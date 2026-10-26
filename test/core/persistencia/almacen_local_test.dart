import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rondo/core/persistencia/almacen_local.dart';

void main() {
  const clave = 'rondo.datos';
  final datos = {
    'nombre': 'María',
    'medicamentos': [
      {'id': 'm1', 'nombre': 'Losartán'},
    ],
  };

  /// Lo que quedó en cada almacén del celular.
  Future<String?> enPrefs() async => (await SharedPreferences.getInstance()).getString(clave);
  Future<String?> enSeguro() => const FlutterSecureStorage().read(key: clave);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('los datos generales (con los medicamentos) se guardan cifrados', () async {
    await AlmacenLocal().guardarDatos(datos);

    expect(await enSeguro(), contains('Losartán'));
    expect(await enPrefs(), isNull);
    expect(await AlmacenLocal().leerDatos(), datos);
  });

  test('los datos que estaban sin cifrar se siguen leyendo', () async {
    SharedPreferences.setMockInitialValues({clave: jsonEncode(datos)});

    expect(await AlmacenLocal().leerDatos(), datos);
  });

  test('al guardar, se pasan a lo cifrado y se borra la copia sin cifrar', () async {
    SharedPreferences.setMockInitialValues({clave: jsonEncode(datos)});
    final almacen = AlmacenLocal();

    await almacen.guardarDatos((await almacen.leerDatos())!);

    expect(await enPrefs(), isNull);
    expect(await enSeguro(), contains('Losartán'));
  });

  test('si hay datos cifrados, se ignora una copia vieja sin cifrar', () async {
    SharedPreferences.setMockInitialValues({clave: jsonEncode({'nombre': 'Vieja'})});
    FlutterSecureStorage.setMockInitialValues({clave: jsonEncode(datos)});

    expect((await AlmacenLocal().leerDatos())!['nombre'], 'María');
  });
}
