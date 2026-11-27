import 'package:flutter/material.dart';
import 'package:monedero_core/monedero_core.dart';

import '../core/widgets/qr.dart';
import 'card_reader.dart';

/// Formas de simular la lectura mientras no hay tarjetas físicas.
enum SimulatedReadMode {
  /// Escanear con la cámara el QR que muestra la app del titular.
  camera('Escanear QR', Icons.qr_code_scanner_rounded),

  /// Elegir de la lista de tarjetas de demostración (solo modo demo).
  demoList('Lista', Icons.list_alt_rounded),

  /// Escribir el número (en modo demo) o pegar el contenido del QR.
  manual('Número', Icons.keyboard_alt_outlined);

  const SimulatedReadMode(this.label, this.icon);

  /// Nombre del modo.
  final String label;

  /// Ícono del modo.
  final IconData icon;
}

/// Lector simulado (ADR 0003): obtiene las credenciales de un QR, de la
/// lista demo o de lo que escribe el cajero.
class SimulatedCardReader implements CardReader {
  /// Crea el lector en [mode]. [loadDemoCards] trae las tarjetas activas de
  /// demostración (con sus credenciales) desde la API.
  const SimulatedCardReader({required this.mode, required this.loadDemoCards});

  /// Modo de lectura.
  final SimulatedReadMode mode;

  /// Tarjetas de demostración, o lista vacía fuera de modo demo.
  final Future<List<Map<String, Object?>>> Function() loadDemoCards;

  @override
  String get name => mode.label;

  @override
  Future<CardCredentials?> read(BuildContext context) async {
    switch (mode) {
      case SimulatedReadMode.camera:
        final raw = await scanQr(context, title: 'Escanea el QR de la tarjeta');
        if (raw == null) return null;
        return QrPayloads.card(raw) ??
            (throw const CardReadException(
              'Ese QR no es de una tarjeta. Pide al titular que abra '
              '"Mostrar mi código QR".',
            ));
      case SimulatedReadMode.demoList:
        final cards = await loadDemoCards();
        if (!context.mounted) return null;
        return _pickFromDemo(context, cards);
      case SimulatedReadMode.manual:
        if (!context.mounted) return null;
        final raw = await showDialog<String>(
          context: context,
          builder: (_) => const _ManualDialog(),
        );
        if (raw == null) return null;
        final fromQr = QrPayloads.card(raw);
        if (fromQr != null) return fromQr;
        final number = raw.replaceAll(RegExp(r'\s'), '');
        if (!CardNumber.isValid(number)) {
          throw const CardReadException(
            'Número no válido: deben ser 16 dígitos con dígito verificador.',
          );
        }
        // Solo con el número no hay UID ni firma: en modo demo se buscan
        // en la lista; en un servidor real hace falta el QR o el chip.
        final match = (await loadDemoCards()).where(
          (c) => c['number'] == number,
        );
        if (match.isEmpty) {
          throw const CardReadException(
            'No hay una tarjeta activa con ese número.',
          );
        }
        return CardCredentials.fromJson(
          match.first['credentials']! as Map<String, Object?>,
        );
    }
  }

  Future<CardCredentials?> _pickFromDemo(
    BuildContext context,
    List<Map<String, Object?>> cards,
  ) async {
    if (!context.mounted) return null;
    if (cards.isEmpty) {
      throw const CardReadException(
        'Todavía no hay tarjetas activas. Administración las emite y '
        'entrega.',
      );
    }
    final picked = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Tarjetas activas'),
              subtitle: Text('Simula acercar una de estas tarjetas.'),
            ),
            for (final c in cards)
              ListTile(
                leading: const Icon(Icons.credit_card_rounded),
                title: Text(c['cardholderName']! as String),
                subtitle: Text(c['numberMasked']! as String),
                trailing: Text(Money.format(c['balanceCents']! as int)),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return null;
    return CardCredentials.fromJson(
      picked['credentials']! as Map<String, Object?>,
    );
  }
}

class _ManualDialog extends StatefulWidget {
  const _ManualDialog();

  @override
  State<_ManualDialog> createState() => _ManualDialogState();
}

class _ManualDialogState extends State<_ManualDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Escribir tarjeta'),
    content: SizedBox(
      width: 380,
      child: TextField(
        controller: _text,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        decoration: const InputDecoration(
          labelText: 'Número de 16 dígitos o contenido del QR',
          helperText: 'Los 16 dígitos de la tarjeta.',
          helperMaxLines: 2,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () => Navigator.of(context).pop(_text.text),
        child: const Text('Leer'),
      ),
    ],
  );
}
