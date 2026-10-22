import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:monedero_core/monedero_core.dart';

import 'api/api_client.dart';
import 'config/app_config.dart';

/// Cliente HTTP de bajo nivel. Se reemplaza en pruebas con `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Cliente de la API configurado con [AppConfig.apiBaseUrl].
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    httpClient: ref.watch(httpClientProvider),
  ),
);

/// Estado de salud de la API. Se refresca con `ref.invalidate`.
final apiHealthProvider = FutureProvider<HealthStatus>(
  (ref) => ref.watch(apiClientProvider).health(),
);
