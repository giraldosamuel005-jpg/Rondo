import 'dart:async';

import 'package:flutter/foundation.dart';

import '../alertas/alerta_compartida.dart';
import '../alertas/aviso_alerta.dart';
import '../models/contacto.dart';
import '../models/evento.dart';
import '../state/app_state.dart';
import '../utils/formato.dart';
import 'ficha_publica.dart';
import 'servicio_vinculos.dart';
import 'vinculo.dart';

/// Cómo va la ficha del QR en el servidor (RF-24).
enum EstadoFicha { subiendo, lista, fallo }

/// Vínculos entre la persona y sus cuidadores (RF-05, RF-26, RF-27).
///
/// Escucha al [AppState]: cuando hay sesión se conecta al servidor y
/// - a la persona le mantiene al día sus invitaciones y cuidadores, y publica
///   su estado (ronda, "Estoy bien", medicamentos) solo mientras alguien la cuide;
/// - a la persona le publica la ficha médica bajo el token de su QR (RF-24) y
///   le trae cuándo la abrieron (RF-25);
/// - a la persona le sube las alertas que no canceló (RF-15);
/// - al cuidador le trae las personas que lo vincularon, con sus alertas, y
///   las pone en el [AppState], así las pantallas de cuidador funcionan igual
///   que antes. Cada alerta nueva sale por [alertasNuevas].
///
/// Si una escucha del servidor falla, se vuelve a intentar sola (ver
/// [_vigilar]): un error pasajero no puede dejar al cuidador sin alertas.
class Vinculos extends ChangeNotifier implements ServidorAlertas {
  Vinculos(
    this._servicio,
    this._estado, {
    DateTime Function()? reloj,
    LectorUbicacion? ubicacion,
  }) : _reloj = reloj ?? DateTime.now,
       _lector = ubicacion {
    _estado.addListener(_alCambiarEstado);
    _alCambiarEstado();
  }

  static const errorConexion =
      'No pudimos conectarnos. Revisa tu internet e intenta otra vez.';

  final ServicioVinculos _servicio;
  final AppState _estado;
  final DateTime Function() _reloj;
  final LectorUbicacion? _lector;

  ({String celular, bool cuidador})? _sesion;
  String? _uid;
  Future<String>? _conectando;
  final List<_Escucha> _subs = [];
  bool _cerrado = false;

  /// Cerrar la sesión anterior toma un momento (revoca y borra en el
  /// servidor). Una sesión nueva espera a que termine: si no, al terminar le
  /// cerraría la sesión a la nueva y dejaría de funcionar todo en silencio.
  Future<void> _cierre = Future.value();

  Timer? _reconexion;

  /// Hablando con el servidor. Antes de saberlo se supone que sí.
  bool _enLinea = true;
  Timer? _avisoSinConexion;
  DateTime? _ultimaVezEnLinea;

  // Persona
  List<Invitacion> _invitaciones = const [];
  List<Vinculo> _cuidadores = const [];
  bool _llegaronCuidadores = false;
  Completer<void>? _esperaCuidadores;
  EstadoCompartido? _publicado;

  // Persona: ubicación para sus cuidadores (RF-26)
  Posicion? _ubicacion;
  DateTime? _ubicacionEn;
  bool _leyendoUbicacion = false;
  Timer? _relojUbicacion;
  _Escucha? _subSolicitudes;
  DateTime? _solicitudAtendida;
  DateTime? _ultimoEstoyBienVisto;

  /// Cada cuánto se actualiza la ubicación mientras se comparte.
  static const cadaUbicacion = Duration(minutes: 5);

  // Persona: ficha del QR (RF-24, RF-25)
  String? _fichaToken;
  FichaPublica? _fichaPublicada;
  EstadoFicha _estadoFicha = EstadoFicha.subiendo;
  Timer? _reintentoFicha;
  _Escucha? _subConsultas;

  /// Cada cuánto se vuelve a intentar subir la ficha si el servidor la rechazó.
  static const cadaReintentoFicha = Duration(seconds: 15);
  List<DateTime> _consultas = const [];

  // Cuidador
  List<Vinculo> _personas = const [];

