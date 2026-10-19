import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

enum StatusChipVariant { activa, alerta, pausa }

/// Cápsula de estado: "Ronda activa", "En pausa", "Alerta".
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.variant});

  final String label;
  final StatusChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    final (fondo, color) = switch (variant) {
      StatusChipVariant.activa => (c.accentSoft, c.accent),
      StatusChipVariant.alerta => (c.alert.withValues(alpha: 0.18), c.alertText),
      StatusChipVariant.pausa => (c.neutralSoft, c.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
