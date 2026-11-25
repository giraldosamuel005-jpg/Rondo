import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/alertas/alerta_compartida.dart';
import 'package:rondo/core/alertas/aviso_alerta.dart';
import 'package:rondo/core/alertas/control_alerta.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/evento.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/state/app_state.dart';

import '../../support/alertas_falsas.dart';

void main() {
  const ana = Contacto(nombre: 'Ana María', celular: '3001234567');
  const luis = Contacto(nombre: 'Luis', celular: '3009876543');
  const casa = Posicion(3.4372, -76.5225);

  late AppState estado;
  late SmsFalso sms;
  late ServidorAlertasFalso servidor;
  late AlarmaFalsa alarma;
  late LectorUbicacion gps;

  setUp(() {
    estado = AppState()
      ..iniciarSesion('3104567890')
      ..guardarPerfil(nombre: 'Rosa Gómez', tipo: TipoCuenta.paraMi)
      ..agregarContacto(ana)
      ..agregarContacto(luis)
      ..activarRonda()
      ..cambiarPermiso(PermisoSistema.ubicacion, true)
      ..cambiarPermiso(PermisoSistema.sms, true);
    sms = SmsFalso();
    servidor = ServidorAlertasFalso();
    alarma = AlarmaFalsa();
    gps = UbicacionFalsa(casa);
  });

  /// Corre [prueba] con un reloj de mentiras que avanza cuando ella diga.
  void conReloj(void Function(FakeAsync tiempo, ControlAlerta control) prueba) => fakeAsync((tiempo) {
        final inicio = DateTime(2026, 11, 24, 15, 42);
        final control = ControlAlerta(
          estado,
          ubicacion: gps,
          sms: sms,
          servidor: servidor,
          alarma: alarma,
          reloj: () => inicio.add(tiempo.elapsed),
        );
        prueba(tiempo, control);
        control.dispose();
      });

  Iterable<Evento> enviadas() => estado.eventos.where((e) => e.tipo == TipoEvento.alertaEnviada);

  group('el SMS', () {
    final fecha = DateTime(2026, 11, 10, 15, 42);

    test('dice quién, a qué hora, dónde y qué hacer', () {
      final texto = AlertaCompartida.mensajeSms(nombre: 'Rosa Gómez', fecha: fecha, posicion: casa);
      expect(texto, contains('Rosa Gómez pudo haberse caído (3:42 p. m.)'));
      expect(texto, contains('https://www.google.com/maps/search/?api=1&query=3.43720,-76.52250'));
      expect(texto, contains('Llama ya a Rosa'));
      expect(texto, contains('123'));
    });

    test('si la persona pidió ayuda no dice que se cayó', () {
      final texto = AlertaCompartida.mensajeSms(nombre: 'Rosa', fecha: fecha, pidioAyuda: true);
      expect(texto, contains('Rosa pidió ayuda'));
      expect(texto, isNot(contains('caído')));
    });

    test('una prueba dice que no es una emergencia', () {
      final texto = AlertaCompartida.mensajeSms(nombre: 'Rosa', fecha: fecha, prueba: true);
      expect(texto, contains('PRUEBA'));
      expect(texto, isNot(contains('Llama ya')));
    });
  });

  group('cuenta regresiva', () {
    test('a los 10 s avisa por SMS y a los cuidadores, con la ubicación', () {
      conReloj((tiempo, control) {
        control.iniciar();
        expect(control.fase, FaseAlerta.contando);
        expect(alarma.sonando, isTrue);

        tiempo.elapse(const Duration(seconds: 9));
        expect(control.segundosRestantes, 1);
        expect(sms.enviados, isEmpty);

        tiempo.elapse(const Duration(seconds: 2));
        expect(control.fase, FaseAlerta.enviada);
        expect(sms.enviados.keys, {ana.celular, luis.celular});
        expect(sms.enviados[ana.celular]!.single, contains('google.com/maps'));
        expect(servidor.recibidas.single.posicion, casa);
        expect(alarma.sonando, isFalse);
        expect(enviadas().single.detalle, 'Avisamos a Ana, Luis y tus cuidadores en Rondó');
      });
    });

    test('si el celular se durmió, al despertar cuenta el tiempo real', () {
      fakeAsync((tiempo) {
        var ahora = DateTime(2026, 11, 24);
        final control = ControlAlerta(estado, sms: sms, servidor: servidor, alarma: alarma, reloj: () => ahora);
        control.iniciar();
        ahora = ahora.add(const Duration(minutes: 1)); // Durmió sin correr nada
        tiempo.elapse(const Duration(milliseconds: 200));
        expect(sms.enviados, isNotEmpty);
        control.dispose();
      });
    });

    test('"Estoy bien" a tiempo: no se avisa a nadie', () {
      conReloj((tiempo, control) {
        control.iniciar();
        tiempo.elapse(const Duration(seconds: 5));
        control.estoyBien();
        tiempo.elapse(const Duration(minutes: 1));

        expect(control.activa, isFalse);
        expect(sms.enviados, isEmpty);
        expect(servidor.recibidas, isEmpty);
        expect(alarma.sonando, isFalse);
        expect(estado.eventos.first.tipo, TipoEvento.alertaCancelada);
        expect(estado.alertaAbierta, isNull);
      });
    });

    test('otra caída mientras cuenta no la reinicia', () {
      conReloj((tiempo, control) {
        control.iniciar();
        tiempo.elapse(const Duration(seconds: 6));
        control.iniciar();
        tiempo.elapse(const Duration(seconds: 5));
        expect(control.fase, FaseAlerta.enviada);
      });
    });

    test('cerrar sesión durante la cuenta la cancela', () {
      conReloj((tiempo, control) {
        control.iniciar();
        estado.cerrarSesion();
        tiempo.elapse(const Duration(seconds: 20));
        expect(control.activa, isFalse);
        expect(sms.enviados, isEmpty);
      });
    });
  });

  test('"Pedir ayuda" avisa de una, sin cuenta regresiva', () {
    conReloj((tiempo, control) {
      control.pedirAyuda();
      tiempo.elapse(const Duration(seconds: 1));
      expect(control.fase, FaseAlerta.enviada);
      expect(sms.enviados[ana.celular]!.single, contains('pidió ayuda'));
    });
  });

  group('ubicación', () {
    test('un GPS que no contesta no detiene el aviso', () {
      gps = UbicacionColgada();
      conReloj((tiempo, control) {
        control.iniciar();
        tiempo.elapse(const Duration(seconds: 20));
        expect(control.fase, FaseAlerta.enviada);
        expect(sms.enviados[ana.celular]!.single, contains('No pudimos obtener su ubicación.'));
      });
    });

    test('si el GPS no contesta, va la última conocida', () {
      gps = UbicacionColgada(casa);
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 8));
        expect(control.posicion, casa);
        expect(sms.enviados[ana.celular]!.single, contains('google.com/maps'));
      });
    });

    test('si la persona la apagó en Rondó, ni se lee', () {
      estado.cambiarPermiso(PermisoSistema.ubicacion, false);
      final lector = UbicacionFalsa(casa);
      gps = lector;
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 1));
        expect(lector.lecturas, 0);
        expect(control.posicion, isNull);
      });
    });
  });

  group('cuando algo falla', () {
    test('sin permiso de SMS pero con cuidadores: sí le llegó a alguien', () {
      estado.cambiarPermiso(PermisoSistema.sms, false);
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 1));
        expect(control.faltaPermisoSms, isTrue);
        expect(control.nadieAvisado, isFalse);
        expect(control.reintentando, isFalse); // Reintentar sin permiso no sirve
      });
    });

    test('ni SMS ni servidor: suena la alarma local (RF-17)', () {
      estado.cambiarPermiso(PermisoSistema.sms, false);
      servidor.entrega = EntregaServidor.sinCuidadores;
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 1));
        expect(control.nadieAvisado, isTrue);
        expect(alarma.sonando, isTrue);

        control.cerrar();
        expect(alarma.sonando, isFalse);
      });
    });

    test('al dar el permiso de SMS desde la alerta, sale', () {
      estado.cambiarPermiso(PermisoSistema.sms, false);
      servidor.entrega = EntregaServidor.sinCuidadores;
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 1));
        estado.cambiarPermiso(PermisoSistema.sms, true);
        control.reintentarYa();
        tiempo.elapse(const Duration(seconds: 1));

        expect(control.conSms, [ana, luis]);
        expect(control.nadieAvisado, isFalse);
        expect(alarma.sonando, isFalse);
      });
    });

    test('el SMS que no salió se reintenta, y al salir queda en el Historial', () {
      sms.fallanA.add(luis.celular);
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 1));
        expect(control.sinSms, [luis]);
        expect(control.reintentando, isTrue);

        sms.fallanA.clear(); // Volvió la señal
        control.cerrar(); // Aunque salga de la pantalla
        tiempo.elapse(ControlAlerta.cadaReintento + const Duration(seconds: 1));

        expect(sms.enviados[luis.celular], hasLength(1));
        expect(sms.enviados[ana.celular], hasLength(1)); // A Ana no se le repite
        expect(enviadas().first.detalle, 'Avisamos a Luis');
        expect(control.reintentando, isFalse);
      });
    });

    test('si el servidor la rechaza, se reintenta con el mismo ID', () {
      servidor.entrega = EntregaServidor.fallo;
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 1));
        expect(control.llegoACuidadores, isFalse);

        servidor.entrega = EntregaServidor.recibida;
        tiempo.elapse(ControlAlerta.cadaReintento + const Duration(seconds: 1));
        expect(servidor.recibidas, hasLength(1));
        expect(control.llegoACuidadores, isTrue);
      });
    });

    test('sin internet no se queda en "Avisando…" para siempre', () {
      servidor.entrega = EntregaServidor.pendiente;
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 20));
        expect(control.fase, FaseAlerta.enviada);
        expect(control.conSms, hasLength(2));
        expect(control.entregaServidor, EntregaServidor.pendiente);
      });
    });

    test('no se reintenta sin fin', () {
      sms.fallanA.addAll([ana.celular, luis.celular]);
      servidor.entrega = EntregaServidor.sinCuidadores;
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(hours: 1));
        expect(control.reintentando, isFalse);
      });
    });

    test('si la alarma no suena, lo dice', () {
      alarma.funciona = false;
      conReloj((tiempo, control) {
        control.iniciar();
        tiempo.elapse(const Duration(milliseconds: 100));
        expect(control.sonidoFallo, isTrue);
        control.estoyBien();
      });
    });
  });

  group('"Ya estoy bien" después de avisar', () {
    test('les llega a los mismos y se cierra la alerta', () {
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 1));
        final id = estado.alertaAbierta!.id;

        control.yaEstoyBien();
        tiempo.elapse(const Duration(seconds: 1));

        expect(servidor.resueltas, [id]);
        expect(sms.enviados[ana.celular]!.last, contains('avisó que está bien'));
        expect(estado.alertaAbierta, isNull);
        expect(estado.ultimoEstoyBien, isNotNull);
        expect(control.activa, isFalse);
      });
    });

    test('funciona también desde Inicio, con la pantalla ya cerrada', () {
      conReloj((tiempo, control) {
        control.pedirAyuda();
        tiempo.elapse(const Duration(seconds: 1));
        control.cerrar();
        expect(estado.alertaAbierta, isNotNull);

        control.yaEstoyBien();
        tiempo.elapse(const Duration(seconds: 1));
        expect(servidor.resueltas, hasLength(1));
        expect(estado.alertaAbierta, isNull);
      });
    });
  });

  test('una prueba no deja una alerta abierta', () {
    conReloj((tiempo, control) {
      control.iniciar(prueba: true);
      tiempo.elapse(const Duration(seconds: 12));
      expect(servidor.recibidas.single.prueba, isTrue);
      expect(sms.enviados[ana.celular]!.single, contains('PRUEBA'));
      expect(estado.alertaAbierta, isNull);
      expect(enviadas().single.detalle, startsWith('Prueba.'));
    });
  });
}
