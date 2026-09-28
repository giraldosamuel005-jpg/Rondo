# Plan de arranque — Rondó (app móvil de detección de emergencias)

## Contexto

El repo es `C:\Users\maria\Rondo` (remoto `github.com/giraldosamuel005-jpg/Rondo`, rama `main`); por ahora solo tiene
`README.md` y este plan en `docs/`. Todo el proyecto (app, functions, web, CI) va dentro de esa carpeta, según la
estructura de "Arquitectura". Hay que construir desde cero la app descrita en
`Downloads\Rondo_Requerimientos_Funcionales.pdf` (34 RF): detección de caídas/accidentes/microsueños con sensores,
alerta con cuenta regresiva, notificación a contactos (push → SMS → alarma local), medicamentos, ficha médica QR,
dashboard de cuidadores, modo offline y privacidad.

Decisiones del equipo: **Android + iOS**, equipo de **2 personas** que sabe **Flutter/Dart**, **proyecto académico de
este semestre (~12 semanas)**, cuidador con **cuenta propia en la misma app**, y **Firebase en plan Blaze** (con
tarjeta y alerta de presupuesto; con uso académico el costo es $0).

Entorno verificado: Flutter 3.47.2 / Dart 3.13.2, Node, Java, Android SDK + adb. Falta Firebase CLI y FlutterFire CLI.
**Windows no puede compilar iOS** → ver "Riesgos".

---

## Stack recomendado

| Capa | Tecnología | Por qué |
|---|---|---|
| App (front) | **Flutter 3.47 + Dart 3** | El equipo ya lo sabe; un solo código para Android e iOS |
| Estado / DI | **Riverpod** (+ `riverpod_generator`) | Estándar actual, testeable, sin `BuildContext` |
| Navegación | **go_router** | Deep links (invitaciones, QR) y guards por rol/login |
| Modelos | **freezed + json_serializable** | Inmutables, `copyWith`, serialización a Firestore |
| Auth | **Firebase Auth (teléfono + SMS)** + `local_auth` (huella/Face ID) | RF-01, RF-02 sin servidor propio |
| Base de datos | **Cloud Firestore** con persistencia offline | Trae la **cola offline y la sincronización incluidas** (RF-28/29), listeners en tiempo real para el dashboard |
| Backend | **Cloud Functions (TypeScript, Node 22)** | Envía push, maneja la página pública del QR, purgas programadas |
| Push | **Firebase Cloud Messaging** (`firebase_messaging`) | Gratis, Android e iOS |
| Web pública QR | **Firebase Hosting** (HTML+JS estático) | Ficha médica sin login (RF-24) |
| Seguridad datos | **Firestore Security Rules** + tests con emulador | RF-27: cuidador solo ve a quien lo invitó |
| Sensores | `sensors_plus`, `geolocator`, `flutter_foreground_task` | Monitoreo continuo en segundo plano (Android: foreground service) |
| Microsueños | `camera` + `google_mlkit_face_detection` (on-device) | Probabilidad de ojo abierto, sin enviar video a ningún servidor |
| Voz | `speech_to_text` | Cancelar alerta diciendo "cancelar"/"estoy bien" (RF-14) |
| Alarmas locales | `flutter_local_notifications` (exact alarms + full-screen intent) + `audioplayers` | Medicamentos (RF-22), alerta a pantalla completa (RF-13), alarma local (RF-17) |
| Mapas | `google_maps_flutter` | SDK móvil gratis; geocercas y dashboard |
| QR | `qr_flutter` | Genera el QR de la ficha |
| Seguros locales | `flutter_secure_storage` | PIN de cancelación (hash), no en texto plano |
| Conectividad | `internet_connection_checker_plus` | Saber si hay internet real (no solo WiFi conectado) para decidir push vs SMS |
| Calidad | `flutter_lints`, `mocktail`, GitHub Actions | CI: `flutter analyze` + `flutter test` + tests de reglas/functions |

Monitoreo: Firebase Crashlytics (gratis) para ver fallos en los dispositivos de prueba.

---

## Arquitectura

