import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/tipo_cuenta.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/permission_row.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/tab_page.dart';
import '../alert/fall_alert_page.dart';
import '../auth/login_page.dart';

/// Pestaña Ajustes: perfil, apariencia, permisos (RF-31), aviso del 123 (RF-34)
/// y cerrar sesión.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final estado = context.read<AppState>();
    final navegador = Navigator.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a entrar con tu celular y un código.'),
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

  /// Abre la alerta de caída sin sensores, para probarla y para la demo.
  void _simularCaida(BuildContext context) {
    if (context.read<AppState>().rondaEnPausa) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu ronda está en pausa. Reanúdala para probar la alerta.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true, // Entra desde abajo, como una alerta
        builder: (_) => FallAlertPage(detectadaA: DateTime.now()),
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
                      style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      estado.tipo == TipoCuenta.cuidador ? 'Cuido a alguien' : 'Me cuido a mí',
                      style: t.labelLarge!.copyWith(color: c.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ---------- Apariencia ----------
        const SectionLabel('Apariencia'),
        Glass(
          padding: const EdgeInsets.all(6),
          child: _SelectorTema(
            actual: estado.modoTema,
            onChanged: estado.cambiarModoTema,
          ),
        ),
        const SizedBox(height: 22),

        // ---------- Permisos (RF-31) ----------
        const SectionLabel('Permisos'),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PermissionRow(
                title: 'Ubicación siempre',
                reason: 'Solo se envía dentro de una alerta.',
                value: estado.permisoUbicacion,
                onChanged: estado.cambiarPermisoUbicacion,
              ),
              const GlassDivider(indent: 18),
              PermissionRow(
                title: 'Sensores de movimiento',
                reason: 'Detectan la caída en el teléfono.',
                value: estado.permisoSensores,
                onChanged: estado.cambiarPermisoSensores,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

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
                      style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'En una emergencia, llama al 123.',
                      style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
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
        if (kDebugMode) ...[
          const SizedBox(height: 22),
          const SectionLabel('Modo de pruebas'),
          SecondaryButton(
            label: 'Simular caída',
            icon: Icons.warning_amber_rounded,
            blur: false,
            onPressed: () => _simularCaida(context),
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
                        Icon(icono, size: 22, color: modo == actual ? c.accentLink : c.textSecondary),
                        const SizedBox(height: 4),
                        Text(
                          etiqueta,
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                fontWeight: modo == actual ? FontWeight.w700 : FontWeight.w500,
                                color: modo == actual ? c.accentLink : c.textSecondary,
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
