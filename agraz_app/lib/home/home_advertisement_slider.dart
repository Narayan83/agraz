import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../advertisement_service.dart';
import '../app_theme.dart';
import '../l10n/app_l10n.dart';

typedef AdLinkHandler = void Function(Advertisement ad);

class HomeAdvertisementSlider extends StatefulWidget {
  const HomeAdvertisementSlider({
    super.key,
    this.onInAppLink,
    /// Tall home slider. Upload creatives at 1170×658 (same ratio) so cover fills with no gaps.
    this.aspectRatio = 1170 / 658,
    this.horizontalPadding = 8,
    this.verticalPadding = 6,
  });

  final AdLinkHandler? onInAppLink;
  final double aspectRatio;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  State<HomeAdvertisementSlider> createState() => HomeAdvertisementSliderState();
}

class HomeAdvertisementSliderState extends State<HomeAdvertisementSlider> {
  final PageController _controller = PageController();
  List<Advertisement> _ads = const [];
  bool _loading = true;
  int _index = 0;
  Timer? _timer;
  bool _paused = false;

  /// Brand garden slide is always first; API ads follow.
  int get _pageCount => 1 + (_ads.isEmpty ? 0 : _ads.length);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _reduceMotion {
    final mq = MediaQuery.maybeOf(context);
    return mq?.disableAnimations == true ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ads = await fetchActiveAdvertisements();
    if (!mounted) return;
    setState(() {
      // Drop the plain green fallback when we already show the brand slide.
      _ads = ads.where((a) => a.id != 0 || a.imageUrl.trim().isNotEmpty).toList();
      _loading = false;
      _index = 0;
    });
    _restartTimer();
    if (_ads.isNotEmpty && _ads.first.id > 0) {
      // Impression for first API ad is recorded when user reaches that page.
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_reduceMotion || _paused || _pageCount < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients || _paused || _reduceMotion) return;
      final next = (_index + 1) % _pageCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _onTap(Advertisement ad) async {
    if (ad.id > 0) unawaited(recordAdvertisementClick(ad.id));
    final type = ad.linkType.trim().toLowerCase();
    final value = (ad.linkValue ?? '').trim();
    if (type == 'external_url' && value.isNotEmpty) {
      final uri = Uri.tryParse(value);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (type == 'in_app_screen' && value.isNotEmpty) {
      widget.onInAppLink?.call(ad);
    }
  }

  Widget _frame({required Widget child}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        widget.verticalPadding,
        widget.horizontalPadding,
        widget.verticalPadding,
      ),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _frame(child: const _AdSkeleton());
    }

    final ads = _ads;
    final pageCount = _pageCount;

    return _frame(
      child: Listener(
        onPointerDown: (_) {
          _paused = true;
          _timer?.cancel();
        },
        onPointerUp: (_) {
          _paused = false;
          _restartTimer();
        },
        onPointerCancel: (_) {
          _paused = false;
          _restartTimer();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: pageCount,
              onPageChanged: (i) {
                setState(() => _index = i);
                if (i > 0 && ads.isNotEmpty) {
                  final ad = ads[i - 1];
                  if (ad.id > 0) {
                    unawaited(recordAdvertisementImpression(ad.id));
                  }
                }
              },
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const _BrandGardenSlide();
                }
                final ad = ads[i - 1];
                return GestureDetector(
                  onTap: () => _onTap(ad),
                  child: _AdSlide(ad: ad),
                );
              },
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(pageCount.clamp(1, 4), (i) {
                  final showCount = pageCount.clamp(1, 4);
                  final activeIndex = pageCount <= 4 ? _index : (_index % 4);
                  final isOn = i == activeIndex && i < showCount;
                  return AnimatedContainer(
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    margin: const EdgeInsets.only(left: 4),
                    width: isOn ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOn
                          ? const Color(0xFFF0A030)
                          : Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First slide: farm/garden photo with a light AgRaz logo overlay.
class _BrandGardenSlide extends StatelessWidget {
  const _BrandGardenSlide();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/4Agri.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.15),
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF14603F)),
        ),
        // Soft light wash so the logo reads cleanly without heavy dark green.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.35),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/menulogo.jpeg',
                height: 52,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdSlide extends StatelessWidget {
  const _AdSlide({required this.ad});
  final Advertisement ad;

  @override
  Widget build(BuildContext context) {
    final hasNet = ad.imageUrl.trim().isNotEmpty;
    // Fill every pixel of the slider — no green letterbox gaps.
    if (hasNet) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: const Color(0xFF14603F),
            alignment: Alignment.center,
            child: Image.network(
              ad.resolvedImageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const _TextOnlyAdFallback(),
            ),
          );
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/4Agri.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF14603F)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.08),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 44, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                ad.title.trim().isEmpty
                    ? tr('Smart Farming, Simplified')
                    : ad.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                (ad.subtitle ?? '').trim().isEmpty
                    ? tr('Agriculture ERP for modern farms')
                    : ad.subtitle!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextOnlyAdFallback extends StatelessWidget {
  const _TextOnlyAdFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF14603F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            tr('Smart Farming, Simplified'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdSkeleton extends StatelessWidget {
  const _AdSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: Container(
        width: 160,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