```
Rondo/
├─ app/                      # Flutter
│  └─ lib/
│     ├─ core/               # router, tema, permisos, conectividad, errores, constantes
│     └─ features/
│        ├─ auth/            # RF-01..03
│        ├─ onboarding/      # roles, consentimientos (RF-30), aviso RF-34
│        ├─ contacts/        # RF-04, RF-05
│        ├─ detection/       # detectores puros en Dart (RF-06..11) + servicio en 2º plano
│        ├─ alert/           # pantalla de alerta, cancelación, cadena de envío (RF-13..17)
│        ├─ location/        # geocercas RF-18, Acompáñame RF-19/33
│        ├─ health/          # medicamentos RF-20..22, ficha + QR RF-23..25
│        ├─ caregiver/       # dashboard RF-26/27
│        └─ privacy/         # panel de permisos RF-31/32
│        (cada feature: data/ · domain/ · presentation/)
├─ functions/                # Cloud Functions TypeScript
├─ web/qr/                   # página pública de la ficha médica
├─ firestore.rules · firestore.indexes.json · firebase.json
├─ docs/                     # decisiones (ADR) + matriz RF → pantalla/test
└─ .github/workflows/ci.yml
```

**Clave de diseño:** los detectores (caída, inactividad, accidente, microsueño) son **clases Dart puras** que reciben
muestras de sensores y emiten eventos. No dependen de Flutter ni de plugins → se prueban con trazas grabadas (CSV)
y se ajustan umbrales sin tocar el celular.

### Modelo de datos (Firestore)

- `users/{uid}`: nombre, teléfono, `roles[]` (adulto_mayor, conductor, ruta_riesgo, cuidador), `accountType`
  (para_mi / cuidar), consentimientos con fecha, `fcmTokens[]`
  - `contacts/{id}`: nombre, teléfono, relación, `linkedUid?`
  - `medications/{id}`: nombre, dosis, frecuencia/horarios, `stock`, `unitsPerDose`, inicio → días restantes = stock / (dosis·tomas por día)
  - `intakes/{id}`: `medicationId`, `scheduledAt`, `takenAt?`, estado (tomada/omitida/pendiente)
  - `medicalCard` (doc único): tipo de sangre, alergias, condiciones, contacto de emergencia
  - `qrAccesses/{id}`: fecha, user-agent aproximado (RF-25, solo lo lee el dueño)
  - `alerts/{alertId}`: tipo, estado (cancelada/enviada), ubicación, canales usados, `createdAt` — **`alertId` = UUID generado en el celular** (idempotencia: sin duplicados al sincronizar)
  - `geofences/{id}`: centro, radio, tipo (riesgo/seguro), avisar al entrar/salir
  - `status` (doc): última ubicación, última actividad, batería — lo lee el dashboard
- `caregiverLinks/{patientUid_caregiverUid}`: estado activo/revocado
- `invitations/{id}`: `fromUid`, teléfono invitado, código, estado, expiración
- `qrTokens/{token}`: `uid`, activo (token aleatorio de 128 bits; revocar = borrar y crear otro)
- `companionSessions/{id}`: dueño, contacto, estado; subcolección `locations` → **se borra al confirmar llegada** (RF-33)

> **El PIN de cancelación no se guarda en Firestore.** Su hash vive solo en el dispositivo (`flutter_secure_storage`),
> así nadie con acceso a la base de datos puede leerlo ni intentar adivinarlo.

**Reglas:** el dueño lee/escribe lo suyo; el cuidador **solo lee** si existe `caregiverLinks/{uid}_{callerUid}` con
estado activo → al revocar, pierde acceso de inmediato (RF-27). Nadie lee `qrTokens` desde el cliente.

### Cloud Functions

1. `onAlertCreated` (trigger Firestore): envía push a todos los contactos con app, **en simultáneo** (lo que el PDF
   deja por defecto), con ubicación. Marca `notifiedAt` en una transacción para no enviar dos veces.
2. `getMedicalCard` (HTTPS, sin login): recibe el token, devuelve solo los campos de la ficha, registra el acceso.
3. `acceptInvitation` (callable): cuando el cuidador se registra con el teléfono invitado, crea el `caregiverLink`.
4. `onCompanionEnded`: borra las ubicaciones de la sesión. `scheduledPurge` (diario): borra ubicaciones viejas.

