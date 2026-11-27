import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/api/api_client.dart';
import '../../core/modules.dart';
import '../../core/session/session.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import 'holder_dialogs.dart';

/// Ejecuta una llamada con la sesión del titular.
Future<Map<String, Object?>> _run(
  WidgetRef ref,
  Future<Map<String, Object?>> Function(ApiClient api, String token) action,
) => ref.read(holderSessionProvider.notifier).run(action);

/// Mi perfil: nombre, contraseña, correo y PIN (ver docs/adr/0016).
class ProfilePage extends ConsumerStatefulWidget {
  /// Crea la página.
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, Object?>? _profile;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _run(
        ref,
        (api, t) => api.get('/v1/me/profile', token: t),
      );
      if (mounted) setState(() => _profile = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Cambiar nombre',
        label: 'Nombre completo',
        initial: _profile?['fullName'] as String? ?? '',
        minLength: 3,
      ),
    );
    if (name == null || !mounted) return;
    try {
      final p = await _run(
        ref,
        (api, t) =>
            api.put('/v1/me/profile', token: t, body: {'fullName': name}),
      );
      if (!mounted) return;
      setState(() => _profile = p);
      showMessage(context, 'Nombre actualizado.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if ((changed ?? false) && mounted) {
      showMessage(context, 'Contraseña cambiada.');
    }
  }

  Future<void> _changeEmail() async {
    final p = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _EmailDialog(),
    );
    if (p == null || !mounted) return;
    setState(() => _profile = p);
    showMessage(context, 'Correo actualizado a ${p['email']}.');
  }

  Future<void> _changePin() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePinDialog(),
    );
    if ((changed ?? false) && mounted) showMessage(context, 'PIN cambiado.');
  }

  @override
  Widget build(BuildContext context) {
    final pinOn = ref.watch(moduleOnProvider(AppModule.pinChange));
    final p = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                ErrorPanel(_error!, onRetry: _load)
              else if (p == null)
                const LinearProgressIndicator()
              else ...[
                const SectionTitle('Datos de la cuenta'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Nombre'),
                        subtitle: Text(p['fullName']! as String),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: _editName,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.alternate_email_rounded),
                        title: const Text('Correo'),
                        subtitle: Text(p['email']! as String),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: _changeEmail,
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Seguridad'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded),
                        title: const Text('Cambiar contraseña'),
                        subtitle: const Text('Pide la contraseña actual'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _changePassword,
                      ),
                      if (pinOn) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.pin_outlined),
                          title: const Text('Cambiar PIN de la tarjeta'),
                          subtitle: const Text(
                            r'Lo pide la caja en compras de más de $25.00',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _changePin,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo de una sola línea de texto.
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.minLength,
  });

  final String title;
  final String label;
  final String initial;
  final int minLength;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _valid => _text.text.trim().length >= widget.minLength;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 360,
      child: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (_valid) Navigator.of(context).pop(_text.text.trim());
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _valid
            ? () => Navigator.of(context).pop(_text.text.trim())
            : null,
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
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
    if (_next.text.length < 8 || _next.text != _again.text) {
      setState(
        () => _error = const ApiException(
          'La contraseña nueva debe tener al menos 8 caracteres y coincidir '
          'las dos veces.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _run(
        ref,
        (api, t) => api.put(
          '/v1/me/password',
          token: t,
          body: {'currentPassword': _current.text, 'newPassword': _next.text},
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cambiar contraseña'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (c, label) in [
            (_current, 'Contraseña actual'),
            (_next, 'Contraseña nueva'),
            (_again, 'Repite la contraseña nueva'),
          ]) ...[
            TextField(
              controller: c,
              obscureText: true,
              decoration: InputDecoration(labelText: label),
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) ErrorPanel(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: const Text('Cambiar'),
      ),
    ],
  );
}

