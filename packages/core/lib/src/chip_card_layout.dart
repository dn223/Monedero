import 'dart:convert';
import 'dart:typed_data';

import 'card_number.dart';
import 'card_signature.dart';

/// Formato de los datos de la tarjeta en un chip NTAG215 (Fase 7, ADR 0017).
///
/// El chip solo identifica: guarda el número y la firma; el UID lo pone el
/// fabricante y se lee del propio chip, nunca de su memoria. **El saldo no se
/// guarda en el chip** (vive en PostgreSQL).
///
/// Memoria de usuario, en páginas de 4 bytes a partir de [firstPage]:
///
/// | Página | Contenido |
/// |---|---|
/// | 4 | Encabezado: `M` `N` + versión del formato + `00` |
/// | 5–8 | Número de 16 dígitos en ASCII |
/// | 9–12 | Firma HMAC truncada (16 bytes) |
abstract final class ChipCardLayout {
  /// Primera página de usuario del NTAG215 (las 0–3 son del fabricante).
  static const int firstPage = 4;

  /// Bytes por página.
  static const int pageBytes = 4;

  /// Páginas que ocupa la tarjeta (encabezado + número + firma).
  static const int pageCount = 9;

  /// Bytes que ocupa la tarjeta.
  static const int totalBytes = pageCount * pageBytes;

  /// Versión del formato que escribe esta app.
  static const int version = 1;

  /// Bytes del UID de un NTAG215 (igual al UID de la regla 10).
  static const int uidBytes = CardSignature.uidBytes;

  static const List<int> _magic = [0x4D, 0x4E]; // "MN"

  /// Convierte el UID leído del chip a hex en mayúsculas, o `null` si no
  /// tiene [uidBytes] bytes.
  static String? uidHex(List<int> idBytes) {
    if (idBytes.length != uidBytes) return null;
    return _hex(idBytes);
  }

  /// `true` si [uid] es un UID de chip válido: [uidBytes] bytes en hex.
  static bool isValidUid(String uid) =>
      RegExp('^[0-9A-Fa-f]{${uidBytes * 2}}\$').hasMatch(uid);

  /// Páginas a escribir, en orden, a partir de [firstPage].
  ///
  /// Lanza [ArgumentError] si el número o la firma no son válidos.
  static List<Uint8List> encode({
    required String number,
    required String signature,
  }) {
    if (!CardNumber.isValid(number)) {
      throw ArgumentError.value(number, 'number', 'Número no válido');
    }
    final sig = _fromHex(signature);
    if (sig == null || sig.length != CardSignature.signatureBytes) {
      throw ArgumentError.value(signature, 'signature', 'Firma no válida');
    }
    final bytes = <int>[..._magic, version, 0, ...ascii.encode(number), ...sig];
    return [
      for (var i = 0; i < pageCount; i++)
        Uint8List.fromList(bytes.sublist(i * pageBytes, (i + 1) * pageBytes)),
    ];
  }

  /// Lee el número y la firma de los bytes leídos desde [firstPage].
  ///
  /// Devuelve `null` si el chip está en blanco, tiene otro formato o los
  /// datos no son válidos. No verifica la firma: eso lo hace la API.
  static ({String number, String signature})? decode(List<int> bytes) {
    if (bytes.length < totalBytes) return null;
    if (bytes[0] != _magic[0] || bytes[1] != _magic[1]) return null;
    if (bytes[2] != version) return null;
    final numberBytes = bytes.sublist(4, 20);
    if (numberBytes.any((b) => b < 0x30 || b > 0x39)) return null;
    final number = ascii.decode(numberBytes);
    if (!CardNumber.isValid(number)) return null;
    return (number: number, signature: _hex(bytes.sublist(20, totalBytes)));
  }

  static String _hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();

  static List<int>? _fromHex(String hex) {
    if (!RegExp(r'^([0-9A-Fa-f]{2})+$').hasMatch(hex)) return null;
    return [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }
}
