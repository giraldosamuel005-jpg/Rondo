import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/codigo_qr.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/secondary_button.dart';

/// QR de la ficha médica (RF-24) y botón para cambiarlo (RF-25).
/// Se abre desde la sección "Salud" de Ajustes, solo si hay ficha.
class CodigoQrPage extends StatelessWidget {
  const CodigoQrPage({super.key});

  Future<void> _regenerar(BuildContext context) async {
    final estado = context.read<AppState>();
    final mensajero = ScaffoldMessenger.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Crear un código nuevo?'),
        content: const Text(
          'El código anterior dejará de funcionar. Hazlo si lo perdiste '
          'o si alguien que no debe lo tiene.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Crear código nuevo'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      estado.regenerarCodigoQr();
      mensajero.showSnackBar(
        const SnackBar(content: Text('Listo. El código anterior ya no es válido.')),
      );
    } on StateError {
      mensajero.showSnackBar(const SnackBar(content: Text(CodigoQr.errorRegenerar)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final codigo = context.watch<AppState>().codigoQr;

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.paso,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 8),
              Row(children: [RondoBackButton(onPressed: () => Navigator.of(context).pop())]),
              const SizedBox(height: 22),
              Text('Tu código QR', style: t.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Quien te atienda en una emergencia lo escanea para ver tu ficha médica.',
                style: t.bodyMedium!.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 22),
              Glass(
                padding: const EdgeInsets.all(20),
                child: codigo == null
                    ? _Error(CodigoQr.errorGenerar)
                    : Column(
                        children: [
                          // Fondo blanco siempre, también en modo oscuro: así
                          // cualquier cámara lo lee.
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              // Con el enlace como llave se redibuja al cambiar el token.
                              key: ValueKey(codigo.enlace),
                              data: codigo.enlace,
                              size: 240,
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.white,
                              semanticsLabel: 'Código QR de tu ficha médica',
                              errorStateBuilder: (_, _) => const _Error(CodigoQr.errorGenerar),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Creado: ${diaRelativo(codigo.creadoEn)}',
                            style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              // Aviso mientras no exista el servidor (no es un error de la persona).
              Glass(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 22, color: c.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El código todavía no se puede consultar. No lo imprimas aún.',
                        style: t.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (codigo != null)
                SecondaryButton(
                  label: 'Crear un código nuevo',
                  icon: Icons.refresh_rounded,
                  blur: false,
                  onPressed: () => _regenerar(context),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(color: context.rondo.errorText),
      ),
    );
  }
}
