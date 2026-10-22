import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:monedero_core/monedero_core.dart';

/// Hash de contraseñas y PIN con bcrypt.
class PasswordHasher {
  /// Crea el hasher con el costo [rounds].
  const PasswordHasher({this.rounds = 10});

  /// Costo de bcrypt.
  final int rounds;

  /// Calcula el hash de [secret].
  String hash(String secret) =>
      BCrypt.hashpw(secret, BCrypt.gensalt(logRounds: rounds));

  /// Verifica [secret] contra [hash].
  bool verify(String secret, String hash) => BCrypt.checkpw(secret, hash);
}

/// Identidad autenticada que viaja en el JWT.
class Principal {
  /// Crea la identidad.
  const Principal({required this.id, required this.role});

  /// Id del titular o del personal.
  final String id;

  /// Rol validado por la API.
  final Role role;
}

/// Emisión y verificación de JWT HS256 de corta duración.
class TokenService {
  /// Crea el servicio con [secret] y duración [ttl].
  TokenService(this.secret, this.ttl);

  /// Secreto HS256.
  final String secret;

  /// Duración de cada token.
  final Duration ttl;

  /// Emite un token para [principal].
  String issue(Principal principal) =>
      JWT({'sub': principal.id, 'role': principal.role.wireName})
          .sign(SecretKey(secret), expiresIn: ttl);

  /// Verifica [token]; devuelve `null` si es inválido o venció.
  Principal? verify(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      final payload = jwt.payload as Map<String, dynamic>;
      return Principal(
        id: payload['sub'] as String,
        role: Role.fromWire(payload['role'] as String),
      );
    } on JWTException {
      return null;
    } on StateError {
      return null;
    }
  }
}

/// SHA-256 en hex (credenciales de terminal y códigos de verificación).
String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();

/// Secreto aleatorio en hex de [bytes] bytes.
String randomToken([int bytes = 32]) {
  final rng = Random.secure();
  return List.generate(
    bytes,
    (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Código numérico de 6 dígitos para correo.
String randomCode() => (Random.secure().nextInt(900000) + 100000).toString();
