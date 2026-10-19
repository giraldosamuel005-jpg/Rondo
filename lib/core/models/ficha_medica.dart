import 'contacto.dart';

/// Tipos de sangre válidos (RF-23).
enum TipoSangre {
  aPositivo('A+'),
  aNegativo('A-'),
  bPositivo('B+'),
  bNegativo('B-'),
  abPositivo('AB+'),
  abNegativo('AB-'),
  oPositivo('O+'),
  oNegativo('O-');

  const TipoSangre(this.etiqueta);

  /// Como se muestra: "O+", "AB-"...
  final String etiqueta;
}

/// Ficha médica (RF-23): lo que necesita saber quien atiende la emergencia.
/// Son datos sensibles (Ley 1581): solo se guarda con el consentimiento de
/// datos médicos, y al guardarse en el celular debe ir cifrada (sección 7.1).
class FichaMedica {
  FichaMedica({
    required this.tipoSangre,
    required this.celularContactoEmergencia,
    Iterable<String> alergias = const [],
  }) : alergias = List.unmodifiable(limpiarAlergias(alergias));

  final TipoSangre tipoSangre;

  /// Vacía = sin alergias conocidas.
  final List<String> alergias;

  /// Celular de uno de los contactos de RF-04: se elige de la lista, no se
  /// escribe otra vez. El celular sirve de ID porque no se repite.
  final String celularContactoEmergencia;

  /// Busca el contacto en la lista actual. `null` si ya no está (lo quitaron).
  Contacto? contactoEmergenciaEn(List<Contacto> contactos) {
    for (final contacto in contactos) {
      if (contacto.celular == celularContactoEmergencia) return contacto;
    }
    return null;
  }

  // ---------- Validaciones (mensajes de RF-23) ----------

  static const errorIncompleta = 'Completa los campos obligatorios de la ficha médica.';
  static const errorTipoSangre = 'Selecciona un tipo de sangre válido.';
  static const errorContacto = 'Elige un contacto de emergencia de tu lista.';

  static String? validarTipoSangre(TipoSangre? tipo) => tipo == null ? errorTipoSangre : null;

  static String? validarContacto(String? celular, List<Contacto> contactos) {
    final existe = contactos.any((c) => c.celular == celular);
    return existe ? null : errorContacto;
  }

  /// Revisión final antes de guardar. Si falta todo, un solo mensaje general.
  static String? validar({
    required TipoSangre? tipoSangre,
    required String? celularContacto,
    required List<Contacto> contactos,
  }) {
    if (tipoSangre == null && celularContacto == null) return errorIncompleta;
    return validarTipoSangre(tipoSangre) ?? validarContacto(celularContacto, contactos);
  }

  /// Quita espacios, vacías y repetidas (sin importar mayúsculas),
  /// conservando como la escribió la primera vez.
  static List<String> limpiarAlergias(Iterable<String> alergias) {
    final vistas = <String>{};
    return [
      for (final alergia in alergias.map((a) => a.trim()))
        if (alergia.isNotEmpty && vistas.add(alergia.toLowerCase())) alergia,
    ];
  }
}
