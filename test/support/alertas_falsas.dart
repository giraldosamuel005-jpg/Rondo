import 'dart:async';

import 'package:rondo/core/alertas/alerta_compartida.dart';
import 'package:rondo/core/alertas/aviso_alerta.dart';
import 'package:rondo/core/fondo/fondo.dart';
import 'package:rondo/core/notificaciones/notificaciones.dart';

class UbicacionFalsa implements LectorUbicacion {
  UbicacionFalsa(this.posicion);

  Posicion? posicion;
  int lecturas = 0;

  @override
  Future<Posicion?> leer() async {
    lecturas++;
    return posicion;
  }

  @override
  Future<Posicion?> ultima() async => posicion;
}

/// Un GPS que nunca contesta.
class UbicacionColgada implements LectorUbicacion {
  UbicacionColgada([this.conocida]);

  final Posicion? conocida;

  @override
  Future<Posicion?> leer() => Completer<Posicion?>().future;

  @override
  Future<Posicion?> ultima() async => conocida;
}

class SmsFalso implements EnviadorSms {
  SmsFalso({this.sinPermiso = false, Set<String> fallanA = const {}}) : fallanA = {...fallanA};

  bool sinPermiso;
  final Set<String> fallanA;

  /// Por celular, los textos que le llegaron.
  final Map<String, List<String>> enviados = {};

  @override
  Future<void> enviar(String celular, String texto) async {
    if (sinPermiso) throw const SinPermisoSms();
    if (fallanA.contains(celular)) throw StateError('sin señal');
    (enviados[celular] ??= []).add(texto);
  }
}

class ServidorAlertasFalso implements ServidorAlertas {
  ServidorAlertasFalso([this.entrega = EntregaServidor.recibida]);

  EntregaServidor entrega;
  final List<AlertaCompartida> recibidas = [];
  final List<String> resueltas = [];

  @override
  Future<EntregaServidor> publicarAlerta(AlertaCompartida alerta) async {
    if (entrega == EntregaServidor.pendiente) return Completer<EntregaServidor>().future; // Sin red
    if (entrega == EntregaServidor.recibida) recibidas.add(alerta);
    return entrega;
  }

  @override
  Future<void> resolverAlerta(String alertaId) async => resueltas.add(alertaId);
}

class AlarmaFalsa implements Alarma {
  bool sonando = false;
  bool funciona = true;

  @override
  Future<bool> sonar() async {
    sonando = funciona;
    return funciona;
  }

  @override
  Future<void> parar() async => sonando = false;
}

class NotificacionesFalsas implements Notificaciones {
  final List<String> alertas = [];
  final List<String> quitadas = [];
  final List<String> novedades = [];
  int caidas = 0;
  final toques = StreamController<RespuestaNotificacion>.broadcast(sync: true);

  @override
  Future<void> iniciar() async {}

  @override
  Stream<RespuestaNotificacion> get respuestas => toques.stream;

  @override
  Future<RespuestaNotificacion?> abiertaDesde() async => null;

  @override
  Future<void> caida({required String cuerpo}) async => caidas++;

  @override
  Future<void> quitarCaida() async {}

  @override
  Future<void> alertaDePersona({
    required String personaId,
    required String titulo,
    required String cuerpo,
  }) async =>
      alertas.add(titulo);

  @override
  Future<void> quitarAlertaDePersona(String personaId) async => quitadas.add(personaId);

  @override
  Future<void> novedad({required String personaId, required String titulo, required String cuerpo}) async =>
      novedades.add(cuerpo);
}

class FondoFalso implements ServicioFondo {
  String? titulo;
  bool despierto = false;
  bool falla = false;
  int veces = 0;

  @override
  Future<void> iniciar({
    required String titulo,
    required String texto,
    required bool ubicacion,
    required bool despierto,
  }) async {
    veces++;
    if (falla) throw StateError('Android no deja');
    this.titulo = titulo;
    this.despierto = despierto;
  }

  @override
  Future<void> detener() async => titulo = null;

  @override
  Future<void> sobreBloqueo(bool valor) async {}
}
