import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/vinculos/servicio_vinculos.dart';
import '../../core/vinculos/vinculo.dart';
import '../../core/vinculos/vinculos.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';

/// El cuidador escribe el código que le llegó por SMS (RF-05) y queda
/// vinculado. Devuelve el nombre de la persona al aceptar.
class AceptarInvitacionPage extends StatefulWidget {
  const AceptarInvitacionPage({super.key});

  @override
  State<AceptarInvitacionPage> createState() => _AceptarInvitacionPageState();
}

class _AceptarInvitacionPageState extends State<AceptarInvitacionPage> {
  final _codigo = TextEditingController();
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _aceptar() async {
    final vinculos = context.read<Vinculos>();
    final navegador = Navigator.of(context);
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final vinculo = await vinculos.aceptar(_codigo.text);
      navegador.pop(primerNombre(vinculo.personaNombre));
    } on ErrorVinculo catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.paso,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Align(alignment: Alignment.centerLeft, child: RondoBackButton()),
                      const SizedBox(height: 22),
                      Text('Escribe tu código', style: t.headlineLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Es el de ${Invitacion.largoCodigo} letras y números que te llegó por SMS '
                        'cuando alguien te invitó a cuidarlo.',
                        style: t.bodyMedium!.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 22),
                      Glass(
                        child: GlassField(
                          label: 'Código',
                          controller: _codigo,
                          hint: 'Ej. K7M2QX',
                          errorText: _error,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                            LengthLimitingTextInputFormatter(Invitacion.largoCodigo),
                          ],
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => _aceptar(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 18, color: c.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo verás lo que esa persona comparta, y ella puede dejar de compartir cuando quiera.',
                              style: t.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      if (_ocupado)
                        const Center(child: CircularProgressIndicator())
                      else
                        PrimaryButton(label: 'Aceptar invitación', onPressed: _aceptar),
                      const SizedBox(height: 12),
                    ],
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
