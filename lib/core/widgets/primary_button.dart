import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Botón principal: cápsula turquesa "tintada". Solo uno por pantalla.
/// Con `onPressed: null` se ve desactivado.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 56 normalmente; 54 cuando va dentro de una tarjeta.
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final activo = onPressed != null;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final estilo = Theme.of(context).textTheme.titleMedium!.copyWith(
          color: c.onAccent,
          fontWeight: oscuro ? FontWeight.w700 : FontWeight.w600,
        );

    return Opacity(
      opacity: activo ? 1 : 0.45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.tintTop, c.tintBottom],
          ),
          border: Border.all(color: c.tintBorder),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.32),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: Stack(
              children: [
                // Brillo interior superior.
                Positioned(
                  top: 1,
                  left: height * 0.5,
                  right: height * 0.5,
                  child: Container(height: 1, color: c.tintHighlight),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: c.onAccent),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          style: estilo,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
