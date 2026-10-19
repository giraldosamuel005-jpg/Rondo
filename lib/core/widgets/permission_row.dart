import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';
import 'rondo_toggle.dart';

/// Permiso con su razón al lado (RF-30): la persona sabe para qué se usa
/// ANTES de que Android le pida el permiso.
class PermissionRow extends StatelessWidget {
  const PermissionRow({
    super.key,
    required this.title,
    required this.reason,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String reason;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => onChanged(!value), // Toda la fila activa el interruptor
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.bodyLarge!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(reason, style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RondoToggle(value: value, onChanged: onChanged, semanticLabel: title),
            ],
          ),
        ),
      ),
    );
  }
}
