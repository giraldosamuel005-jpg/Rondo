import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'permisos_sistema.dart';

/// RF-32: si la persona quita un permiso desde los ajustes del celular, Rondó
/// no falla en silencio. Al abrir la app y cada vez que vuelve al frente,
/// revisa los permisos que estaban encendidos; si alguno ya no está, apaga
/// su interruptor y avisa que la función queda limitada.
///
/// Va una sola vez, envolviendo toda la app (`MaterialApp.builder`).
class VigilantePermisos extends StatefulWidget {
  const VigilantePermisos({
    super.key,
    required this.child,
    this.permisos = const PermisosSistema(),
  });

  final Widget child;
  final PermisosSistema permisos;

  @override
  State<VigilantePermisos> createState() => _VigilantePermisosState();
}

class _VigilantePermisosState extends State<VigilantePermisos> {
  late final AppLifecycleListener _ciclo;

  /// Evita dos revisiones a la vez si la app va y viene muy rápido.
  bool _revisando = false;

  static const _avisos = {
    PermisoSistema.ubicacion:
        'Desactivaste el permiso de ubicación. Las alertas se enviarán sin tu ubicación. '
        'Actívala de nuevo en ajustes.',
    PermisoSistema.sensores:
        'Desactivaste el permiso de sensores. La detección de caídas funcionará de forma limitada.',
  };

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(onResume: _revisar);
    // Al abrir la app, después del primer cuadro (ya hay ScaffoldMessenger).
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisar());
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  Future<void> _revisar() async {
    if (_revisando) return;
    _revisando = true;
    try {
      final estado = context.read<AppState>();
      for (final permiso in PermisoSistema.values) {
        // Solo importan los que Rondó cree que tiene.
        if (!estado.tienePermiso(permiso)) continue;

        final actual = await widget.permisos.consultar(permiso);
        if (!mounted) return;
        if (actual == EstadoPermiso.concedido) continue;

        estado.permisoRevocadoPorSistema(permiso);
        _avisar(permiso);
      }
    } finally {
      _revisando = false;
    }
  }

  void _avisar(PermisoSistema permiso) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(_avisos[permiso]!),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Abrir ajustes',
          onPressed: widget.permisos.abrirAjustes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
