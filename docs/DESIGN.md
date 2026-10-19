# Rondó: especificación de diseño "Cristal" (Liquid Glass)

> Documento de handoff para implementación en **Flutter/Dart**. Fuente: canvas de diseño "Rondó · Liquid Glass", página **A · Cristal a fondo**.
> Si este archivo y el código se contradicen, este archivo manda. Si este archivo y la especificación técnica (`Rondo_Especificacion_Tecnica.pdf`) se contradicen en **comportamiento**, manda la especificación técnica; este documento solo define **apariencia**.

---

## 1. Principios

1. **Vidrio sobre luz de color.** Las superficies son paneles translúcidos con desenfoque sobre un fondo con 2–3 manchas de color muy difuminadas. Sin manchas detrás, el vidrio no se percibe: todo fondo de pantalla lleva su capa de manchas.
2. **Una sola acción principal por pantalla:** cápsula "tintada" (turquesa sólido con brillo). Todo lo demás es vidrio neutro.
3. **El color tiene significado:**
   - Turquesa = marca, acción, estado activo.
   - **Coral = SOLO errores** (código incorrecto, campo inválido). Nunca decorativo, nunca para alertas de caída.
   - **Ámbar = alerta de emergencia** (posible caída, cuenta regresiva).
4. **Claro y oscuro son equivalentes**, no uno derivado del otro: cada modo tiene su propia paleta (sección 3).
5. **Copy humano, en tuteo**, frases cortas, el error dice el problema y la salida en la misma frase.
6. **Sin contraseñas:** acceso por celular + código SMS de 4 dígitos, o biometría.

---

## 2. Arquitectura visual de una pantalla

```
Stack
 ├─ Fondo sólido (bg)
 ├─ Capa de manchas (3 círculos, blur 56–70 px, opacidad 0.4–0.75)
 └─ SafeArea → contenido
      ├─ Barra superior: botón Atrás (círculo de vidrio 44) + indicador de progreso (cápsula de vidrio)
      ├─ Título grande (32/700) + subtítulo (15/400, texto secundario)
      ├─ Tarjetas de vidrio (radio 24)
      ├─ Spacer
      └─ Botón principal tintado (cápsula, alto 56) + nota legal 12px
```

Márgenes laterales de pantalla: **20 px** (24 en la pantalla Entrar). Separación entre tarjetas: **10–12 px**. Antes de un bloque nuevo: **22 px**.

---

## 3. Tokens

### 3.1 Color

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `bg` | `#EAF1F0` | `#06110F` | Fondo de pantalla |
| `text` | `#0E1A19` | `#EEF5F4` | Texto principal |
| `textSecondary` | `#3B4D4A` | `#A3B5B2` | Subtítulos, etiquetas, ayudas |
| `accent` | `#0B7A6E` | `#2DD4BF` | Marca, toggles, progreso, iconos activos |
| `accentLink` | `#0B6B60` | `#5EEAD4` | Enlaces de texto |
| `accentSoft` | `#0B7A6E` @ 12% | `#2DD4BF` @ 14% | Fondo de chips/iconos activos |
| `onAccent` | `#FFFFFF` | `#032A25` | Texto sobre botón tintado |
| `hairline` | `#0E1A19` @ 10% | `#FFFFFF` @ 10% | Separadores dentro de tarjetas |
| `error` | `#D9442F` | `#FF7A66` | Bordes de error |
| `errorText` | `#B5321F` | `#FF9A89` | Texto de error |
| `errorSurface` | `#D9442F` @ 9% | `#FF7A66` @ 10% | Fondo de banner de error |
| `alert` | `#F59E0B` | `#FBBF24` | Anillo de cuenta regresiva, botón de ayuda |
| `alertText` | `#92400E` | `#FCD34D` | Chip "Posible caída" |
| `alertBg` | `#FBF3E4` | `#140E05` | Fondo de la pantalla de alerta |
| `toggleOff` | `#0E1A19` @ 14% | `#FFFFFF` @ 18% | Toggle apagado |

**Manchas de fondo (blobs)**

| | Claro | Oscuro |
|---|---|---|
| Turquesa | `#5EEAD4` op. 0.6–0.7 | `#0F766E` op. 0.55–0.6 |
| Azul | `#93C5FD` op. 0.5–0.6 | `#1E40AF` op. 0.4–0.45 |
| Menta | `#A7F3D0` op. 0.7 | `#065F46` op. 0.7 |
| Violeta (opcional, solo paso 1) | `#C4B5FD` op. 0.45 | `#4C1D95` op. 0.4 |
| Alerta | `#FCD34D`, `#FDBA74`, `#FDE68A` | `#B45309`, `#92400E`, `#78350F` |

