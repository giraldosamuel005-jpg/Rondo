import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/models/evento.dart';
import 'package:rondo/core/models/medicamento.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/features/history/history_tab.dart';

void main() {
  Evento evento(TipoEvento tipo, DateTime fecha) => Evento(tipo: tipo, fecha: fecha);

  group('agrupar por día', () {
    test('junta los del mismo día y conserva el orden', () {
      final grupos = agruparPorDia([
        evento(TipoEvento.estoyBien, DateTime(2026, 11, 4, 20)),
        evento(TipoEvento.rondaPausada, DateTime(2026, 11, 4, 8)),
        evento(TipoEvento.rondaActivada, DateTime(2026, 11, 3, 23, 59)),
      ]);

      expect(grupos.map((g) => g.dia), [DateTime(2026, 11, 4), DateTime(2026, 11, 3)]);
      expect(grupos.first.eventos.map((e) => e.tipo), [TipoEvento.estoyBien, TipoEvento.rondaPausada]);
      expect(grupos.last.eventos.single.tipo, TipoEvento.rondaActivada);
    });

    test('sin eventos no hay grupos', () {
      expect(agruparPorDia(const []), isEmpty);
    });

    test('el mismo día de otro mes no se mezcla', () {
      final grupos = agruparPorDia([
        evento(TipoEvento.estoyBien, DateTime(2026, 11, 4)),
        evento(TipoEvento.estoyBien, DateTime(2026, 10, 4)),
      ]);
      expect(grupos, hasLength(2));
    });
  });

  test('cada filtro incluye solo lo suyo', () {
    final alertas = {TipoEvento.alertaEnviada, TipoEvento.alertaCancelada};
    final tomas = {TipoEvento.tomaRegistrada, TipoEvento.tomaOmitida};

    for (final tipo in TipoEvento.values) {
      expect(FiltroHistorial.todo.incluye(tipo), isTrue);
      expect(FiltroHistorial.alertas.incluye(tipo), alertas.contains(tipo));
      expect(FiltroHistorial.medicamentos.incluye(tipo), tomas.contains(tipo));
    }
  });

  group('la pestaña', () {
    Future<void> mostrar(WidgetTester tester, AppState estado) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: estado,
          child: MaterialApp(
            // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
            theme: ThemeData(extensions: [RondoColors.light]),
            home: const Scaffold(body: HistoryTab()),
          ),
        ),
      );
    }

    Future<void> filtrar(WidgetTester tester, String filtro) async {
      await tester.tap(find.text(filtro));
      await tester.pumpAndSettle();
    }

    testWidgets('sin eventos no muestra filtros', (tester) async {
      await mostrar(tester, AppState());

      expect(find.text('Aún no hay nada aquí'), findsOneWidget);
      expect(find.text('Alertas'), findsNothing);
    });

    testWidgets('agrupa bajo "Hoy" y sin repetir el día en cada fila', (tester) async {
      await mostrar(tester, AppState()..activarRonda()..confirmarEstoyBien());

      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Ronda activada'), findsOneWidget);
      expect(find.textContaining('Hoy ·'), findsNothing);
    });

    testWidgets('los filtros muestran solo lo suyo', (tester) async {
      final estado = AppState()
        ..activarRonda()
        ..registrarAlerta(enviada: true)
        ..agregarMedicamento(Medicamento(
          id: 'm1',
          nombre: 'Losartán',
          dosis: '50 mg',
          unidadesPorToma: 1,
          frecuenciaHoras: 8,
          unidadesDisponibles: 30,
          primeraToma: DateTime(2026, 10, 25, 8),
        ));
      estado.registrarToma('m1', tomada: true);
      await mostrar(tester, estado);

      await filtrar(tester, 'Alertas');
      expect(find.text('Alerta enviada'), findsOneWidget);
      expect(find.text('Ronda activada'), findsNothing);
      expect(find.text('Tomaste tu medicamento'), findsNothing);

      await filtrar(tester, 'Medicamentos');
      expect(find.text('Tomaste tu medicamento'), findsOneWidget);
      expect(find.text('Alerta enviada'), findsNothing);

      await filtrar(tester, 'Todo');
      expect(find.text('Ronda activada'), findsOneWidget);
      expect(find.text('Alerta enviada'), findsOneWidget);
      expect(find.text('Tomaste tu medicamento'), findsOneWidget);
    });

    testWidgets('un filtro sin resultados lo explica', (tester) async {
      await mostrar(tester, AppState()..activarRonda());

      await filtrar(tester, 'Alertas');
      expect(find.text('Sin alertas'), findsOneWidget);

      await filtrar(tester, 'Medicamentos');
      expect(find.text('Sin tomas registradas'), findsOneWidget);
    });
  });
}
