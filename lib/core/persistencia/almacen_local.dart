import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'almacen.dart';

/// Guarda los datos en el celular.
/// - Datos generales: `shared_preferences` (archivo privado de la app).
/// - Ficha médica: `flutter_secure_storage`, cifrada con el almacén de llaves
///   de Android (Keystore), porque son datos de salud (Ley 1581).
class AlmacenLocal implements Almacen {
  AlmacenLocal({FlutterSecureStorage? seguro}) : _seguro = seguro ?? const FlutterSecureStorage();

  static const _claveDatos = 'rondo.datos';
  static const _claveFicha = 'rondo.fichaMedica';

  final FlutterSecureStorage _seguro;

  @override
  Future<Map<String, Object?>?> leerDatos() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodificar(prefs.getString(_claveDatos));
  }

  @override
  Future<void> guardarDatos(Map<String, Object?> datos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveDatos, jsonEncode(datos));
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
