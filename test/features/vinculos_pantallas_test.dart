import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/core/vinculos/vinculo.dart';
import 'package:rondo/core/vinculos/vinculos.dart';
import 'package:rondo/features/contacts/contacts_tab.dart';
import 'package:rondo/features/cuidador/personas_tab.dart';

import '../support/servidor_vinculos_falso.dart';

void main() {
  const canal = MethodChannel('plugins.flutter.io/url_launcher');
  const ana = Contacto(nombre: 'Ana', celular: '3001234567');
  late ServidorFalso servidor;
  String? abierto;

  setUp(() {
    servidor = ServidorFalso();
    abierto = null;
  });

  Future<void> mostrar(WidgetTester tester, AppState estado, Vinculos vinculos, Widget pantalla) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (llamada) async {
      abierto = (llamada.arguments as Map)['url'] as String?;
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null));
    addTearDown(vinculos.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: estado),
          ChangeNotifierProvider.value(value: vinculos),
        ],
        child: MaterialApp(
          // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
          theme: ThemeData(extensions: [RondoColors.light]),
          home: Scaffold(body: pantalla),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  AppState persona() => AppState()
    ..iniciarSesion('3104567890')
    ..guardarPerfil(nombre: 'Rosa Gómez', tipo: TipoCuenta.paraMi)
    ..agregarContacto(ana)
    ..activarRonda();

  AppState cuidador() => AppState()
    ..iniciarSesion('3001234567')
    ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);

  group('Contactos → Quién te cuida', () {
    testWidgets('invitar abre el SMS al contacto con el código', (tester) async {
      final estado = persona();
      await mostrar(tester, estado, Vinculos(servidor.celular('rosa'), estado), const ContactsTab());

      expect(find.text('Sin invitar'), findsOneWidget);
      await tocar(tester, 'Invitar a cuidarme');

      final codigo = servidor.invitaciones.keys.single;
      expect(abierto, startsWith('sms:+573001234567?body='));
      expect(Uri.decodeComponent(abierto!), contains(codigo));
      expect(find.text('Invitación enviada · código $codigo'), findsOneWidget);
    });

    testWidgets('cuando acepta dice "Te cuida", y se puede dejar de compartir', (tester) async {
      final estado = persona();
      final vinculos = Vinculos(servidor.celular('rosa'), estado);
      await mostrar(tester, estado, vinculos, const ContactsTab());
      await tocar(tester, 'Invitar a cuidarme');

      // Ana acepta en su celular.
      await tester.runAsync(() => servidor.celular('ana').aceptarInvitacion(
            servidor.invitaciones.keys.single,
            cuidadorUid: 'ana',
            cuidadorNombre: 'Ana',
          ));
      await tester.pumpAndSettle();
      expect(find.text('Te cuida'), findsOneWidget);

      await tocar(tester, 'Dejar de compartir');
      expect(find.text('¿Dejar de compartir con Ana?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Dejar de compartir').last);
      await tester.pumpAndSettle();

      expect(servidor.vinculos.values.single.activo, isFalse);
      expect(find.text('Sin invitar'), findsOneWidget);
    });

    testWidgets('sin internet avisa y no queda como invitada', (tester) async {
      final estado = persona();
      await mostrar(tester, estado, Vinculos(servidor.celular('rosa'), estado), const ContactsTab());
      servidor.sinRed = true;

      await tocar(tester, 'Invitar a cuidarme');

      expect(find.text(Vinculos.errorConexion), findsOneWidget);
      expect(find.text('Sin invitar'), findsOneWidget);
      expect(abierto, isNull);
    });
  });

  group('Personas → código de invitación', () {
    Future<String> invitacionDeRosa() async {
      final rosa = servidor.celular('rosa');
      await rosa.crearInvitacion(Invitacion(
        codigo: 'K7M2QX',
        personaUid: 'rosa',
        personaNombre: 'Rosa Gómez',
        personaCelular: '3104567890',
        celularInvitado: '3001234567',
        nombreInvitado: 'Ana',
        estado: EstadoInvitacion.pendiente,
        expiraEn: DateTime.now().add(Invitacion.vigencia),
      ));
      return 'K7M2QX';
    }

    testWidgets('con el código correcto aparece la persona', (tester) async {
      final codigo = await invitacionDeRosa();
      final estado = cuidador();
      await mostrar(tester, estado, Vinculos(servidor.celular('ana'), estado), PersonasTab(onVerAjustes: () {}));

      await tocar(tester, 'Tengo un código de invitación');
      await tester.enterText(find.byType(TextField), codigo.toLowerCase());
      await tocar(tester, 'Aceptar invitación');

      expect(find.text('Listo. Ahora cuidas a Rosa.'), findsOneWidget);
      expect(find.text('Rosa Gómez'), findsOneWidget);
      expect(find.text('Sin datos aún'), findsOneWidget); // Rosa todavía no ha compartido nada
    });

    testWidgets('con un código que no existe lo dice y no sale de la pantalla', (tester) async {
      final estado = cuidador();
      await mostrar(tester, estado, Vinculos(servidor.celular('ana'), estado), PersonasTab(onVerAjustes: () {}));

      await tocar(tester, 'Tengo un código de invitación');
      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tocar(tester, 'Aceptar invitación');

      expect(find.text(Invitacion.errorNoValida), findsOneWidget);
      expect(find.text('Escribe tu código'), findsOneWidget);
    });
  });

  testWidgets('sin servidor no aparece nada de vincular', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: persona(),
        child: MaterialApp(
          theme: ThemeData(extensions: [RondoColors.light]),
          home: const Scaffold(body: ContactsTab()),
        ),
      ),
    );

    expect(find.text('Quién te cuida'), findsNothing);
  });
}