Tamaño 240–380 px, desenfoque 56 px (claro) / 64–70 px (oscuro). Posición: una arriba-izquierda o arriba-derecha, una a media altura en el borde opuesto, una abajo. Varía la posición entre pantallas para que no se vea como plantilla.

### 3.2 Vidrio (3 niveles)

| Nivel | Uso | Claro | Oscuro |
|---|---|---|---|
| **Tarjeta** | Listas, campos, opciones | Degradado vertical blanco 66% → 40% | Blanco 11% → 4% |
| **Control** | Botón atrás, progreso, tab bar, botones secundarios | Igual que tarjeta, forma cápsula/círculo | Igual |
| **Tintado** | Botón principal | Degradado `#139384` → `#0B7A6E` | Degradado `#5EEAD4` → `#2DD4BF` |

Receta común:
- Desenfoque de fondo: **28 px** (CSS) ≈ `sigma 14` en Flutter.
- Borde 1 px: claro blanco @ 75%, oscuro blanco @ 16%.
- Brillo interior superior 1 px: claro blanco @ 95%, oscuro blanco @ 22%.
- Sombra: claro `0 12 32` `#143C37` @ 10%; oscuro `0 16 40` negro @ 35%.
- Tintado: brillo interior superior blanco @ 45% (claro) / 70% (oscuro), sombra de color del acento @ 30–35%, borde blanco @ 25–35%.

### 3.3 Tipografía

Familia: **Geist** (paquete `google_fonts`), con la del sistema como respaldo. En iOS puede usarse SF Pro (sistema).

| Estilo | Tamaño / peso | Interletrado | Uso |
|---|---|---|---|
| `brand` | 46 / 700 | -1.4 | "Rondó" en Entrar |
| `alertTitle` | 40 / 700 | -1.0 | "¿Estás bien?" |
| `title` | 32 / 700, alto de línea 1.1 | -0.8 | Títulos de pantalla |
| `stat` | 22 / 700 | -0.4 | "Todo en orden" |
| `headline` | 17 / 600 | 0 | Títulos de opción, botones |
| `body` | 17 / 400 | 0 | Valores de campos |
| `callout` | 15–16 / 400–600 | 0 | Subtítulos, nombres en listas |
| `label` | 13 / 600 | 0 | Etiquetas, chips, descripciones |
| `caption` | 12 / 400–600 | 0 | Notas legales, etiquetas de campo |
| `countdown` | 56 / 700, números tabulares | -2 | "0:24" |
| `codeDigit` | 32 / 600 | 0 | Dígitos del código |

### 3.4 Radios y medidas

| Elemento | Medida |
|---|---|
| Tarjeta / lista | radio 24 |
| Tarjeta héroe (estado de ronda) | radio 32 |
| Campo suelto / banner | radio 20 |
| Caja de dígito | 76 alto, radio 22 |
| Icono en tarjeta | 44×44, radio 14 |
| Logo en Entrar | 104×104, radio 34 |
| Botón principal | alto 56 (54 dentro de tarjeta), cápsula |
| Botón secundario | alto 50, cápsula |
| Botón de alerta | alto 64, cápsula |
| Botón atrás / avatar perfil | 44×44 círculo |
| Avatar en lista | 40 círculo (34 en pila, borde 2 del color de fondo) |
| Toggle | 52×32, perilla 28 |
| Tab bar | alto 68, cápsula flotante a 16 de los lados y 24 del borde inferior |
| Toque mínimo | 44×44 |

---

## 4. Componentes

**GlassCard**: contenedor de vidrio nivel Tarjeta. Si contiene filas, se separan con `hairline` de 1 px con sangría izquierda (16–18 px, o 68 cuando la fila tiene avatar).

**PrimaryButton**: cápsula tintada, texto `headline` en `onAccent` (peso 700 en oscuro). Solo uno por pantalla.

**SecondaryButton**: cápsula de vidrio, texto `headline`, color `text` o `textSecondary` si está deshabilitado (ej. "Reenviar en 0:24").

**BackButton**: círculo de vidrio 44, chevron 18 px trazo 2.2. `semanticLabel: "Atrás"`.

**StepPill**: cápsula de vidrio 32 alto: N barras de 18×5 (radio 3), la actual y anteriores en `accent`, las siguientes en `toggleOff` + texto "1 de 2" (`label`, `textSecondary`).

