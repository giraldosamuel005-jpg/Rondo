import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/ficha_medica.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/features/ficha/codigo_qr_page.dart';
import 'package:rondo/features/ficha/ficha_medica_card.dart';

void main() {
  late AppState estado;

  setUp(() {
    estado = AppState()
      ..agregarContacto(const Contacto(nombre: 'Ana', celular: '3001234567'))
      ..darConsentimiento(TipoConsentimiento.datosMedicos)
      ..guardarFichaMedica(FichaMedica(
        tipoSangre: TipoSangre.oPositivo,
        celularContactoEmergencia: '3001234567',
      ));
  });

  Future<void> mostrar(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
          theme: ThemeData(extensions: [RondoColors.light]),
          home: Scaffold(body: pantalla),
        ),
      ),
    );
  }

  testWidgets('el QR lleva el enlace con el token', (tester) async {
    await mostrar(tester, const CodigoQrPage());

    expect(find.byKey(ValueKey(estado.codigoQr!.enlace)), findsOneWidget);
    expect(find.textContaining('todavía no se puede consultar'), findsOneWidget);
  });

  testWidgets('crear un código nuevo pide confirmación y cambia el QR', (tester) async {
    await mostrar(tester, const CodigoQrPage());
    final viejo = estado.codigoQr!.token;
    // El botón queda debajo del QR: se baja hasta verlo.
    await tester.scrollUntilVisible(find.text('Crear un código nuevo'), 200);

    await tester.tap(find.text('Crear un código nuevo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(estado.codigoQr!.token, viejo);

    await tester.tap(find.text('Crear un código nuevo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear código nuevo'));
    await tester.pumpAndSettle();

    expect(estado.codigoQr!.token, isNot(viejo));
    expect(find.byKey(ValueKey(estado.codigoQr!.enlace)), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Listo. El código anterior ya no es válido.'), findsOneWidget);
  });

  testWidgets('en Ajustes, el botón del QR solo aparece si hay ficha', (tester) async {
    await mostrar(tester, const FichaMedicaCard());
    expect(find.text('Ver mi código QR'), findsOneWidget);

    await tester.tap(find.text('Ver mi código QR'));
    await tester.pumpAndSettle();
    expect(find.byType(CodigoQrPage), findsOneWidget);

    estado.retirarConsentimiento(TipoConsentimiento.datosMedicos);
    await mostrar(tester, const FichaMedicaCard());
    expect(find.text('Ver mi código QR'), findsNothing);
  });
}
