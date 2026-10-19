import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/permisos/vigilante_permisos.dart';
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
      // Automático (según el celular), claro u oscuro: se elige en Ajustes.
      themeMode: context.watch<AppState>().modoTema,
      home: const LoginPage(),
      // Revisa en todas las pantallas si quitaron un permiso (RF-32).
      builder: (context, child) => VigilantePermisos(child: child!),
    );
  }
}
