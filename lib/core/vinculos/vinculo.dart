import 'dart:math';

import '../models/persona_a_cargo.dart';
import '../utils/formato.dart';

enum EstadoInvitacion { pendiente, aceptada, revocada }

/// Invitación de una persona a alguien para que la cuide (RF-05).
/// El código es el secreto: quien lo tenga puede aceptarla mientras esté
/// pendiente y no haya vencido.
class Invitacion {
  const Invitacion({
    required this.codigo,
    required this.personaUid,
    required this.personaNombre,
    required this.personaCelular,
    required this.celularInvitado,
    required this.nombreInvitado,
    required this.estado,
    required this.expiraEn,
    this.cuidadorUid,
  });

  /// Cuánto dura una invitación sin aceptar.
  static const vigencia = Duration(hours: 48);

  static const largoCodigo = 6;

  /// Sin 0/O ni 1/I/L, que se confunden al leerlos en un SMS.
  static const _alfabeto = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  final String codigo;
  final String personaUid;
  final String personaNombre;
  final String personaCelular;

  /// El celular del contacto tal como lo guardó la persona (10 dígitos).
  final String celularInvitado;
  final String nombreInvitado;
  final EstadoInvitacion estado;
  final DateTime expiraEn;

  /// Quién la aceptó. `null` mientras esté pendiente.
  final String? cuidadorUid;

  /// "K7M2QX". Usa el generador seguro del sistema.
  static String nuevoCodigo([Random? azar]) {
    final generador = azar ?? Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < largoCodigo; i++) _alfabeto.codeUnitAt(generador.nextInt(_alfabeto.length)),
    ]);
  }

  /// Lo que escribió la persona: " k7m-2qx " → "K7M2QX".
  static String normalizarCodigo(String texto) => texto.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  static bool codigoValido(String codigo) =>
      codigo.length == largoCodigo && codigo.split('').every(_alfabeto.contains);

  bool vencida(DateTime ahora) => !ahora.isBefore(expiraEn);

  bool vigente(DateTime ahora) => estado == EstadoInvitacion.pendiente && !vencida(ahora);

  /// El SMS que se abre para enviarla.
  String get mensajeSms =>
      'Hola ${primerNombre(nombreInvitado)}, te invito a cuidarme en Rondó. '
      'Instala la app, crea tu cuenta con "Cuido a alguien" y escribe este código: '
      '$codigo. Vence en ${vigencia.inHours} horas.';

  // ---------- Errores (RF-05 y RF-27) ----------

  static const errorCodigo = 'Escribe el código de 6 letras y números que te llegó por SMS.';
  static const errorNoValida = 'Esta invitación ya no es válida.';
  static const errorVencida = 'La invitación expiró. Pide una nueva.';
  static const errorPropia = 'Esta invitación la creaste tú. Debe usarla tu cuidador en su celular.';
  static const errorYaInvitado = 'Ya invitaste a esta persona.';
  static const errorSms = 'No se pudo enviar la invitación. Verifica el número e intenta de nuevo.';

  /// Por qué no se puede aceptar, o `null` si sí se puede.
  /// La misma regla la aplica el servidor (firestore.rules).
  static String? errorAlAceptar(Invitacion? invitacion, {required String cuidadorUid, required DateTime ahora}) {
    if (invitacion == null || invitacion.estado != EstadoInvitacion.pendiente) return errorNoValida;
    if (invitacion.personaUid == cuidadorUid) return errorPropia;
    if (invitacion.vencida(ahora)) return errorVencida;
    return null;
  }
}

/// Vínculo entre una persona y quien la cuida (RF-27). Solo la persona puede
/// cortarlo; desde ese momento el servidor le niega los datos al cuidador.
class Vinculo {
  const Vinculo({
    required this.personaUid,
    required this.cuidadorUid,
    required this.personaNombre,
    required this.personaCelular,
    required this.cuidadorNombre,
    required this.celularInvitado,
    required this.codigo,
    required this.activo,
  });

  final String personaUid;
  final String cuidadorUid;
  final String personaNombre;
  final String personaCelular;
  final String cuidadorNombre;

  /// Con este celular la persona lo tiene en sus contactos.
  final String celularInvitado;

  /// La invitación con la que se creó.
  final String codigo;
  final bool activo;

  String get id => idPara(personaUid, cuidadorUid);

  static String idPara(String personaUid, String cuidadorUid) => '${personaUid}_$cuidadorUid';
}

/// Lo que la persona comparte con sus cuidadores (RF-26). Solo se publica
/// mientras tenga al menos un vínculo activo.
class EstadoCompartido {
  const EstadoCompartido({
    required this.nombre,
    required this.celular,
    required this.enPausa,
    this.ultimoEstoyBien,
    this.cumplimiento,
  });

  final String nombre;
  final String celular;
  final bool enPausa;
  final DateTime? ultimoEstoyBien;
  final int? cumplimiento;

  /// Cómo la ve su cuidador. Sin estado publicado todavía: "Sin datos aún".
  static PersonaACargo comoPersona(Vinculo vinculo, EstadoCompartido? estado) => PersonaACargo(
        id: vinculo.personaUid,
        nombre: estado?.nombre ?? vinculo.personaNombre,
        celular: estado?.celular ?? vinculo.personaCelular,
        estado: switch (estado) {
          null => EstadoPersona.sinDatos,
          EstadoCompartido(enPausa: true) => EstadoPersona.enPausa,
          _ => EstadoPersona.activa,
        },
        ultimoEstoyBien: estado?.ultimoEstoyBien,
        cumplimiento: estado?.cumplimiento,
      );

  @override
  bool operator ==(Object other) =>
      other is EstadoCompartido &&
      other.nombre == nombre &&
      other.celular == celular &&
      other.enPausa == enPausa &&
      other.ultimoEstoyBien == ultimoEstoyBien &&
      other.cumplimiento == cumplimiento;

  @override
  int get hashCode => Object.hash(nombre, celular, enPausa, ultimoEstoyBien, cumplimiento);
}
