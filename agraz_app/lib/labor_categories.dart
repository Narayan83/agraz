import 'package:shared_preferences/shared_preferences.dart';

/// Shared labour work categories used for fixed per-person rates.
const List<String> kLaborWorkCategories = [
  'Plucking',
  'Cutting',
  'Drying',
  'Grading',
  'Packing',
  'Transport',
];

const String _customCategoriesKey = 'custom_labor_categories';

List<String> _sortedAlpha(Iterable<String> items) {
  final list = items.toSet().toList();
  list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

/// Default + any user-added categories, alphabetically sorted.
Future<List<String>> loadLaborCategories() async {
  final prefs = await SharedPreferences.getInstance();
  final custom = prefs.getStringList(_customCategoriesKey) ?? [];
  return _sortedAlpha([...kLaborWorkCategories, ...custom]);
}

/// Adds [name] to the custom category list (if new) and returns the
/// updated, alphabetically sorted category list.
Future<List<String>> addCustomLaborCategory(String name) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return loadLaborCategories();
  final prefs = await SharedPreferences.getInstance();
  final custom = prefs.getStringList(_customCategoriesKey) ?? [];
  final exists = kLaborWorkCategories
          .any((c) => c.toLowerCase() == trimmed.toLowerCase()) ||
      custom.any((c) => c.toLowerCase() == trimmed.toLowerCase());
  if (!exists) {
    custom.add(trimmed);
    await prefs.setStringList(_customCategoriesKey, custom);
  }
  return loadLaborCategories();
}

String _laborKey(String prefix, String name) =>
    '${prefix}_${name.trim().toLowerCase()}';

/// Address book for labourers, keyed by (lowercased, trimmed) name — used
/// so the "Additional information" popup can restore a previously entered
/// address when a labourer's name is picked again.
Future<String?> loadLaborAddress(String name) async {
  if (name.trim().isEmpty) return null;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_laborKey('labor_addr', name));
}

Future<void> saveLaborAddress(String name, String address) async {
  if (name.trim().isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final key = _laborKey('labor_addr', name);
  final trimmed = address.trim();
  if (trimmed.isEmpty) {
    await prefs.remove(key);
  } else {
    await prefs.setString(key, trimmed);
  }
}

/// Mobile book for labourers, keyed by name — mobile is now entered via
/// the "Additional information" popup rather than the main form, so it is
/// remembered locally per name to speed up repeat entries.
Future<String?> loadLaborMobile(String name) async {
  if (name.trim().isEmpty) return null;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_laborKey('labor_mobile', name));
}

Future<void> saveLaborMobile(String name, String mobile) async {
  if (name.trim().isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final key = _laborKey('labor_mobile', name);
  final trimmed = mobile.trim();
  if (trimmed.isEmpty) {
    await prefs.remove(key);
  } else {
    await prefs.setString(key, trimmed);
  }
}
