import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/consentimiento.dart';
import '../../core/models/ficha_medica.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/check_card.dart';
import '../../core/widgets/choice_card.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/step_pill.dart';

enum _Paso { consentimiento, sangre, alergias, contacto }

/// Ficha médica (RF-23), en pasos cortos: un dato por pantalla.
/// La primera vez pide antes el consentimiento de datos médicos (RF-30).
/// Devuelve `true` al guardar.
class FichaMedicaPage extends StatefulWidget {
  const FichaMedicaPage({super.key});

  @override
  State<FichaMedicaPage> createState() => _FichaMedicaPageState();
}

class _FichaMedicaPageState extends State<FichaMedicaPage> {
  late _Paso _paso;
  late final _Paso _primerPaso;

  bool _consentimientoAceptado = false;
  TipoSangre? _tipoSangre;
  final List<String> _alergias = [];
  final _alergiaController = TextEditingController();
  String? _celularContacto;

  String? _error;

  @override
  void initState() {
    super.initState();
    final estado = context.read<AppState>();

    _primerPaso = estado.tieneConsentimiento(TipoConsentimiento.datosMedicos)
        ? _Paso.sangre
        : _Paso.consentimiento;
    _paso = _primerPaso;

    // Editar: arranca con lo que ya tenía.
    final ficha = estado.fichaMedica;
    if (ficha != null) {
      _tipoSangre = ficha.tipoSangre;
      _alergias.addAll(ficha.alergias);
      _celularContacto = ficha.contactoEmergenciaEn(estado.contactos)?.celular;
    }
  }

  @override
  void dispose() {
    _alergiaController.dispose();
    super.dispose();
  }

  void _ir(_Paso paso) => setState(() {
        _paso = paso;
        _error = null;
      });

  void _atras() {
    if (_paso == _primerPaso) {
      Navigator.of(context).pop();
    } else {
      _ir(_Paso.values[_paso.index - 1]);
    }
  }

  void _agregarAlergia() {
    final nuevas = FichaMedica.limpiarAlergias([..._alergias, _alergiaController.text]);
    setState(() {
      _alergias
        ..clear()
        ..addAll(nuevas);
      _alergiaController.clear();
    });
  }

