import '../state/app_state.dart';

/// Lo que ve quien escanea el QR (RF-24): la ficha médica ya armada, con los
/// nombres y textos listos para mostrar. Se guarda en el servidor bajo el token
/// del QR, en `fichas/{token}`, y la lee la página web pública.
///
/// Solo valores de JSON (textos, listas), así se comparan fácil y la página
/// no tiene que convertir nada.
class FichaPublica {
  const FichaPublica(this.datos);

  final Map<String, Object?> datos;

  /// La ficha de [estado] como se publica. `null` si no hay nada que publicar:
  /// sin ficha, sin QR o en una cuenta de cuidador.
  static FichaPublica? de(AppState estado) {
    final ficha = estado.fichaMedica;
    if (ficha == null || estado.codigoQr == null || !estado.usaFichaMedica) return null;
    final contacto = ficha.contactoEmergenciaEn(estado.contactos);
    final nacio = ficha.fechaNacimiento;
    return FichaPublica({
      'nombre': estado.nombre,
      // "1950-03-07": la página calcula la edad del día en que la abren.
      'fechaNacimiento': nacio == null
          ? null
          : '${nacio.year.toString().padLeft(4, '0')}-${_dos(nacio.month)}-${_dos(nacio.day)}',
      'tipoSangre': ficha.tipoSangre.etiqueta,
      'alergias': ficha.alergias,
      'enfermedades': ficha.enfermedades,
      // Solo si la persona lo marcó (RF-20): quien escanee los vería.
      'medicamentos': [
        if (ficha.mostrarMedicamentos)
          for (final m in estado.medicamentos) '${m.nombre} · ${m.dosis} · ${m.frecuenciaTexto}',
      ],
      'notas': ficha.notas,
      'contacto': contacto == null
          ? null
          : {'nombre': contacto.nombre, 'relacion': contacto.relacion, 'celular': contacto.celular},
    });
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) => other is FichaPublica && _iguales(datos, other.datos);

  @override
  int get hashCode => datos.length;

  static bool _iguales(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length && a.keys.every((k) => b.containsKey(k) && _iguales(a[k], b[k]));
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_iguales(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
