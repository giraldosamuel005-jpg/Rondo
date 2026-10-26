import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';
import 'glass.dart';

/// Barra de pestañas flotante de vidrio.
/// Quien se cuida: Inicio · Contactos · Historial · Ajustes.
/// Cuidador: Personas · Alertas · Ajustes.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.pestanas, required this.actual, required this.onTap});

  /// Ícono y etiqueta de cada pestaña.
  final List<(IconData, String)> pestanas;
  final int actual;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 34,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (var i = 0; i < pestanas.length; i++)
              Expanded(
                child: _Pestana(
                  icono: pestanas[i].$1,
                  etiqueta: pestanas[i].$2,
                  activa: i == actual,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.icono,
    required this.etiqueta,
    required this.activa,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final color = activa ? c.accentLink : c.textSecondary;

    return Semantics(
      selected: activa,
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: activa ? c.accentSoft : null,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  etiqueta,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontSize: 11,
                        fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                        color: color,
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