**ChoiceCard** (¿Para quién?): vidrio, padding 16, fila: icono 44 en `accentSoft` | título + descripción | radio 24. Seleccionada: contorno interior 2 px `accent`, radio relleno `accent` con check `onAccent`. No seleccionada: icono sobre fondo neutro (`text` @ 6% / blanco @ 7%), radio vacío con borde 1.5 px.

**GlassField**: etiqueta `caption` 600 arriba + valor `body`. Agrupados en una GlassCard con hairline. **Estado error**: fondo `errorSurface`, borde 1.5 `error`, etiqueta y ayuda en `errorText`, ayuda debajo ("Faltan 4 dígitos.").

**PhoneField** (Entrar): dentro de una GlassCard junto con el botón principal: etiqueta → fila "+57" (`textSecondary`, 20/600) | divisor vertical 1×22 | número 20/600.

**CodeInput**: 4 cajas de vidrio en grid de 4 columnas, separación 10. Dígitos erróneos: texto `errorText` + borde 1.5 `error`. Debajo, **ErrorBanner**: icono de círculo con "!" + título 15/600 en `errorText` + explicación 13 en `textSecondary`.

**ContactRow**: avatar con iniciales (degradado turquesa para el 1.º, azul para el 2.º) | nombre 16/600 + "Relación · número" 13 | chip de orden "1.º" (`accentSoft`/`accent`) o "2.º" (neutro). Última fila: "Agregar contacto" con círculo de borde punteado y "+", en `accentLink`.

**PermissionRow**: título 16/600 + razón 13 (`textSecondary`) | Toggle. La razón SIEMPRE va al lado del permiso, antes de pedir el permiso del sistema.

**Toggle**: 52×32, encendido `accent` con perilla a la derecha, apagado `toggleOff`. Perilla blanca con sombra suave.

**StatusChip**: cápsula, 13/700, padding 6×12. Variantes: *Ronda activa* (`accentSoft`/`accent`), *Alerta* (ámbar @ 18% / `alertText`), *En pausa* (neutro).

**StatusRing** (Inicio): anillo 168 px con degradado cónico turquesa, 72% relleno (progreso decorativo del día), centro con pulso del logo y "Vigilando". En oscuro añade halo `accent` @ 25% blur 50.

**CountdownRing** (Alerta): círculo de vidrio 220 → anillo cónico `alert` (proporción = tiempo restante) → centro sólido con "0:24" y "para avisar".

**GlassTabBar**: cápsula de vidrio flotante, 4 pestañas iguales (icono 22 + etiqueta 11). Activa: fondo `accentSoft` en cápsula, color `accentLink`, peso 700. Pestañas: **Inicio · Contactos · Historial · Ajustes** (pendiente confirmar con la especificación).

**Logo**: arco circular abierto (gap arriba-izquierda) + línea de pulso cardiaco, trazo redondeado `accent`. En Inicio solo se usa la línea de pulso.

Iconografía: trazo 1.8–2.2, extremos redondeados, 18–24 px. Sugerido: `lucide_icons` o SVG propios. Sin emoji.

---

## 5. Pantallas

### 01 · Entrar
- Logo en vidrio (104) a 110 px del borde superior → "Rondó" (`brand`) → "Alguien pendiente, siempre." (17, `textSecondary`).
- Spacer.
- GlassCard con PhoneField + PrimaryButton **"Enviarme el código"**.
- Nota: "Te llega un SMS de 4 dígitos. Sin contraseñas." (13, centrada).
- SecondaryButton con icono: **"Entrar con Face ID"** (en Android: "Entrar con huella"; decidir según plataforma con `local_auth`).
- "¿Primera vez? **Crear cuenta**" (enlace).

### 02 · ¿Para quién es la cuenta? (Paso 1 de 2)
- BackButton + StepPill "1 de 2".
- Título + "Puede cambiarlo después."
- ChoiceCards: **Me cuido a mí** ("El teléfono vigila caídas y avisa a tus contactos.") / **Cuido a alguien** ("Recibes sus alertas y su ubicación cuando algo pasa.").
- GlassCard: "¿Cómo te llamas?" / "Celular".
- PrimaryButton **"Continuar"** + "Al continuar aceptas el *tratamiento de datos de salud*." (enlace al aviso de Ley 1581).

### 03 · ¿A quién avisamos? (Paso 2 de 2)
- BackButton + StepPill "2 de 2".
- Título + "Al menos un contacto. Les llega un SMS, incluso sin datos."
- GlassCard de ContactRows + "Agregar contacto".
- Etiqueta "Lo que Rondó necesita" → GlassCard de PermissionRows: **Ubicación siempre** ("Solo se envía dentro de una alerta.") / **Sensores de movimiento** ("Detectan la caída en el teléfono.").
- PrimaryButton **"Activar mi ronda"** + "Puedes pausarla cuando quieras." Deshabilitado si no hay contactos.

