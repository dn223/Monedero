import 'dart:convert';

import 'package:monedero_api/monedero_api.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

/// Entorno de integración: base `monedero_test` recién creada y migrada en
/// el PostgreSQL de Docker, API en memoria y correos en memoria.
class Harness {
  Harness._(
    this.config,
    this.owner,
    this.ownerConfig,
    this.pool,
    this.mailer,
    this.handler,
  );

  /// Configuración de prueba.
  final ApiConfig config;

  /// Conexión del dueño (para pruebas de la base y sembrado).
  final Connection owner;

  /// Datos de conexión del dueño a la base de pruebas.
  final DatabaseConfig ownerConfig;

  /// Pool con el usuario de la API (permisos mínimos).
  final Pool<void> pool;

  /// Correos enviados.
  final MemoryMailer mailer;

  /// Manejador HTTP completo.
  final Handler handler;

  /// Crea la base de pruebas [database] desde cero. Cada archivo de pruebas
  /// usa su propia base, porque `dart test` corre los archivos en paralelo.
  static Future<Harness> start({String database = 'monedero_test'}) async {
    final env = loadEnv(findRepoEnv());
    final base = ApiConfig.fromEnvironment(env).database;
    final ownerCfg = base.copyWith(
      user: env['POSTGRES_OWNER_USER'] ?? 'monedero_owner',
      password: env['POSTGRES_OWNER_PASSWORD'] ?? '',
    );
    final admin = await openConnection(ownerCfg.copyWith(name: 'postgres'));
    await admin.execute('DROP DATABASE IF EXISTS $database WITH (FORCE)');
    await admin.execute('CREATE DATABASE $database');
    await admin.close();

    final ownerDb = ownerCfg.copyWith(name: database);
    final owner = await openConnection(ownerDb);
    final appDb = base.copyWith(
      name: database,
      password: env['POSTGRES_APP_PASSWORD'] ?? 'app-test-password',
    );
    final migrator = Migrator(owner, findMigrationsDir());
    await migrator.ensureAppRole(appDb.user, appDb.password);
    await migrator.migrate();

    final config = ApiConfig(
      demoMode: true,
      database: appDb,
      jwtSecret: 'secreto-de-prueba-con-al-menos-32-caracteres',
      cardMasterKey: 'llave-maestra-de-prueba-de-32-caracteres!!',
      passwordHashRounds: 4,
      sampleData: true,
    );
    await seedDemo(owner, config);
    final pool = openPool(
      appDb,
      maxConnections: 10,
      acquireTimeout: const Duration(minutes: 2),
    );
    final mailer = MemoryMailer();
    final handler = buildApiHandler(
      config,
      services: Services(
        config,
        pool,
        mailer,
        demoReset: DemoResetService(config, ownerDb, findMigrationsDir()),
      ),
    );
    return Harness._(config, owner, ownerDb, pool, mailer, handler);
  }

  /// Servicios con un inyector de fallas en la reposición.
  Services servicesWithFault(FaultHook hook) =>
      Services(config, pool, mailer, replacementFault: hook);

  /// Cierra conexiones.
  Future<void> close() async {
    await pool.close();
    await owner.close();
  }

  /// Llama a la API y devuelve `(status, cuerpo JSON)`.
  Future<(int, Map<String, Object?>)> call(
    String method,
    String path, {
    Object? body,
    String? token,
    String? terminal,
    String? key,
  }) async {
    final response = await handler(
      Request(
        method,
        Uri.parse('http://api.test$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {
          'content-type': 'application/json',
          if (token != null) 'authorization': 'Bearer $token',
          'x-terminal-token': ?terminal,
          'idempotency-key': ?key,
        },
      ),
    );
    final text = await response.readAsString();
    return (
      response.statusCode,
      text.isEmpty
          ? <String, Object?>{}
          : jsonDecode(text) as Map<String, Object?>,
    );
  }

  /// Inicia sesión del personal y devuelve el token.
  Future<String> staffToken(String email, String password) async {
    final (_, body) = await call(
      'POST',
      '/v1/auth/staff/login',
      body: {'email': email, 'password': password},
    );
    return body['accessToken']! as String;
  }

  /// Contexto de caja listo: tokens de admin y cajero y un terminal.
  Future<CashDesk> cashDesk() async {
    final admin = await staffToken(
      DemoUsers.adminEmail,
      DemoUsers.adminPassword,
    );
    final cashier = await staffToken(
      DemoUsers.cashierEmail,
      DemoUsers.cashierPassword,
    );
    final (_, t) = await call(
      'POST',
      '/v1/admin/terminals',
      body: {'name': 'Caja de prueba'},
      token: admin,
    );
    return CashDesk(this, admin, cashier, t['terminalToken']! as String);
  }

  /// Saldo y conciliación de una tarjeta leídos directamente de la base.
  Future<({int balance, int difference, String status, int txCount})> cardState(
    String cardId,
  ) async {
    final row = (await query(
      owner,
      'SELECT status, balance_cents, difference_cents, transaction_count '
      'FROM card_reconciliation WHERE card_id = @id:uuid',
      {'id': cardId},
    )).first;
    return (
      balance: row['balance_cents'] as int,
      difference: row['difference_cents'] as int,
      status: row['status'] as String,
      txCount: row['transaction_count'] as int,
    );
  }
}

/// Operaciones de caja con tokens ya resueltos.
class CashDesk {
  /// Crea el contexto.
  CashDesk(this.h, this.admin, this.cashier, this.terminal);

  /// Entorno.
  final Harness h;

  /// Token de administración.
  final String admin;

  /// Token del cajero.
  final String cashier;

  /// Credencial del terminal.
  final String terminal;

  /// Registra y verifica un titular; emite y entrega su tarjeta.
  /// Devuelve `(cardId, credenciales, token del titular)`.
  Future<(String, Map<String, Object?>, String)> newActiveCard(
    String email,
  ) async {
    await h.call(
      'POST',
      '/v1/auth/cardholders/register',
      body: {
        'fullName': 'Prueba $email',
        'email': email,
        'password': 'clave-segura',
        'pin': '4321',
      },
    );
    await h.call(
      'POST',
      '/v1/auth/cardholders/verify-email',
      body: {'email': email, 'code': h.mailer.lastCodeFor(email)},
    );
    final (_, login) = await h.call(
      'POST',
      '/v1/auth/cardholders/login',
      body: {'email': email, 'password': 'clave-segura'},
    );
    final (_, holders) = await h.call(
      'GET',
      '/v1/admin/cardholders?q=$email',
      token: admin,
    );
    final holderId =
        ((holders['items']! as List).first as Map)['cardholderId'] as String;
    final (_, issued) = await h.call(
      'POST',
      '/v1/admin/cards',
      body: {'cardholderId': holderId},
      token: admin,
    );
    final cardId = issued['cardId']! as String;
    await h.call('POST', '/v1/admin/cards/$cardId/deliver', token: admin);
    return (
      cardId,
      issued['credentials']! as Map<String, Object?>,
      login['accessToken']! as String,
    );
  }

  /// Recarga o débito; [key] por defecto es un UUID nuevo.
  Future<(int, Map<String, Object?>)> op(
    String kind,
    Map<String, Object?> card,
    int cents, {
    String? key,
    String? pin,
  }) => h.call(
    'POST',
    '/v1/cards/$kind',
    body: {'card': card, 'amountCents': cents, 'pin': ?pin},
    token: cashier,
    terminal: terminal,
    key: key ?? const Uuid().v4(),
  );
}
