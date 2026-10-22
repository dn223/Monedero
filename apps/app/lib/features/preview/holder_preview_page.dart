import 'package:flutter/material.dart';

import 'live_widgets.dart';
import 'preview_widgets.dart';

/// Vista de diseño del titular: tarjeta, QR, saldo, historial y acciones.
class HolderPreviewPage extends StatelessWidget {
  /// Crea la vista.
  const HolderPreviewPage({super.key});

  /// Ruta.
  static const path = '/titular';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PreviewScaffold(
      title: 'Hola, Ana',
      icon: Icons.person_rounded,
      children: [
        const LiveHolderPanel(),
        const SectionTitle('Mostrar en caja'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 96,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'La caja escanea este código. Contiene el número, el UID '
                    'y la firma de la tarjeta; nunca el saldo.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Mi tarjeta'),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.pin_rounded),
          label: const Text('Cambiar PIN'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () {},
          icon: const Icon(Icons.report_rounded),
          label: const Text('Reportar pérdida'),
        ),
        const SizedBox(height: 8),
        Text(
          'Al reportar la pérdida te enviaremos un código por correo; con él '
          'la tarjeta se bloquea de inmediato y tu saldo queda protegido.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