### Flujo de emergencia (el corazón de la app)

```
Detector dispara (respeta cooldown por tipo, RF-10)
  → Pantalla completa + alarma + vibración, cuenta regresiva 10 s (RF-13)
      ├─ Cancelado (botón / PIN / huella / voz, RF-14) → se registra "cancelada"
      └─ No cancelado:
           1. Se escribe alerts/{uuid} (Firestore lo encola si no hay red, RF-28)
           2. ¿Hay internet?  Sí → la función envía push a los contactos (RF-15)
           3. No → SMS a cada contacto con https://maps.google.com/?q=lat,lng (RF-16)
           4. ¿Tampoco hay SMS/señal? → alarma sonora local a máximo volumen + linterna (RF-17)
           5. Al volver la red → sincroniza sola, sin duplicados (RF-29)
```

SMS de emergencia: se envía **desde el celular del usuario** (con su plan). En Android va automático (SmsManager
por un MethodChannel pequeño en Kotlin, permiso `SEND_SMS`). En iOS se abre el mensaje ya escrito y el usuario debe
tocar Enviar (limitación de Apple).

### Detección (enfoque inicial, con umbrales ajustables)

- **Caída (RF-06):** caída libre (|a| < 0,5 g por >80 ms) → impacto (> 2,5–3 g) → cambio de orientación (giroscopio)
  → quietud posterior de 5–10 s.
- **Falsos positivos (RF-09):** celular caído = impacto muy alto + queda plano e inmóvil de inmediato; ejercicio =
  actividad periódica sostenida antes del evento; frenazo = desaceleración sin pico de impacto.
- **Inactividad (RF-07):** sin movimiento significativo por N minutos en horario configurado → primero pregunta
  "¿Estás bien?" (RF-12), luego alerta.
- **Accidente (RF-08):** impacto > 4 g + velocidad GPS que cae de > 30 km/h a < 5 km/h en ~3 s.
- **Microsueño (RF-11):** con el celular en soporte, ambos ojos con probabilidad de apertura < 0,3 por > 1,5 s →
  alarma fuerte para despertar al conductor. Si se repite, ofrece alerta a contactos.

Se incluye una **pantalla de depuración** para grabar trazas reales de sensores a CSV y alimentar los tests.

---

## Decisiones sobre los puntos pendientes del PDF

- **Cuidador:** cuenta propia en la misma app. Invitación (RF-05): el usuario elige el contacto, se abre el SMS ya
  escrito con un link (Firebase Hosting) + código. El cuidador instala la app, se registra **con ese mismo número** y
  la invitación se asocia sola. No hace falta Twilio → gratis.
- **Conductor y ruta de riesgo:** roles que se combinan en el mismo usuario, pero se construyen en la fase 5 (se
  pueden recortar si falta tiempo sin romper nada).
- **Varios cuidadores:** notificación simultánea.
- **OTP de 4 dígitos (RF-01):** Firebase usa 6 dígitos fijos. Propuesta: aceptar 6 (más seguro) y dejarlo
  documentado como ajuste del requerimiento → **confirmarlo con el profesor**.

---

## Plan por fases (12 semanas, 2 personas)

**A** = UI, cuenta, salud, cuidador · **B** = sensores, alerta, backend, reglas

| Semana | Fase | A | B |
|---|---|---|---|
| 1 | **0. Setup** | Proyecto Flutter, estructura, tema, go_router, Riverpod | Proyecto Firebase (Blaze + alerta $1), FlutterFire, emuladores, CI. **Spike:** foreground service + sensores con pantalla apagada en un Android real |
| 2–3 | **1. Cuenta** | Login SMS + biometría, onboarding "para mí / cuidar", roles, consentimientos, aviso RF-34 | Reglas base + tests, perfil `users`, contactos (RF-04), tokens FCM |
| 4–6 | **2. Emergencia** | Pantalla de alerta 10 s, cancelar con botón/PIN/huella, botón "Estoy bien", botón SOS manual | Detector de caídas + inactividad + cooldown, `onAlertCreated`, SMS fallback, alarma local, pruebas offline |
| 6–8 | **3. Salud** | Medicamentos, alarmas, días restantes, adherencia; ficha médica + QR | `getMedicalCard`, página web QR, revocar token, log de accesos |
| 8–9 | **4. Cuidadores** | Dashboard (estado, mapa, alertas, adherencia) | Invitaciones, `acceptInvitation`, reglas de cuidador + revocación |
| 9–11 | **5. Conductor / ruta** | Acompáñame (UI), editor de geocercas en mapa, panel de permisos (RF-31) | Accidente, microsueños (ML Kit), purga RF-33, geocercas, cancelar por voz |
| 11–12 | **6. Cierre** | Degradación al revocar permisos (RF-32), pulido UX | Pruebas de campo, ajuste de umbrales, build iOS, demo, documentación |

