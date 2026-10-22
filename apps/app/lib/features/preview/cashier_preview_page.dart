import 'package:flutter/material.dart';
import 'package:monedero_core/monedero_core.dart';

import 'preview_widgets.dart';

/// Vista de diseño de la caja: leer tarjeta, cobrar, recargar y comprobante.
class CashierPreviewPage extends StatefulWidget {
  /// Crea la vista.
  const CashierPreviewPage({super.key});

  /// Ruta.
  static const path = '/caja';

  @override
  State<CashierPreviewPage> createState() => _CashierPreviewPageState();
}

class _CashierPreviewPageState extends State<CashierPreviewPage> {
  int _readMode = 0;
  int _topUpCents = 2000;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PreviewScaffold(
      title: 'Caja 1',
      icon: Icons.point_of_sale_rounded,
      children: [
        const SectionTitle('1. Acercar la tarjeta'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: Text('Escanear QR'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.list_rounded),
              label: Text('Lista demo'),
            ),
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.keyboard_rounded),
              label: Text('Número'),
            ),
          ],
          selected: {_readMode},
          onSelectionChanged: (s) => setState(() => _readMode = s.first),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.verified_rounded, color: scheme.primary),
            ),
            title: const Text(SampleData.holderName),
            subtitle: Text(
              '${CardNumber.masked(SampleData.cardNumber)} · firma válida',
            ),
            trailing: Text(
              Money.format(SampleData.balanceCents),
              style: text.titleMedium,
            ),
          ),
        ),
        const SectionTitle('2. Cobrar'),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Monto',
            prefixText: r'$ ',
            hintText: '7.35',
            helperText: r'Más de $25.00 pide el PIN del titular',
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.shopping_cart_checkout_rounded),
          label: const Text('Cobrar'),
        ),
        const SectionTitle('3. Recargar'),
        Wrap(
          spacing: 8,
          children: [
            for (final cents in [500, 1000, 2000])
              ChoiceChip(
                label: Text(Money.format(cents)),
                selected: _topUpCents == cents,
                onSelected: (_) => setState(() => _topUpCents = cents),
              ),
            ChoiceChip(
              label: const Text(r'Otro múltiplo de $5'),
              selected: _topUpCents == 0,
              onSelected: (_) => setState(() => _topUpCents = 0),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_card_rounded),
          label: Text(
            _topUpCents == 0
                ? 'Recargar'
                : 'Recargar ${Money.format(_topUpCents)}',
          ),
        ),
        const SectionTitle('Comprobante'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: scheme.primary,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text('Cobro aprobado', style: text.titleMedium),
                const Divider(height: 24),
                _row('Tarjeta', CardNumber.masked(SampleData.cardNumber)),
                _row('Monto', Money.format(735)),
                _row('Saldo restante', Money.format(1265)),
                _row('Caja', 'Caja 1 · Cajero Demo'),
              ],
            ),
          ),
        ),
        const SectionTitle('Mensajes de error claros'),
        _error(
          context,
          Icons.money_off_rounded,
          'Saldo insuficiente',
          r'La tarjeta tiene $12.65; el cobro es de $15.00.',
        ),
        _error(
          context,
          Icons.block_rounded,
          'Tarjeta bloqueada',
          'El titular reportó la pérdida de esta tarjeta.',
        ),
        _error(
          context,
          Icons.gpp_bad_rounded,
          'Tarjeta no válida',
          'El número, el UID o la firma no coinciden.',
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label)),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Widget _error(
    BuildContext context,
    IconData icon,
    String title,
    String body,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(icon, color: scheme.onErrorContainer),
        title: Text(title, style: TextStyle(color: scheme.onErrorContainer)),
        subtitle: Text(body, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}
