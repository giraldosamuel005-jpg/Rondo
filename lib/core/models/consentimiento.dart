/// Lo que la persona autoriza por separado (RF-30, Ley 1581 de 2012).
/// Sin consentimiento, la función que depende de él no se activa.
enum TipoConsentimiento {
  /// Enviar la ubicación dentro de una alerta.
  ubicacion,

  /// Que sus cuidadores vinculados vean dónde está mientras su ronda esté
  /// activa (RF-26). Aparte del anterior: se puede dar uno sin el otro.
  ubicacionCuidadores,

  /// Guardar la ficha médica (datos sensibles).
  datosMedicos,
}
