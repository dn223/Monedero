import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:monedero/brand/brand.dart';
import 'package:monedero_core/monedero_core.dart';

import 'support.dart';

const _number = '9990142405712970';

final _card = <String, Object?>{
  'cardId': 'c1',
  'cardholderId': 'u1',
  'cardholderName': 'Ana López',
  'number': _number,
  'numberMasked': '•••• 2970',
  'status': 'ACTIVE',
  'balanceCents': 5000,
  'credentials': {
    'number': _number,
    'uid': '04A1B2C3D4E5F6',
    'signature': '00112233445566778899AABBCCDDEEFF',
  },
};

final _transactions = {
  'items': [
    {
      'transactionId': 't1',
      'type': 'TOP_UP',
      'amountCents': 5000,
      'balanceAfterCents': 5000,
      'createdAt': '2026-10-24T15:00:00Z',
    },
  ],
};

Map<String, Object?> _storedSession(String role, String name, String jwt) => {
  'accessToken': jwt,
  'refreshToken': 'refresh-$role',
  'accessExpiresAt': DateTime.now()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'role': role,
  'userId': 'u1',
  'fullName': name,
};

Reply _unauthorized() => (
  401,
  {
    'error': {'code': 'UNAUTHORIZED', 'message': 'Token vencido.'},
  },
);

