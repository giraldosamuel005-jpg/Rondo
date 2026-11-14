import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/models/medicamento.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/recordatorios/recordatorio.dart';
import 'package:rondo/core/recordatorios/recordatorios.dart';
import 'package:rondo/core/state/app_state.dart';

/// Un "celular" que solo anota lo que le piden programar.
class ProgramadorFalso implements ProgramadorNotificaciones {
  ProgramadorFalso({this.conPermiso = true, this.aceptaPermiso = true, this.abierta});

  bool conPermiso;
  final bool aceptaPermiso;
  final String? abierta;

  List<Recordatorio> programados = [];
  int vecesProgramado = 0;
  int vecesPedido = 0;
  void Function(String medicamentoId)? tocar;

  @override
  Future<void> iniciar({required void Function(String medicamentoId) alTocar}) async => tocar = alTocar;

  @override
  Future<String?> abiertaDesde() async => abierta;

  @override
  Future<bool> permitidas() async => conPermiso;

  @override
  Future<bool> pedirPermiso() async {
    vecesPedido++;
    return conPermiso = aceptaPermiso;
  }

  @override
  Future<void> reemplazar(List<Recordatorio> plan) async {
    vecesProgramado++;
    programados = plan;
  }
}

void main() {
  final ahora = DateTime(2026, 11, 13, 10);

  Medicamento losartan({int cada = 12, DateTime? primera}) => Medicamento(
        id: 'med-1',
        nombre: 'Losartán',
        dosis: '50 mg',
        unidadesPorToma: 1,
        frecuenciaHoras: cada,
        unidadesDisponibles: 30,
        primeraToma: primera ?? DateTime(2026, 11, 10, 8),
      );

  group('qué avisos se programan', () {
    List<Recordatorio> planear(List<Medicamento> meds, {Set<DateTime> registradas = const {}}) =>
        Recordatorio.planear(
          medicamentos: meds,
          yaRegistrada: (_, hora) => registradas.contains(hora),
          ahora: ahora,
        );

    test('las tomas de los próximos 7 días, cada una a su hora', () {
      final plan = planear([losartan()]);

      expect(plan.first.hora, DateTime(2026, 11, 13, 20)); // La de las 8 a. m. ya pasó
      expect(plan[1].hora, DateTime(2026, 11, 14, 8));
      expect(plan, hasLength(14)); // 2 al día × 7 días
      expect(plan.last.hora.isAfter(ahora.add(Recordatorio.horizonte)), isFalse);
    });

    test('el aviso dice qué medicamento y qué dosis', () {
      final aviso = planear([losartan()]).first;

      expect(aviso.titulo, 'Hora de tu medicamento');
      expect(aviso.cuerpo, contains('Losartán 50 mg'));
      expect(aviso.medicamentoId, 'med-1');
    });

    test('una toma ya registrada no vuelve a sonar', () {
      final plan = planear([losartan()], registradas: {DateTime(2026, 11, 13, 20)});

      expect(plan.first.hora, DateTime(2026, 11, 14, 8));
    });

    test('con varios medicamentos van en orden de hora y sin IDs repetidos', () {
      final otro = Medicamento(
        id: 'med-2',
        nombre: 'Metformina',
        dosis: '850 mg',
        unidadesPorToma: 1,
        frecuenciaHoras: 8,
        unidadesDisponibles: 60,
        primeraToma: DateTime(2026, 11, 10, 7),
      );
      final plan = planear([losartan(), otro]);

      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].hora.isBefore(plan[i - 1].hora), isFalse);
      }
      expect({for (final r in plan) r.id}, hasLength(plan.length));
    });

    test('la misma toma siempre tiene el mismo ID', () {
      expect(planear([losartan()]).first.id, planear([losartan()]).first.id);
    });

    test('sin medicamentos no hay avisos', () => expect(planear(const []), isEmpty));
  });

  group('en la app', () {
    AppState persona() => AppState()
      ..iniciarSesion('3104567890')
      ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi)
      ..activarRonda();

    Future<Recordatorios> crear(AppState estado, ProgramadorFalso celular) async {
      final recordatorios = Recordatorios(estado, celular, reloj: () => ahora);
      addTearDown(recordatorios.dispose);
      await pumpEventQueue();
      return recordatorios;
    }

    test('al agregar un medicamento quedan programados sus avisos', () async {
      final estado = persona();
      final celular = ProgramadorFalso();
      final recordatorios = await crear(estado, celular);
      expect(celular.programados, isEmpty);

      estado.agregarMedicamento(losartan());
      await pumpEventQueue();

      expect(celular.programados, hasLength(14));
      expect(recordatorios.aviso, isNull);
    });

    test('al registrar la toma, su aviso se quita', () async {
      // Faltan 30 minutos para la de las 10:30: es la que "toca".
      final estado = persona()..agregarMedicamento(losartan(primera: DateTime(2026, 11, 13, 10, 30)));
      final celular = ProgramadorFalso();
      await crear(estado, celular);
      expect(celular.programados.first.hora, DateTime(2026, 11, 13, 10, 30));

      estado.registrarToma('med-1', tomada: true, ahora: ahora);
      await pumpEventQueue();

      expect(celular.programados.first.hora, DateTime(2026, 11, 13, 22, 30));
    });

    test('si nada cambia en los medicamentos no se reprograma', () async {
      final estado = persona()..agregarMedicamento(losartan());
      final celular = ProgramadorFalso();
      await crear(estado, celular);
      final veces = celular.vecesProgramado;

      estado.confirmarEstoyBien();
      await pumpEventQueue();

      expect(celular.vecesProgramado, veces);
    });

    test('al eliminar el medicamento o cerrar sesión se quitan los avisos', () async {
      final estado = persona()..agregarMedicamento(losartan());
      final celular = ProgramadorFalso();
      await crear(estado, celular);

      estado.cerrarSesion();
      await pumpEventQueue();

      expect(celular.programados, isEmpty);
    });

    test('sin permiso lo pide una vez; si la persona dice que no, lo avisa', () async {
      final estado = persona()..agregarMedicamento(losartan());
      final celular = ProgramadorFalso(conPermiso: false, aceptaPermiso: false);
      final recordatorios = await crear(estado, celular);

      expect(celular.vecesPedido, 1);
      expect(recordatorios.aviso, Recordatorios.errorPermiso);

      estado.confirmarEstoyBien();
      await pumpEventQueue();
      expect(celular.vecesPedido, 1); // No insiste solo
    });

    test('sin medicamentos no pide el permiso ni avisa nada', () async {
      final celular = ProgramadorFalso(conPermiso: false);
      final recordatorios = await crear(persona(), celular);

      expect(celular.vecesPedido, 0);
      expect(recordatorios.aviso, isNull);
    });

    test('tocar un aviso dice qué medicamento abrir', () async {
      final celular = ProgramadorFalso();
      final recordatorios = await crear(persona(), celular);
      final tocados = <String>[];
      final sub = recordatorios.tocados.listen(tocados.add);
      addTearDown(sub.cancel);

      celular.tocar!('med-1');
      await pumpEventQueue();

      expect(tocados, ['med-1']);
    });

    test('si la app se abrió tocando un aviso, lo entrega una sola vez', () async {
      final recordatorios = await crear(persona(), ProgramadorFalso(abierta: 'med-1'));

      expect(recordatorios.tomarAbiertaDesde(), 'med-1');
      expect(recordatorios.tomarAbiertaDesde(), isNull);
    });
  });
}
