import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

import '../config.dart';
import '../db/database.dart';
import '../errors.dart';
import 'auth_service.dart';

/// Emisión, consulta, pérdida y conciliación de tarjetas.
class CardService {
  /// Crea el servicio.
  CardService(this.pool, this.config, this.auth);

  /// Pool de la API.
  final Pool<void> pool;

  /// Configuración (prefijo y llave maestra).
  final ApiConfig config;

  /// Para enviar y validar códigos por correo.
  final AuthService auth;

  static const _cardColumns =
      'c.id, c.number, c.uid, c.signature, c.status, c.balance_cents, '
      'c.cardholder_id, c.created_at, h.full_name AS cardholder_name';

  /// Genera número, UID y firma para una tarjeta nueva (regla 9 y 10).
  Future<({String number, String uid, String signature})> newCredentials(
    Session session,
  ) => newCardCredentials(session, config);

  /// Emite una tarjeta virtual `PENDING` para [cardholderId].
  Future<Map<String, Object?>> issue(String cardholderId) async {
    return pool.runTx((tx) async {
      final holder = await query(
        tx,
        'SELECT 1 FROM cardholders WHERE id = @id:uuid',
        {'id': cardholderId},
      );
      if (holder.isEmpty) {
        throw const ApiException(
          ApiErrorCode.notFound,
          'Titular no encontrado.',
        );
      }
      final open = await query(
        tx,
        "SELECT 1 FROM cards WHERE cardholder_id = @id:uuid AND status <> 'REPLACED'",
        {'id': cardholderId},
      );
      if (open.isNotEmpty) {
        throw const ApiException(
          ApiErrorCode.conflict,
          'El titular ya tiene una tarjeta vigente.',
        );
      }
      final creds = await newCredentials(tx);
      final rows = await query(
        tx,
        'INSERT INTO cards (number, uid, signature, cardholder_id) '
        'VALUES (@n, @u, @s, @h:uuid) RETURNING id',
        {
          'n': creds.number,
          'u': creds.uid,
          's': creds.signature,
          'h': cardholderId,
        },
      );
      return (await _byId(tx, rows.first['id'] as String))!;
    });
  }

  /// Entrega la tarjeta: `PENDING` → `ACTIVE`.
  Future<Map<String, Object?>> deliver(String cardId) async {
    final rows = await query(
      pool,
      "UPDATE cards SET status = 'ACTIVE', updated_at = now() "
      "WHERE id = @id:uuid AND status = 'PENDING' RETURNING id",
      {'id': cardId},
    );
    if (rows.isEmpty) {
      throw const ApiException(
        ApiErrorCode.conflict,
        'Solo se puede entregar una tarjeta PENDING.',
      );
    }
    return (await _byId(pool, cardId))!;
  }

  /// Tarjetas del titular, con credenciales para su QR.
  Future<List<Map<String, Object?>>> cardsOf(String cardholderId) async {
    final rows = await query(
      pool,
      'SELECT $_cardColumns FROM cards c JOIN cardholders h ON h.id = c.cardholder_id '
      'WHERE c.cardholder_id = @id:uuid ORDER BY c.created_at DESC',
      {'id': cardholderId},
    );
    return rows.map(cardJson).toList();
  }

  /// Movimientos de una tarjeta; si [ownerId] se indica, verifica dueño.
  Future<List<Map<String, Object?>>> transactions(
    String cardId, {
    String? ownerId,
  }) async {
    if (ownerId != null) await _requireOwner(cardId, ownerId);
    final rows = await query(
      pool,
      'SELECT id, type, amount_cents, balance_after_cents, created_at '
      'FROM transactions WHERE card_id = @id:uuid ORDER BY created_at DESC',
      {'id': cardId},
    );
    return [
      for (final t in rows)
        {
          'transactionId': t['id'],
          'type': t['type'],
          'amountCents': t['amount_cents'],
          'balanceAfterCents': t['balance_after_cents'],
          'createdAt': (t['created_at'] as DateTime).toUtc().toIso8601String(),
        },
    ];
  }

  /// Paso 1 del reporte de pérdida: envía un código al correo del titular.
  Future<void> startLossReport(String cardholderId, String cardId) async {
    final card = await _requireOwner(cardId, cardholderId);
    if (card['status'] != 'ACTIVE' && card['status'] != 'PENDING') {
      throw const ApiException(
        ApiErrorCode.conflict,
        'Esta tarjeta ya no se puede reportar.',
      );
    }
    await auth.sendCode(
      cardholderId: cardholderId,
      email: card['email'] as String,
      purpose: 'REPORT_LOSS',
      cardId: cardId,
      subject: 'Confirma el reporte de pérdida de tu tarjeta',
    );
  }

  /// Paso 2: con el código correcto la tarjeta pasa a `BLOCKED` (regla 11).
  Future<Map<String, Object?>> confirmLossReport(
    String cardholderId,
    String cardId,
    String code,
  ) async {
    await _requireOwner(cardId, cardholderId);
    await auth.consumeCode(
      cardholderId: cardholderId,
      purpose: 'REPORT_LOSS',
      code: code,
      cardId: cardId,
    );
    await query(
      pool,
      "UPDATE cards SET status = 'BLOCKED', updated_at = now() "
      "WHERE id = @id:uuid AND status IN ('ACTIVE', 'PENDING')",
      {'id': cardId},
    );
    return (await _byId(pool, cardId))!;
  }

