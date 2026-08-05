import 'package:flutter/material.dart';
import 'login.dart'; // Contains LoginScreen
import 'registration.dart';
import 'income_expense.dart';
import 'category_create.dart';
import 'subcategory_create.dart';
import 'services.dart';
import 'mainpage.dart';
import 'app_splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgRaz',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const AppSplashPage(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const RegistrationPage(),
        '/main': (context) => const MainPage(),
        '/receipt_payment': (context) => const IncomeExpensePage(),
        '/category_create': (context) => const CategoryManagementPage(),
        '/subcategory_create': (context) => const SubcategoryManagementPage(),
        '/services': (context) => const ServiceListingPage(),
      },
    );
  }
}
