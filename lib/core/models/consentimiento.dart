/// Lo que la persona autoriza por separado (RF-30, Ley 1581 de 2012).
/// Sin consentimiento, la función que depende de él no se activa.
enum TipoConsentimiento {
  /// Enviar la ubicación dentro de una alerta.
  ubicacion,

  /// Guardar la ficha médica (datos sensibles).
  datosMedicos,

  /// Usar la cámara en el modo conductor (microsueños).
  camara,
}
