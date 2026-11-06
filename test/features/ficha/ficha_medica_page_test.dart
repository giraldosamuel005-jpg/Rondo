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
    await tester.ensureVisible(find.text(texto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  /// Pasa de largo enfermedades, medicamentos, fecha de nacimiento y notas.
  Future<void> saltarOpcionales(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tocar(tester, 'Continuar');
    }
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

    // Enfermedades: una de la lista y otra escrita sin tocar "Agregar"
    expect(find.text('¿Tienes alguna enfermedad?'), findsOneWidget);
    await tocar(tester, 'Diabetes');
    await tester.enterText(find.byType(TextField), 'Artritis');
    await tocar(tester, 'Continuar');

    // Medicamentos
    expect(find.text('¿Mostramos tus medicamentos?'), findsOneWidget);
    await tocar(tester, 'Mostrar mis medicamentos en la ficha');
    await tocar(tester, 'Continuar');

    // Fecha de nacimiento
    expect(find.text('¿Cuándo naciste?'), findsOneWidget);
    await tocar(tester, 'Elegir fecha');
    await tocar(tester, '1960');
    await tocar(tester, '15');
    await tocar(tester, 'OK');
    expect(find.text('15 de enero de 1960'), findsOneWidget);
    await tocar(tester, 'Continuar');

    // Notas
    expect(find.text('¿Algo más que deban saber?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Uso marcapasos');
    await tocar(tester, 'Continuar');

    // Contacto
    await tocar(tester, 'Luis');
    await tocar(tester, 'Guardar ficha');

    final ficha = estado.fichaMedica!;
    expect(ficha.tipoSangre, TipoSangre.oPositivo);
    expect(ficha.alergias, ['Penicilina', 'Maní']);
    expect(ficha.enfermedades, ['Diabetes', 'Artritis']);
    expect(ficha.mostrarMedicamentos, isTrue);
    expect(ficha.fechaNacimiento, DateTime(1960, 1, 15));
    expect(ficha.notas, 'Uso marcapasos');
    expect(ficha.celularContactoEmergencia, '3104445566');
    expect(resultado, isTrue);
  });

  testWidgets('lo opcional se puede saltar', (tester) async {
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    await abrirFicha(tester);

    await tocar(tester, 'O-');
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Continuar'); // Sin alergias
    await saltarOpcionales(tester);
    await tocar(tester, 'Ana');
    await tocar(tester, 'Guardar ficha');

    final ficha = estado.fichaMedica!;
    expect(ficha.enfermedades, isEmpty);
    expect(ficha.mostrarMedicamentos, isFalse);
    expect(ficha.fechaNacimiento, isNull);
    expect(ficha.notas, isEmpty);
  });

  testWidgets('marcar una enfermedad dos veces la desmarca', (tester) async {
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    await abrirFicha(tester);

    await tocar(tester, 'O-');
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Asma');
    await tocar(tester, 'Asma');
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Continuar');
    await tocar(tester, 'Ana');
    await tocar(tester, 'Guardar ficha');

    expect(estado.fichaMedica!.enfermedades, isEmpty);
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
    await saltarOpcionales(tester);
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
        enfermedades: ['Asma', 'Artritis'],
        fechaNacimiento: DateTime(1950, 3, 15),
        notas: 'Uso audífonos',
        mostrarMedicamentos: true,
      ));
    await abrirFicha(tester);

    await tocar(tester, 'Continuar'); // Ya tiene B-
    expect(find.text('Polen'), findsOneWidget);
    await tocar(tester, 'Continuar');
    expect(find.text('Artritis'), findsOneWidget); // La escrita a mano sigue ahí
    await saltarOpcionales(tester);
    await tocar(tester, 'Guardar ficha'); // Ya tiene a Ana

    final ficha = estado.fichaMedica!;
    expect(ficha.tipoSangre, TipoSangre.bNegativo);
    expect(ficha.enfermedades, ['Asma', 'Artritis']);
    expect(ficha.fechaNacimiento, DateTime(1950, 3, 15));
    expect(ficha.notas, 'Uso audífonos');
    expect(ficha.mostrarMedicamentos, isTrue);
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
