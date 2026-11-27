import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage.dart';
import 'app_config.dart';

/// URL del servidor (API) que usa la app.
///
/// Se puede cambiar sin recompilar desde la pantalla "Servidor": se pega o
/// se escanea el link que imprime `dart run tool/share.dart`. El valor se
/// guarda en el dispositivo; si no hay ninguno, se usa
/// [AppConfig.apiBaseUrl].
class ServerUrlNotifier extends Notifier<String> {
  static const _key = 'server.url';

  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_key) ??
      AppConfig.apiBaseUrl;

  /// `true` si el usuario eligió una URL distinta de la predeterminada.
  bool get isCustom =>
      ref.read(sharedPreferencesProvider).getString(_key) != null;

  /// Guarda [url] (ya normalizada) como servidor.
  Future<void> set(String url) async {
    await ref.read(sharedPreferencesProvider).setString(_key, url);
    state = url;
  }

  /// Vuelve a la URL predeterminada.
  Future<void> reset() async {
    await ref.read(sharedPreferencesProvider).remove(_key);
    state = AppConfig.apiBaseUrl;
  }
}

/// URL del servidor vigente.
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(
  ServerUrlNotifier.new,
);
