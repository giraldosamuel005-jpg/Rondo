import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Botón ámbar de emergencia (alto 64): "Pedir ayuda ahora", "Llamar a Rosa".
/// Solo se usa en pantallas de alerta (ámbar = alerta de emergencia).
class AlertButton extends StatelessWidget {
  const AlertButton({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    const alto = 64.0;

    return Container(
      height: alto,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(alto),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(c.alert, Colors.white, 0.18)!, c.alert],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: c.alert.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: c.onAlert),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: c.onAlert,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
