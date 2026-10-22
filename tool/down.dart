import 'src/common.dart';

/// Detiene los contenedores del entorno local.
///
/// Uso:
/// - `dart run tool/down.dart` conserva los datos de PostgreSQL.
/// - `dart run tool/down.dart --borrar-datos` borra también el volumen de la
///   base (empezar de cero).
Future<void> main(List<String> args) async {
  final wipe = args.contains('--borrar-datos');
  heading(wipe ? 'Deteniendo y borrando datos' : 'Deteniendo contenedores');
  final code = await compose(['down', if (wipe) '--volumes']);
  exitWith(code, code == 0 ? 'Listo.' : 'docker compose down falló.');
}
