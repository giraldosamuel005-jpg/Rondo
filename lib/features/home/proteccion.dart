import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/alertas/control_alerta.dart';
import '../../core/permisos/permisos_sistema.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/vinculos/vinculos.dart';
import '../../core/widgets/alert_button.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/secondary_button.dart';

/// Botón "Pedir ayuda" de Inicio: avisa a los contactos sin esperar a que los
/// sensores detecten nada. Pregunta antes, por si fue un toque sin querer.
class BotonPedirAyuda extends StatelessWidget {
  const BotonPedirAyuda({super.key});

  Future<void> _pedir(BuildContext context) async {
    final control = context.read<ControlAlerta>();
    final contactos = context.read<AppState>().contactos;
    final nombres = listaNatural([for (final k in contactos) primerNombre(k.nombre)]);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Pedir ayuda?'),
        content: Text('Le avisamos ya a ${nombres.isEmpty ? 'tus contactos' : nombres}, con tu ubicación.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, pedir ayuda'),
          ),
        ],
      ),
    );
    if (confirmar == true) control.pedirAyuda();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Pedir ayuda',
        excludeSemantics: true,
        child: AlertButton(
          label: 'Pedir ayuda',
          icon: Icons.sos_rounded,
          onPressed: () => _pedir(context),
        ),
      );
}

/// Hay una alerta que salió y sigue abierta: se puede cerrar desde Inicio.
class AlertaAbierta extends StatelessWidget {
  const AlertaAbierta({super.key, required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    return Glass(
      blur: false,
      fill: c.alert.withValues(alpha: 0.14),
      borderColor: c.alert,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enviaste una alerta', style: t.titleMedium!.copyWith(color: c.alertText)),
          const SizedBox(height: 4),
          Text(
            '${diaRelativo(fecha)}, ${horaCorta(fecha)} Si ya estás bien, avísales para que se tranquilicen.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Ya estoy bien, avísales',
            icon: Icons.favorite_rounded,
            blur: false,
            onPressed: () {
              context.read<ControlAlerta>().yaEstoyBien();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Qué bueno que estás bien. Les avisamos.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// RF-32: lo que hoy haría que una alerta no llegue bien, dicho ANTES de que
/// haga falta. Si todo está en orden, no muestra nada.
class AvisosProteccion extends StatelessWidget {
  const AvisosProteccion({super.key, required this.onVerAjustes, required this.onVerContactos});

  final VoidCallback onVerAjustes;
  final VoidCallback onVerContactos;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>();
    final vinculos = context.watch<Vinculos?>();
    final sinCuidadores = vinculos != null && vinculos.cuidadoresCargados && vinculos.cuidadoresActivos.isEmpty;
    final faltaSms = !estado.tienePermiso(PermisoSistema.sms);

    final avisos = <(String, VoidCallback)>[
      if (faltaSms && sinCuidadores)
        ('Hoy nadie recibiría tu alerta. Activa el permiso de SMS.', onVerAjustes)
      else if (faltaSms)
        ('Tus contactos no recibirían el SMS de alerta. Activa el permiso.', onVerAjustes),
      if (!estado.tienePermiso(PermisoSistema.ubicacion))
        ('Tu alerta saldría sin tu ubicación. Activa el permiso.', onVerAjustes),
      if (!estado.tienePermiso(PermisoSistema.notificaciones))
        ('Sin notificaciones no te podemos avisar con la app cerrada.', onVerAjustes),
      if (sinCuidadores) ('Nadie te cuida todavía en Rondó. Invita a un contacto.', onVerContactos),
    ];
    // Sin servidor (web, Windows, pruebas) no hay nada que activar.
    if (vinculos == null || avisos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Glass(
        blur: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Text('Para estar mejor protegido', style: t.titleMedium),
            ),
            for (final (texto, alTocar) in avisos)
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: alTocar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 20, color: c.errorText),
                        const SizedBox(width: 10),
                        Expanded(child: Text(texto, style: t.bodyMedium!.copyWith(color: c.text))),
                        Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
