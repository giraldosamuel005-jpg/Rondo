import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../persistencia/serializacion.dart' show enumPorNombre;
import 'ficha_publica.dart';
import 'servicio_vinculos.dart';
import 'vinculo.dart';

/// [ServicioVinculos] con Firebase: sesión anónima + Firestore.
/// Las reglas de `firestore.rules` son las que de verdad protegen los datos:
/// lo que se valida aquí es para dar mensajes claros.
///
/// Colecciones:
/// - `invitaciones/{codigo}`
/// - `vinculos/{personaUid}_{cuidadorUid}`
/// - `personas/{uid}`: lo que la persona comparte con sus cuidadores.
/// - `fichas/{token}`: la ficha médica pública del QR, y en `consultas` cada
///   vez que alguien la abrió.
class ServicioVinculosFirebase implements ServicioVinculos {
  ServicioVinculosFirebase({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Sin internet, las transacciones fallan solas; esto es por si se cuelga.
  static const _espera = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _invitaciones => _db.collection('invitaciones');
  CollectionReference<Map<String, dynamic>> get _vinculos => _db.collection('vinculos');
  CollectionReference<Map<String, dynamic>> get _personas => _db.collection('personas');

  @override
  Future<String> iniciarSesion() async {
    final actual = _auth.currentUser;
    if (actual != null) return actual.uid;
    final credencial = await _auth.signInAnonymously().timeout(_espera);
    return credencial.user!.uid;
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<void> crearInvitacion(Invitacion invitacion) async {
    final ref = _invitaciones.doc(invitacion.codigo);
    // Transacción y no un simple set: sin internet falla en vez de quedar en
    // cola, y así la persona sabe que la invitación no se creó.
    await _db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) throw const CodigoOcupado();
      tx.set(ref, {
        ..._invitacionAMapa(invitacion),
        'creadaEn': FieldValue.serverTimestamp(),
      });
    }).timeout(_espera);
  }

  @override
  Future<void> revocarInvitacion(String codigo) => _db.runTransaction((tx) async {
        tx.update(_invitaciones.doc(codigo), {'estado': EstadoInvitacion.revocada.name});
      }).timeout(_espera);

  @override
  Future<Vinculo> aceptarInvitacion(
    String codigo, {
    required String cuidadorUid,
    required String cuidadorNombre,
  }) {
    final ref = _invitaciones.doc(codigo);
    final aceptada = _db.runTransaction((tx) async {
      final foto = await tx.get(ref);
      final invitacion = foto.exists ? _invitacionDe(foto.id, foto.data()!) : null;
      final error = Invitacion.errorAlAceptar(invitacion, cuidadorUid: cuidadorUid, ahora: DateTime.now());
      if (error != null) throw ErrorVinculo(error);

      final vinculo = Vinculo(
        personaUid: invitacion!.personaUid,
        cuidadorUid: cuidadorUid,
        personaNombre: invitacion.personaNombre,
        personaCelular: invitacion.personaCelular,
        cuidadorNombre: cuidadorNombre,
        celularInvitado: invitacion.celularInvitado,
        codigo: codigo,
        activo: true,
      );
      tx.update(ref, {
        'estado': EstadoInvitacion.aceptada.name,
        'cuidadorUid': cuidadorUid,
      });
      tx.set(_vinculos.doc(vinculo.id), {
        ..._vinculoAMapa(vinculo),
        'creadoEn': FieldValue.serverTimestamp(),
      });
      return vinculo;
    }).timeout(_espera);
    // Si el servidor la rechaza (por ejemplo, venció según su reloj).
    return aceptada.catchError(
      (Object _) => throw const ErrorVinculo(Invitacion.errorNoValida),
      test: (e) => e is FirebaseException && e.code == 'permission-denied',
    );
  }

  @override
  Future<void> revocarVinculo(Vinculo vinculo) => _db.runTransaction((tx) async {
        tx.update(_vinculos.doc(vinculo.id), {'activo': false});
        tx.update(_invitaciones.doc(vinculo.codigo), {'estado': EstadoInvitacion.revocada.name});
      }).timeout(_espera);

  @override
  Stream<List<Invitacion>> invitacionesDe(String personaUid) => _invitaciones
      .where('personaUid', isEqualTo: personaUid)
      .snapshots()
      .map((q) => [for (final d in q.docs) ?_invitacionDe(d.id, d.data())]);

  @override
  Stream<List<Vinculo>> cuidadoresDe(String personaUid) => _vinculos
      .where('personaUid', isEqualTo: personaUid)
      .snapshots()
      .map((q) => [for (final d in q.docs) ?_vinculoDe(d.data())]);

