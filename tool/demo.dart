import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'src/common.dart';
import 'src/env.dart';

/// Demostración en vivo de los 8 pasos de docs/demo.md contra la API real.
///
/// Uso:
/// - `dart run tool/demo.dart`          corre todo seguido
/// - `dart run tool/demo.dart --pausa`  espera Enter entre pasos (exposición)
///
/// Requiere `dart run tool/up.dart`. Los códigos de verificación se leen de
/// Mailpit, igual que los vería una persona en http://localhost:8025.
Future<void> main(List<String> args) async {
  final pause = args.contains('--pausa');
  final env = readEnv();
  final api = 'http://localhost:${env['API_PORT'] ?? '8080'}';
  final mailpit = 'http://localhost:${env['MAILPIT_UI_PORT'] ?? '8025'}';
  final client = _Client(api);
  final email = 'demo${DateTime.now().millisecondsSinceEpoch}@ufg.local';
  var stepNo = 0;

  Future<void> step(String title) async {
    stepNo++;
    stdout.writeln('\n\x1B[1m── Paso $stepNo. $title\x1B[0m');
    if (pause && stepNo > 1) {
      stdout.write('   (Enter para continuar) ');
      stdin.readLineSync();
    }
  }

  void show(String label, Object? value) => stdout.writeln('   $label: $value');

  // Preparación: personal y terminal.
  heading('Preparación');
  final admin = await client.login(
    '/v1/auth/staff/login',
    env['ADMIN_EMAIL'] ?? 'admin@monedero.local',
    env['ADMIN_PASSWORD'] ?? '',
  );
  final terminal = await client.post('/v1/admin/terminals', {
    'name': 'Caja ${DateTime.now().toIso8601String()}',
  }, token: admin);
  // La caja entra solo con el código que le da administración.
  final opened = await client.post('/v1/auth/terminals/login', {
    'code': terminal.body['code'],
  });
  final cashier = opened.body['accessToken']! as String;
  final terminalToken = opened.body['terminalToken']! as String;
  ok('Administración autenticada; caja creada y abierta con su código.');

  await step('Registrar un titular');
  await client.post('/v1/auth/cardholders/register', {
    'fullName': 'Titular de la Demo',
    'email': email,
    'password': 'ClaveDemo123',
    'pin': '2468',
  });
  final code = await _codeFromMailpit(mailpit, email);
  show('Correo', email);
  show('Código recibido en Mailpit', code);
  await client.post('/v1/auth/cardholders/verify-email', {
    'email': email,
    'code': code,
  });
  final holder = await client.login(
    '/v1/auth/cardholders/login',
    email,
    'ClaveDemo123',
  );
  ok('Correo verificado e inicio de sesión del titular.');

  await step('Emitir y entregar una tarjeta virtual');
  final holders = await client.get(
    '/v1/admin/cardholders?q=$email',
    token: admin,
  );
  final holderId =
      ((holders.body['items']! as List).first as Map)['cardholderId'];
  final issued = await client.post('/v1/admin/cards', {
    'cardholderId': holderId,
  }, token: admin);
  final cardId = issued.body['cardId']! as String;
  final card = issued.body['credentials']! as Map<String, Object?>;
  show('Número', card['number']);
  show('UID (chip simulado)', card['uid']);
  show('Firma HMAC', card['signature']);
  show('Estado', issued.body['status']);
  final delivered = await client.post(
    '/v1/admin/cards/$cardId/deliver',
    {},
    token: admin,
  );
  show('Estado tras la entrega', delivered.body['status']);

  Future<_Res> op(
    String kind,
    int cents, {
    String? pin,
    Map<String, Object?>? withCard,
  }) => client.post(
    '/v1/cards/$kind',
    {'card': withCard ?? card, 'amountCents': cents, 'pin': ?pin},
    token: cashier,
    terminal: terminalToken,
    key: _uuid(),
  );

  await step(r'Recargar $20.00');
  final topUp = await op('top-ups', 2000);
  show('Comprobante', _money(topUp.body['balanceAfterCents']));

  await step(r'Cobrar $7.35');
  final debit = await op('debits', 735);
  show('Saldo después del cobro', _money(debit.body['balanceAfterCents']));

  await step(r'Intentar un sobregiro de $15.00');
  final over = await op('debits', 1500);
  show('Respuesta', '${over.status} ${_err(over)}');

  stdout.writeln(
    '\n   Extra: misma recarga enviada 5 veces con la MISMA Idempotency-Key',
  );
  final key = _uuid();
  for (var i = 0; i < 5; i++) {
    await client.post(
      '/v1/cards/top-ups',
      {'card': card, 'amountCents': 500},
      token: cashier,
      terminal: terminalToken,
      key: key,
    );
  }
  final afterIdem = await client.get('/v1/me/cards', token: holder);
  final balanceNow =
      ((afterIdem.body['items']! as List).first as Map)['balanceCents'];
  show(r'Saldo (solo se sumó $5.00 una vez)', _money(balanceNow));

  stdout.writeln('\n   Extra: tarjeta falsificada (UID cambiado)');
  final forged = await op(
    'debits',
    100,
    withCard: {...card, 'uid': '00000000000000'},
  );
  show('Respuesta', '${forged.status} ${_err(forged)}');

  await step('Reportar la pérdida');
  await client.post('/v1/me/cards/$cardId/loss-reports', {}, token: holder);
  final lossCode = await _codeFromMailpit(mailpit, email, skip: code);
  show('Código de confirmación (Mailpit)', lossCode);
  final blocked = await client.post(
    '/v1/me/cards/$cardId/loss-reports/confirm',
    {'code': lossCode},
    token: holder,
  );
  show('Estado', blocked.body['status']);
  final rejected = await op('debits', 100);
  show(
    'Intento de cobro con la tarjeta bloqueada',
    '${rejected.status} ${_err(rejected)}',
  );

  await step('Reponer la tarjeta conservando el saldo');
  final replaced = await client.post(
    '/v1/admin/cards/$cardId/replace',
    {},
    token: admin,
    key: _uuid(),
  );
  final newCard = replaced.body['newCard']! as Map;
  show('Saldo trasladado', _money(replaced.body['transferredCents']));
  show('Tarjeta anterior', (replaced.body['oldCard']! as Map)['status']);
  show(
    'Tarjeta nueva',
    '${newCard['numberMasked']} · ${newCard['status']} · ${_money(newCard['balanceCents'])}',
  );

  await step('Ver la conciliación');
  final rec = await client.get('/v1/admin/reconciliation', token: admin);
  show('Tarjetas revisadas', rec.body['cards']);
  show('Tarjetas con diferencia', rec.body['cardsWithDifference']);
  show('Diferencia total', _money(rec.body['totalDifferenceCents']));
  stdout.writeln(
    rec.body['totalDifferenceCents'] == 0
        ? '\n\x1B[32m   ✔ Conciliación en cero: saldo = suma de movimientos en todas las tarjetas.\x1B[0m'
        : '\n\x1B[31m   ✘ Hay diferencias.\x1B[0m',
  );
  client.close();
}

