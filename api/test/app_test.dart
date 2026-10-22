import 'dart:convert';

import 'package:monedero_api/monedero_api.dart';
import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const _webOrigin = 'http://localhost:5000';

Future<Response> _send(
  Handler handler,
  String method,
  String path, {
  Map<String, String> headers = const {},
}) async => handler(
  Request(method, Uri.parse('http://api.test$path'), headers: headers),
);

void main() {
  final handler = buildApiHandler(
    const ApiConfig(allowedOrigins: [_webOrigin], demoMode: true),
  );

  test('GET /health responde ok con versión y modo demo', () async {
    final response = await _send(handler, 'GET', '/health');
    expect(response.statusCode, 200);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, Object?>;
    final health = HealthStatus.fromJson(body);
    expect(health.isOk, isTrue);
    expect(health.version, apiVersion);
    expect(health.demoMode, isTrue);
  });

  test('una ruta inexistente devuelve 404 con el formato de error', () async {
    final response = await _send(handler, 'GET', '/no-existe');
    expect(response.statusCode, 404);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, Object?>;
    expect(ApiError.fromJson(body).code, ApiErrorCode.notFound);
  });

  group('CORS', () {
    test('agrega encabezados solo para el origen autorizado', () async {
      final allowed = await _send(
        handler,
        'GET',
        '/health',
        headers: {'origin': _webOrigin},
      );
      expect(allowed.headers['access-control-allow-origin'], _webOrigin);

      final other = await _send(
        handler,
        'GET',
        '/health',
        headers: {'origin': 'http://malicioso.example'},
      );
      expect(other.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test('preflight de un origen no autorizado es rechazado', () async {
      final response = await _send(
        handler,
        'OPTIONS',
        '/health',
        headers: {'origin': 'http://malicioso.example'},
      );
      expect(response.statusCode, 403);
    });

    test('preflight autorizado permite Idempotency-Key', () async {
      final response = await _send(
        handler,
        'OPTIONS',
        '/health',
        headers: {'origin': _webOrigin},
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['access-control-allow-headers'],
        contains('idempotency-key'),
      );
    });
  });

  group('ApiConfig.fromEnvironment', () {
    test('usa valores seguros por defecto', () {
      final config = ApiConfig.fromEnvironment({});
      expect(config.port, 8080);
      expect(config.demoMode, isFalse);
      expect(config.allowedOrigins, isEmpty);
    });

    test('lee la lista de orígenes y el modo demo', () {
      final config = ApiConfig.fromEnvironment({
        'API_PORT': '9090',
        'CORS_ALLOWED_ORIGINS': 'http://localhost:5000, http://127.0.0.1:5000',
        'DEMO_MODE': 'true',
      });
      expect(config.port, 9090);
      expect(config.allowedOrigins, [
        'http://localhost:5000',
        'http://127.0.0.1:5000',
      ]);
      expect(config.demoMode, isTrue);
    });

    test('rechaza valores inválidos', () {
      expect(
        () => ApiConfig.fromEnvironment({'API_PORT': 'abc'}),
        throwsStateError,
      );
      expect(
        () => ApiConfig.fromEnvironment({'DEMO_MODE': 'quizas'}),
        throwsStateError,
      );
    });
  });
}
