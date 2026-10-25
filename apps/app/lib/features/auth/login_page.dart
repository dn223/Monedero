import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';

/// Cuenta de demostración sembrada por `tool/seed.dart` (también en
/// README y docs/demo.md). Solo se ofrece cuando la API confirma que el
/// modo demo está activo.
typedef DemoAccount = ({String label, String email, String password});

/// Cuentas de demostración por rol.
abstract final class DemoAccounts {
  /// Titulares con tarjeta activa (PIN 1234).
  static const holders = <DemoAccount>[
    (label: 'Ana López', email: 'ana@demo.local', password: 'Titular1234'),
    (label: 'Bruno Pérez', email: 'bruno@demo.local', password: 'Titular1234'),
  ];

  /// Cajero.
  static const cashier = <DemoAccount>[
    (
      label: 'Cajero demo',
      email: 'cajero@monedero.local',
      password: 'Cajero1234',
    ),
  ];

  /// Administración.
  static const admin = <DemoAccount>[
    (
      label: 'Administración demo',
      email: 'admin@monedero.local',
      password: 'Admin1234',
    ),
  ];
}

/// Pantalla de inicio de sesión de un rol.
///
/// Envía correo y contraseña a [loginPath] y guarda la sesión en
/// [sessionProvider]. En modo demo muestra las cuentas sembradas para
/// entrar con un toque.
class LoginPage extends ConsumerStatefulWidget {
  /// Crea la pantalla.
  const LoginPage({
    required this.title,
    required this.icon,
    required this.heading,
    required this.message,
    required this.loginPath,
    required this.sessionProvider,
    required this.demoAccounts,
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

  /// Cuentas de demostración para este rol.
  final List<DemoAccount> demoAccounts;

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

  void _useDemo(DemoAccount account) {
    _email.text = account.email;
    _password.text = account.password;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final demo = ref.watch(demoModeProvider);
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
            if (demo && widget.demoAccounts.isNotEmpty) ...[
              const SectionTitle('Cuentas de demostración'),
              for (final account in widget.demoAccounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.bolt_rounded),
                      title: Text('Entrar como ${account.label}'),
                      subtitle: Text('${account.email}\n${account.password}'),
                      isThreeLine: true,
                      onTap: _busy ? null : () => _useDemo(account),
                    ),
                  ),
                ),
            ],
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
