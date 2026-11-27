import 'dart:io';

import 'package:monedero_api/monedero_api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Arranca la API escuchando en todas las interfaces IPv4, para que el
/// emulador (10.0.2.2) y los teléfonos de la misma Wi-Fi puedan conectarse.
Future<void> main() async {
  final env = Platform.environment;
  final config = ApiConfig.fromEnvironment(env)..requireSecrets();
  final pool = openPool(config.database);
  final smtp = SmtpMailer(
    host: config.smtpHost,
    port: config.smtpPort,
    from: config.mailFrom,
  );
  // Solo en modo demo: buzón en memoria y reinicio de la demo por API.
  final ownerPassword = env['POSTGRES_OWNER_PASSWORD'] ?? '';
  final services = Services(
    config,
    pool,
    config.demoMode ? RecordingMailer(smtp) : smtp,
    demoReset: config.demoMode && ownerPassword.isNotEmpty
        ? DemoResetService(
            config,
            config.database.copyWith(
              user: env['POSTGRES_OWNER_USER'] ?? 'monedero_owner',
              password: ownerPassword,
            ),
            findMigrationsDir(),
          )
        : null,
  );
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(buildApiHandler(config, services: services));

  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    config.port,
  );
  stdout.writeln(
    'Monedero API $apiVersion escuchando en http://${server.address.host}:'
    '${server.port} (modo demo: ${config.demoMode})',
  );
  if (config.webDir.isNotEmpty) {
    stdout.writeln('App web servida desde ${config.webDir} (si existe).');
  }

  // Cierre ordenado con Ctrl+C o `docker compose down`.
  final signals = [
    ProcessSignal.sigint.watch(),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
  ];
  await Future.any(signals.map((signal) => signal.first));
  stdout.writeln('Deteniendo la API...');
  await server.close();
  await pool.close();
  exit(0);
}
