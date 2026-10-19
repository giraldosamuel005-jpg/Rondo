import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/ficha_medica.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/core/widgets/rondo_back_button.dart';
import 'package:rondo/features/ficha/ficha_medica_page.dart';

void main() {
  late AppState estado;
  bool? resultado;

  /// Abre la ficha desde un botón, como lo hace Ajustes, para ver qué devuelve.
  Future<void> abrirFicha(WidgetTester tester) async {
    // Celular de 360 x 800: que quepa todo sin hacer scroll.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
          theme: ThemeData(extensions: [RondoColors.light]),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const FichaMedicaPage()),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  setUp(() {
    resultado = null;
    estado = AppState()
      ..agregarContacto(const Contacto(nombre: 'Ana', celular: '3001112233'))
      ..agregarContacto(const Contacto(nombre: 'Luis', celular: '3104445566'));
  });

  testWidgets('flujo completo: consentimiento, sangre, alergias y contacto', (tester) async {
    await abrirFicha(tester);

    // Consentimiento
    expect(find.text('Tus datos médicos'), findsOneWidget);
    await tocar(tester, 'Acepto que Rondó guarde mis datos médicos.');
    await tocar(tester, 'Continuar');
    expect(estado.tieneConsentimiento(TipoConsentimiento.datosMedicos), isTrue);

    // Tipo de sangre
    await tocar(tester, 'O+');
    await tocar(tester, 'Continuar');

    // Alergias: una con el botón y otra escrita sin tocar "Agregar"
    await tester.enterText(find.byType(TextField), 'Penicilina');
    await tocar(tester, 'Agregar');
    await tester.enterText(find.byType(TextField), 'Maní');
    await tocar(tester, 'Continuar');

    // Contacto
    await tocar(tester, 'Luis');
    await tocar(tester, 'Guardar ficha');

    final ficha = estado.fichaMedica!;
    expect(ficha.tipoSangre, TipoSangre.oPositivo);
    expect(ficha.alergias, ['Penicilina', 'Maní']);
    expect(ficha.celularContactoEmergencia, '3104445566');
    expect(resultado, isTrue);
  });

  testWidgets('sin aceptar el consentimiento no avanza', (tester) async {
    await abrirFicha(tester);

    await tocar(tester, 'Continuar');

    expect(find.text('Necesitamos tu consentimiento para guardar tus datos médicos.'), findsOneWidget);
    expect(find.text('Tus datos médicos'), findsOneWidget);
    expect(estado.tieneConsentimiento(TipoConsentimiento.datosMedicos), isFalse);
  });

  testWidgets('sin tipo de sangre no avanza', (tester) async {
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    await abrirFicha(tester);

    await tocar(tester, 'Continuar');

    expect(find.text('Selecciona un tipo de sangre válido.'), findsOneWidget);
  });

  testWidgets('sin contacto no guarda', (tester) async {
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    await abrirFicha(tester);

    await tocar(tester, 'A-');
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Continuar'); // Sin alergias
    await tocar(tester, 'Guardar ficha');

    expect(find.text('Elige un contacto de emergencia de tu lista.'), findsOneWidget);
    expect(estado.fichaMedica, isNull);
  });

  testWidgets('con consentimiento ya dado, empieza en el tipo de sangre', (tester) async {
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    await abrirFicha(tester);

    expect(find.text('¿Cuál es tu tipo de sangre?'), findsOneWidget);
  });

  testWidgets('al editar, arranca con lo que ya tenía', (tester) async {
    estado
      ..darConsentimiento(TipoConsentimiento.datosMedicos)
      ..guardarFichaMedica(FichaMedica(
        tipoSangre: TipoSangre.bNegativo,
        celularContactoEmergencia: '3001112233',
        alergias: ['Polen'],
      ));
    await abrirFicha(tester);

    await tocar(tester, 'Continuar'); // Ya tiene B-
    expect(find.text('Polen'), findsOneWidget);
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Guardar ficha'); // Ya tiene a Ana

    expect(estado.fichaMedica!.tipoSangre, TipoSangre.bNegativo);
    expect(resultado, isTrue);
  });

  testWidgets('la flecha atrás vuelve al paso anterior', (tester) async {
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    await abrirFicha(tester);

    await tocar(tester, 'O-');
    await tocar(tester, 'Continuar');
    expect(find.text('¿Tienes alergias?'), findsOneWidget);

    await tester.tap(find.byType(RondoBackButton));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuál es tu tipo de sangre?'), findsOneWidget);
  });
}
