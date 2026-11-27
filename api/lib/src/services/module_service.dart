import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../errors.dart';

/// Módulos de la aplicación: consulta, cambio por administración y la
/// verificación que hace cada ruta de un módulo (ver docs/adr/0014).
class ModuleService {
  /// Crea el servicio.
  ModuleService(this.pool);

  /// Pool de la API.
  final Pool<void> pool;

  static const _columns =
      'm.key, m.enabled, m.updated_at, s.full_name AS updated_by_name';

  /// Todos los módulos conocidos con su estado, en el orden de [AppModule].
  Future<List<Map<String, Object?>>> list() async {
    final rows = await query(
      pool,
      'SELECT $_columns FROM app_modules m '
      'LEFT JOIN staff_users s ON s.id = m.updated_by',
    );
    final byKey = {for (final r in rows) r['key'] as String: r};
    return [
      for (final module in AppModule.values)
        if (byKey[module.key] case final row?) _json(module, row),
    ];
  }

  /// `true` si [module] está encendido. Un módulo sin fila se considera
  /// apagado: la base manda.
  Future<bool> isEnabled(AppModule module) async {
    final rows = await query(
      pool,
      'SELECT enabled FROM app_modules WHERE key = @k',
      {'k': module.key},
    );
    return rows.isNotEmpty && rows.first['enabled'] == true;
  }

  /// Lanza `MODULE_DISABLED` si [module] está apagado.
  Future<void> require(AppModule module) async {
    if (await isEnabled(module)) return;
    throw ApiException(
      ApiErrorCode.moduleDisabled,
      'El módulo "${module.label}" está desactivado.',
      details: {'module': module.key},
    );
  }

  /// Enciende o apaga [key] y deja el cambio en `module_changes`, todo en
  /// una transacción.
  Future<Map<String, Object?>> set(
    String key, {
    required bool enabled,
    required String staffId,
  }) async {
    final module = AppModule.fromKey(key);
    if (module == null) {
      throw ApiException(ApiErrorCode.notFound, 'No existe el módulo "$key".');
    }
    await pool.runTx((tx) async {
      final updated = await query(
        tx,
        'UPDATE app_modules SET enabled = @e, updated_at = now(), '
        'updated_by = @s:uuid WHERE key = @k RETURNING key',
        {'e': enabled, 's': staffId, 'k': key},
      );
      if (updated.isEmpty) {
        throw ApiException(
          ApiErrorCode.notFound,
          'No existe el módulo "$key".',
        );
      }
      await query(
        tx,
        'INSERT INTO module_changes (module_key, enabled, changed_by) '
        'VALUES (@k, @e, @s:uuid)',
        {'k': key, 'e': enabled, 's': staffId},
      );
    });
    final row = (await query(
      pool,
      'SELECT $_columns FROM app_modules m '
      'LEFT JOIN staff_users s ON s.id = m.updated_by WHERE m.key = @k',
      {'k': key},
    )).first;
    return _json(module, row);
  }

  static Map<String, Object?> _json(
    AppModule module,
    Map<String, dynamic> row,
  ) => {
    'key': module.key,
    'name': module.label,
    'description': module.description,
    'audience': module.audience.wireName,
    'enabled': row['enabled'],
    'updatedAt': (row['updated_at'] as DateTime).toUtc().toIso8601String(),
    'updatedByName': row['updated_by_name'],
  };
}
