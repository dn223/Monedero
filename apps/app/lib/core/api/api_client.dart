import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:monedero_core/monedero_core.dart';

/// Error al hablar con la API: de red, de formato o devuelto por el servidor.
class ApiException implements Exception {
  /// Crea la excepción con un [message] para el usuario y, si la API
  /// respondió con un error estándar, su [apiError].
  const ApiException(this.message, {this.apiError});

  /// Mensaje en español para mostrar al usuario.
  final String message;

  /// Error estándar devuelto por la API, si lo hubo. Es `null` cuando no
  /// hubo respuesta (sin red, servidor apagado, tiempo agotado).
  final ApiError? apiError;

  /// Código del error de la API, si lo hubo.
  ApiErrorCode? get code => apiError?.code;

  /// `true` si no hubo respuesta del servidor: la operación pudo o no haber
  /// llegado, así que se reintenta con la **misma** `Idempotency-Key`.
  bool get isNetwork => apiError == null;

  @override
  String toString() => 'ApiException: $message';
}

/// Cliente HTTP de la API de Monedero.
///
/// Toda operación que cambia saldo requiere conexión: este cliente nunca
/// encola operaciones para enviarlas después (regla 12).
class ApiClient {
  /// Crea el cliente para [baseUrl] usando [httpClient].
  ApiClient({required this.baseUrl, required http.Client httpClient})
    : _http = httpClient;

  /// URL base, por ejemplo `http://localhost:8080`.
  final String baseUrl;

  final http.Client _http;

  /// Consulta `GET /health`.
  Future<HealthStatus> health() async =>
      HealthStatus.fromJson(await get('/health'));

  /// `GET` que devuelve el cuerpo JSON.
  Future<Map<String, Object?>> get(
    String path, {
    String? token,
    String? terminal,
  }) => send('GET', path, token: token, terminal: terminal);

  /// `POST` con cuerpo JSON.
  ///
  /// Para operaciones que cambian saldo, pasa [idempotencyKey] (regla 5):
  /// genérala con [newIdempotencyKey] **una vez por operación** y reutilízala
  /// si hay que reintentar tras un error de red.
  Future<Map<String, Object?>> post(
    String path, {
    Map<String, Object?> body = const {},
    String? token,
    String? terminal,
    String? idempotencyKey,
  }) => send(
    'POST',
    path,
    body: body,
    token: token,
    terminal: terminal,
    key: idempotencyKey,
  );

  /// `PUT` con cuerpo JSON.
  Future<Map<String, Object?>> put(
    String path, {
    Map<String, Object?> body = const {},
    String? token,
  }) => send('PUT', path, body: body, token: token);

  /// `DELETE`.
  Future<Map<String, Object?>> delete(String path, {String? token}) =>
      send('DELETE', path, token: token);

  /// Envía la solicitud y convierte la respuesta en JSON o en
  /// [ApiException].
  Future<Map<String, Object?>> send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
    String? terminal,
    String? key,
  }) async {
    final http.Response response;
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers.addAll({
          'content-type': 'application/json',
          'authorization': ?(token == null ? null : 'Bearer $token'),
          'x-terminal-token': ?terminal,
          'idempotency-key': ?key,
        });
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 15)),
      );
    } on Exception {
      throw ApiException('No se pudo conectar con el servidor ($baseUrl).');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        'El servidor respondió algo inesperado (HTTP ${response.statusCode}).',
        apiError: ApiError(
          ApiErrorCode.internal,
          'HTTP ${response.statusCode}',
        ),
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const ApiException(
        'Respuesta inesperada del servidor.',
        apiError: ApiError(ApiErrorCode.internal, 'Respuesta inesperada.'),
      );
    }
    if (response.statusCode >= 400) {
      final error = ApiError.fromJson(decoded);
      throw ApiException(error.message, apiError: error);
    }
    return decoded;
  }

  /// UUID v4 para `Idempotency-Key`.
  static String newIdempotencyKey() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
