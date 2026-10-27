import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/modules.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';

/// Módulos de la aplicación (`GET /v1/modules`), con quién los cambió.
final adminModulesProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
      final body = await ref.watch(apiClientProvider).get('/v1/modules');
      return (body['items']! as List).cast<Map<String, Object?>>();
    });

/// Módulos: encender o apagar partes de la aplicación.
///
/// El cambio aplica de inmediato para todos: la app del titular oculta la
/// función en su siguiente actualización y la API la rechaza con
/// `MODULE_DISABLED` (ver docs/adr/0014).
class ModulesSection extends ConsumerStatefulWidget {
  /// Crea la sección.
  const ModulesSection({super.key});

  @override
  ConsumerState<ModulesSection> createState() => _ModulesSectionState();
}

class _ModulesSectionState extends ConsumerState<ModulesSection> {
  final _busy = <String>{};

  static IconData _icon(String key) => switch (AppModule.fromKey(key)) {
    AppModule.assistant => Icons.support_agent_rounded,
    AppModule.selfRegistration => Icons.person_add_alt_rounded,
    AppModule.holderPayments => Icons.point_of_sale_rounded,
    AppModule.cardQr => Icons.qr_code_2_rounded,
    AppModule.pinChange => Icons.pin_outlined,
    null => Icons.extension_rounded,
  };

  static String _subtitle(Map<String, Object?> m) {
    final by = m['updatedByName'];
    if (by is! String) return m['description']! as String;
    return '${m['description']}\nÚltimo cambio: '
        '${Fmt.dateTime(m['updatedAt']! as String)} · $by';
  }

  Future<void> _toggle(Map<String, Object?> module, bool enabled) async {
    final key = module['key']! as String;
    setState(() => _busy.add(key));
    try {
      await ref
          .read(adminSessionProvider.notifier)
          .run(
            (api, token) => api.put(
              '/v1/admin/modules/$key',
              body: {'enabled': enabled},
              token: token,
            ),
          );
      ref
        ..invalidate(adminModulesProvider)
        ..invalidate(modulesProvider);
      if (mounted) {
        showMessage(
          context,
          '${module['name']}: ${enabled ? 'activado' : 'desactivado'}.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) showMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modules = ref.watch(adminModulesProvider);
    final active =
        modules.value?.where((m) => m['enabled'] == true).length ?? 0;
    return PageList(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Módulos', style: theme.textTheme.headlineSmall),
            ),
            if (modules.value case final list?)
              Text(
                '$active de ${list.length} activos',
                style: theme.textTheme.labelLarge,
              ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: () => ref.invalidate(adminModulesProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const InfoPanel(
          icon: Icons.toggle_on_outlined,
          child: Text(
            'Activa o desactiva partes de la app. El cambio aplica al instante '
            'para todos los usuarios y la API lo hace cumplir: un módulo '
            'apagado no se puede usar aunque alguien llame a su ruta.',
          ),
        ),
        const SectionTitle('App del titular'),
        switch (modules) {
          AsyncValue(:final value?) => Card(
            child: Column(
              children: [
                for (final (i, m) in value.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(_icon(m['key']! as String)),
                    title: Text(m['name']! as String),
                    subtitle: Text(_subtitle(m)),
                    isThreeLine: m['updatedByName'] != null,
                    value: m['enabled'] == true,
                    onChanged: _busy.contains(m['key'])
                        ? null
                        : (v) => _toggle(m, v),
                  ),
                ],
              ],
            ),
          ),
          AsyncValue(:final error?) => ErrorPanel(
            error,
            onRetry: () => ref.invalidate(adminModulesProvider),
          ),
          _ => const LinearProgressIndicator(),
        },
        const SectionTitle('Siempre activos'),
        const InfoPanel(
          icon: Icons.lock_outline_rounded,
          child: Text(
            'Cobros y recargas en caja, reporte de pérdida y reposición no se '
            'pueden apagar: protegen el dinero de los titulares.',
          ),
        ),
      ],
    );
  }
}
