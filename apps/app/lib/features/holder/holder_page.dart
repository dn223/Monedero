import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/format.dart';
import '../../core/modules.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/widgets/card_widgets.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../assistant/assistant_sheet.dart';
import '../auth/login_page.dart';
import 'holder_dialogs.dart';
import 'holder_providers.dart';
import 'register_page.dart';

/// Espacio del titular: inicio de sesión o, con sesión, su tarjeta.
class HolderPage extends ConsumerWidget {
  /// Crea la pantalla.
  const HolderPage({super.key});

  /// Ruta.
  static const path = '/titular';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(holderSessionProvider);
    if (session == null) {
      return LoginPage(
        title: 'Titular',
        icon: Icons.person_rounded,
        heading: 'Tu tarjeta en el celular',
        message:
            'Consulta tu saldo, muestra tu código en caja y paga sin sacar la '
            'tarjeta.',
        loginPath: '/v1/auth/cardholders/login',
        sessionProvider: holderSessionProvider,
        footer: ref.watch(moduleOnProvider(AppModule.selfRegistration))
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () => context.go(RegisterPage.path),
                  child: const Text('¿Aún no tienes cuenta? Créala'),
                ),
              )
            : null,
      );
    }
    return HolderHome(session: session);
  }
}

/// Inicio del titular: tarjeta, acciones, movimientos y correos recibidos.
///
/// Se actualiza sola cada 5 segundos, así el saldo cambia en cuanto la
/// caja cobra o recarga.
class HolderHome extends ConsumerStatefulWidget {
  /// Crea la pantalla para [session].
  const HolderHome({required this.session, super.key});

  /// Sesión del titular.
  final Session session;

  @override
  ConsumerState<HolderHome> createState() => _HolderHomeState();
}

