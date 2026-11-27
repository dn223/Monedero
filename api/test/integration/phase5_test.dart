@Tags(['integration'])
library;

import 'package:monedero_api/monedero_api.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// Fases 4 y 5 contra PostgreSQL real: renovación de sesión, códigos en
/// pantalla y buzón de la demo, cajas demo, tablero de administración y
/// reinicio de la demo. Usa su propia base para correr en paralelo con las
/// pruebas de diseño.
void main() {
  late Harness h;
  late CashDesk desk;

  setUpAll(() async {
    h = await Harness.start(database: 'monedero_test_fase5');
    desk = await h.cashDesk();
  });
  tearDownAll(() => h.close());

  Map<String, Object?> error(Map<String, Object?> body) =>
      body['error']! as Map<String, Object?>;

  group('Renovación de sesión', () {
    test(
      'el inicio de sesión entrega un token de renovación que rota',
      () async {
        final (status, login) = await h.call(
          'POST',
          '/v1/auth/staff/login',
          body: {
            'email': DemoUsers.adminEmail,
            'password': DemoUsers.adminPassword,
          },
        );
        expect(status, 200);
        final first = login['refreshToken']! as String;
        expect(login['refreshExpiresInSeconds'], greaterThan(0));

        final (s1, renewed) = await h.call(
          'POST',
          '/v1/auth/refresh',
          body: {'refreshToken': first},
        );
        expect(s1, 200);
        expect(renewed['role'], 'ADMIN');
        expect(renewed['fullName'], 'Administración Demo');
        expect(renewed['refreshToken'], isNot(first));

        // El JWT nuevo sirve para una ruta de administración.
        final (s2, _) = await h.call(
          'GET',
          '/v1/admin/stats',
          token: renewed['accessToken']! as String,
        );
        expect(s2, 200);

        // El token usado ya no sirve (rotación).
        final (s3, again) = await h.call(
          'POST',
          '/v1/auth/refresh',
          body: {'refreshToken': first},
        );
        expect(s3, 401);
        expect(error(again)['code'], 'UNAUTHORIZED');
      },
    );

    test('cerrar sesión revoca el token de renovación', () async {
      final (_, login) = await h.call(
        'POST',
        '/v1/auth/cardholders/login',
        body: {'email': 'ana@demo.local', 'password': DemoUsers.holderPassword},
      );
      final refresh = login['refreshToken']! as String;
      final (s1, _) = await h.call(
        'POST',
        '/v1/auth/logout',
        body: {'refreshToken': refresh},
      );
      expect(s1, 200);
      final (s2, _) = await h.call(
        'POST',
        '/v1/auth/refresh',
        body: {'refreshToken': refresh},
      );
      expect(s2, 401);
    });
  });

  group('Modo demo sin Mailpit', () {
    test('registro y reenvío muestran el código; con él se verifica', () async {
      const email = 'demo-codigo@test.local';
      final (status, reg) = await h.call(
        'POST',
        '/v1/auth/cardholders/register',
        body: {
          'fullName': 'Prueba Código',
          'email': email,
          'password': 'clave-segura',
          'pin': '1111',
        },
      );
      expect(status, 201);
      expect(reg['demoCode'], h.mailer.lastCodeFor(email));

      final (s2, resent) = await h.call(
        'POST',
        '/v1/auth/cardholders/resend-code',
        body: {'email': email},
      );
      expect(s2, 202);
      final code = resent['demoCode']! as String;
      expect(code, h.mailer.lastCodeFor(email));

      final (s3, _) = await h.call(
        'POST',
        '/v1/auth/cardholders/verify-email',
        body: {'email': email, 'code': code},
      );
      expect(s3, 200);

      // Un correo desconocido responde igual, sin código.
      final (s4, unknown) = await h.call(
        'POST',
        '/v1/auth/cardholders/resend-code',
        body: {'email': 'nadie@test.local'},
      );
      expect(s4, 202);
      expect(unknown.containsKey('demoCode'), isFalse);
    });

    test('pérdida con código en pantalla y buzón del titular', () async {
      final (cardId, card, token) = await desk.newActiveCard(
        'buzon@test.local',
      );
      expect((await desk.op('top-ups', card, 1000)).$1, 201);

      final (status, started) = await h.call(
        'POST',
        '/v1/me/cards/$cardId/loss-reports',
        token: token,
      );
      expect(status, 202);
      final code = started['demoCode']! as String;

      final (s2, blocked) = await h.call(
        'POST',
        '/v1/me/cards/$cardId/loss-reports/confirm',
        body: {'code': code},
        token: token,
      );
      expect(s2, 200);
      expect(blocked['status'], 'BLOCKED');

      final (s3, inbox) = await h.call('GET', '/v1/demo/inbox', token: token);
      expect(s3, 200);
      final subjects = [
        for (final m in inbox['items']! as List) (m as Map)['subject'],
      ];
      expect(subjects.first, contains('pérdida'));
      expect(subjects, contains(r'Movimiento en tu tarjeta: +$10.00'));

      // El buzón es solo del titular.
      final (s4, _) = await h.call(
        'GET',
        '/v1/demo/inbox',
        token: desk.cashier,
      );
      expect(s4, 403);
    });
  });

  group('Caja', () {
    test(
      'cada dispositivo obtiene su caja demo y la caja se describe',
      () async {
        final (s1, a) = await h.call(
          'POST',
          '/v1/demo/terminals',
          token: desk.cashier,
        );
        final (s2, b) = await h.call(
          'POST',
          '/v1/demo/terminals',
          token: desk.cashier,
        );
        expect((s1, s2), (201, 201));
        expect(a['terminalToken'], isNot(b['terminalToken']));
        expect(a['payCode'], isNot(b['payCode']));

        // La primera credencial sigue sirviendo después de crear la segunda.
        final (s3, me) = await h.call(
          'GET',
          '/v1/cards/terminal',
          token: desk.cashier,
          terminal: a['terminalToken']! as String,
        );
        expect(s3, 200);
        expect(me['name'], a['name']);
        expect(me['payCode'], a['payCode']);
      },
    );
  });

  group('Administración', () {
    test('tablero con estados, saldo y serie diaria de 14 días', () async {
      final (status, stats) = await h.call(
        'GET',
        '/v1/admin/stats',
        token: desk.admin,
      );
      expect(status, 200);
      final byStatus = stats['cardsByStatus']! as Map<String, Object?>;
      expect(byStatus.keys, containsAll(['PENDING', 'ACTIVE', 'BLOCKED']));
      expect(stats['totalBalanceCents'], greaterThanOrEqualTo(6500));
      final daily = stats['daily']! as List;
      expect(daily, hasLength(14));
      final today = daily.last as Map<String, Object?>;
      expect(today['operations'], greaterThan(0));

      final (s2, _) = await h.call(
        'GET',
        '/v1/admin/stats',
        token: desk.cashier,
      );
      expect(s2, 403);
    });

    test('la búsqueda de titulares indica su tarjeta vigente', () async {
      final (_, found) = await h.call(
        'GET',
        '/v1/admin/cardholders?q=ana@demo.local',
        token: desk.admin,
      );
      final ana = (found['items']! as List).first as Map<String, Object?>;
      expect(ana['currentCardStatus'], 'ACTIVE');
      expect(ana['currentCardId'], isA<String>());
    });

    test('reiniciar la demo deja solo los datos sembrados', () async {
      final (s1, _) = await h.call(
        'POST',
        '/v1/admin/demo/reset',
        token: desk.cashier,
      );
      expect(s1, 403);

      final (status, body) = await h.call(
        'POST',
        '/v1/admin/demo/reset',
        token: desk.admin,
      );
      expect(status, 200, reason: '$body');
      expect(body['reset'], isTrue);

      final admin = await h.staffToken(
        DemoUsers.adminEmail,
        DemoUsers.adminPassword,
      );
      final (_, rec) = await h.call(
        'GET',
        '/v1/admin/reconciliation',
        token: admin,
      );
      expect(rec['cards'], 2);
      expect(rec['totalBalanceCents'], 6500);
      expect(rec['totalDifferenceCents'], 0);
    });
  });
}
