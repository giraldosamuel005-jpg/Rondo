import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/tipo_cuenta.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/choice_card.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/step_pill.dart';
import 'contacts_page.dart';

/// 02 · ¿Para quién es la cuenta? — Paso 1 de 2.
/// RF-03 (tipo de cuenta) y RF-34 (aviso "no reemplaza al 123").
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nombreController = TextEditingController();
  TipoCuenta? _tipo; // null = todavía no elige
  bool _avisoAceptado = false;

  String? _errorTipo;
  String? _errorNombre;
  String? _errorAviso;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _elegir(TipoCuenta tipo) {
    setState(() {
      _tipo = tipo;
      _errorTipo = null;
    });
  }

  void _continuar() {
    final nombre = _nombreController.text.trim();

    // Se revisan las tres cosas a la vez, para mostrar todos los errores juntos.
    setState(() {
      _errorTipo = _tipo == null
          ? 'Selecciona si la cuenta es para ti o para cuidar a alguien para continuar.'
          : null;
      _errorNombre = nombre.isEmpty ? 'Escribe tu nombre para continuar.' : null;
      _errorAviso = _avisoAceptado ? null : 'Debes aceptar este aviso para continuar.';
    });
    if (_errorTipo != null || _errorNombre != null || _errorAviso != null) return;

    // Guarda el perfil y la fecha en que se aceptó el aviso (RF-34).
    context.read<AppState>().guardarPerfil(nombre: nombre, tipo: _tipo!);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContactsPage()),
    );
  }

  void _verTratamientoDeDatos() {
    final t = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tratamiento de datos de salud', style: t.titleLarge),
              const SizedBox(height: 12),
              // TEXTO PROVISIONAL: el equipo debe revisarlo antes de entregar.
              Text(
                'Rondó guarda tu nombre, tu celular y tus contactos de emergencia '
                'para avisarles si algo te pasa. Tus datos médicos solo se guardan '
                'si tú los agregas, y solo los ve quien escanee tu código QR en una '
                'emergencia.\n\n'
                'Puedes pedir que borremos tus datos cuando quieras. Este tratamiento '
                'sigue la Ley 1581 de 2012 de protección de datos personales.',
                style: t.bodyLarge,
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Entendido', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.paso1,
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
                      const Row(
                        children: [
                          RondoBackButton(),
                          Expanded(child: Center(child: StepPill(actual: 1, total: 2))),
                          SizedBox(width: 44), // Equilibra el botón Atrás
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text('¿Para quién es la cuenta?', style: t.headlineLarge),
                      const SizedBox(height: 8),
                      Text('Puedes cambiarlo después.', style: t.bodyMedium!.copyWith(fontSize: 16)),
                      const SizedBox(height: 22),

                      // ---------- Tipo de cuenta (RF-03) ----------
                      ChoiceCard(
                        icon: Icons.person_rounded,
                        title: 'Me cuido a mí',
                        description: 'El teléfono vigila caídas y avisa a tus contactos.',
                        selected: _tipo == TipoCuenta.paraMi,
                        onTap: () => _elegir(TipoCuenta.paraMi),
                      ),
                      const SizedBox(height: 10),
                      ChoiceCard(
                        icon: Icons.volunteer_activism_rounded,
                        title: 'Cuido a alguien',
                        description: 'Recibes sus alertas y su ubicación cuando algo pasa.',
                        selected: _tipo == TipoCuenta.cuidador,
                        onTap: () => _elegir(TipoCuenta.cuidador),
                      ),
                      if (_errorTipo != null) ...[
                        const SizedBox(height: 8),
                        _TextoError(_errorTipo!),
                      ],
                      const SizedBox(height: 22),

                      // ---------- Datos ----------
                      Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GlassField(
                              label: '¿Cómo te llamas?',
                              controller: _nombreController,
                              hint: 'Tu nombre',
                              errorText: _errorNombre,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.name],
                              onChanged: (_) {
                                if (_errorNombre != null) setState(() => _errorNombre = null);
                              },
                            ),
                            const GlassDivider(indent: 18),
                            GlassField(
                              label: 'Celular',
                              value: formatearCelular(context.watch<AppState>().celular ?? ''),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---------- Aviso del 123 (RF-34) ----------
                      _AvisoEmergencias(
                        aceptado: _avisoAceptado,
                        error: _errorAviso,
                        onChanged: (valor) => setState(() {
                          _avisoAceptado = valor;
                          _errorAviso = null;
                        }),
                      ),

                      const Spacer(),
                      const SizedBox(height: 24),
                      PrimaryButton(label: 'Continuar', onPressed: _continuar),
                      const SizedBox(height: 6),
                      _NotaLegal(onTap: _verTratamientoDeDatos),
                      const SizedBox(height: 8),
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

/// Tarjeta del aviso obligatorio: "Rondó no reemplaza al 123".
/// Toda la tarjeta se toca para marcarla.
class _AvisoEmergencias extends StatelessWidget {
  const _AvisoEmergencias({required this.aceptado, required this.error, required this.onChanged});

  final bool aceptado;
  final String? error;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final hayError = error != null;

    return Semantics(
      checked: aceptado,
      child: Glass(
        fill: hayError ? c.errorSurface : null,
        borderColor: hayError ? c.error : (aceptado ? c.accent : null),
        borderWidth: (hayError || aceptado) ? 1.5 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => onChanged(!aceptado),
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: aceptado ? c.accent : null,
                      borderRadius: BorderRadius.circular(7),
                      border: aceptado
                          ? null
                          : Border.all(
                              color: hayError ? c.error : c.textSecondary.withValues(alpha: 0.55),
                              width: 1.5,
                            ),
                    ),
                    child: aceptado ? Icon(Icons.check_rounded, size: 16, color: c.onAccent) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entiendo que Rondó no reemplaza los servicios de emergencia oficiales.',
                          style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'En una emergencia, llama al 123.',
                          style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                        ),
                        if (hayError) ...[
                          const SizedBox(height: 6),
                          Text(error!, style: t.labelLarge!.copyWith(color: c.errorText)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Al continuar aceptas el tratamiento de datos de salud."
class _NotaLegal extends StatelessWidget {
  const _NotaLegal({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final estilo = Theme.of(context).textTheme.bodySmall!;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Al continuar aceptas el ', style: estilo),
        Semantics(
          link: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'tratamiento de datos de salud',
                style: estilo.copyWith(
                  color: c.accentLink,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: c.accentLink,
                ),
              ),
            ),
          ),
        ),
        Text('.', style: estilo),
      ],
    );
  }
}

class _TextoError extends StatelessWidget {
  const _TextoError(this.texto);

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