String _money(Object? cents) {
  final c = cents! as int;
  return '\$${c ~/ 100}.${(c % 100).toString().padLeft(2, '0')}';
}

String _err(_Res r) => ((r.body['error'] as Map?)?['code'] ?? 'OK').toString();

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

Future<String> _codeFromMailpit(String base, String to, {String? skip}) async {
  final http = HttpClient();
  try {
    for (var attempt = 0; attempt < 20; attempt++) {
      final search = await _getJson(
        http,
        '$base/api/v1/search?query=${Uri.encodeQueryComponent('to:"$to"')}',
      );
      for (final m in (search['messages'] as List? ?? const [])) {
        final id = (m as Map)['ID'];
        final message = await _getJson(http, '$base/api/v1/message/$id');
        final code = RegExp(r'\b(\d{6})\b')
            .firstMatch(message['Text']! as String)
            ?.group(1);
        if (code != null && code != skip) return code;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  } finally {
    http.close(force: true);
  }
  throw StateError('No llegó el código a Mailpit.');
}

Future<Map<String, Object?>> _getJson(HttpClient http, String url) async {
  final res = await (await http.getUrl(Uri.parse(url))).close();
  return jsonDecode(await res.transform(utf8.decoder).join())
      as Map<String, Object?>;
}

class _Res {
  _Res(this.status, this.body);
  final int status;
  final Map<String, Object?> body;
}

class _Client {
  _Client(this.base);
  final String base;
  final HttpClient _http = HttpClient();

  Future<String> login(String path, String email, String password) async {
    final r = await post(path, {'email': email, 'password': password});
    if (r.status != 200) {
      throw StateError(
        'No se pudo iniciar sesión ($email): ${r.body}. '
        '¿Corriste dart run tool/up.dart?',
      );
    }
    return r.body['accessToken']! as String;
  }

  Future<_Res> get(String path, {String? token}) =>
      _send('GET', path, null, token: token);

  Future<_Res> post(
    String path,
    Map<String, Object?> body, {
    String? token,
    String? terminal,
    String? key,
  }) => _send('POST', path, body, token: token, terminal: terminal, key: key);

  Future<_Res> _send(
    String method,
    String path,
    Map<String, Object?>? body, {
    String? token,
    String? terminal,
    String? key,
  }) async {
    final req = await _http.openUrl(method, Uri.parse('$base$path'));
    req.headers.contentType = ContentType.json;
    if (token != null) req.headers.set('authorization', 'Bearer $token');
    if (terminal != null) req.headers.set('x-terminal-token', terminal);
    if (key != null) req.headers.set('idempotency-key', key);
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return _Res(
      res.statusCode,
      text.isEmpty ? {} : jsonDecode(text) as Map<String, Object?>,
    );
  }

  void close() => _http.close(force: true);
}
