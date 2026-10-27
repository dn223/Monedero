/// Código compartido entre la API y la app de Monedero.
///
/// Contiene únicamente Dart puro (sin Flutter ni `dart:io`) para poder usarse
/// en Android, Web y servidor. Las reglas de negocio de dinero viven aquí para
/// que cliente y servidor validen exactamente igual; la API vuelve a validar
/// todo y la base de datos es la última barrera.
library;

export 'src/api_error.dart';
export 'src/app_module.dart';
export 'src/card_number.dart';
export 'src/card_signature.dart';
export 'src/enums.dart';
export 'src/health.dart';
export 'src/money.dart';
export 'src/qr_payloads.dart';
export 'src/terminal_code.dart';
