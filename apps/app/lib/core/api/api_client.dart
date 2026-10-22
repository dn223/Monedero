import 'dart:convert';

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
  Future<HealthStatus> health() async {
    final json = await _getJson('/health');
    return HealthStatus.fromJson(json);
  }

  Future<Map<String, Object?>> _getJson(String path) async {
    final http.Response response;
    try {
      response = await _http
          .get(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 8));
    } on Exception {
      throw ApiException('No se pudo conectar con la API en $baseUrl.');
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException('Respuesta inválida (HTTP ${response.statusCode}).');
    }
    if (body is! Map<String, Object?>) {
      throw const ApiException('Respuesta inesperada de la API.');
    }
    if (response.statusCode >= 400) {
      final error = ApiError.fromJson(body);
      throw ApiException(error.message, apiError: error);
    }
    return body;
  }
}
