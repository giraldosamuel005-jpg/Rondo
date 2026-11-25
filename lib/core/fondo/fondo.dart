import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/persona_a_cargo.dart';
import '../permisos/permisos_sistema.dart';
import '../state/app_state.dart';
import '../utils/formato.dart';

/// Lo que se le pide al celular para seguir pendiente con la app cerrada.
abstract interface class ServicioFondo {
  /// Enciende (o actualiza) el servicio en primer plano.
  /// [ubicacion]: va a leer el GPS. [despierto]: lee sensores con la pantalla
  /// apagada.
  Future<void> iniciar({
    required String titulo,
    required String texto,
    required bool ubicacion,
    required bool despierto,
  });

  Future<void> detener();

  /// La pantalla se ve aunque el celular esté bloqueado (solo en una alerta).
  Future<void> sobreBloqueo(bool valor);
}

/// Con el canal `rondo/fondo` (CanalFondo.kt, ServicioFondo.kt).
class ServicioFondoAndroid implements ServicioFondo {
  const ServicioFondoAndroid();

  static const _canal = MethodChannel('rondo/fondo');

  @override
  Future<void> iniciar({
    required String titulo,
    required String texto,
    required bool ubicacion,
    required bool despierto,
  }) =>
      _canal.invokeMethod('iniciar', {
        'titulo': titulo,
        'texto': texto,
        'ubicacion': ubicacion,
        'despierto': despierto,
      });

  @override
  Future<void> detener() => _canal.invokeMethod('detener');

  @override
  Future<void> sobreBloqueo(bool valor) => _canal.invokeMethod('sobreBloqueo', {'valor': valor});
}

/// Decide cuándo Rondó sigue pendiente con la app cerrada:
/// - la persona, mientras su ronda esté activa (no en pausa);
/// - el cuidador, mientras cuide a alguien.
class ControlFondo {
  ControlFondo(this._estado, this._servicio) {
    _estado.addListener(_revisar);
    _revisar();
  }

  final AppState _estado;
  final ServicioFondo _servicio;
  ({String titulo, String texto, bool ubicacion, bool despierto})? _actual;
  bool _primera = true;

  void _revisar() {
    final quiere = planDe(_estado);
    if (!_primera && quiere == _actual) return;
    _primera = false;
    _actual = quiere;
    final hacer = quiere == null
        ? _servicio.detener()
        : _servicio.iniciar(
            titulo: quiere.titulo,
            texto: quiere.texto,
            ubicacion: quiere.ubicacion,
            despierto: quiere.despierto,
          );
    hacer.catchError((Object _) {
      // Android no lo dejó (por ejemplo, desde el fondo): el próximo cambio,
      // o al volver a la app, se intenta otra vez.
      if (quiere != null && _actual == quiere) _actual = null;
    });
  }

  /// Al volver a la app: por si Android lo apagó.
  void asegurar() {
    _primera = true;
    _revisar();
  }

  @visibleForTesting
  static ({String titulo, String texto, bool ubicacion, bool despierto})? planDe(AppState estado) {
    if (estado.esCuidador) {
      final personas = [
        for (final p in estado.personasACargo)
          if (!p.id.startsWith(PersonaACargo.prefijoEjemplo)) primerNombre(p.nombre),
      ];
      if (personas.isEmpty) return null;
      return (
        titulo: 'Pendiente de ${listaNatural(personas)}',
        texto: 'Te avisamos si hay una alerta.',
        ubicacion: false,
        despierto: false,
      );
    }
    if (estado.tipo == null || estado.rondaActivaDesde == null || estado.rondaEnPausa) return null;
    final sensores = estado.tienePermiso(PermisoSistema.sensores);
    return (
      titulo: 'Tu ronda está activa',
      texto: sensores ? 'Rondó está pendiente de ti.' : 'La detección de caídas está apagada.',
      ubicacion: estado.permisoUbicacion,
      despierto: sensores,
    );
  }

  void dispose() => _estado.removeListener(_revisar);
}
