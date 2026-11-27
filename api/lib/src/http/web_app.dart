import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// Sirve el build web de Flutter (`flutter build web`) desde [webDir], en el
/// mismo origen que la API: así un solo link (por ejemplo el del túnel de
/// Cloudflare) abre la app y habla con la API sin CORS (ver docs/adr/0011).
///
/// La carpeta se revisa en cada solicitud, porque el build puede generarse
/// después de arrancar la API. Si no existe, devuelve `null` y la API
/// responde su 404 JSON de siempre.
class WebApp {
  /// Crea el servidor de archivos estáticos.
  WebApp(this.webDir);

  /// Carpeta del build web.
  final String webDir;

  Handler? _static;

  /// Archivos que el navegador debe volver a pedir siempre, para que un
  /// build nuevo se vea sin borrar la caché.
  static const _noCache = {
    '',
    'index.html',
    'flutter_bootstrap.js',
    'flutter_service_worker.js',
    'manifest.json',
    'version.json',
  };

  /// Responde [request] con un archivo del build, o `null` si no hay build.
  Future<Response?> handle(Request request) async {
    if (request.method != 'GET' && request.method != 'HEAD') return null;
    if (!File('$webDir/index.html').existsSync()) return null;
    final handler = _static ??= createStaticHandler(
      webDir,
      defaultDocument: 'index.html',
    );
    final response = await handler(request);
    final path = request.url.path;
    return response.change(
      headers: {
        'x-content-type-options': 'nosniff',
        'referrer-policy': 'no-referrer',
        if (_noCache.contains(path)) 'cache-control': 'no-cache',
      },
    );
  }
}
