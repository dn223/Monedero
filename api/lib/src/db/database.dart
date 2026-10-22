import 'package:postgres/postgres.dart';

import '../config.dart';

/// Abre un pool de conexiones a PostgreSQL con [config].
///
/// [acquireTimeout] es cuánto espera una solicitud por una conexión libre;
/// con muchas operaciones sobre la misma tarjeta, la fila bloqueada
/// (`FOR UPDATE`) las serializa y la fila crece.
Pool<void> openPool(
  DatabaseConfig config, {
  int maxConnections = 10,
  Duration acquireTimeout = const Duration(seconds: 30),
}) => Pool.withEndpoints(
  [_endpoint(config)],
  settings: PoolSettings(
    maxConnectionCount: maxConnections,
    sslMode: SslMode.disable,
    connectTimeout: acquireTimeout,
  ),
);

/// Abre una conexión única (migraciones y pruebas).
Future<Connection> openConnection(DatabaseConfig config) => Connection.open(
  _endpoint(config),
  settings: const ConnectionSettings(sslMode: SslMode.disable),
);

Endpoint _endpoint(DatabaseConfig config) => Endpoint(
  host: config.host,
  port: config.port,
  database: config.name,
  username: config.user,
  password: config.password,
);

/// Ejecuta [sql] con parámetros con nombre (`@nombre`) y devuelve las filas
/// como mapas columna → valor.
Future<List<Map<String, dynamic>>> query(
  Session session,
  String sql, [
  Map<String, Object?> parameters = const {},
]) async {
  final result = await session.execute(Sql.named(sql), parameters: parameters);
  return [for (final row in result) row.toColumnMap()];
}
