import 'src/common.dart';

/// Aplica las migraciones pendientes de `db/migrations`.
///
/// Uso: `dart run tool/migrate.dart`
Future<void> main(List<String> args) async {
  heading('Migraciones');
  final code = await run('dart', ['run', 'api/bin/migrate.dart']);
  exitWith(code, code == 0 ? null : 'Las migraciones fallaron.');
}
