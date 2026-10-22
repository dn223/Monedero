import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../errors.dart';
import '../security.dart';

/// Terminales de caja autorizados, cada uno con su credencial.
class TerminalService {
  /// Crea el servicio.
  TerminalService(this.pool);

  /// Pool de la API.
  final Pool<void> pool;

  /// Registra un terminal y devuelve su credencial **una sola vez**; en la
  /// base solo queda su SHA-256.
  Future<Map<String, Object?>> create(String name, String adminId) async {
    if (name.trim().isEmpty) {
      throw const ApiException(
        ApiErrorCode.validationFailed,
        'Falta el nombre.',
      );
    }
    final token = randomToken();
    final rows = await query(
      pool,
      'INSERT INTO terminals (name, credential_hash, registered_by) '
      'VALUES (@n, @h, @a:uuid) RETURNING id, name',
      {'n': name.trim(), 'h': sha256Hex(token), 'a': adminId},
    );
    return {
      'terminalId': rows.first['id'],
      'name': rows.first['name'],
      'terminalToken': token,
    };
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

  /// Lista los terminales.
  Future<List<Map<String, Object?>>> list() async => [
    for (final t in await query(
      pool,
      'SELECT id, name, active, last_seen_at, created_at FROM terminals '
      'ORDER BY created_at',
    ))
      {
        'terminalId': t['id'],
        'name': t['name'],
        'active': t['active'],
        'lastSeenAt': (t['last_seen_at'] as DateTime?)
            ?.toUtc()
            .toIso8601String(),
      },
  ];

  /// Revoca un terminal.
  Future<void> revoke(String id) async {
    await query(
      pool,
      'UPDATE terminals SET active = false WHERE id = @id:uuid',
      {'id': id},
    );
  }
}
