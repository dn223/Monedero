import 'dart:convert';
import 'dart:io';

import 'package:monedero_api/monedero_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Límite de solicitudes y app web servida por la API (sin base de datos).
void main() {
  Future<Response> get(Handler handler, String path, {String? ip}) async =>
      handler(
        Request(
          'GET',
          Uri.parse('http://api.test$path'),
          headers: {'cf-connecting-ip': ?ip},
        ),
      );

  group('Límite de solicitudes', () {
    test('responde 429 RATE_LIMITED al pasar el límite por minuto', () async {
      final handler = buildApiHandler(
        const ApiConfig(rateLimitPerMinute: 3, rateLimitAuthPerMinute: 1),
      );
      for (var i = 0; i < 3; i++) {
        expect((await get(handler, '/v1/algo')).statusCode, 404);
      }
      final blocked = await get(handler, '/v1/algo');
      expect(blocked.statusCode, 429);
      expect(blocked.headers['retry-after'], isNotNull);
      final body = jsonDecode(await blocked.readAsString()) as Map;
      expect((body['error'] as Map)['code'], 'RATE_LIMITED');

      // /health no cuenta para el límite.
      expect((await get(handler, '/health')).statusCode, 200);
    });

    test('las rutas de autenticación tienen su propio límite', () async {
      final handler = buildApiHandler(
        const ApiConfig(rateLimitPerMinute: 100, rateLimitAuthPerMinute: 1),
      );
      expect((await get(handler, '/v1/auth/x')).statusCode, 404);
      expect((await get(handler, '/v1/auth/x')).statusCode, 429);
      expect((await get(handler, '/v1/otra')).statusCode, 404);
    });

    test('detrás del túnel separa clientes por CF-Connecting-IP', () async {
      final handler = buildApiHandler(
        const ApiConfig(
          rateLimitPerMinute: 1,
          rateLimitAuthPerMinute: 1,
          rateLimitTrustProxy: true,
        ),
      );
      expect((await get(handler, '/v1/a', ip: '1.1.1.1')).statusCode, 404);
      expect((await get(handler, '/v1/a', ip: '2.2.2.2')).statusCode, 404);
      expect((await get(handler, '/v1/a', ip: '1.1.1.1')).statusCode, 429);
    });
  });

  group('App web en el mismo origen', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('monedero_web');
      File('${dir.path}/index.html').writeAsStringSync('<html>app</html>');
      File('${dir.path}/main.dart.js').writeAsStringSync('// js');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('sirve index.html sin caché y los archivos del build', () async {
      final handler = buildApiHandler(ApiConfig(webDir: dir.path));
      final index = await get(handler, '/');
      expect(index.statusCode, 200);
      expect(await index.readAsString(), contains('app'));
      expect(index.headers['cache-control'], 'no-cache');
      expect((await get(handler, '/main.dart.js')).statusCode, 200);
    });

    test('las rutas de la API siguen respondiendo JSON', () async {
      final handler = buildApiHandler(ApiConfig(webDir: dir.path));
      final missing = await get(handler, '/v1/nada');
      expect(missing.statusCode, 404);
      expect(missing.headers['content-type'], contains('application/json'));
      expect((await get(handler, '/health')).statusCode, 200);
    });

    test('sin build web, / responde el 404 JSON de la API', () async {
      final handler = buildApiHandler(
        ApiConfig(webDir: '${dir.path}/no-existe'),
      );
      expect((await get(handler, '/')).statusCode, 404);
    });
  });
}
