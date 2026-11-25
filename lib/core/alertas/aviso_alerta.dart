import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'alerta_compartida.dart';

/// Lee la ubicación del celular. `null` si no hay permiso o no se pudo.
abstract interface class LectorUbicacion {
  Future<Posicion?> leer();

  /// La última que conoce el celular, sin esperar al GPS.
  Future<Posicion?> ultima();
}

/// Envía un SMS sin abrir la app de mensajes. Termina cuando el SMS salió del
/// celular. Lanza [SinPermisoSms] si Android no lo permite, o cualquier otro
/// error si no salió (sin señal, sin saldo, modo avión).
abstract interface class EnviadorSms {
  Future<void> enviar(String celular, String texto);
}

class SinPermisoSms implements Exception {
  const SinPermisoSms();
}

/// La alarma sonora (RF-13, RF-17).
abstract interface class Alarma {
  /// Suena en bucle. `false` si no se pudo reproducir.
  Future<bool> sonar();

  Future<void> parar();
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
        // Con los servicios de Google, sin wifi sale un cuadro pidiendo activar
        // la "precisión" que taparía la alerta. Así lee directo de Android.
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 8),
        ),
      );
      return Posicion(p.latitude, p.longitude);
    } catch (_) {
      return ultima();
    }
  }

  @override
  Future<Posicion?> ultima() async {
    try {
      final p = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
      return p == null ? null : Posicion(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// SMS con el canal `rondo/sms` (CanalSms.kt, SmsManager de Android).
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

/// La alarma, por el canal de ALARMA (no de música): suena con el volumen de
/// alarmas, aunque la persona tenga la música en silencio.
class AlarmaSonora implements Alarma {
  AudioPlayer? _audio;

  @override
  Future<bool> sonar() async {
    try {
      final audio = _audio ??= AudioPlayer();
      await audio.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransient,
            stayAwake: true,
          ),
        ),
      );
      await audio.setReleaseMode(ReleaseMode.loop); // Suena en bucle
      await audio.play(AssetSource('sounds/alarma.wav'), volume: 1);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> parar() async {
    try {
      await _audio?.stop();
    } catch (_) {
      // Ya estaba parada.
    }
  }
}
