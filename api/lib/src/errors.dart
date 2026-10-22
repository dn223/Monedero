import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

/// Error de negocio esperado; el middleware lo convierte en respuesta JSON.
class ApiException implements Exception {
  /// Crea el error con su [code], [message] y [details] opcionales.
  const ApiException(this.code, this.message, {this.details = const {}});

  /// Código estable.
  final ApiErrorCode code;

  /// Mensaje en español para personas.
  final String message;

  /// Detalles sin datos sensibles.
  final Map<String, Object?> details;

  /// Cuerpo estándar del error.
  ApiError get error => ApiError(code, message, details: details);

  @override
  String toString() => 'ApiException(${code.wireName}: $message)';
}

/// `true` si [error] es una violación de unicidad de PostgreSQL.
bool isUniqueViolation(Object error) =>
    error is ServerException && error.code == '23505';
