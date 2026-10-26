import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/widgets/glass_tab_bar.dart';
import '../contacts/contacts_tab.dart';
import '../cuidador/alertas_tab.dart';
import '../cuidador/personas_tab.dart';
import '../history/history_tab.dart';
import '../home/home_page.dart';
import '../settings/settings_tab.dart';

/// Contenedor principal de la app después del registro:
/// las pestañas + la barra de vidrio flotante.
/// - Quien se cuida: Inicio · Contactos · Historial · Ajustes.
/// - Cuidador (RF-26): Personas · Alertas · Ajustes.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  // Posición de cada pestaña en la barra (cuenta "para mí").
  static const inicio = 0;
  static const contactos = 1;
  static const historial = 2;
  static const ajustes = 3;

  // Posición de cada pestaña en la barra (cuenta de cuidador).
  static const personas = 0;
  static const alertas = 1;
  static const ajustesCuidador = 2;

  static const _pestanas = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.people_alt_rounded, 'Contactos'),
    (Icons.history_rounded, 'Historial'),
    (Icons.settings_rounded, 'Ajustes'),
  ];

  static const _pestanasCuidador = [
    (Icons.favorite_rounded, 'Personas'),
    (Icons.notifications_rounded, 'Alertas'),
    (Icons.settings_rounded, 'Ajustes'),
  ];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // La primera pestaña (Inicio o Personas) es la 0 en los dos casos.
  int _actual = 0;

  void _irA(int pestana) => setState(() => _actual = pestana);

  @override
  Widget build(BuildContext context) {
    final esCuidador = context.watch<AppState>().esCuidador;

    final List<Widget> paginas = esCuidador
        ? [
            PersonasTab(onVerAjustes: () => _irA(MainShell.ajustesCuidador)),
            const AlertasTab(),
            const SettingsTab(),
          ]
        : [
            HomePage(
              onVerContactos: () => _irA(MainShell.contactos),
              onVerAjustes: () => _irA(MainShell.ajustes),
            ),
            const ContactsTab(),
            const HistoryTab(),
            const SettingsTab(),
          ];

    // Botón atrás de Android: desde otra pestaña vuelve a la primera;
    // desde la primera sí cierra la app.
    return PopScope(
      canPop: _actual == 0,
      onPopInvokedWithResult: (seCerro, _) {
        if (!seCerro) _irA(0);
      },
      child: Scaffold(
        // El contenido pasa por debajo de la barra (se ve a través del vidrio),
        // y los SnackBar aparecen encima de ella en vez de taparla.
        extendBody: true,
        // IndexedStack muestra solo la pestaña actual, pero mantiene las
        // demás vivas: al volver, conservan su scroll.
        body: IndexedStack(index: _actual, children: paginas),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: GlassTabBar(
              pestanas: esCuidador ? MainShell._pestanasCuidador : MainShell._pestanas,
              actual: _actual,
              onTap: _irA,
            ),
          ),
        ),
      ),
    );
  }
}
