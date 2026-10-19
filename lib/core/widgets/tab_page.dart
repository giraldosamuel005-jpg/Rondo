import 'package:flutter/material.dart';

import 'blob_background.dart';

/// Estructura común de las pestañas (Contactos, Historial, Ajustes):
/// fondo con manchas, título grande, subtítulo y contenido con scroll.
/// El contenido termina justo encima de la barra flotante y, al hacer scroll,
/// pasa por debajo de ella.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.blobs,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Blob> blobs;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final abajo = MediaQuery.paddingOf(context).bottom;

    return BlobBackground(
      blobs: blobs,
      child: SafeArea(
        bottom: false,
        child: ListView(
          // "abajo" ya incluye la altura de la barra de pestañas (extendBody).
          padding: EdgeInsets.fromLTRB(20, 20, 20, abajo + 16),
          children: [
            Text(title, style: t.headlineLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: t.bodyMedium!.copyWith(fontSize: 16)),
            ],
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Etiqueta pequeña encima de un grupo de tarjetas ("Permisos", "Apariencia").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
