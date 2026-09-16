import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agraz/app_theme.dart';
import 'package:agraz/dairy.dart';
import 'package:agraz/dairy_owner.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: page,
      ),
    );
    await tester.pump();
  }

  testWidgets('Dairy entry form renders and Save validates empty name',
      (tester) async {
    await pumpPage(tester, const DairyPage(skipBootstrap: true));

    expect(tester.takeException(), isNull);
    expect(find.text('Dairy'), findsWidgets);
    expect(find.text('Entry'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    final narration = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(narration.minLines, isNotNull);
    expect(narration.maxLines, isNotNull);
    expect(narration.minLines! <= narration.maxLines!, isTrue);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter dairy / party name'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Gowda Dairy');
    await tester.enterText(fields.at(2), '10');
    await tester.enterText(fields.at(3), '5');
    await tester.pump();

    final amountField = tester.widget<TextField>(fields.at(4));
    expect(amountField.controller?.text, '50.00');

    await tester.tap(find.text('Payment received'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Quantity (liters)'), findsNothing);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No dairy entries yet'), findsOneWidget);
  });

  testWidgets('Dairy searches saved vendor and fills last-day rate',
      (tester) async {
    await pumpPage(
      tester,
      DairyPage(
        skipBootstrap: true,
        seedEntries: const [
          {
            'id': 1,
            'party_name': 'Gowda Dairy',
            'party_mobile': '9876543210',
            'kind': 'milk_given',
            'rate_per_liter': 42,
            'date': '2026-09-12',
          },
        ],
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Go');
    await tester.pump();
    expect(find.text('Gowda Dairy'), findsOneWidget);
    expect(find.textContaining('Last rate'), findsOneWidget);

    await tester.tap(find.text('Gowda Dairy'));
    await tester.pump();

    expect(tester.widget<TextField>(fields.at(0)).controller?.text, 'Gowda Dairy');
    expect(tester.widget<TextField>(fields.at(1)).controller?.text, '9876543210');
    expect(tester.widget<TextField>(fields.at(3)).controller?.text, '42');
  });

  testWidgets('Dairy owner entry form with narration does not assert',
      (tester) async {
    await pumpPage(tester, const DairyOwnerPage(skipBootstrap: true));

    expect(tester.takeException(), isNull);
    expect(find.text('Dairy Owner'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);

    final narration = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(narration.minLines! <= narration.maxLines!, isTrue);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter customer name'), findsOneWidget);

    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Add customer'), findsOneWidget);
  });

  testWidgets('Dairy owner searches customer and fills last-day rate',
      (tester) async {
    await pumpPage(
      tester,
      DairyOwnerPage(
        skipBootstrap: true,
        seedCustomers: const [
          {
            'id': 9,
            'name': 'Ramu Gowda',
            'mobile': '9999900000',
            'village': 'Hebbal',
            'default_rate': 38,
            'last_rate': 41,
          },
        ],
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ra');
    await tester.pump();
    expect(find.text('Ramu Gowda'), findsWidgets);
    expect(find.textContaining('Last rate'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Ramu Gowda');
    await tester.pump();

    expect(tester.widget<TextField>(fields.at(0)).controller?.text, 'Ramu Gowda');
    expect(tester.widget<TextField>(fields.at(1)).controller?.text, '9999900000');
    expect(tester.widget<TextField>(fields.at(3)).controller?.text, '41');
  });
}
