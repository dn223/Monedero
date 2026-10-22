import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// UID simulado y firma HMAC de la tarjeta (regla 10).
///
/// La llave maestra solo existe en el servidor; la app nunca llama a [sign].
abstract final class CardSignature {
  /// Bytes del UID simulado (como un chip MIFARE de 7 bytes).
  static const int uidBytes = 7;

  /// Bytes de la firma truncada.
  static const int signatureBytes = 16;

  /// Genera un UID aleatorio de 7 bytes en hexadecimal mayúsculas.
  static String generateUid({Random? random}) {
    final rng = random ?? Random.secure();
    return List.generate(
      uidBytes,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join().toUpperCase();
  }

  /// `HMAC-SHA256(masterKey, number + uid)` truncado a 16 bytes, en hex.
  static String sign({
    required String masterKey,
    required String number,
    required String uid,
  }) {
    final hmac = Hmac(sha256, utf8.encode(masterKey));
    final digest = hmac.convert(utf8.encode('$number${uid.toUpperCase()}'));
    return digest.bytes
        .take(signatureBytes)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  /// Verifica la firma en tiempo constante.
  static bool verify({
    required String masterKey,
    required String number,
    required String uid,
    required String signature,
  }) {
    final expected = sign(masterKey: masterKey, number: number, uid: uid);
    final given = signature.toUpperCase();
    if (given.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected.codeUnitAt(i) ^ given.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Lo que entrega cualquier lector de tarjetas (QR hoy, NFC mañana).
class CardCredentials {
  /// Crea las credenciales leídas de una tarjeta.
  const CardCredentials({
    required this.number,
    required this.uid,
    required this.signature,
  });

  /// Lee las credenciales desde JSON (`number`, `uid`, `signature`).
  factory CardCredentials.fromJson(Map<String, Object?> json) =>
      CardCredentials(
        number: json['number']! as String,
        uid: json['uid']! as String,
        signature: json['signature']! as String,
      );

  /// Número de 16 dígitos.
  final String number;

  /// UID del chip (simulado) en hex.
  final String uid;

  /// Firma HMAC truncada en hex.
  final String signature;

  /// Serializa a JSON; es también el contenido del QR de la tarjeta virtual.
  Map<String, Object?> toJson() => {
    'number': number,
    'uid': uid,
    'signature': signature,
  };
}
