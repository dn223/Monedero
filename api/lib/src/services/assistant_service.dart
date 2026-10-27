import 'package:monedero_core/monedero_core.dart';

import '../config.dart';
import '../db/database.dart';
import '../errors.dart';
import 'card_service.dart';
import 'module_service.dart';

/// De qué trata la pregunta del titular.
enum AssistantIntent {
  /// Perdió la tarjeta o se la robaron.
  loss,

  /// Pregunta por la reposición.
  replacement,

  /// PIN.
  pin,

  /// Cómo recargar.
  topUp,

  /// Cómo pagar.
  pay,

  /// Código QR.
  qr,

  /// Último movimiento o historial.
  history,

  /// Saldo.
  balance,

  /// Saludo.
  greeting,

  /// Agradecimiento.
  thanks,

  /// No se entendió: se ofrece ayuda.
  help,
}

/// Lo que el asistente sabe del titular al responder.
class AssistantContext {
  /// Crea el contexto.
  const AssistantContext({
    required this.firstName,
    required this.enabled,
    required this.pinRequiredAboveCents,
    this.cardStatus,
    this.balanceCents,
    this.lastTransaction,
  });

  /// Nombre de pila del titular.
  final String firstName;

  /// Módulos encendidos (para no sugerir funciones apagadas).
  final Set<AppModule> enabled;

  /// Monto a partir del cual la caja pide PIN.
  final int pinRequiredAboveCents;

  /// Estado de la tarjeta vigente, o `null` si aún no tiene.
  final String? cardStatus;

  /// Saldo de la tarjeta vigente.
  final int? balanceCents;

  /// Último movimiento (`type`, `amountCents`, `createdAt`).
  final Map<String, Object?>? lastTransaction;
}

/// Respuesta del asistente.
typedef AssistantReply = ({
  AssistantIntent intent,
  String text,
  List<String> suggestions,
});

/// Asistente virtual por reglas: reconoce la intención por palabras clave
/// y responde con los datos reales del titular. No usa servicios externos
/// ni guarda las conversaciones (ver docs/adr/0014).
class AssistantBrain {
  /// Crea el asistente.
  const AssistantBrain();

  /// Largo máximo de una pregunta.
  static const maxMessageLength = 500;

  // Orden = prioridad: "perdí mi tarjeta, ¿y mi saldo?" es una pérdida.
  static const _keywords = <AssistantIntent, List<String>>{
    AssistantIntent.loss: [
      'perdi',
      'perdida',
      'extravi',
      'robo',
      'robaron',
      'bloque',
      'hurto',
    ],
    AssistantIntent.replacement: ['reposicion', 'repon', 'nueva tarjeta'],
    AssistantIntent.pin: ['pin', 'clave'],
    AssistantIntent.topUp: ['recarg', 'abon', 'deposit', 'cargar saldo'],
    AssistantIntent.qr: ['qr', 'codigo de mi tarjeta'],
    AssistantIntent.pay: ['pag', 'compr', 'cobr'],
    AssistantIntent.history: [
      'movimiento',
      'historial',
      'ultim',
      'gaste',
      'gasto',
    ],
    AssistantIntent.balance: [
      'saldo',
      'cuanto tengo',
      'dinero',
      'disponible',
      'plata',
    ],
    AssistantIntent.greeting: ['hola', 'buenas', 'buenos', 'saludos'],
    AssistantIntent.thanks: ['gracias', 'muy amable'],
  };

  static const _exact = {'pin', 'qr'};

