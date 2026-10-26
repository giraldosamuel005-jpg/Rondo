import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/evento.dart';
import 'package:rondo/core/models/ficha_medica.dart';
import 'package:rondo/core/models/medicamento.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/persistencia/almacen.dart';
import 'package:rondo/core/state/app_state.dart';

/// Llena un estado como si alguien hubiera usado la app.
Future<AppState> estadoUsado(AlmacenMemoria almacen) async {
  final estado = AppState(almacen: almacen)
    ..iniciarSesion('3206523232')
    ..guardarPerfil(nombre: 'María José', tipo: TipoCuenta.paraMi)
    ..agregarContacto(const Contacto(nombre: 'Ana', celular: '3001234567', relacion: 'Hija'))
    ..cambiarPermisoUbicacion(true)
    ..darConsentimiento(TipoConsentimiento.datosMedicos)
    ..guardarFichaMedica(FichaMedica(
      tipoSangre: TipoSangre.oPositivo,
      celularContactoEmergencia: '3001234567',
      alergias: ['Penicilina'],
    ))
    ..agregarMedicamento(Medicamento(
      id: 'm1',
      nombre: 'Losartán',
      dosis: '50 mg',
      unidadesPorToma: 1,
      frecuenciaHoras: 8,
      unidadesDisponibles: 30,
      primeraToma: DateTime(2026, 10, 25, 8),
    ))
    ..activarRonda()
    ..confirmarEstoyBien()
    ..cambiarModoTema(ThemeMode.dark);
  estado.registrarToma('m1', tomada: true, ahora: DateTime(2026, 10, 25, 8, 5));
  await estado.guardadoPendiente;
  return estado;
}

void main() {
  test('sin almacén no guarda nada (como en las demás pruebas)', () {
    final estado = AppState()..iniciarSesion('3206523232');
    expect(estado.celular, '3206523232');
  });

  test('al volver a abrir la app, todo sigue ahí', () async {
    final almacen = AlmacenMemoria();
    await estadoUsado(almacen);

    final nuevo = await AppState.cargar(almacen);

    expect(nuevo.registroCompleto, isTrue);
    expect(nuevo.nombre, 'María José');
    expect(nuevo.tipo, TipoCuenta.paraMi);
    expect(nuevo.contactos.single.relacion, 'Hija');
    expect(nuevo.permisoUbicacion, isTrue);
    expect(nuevo.tieneConsentimiento(TipoConsentimiento.ubicacion), isTrue);
    expect(nuevo.fichaMedica!.tipoSangre, TipoSangre.oPositivo);
    expect(nuevo.fichaMedica!.alergias, ['Penicilina']);
    expect(nuevo.medicamento('m1')!.unidadesDisponibles, 29);
    expect(nuevo.cumplimiento, 100);
    expect(nuevo.ultimoEstoyBien, isNotNull);
    expect(nuevo.eventos.map((e) => e.tipo), contains(TipoEvento.rondaActivada));
    expect(nuevo.modoTema, ThemeMode.dark);
  });

  test('la ficha médica se guarda aparte de los demás datos', () async {
    final almacen = AlmacenMemoria();
    await estadoUsado(almacen);

    expect(almacen.ficha, isNotNull);
    expect(almacen.datos.toString(), isNot(contains('Penicilina')));
  });

  test('retirar el consentimiento de datos médicos borra la ficha guardada', () async {
    final almacen = AlmacenMemoria();
    final estado = await estadoUsado(almacen);

    estado.retirarConsentimiento(TipoConsentimiento.datosMedicos);
    await estado.guardadoPendiente;

    expect(almacen.ficha, isNull);
    expect((await AppState.cargar(almacen)).fichaMedica, isNull);
  });

  test('cerrar sesión borra la cuenta pero conserva la apariencia', () async {
    final almacen = AlmacenMemoria();
    final estado = await estadoUsado(almacen);

    estado.cerrarSesion();
    await estado.guardadoPendiente;
    final nuevo = await AppState.cargar(almacen);

    expect(nuevo.registroCompleto, isFalse);
    expect(nuevo.contactos, isEmpty);
    expect(almacen.ficha, isNull);
    expect(nuevo.modoTema, ThemeMode.dark);
  });

  test('si no termina el registro, la app vuelve a Entrar', () async {
    final almacen = AlmacenMemoria();
    final estado = AppState(almacen: almacen)
      ..iniciarSesion('3206523232')
      ..guardarPerfil(nombre: 'María', tipo: TipoCuenta.paraMi);
    await estado.guardadoPendiente;

    expect((await AppState.cargar(almacen)).registroCompleto, isFalse);
  });

  test('datos dañados o desconocidos no hacen fallar la carga', () async {
    final almacen = AlmacenMemoria()
      ..datos = {
        'celular': '3206523232',
        'tipo': 'conductor', // Perfil que ya no existe
        'contactos': [
          {'nombre': 'Ana', 'celular': '3001234567'},
          {'basura': true},
        ],
        'eventos': [
          {'tipo': 'accidente', 'fecha': '2026-10-25T08:00:00.000'},
        ],
        'modoTema': 'arcoiris',
      };

    final estado = await AppState.cargar(almacen);

    expect(estado.tipo, isNull);
    expect(estado.contactos, hasLength(1));
    expect(estado.eventos, isEmpty);
    expect(estado.modoTema, ThemeMode.system);
  });
}
