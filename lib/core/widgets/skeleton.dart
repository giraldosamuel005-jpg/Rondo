import 'package:flutter/material.dart';

import '../theme/rondo_colors.dart';

/// Barra gris con un brillo que la recorre: ocupa el lugar de lo que todavía
/// está cargando, con la forma de lo que va a aparecer (en vez de un círculo
/// girando). Con "quitar animaciones" activado en el celular se queda quieta.
///
/// El lector de pantalla no lee las barras una por una: quien las use debe
/// envolver el grupo con `Semantics(label: 'Cargando…')` (ver [SkeletonFila]).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  /// `null` = ocupa todo el ancho disponible.
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _brillo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se decide aquí (y no en initState) porque depende de MediaQuery.
    final quieta = MediaQuery.disableAnimationsOf(context);
    if (quieta) {
      _brillo.stop();
    } else if (!_brillo.isAnimating) {
      _brillo.repeat();
    }
  }

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final base = c.neutralSoft;
    final brillo = c.text.withValues(alpha: 0.12);

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _brillo,
          builder: (context, _) {
            // El brillo va de izquierda a derecha, de -1 a 2 veces el ancho.
            final x = -1.0 + _brillo.value * 3;
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                gradient: LinearGradient(
                  begin: Alignment(x - 0.6, 0),
                  end: Alignment(x + 0.6, 0),
                  colors: [base, brillo, base],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Fila de lista cargando: círculo (avatar) + dos líneas de texto.
class SkeletonFila extends StatelessWidget {
  const SkeletonFila({super.key, this.etiqueta = 'Cargando…'});

  /// Lo que dice el lector de pantalla.
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiqueta,
      liveRegion: true,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Skeleton(width: 44, height: 44, radius: 22),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 150, height: 16),
                  SizedBox(height: 8),
                  Skeleton(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
