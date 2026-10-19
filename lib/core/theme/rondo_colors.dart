import 'package:flutter/material.dart';

/// Colores de Rondó (docs/DESIGN.md, sección 3.1).
/// Claro y oscuro tienen cada uno su propia paleta; no se deriva uno del otro.
@immutable
class RondoColors extends ThemeExtension<RondoColors> {
  const RondoColors({
    required this.bg,
    required this.text,
    required this.textSecondary,
    required this.accent,
    required this.accentLink,
    required this.accentSoft,
    required this.onAccent,
    required this.hairline,
    required this.neutralSoft,
    required this.error,
    required this.errorText,
    required this.errorSurface,
    required this.alert,
    required this.alertText,
    required this.alertBg,
    required this.onAlert,
    required this.alertBlobs,
    required this.toggleOff,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassShadow,
    required this.tintTop,
    required this.tintBottom,
    required this.tintHighlight,
    required this.tintBorder,
    required this.avatarBlueTop,
    required this.avatarBlueBottom,
    required this.blobs,
    required this.blobOpacity,
    required this.blobSigma,
  });

  // Base
  final Color bg;
  final Color text;
  final Color textSecondary;

  // Marca y acción (turquesa)
  final Color accent;
  final Color accentLink;
  final Color accentSoft;
  final Color onAccent;

  // Separadores y fondos neutros
  final Color hairline;
  final Color neutralSoft;

  // Coral: SOLO errores
  final Color error;
  final Color errorText;
  final Color errorSurface;

  // Ámbar: SOLO alerta de emergencia
  final Color alert;
  final Color alertText;
  final Color alertBg;

  /// Texto sobre el botón ámbar "Pedir ayuda ahora".
  final Color onAlert;

  /// Manchas de fondo de la pantalla de alerta.
  final List<Color> alertBlobs;

  final Color toggleOff;

  // Vidrio (tarjetas y controles)
  final Color glassTop;
  final Color glassBottom;
  final Color glassBorder;
  final Color glassHighlight;
  final Color glassShadow;

  // Vidrio tintado (botón principal)
  final Color tintTop;
  final Color tintBottom;
  final Color tintHighlight;
  final Color tintBorder;

  // Avatar del 2.º contacto
  final Color avatarBlueTop;
  final Color avatarBlueBottom;

  // Manchas de fondo
  final List<Color> blobs;
  final double blobOpacity;
  final double blobSigma;

  static const light = RondoColors(
    bg: Color(0xFFEAF1F0),
    text: Color(0xFF0E1A19),
    textSecondary: Color(0xFF3B4D4A),
    accent: Color(0xFF0B7A6E),
    accentLink: Color(0xFF0B6B60),
    accentSoft: Color(0x1F0B7A6E), // 12 %
    onAccent: Colors.white,
    hairline: Color(0x1A0E1A19), // 10 %
    neutralSoft: Color(0x0F0E1A19), // 6 %
    error: Color(0xFFD9442F),
    errorText: Color(0xFFB5321F),
    errorSurface: Color(0x17D9442F), // 9 %
    alert: Color(0xFFF59E0B),
    alertText: Color(0xFF92400E),
    alertBg: Color(0xFFFBF3E4),
    onAlert: Color(0xFF3B2300),
    alertBlobs: [Color(0xFFFCD34D), Color(0xFFFDBA74), Color(0xFFFDE68A)],
    toggleOff: Color(0x240E1A19), // 14 %
    glassTop: Color(0xA8FFFFFF), // 66 %
    glassBottom: Color(0x66FFFFFF), // 40 %
    glassBorder: Color(0xBFFFFFFF), // 75 %
    glassHighlight: Color(0xF2FFFFFF), // 95 %
    glassShadow: Color(0x1A143C37), // 10 %
    tintTop: Color(0xFF139384),
    tintBottom: Color(0xFF0B7A6E),
    tintHighlight: Color(0x73FFFFFF), // 45 %
    tintBorder: Color(0x40FFFFFF), // 25 %
    avatarBlueTop: Color(0xFF60A5FA),
    avatarBlueBottom: Color(0xFF2563EB),
    blobs: [
      Color(0xFF5EEAD4), // turquesa
      Color(0xFF93C5FD), // azul
      Color(0xFFA7F3D0), // menta
      Color(0xFFC4B5FD), // violeta (opcional)
    ],
    blobOpacity: 0.62,
    blobSigma: 28, // ≈ blur 56 px del diseño
  );

  static const dark = RondoColors(
    bg: Color(0xFF06110F),
    text: Color(0xFFEEF5F4),
    textSecondary: Color(0xFFA3B5B2),
    accent: Color(0xFF2DD4BF),
    accentLink: Color(0xFF5EEAD4),
    accentSoft: Color(0x242DD4BF), // 14 %
    onAccent: Color(0xFF032A25),
    hairline: Color(0x1AFFFFFF), // 10 %
    neutralSoft: Color(0x12FFFFFF), // 7 %
    error: Color(0xFFFF7A66),
    errorText: Color(0xFFFF9A89),
    errorSurface: Color(0x1AFF7A66), // 10 %
    alert: Color(0xFFFBBF24),
    alertText: Color(0xFFFCD34D),
    alertBg: Color(0xFF140E05),
    onAlert: Color(0xFF3B2300),
    alertBlobs: [Color(0xFFB45309), Color(0xFF92400E), Color(0xFF78350F)],
    toggleOff: Color(0x2EFFFFFF), // 18 %
    glassTop: Color(0x1CFFFFFF), // 11 %
    glassBottom: Color(0x0AFFFFFF), // 4 %
    glassBorder: Color(0x29FFFFFF), // 16 %
    glassHighlight: Color(0x38FFFFFF), // 22 %
    glassShadow: Color(0x59000000), // 35 %
    tintTop: Color(0xFF5EEAD4),
    tintBottom: Color(0xFF2DD4BF),
    tintHighlight: Color(0xB3FFFFFF), // 70 %
    tintBorder: Color(0x59FFFFFF), // 35 %
    avatarBlueTop: Color(0xFF3B82F6),
    avatarBlueBottom: Color(0xFF1E40AF),
    blobs: [
      Color(0xFF0F766E),
      Color(0xFF1E40AF),
      Color(0xFF065F46),
      Color(0xFF4C1D95),
    ],
    blobOpacity: 0.55,
    blobSigma: 34, // ≈ blur 64–70 px del diseño
  );

