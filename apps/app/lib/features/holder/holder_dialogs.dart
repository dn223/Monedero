import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/session/session.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/qr.dart';

/// QR de la tarjeta para que la caja lo escanee (en lugar del chip NFC).
Future<void> showCardQr(BuildContext context, Map<String, Object?> card) {
  final credentials = card['credentials']! as Map<String, Object?>;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Muestra este código en caja'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrBox(
            jsonEncode(credentials),
            size: 240,
            semanticLabel: 'Código QR de la tarjeta',
          ),
          const SizedBox(height: 16),
          Text(
            Fmt.cardNumber(card['number']! as String),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Contiene el número, el UID y la firma de tu tarjeta; nunca el '
            'saldo ni tu PIN.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

/// Campo de PIN de 4 dígitos.
class PinField extends StatelessWidget {
  /// Crea el campo.
  const PinField({
    required this.controller,
    required this.label,
    this.helper,
    this.onSubmitted,
    super.key,
  });

  /// Controlador.
  final TextEditingController controller;

  /// Etiqueta.
  final String label;

  /// Ayuda opcional.
  final String? helper;

  /// Al presionar Enter.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 4,
    onSubmitted: onSubmitted,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      counterText: '',
      prefixIcon: const Icon(Icons.pin_outlined),
    ),
  );
}

/// Pago desde la app del titular en la caja cuyo código escribe.
class PayDialog extends ConsumerStatefulWidget {
  /// Crea el diálogo.
  const PayDialog({super.key});

  @override
  ConsumerState<PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends ConsumerState<PayDialog> {
  final _code = TextEditingController();
  final _amount = TextEditingController();
  final _pin = TextEditingController();
  Object? _error;
  bool _busy = false;

  /// Misma clave mientras se reintenta el mismo pago (regla 5).
  String? _key;
  String? _keyFor;

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
      setState(
        () => _error = const ApiException(
          'Escribe el código de 6 dígitos de la caja y el monto.',
        ),
      );
      return;
    }
    final intent = '$code|$cents|${_pin.text}';
    if (_keyFor != intent) {
      _key = ApiClient.newIdempotencyKey();
      _keyFor = intent;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await ref
          .read(holderSessionProvider.notifier)
          .run(
            (api, token) => api.post(
              '/v1/me/payments',
              token: token,
              idempotencyKey: _key,
              body: {
                'terminalCode': code,
                'amountCents': cents,
                if (_pin.text.isNotEmpty) 'pin': _pin.text,
              },
            ),
          );
      if (mounted) Navigator.of(context).pop(receipt);
    } on ApiException catch (error) {
      // Con respuesta del servidor, la operación terminó: clave nueva.
      if (!error.isNetwork) _keyFor = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pagar en caja'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Escribe el código que muestra la pantalla de la caja y el monto '
            'de tu compra.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Código de caja',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
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
          PinField(
            controller: _pin,
            label: 'PIN',
            helper: r'Solo para pagos de más de $25.00',
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorPanel(_error!),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'Pagando…' : 'Pagar'),
      ),
    ],
  );
}

/// Cambio de PIN: pide el actual y el nuevo dos veces.
class ChangePinDialog extends ConsumerStatefulWidget {
  /// Crea el diálogo.
  const ChangePinDialog({super.key});

  @override
  ConsumerState<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends ConsumerState<ChangePinDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  Object? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length != 4 || _next.text != _again.text) {
      setState(
        () => _error = const ApiException(
          'El PIN nuevo debe tener 4 dígitos y coincidir las dos veces.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(holderSessionProvider.notifier)
          .run(
            (api, token) => api.put(
              '/v1/me/pin',
              token: token,
              body: {'currentPin': _current.text, 'newPin': _next.text},
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cambiar PIN'),
    content: SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PinField(controller: _current, label: 'PIN actual'),
          const SizedBox(height: 12),
          PinField(controller: _next, label: 'PIN nuevo'),
          const SizedBox(height: 12),
          PinField(
            controller: _again,
            label: 'Repite el PIN nuevo',
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorPanel(_error!),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: _busy ? null : _submit,
        child: const Text('Cambiar PIN'),
      ),
    ],
  );
}

/// Reporte de pérdida en dos pasos: enviar código al correo y confirmarlo.
/// Con el código correcto la tarjeta queda bloqueada de inmediato.
class LossReportDialog extends ConsumerStatefulWidget {
  /// Crea el diálogo para la tarjeta [cardId].
  const LossReportDialog({required this.cardId, super.key});

  /// Tarjeta que se reporta.
  final String cardId;

  @override
  ConsumerState<LossReportDialog> createState() => _LossReportDialogState();
}

class _LossReportDialogState extends ConsumerState<LossReportDialog> {
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _demoCode;
  Object? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _step(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _step(() async {
    final body = await ref
        .read(holderSessionProvider.notifier)
        .run(
          (api, token) => api.post(
            '/v1/me/cards/${widget.cardId}/loss-reports',
            token: token,
          ),
        );
    setState(() {
      _sent = true;
      _demoCode = body['demoCode'] as String?;
    });
  });

  Future<void> _confirm() => _step(() async {
    await ref
        .read(holderSessionProvider.notifier)
        .run(
          (api, token) => api.post(
            '/v1/me/cards/${widget.cardId}/loss-reports/confirm',
            token: token,
            body: {'code': _code.text.trim()},
          ),
        );
    if (mounted) Navigator.of(context).pop(true);
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.report_outlined, color: scheme.error),
      title: const Text('Reportar pérdida'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _sent
                  ? 'Te enviamos un código de 6 dígitos a tu correo. '
                        'Escríbelo para bloquear la tarjeta.'
                  : 'Para confirmar que eres tú, te enviaremos un código a tu '
                        'correo. Al confirmarlo, la tarjeta se bloquea al '
                        'instante y tu saldo queda protegido hasta la '
                        'reposición.',
            ),
            if (_sent) ...[
              const SizedBox(height: 16),
              if (_demoCode != null) ...[
                DemoCodeBanner(
                  code: _demoCode!,
                  onUse: () => _code.text = _demoCode!,
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _confirm(),
                decoration: const InputDecoration(
                  labelText: 'Código del correo',
                  counterText: '',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorPanel(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            minimumSize: const Size(0, 44),
          ),
          onPressed: _busy ? null : (_sent ? _confirm : _sendCode),
          child: Text(_sent ? 'Bloquear tarjeta' : 'Enviar código'),
        ),
      ],
    );
  }
}
