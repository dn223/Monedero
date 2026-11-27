@Tags(['integration'])
library;

import 'package:monedero_api/monedero_api.dart';
import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// Fase 7 (ADR 0017): vincular un chip NFC NTAG215 a una tarjeta contra
/// PostgreSQL real. Usa su propia base.
void main() {
  late Harness h;
  late CashDesk desk;

  setUpAll(() async {
    h = await Harness.start(database: 'monedero_test_chip');
    desk = await h.cashDesk();
  });
  tearDownAll(() => h.close());

  String code(Map<String, Object?> body) =>
      (body['error']! as Map<String, Object?>)['code']! as String;

  Future<(int, Map<String, Object?>)> link(
    String cardId,
    String chipUid, {
    String? token,
  }) => h.call(
    'POST',
    '/v1/admin/cards/$cardId/chip',
    body: {'chipUid': chipUid},
    token: token ?? desk.admin,
  );

  Future<(int, Map<String, Object?>)> read(Map<String, Object?> creds) =>
      h.call(
        'POST',
        '/v1/cards/read',
        body: {'card': creds},
        token: desk.cashier,
        terminal: desk.terminal,
      );

  test('la tarjeta adopta el UID del chip y opera con él', () async {
    final (cardId, oldCreds, _) = await desk.newActiveCard('chip1@test.local');
    await desk.op('top-ups', oldCreds, 2000);

    final (status, body) = await link(cardId, '04a1b2c3d4e5f6');
    expect(status, 200, reason: '$body');
    final creds = body['credentials']! as Map<String, Object?>;
    expect(creds['number'], oldCreds['number']);
    expect(creds['uid'], '04A1B2C3D4E5F6');
    expect(creds['signature'], isNot(oldCreds['signature']));

    // Lo que la app escribe en el chip se lee igual.
    final pages = ChipCardLayout.encode(
      number: creds['number']! as String,
      signature: creds['signature']! as String,
    );
    final fromChip = ChipCardLayout.decode([for (final p in pages) ...p])!;
    expect(fromChip.signature, creds['signature']);

    // La caja opera con las credenciales del chip; las anteriores ya no sirven.
    final (readStatus, readBody) = await read(creds);
    expect(readStatus, 200, reason: '$readBody');
    expect(readBody['balanceCents'], 2000);
    final (oldStatus, oldBody) = await read(oldCreds);
    expect(oldStatus, 422);
    expect(code(oldBody), 'INVALID_CARD_SIGNATURE');

    final (debit, _) = await desk.op('debits', creds, 735);
    expect(debit, 201);
    final state = await h.cardState(cardId);
    expect(state.balance, 1265);
    expect(state.difference, 0, reason: 'el saldo no cambia al vincular');

    // Queda auditado.
    final audit = await query(
      h.owner,
      'SELECT previous_uid, chip_uid FROM card_chip_links '
      'WHERE card_id = @id:uuid',
      {'id': cardId},
    );
    expect(audit, hasLength(1));
    expect(audit.first['previous_uid'], oldCreds['uid']);
    expect(audit.first['chip_uid'], '04A1B2C3D4E5F6');
  });

  test('repetir con el mismo chip no cambia nada', () async {
    final (cardId, _, _) = await desk.newActiveCard('chip2@test.local');
    final (_, first) = await link(cardId, '04B1B2C3D4E5F6');
    final (status, again) = await link(cardId, '04B1B2C3D4E5F6');
    expect(status, 200);
    expect(again['credentials'], first['credentials']);
    final audit = await query(
      h.owner,
      'SELECT 1 FROM card_chip_links WHERE card_id = @id:uuid',
      {'id': cardId},
    );
    expect(audit, hasLength(1));
  });

  test('un chip no puede ser de dos tarjetas', () async {
    final (cardA, _, _) = await desk.newActiveCard('chip3@test.local');
    final (cardB, _, _) = await desk.newActiveCard('chip4@test.local');
    expect((await link(cardA, '04C1B2C3D4E5F6')).$1, 200);
    final (status, body) = await link(cardB, '04C1B2C3D4E5F6');
    expect(status, 409);
    expect(code(body), 'CHIP_ALREADY_LINKED');
  });

  test('UID mal formado, tarjeta bloqueada y rol incorrecto', () async {
    final (cardId, _, holder) = await desk.newActiveCard('chip5@test.local');

    final (bad, badBody) = await link(cardId, '04A1B2C3'); // 4 bytes
    expect(bad, 400);
    expect(code(badBody), 'VALIDATION_FAILED');

    final (asCashier, _) = await link(
      cardId,
      '04D1B2C3D4E5F6',
      token: desk.cashier,
    );
    expect(asCashier, 403);
    final (asHolder, _) = await link(cardId, '04D1B2C3D4E5F6', token: holder);
    expect(asHolder, 403);

    await query(
      h.owner,
      "UPDATE cards SET status = 'BLOCKED' WHERE id = @id:uuid",
      {'id': cardId},
    );
    final (blocked, blockedBody) = await link(cardId, '04D1B2C3D4E5F6');
    expect(blocked, 409);
    expect(code(blockedBody), 'CARD_NOT_ACTIVE');
  });
}
