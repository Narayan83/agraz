/// Uttara Kannada taluks and hoblis for Karnataka RTC entry.
class UkLandGeo {
  static const String defaultState = 'Karnataka';
  static const String defaultDistrict = 'Uttara Kannada';
  static const String defaultTaluk = 'Sirsi';

  static const List<String> states = ['Karnataka'];

  static const List<String> districts = ['Uttara Kannada'];

  static const List<String> taluks = [
    'Sirsi',
    'Siddapur',
    'Yellapur',
    'Mundgod',
    'Haliyal',
    'Joida',
    'Dandeli',
    'Karwar',
    'Ankola',
    'Kumta',
    'Honnavar',
    'Bhatkal',
  ];

  /// Hoblis keyed by taluk (revenue circles commonly used in UK RTC).
  static const Map<String, List<String>> hoblisByTaluk = {
    'Sirsi': [
      'Sirsi',
      'Banavasi',
      'Sonda',
      'Sugavi',
      'Chipgi',
      'Hulekal',
      'Devanalli',
      'Bisalkoppa',
    ],
    'Siddapur': [
      'Siddapur',
      'Kansur',
      'Kyadgi',
      'Hareguli',
      'Bilagi',
    ],
    'Yellapur': [
      'Yellapur',
      'Kiravatti',
      'Idagundi',
      'Vajralli',
    ],
    'Mundgod': [
      'Mundgod',
      'Pala',
      'Bedasgaon',
      'Hangarki',
    ],
    'Haliyal': [
      'Haliyal',
      'Bhagawati',
      'Tattihalla',
      'Murkwad',
    ],
    'Joida': [
      'Joida',
      'Castle Rock',
      'Anshi',
      'Kumbarwada',
    ],
    'Dandeli': [
      'Dandeli',
      'Ambewadi',
    ],
    'Karwar': [
      'Karwar',
      'Chittakula',
      'Kadwad',
      'Majali',
    ],
    'Ankola': [
      'Ankola',
      'Belase',
      'Achave',
      'Agsur',
    ],
    'Kumta': [
      'Kumta',
      'Gokarna',
      'Mirjan',
      'Baad',
      'Kagal',
    ],
    'Honnavar': [
      'Honnavar',
      'Manki',
      'Karki',
      'Idagunji',
    ],
    'Bhatkal': [
      'Bhatkal',
      'Murdeshwar',
      'Mavinkurve',
      'Shirali',
    ],
  };

  static List<String> hoblisFor(String taluk) {
    return List<String>.from(hoblisByTaluk[taluk] ?? const <String>[]);
  }

  /// 40 gunta = 1 acre, 4 ana = 1 gunta.
  static ({int acre, int gunta, int ana, double totalAcres}) normalizeArea({
    required int acre,
    required int gunta,
    required int ana,
  }) {
    var a = acre;
    var g = gunta;
    var n = ana;
    g += n ~/ 4;
    n = n % 4;
    a += g ~/ 40;
    g = g % 40;
    final total = a + (g / 40.0) + (n / 160.0);
    return (acre: a, gunta: g, ana: n, totalAcres: total);
  }

  static String formatTotal(double totalAcres) {
    return totalAcres.toStringAsFixed(totalAcres == totalAcres.roundToDouble() ? 0 : 4);
  }
}
