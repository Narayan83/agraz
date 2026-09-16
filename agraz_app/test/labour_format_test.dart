import 'package:agraz/app_theme.dart';
import 'package:agraz/labour_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment caption is lump sum, not rate × hours', () {
    expect(laborRateHoursCaption('payment', 4000, 1), '₹4000');
    expect(laborRateHoursCaption('PAYMENT', 4500, 1), '₹4500');
  });

  test('labour caption keeps rate × days/hrs', () {
    expect(laborRateHoursCaption('payable', 550, 1), '₹550 × 1');
    expect(laborRateHoursCaption('payable', 550, 0.5), '₹550 × 0.5');
    expect(laborRateHoursCaption(null, 550, 1), '₹550 × 1');
  });

  test('work kind excludes payment, tally and opening', () {
    expect(laborIsWorkKind('payable'), isTrue);
    expect(laborIsWorkKind('opening'), isFalse);
    expect(laborIsWorkKind('payment'), isFalse);
    expect(laborIsWorkKind('tally'), isFalse);
  });

  test('summary nets payments out of labour cost and ignores payment hours', () {
    final t = summarizeLaborEntries([
      {'entry_kind': 'payable', 'wage': 550, 'hours': 10.5, 'date': '2026-08-06'},
      {'entry_kind': 'payment', 'wage': 4000, 'hours': 1, 'date': '2026-08-06'},
      {'entry_kind': 'payment', 'wage': 500, 'hours': 1, 'date': '2026-08-10'},
    ]);
    expect(t.work, 5775);
    expect(t.paid, 4500);
    expect(t.net, 1275);
    expect(t.hours, 10.5);
  });

  test('net from API summary uses payable minus paid, not total_cost', () {
    expect(
      laborNetFromSummary({
        'total_cost': 10275,
        'total_payable': 5775,
        'total_paid': 4500,
      }),
      1275,
    );
  });

  test('OB/Tally both zero resets account to 0', () {
    final t = summarizeLaborEntries([
      {'id': 1, 'entry_kind': 'payable', 'wage': 500, 'hours': 10, 'date': '2026-08-01'},
      {'id': 2, 'entry_kind': 'payment', 'wage': 2000, 'hours': 1, 'date': '2026-08-10'},
      {'id': 3, 'entry_kind': 'tally', 'wage': 0, 'hours': 1, 'date': '2026-08-15'},
      {'id': 4, 'entry_kind': 'payable', 'wage': 400, 'hours': 1, 'date': '2026-08-20'},
    ], applyAccountReset: true);
    expect(t.work, 400);
    expect(t.paid, 0);
    expect(t.net, 400);
    expect(t.hours, 1);
  });

  test('OB payable opening becomes the new starting balance', () {
    final t = summarizeLaborEntries([
      {'id': 1, 'entry_kind': 'payable', 'wage': 800, 'hours': 5, 'date': '2026-07-01'},
      {'id': 2, 'entry_kind': 'opening', 'wage': 3000, 'hours': 1, 'date': '2026-08-01'},
      {'id': 3, 'entry_kind': 'payable', 'wage': 500, 'hours': 2, 'date': '2026-08-05'},
      {'id': 4, 'entry_kind': 'payment', 'wage': 1000, 'hours': 1, 'date': '2026-08-10'},
    ], applyAccountReset: true);
    expect(t.work, 4000); // 3000 opening + 1000 later work
    expect(t.paid, 1000);
    expect(t.net, 3000);
    expect(t.hours, 2);
  });

  test('OB payment opening is a debit starting balance', () {
    final t = summarizeLaborEntries([
      {'id': 1, 'entry_kind': 'payable', 'wage': 900, 'hours': 3, 'date': '2026-07-01'},
      {'id': 2, 'entry_kind': 'opening', 'wage': -1500, 'hours': 1, 'date': '2026-08-01'},
      {'id': 3, 'entry_kind': 'payable', 'wage': 400, 'hours': 1, 'date': '2026-08-04'},
    ], applyAccountReset: true);
    expect(t.work, 400);
    expect(t.paid, 1500);
    expect(t.net, -1100);
  });

  test('entry amount colors: payable green, payment red', () {
    expect(laborEntryAmountColor('payable', 350), AppColors.income);
    expect(laborEntryAmountColor('payment', 1000), AppColors.expense);
    expect(laborEntryAmountColor('opening', -500), AppColors.expense);
    expect(laborEntryAmountColor('opening', 500), AppColors.info);
  });

  test('balance colors: payable debit red, receivable credit green', () {
    expect(laborPayableBalanceColor, AppColors.expense);
    expect(laborReceivableBalanceColor, AppColors.income);
  });

  test('person filter matches exact name or mobile', () {
    expect(
      laborEntryBelongsToPerson(
        {'name': 'Manjunath Patagar', 'mobile': '9876543210'},
        name: 'Manjunath Patagar',
        mobile: '9876543210',
      ),
      isTrue,
    );
    expect(
      laborEntryBelongsToPerson(
        {'name': 'Manjunath Other', 'mobile': '1111111111'},
        name: 'Manjunath Patagar',
        mobile: '9876543210',
      ),
      isFalse,
    );
    expect(
      laborEntryBelongsToPerson(
        {'name': 'Manjunath Patagar', 'mobile': ''},
        name: 'Manjunath Patagar',
      ),
      isTrue,
    );
    expect(
      laborEntryBelongsToPerson(
        {'name': 'Someone Else', 'mobile': ''},
        name: 'Manjunath Patagar',
      ),
      isFalse,
    );
  });

  test('signed balance color: positive green, negative red', () {
    expect(laborSignedBalanceColor(100), AppColors.income);
    expect(laborSignedBalanceColor(0), AppColors.income);
    expect(laborSignedBalanceColor(-50), AppColors.expense);
  });

  test('period statement carries opening from prior transactions', () {
    final entries = [
      {'id': 1, 'entry_kind': 'payable', 'wage': 500, 'hours': 10, 'date': '2026-08-01'},
      {'id': 2, 'entry_kind': 'payment', 'wage': 875, 'hours': 1, 'date': '2026-08-15'},
      {'id': 3, 'entry_kind': 'payable', 'wage': 350, 'hours': 1, 'date': '2026-09-05'},
      {'id': 4, 'entry_kind': 'payment', 'wage': 1500, 'hours': 1, 'date': '2026-09-20'},
    ];
    final sep = laborPeriodStatement(
      entries,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
    );
    expect(sep.opening, 4125); // 5000 - 875
    expect(sep.work, 350);
    expect(sep.paid, 1500);
    expect(sep.periodNet, -1150);
    expect(sep.closing, 2975); // 4125 - 1150
    expect(sep.openingFromEntry, isFalse);
  });

  test('period statement uses explicit opening on period start', () {
    final entries = [
      {'id': 1, 'entry_kind': 'payable', 'wage': 900, 'hours': 5, 'date': '2026-07-01'},
      {'id': 2, 'entry_kind': 'opening', 'wage': 2000, 'hours': 1, 'date': '2026-08-01'},
      {'id': 3, 'entry_kind': 'payable', 'wage': 400, 'hours': 1, 'date': '2026-08-10'},
      {'id': 4, 'entry_kind': 'payment', 'wage': 500, 'hours': 1, 'date': '2026-08-20'},
    ];
    final aug = laborPeriodStatement(
      entries,
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 31),
    );
    expect(aug.openingFromEntry, isTrue);
    expect(aug.opening, 2000);
    expect(aug.work, 400);
    expect(aug.paid, 500);
    expect(aug.closing, 1900);
  });

  test('period statement negative opening from debit opening entry', () {
    final entries = [
      {'id': 1, 'entry_kind': 'opening', 'wage': -800, 'hours': 1, 'date': '2026-09-01'},
      {'id': 2, 'entry_kind': 'payable', 'wage': 300, 'hours': 1, 'date': '2026-09-05'},
    ];
    final sep = laborPeriodStatement(
      entries,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
    );
    expect(sep.openingFromEntry, isTrue);
    expect(sep.opening, -800);
    expect(sep.closing, -500);
  });

  test('future opening does not seed earlier months', () {
    final entries = [
      {'id': 1, 'entry_kind': 'opening', 'wage': 6141, 'hours': 1, 'date': '2026-08-01'},
      {'id': 2, 'entry_kind': 'payment', 'wage': 5562, 'hours': 1, 'date': '2026-09-10'},
    ];
    final jul = laborPeriodStatement(
      entries,
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 31),
    );
    expect(jul.opening, 0);
    expect(jul.closing, 0);
    expect(jul.entryCount, 0);

    final aug = laborPeriodStatement(
      entries,
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 31),
    );
    expect(aug.onlyOpeningEntry, isTrue);
    expect(aug.summaryAmount, 6141);
    expect(aug.opening, 6141);
    expect(aug.closing, 6141);
  });

  test('mid-month only opening still shows as opening transaction', () {
    final entries = [
      {'id': 1, 'entry_kind': 'opening', 'wage': 6141, 'hours': 1, 'date': '2026-08-15'},
    ];
    final aug = laborPeriodStatement(
      entries,
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 31),
    );
    expect(aug.onlyOpeningEntry, isTrue);
    expect(aug.summaryAmount, 6141);
    expect(aug.opening, 6141);
    expect(aug.closing, 6141);
  });

  test('work lines group by type of work and wage', () {
    final entries = [
      {'id': 1, 'entry_kind': 'opening', 'wage': 5000, 'hours': 1, 'date': '2026-09-01'},
      {
        'id': 2,
        'entry_kind': 'payable',
        'work_type': 'Daily Wages',
        'wage': 550,
        'hours': 10,
        'date': '2026-09-02',
      },
      {
        'id': 3,
        'entry_kind': 'payable',
        'work_type': 'Daily Wages',
        'wage': 550,
        'hours': 2,
        'date': '2026-09-03',
      },
      {
        'id': 4,
        'entry_kind': 'payable',
        'work_type': 'Daily Wages',
        'wage': 800,
        'hours': 5,
        'date': '2026-09-04',
      },
      {
        'id': 5,
        'entry_kind': 'payable',
        'work_type': 'Contract',
        'wage': 60,
        'hours': 10,
        'date': '2026-09-05',
      },
      {
        'id': 6,
        'entry_kind': 'payable',
        'work_type': 'Contract',
        'wage': 1.5,
        'hours': 150,
        'date': '2026-09-06',
      },
      {'id': 7, 'entry_kind': 'payment', 'wage': 6000, 'hours': 1, 'date': '2026-09-10'},
    ];
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 9, 30);
    final lines = laborWorkLines(entries, from: from, to: to);
    expect(lines, hasLength(4));
    expect(lines[0].workType, 'Daily Wages');
    expect(lines[0].wage, 550);
    expect(lines[0].labour, 12);
    expect(lines[0].total, 6600);
    expect(lines[1].workType, 'Daily Wages');
    expect(lines[1].wage, 800);
    expect(lines[1].labour, 5);
    expect(lines[1].total, 4000);
    expect(lines[2].workType, 'Contract');
    expect(lines[2].wage, 60);
    expect(lines[2].labour, 10);
    expect(lines[2].total, 600);
    expect(lines[3].workType, 'Contract');
    expect(lines[3].wage, 1.5);
    expect(lines[3].labour, 150);
    expect(lines[3].total, 225);

    final stmt = laborPeriodStatement(entries, from: from, to: to);
    expect(stmt.opening, 5000);
    expect(stmt.work, 11425);
    expect(stmt.paid, 6000);
    expect(stmt.closing, 10425);
    expect(laborPeriodPaymentEntries(entries, from: from, to: to), hasLength(1));
  });

  test('month closing equals next month opening without new OB', () {
    final entries = [
      {'id': 1, 'entry_kind': 'payable', 'wage': 500, 'hours': 10, 'date': '2026-08-05'},
      {'id': 2, 'entry_kind': 'payment', 'wage': 2000, 'hours': 1, 'date': '2026-08-20'},
      {'id': 3, 'entry_kind': 'payable', 'wage': 400, 'hours': 2, 'date': '2026-09-05'},
      {'id': 4, 'entry_kind': 'payment', 'wage': 500, 'hours': 1, 'date': '2026-09-15'},
    ];
    final aug = laborPeriodStatement(
      entries,
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 31),
    );
    final sep = laborPeriodStatement(
      entries,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
    );
    expect(aug.closing, 3000); // 5000 - 2000
    expect(sep.opening, aug.closing);
    expect(sep.closing, 3300); // 3000 + 800 - 500
  });

  test('tally mid-month resets balance for later entries', () {
    final entries = [
      {'id': 1, 'entry_kind': 'payable', 'wage': 1000, 'hours': 5, 'date': '2026-09-01'},
      {'id': 2, 'entry_kind': 'payment', 'wage': 2000, 'hours': 1, 'date': '2026-09-10'},
      {'id': 3, 'entry_kind': 'tally', 'wage': 0, 'hours': 1, 'date': '2026-09-15'},
      {'id': 4, 'entry_kind': 'payable', 'wage': 300, 'hours': 2, 'date': '2026-09-20'},
    ];
    final after = summarizeLaborEntries(
      entries,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
      applyAccountReset: true,
    );
    expect(after.work, 600);
    expect(after.paid, 0);
    expect(after.net, 600);
  });

  test('same mobile different name spelling still one person filter', () {
    expect(
      laborEntryBelongsToPerson(
        {'name': 'Ramu Gowda', 'mobile': '9000011111'},
        name: 'Ramu',
        mobile: '9000011111',
      ),
      isTrue,
    );
  });

  test('summary labour search matches name or mobile', () {
    final people = [
      {'name': 'Manjunath Patagar', 'mobile': '9876543210'},
      {'name': 'Ramu Gowda', 'mobile': '9000011111'},
      {'name': 'Lakshmi', 'mobile': ''},
    ];
    expect(laborPersonMatchesQuery(people[0], 'manju'), isTrue);
    expect(laborPersonMatchesQuery(people[0], '98765'), isTrue);
    expect(laborPersonMatchesQuery(people[0], 'ramu'), isFalse);
    expect(laborPeopleMatchingQuery(people, 'gowda'), hasLength(1));
    expect(laborPeopleMatchingQuery(people, 'gowda').single['name'], 'Ramu Gowda');
    expect(laborPeopleMatchingQuery(people, ''), hasLength(3));
    expect(laborPeopleMatchingQuery(people, 'zzz'), isEmpty);
  });
}
