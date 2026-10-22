import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../brand/brand.dart';

/// Datos de ejemplo de las vistas de diseño (aún no conectadas a la API).
abstract final class SampleData {
  /// Número de la tarjeta de ejemplo.
  static const cardNumber = '9990142405712970';

  /// Titular de ejemplo.
  static const holderName = 'Ana López';

  /// Saldo de ejemplo.
  static const balanceCents = 1265;

  /// Movimientos de ejemplo: (tipo, monto, saldo después, fecha).
  static const transactions = [
    ('DEBIT', 735, 1265, 'Hoy 10:42'),
    ('TOP_UP', 2000, 2000, 'Hoy 10:40'),
    ('DEBIT', 450, 0, 'Ayer 17:15'),
    ('TOP_UP', 500, 450, 'Ayer 17:02'),
  ];
}

/// Esqueleto común de las vistas: barra superior, aviso de vista de diseño
/// y contenido centrado con ancho máximo.
class PreviewScaffold extends StatelessWidget {
  /// Crea la vista.
  const PreviewScaffold({
    required this.title,
    required this.icon,
    required this.children,
    this.maxWidth = 520,
    super.key,
  });

  /// Título de la barra.
  final String title;

  /// Ícono del rol.
  final IconData icon;

  /// Contenido.
  final List<Widget> children;

  /// Ancho máximo del contenido.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Inicio',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Brand.logo(size: 28, color: scheme.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 18,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lo marcado "en vivo" usa la API real; '
                          'lo demás es vista de diseño con datos de ejemplo.',
                          style: TextStyle(color: scheme.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de sección.
class SectionTitle extends StatelessWidget {
  /// Crea el título.
  const SectionTitle(this.text, {super.key});

  /// Texto.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Tarjeta visual del monedero.
class VirtualCard extends StatelessWidget {
  /// Crea la tarjeta.
  const VirtualCard({
    required this.number,
    required this.holder,
    required this.balanceCents,
    this.status = 'ACTIVE',
    super.key,
  });

  /// Número completo.
  final String number;

  /// Nombre del titular.
  final String holder;

  /// Saldo en centavos.
  final int balanceCents;

  /// Estado de la tarjeta.
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grouped = [
      for (var i = 0; i < number.length; i += 4) number.substring(i, i + 4),
    ].join(' ');
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: scheme.onPrimary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Brand.logo(size: 28, color: scheme.onPrimary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      Brand.appName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  StatusChip(status, onCard: true),
                ],
              ),
              const Spacer(),
              const Text('Saldo disponible'),
              Text(
                Money.format(balanceCents),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                grouped,
                style: const TextStyle(fontSize: 18, letterSpacing: 2),
              ),
              Text(holder.toUpperCase()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de estado de tarjeta con color según el estado.
class StatusChip extends StatelessWidget {
  /// Crea el chip.
  const StatusChip(this.status, {this.onCard = false, super.key});

  /// `PENDING`, `ACTIVE`, `BLOCKED` o `REPLACED`.
  final String status;

  /// `true` si va sobre la tarjeta de color.
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      'ACTIVE' => (
        'Activa',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      'PENDING' => (
        'Pendiente',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      'BLOCKED' => (
        'Bloqueada',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      _ => (
        'Repuesta',
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onCard ? scheme.onPrimary.withValues(alpha: 0.2) : bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onCard ? scheme.onPrimary : fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Fila de movimiento del historial.
class TransactionTile extends StatelessWidget {
  /// Crea la fila.
  const TransactionTile({
    required this.type,
    required this.amountCents,
    required this.balanceAfterCents,
    required this.when,
    super.key,
  });

  /// Tipo de movimiento.
  final String type;

  /// Monto en centavos.
  final int amountCents;

  /// Saldo después.
  final int balanceAfterCents;

  /// Fecha legible.
  final String when;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final credit = type == 'TOP_UP' || type == 'REPLACEMENT_IN';
    final label = switch (type) {
      'TOP_UP' => 'Recarga en caja',
      'DEBIT' => 'Compra',
      'REPLACEMENT_IN' => 'Saldo trasladado',
      _ => 'Saldo enviado a tarjeta nueva',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: credit
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        child: Icon(
          credit ? Icons.add_rounded : Icons.shopping_bag_outlined,
          color: credit ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(label),
      subtitle: Text('$when · saldo ${Money.format(balanceAfterCents)}'),
      trailing: Text(
        '${credit ? '+' : '−'}${Money.format(amountCents)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: credit ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
  }
}
