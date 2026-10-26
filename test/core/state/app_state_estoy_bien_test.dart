import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/models/evento.dart';
import 'package:rondo/core/state/app_state.dart';

void main() {
  late AppState estado;

  setUp(() => estado = AppState());

  test('al empezar nunca ha confirmado "Estoy bien"', () {
    expect(estado.ultimoEstoyBien, isNull);
  });

  test('"Estoy bien" queda en el Historial con su hora (RF-12)', () {
    final antes = DateTime.now();
    estado.confirmarEstoyBien();

    expect(estado.eventos.first.tipo, TipoEvento.estoyBien);
    expect(estado.ultimoEstoyBien, isNotNull);
    expect(estado.ultimoEstoyBien!.isBefore(antes), isFalse);
  });

  test('la última confirmación es la más reciente, aunque haya otros eventos después', () async {
    estado.confirmarEstoyBien();
    final primera = estado.ultimoEstoyBien;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    estado.confirmarEstoyBien();
    estado.alternarPausa();

    expect(estado.ultimoEstoyBien!.isAfter(primera!), isTrue);
    expect(estado.eventos.first.tipo, TipoEvento.rondaPausada);
  });

  test('cerrar sesión borra las confirmaciones', () {
    estado.confirmarEstoyBien();
    estado.cerrarSesion();
    expect(estado.ultimoEstoyBien, isNull);
  });
}
