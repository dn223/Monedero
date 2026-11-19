import 'package:monedero_core/monedero_core.dart';
import 'package:test/test.dart';

void main() {
  group('Anulación', () {
    test('solo recargas y cobros se pueden anular', () {
      expect(TransactionType.topUp.isReversible, isTrue);
      expect(TransactionType.debit.isReversible, isTrue);
      expect(TransactionType.replacementIn.isReversible, isFalse);
      expect(TransactionType.replacementOut.isReversible, isFalse);
      expect(TransactionType.reversalIn.isReversible, isFalse);
      expect(TransactionType.reversalOut.isReversible, isFalse);
    });

    test('el contramovimiento tiene el signo contrario', () {
      for (final type in [TransactionType.topUp, TransactionType.debit]) {
        expect(type.reversalType.sign, -type.sign);
      }
      expect(TransactionType.debit.reversalType, TransactionType.reversalIn);
      expect(TransactionType.topUp.reversalType, TransactionType.reversalOut);
    });
  });

  test('módulos nuevos y su audiencia', () {
    expect(AppModule.fromKey('card_transfer'), AppModule.cardTransfer);
    expect(AppModule.cardTransfer.audience, ModuleAudience.cardholder);
    expect(
      AppModule.fromKey('transaction_reversal')?.audience,
      ModuleAudience.admin,
    );
  });
}
