import 'package:postgres/postgres.dart';

import '../config.dart';
import '../mailer.dart';
import '../security.dart';
import 'assistant_service.dart';
import 'auth_service.dart';
import 'card_service.dart';
import 'demo_reset_service.dart';
import 'ledger_service.dart';
import 'module_service.dart';
import 'replacement_service.dart';
import 'terminal_service.dart';

/// Todas las dependencias de negocio de la API.
class Services {
  /// Construye los servicios sobre [pool].
  factory Services(
    ApiConfig config,
    Pool<void> pool,
    Mailer mailer, {
    FaultHook? replacementFault,
    DemoResetService? demoReset,
  }) {
    final hasher = PasswordHasher(rounds: config.passwordHashRounds);
    final tokens = TokenService(config.jwtSecret, config.jwtTtl);
    final auth = AuthService(pool, config, hasher, tokens, mailer);
    final cards = CardService(pool, config, auth);
    final modules = ModuleService(pool);
    return Services._(
      pool: pool,
      tokens: tokens,
      auth: auth,
      cards: cards,
      ledger: LedgerService(pool, config, hasher, mailer),
      replacements: ReplacementService(
        pool,
        cards,
        faultHook: replacementFault,
      ),
      terminals: TerminalService(pool, hasher),
      modules: modules,
      assistant: AssistantService(config, cards, modules),
      outbox: switch (mailer) {
        final MailOutbox outbox => outbox,
        _ => null,
      },
      demoReset: demoReset,
    );
  }

  Services._({
    required this.pool,
    required this.tokens,
    required this.auth,
    required this.cards,
    required this.ledger,
    required this.replacements,
    required this.terminals,
    required this.modules,
    required this.assistant,
    required this.outbox,
    required this.demoReset,
  });

  /// Pool compartido.
  final Pool<void> pool;

  /// JWT.
  final TokenService tokens;

  /// Autenticación.
  final AuthService auth;

  /// Tarjetas.
  final CardService cards;

  /// Recargas y débitos.
  final LedgerService ledger;

  /// Reposiciones.
  final ReplacementService replacements;

  /// Terminales.
  final TerminalService terminals;

  /// Módulos que administración activa o desactiva.
  final ModuleService modules;

  /// Asistente virtual del titular.
  final AssistantService assistant;

  /// Últimos correos enviados (buzón de la demo), si el mailer los guarda.
  final MailOutbox? outbox;

  /// Reinicio de la demo por API; `null` si no está configurado.
  final DemoResetService? demoReset;
}
