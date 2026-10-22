import 'package:monedero_core/monedero_core.dart';
import 'package:postgres/postgres.dart';

import '../config.dart';
import '../db/database.dart';
import '../errors.dart';
import '../mailer.dart';
import '../security.dart';

/// Registro, verificación de correo, inicio de sesión y códigos por correo.
class AuthService {
  /// Crea el servicio.
  AuthService(this.pool, this.config, this.hasher, this.tokens, this.mailer);

  /// Pool de la API.
  final Pool<void> pool;

  /// Configuración.
  final ApiConfig config;

  /// Hash de contraseñas y PIN.
  final PasswordHasher hasher;

  /// Emisión de JWT.
  final TokenService tokens;

  /// Envío de códigos.
  final Mailer mailer;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Registra un titular y envía el código de verificación al correo.
  Future<Map<String, Object?>> registerCardholder({
    required String fullName,
    required String email,
    required String password,
    required String pin,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (fullName.trim().isEmpty || !_emailPattern.hasMatch(normalized)) {
      throw const ApiException(
        ApiErrorCode.validationFailed,
        'Nombre y correo válidos son obligatorios.',
      );
    }
    if (password.length < 8) {
      throw const ApiException(
        ApiErrorCode.validationFailed,
        'La contraseña debe tener al menos 8 caracteres.',
      );
    }
    validatePin(pin);
    final String id;
    try {
      final rows = await query(
        pool,
        'INSERT INTO cardholders (full_name, email, password_hash, pin_hash) '
        'VALUES (@n, @e, @p, @pin) RETURNING id',
        {
          'n': fullName.trim(),
          'e': normalized,
          'p': hasher.hash(password),
          'pin': hasher.hash(pin),
        },
      );
      id = rows.first['id'] as String;
    } on Object catch (error) {
      if (!isUniqueViolation(error)) rethrow;
      throw const ApiException(
        ApiErrorCode.conflict,
        'Ya existe una cuenta con ese correo.',
      );
    }
    await sendCode(
      cardholderId: id,
      email: normalized,
      purpose: 'VERIFY_EMAIL',
      subject: 'Tu código de verificación',
    );
    return {'cardholderId': id, 'email': normalized};
  }

  /// Confirma el correo con el código recibido.
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final holder = await _holderByEmail(email);
    if (holder == null) {
      throw const ApiException(
        ApiErrorCode.invalidVerificationCode,
        'Código incorrecto o vencido.',
      );
    }
    await consumeCode(
      cardholderId: holder['id'] as String,
      purpose: 'VERIFY_EMAIL',
      code: code,
    );
    await query(
      pool,
      'UPDATE cardholders SET email_verified_at = now() WHERE id = @id:uuid',
      {'id': holder['id']},
    );
  }

  /// Inicio de sesión del titular (correo verificado + contraseña).
  Future<Map<String, Object?>> loginCardholder(
    String email,
    String password,
  ) async {
    final holder = await _holderByEmail(email);
    if (holder == null ||
        holder['email_verified_at'] == null ||
        !hasher.verify(password, holder['password_hash'] as String)) {
      throw const ApiException(
        ApiErrorCode.invalidCredentials,
        'Correo o contraseña incorrectos, o correo sin verificar.',
      );
    }
    final principal = Principal(
      id: holder['id'] as String,
      role: Role.cardholder,
    );
    return _session(principal, holder['full_name'] as String);
  }

  /// Inicio de sesión de cajeros y administradores.
  Future<Map<String, Object?>> loginStaff(String email, String password) async {
    final rows = await query(
      pool,
      'SELECT id, full_name, password_hash, role FROM staff_users '
      'WHERE email = CAST(@e AS citext) AND active',
      {'e': email.trim().toLowerCase()},
    );
    final staff = rows.firstOrNull;
    if (staff == null ||
        !hasher.verify(password, staff['password_hash'] as String)) {
      throw const ApiException(
        ApiErrorCode.invalidCredentials,
        'Correo o contraseña incorrectos.',
      );
    }
    final principal = Principal(
      id: staff['id'] as String,
      role: Role.fromWire(staff['role'] as String),
    );
    return _session(principal, staff['full_name'] as String);
  }

