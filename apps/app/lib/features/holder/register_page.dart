import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import 'holder_dialogs.dart';

/// Registro del titular en dos pasos: datos y verificación del correo.
///
/// Al verificar, inicia sesión con la misma contraseña y vuelve a la
/// pantalla del titular. En modo demo el código del correo se muestra en
/// pantalla.
class RegisterPage extends ConsumerStatefulWidget {
  /// Crea la pantalla.
  const RegisterPage({super.key});

  /// Ruta.
  static const path = '/titular/registro';

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  final _pinAgain = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _demoCode;
  Object? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _pin, _pinAgain, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
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

  Future<void> _register() async {
    if (_pin.text.length != 4 || _pin.text != _pinAgain.text) {
      setState(
        () => _error = const ApiException(
          'El PIN debe tener 4 dígitos y coincidir las dos veces.',
        ),
      );
      return;
    }
    await _guard(() async {
      final body = await ref
          .read(apiClientProvider)
          .post(
            '/v1/auth/cardholders/register',
            body: {
              'fullName': _name.text.trim(),
              'email': _email.text.trim(),
              'password': _password.text,
              'pin': _pin.text,
            },
          );
      setState(() {
        _codeStep = true;
        _demoCode = body['demoCode'] as String?;
      });
    });
  }

  Future<void> _resend() => _guard(() async {
    final body = await ref
        .read(apiClientProvider)
        .post(
          '/v1/auth/cardholders/resend-code',
          body: {'email': _email.text.trim()},
        );
    setState(() => _demoCode = body['demoCode'] as String? ?? _demoCode);
    if (mounted) showMessage(context, 'Te enviamos un código nuevo.');
  });

  Future<void> _verify() => _guard(() async {
    final api = ref.read(apiClientProvider);
    await api.post(
      '/v1/auth/cardholders/verify-email',
      body: {'email': _email.text.trim(), 'code': _code.text.trim()},
    );
    final session = await api.post(
      '/v1/auth/cardholders/login',
      body: {'email': _email.text.trim(), 'password': _password.text},
    );
    ref.read(holderSessionProvider.notifier).signIn(session);
    if (mounted) context.go('/titular');
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoleScaffold(
      title: 'Crear cuenta',
      icon: Icons.person_add_alt_rounded,
      maxWidth: 460,
      body: PageList(
        children: [
          const SizedBox(height: 8),
          Text(
            _codeStep ? 'Revisa tu correo' : 'Tus datos',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _codeStep
                ? 'Enviamos un código de 6 dígitos a ${_email.text.trim()}.'
                : 'Con tu cuenta, administración emite tu tarjeta y tú ves tu '
                      'saldo desde el celular.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (!_codeStep) ...[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                helperText: 'Al menos 8 caracteres',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PinField(
                    controller: _pin,
                    label: 'PIN',
                    helper: '4 dígitos',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PinField(controller: _pinAgain, label: 'Repite PIN'),
                ),
              ],
            ),
          ] else ...[
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
              onSubmitted: (_) => _verify(),
              decoration: const InputDecoration(
                labelText: 'Código',
                counterText: '',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(_error!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : (_codeStep ? _verify : _register),
            child: Text(_codeStep ? 'Verificar y entrar' : 'Crear cuenta'),
          ),
          if (_codeStep)
            TextButton(
              onPressed: _busy ? null : _resend,
              child: const Text('Enviar otro código'),
            )
          else
            TextButton(
              onPressed: () => context.go('/titular'),
              child: const Text('Ya tengo cuenta'),
            ),
        ],
      ),
    );
  }
}
