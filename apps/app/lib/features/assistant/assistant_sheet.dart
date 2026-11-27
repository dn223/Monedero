import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';

/// Abre el asistente: diálogo en escritorio, hoja inferior en celular.
Future<void> showAssistant(BuildContext context) {
  if (Breakpoints.isWide(context)) {
    return showDialog<void>(
      context: context,
      builder: (_) => const Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: 460, height: 620, child: AssistantChat()),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: const AssistantChat(),
      ),
    ),
  );
}

/// Un mensaje del chat.
typedef _Message = ({bool mine, String text, bool error});

/// Chat con el asistente virtual (módulo `assistant`).
///
/// Las respuestas vienen de `POST /v1/assistant/messages`, que lee el saldo
/// y los movimientos reales del titular. Si administración apaga el módulo,
/// la API responde `MODULE_DISABLED` y el chat se cierra a nuevas preguntas.
class AssistantChat extends ConsumerStatefulWidget {
  /// Crea el chat.
  const AssistantChat({super.key});

  @override
  ConsumerState<AssistantChat> createState() => _AssistantChatState();
}

class _AssistantChatState extends ConsumerState<AssistantChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  var _suggestions = const [
    '¿Cuál es mi saldo?',
    '¿Cuál fue mi último movimiento?',
    '¿Cómo recargo?',
    'Perdí mi tarjeta',
  ];
  bool _busy = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final name = ref.read(holderSessionProvider)?.firstName ?? '';
    _messages.add((
      mine: false,
      text:
          '¡Hola${name.isEmpty ? '' : ', $name'}! Soy el asistente de tu '
          'tarjeta. ¿En qué te ayudo?',
      error: false,
    ));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy || _closed) return;
    _input.clear();
    setState(() {
      _messages.add((mine: true, text: text, error: false));
      _busy = true;
    });
    _toBottom();
    try {
      final body = await ref
          .read(holderSessionProvider.notifier)
          .run(
            (api, token) => api.post(
              '/v1/assistant/messages',
              body: {'message': text},
              token: token,
            ),
          );
      if (!mounted) return;
      setState(() {
        _messages.add((
          mine: false,
          text: body['reply']! as String,
          error: false,
        ));
        _suggestions = (body['suggestions']! as List).cast<String>();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add((mine: false, text: friendlyError(error), error: true));
        _closed = error.code == ApiErrorCode.moduleDisabled;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.support_agent_rounded,
              color: scheme.onPrimaryContainer,
            ),
          ),
          title: const Text('Asistente virtual'),
          subtitle: const Text('Responde con los datos de tu tarjeta'),
          trailing: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in _messages) _Bubble(m),
              if (_busy)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!_closed && _suggestions.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(s),
                      onPressed: _busy ? null : () => _send(s),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_closed,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: _closed
                        ? 'El asistente está desactivado'
                        : 'Escribe tu pregunta',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Enviar',
                onPressed: _closed || _busy ? null : () => _send(_input.text),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.mine;
    final (bg, fg) = mine
        ? (scheme.primary, scheme.onPrimary)
        : message.error
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : (scheme.surfaceContainerHigh, scheme.onSurface);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Text(message.text, style: TextStyle(color: fg)),
      ),
    );
  }
}
