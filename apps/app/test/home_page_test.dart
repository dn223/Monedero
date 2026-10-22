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
    expect(find.text('Titular'), findsOneWidget);
  });

  testWidgets('los tres roles abren su vista', (tester) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'status': 'ok', 'version': '0.2.0', 'demoMode': true}),
        200,
      ),
    );
    tester.view
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (button, expected) in [
      ('Titular', 'Saldo disponible'),
      ('Caja', 'Escanear QR'),
      ('Administración', 'Emitir tarjeta'),
    ]) {
      await tester.pumpWidget(_appWith(client));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsWidgets, reason: button);
      await tester.tap(find.byTooltip('Inicio'));
      await tester.pumpAndSettle();
    }
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
