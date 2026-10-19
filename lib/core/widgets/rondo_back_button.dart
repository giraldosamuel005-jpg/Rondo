import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';
import 'glass.dart';

/// Botón "Atrás": círculo de vidrio de 44 con un chevron.
class RondoBackButton extends StatelessWidget {
  const RondoBackButton({super.key, this.onPressed});

  /// Por defecto vuelve a la pantalla anterior.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Semantics(
      button: true,
      label: 'Atrás',
      excludeSemantics: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Glass(
          radius: 22,
          shadow: false,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed ?? () => Navigator.of(context).maybePop(),
              child: Center(
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
