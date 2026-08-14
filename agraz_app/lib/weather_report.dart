import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'l10n/locale_controller.dart';
import 'weather_service.dart';

class WeatherReportPage extends StatefulWidget {
  const WeatherReportPage({super.key});

  @override
  State<WeatherReportPage> createState() => _WeatherReportPageState();
}

class _WeatherReportPageState extends State<WeatherReportPage> {
  bool _loading = true;
  String? _error;
  String _location = 'sirsi';
  List<Map<String, dynamic>> _locations = [];
  Map<String, dynamic> _report = {};

  bool get _kn => LocaleController.instance.isKannada;

  String _pick(Map? m, String en, String kn) {
    if (m == null) return '';
    if (_kn) {
      final v = m[kn]?.toString() ?? '';
      if (v.isNotEmpty) return v;
    }
    return m[en]?.toString() ?? '';
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _deg(dynamic v) => '${_num(v).round()}°';

  String _mm(dynamic v) {
    final n = _num(v);
    if (n <= 0) return '0 mm';
    if (n < 1) return '${n.toStringAsFixed(1)} mm';
    return '${n.round()} mm';
  }

  String _when(dynamic iso) {
    if (iso == null) return '';
    try {
      final t = DateTime.parse(iso.toString()).toLocal();
      return DateFormat('d MMM, h:mm a').format(t);
    } catch (_) {
      return iso.toString();
    }
  }

  String _dayLabel(Map d) {
    final wd = _pick(d, 'weekday', 'weekday_kn');
    final date = d['date']?.toString() ?? '';
    if (date.length >= 10) {
      try {
        final t = DateTime.parse(date);
        return '$wd · ${DateFormat('d MMM').format(t)}';
      } catch (_) {}
    }
    return wd;
  }

  IconData _codeIcon(int code) {
    if (code == 0 || code == 1) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.blur_on_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    if (code >= 80) return Icons.grain_rounded;
    if (code >= 61) return Icons.umbrella_rounded;
    if (code >= 51) return Icons.water_drop_rounded;
    return Icons.cloud_queue_rounded;
  }

  Color _codeColor(int code) {
    if (code == 0 || code == 1) return const Color(0xFFE9A13B);
    if (code >= 95) return const Color(0xFF7C3AED);
    if (code >= 61) return AppColors.info;
    if (code <= 3) return AppColors.textSecondary;
    return AppColors.primaryLight;
  }

  IconData _sugIcon(String key) {
    switch (key) {
      case 'storm':
        return Icons.thunderstorm_rounded;
      case 'rain':
        return Icons.umbrella_rounded;
      case 'humidity':
        return Icons.water_drop_rounded;
      case 'sun':
        return Icons.wb_sunny_rounded;
      case 'dry':
        return Icons.agriculture_rounded;
      case 'wind':
        return Icons.air_rounded;
      case 'plant':
        return Icons.spa_rounded;
      case 'hot':
        return Icons.wb_twilight_rounded;
      default:
        return Icons.tips_and_updates_rounded;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'high':
        return AppColors.expense;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final locs = await fetchWeatherLocations();
    final report = await fetchWeatherReport(location: _location);
    if (!mounted) return;
    setState(() {
      _locations = locs;
      _report = report;
      _loading = false;
      _error = report.isEmpty ? tr('Weather report is not ready yet. Please try again shortly.') : null;
    });
  }

  Future<void> _selectLocation(String key) async {
    if (key == _location) return;
    setState(() => _location = key);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: GradientAppBar(
            title: tr('Weather Report'),
            actions: withFeedbackAction(
              context,
              menu: 'weather',
              actions: [
                IconButton(
                  tooltip: tr('Refresh'),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
          ),
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: _buildBody(),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading && _report.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null && _report.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(onPressed: _load, child: Text(tr('Retry'))),
          ),
        ],
      );
    }

    final current = _report['current'] is Map
        ? Map<String, dynamic>.from(_report['current'] as Map)
        : <String, dynamic>{};
    final days = (_report['days'] is List)
        ? (_report['days'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final insights = (_report['insights'] is List)
        ? (_report['insights'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final suggestions = (_report['suggestions'] is List)
        ? (_report['suggestions'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final locName = _kn
        ? (_report['location_kn']?.toString() ?? _report['location_name']?.toString() ?? '')
        : (_report['location_name']?.toString() ?? '');
    final district = _report['district']?.toString() ?? '';
    final fetched = _when(_report['fetched_at']);
    final code = _num(current['weather_code']).round();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _locationChips(),
        const SizedBox(height: 12),
        if (insights.isNotEmpty) ...[
          Text(tr('Weather insights'), style: AppText.h3),
          const SizedBox(height: 8),
          ...insights.map(_suggestionCard),
          const SizedBox(height: 16),
        ],
        if (suggestions.isNotEmpty) ...[
          Text(tr('Farm advice for the next week'), style: AppText.h3),
          const SizedBox(height: 8),
          ...suggestions.map(_suggestionCard),
          const SizedBox(height: 16),
        ],
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _codeColor(code).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_codeIcon(code), color: _codeColor(code), size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locName,
                          style: AppText.h3,
                        ),
                        Text(
                          district,
                          style: AppText.small,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _deg(current['temp_c']),
                    style: AppText.h1.copyWith(height: 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _pick(current, 'condition_en', 'condition_kn'),
                style: AppText.bodyStrong,
              ),
              if (fetched.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${tr('Updated')} $fetched',
                    style: AppText.small,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(Icons.water_drop_outlined, tr('Humidity'), '${_num(current['humidity']).round()}%'),
                  _stat(Icons.umbrella_outlined, tr('Rain'), _mm(current['rain_mm'])),
                  _stat(Icons.air_rounded, tr('Wind'), '${_num(current['wind_kmh']).round()} km/h'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat(Icons.thermostat_rounded, tr('Feels like'), _deg(current['feels_like_c'])),
                  _stat(Icons.unfold_more_rounded, tr('Min / Max'), '${_deg(current['min_c'])} / ${_deg(current['max_c'])}'),
                  _stat(Icons.wb_sunny_outlined, tr('UV'), _num(current['uv_index']).toStringAsFixed(0)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat(Icons.cloud_outlined, tr('Cloud'), '${_num(current['cloud_cover_pct']).round()}%'),
                  _stat(Icons.explore_outlined, tr('Wind dir'), current['wind_direction']?.toString() ?? '—'),
                  _stat(Icons.grain_rounded, tr('Rain chance'), '${_num(current['rain_probability_pct']).round()}%'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(tr('7-day forecast'), style: AppText.h3),
        const SizedBox(height: 8),
        if (days.isEmpty)
          AppCard(
            child: Text(tr('No forecast yet'), style: AppText.body),
          )
        else
          ...days.map(_dayCard),
        const SizedBox(height: 10),
        Text(
          tr('Report is refreshed automatically every 8 hours.'),
          style: AppText.small,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _locationChips() {
    final items = _locations.isNotEmpty
        ? _locations
        : [
            {'key': 'sirsi', 'name': 'Sirsi', 'name_kn': 'ಸಿರ್ಸಿ'},
            {'key': 'siddapur', 'name': 'Siddapur', 'name_kn': 'ಸಿದ್ದಾಪುರ'},
            {'key': 'yellapur', 'name': 'Yellapur', 'name_kn': 'ಯಲ್ಲಾಪುರ'},
          ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final key = item['key']?.toString() ?? '';
          final selected = key == _location;
          final label = _kn
              ? (item['name_kn']?.toString() ?? item['name']?.toString() ?? key)
              : (item['name']?.toString() ?? key);
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => _selectLocation(key),
            selectedColor: AppColors.primarySoft,
            labelStyle: TextStyle(
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            side: BorderSide(
              color: selected ? AppColors.primaryLight : AppColors.border,
            ),
            backgroundColor: AppColors.surface,
          );
        },
      ),
    );
  }

  Widget _suggestionCard(Map<String, dynamic> s) {
    final color = _priorityColor(s['priority']?.toString() ?? 'info');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_sugIcon(s['icon']?.toString() ?? ''), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pick(s, 'title_en', 'title_kn'),
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _pick(s, 'body_en', 'body_kn'),
                    style: AppText.small.copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value, style: AppText.bodyStrong.copyWith(fontSize: 13)),
          Text(label, style: AppText.small),
        ],
      ),
    );
  }

  Widget _dayCard(Map<String, dynamic> d) {
    final code = _num(d['weather_code']).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(_codeIcon(code), color: _codeColor(code), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dayLabel(d), style: AppText.bodyStrong.copyWith(fontSize: 14)),
                  Text(
                    _pick(d, 'condition_en', 'condition_kn'),
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_deg(d['temp_max'])} / ${_deg(d['temp_min'])}',
                  style: AppText.bodyStrong.copyWith(fontSize: 14),
                ),
                Text(
                  '${tr('Rain')} ${_mm(d['rain_mm'])}',
                  style: AppText.small,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
