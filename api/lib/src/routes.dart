import 'package:monedero_core/monedero_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'errors.dart';
import 'http/json.dart';
import 'http/request.dart';
import 'mailer.dart';
import 'security.dart';
import 'services/services.dart';

/// Rutas de negocio `/v1/...`. Cada ruta valida el rol en la API.
void addBusinessRoutes(Router router, ApiConfig config, Services s) {
  const holder = {Role.cardholder};
  const cashier = {Role.cashier, Role.admin};
  const admin = {Role.admin};

  void requireDemo() {
    if (!config.demoMode) {
      throw const ApiException(
        ApiErrorCode.demoModeDisabled,
        'El modo demo está desactivado.',
      );
    }
  }

  Principal auth(Request r, Set<Role> roles) => requireRole(r, s.tokens, roles);

  // --- Autenticación -------------------------------------------------------
  router
    ..post('/v1/auth/cardholders/register', (Request r) async {
      await s.modules.require(AppModule.selfRegistration);
      final b = await readJson(r);
      return jsonResponse(
        await s.auth.registerCardholder(
          fullName: requireString(b, 'fullName'),
          email: requireString(b, 'email'),
          password: requireString(b, 'password'),
          pin: requireString(b, 'pin'),
        ),
        status: 201,
      );
    })
    ..post('/v1/auth/cardholders/verify-email', (Request r) async {
      final b = await readJson(r);
      await s.auth.verifyEmail(
        email: requireString(b, 'email'),
        code: requireString(b, 'code'),
      );
      return jsonResponse({'verified': true});
    })
    ..post('/v1/auth/cardholders/login', (Request r) async {
      final b = await readJson(r);
      return jsonResponse(
        await s.auth.loginCardholder(
          requireString(b, 'email'),
          requireString(b, 'password'),
        ),
      );
    })
    ..post('/v1/auth/cardholders/resend-code', (Request r) async {
      final b = await readJson(r);
      return jsonResponse(
        await s.auth.resendVerificationCode(requireString(b, 'email')),
        status: 202,
      );
    })
    ..post('/v1/auth/staff/login', (Request r) async {
      final b = await readJson(r);
      return jsonResponse(
        await s.auth.loginStaff(
          requireString(b, 'email'),
          requireString(b, 'password'),
        ),
      );
    })
    // Renovación de sesión: rota el token de renovación (ver ADR 0010).
    ..post('/v1/auth/refresh', (Request r) async {
      final b = await readJson(r);
      return jsonResponse(
        await s.auth.refresh(requireString(b, 'refreshToken')),
      );
    })
    ..post('/v1/auth/logout', (Request r) async {
      final b = await readJson(r);
      await s.auth.logout(requireString(b, 'refreshToken'));
      return jsonResponse({'loggedOut': true});
    })
    // --- Titular -----------------------------------------------------------
    ..get('/v1/me/cards', (Request r) async {
      final p = auth(r, holder);
      final items = await s.cards.cardsOf(p.id);
      // Sin el módulo de QR no viajan las credenciales que lo forman.
      final qr = await s.modules.isEnabled(AppModule.cardQr);
      return jsonResponse({
        'items': [
          for (final c in items) qr ? c : ({...c}..remove('credentials')),
        ],
      });
    })
    ..get('/v1/me/cards/<id>/transactions', (Request r, String id) async {
      final p = auth(r, holder);
      return jsonResponse({
        'items': await s.cards.transactions(id, ownerId: p.id),
      });
    })
    ..post('/v1/me/cards/<id>/loss-reports', (Request r, String id) async {
      final p = auth(r, holder);
      final code = await s.cards.startLossReport(p.id, id);
      return jsonResponse({
        'codeSent': true,
        // Solo en modo demo: el código se ve en pantalla (ver ADR 0011).
        if (config.demoMode) 'demoCode': code,
      }, status: 202);
    })
    ..post('/v1/me/cards/<id>/loss-reports/confirm', (
      Request r,
      String id,
    ) async {
      final p = auth(r, holder);
      final b = await readJson(r);
      return jsonResponse(
        await s.cards.confirmLossReport(p.id, id, requireString(b, 'code')),
      );
    })
    ..put('/v1/me/pin', (Request r) async {
      final p = auth(r, holder);
      await s.modules.require(AppModule.pinChange);
      final b = await readJson(r);
      await s.auth.changePin(
        p.id,
        requireString(b, 'currentPin'),
        requireString(b, 'newPin'),
      );
      return jsonResponse({'changed': true});
    })
    ..post('/v1/assistant/messages', (Request r) async {
      final p = auth(r, holder);
      final b = await readJson(r);
      return jsonResponse(
        await s.assistant.reply(p.id, requireString(b, 'message')),
      );
    })
    // --- Módulos -----------------------------------------------------------
    // Público: la app decide qué mostrar incluso antes de iniciar sesión.
    ..get('/v1/modules', (Request r) async {
      return jsonResponse({'items': await s.modules.list()});
    })
    ..put('/v1/admin/modules/<key>', (Request r, String key) async {
      final p = auth(r, admin);
      final b = await readJson(r);
      final enabled = b['enabled'];
      if (enabled is! bool) {
        throw const ApiException(
          ApiErrorCode.validationFailed,
          'El campo "enabled" debe ser true o false.',
          details: {'field': 'enabled'},
        );
      }
      return jsonResponse(
        await s.modules.set(key, enabled: enabled, staffId: p.id),
      );
    })
    // --- Caja (rol + credencial de terminal) -------------------------------
    ..get('/v1/cards/terminal', (Request r) async {
      auth(r, cashier);
      final terminalId = await s.terminals.authenticate(
        r.headers['x-terminal-token'],
      );
      return jsonResponse(await s.terminals.describe(terminalId));
    })
    ..post('/v1/cards/read', (Request r) async {
      auth(r, cashier);
      await s.terminals.authenticate(r.headers['x-terminal-token']);
      final card = requireCard(await readJson(r));
      final found = await s.cards.search(card.number);
      final match = found.where((c) {
        final creds = c['credentials']! as Map<String, Object?>;
        return creds['uid'] == card.uid.toUpperCase() &&
            creds['signature'] == card.signature.toUpperCase();
      });
      final valid =
          CardSignature.verify(
            masterKey: config.cardMasterKey,
            number: card.number,
            uid: card.uid,
            signature: card.signature,
          ) &&
          match.isNotEmpty;
      if (!valid) {
        throw const ApiException(
          ApiErrorCode.invalidCardSignature,
          'La tarjeta no es válida (número, UID o firma no coinciden).',
        );
      }
      final c = match.first;
      return jsonResponse({
        'numberMasked': c['numberMasked'],
        'cardholderName': c['cardholderName'],
        'status': c['status'],
        'balanceCents': c['balanceCents'],
        'pinRequiredAboveCents': config.pinRequiredAboveCents,
      });
    })
    ..post('/v1/cards/top-ups', (Request r) async {
      final p = auth(r, cashier);
      final terminalId = await s.terminals.authenticate(
        r.headers['x-terminal-token'],
      );
      final key = requireIdempotencyKey(r);
      final b = await readJson(r);
      return jsonResponse(
        await s.ledger.topUp(
          card: requireCard(b),
          amountCents: requireCents(b, 'amountCents'),
          idempotencyKey: key,
          terminalId: terminalId,
          staffId: p.id,
        ),
        status: 201,
      );
    })
    ..post('/v1/cards/debits', (Request r) async {
      final p = auth(r, cashier);
      final terminalId = await s.terminals.authenticate(
        r.headers['x-terminal-token'],
      );
      final key = requireIdempotencyKey(r);
      final b = await readJson(r);
      return jsonResponse(
        await s.ledger.debit(
          card: requireCard(b),
          amountCents: requireCents(b, 'amountCents'),
          idempotencyKey: key,
          terminalId: terminalId,
          staffId: p.id,
          pin: b['pin'] as String?,
        ),
        status: 201,
      );
    })
    // --- Administración ----------------------------------------------------
    ..get('/v1/admin/cardholders', (Request r) async {
      auth(r, admin);
      return jsonResponse({
        'items': await s.cards.searchCardholders(
          r.url.queryParameters['q'] ?? '',
        ),
      });
    })
    ..get('/v1/admin/cards', (Request r) async {
      auth(r, admin);
      return jsonResponse({
        'items': await s.cards.search(r.url.queryParameters['q'] ?? ''),
      });
    })
    ..post('/v1/admin/cards', (Request r) async {
      auth(r, admin);
      final b = await readJson(r);
      return jsonResponse(
        await s.cards.issue(requireString(b, 'cardholderId')),
        status: 201,
      );
    })
    ..post('/v1/admin/cards/<id>/deliver', (Request r, String id) async {
      auth(r, admin);
      return jsonResponse(await s.cards.deliver(id));
    })
    ..post('/v1/admin/cards/<id>/replace', (Request r, String id) async {
      final p = auth(r, admin);
      return jsonResponse(
        await s.replacements.replace(
          oldCardId: id,
          adminId: p.id,
          idempotencyKey: requireIdempotencyKey(r),
        ),
        status: 201,
      );
    })
    ..get('/v1/admin/cards/<id>/transactions', (Request r, String id) async {
      auth(r, admin);
      return jsonResponse({'items': await s.cards.transactions(id)});
    })
    ..get('/v1/admin/stats', (Request r) async {
      auth(r, admin);
      return jsonResponse(await s.cards.stats());
    })
    ..post('/v1/admin/demo/reset', (Request r) async {
      auth(r, admin);
      requireDemo();
      final reset = s.demoReset;
      if (reset == null) {
        throw const ApiException(
          ApiErrorCode.conflict,
          'El reinicio por API no está configurado en este servidor. '
          'Usa dart run tool/reset_demo.dart.',
        );
      }
      await reset.reset();
      return jsonResponse({'reset': true});
    })
    ..get('/v1/admin/reconciliation', (Request r) async {
      auth(r, admin);
      return jsonResponse(await s.cards.reconciliation());
    })
    ..get('/v1/admin/terminals', (Request r) async {
      auth(r, admin);
      return jsonResponse({'items': await s.terminals.list()});
    })
    ..post('/v1/admin/terminals', (Request r) async {
      final p = auth(r, admin);
      final b = await readJson(r);
      return jsonResponse(
        await s.terminals.create(requireString(b, 'name'), p.id),
        status: 201,
      );
    })
    ..delete('/v1/admin/terminals/<id>', (Request r, String id) async {
      auth(r, admin);
      await s.terminals.revoke(id);
      return jsonResponse({'revoked': true});
    })
    // --- Modo demo ---------------------------------------------------------
    ..get('/v1/demo/cards', (Request r) async {
      auth(r, cashier);
      if (!config.demoMode) {
        throw const ApiException(
          ApiErrorCode.demoModeDisabled,
          'El modo demo está desactivado.',
        );
      }
      return jsonResponse({
        'items': await s.cards.search('', activeOnly: true),
      });
    })
    // Sesiones sin contraseña SOLO en modo demo (exposición). Con
    // DEMO_MODE=false responden 403.
    ..post('/v1/demo/cashier-session', (Request r) async {
      requireDemo();
      return jsonResponse({
        ...await s.auth.demoStaffSession(Role.cashier),
        ...await s.terminals.demoTerminal(),
      });
    })
    ..post('/v1/demo/holder-session', (Request r) async {
      requireDemo();
      final b = await readJson(r);
      return jsonResponse(
        await s.auth.demoHolderSession(requireString(b, 'email')),
      );
    })
    // Cada dispositivo de caja obtiene su propia "Caja demo N".
    ..post('/v1/demo/terminals', (Request r) async {
      requireDemo();
      final p = auth(r, cashier);
      return jsonResponse(await s.terminals.createDemo(p.id), status: 201);
    })
    // Buzón: los correos que recibió el titular (códigos y avisos), para
    // quien prueba sin acceso a Mailpit.
    ..get('/v1/demo/inbox', (Request r) async {
      requireDemo();
      final p = auth(r, holder);
      final email = await s.auth.emailOf(p.id);
      return jsonResponse({
        'items': [
          for (final m in s.outbox?.messagesFor(email) ?? const <SentMail>[])
            {
              'subject': m.subject,
              'text': m.text,
              'sentAt': m.sentAt.toUtc().toIso8601String(),
            },
        ],
      });
    })
    ..get('/v1/demo/terminal-activity/<payCode>', (
      Request r,
      String payCode,
    ) async {
      requireDemo();
      auth(r, cashier);
      return jsonResponse({
        'items': await s.terminals.activityByPayCode(payCode),
      });
    })
    // --- Pago del titular en caja -------------------------------------------
    ..post('/v1/me/payments', (Request r) async {
      final p = auth(r, holder);
      await s.modules.require(AppModule.holderPayments);
      final key = requireIdempotencyKey(r);
      final b = await readJson(r);
      return jsonResponse(
        await s.ledger.payAtTerminal(
          cardholderId: p.id,
          payCode: requireString(b, 'terminalCode'),
          amountCents: requireCents(b, 'amountCents'),
          idempotencyKey: key,
          pin: b['pin'] as String?,
        ),
        status: 201,
      );
    })
    ..get('/v1/cards/terminal-activity', (Request r) async {
      auth(r, cashier);
      final terminalId = await s.terminals.authenticate(
        r.headers['x-terminal-token'],
      );
      return jsonResponse({'items': await s.terminals.activity(terminalId)});
    });
}