  void _continuar() {
    final estado = context.read<AppState>();

    switch (_paso) {
      case _Paso.consentimiento:
        if (!_consentimientoAceptado) {
          setState(() => _error = 'Necesitamos tu consentimiento para guardar tus datos médicos.');
          return;
        }
        estado.darConsentimiento(TipoConsentimiento.datosMedicos);
        _ir(_Paso.sangre);

      case _Paso.sangre:
        final error = FichaMedica.validarTipoSangre(_tipoSangre);
        if (error != null) {
          setState(() => _error = error);
          return;
        }
        _ir(_Paso.alergias);

      case _Paso.alergias:
        // Si escribió una y no tocó "Agregar", también cuenta.
        if (_alergiaController.text.trim().isNotEmpty) _agregarAlergia();
        _ir(_Paso.contacto);

      case _Paso.contacto:
        final error = FichaMedica.validar(
          tipoSangre: _tipoSangre,
          celularContacto: _celularContacto,
          contactos: estado.contactos,
        );
        if (error != null) {
          setState(() => _error = error);
          return;
        }
        estado.guardarFichaMedica(FichaMedica(
          tipoSangre: _tipoSangre!,
          celularContactoEmergencia: _celularContacto!,
          alergias: _alergias,
        ));
        Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (titulo, subtitulo) = switch (_paso) {
      _Paso.consentimiento => ('Tus datos médicos', 'Los ve quien te atienda en una emergencia.'),
      _Paso.sangre => ('¿Cuál es tu tipo de sangre?', 'Si no lo sabes, puedes volver cuando lo tengas.'),
      _Paso.alergias => ('¿Tienes alergias?', 'Medicamentos, alimentos u otras. Si no tienes, continúa.'),
      _Paso.contacto => ('¿A quién llamamos?', 'Quien te atienda verá este contacto en tu ficha.'),
    };

    return PopScope(
      // El botón atrás de Android retrocede un paso, igual que la flecha.
      canPop: _paso == _primerPaso,
      onPopInvokedWithResult: (seCerro, _) {
        if (!seCerro) _atras();
      },
      child: Scaffold(
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
                        Row(
                          children: [
                            RondoBackButton(onPressed: _atras),
                            Expanded(
                              child: Center(
                                child: _paso == _Paso.consentimiento
                                    ? const SizedBox.shrink()
                                    : StepPill(actual: _paso.index, total: 3),
                              ),
                            ),
                            const SizedBox(width: 44), // Equilibra el botón Atrás
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(titulo, style: t.headlineLarge),
                        const SizedBox(height: 8),
                        Text(subtitulo, style: t.bodyMedium!.copyWith(fontSize: 16)),
                        const SizedBox(height: 22),
                        switch (_paso) {
                          _Paso.consentimiento => _pasoConsentimiento(),
                          _Paso.sangre => _pasoSangre(),
                          _Paso.alergias => _pasoAlergias(),
                          _Paso.contacto => _pasoContacto(),
                        },
                        const Spacer(),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: _paso == _Paso.contacto ? 'Guardar ficha' : 'Continuar',
                          onPressed: _continuar,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pasoConsentimiento() {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          padding: const EdgeInsets.all(16),
          // TEXTO PROVISIONAL: el equipo debe revisarlo antes de entregar.
          child: Text(
            'Rondó guarda tu tipo de sangre, tus alergias y a quién llamar. '
            'Son datos sensibles: solo se guardan con tu permiso, y puedes '
            'borrarlos cuando quieras desde Ajustes.',
            style: t.bodyLarge,
          ),
        ),
        const SizedBox(height: 12),
        CheckCard(
          title: 'Acepto que Rondó guarde mis datos médicos.',
          detail: 'Ley 1581 de 2012 de protección de datos personales.',
          value: _consentimientoAceptado,
          error: _error,
          onChanged: (valor) => setState(() {
            _consentimientoAceptado = valor;
            _error = null;
          }),
        ),
      ],
    );
  }

  Widget _pasoSangre() {
    final filas = [TipoSangre.values.sublist(0, 4), TipoSangre.values.sublist(4)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final fila in filas) ...[
          Row(
            children: [
              for (final tipo in fila) ...[
                if (tipo != fila.first) const SizedBox(width: 10),
                Expanded(
                  child: _OpcionSangre(
                    tipo: tipo,
                    seleccionada: tipo == _tipoSangre,
                    hayError: _error != null,
                    onTap: () => setState(() {
                      _tipoSangre = tipo;
                      _error = null;
                    }),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (_error != null) _TextoError(_error!),
      ],
    );
  }

  Widget _pasoAlergias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          child: GlassField(
            label: 'Alergia',
            controller: _alergiaController,
            hint: 'Ej. penicilina',
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _agregarAlergia(),
          ),
        ),
        const SizedBox(height: 10),
        SecondaryButton(label: 'Agregar', icon: Icons.add_rounded, onPressed: _agregarAlergia),
        const SizedBox(height: 16),
        if (_alergias.isEmpty)
          Text('Sin alergias conocidas.', style: Theme.of(context).textTheme.bodyMedium)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final alergia in _alergias)
                _Etiqueta(
                  texto: alergia,
                  onQuitar: () => setState(() => _alergias.remove(alergia)),
                ),
            ],
          ),
      ],
    );
  }

  Widget _pasoContacto() {
    final contactos = context.watch<AppState>().contactos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final contacto in contactos) ...[
          ChoiceCard(
            icon: Icons.person_rounded,
            title: contacto.nombre,
            description: contacto.detalle,
            selected: contacto.celular == _celularContacto,
            onTap: () => setState(() {
              _celularContacto = contacto.celular;
              _error = null;
            }),
          ),
          const SizedBox(height: 10),
        ],
        if (_error != null) _TextoError(_error!),
      ],
    );
  }
}

/// Un tipo de sangre para tocar ("O+").
class _OpcionSangre extends StatelessWidget {
  const _OpcionSangre({
    required this.tipo,
    required this.seleccionada,
    required this.hayError,
    required this.onTap,
  });

  final TipoSangre tipo;
  final bool seleccionada;
  final bool hayError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Semantics(
      button: true,
      selected: seleccionada,
      label: 'Tipo de sangre ${tipo.etiqueta}',
      excludeSemantics: true,
      child: Glass(
        radius: 20,
        fill: seleccionada ? c.accentSoft : null,
        borderColor: seleccionada ? c.accent : (hayError ? c.error : null),
        borderWidth: seleccionada || hayError ? 1.5 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  tipo.etiqueta,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: seleccionada ? c.accentLink : c.text,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una alergia agregada, con su botón para quitarla.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.onQuitar});

  final String texto;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Glass(
      radius: 18,
      padding: const EdgeInsets.only(left: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(texto, style: Theme.of(context).textTheme.bodyLarge),
          IconButton(
            onPressed: onQuitar,
            tooltip: 'Quitar $texto',
            icon: Icon(Icons.close_rounded, size: 18, color: c.textSecondary),
          ),
        ],
      ),
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
