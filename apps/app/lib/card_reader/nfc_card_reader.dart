import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import 'card_reader.dart';
import 'nfc_chip.dart';

/// Acceso al NFC del dispositivo (las pruebas lo reemplazan por uno falso).
final nfcChipIoProvider = Provider<NfcChipIo>((ref) => PlatformNfcChipIo());

/// Estado del NFC del dispositivo.
final nfcStatusProvider = FutureProvider<NfcStatus>(
  (ref) => ref.watch(nfcChipIoProvider).status(),
);

/// Lector de la caja para tarjetas físicas NTAG215 (Fase 7, ADR 0017).
///
/// Entrega las mismas [CardCredentials] que el lector simulado; la API valida
/// número, UID y firma igual que con el QR (regla 10).
class NfcCardReader implements CardReader {
  /// Crea el lector sobre [io].
  const NfcCardReader(this.io);

  /// NFC del dispositivo.
  final NfcChipIo io;

  @override
  String get name => 'NFC';

  @override
  Future<CardCredentials?> read(BuildContext context) => runWithChip(
    context,
    io: io,
    title: 'Acerca la tarjeta',
    message:
        'Acerca la tarjeta o el llavero a la parte trasera del teléfono y '
        'mantenlo quieto.',
    action: readChipCredentials,
  );
}

/// Muestra la hoja "acerca el chip", ejecuta [action] con el chip y la
/// cierra. Devuelve `null` si se canceló; relanza los errores de [action].
Future<T?> runWithChip<T>(
  BuildContext context, {
  required NfcChipIo io,
  required String title,
  required String message,
  required Future<T> Function(ChipTag tag) action,
}) async {
  switch (await io.status()) {
    case NfcStatus.ready:
      break;
    case NfcStatus.disabled:
      throw const CardReadException(
        'El NFC está apagado. Actívalo en los ajustes del teléfono.',
      );
    case NfcStatus.unsupported:
      throw const CardReadException('Este dispositivo no tiene NFC.');
  }
  if (!context.mounted) return null;
  final outcome = await showModalBottomSheet<_Outcome<T>>(
    context: context,
    showDragHandle: true,
    builder: (_) =>
        _ChipSheet<T>(io: io, title: title, message: message, action: action),
  );
  if (outcome == null) return null;
  if (outcome.error case final error?) {
    Error.throwWithStackTrace(error, outcome.stack ?? StackTrace.current);
  }
  return outcome.value;
}

class _Outcome<T> {
  const _Outcome.value(this.value) : error = null, stack = null;
  const _Outcome.error(this.error, this.stack) : value = null;

  final T? value;
  final Object? error;
  final StackTrace? stack;
}

class _ChipSheet<T> extends StatefulWidget {
  const _ChipSheet({
    required this.io,
    required this.title,
    required this.message,
    required this.action,
  });

  final NfcChipIo io;
  final String title;
  final String message;
  final Future<T> Function(ChipTag tag) action;

  @override
  State<_ChipSheet<T>> createState() => _ChipSheetState<T>();
}

class _ChipSheetState<T> extends State<_ChipSheet<T>> {
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _Outcome<T>? outcome;
    try {
      outcome = _Outcome.value(await widget.io.withTag(widget.action));
    } on NfcCancelled {
      outcome = null;
    } on Object catch (error, stack) {
      outcome = _Outcome.error(error, stack);
    }
    _finished = true;
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  void dispose() {
    // Si la hoja se cerró deslizando, se libera el NFC.
    if (!_finished) widget.io.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.contactless_rounded,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => widget.io.cancel(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
