import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Logo de Rondó: claro en modo claro, oscuro en modo oscuro.
/// En oscuro es un recuadro con sombra; en claro, solo los trazos sobre el fondo.
class RondoLogo extends StatelessWidget {
  const RondoLogo({super.key, this.size = 104});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final radio = BorderRadius.circular(size * 0.33);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radio,
        boxShadow: oscuro
            ? [
                BoxShadow(
                  color: c.glassShadow,
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radio,
        child: Image.asset(
          oscuro ? 'assets/images/logo.png' : 'assets/images/logo_claro.png',
          fit: BoxFit.cover,
          semanticLabel: 'Logo de Rondó',
        ),
      ),
    );
  }
}
