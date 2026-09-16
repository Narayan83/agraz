import 'package:agraz/income_expense_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FarmIncomeLineCalc', () {
    test('price and qty compute total', () {
      final r = FarmIncomeLineCalc.sync(
        quantity: 10,
        unitPrice: 25,
        total: 0,
        fromTotal: false,
      );
      expect(r.unitPrice, 25);
      expect(r.total, 250);
    });

    test('total and qty compute price', () {
      final r = FarmIncomeLineCalc.sync(
        quantity: 10,
        unitPrice: 0,
        total: 250,
        fromTotal: true,
      );
      expect(r.unitPrice, 25);
      expect(r.total, 250);
    });

    test('qty change after price recomputes total', () {
      final r = FarmIncomeLineCalc.sync(
        quantity: 4,
        unitPrice: 25,
        total: 250,
        fromTotal: false,
      );
      expect(r.unitPrice, 25);
      expect(r.total, 100);
    });

    test('qty change after total recomputes price', () {
      final r = FarmIncomeLineCalc.sync(
        quantity: 5,
        unitPrice: 25,
        total: 250,
        fromTotal: true,
      );
      expect(r.unitPrice, 50);
      expect(r.total, 250);
    });

    test('qty zero never invents quantity or the other field', () {
      final r = FarmIncomeLineCalc.sync(
        quantity: 0,
        unitPrice: 25,
        total: 250,
        fromTotal: true,
      );
      expect(r.unitPrice, 25);
      expect(r.total, 250);
    });
  });

  test('fromJson fills price from total and qty', () {
    final line = FarmIncomeProductLine.fromJson({
      'product': 'rashi',
      'quantity': 10,
      'unit': 'kg',
      'total': 250,
    });
    expect(line.unitPrice, 25);
    expect(line.total, 250);
  });

  test('toJson includes computed total', () {
    final json = FarmIncomeProductLine(
      product: 'rashi',
      quantity: 10,
      unitPrice: 12.5,
    ).toJson();
    expect(json['total'], 125);
    expect(json['unit_price'], 12.5);
  });

  test('product details require exactly one farming-income crop', () {
    expect(
      IncomeExpenseData.supportsProductDetails('Farming Income', ['Arecanut']),
      isTrue,
    );
    expect(
      IncomeExpenseData.supportsProductDetails(
        'Farming Income',
        ['Arecanut', 'Banana'],
      ),
      isFalse,
    );
    expect(
      IncomeExpenseData.supportsProductDetails('Farming Expense', ['Labour']),
      isFalse,
    );
  });

  test('saving a transaction sends a single subcategory', () {
    final data = IncomeExpenseData()
      ..receiptPaymentType = 'Income'
      ..category = 'Farming Income'
      ..subCategories = ['Arecanut']
      ..subCategory = 'Arecanut'
      ..amount = 250
      ..transactionDate = DateTime(2026, 9, 15)
      ..name = 'hapcins'
      ..mobile = '9999999999'
      ..productLines = [
        FarmIncomeProductLine(
          product: 'rashi',
          quantity: 10,
          unit: 'kg',
          unitPrice: 25,
          lineTotal: 250,
        ),
      ];
    final json = data.toJson();
    expect(json['subCategory'], 'Arecanut');
    expect(json['sub_category'], 'Arecanut');
    expect(json.containsKey('subCategories'), isFalse);
    expect(json['product_lines'], isA<List>());
    expect((json['product_lines'] as List).single['total'], 250);
  });
}