  @override
  Stream<List<Vinculo>> personasDe(String cuidadorUid) => _vinculos
      .where('cuidadorUid', isEqualTo: cuidadorUid)
      .where('activo', isEqualTo: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) ?_vinculoDe(d.data())]);

  @override
  Stream<EstadoCompartido?> estadoDe(String personaUid) =>
      _personas.doc(personaUid).snapshots().map((d) => d.exists ? _estadoDe(d.data()!) : null);

  @override
  Future<void> publicarEstado(String personaUid, EstadoCompartido? estado) {
    final ref = _personas.doc(personaUid);
    if (estado == null) return ref.delete();
    return ref.set({
      'nombre': estado.nombre,
      'celular': estado.celular,
      'enPausa': estado.enPausa,
      'ultimoEstoyBien': _fecha(estado.ultimoEstoyBien),
      'cumplimiento': estado.cumplimiento,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Ficha médica del QR ----------
  // Un `set` normal y no una transacción: sin internet queda en cola y se
  // envía solo cuando vuelva la señal.

  CollectionReference<Map<String, dynamic>> get _fichas => _db.collection('fichas');

  @override
  Future<void> publicarFicha(String personaUid, String token, FichaPublica ficha) => _fichas.doc(token).set({
        ...ficha.datos,
        'duenoUid': personaUid,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

  /// Se reemplaza por un documento sin datos médicos que solo dice "revocada".
  @override
  Future<void> revocarFicha(String personaUid, String token) => _fichas.doc(token).set({
        'duenoUid': personaUid,
        'revocada': true,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

  @override
  Stream<List<DateTime>> consultasDe(String token) => _fichas
      .doc(token)
      .collection('consultas')
      .orderBy('en', descending: true)
      .limit(20)
      .snapshots()
      .map((q) => [
            for (final d in q.docs)
              if (d.data()['en'] case final Timestamp en) en.toDate(),
          ]);

  // ---------- Mapas de Firestore ----------

  static Timestamp? _fecha(DateTime? fecha) => fecha == null ? null : Timestamp.fromDate(fecha);

  static Map<String, Object?> _invitacionAMapa(Invitacion i) => {
        'personaUid': i.personaUid,
        'personaNombre': i.personaNombre,
        'personaCelular': i.personaCelular,
        'celularInvitado': i.celularInvitado,
        'nombreInvitado': i.nombreInvitado,
        'estado': i.estado.name,
        'expiraEn': _fecha(i.expiraEn),
      };

  static Invitacion? _invitacionDe(String codigo, Map<String, dynamic> m) {
    final estado = enumPorNombre(EstadoInvitacion.values, m['estado']);
    final expira = m['expiraEn'];
    if (estado == null || expira is! Timestamp || m['personaUid'] is! String) return null;
    return Invitacion(
      codigo: codigo,
      personaUid: m['personaUid'] as String,
      personaNombre: m['personaNombre'] as String? ?? '',
      personaCelular: m['personaCelular'] as String? ?? '',
      celularInvitado: m['celularInvitado'] as String? ?? '',
      nombreInvitado: m['nombreInvitado'] as String? ?? '',
      estado: estado,
      expiraEn: expira.toDate(),
      cuidadorUid: m['cuidadorUid'] as String?,
    );
  }

  static Map<String, Object?> _vinculoAMapa(Vinculo v) => {
        'personaUid': v.personaUid,
        'cuidadorUid': v.cuidadorUid,
        'personaNombre': v.personaNombre,
        'personaCelular': v.personaCelular,
        'cuidadorNombre': v.cuidadorNombre,
        'celularInvitado': v.celularInvitado,
        'codigo': v.codigo,
        'activo': v.activo,
      };

  static Vinculo? _vinculoDe(Map<String, dynamic> m) {
    if (m['personaUid'] is! String || m['cuidadorUid'] is! String || m['codigo'] is! String) return null;
    return Vinculo(
      personaUid: m['personaUid'] as String,
      cuidadorUid: m['cuidadorUid'] as String,
      personaNombre: m['personaNombre'] as String? ?? '',
      personaCelular: m['personaCelular'] as String? ?? '',
      cuidadorNombre: m['cuidadorNombre'] as String? ?? '',
      celularInvitado: m['celularInvitado'] as String? ?? '',
      codigo: m['codigo'] as String,
      activo: m['activo'] == true,
    );
  }

  static EstadoCompartido _estadoDe(Map<String, dynamic> m) => EstadoCompartido(
        nombre: m['nombre'] as String? ?? '',
        celular: m['celular'] as String? ?? '',
        enPausa: m['enPausa'] == true,
        ultimoEstoyBien: (m['ultimoEstoyBien'] as Timestamp?)?.toDate(),
        cumplimiento: (m['cumplimiento'] as num?)?.toInt(),
      );
}
