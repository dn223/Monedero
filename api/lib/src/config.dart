/// Configuración de la API leída de variables de entorno.
///
/// Todas las variables están documentadas en `.env.example`. Ningún secreto
/// tiene valor por defecto en el código: si falta uno obligatorio la API no
/// arranca.
class ApiConfig {
  /// Crea una configuración explícita (útil en pruebas).
  const ApiConfig({
    this.port = 8080,
    this.allowedOrigins = const [],
    this.demoMode = false,
  });

  /// Construye la configuración desde un mapa de entorno, normalmente
  /// `Platform.environment`.
  ///
  /// Lanza [StateError] si un valor tiene un formato inválido.
  factory ApiConfig.fromEnvironment(Map<String, String> env) {
    final portText = env['API_PORT'] ?? '8080';
    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      throw StateError('API_PORT inválido: "$portText".');
    }
    return ApiConfig(
      port: port,
      allowedOrigins: _parseList(env['CORS_ALLOWED_ORIGINS']),
      demoMode: _parseBool(env['DEMO_MODE'], name: 'DEMO_MODE'),
    );
  }

  /// Puerto TCP donde escucha la API.
  final int port;

  /// Orígenes web autorizados por CORS (por ejemplo `http://localhost:5000`).
  ///
  /// Las apps Android no envían `Origin`, así que CORS solo afecta a la web.
  final List<String> allowedOrigins;

  /// Activa la lista de tarjetas de demostración y el reinicio de la demo.
  /// Desactivado por defecto; nunca debe activarse en producción.
  final bool demoMode;

  static List<String> _parseList(String? value) => (value ?? '')
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  static bool _parseBool(String? value, {required String name}) {
    switch ((value ?? 'false').trim().toLowerCase()) {
      case 'true' || '1' || 'yes' || 'si' || 'sí':
        return true;
      case 'false' || '0' || 'no' || '':
        return false;
      default:
        throw StateError('$name debe ser true o false, no "$value".');
    }
  }
}
