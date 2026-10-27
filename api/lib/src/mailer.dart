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

/// Correo enviado, tal como lo guarda un [MailOutbox].
typedef SentMail = ({String to, String subject, String text, DateTime sentAt});

/// Buzón con los últimos correos enviados por la API.
///
/// Solo se expone en modo demo (`GET /v1/demo/inbox`), para que quien
/// prueba desde un link público vea los avisos sin acceso a Mailpit.
abstract interface class MailOutbox {
  /// Correos enviados a [email], el más reciente primero.
  List<SentMail> messagesFor(String email);
}

/// Envía con [inner] y además recuerda los últimos [capacity] correos en
/// memoria (modo demo). Se pierden al reiniciar la API.
class RecordingMailer implements Mailer, MailOutbox {
  /// Crea el mailer que envuelve a [inner].
  RecordingMailer(this.inner, {this.capacity = 200});

  /// Mailer real (SMTP hacia Mailpit).
  final Mailer inner;

  /// Máximo de correos que se recuerdan.
  final int capacity;

  final List<SentMail> _sent = [];

  @override
  Future<void> send({
    required String to,
    required String subject,
    required String text,
  }) async {
    _sent.add((to: to, subject: subject, text: text, sentAt: DateTime.now()));
    if (_sent.length > capacity) _sent.removeAt(0);
    await inner.send(to: to, subject: subject, text: text);
  }

  @override
  List<SentMail> messagesFor(String email) => _sent.reversed
      .where((m) => m.to.toLowerCase() == email.toLowerCase())
      .toList();
}

/// Guarda los correos en memoria (pruebas).
class MemoryMailer implements Mailer, MailOutbox {
  /// Correos enviados, el más reciente al final.
  final List<SentMail> sent = [];

  @override
  Future<void> send({
    required String to,
    required String subject,
    required String text,
  }) async =>
      sent.add((to: to, subject: subject, text: text, sentAt: DateTime.now()));

  @override
  List<SentMail> messagesFor(String email) => sent.reversed
      .where((m) => m.to.toLowerCase() == email.toLowerCase())
      .toList();

  /// Último código de 6 dígitos enviado a [to].
  String lastCodeFor(String to) {
    final message = sent.lastWhere((m) => m.to == to);
    return RegExp(r'\b(\d{6})\b').firstMatch(message.text)!.group(1)!;
  }
}