**Mínimo demostrable al final de la semana 6:** registro → contactos → caída detectada → alerta → push/SMS al
contacto. Si el semestre se aprieta, lo primero que se recorta es la fase 5.

---

## Riesgos y limitaciones (dejarlos documentados en el informe)

1. **iOS necesita un Mac** para compilar. Opciones: un Mac prestado de la universidad, o **Codemagic** (plan gratis
   con minutos de macOS) para compilar en la nube. Para instalar en un iPhone real se necesita Apple ID (7 días gratis
   con Xcode) o la cuenta de desarrollador ($99/año). Recomendación: desarrollar y hacer la demo en **Android** y
   mostrar iOS como compilación secundaria.
2. **iOS en segundo plano:** Apple no permite sensores continuos. En iOS la detección continua solo funciona con
   ubicación en segundo plano activa (Acompáñame / modo conductor) o con la app abierta.
3. **SMS automático** solo en Android. Google Play restringe `SEND_SMS`: para el proyecto se distribuye por APK o
   pruebas internas.
4. **Pantalla completa sobre bloqueo:** Android 14+ restringe los full-screen intents a apps de alarma/llamadas
   (hay que declararlo). iOS: se usa notificación "time-sensitive" (las critical alerts requieren aprobación de Apple).
5. **Falsos positivos:** la detección es heurística; se mitiga con trazas grabadas, cuenta regresiva y cooldown.
6. **Batería:** el foreground service y el GPS consumen. Se muestrea a baja frecuencia en reposo.

---

## Primeros pasos concretos al aprobar el plan

1. Instalar herramientas: `npm i -g firebase-tools`, `dart pub global activate flutterfire_cli`, `flutter upgrade`.
2. Crear `Rondo/app` con `flutter create --org co.edu.usc --platforms android,ios app`, estructura `core/` +
   `features/`, dependencias base, lints y tema.
3. Crear `docs/decisiones.md` (este stack) y `docs/matriz-rf.md` (RF → pantalla → test).
4. `.gitignore` (excluir `google-services.json` / `GoogleService-Info.plist` si el repo es público), CI de GitHub Actions.
5. Firebase: lo crea el equipo en la consola (requiere su cuenta y tarjeta); luego `flutterfire configure`.
6. Actualizar el `README.md` con la descripción, el stack y cómo correr el proyecto.

---

## Verificación

- **Unit tests** de detectores con trazas CSV grabadas: caída real sobre colchón, celular soltado sobre la cama,
  trote, frenazo en carro → cada una con el resultado esperado.
- **Tests de reglas Firestore** con el emulador (`@firebase/rules-unit-testing`): cuidador con vínculo lee; sin
  vínculo o revocado → denegado; desconocido no lee `qrTokens`.
- **Tests de Functions** en el emulador: alerta crea un solo push aunque llegue dos veces; QR revocado → 404.
- **Widget tests:** cuenta regresiva de 10 s, cancelación con PIN.
- **Pruebas manuales en dispositivo:** modo avión → llega SMS con link de Maps; sin SIM y sin red → suena alarma
  local; modo avión, crear alerta, volver a la red → aparece una sola vez en el dashboard; escanear QR desde otro
  celular sin la app; revocar cuidador → su dashboard se vacía.
- CI verde (`flutter analyze`, `flutter test`, tests de reglas y functions) en cada push.
