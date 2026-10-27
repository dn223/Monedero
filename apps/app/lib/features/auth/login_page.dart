import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';

/// Pantalla de inicio de sesión de un rol.
///
/// Envía correo y contraseña a [loginPath] y guarda la sesión en
/// [sessionProvider].
class LoginPage extends ConsumerStatefulWidget {
  /// Crea la pantalla.
  const LoginPage({
    required this.title,
    required this.icon,
    required this.heading,
    required this.message,
    required this.loginPath,
    required this.sessionProvider,
    this.footer,
    super.key,
  });

  /// Título de la barra.
  final String title;

  /// Ícono del rol.
  final IconData icon;

  /// Encabezado del formulario.
  final String heading;

  /// Texto bajo el encabezado.
  final String message;

  /// Ruta de la API para iniciar sesión.
  final String loginPath;

  /// Dónde se guarda la sesión.
  final NotifierProvider<SessionNotifier, Session?> sessionProvider;

  /// Contenido opcional bajo el botón (por ejemplo, "Crear cuenta").
  final Widget? footer;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(
        () => _error = const ApiException('Escribe correo y contraseña.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await ref
          .read(apiClientProvider)
          .post(
            widget.loginPath,
            body: {'email': _email.text.trim(), 'password': _password.text},
          );
      ref.read(widget.sessionProvider.notifier).signIn(body);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoleScaffold(
      title: widget.title,
      icon: widget.icon,
      maxWidth: 460,
      body: AutofillGroup(
        child: PageList(
          children: [
            const SizedBox(height: 8),
            Text(widget.heading, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              widget.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hidden,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Mostrar' : 'Ocultar',
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorPanel(_error!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Entrando…' : 'Entrar'),
            ),
            ?widget.footer,
          ],
        ),
      ),
    );
  }
}

/// Botón de la barra para cerrar la sesión de [sessionProvider].
class SignOutButton extends ConsumerWidget {
  /// Crea el botón.
  const SignOutButton(this.sessionProvider, {super.key});

  /// Sesión que se cierra.
  final NotifierProvider<SessionNotifier, Session?> sessionProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Cerrar sesión',
    icon: const Icon(Icons.logout_rounded),
    // La pantalla del rol vuelve sola al inicio de sesión.
    onPressed: () => ref.read(sessionProvider.notifier).signOut(),
  );
}
