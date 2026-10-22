import 'package:meta/meta.dart';

/// Códigos de error estables que devuelve la API.
///
/// El cliente decide qué mensaje mostrar a partir de [ApiErrorCode], nunca
/// a partir del texto libre de [ApiError.message]. Los valores se serializan
/// en `SCREAMING_SNAKE_CASE` (ver [wireName]).
enum ApiErrorCode {
  /// El cuerpo o los parámetros de la solicitud no son válidos.
  validationFailed('VALIDATION_FAILED', 400),

  /// Falta autenticación o el token expiró.
  unauthorized('UNAUTHORIZED', 401),

  /// El usuario está autenticado pero su rol no permite la operación.
  forbidden('FORBIDDEN', 403),

  /// El recurso solicitado no existe.
  notFound('NOT_FOUND', 404),

  /// La operación entra en conflicto con el estado actual del recurso.
  conflict('CONFLICT', 409),

  /// Se superó el límite de intentos (PIN, códigos de verificación).
  tooManyAttempts('TOO_MANY_ATTEMPTS', 429),

  /// Error inesperado del servidor. Nunca expone detalles internos.
  internal('INTERNAL_ERROR', 500);

  const ApiErrorCode(this.wireName, this.httpStatus);

  /// Nombre con el que viaja el código en el JSON.
  final String wireName;

  /// Código HTTP asociado por defecto.
  final int httpStatus;

  /// Busca el código por su [wireName]; devuelve [internal] si no se conoce,
  /// para que un cliente antiguo no falle ante códigos nuevos.
  static ApiErrorCode fromWire(String value) => ApiErrorCode.values.firstWhere(
    (code) => code.wireName == value,
    orElse: () => ApiErrorCode.internal,
  );
}

/// Cuerpo estándar de error de la API.
///
/// Formato en JSON:
///
/// ```json
/// {"error": {"code": "VALIDATION_FAILED", "message": "…", "details": {}}}
/// ```
@immutable
class ApiError {
  /// Crea un error con su [code], un [message] legible en español y
  /// [details] opcionales (por ejemplo, el campo inválido).
  const ApiError(this.code, this.message, {this.details = const {}});

  /// Reconstruye un error a partir del JSON devuelto por la API.
  factory ApiError.fromJson(Map<String, Object?> json) {
    final error = json['error'];
    if (error is! Map<String, Object?>) {
      throw const FormatException('Respuesta de error sin el objeto "error".');
    }
    final details = error['details'];
    return ApiError(
      ApiErrorCode.fromWire(error['code']! as String),
      error['message']! as String,
      details: details is Map<String, Object?> ? details : const {},
    );
  }

  /// Código estable del error.
  final ApiErrorCode code;

  /// Mensaje para personas, en español. No debe contener datos sensibles.
  final String message;

  /// Información adicional estructurada (sin datos sensibles).
  final Map<String, Object?> details;

  /// Serializa el error con el formato estándar de la API.
  Map<String, Object?> toJson() => {
    'error': {
      'code': code.wireName,
      'message': message,
      if (details.isNotEmpty) 'details': details,
    },
  };

  @override
  String toString() => 'ApiError(${code.wireName}: $message)';
}
