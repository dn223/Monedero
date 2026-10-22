import 'package:postgres/postgres.dart';

import '../config.dart';
import '../mailer.dart';
import '../security.dart';
import 'auth_service.dart';
import 'card_service.dart';
import 'ledger_service.dart';
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
  }) {
    final hasher = PasswordHasher(rounds: config.passwordHashRounds);
    final tokens = TokenService(config.jwtSecret, config.jwtTtl);
    final auth = AuthService(pool, config, hasher, tokens, mailer);
    final cards = CardService(pool, config, auth);
    return Services._(
      pool: pool,
      tokens: tokens,
      auth: auth,
      cards: cards,
      ledger: LedgerService(pool, config, hasher),
      replacements: ReplacementService(
        pool,
        cards,
        faultHook: replacementFault,
      ),
      terminals: TerminalService(pool),
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
}
