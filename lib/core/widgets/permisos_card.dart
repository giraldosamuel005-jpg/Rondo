import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../permisos/permisos_sistema.dart';
import '../state/app_state.dart';
import 'error_banner.dart';
import 'glass.dart';
import 'permission_row.dart';

/// Interruptores de ubicación, sensores y SMS (RF-30), usados en el registro y en
/// Ajustes. Al encenderlos se pide el permiso real del sistema; si la persona
/// dice que no, el error se muestra aquí mismo, debajo de la tarjeta.
class PermisosCard extends StatefulWidget {
  const PermisosCard({
    super.key,
    this.permisos = const PermisosSistema(),
    this.mostrar = const {...PermisoSistema.values},
  });

  final PermisosSistema permisos;

  /// Cuáles se muestran (el cuidador solo usa notificaciones).
  final Set<PermisoSistema> mostrar;

  @override
  State<PermisosCard> createState() => _PermisosCardState();
}

class _PermisosCardState extends State<PermisosCard> {
  /// El último permiso que no se pudo activar, y por qué.
  ({PermisoSistema permiso, EstadoPermiso estado})? _error;

  /// Evita abrir dos ventanas del sistema con dos toques seguidos.
  bool _pidiendo = false;

  static const _titulos = {
    PermisoSistema.ubicacion: 'Ubicación',
    PermisoSistema.sensores: 'Sensores de movimiento',
    PermisoSistema.sms: 'Enviar SMS',
    PermisoSistema.notificaciones: 'Notificaciones',
  };

  /// Para qué se usa cada uno (RF-30).
  static const _razones = {
    PermisoSistema.ubicacion: 'Se envía en una alerta, y a tus cuidadores solo si tú lo activas.',
    PermisoSistema.sensores: 'Detectan la caída en el teléfono.',
    PermisoSistema.sms: 'Solo para avisar a tus contactos en una alerta.',
    PermisoSistema.notificaciones: 'Para avisarte aunque tengas la app cerrada.',
  };

  static const _mensajes = {
    PermisoSistema.ubicacion: 'Necesitamos tu permiso de ubicación para enviar alertas con tu posición.',
    PermisoSistema.sensores: 'Activa el permiso de sensores de movimiento para usar la detección de caídas.',
    PermisoSistema.sms: 'La app no tiene permiso para enviar SMS. Actívalo en ajustes.',
    PermisoSistema.notificaciones: 'Sin notificaciones no te podemos avisar con la app cerrada.',
  };

  void _guardar(PermisoSistema permiso, bool valor) =>
      context.read<AppState>().cambiarPermiso(permiso, valor);

  Future<void> _cambiar(PermisoSistema permiso, bool encender) async {
    // Apagar no le quita el permiso a Android (eso solo lo hace la persona en
    // los ajustes del celular); Rondó simplemente deja de usarlo.
    if (!encender && permiso == PermisoSistema.notificaciones) {
      // Las notificaciones sí son del sistema: solo se apagan allá.
      await widget.permisos.abrirAjustes();
      return;
    }
    if (!encender) {
      _guardar(permiso, false);
      if (_error?.permiso == permiso) setState(() => _error = null);
      return;
    }

    if (_pidiendo) return;
    _pidiendo = true;
    final respuesta = await widget.permisos.pedir(permiso);
    _pidiendo = false;
    if (!mounted) return;

    final concedido = respuesta == EstadoPermiso.concedido;
    _guardar(permiso, concedido);
    setState(() => _error = concedido ? null : (permiso: permiso, estado: respuesta));
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<AppState>();
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, permiso) in PermisoSistema.values.where(widget.mostrar.contains).indexed) ...[
                if (i > 0) const GlassDivider(indent: 18),
                PermissionRow(
                  title: _titulos[permiso]!,
                  reason: _razones[permiso]!,
                  value: estado.tienePermiso(permiso),
                  onChanged: (v) => _cambiar(permiso, v),
                ),
              ],
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(
            title: _mensajes[error.permiso]!,
            message: error.estado == EstadoPermiso.bloqueado
                ? 'Sin este permiso no podemos activar esta función. Actívalo en los ajustes del celular.'
                : 'Toca el interruptor para intentarlo otra vez.',
          ),
          if (error.estado == EstadoPermiso.bloqueado)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.permisos.abrirAjustes,
                icon: const Icon(Icons.settings_outlined, size: 20),
                label: const Text('Abrir ajustes'),
              ),
            ),
        ],
      ],
    );
  }
}
