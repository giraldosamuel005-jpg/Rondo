import 'dart:async';

import 'package:flutter/foundation.dart';

import '../alertas/alerta_compartida.dart';
import '../models/contacto.dart';
import '../state/app_state.dart';
import 'ficha_publica.dart';
import 'servicio_vinculos.dart';
import 'vinculo.dart';

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
class Vinculos extends ChangeNotifier {
  Vinculos(this._servicio, this._estado, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now {
    _estado.addListener(_alCambiarEstado);
    _alCambiarEstado();
  }

  static const errorConexion = 'No pudimos conectarnos. Revisa tu internet e intenta otra vez.';

  final ServicioVinculos _servicio;
  final AppState _estado;
  final DateTime Function() _reloj;

  ({String celular, bool cuidador})? _sesion;
  String? _uid;
  Future<String>? _conectando;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _cerrado = false;

  // Persona
  List<Invitacion> _invitaciones = const [];
  List<Vinculo> _cuidadores = const [];
  EstadoCompartido? _publicado;

  // Persona: ficha del QR (RF-24, RF-25)
  String? _fichaToken;
  FichaPublica? _fichaPublicada;
  StreamSubscription<List<DateTime>>? _subConsultas;
  List<DateTime> _consultas = const [];

  // Cuidador
  List<Vinculo> _personas = const [];
  final Map<String, StreamSubscription<EstadoCompartido?>> _subsEstado = {};
  final Map<String, EstadoCompartido?> _estados = {};
  final List<String> _retirados = [];

  // Cuidador: alertas de cada persona (RF-15, RF-26)
  final Map<String, StreamSubscription<List<AlertaCompartida>>> _subsAlertas = {};
  final Map<String, List<AlertaCompartida>> _alertas = {};

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

  List<Vinculo> get cuidadoresActivos => [for (final v in _cuidadores) if (v.activo) v];

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

  /// Cuidador: nombres de quienes dejaron de compartir con él (RF-27).
  List<String> get retirados => List.unmodifiable(_retirados);

  void descartarRetirados() {
    _retirados.clear();
    notifyListeners();
  }

  // ---------- Acciones de la persona ----------

  /// Crea la invitación. Después hay que enviar el SMS con [Invitacion.mensajeSms].
  Future<Invitacion> invitar(Contacto contacto) async {
    if (vinculoCon(contacto.celular) != null || invitacionPendiente(contacto.celular) != null) {
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
      _invitaciones = [for (final i in _invitaciones) if (i.codigo != invitacion.codigo) i, invitacion];
      notifyListeners();
      return invitacion;
    }
    throw const ErrorVinculo(errorConexion);
  }

  Future<void> cancelarInvitacion(Invitacion invitacion) =>
      _accion(() => _servicio.revocarInvitacion(invitacion.codigo));

  /// RF-27: desde este momento el cuidador ya no ve nada.
  Future<void> dejarDeCompartir(Vinculo vinculo) => _accion(() => _servicio.revocarVinculo(vinculo));

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
  /// Devuelve `true` cuando el servidor la recibió. Sin cuidadores no sube nada.
  Future<bool> publicarAlerta({required DateTime fecha, Posicion? posicion}) async {
    final sesion = _sesion;
    if (sesion == null || sesion.cuidador) return false;
    final uid = await _conectar();
    if (cuidadoresActivos.isEmpty) return false;
    await _servicio.publicarAlerta(
      uid,
      AlertaCompartida(id: AlertaCompartida.nuevoId(_reloj()), fecha: fecha, posicion: posicion),
    );
    return true;
  }

  // ---------- Acciones del cuidador ----------

  /// El cuidador atendió las alertas de esa persona. Sin internet queda en
  /// cola y se envía después; la pantalla no tiene que esperar.
  void atenderAlertas(String personaUid) {
    final uid = _uid;
    if (uid == null) return;
    for (final a in _alertas[personaUid] ?? const <AlertaCompartida>[]) {
      if (!a.atendida) _servicio.atenderAlerta(personaUid, a.id, cuidadorUid: uid).ignore();
    }
  }

  /// Acepta con el código que le llegó por SMS. Devuelve el vínculo creado.
  Future<Vinculo> aceptar(String texto) async {
    final codigo = Invitacion.normalizarCodigo(texto);
    if (!Invitacion.codigoValido(codigo)) throw const ErrorVinculo(Invitacion.errorCodigo);
    final uid = await _uidOError();
    try {
      return await _servicio.aceptarInvitacion(codigo, cuidadorUid: uid, cuidadorNombre: _estado.nombre);
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
    return _conectando ??= _servicio.iniciarSesion().then(
      (uid) {
        _conectando = null;
        if (!_cerrado && _sesion != null && _uid == null) {
          _uid = uid;
          _escuchar(uid, comoCuidador: _sesion!.cuidador);
          if (!_sesion!.cuidador) _publicarFichaSiCambio();
        }
        return uid;
      },
      onError: (Object error) {
        _conectando = null;
        throw error;
      },
    );
  }

  void _escuchar(String uid, {required bool comoCuidador}) {
    if (comoCuidador) {
      _subs.add(_servicio.personasDe(uid).listen(_alCambiarPersonas, onError: _ignorar));
      return;
    }
    _subs
      ..add(_servicio.invitacionesDe(uid).listen((lista) {
        _invitaciones = lista;
        notifyListeners();
      }, onError: _ignorar))
      ..add(_servicio.cuidadoresDe(uid).listen((lista) {
        _cuidadores = lista;
        _publicarSiCambio();
        notifyListeners();
      }, onError: _ignorar));
  }

  /// Sin permiso (vínculo cortado) o sin red: se sigue con lo que había.
  static void _ignorar(Object _) {}

  void _alCambiarEstado() {
    if (_cerrado) return;
    final celular = _estado.celular;
    final sesion = (celular == null || _estado.tipo == null) ? null : (celular: celular, cuidador: _estado.esCuidador);

    if (sesion != _sesion) {
      final anterior = _sesion;
      _sesion = sesion;
      _reiniciar(personaCerroSesion: anterior != null && !anterior.cuidador && sesion == null);
    }
    if (_sesion == null) return;
    if (_uid == null) {
      if (_conectando == null) _conectar().ignore(); // Sin red: se reintenta en el próximo cambio
    } else if (!_sesion!.cuidador) {
      _publicarSiCambio();
      _publicarFichaSiCambio();
    }
  }

  /// Cambió la sesión: se olvida todo lo de la anterior.
  void _reiniciar({required bool personaCerroSesion}) {
    final uidAnterior = _uid;
    final cuidadores = cuidadoresActivos;
    final ahora = _reloj();
    final pendientes = [for (final i in _invitaciones) if (i.vigente(ahora)) i];
    final habiaPublicado = _publicado != null;
    final fichaToken = _fichaToken;

    for (final s in _subs) {
      s.cancel();
    }
    _subConsultas?.cancel();
    _subConsultas = null;
    _consultas = const [];
    _fichaToken = null;
    _fichaPublicada = null;
    for (final s in _subsEstado.values) {
      s.cancel();
    }
    for (final s in _subsAlertas.values) {
      s.cancel();
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
      unawaited(() async {
        // Cerrar sesión borra la cuenta: también deja de compartir (Ley 1581).
        if (personaCerroSesion) {
          for (final v in cuidadores) {
            await _servicio.revocarVinculo(v).catchError((_) {});
          }
          for (final i in pendientes) {
            await _servicio.revocarInvitacion(i.codigo).catchError((_) {});
          }
          if (habiaPublicado) await _servicio.publicarEstado(uidAnterior, null).catchError((_) {});
          // Y el QR que tenga impreso ya no muestra nada.
          if (fichaToken != null) await _servicio.revocarFicha(uidAnterior, fichaToken).catchError((_) {});
          await _servicio.borrarAlertas(uidAnterior).catchError((_) {});
        }
        await _servicio.cerrarSesion().catchError((_) {});
      }());
    }
    notifyListeners();
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
          );
    if (nuevo == _publicado) return;
    _publicado = nuevo;
    _servicio.publicarEstado(uid, nuevo).ignore(); // Sin red, Firestore lo envía después
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
    if (token != null) {
      // Las consultas se leen cuando la ficha ya existe: antes, las reglas no
      // saben de quién es y no dejan leerlas.
      _servicio.publicarFicha(uid, token, ficha!).then((_) {
        if (_fichaToken == token && _subConsultas == null && !_cerrado) _escucharConsultas(token);
      }, onError: _ignorar);
    }
    if (anterior != null && anterior != token) {
      _servicio.revocarFicha(uid, anterior).ignore();
      _subConsultas?.cancel();
      _subConsultas = null;
      _consultas = const [];
      notifyListeners();
    }
  }

  void _escucharConsultas(String token) {
    _subConsultas = _servicio.consultasDe(token).listen((lista) {
      _consultas = lista;
      notifyListeners();
    }, onError: _ignorar);
  }

  // ---------- Cuidador: las personas que cuida ----------

  void _alCambiarPersonas(List<Vinculo> nuevos) {
    final siguen = {for (final v in nuevos) v.personaUid};
    for (final antes in _personas) {
      if (siguen.contains(antes.personaUid)) continue;
      _retirados.add(_estados[antes.personaUid]?.nombre ?? antes.personaNombre);
      _subsEstado.remove(antes.personaUid)?.cancel();
      _subsAlertas.remove(antes.personaUid)?.cancel();
      _estados.remove(antes.personaUid);
      _alertas.remove(antes.personaUid);
    }
    for (final v in nuevos) {
      _subsEstado.putIfAbsent(
        v.personaUid,
        () => _servicio.estadoDe(v.personaUid).listen((estado) {
          _estados[v.personaUid] = estado;
          _ponerPersonas();
        }, onError: _ignorar),
      );
      _subsAlertas.putIfAbsent(
        v.personaUid,
        () => _servicio.alertasDe(v.personaUid).listen((lista) => _alCambiarAlertas(v.personaUid, lista),
            onError: _ignorar),
      );
    }
    _personas = nuevos;
    _ponerPersonas();
    notifyListeners();
  }

  void _alCambiarAlertas(String personaUid, List<AlertaCompartida> lista) {
    _alertas[personaUid] = lista;
    final ahora = _reloj();
    var hayNueva = false;
    for (final a in lista) {
      final primeraVez = _alertasVistas.add('$personaUid/${a.id}');
      if (primeraVez && !a.atendida && ahora.difference(a.fecha) < alertaReciente) hayNueva = true;
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
          ),
      ]);

  @override
  void dispose() {
    _cerrado = true;
    _estado.removeListener(_alCambiarEstado);
    for (final s in _subs) {
      s.cancel();
    }
    for (final s in _subsEstado.values) {
      s.cancel();
    }
    for (final s in _subsAlertas.values) {
      s.cancel();
    }
    _subConsultas?.cancel();
    _alertasNuevas.close();
    super.dispose();
  }
}
