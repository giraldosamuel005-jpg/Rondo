import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';
import '../theme/rondo_text.dart';
import 'glass.dart';

/// Anillo de la alerta: círculo de vidrio → anillo ámbar que se vacía
/// con el tiempo → centro sólido con "0:10" y "para avisar".
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.restante,
    required this.segundos,
    this.size = 220,
  });

  /// Proporción de tiempo que queda: 1.0 al empezar, 0.0 al terminar.
  final double restante;

  /// Segundos que se muestran en el centro.
  final int segundos;

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Glass(
          radius: size / 2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: CustomPaint(
              painter: _AnilloPainter(restante: restante, color: c.alert, pista: c.toggleOff),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.alertBg),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '0:${segundos.toString().padLeft(2, '0')}',
                          style: RondoText.countdown(c),
                        ),
                        Text('para avisar', style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  _AnilloPainter({required this.restante, required this.color, required this.pista});

  final double restante;
  final Color color;
  final Color pista;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 14.0;
    final centro = size.center(Offset.zero);
    final radio = (size.shortestSide - grosor) / 2;
    final area = Rect.fromCircle(center: centro, radius: radio);

    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..color = pista
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor,
    );

    if (restante <= 0) return;

    final barrido = 2 * math.pi * restante;
    canvas.drawArc(
      area,
      -math.pi / 2,
      barrido,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round
        ..color = color, // un solo color: la cuenta regresiva se lee mejor
    );
  }

  @override
  bool shouldRepaint(_AnilloPainter old) =>
      old.restante != restante || old.color != color || old.pista != pista;
}
