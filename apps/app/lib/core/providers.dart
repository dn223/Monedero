import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:monedero_core/monedero_core.dart';

import 'api/api_client.dart';
import 'config/server_settings.dart';

/// Cliente HTTP de bajo nivel. Se reemplaza en pruebas con `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Cliente de la API apuntando al servidor elegido ([serverUrlProvider]).
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: ref.watch(serverUrlProvider),
    httpClient: ref.watch(httpClientProvider),
  ),
);

/// Estado de salud de la API (incluye si el modo demo está activo). Se
/// refresca con `ref.invalidate`.
final apiHealthProvider = FutureProvider<HealthStatus>(
  (ref) => ref.watch(apiClientProvider).health(),
);

/// `true` si la API confirmó que el modo demo está activo. Mientras no se
/// sabe (o sin conexión) es `false`, así nunca se muestra ayuda de demo en
/// un servidor real.
final demoModeProvider = Provider<bool>(
  (ref) => ref.watch(apiHealthProvider).value?.demoMode ?? false,
);
