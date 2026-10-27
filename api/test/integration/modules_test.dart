@Tags(['integration'])
library;

import 'package:monedero_api/monedero_api.dart';
import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// Módulos de la aplicación y asistente virtual contra PostgreSQL real.
/// Usa su propia base.
void main() {
  late Harness h;
  late CashDesk desk;
  late String holderToken;

  setUpAll(() async {
    h = await Harness.start(database: 'monedero_test_modulos');
    desk = await h.cashDesk();
    final (_, login) = await h.call(
      'POST',
      '/v1/auth/cardholders/login',
      body: {'email': 'ana@demo.local', 'password': DemoUsers.holderPassword},
    );
    holderToken = login['accessToken']! as String;
  });
  tearDownAll(() => h.close());

  Map<String, Object?> error(Map<String, Object?> body) =>
      body['error']! as Map<String, Object?>;

  Future<void> toggle(String key, {required bool enabled}) async {
    final (status, body) = await h.call(
      'PUT',
      '/v1/admin/modules/$key',
      body: {'enabled': enabled},
      token: desk.admin,
    );
    expect(status, 200, reason: '$body');
  }

  test('la lista de módulos es pública y empieza todo encendido', () async {
    final (status, body) = await h.call('GET', '/v1/modules');
    expect(status, 200);
    final items = (body['items']! as List).cast<Map<String, Object?>>();
    expect(items.map((m) => m['key']), [
      'assistant',
      'self_registration',
      'holder_payments',
      'card_qr',
      'pin_change',
    ]);
    expect(items.every((m) => m['enabled'] == true), isTrue);
    expect(items.first['name'], 'Asistente virtual');
  });

  test('solo administración cambia un módulo', () async {
    for (final token in [desk.cashier, holderToken]) {
      final (status, body) = await h.call(
        'PUT',
        '/v1/admin/modules/assistant',
        body: {'enabled': false},
        token: token,
      );
      expect(status, 403);
      expect(error(body)['code'], 'FORBIDDEN');
    }
    final (s1, _) = await h.call(
      'PUT',
      '/v1/admin/modules/no_existe',
      body: {'enabled': false},
      token: desk.admin,
    );
    expect(s1, 404);
    final (s2, b2) = await h.call(
      'PUT',
      '/v1/admin/modules/assistant',
      body: {'enabled': 'no'},
      token: desk.admin,
    );
    expect(s2, 400);
    expect(error(b2)['code'], 'VALIDATION_FAILED');
  });

  test('el asistente responde con el saldo real del titular', () async {
    final (status, body) = await h.call(
      'POST',
      '/v1/assistant/messages',
      body: {'message': '¿Cuál es mi saldo?'},
      token: holderToken,
    );
    expect(status, 200);
    expect(body['intent'], 'balance');
    final (_, cards) = await h.call('GET', '/v1/me/cards', token: holderToken);
    final card = (cards['items']! as List).first as Map<String, Object?>;
    final balance = card['balanceCents']! as int;
    expect(body['reply'], contains(Money.format(balance)));
    expect(body['suggestions'], isNotEmpty);

    // El cajero no usa el asistente del titular.
    final (s2, _) = await h.call(
      'POST',
      '/v1/assistant/messages',
      body: {'message': 'hola'},
      token: desk.cashier,
    );
    expect(s2, 403);
  });

  test('apagar el asistente lo bloquea en la API y queda registrado', () async {
    await toggle('assistant', enabled: false);
    final (status, body) = await h.call(
      'POST',
      '/v1/assistant/messages',
      body: {'message': 'hola'},
      token: holderToken,
    );
    expect(status, 403);
    expect(error(body)['code'], 'MODULE_DISABLED');
    expect(
      (error(body)['details']! as Map<String, Object?>)['module'],
      'assistant',
    );

    final (_, list) = await h.call('GET', '/v1/modules');
    final assistant = (list['items']! as List).first as Map<String, Object?>;
    expect(assistant['enabled'], isFalse);
    expect(assistant['updatedByName'], 'Administración Demo');

    final log = await query(
      h.owner,
      "SELECT enabled FROM module_changes WHERE module_key = 'assistant' "
      'ORDER BY changed_at',
    );
    expect(log.map((r) => r['enabled']), [false]);

    await toggle('assistant', enabled: true);
    final (again, _) = await h.call(
      'POST',
      '/v1/assistant/messages',
      body: {'message': 'hola'},
      token: holderToken,
    );
    expect(again, 200);
  });

  test('cada módulo apagado cierra su ruta', () async {
    await toggle('self_registration', enabled: false);
    await toggle('pin_change', enabled: false);
    await toggle('holder_payments', enabled: false);
    await toggle('card_qr', enabled: false);
    try {
      final (s1, b1) = await h.call(
        'POST',
        '/v1/auth/cardholders/register',
        body: {
          'fullName': 'Nadie Nuevo',
          'email': 'nadie@demo.local',
          'password': 'Clave-segura-123',
          'pin': '4321',
        },
      );
      expect((s1, error(b1)['code']), (403, 'MODULE_DISABLED'));

      final (s2, b2) = await h.call(
        'PUT',
        '/v1/me/pin',
        body: {'currentPin': '1234', 'newPin': '4321'},
        token: holderToken,
      );
      expect((s2, error(b2)['code']), (403, 'MODULE_DISABLED'));

      final (s3, b3) = await h.call(
        'POST',
        '/v1/me/payments',
        body: {'terminalCode': '000000', 'amountCents': 100},
        token: holderToken,
        key: '9b2f2f9e-8a4e-4c55-9d0e-1f3a1c2b3d4e',
      );
      expect((s3, error(b3)['code']), (403, 'MODULE_DISABLED'));

      // Sin QR, la tarjeta no trae las credenciales que lo forman…
      final (_, cards) = await h.call(
        'GET',
        '/v1/me/cards',
        token: holderToken,
      );
      final card = (cards['items']! as List).first as Map<String, Object?>;
      expect(card.containsKey('credentials'), isFalse);
      expect(card['balanceCents'], isA<int>());
    } finally {
      for (final key in [
        'self_registration',
        'pin_change',
        'holder_payments',
        'card_qr',
      ]) {
        await toggle(key, enabled: true);
      }
    }

    // …y con el módulo encendido vuelven.
    final (_, cards) = await h.call('GET', '/v1/me/cards', token: holderToken);
    final card = (cards['items']! as List).first as Map<String, Object?>;
    expect(card.containsKey('credentials'), isTrue);
  });

  test('la caja cobra y recarga aunque los módulos estén apagados', () async {
    final (cardId, creds, _) = await desk.newActiveCard('modulos@demo.local');
    for (final m in AppModule.values) {
      await toggle(m.key, enabled: false);
    }
    try {
      final (s1, _) = await h.call(
        'POST',
        '/v1/cards/top-ups',
        body: {'card': creds, 'amountCents': 1000},
        token: desk.cashier,
        terminal: desk.terminal,
        key: '0f8a8b44-6a7c-4c3e-9c0d-3e2b1a4c5d6e',
      );
      expect(s1, 201);
      expect((await h.cardState(cardId)).balance, 1000);
    } finally {
      for (final m in AppModule.values) {
        await toggle(m.key, enabled: true);
      }
    }
  });
}
