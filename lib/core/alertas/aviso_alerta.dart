import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/contacto.dart';
import 'alerta_compartida.dart';

/// Lee la ubicación del celular. `null` si no hay permiso o no se pudo.
abstract interface class LectorUbicacion {
  Future<Posicion?> leer();
}

/// Envía un SMS sin abrir la app de mensajes.
/// Lanza [SinPermisoSms] si Android no lo permite, o cualquier otro error si falló.
abstract interface class EnviadorSms {
  Future<void> enviar(String celular, String texto);
}

class SinPermisoSms implements Exception {
  const SinPermisoSms();
}

/// Lo que pasó al avisar, para mostrárselo a la persona.
class ResultadoAviso {
  const ResultadoAviso({
    required this.posicion,
    required this.conSms,
    required this.sinSms,
    required this.faltaPermisoSms,
    required this.llegoACuidadores,
  });

  final Posicion? posicion;

  /// A quiénes se les envió el SMS.
  final List<Contacto> conSms;

  /// A quiénes no se les pudo enviar (sin señal, sin saldo, sin permiso).
  final List<Contacto> sinSms;

  final bool faltaPermisoSms;

  /// El servidor confirmó la alerta: los cuidadores con Rondó la ven.
  final bool llegoACuidadores;

  /// Ni SMS ni servidor: toca la alarma local (RF-17).
  bool get nadieAvisado => conSms.isEmpty && !llegoACuidadores;
}

/// RF-15 a RF-17: cuando la persona no cancela la alerta, consigue la
/// ubicación, manda el SMS a cada contacto y sube la alerta para los cuidadores.
class AvisoDeAlerta {
  const AvisoDeAlerta({required this.ubicacion, required this.sms});

  final LectorUbicacion ubicacion;
  final EnviadorSms sms;

  /// Cuánto se espera la ubicación y la confirmación del servidor.
  static const espera = Duration(seconds: 10);

  /// [usarUbicacion] y [usarSms]: lo que la persona tiene encendido en Rondó.
  /// [alServidor] sube la alerta y dice si el servidor la recibió.
  Future<ResultadoAviso> avisar({
    required String nombre,
    required List<Contacto> contactos,
    required DateTime fecha,
    required bool usarUbicacion,
    required bool usarSms,
    Future<bool> Function({required DateTime fecha, Posicion? posicion})? alServidor,
  }) async {
    final posicion = usarUbicacion
        ? await ubicacion.leer().timeout(espera, onTimeout: () => null).catchError((Object _) => null)
        : null;

    // El servidor y los SMS a la vez: ninguno espera al otro.
    final servidor = (alServidor?.call(fecha: fecha, posicion: posicion) ?? Future.value(false))
        .timeout(espera, onTimeout: () => false)
        .catchError((Object _) => false);

    final conSms = <Contacto>[];
    final sinSms = <Contacto>[];
    var faltaPermiso = !usarSms;
    final texto = AlertaCompartida.mensajeSms(nombre: nombre, fecha: fecha, posicion: posicion);
    for (final contacto in contactos) {
      if (faltaPermiso) {
        sinSms.add(contacto);
        continue;
      }
      try {
        await sms.enviar(contacto.celular, texto);
        conSms.add(contacto);
      } on SinPermisoSms {
        faltaPermiso = true;
        sinSms.add(contacto);
      } catch (_) {
        sinSms.add(contacto);
      }
    }

    return ResultadoAviso(
      posicion: posicion,
      conSms: conSms,
      sinSms: sinSms,
      faltaPermisoSms: faltaPermiso,
      llegoACuidadores: await servidor,
    );
  }
}

// ---------- En el celular ----------

/// GPS con `geolocator`. Si no responde a tiempo, la última posición conocida.
class LectorUbicacionGps implements LectorUbicacion {
  const LectorUbicacionGps();

  @override
  Future<Posicion?> leer() async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return Posicion(p.latitude, p.longitude);
    } catch (_) {
      return _ultima();
    }
  }

  Future<Posicion?> _ultima() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : Posicion(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// SMS con el canal `rondo/sms` de MainActivity.kt (SmsManager de Android).
class EnviadorSmsAndroid implements EnviadorSms {
  const EnviadorSmsAndroid();

  static const _canal = MethodChannel('rondo/sms');

  @override
  Future<void> enviar(String celular, String texto) async {
    try {
      await _canal.invokeMethod<bool>('enviar', {'numero': '+57$celular', 'texto': texto});
    } on PlatformException catch (e) {
      if (e.code == 'sin-permiso') throw const SinPermisoSms();
      rethrow;
    }
  }
}
