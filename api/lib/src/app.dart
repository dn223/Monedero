import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'http/json.dart';
import 'http/middleware.dart';
import 'version.dart';

/// Construye el manejador HTTP completo de la API a partir de [config].
///
/// Orden de middlewares: errores → CORS → rutas. Las pruebas usan este
/// manejador directamente, sin abrir un puerto.
Handler buildApiHandler(ApiConfig config) {
  final router = Router(notFoundHandler: _notFound)
    ..get('/health', (Request request) => _health(config));

  return const Pipeline()
      .addMiddleware(handleErrors())
      .addMiddleware(cors(config.allowedOrigins))
      .addHandler(router.call);
}

Response _health(ApiConfig config) => jsonResponse(
  HealthStatus(
    status: 'ok',
    version: apiVersion,
    demoMode: config.demoMode,
  ).toJson(),
);

Response _notFound(Request request) => errorResponse(
  ApiError(
    ApiErrorCode.notFound,
    'Ruta no encontrada: ${request.method} /${request.url.path}',
  ),
);