  /// Quita acentos, mayúsculas y signos.
  static String normalize(String text) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      out.write(i >= 0 ? to[i] : ch);
    }
    return out
        .toString()
        .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(' +'), ' ')
        .trim();
  }

  /// Reconoce la intención de [message].
  AssistantIntent classify(String message) {
    final text = normalize(message);
    final words = text.split(' ');
    bool has(String key) => key.contains(' ')
        ? text.contains(key)
        // "pin" y "qr" exactas (no "pintura"); las demás, por raíz.
        : _exact.contains(key)
        ? words.contains(key)
        : words.any((w) => w.startsWith(key));
    for (final MapEntry(:key, :value) in _keywords.entries) {
      if (value.any(has)) return key;
    }
    return AssistantIntent.help;
  }

  /// Responde [message] con los datos de [c].
  AssistantReply answer(String message, AssistantContext c) {
    final intent = classify(message);
    final on = c.enabled.contains;
    final pinLimit = Money.format(c.pinRequiredAboveCents);
    final hasCard = c.cardStatus != null;
    final active = c.cardStatus == 'ACTIVE';

    String noCard() =>
        'Aún no tienes tarjeta. Pide en administración que la emitan; cuando '
        'te la entreguen la verás en tu inicio con su saldo.';

    final text = switch (intent) {
      AssistantIntent.balance when !hasCard => noCard(),
      AssistantIntent.balance =>
        'Tu saldo es ${Money.format(c.balanceCents ?? 0)}.'
            '${active ? '' : ' Tu tarjeta está ${_status(c.cardStatus)}, '
                      'así que por ahora no se puede usar.'}',
      AssistantIntent.history when c.lastTransaction == null =>
        hasCard ? 'Tu tarjeta aún no tiene movimientos.' : noCard(),
      AssistantIntent.history => _lastMovement(c.lastTransaction!),
      AssistantIntent.topUp =>
        r'Recarga en cualquier caja del comercio: muestra tu tarjeta'
            '${on(AppModule.cardQr) ? ' o tu código QR' : ''} y di el monto. '
            r'Las recargas son en múltiplos de $5.00 y el saldo cambia al '
            'instante.',
      AssistantIntent.pay =>
        'En caja, muestra tu tarjeta'
            '${on(AppModule.cardQr) ? ' o tu código QR' : ''}'
            '${on(AppModule.holderPayments) ? ', o toca "Pagar en caja" y escribe el código que muestra la caja' : ''}. '
            'Las compras de más de $pinLimit piden tu PIN y nunca puedes '
            'gastar más de tu saldo.',
      AssistantIntent.qr when !on(AppModule.cardQr) =>
        'El código QR de la tarjeta no está disponible en este momento. '
            'Puedes pagar mostrando tu tarjeta en caja.',
      AssistantIntent.qr =>
        'Toca "Mostrar mi código QR" en tu inicio. La caja lo lee con la '
            'cámara, igual que si pasaras la tarjeta.',
      AssistantIntent.pin =>
        'La caja pide tu PIN en compras de más de $pinLimit. '
            '${on(AppModule.pinChange) ? 'Para cambiarlo toca "Cambiar PIN" en tu inicio; te pedirá el PIN actual.' : 'El cambio de PIN desde la app no está disponible ahora; pídelo en administración.'}',
      AssistantIntent.loss =>
        'Toca "Reportar pérdida" en tu inicio. Te enviamos un código a tu '
            'correo y, al confirmarlo, la tarjeta se bloquea al instante: '
            'nadie puede usar tu saldo. Después administración te repone la '
            'tarjeta con el mismo saldo.',
      AssistantIntent.replacement =>
        'La reposición la hace administración después de que reportas la '
            'pérdida: crea una tarjeta nueva y le pasa todo tu saldo. La '
            'tarjeta anterior queda anulada.',
      AssistantIntent.greeting =>
        '¡Hola, ${c.firstName}! Soy el asistente de tu tarjeta. Pregúntame '
            'por tu saldo, cómo recargar o qué hacer si la pierdes.',
      AssistantIntent.thanks => '¡Con gusto, ${c.firstName}!',
      AssistantIntent.help =>
        'No entendí tu pregunta. Puedo ayudarte con tu saldo, tus '
            'movimientos, recargas, pagos, el PIN o la pérdida de tu tarjeta.',
    };

    return (
      intent: intent,
      text: text,
      suggestions: [
        if (intent != AssistantIntent.balance) '¿Cuál es mi saldo?',
        if (intent != AssistantIntent.history)
          '¿Cuál fue mi último movimiento?',
        if (intent != AssistantIntent.topUp) '¿Cómo recargo?',
        if (intent != AssistantIntent.loss) 'Perdí mi tarjeta',
      ].take(3).toList(),
    );
  }

  static String _status(String? status) => switch (status) {
    'PENDING' => 'por entregar',
    'BLOCKED' => 'bloqueada',
    'REPLACED' => 'repuesta',
    _ => 'inactiva',
  };

  static String _lastMovement(Map<String, Object?> t) {
    final amount = Money.format(t['amountCents']! as int);
    final label = switch (t['type']) {
      'TOP_UP' => 'una recarga de $amount',
      'DEBIT' => 'una compra de $amount',
      'REPLACEMENT_IN' => 'el traslado de $amount por reposición',
      _ => 'un traslado de $amount por reposición',
    };
    final after = t['balanceAfterCents'];
    return 'Tu último movimiento fue $label'
        '${after is int ? '; tu saldo quedó en ${Money.format(after)}' : ''}.';
  }
}

/// Asistente del titular: arma el contexto con sus datos y responde.
class AssistantService {
  /// Crea el servicio.
  AssistantService(this.config, this.cards, this.modules);

  /// Configuración (límite del PIN).
  final ApiConfig config;

  /// Tarjetas y movimientos.
  final CardService cards;

  /// Módulos encendidos.
  final ModuleService modules;

  static const _brain = AssistantBrain();

  /// Responde [message] para el titular [cardholderId].
  Future<Map<String, Object?>> reply(
    String cardholderId,
    String message,
  ) async {
    await modules.require(AppModule.assistant);
    final text = message.trim();
    if (text.isEmpty || text.length > AssistantBrain.maxMessageLength) {
      throw const ApiException(
        ApiErrorCode.validationFailed,
        'Escribe una pregunta de hasta 500 caracteres.',
        details: {'field': 'message'},
      );
    }
    final all = await cards.cardsOf(cardholderId);
    final card =
        all.where((c) => c['status'] != 'REPLACED').firstOrNull ??
        all.firstOrNull;
    final tx = card == null
        ? const <Map<String, Object?>>[]
        : await cards.transactions(card['cardId']! as String);
    final holder = await query(
      cards.pool,
      'SELECT full_name FROM cardholders WHERE id = @id:uuid',
      {'id': cardholderId},
    );
    final name = holder.firstOrNull?['full_name'] as String? ?? '';
    final enabled = {
      for (final m in await modules.list())
        if (m['enabled'] == true) AppModule.fromKey(m['key']! as String)!,
    };
    final r = _brain.answer(
      text,
      AssistantContext(
        firstName: name.split(' ').first,
        enabled: enabled,
        pinRequiredAboveCents: config.pinRequiredAboveCents,
        cardStatus: card?['status'] as String?,
        balanceCents: card?['balanceCents'] as int?,
        lastTransaction: tx.firstOrNull,
      ),
    );
    return {
      'intent': r.intent.name,
      'reply': r.text,
      'suggestions': r.suggestions,
    };
  }
}
