import 'package:mailer/mailer.dart' as mail;
import 'package:mailer/smtp_server.dart';

/// Envío de correos (códigos de verificación).
abstract interface class Mailer {
  /// Envía [text] a [to] con [subject].
  Future<void> send({
    required String to,
    required String subject,
    required String text,
  });
}

/// Envía por SMTP sin TLS (Mailpit en local).
class SmtpMailer implements Mailer {
  /// Crea el mailer hacia [host]:[port] con remitente [from].
  SmtpMailer({required this.host, required this.port, required this.from});

  /// Host SMTP.
  final String host;

  /// Puerto SMTP.
  final int port;

  /// Remitente, por ejemplo `Monedero <no-responder@monedero.local>`.
  final String from;

  @override
  Future<void> send({
    required String to,
    required String subject,
    required String text,
  }) async {
    final match = RegExp(r'^(.*)<(.+)>$').firstMatch(from.trim());
    final address = match == null
        ? mail.Address(from.trim())
        : mail.Address(match.group(2)!.trim(), match.group(1)!.trim());
    final message = mail.Message()
      ..from = address
      ..recipients.add(to)
      ..subject = subject
      ..text = text;
    await mail.send(
      message,
      SmtpServer(
        host,
        port: port,
        ignoreBadCertificate: true,
        allowInsecure: true,
      ),
    );
  }
}

/// Guarda los correos en memoria (pruebas).
class MemoryMailer implements Mailer {
  /// Correos enviados, el más reciente al final.
  final List<({String to, String subject, String text})> sent = [];

  @override
  Future<void> send({
    required String to,
    required String subject,
    required String text,
  }) async => sent.add((to: to, subject: subject, text: text));

  /// Último código de 6 dígitos enviado a [to].
  String lastCodeFor(String to) {
    final message = sent.lastWhere((m) => m.to == to);
    return RegExp(r'\b(\d{6})\b').firstMatch(message.text)!.group(1)!;
  }
}
