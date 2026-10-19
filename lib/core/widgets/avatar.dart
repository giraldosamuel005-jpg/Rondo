import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Círculo con las iniciales de una persona.
/// `variante` 0 = degradado turquesa (1.º contacto), 1 = azul (2.º), y se alternan.
class RondoAvatar extends StatelessWidget {
  const RondoAvatar({
    super.key,
    required this.iniciales,
    this.size = 40,
    this.variante = 0,
    this.borderColor,
  });

  final String iniciales;
  final double size;
  final int variante;

  /// Borde de 2 px del color del fondo, para avatares apilados.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final turquesa = variante.isEven;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: turquesa
              ? [c.tintTop, c.tintBottom]
              : [c.avatarBlueTop, c.avatarBlueBottom],
        ),
        border: borderColor != null ? Border.all(color: borderColor!, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        iniciales,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700,
              color: turquesa ? c.onAccent : Colors.white,
            ),
      ),
    );
  }
}