  /// Cambia el PIN del titular verificando el actual.
  Future<void> changePin(
    String cardholderId,
    String currentPin,
    String newPin,
  ) async {
    validatePin(newPin);
    final rows = await query(
      pool,
      'SELECT pin_hash FROM cardholders WHERE id = @id:uuid',
      {'id': cardholderId},
    );
    if (rows.isEmpty ||
        !hasher.verify(currentPin, rows.first['pin_hash'] as String)) {
      throw const ApiException(
        ApiErrorCode.invalidPin,
        'PIN actual incorrecto.',
      );
    }
    await query(
      pool,
      'UPDATE cardholders SET pin_hash = @h, failed_pin_attempts = 0, '
      'pin_locked_until = NULL WHERE id = @id:uuid',
      {'h': hasher.hash(newPin), 'id': cardholderId},
    );
  }

  /// Genera, guarda (hash) y envía un código de 6 dígitos.
  Future<void> sendCode({
    required String cardholderId,
    required String email,
    required String purpose,
    required String subject,
    String? cardId,
  }) async {
    final code = randomCode();
    await query(
      pool,
      'INSERT INTO verification_codes (cardholder_id, purpose, card_id, '
      "code_hash, expires_at) VALUES (@h:uuid, @p, @c:uuid, @x, now() + interval '10 minutes')",
      {'h': cardholderId, 'p': purpose, 'c': cardId, 'x': sha256Hex(code)},
    );
    await mailer.send(
      to: email,
      subject: subject,
      text:
          'Tu código es $code\n\nVence en 10 minutos. '
          'Si no lo solicitaste, ignora este correo.',
    );
  }

  /// Valida el código más reciente de [purpose]; aplica límite de intentos.
  Future<void> consumeCode({
    required String cardholderId,
    required String purpose,
    required String code,
    String? cardId,
  }) async {
    final rows = await query(
      pool,
      'SELECT id, code_hash, attempts, (expires_at < now()) AS expired '
      'FROM verification_codes WHERE cardholder_id = @h:uuid AND purpose = @p '
      'AND consumed_at IS NULL AND card_id IS NOT DISTINCT FROM @c:uuid '
      'ORDER BY created_at DESC LIMIT 1',
      {'h': cardholderId, 'p': purpose, 'c': cardId},
    );
    final row = rows.firstOrNull;
    if (row == null || row['expired'] == true) {
      throw const ApiException(
        ApiErrorCode.invalidVerificationCode,
        'Código incorrecto o vencido.',
      );
    }
    if ((row['attempts'] as int) >= config.maxVerificationCodeAttempts) {
      throw const ApiException(
        ApiErrorCode.tooManyAttempts,
        'Demasiados intentos. Solicita un código nuevo.',
      );
    }
    if (sha256Hex(code.trim()) != row['code_hash']) {
      await query(
        pool,
        'UPDATE verification_codes SET attempts = attempts + 1 WHERE id = @id:uuid',
        {'id': row['id']},
      );
      throw const ApiException(
        ApiErrorCode.invalidVerificationCode,
        'Código incorrecto o vencido.',
      );
    }
    await query(
      pool,
      'UPDATE verification_codes SET consumed_at = now() WHERE id = @id:uuid',
      {'id': row['id']},
    );
  }

  /// Lanza error si [pin] no son exactamente 4 dígitos.
  static void validatePin(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const ApiException(
        ApiErrorCode.validationFailed,
        'El PIN debe tener 4 dígitos.',
      );
    }
  }

  Future<Map<String, dynamic>?> _holderByEmail(String email) async =>
      (await query(
        pool,
        'SELECT id, full_name, password_hash, email_verified_at '
        'FROM cardholders WHERE email = CAST(@e AS citext)',
        {'e': email.trim().toLowerCase()},
      )).firstOrNull;

  Map<String, Object?> _session(Principal principal, String name) => {
    'accessToken': tokens.issue(principal),
    'tokenType': 'Bearer',
    'expiresInSeconds': config.jwtTtl.inSeconds,
    'role': principal.role.wireName,
    'userId': principal.id,
    'fullName': name,
  };
}
