import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/contacto.dart';
import '../theme/rondo_colors.dart';
import 'avatar.dart';

/// Fila de un contacto de emergencia: avatar | nombre + detalle | "1.º".
class ContactRow extends StatelessWidget {
  const ContactRow({
    super.key,
    required this.contacto,
    required this.orden,
    this.onTap,
  });

  final Contacto contacto;

  /// 1 para el primero, 2 para el segundo...
  final int orden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final esPrimero = orden == 1;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              RondoAvatar(iniciales: contacto.iniciales, variante: orden - 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contacto.nombre,
                      style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contacto.detalle,
                      style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: esPrimero ? c.accentSoft : c.neutralSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$orden.º',
                  style: t.labelLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: esPrimero ? c.accent : c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Última fila de la lista: "+ Agregar contacto".
class AddContactRow extends StatelessWidget {
  const AddContactRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Agregar contacto',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CustomPaint(
                    painter: _CirculoPunteado(c.accentLink),
                    child: Icon(Icons.add_rounded, size: 22, color: c.accentLink),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Agregar contacto',
                  style: t.bodyLarge!.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.accentLink,
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

/// Dibuja un círculo con borde punteado.
class _CirculoPunteado extends CustomPainter {
  _CirculoPunteado(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const trazos = 16;
    const paso = 2 * math.pi / trazos;
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final area = Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5);

    for (var i = 0; i < trazos; i++) {
      canvas.drawArc(area, i * paso, paso * 0.55, false, pincel);
    }
  }

  @override
  bool shouldRepaint(_CirculoPunteado old) => old.color != color;
}
