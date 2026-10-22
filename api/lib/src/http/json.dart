import 'dart:convert';

import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// Respuesta JSON exitosa con el [body] dado.
Response jsonResponse(Object? body, {int status = 200}) =>
    Response(status, body: jsonEncode(body), headers: _jsonHeaders);

/// Respuesta de error con el formato estándar `{"error": {...}}`.
///
/// Usa el código HTTP asociado a [ApiError.code] salvo que se indique
/// [status].
Response errorResponse(ApiError error, {int? status}) => Response(
  status ?? error.code.httpStatus,
  body: jsonEncode(error.toJson()),
  headers: _jsonHeaders,
);
