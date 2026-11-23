import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Lo que pasó al pedir la huella (RF-02).
///
/// La app nunca ve ni guarda la huella: el sistema operativo la valida y solo
/// responde "válido" o "no válido".
enum ResultadoBiometria {
  /// El sistema reconoció la huella.
  valido,

  /// No la reconoció, o la persona canceló. Se puede intentar de nuevo.
  noValido,

  /// El celular no tiene sensor, o no hay ninguna huella guardada.
  noDisponible,

  /// Demasiados intentos fallidos: el sistema bloqueó el sensor un rato.
  bloqueado,
}

/// Mensajes de error de RF-02, tal cual (requisitos.md).
class MensajesBiometria {
  MensajesBiometria._();

  static const noValido =
      'No se reconoció tu huella. Intenta de nuevo o ingresa con tu código SMS.';
  static const noDisponible =
      'Tu celular no tiene biometría configurada. Ingresa con tu código SMS.';
  static const bloqueado =
      'Demasiados intentos fallidos. Ingresa con tu código SMS.';

  /// El mensaje que corresponde a un resultado que no fue válido.
  static String? de(ResultadoBiometria resultado) => switch (resultado) {
    ResultadoBiometria.valido => null,
    ResultadoBiometria.noValido => noValido,
    ResultadoBiometria.noDisponible => noDisponible,
    ResultadoBiometria.bloqueado => bloqueado,
  };
}

/// Pide la huella al sistema. Las pantallas hablan con esta clase, no con
/// `local_auth`, para poder cambiarla por una falsa en las pruebas.
abstract class ServicioBiometria {
  /// El celular tiene sensor y al menos una huella guardada.
  Future<bool> get disponible;

  /// Muestra el cuadro del sistema y espera la respuesta.
  Future<ResultadoBiometria> autenticar(String motivo);
}

/// Versión real, con `local_auth`.
class ServicioBiometriaLocal implements ServicioBiometria {
  ServicioBiometriaLocal([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> get disponible async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics)
        return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ResultadoBiometria> autenticar(String motivo) async {
    try {
      // biometricOnly: solo huella o rostro. El PIN del celular no cuenta:
      // el plan B de la app es el código SMS.
      final ok = await _auth.authenticate(
        localizedReason: motivo,
        biometricOnly: true,
      );
      return ok ? ResultadoBiometria.valido : ResultadoBiometria.noValido;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          ResultadoBiometria.noDisponible,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => ResultadoBiometria.bloqueado,
        _ => ResultadoBiometria.noValido,
      };
    } catch (_) {
      return ResultadoBiometria.noValido;
    }
  }
}

/// Para web, Windows y pruebas: nunca hay huella.
class ServicioBiometriaNoDisponible implements ServicioBiometria {
  const ServicioBiometriaNoDisponible();

  @override
  Future<bool> get disponible async => false;

  @override
  Future<ResultadoBiometria> autenticar(String motivo) async =>
      ResultadoBiometria.noDisponible;
}

/// El servicio que corresponde a esta plataforma.
ServicioBiometria servicioBiometriaDeLaPlataforma() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
    return ServicioBiometriaLocal();
  return const ServicioBiometriaNoDisponible();
}
