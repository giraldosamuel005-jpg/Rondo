import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Marca de estado de la ronda (Inicio): un cuadrado sólido de color.
///
/// - Activa: turquesa con la línea de pulso del logo.
/// - En pausa: gris con el símbolo de pausa.
///
/// Reemplaza al anillo con "72 %" que había antes: ese número no medía nada.
/// Esta marca solo dice una cosa y es verdad: si la ronda vigila o no.
class EstadoMarca extends StatelessWidget {
  const EstadoMarca({super.key, required this.activa, this.size = 64});

  final bool activa;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activa ? c.accent : c.neutralSoft,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: activa
            ? CustomPaint(
                size: Size(size * 0.56, size * 0.28),
                painter: PulsoPainter(c.onAccent),
              )
            : Icon(Icons.pause_rounded, size: size * 0.5, color: c.textSecondary),
      ),
    );
  }
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
    final camino = Path()..moveTo(puntos.first.dx * size.width, puntos.first.dy * size.height);
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
