import 'package:agraz/dairy_parties.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entries = [
    {
      'id': 2,
      'party_name': 'Gowda Dairy',
      'party_mobile': '9876543210',
      'kind': 'milk_given',
      'rate_per_liter': 45,
      'date': '2026-09-13',
    },
    {
      'id': 1,
      'party_name': 'Gowda Dairy',
      'party_mobile': '9876543210',
      'kind': 'milk_given',
      'rate_per_liter': 42,
      'date': '2026-09-12',
    },
    {
      'id': 3,
      'party_name': 'Nandini',
      'party_mobile': '',
      'kind': 'payment_received',
      'rate_per_liter': 99,
      'date': '2026-09-13',
    },
    {
      'id': 4,
      'party_name': 'Nandini',
      'party_mobile': '',
      'kind': 'milk_bought',
      'rate_per_liter': 38,
      'date': '2026-09-10',
    },
  ];

  test('one person identity keeps latest milk rate', () {
    final parties = dairyPartiesFrom(entries: entries);
    expect(parties.length, 2);

    final gowda = dairyMatchedParty(parties, name: 'gowda dairy');
    expect(gowda, isNotNull);
    expect(gowda!.mobile, '9876543210');
    expect(gowda.lastRate, 45);

    final nandini = dairyMatchedParty(parties, name: 'Nandini');
    expect(nandini, isNotNull);
    expect(nandini!.lastRate, 38);
  });

  test('customer directory plus later entry updates last rate', () {
    final parties = dairyPartiesFrom(
      customers: [
        {
          'id': 9,
          'name': 'Ramu',
          'mobile': '9999900000',
          'village': 'Hebbal',
          'default_rate': 38,
        },
      ],
      entries: [
        {
          'id': 11,
          'customer_id': 9,
          'party_name': 'Ramu',
          'party_mobile': '9999900000',
          'kind': 'collected',
          'rate_per_liter': 41,
          'date': '2026-09-12',
        },
      ],
    );
    expect(parties, hasLength(1));
    expect(parties.first.customerId, 9);
    expect(parties.first.lastRate, 41);
    expect(parties.first.village, 'Hebbal');
  });

  test('search matches prefix like labour name suggestions', () {
    final parties = dairyPartiesFrom(entries: entries);
    final hits = searchDairyParties(parties, name: 'go');
    expect(hits.map((p) => p.name), ['Gowda Dairy']);
    expect(searchDairyParties(parties, name: 'Gowda Dairy'), isEmpty);
    expect(
      dairyMatchedParty(parties, mobile: '9876543210')!.name,
      'Gowda Dairy',
    );
  });

  test('same mobile is one identity even if name spelling changes', () {
    final parties = dairyPartiesFrom(entries: [
      {
        'id': 1,
        'party_name': 'Gowda',
        'party_mobile': '9000000000',
        'kind': 'milk_given',
        'rate_per_liter': 40,
        'date': '2026-09-01',
      },
      {
        'id': 2,
        'party_name': 'Gowda Dairy',
        'party_mobile': '9000000000',
        'kind': 'milk_given',
        'rate_per_liter': 44,
        'date': '2026-09-12',
      },
    ]);
    expect(parties, hasLength(1));
    expect(parties.first.name, 'Gowda Dairy');
    expect(parties.first.lastRate, 44);
  });
}