  /// Ya llegó la primera lista de personas del servidor (aunque venga vacía).
  bool _llegaronPersonas = false;
  final Map<String, _Escucha> _subsEstado = {};
  final Map<String, EstadoCompartido?> _estados = {};
  final List<String> _retirados = [];

  // Cuidador: alertas de cada persona (RF-15, RF-26)
  final Map<String, _Escucha> _subsAlertas = {};
  final Map<String, List<AlertaCompartida>> _alertas = {};
  final _novedades = StreamController<Novedad>.broadcast();

  /// "{personaUid}/{alertaId}" de las que ya llegaron en esta sesión.
  final Set<String> _alertasVistas = {};
  final _alertasNuevas = StreamController<String>.broadcast();

  /// Una alerta sin atender más vieja que esto no abre la pantalla de alerta
  /// (sigue en la lista de Alertas).
  static const alertaReciente = Duration(minutes: 30);

  // ---------- Lectura ----------

  /// Cuidador: el ID de la persona cada vez que llega una alerta nueva sin
  /// atender. La app abre con esto la pantalla de alerta.
  Stream<String> get alertasNuevas => _alertasNuevas.stream;

  /// Cuidador: lo demás que le conviene saber de las personas que cuida
  /// (pausó la ronda, dijo que está bien...).
  Stream<Novedad> get novedades => _novedades.stream;

  /// Sin conexión con el servidor.
  bool get sinConexion => _sesion != null && !_enLinea;

  /// Cuándo se supo algo del servidor por última vez.
  DateTime? get ultimaVezEnLinea => _ultimaVezEnLinea;

  /// Cuidador: sigue esperando la primera respuesta del servidor. Las pantallas
  /// muestran un skeleton en vez de "Aún no tienes personas a tu cargo".
  bool get cargandoPersonas => _sesion?.cuidador == true && !_llegaronPersonas;

  /// Ya se sabe quién la cuida (aunque no sea nadie).
  bool get cuidadoresCargados => _llegaronCuidadores;

  List<Vinculo> get cuidadoresActivos => [
    for (final v in _cuidadores)
      if (v.activo) v,
  ];

  /// El vínculo activo con ese contacto, si lo hay.
  Vinculo? vinculoCon(String celular) =>
      cuidadoresActivos.where((v) => v.celularInvitado == celular).firstOrNull;

  /// La invitación vigente más reciente para ese contacto, si la hay.
  Invitacion? invitacionPendiente(String celular) {
    final ahora = _reloj();
    Invitacion? mejor;
    for (final i in _invitaciones) {
      if (i.celularInvitado != celular || !i.vigente(ahora)) continue;
      if (mejor == null || i.expiraEn.isAfter(mejor.expiraEn)) mejor = i;
    }
    return mejor;
  }

  /// Persona: cuándo abrieron su ficha con el QR actual (RF-25), de la más
  /// reciente a la más vieja.
  List<DateTime> get consultasFicha => _consultas;

  /// Persona: si el QR ya se puede escanear. Hasta que el servidor no confirma
  /// la ficha, quien lo escanee no vería nada (o vería la versión anterior).
  EstadoFicha get estadoFicha => _estadoFicha;

  /// Cuidador: nombres de quienes dejaron de compartir con él (RF-27).
  List<String> get retirados => List.unmodifiable(_retirados);

  void descartarRetirados() {
    _retirados.clear();
    notifyListeners();
  }

  // ---------- Acciones de la persona ----------

  /// Crea la invitación. Después hay que enviar el SMS con [Invitacion.mensajeSms].
  Future<Invitacion> invitar(Contacto contacto) async {
    if (vinculoCon(contacto.celular) != null ||
        invitacionPendiente(contacto.celular) != null) {
      throw const ErrorVinculo(Invitacion.errorYaInvitado);
    }
    final uid = await _uidOError();
    // Con 31^6 códigos posibles casi nunca choca; si choca, otro intento.
    for (var intento = 0; intento < 3; intento++) {
      final invitacion = Invitacion(
        codigo: Invitacion.nuevoCodigo(),
        personaUid: uid,
        personaNombre: _estado.nombre,
        personaCelular: _estado.celular ?? '',
        celularInvitado: contacto.celular,
        nombreInvitado: contacto.nombre,
        estado: EstadoInvitacion.pendiente,
        expiraEn: _reloj().add(Invitacion.vigencia),
      );
      try {
        await _servicio.crearInvitacion(invitacion);
      } on CodigoOcupado {
        continue;
      } catch (_) {
        throw const ErrorVinculo(errorConexion);
      }
      // Se muestra ya, sin esperar a que el servidor la devuelva.
      _invitaciones = [
        for (final i in _invitaciones)
          if (i.codigo != invitacion.codigo) i,
        invitacion,
      ];
      notifyListeners();
      return invitacion;
    }
    throw const ErrorVinculo(errorConexion);
  }