void main() {
  testWidgets('inicio: marca, servidor conectado y los tres roles', (
    tester,
  ) async {
    await pumpApp(tester, FakeApi({'GET /health': health}));

    expect(find.text(Brand.appName), findsWidgets);
    expect(
      find.textContaining('Servidor conectado', findRichText: true),
      findsOneWidget,
    );
    // Sin la palabra "demo" en pantalla.
    expect(find.textContaining('demo', findRichText: true), findsNothing);
    for (final role in ['Soy titular', 'Caja', 'Administración']) {
      expect(find.text(role), findsOneWidget);
    }
  });

  testWidgets('avisa cuando el servidor no responde', (tester) async {
    final api = FakeApi({})
      ..routes['GET /health'] = (_) => throw http.ClientException('sin red');
    await pumpApp(tester, api);

    expect(
      find.textContaining('Sin conexión con el servidor', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('titular: inicia sesión y ve saldo y movimientos', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /health': health,
      'POST /v1/auth/cardholders/login': (r) {
        final body = jsonDecode(r.body) as Map;
        expect(body, {'email': 'ana@correo.com', 'password': 'Clave-segura-1'});
        return (200, sessionJson('CARDHOLDER', 'Ana López'));
      },
      'GET /v1/me/cards': (_) => (
        200,
        {
          'items': [_card],
        },
      ),
      'GET /v1/me/cards/c1/transactions': (_) => (200, _transactions),
      'GET /v1/demo/inbox': (_) => (200, {'items': <Object>[]}),
    });
    await pumpApp(tester, api, size: const Size(420, 1600));

    await tester.tap(find.text('Soy titular'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Entrar como'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'ana@correo.com');
    await tester.enterText(find.byType(TextField).at(1), 'Clave-segura-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text(r'$50.00'), findsWidgets);
    expect(find.text('Recarga en caja'), findsOneWidget);
    expect(find.text('Pagar en caja'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('sesión vencida: renueva una vez con el token de renovación', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /health': health,
      'GET /v1/me/cards': (r) => r.headers['authorization'] == 'Bearer viejo'
          ? _unauthorized()
          : (
              200,
              {
                'items': [_card],
              },
            ),
      'POST /v1/auth/refresh': (r) {
        expect(
          (jsonDecode(r.body) as Map)['refreshToken'],
          'refresh-CARDHOLDER',
        );
        return (200, sessionJson('CARDHOLDER', 'Ana López'));
      },
      'GET /v1/me/cards/c1/transactions': (_) => (200, _transactions),
      'GET /v1/demo/inbox': (_) => (200, {'items': <Object>[]}),
    });
    await pumpApp(
      tester,
      api,
      size: const Size(420, 1600),
      stored: {
        'session.CARDHOLDER': jsonEncode(
          _storedSession('CARDHOLDER', 'Ana López', 'viejo'),
        ),
      },
    );

    await tester.tap(find.text('Soy titular'));
    await tester.pumpAndSettle();

    expect(find.text(r'$50.00'), findsWidgets);
    expect(api.calls.where((c) => c == 'POST /v1/auth/refresh'), hasLength(1));
    await unmount(tester);
  });

  testWidgets('caja: abre con su código, elige una tarjeta de la lista, cobra '
      'y muestra el comprobante', (tester) async {
    String? key;
    final api = FakeApi({
      'GET /health': health,
      'POST /v1/auth/terminals/login': (r) {
        expect((jsonDecode(r.body) as Map)['code'], 'K7M4Q2XPHT9W');
        return (
          200,
          {
            ...sessionJson('CASHIER', 'Caja 1'),
            'terminalToken': 'K7M4Q2XPHT9W',
            'terminalId': 't1',
            'name': 'Caja 1',
            'payCode': '482913',
          },
        );
      },
      'GET /v1/cards/terminal-activity': (r) {
        expect(r.headers['x-terminal-token'], 'K7M4Q2XPHT9W');
        return (200, {'items': <Object>[]});
      },
      'GET /v1/demo/cards': (_) => (
        200,
        {
          'items': [_card],
        },
      ),
      'POST /v1/cards/read': (r) {
        expect(r.headers['x-terminal-token'], isNotNull);
        return (
          200,
          {
            'numberMasked': '•••• 2970',
            'cardholderName': 'Ana López',
            'status': 'ACTIVE',
            'balanceCents': 5000,
            'pinRequiredAboveCents': 2500,
          },
        );
      },
      'POST /v1/cards/debits': (r) {
        key = r.headers['idempotency-key'];
        expect((jsonDecode(r.body) as Map)['amountCents'], 735);
        return (
          201,
          {
            'transactionId': 'abcdef12-0000-4000-8000-000000000000',
            'type': 'DEBIT',
            'amountCents': 735,
            'balanceAfterCents': 4265,
            'cardNumberMasked': '•••• 2970',
            'createdAt': '2026-10-25T10:42:00Z',
          },
        );
      },
    });
    await pumpApp(tester, api);

    await tester.tap(find.text('Caja'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'k7m4-q2xp-ht9w');
    await tester.tap(find.text('Abrir caja').last);
    await tester.pumpAndSettle();
    expect(find.text('482 913'), findsOneWidget);

    await tester.tap(find.text('Elegir tarjeta de la lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana López').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '7.35');
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'Cobrar $7.35'));
    await tester.pumpAndSettle();

    expect(find.text('Cobro aprobado'), findsOneWidget);
    expect(find.text(r'$42.65'), findsOneWidget);
    expect(key, matches(RegExp(r'^[0-9a-f-]{36}$')));
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('administración: tablero con saldo y conciliación en cero', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /health': health,
      'GET /v1/admin/stats': (_) => (
        200,
        {
          'cardsByStatus': {
            'PENDING': 1,
            'ACTIVE': 2,
            'BLOCKED': 0,
            'REPLACED': 0,
          },
          'totalBalanceCents': 6500,
          'cardholders': 3,
          'activeTerminals': 1,
          'transactions': 4,
          'daily': [
            for (var i = 0; i < 14; i++)
              {
                'day': '2026-10-${(12 + i).toString().padLeft(2, '0')}',
                'topUpCents': i == 13 ? 6500 : 0,
                'debitCents': i == 13 ? 735 : 0,
                'operations': i == 13 ? 3 : 0,
              },
          ],
        },
      ),
      'GET /v1/admin/reconciliation': (_) => (
        200,
        {
          'cards': 3,
          'cardsWithDifference': 0,
          'totalBalanceCents': 6500,
          'totalDifferenceCents': 0,
          'items': <Object>[],
        },
      ),
    });
    await pumpApp(
      tester,
      api,
      stored: {
        'session.ADMIN': jsonEncode(
          _storedSession('ADMIN', 'Administración Demo', 'jwt-ADMIN'),
        ),
      },
    );

    await tester.tap(find.text('Administración'));
    await tester.pumpAndSettle();

    expect(find.text('Saldo en circulación'), findsOneWidget);
    expect(find.text(r'$65.00'), findsOneWidget);
    expect(find.text('Todo cuadra'), findsOneWidget);
    expect(find.text('Recargas'), findsOneWidget);
  });

  testWidgets('módulos: el titular ve solo lo activo y usa el asistente', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /health': health,
      'GET /v1/modules': (_) => (200, _modules({'holder_payments'})),
      'GET /v1/me/cards': (_) => (
        200,
        {
          'items': [_card],
        },
      ),
      'GET /v1/me/cards/c1/transactions': (_) => (200, _transactions),
      'GET /v1/demo/inbox': (_) => (200, {'items': <Object>[]}),
      'POST /v1/assistant/messages': (r) {
        expect((jsonDecode(r.body) as Map)['message'], '¿Cuál es mi saldo?');
        return (
          200,
          {
            'intent': 'balance',
            'reply': r'Tu saldo es $50.00.',
            'suggestions': ['¿Cómo recargo?'],
          },
        );
      },
    });
    await pumpApp(
      tester,
      api,
      size: const Size(420, 1600),
      stored: {
        'session.CARDHOLDER': jsonEncode(
          _storedSession('CARDHOLDER', 'Ana López', 'jwt-CARDHOLDER'),
        ),
      },
    );
    await tester.tap(find.text('Soy titular'));
    await tester.pumpAndSettle();

    // Pago con código apagado: no hay botón; el QR sigue.
    expect(find.text('Pagar en caja'), findsNothing);
    expect(find.text('Mostrar mi código QR'), findsOneWidget);

    await tester.tap(find.text('Asistente'));
    await tester.pumpAndSettle();
    expect(find.text('Asistente virtual'), findsOneWidget);
    await tester.tap(find.text('¿Cuál es mi saldo?'));
    await tester.pumpAndSettle();
    expect(find.text(r'Tu saldo es $50.00.'), findsOneWidget);
    expect(find.text('¿Cómo recargo?'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('módulos: administración apaga el asistente', (tester) async {
    var off = <String>{};
    Map<String, Object?>? sent;
    final api = FakeApi({
      'GET /health': health,
      'GET /v1/admin/stats': (_) => (500, {}),
      'GET /v1/admin/reconciliation': (_) => (500, {}),
      'GET /v1/modules': (_) => (200, _modules(off)),
      'PUT /v1/admin/modules/assistant': (r) {
        sent = jsonDecode(r.body) as Map<String, Object?>;
        off = {'assistant'};
        return (200, (_modules(off)['items']! as List).first as Object);
      },
    });
    await pumpApp(
      tester,
      api,
      stored: {
        'session.ADMIN': jsonEncode(
          _storedSession('ADMIN', 'Administración Demo', 'jwt-ADMIN'),
        ),
      },
    );
    await tester.tap(find.text('Administración'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Módulos'));
    await tester.pumpAndSettle();

    expect(find.text('5 de 5 activos'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Asistente virtual'));
    await tester.pumpAndSettle();

    expect(sent, {'enabled': false});
    expect(find.text('4 de 5 activos'), findsOneWidget);
    expect(find.text('Asistente virtual: desactivado.'), findsOneWidget);
  });
}

/// Lista de módulos como la devuelve `GET /v1/modules`, con [off] apagados.
Map<String, Object?> _modules(Set<String> off) => {
  'items': [
    for (final m in AppModule.values)
      {
        'key': m.key,
        'name': m.label,
        'description': m.description,
        'audience': 'CARDHOLDER',
        'enabled': !off.contains(m.key),
        'updatedAt': '2026-10-27T15:00:00Z',
        'updatedByName': null,
      },
  ],
};
