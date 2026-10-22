import 'dart:io';

/// Raíz del repositorio (la carpeta que contiene `tool/`).
final Directory repoRoot = File.fromUri(Platform.script).parent.parent;

/// Escribe un título de sección en la consola.
void heading(String text) => stdout.writeln('\n== $text');

/// Escribe un mensaje de éxito.
void ok(String text) => stdout.writeln('  [ok] $text');

/// Escribe una advertencia.
void warn(String text) => stdout.writeln('  [!] $text');

/// Escribe un error en stderr.
void fail(String text) => stderr.writeln('  [x] $text');

/// Ejecuta [executable] con [arguments] mostrando su salida en vivo.
///
/// En Windows se usa `runInShell` para que funcionen `flutter.bat` y
/// `dart.bat`. Devuelve el código de salida.
Future<int> run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  stdout.writeln('  \$ $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory ?? repoRoot.path,
    environment: environment,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

/// Ejecuta un comando y devuelve su salida, sin mostrarla. Devuelve `null`
/// si el programa no existe o falla.
Future<String?> capture(String executable, List<String> arguments) async {
  try {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: repoRoot.path,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) return null;
    return (result.stdout as String).trim();
  } on ProcessException {
    return null;
  }
}

/// Ejecuta `docker compose` con [arguments] en la raíz del repositorio.
Future<int> compose(List<String> arguments) =>
    run('docker', ['compose', ...arguments]);

/// Termina el script con [code] mostrando [message] si hubo error.
Never exitWith(int code, [String? message]) {
  if (message != null) {
    code == 0 ? ok(message) : fail(message);
  }
  exit(code);
}
