import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/alertas/alertas_cuidador.dart';
import '../../core/alertas/control_alerta.dart';
import '../../core/fondo/fondo.dart';
import '../../core/notificaciones/notificaciones.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formato.dart';
import '../../core/vinculos/vinculos.dart';
import '../alert/fall_alert_page.dart';
import '../auth/bloqueo_page.dart';
import '../cuidador/alerta_entrante_page.dart';
import '../cuidador/persona_detalle_page.dart';

/// Une lo que pasa (alertas, notificaciones, novedades) con las pantallas.
/// Envuelve toda la app una sola vez, así las alertas se abren sobre cualquier
/// pantalla, incluso la de la huella.
class Coordinador extends StatefulWidget {
  const Coordinador({super.key, required this.navegador, required this.child});

  final GlobalKey<NavigatorState> navegador;
  final Widget child;

  @override
  State<Coordinador> createState() => _CoordinadorState();
}

class _CoordinadorState extends State<Coordinador> {
  late final AppLifecycleListener _ciclo;
  final List<StreamSubscription<Object?>> _subs = [];
  late final ControlAlerta? _control = context.read<ControlAlerta?>();
  late final Notificaciones? _notificaciones = context.read<Notificaciones?>();
  late final ServicioFondo? _fondo = context.read<ServicioFondo?>();

  Route<void>? _rutaCaida;

  /// Personas con la pantalla de alerta ya abierta: no se abre dos veces.
  final Set<String> _alertasAbiertas = {};

  /// La pantalla se cerró del todo (la quitaron de las recientes) pero Rondó
  /// siguió pendiente: al volver se pide otra vez la huella (RF-02).
  bool _pedirHuella = false;
  bool _avisoEnPantalla = false;

  bool get _aLaVista => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onDetach: () => _pedirHuella = true,
      onResume: _alVolver,
      onHide: _mostrarCaidaSiHaceFalta,
    );
    _control?.addListener(_alCambiarCaida);
    final cuidador = context.read<AlertasCuidador?>();
    if (cuidador != null) _subs.add(cuidador.abrir.listen(_abrirAlerta));
    final vinculos = context.read<Vinculos?>();
    if (vinculos != null) _subs.add(vinculos.novedades.listen(_alHaberNovedad));
    final notificaciones = _notificaciones;
    if (notificaciones != null) {
      _subs.add(notificaciones.respuestas.listen(_alResponder));
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Los avisos de toma los recoge Recordatorios.
        final abierta = await notificaciones.abiertaDesde();
        if (mounted && abierta != null) _alResponder(abierta);
      });
    }
  }

  @override
  void dispose() {
    _ciclo.dispose();
    _control?.removeListener(_alCambiarCaida);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ---------- Persona: su alerta ----------

  void _alCambiarCaida() {
    final control = _control!;
    if (control.activa && _rutaCaida == null) {
      _rutaCaida = MaterialPageRoute<void>(
        fullscreenDialog: true, // Entra desde abajo, como una alerta
        builder: (_) => const FallAlertPage(),
      );
      widget.navegador.currentState?.push(_rutaCaida!);
    } else if (!control.activa && _rutaCaida != null) {
      final ruta = _rutaCaida!;
      _rutaCaida = null;
      final navegador = widget.navegador.currentState;
      if (ruta.isCurrent) {
        navegador?.pop();
      } else if (ruta.isActive) {
        navegador?.removeRoute(ruta);
      }
    }

    _mostrarCaidaSiHaceFalta();
    if (control.fase != FaseAlerta.contando && _avisoEnPantalla) {
      _avisoEnPantalla = false;
      _notificaciones?.quitarCaida();
      if (!control.activa) _fondo?.sobreBloqueo(false).ignore();
    } else if (!control.activa) {
      _fondo?.sobreBloqueo(false).ignore();
    }
  }

  /// La alerta corre con la app fuera de la vista: notificación a pantalla
  /// completa, que también prende la pantalla del celular.
  void _mostrarCaidaSiHaceFalta() {
    final control = _control;
    if (control == null || control.fase != FaseAlerta.contando || _aLaVista || _avisoEnPantalla) return;
    _avisoEnPantalla = true;
    unawaited(() async {
      await _fondo?.sobreBloqueo(true).catchError((Object _) {});
      final nombres = listaNatural([for (final k in control.contactos) primerNombre(k.nombre)]);
      await _notificaciones?.caida(
        cuerpo: 'Posible caída. Si no respondes, avisamos a ${nombres.isEmpty ? 'tus contactos' : nombres}.',
      );
    }());
  }

  // ---------- Cuidador ----------

  Future<void> _abrirAlerta(String personaId) async {
    final navegador = widget.navegador.currentState;
    if (navegador == null || !_alertasAbiertas.add(personaId)) return;
    if (!_aLaVista) _fondo?.sobreBloqueo(true).ignore();
    await navegador.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AlertaEntrantePage(personaId: personaId),
      ),
    );
    _alertasAbiertas.remove(personaId);
    if (_alertasAbiertas.isEmpty && !(_control?.activa ?? false)) _fondo?.sobreBloqueo(false).ignore();
  }

  void _alHaberNovedad(Novedad novedad) {
    if (_aLaVista) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(novedad.mensaje)));
    } else {
      _notificaciones?.novedad(
        personaId: novedad.personaId,
        titulo: novedad.nombre,
        cuerpo: novedad.mensaje,
      );
    }
  }

  // ---------- Notificaciones tocadas ----------

  void _alResponder(RespuestaNotificacion r) {
    final control = _control;
    if (r.destino == RespuestaNotificacion.caida) {
      if (r.accion == RespuestaNotificacion.accionEstoyBien) control?.estoyBien();
      if (r.accion == RespuestaNotificacion.accionPedirAyuda) control?.pedirAyuda();
      return;
    }
    final id = r.personaId;
    if (id == null || context.read<AppState>().personaACargo(id) == null) return;
    if (r.destino.startsWith(RespuestaNotificacion.alerta)) {
      _abrirAlerta(id);
    } else {
      widget.navegador.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => PersonaDetallePage(personaId: id)),
      );
    }
  }

  // ---------- Volver a la app ----------

  void _alVolver() {
    context.read<ControlFondo?>()?.asegurar();
    final estado = context.read<AppState>();
    final hayAlerta = (_control?.activa ?? false) || _alertasAbiertas.isNotEmpty;
    final pedir = _pedirHuella && estado.huellaActivada && estado.registroCompleto && !hayAlerta;
    _pedirHuella = false;
    if (!pedir) return;
    widget.navegador.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const BloqueoPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
