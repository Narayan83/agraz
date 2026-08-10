import 'locale_controller.dart';
import 'translations_kn.dart';

/// Translate an English UI string to the active locale.
/// English is the source key; Kannada comes from [kKannadaTranslations].
String tr(String english) {
  if (english.isEmpty) return english;
  if (LocaleController.instance.isEnglish) return english;
  return kKannadaTranslations[english] ?? english;
}

/// Convenience for templates: `trf('Page {0} of {1}', [page, total])`
String trf(String englishTemplate, List<Object?> args) {
  var out = tr(englishTemplate);
  for (var i = 0; i < args.length; i++) {
    out = out.replaceAll('{$i}', '${args[i]}');
  }
  return out;
}

extension AppL10nString on String {
  String get trl => tr(this);
}
