import 'dart:io';

/// Lee un archivo `.env` (clave=valor) y lo combina con el entorno del
/// proceso; el entorno del proceso tiene prioridad.
Map<String, String> loadEnv(String path) {
  final values = <String, String>{};
  final file = File(path);
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final i = trimmed.indexOf('=');
      if (i <= 0) continue;
      values[trimmed.substring(0, i).trim()] = trimmed.substring(i + 1).trim();
    }
  }
  return {...values, ...Platform.environment};
}

/// Busca el `.env` de la raíz del repositorio subiendo desde el directorio
/// actual.
String findRepoEnv() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 5; i++) {
    final candidate = File('${dir.path}${Platform.pathSeparator}.env');
    if (candidate.existsSync()) return candidate.path;
    dir = dir.parent;
  }
  return '.env';
}

/// Busca `db/migrations` subiendo desde el directorio actual.
Directory findMigrationsDir() {
  var dir = Directory.current.absolute;
  final sep = Platform.pathSeparator;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}${sep}db${sep}migrations');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError('No se encontró db/migrations.');
}
