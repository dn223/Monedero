import 'dart:io';

import 'package:monedero_core/monedero_core.dart';

import '../config.dart';
import '../db/database.dart';
import '../db/migrator.dart';
import '../errors.dart';
import '../seed.dart';

/// Reinicia la base de la demostración desde la API: borra todo, migra y
/// siembra de nuevo, igual que `dart run tool/reset_demo.dart`.
///
/// **Solo con `DEMO_MODE=true`.** Es la única parte de la API que usa al
/// dueño del esquema ([ownerDatabase]): el usuario `monedero_app` no puede
/// borrar movimientos (regla 6). En producción no se configura y la ruta
/// responde `DEMO_MODE_DISABLED` (ver docs/adr/0011).
class DemoResetService {
  /// Crea el servicio.
  DemoResetService(this.config, this.ownerDatabase, this.migrationsDir);

  /// Configuración (modo demo, usuario de la API y llaves para sembrar).
  final ApiConfig config;

  /// Conexión con el dueño del esquema.
  final DatabaseConfig ownerDatabase;

  /// Carpeta `db/migrations`.
  final Directory migrationsDir;

  Future<void>? _running;

  /// Ejecuta el reinicio. Si ya hay uno en curso, espera ese mismo.
  Future<void> reset() {
    if (!config.demoMode) {
      throw const ApiException(
        ApiErrorCode.demoModeDisabled,
        'El modo demo está desactivado.',
      );
    }
    return _running ??= _reset().whenComplete(() => _running = null);
  }

  Future<void> _reset() async {
    final owner = await openConnection(ownerDatabase);
    try {
      final migrator = Migrator(owner, migrationsDir);
      await migrator.dropEverything();
      await migrator.ensureAppRole(
        config.database.user,
        config.database.password,
      );
      await migrator.migrate();
      await seedDemo(owner, config);
    } finally {
      await owner.close();
    }
  }
}
