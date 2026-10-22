import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../errors.dart';
import 'card_service.dart';

/// Punto donde las pruebas pueden forzar una falla a mitad de la reposición.
typedef FaultHook = Future<void> Function(String stage);

/// Reposición de una tarjeta bloqueada (regla 11), en **una sola transacción**.
class ReplacementService {
  /// Crea el servicio. [faultHook] solo se usa en pruebas.
  ReplacementService(this.pool, this.cards, {this.faultHook});

  /// Pool de la API.
  final Pool<void> pool;

  /// Para generar credenciales y serializar tarjetas.
  final CardService cards;

  /// Inyector de fallas (pruebas).
  final FaultHook? faultHook;

  /// Crea la tarjeta nueva `ACTIVE`, traslada el saldo con dos movimientos,
  /// marca la anterior `REPLACED` y registra la auditoría. Si algo falla,
  /// PostgreSQL revierte todo.
  Future<Map<String, Object?>> replace({
    required String oldCardId,
    required String adminId,
    required String idempotencyKey,
  }) async {
    return pool.runTx((tx) async {
      final old = await query(
        tx,
        'SELECT id, status, balance_cents, cardholder_id FROM cards '
        'WHERE id = @id:uuid FOR UPDATE',
        {'id': oldCardId},
      );
      if (old.isEmpty) {
        throw const ApiException(
          ApiErrorCode.notFound,
          'Tarjeta no encontrada.',
        );
      }
      final previous = await query(
        tx,
        'SELECT old_card_id, new_card_id, transferred_cents FROM replacements '
        'WHERE idempotency_key = @k',
        {'k': idempotencyKey},
      );
      if (previous.isNotEmpty) {
        if (previous.first['old_card_id'] != oldCardId) {
          throw const ApiException(
            ApiErrorCode.idempotencyKeyReused,
            'Esa Idempotency-Key ya se usó para otra reposición.',
          );
        }
        return _result(tx, previous.first);
      }
      final card = old.first;
      if (card['status'] != CardStatus.blocked.wireName) {
        throw const ApiException(
          ApiErrorCode.conflict,
          'Solo se reponen tarjetas BLOCKED (reporte de pérdida confirmado).',
        );
      }
      final balance = card['balance_cents'] as int;
      final creds = await cards.newCredentials(tx);
      final created = await query(
        tx,
        'INSERT INTO cards (number, uid, signature, cardholder_id, status) '
        "VALUES (@n, @u, @s, @h:uuid, 'ACTIVE') RETURNING id",
        {
          'n': creds.number,
          'u': creds.uid,
          's': creds.signature,
          'h': card['cardholder_id'],
        },
      );
      final newCardId = created.first['id'] as String;
      await faultHook?.call('after-new-card');

      if (balance > 0) {
        await query(
          tx,
          'UPDATE cards SET balance_cents = 0, version = version + 1 '
          'WHERE id = @id:uuid',
          {'id': oldCardId},
        );
        await _movement(
          tx,
          oldCardId,
          'REPLACEMENT_OUT',
          balance,
          0,
          '$idempotencyKey:out',
          adminId,
        );
        await faultHook?.call('after-transfer-out');
        await query(
          tx,
          'UPDATE cards SET balance_cents = @b, version = version + 1 '
          'WHERE id = @id:uuid',
          {'b': balance, 'id': newCardId},
        );
        await _movement(
          tx,
          newCardId,
          'REPLACEMENT_IN',
          balance,
          balance,
          '$idempotencyKey:in',
          adminId,
        );
      }
      await query(
        tx,
        "UPDATE cards SET status = 'REPLACED', updated_at = now() WHERE id = @id:uuid",
        {'id': oldCardId},
      );
      final audit = await query(
        tx,
        'INSERT INTO replacements (old_card_id, new_card_id, transferred_cents, '
        'idempotency_key, performed_by) VALUES (@o:uuid, @n:uuid, @t, @k, @a:uuid) '
        'RETURNING old_card_id, new_card_id, transferred_cents',
        {
          'o': oldCardId,
          'n': newCardId,
          't': balance,
          'k': idempotencyKey,
          'a': adminId,
        },
      );
      return _result(tx, audit.first);
    });
  }

  Future<void> _movement(
    Session tx,
    String cardId,
    String type,
    int amount,
    int balanceAfter,
    String key,
    String adminId,
  ) => query(
    tx,
    'INSERT INTO transactions (card_id, type, amount_cents, balance_after_cents, '
    'idempotency_key, staff_user_id) VALUES (@c:uuid, @t, @a, @b, @k, @s:uuid)',
    {
      'c': cardId,
      't': type,
      'a': amount,
      'b': balanceAfter,
      'k': key,
      's': adminId,
    },
  );

  Future<Map<String, Object?>> _result(
    Session tx,
    Map<String, dynamic> r,
  ) async {
    final rows = await query(
      tx,
      'SELECT c.id, c.number, c.uid, c.signature, c.status, c.balance_cents, '
      'c.cardholder_id, h.full_name AS cardholder_name FROM cards c '
      'JOIN cardholders h ON h.id = c.cardholder_id WHERE c.id IN (@o:uuid, @n:uuid)',
      {'o': r['old_card_id'], 'n': r['new_card_id']},
    );
    Map<String, Object?> pick(Object? id) =>
        CardService.cardJson(rows.firstWhere((c) => c['id'] == id));
    return {
      'transferredCents': r['transferred_cents'],
      'oldCard': pick(r['old_card_id']),
      'newCard': pick(r['new_card_id']),
    };
  }
}
