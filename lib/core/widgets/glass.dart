import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Ajustes de rendimiento del vidrio (docs/DESIGN.md, sección 6.3).
class RondoPerf {
  RondoPerf._();

  /// Con `true` el vidrio se dibuja sin desenfoque, como superficie sólida.
  /// Más adelante se activará con ahorro de batería o en celulares lentos.
  static bool reduceGlass = false;
}

/// Superficie de vidrio: degradado translúcido, borde fino, brillo superior
/// y desenfoque de lo que hay detrás.
///
/// El desenfoque (`BackdropFilter`) es costoso: máximo 6 por pantalla.
/// Para vidrios repetidos (las casillas del código, filas de una lista)
/// usa `blur: false`.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.blur = true,
    this.shadow = true,
    this.borderColor,
    this.borderWidth = 1,
    this.fill,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool blur;
  final bool shadow;

  /// Cambia el borde (por ejemplo, turquesa si está seleccionado o coral si hay error).
  final Color? borderColor;
  final double borderWidth;

  /// Color sólido en vez del degradado de vidrio (por ejemplo, fondo de error).
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final esquinas = BorderRadius.circular(radius);
    final reducido = MediaQuery.highContrastOf(context) || RondoPerf.reduceGlass;
    final conDegradado = fill == null && !reducido;

    Widget cuerpo = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: esquinas,
        color: fill ?? (reducido ? c.bg.withValues(alpha: 0.96) : null),
        gradient: conDegradado
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.glassTop, c.glassBottom],
              )
            : null,
        border: Border.all(color: borderColor ?? c.glassBorder, width: borderWidth),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
          // Brillo de 1 px en el borde superior: da la sensación de vidrio.
          if (conDegradado)
            Positioned(
              top: 0,
              left: radius * 0.6,
              right: radius * 0.6,
              child: IgnorePointer(
                child: Container(height: 1, color: c.glassHighlight),
              ),
            ),
        ],
      ),
    );

    cuerpo = ClipRRect(
      borderRadius: esquinas,
      child: (blur && !reducido)
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: cuerpo,
            )
          : cuerpo,
    );

    if (!shadow) return cuerpo;

    // La sombra va por fuera del recorte y solo hacia afuera (BlurStyle.outer),
    // para no ensuciar el vidrio translúcido.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: esquinas,
        boxShadow: [
          BoxShadow(
            color: c.glassShadow,
            blurRadius: 32,
            offset: const Offset(0, 12),
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: cuerpo,
    );
  }
}

/// Línea separadora de 1 px entre filas dentro de una tarjeta de vidrio.
class GlassDivider extends StatelessWidget {
  const GlassDivider({super.key, this.indent = 16});

  /// Sangría izquierda: 16–18 normalmente, 68 si la fila tiene avatar.
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 1, color: context.rondo.hairline),
    );
  }
}
