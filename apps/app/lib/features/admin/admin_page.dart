import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/card_widgets.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../auth/login_page.dart';
import 'admin_providers.dart';
import 'admin_sections.dart';
import 'daily_chart.dart';
import 'modules_section.dart';

/// Espacio de administración: inicio de sesión o el panel con resumen,
/// tarjetas, titulares y cajas.
class AdminPage extends ConsumerWidget {
  /// Crea la pantalla.
  const AdminPage({super.key});

  /// Ruta.
  static const path = '/admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider);
    if (session == null) {
      return LoginPage(
        title: 'Administración',
        icon: Icons.admin_panel_settings_rounded,
        heading: 'Administración',
        message:
            'Emite y entrega tarjetas, repón las perdidas, autoriza cajas y '
            'revisa que la contabilidad cuadre.',
        loginPath: '/v1/auth/staff/login',
        sessionProvider: adminSessionProvider,
        demoAccounts: DemoAccounts.admin,
      );
    }
    return const AdminShell();
  }
}

/// Panel de administración con navegación lateral (escritorio) o
/// inferior (celular).
class AdminShell extends ConsumerStatefulWidget {
  /// Crea el panel.
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  static const _sections = [
    (Icons.insights_outlined, Icons.insights_rounded, 'Resumen'),
    (Icons.credit_card_outlined, Icons.credit_card_rounded, 'Tarjetas'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'Titulares'),
    (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'Cajas'),
    (Icons.extension_outlined, Icons.extension_rounded, 'Módulos'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final body = switch (_index) {
      0 => const DashboardSection(),
      1 => const CardsSection(),
      2 => const HoldersSection(),
      3 => const TerminalsSection(),
      _ => const ModulesSection(),
    };
    return RoleScaffold(
      title: 'Administración',
      icon: Icons.admin_panel_settings_rounded,
      maxWidth: 1280,
      actions: [SignOutButton(adminSessionProvider)],
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final (icon, selected, label) in _sections)
                  NavigationDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: label,
                  ),
              ],
            ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final (icon, selected, label) in _sections)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}

/// Resumen: indicadores, conciliación y movimiento de dinero por día.
class DashboardSection extends ConsumerWidget {
  /// Crea la sección.
  const DashboardSection({super.key});

  Future<void> _resetDemo(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Reiniciar la demo',
      message:
          'Se borran todas las tarjetas, titulares, cajas y movimientos, y se '
          'vuelven a sembrar los datos de demostración. Todas las sesiones se '
          'cierran.',
      action: 'Reiniciar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(adminSessionProvider.notifier)
          .run((api, token) => api.post('/v1/admin/demo/reset', token: token));
      // Los usuarios se volvieron a crear: las sesiones anteriores no sirven.
      for (final session in [
        holderSessionProvider,
        cashierSessionProvider,
        adminSessionProvider,
      ]) {
        await ref.read(session.notifier).signOut();
      }
      if (context.mounted) showMessage(context, 'Demo reiniciada.');
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(adminStatsProvider);
    final rec = ref.watch(reconciliationProvider);
    final demo = ref.watch(demoModeProvider);
    void refresh() => ref
      ..invalidate(adminStatsProvider)
      ..invalidate(reconciliationProvider);

    return PageList(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Resumen', style: theme.textTheme.headlineSmall),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (demo)
              TextButton.icon(
                onPressed: () => _resetDemo(context, ref),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reiniciar demo'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        switch (stats) {
          AsyncValue(:final value?) => _Kpis(stats: value),
          AsyncValue(:final error?) => ErrorPanel(error, onRetry: refresh),
          _ => const LinearProgressIndicator(),
        },
        const SectionTitle('Conciliación'),
        switch (rec) {
          AsyncValue(:final value?) => _Reconciliation(data: value),
          AsyncValue(:final error?) => ErrorPanel(error, onRetry: refresh),
          _ => const LinearProgressIndicator(),
        },
        const SectionTitle('Recargas y cobros, últimos 14 días'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: switch (stats) {
              AsyncValue(:final value?) => DailyChart(
                days: (value['daily']! as List).cast<Map<String, Object?>>(),
              ),
              _ => const SizedBox(height: 240),
            },
          ),
        ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.stats});

