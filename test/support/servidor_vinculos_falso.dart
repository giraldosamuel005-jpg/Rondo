import 'dart:async';

import 'package:rondo/core/vinculos/ficha_publica.dart';
import 'package:rondo/core/vinculos/servicio_vinculos.dart';
import 'package:rondo/core/vinculos/vinculo.dart';

/// Un "Firestore" en memoria compartido por varios celulares de prueba.
/// Aplica las mismas reglas que firestore.rules en lo que importa.
class ServidorFalso {
  ServidorFalso({DateTime Function()? reloj}) : reloj = reloj ?? DateTime.now;

  final DateTime Function() reloj;
  final Map<String, Invitacion> invitaciones = {};
  final Map<String, Vinculo> vinculos = {};
  final Map<String, EstadoCompartido> estados = {};

  /// fichas/{token}: el dueño y la ficha, o `null` si está revocada.
  final Map<String, ({String duenoUid, FichaPublica? ficha})> fichas = {};
  final Map<String, List<DateTime>> consultas = {};

  /// Lo que haría la página web al abrir el QR.
  void abrirFicha(String token, DateTime en) {
    final f = fichas[token];
    if (f == null || f.ficha == null) throw StateError('permission-denied');
    (consultas[token] ??= []).add(en);
    _avisar();
  }
  final _cambios = StreamController<void>.broadcast();

  /// Si es `true`, todo falla como sin internet.
  bool sinRed = false;

  void _avisar() => _cambios.add(null);

  /// Un celular con su propia sesión anónima.
  ServicioFalso celular(String uid) => ServicioFalso(this, uid);
}

class ServicioFalso implements ServicioVinculos {
  ServicioFalso(this._servidor, this._uid);

  final ServidorFalso _servidor;
  final String _uid;
  bool sesionAbierta = false;

  void _red() {
    if (_servidor.sinRed) throw StateError('sin red');
  }

  /// Emite ya y en cada cambio del servidor.
  Stream<T> _vigilar<T>(T Function() leer) async* {
    yield leer();
    await for (final _ in _servidor._cambios.stream) {
      yield leer();
    }
  }

  @override
  Future<String> iniciarSesion() async {
    _red();
    sesionAbierta = true;
    return _uid;
  }

  @override
  Future<void> cerrarSesion() async => sesionAbierta = false;

  @override
  Future<void> crearInvitacion(Invitacion invitacion) async {
    _red();
    if (_servidor.invitaciones.containsKey(invitacion.codigo)) throw const CodigoOcupado();
    if (invitacion.personaUid != _uid) throw StateError('permission-denied');
    _servidor.invitaciones[invitacion.codigo] = invitacion;
    _servidor._avisar();
  }

  @override
  Future<void> revocarInvitacion(String codigo) async {
    _red();
    final i = _servidor.invitaciones[codigo]!;
    if (i.personaUid != _uid) throw StateError('permission-denied');
    _servidor.invitaciones[codigo] = _con(i, EstadoInvitacion.revocada);
    _servidor._avisar();
  }

  @override
  Future<Vinculo> aceptarInvitacion(String codigo, {required String cuidadorUid, required String cuidadorNombre}) async {
    _red();
    final i = _servidor.invitaciones[codigo];
    final error = Invitacion.errorAlAceptar(i, cuidadorUid: _uid, ahora: _servidor.reloj());
    if (error != null) throw ErrorVinculo(error);
    _servidor.invitaciones[codigo] = _con(i!, EstadoInvitacion.aceptada, cuidadorUid: _uid);
    final v = Vinculo(
      personaUid: i.personaUid,
      cuidadorUid: _uid,
      personaNombre: i.personaNombre,
      personaCelular: i.personaCelular,
      cuidadorNombre: cuidadorNombre,
      celularInvitado: i.celularInvitado,
      codigo: codigo,
      activo: true,
    );
    _servidor.vinculos[v.id] = v;
    _servidor._avisar();
    return v;
  }

  @override
  Future<void> revocarVinculo(Vinculo vinculo) async {
    _red();
    if (vinculo.personaUid != _uid) throw StateError('permission-denied');
    final v = _servidor.vinculos[vinculo.id]!;
    _servidor.vinculos[v.id] = Vinculo(
      personaUid: v.personaUid,
      cuidadorUid: v.cuidadorUid,
      personaNombre: v.personaNombre,
      personaCelular: v.personaCelular,
      cuidadorNombre: v.cuidadorNombre,
      celularInvitado: v.celularInvitado,
      codigo: v.codigo,
      activo: false,
    );
    final i = _servidor.invitaciones[v.codigo]!;
    _servidor.invitaciones[v.codigo] = _con(i, EstadoInvitacion.revocada, cuidadorUid: i.cuidadorUid);
    _servidor._avisar();
  }

  @override
  Stream<List<Invitacion>> invitacionesDe(String personaUid) =>
      _vigilar(() => [for (final i in _servidor.invitaciones.values) if (i.personaUid == personaUid) i]);

  @override
  Stream<List<Vinculo>> cuidadoresDe(String personaUid) =>
      _vigilar(() => [for (final v in _servidor.vinculos.values) if (v.personaUid == personaUid) v]);

  @override
  Stream<List<Vinculo>> personasDe(String cuidadorUid) => _vigilar(
      () => [for (final v in _servidor.vinculos.values) if (v.cuidadorUid == cuidadorUid && v.activo) v]);

  /// Como las reglas: solo la persona o un cuidador con vínculo activo.
  @override
  Stream<EstadoCompartido?> estadoDe(String personaUid) => _vigilar(() {
        final vinculo = _servidor.vinculos[Vinculo.idPara(personaUid, _uid)];
        final puede = personaUid == _uid || (vinculo?.activo ?? false);
        return puede ? _servidor.estados[personaUid] : null;
      });

  @override
  Future<void> publicarEstado(String personaUid, EstadoCompartido? estado) async {
    if (personaUid != _uid) throw StateError('permission-denied');
    if (estado == null) {
      _servidor.estados.remove(personaUid);
    } else {
      _servidor.estados[personaUid] = estado;
    }
    _servidor._avisar();
  }

  @override
  Future<void> publicarFicha(String personaUid, String token, FichaPublica ficha) async {
    _red();
    final actual = _servidor.fichas[token];
    if (personaUid != _uid || (actual != null && (actual.duenoUid != _uid || actual.ficha == null))) {
      throw StateError('permission-denied');
    }
    _servidor.fichas[token] = (duenoUid: _uid, ficha: ficha);
    _servidor._avisar();
  }

  @override
  Future<void> revocarFicha(String personaUid, String token) async {
    _red();
    final actual = _servidor.fichas[token];
    if (personaUid != _uid || (actual != null && actual.duenoUid != _uid)) throw StateError('permission-denied');
    _servidor.fichas[token] = (duenoUid: _uid, ficha: null);
    _servidor._avisar();
  }

  @override
  Stream<List<DateTime>> consultasDe(String token) => _vigilar(() {
        if (_servidor.fichas[token]?.duenoUid != _uid) throw StateError('permission-denied');
        return [...?_servidor.consultas[token]]..sort((a, b) => b.compareTo(a));
      });

  static Invitacion _con(Invitacion i, EstadoInvitacion estado, {String? cuidadorUid}) => Invitacion(
        codigo: i.codigo,
        personaUid: i.personaUid,
        personaNombre: i.personaNombre,
        personaCelular: i.personaCelular,
        celularInvitado: i.celularInvitado,
        nombreInvitado: i.nombreInvitado,
        estado: estado,
        expiraEn: i.expiraEn,
        cuidadorUid: cuidadorUid,
      );
}
