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
  // El perfil `compartir` incluye el túnel de tool/share.dart; sin él,
  // `down` no lo detendría.
  final code = await compose([
    '--profile',
    'compartir',
    'down',
    if (wipe) '--volumes',
  ]);
  exitWith(code, code == 0 ? 'Listo.' : 'docker compose down falló.');
}
