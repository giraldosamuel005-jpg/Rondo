import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/alertas/alerta_compartida.dart';
import 'package:rondo/core/alertas/alertas_cuidador.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/ficha_medica.dart';
import 'package:rondo/core/models/persona_a_cargo.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/vinculos/servicio_vinculos.dart';
import 'package:rondo/core/vinculos/vinculo.dart';
import 'package:rondo/core/vinculos/vinculos.dart';

import '../../support/alertas_falsas.dart';
import '../../support/servidor_vinculos_falso.dart';

void main() {
  group('código de invitación', () {
    test('tiene 6 caracteres sin los que se confunden', () {
      final azar = Random(7);
      for (var i = 0; i < 200; i++) {
        final codigo = Invitacion.nuevoCodigo(azar);
        expect(Invitacion.codigoValido(codigo), isTrue, reason: codigo);
        expect(codigo, isNot(matches(RegExp('[01OIL]'))));
      }
    });

    test('acepta lo que escriba la persona con espacios, guiones o minúsculas', () {
      expect(Invitacion.normalizarCodigo(' k7m-2qx '), 'K7M2QX');
      expect(Invitacion.codigoValido('K7M2QX'), isTrue);
      expect(Invitacion.codigoValido('K7M2Q'), isFalse);
      expect(Invitacion.codigoValido('K7M2Q0'), isFalse); // El 0 no existe
    });
  });

  group('cuándo se puede aceptar', () {
    final ahora = DateTime(2026, 11, 9, 10);
    Invitacion invitacion({EstadoInvitacion estado = EstadoInvitacion.pendiente, Duration vence = const Duration(hours: 1)}) =>
        Invitacion(
          codigo: 'K7M2QX',
          personaUid: 'rosa',
          personaNombre: 'Rosa',
          personaCelular: '3104567890',
          celularInvitado: '3001234567',
          nombreInvitado: 'Ana',
          estado: estado,
          expiraEn: ahora.add(vence),
        );

    String? error(Invitacion? i, {String uid = 'ana'}) => Invitacion.errorAlAceptar(i, cuidadorUid: uid, ahora: ahora);

    test('pendiente y vigente: sí', () => expect(error(invitacion()), isNull));
    test('no existe', () => expect(error(null), Invitacion.errorNoValida));
    test('ya usada', () => expect(error(invitacion(estado: EstadoInvitacion.aceptada)), Invitacion.errorNoValida));
    test('anulada', () => expect(error(invitacion(estado: EstadoInvitacion.revocada)), Invitacion.errorNoValida));
    test('vencida', () => expect(error(invitacion(vence: Duration.zero)), Invitacion.errorVencida));
    test('la propia', () => expect(error(invitacion(), uid: 'rosa'), Invitacion.errorPropia));
  });

  test('el SMS lleva el código y saluda por el primer nombre', () {
    final i = Invitacion(
      codigo: 'K7M2QX',
      personaUid: 'rosa',
      personaNombre: 'Rosa',
      personaCelular: '3104567890',
      celularInvitado: '3001234567',
      nombreInvitado: 'Ana María',
      estado: EstadoInvitacion.pendiente,
      expiraEn: DateTime(2026),
    );
    expect(i.mensajeSms, startsWith('Hola Ana,'));
    expect(i.mensajeSms, contains('K7M2QX'));
  });

  group('entre dos celulares', () {
    const ana = Contacto(nombre: 'Ana', celular: '3001234567', relacion: 'Hija');
    late ServidorFalso servidor;
    late AppState rosa;
    late AppState andres;
    late Vinculos deRosa;
    late Vinculos deAndres;

    setUp(() {
      servidor = ServidorFalso();
      rosa = AppState()
        ..iniciarSesion('3104567890')
        ..guardarPerfil(nombre: 'Rosa Gómez', tipo: TipoCuenta.paraMi)
        ..agregarContacto(ana)
        ..activarRonda();
      andres = AppState()
        ..iniciarSesion('3001234567')
        ..guardarPerfil(nombre: 'Ana Gómez', tipo: TipoCuenta.cuidador);
      deRosa = Vinculos(servidor.celular('uid-rosa'), rosa);
      deAndres = Vinculos(servidor.celular('uid-ana'), andres);
    });

    tearDown(() {
      deRosa.dispose();
      deAndres.dispose();
    });

    Future<Invitacion> invitarYAceptar() async {
      await pumpEventQueue();
      final invitacion = await deRosa.invitar(ana);
      await deAndres.aceptar(invitacion.codigo.toLowerCase());
      await pumpEventQueue();
      return invitacion;
    }

    test('invitar deja la invitación pendiente para ese contacto', () async {
      await pumpEventQueue();
      final invitacion = await deRosa.invitar(ana);

      expect(deRosa.invitacionPendiente(ana.celular)?.codigo, invitacion.codigo);
      expect(deRosa.vinculoCon(ana.celular), isNull);
    });

    test('no se puede invitar dos veces al mismo contacto', () async {
      await pumpEventQueue();
      await deRosa.invitar(ana);

      expect(
        () => deRosa.invitar(ana),
        throwsA(isA<ErrorVinculo>().having((e) => e.mensaje, 'mensaje', Invitacion.errorYaInvitado)),
      );
    });

    test('al aceptar, el cuidador ve a la persona con su estado', () async {
      await invitarYAceptar();

      expect(deRosa.vinculoCon(ana.celular), isNotNull);
      final persona = andres.personasACargo.single;
      expect(persona.nombre, 'Rosa Gómez');
      expect(persona.celular, '3104567890');
      expect(persona.estado, EstadoPersona.activa);
    });

    test('lo que hace la persona le llega al cuidador', () async {
      await invitarYAceptar();

      rosa
        ..confirmarEstoyBien()
        ..alternarPausa();
      await pumpEventQueue();

      final persona = andres.personasACargo.single;
      expect(persona.estado, EstadoPersona.enPausa);
      expect(persona.ultimoEstoyBien, rosa.ultimoEstoyBien);
    });

    test('sin cuidadores no se publica nada en el servidor', () async {
      await pumpEventQueue();
      rosa.confirmarEstoyBien();
      await pumpEventQueue();

      expect(servidor.estados, isEmpty);
    });

    test('dejar de compartir: el cuidador la pierde y queda el aviso', () async {
      await invitarYAceptar();

      await deRosa.dejarDeCompartir(deRosa.vinculoCon(ana.celular)!);
      await pumpEventQueue();

      expect(andres.personasACargo, isEmpty);
      expect(deAndres.retirados, ['Rosa Gómez']);
      expect(servidor.estados, isEmpty); // Ya no hay a quién mostrárselo
    });

    test('con el código de un vínculo cortado no se vuelve a entrar', () async {
      final invitacion = await invitarYAceptar();
      await deRosa.dejarDeCompartir(deRosa.vinculoCon(ana.celular)!);
      await pumpEventQueue();

      expect(
        () => deAndres.aceptar(invitacion.codigo),
        throwsA(isA<ErrorVinculo>().having((e) => e.mensaje, 'mensaje', Invitacion.errorNoValida)),
      );
    });

    test('una invitación cancelada ya no sirve', () async {
      await pumpEventQueue();
      final invitacion = await deRosa.invitar(ana);
      await deRosa.cancelarInvitacion(invitacion);
      await pumpEventQueue();

      expect(deRosa.invitacionPendiente(ana.celular), isNull);
      await expectLater(deAndres.aceptar(invitacion.codigo), throwsA(isA<ErrorVinculo>()));
    });

    test('la persona no puede aceptar su propia invitación', () async {
      await pumpEventQueue();
      final invitacion = await deRosa.invitar(ana);

      await expectLater(
        deRosa.aceptar(invitacion.codigo),
        throwsA(isA<ErrorVinculo>().having((e) => e.mensaje, 'mensaje', Invitacion.errorPropia)),
      );
    });

    test('un código mal escrito ni siquiera va al servidor', () async {
      servidor.sinRed = true;
      await expectLater(
        deAndres.aceptar('abc'),
        throwsA(isA<ErrorVinculo>().having((e) => e.mensaje, 'mensaje', Invitacion.errorCodigo)),
      );
    });

    test('sin internet lo dice claro', () async {
      servidor.sinRed = true;
      await expectLater(
        deRosa.invitar(ana),
        throwsA(isA<ErrorVinculo>().having((e) => e.mensaje, 'mensaje', Vinculos.errorConexion)),
      );
    });

    test('quitar el contacto corta su vínculo', () async {
      await invitarYAceptar();

      await deRosa.olvidarContacto(ana.celular);
      await pumpEventQueue();

      expect(andres.personasACargo, isEmpty);
    });

    test('cerrar sesión deja de compartir con todos', () async {
      await invitarYAceptar();

      rosa.cerrarSesion();
      await pumpEventQueue();

      expect(andres.personasACargo, isEmpty);
      expect(servidor.estados, isEmpty);
    });

    test('cerrar sesión anula las invitaciones sin aceptar', () async {
      await pumpEventQueue();
      final invitacion = await deRosa.invitar(ana);

      rosa.cerrarSesion();
      await pumpEventQueue();

      expect(servidor.invitaciones[invitacion.codigo]!.estado, EstadoInvitacion.revocada);
    });

    group('alertas', () {
      const casa = Posicion(3.4372, -76.5225);

      AlertaCompartida alerta({DateTime? fecha, Posicion? posicion}) =>
          AlertaCompartida(id: 'a1', fecha: fecha ?? DateTime.now(), posicion: posicion);

      test('la alerta de la persona le llega al cuidador con su ubicación', () async {
        await invitarYAceptar();
        final nuevas = <String>[];
        final sub = deAndres.alertasNuevas.listen(nuevas.add);
        addTearDown(sub.cancel);

        final entrega = await deRosa.publicarAlerta(alerta(posicion: casa));
        await pumpEventQueue();

        expect(entrega, EntregaServidor.recibida);
        final persona = andres.personasACargo.single;
        expect(persona.estado, EstadoPersona.alerta);
        expect(persona.alertas.single.atendida, isFalse);
        expect(persona.ubicacion!.latitud, casa.latitud);
        expect(nuevas, ['uid-rosa']); // Suena y abre la pantalla de alerta
      });

      test('sin cuidadores no se sube nada', () async {
        await pumpEventQueue();

        expect(await deRosa.publicarAlerta(alerta()), EntregaServidor.sinCuidadores);
        expect(servidor.alertas, isEmpty);
      });

      test('recién abierta la app espera la lista de cuidadores en vez de perder la alerta', () async {
        await invitarYAceptar();
        // Rosa cierra y vuelve a abrir la app, y se cae de inmediato.
        final otraVez = Vinculos(servidor.celular('uid-rosa'), rosa);
        addTearDown(otraVez.dispose);

        expect(await otraVez.publicarAlerta(alerta()), EntregaServidor.recibida);
      });

      test('sin red dice que falló, para que se reintente', () async {
        await invitarYAceptar();
        servidor.sinRed = true;
        expect(await deRosa.publicarAlerta(alerta()), EntregaServidor.fallo);
      });

      test('el cuidador la atiende y deja de estar en alerta', () async {
        await invitarYAceptar();
        await deRosa.publicarAlerta(alerta());
        await pumpEventQueue();

        deAndres.atenderAlertas('uid-rosa');
        await pumpEventQueue();

        expect(servidor.alertas['uid-rosa']!.single.atendida, isTrue);
        expect(andres.personasACargo.single.estado, EstadoPersona.activa);
      });

      test('si la persona avisa que está bien, el cuidador lo ve', () async {
        await invitarYAceptar();
        await deRosa.publicarAlerta(alerta());
        await deRosa.resolverAlerta('a1');
        await pumpEventQueue();

        final persona = andres.personasACargo.single;
        expect(persona.estado, EstadoPersona.activa);
        expect(persona.alertas.single.estabaBien, isTrue);
      });

      test('una alerta vieja no abre la pantalla, pero sale en la lista', () async {
        await invitarYAceptar();
        final nuevas = <String>[];
        final sub = deAndres.alertasNuevas.listen(nuevas.add);
        addTearDown(sub.cancel);

        await deRosa.publicarAlerta(alerta(fecha: DateTime.now().subtract(const Duration(hours: 2))));
        await pumpEventQueue();

        expect(nuevas, isEmpty);
        expect(andres.personasACargo.single.alertas, hasLength(1));
      });

      test('cerrar sesión borra las alertas del servidor', () async {
        await invitarYAceptar();
        await deRosa.publicarAlerta(alerta());

        rosa.cerrarSesion();
        await pumpEventQueue();

        expect(servidor.alertas, isEmpty);
      });

      test('al cuidador le suena, y se calla cuando alguien la atiende', () async {
        await invitarYAceptar();
        final alarma = AlarmaFalsa();
        final avisos = NotificacionesFalsas();
        final control = AlertasCuidador(andres, deAndres, alarma: alarma, notificaciones: avisos);
        addTearDown(control.dispose);
        final abiertas = <String>[];
        control.abrir.listen(abiertas.add);

        await deRosa.publicarAlerta(alerta());
        await pumpEventQueue();
        expect(alarma.sonando, isTrue);
        expect(avisos.alertas, ['Rosa necesita ayuda']);
        expect(abiertas, ['uid-rosa']);

        await deRosa.resolverAlerta('a1'); // Rosa avisó que está bien
        await pumpEventQueue();
        expect(alarma.sonando, isFalse);
        expect(avisos.quitadas, ['uid-rosa']);
      });
    });

    group('ubicación (RF-26)', () {
      const casa = Posicion(3.4372, -76.5225);
      const parque = Posicion(3.4476, -76.5418);
      late UbicacionFalsa gps;

      setUp(() {
        gps = UbicacionFalsa(casa);
        deRosa.dispose();
        deRosa = Vinculos(servidor.celular('uid-rosa'), rosa, ubicacion: gps);
      });

      Future<void> autorizar() async {
        rosa
          ..cambiarPermiso(PermisoSistema.ubicacion, true)
          ..darConsentimiento(TipoConsentimiento.ubicacionCuidadores);
        await pumpEventQueue();
      }

      test('sin autorizarlo, el cuidador no la ve y ni se lee el GPS', () async {
        rosa.cambiarPermiso(PermisoSistema.ubicacion, true); // Solo para alertas
        await invitarYAceptar();

        expect(gps.lecturas, 0);
        expect(andres.personasACargo.single.ubicacion, isNull);
        expect(andres.personasACargo.single.comparteUbicacion, isFalse);
      });

      test('al autorizarlo, el cuidador ve dónde está', () async {
        await invitarYAceptar();
        await autorizar();

        final persona = andres.personasACargo.single;
        expect(persona.comparteUbicacion, isTrue);
        expect(persona.ubicacion!.latitud, casa.latitud);
      });

      test('el cuidador la pide y llega la nueva', () async {
        await autorizar();
        await invitarYAceptar();
        gps.posicion = parque;

        await deAndres.pedirUbicacion('uid-rosa');
        await pumpEventQueue();

        expect(andres.personasACargo.single.ubicacion!.latitud, parque.latitud);
      });

      test('"Estoy bien" también la actualiza', () async {
        await autorizar();
        await invitarYAceptar();
        gps.posicion = parque;

        rosa.confirmarEstoyBien();
        await pumpEventQueue();

        expect(andres.personasACargo.single.ubicacion!.latitud, parque.latitud);
      });

      test('en pausa, o al quitar la autorización, deja de verse', () async {
        await autorizar();
        await invitarYAceptar();

        rosa.alternarPausa();
        await pumpEventQueue();
        expect(andres.personasACargo.single.ubicacion, isNull);

        rosa.alternarPausa();
        await pumpEventQueue();
        expect(andres.personasACargo.single.ubicacion, isNotNull);

        rosa.retirarConsentimiento(TipoConsentimiento.ubicacionCuidadores);
        await pumpEventQueue();
        expect(andres.personasACargo.single.ubicacion, isNull);
        expect(andres.personasACargo.single.comparteUbicacion, isFalse);
      });

      test('quien ya no la cuida no la puede pedir', () async {
        await autorizar();
        await invitarYAceptar();
        await deRosa.dejarDeCompartir(deRosa.vinculoCon(ana.celular)!);
        await pumpEventQueue();

        await expectLater(deAndres.pedirUbicacion('uid-rosa'), throwsA(isA<ErrorVinculo>()));
      });
    });

    test('novedades: pausa, reanuda, "Estoy bien"; ponerse al día no es novedad', () async {
      final novedades = <TipoNovedad>[];
      final sub = deAndres.novedades.listen((n) => novedades.add(n.tipo));
      addTearDown(sub.cancel);
      rosa.confirmarEstoyBien(); // Antes de vincularse
      await invitarYAceptar();
      expect(novedades, isEmpty);

      rosa.alternarPausa();
      await pumpEventQueue();
      rosa.alternarPausa();
      await pumpEventQueue();
      rosa.confirmarEstoyBien();
      await pumpEventQueue();

      expect(novedades, [TipoNovedad.pauso, TipoNovedad.reanudo, TipoNovedad.estoyBien]);
    });

    test('el parentesco que escribió el cuidador se conserva con cada cambio', () async {
      await invitarYAceptar();
      andres.ponerParentesco('uid-rosa', 'Mamá');
      rosa.confirmarEstoyBien();
      await pumpEventQueue();

      expect(andres.personasACargo.single.relacion, 'Mamá');
    });

    test('las personas de ejemplo no se mezclan con las reales', () async {
      andres.cargarPersonasDeEjemplo();
      await invitarYAceptar();

      expect(andres.personasACargo, hasLength(3));

      await deRosa.dejarDeCompartir(deRosa.vinculoCon(ana.celular)!);
      await pumpEventQueue();
      expect(andres.personasACargo.map((p) => p.id), everyElement(startsWith(PersonaACargo.prefijoEjemplo)));
    });
  });

  group('ficha del QR', () {
    late ServidorFalso servidor;
    late AppState rosa;
    late Vinculos deRosa;

    FichaMedica ficha({List<String> alergias = const ['Penicilina']}) => FichaMedica(
          tipoSangre: TipoSangre.oPositivo,
          celularContactoEmergencia: '3001234567',
          alergias: alergias,
          fechaNacimiento: DateTime(1950, 3, 7),
        );

    setUp(() async {
      servidor = ServidorFalso();
      rosa = AppState()
        ..iniciarSesion('3104567890')
        ..guardarPerfil(nombre: 'Rosa Gómez', tipo: TipoCuenta.paraMi)
        ..agregarContacto(const Contacto(nombre: 'Ana', celular: '3001234567', relacion: 'Hija'))
        ..darConsentimiento(TipoConsentimiento.datosMedicos)
        ..guardarFichaMedica(ficha())
        ..activarRonda();
      deRosa = Vinculos(servidor.celular('uid-rosa'), rosa);
      await pumpEventQueue();
    });

    tearDown(() => deRosa.dispose());

    Map<String, Object?>? enServidor(String token) => servidor.fichas[token]?.ficha?.datos;

    test('se publica bajo el token del QR, lista para mostrar', () {
      final datos = enServidor(rosa.codigoQr!.token)!;
      expect(datos['nombre'], 'Rosa Gómez');
      expect(datos['tipoSangre'], 'O+');
      expect(datos['alergias'], ['Penicilina']);
      expect(datos['fechaNacimiento'], '1950-03-07');
      expect(datos['contacto'], {'nombre': 'Ana', 'relacion': 'Hija', 'celular': '3001234567'});
      expect(datos['medicamentos'], isEmpty); // No marcó "mostrar medicamentos"
      expect(servidor.fichas[rosa.codigoQr!.token]!.duenoUid, 'uid-rosa');
    });

    test('al editar la ficha se actualiza la del QR', () async {
      rosa.guardarFichaMedica(ficha(alergias: ['Penicilina', 'Maní']));
      await pumpEventQueue();

      expect(enServidor(rosa.codigoQr!.token)!['alergias'], ['Penicilina', 'Maní']);
    });

    test('con un código nuevo, el anterior queda revocado', () async {
      final viejo = rosa.codigoQr!.token;
      rosa.regenerarCodigoQr();
      await pumpEventQueue();

      expect(servidor.fichas[viejo]!.ficha, isNull);
      expect(enServidor(rosa.codigoQr!.token), isNotNull);
    });

    test('retirar el consentimiento revoca el QR', () async {
      final token = rosa.codigoQr!.token;
      rosa.retirarConsentimiento(TipoConsentimiento.datosMedicos);
      await pumpEventQueue();

      expect(servidor.fichas[token]!.ficha, isNull);
    });

    test('cerrar sesión revoca el QR', () async {
      final token = rosa.codigoQr!.token;
      rosa.cerrarSesion();
      await pumpEventQueue();

      expect(servidor.fichas[token]!.ficha, isNull);
    });

    test('la persona ve cuándo abrieron su ficha', () async {
      expect(deRosa.consultasFicha, isEmpty);

      servidor.abrirFicha(rosa.codigoQr!.token, DateTime(2026, 11, 10, 9));
      servidor.abrirFicha(rosa.codigoQr!.token, DateTime(2026, 11, 10, 11));
      await pumpEventQueue();

      expect(deRosa.consultasFicha, [DateTime(2026, 11, 10, 11), DateTime(2026, 11, 10, 9)]);
    });

    test('una ficha revocada ya no se puede abrir', () async {
      final viejo = rosa.codigoQr!.token;
      rosa.regenerarCodigoQr();
      await pumpEventQueue();

      expect(() => servidor.abrirFicha(viejo, DateTime(2026)), throwsStateError);
      expect(deRosa.consultasFicha, isEmpty); // Las del código nuevo: ninguna
    });
  });

  test('si el servidor rechaza la ficha del QR, lo dice y la vuelve a subir sola', () {
    fakeAsync((tiempo) {
      final servidor = ServidorFalso()..fichasFallan = true;
      final rosa = AppState()
        ..iniciarSesion('3104567890')
        ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi)
        ..agregarContacto(const Contacto(nombre: 'Ana', celular: '3001234567'))
        ..darConsentimiento(TipoConsentimiento.datosMedicos)
        ..guardarFichaMedica(
          FichaMedica(tipoSangre: TipoSangre.oPositivo, celularContactoEmergencia: '3001234567'),
        );
      final deRosa = Vinculos(servidor.celular('rosa'), rosa);
      tiempo.flushMicrotasks();
      expect(deRosa.estadoFicha, EstadoFicha.fallo);
      tiempo.elapse(const Duration(minutes: 1));
      expect(deRosa.estadoFicha, EstadoFicha.fallo);
      expect(servidor.fichas, isEmpty);

      servidor.fichasFallan = false; // Se arregló en el servidor
      tiempo.elapse(Vinculos.cadaReintentoFicha);
      expect(deRosa.estadoFicha, EstadoFicha.lista);
      expect(servidor.fichas[rosa.codigoQr!.token]!.ficha, isNotNull);

      // Un código nuevo que falla y luego sale: el viejo queda revocado.
      final viejo = rosa.codigoQr!.token;
      servidor.fichasFallan = true;
      rosa.regenerarCodigoQr();
      tiempo.flushMicrotasks();
      expect(deRosa.estadoFicha, EstadoFicha.fallo);
      servidor.fichasFallan = false;
      tiempo.elapse(Vinculos.cadaReintentoFicha);
      expect(deRosa.estadoFicha, EstadoFicha.lista);
      expect(servidor.fichas[viejo]!.ficha, isNull);
      deRosa.dispose();
    });
  });

  test('si la escucha de alertas falla, se vuelve a intentar sola', () {
    fakeAsync((tiempo) {
      final servidor = ServidorFalso()..alertasFallan = true;
      final rosa = AppState()
        ..iniciarSesion('3104567890')
        ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi)
        ..agregarContacto(const Contacto(nombre: 'Ana', celular: '3001234567'))
        ..activarRonda();
      final ana = AppState()
        ..iniciarSesion('3001234567')
        ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
      final deRosa = Vinculos(servidor.celular('rosa'), rosa);
      final deAna = Vinculos(servidor.celular('ana'), ana);
      tiempo.flushMicrotasks();
      deRosa.invitar(rosa.contactos.single).then((i) => deAna.aceptar(i.codigo));
      tiempo.elapse(const Duration(seconds: 1));
      deRosa.publicarAlerta(AlertaCompartida(id: 'a1', fecha: DateTime.now()));
      tiempo.elapse(const Duration(seconds: 1));
      expect(ana.personasACargo.single.alertas, isEmpty);

      servidor.alertasFallan = false; // Se arregló en el servidor
      tiempo.elapse(const Duration(minutes: 1));
      expect(ana.personasACargo.single.alertas, hasLength(1));

      deRosa.dispose();
      deAna.dispose();
    });
  });

  test('cerrar sesión y entrar enseguida: la sesión nueva no se queda sin servidor', () {
    fakeAsync((tiempo) {
      final servidor = ServidorFalso();
      final celular = servidor.celular('uid')..demoraAlCerrar = const Duration(seconds: 2);
      final estado = AppState()
        ..iniciarSesion('3104567890')
        ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi);
      final vinculos = Vinculos(celular, estado);
      tiempo.elapse(const Duration(seconds: 1));
      expect(celular.sesionAbierta, isTrue);

      estado
        ..cerrarSesion()
        ..iniciarSesion('3001234567')
        ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
      tiempo.elapse(const Duration(seconds: 10));

      expect(celular.sesionAbierta, isTrue);
      vinculos.dispose();
    });
  });

  test('sin internet al abrir, se conecta solo cuando vuelve', () {
    fakeAsync((tiempo) {
      final servidor = ServidorFalso()..sinRed = true;
      final celular = servidor.celular('uid');
      final estado = AppState()
        ..iniciarSesion('3001234567')
        ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
      final vinculos = Vinculos(celular, estado);
      tiempo.elapse(const Duration(seconds: 1));
      expect(celular.sesionAbierta, isFalse);

      servidor.sinRed = false;
      tiempo.elapse(const Duration(seconds: 15));
      expect(celular.sesionAbierta, isTrue);
      vinculos.dispose();
    });
  });

  test('una invitación vencida no se acepta', () async {
    var ahora = DateTime(2026, 11, 9, 10);
    final servidor = ServidorFalso(reloj: () => ahora);
    final rosa = AppState()
      ..iniciarSesion('3104567890')
      ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi);
    final ana = AppState()
      ..iniciarSesion('3001234567')
      ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
    final deRosa = Vinculos(servidor.celular('rosa'), rosa, reloj: () => ahora);
    final deAna = Vinculos(servidor.celular('ana'), ana, reloj: () => ahora);
    addTearDown(deRosa.dispose);
    addTearDown(deAna.dispose);
    await pumpEventQueue();

    final invitacion = await deRosa.invitar(const Contacto(nombre: 'Ana', celular: '3001234567'));
    ahora = ahora.add(Invitacion.vigencia);

    await expectLater(
      deAna.aceptar(invitacion.codigo),
      throwsA(isA<ErrorVinculo>().having((e) => e.mensaje, 'mensaje', Invitacion.errorVencida)),
    );
    // Y la persona ya la puede volver a invitar.
    expect(deRosa.invitacionPendiente('3001234567'), isNull);
  });
}
