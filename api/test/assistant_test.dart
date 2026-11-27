import 'package:monedero_api/src/services/assistant_service.dart';
import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

void main() {
  const brain = AssistantBrain();
  const ana = AssistantContext(
    firstName: 'Ana',
    enabled: {...AppModule.values},
    pinRequiredAboveCents: 2500,
    cardStatus: 'ACTIVE',
    balanceCents: 1735,
    lastTransaction: {
      'type': 'DEBIT',
      'amountCents': 735,
      'balanceAfterCents': 1735,
    },
  );

  group('AssistantBrain.classify', () {
    test('reconoce la intención sin importar acentos ni mayúsculas', () {
      expect(brain.classify('¿Cuál es mi SALDO?'), AssistantIntent.balance);
      expect(brain.classify('cuanto tengo'), AssistantIntent.balance);
      expect(brain.classify('¿Cómo recargo?'), AssistantIntent.topUp);
      expect(brain.classify('Quiero cambiar mi PIN'), AssistantIntent.pin);
      expect(brain.classify('¿Cómo pago en caja?'), AssistantIntent.pay);
      expect(brain.classify('mi último movimiento'), AssistantIntent.history);
      expect(brain.classify('Hola'), AssistantIntent.greeting);
      expect(brain.classify('muchas gracias'), AssistantIntent.thanks);
      expect(brain.classify('qué hora es'), AssistantIntent.help);
    });

    test('la pérdida tiene prioridad sobre el saldo', () {
      expect(
        brain.classify('Perdí mi tarjeta, ¿qué pasa con mi saldo?'),
        AssistantIntent.loss,
      );
      expect(brain.classify('me la robaron'), AssistantIntent.loss);
    });

    test('"pin" se reconoce solo como palabra completa', () {
      expect(brain.classify('pintura'), AssistantIntent.help);
    });
  });

  group('AssistantBrain.answer', () {
    test('responde el saldo y el último movimiento reales', () {
      expect(brain.answer('saldo', ana).text, r'Tu saldo es $17.35.');
      expect(
        brain.answer('último movimiento', ana).text,
        allOf(contains(r'compra de $7.35'), contains(r'$17.35')),
      );
    });

    test('avisa si la tarjeta no está activa o no existe', () {
      const blocked = AssistantContext(
        firstName: 'Ana',
        enabled: {},
        pinRequiredAboveCents: 2500,
        cardStatus: 'BLOCKED',
        balanceCents: 500,
      );
      expect(brain.answer('saldo', blocked).text, contains('bloqueada'));
      const none = AssistantContext(
        firstName: 'Ana',
        enabled: {},
        pinRequiredAboveCents: 2500,
      );
      expect(brain.answer('saldo', none).text, contains('Aún no tienes'));
    });

    test('no sugiere funciones de módulos apagados', () {
      const off = AssistantContext(
        firstName: 'Ana',
        enabled: {AppModule.assistant},
        pinRequiredAboveCents: 2500,
        cardStatus: 'ACTIVE',
        balanceCents: 0,
      );
      final pay = brain.answer('¿cómo pago?', off).text;
      expect(pay, isNot(contains('QR')));
      expect(pay, isNot(contains('Pagar en caja')));
      expect(pay, contains(r'$25.00'));
      expect(
        brain.answer('cambiar pin', off).text,
        contains('no está disponible'),
      );
      expect(brain.answer('pin', ana).text, contains('Cambiar PIN'));
    });

    test('ofrece hasta 3 sugerencias distintas a lo que se preguntó', () {
      final r = brain.answer('saldo', ana);
      expect(r.suggestions, hasLength(3));
      expect(r.suggestions, isNot(contains('¿Cuál es mi saldo?')));
    });
  });
}
