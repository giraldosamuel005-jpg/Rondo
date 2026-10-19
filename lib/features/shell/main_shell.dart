import 'package:flutter/material.dart';

import '../../core/widgets/glass_tab_bar.dart';
import '../contacts/contacts_tab.dart';
import '../history/history_tab.dart';
import '../home/home_page.dart';
import '../settings/settings_tab.dart';

/// Contenedor principal de la app después del registro:
/// las 4 pestañas + la barra de vidrio flotante.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  // Posición de cada pestaña en la barra.
  static const inicio = 0;
  static const contactos = 1;
  static const historial = 2;
  static const ajustes = 3;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _actual = MainShell.inicio;

  void _irA(int pestana) => setState(() => _actual = pestana);

  @override
  Widget build(BuildContext context) {
    // Botón atrás de Android: desde otra pestaña vuelve a Inicio;
    // desde Inicio sí cierra la app.
    return PopScope(
      canPop: _actual == MainShell.inicio,
      onPopInvokedWithResult: (seCerro, _) {
        if (!seCerro) _irA(MainShell.inicio);
      },
      child: Scaffold(
        // El contenido pasa por debajo de la barra (se ve a través del vidrio),
        // y los SnackBar aparecen encima de ella en vez de taparla.
        extendBody: true,
        // IndexedStack muestra solo la pestaña actual, pero mantiene las
        // demás vivas: al volver, conservan su scroll.
        body: IndexedStack(
          index: _actual,
          children: [
            HomePage(
              onVerContactos: () => _irA(MainShell.contactos),
              onVerAjustes: () => _irA(MainShell.ajustes),
            ),
            const ContactsTab(),
            const HistoryTab(),
            const SettingsTab(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: GlassTabBar(actual: _actual, onTap: _irA),
          ),
        ),
      ),
    );
  }
}
