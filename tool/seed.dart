import 'src/common.dart';

/// Migra y siembra los datos de demostración (no duplica si ya existen).
///
/// Uso: `dart run tool/seed.dart`
Future<void> main(List<String> args) async {
  heading('Datos de demostración');
  final code = await run('dart', ['run', 'api/bin/migrate.dart', '--seed']);
  exitWith(code, code == 0 ? null : 'El sembrado falló.');
}
