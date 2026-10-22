import 'dart:io';

import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';

import 'json.dart';

/// Encabezados que el navegador puede enviar a la API.
const corsAllowedHeaders = [
  'authorization',
  'content-type',
  'idempotency-key',
  'x-terminal-token',
];

/// Middleware CORS que solo autoriza los orígenes de [allowedOrigins].
///
/// Si el origen no está en la lista no se agregan encabezados CORS y el
/// navegador bloquea la respuesta. Las solicitudes sin `Origin` (apps
/// Android, pruebas, curl) pasan sin cambios.
Middleware cors(List<String> allowedOrigins) {
  final allowed = allowedOrigins.toSet();
  return (inner) => (request) async {
    final origin = request.headers['origin'];
    final isAllowed = origin != null && allowed.contains(origin);

    if (request.method == 'OPTIONS' && origin != null) {
      if (!isAllowed) return Response.forbidden(null);
      return Response.ok(null, headers: _corsHeaders(origin));
    }

    final response = await inner(request);
    return isAllowed
        ? response.change(headers: _corsHeaders(origin))
        : response;
  };
}

Map<String, String> _corsHeaders(String origin) => {
  'access-control-allow-origin': origin,
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': corsAllowedHeaders.join(', '),
  'access-control-max-age': '600',
  'vary': 'Origin',
};

/// Convierte cualquier excepción no controlada en `500 INTERNAL_ERROR` sin
/// filtrar detalles internos al cliente; el detalle se escribe en stderr.
Middleware handleErrors() =>
    (inner) => (request) async {
      try {
        return await inner(request);
      } on HijackException {
        rethrow;
      } on Object catch (error, stackTrace) {
        stderr.writeln('ERROR ${request.method} ${request.requestedUri.path}');
        stderr.writeln('$error\n$stackTrace');
        return errorResponse(
          const ApiError(ApiErrorCode.internal, 'Error interno del servidor.'),
        );
      }
    };
