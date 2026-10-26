import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'almacen.dart';

/// Guarda los datos en el celular, todo cifrado con `flutter_secure_storage`
/// (almacén de llaves de Android / Keychain de iOS). Los datos generales
/// también llevan datos de salud (medicamentos, tomas, alertas), así que van
/// cifrados igual que la ficha (sección 7.1, Ley 1581).
///
/// Versiones anteriores guardaban los datos generales sin cifrar en
/// `shared_preferences`: si están ahí, se leen y en el siguiente guardado se
/// pasan a lo cifrado y se borra la copia vieja.
class AlmacenLocal implements Almacen {
  AlmacenLocal({FlutterSecureStorage? seguro}) : _seguro = seguro ?? const FlutterSecureStorage();

  static const _claveDatos = 'rondo.datos';
  static const _claveFicha = 'rondo.fichaMedica';

  final FlutterSecureStorage _seguro;

  @override
  Future<Map<String, Object?>?> leerDatos() async {
    final cifrados = await _seguro.read(key: _claveDatos);
    if (cifrados != null) return _decodificar(cifrados);
    final prefs = await SharedPreferences.getInstance();
    return _decodificar(prefs.getString(_claveDatos));
  }

  @override
  Future<void> guardarDatos(Map<String, Object?> datos) async {
    await _seguro.write(key: _claveDatos, value: jsonEncode(datos));
    // Primero se escribe lo cifrado y luego se borra la copia vieja, para no
    // perder nada si la app se cierra en medio.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveDatos);
  }

  @override
  Future<Map<String, Object?>?> leerFicha() async =>
      _decodificar(await _seguro.read(key: _claveFicha));

  @override
  Future<void> guardarFicha(Map<String, Object?>? ficha) async {
    if (ficha == null) {
      await _seguro.delete(key: _claveFicha);
    } else {
      await _seguro.write(key: _claveFicha, value: jsonEncode(ficha));
    }
  }

  /// Si el texto está dañado, se ignora (la app arranca como nueva).
  Map<String, Object?>? _decodificar(String? texto) {
    if (texto == null) return null;
    try {
      final json = jsonDecode(texto);
      return json is Map ? json.cast<String, Object?>() : null;
    } on FormatException {
      return null;
    }
  }
}
