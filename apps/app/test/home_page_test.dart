import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monedero/app.dart';
import 'package:monedero/brand/brand.dart';
import 'package:monedero/core/providers.dart';

Widget _appWith(http.Client client) => ProviderScope(
  // Sin reintentos automáticos de Riverpod para que la prueba sea determinista.
  retry: (retryCount, error) => null,
  overrides: [httpClientProvider.overrideWithValue(client)],
  child: const MonederoApp(),
);

void main() {
  testWidgets('muestra la marca y la API conectada', (tester) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'status': 'ok', 'version': '0.1.0', 'demoMode': true}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(_appWith(client));
    await tester.pumpAndSettle();

    expect(find.text(Brand.appName), findsOneWidget);
    expect(find.text('API conectada'), findsOneWidget);
    expect(find.textContaining('modo demo activo'), findsOneWidget);
    expect(find.text('Titular (fase 3)'), findsOneWidget);
  });

  testWidgets('avisa cuando la API no responde', (tester) async {
    final client = MockClient(
      (request) async => throw http.ClientException('sin red'),
    );

    await tester.pumpWidget(_appWith(client));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión con la API'), findsOneWidget);
  });
}
