import 'dart:convert';

import 'card_number.dart';
import 'card_signature.dart';
import 'terminal_code.dart';

/// Contenidos de los códigos QR que la app genera y escanea.
///
/// Hay tres tipos de QR, todos en texto plano para que cualquier lector los
/// entienda:
///
/// - **Tarjeta**: JSON `{"number", "uid", "signature"}` (ver
///   [CardCredentials.toJson]). La caja lo escanea en lugar de leer el chip.
/// - **Vínculo de caja**: JSON `{"type": "monedero-terminal",
///   "terminalToken": "…"}`. Administración lo muestra una sola vez al crear
///   una caja y el dispositivo de la caja lo escanea.
/// - **Servidor**: la URL de la API tal cual (`https://…`). La cámara del
///   celular la abre en el navegador y la app la usa como servidor.
abstract final class QrPayloads {
  /// Valor de `type` del QR de vínculo de caja.
  static const terminalLinkType = 'monedero-terminal';

  static final _hex14 = RegExp(r'^[0-9A-F]{14}$');
  static final _hex32 = RegExp(r'^[0-9A-F]{32}$');
  static final _token = RegExp(r'^[0-9a-f]{64}$');

  /// Lee las credenciales de una tarjeta desde el texto de su QR.
  ///
  /// Devuelve `null` si el texto no es JSON, si falta un campo o si el
  /// número no pasa Luhn. La firma **no** se verifica aquí: la llave maestra
  /// solo vive en el servidor, que es quien la valida.
  static CardCredentials? card(String raw) {
    final json = _decode(raw);
    if (json == null) return null;
    final number = json['number'];
    final uid = json['uid'];
    final signature = json['signature'];
    if (number is! String || uid is! String || signature is! String) {
      return null;
    }
    final card = CardCredentials(
      number: number.trim(),
      uid: uid.trim().toUpperCase(),
      signature: signature.trim().toUpperCase(),
    );
    final valid =
        CardNumber.isValid(card.number) &&
        _hex14.hasMatch(card.uid) &&
        _hex32.hasMatch(card.signature);
    return valid ? card : null;
  }

  /// Texto del QR de vínculo para la credencial de caja [terminalToken].
  static String terminalLink(String terminalToken) =>
      jsonEncode({'type': terminalLinkType, 'terminalToken': terminalToken});

  /// Lee la credencial de caja desde un QR de vínculo, desde el código de
  /// la caja ([TerminalCode], con o sin guiones) o desde una credencial
  /// antigua de 64 caracteres hexadecimales. Devuelve `null` si no es
  /// ninguno.
  static String? terminalToken(String raw) {
    final text = raw.trim();
    if (_token.hasMatch(text)) return text;
    if (TerminalCode.normalize(text) case final code?) return code;
    final json = _decode(text);
    final token = json?['terminalToken'];
    if (json?['type'] != terminalLinkType || token is! String) return null;
    return _token.hasMatch(token) ? token : TerminalCode.normalize(token);
  }

  /// Normaliza la URL de un servidor escrita o escaneada: agrega `http://`
  /// si falta y quita la barra final. Devuelve `null` si no es una URL
  /// `http` o `https` con host.
  static String? serverUrl(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  static Map<String, Object?>? _decode(String raw) {
    try {
      final value = jsonDecode(raw.trim());
      return value is Map<String, Object?> ? value : null;
    } on FormatException {
      return null;
    }
  }
}
