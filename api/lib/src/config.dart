/// Configuración de la API leída de variables de entorno.
///
/// Todas las variables están documentadas en `.env.example`. Ningún secreto
/// tiene valor por defecto en el código: si falta uno obligatorio la API no
/// arranca.
class ApiConfig {
  /// Crea una configuración explícita (útil en pruebas).
  const ApiConfig({
    this.port = 8080,
    this.allowedOrigins = const [],
    this.demoMode = false,
    this.database = const DatabaseConfig(),
    this.jwtSecret = '',
    this.jwtTtl = const Duration(minutes: 15),
    this.cardMasterKey = '',
    this.cardNumberPrefix = '9990',
    this.pinRequiredAboveCents = 2500,
    this.maxPinAttempts = 3,
    this.maxVerificationCodeAttempts = 5,
    this.smtpHost = 'localhost',
    this.smtpPort = 1025,
    this.mailFrom = 'no-responder@monedero.local',
    this.passwordHashRounds = 10,
    this.refreshTtl = const Duration(days: 7),
    this.rateLimitPerMinute = 0,
    this.rateLimitAuthPerMinute = 0,
    this.rateLimitTrustProxy = false,
    this.webDir = '',
  });

  /// Construye la configuración desde un mapa de entorno, normalmente
  /// `Platform.environment`.
  ///
  /// Lanza [StateError] si un valor tiene un formato inválido.
  factory ApiConfig.fromEnvironment(Map<String, String> env) {
    return ApiConfig(
      port: _int(env, 'API_PORT', 8080),
      allowedOrigins: _parseList(env['CORS_ALLOWED_ORIGINS']),
      demoMode: _parseBool(env['DEMO_MODE'], name: 'DEMO_MODE'),
      database: DatabaseConfig(
        host: env['DATABASE_HOST'] ?? 'localhost',
        port: _int(env, 'DATABASE_PORT', _int(env, 'POSTGRES_PORT', 5432)),
        name: env['POSTGRES_DB'] ?? 'monedero',
        user: env['POSTGRES_APP_USER'] ?? 'monedero_app',
        password: env['POSTGRES_APP_PASSWORD'] ?? '',
      ),
      jwtSecret: env['JWT_SECRET'] ?? '',
      jwtTtl: Duration(minutes: _int(env, 'JWT_TTL_MINUTES', 15)),
      cardMasterKey: env['CARD_MASTER_KEY'] ?? '',
      cardNumberPrefix: env['CARD_NUMBER_PREFIX'] ?? '9990',
      pinRequiredAboveCents: _int(env, 'PIN_REQUIRED_ABOVE_CENTS', 2500),
      maxPinAttempts: _int(env, 'MAX_PIN_ATTEMPTS', 3),
      maxVerificationCodeAttempts: _int(
        env,
        'MAX_VERIFICATION_CODE_ATTEMPTS',
        5,
      ),
      smtpHost: env['SMTP_HOST'] ?? 'localhost',
      smtpPort: _int(env, 'SMTP_PORT', _int(env, 'MAILPIT_SMTP_PORT', 1025)),
      mailFrom: env['MAIL_FROM'] ?? 'no-responder@monedero.local',
      refreshTtl: Duration(days: _int(env, 'REFRESH_TOKEN_TTL_DAYS', 7)),
      rateLimitPerMinute: _int(env, 'RATE_LIMIT_PER_MINUTE', 600),
      rateLimitAuthPerMinute: _int(env, 'RATE_LIMIT_AUTH_PER_MINUTE', 30),
      rateLimitTrustProxy: _parseBool(
        env['RATE_LIMIT_TRUST_PROXY'],
        name: 'RATE_LIMIT_TRUST_PROXY',
      ),
      webDir: env['WEB_DIR'] ?? '',
    );
  }

  /// Puerto TCP donde escucha la API.
  final int port;

  /// Orígenes web autorizados por CORS (por ejemplo `http://localhost:5000`).
  ///
  /// Las apps Android no envían `Origin`, así que CORS solo afecta a la web.
  final List<String> allowedOrigins;

  /// Activa la lista de tarjetas de demostración y el reinicio de la demo.
  /// Desactivado por defecto; nunca debe activarse en producción.
  final bool demoMode;

