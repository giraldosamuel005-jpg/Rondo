/// Dónde se guardan los datos de la app.
///
/// La app solo conoce esta "interfaz": hoy la implementa [AlmacenLocal]
/// (en el celular) y en las pruebas [AlmacenMemoria]. Con Firebase se agrega
/// otra implementación y las pantallas no cambian.
abstract class Almacen {
  /// Datos generales (perfil, contactos, medicamentos, historial...). También
  /// tienen datos de salud: el almacén real los guarda cifrados.
  /// `null` si nunca se ha guardado nada.
  Future<Map<String, Object?>?> leerDatos();
  Future<void> guardarDatos(Map<String, Object?> datos);

  /// Ficha médica: datos sensibles, se guardan aparte y cifrados (Ley 1581).
  Future<Map<String, Object?>?> leerFicha();

  /// Con `null` se borra.
  Future<void> guardarFicha(Map<String, Object?>? ficha);
}

/// Guarda todo en memoria. Solo para pruebas.
class AlmacenMemoria implements Almacen {
  Map<String, Object?>? datos;
  Map<String, Object?>? ficha;

  @override
  Future<Map<String, Object?>?> leerDatos() async => datos;

  @override
  Future<void> guardarDatos(Map<String, Object?> datos) async => this.datos = datos;

  @override
  Future<Map<String, Object?>?> leerFicha() async => ficha;

  @override
  Future<void> guardarFicha(Map<String, Object?>? ficha) async => this.ficha = ficha;
}
