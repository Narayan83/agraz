import 'package:agraz/mainpage.dart';
import 'package:flutter/material.dart';
import 'login.dart'; // Contains LoginScreen
import 'registration.dart';
import 'income_expense.dart';
import 'category_create.dart';
import 'subcategory_create.dart';
import 'services.dart';
import 'service_register.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Auth',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Open main page without requiring login first
      initialRoute: '/main',
      // Define all your routes
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const RegistrationPage(),
        '/main': (context) => const MainPage(),
        '/receipt_payment':
            (context) =>
                const IncomeExpensePage(), // Assuming you have MainPage
        '/category_create':
            (context) =>
                const CategoryManagementPage(), // Assuming you have MainPage
        '/subcategory_create':
            (context) =>
                const SubcategoryManagementPage(), // Assuming you have MainPage
        '/services':
            (context) => ServiceListingPage(), // Assuming you have MainPage
        '/service_register':
            (context) => ServiceRegisterPage(), // Assuming you have MainPage
      },
    );
  }
}
