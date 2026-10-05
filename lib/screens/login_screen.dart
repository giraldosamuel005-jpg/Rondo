import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'codigo_screen.dart';


/// Pantalla 1 del login: la persona escribe su número de celular.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Guarda lo que la persona escribe en el campo del celular.
  final _celularController = TextEditingController();

  // Mensaje de error. Si es null, no se muestra ningún error.
  String? _error;

  @override
  void dispose() {
    _celularController.dispose(); // Libera memoria cuando se cierra la pantalla
    super.dispose();
  }

  void _enviarCodigo() {
    final celular = _celularController.text;

    // setState le avisa a Flutter que algo cambió y que vuelva a dibujar.
    setState(() {
      _error = celular.length == 10
          ? null
          : 'Ingresa un número de celular válido.';
    });

    if (_error != null) return;

    // Abre la pantalla del código, encima de esta.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CodigoScreen(celular: celular),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme; // Los estilos de texto del tema

    return Scaffold(
      body: Container(
        // Degradado "Hero Sky": azul cielo arriba → crema → blanco.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.heroSkyTop,
              AppColors.heroSkyBottom,
              AppColors.paperWhite,
            ],
            stops: [0.0, 0.35, 0.6],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- Logo y nombre ----------
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Rondó', textAlign: TextAlign.center, style: textos.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Alguien pendiente, siempre',
                  textAlign: TextAlign.center,
                  style: textos.bodyMedium,
                ),
                const SizedBox(height: 48),

                // ---------- Campo del celular ----------
                Text(
                  'Número de celular',
                  style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _celularController,
                  keyboardType: TextInputType.phone, // Abre el teclado numérico
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // Solo números
                    LengthLimitingTextInputFormatter(10), // Máximo 10
                  ],
                  style: textos.bodyLarge,
                  decoration: InputDecoration(
                    hintText: '300 123 4567',
                    errorText: _error,
                    // "+57" fijo al inicio del campo
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 20, right: 8),
                      child: Text(
                        '+57',
                        style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                  ),
                  onSubmitted: (_) => _enviarCodigo(), // Enter del teclado = enviar
                ),
                const SizedBox(height: 12),
                Text(
                  'Te llega un mensaje de texto con 4 números. '
                  'No hay contraseñas que recordar.',
                  style: textos.bodyMedium,
                ),
                const SizedBox(height: 24),

                // ---------- Botón principal ----------
                FilledButton(
                  onPressed: _enviarCodigo,
                  child: const Text('Enviarme el código'),
                ),
                const SizedBox(height: 40),

                // ---------- Opciones secundarias ----------
                OutlinedButton.icon(
                  onPressed: () {}, // Más adelante: huella
                  icon: const Icon(Icons.fingerprint, size: 28),
                  label: const Text('Entrar con huella'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿Primera vez?', style: textos.bodyMedium),
                    TextButton(
                      onPressed: () {}, // Más adelante: registro
                      child: const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
