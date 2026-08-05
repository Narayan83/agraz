import 'package:flutter/material.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final ThemeData _light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.green,
  );

  static final ThemeData _dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.green,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AgRaz',
          theme: _light,
          darkTheme: _dark,
          themeMode: ThemeController.instance.themeMode,
          home: const AppSplashPage(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/registration': (context) => const RegistrationPage(),
            '/main': (context) => const MainPage(),
            '/receipt_payment': (context) => const IncomeExpensePage(),
            '/category_create': (context) => const CategoryManagementPage(),
            '/subcategory_create': (context) => const SubcategoryManagementPage(),
            '/services': (context) => const ServiceListingPage(),
            '/reset-password': (context) => const ResetPasswordPage(),
          },
        );
      },
    );
  }
}
