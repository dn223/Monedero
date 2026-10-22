import 'dart:math';

import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

void main() {
  group('Money', () {
    test('recarga: solo múltiplos de \$5 mayores que cero', () {
      expect(Money.isValidTopUp(500), isTrue);
      expect(Money.isValidTopUp(2000), isTrue);
      expect(Money.isValidTopUp(0), isFalse);
      expect(Money.isValidTopUp(-500), isFalse);
      expect(Money.isValidTopUp(735), isFalse);
    });

    test('débito: mayor que cero', () {
      expect(Money.isValidDebitAmount(1), isTrue);
      expect(Money.isValidDebitAmount(0), isFalse);
      expect(Money.isValidDebitAmount(-1), isFalse);
    });

    test('formato USD con dos decimales', () {
      expect(Money.format(735), r'$7.35');
      expect(Money.format(0), r'$0.00');
      expect(Money.format(123456), r'$1,234.56');
      expect(Money.format(-500), r'-$5.00');
    });

    test('convierte texto a centavos sin double', () {
      expect(Money.parseCents('7.35'), 735);
      expect(Money.parseCents(r'$20'), 2000);
      expect(Money.parseCents('1,234.5'), 123450);
      expect(Money.parseCents('0.1'), 10);
      expect(Money.parseCents('7.355'), isNull);
      expect(Money.parseCents('abc'), isNull);
      expect(Money.parseCents('-5'), isNull);
    });
  });

  group('CardNumber', () {
    test('Luhn conocido', () {
      expect(CardNumber.isValid('4539578763621486'), isTrue);
      expect(CardNumber.isValid('4539578763621487'), isFalse);
      expect(CardNumber.isValid('123'), isFalse);
    });

    test('genera 16 dígitos válidos con el prefijo', () {
      final rng = Random(1);
      for (var i = 0; i < 200; i++) {
        final number = CardNumber.generate('9990', random: rng);
        expect(number, hasLength(16));
        expect(number, startsWith('9990'));
        expect(CardNumber.isValid(number), isTrue);
      }
    });

    test('enmascara', () {
      expect(CardNumber.masked('9990123412341234'), '•••• 1234');
    });
  });

  group('CardSignature', () {
    const key = 'llave-de-prueba';
    const number = '9990000000000001';

    test('UID de 7 bytes en hex', () {
      expect(CardSignature.generateUid(), matches(RegExp(r'^[0-9A-F]{14}$')));
    });

    test('firma de 16 bytes que verifica', () {
      const uid = '04A1B2C3D4E5F6';
      final sig = CardSignature.sign(masterKey: key, number: number, uid: uid);
      expect(sig, matches(RegExp(r'^[0-9A-F]{32}$')));
      expect(
        CardSignature.verify(
          masterKey: key,
          number: number,
          uid: uid,
          signature: sig,
        ),
        isTrue,
      );
    });

    test('UID cambiado, firma alterada u otra llave: rechazo', () {
      const uid = '04A1B2C3D4E5F6';
      final sig = CardSignature.sign(masterKey: key, number: number, uid: uid);
      bool ok(String k, String n, String u, String s) =>
          CardSignature.verify(masterKey: k, number: n, uid: u, signature: s);
      expect(ok(key, number, '04A1B2C3D4E5F7', sig), isFalse);
      expect(ok(key, '9990000000000019', uid, sig), isFalse);
      expect(ok('otra', number, uid, sig), isFalse);
      final flipped = sig.endsWith('0') ? '1' : '0';
      expect(ok(key, number, uid, '${sig.substring(0, 31)}$flipped'), isFalse);
    });
  });
}
