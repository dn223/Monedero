import 'dart:io';

import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';

import 'json.dart';

/// Límite de solicitudes por cliente en ventanas fijas de un minuto.
///
/// Solo cuenta las rutas de negocio (`/v1/...`): `/health` y la app web no
/// se limitan. Las rutas de inicio de sesión, registro, renovación y sesiones
/// demo tienen un límite más estricto ([authPerMinute]) para frenar ataques
/// de fuerza bruta. Los contadores viven en memoria: con varias réplicas de
/// la API habría que moverlos a un almacén compartido (ver docs/adr/0010).
class RateLimiter {
  /// Crea el limitador. Un límite en `0` lo desactiva.
  RateLimiter({
    required this.perMinute,
    required this.authPerMinute,
    this.trustProxy = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Solicitudes por minuto y cliente a `/v1/...`.
  final int perMinute;

  /// Solicitudes por minuto y cliente a las rutas de autenticación.
  final int authPerMinute;

  /// Identifica al cliente por `CF-Connecting-IP` / `X-Forwarded-For`.
  final bool trustProxy;

  final DateTime Function() _clock;
  final Map<String, ({int window, int count})> _hits = {};

  /// Middleware de shelf que aplica el límite.
  Middleware get middleware =>
      (inner) => (request) {
        final path = request.url.path;
        if (request.method == 'OPTIONS' || !path.startsWith('v1/')) {
          return inner(request);
        }
        final strict = isAuthPath(path);
        final limit = strict ? authPerMinute : perMinute;
        if (limit <= 0) return inner(request);

        final now = _clock();
        final window = now.millisecondsSinceEpoch ~/ 60000;
        final key = '${strict ? 'auth' : 'api'}|${clientOf(request)}';
        final previous = _hits[key];
        final count = previous != null && previous.window == window
            ? previous.count + 1
            : 1;
        _hits[key] = (window: window, count: count);
        if (_hits.length > 10000) {
          _hits.removeWhere((_, v) => v.window != window);
        }
        if (count <= limit) return inner(request);

        final retryAfter = 60 - (now.millisecondsSinceEpoch ~/ 1000) % 60;
        return errorResponse(
          ApiError(
            ApiErrorCode.rateLimited,
            'Demasiadas solicitudes. Espera $retryAfter segundos e intenta '
            'de nuevo.',
            details: {'retryAfterSeconds': retryAfter},
          ),
        ).change(headers: {'retry-after': '$retryAfter'});
      };

  /// `true` si [path] (sin barra inicial) es de autenticación o de sesión
  /// demo, que llevan el límite estricto.
  static bool isAuthPath(String path) =>
      path.startsWith('v1/auth/') ||
      (path.startsWith('v1/demo/') && path.endsWith('-session'));

  /// Dirección del cliente que hace la solicitud.
  String clientOf(Request request) {
    if (trustProxy) {
      final cf = request.headers['cf-connecting-ip'];
      if (cf != null && cf.isNotEmpty) return cf.trim();
      final forwarded = request.headers['x-forwarded-for'];
      if (forwarded != null && forwarded.isNotEmpty) {
        return forwarded.split(',').first.trim();
      }
    }
    final info = request.context['shelf.io.connection_info'];
    return info is HttpConnectionInfo ? info.remoteAddress.address : 'local';
  }
}
