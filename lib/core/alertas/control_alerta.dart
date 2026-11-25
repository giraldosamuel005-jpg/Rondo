import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/contacto.dart';
import '../permisos/permisos_sistema.dart';
import '../state/app_state.dart';
import '../utils/formato.dart';
import 'alerta_compartida.dart';
import 'aviso_alerta.dart';

enum FaseAlerta {
  /// Cuenta regresiva: todavía se puede cancelar (RF-13, RF-14).
  contando,

  /// Se acabó el tiempo o pidió ayuda: primer intento de avisar (RF-15).
  avisando,

  /// Ya se intentó; lo que falte se sigue reintentando.
  enviada,
}

enum EntregaSms { enviando, enviado, fallo }

/// La alerta de la persona, de principio a fin (RF-13 a RF-17).
///
/// Vive aparte de las pantallas a propósito: la cuenta regresiva va con el
/// reloj del celular, así que la alerta se envía aunque la pantalla se apague,
/// la persona salga de la app o la pantalla de alerta no se pueda dibujar.
class ControlAlerta extends ChangeNotifier {
  ControlAlerta(
    this._estado, {
    this.ubicacion,
    this.sms,
    this.servidor,
    this.alarma,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now {
    _estado.addListener(_alCambiarEstado);
  }

  final AppState _estado;
  final LectorUbicacion? ubicacion;
  final EnviadorSms? sms;
  final ServidorAlertas? servidor;
  final Alarma? alarma;
  final DateTime Function() _reloj;

  /// RF-13: la cuenta regresiva dura 10 s.
  static const duracion = Duration(seconds: 10);

  /// Cuánto se espera en "Avisando…" antes de mostrar cómo va. Lo que no haya
  /// terminado sigue en curso.
  static const esperaPrimerIntento = Duration(seconds: 12);

  /// Cuánto se espera la ubicación antes de avisar sin ella. Se empieza a
  /// buscar desde que arranca la cuenta, así que casi siempre ya está.
  static const esperaUbicacion = Duration(seconds: 6);

  /// Si algo no salió, se vuelve a intentar.
  static const cadaReintento = Duration(seconds: 30);
  static const maximoReintentos = 10;

  static const errorSonido = 'No se pudo reproducir la alarma sonora. Revisa el volumen de tu celular.';

  FaseAlerta? _fase;
  bool _prueba = false;
  bool _pidioAyuda = false;
  bool _errorDeSonido = false;
  DateTime _detectadaA = DateTime(2026);
  DateTime _limite = DateTime(2026);
  int _segundos = 0;
  Timer? _cuenta;

  String _id = '';
  List<Contacto> _contactos = const [];
  Future<Posicion?>? _lectura;
  Posicion? _posicion;
  final Map<String, EntregaSms> _porCelular = {};
  bool _faltaPermisoSms = false;
  EntregaServidor? _servidorEstado;
  Timer? _reintento;
  int _reintentos = 0;
  int _vuelta = 0;
  bool _cerrado = false;

  // ---------- Lectura ----------

  /// `null` si no hay ninguna alerta a la vista.
  FaseAlerta? get fase => _fase;
  bool get activa => _fase != null;

  bool get prueba => _prueba;

  /// La persona la pidió con el botón; no la detectaron los sensores.
  bool get pidioAyuda => _pidioAyuda;
  DateTime get detectadaA => _detectadaA;
  int get segundosRestantes => _segundos;

  /// De 1.0 (recién empieza) a 0.0, para dibujar el anillo.
  double get fraccionRestante =>
      (_limite.difference(_reloj()).inMilliseconds / duracion.inMilliseconds).clamp(0.0, 1.0);

  /// Sin SMS ni servidor (web, Windows): no se envía nada real.
  bool get simulada => sms == null && servidor == null;

  bool get sonidoFallo => _errorDeSonido;
  Posicion? get posicion => _posicion;
  bool get faltaPermisoSms => _faltaPermisoSms;
  EntregaServidor? get entregaServidor => _servidorEstado;
  EntregaSms? entregaSms(Contacto contacto) => _porCelular[contacto.celular];

  List<Contacto> get contactos => _contactos;
  List<Contacto> get conSms => _con(EntregaSms.enviado);
  List<Contacto> get sinSms => _con(EntregaSms.fallo);
  bool get llegoACuidadores => _servidorEstado == EntregaServidor.recibida;

  /// Ni un SMS ni el servidor: toca la alarma local (RF-17).
  bool get nadieAvisado => !simulada && conSms.isEmpty && !llegoACuidadores;

  /// Todavía se está intentando avisarle a alguien más.
  bool get reintentando => _reintento != null;

  List<Contacto> _con(EntregaSms entrega) => [
        for (final k in _contactos)
          if (_porCelular[k.celular] == entrega) k,
      ];

  // ---------- Acciones ----------

  /// Arranca la cuenta regresiva. Si ya hay una alerta en curso, no hace nada.
  void iniciar({DateTime? detectadaA, bool prueba = false}) {
    if (_fase == FaseAlerta.contando || _fase == FaseAlerta.avisando || _cerrado) return;
    _empezar(detectadaA: detectadaA, prueba: prueba, pidioAyuda: false);
    _fase = FaseAlerta.contando;
    _limite = _reloj().add(duracion);
    _segundos = duracion.inSeconds;
    // Cada poco y contra el reloj: si el celular se duerme un rato, al
    // despertar sabe cuánto tiempo pasó de verdad.
    _cuenta = Timer.periodic(const Duration(milliseconds: 200), (_) => _tic());
    _sonar();
    notifyListeners();
  }

  /// Botón "Pedir ayuda": avisa de una, sin cuenta regresiva. Sirve también
  /// durante la cuenta (RF-14).
  void pedirAyuda() {
    if (_cerrado || _fase == FaseAlerta.avisando) return;
    if (_fase != FaseAlerta.contando) _empezar(prueba: false, pidioAyuda: true);
    _avisar();
  }

  /// RF-14: durante la cuenta regresiva, la persona está bien → no se avisa.
  void estoyBien() {
    if (_fase != FaseAlerta.contando) return;
    _limpiar();
    _estado.registrarAlerta(enviada: false);
    notifyListeners();
  }

  /// La alerta ya salió y la persona está bien: se les avisa a los mismos.
  void yaEstoyBien() {
    if (_fase == FaseAlerta.contando || _fase == FaseAlerta.avisando) return;
    final avisados = _prueba ? const <Contacto>[] : conSms;
    final id = _estado.alertaAbierta?.id ?? _id;
    final texto = AlertaCompartida.mensajeEstoyBien(nombre: _estado.nombre, fecha: _reloj());
    _limpiar();
    if (id.isNotEmpty) servidor?.resolverAlerta(id).ignore();
    for (final k in avisados) {
      sms?.enviar(k.celular, texto).ignore();
    }
    _porCelular.clear();
    _estado.confirmarEstoyBien();
    notifyListeners();
  }

  /// Sale de la pantalla de alerta. Lo que falte por avisar sigue en curso.
  void cerrar() {
    if (_fase != FaseAlerta.enviada) return;
    alarma?.parar();
    _fase = null;
    notifyListeners();
  }

  /// Después de dar un permiso, o si la persona no quiere esperar.
  void reintentarYa() {
    if (_fase != FaseAlerta.enviada) return;
    _reintentos = 0;
    _reintentar();
  }

  // ---------- Por dentro ----------

  /// Cerró sesión: la alerta era de esa cuenta.
  void _alCambiarEstado() {
    if (_estado.tipo != null || (_fase == null && _reintento == null)) return;
    _limpiar();
    notifyListeners();
  }

  void _empezar({DateTime? detectadaA, required bool prueba, required bool pidioAyuda}) {
    _limpiar();
    final ahora = _reloj();
    _id = AlertaCompartida.nuevoId(ahora);
    _detectadaA = detectadaA ?? ahora;
    _prueba = prueba;
    _pidioAyuda = pidioAyuda;
    _contactos = _estado.contactos;
    _porCelular.clear();
    _posicion = null;
    _faltaPermisoSms = false;
    _servidorEstado = null;
    _errorDeSonido = false;
    _reintentos = 0;
    // La ubicación se busca desde ya, para no demorar el aviso.
    _lectura = _estado.permisoUbicacion ? _leerUbicacion() : Future.value();
  }

  void _limpiar() {
    _cuenta?.cancel();
    _cuenta = null;
    _reintento?.cancel();
    _reintento = null;
    _vuelta++; // Lo que venga de una alerta anterior ya no cuenta
    alarma?.parar();
    _fase = null;
  }

  Future<Posicion?> _leerUbicacion() async {
    try {
      return await ubicacion?.leer();
    } catch (_) {
      return null;
    }
  }

  /// El GPS no contestó a tiempo: mejor la última conocida que ninguna.
  Future<Posicion?> _ultimaUbicacion() async {
    try {
      return await ubicacion?.ultima().timeout(const Duration(seconds: 1), onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  Future<void> _sonar() async {
    final vuelta = _vuelta;
    final ok = await (alarma?.sonar() ?? Future.value(true));
    if (vuelta != _vuelta || _cerrado) return;
    // Mientras cargaba el sonido la alerta pudo avanzar: que no quede sonando.
    if (_fase != FaseAlerta.contando && !(_fase == FaseAlerta.enviada && nadieAvisado)) alarma?.parar();
    if (_errorDeSonido != !ok) {
      _errorDeSonido = !ok;
      notifyListeners();
    }
  }

  void _tic() {
    final falta = _limite.difference(_reloj());
    if (falta <= Duration.zero) {
      _avisar();
      return;
    }
    final segundos = (falta.inMilliseconds / 1000).ceil();
    if (segundos != _segundos) {
      _segundos = segundos;
      notifyListeners();
    }
  }

  /// RF-15: se acabó el tiempo o pidió ayuda.
  Future<void> _avisar() async {
    _cuenta?.cancel();
    _cuenta = null;
    alarma?.parar();
    _fase = FaseAlerta.avisando;
    final vuelta = _vuelta;
    // Queda guardada como abierta desde ya: aunque la app se cierre aquí, al
    // volver la persona puede avisar que está bien.
    if (!_prueba) _estado.abrirAlerta(_id, _detectadaA);
    notifyListeners();

    _posicion = await _lectura!.timeout(esperaUbicacion, onTimeout: _ultimaUbicacion);
    if (vuelta != _vuelta || _cerrado) return;

    // El servidor y todos los SMS a la vez: ninguno espera al otro.
    final envios = [for (final k in _contactos) _enviarSms(k, vuelta), _subir(vuelta)];
    await Future.wait(envios).timeout(esperaPrimerIntento, onTimeout: () => const []);
    if (vuelta != _vuelta || _cerrado) return;

    _fase = FaseAlerta.enviada;
    _estado.registrarAlerta(enviada: true, detalle: _detalle());
    if (nadieAvisado) _sonar(); // RF-17
    _programarReintento();
    notifyListeners();
  }

  Future<void> _enviarSms(Contacto contacto, int vuelta) async {
    final enviador = sms;
    if (enviador == null) return;
    if (!_estado.tienePermiso(PermisoSistema.sms)) {
      _faltaPermisoSms = true;
      _porCelular[contacto.celular] = EntregaSms.fallo;
      return;
    }
    _porCelular[contacto.celular] = EntregaSms.enviando;
    var entrega = EntregaSms.enviado;
    try {
      await enviador.enviar(
        contacto.celular,
        AlertaCompartida.mensajeSms(
          nombre: _estado.nombre,
          fecha: _detectadaA,
          posicion: _posicion,
          pidioAyuda: _pidioAyuda,
          prueba: _prueba,
        ),
      );
    } on SinPermisoSms {
      if (vuelta == _vuelta) _faltaPermisoSms = true;
      entrega = EntregaSms.fallo;
    } catch (_) {
      entrega = EntregaSms.fallo;
    }
    if (vuelta != _vuelta || _cerrado) return;
    _porCelular[contacto.celular] = entrega;
    _alAvanzar();
  }

  Future<void> _subir(int vuelta) async {
    final destino = servidor;
    if (destino == null) {
      _servidorEstado = EntregaServidor.sinCuidadores;
      return;
    }
    _servidorEstado = EntregaServidor.pendiente;
    var entrega = EntregaServidor.fallo;
    try {
      entrega = await destino.publicarAlerta(
        AlertaCompartida(id: _id, fecha: _detectadaA, posicion: _posicion, prueba: _prueba),
      );
    } catch (_) {
      // Queda como fallo.
    }
    if (vuelta != _vuelta || _cerrado) return;
    _servidorEstado = entrega;
    _alAvanzar();
  }

  /// Llegó el resultado de un envío (quizá tarde, ya con la pantalla mostrada).
  void _alAvanzar() {
    if (!nadieAvisado) alarma?.parar(); // Ya le llegó a alguien
    if (_fase != FaseAlerta.avisando) _programarReintento();
    notifyListeners();
  }

  bool get _faltaAlgo {
    final smsPendiente = !_faltaPermisoSms && sinSms.isNotEmpty;
    return smsPendiente || _servidorEstado == EntregaServidor.fallo;
  }

  void _programarReintento() {
    if (_reintento != null || !_faltaAlgo || _reintentos >= maximoReintentos) return;
    _reintento = Timer(cadaReintento, _reintentar);
  }

  Future<void> _reintentar() async {
    _reintento?.cancel();
    _reintento = null;
    _reintentos++;
    final vuelta = _vuelta;
    final antes = _avisados();
    final faltan = sinSms;
    final subir = _servidorEstado == EntregaServidor.fallo;
    _faltaPermisoSms = false;
    notifyListeners();
    await Future.wait([for (final k in faltan) _enviarSms(k, vuelta), if (subir) _subir(vuelta)]);
    if (vuelta != _vuelta || _cerrado) return;
    final nuevos = _avisados().where((n) => !antes.contains(n)).toList();
    if (nuevos.isNotEmpty) {
      _estado.registrarAlerta(enviada: true, detalle: 'Avisamos a ${listaNatural(nuevos)}');
    }
    _programarReintento();
    notifyListeners();
  }

  List<String> _avisados() => [
        for (final k in conSms) primerNombre(k.nombre),
        if (llegoACuidadores) 'tus cuidadores en Rondó',
      ];

  /// Lo que queda en el Historial: "Avisamos a Ana y Luis".
  String _detalle() {
    final prefijo = _prueba ? 'Prueba. ' : '';
    if (simulada) return '${prefijo}Simulación: no se envió nada';
    final avisados = _avisados();
    if (avisados.isEmpty) return '${prefijo}No se pudo avisar a nadie';
    return '${prefijo}Avisamos a ${listaNatural(avisados)}';
  }

  @override
  void dispose() {
    _cerrado = true;
    _estado.removeListener(_alCambiarEstado);
    _cuenta?.cancel();
    _reintento?.cancel();
    alarma?.parar();
    super.dispose();
  }
}
