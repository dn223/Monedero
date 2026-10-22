import 'dart:convert';

import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';

import '../errors.dart';
import '../security.dart';

/// Lee el cuerpo JSON como objeto o lanza `VALIDATION_FAILED`.
Future<Map<String, Object?>> readJson(Request request) async {
  try {
    final body = jsonDecode(await request.readAsString());
    if (body is Map<String, Object?>) return body;
  } on FormatException {
    // Cae al error de abajo.
  }
  throw const ApiException(
    ApiErrorCode.validationFailed,
    'El cuerpo debe ser un objeto JSON.',
  );
}

/// Campo de texto obligatorio.
String requireString(Map<String, Object?> body, String field) {
  final value = body[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw ApiException(
    ApiErrorCode.validationFailed,
    'Falta el campo "$field".',
    details: {'field': field},
  );
}

/// Monto entero en centavos. Rechaza decimales: el dinero nunca es `double`.
int requireCents(Map<String, Object?> body, String field) {
  final value = body[field];
  if (value is int) return value;
  throw ApiException(
    ApiErrorCode.validationFailed,
    '"$field" debe ser un entero en centavos (por ejemplo 735 = \$7.35).',
    details: {'field': field},
  );
}

/// Credenciales de la tarjeta en `body['card']`.
CardCredentials requireCard(Map<String, Object?> body) {
  final card = body['card'];
  if (card is Map<String, Object?> &&
      card['number'] is String &&
      card['uid'] is String &&
      card['signature'] is String) {
    return CardCredentials.fromJson(card);
  }
  throw const ApiException(
    ApiErrorCode.validationFailed,
    'Falta "card" con number, uid y signature.',
  );
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Encabezado `Idempotency-Key` obligatorio con formato UUID (regla 5).
String requireIdempotencyKey(Request request) {
  final key = request.headers['idempotency-key']?.trim();
  if (key != null && _uuid.hasMatch(key)) return key.toLowerCase();
  throw const ApiException(
    ApiErrorCode.idempotencyKeyRequired,
    'Falta el encabezado Idempotency-Key (UUID generado por el cliente).',
  );
}

/// Valida el JWT y que su rol esté en [roles] (roles validados en la API).
Principal requireRole(Request request, TokenService tokens, Set<Role> roles) {
  final header = request.headers['authorization'] ?? '';
  final principal = header.startsWith('Bearer ')
      ? tokens.verify(header.substring(7))
      : null;
  if (principal == null) {
    throw const ApiException(
      ApiErrorCode.unauthorized,
      'Inicia sesión de nuevo (token ausente o vencido).',
    );
  }
  if (!roles.contains(principal.role)) {
    throw const ApiException(
      ApiErrorCode.forbidden,
      'Tu rol no permite esta operación.',
    );
  }
  return principal;
}
