import 'package:flutter/material.dart';
import 'bottom_navigation.dart';
import 'login_screen.dart';

void main() {
  runApp(ReCodeApp());
}

class ReCodeApp extends StatelessWidget {
  const ReCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReCode',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          bodyLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),

        colorScheme: ColorScheme.light(
          primary: Colors.blue, // Primary color for apps
          secondary: Colors.blueAccent, // Secondary color
          surface: Colors.white, // Background color
          onPrimary: Colors.white, // Text color on primary
          error: Colors.red, // Explicit error color
        ),
        
      ),
      home: LoginScreen(),
    );
  }
}
