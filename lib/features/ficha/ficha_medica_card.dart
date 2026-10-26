import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/consentimiento.dart';
import '../../core/models/ficha_medica.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/secondary_button.dart';
import 'codigo_qr_page.dart';
import 'ficha_medica_page.dart';

/// Sección "Salud" de Ajustes: resumen de la ficha médica (RF-23).
/// Tocarla abre la ficha para llenarla o editarla.
class FichaMedicaCard extends StatelessWidget {
  const FichaMedicaCard({super.key});

  Future<void> _abrir(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    final guardada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FichaMedicaPage()),
    );
    if (guardada == true) {
      mensajero.showSnackBar(const SnackBar(content: Text('Guardamos tu ficha médica.')));
    }
  }

  /// Ley 1581: la persona puede retirar su consentimiento y borrar sus datos.
  Future<void> _borrar(BuildContext context) async {
    final estado = context.read<AppState>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar tu ficha médica?'),
        content: const Text(
          'Se borran tu tipo de sangre, tus alergias, tu contacto de emergencia '
          'y tu código QR, y retiras tu consentimiento de datos médicos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar == true) estado.retirarConsentimiento(TipoConsentimiento.datosMedicos);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>();
    final ficha = estado.fichaMedica;
    final sinContacto = ficha != null && ficha.contactoEmergenciaEn(estado.contactos) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _abrir(context),
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Icon(Icons.medical_information_outlined, size: 26, color: c.accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ficha médica',
                            style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sinContacto ? FichaMedica.errorContacto : _resumen(ficha, estado),
                            style: t.labelLarge!.copyWith(
                              fontWeight: FontWeight.w400,
                              color: sinContacto ? c.errorText : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (ficha != null) ...[
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Ver mi código QR',
            icon: Icons.qr_code_2_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CodigoQrPage()),
            ),
          ),
        ],
        if (estado.tieneConsentimiento(TipoConsentimiento.datosMedicos))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _borrar(context),
              child: const Text('Borrar ficha y retirar consentimiento'),
            ),
          ),
      ],
    );
  }

  /// "O+ · 2 alergias · Llamar a Ana", o la invitación a llenarla.
  String _resumen(FichaMedica? ficha, AppState estado) {
    if (ficha == null) return 'Agrega tu tipo de sangre, alergias y a quién llamar.';

    final alergias = switch (ficha.alergias.length) {
      0 => 'Sin alergias',
      1 => '1 alergia',
      final n => '$n alergias',
    };
    final contacto = ficha.contactoEmergenciaEn(estado.contactos)!;
    return '${ficha.tipoSangre.etiqueta} · $alergias · Llamar a ${contacto.nombre}';
  }
}
