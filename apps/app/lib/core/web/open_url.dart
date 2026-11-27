/// Abre una dirección en la pestaña actual (solo hace algo en la web).
///
/// En la web, el navegador descarga el archivo si el servidor lo marca como
/// adjunto (`content-disposition: attachment`), sin salir de la app.
library;

export 'open_url_stub.dart' if (dart.library.js_interop) 'open_url_web.dart';
