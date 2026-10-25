import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:qr/qr.dart';

import 'src/common.dart';
import 'src/env.dart';

/// Levanta todo y abre un **link público temporal** para la exposición.
///
/// 1. Compila la app web (`flutter build web --release`).
/// 2. Levanta PostgreSQL, Mailpit, la API (que sirve la web) y el túnel de
///    Cloudflare (perfil `compartir` de docker-compose; gratis, sin cuenta).
/// 3. Migra y siembra los datos de demostración.
/// 4. Imprime el link `https://….trycloudflare.com` con un QR para el celular.
///
/// Uso:
/// - `dart run tool/share.dart`               todo lo anterior
/// - `dart run tool/share.dart --sin-compilar` reutiliza el build web
///
/// Para detener todo: `dart run tool/down.dart`. Guía: docs/exposicion.md.
Future<void> main(List<String> args) async {
  final skipBuild = args.contains('--sin-compilar');

  heading('Configuración');
  if (ensureEnvFile()) ok('Se creó .env con secretos aleatorios.');
  final added = syncEnvFile();
  if (added.isNotEmpty) ok('Variables nuevas en .env: ${added.join(', ')}');
  final env = readEnv();
  if ((env['DEMO_MODE'] ?? 'false').toLowerCase() != 'true') {
    warn(
      'DEMO_MODE no es true: quien entre por el link no verá las cuentas ni '
      'los códigos de demostración.',
    );
  }
  final apiPort = env['API_PORT'] ?? '8080';

  final webIndex = File(
    '${repoRoot.path}/apps/app/build/web/index.html'.replaceAll(
      '/',
      Platform.pathSeparator,
    ),
  );
  if (skipBuild && webIndex.existsSync()) {
    heading('App web');
    ok('Se reutiliza apps/app/build/web.');
  } else {
    heading('Compilando la app web (1 a 3 minutos)');
    final built = await run(
      'flutter',
      ['build', 'web', '--release'],
      workingDirectory:
          '${repoRoot.path}${Platform.pathSeparator}apps'
          '${Platform.pathSeparator}app',
    );
    if (built != 0) exitWith(built, 'flutter build web falló.');
  }

  heading('Levantando contenedores y el túnel');
  final up = await compose([
    '--profile',
    'compartir',
    'up',
    '-d',
    '--build',
    '--wait',
  ]);
  if (up != 0) {
    exitWith(
      up,
      '¿Está abierto Docker Desktop? Prueba dart run tool/doctor.dart.',
    );
  }

  heading('Migraciones y datos de demostración');
  final migrated = await run('dart', ['run', 'api/bin/migrate.dart', '--seed']);
  if (migrated != 0) exitWith(migrated, 'Las migraciones fallaron.');

  heading('Esperando la API');
  if (!await _waitOk(Uri.parse('http://localhost:$apiPort/health'), 30)) {
    exitWith(1, 'La API no respondió. Revisa: docker compose logs api');
  }
  ok('API lista en http://localhost:$apiPort');

  heading('Esperando el link público');
  final url = await _tunnelUrl(const Duration(seconds: 90));
  if (url == null) {
    exitWith(
      1,
      'El túnel no entregó un link. Revisa: docker compose logs tunnel '
      '(hace falta Internet).',
    );
  }
  // El nombre del túnel tarda hasta un par de minutos en resolver.
  final reachable = await _waitOk(Uri.parse('$url/health'), 120);
  reachable
      ? ok('El link responde.')
      : warn(
          'El link aún no responde desde esta PC; espera un minuto y ábrelo.',
        );

  stdout
    ..writeln()
    ..writeln('  Link para el inge (web y celular):')
    ..writeln()
    ..writeln('      $url')
    ..writeln()
    ..writeln(_qrText(url))
    ..writeln('  Cuentas demo (también se muestran en la app):')
    ..writeln('    Titular ....... ana@demo.local / Titular1234  (PIN 1234)')
    ..writeln('    Caja .......... cajero@monedero.local / Cajero1234')
    ..writeln('    Administración  admin@monedero.local / Admin1234')
    ..writeln()
    ..writeln(
      '  APK: en el inicio toca el ícono de servidor y escanea este QR.',
    )
    ..writeln('  Detener todo:  dart run tool/down.dart')
    ..writeln('  El link cambia cada vez que se recrea el túnel.');
}

/// Lee los registros del contenedor del túnel hasta encontrar su URL.
Future<String?> _tunnelUrl(Duration timeout) async {
  final pattern = RegExp(r'https://[a-z0-9-]+\.trycloudflare\.com');
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final logs = await Process.run(
      'docker',
      ['compose', 'logs', '--no-color', 'tunnel'],
      workingDirectory: repoRoot.path,
      runInShell: Platform.isWindows,
    );
    final matches = pattern.allMatches('${logs.stdout}${logs.stderr}');
    if (matches.isNotEmpty) return matches.last.group(0);
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  return null;
}

/// `true` si [url] responde 200 antes de [seconds] segundos.
Future<bool> _waitOk(Uri url, int seconds) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  try {
    for (var i = 0; i < seconds; i++) {
      try {
        final response = await (await client.getUrl(url)).close();
        await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) return true;
      } on IOException {
        // Aún no responde.
      } on TimeoutException {
        // Aún no responde.
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
  } finally {
    client.close(force: true);
  }
}

/// QR de [data] dibujado con medios bloques (dos filas por línea).
///
/// Los módulos claros se dibujan con bloques, pensando en consolas de fondo
/// oscuro (el caso común en Windows Terminal y PowerShell).
String _qrText(String data) {
  final qr = QrImage(
    QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L),
  );
  const quiet = 2;
  final size = qr.moduleCount + quiet * 2;
  bool light(int row, int col) {
    final r = row - quiet;
    final c = col - quiet;
    if (r < 0 || c < 0 || r >= qr.moduleCount || c >= qr.moduleCount) {
      return true;
    }
    return !qr.isDark(r, c);
  }

  final out = StringBuffer();
  for (var row = 0; row < size; row += 2) {
    out.write('      ');
    for (var col = 0; col < size; col++) {
      final top = light(row, col);
      final bottom = row + 1 < size ? light(row + 1, col) : true;
      out.write(
        top && bottom
            ? '█'
            : top
            ? '▀'
            : bottom
            ? '▄'
            : ' ',
      );
    }
    out.writeln();
  }
  return out.toString();
}
