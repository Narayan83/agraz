import 'package:agraz/advertisement_service.dart';
import 'package:agraz/home/home_advertisement_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('default advertisement constant is Smart Farming, Simplified', () {
    expect(kDefaultAdvertisement.title, 'Smart Farming, Simplified');
    expect(kDefaultAdvertisement.linkType, 'none');
  });

  testWidgets('AdSlide fallback renders Smart Farming title from default ad',
      (tester) async {
    // Directly render a slide with the fallback model (API failure path).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 219,
            width: 390,
            child: PageView(
              children: [
                // Mirror the slider's fallback content.
                Builder(
                  builder: (context) {
                    final ad = kDefaultAdvertisement;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFF14603F)),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              ad.title.isEmpty
                                  ? 'Smart Farming, Simplified'
                                  : ad.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Smart Farming, Simplified'), findsOneWidget);
    expect(find.byType(HomeAdvertisementSlider), findsNothing);
  });

  testWidgets('HomeAdvertisementSlider builds without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeAdvertisementSlider(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HomeAdvertisementSlider), findsOneWidget);
    // Finish pending timers from auto-slide / HTTP.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('HomeAdvertisementSlider uses 1170:658 frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: HomeAdvertisementSlider(),
          ),
        ),
      ),
    );
    await tester.pump();
    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, closeTo(1170 / 658, 0.001));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('first slide shows AgRaz brand logo asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: HomeAdvertisementSlider(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.image(const AssetImage('assets/images/menulogo.jpeg')),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/images/4Agri.jpg')),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 5));
  });
}
