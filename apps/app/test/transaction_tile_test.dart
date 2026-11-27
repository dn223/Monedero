import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monedero/core/widgets/card_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Material(child: child)),
);

Map<String, Object?> _tx({
  String type = 'DEBIT',
  bool reversed = false,
  bool reversible = true,
  String? reason,
}) => {
  'transactionId': 't1',
  'type': type,
  'amountCents': 735,
  'balanceAfterCents': 1265,
  'createdAt': '2026-11-18T15:00:00Z',
  'reversed': reversed,
  'reversible': reversible,
  'reason': ?reason,
};

void main() {
  testWidgets('el botón Anular solo aparece si se puede anular', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(TransactionTile(_tx(), onReverse: () => tapped = true)),
    );
    await tester.tap(find.byTooltip('Anular movimiento'));
    expect(tapped, isTrue);

    await tester.pumpWidget(
      _wrap(TransactionTile(_tx(reversible: false), onReverse: () {})),
    );
    expect(find.byTooltip('Anular movimiento'), findsNothing);

    await tester.pumpWidget(_wrap(TransactionTile(_tx())));
    expect(find.byTooltip('Anular movimiento'), findsNothing);
  });

  testWidgets('muestra el movimiento anulado y el contramovimiento', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TransactionTile(
          _tx(reversed: true, reversible: false, reason: 'Cobro duplicado'),
        ),
      ),
    );
    expect(find.text('Compra (anulado)'), findsOneWidget);
    expect(find.textContaining('Motivo: Cobro duplicado'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(TransactionTile(_tx(type: 'REVERSAL_IN', reversible: false))),
    );
    expect(find.text('Devolución por cobro anulado'), findsOneWidget);
    expect(find.text(r'+$7.35'), findsOneWidget);
  });
}
