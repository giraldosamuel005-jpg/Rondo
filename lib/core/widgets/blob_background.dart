import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/rondo_colors.dart';

/// Una mancha de color del fondo.
class Blob {
  const Blob(this.alignment, this.size, this.colorIndex);

  /// Dónde va. Valores fuera de -1..1 la sacan parcialmente de la pantalla.
  final Alignment alignment;
  final double size;

  /// 0 turquesa · 1 azul · 2 menta · 3 violeta.
  final int colorIndex;
}

/// Fondo de pantalla con 2–3 manchas de color muy difuminadas.
/// Sin manchas detrás, el vidrio no se percibe (docs/DESIGN.md, principio 1).
class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key, required this.child, this.blobs = entrar});

  final Widget child;
  final List<Blob> blobs;

  // Posiciones distintas por pantalla, para que no se vea como plantilla.
  static const entrar = [
    Blob(Alignment(-1.4, -1.05), 340, 0),
    Blob(Alignment(1.5, -0.1), 300, 1),
    Blob(Alignment(-0.9, 1.25), 360, 2),
  ];

  /// Paso 1 del registro: la única pantalla con la mancha violeta.
  static const paso1 = [
    Blob(Alignment(1.4, -1.1), 320, 0),
    Blob(Alignment(-1.5, 0.15), 300, 1),
    Blob(Alignment(1.1, 1.2), 340, 2),
    Blob(Alignment(-1.2, -1.2), 220, 3),
  ];

  static const paso = [
    Blob(Alignment(1.4, -1.1), 320, 0),
    Blob(Alignment(-1.5, 0.15), 300, 1),
    Blob(Alignment(1.1, 1.2), 340, 2),
  ];

  static const codigo = [
    Blob(Alignment(-1.3, -1.15), 320, 1),
    Blob(Alignment(1.45, 0.05), 300, 0),
    Blob(Alignment(-1.0, 1.2), 340, 2),
  ];

  static const inicio = [
    Blob(Alignment(-1.35, -1.0), 360, 0),
    Blob(Alignment(1.5, -0.35), 300, 2),
    Blob(Alignment(0.6, 1.3), 340, 1),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Íconos de la barra de estado (hora, batería) legibles en cada modo.
      value: oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: c.bg)),
          Positioned.fill(
            // Las manchas se pintan una vez y no reciben toques.
            child: RepaintBoundary(
              child: IgnorePointer(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: c.blobSigma,
                    sigmaY: c.blobSigma,
                    tileMode: TileMode.decal,
                  ),
                  child: Stack(
                    children: [
                      for (final blob in blobs)
                        Align(
                          alignment: blob.alignment,
                          child: Container(
                            width: blob.size,
                            height: blob.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.blobs[blob.colorIndex % c.blobs.length]
                                  .withValues(alpha: c.blobOpacity),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
