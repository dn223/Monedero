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

  /// Falta el encabezado `Idempotency-Key` o no es un UUID.
  idempotencyKeyRequired('IDEMPOTENCY_KEY_REQUIRED', 400),

  /// La misma `Idempotency-Key` llegó con otro contenido.
  idempotencyKeyReused('IDEMPOTENCY_KEY_REUSED', 422),

  /// Monto inválido (≤ 0 o recarga que no es múltiplo de $5).
  invalidAmount('INVALID_AMOUNT', 422),

  /// El débito supera el saldo.
  insufficientFunds('INSUFFICIENT_FUNDS', 422),

  /// La tarjeta no está ACTIVE.
  cardNotActive('CARD_NOT_ACTIVE', 409),

  /// Número, UID o firma no coinciden.
  invalidCardSignature('INVALID_CARD_SIGNATURE', 422),

  /// Débito sobre el límite sin PIN.
  pinRequired('PIN_REQUIRED', 422),

  /// PIN incorrecto.
  invalidPin('INVALID_PIN', 422),

  /// Código de correo incorrecto o vencido.
  invalidVerificationCode('INVALID_VERIFICATION_CODE', 422),

  /// Correo o contraseña incorrectos, o correo sin verificar.
  invalidCredentials('INVALID_CREDENTIALS', 401),

  /// Terminal desconocido o revocado.
  terminalNotAuthorized('TERMINAL_NOT_AUTHORIZED', 403),

  /// Endpoint de demo con el modo demo apagado.
  demoModeDisabled('DEMO_MODE_DISABLED', 403),

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
