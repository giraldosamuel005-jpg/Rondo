import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/models/evento.dart';
import 'package:rondo/core/models/medicamento.dart';
import 'package:rondo/core/state/app_state.dart';

Medicamento losartan({
  int porToma = 1,
  int cadaHoras = 8,
  int disponibles = 30,
  DateTime? primera,
}) =>
    Medicamento(
      id: 'm1',
      nombre: 'Losartán',
      dosis: '50 mg',
      unidadesPorToma: porToma,
      frecuenciaHoras: cadaHoras,
      unidadesDisponibles: disponibles,
      primeraToma: primera ?? DateTime(2026, 10, 25, 8),
    );

void main() {
  group('RF-21: días restantes', () {
    test('1 pastilla cada 8 h con 30 pastillas → 3 al día → 10 días', () {
      final m = losartan();
      expect(m.unidadesPorDia, 3);
      expect(m.diasRestantes, 10);
      expect(m.seEstaAcabando, isFalse);
    });

    test('se redondea hacia abajo', () {
      // 2 por toma cada 12 h = 4 al día; 15 / 4 = 3,75 → 3 días.
      expect(losartan(porToma: 2, cadaHoras: 12, disponibles: 15).diasRestantes, 3);
    });

    test('con 3 días o menos avisa que se está acabando', () {
      final m = losartan(disponibles: 6); // 2 días
      expect(m.seEstaAcabando, isTrue);
      expect(m.avisoReponer, 'Te quedan 2 días de Losartán. Recuerda reponerlo.');
    });
  });

  group('horarios', () {
    final primera = DateTime(2026, 10, 25, 8);

    test('antes de empezar, la próxima es la primera toma', () {
      expect(losartan().proximaToma(DateTime(2026, 10, 25, 6)), primera);
    });

    test('después, la próxima es la siguiente cada 8 h', () {
      expect(losartan().proximaToma(DateTime(2026, 10, 25, 9)), DateTime(2026, 10, 25, 16));
      expect(losartan().proximaToma(DateTime(2026, 10, 25, 23)), DateTime(2026, 10, 26));
    });

    test('la dosis que toca: la próxima si falta una hora o menos, si no la anterior', () {
      final m = losartan();
      expect(m.dosisActual(DateTime(2026, 10, 25, 15, 30)), DateTime(2026, 10, 25, 16));
      expect(m.dosisActual(DateTime(2026, 10, 25, 10)), DateTime(2026, 10, 25, 8));
    });
  });

  group('RF-20: validaciones', () {
    String? validar({
      String nombre = 'Losartán',
      String dosis = '50 mg',
      int? frecuencia = 8,
      int porToma = 1,
      int? disponibles = 30,
      List<Medicamento> otros = const [],
      String? idEditando,
    }) =>
        Medicamento.validar(
          nombre: nombre,
          dosis: dosis,
          frecuenciaHoras: frecuencia,
          unidadesPorToma: porToma,
          unidadesDisponibles: disponibles,
          otros: otros,
          idEditando: idEditando,
        );

    test('completo y nuevo: sin error', () => expect(validar(), isNull));

    test('falta nombre, dosis o frecuencia', () {
      expect(validar(nombre: ' '), Medicamento.errorIncompleto);
      expect(validar(dosis: ''), Medicamento.errorIncompleto);
      expect(validar(frecuencia: null), Medicamento.errorIncompleto);
    });

    test('unidades por toma en cero', () {
      expect(validar(porToma: 0), Medicamento.errorUnidadesPorToma);
    });

    test('sin unidades disponibles', () {
      expect(validar(disponibles: null), Medicamento.errorDisponibles);
    });

    test('repetido sin importar mayúsculas, salvo que sea el mismo al editar', () {
      final otros = [losartan()];
      expect(validar(nombre: 'losartán ', otros: otros), Medicamento.errorRepetido);
      expect(validar(otros: otros, idEditando: 'm1'), isNull);
    });
  });

  group('RF-22: tomas en el estado', () {
    late AppState estado;
    final ahora = DateTime(2026, 10, 25, 8, 10);

    setUp(() {
      estado = AppState();
      estado.agregarMedicamento(losartan(disponibles: 10));
    });

    test('al empezar no hay cumplimiento', () {
      expect(estado.cumplimiento, isNull);
    });

    test('tomar descuenta unidades y queda en el Historial', () {
      expect(estado.registrarToma('m1', tomada: true, ahora: ahora), isTrue);
      expect(estado.medicamento('m1')!.unidadesDisponibles, 9);
      expect(estado.eventos.first.tipo, TipoEvento.tomaRegistrada);
      expect(estado.cumplimiento, 100);
    });

    test('la misma dosis no se registra dos veces', () {
      estado.registrarToma('m1', tomada: true, ahora: ahora);
      expect(estado.registrarToma('m1', tomada: true, ahora: ahora), isFalse);
      expect(estado.medicamento('m1')!.unidadesDisponibles, 9);
    });

    test('no tomarla no descuenta y baja el cumplimiento', () {
      estado.registrarToma('m1', tomada: true, ahora: ahora);
      estado.registrarToma('m1', tomada: false, ahora: ahora.add(const Duration(hours: 8)));
      expect(estado.medicamento('m1')!.unidadesDisponibles, 9);
      expect(estado.cumplimiento, 50);
      expect(estado.eventos.first.tipo, TipoEvento.tomaOmitida);
    });

    test('eliminar un medicamento borra sus tomas', () {
      estado.registrarToma('m1', tomada: true, ahora: ahora);
      estado.eliminarMedicamento('m1');
      expect(estado.medicamentos, isEmpty);
      expect(estado.cumplimiento, isNull);
    });

    test('después de registrar una dosis, la próxima pasa a la siguiente', () {
      estado.registrarToma('m1', tomada: true, ahora: DateTime(2026, 10, 25, 7, 30));
      final p = estado.proximaToma(DateTime(2026, 10, 25, 7, 40));
      expect(p!.hora, DateTime(2026, 10, 25, 16));
    });

    test('con 1 día dice "queda" en singular', () {
      expect(losartan(disponibles: 3).diasTexto, 'Queda 1 día');
      expect(losartan(disponibles: 3).avisoReponer, 'Te queda 1 día de Losartán. Recuerda reponerlo.');
      expect(losartan(disponibles: 6).diasTexto, 'Quedan 2 días');
    });

    test('la próxima toma general es la más cercana', () {
      estado.agregarMedicamento(Medicamento(
        id: 'm2',
        nombre: 'Metformina',
        dosis: '850 mg',
        unidadesPorToma: 1,
        frecuenciaHoras: 12,
        unidadesDisponibles: 20,
        primeraToma: DateTime(2026, 10, 25, 9),
      ));
      final p = estado.proximaToma(DateTime(2026, 10, 25, 8, 30));
      expect(p!.medicamento.id, 'm2');
      expect(p.hora, DateTime(2026, 10, 25, 9));
    });
  });
}
