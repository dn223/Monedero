/// API HTTP de Monedero.
///
/// El punto de entrada del servidor está en `bin/server.dart`; este archivo
/// expone lo necesario para construir el manejador en pruebas.
library;

export 'src/app.dart' show buildApiHandler;
export 'src/config.dart' show ApiConfig;
export 'src/version.dart' show apiVersion;
