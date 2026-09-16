import 'package:agraz/uk_land_geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sirsi hoblis include Sampakanda', () {
    final hoblis = UkLandGeo.hoblisFor('Sirsi');
    expect(hoblis, contains('Sampakanda'));
    expect(hoblis, contains('Sampakhanda'));
    expect(hoblis, contains('Sirsi'));
  });

  test('Sirsi, Siddapur and Yellapur gramas are offered', () {
    expect(UkLandGeo.gramasFor('Sirsi', 'Sirsi'), contains('Sirsi'));
    expect(UkLandGeo.gramasFor('Siddapur', 'Siddapur'), contains('Siddapur'));
    expect(UkLandGeo.gramasFor('Yellapur', 'Yellapur'), contains('Yellapur'));
    expect(UkLandGeo.gramasFor('Sirsi', 'Sampakanda'), contains('Sampakanda'));
  });

  test('withCurrent keeps a saved hobli that is not in the list', () {
    final list = UkLandGeo.withCurrent(['Sirsi', 'Banavasi'], 'Sampakanda');
    expect(list.first, 'Sampakanda');
    expect(list, contains('Sirsi'));
  });
}
