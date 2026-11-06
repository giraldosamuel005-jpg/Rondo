import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/ficha_medica.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/persistencia/serializacion.dart';
import 'package:rondo/core/state/app_state.dart';

void main() {
  const ana = Contacto(nombre: 'Ana', celular: '3001112233');
  const luis = Contacto(nombre: 'Luis', celular: '3104445566');
  const contactos = [ana, luis];

  group('tipo de sangre', () {
    test('son los 8 del documento, con su etiqueta', () {
      expect(
        TipoSangre.values.map((t) => t.etiqueta),
        ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
      );
    });
  });

  group('alergias', () {
    test('quita espacios, vacías y repetidas sin importar mayúsculas', () {
      expect(
        FichaMedica.limpiarLista([' Penicilina ', '', 'maní', 'PENICILINA', '   ']),
        ['Penicilina', 'maní'],
      );
    });

    test('la ficha guarda las alergias ya limpias y no se pueden cambiar desde afuera', () {
      final ficha = FichaMedica(
        tipoSangre: TipoSangre.oPositivo,
        celularContactoEmergencia: ana.celular,
        alergias: ['Polen', 'polen'],
      );
      expect(ficha.alergias, ['Polen']);
      expect(() => ficha.alergias.add('Otra'), throwsUnsupportedError);
    });

    test('sin alergias es válido', () {
      final ficha = FichaMedica(tipoSangre: TipoSangre.aNegativo, celularContactoEmergencia: ana.celular);
      expect(ficha.alergias, isEmpty);
    });
  });

  group('datos opcionales', () {
    FichaMedica fichaCon({DateTime? nacio, String notas = '', List<String> enfermedades = const []}) => FichaMedica(
          tipoSangre: TipoSangre.oPositivo,
          celularContactoEmergencia: ana.celular,
          fechaNacimiento: nacio,
          notas: notas,
          enfermedades: enfermedades,
        );

    test('la edad cambia justo el día del cumpleaños', () {
      final ficha = fichaCon(nacio: DateTime(1950, 3, 15));
      expect(ficha.edad(DateTime(2026, 3, 14)), 75);
      expect(ficha.edad(DateTime(2026, 3, 15)), 76);
      expect(ficha.edad(DateTime(2026, 2, 28)), 75);
      expect(ficha.edad(DateTime(2026, 11, 5)), 76);
    });

    test('sin fecha de nacimiento no hay edad', () {
      expect(fichaCon().edad(DateTime(2026)), isNull);
    });

    test('limpia las notas y las enfermedades', () {
      final ficha = fichaCon(notas: '  Uso marcapasos \n', enfermedades: ['Asma', ' asma ', '']);
      expect(ficha.notas, 'Uso marcapasos');
      expect(ficha.enfermedades, ['Asma']);
    });

    test('una enfermedad común escrita a mano queda como en la lista', () {
      expect(FichaMedica.conEnfermedad(const [], ' diabetes '), ['Diabetes']);
      expect(FichaMedica.conEnfermedad(['Diabetes'], 'DIABETES'), ['Diabetes']);
      expect(FichaMedica.conEnfermedad(['Asma'], 'Artritis'), ['Asma', 'Artritis']);
    });

    test('por defecto no muestra los medicamentos', () {
      expect(fichaCon().mostrarMedicamentos, isFalse);
    });

    test('todo sobrevive a guardar y cargar', () {
      final ficha = FichaMedica(
        tipoSangre: TipoSangre.aPositivo,
        celularContactoEmergencia: ana.celular,
        enfermedades: ['Asma'],
        fechaNacimiento: DateTime(1950, 3, 15),
        notas: 'Uso audífonos',
        mostrarMedicamentos: true,
      );

      final cargada = fichaDeJson(jsonDecode(jsonEncode(fichaAJson(ficha))) as Map<String, Object?>)!;

      expect(cargada.enfermedades, ['Asma']);
      expect(cargada.fechaNacimiento, DateTime(1950, 3, 15));
      expect(cargada.notas, 'Uso audífonos');
      expect(cargada.mostrarMedicamentos, isTrue);
    });

    test('una ficha guardada antes de estos datos sigue cargando', () {
      final cargada = fichaDeJson({
        'tipoSangre': 'oPositivo',
        'alergias': ['Polen'],
        'celularContactoEmergencia': ana.celular,
      })!;

      expect(cargada.alergias, ['Polen']);
      expect(cargada.enfermedades, isEmpty);
      expect(cargada.fechaNacimiento, isNull);
      expect(cargada.notas, isEmpty);
      expect(cargada.mostrarMedicamentos, isFalse);
    });
  });

  group('validaciones (mensajes de RF-23)', () {
    test('si falta todo, un solo mensaje general', () {
      expect(
        FichaMedica.validar(tipoSangre: null, celularContacto: null, contactos: contactos),
        FichaMedica.errorIncompleta,
      );
    });

    test('falta el tipo de sangre', () {
      expect(
        FichaMedica.validar(tipoSangre: null, celularContacto: ana.celular, contactos: contactos),
        'Selecciona un tipo de sangre válido.',
      );
    });

    test('el contacto tiene que estar en la lista', () {
      expect(
        FichaMedica.validar(tipoSangre: TipoSangre.bPositivo, celularContacto: '3999999999', contactos: contactos),
        'Elige un contacto de emergencia de tu lista.',
      );
    });

    test('todo bien', () {
      expect(
        FichaMedica.validar(tipoSangre: TipoSangre.bPositivo, celularContacto: luis.celular, contactos: contactos),
        isNull,
      );
    });
  });

  test('encuentra el contacto de emergencia, o null si lo quitaron', () {
    final ficha = FichaMedica(tipoSangre: TipoSangre.oPositivo, celularContactoEmergencia: luis.celular);
    expect(ficha.contactoEmergenciaEn(contactos)?.nombre, 'Luis');
    expect(ficha.contactoEmergenciaEn([ana]), isNull);
  });

  group('en AppState', () {
    late AppState estado;
    final ficha = FichaMedica(tipoSangre: TipoSangre.oNegativo, celularContactoEmergencia: ana.celular);

    setUp(() => estado = AppState());

    test('sin consentimiento de datos médicos no se puede guardar', () {
      expect(() => estado.guardarFichaMedica(ficha), throwsStateError);
      expect(estado.fichaMedica, isNull);
    });

    test('con consentimiento se guarda', () {
      estado.darConsentimiento(TipoConsentimiento.datosMedicos);
      estado.guardarFichaMedica(ficha);
      expect(estado.fichaMedica, same(ficha));
    });

    test('retirar el consentimiento borra la ficha', () {
      estado.darConsentimiento(TipoConsentimiento.datosMedicos);
      estado.guardarFichaMedica(ficha);

      estado.retirarConsentimiento(TipoConsentimiento.datosMedicos);

      expect(estado.fichaMedica, isNull);
    });

    test('retirar otro consentimiento no toca la ficha', () {
      estado.darConsentimiento(TipoConsentimiento.datosMedicos);
      estado.guardarFichaMedica(ficha);

      estado.retirarConsentimiento(TipoConsentimiento.ubicacion);

      expect(estado.fichaMedica, isNotNull);
    });

    test('cerrar sesión borra la ficha', () {
      estado.darConsentimiento(TipoConsentimiento.datosMedicos);
      estado.guardarFichaMedica(ficha);

      estado.cerrarSesion();

      expect(estado.fichaMedica, isNull);
    });

    test('solo las cuentas "Me cuido a mí" usan ficha', () {
      estado.guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.paraMi);
      expect(estado.usaFichaMedica, isTrue);

      estado.guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
      expect(estado.usaFichaMedica, isFalse);
    });
  });
}
