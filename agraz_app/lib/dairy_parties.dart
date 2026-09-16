import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'l10n/app_l10n.dart';

/// One vendor/customer identity reused on later dairy entries.
class DairyParty {
  const DairyParty({
    required this.name,
    this.mobile = '',
    this.village = '',
    this.lastRate = 0,
    this.customerId,
    this.lastDate = '',
  });

  final String name;
  final String mobile;
  final String village;
  final double lastRate;
  final int? customerId;
  final String lastDate;

  String get identityKey => dairyPartyKey(name: name, mobile: mobile);

  DairyParty merge(DairyParty other) {
    final otherNewer =
        lastDate.isEmpty || other.lastDate.compareTo(lastDate) >= 0;
    final rate = other.lastRate > 0 && (otherNewer || lastRate <= 0)
        ? other.lastRate
        : (lastRate > 0 ? lastRate : other.lastRate);
    return DairyParty(
      name: other.name.trim().isNotEmpty && otherNewer
          ? other.name.trim()
          : (name.trim().isNotEmpty ? name.trim() : other.name.trim()),
      mobile: dairyLast10(other.mobile).length == 10
          ? dairyLast10(other.mobile)
          : (dairyLast10(mobile).length == 10
              ? dairyLast10(mobile)
              : (other.mobile.trim().isNotEmpty
                  ? other.mobile.trim()
                  : mobile.trim())),
      village: village.trim().isNotEmpty ? village.trim() : other.village.trim(),
      lastRate: rate,
      customerId: customerId ?? other.customerId,
      lastDate: otherNewer && other.lastDate.isNotEmpty ? other.lastDate : lastDate,
    );
  }
}

double _partyNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String dairyLast10(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 10) return digits.substring(digits.length - 10);
  return digits;
}

String dairyPartyKey({required String name, String mobile = ''}) {
  final m = dairyLast10(mobile);
  if (m.length == 10) return 'm:$m';
  return 'n:${name.trim().toLowerCase()}';
}

bool dairyIsMilkKind(String kind) {
  switch (kind) {
    case 'milk_given':
    case 'milk_bought':
    case 'collected':
    case 'sold':
      return true;
    default:
      return false;
  }
}

String dairyRateText(double rate) {
  if (rate <= 0) return '';
  if (rate == rate.roundToDouble()) return '${rate.toInt()}';
  return rate.toStringAsFixed(2);
}

/// Directory of people: customers first, then rows overlay the latest
/// name, mobile, and last milk rate (newest date wins).
List<DairyParty> dairyPartiesFrom({
  List<Map<String, dynamic>> entries = const [],
  List<Map<String, dynamic>> customers = const [],
}) {
  final map = <String, DairyParty>{};

  void upsert(DairyParty party) {
    if (party.name.trim().isEmpty && dairyLast10(party.mobile).length != 10) {
      return;
    }
    final key = party.identityKey;
    final existing = map[key];
    map[key] = existing == null ? party : existing.merge(party);
  }

  for (final c in customers) {
    final id = _partyNum(c['id']).toInt();
    final rate = _partyNum(c['last_rate']) > 0
        ? _partyNum(c['last_rate'])
        : _partyNum(c['default_rate']);
    upsert(DairyParty(
      name: '${c['name'] ?? ''}'.trim(),
      mobile: '${c['mobile'] ?? ''}'.trim(),
      village: '${c['village'] ?? ''}'.trim(),
      lastRate: rate,
      customerId: id > 0 ? id : null,
    ));
  }

  final rows = [...entries]..sort((a, b) {
      final byDate = '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}');
      if (byDate != 0) return byDate;
      return _partyNum(b['id']).toInt() - _partyNum(a['id']).toInt();
    });

  for (final row in rows) {
    final kind = '${row['kind'] ?? row['owner_kind'] ?? ''}';
    final rate = dairyIsMilkKind(kind) ? _partyNum(row['rate_per_liter']) : 0.0;
    final id = _partyNum(row['customer_id']).toInt();
    upsert(DairyParty(
      name: '${row['party_name'] ?? ''}'.trim(),
      mobile: '${row['party_mobile'] ?? ''}'.trim(),
      lastRate: rate,
      customerId: id > 0 ? id : null,
      lastDate: '${row['date'] ?? ''}',
    ));
  }

  final list = map.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}

/// Labour-style search: 10-digit mobile is an exact identity; otherwise
/// names matching the typed prefix/contains, excluding the exact typed name.
List<DairyParty> searchDairyParties(
  List<DairyParty> parties, {
  String name = '',
  String mobile = '',
  int limit = 6,
}) {
  final qMob = dairyLast10(mobile);
  if (qMob.length == 10) {
    final hits =
        parties.where((p) => dairyLast10(p.mobile) == qMob).toList();
    if (hits.isNotEmpty) return hits.take(limit).toList();
  }
  final qName = name.trim().toLowerCase();
  if (qName.length < 2) return const [];
  final starts = <DairyParty>[];
  final contains = <DairyParty>[];
  for (final p in parties) {
    final n = p.name.toLowerCase();
    if (n.isEmpty || n == qName) continue;
    if (n.startsWith(qName)) {
      starts.add(p);
    } else if (n.contains(qName)) {
      contains.add(p);
    }
  }
  return [...starts, ...contains].take(limit).toList();
}

/// Exact identity: mobile (10 digits) wins, else unique full name.
DairyParty? dairyMatchedParty(
  List<DairyParty> parties, {
  String name = '',
  String mobile = '',
}) {
  final qMob = dairyLast10(mobile);
  if (qMob.length == 10) {
    for (final p in parties) {
      if (dairyLast10(p.mobile) == qMob) return p;
    }
  }
  final qName = name.trim().toLowerCase();
  if (qName.isEmpty) return null;
  DairyParty? found;
  for (final p in parties) {
    if (p.name.toLowerCase() == qName) {
      if (found != null) return found;
      found = p;
    }
  }
  return found;
}

Widget dairyPartySuggestionList({
  required List<DairyParty> parties,
  required ValueChanged<DairyParty> onSelect,
}) {
  if (parties.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      children: [
        for (var i = 0; i < parties.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Material(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onSelect(parties[i]),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(parties[i].name, style: AppText.bodyStrong),
                          if (_partyCaption(parties[i]).isNotEmpty)
                            Text(
                              _partyCaption(parties[i]),
                              style: AppText.caption,
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.north_west_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

String _partyCaption(DairyParty p) {
  final parts = <String>[];
  if (p.mobile.isNotEmpty) parts.add(p.mobile);
  if (p.village.isNotEmpty) parts.add(p.village);
  if (p.lastRate > 0) {
    parts.add(
      '${tr('Last rate')} ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(p.lastRate)}',
    );
  }
  return parts.join('  ·  ');
}
