import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKeyLocale = 'agraz_locale';

/// App language: English (`en`) or Kannada (`kn`).
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  Locale _locale = const Locale('en');
  bool _loaded = false;

  Locale get locale => _locale;
  bool get isLoaded => _loaded;
  bool get isKannada => _locale.languageCode == 'kn';
  bool get isEnglish => _locale.languageCode == 'en';

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('kn'),
  ];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_prefsKeyLocale) ?? 'en';
    _locale = code == 'kn' ? const Locale('kn') : const Locale('en');
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'en' && locale.languageCode != 'kn') return;
    _locale = Locale(locale.languageCode);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKeyLocale, _locale.languageCode);
  }

  Future<void> setLanguageCode(String code) =>
      setLocale(Locale(code == 'kn' ? 'kn' : 'en'));
}
