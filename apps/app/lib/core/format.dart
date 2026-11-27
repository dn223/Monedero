/// Formatos de fecha y número para mostrar en pantalla.
abstract final class Fmt {
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `25/10 14:05` en hora local, a partir de una fecha ISO-8601 de la API.
  static String dateTime(String iso) {
    final t = DateTime.parse(iso).toLocal();
    return '${_two(t.day)}/${_two(t.month)} ${_two(t.hour)}:${_two(t.minute)}';
  }

  /// `14:05` en hora local.
  static String time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  /// "Hace 3 min", "hace 2 h" o la fecha, para la última conexión.
  static String ago(String? iso) {
    if (iso == null) return 'Nunca';
    final t = DateTime.parse(iso).toLocal();
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Hace un momento';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'Hace ${d.inHours} h';
    return dateTime(iso);
  }

  /// Número de tarjeta en grupos de 4: `9990 1424 0571 2970`.
  static String cardNumber(String number) => [
    for (var i = 0; i < number.length; i += 4)
      number.substring(i, (i + 4).clamp(0, number.length)),
  ].join(' ');

  /// Código de caja en dos grupos: `482 913`.
  static String payCode(String code) =>
      code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

  /// Nombre del día y mes corto para ejes: `25 oct`.
  static String shortDay(String isoDay) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final d = DateTime.parse(isoDay);
    return '${d.day} ${months[d.month - 1]}';
  }
}
