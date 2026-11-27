import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'http/json.dart';
import 'http/middleware.dart';
import 'http/rate_limit.dart';
import 'http/web_app.dart';
import 'routes.dart';
import 'services/services.dart';
import 'version.dart';

/// Construye el manejador HTTP completo de la API a partir de [config].
///
/// Sin [services] solo expone `/health` (pruebas sin base de datos).
/// Orden de middlewares: errores → CORS → límite de solicitudes → rutas.
/// Lo que no es una ruta de la API se busca en el build web
/// ([ApiConfig.webDir]), si está configurado.
Handler buildApiHandler(ApiConfig config, {Services? services}) {
  final web = config.webDir.isEmpty ? null : WebApp(config.webDir);
  final router = Router(
    notFoundHandler: (Request request) async {
      if (web != null && !request.url.path.startsWith('v1/')) {
        final response = await web.handle(request);
        if (response != null && response.statusCode != 404) {
          return response;
        }
      }
      return _notFound(request);
    },
  )..get('/health', (Request request) => _health(config));
  if (services != null) addBusinessRoutes(router, config, services);

  final limiter = RateLimiter(
    perMinute: config.rateLimitPerMinute,
    authPerMinute: config.rateLimitAuthPerMinute,
    trustProxy: config.rateLimitTrustProxy,
  );
  return const Pipeline()
      .addMiddleware(handleErrors())
      .addMiddleware(cors(config.allowedOrigins))
      .addMiddleware(limiter.middleware)
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
