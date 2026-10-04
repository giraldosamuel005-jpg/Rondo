# Rondó — Requerimientos funcionales

> Transcripción de `Rondo_Requerimientos_Funcionales.pdf`, con correcciones (ver [Cambios respecto al PDF](#cambios-respecto-al-pdf) al final). Este archivo es la fuente de verdad; si cambian los requerimientos, se edita aquí.

## 1. Descripción del proyecto

Rondó es una app móvil que detecta emergencias personales (caídas, accidentes de tránsito, microsueños y desmayos) con los sensores del celular y avisa automáticamente a los contactos de la persona con su ubicación. Además pone la información médica al alcance de quien atienda la emergencia y ayuda a controlar los medicamentos. Funciona con o sin internet y se adapta a quién la usa: adulto mayor, conductor, persona en ruta de riesgo o cuidador.

## 2. Perfiles de usuario

| Perfil | Módulos activos |
|---|---|
| Adulto mayor | Detección de caídas, medicamentos, ficha médica QR, botón "Estoy bien" |
| Conductor | Detección de accidentes, microsueños, ficha médica QR |
| Persona en ruta de riesgo | Modo "Acompáñame", geocercas, ficha médica QR |
| Cuidador / contacto | Dashboard de alertas, ubicación, adherencia a medicamentos |

*Los perfiles no son excluyentes: un usuario puede combinar roles.*

## 3. Requerimientos funcionales

Todos los textos de la app tratan al usuario de **tú**.

Cada requerimiento indica qué hace la app, cómo funciona, qué datos maneja y qué mensajes de error puede mostrar. Los tipos de dato son de Dart (Flutter) y son una propuesta que el equipo debe validar. Los textos entre corchetes son datos que la app completa al momento de mostrar el mensaje.

---

### 3.1 Cuenta y contactos

#### RF-01 — Registro e ingreso con número de celular y código SMS de 4 dígitos
- **Cómo funciona:** La persona escribe su celular. El servidor envía un SMS con un código de 4 dígitos que expira. Al escribirlo bien, el servidor devuelve un token de sesión que la app guarda en almacenamiento seguro. Si es la primera vez, se crea la cuenta.
- **Datos:**
  - celular: `String` (con indicativo, ej. +57)
  - código SMS: `String` (4 dígitos; String para no perder ceros iniciales)
  - token de sesión: `String` (lo entrega el servidor)
  - ID de usuario: `String` (UUID, lo asigna el servidor)
- **Errores:**
  - "Ingresa un número de celular válido."
  - "El código es incorrecto. Intenta de nuevo."
  - "El código expiró. Solicita uno nuevo."
  - "No pudimos enviar el SMS. Revisa tu conexión e intenta otra vez."

#### RF-02 — Reingreso con huella o Face ID
- **Cómo funciona:** Tras el primer ingreso, la app ofrece activar huella o Face ID. En los siguientes ingresos el sistema operativo valida la biometría y la app solo recibe "válido" o "no válido". Si falla, se usa el código SMS.
- **Datos:**
  - biometría activada: `bool` (se guarda en el celular)
  - La app nunca guarda ni ve la huella o el rostro.
- **Errores:**
  - "No se reconoció tu huella. Intenta de nuevo o ingresa con tu código SMS."
  - "Tu celular no tiene biometría configurada. Ingresa con tu código SMS."
  - "Demasiados intentos fallidos. Ingresa con tu código SMS."

#### RF-03 — Al registrarse, elegir si la cuenta es "para mí" o "para cuidar a alguien"
- **Cómo funciona:** Al terminar el registro, la persona elige "para mí" o "para cuidar a alguien". Esto define qué módulos se activan y si se muestra el dashboard de cuidador.
- **Datos:**
  - tipo de cuenta: `enum` (paraMi, cuidador)
  - perfiles activos: `List<enum>` (adultoMayor, conductor, rutaRiesgo, cuidador)
- **Errores:**
  - "Selecciona si la cuenta es para ti o para cuidar a alguien para continuar."

#### RF-04 — Registrar contactos de emergencia, que recibirán las alertas
- **Cómo funciona:** El usuario agrega contactos desde una pantalla de contactos. Ellos reciben las alertas cuando una emergencia no se cancela.
- **Datos:**
  - nombre: `String`
  - celular: `String`
  - es cuidador: `bool`
- **Errores:**
  - "Ingresa un nombre y un número de celular válidos."
  - "Este contacto ya está registrado."
  - "Debes registrar al menos un contacto de emergencia."
  - "No se pudo guardar el contacto. Intenta de nuevo."

#### RF-05 — Invitar cuidadores por SMS, aunque no tengan la app instalada
- **Cómo funciona:** Se envía un SMS al celular del cuidador con un enlace de invitación. Si no tiene la app, el enlace lo lleva a instalarla. Al aceptar, la invitación pasa de pendiente a aceptada.
- **Datos:**
  - celular del invitado: `String`
  - ID de invitación: `String` (UUID)
  - estado: `enum` (pendiente, aceptada, revocada)
- **Errores:**
  - "No se pudo enviar la invitación. Verifica el número e intenta de nuevo."
  - "Ya invitaste a esta persona."
  - "La invitación expiró. Envía una nueva."

---

### 3.2 Detección de riesgos

#### RF-06 — Detectar caídas con el acelerómetro y el giroscopio del celular
- **Cómo funciona:** La app lee el acelerómetro y el giroscopio en segundo plano. Una caída se identifica por un pico fuerte de aceleración seguido de muy poco movimiento. Los umbrales exactos se definen probando con datos reales.
- **Datos:**
  - acelerómetro x, y, z: `double`
  - giroscopio x, y, z: `double`
  - Son lecturas del sensor, el usuario no las escribe.
  - Evento creado: tipo (`enum`), fecha y hora (`DateTime`), latitud y longitud (`double`)
- **Errores:**
  - "Activa el permiso de sensores de movimiento para usar la detección de caídas."
  - "No pudimos acceder a los sensores del celular. La detección de caídas está desactivada."

#### RF-07 — Detectar inactividad prolongada (posible desmayo sin impacto)
- **Cómo funciona:** Si el celular no registra movimiento durante un tiempo prolongado en un momento en que normalmente se movería, se considera un posible desmayo y se inicia la alerta.
- **Datos:**
  - tiempo sin movimiento: `int` (segundos)
  - tiempo máximo permitido: `int` (segundos)
- **Errores:**
  - "La detección de inactividad no está disponible: el celular no está reportando datos de movimiento."
  - "Activa el permiso de sensores de movimiento para usar esta función."

#### RF-08 — Detectar accidentes de tránsito: impacto seguido de una caída anómala de velocidad
- **Cómo funciona:** Se combina un impacto fuerte (acelerómetro) con una caída brusca de velocidad medida por GPS. Un frenazo sin impacto no cuenta como accidente.
- **Datos:**
  - velocidad: `double` (m/s, del GPS)
  - fuerza del impacto: `double` (m/s²)
- **Errores:**
  - "Activa la ubicación para detectar accidentes de tránsito."
  - "No pudimos medir la velocidad. La detección de accidentes está limitada."

#### RF-09 — Reducir falsos positivos: distinguir si cayó el celular o la persona, y descartar ejercicio y frenazos bruscos
- **Cómo funciona:** Antes de lanzar la alerta se revisa el patrón de movimiento. Se descarta si solo cayó el celular y la persona sigue en movimiento, si el patrón es de ejercicio o si es un frenazo sin impacto.
- **Datos:**
  - No pide datos al usuario; usa las lecturas de los sensores.
  - confianza del evento: `double` (0 a 1)
- **Errores:**
  - Proceso interno, no muestra mensaje al usuario.
  - "No se pudo guardar el ajuste de sensibilidad."

#### RF-10 — Aplicar un cooldown por tipo de evento para no repetir alertas
- **Cómo funciona:** Después de un evento de un tipo, se ignoran nuevos eventos del mismo tipo durante un tiempo de espera, para no generar alertas repetidas.
- **Datos:**
  - tipo de evento: `enum`
  - hora del último evento: `DateTime`
  - tiempo de espera: `int` (segundos)
- **Errores:**
  - Proceso interno, no muestra mensaje al usuario. El evento omitido queda en el registro interno.

#### RF-11 — Detectar microsueños del conductor con la cámara durante el viaje
- **Cómo funciona:** Mientras el viaje está activo, la app analiza la imagen de la cámara y busca ojos cerrados por más tiempo del normal. Las imágenes se procesan en el celular y no se guardan.
- **Datos:**
  - viaje activo: `bool`
  - Los cuadros de cámara se procesan y se descartan, no se guardan.
- **Errores:**
  - "Activa el permiso de cámara para detectar microsueños."
  - "No se pudo iniciar la cámara. Cierra otras apps que la estén usando."
  - "Hay poca luz. La detección de microsueños puede no funcionar bien."

#### RF-12 — Ofrecer al adulto mayor un botón "Estoy bien" para confirmar que está sin novedad
- **Cómo funciona:** El adulto mayor toca el botón para confirmar que está sin novedad. Se registra la confirmación con su hora y el cuidador la ve en su dashboard.
- **Datos:**
  - confirmación: `DateTime` (hora en que tocó el botón)
- **Errores:**
  - "No se pudo registrar tu confirmación. Se reintentará cuando haya conexión."

---

### 3.3 Alerta de emergencia

#### RF-13 — Mostrar una alerta a pantalla completa con cuenta regresiva de 10 s y alarma sonora
- **Cómo funciona:** Al detectarse un evento aparece una pantalla completa con cuenta regresiva de 10 s y una alarma sonora, para que la persona, o quien esté cerca, la vea y la escuche.
- **Datos:**
  - ID de alerta: `String` (UUID)
  - estado: `enum` (pendiente, cancelada, enviada)
  - segundos restantes: `int`
- **Errores:**
  - "No se pudo reproducir la alarma sonora. Revisa el volumen de tu celular."
  - "No se pudo mostrar la alerta. Se avisará directamente a tus contactos."

#### RF-14 — Permitir cancelar la alerta durante la cuenta regresiva con botón, PIN, biometría o voz
- **Cómo funciona:** Durante los 10 s se puede cancelar con botón, PIN, biometría o voz. Al cancelar, la alarma se detiene y la alerta queda como cancelada.
- **Datos:**
  - PIN: `String` (se guarda como hash, nunca en texto plano)
  - palabra de cancelación por voz: `String`
- **Errores:**
  - "PIN incorrecto. Intenta de nuevo."
  - "No se reconoció tu huella. Intenta de nuevo o usa tu PIN."
  - "No te escuchamos bien. Repite la palabra de cancelación o usa el botón."
  - "Demasiados intentos fallidos. La alerta continuará."

#### RF-15 — Si la alerta no se cancela, notificar por push a todos los contactos con la ubicación
- **Cómo funciona:** Cuando la cuenta regresiva termina sin cancelar, la app envía un push a todos los contactos al mismo tiempo, con el tipo de evento, la hora y la ubicación.
- **Datos:**
  - latitud y longitud: `double`
  - hora: `DateTime`
  - contactos destino: `List<String>` (IDs)
- **Errores:**
  - "No se pudo notificar a [nombre del contacto]. Reintentando…"
  - "No se pudo obtener tu ubicación. Se avisó a tus contactos sin ella."
  - "No se pudo notificar a ningún contacto. Se intentará por SMS."

#### RF-16 — Si no hay datos, enviar un SMS con enlace a Google Maps
- **Cómo funciona:** Si el celular no tiene datos, la app envía un SMS a cada contacto con un enlace a Google Maps con la ubicación.
- **Datos:**
  - enlace: `String` (URL de Google Maps con latitud y longitud)
  - celular del contacto: `String`
- **Errores:**
  - "Sin conexión de datos. Enviando alerta por SMS."
  - "No se pudo enviar el SMS. Verifica tu señal y tu saldo."
  - "La app no tiene permiso para enviar SMS. Actívalo en ajustes."

#### RF-17 — Si no hay datos ni SMS, activar una alarma sonora local
- **Cómo funciona:** Si tampoco se puede enviar SMS, se activa una alarma sonora local para llamar la atención de las personas cercanas.
- **Datos:**
  - alarma activa: `bool`
- **Errores:**
  - "Sin conexión ni señal. Activando alarma sonora para pedir ayuda cercana."

---

### 3.4 Ubicación

#### RF-18 — Crear y editar geocercas, y avisar cuando la persona entre o salga de ellas
- **Cómo funciona:** El usuario marca un punto en el mapa, elige un radio y un nombre. La app compara su ubicación actual con el centro y avisa cuando cruza el borde hacia dentro o hacia fuera.
- **Datos:**
  - nombre: `String`
  - latitud y longitud del centro: `double`
  - radio: `double` (metros)
  - activa: `bool`
  - avisar al entrar / al salir: `bool`
- **Errores:**
  - "Ponle un nombre y un radio a la geocerca."
  - "No se pudo obtener tu ubicación. Activa el GPS e intenta de nuevo."
  - "No se pudo guardar la geocerca. Intenta de nuevo."
  - "Se alcanzó el máximo de geocercas permitidas."

#### RF-19 — Modo "Acompáñame": compartir la ubicación periódicamente con un contacto hasta confirmar la llegada segura con PIN o biometría
- **Cómo funciona:** El usuario elige un contacto e inicia el modo. La app envía su ubicación cada cierto intervalo hasta que confirma la llegada con PIN o biometría.
- **Datos:**
  - contacto elegido: `String` (ID)
  - intervalo: `int` (segundos)
  - ubicaciones: `List` (latitud, longitud, hora)
  - estado: `enum` (activo, finalizado)
- **Errores:**
  - "Selecciona un contacto para compartir tu ubicación."
  - "No se pudo compartir tu ubicación. Revisa el GPS y tu conexión."
  - "PIN o huella incorrectos. No se pudo confirmar la llegada."
  - "Se perdió la conexión. Tu ubicación se enviará cuando se recupere."

---

### 3.5 Salud

#### RF-20 — Registrar medicamentos con dosis y frecuencia
- **Cómo funciona:** El usuario agrega cada medicamento con su dosis y cada cuánto se toma.
- **Datos:**
  - nombre: `String`
  - dosis: `String` (descriptiva, ej. "500 mg")
  - unidades por toma: `int` (ej. 1 pastilla; mayor a cero)
  - frecuencia: `int` (cada cuántas horas)
  - unidades disponibles: `int`
  - fecha de inicio: `DateTime`
- **Errores:**
  - "Ingresa el nombre del medicamento, la dosis y la frecuencia."
  - "Las unidades por toma deben ser un número mayor a cero."
  - "Este medicamento ya está registrado."

#### RF-21 — Calcular los días restantes de cada medicamento
- **Cómo funciona:** Unidades por día = unidades por toma × (24 ÷ frecuencia). Días restantes = unidades disponibles ÷ unidades por día, redondeado hacia abajo. Cada vez que se registra una toma, se restan las unidades por toma de las unidades disponibles y se recalcula.
- **Datos:**
  - días restantes: `int` (se calcula, no lo escribe el usuario)
- **Errores:**
  - "Ingresa cuántas unidades tienes para calcular los días restantes."
  - "Te quedan [X] días de [medicamento]. Recuerda reponerlo."

#### RF-22 — Emitir alarmas de toma y guardar el historial de adherencia
- **Cómo funciona:** A la hora programada suena la alarma. Cuando la persona confirma la toma o la ignora, se guarda el registro. Con esos registros se calcula el porcentaje de tomas cumplidas.
- **Datos:**
  - hora programada: `DateTime`
  - tomada: `bool`
  - hora real: `DateTime` (vacía si no la tomó)
- **Errores:**
  - "No se pudo programar la alarma. Activa los permisos de notificaciones."
  - "No se pudo guardar el registro de la toma. Intenta de nuevo."

#### RF-23 — Crear una ficha médica con alergias, tipo de sangre y contacto de emergencia
- **Cómo funciona:** El usuario llena un formulario con sus datos médicos básicos. La ficha se guarda en el servidor y solo el dueño puede editarla.
- **Datos:**
  - alergias: `List<String>`
  - tipo de sangre: `enum` (A+, A-, B+, B-, AB+, AB-, O+, O-)
  - contacto de emergencia: `String` (ID de uno de los contactos registrados en RF-04; no se escribe de nuevo)
- **Errores:**
  - "Completa los campos obligatorios de la ficha médica."
  - "Elige un contacto de emergencia de tu lista."
  - "Selecciona un tipo de sangre válido."
  - "No se pudo guardar la ficha. Intenta de nuevo."

#### RF-24 — Generar un QR de la ficha, consultable sin login y en solo lectura
- **Cómo funciona:** Se genera un QR que contiene un enlace con un token aleatorio, no los datos médicos. Quien lo escanea (por ejemplo, un paramédico) abre la ficha en solo lectura sin iniciar sesión.
- **Datos:**
  - token: `String` (aleatorio)
  - enlace: `String` (URL con el token)
- **Errores:**
  - "No se pudo generar el código QR. Intenta de nuevo."
  - "Este código QR no es válido."
  - "Este enlace fue revocado por su dueño."

#### RF-25 — Revocar y regenerar el token del QR, y registrar cada consulta (visible solo para el dueño)
- **Cómo funciona:** Revocar invalida el token y el QR viejo deja de funcionar. Regenerar crea uno nuevo. Cada vez que alguien abre la ficha se guarda un registro que solo ve el dueño.
- **Datos:**
  - token activo: `bool`
  - fecha de consulta: `DateTime`
  - origen de la consulta: `String` (opcional)
- **Errores:**
  - "No se pudo regenerar el código. Intenta de nuevo."
  - "No se pudo cargar el historial de consultas."
  - "El código anterior ya no es válido."

---

### 3.6 Cuidadores

#### RF-26 — Dashboard del cuidador con estado, ubicación, alertas y adherencia de las personas a su cargo
- **Cómo funciona:** El cuidador ve la lista de personas que lo invitaron y, de cada una, su estado, última ubicación, alertas recientes y adherencia a medicamentos. Solo lee datos que ya existen.
- **Datos:** No pide datos nuevos. Lee: estado (`enum`), última ubicación (`double`, `double`), alertas (`List`), adherencia (`double`, porcentaje).
- **Errores:**
  - "No se pudo cargar la información de [nombre]. Desliza para actualizar."
  - "Aún no tienes personas a tu cargo."
  - "Sin conexión. Mostrando datos de hace [X] minutos."

#### RF-27 — Limitar al cuidador a los datos de quien lo invitó, y cortar su acceso si el usuario revoca el vínculo
- **Cómo funciona:** En cada consulta el servidor verifica que exista un vínculo activo entre el cuidador y la persona. Si el usuario revoca el vínculo, la consulta se rechaza desde ese momento.
- **Datos:**
  - ID del cuidador: `String`
  - ID del usuario: `String`
  - vínculo activo: `bool`
- **Errores:**
  - "No tienes permiso para ver esta información."
  - "[Nombre] ya no comparte su información contigo."
  - "Esta invitación ya no es válida."

---

### 3.7 Funcionamiento offline

#### RF-28 — Funcionar sin internet guardando los eventos en una cola local
- **Cómo funciona:** Sin internet, cada evento (alerta, toma, confirmación) se guarda en una base local del celular y se marca como pendiente de envío.
- **Datos:**
  - evento: JSON guardado en base local (SQLite / Hive)
  - ID local: `String` (UUID)
  - enviado: `bool`
- **Errores:**
  - "Sin conexión. Tus eventos se guardarán y se enviarán cuando vuelvas a tener internet."
  - "El almacenamiento del celular está lleno. No se pueden guardar más eventos."

#### RF-29 — Sincronizar la cola automáticamente al recuperar la red, sin pérdida ni duplicados
- **Cómo funciona:** Al volver la red, la app envía los eventos pendientes en orden. Cada uno lleva un UUID generado en el celular, así el servidor detecta si ya lo recibió y no lo duplica. Se marcan como enviados solo cuando el servidor confirma.
- **Datos:**
  - ID local: `String` (UUID)
  - enviado: `bool`
  - intentos: `int`
- **Errores:**
  - "No se pudo sincronizar. Se reintentará automáticamente."
  - "Algunos eventos no se pudieron enviar. Revisa tu conexión."

---

### 3.8 Privacidad y permisos

#### RF-30 — Pedir consentimiento explícito y por separado para ubicación, datos médicos y cámara
- **Cómo funciona:** Cada permiso se solicita por separado, con una explicación de para qué se usa. Sin consentimiento, las funciones que dependen de ese permiso no se activan.
- **Datos:**
  - consentimiento de ubicación, datos médicos y cámara: 3 `bool`
  - fecha de cada consentimiento: `DateTime`
- **Errores:**
  - "Necesitamos tu permiso de ubicación para enviar alertas con tu posición."
  - "Necesitamos tu consentimiento para guardar tus datos médicos."
  - "Necesitamos acceso a la cámara para detectar microsueños."
  - "Sin este permiso no podemos activar esta función."

#### RF-31 — Ofrecer un panel central de permisos y gestión de contactos
- **Cómo funciona:** Una pantalla de ajustes muestra el estado de cada permiso y permite agregar, editar y eliminar contactos.
- **Datos:** Los mismos de RF-04 y RF-30.
- **Errores:**
  - "No se pudieron cargar tus permisos. Intenta de nuevo."
  - "No se pudo eliminar el contacto. Intenta de nuevo."
  - "Debes mantener al menos un contacto de emergencia."

#### RF-32 — Si el usuario revoca un permiso, reducir la función y avisarle, sin fallar en silencio
- **Cómo funciona:** La app revisa el estado del permiso al abrirse y al usar la función. Si fue revocado, muestra un aviso y sigue en modo reducido (por ejemplo, alertas sin ubicación) en lugar de fallar en silencio.
- **Datos:**
  - estado del permiso: `enum` (concedido, denegado)
- **Errores:**
  - "Desactivaste el permiso de [ubicación / cámara / sensores]. Esta función funcionará de forma limitada."
  - "Las alertas se enviarán sin tu ubicación. Actívala de nuevo en ajustes."

#### RF-33 — Borrar las ubicaciones de "Acompáñame" una vez confirmada la llegada segura
- **Cómo funciona:** Al confirmar la llegada segura, se borran del servidor y del celular las ubicaciones guardadas del trayecto.
- **Datos:**
  - ubicaciones del trayecto: `List` (se eliminan al confirmar)
- **Errores:**
  - "Llegada confirmada. Tus ubicaciones del trayecto fueron eliminadas."
  - "No se pudieron borrar tus ubicaciones del trayecto. Se reintentará."

#### RF-34 — Indicar que la app no reemplaza los servicios de emergencia oficiales
- **Cómo funciona:** Un aviso visible, al registrarse y en ajustes, dice que Rondó no reemplaza a los servicios de emergencia oficiales. Se pide aceptarlo para continuar.
- **Datos:**
  - aviso aceptado: `bool`
  - fecha de aceptación: `DateTime`
- **Errores:**
  - "Rondó no reemplaza los servicios de emergencia oficiales. En una emergencia, llama al 123."
  - "Debes aceptar este aviso para continuar."

---

## Cambios respecto al PDF

| Fecha | Dónde | Cambio |
|---|---|---|
| 2026-10-04 | Sección 3 | Las subsecciones se renumeraron de 4.x a 3.x para que coincidan con su sección. |
| 2026-10-04 | Sección 3 | Se fija el trato de **tú** en todos los textos de la app. |
| 2026-10-04 | RF-20 | Se agrega `unidades por toma: int`. La dosis queda como texto descriptivo, y el error "La dosis debe ser un número mayor a cero" pasa a referirse a las unidades por toma. |
| 2026-10-04 | RF-21 | Se define la fórmula completa de unidades por día y días restantes, que antes no se podía calcular con los datos de RF-20. |
| 2026-10-04 | RF-23 | El contacto de emergencia de la ficha se elige de los contactos de RF-04 en vez de escribirse otra vez. |
