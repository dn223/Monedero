import 'dart:convert';
import 'dart:io';

import 'src/common.dart';
import 'src/env.dart';

/// Levanta PostgreSQL, Mailpit y la API con Docker Compose y espera a que la
/// API responda en `/health`.
///
/// Uso: `dart run tool/up.dart`
Future<void> main(List<String> args) async {
  heading('Configuración');
  if (ensureEnvFile()) {
    ok('Se creó .env desde .env.example con secretos aleatorios.');
  } else {
    ok('Usando el .env existente.');
  }
  final env = readEnv();
  final apiPort = env['API_PORT'] ?? '8080';
  final mailpitPort = env['MAILPIT_UI_PORT'] ?? '8025';

  heading('Levantando contenedores');
  final code = await compose(['up', '-d', '--build', '--wait']);
  if (code != 0) {
    exitWith(
      code,
      'docker compose falló. ¿Está abierto Docker Desktop? '
      'Prueba `dart run tool/doctor.dart`.',
    );
  }

  heading('Migraciones y datos de demostración');
  final migrated = await run('dart', ['run', 'api/bin/migrate.dart', '--seed']);
  if (migrated != 0) exitWith(migrated, 'Las migraciones fallaron.');

  heading('Esperando la API');
  final healthUrl = Uri.parse('http://localhost:$apiPort/health');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    for (var attempt = 1; attempt <= 30; attempt++) {
      try {
        final request = await client.getUrl(healthUrl);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) {
          ok('API lista: $body');
          stdout
            ..writeln()
            ..writeln('  API ............ http://localhost:$apiPort')
            ..writeln('  Correos (Mailpit) http://localhost:$mailpitPort')
            ..writeln(
              '  App web ........ cd apps/app && '
              'flutter run -d chrome --web-port 5000',
            )
            ..writeln('  Detener ........ dart run tool/down.dart');
          return;
        }
      } on IOException {
        // La API aún no acepta conexiones; se reintenta.
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  } finally {
    client.close(force: true);
  }
  exitWith(
    1,
    'La API no respondió en $healthUrl. Revisa: docker compose logs api',
  );
}
