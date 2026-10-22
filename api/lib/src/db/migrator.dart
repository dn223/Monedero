import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

/// Aplica las migraciones de `db/migrations` en orden, con checksum.
///
/// Se conecta con el **dueño del esquema**, nunca con el usuario de la API.
/// Si una migración ya aplicada cambió, se detiene: las migraciones aplicadas
/// no se editan (AGENTS.md § 5).
class Migrator {
  /// Crea el migrador sobre [connection] leyendo SQL de [migrationsDir].
  Migrator(this.connection, this.migrationsDir);

  /// Conexión con el dueño del esquema.
  final Connection connection;

  /// Carpeta con los archivos `NNNN_descripcion.sql`.
  final Directory migrationsDir;

  /// Crea (o actualiza la contraseña de) el rol de la API.
  Future<void> ensureAppRole(String user, String password) async {
    if (!RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(user)) {
      throw ArgumentError.value(user, 'user', 'Nombre de rol inválido.');
    }
    final literal = "'${password.replaceAll("'", "''")}'";
    final exists = await connection.execute(
      Sql.named('SELECT 1 FROM pg_roles WHERE rolname = @u'),
      parameters: {'u': user},
    );
    final verb = exists.isEmpty ? 'CREATE' : 'ALTER';
    await connection.execute(
      '$verb ROLE $user WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE '
      'PASSWORD $literal',
    );
  }

  /// Borra todo el esquema `public` (solo para reiniciar la demo y pruebas).
  Future<void> dropEverything() async {
    await connection.execute('DROP SCHEMA public CASCADE');
    await connection.execute('CREATE SCHEMA public');
  }

  /// Aplica las migraciones pendientes. Devuelve los nombres aplicados.
  Future<List<String>> migrate() async {
    await connection.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name        TEXT PRIMARY KEY,
        checksum    TEXT NOT NULL,
        applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
      )''');
    final applied = {
      for (final row in await connection.execute(
        'SELECT name, checksum FROM schema_migrations',
      ))
        row[0]! as String: row[1]! as String,
    };

    final files =
        migrationsDir
            .listSync()
            .whereType<File>()
            .where((f) => RegExp(r'\d{4}_.+\.sql$').hasMatch(f.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final newlyApplied = <String>[];
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final sql = file.readAsStringSync().replaceAll('\r\n', '\n');
      final checksum = sha256.convert(utf8.encode(sql)).toString();
      final previous = applied[name];
      if (previous != null) {
        if (previous != checksum) {
          throw StateError(
            'La migración $name cambió después de aplicarse. '
            'No edites migraciones aplicadas: crea una nueva.',
          );
        }
        continue;
      }
      await connection.runTx((tx) async {
        await tx.execute(sql, queryMode: QueryMode.simple);
        await tx.execute(
          Sql.named(
            'INSERT INTO schema_migrations (name, checksum) VALUES (@n, @c)',
          ),
          parameters: {'n': name, 'c': checksum},
        );
      });
      newlyApplied.add(name);
    }
    return newlyApplied;
  }
}
