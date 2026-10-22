import 'dart:math';

/// Números de tarjeta de 16 dígitos con dígito verificador Luhn (regla 9).
abstract final class CardNumber {
  /// Longitud del número de tarjeta.
  static const int length = 16;

  /// Calcula el dígito verificador Luhn de [partial] (solo dígitos).
  static int luhnCheckDigit(String partial) {
    var sum = 0;
    var doubleIt = true;
    for (var i = partial.length - 1; i >= 0; i--) {
      var digit = partial.codeUnitAt(i) - 48;
      if (doubleIt) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleIt = !doubleIt;
    }
    return (10 - sum % 10) % 10;
  }

  /// `true` si [number] tiene 16 dígitos y su dígito Luhn es correcto.
  static bool isValid(String number) {
    if (!RegExp(r'^\d{16}$').hasMatch(number)) return false;
    final body = number.substring(0, length - 1);
    return luhnCheckDigit(body) == number.codeUnitAt(length - 1) - 48;
  }

  /// Genera un número aleatorio con el [prefix] dado y dígito Luhn.
  ///
  /// La unicidad la garantiza la base (`UNIQUE`); la API regenera si choca.
  static String generate(String prefix, {Random? random}) {
    if (!RegExp(r'^\d{1,8}$').hasMatch(prefix)) {
      throw ArgumentError.value(prefix, 'prefix', 'De 1 a 8 dígitos.');
    }
    final rng = random ?? Random.secure();
    final buffer = StringBuffer(prefix);
    while (buffer.length < length - 1) {
      buffer.write(rng.nextInt(10));
    }
    final body = buffer.toString();
    return '$body${luhnCheckDigit(body)}';
  }

  /// Muestra solo los últimos 4 dígitos: `•••• 1234`.
  static String masked(String number) =>
      '•••• ${number.substring(number.length - 4)}';
}
