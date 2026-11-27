@Tags(['integration'])
library;

import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

/// Observaciones del ingeniero (ADR 0016) contra PostgreSQL real: anulación
/// por contramovimiento, tarjeta nueva con traslado de saldo y perfil.
/// Usa su propia base.
void main() {
  late Harness h;
  late CashDesk desk;

  setUpAll(() async {
    h = await Harness.start(database: 'monedero_test_observaciones');
    desk = await h.cashDesk();
  });
  tearDownAll(() => h.close());

  String code(Map<String, Object?> body) =>
      (body['error']! as Map<String, Object?>)['code']! as String;

  Future<List<Map<String, Object?>>> movements(String cardId) async {
    final (_, body) = await h.call(
      'GET',
      '/v1/admin/cards/$cardId/transactions',
      token: desk.admin,
    );
    return (body['items']! as List).cast<Map<String, Object?>>();
  }

  Future<(int, Map<String, Object?>)> reverse(
    String transactionId, {
    String reason = 'Cobro duplicado por error',
    String? key,
    String? token,
  }) => h.call(
    'POST',
    '/v1/admin/transactions/$transactionId/reversals',
    body: {'reason': reason},
    token: token ?? desk.admin,
    key: key ?? const Uuid().v4(),
  );

  group('Anulación', () {
    test('anular un cobro devuelve el dinero sin tocar el original', () async {
      final (cardId, card, _) = await desk.newActiveCard('anula1@test.local');
      await desk.op('top-ups', card, 2000);
      final (_, debit) = await desk.op('debits', card, 735);
      final debitId = debit['transactionId']! as String;

      final key = const Uuid().v4();
      final (status, body) = await reverse(debitId, key: key);
      expect(status, 201, reason: '$body');
      expect(body['type'], 'REVERSAL_IN');
      expect(body['balanceAfterCents'], 2000);

      // Repetir con la misma clave devuelve lo mismo y no aplica nada.
      final (again, replay) = await reverse(debitId, key: key);
      expect(again, 201);
      expect(replay['reversalTransactionId'], body['reversalTransactionId']);

      // Otra clave: el movimiento ya fue anulado.
      final (twice, err) = await reverse(debitId);
      expect(twice, 409);
      expect(code(err), 'TRANSACTION_ALREADY_REVERSED');

      final state = await h.cardState(cardId);
      expect(state.balance, 2000);
      expect(state.difference, 0);
      expect(state.txCount, 3);

      final items = await movements(cardId);
      final original = items.firstWhere((m) => m['transactionId'] == debitId);
      expect(original['amountCents'], 735, reason: 'el original no cambia');
      expect(original['reversed'], isTrue);
      expect(original['reversible'], isFalse);
      expect(h.mailer.sent.last.subject, contains('anulado'));
    });

    test('anular una recarga nunca deja saldo negativo', () async {
      final (cardId, card, _) = await desk.newActiveCard('anula2@test.local');
      final (_, topUp) = await desk.op('top-ups', card, 2000);
      await desk.op('debits', card, 1500);

      final (status, err) = await reverse(topUp['transactionId']! as String);
      expect(status, 422);
      expect(code(err), 'INSUFFICIENT_FUNDS');
      expect((await h.cardState(cardId)).balance, 500);

      final (_, small) = await desk.op('top-ups', card, 500);
      final (ok, body) = await reverse(small['transactionId']! as String);
      expect(ok, 201);
      expect(body['type'], 'REVERSAL_OUT');
      expect((await h.cardState(cardId)).difference, 0);
    });

    test('no se anulan contramovimientos ni sin motivo ni sin rol', () async {
      final (cardId, card, holderToken) = await desk.newActiveCard(
        'anula3@test.local',
      );
      final (_, debit) = await desk.op('top-ups', card, 1000);
      final (_, reversal) = await reverse(debit['transactionId']! as String);

      final (s1, e1) = await reverse(
        reversal['reversalTransactionId']! as String,
      );
      expect(s1, 409);
      expect(code(e1), 'TRANSACTION_NOT_REVERSIBLE');

      final (_, other) = await desk.op('top-ups', card, 500);
      final otherId = other['transactionId']! as String;
      final (s2, e2) = await reverse(otherId, reason: 'no');
      expect(s2, 400);
      expect(code(e2), 'VALIDATION_FAILED');

      for (final token in [desk.cashier, holderToken]) {
        final (s3, _) = await reverse(otherId, token: token);
        expect(s3, 403);
      }
      expect((await h.cardState(cardId)).difference, 0);
    });

    test('con el módulo apagado la API la rechaza', () async {
      final (_, card, _) = await desk.newActiveCard('anula4@test.local');
      final (_, topUp) = await desk.op('top-ups', card, 500);
      await h.call(
        'PUT',
        '/v1/admin/modules/transaction_reversal',
        body: {'enabled': false},
        token: desk.admin,
      );
      final (status, err) = await reverse(topUp['transactionId']! as String);
      await h.call(
        'PUT',
        '/v1/admin/modules/transaction_reversal',
        body: {'enabled': true},
        token: desk.admin,
      );
      expect(status, 403);
      expect(code(err), 'MODULE_DISABLED');
    });
  });

  group('Tarjeta nueva con traslado de saldo', () {
    test('el titular pide tarjeta nueva y se traslada todo el saldo', () async {
      const email = 'nueva@test.local';
      final (cardId, card, token) = await desk.newActiveCard(email);
      await desk.op('top-ups', card, 2000);
      await desk.op('debits', card, 735);

      final (sent, _) = await h.call(
        'POST',
        '/v1/me/cards/$cardId/card-requests',
        token: token,
      );
      expect(sent, 202);

      final (bad, err) = await h.call(
        'POST',
        '/v1/me/cards/$cardId/card-requests/confirm',
        body: {'code': '000000'},
        token: token,
        key: const Uuid().v4(),
      );
      expect(bad, 422);
      expect(code(err), 'INVALID_VERIFICATION_CODE');

      final key = const Uuid().v4();
      final (status, body) = await h.call(
        'POST',
        '/v1/me/cards/$cardId/card-requests/confirm',
        body: {'code': h.mailer.lastCodeFor(email)},
        token: token,
        key: key,
      );
      expect(status, 201, reason: '$body');
      expect(body['transferredCents'], 1265);
      final newCard = body['newCard']! as Map<String, Object?>;
      expect(newCard['status'], 'ACTIVE');
      expect(newCard['balanceCents'], 1265);
      expect((body['oldCard']! as Map)['status'], 'REPLACED');

      // Reintento con la misma clave: mismo resultado, sin pedir código.
      final (again, replay) = await h.call(
        'POST',
        '/v1/me/cards/$cardId/card-requests/confirm',
        body: {'code': 'ya-usado'},
        token: token,
        key: key,
      );
      expect(again, 201);
      expect((replay['newCard']! as Map)['cardId'], newCard['cardId']);

      expect((await h.cardState(cardId)).difference, 0);
      expect((await h.cardState(newCard['cardId']! as String)).difference, 0);

      // La tarjeta anterior ya no opera.
      final (_, rejected) = await desk.op('debits', card, 100);
      expect(code(rejected), 'CARD_NOT_ACTIVE');
    });

    test('una tarjeta bloqueada no se cambia por esta vía', () async {
      const email = 'nueva2@test.local';
      final (cardId, _, token) = await desk.newActiveCard(email);
      await h.call('POST', '/v1/me/cards/$cardId/loss-reports', token: token);
      await h.call(
        'POST',
        '/v1/me/cards/$cardId/loss-reports/confirm',
        body: {'code': h.mailer.lastCodeFor(email)},
        token: token,
      );
      final (status, err) = await h.call(
        'POST',
        '/v1/me/cards/$cardId/card-requests',
        token: token,
      );
      expect(status, 409);
      expect(code(err), 'CARD_NOT_ACTIVE');
    });
  });

  group('Perfil del titular', () {
    test('cambia nombre, contraseña y correo', () async {
      const email = 'perfil@test.local';
      final (_, _, token) = await desk.newActiveCard(email);

      final (s1, p1) = await h.call(
        'PUT',
        '/v1/me/profile',
        body: {'fullName': 'Nombre Nuevo'},
        token: token,
      );
      expect(s1, 200);
      expect(p1['fullName'], 'Nombre Nuevo');

      final (s2, e2) = await h.call(
        'PUT',
        '/v1/me/password',
        body: {'currentPassword': 'mala-clave', 'newPassword': 'otra-clave-1'},
        token: token,
      );
      expect(s2, 400, reason: 'contraseña actual mala: 400, no 401');
      expect(code(e2), 'VALIDATION_FAILED');
      final (s3, _) = await h.call(
        'PUT',
        '/v1/me/password',
        body: {
          'currentPassword': 'clave-segura',
          'newPassword': 'otra-clave-1',
        },
        token: token,
      );
      expect(s3, 200);

      const newEmail = 'perfil-nuevo@test.local';
      final (s4, _) = await h.call(
        'POST',
        '/v1/me/email-change',
        body: {'newEmail': newEmail, 'password': 'otra-clave-1'},
        token: token,
      );
      expect(s4, 202);
      expect(h.mailer.sent.last.to, newEmail, reason: 'el código va al nuevo');
      final (s5, p5) = await h.call(
        'POST',
        '/v1/me/email-change/confirm',
        body: {'code': h.mailer.lastCodeFor(newEmail)},
        token: token,
      );
      expect(s5, 200);
      expect(p5['email'], newEmail);

      // Entra con el correo y la contraseña nuevos.
      final (login, _) = await h.call(
        'POST',
        '/v1/auth/cardholders/login',
        body: {'email': newEmail, 'password': 'otra-clave-1'},
      );
      expect(login, 200);
    });

    test('no permite tomar el correo de otra cuenta', () async {
      final (_, _, token) = await desk.newActiveCard('perfil2@test.local');
      final (status, err) = await h.call(
        'POST',
        '/v1/me/email-change',
        body: {'newEmail': 'anula1@test.local', 'password': 'clave-segura'},
        token: token,
      );
      expect(status, 409);
      expect(code(err), 'CONFLICT');
    });
  });
}
