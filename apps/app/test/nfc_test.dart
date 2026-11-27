import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monedero/card_reader/card_reader.dart';
import 'package:monedero/card_reader/nfc_card_reader.dart';
import 'package:monedero/card_reader/nfc_chip.dart';
import 'package:monedero_core/monedero_core.dart';

/// Chip NTAG215 en memoria: 135 páginas de 4 bytes.
class FakeChip implements ChipTag {
  FakeChip({List<int>? id})
    : id = id ?? [0x04, 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6];

  @override
  final List<int> id;

  final memory = List<int>.filled(135 * 4, 0);
  int writes = 0;

  @override
  Future<List<int>> readPages(int page) async =>
      memory.sublist(page * 4, page * 4 + 16);

  @override
  Future<void> writePage(int page, List<int> data) async {
    writes++;
    memory.setRange(page * 4, page * 4 + 4, data);
  }
}

/// NFC falso: entrega [chip] cuando la prueba llama a [tap].
class FakeIo implements NfcChipIo {
  FakeIo({this.state = NfcStatus.ready});

  NfcStatus state;
  final _tap = Completer<ChipTag>();
  Completer<Object?>? _pending;

  void tap(ChipTag chip) => _tap.complete(chip);

  @override
  Future<NfcStatus> status() async => state;

  @override
  Future<T> withTag<T>(Future<T> Function(ChipTag tag) onTag) async {
    final done = Completer<Object?>();
    _pending = done;
    unawaited(
      _tap.future.then((chip) async {
        try {
          final result = await onTag(chip);
          if (!done.isCompleted) done.complete(result);
        } on Object catch (error) {
          if (!done.isCompleted) done.completeError(error);
        }
      }),
    );
    return await done.future as T;
  }

  @override
  Future<void> cancel() async {
    if (_pending case final p? when !p.isCompleted) {
      p.completeError(const NfcCancelled());
    }
  }
}

final _number = CardNumber.generate('6000');
const _uid = '04A1B2C3D4E5F6';
final _credentials = CardCredentials(
  number: _number,
  uid: _uid,
  signature: CardSignature.sign(
    masterKey: 'llave-de-prueba',
    number: _number,
    uid: _uid,
  ),
);

void main() {
  group('chip NTAG215', () {
    test('lo grabado se lee igual, con el UID del propio chip', () async {
      final chip = FakeChip();
      await writeChipCredentials(chip, _credentials);
      expect(chip.memory.sublist(16, 20), [0x4D, 0x4E, 1, 0]);

      final read = await readChipCredentials(chip);
      expect(read.toJson(), _credentials.toJson());
    });

    test('un chip en blanco no es una tarjeta', () async {
      expect(
        readChipCredentials(FakeChip()),
        throwsA(isA<CardReadException>()),
      );
    });

    test('un chip con UID de 4 bytes no es compatible', () async {
      expect(
        readChipCredentials(FakeChip(id: [1, 2, 3, 4])),
        throwsA(isA<CardReadException>()),
      );
    });

    test('no graba credenciales de otro chip', () async {
      final other = FakeChip(id: [0x04, 1, 2, 3, 4, 5, 6]);
      await expectLater(
        writeChipCredentials(other, _credentials),
        throwsA(isA<CardReadException>()),
      );
      expect(other.writes, 0);
    });

    test('copiar la memoria a otro chip cambia el UID leído', () async {
      final original = FakeChip();
      await writeChipCredentials(original, _credentials);
      final copy = FakeChip(id: [0x04, 9, 9, 9, 9, 9, 9])
        ..memory.setAll(0, original.memory);
      final read = await readChipCredentials(copy);
      // La firma ya no corresponde a ese UID: la API la rechaza.
      expect(read.uid, isNot(_uid));
      expect(
        CardSignature.verify(
          masterKey: 'llave-de-prueba',
          number: read.number,
          uid: read.uid,
          signature: read.signature,
        ),
        isFalse,
      );
    });
  });

  group('lector NFC de la caja', () {
    // La barra de progreso se anima sin fin: se avanza con pump, no con
    // pumpAndSettle.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<Future<CardCredentials?>> open(
      WidgetTester tester,
      NfcChipIo io,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      final result = NfcCardReader(io).read(ctx);
      await settle(tester);
      return result;
    }

    testWidgets('pide acercar la tarjeta y la lee', (tester) async {
      final chip = FakeChip();
      await writeChipCredentials(chip, _credentials);
      final io = FakeIo();
      final result = await open(tester, io);
      expect(find.text('Acerca la tarjeta'), findsOneWidget);

      io.tap(chip);
      await settle(tester);
      expect(find.text('Acerca la tarjeta'), findsNothing);
      expect((await result)!.number, _number);
    });

    testWidgets('Cancelar devuelve null', (tester) async {
      final io = FakeIo();
      final result = await open(tester, io);
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
      expect(await result, isNull);
    });

    testWidgets('con el NFC apagado lo avisa sin abrir la hoja', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      final io = FakeIo(state: NfcStatus.disabled);
      final check = expectLater(
        NfcCardReader(io).read(ctx),
        throwsA(isA<CardReadException>()),
      );
      await settle(tester);
      expect(find.text('Acerca la tarjeta'), findsNothing);
      await check;
    });
  });
}
