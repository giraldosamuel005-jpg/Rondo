import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../state/app_state.dart';
import 'recordatorio.dart';

/// Programa notificaciones en el celular. La app usa la de Android; las
/// pruebas, una falsa.
abstract interface class ProgramadorNotificaciones {
  /// Prepara todo. [alTocar] recibe el ID del medicamento de la notificación
  /// que la persona tocó.
  Future<void> iniciar({required void Function(String medicamentoId) alTocar});

  /// Si la app se abrió tocando una notificación, el ID de su medicamento.
  Future<String?> abiertaDesde();

  /// ¿La persona deja que Rondó muestre notificaciones?
  Future<bool> permitidas();

  /// Muestra la ventana del sistema para pedir el permiso.
  Future<bool> pedirPermiso();

  /// Deja programados exactamente estos avisos: quita los que había y pone estos.
  Future<void> reemplazar(List<Recordatorio> plan);
}

/// RF-22: mantiene programados los avisos de toma según los medicamentos.
///
/// Escucha al [AppState]: cada vez que cambian los medicamentos o se registra
/// una toma, vuelve a calcular qué avisos faltan y los reprograma.
class Recordatorios extends ChangeNotifier {
  Recordatorios(this._estado, this._programador, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now {
    _iniciar();
  }

  static const errorPermiso = 'No se pudo programar la alarma. Activa los permisos de notificaciones.';

  final AppState _estado;
  final ProgramadorNotificaciones _programador;
  final DateTime Function() _reloj;

  final _tocados = StreamController<String>.broadcast();
  List<Recordatorio>? _programados;
  bool? _permitidas;
  bool _fallo = false;
  bool _yaPidio = false;
  bool _pidiendo = false;
  bool _listo = false;
  bool _cerrado = false;

  /// Cola: cada reprogramación espera a la anterior, así no se pisan.
  Future<void> _cola = Future.value();

  /// Espera a que termine de programar (útil en pruebas).
  Future<void> get pendiente => _cola;

  /// El ID del medicamento cada vez que la persona toca un aviso: la app
  /// abre con esto la pantalla de medicamentos.
  Stream<String> get tocados => _tocados.stream;

  /// Si la app se abrió tocando un aviso, su medicamento. Se entrega una vez.
  String? tomarAbiertaDesde() {
    final id = _abiertaDesde;
    _abiertaDesde = null;
    return id;
  }

  String? _abiertaDesde;

  /// Los avisos que quedaron programados, del más cercano al más lejano.
  List<Recordatorio> get programados => _programados ?? const [];

  /// Por qué no van a sonar los avisos aunque haya medicamentos, para
  /// decírselo a la persona. `null` si todo va bien.
  String? get aviso {
    // Mientras la ventana del permiso está abierta todavía no es un error.
    if (!_usaMedicamentos || _pidiendo) return null;
    return _permitidas == false || _fallo ? errorPermiso : null;
  }

  bool get _usaMedicamentos => _estado.usaFichaMedica && _estado.medicamentos.isNotEmpty;

  Future<void> _iniciar() async {
    try {
      await _programador.iniciar(alTocar: (id) {
        if (!_cerrado) _tocados.add(id);
      });
      final abierta = await _programador.abiertaDesde();
      if (abierta != null) {
        // Si la pantalla principal ya está escuchando, se le avisa de una;
        // si no, lo recoge ella con tomarAbiertaDesde().
        _tocados.hasListener ? _tocados.add(abierta) : _abiertaDesde = abierta;
      }
      _permitidas = await _programador.permitidas();
    } catch (_) {
      _fallo = true;
    }
    if (_cerrado) return;
    _listo = true;
    _estado.addListener(_revisar);
    _revisar();
    notifyListeners();
  }

  /// Vuelve a pedir el permiso (botón "Activar notificaciones").
  Future<void> pedirPermiso() async {
    _permitidas = await _preguntar();
    if (_cerrado) return;
    _programados = null; // Obliga a reprogramar con el permiso nuevo
    _revisar();
    notifyListeners();
  }

  /// Muestra la ventana del sistema y espera la respuesta.
  Future<bool> _preguntar() async {
    _pidiendo = true;
    if (!_cerrado) notifyListeners();
    try {
      return await _programador.pedirPermiso();
    } catch (_) {
      return false;
    } finally {
      _pidiendo = false;
    }
  }

  void _revisar() {
    if (_cerrado || !_listo) return;
    final plan = _usaMedicamentos
        ? Recordatorio.planear(
            medicamentos: _estado.medicamentos,
            yaRegistrada: _estado.tomaYaRegistrada,
            ahora: _reloj(),
          )
        : const <Recordatorio>[];
    if (listEquals(plan, _programados)) return;
    _programados = plan;

    _cola = _cola.then((_) async {
      // La primera vez que hay medicamentos y falta el permiso, se pide solo.
      if (plan.isNotEmpty && _permitidas == false && !_yaPidio) {
        _yaPidio = true;
        _permitidas = await _preguntar();
      }
      try {
        await _programador.reemplazar(plan);
        _fallo = false;
      } catch (_) {
        _fallo = true;
      }
      if (!_cerrado) notifyListeners();
    });
  }

  @override
  void dispose() {
    _cerrado = true;
    _estado.removeListener(_revisar);
    _tocados.close();
    super.dispose();
  }
}

// ---------- En el celular ----------

/// Notificaciones locales de Android con `flutter_local_notifications`.
/// Las programa el propio celular: suenan aunque la app esté cerrada y sin
/// internet, y se conservan al reiniciar el celular.
class ProgramadorAndroid implements ProgramadorNotificaciones {
  final _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'tomas',
      'Tomas de medicamentos',
      channelDescription: 'Te avisa a la hora de cada toma.',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    ),
  );

  @override
  Future<void> iniciar({required void Function(String medicamentoId) alTocar}) async {
    // Las horas se pasan como instantes exactos (UTC): no hace falta saber
    // la zona horaria del celular.
    tz.setLocalLocation(tz.UTC);
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_rondo')),
      onDidReceiveNotificationResponse: (respuesta) {
        final id = respuesta.payload;
        if (id != null) alTocar(id);
      },
    );
  }

  @override
  Future<String?> abiertaDesde() async {
    final detalles = await _plugin.getNotificationAppLaunchDetails();
    if (detalles?.didNotificationLaunchApp != true) return null;
    return detalles!.notificationResponse?.payload;
  }

  @override
  Future<bool> permitidas() async => await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> pedirPermiso() async => await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> reemplazar(List<Recordatorio> plan) async {
    await _plugin.cancelAllPendingNotifications();
    // A la hora en punto si Android lo permite; si no, con unos minutos de margen.
    final exactas = await _android?.canScheduleExactNotifications() ?? false;
    for (final r in plan) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.hora, tz.UTC),
        notificationDetails: _detalles,
        androidScheduleMode:
            exactas ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.titulo,
        body: r.cuerpo,
        payload: r.medicamentoId,
      );
    }
  }
}
