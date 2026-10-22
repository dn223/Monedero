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

  /// Error estándar devuelto por la API, si lo hubo.
  final ApiError? apiError;

  @override
  String toString() => 'ApiException: $message';
}

/// Cliente HTTP de la API de Monedero.
///
/// Toda operación que cambia saldo requiere conexión: este cliente nunca
/// encola operaciones para enviarlas después.
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
  }) => _send('GET', path, token: token, terminal: terminal);

  /// `POST` con cuerpo JSON. Si [idempotent] es `true`, agrega una
  /// `Idempotency-Key` nueva (regla 5).
  Future<Map<String, Object?>> post(
    String path, {
    Map<String, Object?> body = const {},
    String? token,
    bool idempotent = false,
  }) => _send(
    'POST',
    path,
    body: body,
    token: token,
    key: idempotent ? newIdempotencyKey() : null,
  );

  Future<Map<String, Object?>> _send(
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
        await _http.send(request).timeout(const Duration(seconds: 8)),
      );
    } on Exception {
      throw ApiException('No se pudo conectar con la API en $baseUrl.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException('Respuesta inválida (HTTP ${response.statusCode}).');
    }
    if (decoded is! Map<String, Object?>) {
      throw const ApiException('Respuesta inesperada de la API.');
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
