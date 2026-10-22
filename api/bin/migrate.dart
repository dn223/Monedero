import 'dart:io';

import 'package:monedero_api/monedero_api.dart';

/// Aplica migraciones (y opcionalmente reinicia y siembra la base).
///
/// Uso (desde la raíz; normalmente vía `tool/`):
/// - `dart run api/bin/migrate.dart`            migra
/// - `dart run api/bin/migrate.dart --seed`     migra y siembra la demo
/// - `dart run api/bin/migrate.dart --reset`    borra todo, migra y siembra
///   (solo con `DEMO_MODE=true`)
Future<void> main(List<String> args) async {
  final env = loadEnv(findRepoEnv());
  final config = ApiConfig.fromEnvironment(env);
  final reset = args.contains('--reset');
  final seed = args.contains('--seed') || reset;
  if (reset && !config.demoMode) {
    stderr.writeln('Reiniciar solo está permitido con DEMO_MODE=true.');
    exit(2);
  }
  final owner = await openConnection(
    config.database.copyWith(
      user: env['POSTGRES_OWNER_USER'] ?? 'monedero_owner',
      password: env['POSTGRES_OWNER_PASSWORD'] ?? '',
    ),
  );
  try {
    final migrator = Migrator(owner, findMigrationsDir());
    if (reset) {
      await migrator.dropEverything();
      stdout.writeln('  [ok] Base vaciada.');
    }
    await migrator.ensureAppRole(
      config.database.user,
      config.database.password,
    );
    final applied = await migrator.migrate();
    stdout.writeln(
      applied.isEmpty
          ? '  [ok] Sin migraciones pendientes.'
          : '  [ok] Migraciones aplicadas: ${applied.join(', ')}',
    );
    if (seed) {
      final seeded = await seedDemo(owner, config);
      stdout.writeln(
        seeded
            ? '  [ok] Datos de demostración sembrados.'
            : '  [ok] Ya había datos; no se sembró de nuevo.',
      );
    }
  } finally {
    await owner.close();
  }
}