  /// Busca tarjetas por número, titular o correo (administración).
  Future<List<Map<String, Object?>>> search(
    String q, {
    bool activeOnly = false,
  }) async {
    final rows = await query(
      pool,
      'SELECT $_cardColumns FROM cards c JOIN cardholders h ON h.id = c.cardholder_id '
      "WHERE (@q = '' OR c.number LIKE '%' || @q || '%' "
      "OR h.full_name ILIKE '%' || @q || '%' OR h.email::text ILIKE '%' || @q || '%') "
      "AND (NOT @a OR c.status = 'ACTIVE') ORDER BY c.created_at DESC LIMIT 50",
      {'q': q.trim(), 'a': activeOnly},
    );
    return rows.map(cardJson).toList();
  }

  /// Busca titulares por nombre o correo.
  Future<List<Map<String, Object?>>> searchCardholders(String q) async {
    final rows = await query(
      pool,
      'SELECT id, full_name, email::text AS email, email_verified_at, created_at '
      "FROM cardholders WHERE @q = '' OR full_name ILIKE '%' || @q || '%' "
      "OR email::text ILIKE '%' || @q || '%' ORDER BY created_at DESC LIMIT 50",
      {'q': q.trim()},
    );
    return [
      for (final h in rows)
        {
          'cardholderId': h['id'],
          'fullName': h['full_name'],
          'email': h['email'],
          'emailVerified': h['email_verified_at'] != null,
        },
    ];
  }

  /// Regla 7: saldo frente a suma de movimientos por tarjeta.
  Future<Map<String, Object?>> reconciliation() async {
    final rows = await query(
      pool,
      'SELECT card_id, number, status, balance_cents, ledger_cents, '
      'difference_cents, transaction_count FROM card_reconciliation ORDER BY number',
    );
    final items = [
      for (final r in rows)
        {
          'cardId': r['card_id'],
          'cardNumberMasked': CardNumber.masked(r['number'] as String),
          'status': r['status'],
          'balanceCents': r['balance_cents'],
          'ledgerCents': r['ledger_cents'],
          'differenceCents': r['difference_cents'],
          'transactionCount': r['transaction_count'],
        },
    ];
    return {
      'cards': items.length,
      'cardsWithDifference': items
          .where((i) => i['differenceCents'] != 0)
          .length,
      'totalBalanceCents': items.fold<int>(
        0,
        (s, i) => s + (i['balanceCents']! as int),
      ),
      'totalDifferenceCents': items.fold<int>(
        0,
        (s, i) => s + (i['differenceCents']! as int).abs(),
      ),
      'items': items,
    };
  }

  Future<Map<String, dynamic>> _requireOwner(
    String cardId,
    String ownerId,
  ) async {
    final rows = await query(
      pool,
      'SELECT c.status, h.email::text AS email FROM cards c '
      'JOIN cardholders h ON h.id = c.cardholder_id '
      'WHERE c.id = @id:uuid AND c.cardholder_id = @o:uuid',
      {'id': cardId, 'o': ownerId},
    );
    if (rows.isEmpty) {
      throw const ApiException(ApiErrorCode.notFound, 'Tarjeta no encontrada.');
    }
    return rows.first;
  }

  Future<Map<String, Object?>?> _byId(Session s, String id) async {
    final rows = await query(
      s,
      'SELECT $_cardColumns FROM cards c JOIN cardholders h ON h.id = c.cardholder_id '
      'WHERE c.id = @id:uuid',
      {'id': id},
    );
    return rows.isEmpty ? null : cardJson(rows.first);
  }

  /// Tarjeta en JSON, con sus credenciales (contenido del QR).
  static Map<String, Object?> cardJson(Map<String, dynamic> c) => {
    'cardId': c['id'],
    'cardholderId': c['cardholder_id'],
    'cardholderName': c['cardholder_name'],
    'number': c['number'],
    'numberMasked': CardNumber.masked(c['number'] as String),
    'status': c['status'],
    'balanceCents': c['balance_cents'],
    'credentials': CardCredentials(
      number: c['number'] as String,
      uid: c['uid'] as String,
      signature: c['signature'] as String,
    ).toJson(),
  };
}

/// Genera número (Luhn, prefijo configurable), UID simulado y firma HMAC
/// para una tarjeta nueva. Si el número o el UID ya existen, se regeneran
/// (regla 9).
Future<({String number, String uid, String signature})> newCardCredentials(
  Session session,
  ApiConfig config,
) async {
  while (true) {
    final number = CardNumber.generate(config.cardNumberPrefix);
    final uid = CardSignature.generateUid();
    final taken = await query(
      session,
      'SELECT 1 FROM cards WHERE number = @n OR uid = @u',
      {'n': number, 'u': uid},
    );
    if (taken.isNotEmpty) continue;
    return (
      number: number,
      uid: uid,
      signature: CardSignature.sign(
        masterKey: config.cardMasterKey,
        number: number,
        uid: uid,
      ),
    );
  }
}
