import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../card_reader/card_reader.dart';
import '../../card_reader/simulated_card_reader.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/card_widgets.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/qr.dart';
import '../../core/widgets/receipt.dart';
import 'cashier_providers.dart';

/// Espacio de la caja: se abre con el código que entregó administración y,
/// abierta, muestra el mostrador para leer tarjetas, cobrar y recargar.
class CashierPage extends ConsumerWidget {
  /// Crea la pantalla.
  const CashierPage({super.key});

  /// Ruta.
  static const path = '/caja';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cashierSessionProvider);
    final terminal = ref.watch(terminalProvider);
    if (session == null || terminal == null) return const CashierCodePage();
    return CashierDesk(session: session, terminal: terminal);
  }
}

/// Abre la caja con su código de acceso (o el QR que lo contiene).
class CashierCodePage extends ConsumerStatefulWidget {
  /// Crea la pantalla.
  const CashierCodePage({super.key});

  @override
  ConsumerState<CashierCodePage> createState() => _CashierCodePageState();
}

class _CashierCodePageState extends ConsumerState<CashierCodePage> {
  final _code = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _open(String raw) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(terminalProvider.notifier).open(raw);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final raw = await scanQr(context, title: 'Escanea el QR de la caja');
    if (raw != null) await _open(raw);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoleScaffold(
      title: 'Caja',
      icon: Icons.point_of_sale_rounded,
      maxWidth: 520,
      body: PageList(
        children: [
          const SizedBox(height: 8),
          Text('Abrir caja', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Escribe el código de la caja. Administración lo genera en Cajas, '
            'con el botón "Nueva caja".',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 2),
            decoration: const InputDecoration(
              labelText: 'Código de la caja',
              hintText: 'K7M4-Q2XP-HT9W',
              prefixIcon: Icon(Icons.key_rounded),
            ),
            onSubmitted: _busy ? null : _open,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(_error!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : () => _open(_code.text),
            child: Text(_busy ? 'Abriendo…' : 'Abrir caja'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Escanear QR de la caja'),
          ),
        ],
      ),
    );
  }
}

/// Mostrador de la caja.
class CashierDesk extends ConsumerStatefulWidget {
  /// Crea el mostrador para [session] en la caja [terminal].
  const CashierDesk({required this.session, required this.terminal, super.key});

  /// Sesión del cajero.
  final Session session;

  /// Caja vinculada.
  final TerminalLink terminal;

  @override
  ConsumerState<CashierDesk> createState() => _CashierDeskState();
}

enum _Operation { debit, topUp }

class _CashierDeskState extends ConsumerState<CashierDesk> {
  final _amount = TextEditingController();
  final _pin = TextEditingController();
  Timer? _timer;

  SimulatedReadMode _mode = SimulatedReadMode.demoList;
  _Operation _operation = _Operation.debit;
  int? _topUpCents = 1000;

  /// Credenciales leídas y lo que la API respondió al leerlas.
  CardCredentials? _card;
  Map<String, Object?>? _cardInfo;

  bool _busy = false;
  Object? _error;

  /// Misma `Idempotency-Key` mientras se reintenta la misma operación.
  String? _key;
  String? _keyFor;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => ref.invalidate(terminalActivityProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amount.dispose();
    _pin.dispose();
    super.dispose();
  }

