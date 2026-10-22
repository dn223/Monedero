import 'src/common.dart';

/// Borra la base, la migra de nuevo y siembra la demo.
/// Solo funciona con `DEMO_MODE=true`.
///
/// Uso: `dart run tool/reset_demo.dart`
Future<void> main(List<String> args) async {
  heading('Reiniciando la demo');
  final code = await run('dart', ['run', 'api/bin/migrate.dart', '--reset']);
  exitWith(code, code == 0 ? 'Demo reiniciada.' : 'El reinicio falló.');
}
