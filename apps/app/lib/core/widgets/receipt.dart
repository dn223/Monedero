import 'package:flutter/material.dart';
import 'package:monedero_core/monedero_core.dart';

import '../format.dart';
import '../theme/app_theme.dart';

/// Comprobante de una operación con forma de ticket de caja (bordes
/// dentados), como el que imprime la caja de un supermercado.
class Receipt extends StatelessWidget {
  /// Crea el comprobante a partir de la respuesta de la API.
  const Receipt({
    required this.receipt,
    required this.terminalName,
    this.cardholderName,
    super.key,
  });

  /// Respuesta de recarga, cobro o pago (`type`, `amountCents`,
  /// `balanceAfterCents`, `cardNumberMasked`, `createdAt`, `transactionId`).
  final Map<String, Object?> receipt;

  /// Caja donde se hizo.
  final String terminalName;

  /// Titular, si se conoce.
  final String? cardholderName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topUp = receipt['type'] == 'TOP_UP';
    final id = receipt['transactionId']! as String;
    const paper = Color(0xFFFFFDF7);
    const ink = Color(0xFF1F2421);
    final rows = <(String, String)>[
      ('Tarjeta', receipt['cardNumberMasked']! as String),
      if (cardholderName != null) ('Titular', cardholderName!),
      ('Caja', terminalName),
      ('Fecha', Fmt.dateTime(receipt['createdAt']! as String)),
      ('Operación', id.substring(0, 8).toUpperCase()),
    ];
    return ClipPath(
      clipper: const _TicketClipper(),
      child: ColoredBox(
        color: paper,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(color: ink),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  topUp ? 'Recarga aprobada' : 'Cobro aprobado',
                  style: theme.textTheme.titleLarge?.copyWith(color: ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '${topUp ? '+' : '−'}'
                  '${Money.format(receipt['amountCents']! as int)}',
                  style: AppText.money(
                    theme.textTheme.displaySmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _DashedLine(color: ink),
                const SizedBox(height: 12),
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(label, style: const TextStyle(color: ink)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            value,
                            textAlign: TextAlign.end,
                            style: AppText.money(
                              const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const _DashedLine(color: ink),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        topUp ? 'Saldo nuevo' : 'Saldo restante',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      Money.format(receipt['balanceAfterCents']! as int),
                      style: AppText.money(
                        theme.textTheme.titleLarge?.copyWith(color: ink),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra el [Receipt] en un diálogo con la acción "Nueva operación".
Future<void> showReceipt(
  BuildContext context, {
  required Map<String, Object?> receipt,
  required String terminalName,
  String? cardholderName,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Receipt(
            receipt: receipt,
            terminalName: terminalName,
            cardholderName: cardholderName,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.done_rounded),
            label: const Text('Listo'),
          ),
        ],
      ),
    ),
  ),
);

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final count = (box.maxWidth / 8).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(
              width: 4,
              height: 1,
              child: ColoredBox(color: color.withValues(alpha: 0.4)),
            ),
        ],
      );
    },
  );
}

/// Bordes superior e inferior dentados del ticket.
class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();

  @override
  Path getClip(Size size) {
    const tooth = 8.0;
    final count = (size.width / (tooth * 2)).floor();
    final step = size.width / count;
    final path = Path()..moveTo(0, tooth);
    for (var i = 0; i < count; i++) {
      path
        ..lineTo(i * step + step / 2, 0)
        ..lineTo((i + 1) * step, tooth);
    }
    path.lineTo(size.width, size.height - tooth);
    for (var i = count; i > 0; i--) {
      path
        ..lineTo(i * step - step / 2, size.height)
        ..lineTo((i - 1) * step, size.height - tooth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
