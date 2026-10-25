import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monedero/app.dart';
import 'package:monedero/core/providers.dart';
import 'package:monedero/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Respuesta simulada de la API: `(estado HTTP, cuerpo JSON)`.
typedef Reply = (int, Object);

/// API falsa: responde según `"MÉTODO /ruta"` y anota cada llamada.
class FakeApi {
  /// Crea la API con sus [routes]; lo no previsto responde 404.
  FakeApi(this.routes);

  /// Respuestas por `"GET /v1/me/cards"`; la ruta no incluye la consulta.
  final Map<String, Reply Function(http.Request request)> routes;

  /// Llamadas recibidas, en orden (`"POST /v1/auth/refresh"`).
  final List<String> calls = [];

  /// Cliente HTTP que usa la app en la prueba.
  late final http.Client client = MockClient((request) async {
    final key = '${request.method} ${request.url.path}';
    calls.add(key);
    final route = routes[key];
    final (status, body) = route == null
        ? (
            404,
            {
              'error': {'code': 'NOT_FOUND', 'message': 'No existe $key'},
            },
          )
        : route(request);
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// `/health` con modo demo.
Reply health(http.Request _) =>
    (200, {'status': 'ok', 'version': '0.4.0', 'demoMode': true});

/// Sesión como la devuelve la API al iniciar sesión.
Map<String, Object?> sessionJson(
  String role,
  String name, {
  String id = 'u1',
}) => {
  'accessToken': 'jwt-$role',
  'tokenType': 'Bearer',
  'expiresInSeconds': 900,
  'refreshToken': 'refresh-$role',
  'refreshExpiresInSeconds': 604800,
  'role': role,
  'userId': id,
  'fullName': name,
};

/// Monta la app con la [api] falsa y el almacenamiento [stored].
Future<void> pumpApp(
  WidgetTester tester,
  FakeApi api, {
  Map<String, Object> stored = const {},
  Size size = const Size(1400, 1000),
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final preferences = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // Sin reintentos automáticos de Riverpod: pruebas deterministas.
      retry: (retryCount, error) => null,
      overrides: [
        httpClientProvider.overrideWithValue(api.client),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const MonederoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Desmonta la app para cancelar los temporizadores de actualización.
Future<void> unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());
