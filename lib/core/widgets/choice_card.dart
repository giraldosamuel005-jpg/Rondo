import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';
import 'glass.dart';

/// Tarjeta de opción única ("Me cuido a mí" / "Cuido a alguien").
/// Toda la tarjeta se puede tocar, no solo el círculo.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Glass(
        radius: 24,
        borderColor: selected ? c.accent : null,
        borderWidth: selected ? 2 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? c.accentSoft : c.neutralSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 22, color: selected ? c.accent : c.text),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleMedium),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Radio(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.accent : null,
        border: selected
            ? null
            : Border.all(color: c.textSecondary.withValues(alpha: 0.55), width: 1.5),
      ),
      child: selected ? Icon(Icons.check_rounded, size: 16, color: c.onAccent) : null,
    );
  }
}