  final Map<String, Object?> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byStatus = stats['cardsByStatus']! as Map<String, Object?>;
    final active = byStatus['ACTIVE']! as int;
    final total = byStatus.values.fold<int>(0, (s, v) => s + (v! as int));

    Widget tile(String label, String value, {String? note}) => SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(value, style: AppText.money(theme.textTheme.headlineSmall)),
              if (note != null)
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // El saldo en circulación es el dato principal: lo que la empresa
        // debe a los titulares.
        SizedBox(
          width: 280,
          child: Card(
            color: scheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo en circulación',
                    style: TextStyle(color: scheme.onPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Money.format(stats['totalBalanceCents']! as int),
                    style: AppText.money(
                      theme.textTheme.headlineMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'Lo que los titulares pueden gastar',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        tile('Tarjetas activas', '$active', note: 'de $total emitidas'),
        tile(
          'Por entregar o bloqueadas',
          '${(byStatus['PENDING']! as int) + (byStatus['BLOCKED']! as int)}',
          note:
              '${byStatus['PENDING']} por entregar, '
              '${byStatus['BLOCKED']} bloqueadas',
        ),
        tile('Titulares', '${stats['cardholders']}'),
        tile('Cajas activas', '${stats['activeTerminals']}'),
        tile('Movimientos', '${stats['transactions']}', note: 'en el libro'),
      ],
    );
  }
}

/// Estado de la regla 7: saldo de cada tarjeta = suma de sus movimientos.
class _Reconciliation extends StatefulWidget {
  const _Reconciliation({required this.data});

  final Map<String, Object?> data;

  @override
  State<_Reconciliation> createState() => _ReconciliationState();
}

class _ReconciliationState extends State<_Reconciliation> {
  bool _detail = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final scheme = theme.colorScheme;
    final data = widget.data;
    final bad = data['cardsWithDifference']! as int;
    final ok = bad == 0;
    final items = (data['items']! as List).cast<Map<String, Object?>>();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            leading: CircleAvatar(
              backgroundColor: ok ? palette.good : scheme.error,
              child: Icon(
                ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: ok ? palette.onGood : scheme.onError,
              ),
            ),
            title: Text(
              ok
                  ? 'Todo cuadra'
                  : '$bad tarjeta${bad == 1 ? '' : 's'} con diferencia',
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              ok
                  ? 'El saldo de las ${data['cards']} tarjetas es igual a la '
                        'suma de sus movimientos.'
                  : 'Diferencia total '
                        '${Money.format(data['totalDifferenceCents']! as int)}. '
                        'Revisa el detalle.',
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _detail = !_detail),
              child: Text(_detail ? 'Ocultar' : 'Ver detalle'),
            ),
          ),
          if (_detail)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Tarjeta')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Saldo'), numeric: true),
                  DataColumn(label: Text('Suma de movimientos'), numeric: true),
                  DataColumn(label: Text('Diferencia'), numeric: true),
                  DataColumn(label: Text('Movimientos'), numeric: true),
                ],
                rows: [
                  for (final r in items)
                    DataRow(
                      cells: [
                        DataCell(Text(r['cardNumberMasked']! as String)),
                        DataCell(StatusChip(r['status']! as String)),
                        DataCell(Text(Money.format(r['balanceCents']! as int))),
                        DataCell(Text(Money.format(r['ledgerCents']! as int))),
                        DataCell(
                          Text(
                            Money.format(r['differenceCents']! as int),
                            style: TextStyle(
                              color: r['differenceCents'] == 0
                                  ? null
                                  : scheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(Text('${r['transactionCount']}')),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
