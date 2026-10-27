import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../brand/brand.dart';
import '../format.dart';
import '../theme/app_theme.dart';

/// Tarjeta virtual del monedero, con la proporción de una tarjeta física
/// (ISO 7810, 85.6 × 54 mm), su chip simulado y el saldo como protagonista.
class VirtualCard extends StatelessWidget {
  /// Crea la tarjeta.
  const VirtualCard({
    required this.number,
    required this.holder,
    required this.balanceCents,
    this.status = 'ACTIVE',
    this.staleSince,
    super.key,
  });

  /// Número completo o enmascarado.
  final String number;

  /// Nombre del titular.
  final String holder;

  /// Saldo en centavos.
  final int balanceCents;

  /// Estado de la tarjeta (`ACTIVE`, `PENDING`, `BLOCKED`, `REPLACED`).
  final String status;

  /// Si el saldo viene de la caché (sin conexión), desde cuándo.
  final DateTime? staleSince;

  @override
  Widget build(BuildContext context) {
    // Colores fijos de la marca (no los del tema): la tarjeta se ve igual
    // que una física en modo claro y oscuro.
    final active = status == 'ACTIVE' || status == 'PENDING';
    final colors = active
        ? [Brand.seedColor, Color.lerp(Brand.seedColor, Colors.black, 0.5)!]
        : [const Color(0xFF6F7973), const Color(0xFF3A403C)];
    const ink = Colors.white;
    final shown = RegExp(r'^\d{16}$').hasMatch(number)
        ? Fmt.cardNumber(number)
        : number;

    return Semantics(
      label:
          'Tarjeta $shown de $holder, saldo ${Money.format(balanceCents)}, '
          '${StatusChip.labelOf(status)}',
      child: AspectRatio(
        aspectRatio: 85.6 / 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CustomPaint(
              painter: _RingsPainter(ink.withValues(alpha: 0.07)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: DefaultTextStyle(
                  style: TextStyle(color: ink),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final scale = (box.maxWidth / 340).clamp(0.75, 1.3);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Brand.logo(size: 24 * scale, color: ink),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  Brand.appName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17 * scale,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (staleSince != null)
                                const _Pill('No actualizado')
                              else
                                _Pill(StatusChip.labelOf(status)),
                            ],
                          ),
                          SizedBox(height: 14 * scale),
                          Row(
                            children: [
                              _Chip(scale: scale),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.contactless_outlined,
                                color: ink.withValues(alpha: 0.8),
                                size: 22 * scale,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            'Saldo disponible',
                            style: TextStyle(
                              fontSize: 12 * scale,
                              color: ink.withValues(alpha: 0.8),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              Money.format(balanceCents),
                              style: AppText.money(
                                TextStyle(
                                  fontSize: 34 * scale,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              shown,
                              style: AppText.money(
                                TextStyle(
                                  fontSize: 17 * scale,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            holder.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12 * scale,
                              letterSpacing: 1.2,
                              color: ink.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de contacto dibujado (en la Fase 7 será un chip NFC real).
class _Chip extends StatelessWidget {
  const _Chip({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) => Container(
    width: 38 * scale,
    height: 28 * scale,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: const LinearGradient(
        colors: [Color(0xFFF3D98B), Color(0xFFC9A54A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(painter: _ChipLinesPainter()),
  );
}

class _ChipLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x66704F10)
      ..strokeWidth = 1;
    final w = size.width;
    final h = size.height;
    canvas
      ..drawLine(Offset(0, h / 3), Offset(w, h / 3), paint)
      ..drawLine(Offset(0, 2 * h / 3), Offset(w, 2 * h / 3), paint)
      ..drawLine(Offset(w / 2, 0), Offset(w / 2, h / 3), paint)
      ..drawLine(Offset(w / 2, 2 * h / 3), Offset(w / 2, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Anillos concéntricos tenues en la esquina, como el borde de una moneda.
class _RingsPainter extends CustomPainter {
  _RingsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    final center = Offset(size.width * 1.02, size.height * 0.05);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, size.width * 0.16 * i, paint);
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.8),
      math.pi * 0.5,
      math.pi * 0.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = DefaultTextStyle.of(context).style.color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Chip de estado de tarjeta con color e ícono según el estado (nunca solo
/// color).
class StatusChip extends StatelessWidget {
  /// Crea el chip.
  const StatusChip(this.status, {super.key});

  /// `PENDING`, `ACTIVE`, `BLOCKED` o `REPLACED`.
  final String status;

  /// Nombre del estado en español.
  static String labelOf(String status) => switch (status) {
    'ACTIVE' => 'Activa',
    'PENDING' => 'Por entregar',
    'BLOCKED' => 'Bloqueada',
    'REPLACED' => 'Repuesta',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, bg, fg) = switch (status) {
      'ACTIVE' => (
        Icons.check_circle_rounded,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      'PENDING' => (
        Icons.schedule_rounded,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      'BLOCKED' => (
        Icons.block_rounded,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      _ => (
        Icons.swap_horiz_rounded,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            labelOf(status),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de movimiento del historial.
class TransactionTile extends StatelessWidget {
  /// Crea la fila a partir del JSON de un movimiento de la API.
  const TransactionTile(this.item, {this.subtitle, super.key});

  /// Movimiento (`type`, `amountCents`, `balanceAfterCents`, `createdAt`).
  final Map<String, Object?> item;

  /// Texto opcional en lugar de "fecha · saldo".
  final String? subtitle;

  /// `true` si el tipo suma saldo.
  static bool isCredit(String type) =>
      type == 'TOP_UP' || type == 'REPLACEMENT_IN';

  /// Nombre del tipo de movimiento.
  static String labelOf(String type) => switch (type) {
    'TOP_UP' => 'Recarga en caja',
    'DEBIT' => 'Compra',
    'REPLACEMENT_IN' => 'Saldo recibido de la tarjeta anterior',
    'REPLACEMENT_OUT' => 'Saldo enviado a la tarjeta nueva',
    _ => type,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = item['type']! as String;
    final credit = isCredit(type);
    final amount = item['amountCents']! as int;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: credit
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        child: Icon(switch (type) {
          'TOP_UP' => Icons.add_rounded,
          'DEBIT' => Icons.shopping_bag_outlined,
          _ => Icons.swap_horiz_rounded,
        }, color: credit ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
      ),
      title: Text(labelOf(type)),
      subtitle: Text(
        subtitle ??
            '${Fmt.dateTime(item['createdAt']! as String)}, saldo '
                '${Money.format(item['balanceAfterCents']! as int)}',
      ),
      trailing: Text(
        '${credit ? '+' : '−'}${Money.format(amount)}',
        style: AppText.money(
          Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: credit ? scheme.primary : scheme.onSurface),
        ),
      ),
    );
  }
}
