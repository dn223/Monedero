import 'dart:math';

import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalCode', () {
    test('genera 12 caracteres del alfabeto sin caracteres confusos', () {
      final code = TerminalCode.generate(Random(1));
      expect(code, hasLength(12));
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{12}$')));
    });

    test('normaliza guiones, espacios y minúsculas', () {
      expect(TerminalCode.normalize('k7m4-q2xp ht9w'), 'K7M4Q2XPHT9W');
      expect(TerminalCode.normalize('K7M4-Q2XP'), isNull);
      expect(TerminalCode.normalize('K7M4-Q2XP-HT9O'), isNull);
    });

    test('se muestra en grupos de 4', () {
      expect(TerminalCode.format('K7M4Q2XPHT9W'), 'K7M4-Q2XP-HT9W');
    });

    test('el lector de credenciales de caja acepta el código', () {
      expect(QrPayloads.terminalToken('k7m4-q2xp-ht9w'), 'K7M4Q2XPHT9W');
      expect(
        QrPayloads.terminalToken(QrPayloads.terminalLink('K7M4Q2XPHT9W')),
        'K7M4Q2XPHT9W',
      );
    });
  });
}
