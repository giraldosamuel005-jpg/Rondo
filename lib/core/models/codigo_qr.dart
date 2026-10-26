import 'dart:math';

/// Código QR de la ficha médica (RF-24). El QR no lleva datos médicos: lleva
/// un enlace con un token aleatorio. Quien lo escanea abre la ficha en solo
/// lectura, sin iniciar sesión.
///
/// Por ahora el token solo existe en el celular. Cuando haya servidor, se sube
/// junto con la ficha y la página pública lo valida (y registra cada consulta,
/// RF-25).
class CodigoQr {
  const CodigoQr({required this.token, required this.creadoEn});

  /// Token nuevo de 128 bits, con el generador seguro del sistema.
  factory CodigoQr.nuevo({Random? azar, DateTime? ahora}) {
    final generador = azar ?? Random.secure();
    final bytes = List.generate(bytesToken, (_) => generador.nextInt(256));
    return CodigoQr(
      token: bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      creadoEn: ahora ?? DateTime.now(),
    );
  }

  /// 16 bytes = 128 bits.
  static const bytesToken = 16;

  /// PROVISIONAL: el dominio `.example` está reservado y nunca abre nada.
  /// Cambiarlo por el del servidor cuando exista.
  static const urlBase = 'https://ficha.rondo.example';

  static const errorGenerar = 'No se pudo generar el código QR. Intenta de nuevo.';
  static const errorRegenerar = 'No se pudo regenerar el código. Intenta de nuevo.';

  /// 32 caracteres hexadecimales (0-9, a-f).
  final String token;
  final DateTime creadoEn;

  /// Lo que va dentro del QR.
  String get enlace => '$urlBase/f/$token';

  static bool tokenValido(Object? token) =>
      token is String && RegExp('^[0-9a-f]{${bytesToken * 2}}\$').hasMatch(token);
}
