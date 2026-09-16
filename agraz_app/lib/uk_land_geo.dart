/// Uttara Kannada taluks, hoblis and gramas for Karnataka RTC entry.
class UkLandGeo {
  static const String defaultState = 'Karnataka';
  static const String defaultDistrict = 'Uttara Kannada';
  static const String defaultTaluk = 'Sirsi';
  static const String otherGrama = 'Other';

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

  /// Hoblis keyed by taluk (revenue circles used in UK Bhoomi / RTC).
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
      'Sampakanda',
      'Sampakhanda',
    ],
    'Siddapur': [
      'Siddapur',
      'Kansur',
      'Kyadgi',
      'Hareguli',
      'Bilagi',
      'Bilgi',
    ],
    'Yellapur': [
      'Yellapur',
      'Kiravatti',
      'Kirwatti',
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

  /// Gramas (villages) keyed by hobli for Sirsi, Siddapur and Yellapur.
  static const Map<String, List<String>> gramasByHobli = {
    'Sirsi': [
      'Sirsi',
      'Sirsi (Rural)',
      'Hutgar',
      'Sadashivalli',
      'Chipgi',
    ],
    'Banavasi': [
      'Banavasi',
      'Margundi',
    ],
    'Sonda': [
      'Sonda',
      'Sondha',
      'Audala',
      'Hancharata',
    ],
    'Sugavi': [
      'Sugavi',
      'Bengle',
      'Vaddinakoppa',
    ],
    'Chipgi': [
      'Chipgi',
      'Boppanalli',
      'Sannakeri',
      'Isalooru',
    ],
    'Hulekal': [
      'Hulekal',
      'Bakkal',
      'Harehulekal',
      'Hancharata',
    ],
    'Devanalli': [
      'Devanalli',
      'Devanmane',
      'Benagaon',
      'Sarguppa',
    ],
    'Bisalkoppa': [
      'Bisalkoppa',
      'Adnalli',
      'Angodkoppa',
      'Ullal',
      'Benagi',
    ],
    'Sampakanda': [
      'Sampakanda',
      'Sampakhanda',
      'Janmane',
      'Adalli',
      'Balavalli',
    ],
    'Sampakhanda': [
      'Sampakhanda',
      'Sampakanda',
      'Janmane',
      'Adalli',
      'Balavalli',
    ],
    'Siddapur': [
      'Siddapur',
      'Kangod',
      'Akkunji',
      'Kolsirsi',
      'Itagi',
    ],
    'Kansur': [
      'Kansur',
      'Tarehalli-Kansur',
      'Kangod-Kansur',
    ],
    'Kyadgi': [
      'Kyadgi',
      'Hostot',
      'Heggarani',
    ],
    'Hareguli': [
      'Hareguli',
    ],
    'Bilagi': [
      'Bilagi',
      'Bilgi',
      'Itagi',
      'Hosamanju',
    ],
    'Bilgi': [
      'Bilgi',
      'Bilagi',
      'Itagi',
      'Hosamanju',
    ],
    'Yellapur': [
      'Yellapur',
      'Madnur',
    ],
    'Kiravatti': [
      'Kiravatti',
      'Kirwatti',
      'Hosalli',
      'Kanchanahalli',
    ],
    'Kirwatti': [
      'Kirwatti',
      'Kiravatti',
      'Hosalli',
      'Kanchanahalli',
    ],
    'Idagundi': [
      'Idagundi',
      'Idgundi',
    ],
    'Vajralli': [
      'Vajralli',
      'Magod',
      'Nandolli',
    ],
  };

  /// Taluk-headquarter gramas always offered for the three core taluks.
  static const Map<String, List<String>> gramasByTaluk = {
    'Sirsi': ['Sirsi'],
    'Siddapur': ['Siddapur'],
    'Yellapur': ['Yellapur'],
  };

  static List<String> hoblisFor(String taluk) {
    return List<String>.from(hoblisByTaluk[taluk] ?? const <String>[]);
  }

  static List<String> gramasFor(String taluk, String hobli) {
    final seen = <String>{};
    final out = <String>[];
    void addAll(Iterable<String> names) {
      for (final n in names) {
        final name = n.trim();
        if (name.isEmpty || !seen.add(name)) continue;
        out.add(name);
      }
    }

    addAll(gramasByHobli[hobli] ?? const <String>[]);
    addAll(gramasByTaluk[taluk] ?? const <String>[]);
    if (hobli.trim().isNotEmpty) addAll([hobli.trim()]);
    if (out.isEmpty && taluk.trim().isNotEmpty) addAll([taluk.trim()]);
    addAll([otherGrama]);
    return out;
  }

  /// Keep a saved value visible even if it is not in the canonical list.
  static List<String> withCurrent(List<String> options, String? current) {
    final list = List<String>.from(options);
    final cur = (current ?? '').trim();
    if (cur.isNotEmpty && !list.contains(cur)) {
      list.insert(0, cur);
    }
    return list;
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
