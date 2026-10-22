import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import 'demo_providers.dart';
import 'preview_widgets.dart';

/// Caja en vivo: muestra el código de caja y los pagos recibidos, que se
/// refrescan cada 3 segundos.
class LiveCashierPanel extends ConsumerStatefulWidget {
  /// Crea el panel.
  const LiveCashierPanel({super.key});

  @override
  ConsumerState<LiveCashierPanel> createState() => _LiveCashierPanelState();
}

class _LiveCashierPanelState extends ConsumerState<LiveCashierPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => ref.invalidate(terminalActivityProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(cashierSessionProvider);
    final activity = ref.watch(terminalActivityProvider);

    return session.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => _errorCard(context, e),
      data: (s) {
        final code = s['payCode']! as String;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Código de caja',
                      style: text.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${code.substring(0, 3)} ${code.substring(3)}',
                      style: text.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '${s['name']} · el titular escribe este código en su app '
                      'para pagar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Pagos recibidos (en vivo)'),
            activity.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => _errorCard(context, e),
              data: (items) => items.isEmpty
                  ? const Text('Aún no hay pagos en esta caja.')
                  : Column(
                      children: [
                        for (final t in items)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.check_circle_rounded,
                                color: scheme.primary,
                              ),
                              title: Text(
                                '${t['type'] == 'TOP_UP' ? 'Recarga' : 'Pago'}'
                                ' de ${t['cardholderName']}',
                              ),
                              subtitle: Text(
                                '${t['cardNumberMasked']} · saldo '
                                '${Money.format(t['balanceAfterCents']! as int)}',
                              ),
                              trailing: Text(
                                Money.format(t['amountCents']! as int),
                                style: text.titleMedium,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Titular en vivo: tarjeta y movimientos reales, y botón "Pagar en caja".
class LiveHolderPanel extends ConsumerWidget {
  /// Crea el panel.
  const LiveHolderPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(holderCardProvider);
    return data.when(
      skipLoadingOnRefresh: true,
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => _errorCard(context, e),
      data: (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VirtualCard(
            number: d.card['number']! as String,
            holder: d.card['cardholderName']! as String,
            balanceCents: d.card['balanceCents']! as int,
            status: d.card['status']! as String,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pay(context, ref),
            icon: const Icon(Icons.point_of_sale_rounded),
            label: const Text('Pagar en caja'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(holderCardProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar saldo'),
          ),
          const SectionTitle('Movimientos'),
          if (d.items.isEmpty) const Text('Sin movimientos todavía.'),
          for (final t in d.items.take(8))
            TransactionTile(
              type: t['type']! as String,
              amountCents: t['amountCents']! as int,
              balanceAfterCents: t['balanceAfterCents']! as int,
              when: _time(t['createdAt']! as String),
            ),
        ],
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _PayDialog(),
    );
    if (result == null || !context.mounted) return;
    ref.invalidate(holderCardProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pago aprobado: ${Money.format(result['amountCents']! as int)}. '
          'Saldo: ${Money.format(result['balanceAfterCents']! as int)}. '
          'Te enviamos el aviso por correo.',
        ),
      ),
    );
  }

  static String _time(String iso) {
    final t = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }
}

class _PayDialog extends ConsumerStatefulWidget {
  const _PayDialog();

  @override
  ConsumerState<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends ConsumerState<_PayDialog> {
  final _code = TextEditingController();
  final _amount = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _amount.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cents = Money.parseCents(_amount.text);
    final code = _code.text.replaceAll(' ', '');
    if (code.length != 6 || cents == null || cents <= 0) {
      setState(() => _error = 'Escribe el código de 6 dígitos y un monto.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref.read(holderTokenProvider.future);
      final receipt = await ref
          .read(apiClientProvider)
          .post(
            '/v1/me/payments',
            token: token,
            idempotent: true,
            body: {
              'terminalCode': code,
              'amountCents': cents,
              if (_pin.text.isNotEmpty) 'pin': _pin.text,
            },
          );
      if (mounted) Navigator.of(context).pop(receipt);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = switch (e.apiError?.code) {
          ApiErrorCode.insufficientFunds => 'Saldo insuficiente.',
          ApiErrorCode.pinRequired =>
            r'Los pagos mayores de $25.00 requieren tu PIN.',
          ApiErrorCode.invalidPin => 'PIN incorrecto.',
          ApiErrorCode.notFound => 'Código de caja no válido.',
          ApiErrorCode.cardNotActive => 'Tu tarjeta no está activa.',
          _ => e.message,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pagar en caja'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Código de caja'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto',
            prefixText: r'$ ',
            hintText: '7.35',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: r'PIN (solo si es más de $25)',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'Pagando…' : 'Pagar'),
      ),
    ],
  );
}

Widget _errorCard(BuildContext context, Object error) {
  final scheme = Theme.of(context).colorScheme;
  return Card(
    color: scheme.errorContainer,
    child: ListTile(
      leading: Icon(Icons.cloud_off_rounded, color: scheme.onErrorContainer),
      title: Text(
        'Sin conexión con la API',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
      subtitle: Text(
        error is ApiException ? error.message : 'Error inesperado.',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    ),
  );
}
