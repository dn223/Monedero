import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'http/json.dart';
import 'http/middleware.dart';
import 'routes.dart';
import 'services/services.dart';
import 'version.dart';

/// Construye el manejador HTTP completo de la API a partir de [config].
///
/// Sin [services] solo expone `/health` (pruebas sin base de datos).
/// Orden de middlewares: errores → CORS → rutas.
Handler buildApiHandler(ApiConfig config, {Services? services}) {
  final router = Router(notFoundHandler: _notFound)
    ..get('/health', (Request request) => _health(config));
  if (services != null) addBusinessRoutes(router, config, services);

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
