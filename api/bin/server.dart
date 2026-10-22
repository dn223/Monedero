import 'dart:io';

import 'package:monedero_api/monedero_api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Arranca la API escuchando en todas las interfaces IPv4, para que el
/// emulador (10.0.2.2) y los teléfonos de la misma Wi-Fi puedan conectarse.
Future<void> main() async {
  final config = ApiConfig.fromEnvironment(Platform.environment);
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(buildApiHandler(config));

  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    config.port,
  );
  stdout.writeln(
    'Monedero API $apiVersion escuchando en http://${server.address.host}:'
    '${server.port} (modo demo: ${config.demoMode})',
  );

  // Cierre ordenado con Ctrl+C o `docker compose down`.
  final signals = [
    ProcessSignal.sigint.watch(),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
  ];
  await Future.any(signals.map((signal) => signal.first));
  stdout.writeln('Deteniendo la API...');
  await server.close();
  exit(0);
}
