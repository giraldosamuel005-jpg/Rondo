import 'dart:async'; // Para Timer (la cuenta regresiva)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Pantalla 2 del login: la persona escribe el código de 4 dígitos.
class CodigoScreen extends StatefulWidget {
  const CodigoScreen({super.key, required this.celular});

  /// Número que escribió en la pantalla anterior (10 dígitos, sin +57).
  final String celular;

  @override
  State<CodigoScreen> createState() => _CodigoScreenState();
}

class _CodigoScreenState extends State<CodigoScreen> {
  // TEMPORAL: mientras no hay servidor, el código correcto siempre es este.
  static const _codigoDePrueba = '1234';
  static const _intentosMaximos = 3;
  static const _segundosParaReenviar = 30;

  final _codigoController = TextEditingController();
  String? _error;
  int _intentosRestantes = _intentosMaximos;
  int _segundosRestantes = _segundosParaReenviar;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _iniciarTemporizador(); // Arranca la cuenta regresiva al abrir la pantalla
  }

  @override
  void dispose() {
    _temporizador?.cancel(); // Detiene el reloj al salir, si no seguiría corriendo
    _codigoController.dispose();
    super.dispose();
  }

  /// "3206523232" → "+57 320 652 3232"
  String get _celularFormateado {
    final c = widget.celular;
    return '+57 ${c.substring(0, 3)} ${c.substring(3, 6)} ${c.substring(6)}';
  }

  void _iniciarTemporizador() {
    _segundosRestantes = _segundosParaReenviar;
    _temporizador?.cancel();
    // Cada segundo resta 1 y redibuja la pantalla, hasta llegar a 0.
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
      // Siguiente etapa: aquí iremos al aviso "no reemplaza al 123".
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Código correcto!')),
      );
      return;
    }

    setState(() {
      _intentosRestantes--;
      _codigoController.clear();
      if (_intentosRestantes > 0) {
        final palabra = _intentosRestantes == 1 ? 'intento' : 'intentos';
        _error = 'El código es incorrecto. Intenta de nuevo. '
            'Te quedan $_intentosRestantes $palabra.';
      } else {
        _error = 'Demasiados intentos fallidos. Pide un código nuevo.';
      }
    });
  }

  void _reenviar() {
    setState(() {
      _codigoController.clear();
      _error = null;
      _intentosRestantes = _intentosMaximos;
      _iniciarTemporizador();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Te enviamos un código nuevo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final codigo = _codigoController.text;
    final puedeConfirmar = codigo.length == 4 && _intentosRestantes > 0;

    return Scaffold(
      appBar: AppBar(), // Pone la flecha ← automáticamente
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------- Título ----------
              Text('Escribe el código', style: textos.headlineLarge),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  text: 'Te lo enviamos al ',
                  children: [
                    TextSpan(
                      text: _celularFormateado,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: textos.bodyLarge?.copyWith(color: AppColors.bodyGray),
              ),
              const SizedBox(height: 32),

              // ---------- Las 4 casillas ----------
              // Truco: un campo de texto INVISIBLE encima de 4 cajas.
              // La persona escribe en el campo; las cajas solo muestran los números.
              Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (i) => _casilla(i, codigo)),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _codigoController,
                        autofocus: true, // Abre el teclado al entrar
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        showCursor: false,
                        enableInteractiveSelection: false,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                    ),
                  ),
                ],
              ),

              // ---------- Mensaje de error (solo si hay) ----------
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: textos.bodyLarge?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // ---------- Botones ----------
              FilledButton(
                onPressed: puedeConfirmar ? _confirmar : null, // null = desactivado
                child: const Text('Confirmar'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _segundosRestantes == 0 ? _reenviar : null,
                child: Text(
                  _segundosRestantes == 0
                      ? 'Enviarme otro código'
                      : 'Pedir otro código en 0:${_segundosRestantes.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 24),

              // TEMPORAL: ayuda para probar sin servidor. Se borra con Firebase.
              Text(
                'Código de prueba: $_codigoDePrueba',
                textAlign: TextAlign.center,
                style: textos.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dibuja una de las 4 cajas del código.
  Widget _casilla(int indice, String codigo) {
    final tieneNumero = indice < codigo.length;
    final esLaActual = indice == codigo.length; // La siguiente por llenar
    final hayError = _error != null;

    final Color colorBorde;
    if (hayError) {
      colorBorde = AppColors.error;
    } else if (esLaActual) {
      colorBorde = AppColors.charcoal;
    } else {
      colorBorde = AppColors.fieldBorder;
    }

    return Container(
      width: 68,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cloudCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorBorde,
          width: (esLaActual || hayError) ? 2 : 1.5,
        ),
      ),
      child: Text(
        tieneNumero ? codigo[indice] : '',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
    );
  }
}
