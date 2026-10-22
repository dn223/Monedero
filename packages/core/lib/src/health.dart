import 'package:meta/meta.dart';

/// Respuesta de `GET /health`: indica si la API está viva.
@immutable
class HealthStatus {
  /// Crea un estado de salud.
  const HealthStatus({
    required this.status,
    required this.version,
    required this.demoMode,
  });

  /// Lee el estado desde el JSON de la API.
  factory HealthStatus.fromJson(Map<String, Object?> json) => HealthStatus(
    status: json['status']! as String,
    version: json['version']! as String,
    demoMode: json['demoMode']! as bool,
  );

  /// `ok` cuando la API responde correctamente.
  final String status;

  /// Versión de la API desplegada.
  final String version;

  /// `true` si el modo demo está activo (tarjetas de demostración y reinicio).
  final bool demoMode;

  /// Indica si la API está operativa.
  bool get isOk => status == 'ok';

  /// Serializa el estado a JSON.
  Map<String, Object?> toJson() => {
    'status': status,
    'version': version,
    'demoMode': demoMode,
  };
}
