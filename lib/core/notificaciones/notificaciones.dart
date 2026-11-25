import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// La persona tocó una notificación (o uno de sus botones).
class RespuestaNotificacion {
  const RespuestaNotificacion(this.destino, {this.accion});

  /// Qué abrir: [caida], "[alerta]{personaId}", "[novedad]{personaId}" o, en
  /// los avisos de toma, el ID del medicamento.
  final String destino;

  /// El botón que tocó; `null` si tocó la notificación misma.
  final String? accion;

  static const caida = 'caida';
  static const alerta = 'alerta:';
  static const novedad = 'novedad:';

  static const accionEstoyBien = 'estoy_bien';
  static const accionPedirAyuda = 'pedir_ayuda';

  /// No es un aviso de toma de medicamento.
  bool get esDeAlerta => destino == caida || destino.startsWith(alerta) || destino.startsWith(novedad);

  String? get personaId => destino.startsWith(alerta)
      ? destino.substring(alerta.length)
      : destino.startsWith(novedad)
          ? destino.substring(novedad.length)
          : null;
}

/// Las notificaciones de alertas. La app usa las de Android; las pruebas, una
/// falsa.
abstract interface class Notificaciones {
  Future<void> iniciar();

  Stream<RespuestaNotificacion> get respuestas;

  /// Si la app se abrió tocando una notificación. Se entrega una sola vez.
  Future<RespuestaNotificacion?> abiertaDesde();

  /// Persona: posible caída, a pantalla completa aunque el celular esté
  /// bloqueado, con los botones "Estoy bien" y "Pedir ayuda".
  Future<void> caida({required String cuerpo});
  Future<void> quitarCaida();

  /// Cuidador: alguien que cuida necesita ayuda (RF-15).
  Future<void> alertaDePersona({required String personaId, required String titulo, required String cuerpo});
  Future<void> quitarAlertaDePersona(String personaId);

  /// Cuidador: algo que le conviene saber, sin ser emergencia.
  Future<void> novedad({required String personaId, required String titulo, required String cuerpo});
}

/// Notificaciones locales de Android. Hay UN solo plugin para toda la app:
/// los avisos de toma (Recordatorios) también usan este.
class NotificacionesAndroid implements Notificaciones {
  final plugin = FlutterLocalNotificationsPlugin();
  final _respuestas = StreamController<RespuestaNotificacion>.broadcast();
  Future<void>? _iniciando;
  bool _entregada = false;

  AndroidFlutterLocalNotificationsPlugin? get android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Stream<RespuestaNotificacion> get respuestas => _respuestas.stream;

  @override
  Future<void> iniciar() => _iniciando ??= plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_rondo')),
        onDidReceiveNotificationResponse: (r) {
          final respuesta = _de(r);
          if (respuesta != null) _respuestas.add(respuesta);
        },
      );

  @override
  Future<RespuestaNotificacion?> abiertaDesde() async {
    if (_entregada) return null;
    _entregada = true;
    await iniciar();
    final detalles = await plugin.getNotificationAppLaunchDetails();
    if (detalles?.didNotificationLaunchApp != true) return null;
    final r = detalles!.notificationResponse;
    return r == null ? null : _de(r);
  }

  static RespuestaNotificacion? _de(NotificationResponse r) {
    final destino = r.payload;
    if (destino == null || destino.isEmpty) return null;
    final accion = r.actionId;
    return RespuestaNotificacion(destino, accion: accion == null || accion.isEmpty ? null : accion);
  }

  // ---------- Canales ----------

  /// Suena la alarma de la app, no la de la notificación: por eso va en
  /// silencio (si no, sonarían las dos).
  static const _urgente = AndroidNotificationDetails(
    'alertas',
    'Alertas de emergencia',
    channelDescription: 'Posibles caídas y alertas de las personas que cuidas.',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    fullScreenIntent: true,
    playSound: false,
    enableVibration: true,
    ongoing: true,
    autoCancel: false,
    actions: [
      AndroidNotificationAction(
        RespuestaNotificacion.accionEstoyBien,
        'Estoy bien',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        RespuestaNotificacion.accionPedirAyuda,
        'Pedir ayuda',
        showsUserInterface: true,
      ),
    ],
  );

  static const _alertaPersona = AndroidNotificationDetails(
    'alertas',
    'Alertas de emergencia',
    channelDescription: 'Posibles caídas y alertas de las personas que cuidas.',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    fullScreenIntent: true,
    playSound: false,
    enableVibration: true,
  );

  static const _novedad = AndroidNotificationDetails(
    'novedades',
    'Novedades de quienes cuidas',
    channelDescription: 'Cuando pausan su ronda, dicen que están bien o no toman un medicamento.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _idCaida = 7100;

  /// Un número estable por persona, en su propio rango.
  static int _id(String personaId, int base) {
    var n = 17;
    for (final letra in personaId.codeUnits) {
      n = (n * 31 + letra) & 0xffff;
    }
    return base + n;
  }

  @override
  Future<void> caida({required String cuerpo}) => _mostrar(
        _idCaida,
        '¿Estás bien?',
        cuerpo,
        _urgente,
        RespuestaNotificacion.caida,
      );

  @override
  Future<void> quitarCaida() => _quitar(_idCaida);

  @override
  Future<void> alertaDePersona({
    required String personaId,
    required String titulo,
    required String cuerpo,
  }) =>
      _mostrar(
        _id(personaId, 100000),
        titulo,
        cuerpo,
        _alertaPersona,
        '${RespuestaNotificacion.alerta}$personaId',
      );

  @override
  Future<void> quitarAlertaDePersona(String personaId) => _quitar(_id(personaId, 100000));

  @override
  Future<void> novedad({
    required String personaId,
    required String titulo,
    required String cuerpo,
  }) =>
      _mostrar(
        _id(personaId, 200000),
        titulo,
        cuerpo,
        _novedad,
        '${RespuestaNotificacion.novedad}$personaId',
      );

  /// Sin permiso de notificaciones no se muestra nada, pero la alerta sigue
  /// su curso: nunca debe fallar por esto.
  Future<void> _mostrar(
    int id,
    String titulo,
    String cuerpo,
    AndroidNotificationDetails detalles,
    String destino,
  ) async {
    try {
      await iniciar();
      await plugin.show(
        id: id,
        title: titulo,
        body: cuerpo,
        notificationDetails: NotificationDetails(android: detalles),
        payload: destino,
      );
    } catch (_) {
      // Se sigue sin notificación.
    }
  }

  Future<void> _quitar(int id) async {
    try {
      await iniciar();
      await plugin.cancel(id: id);
    } catch (_) {
      // No estaba.
    }
  }
}
