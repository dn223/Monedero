import 'dart:js_interop';

@JS('window.open')
external void _windowOpen(String url, String target);

/// Abre [url] en la pestaña actual del navegador.
void openUrl(String url) => _windowOpen(url, '_self');
