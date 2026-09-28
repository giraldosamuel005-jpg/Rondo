import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rondo/main.dart';

void main() {
  testWidgets('muestra la pantalla inicial de Rondó', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: RondoApp()),
    );

    expect(find.text('Rondó'), findsOneWidget);
    expect(find.text('Tu seguridad, más cerca.'), findsOneWidget);
  });
}
