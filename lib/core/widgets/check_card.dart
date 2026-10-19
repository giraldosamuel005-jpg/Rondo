import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';
import 'glass.dart';

/// Tarjeta para aceptar algo (consentimientos, avisos). Toda la tarjeta se
/// toca para marcarla; el error se muestra adentro, en coral.
class CheckCard extends StatelessWidget {
  const CheckCard({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.detail,
    this.error,
  });

  final String title;
  final String? detail;
  final bool value;
  final String? error;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final hayError = error != null;

    return Semantics(
      checked: value,
      child: Glass(
        fill: hayError ? c.errorSurface : null,
        borderColor: hayError ? c.error : (value ? c.accent : null),
        borderWidth: (hayError || value) ? 1.5 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => onChanged(!value),
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: value ? c.accent : null,
                      borderRadius: BorderRadius.circular(7),
                      border: value
                          ? null
                          : Border.all(
                              color: hayError ? c.error : c.textSecondary.withValues(alpha: 0.55),
                              width: 1.5,
                            ),
                    ),
                    child: value ? Icon(Icons.check_rounded, size: 16, color: c.onAccent) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                        if (detail != null) ...[
                          const SizedBox(height: 4),
                          Text(detail!, style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400)),
                        ],
                        if (hayError) ...[
                          const SizedBox(height: 6),
                          Semantics(
                            liveRegion: true,
                            child: Text(error!, style: t.labelLarge!.copyWith(color: c.errorText)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
