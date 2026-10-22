@Tags(['integration'])
library;

import 'package:monedero_api/monedero_api.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

/// Pruebas obligatorias de diseño (docs/testing.md § 3) contra PostgreSQL
/// real. Requieren `dart run tool/up.dart`.
void main() {
  late Harness h;
  late CashDesk desk;

  setUpAll(() async {
    h = await Harness.start();
    desk = await h.cashDesk();
  });
  tearDownAll(() => h.close());

  test('1. 1,000 débitos concurrentes: nunca saldo negativo y conciliación '
      'en cero', () async {
    final (cardId, card, _) = await desk.newActiveCard(
      'concurrencia@test.local',
    );
    expect((await desk.op('top-ups', card, 10000)).$1, 201); // $100.00

    // 1,000 cobros de $0.25 al mismo tiempo: solo caben 400.
    final results = await Future.wait([
      for (var i = 0; i < 1000; i++) desk.op('debits', card, 25),
    ]);
    final ok = results.where((r) => r.$1 == 201).length;
    final rejected = results.where(
      (r) =>
          r.$1 == 422 &&
          (r.$2['error']! as Map)['code'] == 'INSUFFICIENT_FUNDS',
    );
    final summary = <String, int>{};
    for (final (status, body) in results) {
      final code = (body['error'] as Map?)?['code'] ?? 'OK';
      summary.update('$status $code', (n) => n + 1, ifAbsent: () => 1);
    }
    expect(ok, 400, reason: '$summary');
    expect(rejected.length, 600, reason: '$summary');

    final state = await h.cardState(cardId);
    expect(state.balance, 0);
    expect(state.difference, 0);
    expect(state.txCount, 401); // 1 recarga + 400 débitos

    final negatives = await h.owner.execute(
      'SELECT count(*) FROM transactions WHERE balance_after_cents < 0',
    );
    expect(negatives.first.first, 0);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('2. Misma operación 5 veces con la misma Idempotency-Key se aplica una '
      'vez', () async {
    final (cardId, card, _) = await desk.newActiveCard(
      'idempotencia@test.local',
    );
    final key = const Uuid().v4();
    final responses = [
      for (var i = 0; i < 5; i++)
        await desk.op('top-ups', card, 2000, key: key),
    ];
    expect(responses.map((r) => r.$1).toSet(), {201});
    expect(responses.map((r) => r.$2.toString()).toSet(), hasLength(1));

    final state = await h.cardState(cardId);
    expect(state.balance, 2000);
    expect(state.txCount, 1);

    // La misma clave con otro monto no se aplica.
    final reused = await desk.op('top-ups', card, 500, key: key);
    expect(reused.$1, 422);
    expect((reused.$2['error']! as Map)['code'], 'IDEMPOTENCY_KEY_REUSED');

    // También en paralelo: 5 envíos simultáneos con la misma clave.
    final parallelKey = const Uuid().v4();
    final parallel = await Future.wait([
      for (var i = 0; i < 5; i++)
        desk.op('debits', card, 735, key: parallelKey),
    ]);
    expect(parallel.map((r) => r.$1).toSet(), {201});
    expect((await h.cardState(cardId)).balance, 2000 - 735);

    // Una operación rechazada no consume la clave.
    final failKey = const Uuid().v4();
    expect((await desk.op('debits', card, 999999, key: failKey)).$1, 422);
    expect((await desk.op('debits', card, 100, key: failKey)).$1, 201);
  });

  test('3. Reposición con falla forzada a mitad: todo se revierte', () async {
    final (cardId, card, holderToken) = await desk.newActiveCard(
      'reposicion@test.local',
    );
    await desk.op('top-ups', card, 2000);
    await desk.op('debits', card, 735);
    await h.call(
      'POST',
      '/v1/me/cards/$cardId/loss-reports',
      token: holderToken,
    );
    final (status, blocked) = await h.call(
      'POST',
      '/v1/me/cards/$cardId/loss-reports/confirm',
      body: {'code': h.mailer.lastCodeFor('reposicion@test.local')},
      token: holderToken,
    );
    expect(status, 200);
    expect(blocked['status'], 'BLOCKED');

    final admin =
        (await query(h.owner, 'SELECT id FROM staff_users WHERE role = @r', {
              'r': 'ADMIN',
            })).first['id']
            as String;
    final cardsBefore = await h.owner.execute('SELECT count(*) FROM cards');

    final faulty = h.servicesWithFault((stage) async {
      if (stage == 'after-transfer-out') throw StateError('falla forzada');
    });
    await expectLater(
      faulty.replacements.replace(
        oldCardId: cardId,
        adminId: admin,
        idempotencyKey: const Uuid().v4(),
      ),
      throwsStateError,
    );

    final state = await h.cardState(cardId);
    expect(state.status, 'BLOCKED');
    expect(state.balance, 1265);
    expect(state.difference, 0);
    expect(
      (await h.owner.execute('SELECT count(*) FROM cards')).first.first,
      cardsBefore.first.first,
    );
    expect(
      (await h.owner.execute('SELECT count(*) FROM replacements')).first.first,
      0,
    );

    // Sin falla, la reposición conserva el saldo.
    final (code, replaced) = await h.call(
      'POST',
      '/v1/admin/cards/$cardId/replace',
      token: desk.admin,
      key: const Uuid().v4(),
    );
    expect(code, 201);
    expect(replaced['transferredCents'], 1265);
    expect((replaced['newCard']! as Map)['balanceCents'], 1265);
    expect((replaced['newCard']! as Map)['status'], 'ACTIVE');
    expect((replaced['oldCard']! as Map)['status'], 'REPLACED');
  });

  test('4. Modificar o borrar un movimiento: la base lo rechaza', () async {
    final (cardId, card, _) = await desk.newActiveCard('inmutable@test.local');
    await desk.op('top-ups', card, 500);

    // a) El usuario de la API no tiene permisos.
    for (final sql in [
      'UPDATE transactions SET amount_cents = 1 WHERE card_id = @id:uuid',
      'DELETE FROM transactions WHERE card_id = @id:uuid',
    ]) {
      await expectLater(
        query(h.pool, sql, {'id': cardId}),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', '42501')),
      );
    }
    // b) Ni el dueño del esquema: el trigger lo impide.
    for (final sql in [
      'UPDATE transactions SET amount_cents = 1 WHERE card_id = @id:uuid',
      'DELETE FROM transactions WHERE card_id = @id:uuid',
    ]) {
      await expectLater(
        query(h.owner, sql, {'id': cardId}),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('solo inserción'),
          ),
        ),
      );
    }
    expect((await h.cardState(cardId)).txCount, 1);
  });

  test('5. Firma inválida o UID cambiado: operación rechazada', () async {
    final (cardId, card, _) = await desk.newActiveCard('firma@test.local');
    await desk.op('top-ups', card, 1000);
    final uid = card['uid']! as String;
    final changedUid = {
      ...card,
      'uid': '${uid.substring(0, 13)}${uid.endsWith('0') ? '1' : '0'}',
    };
    final badSignature = {...card, 'signature': '0' * 32};
    for (final forged in [changedUid, badSignature]) {
      final (status, body) = await desk.op('debits', forged, 100);
      expect(status, 422);
      expect((body['error']! as Map)['code'], 'INVALID_CARD_SIGNATURE');
    }
    expect((await h.cardState(cardId)).balance, 1000);
  });

  group('Reglas de caja', () {
    test('recarga solo múltiplos de \$5; sobregiro rechazado; PIN sobre '
        '\$25; tarjeta bloqueada no opera', () async {
      final (cardId, card, holderToken) = await desk.newActiveCard(
        'reglas@test.local',
      );
      expect((await desk.op('top-ups', card, 735)).$1, 422);
      expect((await desk.op('top-ups', card, 5000)).$1, 201);

      final noPin = await desk.op('debits', card, 3000);
      expect((noPin.$2['error']! as Map)['code'], 'PIN_REQUIRED');
      final badPin = await desk.op('debits', card, 3000, pin: '0000');
      expect((badPin.$2['error']! as Map)['code'], 'INVALID_PIN');
      expect((await desk.op('debits', card, 3000, pin: '4321')).$1, 201);

      final over = await desk.op('debits', card, 2001);
      expect((over.$2['error']! as Map)['code'], 'INSUFFICIENT_FUNDS');

      await h.call(
        'POST',
        '/v1/me/cards/$cardId/loss-reports',
        token: holderToken,
      );
      await h.call(
        'POST',
        '/v1/me/cards/$cardId/loss-reports/confirm',
        body: {'code': h.mailer.lastCodeFor('reglas@test.local')},
        token: holderToken,
      );
      final blocked = await desk.op('debits', card, 100);
      expect((blocked.$2['error']! as Map)['code'], 'CARD_NOT_ACTIVE');
    });

    test('roles validados en la API y terminal obligatorio', () async {
      final (_, card, holderToken) = await desk.newActiveCard(
        'roles@test.local',
      );
      final asHolder = await h.call(
        'POST',
        '/v1/cards/top-ups',
        body: {'card': card, 'amountCents': 500},
        token: holderToken,
        terminal: desk.terminal,
        key: const Uuid().v4(),
      );
      expect(asHolder.$1, 403);
      final noTerminal = await h.call(
        'POST',
        '/v1/cards/top-ups',
        body: {'card': card, 'amountCents': 500},
        token: desk.cashier,
        key: const Uuid().v4(),
      );
      expect(
        (noTerminal.$2['error']! as Map)['code'],
        'TERMINAL_NOT_AUTHORIZED',
      );
      final noKey = await h.call(
        'POST',
        '/v1/cards/top-ups',
        body: {'card': card, 'amountCents': 500},
        token: desk.cashier,
        terminal: desk.terminal,
      );
      expect((noKey.$2['error']! as Map)['code'], 'IDEMPOTENCY_KEY_REQUIRED');
    });

    test('el titular paga con el código de caja y recibe el aviso por '
        'correo', () async {
      const email = 'pago-caja@test.local';
      final (cardId, card, holderToken) = await desk.newActiveCard(email);
      await desk.op('top-ups', card, 2000);

      final (_, session) = await h.call('POST', '/v1/demo/cashier-session');
      final payCode = session['payCode']! as String;
      expect(payCode, matches(RegExp(r'^\d{6}$')));

      final (status, receipt) = await h.call(
        'POST',
        '/v1/me/payments',
        body: {'terminalCode': payCode, 'amountCents': 735},
        token: holderToken,
        key: const Uuid().v4(),
      );
      expect(status, 201);
      expect(receipt['balanceAfterCents'], 1265);
      expect((await h.cardState(cardId)).difference, 0);
      expect(
        h.mailer.sent.last,
        isA<({String to, String subject, String text})>()
            .having((m) => m.to, 'to', email)
            .having((m) => m.text, 'text', contains(r'$12.65')),
      );

      final (_, activity) = await h.call(
        'GET',
        '/v1/cards/terminal-activity',
        token: session['accessToken']! as String,
        terminal: session['terminalToken']! as String,
      );
      expect(
        (activity['items']! as List).first,
        containsPair('amountCents', 735),
      );

      final wrong = await h.call(
        'POST',
        '/v1/me/payments',
        body: {'terminalCode': '000000', 'amountCents': 100},
        token: holderToken,
        key: const Uuid().v4(),
      );
      expect(wrong.$1, 404);
    });

    test('la conciliación global queda en cero', () async {
      final (status, body) = await h.call(
        'GET',
        '/v1/admin/reconciliation',
        token: desk.admin,
      );
      expect(status, 200);
      expect(body['cardsWithDifference'], 0);
      expect(body['totalDifferenceCents'], 0);
    });
  });
}
