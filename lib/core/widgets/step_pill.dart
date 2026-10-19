import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';
import 'glass.dart';

/// Indicador de progreso del registro: barritas + "1 de 2".
class StepPill extends StatelessWidget {
  const StepPill({super.key, required this.actual, required this.total});

  final int actual;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Semantics(
      label: 'Paso $actual de $total',
      excludeSemantics: true,
      child: Glass(
        radius: 16,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= total; i++) ...[
                Container(
                  width: 18,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= actual ? c.accent : c.toggleOff,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 4),
              Text('$actual de $total', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