  Future<void> cancelarInvitacion(Invitacion invitacion) =>
      _accion(() => _servicio.revocarInvitacion(invitacion.codigo));

  /// RF-27: desde este momento el cuidador ya no ve nada.
  Future<void> dejarDeCompartir(Vinculo vinculo) =>
      _accion(() => _servicio.revocarVinculo(vinculo));

  /// Al quitar un contacto: corta su vínculo y anula su invitación, si hay.
  Future<void> olvidarContacto(String celular) async {
    final vinculo = vinculoCon(celular);
    final invitacion = invitacionPendiente(celular);
    try {
      if (vinculo != null) await dejarDeCompartir(vinculo);
      if (invitacion != null) await cancelarInvitacion(invitacion);
    } on ErrorVinculo {
      // Sin internet: quedará como estaba; se puede revocar después.
    }
  }

  /// RF-15: sube la alerta que la persona no canceló, para sus cuidadores.
  /// Termina cuando el servidor la recibió. Sin cuidadores no sube nada.
  @override
  Future<EntregaServidor> publicarAlerta(AlertaCompartida alerta) async {
    final sesion = _sesion;
    if (sesion == null || sesion.cuidador) return EntregaServidor.sinCuidadores;
    final String uid;
    try {
      uid = await _conectar();
    } catch (_) {
      return EntregaServidor.fallo;
    }
    // Recién abierta la app la lista puede no haber llegado: se espera un poco
    // en vez de creer que no tiene cuidadores.
    if (!_llegaronCuidadores) {
      final espera = _esperaCuidadores ??= Completer();
      await espera.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    }
    if (_llegaronCuidadores && cuidadoresActivos.isEmpty) {
      return EntregaServidor.sinCuidadores;
    }
    try {
      await _servicio.publicarAlerta(uid, alerta);
      return EntregaServidor.recibida;
    } catch (_) {
      return EntregaServidor.fallo;
    }
  }

  /// La persona avisó que está bien: sus cuidadores lo ven.
  @override
  Future<void> resolverAlerta(String alertaId) async {
    final uid = _uid;
    if (uid == null || alertaId.isEmpty) return;
    await _servicio.resolverAlerta(uid, alertaId);
  }

  /// Lee dónde está y, si cambió, se lo muestra a sus cuidadores. Solo si ella
  /// lo autorizó, su ronda está activa y alguien la cuida.
  Future<void> actualizarUbicacion() async {
    final lector = _lector;
    if (lector == null || _leyendoUbicacion || !_compartiendoUbicacion) return;
    _leyendoUbicacion = true;
    try {
      final posicion = await lector.leer();
      if (posicion == null || _cerrado || !_compartiendoUbicacion) return;
      _ubicacion = posicion;
      _ubicacionEn = _reloj();
      _publicarSiCambio();
    } catch (_) {
      // Sin GPS: se queda con la anterior.
    } finally {
      _leyendoUbicacion = false;
    }
  }

  bool get _compartiendoUbicacion =>
      _uid != null &&
      _sesion?.cuidador == false &&
      _estado.comparteUbicacion &&
      !_estado.rondaEnPausa &&
      cuidadoresActivos.isNotEmpty;

