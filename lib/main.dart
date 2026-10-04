import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

import 'screens/login_screen.dart';


void main() {
  runApp(const RondoApp());
}

class RondoApp extends StatelessWidget {
  const RondoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rondó',
      debugShowCheckedModeBanner: false, // Quita la cinta roja "DEBUG"
      theme: AppTheme.light, // ← aquí se aplica el tema a toda la app
      home: const LoginScreen(),

    );
  }
}
