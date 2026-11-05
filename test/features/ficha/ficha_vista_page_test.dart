import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/ficha_medica.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/features/ficha/codigo_qr_page.dart';
import 'package:rondo/features/ficha/ficha_vista_page.dart';

void main() {
  const ana = Contacto(nombre: 'Ana', celular: '3001234567', relacion: 'Hija');

  AppState estadoConFicha({List<String> alergias = const []}) => AppState()
    ..guardarPerfil(nombre: 'María José', tipo: TipoCuenta.paraMi)
    ..agregarContacto(ana)
    ..darConsentimiento(TipoConsentimiento.datosMedicos)
    ..guardarFichaMedica(FichaMedica(
      tipoSangre: TipoSangre.oNegativo,
      celularContactoEmergencia: ana.celular,
      alergias: alergias,
    ));

  Future<void> mostrar(WidgetTester tester, AppState estado, Widget pantalla) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
          theme: ThemeData(extensions: [RondoColors.light]),
          home: pantalla,
        ),
      ),
    );
  }

  testWidgets('muestra el nombre, la sangre, las alergias y el contacto', (tester) async {
    await mostrar(tester, estadoConFicha(alergias: ['Penicilina', 'Maní']), const FichaVistaPage());

    expect(find.text('María José'), findsOneWidget);
    expect(find.text('O-'), findsOneWidget);
    expect(find.text('Penicilina'), findsOneWidget);
    expect(find.text('Maní'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Hija · +57 300 123 4567'), findsOneWidget);
  });

  testWidgets('es solo lectura: no hay campos ni botones para cambiar nada', (tester) async {
    await mostrar(tester, estadoConFicha(), const FichaVistaPage());

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(InkWell), findsOneWidget); // Solo la flecha para volver
  });

  testWidgets('sin alergias lo dice', (tester) async {
    await mostrar(tester, estadoConFicha(), const FichaVistaPage());

    expect(find.text('Sin alergias conocidas.'), findsOneWidget);
  });

  testWidgets('si quitaron el contacto de emergencia, lo avisa', (tester) async {
    final estado = estadoConFicha()..quitarContacto(ana);
    await mostrar(tester, estado, const FichaVistaPage());

    expect(find.textContaining('Sin contacto'), findsOneWidget);
  });

  testWidgets('sin ficha no falla', (tester) async {
    await mostrar(tester, AppState(), const FichaVistaPage());

    expect(find.text('Aún no tienes ficha médica.'), findsOneWidget);
  });

  testWidgets('se abre desde la pantalla del QR', (tester) async {
    await mostrar(tester, estadoConFicha(), const CodigoQrPage());

    await tester.scrollUntilVisible(find.text('Ver cómo se ve'), 200);
    await tester.tap(find.text('Ver cómo se ve'));
    await tester.pumpAndSettle();

    expect(find.byType(FichaVistaPage), findsOneWidget);
    expect(find.text('Así se ve tu ficha'), findsOneWidget);
  });
}
