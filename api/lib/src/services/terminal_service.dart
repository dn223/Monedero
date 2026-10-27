import 'dart:math';

import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../errors.dart';
import '../security.dart';

/// Caja que entró con su código: su usuario de personal y lo que muestra.
typedef TerminalLogin = ({
  String cashierId,
  String terminalId,
  String name,
  String? payCode,
  String terminalToken,
});

/// Terminales de caja autorizados, cada uno con su código de acceso
/// ([TerminalCode]), su usuario de caja y un código corto de 6 dígitos para
/// que el titular pague desde su app.
class TerminalService {
  /// Crea el servicio.
  TerminalService(this.pool, this.hasher);

  /// Pool de la API.
  final Pool<void> pool;

  /// Para la contraseña (inutilizable) del usuario de caja.
  final PasswordHasher hasher;

  /// Nombre del terminal que usa la sesión de demostración.
  static const demoTerminalName = 'Caja Demo';

  /// Registra un terminal con su usuario de caja y devuelve su código de
  /// acceso **una sola vez** (`terminalToken` normalizado y `code` en
  /// grupos); en la base solo queda su SHA-256.
  Future<Map<String, Object?>> create(String name, String? adminId) async {
    if (name.trim().isEmpty) {
      throw const ApiException(
        ApiErrorCode.validationFailed,
        'Falta el nombre.',
      );
    }
    final token = TerminalCode.generate();
    final payCode = await _freePayCode();
    final rows = await pool.runTx((tx) async {
      final created = await query(
        tx,
        'INSERT INTO terminals (name, credential_hash, registered_by, pay_code) '
        'VALUES (@n, @h, @a:uuid, @p) RETURNING id, name, pay_code',
        {'n': name.trim(), 'h': sha256Hex(token), 'a': adminId, 'p': payCode},
      );
      await _createCashier(tx, created.first['id'] as String, name.trim());
      return created;
    });
    return {
      'terminalId': rows.first['id'],
      'name': rows.first['name'],
      'payCode': rows.first['pay_code'],
      'terminalToken': token,
      'code': TerminalCode.format(token),
    };
  }

  /// Solo modo demo: devuelve la "Caja Demo" con una credencial nueva
  /// (rota la anterior) y su código de pago; la crea si no existe.
  Future<Map<String, Object?>> demoTerminal() async {
    final existing = (await query(
      pool,
      'SELECT id, pay_code FROM terminals WHERE name = @n AND active '
      'ORDER BY created_at LIMIT 1',
      {'n': demoTerminalName},
    )).firstOrNull;
    if (existing == null) return create(demoTerminalName, null);
    final token = randomToken();
    final payCode = (existing['pay_code'] as String?) ?? await _freePayCode();
    await query(
      pool,
      'UPDATE terminals SET credential_hash = @h, pay_code = @p '
      'WHERE id = @id:uuid',
      {'h': sha256Hex(token), 'p': payCode, 'id': existing['id']},
    );
    return {
      'terminalId': existing['id'],
      'name': demoTerminalName,
      'payCode': payCode,
      'terminalToken': token,
    };
  }

  /// Solo modo demo: crea una caja nueva "Caja demo N" para el dispositivo
  /// que la pide, así varias personas pueden hacer de cajero a la vez sin
  /// invalidarse la credencial entre sí.
  Future<Map<String, Object?>> createDemo(String staffId) async {
    final count =
        (await query(
              pool,
              "SELECT count(*)::int AS n FROM terminals WHERE name LIKE 'Caja demo %'",
            )).first['n']
            as int;
    return create('Caja demo ${count + 1}', staffId);
  }

  /// Entrada de la caja con su código [raw] (con o sin guiones). Lanza
  /// `INVALID_CREDENTIALS` si no corresponde a una caja activa.
  Future<TerminalLogin> login(String raw) async {
    final code = QrPayloads.terminalToken(raw);
    final rows = code == null
        ? const <Map<String, dynamic>>[]
        : await query(
            pool,
            'UPDATE terminals SET last_seen_at = now() '
            'WHERE credential_hash = @h AND active '
            'RETURNING id, name, pay_code, cashier_id',
            {'h': sha256Hex(code)},
          );
    if (code == null || rows.isEmpty) {
      throw const ApiException(
        ApiErrorCode.invalidCredentials,
        'Código de caja incorrecto o revocado.',
      );
    }
    final t = rows.first;
    final String cashierId =
        t['cashier_id'] as String? ??
        await pool.runTx<String>(
          (tx) => _createCashier(tx, t['id'] as String, t['name'] as String),
        );
    return (
      cashierId: cashierId,
      terminalId: t['id'] as String,
      name: t['name'] as String,
      payCode: t['pay_code'] as String?,
      terminalToken: code,
    );
  }

