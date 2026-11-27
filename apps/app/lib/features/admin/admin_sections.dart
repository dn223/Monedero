import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../card_reader/card_reader.dart';
import '../../card_reader/nfc_card_reader.dart';
import '../../card_reader/nfc_chip.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/modules.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/card_widgets.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/qr.dart';
import 'admin_providers.dart';

/// Campo de búsqueda que avisa el texto tras una pausa breve al escribir.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search_rounded),
      hintText: widget.hint,
    ),
    onChanged: (text) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => widget.onChanged(text.trim()),
      );
    },
  );
}

/// Ejecuta una acción de administración y muestra el resultado o el error.
Future<Map<String, Object?>?> _adminAction(
  BuildContext context,
  WidgetRef ref,
  Future<Map<String, Object?>> Function(ApiClient api, String token) action,
) async {
  try {
    return await ref.read(adminSessionProvider.notifier).run(action);
  } on ApiException catch (error) {
    if (context.mounted) showMessage(context, friendlyError(error));
    return null;
  }
}

/// Tarjetas: buscar, entregar, reponer y ver movimientos.
class CardsSection extends ConsumerStatefulWidget {
  /// Crea la sección.
  const CardsSection({super.key});

  @override
  ConsumerState<CardsSection> createState() => _CardsSectionState();
}

class _CardsSectionState extends ConsumerState<CardsSection> {
  String _query = '';

  void _refresh() => ref
    ..invalidate(adminCardsProvider(_query))
    ..invalidate(adminStatsProvider)
    ..invalidate(reconciliationProvider);

  Future<void> _deliver(Map<String, Object?> card) async {
    final done = await _adminAction(
      context,
      ref,
      (api, token) =>
          api.post('/v1/admin/cards/${card['cardId']}/deliver', token: token),
    );
    if (done == null || !mounted) return;
    _refresh();
    showMessage(context, 'Tarjeta entregada: ya puede usarse en caja.');
  }

  /// Graba la tarjeta en un chip NTAG215 (Fase 7, ADR 0017): lee el UID del
  /// chip, la API vincula ese UID y firma, y la app escribe y verifica.
  Future<void> _writeChip(Map<String, Object?> card) async {
    final cardId = card['cardId']! as String;
    try {
      final written = await runWithChip(
        context,
        io: ref.read(nfcChipIoProvider),
        title: 'Grabar chip',
        message:
            'Acerca un chip NTAG215 en blanco (o el de esta tarjeta) y no lo '
            'retires hasta que termine.',
        action: (tag) async {
          final uid = ChipCardLayout.uidHex(tag.id);
          if (uid == null) {
            throw const CardReadException(
              'Este chip no es compatible: se necesita un NTAG215.',
            );
          }
          final linked = await ref
              .read(adminSessionProvider.notifier)
              .run(
                (api, token) => api.post(
                  '/v1/admin/cards/$cardId/chip',
                  token: token,
                  body: {'chipUid': uid},
                ),
              );
          final credentials = CardCredentials.fromJson(
            linked['credentials']! as Map<String, Object?>,
          );
          await writeChipCredentials(tag, credentials);
          return credentials;
        },
      );
      if (written == null || !mounted) return;
      _refresh();
      showMessage(
        context,
        'Chip grabado para ${card['cardholderName']}. El QR anterior deja '
        'de servir; el titular ve el nuevo en su app.',
      );
    } on ApiException catch (error) {
      if (mounted) showMessage(context, friendlyError(error));
    } on CardReadException catch (error) {
      if (mounted) showMessage(context, error.message);
    }
  }

