import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

void main() {
  group('AppModule', () {
    test('cada módulo tiene una llave única en snake_case', () {
      final keys = AppModule.values.map((m) => m.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
      for (final key in keys) {
        expect(key, matches(RegExp(r'^[a-z][a-z_]*$')));
      }
    });

    test('se busca por su llave', () {
      expect(AppModule.fromKey('assistant'), AppModule.assistant);
      expect(AppModule.fromKey('card_qr'), AppModule.cardQr);
      expect(AppModule.fromKey('no_existe'), isNull);
    });

    test('MODULE_DISABLED responde 403', () {
      expect(
        ApiErrorCode.fromWire('MODULE_DISABLED'),
        ApiErrorCode.moduleDisabled,
      );
      expect(ApiErrorCode.moduleDisabled.httpStatus, 403);
    });
  });
}
