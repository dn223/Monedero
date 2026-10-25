import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monedero_core/monedero_core.dart';

import '../api/api_client.dart';

/// Mensaje para el usuario según el código de error de la API.
///
/// La app decide por [ApiErrorCode], nunca por el texto libre del servidor
/// (AGENTS.md § 5); el texto del servidor solo se usa para errores no
/// previstos aquí.
String friendlyError(Object error) {
  if (error is! ApiException) return 'Ocurrió un error inesperado.';
  final details = error.apiError?.details ?? const {};
  return switch (error.code) {
    null => error.message,
    ApiErrorCode.insufficientFunds =>
      details['balanceCents'] is int
          ? 'Saldo insuficiente: la tarjeta tiene '
                '${Money.format(details['balanceCents']! as int)}.'
          : 'Saldo insuficiente.',
    ApiErrorCode.pinRequired => 'Este monto requiere el PIN del titular.',
    ApiErrorCode.invalidPin =>
      details['attemptsLeft'] is int
          ? 'PIN incorrecto. Quedan ${details['attemptsLeft']} intentos.'
          : 'PIN incorrecto.',
    ApiErrorCode.tooManyAttempts =>
      'Demasiados intentos fallidos. Espera 15 minutos o pide un código nuevo.',
    ApiErrorCode.cardNotActive => switch (details['status']) {
      'BLOCKED' => 'La tarjeta está bloqueada: su titular reportó la pérdida.',
      'PENDING' => 'La tarjeta aún no se ha entregado.',
      'REPLACED' => 'Esta tarjeta fue repuesta por una nueva.',
      _ => 'La tarjeta no está activa.',
    },
    ApiErrorCode.invalidCardSignature =>
      'Tarjeta no válida: el número, el UID o la firma no coinciden.',
    ApiErrorCode.invalidAmount =>
      r'Monto no válido. Las recargas son múltiplos de $5.00.',
    ApiErrorCode.invalidCredentials =>
      'Correo o contraseña incorrectos (o el correo aún no se verificó).',
    ApiErrorCode.invalidVerificationCode => 'Código incorrecto o vencido.',
    ApiErrorCode.terminalNotAuthorized =>
      'Esta caja no está autorizada o fue revocada. Vincúlala de nuevo.',
    ApiErrorCode.rateLimited =>
      'Demasiadas solicitudes seguidas. Espera un minuto e intenta de nuevo.',
    ApiErrorCode.forbidden => 'Tu cuenta no tiene permiso para esto.',
    ApiErrorCode.unauthorized => 'Tu sesión venció. Inicia sesión de nuevo.',
    ApiErrorCode.demoModeDisabled => 'El modo demo está desactivado.',
    _ => error.message,
  };
}

/// Aviso de error con ícono, en el color de error del tema.
class ErrorPanel extends StatelessWidget {
  /// Crea el aviso para [error] (se traduce con [friendlyError]).
  const ErrorPanel(this.error, {this.onRetry, super.key});

  /// Error a mostrar.
  final Object error;

  /// Acción "Reintentar" opcional.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offline = error is ApiException && (error as ApiException).isNetwork;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(
          offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
          color: scheme.onErrorContainer,
        ),
        title: Text(
          offline ? 'Sin conexión con el servidor' : friendlyError(error),
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        subtitle: offline
            ? Text(
                friendlyError(error),
                style: TextStyle(color: scheme.onErrorContainer),
              )
            : null,
        trailing: onRetry == null
            ? null
            : TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ),
    );
  }
}

/// Nota informativa en tono secundario (por ejemplo, ayudas de la demo).
class InfoPanel extends StatelessWidget {
  /// Crea la nota.
  const InfoPanel({
    required this.icon,
    required this.child,
    this.trailing,
    super.key,
  });

  /// Ícono.
  final IconData icon;

  /// Contenido.
  final Widget child;

  /// Acción opcional a la derecha.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSecondaryContainer),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(child: child),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Código que en producción llegaría por correo y que, solo en modo demo,
/// la API devuelve para mostrarlo aquí (quien prueba por el link público no
/// tiene acceso a Mailpit).
class DemoCodeBanner extends StatelessWidget {
  /// Crea el aviso con el [code] y la acción para usarlo.
  const DemoCodeBanner({required this.code, required this.onUse, super.key});

  /// Código de 6 dígitos.
  final String code;

  /// Escribe el código en el campo.
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) => InfoPanel(
    icon: Icons.mark_email_read_outlined,
    trailing: TextButton(onPressed: onUse, child: const Text('Usar')),
    child: Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Modo demo: el código enviado al correo es '),
          TextSpan(
            text: code,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Muestra un mensaje corto abajo de la pantalla.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Copia [text] al portapapeles y avisa.
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  String message = 'Copiado.',
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showMessage(context, message);
}

/// Diálogo de confirmación; devuelve `true` si se confirmó.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(0, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