  /// Empieza o deja de compartir la ubicación según lo que decidió.
  void _revisarUbicacion() {
    final uid = _uid;
    if (uid != null && _compartiendoUbicacion) {
      if (_relojUbicacion != null) return;
      _relojUbicacion = Timer.periodic(
        cadaUbicacion,
        (_) => actualizarUbicacion(),
      );
      _subSolicitudes = _vigilar(
        () => _servicio.ubicacionPedida(uid),
        _alPedirUbicacion,
      );
      actualizarUbicacion();
      return;
    }
    _relojUbicacion?.cancel();
    _relojUbicacion = null;
    _subSolicitudes?.cancelar();
    _subSolicitudes = null;
    _ubicacion = null;
    _ubicacionEn = null;
  }

  void _alPedirUbicacion(DateTime? pedidaEn) {
    if (pedidaEn == null) return;
    final anterior = _solicitudAtendida;
    if (anterior != null && !pedidaEn.isAfter(anterior)) return;
    _solicitudAtendida = pedidaEn;
    actualizarUbicacion();
  }

  // ---------- Acciones del cuidador ----------

  /// El cuidador quiere saber dónde está ahora.
  Future<void> pedirUbicacion(String personaUid) => _accion(
    () => _servicio.pedirUbicacion(personaUid, cuidadorUid: _uid!),
  );

  /// El cuidador atendió las alertas de esa persona. Sin internet queda en
  /// cola y se envía después; la pantalla no tiene que esperar.
  void atenderAlertas(String personaUid) {
    final uid = _uid;
    if (uid == null) return;
    for (final a in _alertas[personaUid] ?? const <AlertaCompartida>[]) {
      if (!a.atendida) {
        _servicio.atenderAlerta(personaUid, a.id, cuidadorUid: uid).ignore();
      }
    }
  }

  /// Acepta con el código que le llegó por SMS. Devuelve el vínculo creado.
  Future<Vinculo> aceptar(String texto) async {
    final codigo = Invitacion.normalizarCodigo(texto);
    if (!Invitacion.codigoValido(codigo)) {
      throw const ErrorVinculo(Invitacion.errorCodigo);
    }
    final uid = await _uidOError();
    try {
      return await _servicio.aceptarInvitacion(
        codigo,
        cuidadorUid: uid,
        cuidadorNombre: _estado.nombre,
      );
    } on ErrorVinculo {
      rethrow;
    } catch (_) {
      throw const ErrorVinculo(errorConexion);
    }
  }

  // ---------- Conexión ----------

  Future<void> _accion(Future<void> Function() hacer) async {
    await _uidOError();
    try {
      await hacer();
    } on ErrorVinculo {
      rethrow;
    } catch (_) {
      throw const ErrorVinculo(errorConexion);
    }
  }

  Future<String> _uidOError() async {
    try {
      return await _conectar();
    } catch (_) {
      throw const ErrorVinculo(errorConexion);
    }
  }

  /// Inicia la sesión anónima (una sola vez) y empieza a escuchar.
  Future<String> _conectar() {
    final uid = _uid;
    if (uid != null) return Future.value(uid);
    final enCurso = _conectando;
    if (enCurso != null) return enCurso;
    late final Future<String> esta;
    esta = _cierre
        .then((_) => _servicio.iniciarSesion())
        .then(
          (uid) {
            // Mientras conectaba pudo cerrar sesión: esta ya no cuenta.
            if (!identical(_conectando, esta)) return uid;
            _conectando = null;
            if (!_cerrado && _sesion != null && _uid == null) {
              _uid = uid;
              _enLinea = true;
              _escuchar(uid, comoCuidador: _sesion!.cuidador);
              if (!_sesion!.cuidador) _publicarFichaSiCambio();
            }
            return uid;
          },
          onError: (Object error) {
            if (identical(_conectando, esta)) {
              _conectando = null;
              _reintentarConexion();
              _sinSesion();
            }
            throw error;
          },
        );
    return _conectando = esta;
  }

  /// Sin internet al abrir: se vuelve a intentar solo.
  void _reintentarConexion() {
    if (_cerrado || _sesion == null || _reconexion != null) return;
    _reconexion = Timer(const Duration(seconds: 10), () {
      _reconexion = null;
      if (!_cerrado && _sesion != null && _uid == null) _conectar().ignore();
    });
  }

