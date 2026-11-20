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

  /// Ruta pública del APK de Android que se descarga desde la web.
  static const apkRoute = 'descargas/monedero.apk';

  /// APK release de 64 bits (`flutter build apk --release --split-per-abi`).
  /// Vive junto al build web, en la misma carpeta `build` de la app.
  String get apkPath =>
      '${Directory(webDir).parent.path}/app/outputs/flutter-apk/'
      'app-arm64-v8a-release.apk';

  /// Archivos que el navegador debe volver a pedir siempre, para que un
  /// build nuevo se vea sin borrar la caché.
  static const _noCache = {
    '',
    'index.html',
    'flutter_bootstrap.js',
    'main.dart.js',
    'flutter_service_worker.js',
    'manifest.json',
    'version.json',
  };

  /// Responde [request] con un archivo del build, o `null` si no hay build.
  Future<Response?> handle(Request request) async {
    if (request.method != 'GET' && request.method != 'HEAD') return null;
    if (request.url.path == apkRoute) return _apk(request);
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

  /// Entrega el APK con su tipo MIME y como descarga; 404 si no se compiló.
  Response? _apk(Request request) {
    final file = File(apkPath);
    if (!file.existsSync()) return null;
    return Response.ok(
      request.method == 'HEAD' ? null : file.openRead(),
      headers: {
        'content-type': 'application/vnd.android.package-archive',
        'content-length': '${file.lengthSync()}',
        'content-disposition': 'attachment; filename="monedero.apk"',
        'cache-control': 'no-cache',
        'x-content-type-options': 'nosniff',
      },
    );
  }
}
