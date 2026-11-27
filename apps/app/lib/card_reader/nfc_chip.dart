import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:monedero_core/monedero_core.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'card_reader.dart';

/// Un chip NTAG215 acercado al teléfono (Fase 7, ADR 0017).
///
/// Es la frontera con el hardware: la lógica de [readChipCredentials] y
/// [writeChipCredentials] se prueba con un chip falso.
abstract interface class ChipTag {
  /// UID que grabó el fabricante (7 bytes en un NTAG215).
  List<int> get id;

  /// Lee 4 páginas (16 bytes) desde [page].
  Future<List<int>> readPages(int page);

  /// Escribe una página de 4 bytes en [page].
  Future<void> writePage(int page, List<int> data);
}

/// Estado del NFC del dispositivo.
enum NfcStatus {
  /// Hay NFC y está encendido.
  ready,

  /// Hay NFC pero está apagado en los ajustes.
  disabled,

  /// El dispositivo (o la web) no tiene NFC.
  unsupported,
}

/// Acceso al NFC del dispositivo.
abstract interface class NfcChipIo {
  /// Estado del NFC.
  Future<NfcStatus> status();

  /// Espera un chip, ejecuta [onTag] mientras sigue cerca y cierra la
  /// sesión. Lanza [NfcCancelled] si se llamó a [cancel].
  Future<T> withTag<T>(Future<T> Function(ChipTag tag) onTag);

  /// Cancela la espera en curso.
  Future<void> cancel();
}

/// Se canceló la espera del chip.
class NfcCancelled implements Exception {
  /// Crea la excepción.
  const NfcCancelled();
}

/// Lee número, UID y firma de un chip grabado por administración.
///
/// El UID sale del propio chip (lo pone el fabricante); el número y la firma,
/// de su memoria ([ChipCardLayout]). La API valida la firma después.
Future<CardCredentials> readChipCredentials(ChipTag tag) async {
  final uid = ChipCardLayout.uidHex(tag.id);
  if (uid == null) {
    throw const CardReadException(
      'Este chip no es compatible: se necesita un NTAG215 (13.56 MHz).',
    );
  }
  final bytes = <int>[];
  const first = ChipCardLayout.firstPage;
  for (var page = first; page < first + ChipCardLayout.pageCount; page += 4) {
    bytes.addAll(await tag.readPages(page));
  }
  final data = ChipCardLayout.decode(bytes);
  if (data == null) {
    throw const CardReadException(
      'Este chip está en blanco o no es una tarjeta de Monedero. '
      'Administración debe grabarlo primero.',
    );
  }
  return CardCredentials(
    number: data.number,
    uid: uid,
    signature: data.signature,
  );
}

/// Escribe [credentials] en el chip y verifica leyéndolo de nuevo.
///
/// Las credenciales deben ser las que devolvió la API para el UID de este
/// mismo chip; si no coinciden no se escribe nada.
Future<void> writeChipCredentials(
  ChipTag tag,
  CardCredentials credentials,
) async {
  final uid = ChipCardLayout.uidHex(tag.id);
  if (uid == null || uid != credentials.uid.toUpperCase()) {
    throw const CardReadException(
      'El chip cambió durante la grabación. Mantén el mismo chip cerca '
      'e intenta de nuevo.',
    );
  }
  final pages = ChipCardLayout.encode(
    number: credentials.number,
    signature: credentials.signature,
  );
  for (var i = 0; i < pages.length; i++) {
    await tag.writePage(ChipCardLayout.firstPage + i, pages[i]);
  }
  final check = await readChipCredentials(tag);
  if (check.number != credentials.number ||
      check.signature != credentials.signature.toUpperCase()) {
    throw const CardReadException(
      'La verificación del chip falló. Intenta grabarlo de nuevo.',
    );
  }
}

/// NFC real con `nfc_manager` (solo Android; en web y otros es
/// [NfcStatus.unsupported]).
class PlatformNfcChipIo implements NfcChipIo {
  /// Crea el acceso al NFC.
  PlatformNfcChipIo();

  Completer<Object?>? _pending;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<NfcStatus> status() async {
    if (!_android) return NfcStatus.unsupported;
    try {
      return switch (await NfcManager.instance.checkAvailability()) {
        NfcAvailability.enabled => NfcStatus.ready,
        NfcAvailability.disabled => NfcStatus.disabled,
        NfcAvailability.unsupported => NfcStatus.unsupported,
      };
    } on Object {
      return NfcStatus.unsupported;
    }
  }

  @override
  Future<T> withTag<T>(Future<T> Function(ChipTag tag) onTag) async {
    final done = Completer<Object?>();
    _pending = done;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (tag) async {
          if (done.isCompleted) return;
          try {
            final chip = _AndroidChipTag.from(tag);
            final result = await onTag(chip);
            if (!done.isCompleted) done.complete(result);
          } on PlatformException catch (error) {
            // El código de Android ayuda a distinguir un chip retirado de
            // uno protegido contra escritura.
            if (!done.isCompleted) {
              done.completeError(
                CardReadException(
                  'Se perdió la conexión con el chip. Mantenlo quieto '
                  'e intenta de nuevo (${error.code}).',
                ),
              );
            }
          } on Object catch (error, stack) {
            if (!done.isCompleted) done.completeError(error, stack);
          }
        },
      );
      return await done.future as T;
    } finally {
      _pending = null;
      try {
        await NfcManager.instance.stopSession();
      } on Object {
        // La sesión ya estaba cerrada.
      }
    }
  }

  @override
  Future<void> cancel() async {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const NfcCancelled());
    }
  }
}

class _AndroidChipTag implements ChipTag {
  _AndroidChipTag(this._tag);

  factory _AndroidChipTag.from(NfcTag tag) {
    final ultralight = MifareUltralightAndroid.from(tag);
    if (ultralight == null) {
      throw const CardReadException(
        'Este chip no es compatible: se necesita un NTAG215 (13.56 MHz).',
      );
    }
    return _AndroidChipTag(ultralight);
  }

  final MifareUltralightAndroid _tag;

  @override
  List<int> get id => _tag.tag.id;

  @override
  Future<List<int>> readPages(int page) => _tag.readPages(pageOffset: page);

  @override
  Future<void> writePage(int page, List<int> data) =>
      _tag.writePage(pageOffset: page, data: Uint8List.fromList(data));
}