  _Escucha _vigilar<T>(
    Stream<T> Function() crear,
    void Function(T) alLlegar, {
    void Function()? alFallar,
  }) => _Escucha(() => crear().listen(null), (dato) {
    if (!_cerrado) alLlegar(dato as T);
  }, alFallar);

  void _escuchar(String uid, {required bool comoCuidador}) {
    _subs.add(
      _vigilar(
        () => _servicio.enLinea(uid, cuidador: comoCuidador),
        _alCambiarConexion,
      ),
    );
    if (comoCuidador) {
      _subs.add(
        _vigilar(
          () => _servicio.personasDe(uid),
          _alCambiarPersonas,
          alFallar: _dejarDeCargar,
        ),
      );
      return;
    }
    _subs
      ..add(
        _vigilar(() => _servicio.invitacionesDe(uid), (
          List<Invitacion> lista,
        ) {
          _invitaciones = lista;
          notifyListeners();
        }),
      )
      ..add(
        _vigilar(() => _servicio.cuidadoresDe(uid), (List<Vinculo> lista) {
          _cuidadores = lista;
          _llegaronCuidadores = true;
          _esperaCuidadores?.complete();
          _esperaCuidadores = null;
          _revisarUbicacion();
          _publicarSiCambio();
          notifyListeners();
        }),
      );
  }

  /// Al empezar, Firestore siempre muestra primero lo guardado en el celular:
  /// solo se dice "sin conexión" si pasan unos segundos así.
  void _alCambiarConexion(bool enLinea) {
    _avisoSinConexion?.cancel();
    _avisoSinConexion = null;
    if (enLinea) {
      _ultimaVezEnLinea = _reloj();
      if (_enLinea) return;
      _enLinea = true;
      notifyListeners();
      return;
    }
    if (!_enLinea) return;
    _ultimaVezEnLinea = _reloj();
    _avisoSinConexion = Timer(const Duration(seconds: 8), () {
      _enLinea = false;
      notifyListeners();
    });
  }

  /// No se pudo ni entrar: se muestra "Sin conexión" en vez de cargar sin fin.
  void _sinSesion() {
    if (_cerrado || _sesion == null) return;
    _enLinea = false;
    _llegaronPersonas = true;
    notifyListeners();
  }

  void _dejarDeCargar() {
    if (_llegaronPersonas) return;
    _llegaronPersonas = true;
    notifyListeners();
  }

  void _alCambiarEstado() {
    if (_cerrado) return;
    final celular = _estado.celular;
    final sesion = (celular == null || _estado.tipo == null)
        ? null
        : (celular: celular, cuidador: _estado.esCuidador);

    if (sesion != _sesion) {
      final anterior = _sesion;
      _sesion = sesion;
      _reiniciar(
        personaCerroSesion:
            anterior != null && !anterior.cuidador && sesion == null,
      );
    }
    if (_sesion == null) return;
    if (_uid == null) {
      if (_conectando == null && _reconexion == null) _conectar().ignore();
    } else if (!_sesion!.cuidador) {
      _revisarUbicacion();
      // "Estoy bien" es un buen momento para decir también dónde está.
      final estoyBien = _estado.ultimoEstoyBien;
      if (estoyBien != _ultimoEstoyBienVisto) {
        _ultimoEstoyBienVisto = estoyBien;
        actualizarUbicacion();
      }
      _publicarSiCambio();
      _publicarFichaSiCambio();
    }
  }