class _HolderHomeState extends ConsumerState<HolderHome> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // También los módulos: si administración apaga uno, el botón
    // desaparece sin recargar la página.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() => ref
    ..invalidate(holderSnapshotProvider)
    ..invalidate(holderInboxProvider)
    ..invalidate(modulesProvider);

  Future<void> _pay() async {
    final receipt = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const PayDialog(),
    );
    if (receipt == null || !mounted) return;
    _refresh();
    showMessage(
      context,
      'Pago aprobado: ${Money.format(receipt['amountCents']! as int)}. '
      'Saldo: ${Money.format(receipt['balanceAfterCents']! as int)}.',
    );
  }

  Future<void> _changePin() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePinDialog(),
    );
    if ((changed ?? false) && mounted) showMessage(context, 'PIN cambiado.');
  }

  Future<void> _reportLoss(String cardId) async {
    final blocked = await showDialog<bool>(
      context: context,
      builder: (_) => LossReportDialog(cardId: cardId),
    );
    if (!(blocked ?? false) || !mounted) return;
    _refresh();
    showMessage(
      context,
      'Tarjeta bloqueada. Pide la reposición en administración: tu saldo pasa '
      'a la tarjeta nueva.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = ref.watch(holderSnapshotProvider);
    final demo = ref.watch(demoModeProvider);
    final data = snapshot.value;
    final card = data?.card;
    final status = card?['status'] as String?;
    final canOperate = status == 'ACTIVE' && !(data?.isStale ?? true);
    bool on(AppModule m) => ref.watch(moduleOnProvider(m));
    final payOn = on(AppModule.holderPayments);
    final qrOn = on(AppModule.cardQr) && card?['credentials'] != null;
    final pinOn = on(AppModule.pinChange);
    final canReport = status == 'ACTIVE' || status == 'PENDING';

    return RoleScaffold(
      title: 'Hola, ${widget.session.firstName}',
      icon: Icons.person_rounded,
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refresh,
        ),
        SignOutButton(holderSessionProvider),
      ],
      floatingActionButton: on(AppModule.assistant) && !(data?.isStale ?? true)
          ? FloatingActionButton.extended(
              onPressed: () => showAssistant(context),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Asistente'),
            )
          : null,
      body: TwoColumns(
        start: [
          if (snapshot.hasError && data == null)
            ErrorPanel(snapshot.error!, onRetry: _refresh)
          else if (data == null)
            const _CardPlaceholder()
          else if (card == null)
            EmptyState(
              icon: Icons.credit_card_off_outlined,
              title: 'Aún no tienes tarjeta',
              message:
                  'Pide en administración que emitan tu tarjeta. Cuando te la '
                  'entreguen aparecerá aquí con su saldo.',
              action: OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Revisar de nuevo'),
              ),
            )
          else ...[
            VirtualCard(
              number: card['number']! as String,
              holder: card['cardholderName']! as String,
              balanceCents: card['balanceCents']! as int,
              status: status!,
              staleSince: data.staleSince,
            ),
            const SizedBox(height: 16),
            if (data.isStale)
              InfoPanel(
                icon: Icons.cloud_off_rounded,
                child: Text(
                  'Sin conexión. Saldo de las ${Fmt.time(data.staleSince!)}; '
                  'no se puede pagar hasta recuperar la conexión.',
                ),
              )
            else if (status == 'PENDING')
              const InfoPanel(
                icon: Icons.schedule_rounded,
                child: Text(
                  'Tu tarjeta está lista. Se activa cuando administración la '
                  'marque como entregada.',
                ),
              )
            else if (status == 'BLOCKED')
              const InfoPanel(
                icon: Icons.lock_outline_rounded,
                child: Text(
                  'Tarjeta bloqueada por pérdida. Administración puede '
                  'reponerla y pasar tu saldo a la tarjeta nueva.',
                ),
              ),
            if (canOperate && payOn)
              FilledButton.icon(
                onPressed: _pay,
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('Pagar en caja'),
              ),
            if (canOperate && payOn && qrOn) const SizedBox(height: 8),
            if (canOperate && qrOn)
              OutlinedButton.icon(
                onPressed: () => showCardQr(context, card),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Mostrar mi código QR'),
              ),
            if (!data.isStale && (pinOn || canReport)) ...[
              const SectionTitle('Mi tarjeta'),
              Card(
                child: Column(
                  children: [
                    if (pinOn)
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: const Text('Cambiar PIN'),
                        subtitle: const Text(
                          r'Lo pide la caja en compras de más de $25.00',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _changePin,
                      ),
                    if (canReport) ...[
                      if (pinOn) const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.report_outlined,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          'Reportar pérdida',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        subtitle: const Text(
                          'Bloquea la tarjeta al instante con un código de tu '
                          'correo',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _reportLoss(card['cardId']! as String),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
        end: [
          SectionTitle(
            'Movimientos',
            trailing: data?.transactions.isNotEmpty ?? false
                ? Text(
                    '${data!.transactions.length}',
                    style: theme.textTheme.labelLarge,
                  )
                : null,
          ),
          if (data == null)
            const SizedBox.shrink()
          else if (data.isStale)
            const Text('Los movimientos se ven cuando vuelva la conexión.')
          else if (data.transactions.isEmpty)
            const Text('Aún no hay movimientos en esta tarjeta.')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    for (final t in data.transactions.take(30))
                      TransactionTile(t),
                  ],
                ),
              ),
            ),
          if (demo) const _Inbox(),
        ],
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder();

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 85.6 / 54,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator()),
    ),
  );
}

/// Correos que recibió el titular (códigos y avisos de movimientos).
class _Inbox extends ConsumerWidget {
  const _Inbox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(holderInboxProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Correos recibidos'),
        const InfoPanel(
          icon: Icons.mark_email_unread_outlined,
          child: Text(
            'Aquí ves los correos que la app te envía: códigos y avisos de '
            'cada movimiento.',
          ),
        ),
        const SizedBox(height: 8),
        if (inbox.isEmpty)
          const Text('Todavía no hay correos.')
        else
          Card(
            child: Column(
              children: [
                for (final m in inbox.take(10))
                  ExpansionTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text(m['subject']! as String),
                    subtitle: Text(Fmt.dateTime(m['sentAt']! as String)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedAlignment: Alignment.centerLeft,
                    children: [SelectableText(m['text']! as String)],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
