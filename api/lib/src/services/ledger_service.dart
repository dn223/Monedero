import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

import '../config.dart';
import '../db/database.dart';
import '../errors.dart';
import '../security.dart';

/// Recargas y débitos: **las únicas operaciones de caja que mueven dinero.**
///
/// Cumple las reglas 2 a 6 y 10: valida monto y firma, y en una sola
/// transacción bloquea la tarjeta (`FOR UPDATE`), verifica estado y saldo,
/// actualiza el saldo e inserta el movimiento con su `Idempotency-Key`.
class LedgerService {
  /// Crea el servicio.
  LedgerService(this.pool, this.config, this.hasher);

  /// Pool con el usuario de permisos mínimos.
  final Pool<void> pool;

  /// Configuración (llave maestra, límite de PIN, intentos).
  final ApiConfig config;

  /// Verificador de PIN.
  final PasswordHasher hasher;

  /// Recarga [amountCents] (múltiplo de $5) en la tarjeta [card].
  Future<Map<String, Object?>> topUp({
    required CardCredentials card,
    required int amountCents,
    required String idempotencyKey,
    required String terminalId,
    required String staffId,
  }) {
    if (!Money.isValidTopUp(amountCents)) {
      throw const ApiException(
        ApiErrorCode.invalidAmount,
        r'La recarga debe ser un múltiplo de $5.00 mayor que cero.',
      );
    }
    return _apply(
      TransactionType.topUp,
      card,
      amountCents,
      idempotencyKey,
      terminalId,
      staffId,
    );
  }

  /// Cobra [amountCents] de la tarjeta [card]; exige [pin] sobre el límite.
  Future<Map<String, Object?>> debit({
    required CardCredentials card,
    required int amountCents,
    required String idempotencyKey,
    required String terminalId,
    required String staffId,
    String? pin,
  }) async {
    if (!Money.isValidDebitAmount(amountCents)) {
      throw const ApiException(
        ApiErrorCode.invalidAmount,
        'El cobro debe ser mayor que cero.',
      );
    }
    _verifySignature(card);
    if (amountCents > config.pinRequiredAboveCents) {
      if (pin == null || pin.isEmpty) {
        throw ApiException(
          ApiErrorCode.pinRequired,
          'Cobros mayores de ${Money.format(config.pinRequiredAboveCents)} '
          'requieren el PIN del titular.',
        );
      }
      await _verifyPin(card.number, pin);
    }
    return _apply(
      TransactionType.debit,
      card,
      amountCents,
      idempotencyKey,
      terminalId,
      staffId,
    );
  }

  /// Valida número, UID y firma de la tarjeta sin tocar la base.
  void _verifySignature(CardCredentials card) {
    final valid =
        CardNumber.isValid(card.number) &&
        CardSignature.verify(
          masterKey: config.cardMasterKey,
          number: card.number,
          uid: card.uid,
          signature: card.signature,
        );
    if (!valid) {
      throw const ApiException(
        ApiErrorCode.invalidCardSignature,
        'La tarjeta no es válida (número, UID o firma no coinciden).',
      );
    }
  }

  Future<Map<String, Object?>> _apply(
    TransactionType type,
    CardCredentials card,
    int amountCents,
    String key,
    String terminalId,
    String staffId,
  ) async {
    _verifySignature(card);
    try {
      return await pool.runTx((tx) async {
        // Regla 4: bloquea la fila; otras operaciones sobre la misma tarjeta
        // esperan aquí hasta el COMMIT.
        final rows = await query(
          tx,
          'SELECT id, number, uid, signature, status, balance_cents '
          'FROM cards WHERE number = @n FOR UPDATE',
          {'n': card.number},
        );
        if (rows.isEmpty ||
            (rows.first['uid'] as String) != card.uid.toUpperCase() ||
            (rows.first['signature'] as String) !=
                card.signature.toUpperCase()) {
          throw const ApiException(
            ApiErrorCode.invalidCardSignature,
            'La tarjeta no es válida (número, UID o firma no coinciden).',
          );
        }
        final row = rows.first;
        final cardId = row['id'] as String;

        // Regla 5: con la fila bloqueada, una clave repetida devuelve el
        // resultado original sin aplicar nada.
        final replay = await _findByKey(tx, key);
        if (replay != null) {
          return _replayOrReject(replay, cardId, type, amountCents);
        }

        if (row['status'] != CardStatus.active.wireName) {
          throw ApiException(
            ApiErrorCode.cardNotActive,
            'La tarjeta no está activa (${row['status']}).',
            details: {'status': row['status']},
          );
        }
        final balance = row['balance_cents'] as int;
        final newBalance = balance + type.sign * amountCents;
        if (newBalance < 0) {
          throw ApiException(
            ApiErrorCode.insufficientFunds,
            'Saldo insuficiente.',
            details: {'balanceCents': balance, 'amountCents': amountCents},
          );
        }
        await query(
          tx,
          'UPDATE cards SET balance_cents = @b, version = version + 1, '
          'updated_at = now() WHERE id = @id:uuid',
          {'b': newBalance, 'id': cardId},
        );
        final inserted = await query(
          tx,
          'INSERT INTO transactions (card_id, type, amount_cents, '
          'balance_after_cents, idempotency_key, terminal_id, staff_user_id) '
          'VALUES (@c:uuid, @t, @a, @b, @k, @term:uuid, @s:uuid) '
          'RETURNING id, card_id, type, amount_cents, balance_after_cents, '
          'created_at',
          {
            'c': cardId,
            't': type.wireName,
            'a': amountCents,
            'b': newBalance,
            'k': key,
            'term': terminalId,
            's': staffId,
          },
        );
        return receipt(inserted.first, row['number'] as String);
      });
    } on Object catch (error) {
      // Carrera con la misma clave en otra tarjeta: la base la detiene.
      if (!isUniqueViolation(error)) rethrow;
      final replay = await _findByKey(pool, key);
      if (replay == null) rethrow;
      final cardId = (await query(
        pool,
        'SELECT id FROM cards WHERE number = @n',
        {'n': card.number},
      )).firstOrNull?['id'];
      return _replayOrReject(replay, cardId as String?, type, amountCents);
    }
  }

