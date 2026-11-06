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
    Iterable<String> enfermedades = const [],
    this.fechaNacimiento,
    String notas = '',
    this.mostrarMedicamentos = false,
  })  : alergias = List.unmodifiable(limpiarLista(alergias)),
        enfermedades = List.unmodifiable(limpiarLista(enfermedades)),
        notas = notas.trim();

  final TipoSangre tipoSangre;

  /// Vacía = sin alergias conocidas.
  final List<String> alergias;

  /// Opcional. Vacía = no registró ninguna (no significa que no tenga).
  final List<String> enfermedades;

  /// Opcional: de aquí sale la edad.
  final DateTime? fechaNacimiento;

  /// Opcional: lo demás que deba saber quien atiende (marcapasos, audífonos...).
  final String notas;

  /// Si la ficha muestra la lista de medicamentos (RF-20). Hay que marcarlo:
  /// quien escanee el QR la vería. Los medicamentos no se copian aquí.
  final bool mostrarMedicamentos;

  /// Celular de uno de los contactos de RF-04: se elige de la lista, no se
  /// escribe otra vez. El celular sirve de ID porque no se repite.
  final String celularContactoEmergencia;

  /// Las más frecuentes, para marcar con un toque sin escribir.
  static const enfermedadesComunes = [
    'Diabetes',
    'Hipertensión',
    'Problemas del corazón',
    'Asma',
    'EPOC',
    'Epilepsia',
    'Párkinson',
    'Alzheimer',
  ];

  static const limiteNotas = 300;

  /// Años cumplidos en [ahora]. `null` si no puso su fecha de nacimiento.
  int? edad(DateTime ahora) {
    final nacio = fechaNacimiento;
    if (nacio == null) return null;
    final yaCumplio = ahora.month > nacio.month || (ahora.month == nacio.month && ahora.day >= nacio.day);
    return ahora.year - nacio.year - (yaCumplio ? 0 : 1);
  }

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
  static List<String> limpiarLista(Iterable<String> textos) {
    final vistas = <String>{};
    return [
      for (final texto in textos.map((t) => t.trim()))
        if (texto.isNotEmpty && vistas.add(texto.toLowerCase())) texto,
    ];
  }

  /// Agrega una enfermedad escrita a mano. Si es una de las comunes, la deja
  /// como aparece en la lista ("diabetes" marca "Diabetes").
  static List<String> conEnfermedad(Iterable<String> actuales, String nueva) {
    final escrita = nueva.trim().toLowerCase();
    final comun = enfermedadesComunes.where((e) => e.toLowerCase() == escrita).firstOrNull;
    return limpiarLista([...actuales, comun ?? nueva]);
  }
}