  /// Crea el usuario de caja del terminal [terminalId] y lo enlaza. Su
  /// contraseña es aleatoria y nadie la conoce: solo se entra con el código.
  Future<String> _createCashier(
    Session tx,
    String terminalId,
    String name,
  ) async {
    final id =
        (await query(
              tx,
              'INSERT INTO staff_users (full_name, email, password_hash, role) '
              "VALUES (@n, @e, @p, 'CASHIER') RETURNING id",
              {
                'n': name,
                'e': 'caja-$terminalId@cajas.monedero.local',
                'p': hasher.hash(randomToken()),
              },
            )).first['id']
            as String;
    await query(
      tx,
      'UPDATE terminals SET cashier_id = @c:uuid WHERE id = @id:uuid',
      {'c': id, 'id': terminalId},
    );
    return id;
  }

  /// Nombre y código de pago del terminal [terminalId] (la caja lo muestra).
  Future<Map<String, Object?>> describe(String terminalId) async {
    final t = (await query(
      pool,
      'SELECT id, name, pay_code FROM terminals WHERE id = @id:uuid',
      {'id': terminalId},
    )).first;
    return {'terminalId': t['id'], 'name': t['name'], 'payCode': t['pay_code']};
  }

  /// Devuelve el id del terminal activo con [token] o lanza
  /// `TERMINAL_NOT_AUTHORIZED`.
  Future<String> authenticate(String? token) async {
    if (token == null || token.isEmpty) {
      throw const ApiException(
        ApiErrorCode.terminalNotAuthorized,
        'Falta la credencial del terminal (X-Terminal-Token).',
      );
    }
    final rows = await query(
      pool,
      'UPDATE terminals SET last_seen_at = now() '
      'WHERE credential_hash = @h AND active RETURNING id',
      {'h': sha256Hex(token)},
    );
    if (rows.isEmpty) {
      throw const ApiException(
        ApiErrorCode.terminalNotAuthorized,
        'Terminal no autorizado o revocado.',
      );
    }
    return rows.first['id'] as String;
  }

  /// Últimos movimientos hechos en el terminal [terminalId].
  Future<List<Map<String, Object?>>> activity(String terminalId) async => [
    for (final t in await query(
      pool,
      'SELECT t.id, t.type, t.amount_cents, t.balance_after_cents, t.created_at, '
      'c.number, h.full_name FROM transactions t JOIN cards c ON c.id = t.card_id '
      'JOIN cardholders h ON h.id = c.cardholder_id '
      'WHERE t.terminal_id = @id:uuid ORDER BY t.created_at DESC LIMIT 10',
      {'id': terminalId},
    ))
      {
        'transactionId': t['id'],
        'type': t['type'],
        'amountCents': t['amount_cents'],
        'balanceAfterCents': t['balance_after_cents'],
        'cardNumberMasked': CardNumber.masked(t['number'] as String),
        'cardholderName': t['full_name'],
        'createdAt': (t['created_at'] as DateTime).toUtc().toIso8601String(),
      },
  ];

  /// Últimos movimientos del terminal con código de pago [payCode].
  Future<List<Map<String, Object?>>> activityByPayCode(String payCode) async {
    final t = (await query(
      pool,
      'SELECT id FROM terminals WHERE pay_code = @c',
      {'c': payCode},
    )).firstOrNull;
    return t == null ? const [] : activity(t['id'] as String);
  }

  /// Lista los terminales.
  Future<List<Map<String, Object?>>> list() async => [
    for (final t in await query(
      pool,
      'SELECT id, name, active, pay_code, last_seen_at FROM terminals '
      'ORDER BY created_at',
    ))
      {
        'terminalId': t['id'],
        'name': t['name'],
        'active': t['active'],
        'payCode': t['pay_code'],
        'lastSeenAt': (t['last_seen_at'] as DateTime?)
            ?.toUtc()
            .toIso8601String(),
      },
  ];

  /// Revoca un terminal.
  Future<void> revoke(String id) async {
    // Desactivar su usuario corta también la renovación de su sesión.
    await pool.runTx((tx) async {
      final rows = await query(
        tx,
        'UPDATE terminals SET active = false WHERE id = @id:uuid '
        'RETURNING cashier_id',
        {'id': id},
      );
      final cashierId = rows.firstOrNull?['cashier_id'];
      if (cashierId != null) {
        await query(
          tx,
          'UPDATE staff_users SET active = false WHERE id = @c:uuid',
          {'c': cashierId},
        );
      }
    });
  }

  Future<String> _freePayCode() async {
    final rng = Random.secure();
    while (true) {
      final code = (rng.nextInt(900000) + 100000).toString();
      final taken = await query(
        pool,
        'SELECT 1 FROM terminals WHERE pay_code = @c',
        {'c': code},
      );
      if (taken.isEmpty) return code;
    }
  }
}
