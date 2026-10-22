import 'dart:io';

import 'src/common.dart';

/// Verificación completa antes de un commit o pull request: formato,
/// análisis estático, guardia de dinero y pruebas.
///
/// Uso:
/// - `dart run tool/check.dart` verifica sin modificar archivos.
/// - `dart run tool/check.dart --fix` aplica `dart format` primero.
Future<void> main(List<String> args) async {
  final fix = args.contains('--fix');
  final failures = <String>[];

  Future<void> step(String name, Future<int> Function() action) async {
    heading(name);
    final code = await action();
    if (code != 0) failures.add(name);
  }

  await step(
    'Formato',
    () => run('dart', [
      'format',
      if (!fix) ...['--output=none', '--set-exit-if-changed'],
      'packages',
      'api',
      'apps/app/lib',
      'apps/app/test',
      'tool',
    ]),
  );
  await step('Análisis estático', () => run('flutter', ['analyze']));
  await step('Guardia de dinero', () async => moneyGuard());
  await step(
    'Pruebas: packages/core',
    () => run('dart', ['test'], workingDirectory: _path('packages/core')),
  );
  await step(
    'Pruebas: api',
    () => run('dart', ['test'], workingDirectory: _path('api')),
  );
  await step(
    'Pruebas: apps/app',
    () => run('flutter', ['test'], workingDirectory: _path('apps/app')),
  );

  stdout.writeln();
  if (failures.isEmpty) exitWith(0, 'Todo en verde.');
  exitWith(1, 'Fallaron: ${failures.join(', ')}');
}

String _path(String relative) =>
    '${repoRoot.path}${Platform.pathSeparator}'
    '${relative.replaceAll('/', Platform.pathSeparator)}';

/// Regla de negocio 1: el dinero es `int` en centavos, nunca `double`.
///
/// Busca en el código Dart líneas que mezclen `double`/`num` con nombres de
/// dinero, y en las migraciones SQL tipos decimales o flotantes. Es una red
/// de seguridad adicional a la revisión de código, no la reemplaza.
int moneyGuard() {
  final dartPattern = RegExp(
    r'\b(double|num)\b[^;]*\b\w*(cents|amount|balance|monto|saldo|price|precio|total)\w*\b',
    caseSensitive: false,
  );
  final sqlPattern = RegExp(
    r'\b(real|double\s+precision|float\d*|numeric|decimal|money)\b',
    caseSensitive: false,
  );
  final findings = <String>[];

  void scan(String relativeDir, RegExp pattern, String extension) {
    final dir = Directory(_path(relativeDir));
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith(extension)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('--')) continue;
        if (pattern.hasMatch(line)) {
          final relative = entity.path.substring(repoRoot.path.length + 1);
          findings.add('$relative:${i + 1}: ${line.trim()}');
        }
      }
    }
  }

  for (final dir in [
    'packages/core/lib',
    'api/lib',
    'api/bin',
    'apps/app/lib',
  ]) {
    scan(dir, dartPattern, '.dart');
  }
  scan('db/migrations', sqlPattern, '.sql');

  if (findings.isEmpty) {
    ok('Sin double/num ni tipos decimales para dinero.');
    return 0;
  }
  fail('Posible dinero sin centavos enteros (regla 1 de AGENTS.md):');
  for (final finding in findings) {
    stderr.writeln('      $finding');
  }
  return 1;
}
