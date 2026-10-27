import 'package:postgres/postgres.dart';

import 'config.dart';
import 'db/database.dart';
import 'security.dart';
import 'services/card_service.dart';

/// Credenciales de demostración (también en README y docs/demo.md).
abstract final class DemoUsers {
  /// Administrador.
  static const adminEmail = 'admin@monedero.local';

  /// Contraseña del administrador.
  static const adminPassword = 'Admin1234';

  /// Cajero.
  static const cashierEmail = 'cajero@monedero.local';

  /// Contraseña del cajero.
  static const cashierPassword = 'Cajero1234';

  /// Contraseña de los titulares de ejemplo.
  static const holderPassword = 'Titular1234';

  /// PIN de los titulares de ejemplo.
  static const holderPin = '1234';
}

/// Siembra la base según [ApiConfig.sampleData]: datos de ejemplo
/// ([seedDemo]) o solo la cuenta de administración ([seedAdmin]).
Future<bool> seedDatabase(Connection owner, ApiConfig config) =>
    config.sampleData ? seedDemo(owner, config) : seedAdmin(owner, config);

/// Crea la única cuenta de administración con `ADMIN_EMAIL` y
/// `ADMIN_PASSWORD`. Sin titulares, cajas ni saldos: todo se registra desde
/// la app. Es idempotente: si ya hay personal, no hace nada.
Future<bool> seedAdmin(Connection owner, ApiConfig config) async {
  final existing = await owner.execute('SELECT 1 FROM staff_users LIMIT 1');
  if (existing.isNotEmpty) return false;
  if (config.adminPassword.length < 10) {
    throw StateError(
      'ADMIN_PASSWORD debe tener al menos 10 caracteres (ver .env.example).',
    );
  }
  final hasher = PasswordHasher(rounds: config.passwordHashRounds);
  await query(
    owner,
    'INSERT INTO staff_users (full_name, email, password_hash, role) '
    "VALUES ('Administración', @e, @p, 'ADMIN')",
    {'e': config.adminEmail, 'p': hasher.hash(config.adminPassword)},
  );
  return true;
}

/// Siembra datos de demostración usando la conexión del dueño ([owner]).
///
/// Es idempotente: si ya hay personal, no hace nada y devuelve `false`.
/// Los saldos iniciales se registran como recargas reales en el libro para
/// que la conciliación cuadre.
Future<bool> seedDemo(Connection owner, ApiConfig config) async {
  final existing = await owner.execute('SELECT 1 FROM staff_users LIMIT 1');
  if (existing.isNotEmpty) return false;
  final hasher = PasswordHasher(rounds: config.passwordHashRounds);

  Future<String> insertId(String sql, Map<String, Object?> params) async =>
      (await query(owner, sql, params)).first['id'] as String;

  const staffSql =
      'INSERT INTO staff_users (full_name, email, password_hash, role) '
      'VALUES (@n, @e, @p, @r) RETURNING id';
  final adminId = await insertId(staffSql, {
    'n': 'Administración Demo',
    'e': DemoUsers.adminEmail,
    'p': hasher.hash(DemoUsers.adminPassword),
    'r': 'ADMIN',
  });
  await insertId(staffSql, {
    'n': 'Cajero Demo',
    'e': DemoUsers.cashierEmail,
    'p': hasher.hash(DemoUsers.cashierPassword),
    'r': 'CASHIER',
  });

  for (final (name, email, cents) in [
    ('Ana López', 'ana@demo.local', 5000),
    ('Bruno Pérez', 'bruno@demo.local', 1500),
  ]) {
    final holderId = await insertId(
      'INSERT INTO cardholders (full_name, email, email_verified_at, '
      'password_hash, pin_hash) VALUES (@n, @e, now(), @p, @pin) RETURNING id',
      {
        'n': name,
        'e': email,
        'p': hasher.hash(DemoUsers.holderPassword),
        'pin': hasher.hash(DemoUsers.holderPin),
      },
    );
    final creds = await newCardCredentials(owner, config);
    final cardId = await insertId(
      'INSERT INTO cards (number, uid, signature, cardholder_id, status, '
      "balance_cents) VALUES (@n, @u, @s, @h:uuid, 'ACTIVE', @b) RETURNING id",
      {
        'n': creds.number,
        'u': creds.uid,
        's': creds.signature,
        'h': holderId,
        'b': cents,
      },
    );
    await query(
      owner,
      'INSERT INTO transactions (card_id, type, amount_cents, '
      'balance_after_cents, idempotency_key, staff_user_id) '
      "VALUES (@c:uuid, 'TOP_UP', @a, @a, @k, @s:uuid)",
      {'c': cardId, 'a': cents, 'k': 'seed:$email', 's': adminId},
    );
  }
  return true;
}
