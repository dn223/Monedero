import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

void main() {
  const uid = '04A1B2C3D4E5F6';
  final number = CardNumber.generate('6000');
  final signature = CardSignature.sign(
    masterKey: 'llave-de-prueba',
    number: number,
    uid: uid,
  );

  group('ChipCardLayout', () {
    test('escribe 9 páginas de 4 bytes y se leen igual', () {
      final pages = ChipCardLayout.encode(number: number, signature: signature);
      expect(pages, hasLength(9));
      expect(pages.every((p) => p.length == 4), isTrue);
      expect(pages.first, [0x4D, 0x4E, 1, 0]);

      final read = ChipCardLayout.decode([for (final p in pages) ...p]);
      expect(read, isNotNull);
      expect(read!.number, number);
      expect(read.signature, signature);
    });

    test('lo leído de más (páginas 13–15) se ignora', () {
      final pages = ChipCardLayout.encode(number: number, signature: signature);
      final read = ChipCardLayout.decode([
        for (final p in pages) ...p,
        ...List.filled(12, 0),
      ]);
      expect(read!.number, number);
    });

    test('un chip en blanco, de otro formato o corto no se acepta', () {
      expect(ChipCardLayout.decode(List.filled(36, 0)), isNull);
      expect(ChipCardLayout.decode(List.filled(10, 0)), isNull);
      final pages = ChipCardLayout.encode(number: number, signature: signature);
      final otherVersion = [for (final p in pages) ...p]..[2] = 9;
      expect(ChipCardLayout.decode(otherVersion), isNull);
      final badDigit = [for (final p in pages) ...p]..[5] = 0x41;
      expect(ChipCardLayout.decode(badDigit), isNull);
    });

    test('rechaza número o firma no válidos al escribir', () {
      expect(
        () => ChipCardLayout.encode(number: '1234', signature: signature),
        throwsArgumentError,
      );
      expect(
        () => ChipCardLayout.encode(number: number, signature: 'ABC'),
        throwsArgumentError,
      );
    });

    test('UID: 7 bytes en hex mayúsculas', () {
      expect(
        ChipCardLayout.uidHex([0x04, 0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6]),
        uid,
      );
      expect(ChipCardLayout.uidHex([1, 2, 3, 4]), isNull);
      expect(ChipCardLayout.isValidUid(uid), isTrue);
      expect(ChipCardLayout.isValidUid('04a1b2c3d4e5f6'), isTrue);
      expect(ChipCardLayout.isValidUid('04A1B2C3'), isFalse);
      expect(ChipCardLayout.isValidUid('04A1B2C3D4E5FG'), isFalse);
    });
  });
}