  Future<Map<String, dynamic>?> _findByKey(Session s, String key) async {
    final rows = await query(
      s,
      'SELECT t.id, t.card_id, t.type, t.amount_cents, t.balance_after_cents, '
      't.created_at, c.number FROM transactions t JOIN cards c ON c.id = t.card_id '
      'WHERE t.idempotency_key = @k',
      {'k': key},
    );
    return rows.firstOrNull;
  }

  Map<String, Object?> _replayOrReject(
    Map<String, dynamic> original,
    String? cardId,
    TransactionType type,
    int amountCents,
  ) {
    final same =
        original['card_id'] == cardId &&
        original['type'] == type.wireName &&
        original['amount_cents'] == amountCents;
    if (!same) {
      throw const ApiException(
        ApiErrorCode.idempotencyKeyReused,
        'Esa Idempotency-Key ya se usó para otra operación.',
      );
    }
    return receipt(original, original['number'] as String);
  }

  Future<void> _verifyPin(String number, String pin) async {
    final rows = await query(
      pool,
      'SELECT h.id, h.pin_hash, h.failed_pin_attempts, '
      '(h.pin_locked_until IS NOT NULL AND h.pin_locked_until > now()) AS locked '
      'FROM cardholders h JOIN cards c ON c.cardholder_id = h.id '
      'WHERE c.number = @n',
      {'n': number},
    );
    if (rows.isEmpty) return; // La firma ya se validó; _apply rechazará.
    final holder = rows.first;
    if (holder['locked'] == true) {
      throw const ApiException(
        ApiErrorCode.tooManyAttempts,
        'PIN bloqueado por intentos fallidos. Intenta en 15 minutos.',
      );
    }
    if (hasher.verify(pin, holder['pin_hash'] as String)) {
      await query(
        pool,
        'UPDATE cardholders SET failed_pin_attempts = 0, pin_locked_until = NULL '
        'WHERE id = @id:uuid',
        {'id': holder['id']},
      );
      return;
    }
    final attempts = (holder['failed_pin_attempts'] as int) + 1;
    final lock = attempts >= config.maxPinAttempts;
    await query(
      pool,
      'UPDATE cardholders SET failed_pin_attempts = @a, pin_locked_until = '
      "CASE WHEN @l THEN now() + interval '15 minutes' ELSE NULL END "
      'WHERE id = @id:uuid',
      {'a': lock ? 0 : attempts, 'l': lock, 'id': holder['id']},
    );
    throw ApiException(
      lock ? ApiErrorCode.tooManyAttempts : ApiErrorCode.invalidPin,
      lock
          ? 'PIN bloqueado por intentos fallidos. Intenta en 15 minutos.'
          : 'PIN incorrecto.',
      details: {if (!lock) 'attemptsLeft': config.maxPinAttempts - attempts},
    );
  }

  /// Comprobante de un movimiento (también se usa al repetir una clave).
  static Map<String, Object?> receipt(Map<String, dynamic> t, String number) =>
      {
        'transactionId': t['id'],
        'type': t['type'],
        'amountCents': t['amount_cents'],
        'balanceAfterCents': t['balance_after_cents'],
        'cardNumberMasked': CardNumber.masked(number),
        'createdAt': (t['created_at'] as DateTime).toUtc().toIso8601String(),
      };
}