  /// Conexión a PostgreSQL con el usuario de permisos mínimos.
  final DatabaseConfig database;

  /// Secreto HS256 de los JWT.
  final String jwtSecret;

  /// Duración de los tokens de acceso.
  final Duration jwtTtl;

  /// Llave maestra para firmar tarjetas (solo en el servidor).
  final String cardMasterKey;

  /// Prefijo de los números de tarjeta.
  final String cardNumberPrefix;

  /// Débitos mayores a este monto exigen PIN.
  final int pinRequiredAboveCents;

  /// Intentos de PIN fallidos antes de bloquear 15 minutos.
  final int maxPinAttempts;

  /// Intentos por código de verificación.
  final int maxVerificationCodeAttempts;

  /// Servidor SMTP (Mailpit en local).
  final String smtpHost;

  /// Puerto SMTP.
  final int smtpPort;

  /// Remitente de los correos.
  final String mailFrom;

  /// Costo de bcrypt (las pruebas usan uno menor para ir rápido).
  final int passwordHashRounds;

  /// Duración de los tokens de renovación de sesión (refresh).
  final Duration refreshTtl;

  /// Solicitudes por minuto y cliente a `/v1/...`. `0` desactiva el límite
  /// (solo en pruebas; desde el entorno el valor por defecto es 600).
  final int rateLimitPerMinute;

  /// Límite más estricto para inicio de sesión, registro y sesiones demo.
  /// `0` lo desactiva (desde el entorno el valor por defecto es 30).
  final int rateLimitAuthPerMinute;

  /// Si es `true`, identifica al cliente por `CF-Connecting-IP` o
  /// `X-Forwarded-For` (detrás del túnel de Cloudflare o de un proxy).
  /// Solo debe activarse cuando un proxy confiable pone esos encabezados.
  final bool rateLimitTrustProxy;

  /// Carpeta con el build web de Flutter que la API sirve en `/`
  /// (vacío = no sirve la app web).
  final String webDir;

  /// Lanza [StateError] si faltan los secretos necesarios para operar.
  void requireSecrets() {
    if (jwtSecret.length < 32) {
      throw StateError('JWT_SECRET falta o tiene menos de 32 caracteres.');
    }
    if (cardMasterKey.length < 32) {
      throw StateError('CARD_MASTER_KEY falta o tiene menos de 32 caracteres.');
    }
    if (database.password.isEmpty) {
      throw StateError('Falta POSTGRES_APP_PASSWORD.');
    }
  }

  static int _int(Map<String, String> env, String name, int fallback) {
    final text = env[name];
    if (text == null || text.trim().isEmpty) return fallback;
    final value = int.tryParse(text.trim());
    if (value == null ||
        value < 0 ||
        (name.endsWith('PORT') && value > 65535)) {
      throw StateError('$name inválido: "$text".');
    }
    if (name.endsWith('PORT') && value == 0) {
      throw StateError('$name inválido: "$text".');
    }
    return value;
  }

  static List<String> _parseList(String? value) => (value ?? '')
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  static bool _parseBool(String? value, {required String name}) {
    switch ((value ?? 'false').trim().toLowerCase()) {
      case 'true' || '1' || 'yes' || 'si' || 'sí':
        return true;
      case 'false' || '0' || 'no' || '':
        return false;
      default:
        throw StateError('$name debe ser true o false, no "$value".');
    }
  }
}

/// Datos de conexión a PostgreSQL.
class DatabaseConfig {
  /// Crea la configuración de conexión.
  const DatabaseConfig({
    this.host = 'localhost',
    this.port = 5432,
    this.name = 'monedero',
    this.user = 'monedero_app',
    this.password = '',
  });

  /// Host del servidor.
  final String host;

  /// Puerto del servidor.
  final int port;

  /// Nombre de la base.
  final String name;

  /// Usuario (en la API, `monedero_app`).
  final String user;

  /// Contraseña.
  final String password;

  /// Copia con otros valores.
  DatabaseConfig copyWith({String? name, String? user, String? password}) =>
      DatabaseConfig(
        host: host,
        port: port,
        name: name ?? this.name,
        user: user ?? this.user,
        password: password ?? this.password,
      );
}
