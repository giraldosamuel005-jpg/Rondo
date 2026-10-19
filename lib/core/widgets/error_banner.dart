import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Banner de error: dice el problema (título) y la salida (mensaje).
/// Coral se usa SOLO para errores.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    // liveRegion: el lector de pantalla lo anuncia apenas aparece.
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.errorSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 22, color: c.errorText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.bodyMedium!.copyWith(
                      color: c.errorText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
