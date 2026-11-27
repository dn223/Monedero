import 'dart:convert';

import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

void main() {
  const key = 'llave-maestra-de-prueba-de-32-caracteres!!';
  final number = CardNumber.generate('9990');
  const uid = '04A1B2C3D4E5F6';
  final signature = CardSignature.sign(
    masterKey: key,
    number: number,
    uid: uid,
  );

  group('QR de tarjeta', () {
    test('lee el JSON de la tarjeta y normaliza mayúsculas', () {
      final raw = jsonEncode({
        'number': number,
        'uid': uid.toLowerCase(),
        'signature': signature.toLowerCase(),
      });
      final card = QrPayloads.card(raw)!;
      expect(card.number, number);
      expect(card.uid, uid);
      expect(card.signature, signature);
    });

    test('rechaza texto que no es una tarjeta', () {
      expect(QrPayloads.card('hola'), isNull);
      expect(QrPayloads.card('{"number": "1234"}'), isNull);
      final badLuhn =
          '${number.substring(0, 15)}'
          '${(int.parse(number[15]) + 1) % 10}';
      expect(
        QrPayloads.card(
          jsonEncode({'number': badLuhn, 'uid': uid, 'signature': signature}),
        ),
        isNull,
      );
    });
  });

  group('QR de vínculo de caja', () {
    final token = List.filled(64, 'a').join();

    test('ida y vuelta', () {
      expect(QrPayloads.terminalToken(QrPayloads.terminalLink(token)), token);
    });

    test('acepta la credencial pegada tal cual', () {
      expect(QrPayloads.terminalToken('  $token '), token);
    });

    test('rechaza otros contenidos', () {
      expect(QrPayloads.terminalToken('{"terminalToken": "$token"}'), isNull);
      expect(QrPayloads.terminalToken('abc'), isNull);
    });
  });

  group('URL del servidor', () {
    test('normaliza la URL', () {
      expect(
        QrPayloads.serverUrl('https://ejemplo.trycloudflare.com/'),
        'https://ejemplo.trycloudflare.com',
      );
      expect(
        QrPayloads.serverUrl('192.168.1.50:8080'),
        'http://192.168.1.50:8080',
      );
      expect(
        QrPayloads.serverUrl('http://localhost:8080/#/caja'),
        'http://localhost:8080',
      );
    });

    test('rechaza lo que no es http(s)', () {
      expect(QrPayloads.serverUrl(''), isNull);
      expect(QrPayloads.serverUrl('ftp://x.com'), isNull);
    });
  });
}
