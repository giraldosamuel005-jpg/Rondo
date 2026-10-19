import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:permission_handler/permission_handler.dart';

/// Permisos que Rondó le pide al sistema operativo (RF-30).
enum PermisoSistema {
  /// GPS, para mandar la posición dentro de una alerta.
  ubicacion,

  /// Movimiento/actividad física, para detectar caídas.
  sensores,
}

/// Lo que respondió el sistema, resumido a lo que le importa a la app.
enum EstadoPermiso {
  concedido,

  /// Dijo que no, pero se puede volver a preguntar.
  denegado,

  /// Dijo "no volver a preguntar" (o lo bloquea el sistema): solo se puede
  /// activar desde los ajustes del celular.
  bloqueado,
}

/// Único lugar de la app que habla con `permission_handler`.
/// Las pantallas usan esta clase y nunca el paquete directamente.
class PermisosSistema {
  const PermisosSistema();

  /// Muestra la ventana del sistema (si todavía se puede) y devuelve la respuesta.
  Future<EstadoPermiso> pedir(PermisoSistema permiso) async =>
      _resumir(await _delSistema(permiso).request());

  /// Revisa el estado actual sin mostrarle nada a la persona (RF-32).
  Future<EstadoPermiso> consultar(PermisoSistema permiso) async =>
      _resumir(await _delSistema(permiso).status);

  /// Abre los ajustes de Rondó en el celular, para un permiso [EstadoPermiso.bloqueado].
  Future<bool> abrirAjustes() => openAppSettings();

  // Ubicación: "mientras se usa la app". La ubicación en segundo plano
  // ("siempre") llega con el servicio de monitoreo continuo.
  //
  // Sensores: Android no pide permiso para el acelerómetro, pero sí para
  // reconocer actividad física (filtra falsos positivos, sección 4).
  // iOS lo llama "Movimiento y actividad física".
  Permission _delSistema(PermisoSistema permiso) => switch (permiso) {
        PermisoSistema.ubicacion => Permission.locationWhenInUse,
        PermisoSistema.sensores => defaultTargetPlatform == TargetPlatform.iOS
            ? Permission.sensors
            : Permission.activityRecognition,
      };

  EstadoPermiso _resumir(PermissionStatus estado) => switch (estado) {
        PermissionStatus.granted ||
        PermissionStatus.limited ||
        PermissionStatus.provisional =>
          EstadoPermiso.concedido,
        PermissionStatus.denied => EstadoPermiso.denegado,
        PermissionStatus.permanentlyDenied ||
        PermissionStatus.restricted =>
          EstadoPermiso.bloqueado,
      };
}