  @override
  RondoColors copyWith({
    Color? bg,
    Color? text,
    Color? textSecondary,
    Color? accent,
    Color? accentLink,
    Color? accentSoft,
    Color? onAccent,
    Color? hairline,
    Color? neutralSoft,
    Color? error,
    Color? errorText,
    Color? errorSurface,
    Color? alert,
    Color? alertText,
    Color? alertBg,
    Color? onAlert,
    List<Color>? alertBlobs,
    Color? toggleOff,
    Color? glassTop,
    Color? glassBottom,
    Color? glassBorder,
    Color? glassHighlight,
    Color? glassShadow,
    Color? tintTop,
    Color? tintBottom,
    Color? tintHighlight,
    Color? tintBorder,
    Color? avatarBlueTop,
    Color? avatarBlueBottom,
    List<Color>? blobs,
    double? blobOpacity,
    double? blobSigma,
  }) {
    return RondoColors(
      bg: bg ?? this.bg,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentLink: accentLink ?? this.accentLink,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      hairline: hairline ?? this.hairline,
      neutralSoft: neutralSoft ?? this.neutralSoft,
      error: error ?? this.error,
      errorText: errorText ?? this.errorText,
      errorSurface: errorSurface ?? this.errorSurface,
      alert: alert ?? this.alert,
      alertText: alertText ?? this.alertText,
      alertBg: alertBg ?? this.alertBg,
      onAlert: onAlert ?? this.onAlert,
      alertBlobs: alertBlobs ?? this.alertBlobs,
      toggleOff: toggleOff ?? this.toggleOff,
      glassTop: glassTop ?? this.glassTop,
      glassBottom: glassBottom ?? this.glassBottom,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassShadow: glassShadow ?? this.glassShadow,
      tintTop: tintTop ?? this.tintTop,
      tintBottom: tintBottom ?? this.tintBottom,
      tintHighlight: tintHighlight ?? this.tintHighlight,
      tintBorder: tintBorder ?? this.tintBorder,
      avatarBlueTop: avatarBlueTop ?? this.avatarBlueTop,
      avatarBlueBottom: avatarBlueBottom ?? this.avatarBlueBottom,
      blobs: blobs ?? this.blobs,
      blobOpacity: blobOpacity ?? this.blobOpacity,
      blobSigma: blobSigma ?? this.blobSigma,
    );
  }

  /// Mezcla dos paletas; Flutter lo usa para animar el cambio claro ↔ oscuro.
  @override
  RondoColors lerp(ThemeExtension<RondoColors>? other, double t) {
    if (other is! RondoColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return RondoColors(
      bg: mix(bg, other.bg),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
      accentLink: mix(accentLink, other.accentLink),
      accentSoft: mix(accentSoft, other.accentSoft),
      onAccent: mix(onAccent, other.onAccent),
      hairline: mix(hairline, other.hairline),
      neutralSoft: mix(neutralSoft, other.neutralSoft),
      error: mix(error, other.error),
      errorText: mix(errorText, other.errorText),
      errorSurface: mix(errorSurface, other.errorSurface),
      alert: mix(alert, other.alert),
      alertText: mix(alertText, other.alertText),
      alertBg: mix(alertBg, other.alertBg),
      onAlert: mix(onAlert, other.onAlert),
      alertBlobs: [
        for (var i = 0; i < alertBlobs.length; i++)
          mix(alertBlobs[i], other.alertBlobs[i % other.alertBlobs.length]),
      ],
      toggleOff: mix(toggleOff, other.toggleOff),
      glassTop: mix(glassTop, other.glassTop),
      glassBottom: mix(glassBottom, other.glassBottom),
      glassBorder: mix(glassBorder, other.glassBorder),
      glassHighlight: mix(glassHighlight, other.glassHighlight),
      glassShadow: mix(glassShadow, other.glassShadow),
      tintTop: mix(tintTop, other.tintTop),
      tintBottom: mix(tintBottom, other.tintBottom),
      tintHighlight: mix(tintHighlight, other.tintHighlight),
      tintBorder: mix(tintBorder, other.tintBorder),
      avatarBlueTop: mix(avatarBlueTop, other.avatarBlueTop),
      avatarBlueBottom: mix(avatarBlueBottom, other.avatarBlueBottom),
      blobs: [
        for (var i = 0; i < blobs.length; i++)
          mix(blobs[i], other.blobs[i % other.blobs.length]),
      ],
      blobOpacity: blobOpacity + (other.blobOpacity - blobOpacity) * t,
      blobSigma: blobSigma + (other.blobSigma - blobSigma) * t,
    );
  }
}

/// Atajo: `context.rondo.accent` en vez de
/// `Theme.of(context).extension<RondoColors>()!.accent`.
extension RondoColorsContext on BuildContext {
  RondoColors get rondo => Theme.of(this).extension<RondoColors>()!;
}
