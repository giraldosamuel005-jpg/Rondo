import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/permisos/vigilante_permisos.dart';
import 'core/persistencia/almacen_local.dart';
import 'core/state/app_state.dart';
import 'core/theme/rondo_theme.dart';
import 'features/auth/login_page.dart';
import 'features/shell/main_shell.dart';

Future<void> main() async {
  // Necesario para leer lo guardado antes de mostrar la app.
  WidgetsFlutterBinding.ensureInitialized();
  final estado = await AppState.cargar(AlmacenLocal());

  runApp(
    // UN solo AppState para todas las pantallas, ya con los datos guardados.
    ChangeNotifierProvider.value(
      value: estado,
      child: RondoApp(registrado: estado.registroCompleto),
    ),
  );
}

class RondoApp extends StatelessWidget {
  const RondoApp({super.key, required this.registrado});

  /// Si ya terminó el registro, la app abre directo en Inicio.
  final bool registrado;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rondó',
      // Textos de Flutter (selector de hora, diálogos...) en español de Colombia.
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false, // Quita la cinta roja "DEBUG"
      theme: RondoTheme.light(),
      darkTheme: RondoTheme.dark(),
      // Automático (según el celular), claro u oscuro: se elige en Ajustes.
      themeMode: context.watch<AppState>().modoTema,
      home: registrado ? const MainShell() : const LoginPage(),
      // Revisa en todas las pantallas si quitaron un permiso (RF-32).
      builder: (context, child) => VigilantePermisos(child: child!),
    );
  }
}
