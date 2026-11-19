import 'dart:io';

import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../errors.dart';
import '../mailer.dart';

/// Anulación de movimientos por administración (ver docs/adr/0016).
///
/// Nunca edita ni borra el movimiento original (regla 6): en una sola
/// transacción bloquea la tarjeta (`FOR UPDATE`), inserta el contramovimiento
/// (`REVERSAL_IN` para un cobro, `REVERSAL_OUT` para una recarga), ajusta el
/// saldo y deja la auditoría en `reversals`. Cada movimiento se anula una sola
/// vez y anular una recarga nunca deja el saldo negativo (regla 3).
class ReversalService {
  /// Crea el servicio.
  ReversalService(this.pool, this.mailer);

  /// Pool con el usuario de permisos mínimos.
  final Pool<void> pool;

  /// Aviso al titular.
  final Mailer mailer;

  /// Anula el movimiento [transactionId] con un [reason] obligatorio.
  Future<Map<String, Object?>> reverse({
    required String transactionId,
    required String reason,
    required String adminId,
    required String idempotencyKey,
  }) async {
    final why = reason.trim();
    if (why.length < 5) {
      throw const ApiException(
        ApiErrorCode.validationFailed,
        'Escribe el motivo de la anulación (al menos 5 caracteres).',
        details: {'field': 'reason'},
      );
    }
    var created = false;
    final Map<String, Object?> result;
    try {
      result = await pool.runTx((tx) async {
        final previous = await _byKey(tx, idempotencyKey);
        if (previous != null) {
          if (previous['originalTransactionId'] != transactionId) {
            throw const ApiException(
              ApiErrorCode.idempotencyKeyReused,
              'Esa Idempotency-Key ya se usó para otra anulación.',
            );
          }
          return previous;
        }

        final original = (await query(
          tx,
          'SELECT id, card_id, type, amount_cents FROM transactions '
          'WHERE id = @id:uuid',
          {'id': transactionId},
        )).firstOrNull;
        if (original == null) {
          throw const ApiException(
            ApiErrorCode.notFound,
            'Movimiento no encontrado.',
          );
        }
        final type = TransactionType.fromWire(original['type'] as String);
        if (!type.isReversible) {
          throw const ApiException(
            ApiErrorCode.transactionNotReversible,
            'Solo se pueden anular recargas y cobros.',
          );
        }

        // Regla 4: la tarjeta queda bloqueada hasta el COMMIT.
        final card = (await query(
          tx,
          'SELECT id, status, balance_cents FROM cards '
          'WHERE id = @id:uuid FOR UPDATE',
          {'id': original['card_id']},
        )).first;

        final already = await query(
          tx,
          'SELECT 1 FROM reversals WHERE original_transaction_id = @id:uuid',
          {'id': transactionId},
        );
        if (already.isNotEmpty) {
          throw const ApiException(
            ApiErrorCode.transactionAlreadyReversed,
            'Este movimiento ya fue anulado.',
          );
        }
        final status = card['status'] as String;
        if (status != CardStatus.active.wireName &&
            status != CardStatus.blocked.wireName) {
          throw ApiException(
            ApiErrorCode.cardNotActive,
            'La tarjeta está $status: su saldo ya no se puede ajustar.',
            details: {'status': status},
          );
        }

        final amount = original['amount_cents'] as int;
        final reversalType = type.reversalType;
        final balance = card['balance_cents'] as int;
        final newBalance = balance + reversalType.sign * amount;
        if (newBalance < 0) {
          throw ApiException(
            ApiErrorCode.insufficientFunds,
            'No se puede anular la recarga: la tarjeta tiene '
            '${Money.format(balance)} y habría que retirar '
            '${Money.format(amount)}.',
            details: {'balanceCents': balance, 'amountCents': amount},
          );
        }

        await query(
          tx,
          'UPDATE cards SET balance_cents = @b, version = version + 1, '
          'updated_at = now() WHERE id = @id:uuid',
          {'b': newBalance, 'id': card['id']},
        );
        final inserted = (await query(
          tx,
          'INSERT INTO transactions (card_id, type, amount_cents, '
          'balance_after_cents, idempotency_key, staff_user_id) '
          'VALUES (@c:uuid, @t, @a, @b, @k, @s:uuid) RETURNING id',
          {
            'c': card['id'],
            't': reversalType.wireName,
            'a': amount,
            'b': newBalance,
            'k': idempotencyKey,
            's': adminId,
          },
        )).first;
        await query(
          tx,
          'INSERT INTO reversals (original_transaction_id, '
          'reversal_transaction_id, reason, idempotency_key, performed_by) '
          'VALUES (@o:uuid, @r:uuid, @why, @k, @s:uuid)',
          {
            'o': transactionId,
            'r': inserted['id'],
            'why': why,
            'k': idempotencyKey,
            's': adminId,
          },
        );
        created = true;
        return (await _byKey(tx, idempotencyKey))!;
      });
    } on Object catch (error) {
      // Dos anulaciones simultáneas del mismo movimiento: decide el UNIQUE.
      if (!isUniqueViolation(error)) rethrow;
      final previous = await _byKey(pool, idempotencyKey);
      if (previous != null &&
          previous['originalTransactionId'] == transactionId) {
        return previous;
      }
      throw const ApiException(
        ApiErrorCode.transactionAlreadyReversed,
        'Este movimiento ya fue anulado.',
      );
    }
    if (created) await _notify(result);
    return result;
  }

