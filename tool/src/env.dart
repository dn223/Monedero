import 'dart:io';
import 'dart:math';

import 'common.dart';

/// Marcador de `.env.example` que se reemplaza por un secreto aleatorio.
const generatePlaceholder = '__GENERAR__';

/// Archivo `.env` de la raíz del repositorio.
File get envFile => File('${repoRoot.path}${Platform.pathSeparator}.env');

/// Crea `.env` a partir de `.env.example` si no existe, generando secretos
/// aleatorios para cada valor [generatePlaceholder]. Devuelve `true` si lo
/// creó.
bool ensureEnvFile() {
  if (envFile.existsSync()) return false;
  final example = File('${repoRoot.path}${Platform.pathSeparator}.env.example');
  final random = Random.secure();
  final content = example.readAsStringSync().replaceAllMapped(
    RegExp(generatePlaceholder),
    (_) => _randomHex(random, 32),
  );
  envFile.writeAsStringSync(content);
  return true;
}

/// Lee `.env` como mapa clave → valor (ignora comentarios y líneas vacías).
Map<String, String> readEnv() {
  if (!envFile.existsSync()) return const {};
  final values = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    values[trimmed.substring(0, separator).trim()] = trimmed
        .substring(separator + 1)
        .trim();
  }
  return values;
}

String _randomHex(Random random, int bytes) => List.generate(
  bytes,
  (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
