/// Estados de la tarjeta (regla 8). Solo [active] mueve dinero.
enum CardStatus {
  /// Emitida, aún no entregada.
  pending('PENDING'),

  /// En uso: recibe recargas y débitos.
  active('ACTIVE'),

  /// Reportada como perdida.
  blocked('BLOCKED'),

  /// Sustituida por otra tarjeta; saldo trasladado.
  replaced('REPLACED');

  const CardStatus(this.wireName);

  /// Nombre en la base y en el JSON.
  final String wireName;

  /// Busca el estado por su [wireName].
  static CardStatus fromWire(String value) =>
      CardStatus.values.firstWhere((s) => s.wireName == value);
}

/// Tipos de movimiento del libro.
enum TransactionType {
  /// Recarga en caja (+).
  topUp('TOP_UP', 1),

  /// Cobro en caja (−).
  debit('DEBIT', -1),

  /// Saldo que sale de la tarjeta repuesta (−).
  replacementOut('REPLACEMENT_OUT', -1),

  /// Saldo que entra a la tarjeta nueva (+).
  replacementIn('REPLACEMENT_IN', 1);

  const TransactionType(this.wireName, this.sign);

  /// Nombre en la base y en el JSON.
  final String wireName;

  /// +1 si suma al saldo, −1 si resta.
  final int sign;

  /// Busca el tipo por su [wireName].
  static TransactionType fromWire(String value) =>
      TransactionType.values.firstWhere((t) => t.wireName == value);
}

/// Roles validados por la API.
enum Role {
  /// Titular de la tarjeta.
  cardholder('CARDHOLDER'),

  /// Cajero.
  cashier('CASHIER'),

  /// Administrador.
  admin('ADMIN');

  const Role(this.wireName);

  /// Nombre en el JWT y en la base.
  final String wireName;

  /// Busca el rol por su [wireName].
  static Role fromWire(String value) =>
      Role.values.firstWhere((r) => r.wireName == value);
}