  /// Cambió la sesión: se olvida todo lo de la anterior.
  void _reiniciar({required bool personaCerroSesion}) {
    final uidAnterior = _uid;
    final cuidadores = cuidadoresActivos;
    final ahora = _reloj();
    final pendientes = [
      for (final i in _invitaciones)
        if (i.vigente(ahora)) i,
    ];
    final habiaPublicado = _publicado != null;
    final fichaToken = _fichaToken;

    for (final s in _subs) {
      s.cancelar();
    }
    _reconexion?.cancel();
    _reconexion = null;
    _avisoSinConexion?.cancel();
    _avisoSinConexion = null;
    _enLinea = true;
    _ultimaVezEnLinea = null;
    _llegaronPersonas = false;
    _llegaronCuidadores = false;
    _relojUbicacion?.cancel();
    _relojUbicacion = null;
    _subSolicitudes?.cancelar();
    _subSolicitudes = null;
    _solicitudAtendida = null;
    _ubicacion = null;
    _ubicacionEn = null;
    _subConsultas?.cancelar();
    _subConsultas = null;
    _consultas = const [];
    _fichaToken = null;
    _fichaPublicada = null;
    _estadoFicha = EstadoFicha.subiendo;
    _reintentoFicha?.cancel();
    _reintentoFicha = null;
    for (final s in [..._subsEstado.values, ..._subsAlertas.values]) {
      s.cancelar();
    }
    _subs.clear();
    _subsEstado.clear();
    _subsAlertas.clear();
    _alertas.clear();
    _alertasVistas.clear();
    _estados.clear();
    _invitaciones = const [];
    _cuidadores = const [];
    _personas = const [];
    _retirados.clear();
    _publicado = null;
    _uid = null;
    _conectando = null;

    if (uidAnterior != null && _sesion == null) {
      final previo = _cierre;
      _cierre = () async {
        await previo;
        // Cerrar sesión borra la cuenta: también deja de compartir (Ley 1581).
        if (personaCerroSesion) {
          for (final v in cuidadores) {
            await _intentar(_servicio.revocarVinculo(v));
          }
          for (final i in pendientes) {
            await _intentar(_servicio.revocarInvitacion(i.codigo));
          }
          if (habiaPublicado) {
            await _intentar(_servicio.publicarEstado(uidAnterior, null));
          }
          // Y el QR que tenga impreso ya no muestra nada.
          if (fichaToken != null) {
            await _intentar(_servicio.revocarFicha(uidAnterior, fichaToken));
          }
          await _intentar(_servicio.borrarAlertas(uidAnterior));
        }
        await _intentar(_servicio.cerrarSesion());
      }();
    }
    notifyListeners();
  }

  /// Un paso del cierre de sesión: si falla o no hay red, se sigue con el otro.
  static Future<void> _intentar(Future<void> paso) async {
    try {
      await paso.timeout(const Duration(seconds: 6));
    } catch (_) {
      // Se sigue.
    }
  }

  // ---------- Persona: lo que comparte ----------

  void _publicarSiCambio() {
    final uid = _uid;
    final sesion = _sesion;
    if (uid == null || sesion == null || sesion.cuidador) return;

    // Solo mientras alguien la cuide: si no, no hay nada en el servidor.
    final nuevo = cuidadoresActivos.isEmpty
        ? null
        : EstadoCompartido(
            nombre: _estado.nombre,
            celular: _estado.celular ?? '',
            enPausa: _estado.rondaEnPausa,
            ultimoEstoyBien: _estado.ultimoEstoyBien,
            cumplimiento: _estado.cumplimiento,
            comparteUbicacion: _estado.comparteUbicacion,
            ubicacion: _ubicacion,
            ubicacionEn: _ubicacionEn,
            ultimaTomaOmitida: _estado.eventos
                .where((e) => e.tipo == TipoEvento.tomaOmitida)
                .firstOrNull
                ?.fecha,
          );
    if (nuevo == _publicado) return;
    _publicado = nuevo;
    // Sin red, Firestore lo envía después.
    _servicio.publicarEstado(uid, nuevo).then(
      (_) {},
      onError: (Object _) {
        // Lo rechazó: que el próximo cambio lo vuelva a intentar.
        if (identical(_publicado, nuevo)) _publicado = null;
      },
    );
  }

