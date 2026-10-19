import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/state/app_state.dart';
import 'core/theme/rondo_theme.dart';
import 'features/auth/login_page.dart';

void main() {
  runApp(
    // Crea UN solo AppState y lo pone a disposición de todas las pantallas.
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const RondoApp(),
    ),
  );
}

class RondoApp extends StatelessWidget {
  const RondoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rondó',
      debugShowCheckedModeBanner: false, // Quita la cinta roja "DEBUG"
      theme: RondoTheme.light(),
      darkTheme: RondoTheme.dark(),
      themeMode: ThemeMode.system, // Claro u oscuro según el celular
      home: const LoginPage(),
    );
  }
}
