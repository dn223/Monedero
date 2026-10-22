import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

void main() {
  group('ApiError', () {
    test('serializa y deserializa con el formato estándar', () {
      const error = ApiError(
        ApiErrorCode.validationFailed,
        'Monto inválido',
        details: {'field': 'amountCents'},
      );

      final json = error.toJson();
      expect(json, {
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'Monto inválido',
          'details': {'field': 'amountCents'},
        },
      });

      final parsed = ApiError.fromJson(json);
      expect(parsed.code, ApiErrorCode.validationFailed);
      expect(parsed.message, 'Monto inválido');
      expect(parsed.details, {'field': 'amountCents'});
    });

    test('omite details cuando está vacío', () {
      const error = ApiError(ApiErrorCode.notFound, 'No existe');
      expect((error.toJson()['error']! as Map).containsKey('details'), isFalse);
    });

    test('un código desconocido se interpreta como INTERNAL_ERROR', () {
      expect(ApiErrorCode.fromWire('CODIGO_NUEVO'), ApiErrorCode.internal);
    });

    test('rechaza JSON sin el objeto error', () {
      expect(
        () => ApiError.fromJson({'message': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('HealthStatus ida y vuelta', () {
    const health = HealthStatus(status: 'ok', version: '0.1.0', demoMode: true);
    final parsed = HealthStatus.fromJson(health.toJson());
    expect(parsed.isOk, isTrue);
    expect(parsed.version, '0.1.0');
    expect(parsed.demoMode, isTrue);
  });
}
