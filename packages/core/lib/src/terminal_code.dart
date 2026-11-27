import 'dart:math';

/// Código de acceso de una caja: 12 caracteres sin letras ni números que se
/// confundan (sin `0`, `O`, `1`, `I`), que administración entrega al crear
/// la caja. Se muestra en grupos (`K7M4-Q2XP-HT9W`) y viaja normalizado
/// (`K7M4Q2XPHT9W`) en el encabezado `X-Terminal-Token`.
abstract final class TerminalCode {
  /// Caracteres permitidos (32: 60 bits de azar en 12 caracteres).
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Largo del código sin guiones.
  static const length = 12;

  /// Genera un código nuevo con un generador seguro.
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    return List.generate(
      length,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
  }

  /// Quita espacios y guiones y pasa a mayúsculas. Devuelve `null` si el
  /// resultado no es un código válido.
  static String? normalize(String raw) {
    final code = raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (code.length != length) return null;
    for (final ch in code.split('')) {
      if (!alphabet.contains(ch)) return null;
    }
    return code;
  }

  /// `K7M4Q2XPHT9W` → `K7M4-Q2XP-HT9W`.
  static String format(String code) => [
    for (var i = 0; i < code.length; i += 4)
      code.substring(i, min(i + 4, code.length)),
  ].join('-');
}