### 04 · Código (estado error)
- BackButton → "Escribe el código" → "Lo enviamos al **+57 315 002 0755**".
- CodeInput (4 dígitos, autoavance, pegado desde SMS / autofill).
- Error: ErrorBanner "Ese código no coincide" / "Te quedan 2 intentos. También puedes pedir uno nuevo." Solo los dígitos afectados se marcan en coral; el botón principal NO cambia de color.
- Spacer → GlassCard info: "Sin datos móviles, el código llega igual por SMS."
- PrimaryButton **"Confirmar"** + SecondaryButton **"Reenviar en 0:24"** (deshabilitado hasta 0:00, luego "Reenviar código").

### 05 · Inicio (ronda activa)
- Fecha (15, secundario) + "Hola, {nombre}" (`title`) | avatar de perfil 44 con iniciales.
- Tarjeta héroe (radio 32): StatusRing → chip "Ronda activa" → "Todo en orden" → "Desde las 7:02 a. m. · sin novedades".
- Grid 2 columnas: **Pausar ronda** / **Ruta segura** (vidrio, icono + etiqueta).
- Fila "Te cuidan 2 personas" con avatares apilados + chevron.
- GlassTabBar flotante. Dejar ~100 px de padding inferior en el scroll para que el contenido pase por debajo del vidrio.
- Estados a diseñar luego: *En pausa* (anillo gris, chip neutro, botón "Reanudar"), *Sin conexión*.

### 06 · Alerta de caída
- Fondo `alertBg` + manchas ámbar. Pantalla completa, sin navegación, debe mostrarse sobre la pantalla de bloqueo (full-screen intent en Android).
- Chip "Posible caída · {hora}" → "¿Estás bien?" (`alertTitle`) → "Si no respondes, avisamos a {contacto 1} con tu ubicación."
- CountdownRing (30 s sugeridos; el valor real lo define la especificación).
- SecondaryButton grande **"Estoy bien"** (vidrio, 64) y botón ámbar **"Pedir ayuda ahora"** (icono de teléfono, texto `#3B2300`).
- Nota: "Se enviará un SMS a {contactos}."
- Vibración + sonido + anuncio de accesibilidad al aparecer.

---

## 6. Implementación en Flutter

### 6.1 Tema

```dart
@immutable
class RondoColors extends ThemeExtension<RondoColors> {
  final Color bg, text, textSecondary, accent, accentLink, onAccent,
      hairline, error, errorText, errorSurface, alert, alertText, alertBg,
      toggleOff, glassTop, glassBottom, glassBorder, glassHighlight;
  final List<Color> blobs;
  // constructor, copyWith, lerp...

  static const light = RondoColors(
    bg: Color(0xFFEAF1F0), text: Color(0xFF0E1A19), textSecondary: Color(0xFF3B4D4A),
    accent: Color(0xFF0B7A6E), accentLink: Color(0xFF0B6B60), onAccent: Colors.white,
    hairline: Color(0x1A0E1A19), error: Color(0xFFD9442F), errorText: Color(0xFFB5321F),
    errorSurface: Color(0x17D9442F), alert: Color(0xFFF59E0B), alertText: Color(0xFF92400E),
    alertBg: Color(0xFFFBF3E4), toggleOff: Color(0x240E1A19),
    glassTop: Color(0xA8FFFFFF), glassBottom: Color(0x66FFFFFF),
    glassBorder: Color(0xBFFFFFFF), glassHighlight: Color(0xF2FFFFFF),
    blobs: [Color(0xFF5EEAD4), Color(0xFF93C5FD), Color(0xFFA7F3D0)],
  );

  static const dark = RondoColors(
    bg: Color(0xFF06110F), text: Color(0xFFEEF5F4), textSecondary: Color(0xFFA3B5B2),
    accent: Color(0xFF2DD4BF), accentLink: Color(0xFF5EEAD4), onAccent: Color(0xFF032A25),
    hairline: Color(0x1AFFFFFF), error: Color(0xFFFF7A66), errorText: Color(0xFFFF9A89),
    errorSurface: Color(0x1AFF7A66), alert: Color(0xFFFBBF24), alertText: Color(0xFFFCD34D),
    alertBg: Color(0xFF140E05), toggleOff: Color(0x2EFFFFFF),
    glassTop: Color(0x1CFFFFFF), glassBottom: Color(0x0AFFFFFF),
    glassBorder: Color(0x29FFFFFF), glassHighlight: Color(0x38FFFFFF),
    blobs: [Color(0xFF0F766E), Color(0xFF1E40AF), Color(0xFF065F46)],
  );
}
```

