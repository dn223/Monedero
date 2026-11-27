import 'package:flutter/widgets.dart';
import 'package:monedero_core/monedero_core.dart';

/// Lector de tarjetas de la caja.
///
/// Toda forma de leer una tarjeta entrega lo mismo: número, UID y firma
/// ([CardCredentials]). La caja no sabe si vinieron de un QR o de un chip;
/// la API valida la firma con la llave maestra en cada operación (regla 10).
///
/// - Hoy: [SimulatedCardReader] (QR con cámara, lista demo o escritura).
/// - Fase 7: `NfcMifareCardReader` (chip MIFARE con NFC), ver docs/nfc.md.
abstract interface class CardReader {
  /// Nombre visible del lector.
  String get name;

  /// Lee una tarjeta. Devuelve `null` si el cajero canceló.
  ///
  /// Lanza [CardReadException] si lo leído no es una tarjeta válida.
  Future<CardCredentials?> read(BuildContext context);
}

/// Lo leído no es una tarjeta (QR de otra cosa, número mal escrito…).
class CardReadException implements Exception {
  /// Crea la excepción con un [message] para el cajero.
  const CardReadException(this.message);

  /// Mensaje en español.
  final String message;

  @override
  String toString() => 'CardReadException: $message';
}
