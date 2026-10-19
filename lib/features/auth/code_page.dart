import 'dart:async'; // Timer (cuenta regresiva para reenviar)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/code_input.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../onboarding/profile_page.dart';

/// 04 · Código (RF-01): la persona escribe el código de 4 dígitos.
class CodePage extends StatefulWidget {
  const CodePage({super.key, required this.celular});

  /// Número que escribió en Entrar (10 dígitos, sin +57).
  final String celular;

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  // TEMPORAL: mientras no hay servidor, el código correcto siempre es este.
  static const _codigoDePrueba = '1234';
  static const _intentosMaximos = 3;
  static const _segundosParaReenviar = 30;

  final _codigoController = TextEditingController();
  int _intentosRestantes = _intentosMaximos;
  int _segundosRestantes = _segundosParaReenviar;
  Timer? _temporizador;

  // Error actual: título (el problema) y mensaje (la salida).
  String? _errorTitulo;
  String? _errorMensaje;

  @override
  void initState() {
    super.initState();
    _iniciarTemporizador();
  }

  @override
  void dispose() {
    _temporizador?.cancel(); // Si no se cancela, el reloj sigue corriendo
    _codigoController.dispose();
    super.dispose();
  }

  void _iniciarTemporizador() {
    _segundosRestantes = _segundosParaReenviar;
    _temporizador?.cancel();
    _temporizador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes == 0) {
        timer.cancel();
        return;
      }
      setState(() => _segundosRestantes--);
    });
  }

  void _confirmar() {
    if (_codigoController.text == _codigoDePrueba) {
      // Reemplaza esta pantalla por el registro: "atrás" vuelve a Entrar,
      // no a escribir el código otra vez.
      context.read<AppState>().iniciarSesion(widget.celular);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
      return;
    }

    setState(() {
      _intentosRestantes--;
      _codigoController.clear(); // Para que vuelva a escribirlo sin borrar
      if (_intentosRestantes > 0) {
        final palabra = _intentosRestantes == 1 ? 'intento' : 'intentos';
        _errorTitulo = 'El código es incorrecto. Intenta de nuevo.';
        _errorMensaje = 'Te quedan $_intentosRestantes $palabra. También puedes pedir uno nuevo.';
      } else {
        _errorTitulo = 'Demasiados intentos fallidos.';
        _errorMensaje = 'Pide un código nuevo para continuar.';
      }
    });
  }

  void _reenviar() {
    setState(() {
      _codigoController.clear();
      _errorTitulo = null;
      _errorMensaje = null;
      _intentosRestantes = _intentosMaximos;
      _iniciarTemporizador();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Te enviamos un código nuevo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final hayError = _errorTitulo != null;
    final puedeConfirmar = _codigoController.text.length == CodeInput.largo && _intentosRestantes > 0;
    final segundos = _segundosRestantes.toString().padLeft(2, '0');

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.codigo,
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
                      Text('Escribe el código', style: t.headlineLarge),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          text: 'Lo enviamos al ',
                          children: [
                            TextSpan(
                              text: formatearCelular(widget.celular),
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.text),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        style: t.bodyMedium!.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 28),

                      // ---------- Las 4 casillas ----------
                      CodeInput(
                        controller: _codigoController,
                        hasError: hayError,
                        onChanged: (_) => setState(() {
                          // Al volver a escribir se quita el coral, salvo que
                          // ya no queden intentos.
                          if (_intentosRestantes > 0) {
                            _errorTitulo = null;
                            _errorMensaje = null;
                          }
                        }),
                      ),

                      if (hayError) ...[
                        const SizedBox(height: 14),
                        ErrorBanner(title: _errorTitulo!, message: _errorMensaje!),
                      ],

                      const Spacer(),
                      const SizedBox(height: 24),

                      // ---------- Aviso: el SMS llega sin datos ----------
                      Glass(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.sms_outlined, size: 22, color: c.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sin datos móviles, el código llega igual por SMS.',
                                style: t.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---------- Botones ----------
                      PrimaryButton(
                        label: 'Confirmar',
                        onPressed: puedeConfirmar ? _confirmar : null,
                      ),
                      const SizedBox(height: 10),
                      SecondaryButton(
                        label: _segundosRestantes == 0
                            ? 'Reenviar código'
                            : 'Reenviar en 0:$segundos',
                        onPressed: _segundosRestantes == 0 ? _reenviar : null,
                      ),
                      const SizedBox(height: 12),

                      // TEMPORAL: ayuda para probar sin servidor. Se borra con Firebase.
                      Text(
                        'Código de prueba: $_codigoDePrueba',
                        textAlign: TextAlign.center,
                        style: t.bodySmall,
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
    );
  }
}
