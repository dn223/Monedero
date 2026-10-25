import 'package:flutter/widgets.dart';
import 'package:monedero_core/monedero_core.dart';

import 'card_reader.dart';

/// Esqueleto del lector NFC para tarjetas MIFARE Classic (Fase 7).
///
/// Leerá el UID del chip y, del bloque de datos, el número y la firma; luego
/// entregará las mismas [CardCredentials] que el lector simulado, así el
/// resto de la caja no cambia. Requiere hardware (celulares con NFC
/// compatible y tarjetas): el plan está en docs/nfc.md.
class NfcMifareCardReader implements CardReader {
  /// Crea el lector.
  const NfcMifareCardReader();

  @override
  String get name => 'Tarjeta NFC';

  @override
  Future<CardCredentials?> read(BuildContext context) => throw UnsupportedError(
    'La lectura NFC llega en la Fase 7 (ver docs/nfc.md).',
  );
}
