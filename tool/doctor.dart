import 'dart:io';

import 'src/common.dart';
import 'src/env.dart';

/// Revisa que el equipo tenga todo lo necesario para trabajar.
///
/// Uso: `dart run tool/doctor.dart`
Future<void> main(List<String> args) async {
  var problems = 0;

  Future<void> check(
    String name,
    String executable,
    List<String> arguments, {
    String? hint,
  }) async {
    final output = await capture(executable, arguments);
    if (output == null) {
      problems++;
      fail('$name: no disponible.${hint == null ? '' : ' $hint'}');
    } else {
      ok('$name: ${output.split('\n').first}');
    }
  }

  heading('Sistema');
  ok('${Platform.operatingSystem} ${Platform.operatingSystemVersion}');

  heading('Herramientas');
  await check('Git', 'git', ['--version'], hint: 'Ver docs/setup.md.');
  await check('Flutter', 'flutter', ['--version'], hint: 'Ver docs/setup.md.');
  await check('Dart', 'dart', ['--version']);
  await check('Docker', 'docker', [
    '--version',
  ], hint: 'Instala Docker Desktop (docs/setup.md).');
  await check('Docker Compose', 'docker', ['compose', 'version']);
  await check('Motor de Docker', 'docker', [
    'info',
    '--format',
    '{{.ServerVersion}}',
  ], hint: 'Abre Docker Desktop y espera "Engine running".');

  heading('Configuración');
  if (envFile.existsSync()) {
    ok('.env presente.');
  } else {
    warn('.env no existe todavía; `dart run tool/up.dart` lo crea.');
  }

  heading('Puertos');
  final env = readEnv();
  for (final entry in {
    'API': env['API_PORT'] ?? '8080',
    'PostgreSQL': env['POSTGRES_PORT'] ?? '5432',
    'Mailpit': env['MAILPIT_UI_PORT'] ?? '8025',
  }.entries) {
    final port = int.parse(entry.value);
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await socket.close();
      ok('${entry.key}: puerto $port libre.');
    } on SocketException {
      warn(
        '${entry.key}: puerto $port en uso (normal si el entorno ya está '
        'levantado; si no, cámbialo en .env).',
      );
    }
  }

  stdout.writeln();
  exitWith(
    problems == 0 ? 0 : 1,
    problems == 0
        ? 'Todo listo.'
        : '$problems problema(s). Revisa docs/setup.md.',
  );
}
