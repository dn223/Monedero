import 'package:flutter/foundation.dart';

/// Configuración de la app que se fija al compilar con `--dart-define`.
///
/// Ejemplo para un teléfono en la misma Wi-Fi que la laptop:
///
/// ```text
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
/// ```
abstract final class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// URL base de la API.
  ///
  /// Si no se define `API_BASE_URL`, usa `http://10.0.2.2:8080` en Android
  /// (el emulador ve así a la laptop) y `http://localhost:8080` en la web.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