`MaterialApp(theme: ..., darkTheme: ..., themeMode: ThemeMode.system)`, con un ajuste en la app para forzar claro/oscuro.

### 6.2 Vidrio

```dart
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 24, this.padding});
  final Widget child; final double radius; final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<RondoColors>()!;
    final r = BorderRadius.circular(radius);
    final reduce = MediaQuery.of(context).highContrast || RondoPerf.reduceGlass;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: reduce ? null : LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [c.glassTop, c.glassBottom]),
        color: reduce ? c.bg.withOpacity(.96) : null,
        border: Border.all(color: c.glassBorder),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    if (reduce) return body;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: body,
      ),
    );
  }
}
```

- El brillo superior (1 px) se puede simular con un `Positioned` de 1 px con `glassHighlight` dentro del `Stack` de la tarjeta, o con un borde superior de color distinto.
- La sombra va **fuera** del `ClipRRect` (un `Container` padre con `boxShadow`).
- Las manchas: `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Stack(...círculos...))` detrás de todo; se pintan **una vez** por pantalla (envolver en `RepaintBoundary`).

### 6.3 Rendimiento y batería (requisito, no opcional)

- `BackdropFilter` es costoso. Límite: **≤ 6 superficies de vidrio visibles a la vez** por pantalla. Las filas dentro de una lista NO llevan su propio filtro: el filtro va en la tarjeta contenedora.
- Modo **"vidrio reducido"** (`RondoPerf.reduceGlass = true`) cuando:
  - el sistema pide reducir transparencias o hay alto contraste,
  - ahorro de batería activo o batería < 20%,
  - el dispositivo es de gama baja (medir FPS en las primeras pantallas).
  En ese modo: sin blur, superficies sólidas al 96%, manchas estáticas.
- Nada de animar las manchas en Inicio mientras la ronda corre en segundo plano.

### 6.4 Accesibilidad
- Contraste verificado: texto ≥ 4.5:1 sobre vidrio en ambos modos (los valores de la tabla ya cumplen sobre los fondos indicados; vuelve a revisar si cambias las manchas).
- `Semantics` en botones de solo icono (Atrás, Perfil, Agregar contacto, Face ID).
- Toggles con `Semantics(toggled: ...)` y etiqueta del permiso.
- Respetar `MediaQuery.textScaler` hasta 1.3 sin cortar textos (las tarjetas crecen en alto).
- La alerta anuncia "Posible caída detectada. Avisaremos en 30 segundos." con `SemanticsService.announce`.

### 6.5 Estructura sugerida

```
lib/
  core/theme/      rondo_colors.dart, rondo_text.dart, rondo_theme.dart
  core/widgets/    glass.dart, blob_background.dart, primary_button.dart,
                   secondary_button.dart, back_button.dart, step_pill.dart,
                   glass_field.dart, code_input.dart, error_banner.dart,
                   contact_row.dart, permission_row.dart, rondo_toggle.dart,
                   status_chip.dart, status_ring.dart, countdown_ring.dart,
                   glass_tab_bar.dart
  features/auth/       login_page.dart, code_page.dart
  features/onboarding/ profile_page.dart, contacts_page.dart
  features/home/       home_page.dart
  features/alert/      fall_alert_page.dart
```

---

## 7. Criterios de aceptación visual

- [ ] Las 6 pantallas existen en claro y oscuro y cambian con el tema del sistema.
- [ ] Coral aparece únicamente en estados de error.
- [ ] Ámbar aparece únicamente en la alerta de caída y el chip "Alerta".
- [ ] Cada pantalla tiene exactamente un botón tintado.
- [ ] Ningún objetivo táctil mide menos de 44×44.
- [ ] Con "vidrio reducido" activo, la app se ve completa y legible sin blur.
- [ ] Máximo 6 `BackdropFilter` simultáneos por pantalla (verificar con Flutter DevTools).
- [ ] Inicio mantiene 60 fps en scroll en un dispositivo Android de gama media.

## 8. Pendientes de diseño
- Vista del cuidador (recibir la alerta de otra persona).
- Ruta segura, Historial, Ajustes, Contactos.
- Estados: ronda en pausa, sin conexión, permiso denegado.
- Confirmar pestañas de la tab bar y duración real de la cuenta regresiva con la especificación técnica.