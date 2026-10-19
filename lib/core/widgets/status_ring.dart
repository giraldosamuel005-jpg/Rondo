import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Anillo de estado de Inicio: turquesa con el pulso del logo cuando la ronda
/// está activa; gris cuando está en pausa.
class StatusRing extends StatelessWidget {
  const StatusRing({super.key, required this.activa, this.size = 168});

  final bool activa;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final colorPrincipal = activa ? c.accent : c.textSecondary.withValues(alpha: 0.6);

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        // En oscuro, un halo turquesa alrededor del anillo.
        decoration: (oscuro && activa)
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.25),
                    blurRadius: 50,
                    blurStyle: BlurStyle.outer,
                  ),
                ],
              )
            : null,
        child: CustomPaint(
          painter: _AnilloPainter(
            progreso: 0.72, // Decorativo: progreso del día
            pista: c.toggleOff,
            colores: activa
                ? [c.accent.withValues(alpha: 0.25), c.accent]
                : [c.toggleOff, colorPrincipal],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(56, 28),
                  painter: PulsoPainter(colorPrincipal),
                ),
                const SizedBox(height: 8),
                Text(
                  activa ? 'Vigilando' : 'En pausa',
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorPrincipal,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  _AnilloPainter({required this.progreso, required this.pista, required this.colores});

  final double progreso;
  final Color pista;
  final List<Color> colores;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 12.0;
    final centro = size.center(Offset.zero);
    final radio = (size.shortestSide - grosor) / 2;
    final area = Rect.fromCircle(center: centro, radius: radio);

    // Pista completa de fondo.
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..color = pista
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor,
    );

    // Arco de progreso con degradado cónico, empezando arriba.
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      // El degradado vuelve al color inicial después del arco, para que el
      // borde redondeado del inicio no tome el color brillante del final.
      ..shader = SweepGradient(
        colors: [colores.first, colores.last, colores.first],
        stops: [0, progreso, 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(area);
    canvas.drawArc(area, -math.pi / 2, 2 * math.pi * progreso, false, pincel);
  }

  @override
  bool shouldRepaint(_AnilloPainter old) =>
      old.progreso != progreso || old.pista != pista || old.colores != colores;
}

/// La línea de pulso cardiaco del logo.
class PulsoPainter extends CustomPainter {
  PulsoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Puntos en proporción (0..1) del ancho y alto.
    const puntos = [
      Offset(0, 0.5),
      Offset(0.28, 0.5),
      Offset(0.4, 0.1),
      Offset(0.54, 0.92),
      Offset(0.65, 0.35),
      Offset(0.73, 0.5),
      Offset(1, 0.5),
    ];
    final camino = Path()
      ..moveTo(puntos.first.dx * size.width, puntos.first.dy * size.height);
    for (final p in puntos.skip(1)) {
      camino.lineTo(p.dx * size.width, p.dy * size.height);
    }

    canvas.drawPath(
      camino,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(PulsoPainter old) => old.color != color;
}
