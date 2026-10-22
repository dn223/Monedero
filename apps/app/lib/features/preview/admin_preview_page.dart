import 'package:flutter/material.dart';
import 'package:monedero_core/monedero_core.dart';

import 'preview_widgets.dart';

/// Vista de diseño de administración: resumen, conciliación, tarjetas y
/// terminales.
class AdminPreviewPage extends StatelessWidget {
  /// Crea la vista.
  const AdminPreviewPage({super.key});

  /// Ruta.
  static const path = '/admin';

  static const _cards = [
    ('9990142405712970', 'Ana López', 'ACTIVE', 1265),
    ('9990287711230458', 'Bruno Pérez', 'ACTIVE', 1500),
    ('9990553019846627', 'Carla Méndez', 'PENDING', 0),
    ('9990901277341185', 'Diego Ramos', 'BLOCKED', 4200),
    ('9990664100982213', 'Diego Ramos', 'REPLACED', 0),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = _cards.fold<int>(0, (s, c) => s + c.$4);
    return PreviewScaffold(
      title: 'Administración',
      icon: Icons.admin_panel_settings_rounded,
      maxWidth: 900,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi(
              context,
              'Tarjetas',
              '${_cards.length}',
              Icons.credit_card_rounded,
            ),
            _kpi(
              context,
              'Saldo en circulación',
              Money.format(total),
              Icons.account_balance_wallet_rounded,
            ),
            _kpi(
              context,
              'Diferencia de conciliación',
              Money.format(0),
              Icons.verified_rounded,
              good: true,
            ),
            _kpi(
              context,
              'Terminales activos',
              '2',
              Icons.point_of_sale_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Emitir tarjeta'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.autorenew_rounded),
              label: const Text('Reponer tarjeta'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reiniciar demo'),
            ),
          ],
        ),
        const SectionTitle('Tarjetas y conciliación'),
        const TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Buscar por número, titular o correo',
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Tarjeta')),
                DataColumn(label: Text('Titular')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Saldo'), numeric: true),
                DataColumn(label: Text('Suma de movimientos'), numeric: true),
                DataColumn(label: Text('Diferencia'), numeric: true),
              ],
              rows: [
                for (final (number, holder, status, cents) in _cards)
                  DataRow(
                    cells: [
                      DataCell(Text(CardNumber.masked(number))),
                      DataCell(Text(holder)),
                      DataCell(StatusChip(status)),
                      DataCell(Text(Money.format(cents))),
                      DataCell(Text(Money.format(cents))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                            Text(' ${Money.format(0)}'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SectionTitle('Terminales'),
        Card(
          child: Column(
            children: [
              for (final (name, last, active) in [
                ('Caja 1', 'hace 2 min', true),
                ('Caja 2', 'hace 1 h', true),
                ('Caja móvil (revocada)', 'hace 3 días', false),
              ])
                ListTile(
                  leading: Icon(
                    Icons.point_of_sale_rounded,
                    color: active ? scheme.primary : scheme.outline,
                  ),
                  title: Text(name),
                  subtitle: Text('Última conexión: $last'),
                  trailing: active
                      ? TextButton(
                          onPressed: () {},
                          child: const Text('Revocar'),
                        )
                      : Text('Revocada', style: text.bodySmall),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpi(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool good = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      child: Card(
        color: good ? scheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