  Future<Map<String, Object?>?> _byKey(Session s, String key) async {
    final row = (await query(
      s,
      'SELECT r.id, r.original_transaction_id, r.reversal_transaction_id, '
      'r.reason, r.created_at, t.type, t.amount_cents, t.balance_after_cents, '
      'c.number FROM reversals r '
      'JOIN transactions t ON t.id = r.reversal_transaction_id '
      'JOIN cards c ON c.id = t.card_id WHERE r.idempotency_key = @k',
      {'k': key},
    )).firstOrNull;
    if (row == null) return null;
    return {
      'reversalId': row['id'],
      'originalTransactionId': row['original_transaction_id'],
      'reversalTransactionId': row['reversal_transaction_id'],
      'type': row['type'],
      'amountCents': row['amount_cents'],
      'balanceAfterCents': row['balance_after_cents'],
      'reason': row['reason'],
      'cardNumberMasked': CardNumber.masked(row['number'] as String),
      'createdAt': (row['created_at'] as DateTime).toUtc().toIso8601String(),
    };
  }

  /// Avisa al titular; un fallo del correo no afecta la anulación.
  Future<void> _notify(Map<String, Object?> r) async {
    try {
      final holder = (await query(
        pool,
        'SELECT h.email::text AS email, h.full_name FROM transactions t '
        'JOIN cards c ON c.id = t.card_id '
        'JOIN cardholders h ON h.id = c.cardholder_id WHERE t.id = @id:uuid',
        {'id': r['reversalTransactionId']},
      )).firstOrNull;
      if (holder == null) return;
      final amount = Money.format(r['amountCents']! as int);
      final refund = r['type'] == TransactionType.reversalIn.wireName;
      await mailer.send(
        to: holder['email'] as String,
        subject: 'Movimiento anulado: ${refund ? '+' : '-'}$amount',
        text:
            'Hola ${holder['full_name']},\n\n'
            '${refund ? 'Se anuló un cobro y te devolvimos' : 'Se anuló una recarga y se retiraron'} '
            '$amount en tu tarjeta ${r['cardNumberMasked']}.\n'
            'Motivo: ${r['reason']}\n'
            'Saldo actual: ${Money.format(r['balanceAfterCents']! as int)}.',
      );
    } on Object catch (error) {
      stderr.writeln('No se pudo enviar el aviso de anulación: $error');
    }
  }
}