  /// Mantiene en el servidor la ficha del QR igual a la del celular. Si el
  /// token cambió (código nuevo) o ya no hay ficha (retiró el consentimiento),
  /// el QR anterior queda revocado.
  void _publicarFichaSiCambio() {
    final uid = _uid;
    final sesion = _sesion;
    if (uid == null || sesion == null || sesion.cuidador) return;

    final ficha = FichaPublica.de(_estado);
    final token = ficha == null ? null : _estado.codigoQr!.token;
    if (token == _fichaToken && ficha == _fichaPublicada) return;

    final anterior = _fichaToken;
    _fichaToken = token;
    _fichaPublicada = ficha;
    _reintentoFicha?.cancel();
    _reintentoFicha = null;
    if (token != null) {
      _ponerEstadoFicha(EstadoFicha.subiendo);
      // Si mientras tanto la editaron, la respuesta de esta ya no cuenta.
      bool vigente() =>
          !_cerrado &&
          _fichaToken == token &&
          identical(_fichaPublicada, ficha);
      // Las consultas se leen cuando la ficha ya existe: antes, las reglas no
      // saben de quién es y no dejan leerlas. Sin internet no responde: queda
      // en cola y sigue "subiendo".
      _servicio.publicarFicha(uid, token, ficha!).then(
        (_) {
          if (!_cerrado && _fichaToken == token && _subConsultas == null) {
            _escucharConsultas(token);
          }
          if (vigente()) _ponerEstadoFicha(EstadoFicha.lista);
        },
        onError: (Object error) {
          if (!vigente()) return;
          debugPrint('No se pudo subir la ficha del QR: $error');
          _ponerEstadoFicha(EstadoFicha.fallo);
          _reintentoFicha = Timer(cadaReintentoFicha, () {
            _fichaPublicada = null; // Para que no crea que ya está igual.
            _publicarFichaSiCambio();
          });
        },
      );
    }
    if (anterior != null && anterior != token) {
      _servicio.revocarFicha(uid, anterior).ignore();
      _subConsultas?.cancelar();
      _subConsultas = null;
      _consultas = const [];
      notifyListeners();
    }
  }

  void _ponerEstadoFicha(EstadoFicha nuevo) {
    if (_estadoFicha == nuevo) return;
    _estadoFicha = nuevo;
    notifyListeners();
  }

  void _escucharConsultas(String token) {
    _subConsultas = _vigilar(() => _servicio.consultasDe(token), (
      List<DateTime> lista,
    ) {
      _consultas = lista;
      notifyListeners();
    });
  }

  // ---------- Cuidador: las personas que cuida ----------

  void _alCambiarPersonas(List<Vinculo> nuevos) {
    if (!_llegaronPersonas) {
      _llegaronPersonas = true;
      notifyListeners(); // Las pantallas cambian el skeleton por la lista (o el vacío).
    }
    final siguen = {for (final v in nuevos) v.personaUid};
    for (final antes in _personas) {
      if (siguen.contains(antes.personaUid)) continue;
      _retirados.add(_estados[antes.personaUid]?.nombre ?? antes.personaNombre);
      _subsEstado.remove(antes.personaUid)?.cancelar();
      _subsAlertas.remove(antes.personaUid)?.cancelar();
      _estados.remove(antes.personaUid);
      _alertas.remove(antes.personaUid);
    }
    for (final v in nuevos) {
      _subsEstado.putIfAbsent(
        v.personaUid,
        () => _vigilar(
          () => _servicio.estadoDe(v.personaUid),
          (EstadoCompartido? estado) => _alCambiarEstadoDe(v, estado),
        ),
      );
      _subsAlertas.putIfAbsent(
        v.personaUid,
        () => _vigilar(
          () => _servicio.alertasDe(v.personaUid),
          (List<AlertaCompartida> lista) => _alCambiarAlertas(v, lista),
        ),
      );
    }
    _personas = nuevos;
    _ponerPersonas();
    notifyListeners();
  }

  /// Lo que cambió desde la última vez que se supo de ella. La primera vez
  /// no cuenta: no es una novedad, es ponerse al día.
  void _alCambiarEstadoDe(Vinculo v, EstadoCompartido? estado) {
    final conocida = _estados.containsKey(v.personaUid);
    final antes = _estados[v.personaUid];
    _estados[v.personaUid] = estado;
    _ponerPersonas();
    if (!conocida || antes == null || estado == null) return;

    void avisar(TipoNovedad tipo) => _novedades.add(
      Novedad(personaId: v.personaUid, nombre: estado.nombre, tipo: tipo),
    );
    if (estado.enPausa != antes.enPausa) {
      avisar(estado.enPausa ? TipoNovedad.pauso : TipoNovedad.reanudo);
    }
    bool nuevo(DateTime? a, DateTime? b) =>
        b != null && (a == null || b.isAfter(a));
    if (nuevo(antes.ultimoEstoyBien, estado.ultimoEstoyBien)) {
      avisar(TipoNovedad.estoyBien);
    }
    if (nuevo(antes.ultimaTomaOmitida, estado.ultimaTomaOmitida)) {
      avisar(TipoNovedad.tomaOmitida);
    }
  }

