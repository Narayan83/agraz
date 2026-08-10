import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'http_setup.dart';
import 'login.dart';
import 'registration.dart';
import 'income_expense.dart';
import 'category_create.dart';
import 'subcategory_create.dart';
import 'services.dart';
import 'mainpage.dart';
import 'app_splash.dart';
import 'theme_controller.dart';
import 'reset_password_page.dart';
import 'app_theme.dart';
import 'l10n/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Emulator DNS often cannot resolve agrazllp.com even when the PC browser works.
  setupAgrazHttpOverrides();
  await ThemeController.instance.load();
  await LocaleController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        LocaleController.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AgRaz',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.themeMode,
          locale: LocaleController.instance.locale,
          supportedLocales: LocaleController.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppSplashPage(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/registration': (context) => const RegistrationPage(),
            '/main': (context) => const MainPage(),
            '/receipt_payment': (context) => const IncomeExpensePage(),
            '/category_create': (context) => const CategoryManagementPage(),
            '/subcategory_create': (context) =>
                const SubcategoryManagementPage(),
            '/services': (context) => const ServiceListingPage(),
            '/reset-password': (context) => const ResetPasswordPage(),
          },
        );
      },
    );
  }
}
