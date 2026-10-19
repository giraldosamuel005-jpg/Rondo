import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Interruptor de 52×32: turquesa encendido, gris apagado.
class RondoToggle extends StatelessWidget {
  const RondoToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Lo que lee el lector de pantalla, por ejemplo "Ubicación siempre".
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    const duracion = Duration(milliseconds: 180);

    return Semantics(
      toggled: value,
      label: semanticLabel,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        // 44 de alto para que sea cómodo de tocar, aunque se vea de 32.
        child: SizedBox(
          width: 52,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: duracion,
              width: 52,
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? c.accent : c.toggleOff,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: duracion,
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
                    ],
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
