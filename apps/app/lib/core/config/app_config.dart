import 'package:flutter/foundation.dart';

/// Configuración de la app que se fija al compilar con `--dart-define`.
///
/// Ejemplo para un teléfono en la misma Wi-Fi que la laptop:
///
/// ```text
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
/// ```
///
/// La URL también se puede cambiar dentro de la app (pantalla "Servidor"),
/// sin recompilar; ese valor guardado tiene prioridad (ver
/// `server_settings.dart`).
abstract final class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// URL base de la API cuando el usuario no ha elegido otra.
  ///
  /// - Con `API_BASE_URL` definido al compilar, usa ese valor.
  /// - En la web publicada (build release servido por la API, también por el
  ///   link del túnel), usa el mismo origen de la página.
  /// - En la web de desarrollo (`flutter run -d chrome`), `localhost:8080`.
  /// - En Android, `10.0.2.2:8080` (así ve el emulador a la laptop).
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) {
      return kReleaseMode ? Uri.base.origin : 'http://localhost:8080';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