  void _alCambiarAlertas(Vinculo v, List<AlertaCompartida> lista) {
    final personaUid = v.personaUid;
    _alertas[personaUid] = lista;
    final ahora = _reloj();
    var hayNueva = false;
    for (final a in lista) {
      final primeraVez = _alertasVistas.add('$personaUid/${a.id}');
      if (primeraVez &&
          !a.atendida &&
          ahora.difference(a.fecha) < alertaReciente) {
        hayNueva = true;
      }
    }
    // Primero la lista al día, después el aviso: la pantalla ya la encuentra.
    _ponerPersonas();
    if (hayNueva) _alertasNuevas.add(personaUid);
  }

  void _ponerPersonas() => _estado.ponerPersonasVinculadas([
    for (final v in _personas)
      EstadoCompartido.comoPersona(
        v,
        _estados[v.personaUid],
        alertas: _alertas[v.personaUid] ?? const [],
        relacion: _estado.parentescoDe(v.personaUid),
      ),
  ]);

  @override
  void dispose() {
    _cerrado = true;
    _estado.removeListener(_alCambiarEstado);
    for (final s in [
      ..._subs,
      ..._subsEstado.values,
      ..._subsAlertas.values,
      ?_subConsultas,
      ?_subSolicitudes,
    ]) {
      s.cancelar();
    }
    _reconexion?.cancel();
    _avisoSinConexion?.cancel();
    _relojUbicacion?.cancel();
    _reintentoFicha?.cancel();
    _alertasNuevas.close();
    _novedades.close();
    super.dispose();
  }
}

enum TipoNovedad { pauso, reanudo, estoyBien, tomaOmitida }

/// Algo que le conviene saber al cuidador, sin ser una emergencia.
class Novedad {
  const Novedad({
    required this.personaId,
    required this.nombre,
    required this.tipo,
  });

  final String personaId;
  final String nombre;
  final TipoNovedad tipo;

  /// "Rosa pausó su ronda. No te llegarán alertas hasta que la reanude."
  String get mensaje {
    final quien = primerNombre(nombre);
    return switch (tipo) {
      TipoNovedad.pauso =>
        '$quien pausó su ronda. No te llegarán alertas hasta que la reanude.',
      TipoNovedad.reanudo => '$quien reanudó su ronda.',
      TipoNovedad.estoyBien => '$quien dijo que está bien.',
      TipoNovedad.tomaOmitida => '$quien marcó que no tomó un medicamento.',
    };
  }
}

/// Una escucha del servidor que no se rinde: si falla o se corta, vuelve a
/// intentarlo a los 3 s, 6 s, 12 s... hasta cada minuto.
class _Escucha {
  _Escucha(this._abrir, this._alLlegar, this._alFallar) {
    _empezar();
  }

  final StreamSubscription<Object?> Function() _abrir;
  final void Function(Object?) _alLlegar;
  final void Function()? _alFallar;

  static const _primeraEspera = Duration(seconds: 3);
  static const _maximaEspera = Duration(minutes: 1);

  StreamSubscription<Object?>? _sub;
  Timer? _reintento;
  Duration _espera = _primeraEspera;
  bool _cancelada = false;

  void _empezar() {
    _sub = _abrir()
      ..onData((dato) {
        _espera = _primeraEspera;
        _alLlegar(dato);
      })
      ..onError((Object _) => _otraVez())
      ..onDone(_otraVez);
  }

  void _otraVez() {
    if (_cancelada || _reintento != null) return;
    _sub?.cancel();
    _alFallar?.call();
    _reintento = Timer(_espera, () {
      _reintento = null;
      if (!_cancelada) _empezar();
    });
    _espera *= 2;
    if (_espera > _maximaEspera) _espera = _maximaEspera;
  }

  void cancelar() {
    _cancelada = true;
    _reintento?.cancel();
    _sub?.cancel();
  }
}