/// Cambio de correo en dos pasos: correo nuevo + contraseña, y luego el
/// código que llega al correo nuevo.
class _EmailDialog extends ConsumerStatefulWidget {
  const _EmailDialog();

  @override
  ConsumerState<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends ConsumerState<_EmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _demoCode;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _step(() async {
    final body = await _run(
      ref,
      (api, t) => api.post(
        '/v1/me/email-change',
        token: t,
        body: {'newEmail': _email.text.trim(), 'password': _password.text},
      ),
    );
    setState(() {
      _sent = true;
      _demoCode = body['demoCode'] as String?;
    });
  });

  Future<void> _confirm() => _step(() async {
    final p = await _run(
      ref,
      (api, t) => api.post(
        '/v1/me/email-change/confirm',
        token: t,
        body: {'code': _code.text.trim()},
      ),
    );
    if (mounted) Navigator.of(context).pop(p);
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cambiar correo'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_sent) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo nuevo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Tu contraseña'),
            ),
          ] else ...[
            Text(
              'Te enviamos un código a ${_email.text.trim()}. Escríbelo para '
              'confirmar el cambio.',
            ),
            const SizedBox(height: 12),
            if (_demoCode != null) ...[
              DemoCodeBanner(
                code: _demoCode!,
                onUse: () => _code.text = _demoCode!,
              ),
              const SizedBox(height: 12),
            ],
            _CodeField(controller: _code, onSubmitted: _confirm),
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
        onPressed: _busy ? null : (_sent ? _confirm : _send),
        child: Text(_sent ? 'Confirmar' : 'Enviar código'),
      ),
    ],
  );
}

/// Tarjeta nueva con traslado de todo el saldo (módulo `card_transfer`):
/// enviar código al correo y confirmarlo. La `Idempotency-Key` se genera una
/// sola vez, así un reintento por mala red no emite dos tarjetas.
class NewCardDialog extends ConsumerStatefulWidget {
  /// Crea el diálogo para la tarjeta activa [cardId].
  const NewCardDialog({
    required this.cardId,
    required this.balanceCents,
    super.key,
  });

  /// Tarjeta que se cambia.
  final String cardId;

  /// Saldo que se trasladará.
  final int balanceCents;

  @override
  ConsumerState<NewCardDialog> createState() => _NewCardDialogState();
}

class _NewCardDialogState extends ConsumerState<NewCardDialog> {
  final _code = TextEditingController();
  final _key = ApiClient.newIdempotencyKey();
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
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _step(() async {
    final body = await _run(
      ref,
      (api, t) =>
          api.post('/v1/me/cards/${widget.cardId}/card-requests', token: t),
    );
    setState(() {
      _sent = true;
      _demoCode = body['demoCode'] as String?;
    });
  });

  Future<void> _confirm() => _step(() async {
    final result = await _run(
      ref,
      (api, t) => api.post(
        '/v1/me/cards/${widget.cardId}/card-requests/confirm',
        token: t,
        idempotencyKey: _key,
        body: {'code': _code.text.trim()},
      ),
    );
    if (mounted) Navigator.of(context).pop(result);
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.autorenew_rounded),
    title: const Text('Pedir tarjeta nueva'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _sent
                ? 'Te enviamos un código a tu correo. Escríbelo para emitir la '
                      'tarjeta nueva.'
                : 'Se emitirá una tarjeta nueva y se le trasladará todo tu '
                      'saldo (${Money.format(widget.balanceCents)}). Tu tarjeta '
                      'actual dejará de funcionar. Para confirmar que eres tú, '
                      'te enviaremos un código a tu correo.',
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
            _CodeField(controller: _code, onSubmitted: _confirm),
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
        onPressed: _busy ? null : (_sent ? _confirm : _send),
        child: Text(_sent ? 'Emitir tarjeta nueva' : 'Enviar código'),
      ),
    ],
  );
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: true,
    keyboardType: TextInputType.number,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSubmitted: (_) => onSubmitted(),
    decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
  );
}