  CardReader get _reader => SimulatedCardReader(
    mode: _mode,
    loadDemoCards: () => ref.read(cashierApiProvider).demoCards(),
  );

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } on CardReadException catch (error) {
      if (mounted) setState(() => _error = ApiException(error.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readCard() => _guard(() async {
    final card = await _reader.read(context);
    if (card == null) return;
    await _lookup(card);
  });

  Future<void> _lookup(CardCredentials card) async {
    final info = await ref
        .read(cashierApiProvider)
        .call(
          (api, token, terminal) => api.post(
            '/v1/cards/read',
            token: token,
            terminal: terminal,
            body: {'card': card.toJson()},
          ),
        );
    setState(() {
      _card = card;
      _cardInfo = info;
      _pin.clear();
    });
  }

  void _clearCard() => setState(() {
    _card = null;
    _cardInfo = null;
    _error = null;
    _pin.clear();
  });

  int? get _cents => _operation == _Operation.topUp && _topUpCents != null
      ? _topUpCents
      : Money.parseCents(_amount.text);

  bool get _needsPin =>
      _operation == _Operation.debit &&
      (_cents ?? 0) > ((_cardInfo?['pinRequiredAboveCents'] as int?) ?? 2500);

  Future<void> _submit() async {
    final card = _card;
    final cents = _cents;
    if (card == null) return;
    if (cents == null || cents <= 0) {
      setState(() => _error = const ApiException('Escribe un monto válido.'));
      return;
    }
    if (_operation == _Operation.topUp && !Money.isValidTopUp(cents)) {
      setState(
        () => _error = const ApiException(
          r'Las recargas son múltiplos de $5.00 (5, 10, 15…).',
        ),
      );
      return;
    }
    if (_needsPin && _pin.text.length != 4) {
      setState(
        () => _error = const ApiException(
          'Pide al titular que escriba su PIN de 4 dígitos.',
        ),
      );
      return;
    }
    final intent = '${card.number}|${_operation.name}|$cents|${_pin.text}';
    if (_keyFor != intent) {
      _key = ApiClient.newIdempotencyKey();
      _keyFor = intent;
    }
    final path = _operation == _Operation.topUp
        ? '/v1/cards/top-ups'
        : '/v1/cards/debits';
    Map<String, Object?>? receipt;
    await _guard(() async {
      try {
        receipt = await ref
            .read(cashierApiProvider)
            .call(
              (api, token, terminal) => api.post(
                path,
                token: token,
                terminal: terminal,
                idempotencyKey: _key,
                body: {
                  'card': card.toJson(),
                  'amountCents': cents,
                  if (_needsPin) 'pin': _pin.text,
                },
              ),
            );
        _keyFor = null;
      } on ApiException catch (error) {
        // Con respuesta del servidor la operación terminó (aprobada o no):
        // la siguiente lleva clave nueva. Sin respuesta, se reintenta igual.
        if (!error.isNetwork) _keyFor = null;
        rethrow;
      }
    });
    final done = receipt;
    if (done == null || !mounted) return;
    ref.invalidate(terminalActivityProvider);
    final name = _cardInfo?['cardholderName'] as String?;
    _amount.clear();
    _pin.clear();
    await showReceipt(
      context,
      receipt: done,
      terminalName: widget.terminal.name,
      cardholderName: name,
    );
    if (mounted) await _guard(() => _lookup(card));
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoModeProvider);
    // Sin lector NFC todavía: primero la lista y el número, luego la cámara.
    final modes = [
      if (demo) SimulatedReadMode.demoList,
      SimulatedReadMode.manual,
      SimulatedReadMode.camera,
    ];
    if (!modes.contains(_mode)) _mode = modes.first;
    return RoleScaffold(
      title: widget.terminal.name,
      icon: Icons.point_of_sale_rounded,
      actions: [
        IconButton(
          tooltip: 'Cerrar caja',
          icon: const Icon(Icons.logout_rounded),
          onPressed: () async {
            final ok = await confirm(
              context,
              title: 'Cerrar caja',
              message:
                  'Para volver a abrir ${widget.terminal.name} hará falta su '
                  'código.',
              action: 'Cerrar caja',
            );
            if (ok) await ref.read(terminalProvider.notifier).close();
          },
        ),
      ],
      body: TwoColumns(
        start: [
          Text(
            'Sesión de ${widget.session.fullName}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SectionTitle('Tarjeta'),
          if (_cardInfo == null) ...[
            SegmentedButton<SimulatedReadMode>(
              showSelectedIcon: false,
              segments: [
                for (final m in modes)
                  ButtonSegment(
                    value: m,
                    icon: Icon(m.icon),
                    label: Text(m.label),
                  ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
              ),
              onPressed: _busy ? null : _readCard,
              icon: const Icon(Icons.contactless_outlined),
              label: Text(switch (_mode) {
                SimulatedReadMode.camera => 'Escanear la tarjeta del titular',
                SimulatedReadMode.demoList => 'Elegir tarjeta de la lista',
                SimulatedReadMode.manual => 'Escribir número de tarjeta',
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Las tarjetas físicas con NFC llegan en la Fase 7; mientras '
              'tanto se eligen de la lista o por su número.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            _CardSummary(info: _cardInfo!, onClear: _busy ? null : _clearCard),
          if (_cardInfo != null) ...[
            const SectionTitle('Operación'),
            SegmentedButton<_Operation>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _Operation.debit,
                  icon: Icon(Icons.shopping_cart_checkout_rounded),
                  label: Text('Cobrar'),
                ),
                ButtonSegment(
                  value: _Operation.topUp,
                  icon: Icon(Icons.add_card_rounded),
                  label: Text('Recargar'),
                ),
              ],
              selected: {_operation},
              onSelectionChanged: (s) => setState(() {
                _operation = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_operation == _Operation.topUp) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cents in const [500, 1000, 2000, 5000])
                    ChoiceChip(
                      label: Text(Money.format(cents)),
                      selected: _topUpCents == cents,
                      onSelected: (_) => setState(() => _topUpCents = cents),
                    ),
                  ChoiceChip(
                    label: const Text('Otro monto'),
                    selected: _topUpCents == null,
                    onSelected: (_) => setState(() => _topUpCents = null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_operation == _Operation.debit || _topUpCents == null)
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppText.money(Theme.of(context).textTheme.titleLarge),
                decoration: InputDecoration(
                  labelText: _operation == _Operation.debit
                      ? 'Monto de la compra'
                      : r'Monto (múltiplo de $5)',
                  prefixText: r'$ ',
                  hintText: _operation == _Operation.debit ? '7.35' : '15',
                ),
              ),
            if (_needsPin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _pin,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'PIN del titular',
                  helperText:
                      'Compras de más de '
                      '${Money.format(_cardInfo!['pinRequiredAboveCents']! as int)} '
                      'requieren el PIN. Que lo escriba el titular.',
                  helperMaxLines: 2,
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || _cardInfo!['status'] != 'ACTIVE'
                  ? null
                  : _submit,
              icon: Icon(
                _operation == _Operation.debit
                    ? Icons.shopping_cart_checkout_rounded
                    : Icons.add_card_rounded,
              ),
              label: Text(
                _busy
                    ? 'Procesando…'
                    : '${_operation == _Operation.debit ? 'Cobrar' : 'Recargar'}'
                          '${(_cents ?? 0) > 0 ? ' ${Money.format(_cents!)}' : ''}',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(_error!),
          ],
        ],
        end: [
          _PayCodePanel(terminal: widget.terminal),
          const SectionTitle('Últimos movimientos en esta caja'),
          const _Activity(),
        ],
      ),
    );
  }
}

class _CardSummary extends StatelessWidget {
  const _CardSummary({required this.info, required this.onClear});

  final Map<String, Object?> info;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.verified_user_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info['cardholderName']! as String,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(info['numberMasked']! as String),
                      const SizedBox(width: 8),
                      StatusChip(info['status']! as String),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Money.format(info['balanceCents']! as int),
                    style: AppText.money(
                      theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text('Saldo disponible', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Otra tarjeta')),
          ],
        ),
      ),
    );
  }
}

/// Código de la caja: el titular lo escribe en su app para pagar aquí.
class _PayCodePanel extends StatelessWidget {
  const _PayCodePanel({required this.terminal});

  final TerminalLink terminal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = terminal.payCode;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código de esta caja',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                code == null ? 'Sin código' : Fmt.payCode(code),
                style: AppText.money(
                  theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El titular lo escribe en su app, en "Pagar en caja", para pagar '
              'sin mostrar la tarjeta.',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _Activity extends ConsumerWidget {
  const _Activity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(terminalActivityProvider);
    final items = activity.value;
    if (items == null) {
      return activity.hasError
          ? ErrorPanel(activity.error!)
          : const LinearProgressIndicator();
    }
    if (items.isEmpty) {
      return const Text(
        'Aún no hay movimientos. Los pagos con código aparecen aquí al '
        'instante.',
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            for (final t in items)
              TransactionTile(
                t,
                subtitle:
                    '${t['cardholderName']}, ${t['cardNumberMasked']}, '
                    '${Fmt.dateTime(t['createdAt']! as String)}',
              ),
          ],
        ),
      ),
    );
  }
}