  Future<void> _replace(Map<String, Object?> card) async {
    final ok = await confirm(
      context,
      title: 'Reponer tarjeta',
      message:
          'Se crea una tarjeta nueva activa para ${card['cardholderName']}, '
          'se le traslada el saldo de ${Money.format(card['balanceCents']! as int)} '
          'y la tarjeta ${card['numberMasked']} queda marcada como repuesta. '
          'Todo ocurre en una sola transacción.',
      action: 'Reponer',
    );
    if (!ok || !mounted) return;
    final key = ApiClient.newIdempotencyKey();
    final result = await _adminAction(
      context,
      ref,
      (api, token) => api.post(
        '/v1/admin/cards/${card['cardId']}/replace',
        token: token,
        idempotencyKey: key,
      ),
    );
    if (result == null || !mounted) return;
    _refresh();
    final fresh = result['newCard']! as Map<String, Object?>;
    showMessage(
      context,
      'Tarjeta nueva ${fresh['numberMasked']} con '
      '${Money.format(result['transferredCents']! as int)} trasladados.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(adminCardsProvider(_query));
    final nfc = ref.watch(nfcStatusProvider).value;
    final canWriteChip = nfc != null && nfc != NfcStatus.unsupported;
    return PageList(
      children: [
        _SearchField(
          hint: 'Buscar por número, titular o correo',
          onChanged: (q) => setState(() => _query = q),
        ),
        const SizedBox(height: 12),
        switch (cards) {
          AsyncValue(:final value?) when value.isEmpty => const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Sin resultados',
            message: 'Prueba con otra parte del número, el nombre o el correo.',
          ),
          AsyncValue(:final value?) => Column(
            children: [
              for (final c in value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CardRow(
                    card: c,
                    onDeliver: () => _deliver(c),
                    onReplace: () => _replace(c),
                    onWriteChip: canWriteChip ? () => _writeChip(c) : null,
                    onHistory: () => showDialog<void>(
                      context: context,
                      builder: (_) => _HistoryDialog(card: c),
                    ),
                  ),
                ),
            ],
          ),
          AsyncValue(:final error?) => ErrorPanel(error, onRetry: _refresh),
          _ => const LinearProgressIndicator(),
        },
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.onDeliver,
    required this.onReplace,
    required this.onHistory,
    this.onWriteChip,
  });

  final Map<String, Object?> card;
  final VoidCallback onDeliver;
  final VoidCallback onReplace;
  final VoidCallback onHistory;

  /// Grabar el chip NFC; `null` si el dispositivo no tiene NFC.
  final VoidCallback? onWriteChip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = card['status']! as String;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          spacing: 16,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card['cardholderName']! as String,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        Fmt.cardNumber(card['number']! as String),
                        style: AppText.money(theme.textTheme.bodyMedium),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(status),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Money.format(card['balanceCents']! as int),
                  style: AppText.money(theme.textTheme.titleLarge),
                ),
                const SizedBox(width: 12),
                if (status == 'PENDING')
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: onDeliver,
                    child: const Text('Entregar'),
                  ),
                if (status == 'BLOCKED')
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: onReplace,
                    child: const Text('Reponer'),
                  ),
                if (onWriteChip != null &&
                    (status == 'PENDING' || status == 'ACTIVE'))
                  IconButton(
                    tooltip: 'Grabar chip NFC',
                    onPressed: onWriteChip,
                    icon: const Icon(Icons.contactless_outlined),
                  ),
                IconButton(
                  tooltip: 'Movimientos',
                  onPressed: onHistory,
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDialog extends ConsumerWidget {
  const _HistoryDialog({required this.card});

  final Map<String, Object?> card;

  /// Anulación por contramovimiento (módulo, ADR 0016): pide el motivo,
  /// confirma y llama a la API con una `Idempotency-Key` propia.
  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> t,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReverseDialog(item: t),
    );
    if (reason == null || !context.mounted) return;
    final key = ApiClient.newIdempotencyKey();
    final result = await _adminAction(
      context,
      ref,
      (api, token) => api.post(
        '/v1/admin/transactions/${t['transactionId']}/reversals',
        token: token,
        idempotencyKey: key,
        body: {'reason': reason},
      ),
    );
    if (result == null || !context.mounted) return;
    ref
      ..invalidate(adminCardTransactionsProvider(card['cardId']! as String))
      ..invalidate(adminStatsProvider)
      ..invalidate(reconciliationProvider);
    showMessage(
      context,
      'Movimiento anulado. Saldo de la tarjeta: '
      '${Money.format(result['balanceAfterCents']! as int)}.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(
      adminCardTransactionsProvider(card['cardId']! as String),
    );
    final canReverse = ref.watch(
      moduleOnProvider(AppModule.transactionReversal),
    );
    return AlertDialog(
      title: Text('Movimientos de ${card['numberMasked']}'),
      content: SizedBox(
        width: 520,
        child: switch (tx) {
          AsyncValue(:final value?) when value.isEmpty => const Text(
            'Esta tarjeta no tiene movimientos.',
          ),
          AsyncValue(:final value?) => ListView(
            shrinkWrap: true,
            children: [
              for (final t in value)
                TransactionTile(
                  t,
                  onReverse: canReverse
                      ? () => _reverse(context, ref, t)
                      : null,
                ),
            ],
          ),
          AsyncValue(:final error?) => ErrorPanel(error),
          _ => const LinearProgressIndicator(),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Titulares: buscar y emitir su tarjeta.
class HoldersSection extends ConsumerStatefulWidget {
  /// Crea la sección.
  const HoldersSection({super.key});

  @override
  ConsumerState<HoldersSection> createState() => _HoldersSectionState();
}

class _HoldersSectionState extends ConsumerState<HoldersSection> {
  String _query = '';

  Future<void> _issue(Map<String, Object?> holder) async {
    final card = await _adminAction(
      context,
      ref,
      (api, token) => api.post(
        '/v1/admin/cards',
        token: token,
        body: {'cardholderId': holder['cardholderId']},
      ),
    );
    if (card == null || !mounted) return;
    ref
      ..invalidate(adminHoldersProvider(_query))
      ..invalidate(adminStatsProvider);
    final deliver = await confirm(
      context,
      title: 'Tarjeta emitida',
      message:
          'Se emitió la tarjeta ${card['numberMasked']} para '
          '${holder['fullName']}. Queda por entregar: márcala como entregada '
          'cuando el titular la reciba para activarla.',
      action: 'Entregar ahora',
    );
    if (!deliver || !mounted) return;
    final done = await _adminAction(
      context,
      ref,
      (api, token) =>
          api.post('/v1/admin/cards/${card['cardId']}/deliver', token: token),
    );
    if (done == null || !mounted) return;
    ref.invalidate(adminHoldersProvider(_query));
    showMessage(context, 'Tarjeta entregada y activa.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final holders = ref.watch(adminHoldersProvider(_query));
    return PageList(
      children: [
        _SearchField(
          hint: 'Buscar titular por nombre o correo',
          onChanged: (q) => setState(() => _query = q),
        ),
        const SizedBox(height: 8),
        Text(
          'Los titulares se registran desde la app; aquí se les emite la '
          'tarjeta.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        switch (holders) {
          AsyncValue(:final value?) when value.isEmpty => const EmptyState(
            icon: Icons.person_search_outlined,
            title: 'Sin resultados',
            message: 'Nadie coincide con esa búsqueda.',
          ),
          AsyncValue(:final value?) => Card(
            child: Column(
              children: [
                for (final (i, h) in value.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      child: Text((h['fullName']! as String).characters.first),
                    ),
                    title: Text(h['fullName']! as String),
                    subtitle: Text(
                      h['emailVerified'] == true
                          ? h['email']! as String
                          : '${h['email']} (correo sin verificar)',
                    ),
                    trailing: h['currentCardStatus'] != null
                        ? StatusChip(h['currentCardStatus']! as String)
                        : FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            onPressed: h['emailVerified'] == true
                                ? () => _issue(h)
                                : null,
                            child: const Text('Emitir tarjeta'),
                          ),
                  ),
                ],
              ],
            ),
          ),
          AsyncValue(:final error?) => ErrorPanel(
            error,
            onRetry: () => ref.invalidate(adminHoldersProvider(_query)),
          ),
          _ => const LinearProgressIndicator(),
        },
      ],
    );
  }
}

/// Cajas: autorizar (credencial y QR de vínculo) y revocar.
class TerminalsSection extends ConsumerWidget {
  /// Crea la sección.
  const TerminalsSection({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final created = await _adminAction(
      context,
      ref,
      (api, token) => api.post(
        '/v1/admin/terminals',
        token: token,
        body: {'name': name.trim()},
      ),
    );
    if (created == null || !context.mounted) return;
    ref.invalidate(adminTerminalsProvider);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CredentialDialog(terminal: created),
    );
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> terminal,
  ) async {
    final ok = await confirm(
      context,
      title: 'Revocar ${terminal['name']}',
      message:
          'La caja deja de poder cobrar y recargar de inmediato. Para volver a '
          'usar ese dispositivo hay que crear una caja nueva.',
      action: 'Revocar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await _adminAction(
      context,
      ref,
      (api, token) => api.delete(
        '/v1/admin/terminals/${terminal['terminalId']}',
        token: token,
      ),
    );
    if (done != null) ref.invalidate(adminTerminalsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final terminals = ref.watch(adminTerminalsProvider);
    return PageList(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Cada dispositivo de caja usa su propia credencial.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva caja'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        switch (terminals) {
          AsyncValue(:final value?) when value.isEmpty => const EmptyState(
            icon: Icons.point_of_sale_outlined,
            title: 'Aún no hay cajas',
            message:
                'Crea una caja y vincula con ella el dispositivo del cajero.',
          ),
          AsyncValue(:final value?) => Card(
            child: Column(
              children: [
                for (final (i, t) in value.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.point_of_sale_rounded,
                      color: t['active'] == true
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    title: Text(t['name']! as String),
                    subtitle: Text(
                      t['active'] == true
                          ? 'Código ${t['payCode'] == null ? 'sin asignar' : Fmt.payCode(t['payCode']! as String)}. '
                                'Última conexión: ${Fmt.ago(t['lastSeenAt'] as String?).toLowerCase()}'
                          : 'Revocada',
                    ),
                    trailing: t['active'] == true
                        ? TextButton(
                            onPressed: () => _revoke(context, ref, t),
                            child: const Text('Revocar'),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
          AsyncValue(:final error?) => ErrorPanel(
            error,
            onRetry: () => ref.invalidate(adminTerminalsProvider),
          ),
          _ => const LinearProgressIndicator(),
        },
      ],
    );
  }
}

/// Pide el motivo de la anulación (mínimo 5 caracteres).
class _ReverseDialog extends StatefulWidget {
  const _ReverseDialog({required this.item});

  final Map<String, Object?> item;

  @override
  State<_ReverseDialog> createState() => _ReverseDialogState();
}

class _ReverseDialogState extends State<_ReverseDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.item['type']! as String;
    final amount = Money.format(widget.item['amountCents']! as int);
    final refund = type == 'DEBIT';
    return AlertDialog(
      title: const Text('Anular movimiento'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              refund
                  ? 'Se devolverán $amount a la tarjeta.'
                  : 'Se retirarán $amount de la tarjeta (solo si alcanza el '
                        'saldo).',
            ),
            const SizedBox(height: 4),
            const Text(
              'El movimiento original no se borra: se registra un '
              'contramovimiento y queda en la auditoría.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Ej. cobro duplicado por error',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _reason.text.trim().length >= 5
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
          child: const Text('Anular'),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController(text: 'Caja ');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva caja'),
    content: TextField(
      controller: _name,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Nombre de la caja'),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () => Navigator.of(context).pop(_name.text),
        child: const Text('Crear'),
      ),
    ],
  );
}

/// Código de acceso de la caja recién creada: se muestra **una sola vez**
/// (en la base solo queda su SHA-256).
class _CredentialDialog extends StatelessWidget {
  const _CredentialDialog({required this.terminal});

  final Map<String, Object?> terminal;

  @override
  Widget build(BuildContext context) {
    final token = terminal['terminalToken']! as String;
    final code = terminal['code'] as String? ?? token;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('${terminal['name']} creada'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Entrega este código a la caja: en el dispositivo de la caja, '
                'abre Caja y escríbelo (o escanea el QR). No se vuelve a '
                'mostrar.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: AppText.money(
                  theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QrBox(
                QrPayloads.terminalLink(token),
                size: 200,
                semanticLabel: 'QR para vincular la caja',
              ),
              const SizedBox(height: 12),
              Text(
                'Código para pagar en esta caja: '
                '${Fmt.payCode(terminal['payCode']! as String)}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () =>
              copyToClipboard(context, code, message: 'Código copiado.'),
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
