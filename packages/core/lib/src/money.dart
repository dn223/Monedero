/// Reglas y formato del dinero. **Todo monto es `int` en centavos** (ADR 0004).
abstract final class Money {
  /// Unidad mínima de recarga: $5.00.
  static const int topUpStepCents = 500;

  /// `true` si [amountCents] es una recarga válida: mayor que cero y múltiplo
  /// de $5 (regla 2).
  static bool isValidTopUp(int amountCents) =>
      amountCents > 0 && amountCents % topUpStepCents == 0;

  /// `true` si [amountCents] es un débito válido por sí mismo: mayor que cero.
  /// La comparación con el saldo la hace la API dentro de la transacción.
  static bool isValidDebitAmount(int amountCents) => amountCents > 0;

  /// Formatea centavos como USD con dos decimales: `735` → `$7.35`,
  /// `123456` → `$1,234.56`, `-500` → `-$5.00`.
  static String format(int cents) {
    final negative = cents < 0;
    final abs = cents.abs();
    final dollars = (abs ~/ 100).toString();
    final rest = (abs % 100).toString().padLeft(2, '0');
    final grouped = StringBuffer();
    for (var i = 0; i < dollars.length; i++) {
      if (i > 0 && (dollars.length - i) % 3 == 0) grouped.write(',');
      grouped.write(dollars[i]);
    }
    return '${negative ? '-' : ''}\$$grouped.$rest';
  }

  /// Convierte un texto como `7.35`, `$7.35`, `1,234.5` o `20` a centavos
  /// **sin pasar por `double`**. Devuelve `null` si el texto no es válido o
  /// tiene más de dos decimales.
  static int? parseCents(String text) {
    final cleaned = text.trim().replaceAll(r'$', '').replaceAll(',', '');
    final match = RegExp(r'^(\d{1,12})(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return whole * 100 + int.parse(fraction);
  }
}
