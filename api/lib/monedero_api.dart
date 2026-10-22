/// API HTTP de Monedero.
///
/// El punto de entrada del servidor está en `bin/server.dart`; este archivo
/// expone lo necesario para construir el manejador, migrar y sembrar datos.
library;

export 'src/app.dart' show buildApiHandler;
export 'src/config.dart';
export 'src/db/database.dart';
export 'src/db/migrator.dart';
export 'src/env_file.dart';
export 'src/errors.dart';
export 'src/mailer.dart';
export 'src/security.dart';
export 'src/seed.dart';
export 'src/services/replacement_service.dart' show FaultHook;
export 'src/services/services.dart';
export 'src/version.dart' show apiVersion;
