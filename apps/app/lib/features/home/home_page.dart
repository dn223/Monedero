import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../brand/brand.dart';
import '../../core/config/server_settings.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/widgets/card_widgets.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/qr.dart';
import '../settings/server_page.dart';

/// Pantalla inicial: la marca, la elección de rol, el estado del servidor
/// y (en la web) el QR para abrir la app en el celular.
class HomePage extends ConsumerWidget {
  /// Crea la pantalla inicial.
  const HomePage({super.key});

  /// Ruta de la pantalla.
  static const path = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wide = Breakpoints.isWide(context);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Brand.tagline,
          style:
              (wide
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        const SizedBox(height: 12),
        Text(
          'Tarjeta prepago recargable del comercio: se recarga en caja, se '
          'gasta en compras y su saldo vive seguro en el servidor.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final roles = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoleRow(
          icon: Icons.person_rounded,
          title: 'Soy titular',
          description: 'Consulta tu saldo, muestra tu QR y paga en caja.',
          route: '/titular',
          session: holderSessionProvider,
        ),
        const SizedBox(height: 8),
        _RoleRow(
          icon: Icons.point_of_sale_rounded,
          title: 'Caja',
          description: 'Lee tarjetas, cobra, recarga y entrega comprobante.',
          route: '/caja',
          session: cashierSessionProvider,
        ),
        const SizedBox(height: 8),
        _RoleRow(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Administración',
          description:
              'Emite tarjetas, autoriza cajas y revisa la conciliación.',
          route: '/admin',
          session: adminSessionProvider,
        ),
      ],
    );

    const sample = VirtualCard(
      number: '9990 •••• •••• 2970',
      holder: 'Tu nombre',
      balanceCents: 2500,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 40 : 20,
                vertical: 20,
              ),
              children: [
                Row(
                  children: [
                    const BrandMark(),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Servidor',
                      onPressed: () => context.go(ServerPage.path),
                      icon: const Icon(Icons.dns_outlined),
                    ),
                  ],
                ),
                SizedBox(height: wide ? 48 : 24),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [intro, const SizedBox(height: 32), roles],
                        ),
                      ),
                      const SizedBox(width: 48),
                      const Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: sample,
                            ),
                            SizedBox(height: 32),
                            _OpenOnPhone(),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  intro,
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: sample,
                  ),
                  const SizedBox(height: 28),
                  roles,
                  const SizedBox(height: 16),
                  const _OpenOnPhone(),
                ],
                const SizedBox(height: 24),
                const _ServerStatus(),
                const SizedBox(height: 8),
                Text(
                  '${Brand.organization}, Gestión de la Calidad del Software. '
                  'Prototipo académico: no maneja dinero real.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleRow extends ConsumerWidget {
  const _RoleRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    required this.session,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
  final NotifierProvider<SessionNotifier, Session?> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final open = ref.watch(session);
    return Card(
      child: InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      open == null
                          ? description
                          : 'Sesión abierta: ${open.fullName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: open == null
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// QR con la dirección de esta página, para abrirla en otro dispositivo
/// (solo en la web y cuando la dirección no es `localhost`).
class _OpenOnPhone extends StatelessWidget {
  const _OpenOnPhone();

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final url = Uri.base.origin;
    final local = Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1';
    if (local) {
      return const InfoPanel(
        icon: Icons.smartphone_rounded,
        child: Text(
          'Para abrirla en el celular o compartirla, levanta el link público '
          'con dart run tool/share.dart (ver docs/exposicion.md).',
        ),
      );
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            QrBox(url, size: 112, semanticLabel: 'QR de esta página'),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ábrela en el celular',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Escanea el código con la cámara. En Android puedes '
                    'instalarla desde el menú del navegador.',
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () =>
                        copyToClipboard(context, url, message: 'Link copiado.'),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text(url, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerStatus extends ConsumerWidget {
  const _ServerStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final health = ref.watch(apiHealthProvider);
    final url = ref.watch(serverUrlProvider);
    final (Color color, String text) = switch (health) {
      AsyncData(:final value) when value.isOk => (
        scheme.primary,
        value.demoMode
            ? 'Servidor conectado, modo demo activo'
            : 'Servidor conectado',
      ),
      AsyncError() => (scheme.error, 'Sin conexión con el servidor'),
      _ => (scheme.outline, 'Conectando con el servidor…'),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: text,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: '\n$url',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: () => ref.invalidate(apiHealthProvider),
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}
