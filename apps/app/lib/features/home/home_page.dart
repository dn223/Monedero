import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/brand.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/providers.dart';

/// Pantalla inicial: presenta la marca, el estado de la API y la selección
/// de rol (los roles se habilitan en las fases 3 a 5).
class HomePage extends ConsumerWidget {
  /// Crea la pantalla inicial.
  const HomePage({super.key});

  /// Ruta de la pantalla.
  static const path = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Brand.logo(size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    Brand.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Brand.tagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _ApiStatusCard(),
                  const SizedBox(height: 24),
                  Text('Ingresar como', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const _RoleButton(
                    icon: Icons.person_rounded,
                    label: 'Titular',
                    pendingPhase: 3,
                  ),
                  const SizedBox(height: 8),
                  const _RoleButton(
                    icon: Icons.point_of_sale_rounded,
                    label: 'Caja',
                    pendingPhase: 4,
                  ),
                  const SizedBox(height: 8),
                  const _RoleButton(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Administración',
                    pendingPhase: 5,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Prototipo académico · ${Brand.organization}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApiStatusCard extends ConsumerWidget {
  const _ApiStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(apiHealthProvider);
    final scheme = Theme.of(context).colorScheme;

    final (
      IconData icon,
      Color color,
      String title,
      String subtitle,
    ) = switch (health) {
      AsyncData(:final value) when value.isOk => (
        Icons.cloud_done_rounded,
        scheme.primary,
        'API conectada',
        'Versión ${value.version}'
            '${value.demoMode ? ' · modo demo activo' : ''}',
      ),
      AsyncError(:final error) => (
        Icons.cloud_off_rounded,
        scheme.error,
        'Sin conexión con la API',
        error is ApiException ? error.message : 'Error inesperado.',
      ),
      _ => (
        Icons.cloud_sync_rounded,
        scheme.onSurfaceVariant,
        'Conectando con la API…',
        AppConfig.apiBaseUrl,
      ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Reintentar',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(apiHealthProvider),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.icon,
    required this.label,
    required this.pendingPhase,
  });

  final IconData icon;
  final String label;
  final int pendingPhase;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Disponible en la fase $pendingPhase',
    child: OutlinedButton.icon(
      onPressed: null,
      icon: Icon(icon),
      label: Text('$label (fase $pendingPhase)'),
    ),
  );
}
