import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/alertas/control_alerta.dart';
import '../../core/models/persona_a_cargo.dart';
import '../../core/permisos/permisos_sistema.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/check_card.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/permisos_card.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/tab_page.dart';
import '../auth/login_page.dart';
import '../cuidador/alerta_entrante_page.dart';
import '../ficha/ficha_medica_card.dart';
import 'huella.dart';

/// Pestaña Ajustes: perfil, ficha médica (RF-23), apariencia, permisos (RF-31),
/// aviso del 123 (RF-34) y cerrar sesión.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final estado = context.read<AppState>();
    final navegador = Navigator.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a entrar con tu celular y un código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    // Primero se vuelve a Entrar y luego se borran los datos, para que las
    // pestañas no alcancen a dibujarse vacías.
    navegador.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (ruta) => false,
    );
    estado.cerrarSesion();
  }

  /// Prueba la alerta de principio a fin, sin sensores: a los contactos les
  /// llega de verdad, pero diciendo que es una prueba.
  Future<void> _probarAlerta(BuildContext context) async {
    final control = context.read<ControlAlerta>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Probar la alerta?'),
        content: const Text(
          'Verás la cuenta regresiva como en una caída. Si la dejas terminar, a tus '
          'contactos y cuidadores les llega un mensaje que dice que es una prueba.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Probar'),
          ),
        ],
      ),
    );
    if (confirmar == true) control.iniciar(prueba: true);
  }

  /// Cuidador: a una persona DE EJEMPLO "se le detecta una caída". Nunca a una
  /// real: la alerta sería inventada.
  void _simularAlertaDePersona(BuildContext context) {
    final estado = context.read<AppState>();
    bool esEjemplo(PersonaACargo p) =>
        p.id.startsWith(PersonaACargo.prefijoEjemplo);
    if (!estado.personasACargo.any(esEjemplo)) estado.cargarPersonasDeEjemplo();
    final persona = estado.personasACargo.firstWhere(esEjemplo);
    estado.simularAlertaDe(persona.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AlertaEntrantePage(personaId: persona.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>();

    return TabPage(
      title: 'Ajustes',
      blobs: BlobBackground.entrar,
      children: [
        // ---------- Perfil ----------
        Glass(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              RondoAvatar(iniciales: inicialesDe(estado.nombre), size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(estado.nombre, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      formatearCelular(estado.celular ?? ''),
                      style: t.labelLarge!.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      estado.esCuidador ? 'Cuido a alguien' : 'Me cuido a mí',
                      style: t.labelLarge!.copyWith(color: c.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ---------- Salud (RF-23): solo quien se cuida a sí mismo ----------
        if (estado.usaFichaMedica) ...[
          const SectionLabel('Salud'),
          const FichaMedicaCard(),
          const SizedBox(height: 22),
        ],

        // ---------- Apariencia ----------
        const SectionLabel('Apariencia'),
        Glass(
          padding: const EdgeInsets.all(6),
          child: _SelectorTema(
            actual: estado.modoTema,
            onChanged: estado.cambiarModoTema,
          ),
        ),
        const SizedBox(height: 12),
        CheckCard(
          title: 'Vidrio reducido',
          detail: 'Quita el desenfoque de las tarjetas. Ayuda si el celular va lento o gasta mucha batería.',
          value: estado.vidrioReducido,
          onChanged: (valor) {
            RondoPerf.reducir.value = valor;
            estado.cambiarVidrioReducido(valor);
          },
        ),
        const SizedBox(height: 22),

        // ---------- Seguridad (RF-02): reingresar con la huella ----------
        const SectionLabel('Seguridad'),
        CheckCard(
          title: 'Entrar con huella',
          detail: 'Al abrir Rondó te pedimos tu huella en vez de un código. Si no funciona, entras con tu código SMS.',
          value: estado.huellaActivada,
          onChanged: (valor) {
            if (valor) {
              activarHuella(context);
            } else {
              estado.cambiarHuellaActivada(false);
            }
          },
        ),
        const SizedBox(height: 22),

        // ---------- Permisos (RF-31): el cuidador no usa sensores ----------
        const SectionLabel('Permisos'),
        estado.esCuidador
            ? const PermisosCard(mostrar: {PermisoSistema.notificaciones})
            : const PermisosCard(),
        const SizedBox(height: 22),

        // ---------- Probar la alerta ----------
        if (!estado.esCuidador) ...[
          const SectionLabel('Alerta'),
          SecondaryButton(
            label: 'Probar la alerta',
            icon: Icons.notifications_active_rounded,
            blur: false,
            onPressed: () => _probarAlerta(context),
          ),
          const SizedBox(height: 22),
        ],

        // ---------- Aviso (RF-34) ----------
        const SectionLabel('Importante'),
        Glass(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_hospital_outlined, size: 22, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rondó no reemplaza los servicios de emergencia oficiales.',
                      style: t.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'En una emergencia, llama al 123.',
                      style: t.labelLarge!.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ---------- Cerrar sesión ----------
        SecondaryButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onPressed: () => _cerrarSesion(context),
        ),

        // ---------- Solo en desarrollo ----------
        if (kDebugMode && estado.esCuidador) ...[
          const SizedBox(height: 22),
          const SectionLabel('Modo de pruebas'),
          SecondaryButton(
            label: 'Cargar personas de ejemplo',
            icon: Icons.group_add_rounded,
            blur: false,
            onPressed: estado.cargarPersonasDeEjemplo,
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Simular alerta',
            icon: Icons.warning_amber_rounded,
            blur: false,
            onPressed: () => _simularAlertaDePersona(context),
          ),
          const SizedBox(height: 6),
          Text(
            'Solo aparece mientras desarrollamos la app.',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Tres opciones en fila: Automático · Claro · Oscuro.
class _SelectorTema extends StatelessWidget {
  const _SelectorTema({required this.actual, required this.onChanged});

  final ThemeMode actual;
  final ValueChanged<ThemeMode> onChanged;

  static const _opciones = [
    (ThemeMode.system, Icons.brightness_auto_rounded, 'Automático'),
    (ThemeMode.light, Icons.light_mode_rounded, 'Claro'),
    (ThemeMode.dark, Icons.dark_mode_rounded, 'Oscuro'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Row(
      children: [
        for (final (modo, icono, etiqueta) in _opciones)
          Expanded(
            child: Semantics(
              selected: modo == actual,
              inMutuallyExclusiveGroup: true,
              button: true,
              label: etiqueta,
              excludeSemantics: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onChanged(modo),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 64,
                    decoration: BoxDecoration(
                      color: modo == actual ? c.accentSoft : null,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icono,
                          size: 22,
                          color: modo == actual
                              ? c.accentLink
                              : c.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          etiqueta,
                          style: Theme.of(context).textTheme.labelLarge!
                              .copyWith(
                                fontWeight: modo == actual
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: modo == actual
                                    ? c.accentLink
                                    : c.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
