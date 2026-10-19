import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';
import 'glass.dart';

/// Botón secundario: cápsula de vidrio neutro.
/// Con `onPressed: null` el texto se ve en gris (por ejemplo, "Reenviar en 0:24").
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final color = onPressed != null ? c.text : c.textSecondary;
    final estilo = Theme.of(context).textTheme.titleMedium!.copyWith(color: color);

    return Glass(
      radius: height,
      shadow: false,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(label, style: estilo, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
