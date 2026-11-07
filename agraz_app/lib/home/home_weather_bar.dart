import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
import '../weather_service.dart';

class HomeWeatherBar extends StatefulWidget {
  const HomeWeatherBar({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<HomeWeatherBar> createState() => _HomeWeatherBarState();
}

class _HomeWeatherBarState extends State<HomeWeatherBar>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  late final AnimationController _ticker;
  String _tickerText = '';

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _load();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  bool get _reduceMotion {
    final mq = MediaQuery.maybeOf(context);
    return mq?.disableAnimations == true ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  Future<void> _load() async {
    final data = await fetchWeatherReport(location: 'sirsi');
    if (!mounted) return;
    final current = (data['current'] is Map)
        ? Map<String, dynamic>.from(data['current'] as Map)
        : <String, dynamic>{};
    final days = (data['days'] is List) ? data['days'] as List : const [];
    Map<String, dynamic> tomorrow = {};
    if (days.length > 1 && days[1] is Map) {
      tomorrow = Map<String, dynamic>.from(days[1] as Map);
    } else if (days.isNotEmpty && days[0] is Map) {
      tomorrow = Map<String, dynamic>.from(days[0] as Map);
    }

    final condition = '${current['condition_en'] ?? current['condition'] ?? 'Cloudy'}';
    final humidity = current['humidity'];
    final wind = current['wind_kmh'];
    final rain = current['rain_probability_pct'] ?? current['rain_mm'];
    final hi = tomorrow['max_c'] ?? current['max_c'];
    final lo = tomorrow['min_c'] ?? current['min_c'];

    final parts = <String>[
      condition,
      if (humidity != null) 'Humidity $humidity%',
      if (wind != null) 'Wind ${wind} km/h',
      if (rain != null) 'Rain chance $rain%',
      if (hi != null && lo != null) 'Tomorrow $hi°/$lo°',
    ];

    setState(() {
      _data = data.isEmpty ? null : data;
      _tickerText = parts.isEmpty
          ? tr('Weather unavailable — tap for report')
          : parts.join('   ·   ');
    });

    if (!_reduceMotion && _tickerText.isNotEmpty) {
      _ticker
        ..duration = Duration(seconds: (_tickerText.length / 4).clamp(12, 28).round())
        ..repeat();
    } else {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = (_data != null && _data!['current'] is Map)
        ? Map<String, dynamic>.from(_data!['current'] as Map)
        : null;
    final temp = current?['temp_c'];

    return Material(
      color: const Color(0xFF14603F),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Text(
                  temp != null ? '${temp}°C' : '--°C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.cloud_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRect(
                    child: _reduceMotion || _tickerText.isEmpty
                        ? Text(
                            _tickerText.isEmpty
                                ? tr('Loading weather…')
                                : _tickerText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 13,
                            ),
                          )
                        : AnimatedBuilder(
                            animation: _ticker,
                            builder: (context, _) {
                              return FractionalTranslation(
                                translation: Offset(1.0 - _ticker.value * 2.0, 0),
                                child: Text(
                                  '$_tickerText    $_tickerText',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
