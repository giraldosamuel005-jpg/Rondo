# Rondó — Requerimientos funcionales

> Transcripción de `Rondo_Requerimientos_Funcionales.pdf`, con correcciones (ver [Cambios respecto al PDF](#cambios-respecto-al-pdf) al final). Este archivo es la fuente de verdad; si cambian los requerimientos, se edita aquí.

## 1. Descripción del proyecto

Rondó es una app móvil que detecta emergencias personales (caídas y posibles desmayos) con los sensores del celular y avisa automáticamente a los contactos de la persona con su ubicación. Además pone la información médica al alcance de quien atienda la emergencia y ayuda a controlar los medicamentos. Funciona con o sin internet y se adapta a quién la usa: la persona que se cuida (pensada sobre todo para adultos mayores) o su cuidador.

## 2. Perfiles de usuario

| Perfil | Módulos activos |
|---|---|
| Adulto mayor (cuenta "para mí") | Detección de caídas, medicamentos, ficha médica QR, botón "Estoy bien" |
| Cuidador / contacto (cuenta "para cuidar a alguien") | Dashboard de alertas, ubicación, adherencia a medicamentos |

*Los perfiles no son excluyentes: un usuario puede combinar roles.*

*Los perfiles **Conductor** (detección de accidentes y microsueños) y **Persona en ruta de riesgo** (modo "Acompáñame" y geocercas) quedaron **fuera de alcance** el 2026-10-25.*

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
  - "El código es incorrecto. Intenta de nuevo. Te quedan [X] intentos."
  - "Demasiados intentos fallidos. Pide un código nuevo." (máximo 3 intentos por código; se puede pedir otro código cada 30 s)
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
- **Cómo está hecho (2026-11-23):** Con `local_auth`, solo huella o rostro (no el PIN del celular). Funciona así:
  - **Oferta:** al llegar a Inicio por primera vez, si el celular tiene una huella guardada, un cuadro pregunta "¿Entrar con tu huella?". Sale una sola vez. Se puede activar o quitar después en Ajustes → Seguridad → "Entrar con huella".
  - **Activar:** antes de guardar la preferencia se pide la huella una vez, para saber que funciona.
  - **Reingresar:** si está activada, al abrir la app aparece una pantalla que pide la huella sola. Con la huella válida entra a Inicio. Si falla, muestra el mensaje de arriba, se puede reintentar, y el botón "Entrar con mi código SMS" lleva al código y de ahí directo a Inicio, sin repetir el registro.
  - **Cerrar sesión** borra la preferencia: la huella era de esa cuenta.
  - **Límite:** se pide al abrir la app desde cero o después de quitarla de las recientes, no cada vez que vuelve del fondo. Si hay una alerta en curso, primero se muestra la alerta.

#### RF-03 — Al registrarse, elegir si la cuenta es "para mí" o "para cuidar a alguien"
- **Cómo funciona:** Al terminar el registro, la persona elige "para mí" o "para cuidar a alguien". Esto define qué módulos se activan y si se muestra el dashboard de cuidador.
- **Datos:**
  - tipo de cuenta: `enum` (paraMi, cuidador)
  - perfiles activos: `List<enum>` (adultoMayor, cuidador)
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
- **Cómo está hecho (2026-11-09):** La app abre la app de mensajes de la persona con el SMS ya escrito y un código de 6 caracteres que vence en 48 horas. El cuidador escribe el código en Personas → "Tengo un código de invitación". Todavía no hay enlace que lleve a instalar la app. Errores añadidos: "Escribe el código de 6 letras y números que te llegó por SMS.", "La invitación expiró. Pide una nueva." (lo ve el cuidador) y "Esta invitación la creaste tú. Debe usarla tu cuidador en su celular."

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
- **Cómo está hecho (2026-11-24):** Con la ronda activa y el permiso de sensores encendido, la app lee el acelerómetro y el giroscopio unas 50 veces por segundo. Una caída es un golpe de 2,5 g o más seguido de 2,5 s casi sin movimiento (se dejan pasar 1 s de rebotes). Al detectarla arranca sola la alerta de RF-13. Inicio muestra "Detección de caídas activa", o el error si falta el permiso o fallan los sensores (se reintenta cada 30 s).
  - **Con la app cerrada también funciona:** un servicio en primer plano (`ServicioFondo.kt`) mantiene viva la app aunque la quiten de las recientes, con la pantalla apagada y después de reiniciar el celular. Muestra una notificación fija, "Tu ronda está activa". Se apaga al pausar la ronda o cerrar sesión.
  - **Los umbrales son valores típicos, no medidos.** Falta ajustarlos con caídas reales, como pide este requisito.

#### RF-07 — Detectar inactividad prolongada (posible desmayo sin impacto)
- **Cómo funciona:** Si el celular no registra movimiento durante un tiempo prolongado en un momento en que normalmente se movería, se considera un posible desmayo y se inicia la alerta.
- **Datos:**
  - tiempo sin movimiento: `int` (segundos)
  - tiempo máximo permitido: `int` (segundos)
- **Errores:**
  - "La detección de inactividad no está disponible: el celular no está reportando datos de movimiento."
  - "Activa el permiso de sensores de movimiento para usar esta función."

#### RF-08 — Detectar accidentes de tránsito: impacto seguido de una caída anómala de velocidad
> ⛔ **Fuera de alcance** (decisión del 2026-10-25). Se conserva solo como referencia; no se implementa.

- **Cómo funciona:** Se combina un impacto fuerte (acelerómetro) con una caída brusca de velocidad medida por GPS. Un frenazo sin impacto no cuenta como accidente.
- **Datos:**
  - velocidad: `double` (m/s, del GPS)
  - fuerza del impacto: `double` (m/s²)
- **Errores:**
  - "Activa la ubicación para detectar accidentes de tránsito."
  - "No pudimos medir la velocidad. La detección de accidentes está limitada."

#### RF-09 — Reducir falsos positivos: distinguir si cayó el celular o la persona, y descartar ejercicio
- **Cómo funciona:** Antes de lanzar la alerta se revisa el patrón de movimiento. Se descarta si solo cayó el celular y la persona sigue en movimiento, o si el patrón es de ejercicio.
- **Datos:**
  - No pide datos al usuario; usa las lecturas de los sensores.
  - confianza del evento: `double` (0 a 1)
- **Errores:**
  - Proceso interno, no muestra mensaje al usuario.
  - "No se pudo guardar el ajuste de sensibilidad."
- **Cómo está hecho (2026-11-13):** Un golpe no termina en alerta en tres casos, y cada descarte queda en un registro interno con su motivo:
  - **Siguió el movimiento:** después del golpe el celular se mueve (lo recogieron, o la persona siguió andando).
  - **Ejercicio:** hubo 3 o más sacudidas de 1,8 g en los 4 s anteriores (trotar, saltar).
  - **Confianza baja:** la confianza no llega a 0,6. Se calcula con la quietud (45 %), la fuerza del golpe (25 %) y el cambio de postura del celular (30 %).

  No hay ajuste de sensibilidad: ningún requisito lo define, así que el error de arriba no se usa.

#### RF-10 — Aplicar un cooldown por tipo de evento para no repetir alertas
- **Cómo funciona:** Después de un evento de un tipo, se ignoran nuevos eventos del mismo tipo durante un tiempo de espera, para no generar alertas repetidas.
- **Datos:**
  - tipo de evento: `enum`
  - hora del último evento: `DateTime`
  - tiempo de espera: `int` (segundos)
- **Errores:**
  - Proceso interno, no muestra mensaje al usuario. El evento omitido queda en el registro interno.
- **Cómo está hecho (2026-11-13):** Después de una alerta de caída, las caídas detectadas en los 60 s siguientes no abren otra alerta y quedan en el registro interno. Por ahora el único tipo de evento es la caída.

#### RF-11 — Detectar microsueños del conductor con la cámara durante el viaje
> ⛔ **Fuera de alcance** (decisión del 2026-10-25). Se conserva solo como referencia; no se implementa.

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
- **Cómo está hecho (2026-11-24):** Si hay una alerta abierta, "Estoy bien" también les avisa a quienes la recibieron. Sin conexión se muestra el error de arriba y se envía al volver la red. El cuidador recibe una notificación.

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
- **Cómo está hecho (2026-11-24):** La cuenta regresiva va con el reloj del celular y no con la pantalla (`ControlAlerta`): la alerta se envía aunque la pantalla se apague, la persona salga de la app o tenga las animaciones apagadas. Si la app no está a la vista, sale una notificación a pantalla completa que prende la pantalla, aunque el celular esté bloqueado, con los botones "Estoy bien" y "Pedir ayuda". La alerta se puede probar en Ajustes → "Probar la alerta": llega de verdad, pero dice que es una prueba.

#### RF-14 — Permitir cancelar la alerta durante la cuenta regresiva con el botón "Estoy bien"
- **Cómo funciona:** Durante los 10 s se puede cancelar con el botón "Estoy bien". Al cancelar, la alarma se detiene y la alerta queda como cancelada. El botón "Pedir ayuda ahora" hace lo contrario: avisa de inmediato, sin esperar.
- **Datos:**
  - estado de la alerta: `enum` (cancelada, enviada; ver RF-13)
- **Errores:**
  - No muestra errores: el botón siempre está disponible durante la cuenta regresiva.
- *Cancelar con PIN, huella o voz quedó **fuera de alcance** el 2026-10-25.*
- **Cómo está hecho (2026-11-24):** Además del botón durante la cuenta, Inicio tiene "Pedir ayuda", que avisa de una después de confirmar. Cuando la alerta ya salió, "Ya estoy bien, avísales" le manda un SMS a los mismos contactos y se lo muestra a los cuidadores.

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
- **Cómo está hecho (2026-11-24):** Todavía no hay push (necesita el plan Blaze de Firebase), pero el cuidador recibe la alerta con la app cerrada gracias al mismo servicio en primer plano de RF-06. Al enviarse la alerta pasa esto a la vez:
  - **Ubicación:** se empieza a buscar desde que arranca la cuenta. Si el GPS no contesta, va la última conocida. Después de reiniciar el celular, y hasta que se abra la app, Android no deja leerla: la alerta sale sin ella.
  - **SMS** a cada contacto, sin abrir la app de mensajes. La app espera a que Android confirme que salió.
  - **Servidor:** la alerta se sube a `personas/{uid}/alertas` si hay cuidadores vinculados.

  Lo que no salió se reintenta cada 30 s, hasta 10 veces, aunque la persona cierre la pantalla ("No se pudo notificar a [nombre]. Reintentando…"). Al cuidador le suena la alarma y se le abre la pantalla de alerta, también con el celular bloqueado. Si otro cuidador la atiende, o la persona avisa que está bien, se calla sola. En las pruebas con dos emuladores tardó unos 16 s desde el golpe (10 son la cuenta regresiva).

#### RF-16 — Si no hay datos, enviar un SMS con enlace a Google Maps
- **Cómo funciona:** Si el celular no tiene datos, la app envía un SMS a cada contacto con un enlace a Google Maps con la ubicación.
- **Datos:**
  - enlace: `String` (URL de Google Maps con latitud y longitud)
  - celular del contacto: `String`
- **Errores:**
  - "Sin conexión de datos. Enviando alerta por SMS."
  - "No se pudo enviar el SMS. Verifica tu señal y tu saldo."
  - "La app no tiene permiso para enviar SMS. Actívalo en ajustes."
- **Cómo está hecho (2026-11-24):** El SMS no espera a que se caigan los datos: siempre se envía, junto con la alerta al servidor (ver RF-15). Si falta el permiso, la pantalla de la alerta lo dice y deja darlo ahí mismo ("Permitir SMS y reintentar").

#### RF-17 — Si no hay datos ni SMS, activar una alarma sonora local
- **Cómo funciona:** Si tampoco se puede enviar SMS, se activa una alarma sonora local para llamar la atención de las personas cercanas.
- **Datos:**
  - alarma activa: `bool`
- **Errores:**
  - "Sin conexión ni señal. Activando alarma sonora para pedir ayuda cercana."
- **Cómo está hecho (2026-11-24):** La alarma vuelve a sonar cuando no salió ningún SMS y el servidor no confirmó la alerta, y se calla si un reintento logra avisarle a alguien. La pantalla dice la causa real (sin señal o sin permiso) y muestra un botón para llamar al 123.

---

### 3.4 Ubicación

*Toda esta sección quedó fuera de alcance el 2026-10-25. La ubicación se usa dentro de una alerta (RF-15, RF-16) y, desde el 2026-11-24, para los cuidadores si la persona lo activa (RF-26).*

#### RF-18 — Crear y editar geocercas, y avisar cuando la persona entre o salga de ellas
> ⛔ **Fuera de alcance** (decisión del 2026-10-25). Se conserva solo como referencia; no se implementa.

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
> ⛔ **Fuera de alcance** (decisión del 2026-10-25). Se conserva solo como referencia; no se implementa.

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
- **Cómo está hecho (2026-11-13):** A la hora de cada toma el celular muestra una notificación con sonido ("Hora de tu medicamento"), aunque la app esté cerrada o no haya internet. Al tocarla se abre la pantalla de medicamentos, donde la persona marca "Tomé mi dosis" o "No la tomé". Detalles:
  - **Qué se programa:** las tomas de los próximos 7 días, y se vuelve a programar cada vez que cambian los medicamentos, se registra una toma o se abre la app. Una toma ya registrada no suena.
  - **Permiso:** al agregar el primer medicamento, Android pide el permiso de notificaciones. Si la persona dice que no, la pantalla de medicamentos muestra el error de arriba con un botón "Activar notificaciones".
  - **Límite:** la toma no se puede registrar desde la notificación; hay que abrir la app.

#### RF-23 — Crear una ficha médica con alergias, tipo de sangre y contacto de emergencia
- **Cómo funciona:** El usuario llena un formulario con sus datos médicos básicos. La ficha se guarda en el servidor y solo el dueño puede editarla.
- **Datos:**
  - alergias: `List<String>`
  - tipo de sangre: `enum` (A+, A-, B+, B-, AB+, AB-, O+, O-)
  - contacto de emergencia: `String` (ID de uno de los contactos registrados en RF-04; no se escribe de nuevo)
  - enfermedades (opcional): `List<String>`
  - fecha de nacimiento (opcional): `DateTime`; la edad se calcula a partir de ella
  - notas (opcional): `String`, máximo 300 caracteres
  - mostrar medicamentos (opcional): `bool`, desmarcado por defecto; si se marca, la ficha muestra los medicamentos de RF-20, sin copiarlos
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
- **Cómo está hecho (2026-11-10):** El QR abre `https://rondo-fb405.web.app/f/{token}`, una página web de Firebase Hosting (carpeta `ficha_web/`) que se ve en cualquier celular sin instalar nada. La app sube la ficha ya armada a Firestore en `fichas/{token}` y la mantiene al día cuando cambia. Las reglas dejan leer una ficha a quien tenga su token, pero no listarlas. La página tiene botones para llamar al contacto de emergencia y al 123. Error añadido: "No pudimos cargar la ficha." (sin internet), con botón para intentar otra vez.

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
- **Cómo está hecho (2026-11-10):** Crear un código nuevo, retirar el consentimiento de datos médicos o cerrar sesión deja la ficha del token anterior como revocada: se borran sus datos y la página muestra "Este enlace fue revocado por su dueño.". Cada vez que la página muestra la ficha guarda la fecha en `fichas/{token}/consultas`, y la persona ve las últimas en la pantalla de su código QR. Por ahora no se guarda el origen de la consulta.

---

### 3.6 Cuidadores

#### RF-26 — Dashboard del cuidador con estado, ubicación, alertas y adherencia de las personas a su cargo
- **Cómo funciona:** El cuidador ve la lista de personas que lo invitaron y, de cada una, su estado, última ubicación, alertas recientes y adherencia a medicamentos. Solo lee datos que ya existen.
- **Datos:** No pide datos nuevos. Lee: estado (`enum`), última ubicación (`double`, `double`), alertas (`List`), adherencia (`double`, porcentaje).
- **Errores:**
  - "No se pudo cargar la información de [nombre]. Desliza para actualizar."
  - "Aún no tienes personas a tu cargo."
  - "Sin conexión. Mostrando datos de hace [X] minutos."
- **Cómo está hecho (2026-11-24):** El panel muestra estado, última ubicación, alertas y cumplimiento.
  - **Ubicación:** la persona la comparte si lo activa en Contactos → Quién te cuida → "Compartir mi ubicación" (consentimiento aparte, RF-30). Se actualiza cada 5 minutos, con cada "Estoy bien" y cuando el cuidador toca "Actualizar ubicación". Al pausar la ronda o quitar el permiso, se borra del servidor. La de una alerta se ve siempre.
  - **Novedades:** notificación cuando la persona pausa o reanuda su ronda, dice que está bien o marca que no tomó un medicamento.
  - **Parentesco:** el cuidador lo escribe al aceptar la invitación ("Mamá") y queda solo en su celular.
  - **Sin conexión** se muestra "Sin conexión. Mostrando datos de hace [X] minutos." y se sigue viendo lo último.

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
- **Cómo está hecho (2026-11-09):** Firebase con sesión anónima y Firestore. Las reglas de `firestore.rules` solo dejan leer lo que la persona comparte a quien tenga un vínculo activo con ella. La persona corta el vínculo desde Contactos → "Quién te cuida", y también al quitar ese contacto o al cerrar sesión. Se comparte el estado de la ronda, el último "Estoy bien", el cumplimiento de medicamentos, las alertas y, solo si la persona lo activa, su ubicación (RF-26).

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
- **Cómo está hecho (2026-11-24):** Firestore guarda en el celular lo que falta por enviar (alertas, "Estoy bien", estado). Los SMS no necesitan internet. La pantalla de la alerta dice "Sin conexión: a tus cuidadores les llegará en Rondó cuando vuelva el internet.". No hay una base local propia con el campo `enviado`.

#### RF-29 — Sincronizar la cola automáticamente al recuperar la red, sin pérdida ni duplicados
- **Cómo funciona:** Al volver la red, la app envía los eventos pendientes en orden. Cada uno lleva un UUID generado en el celular, así el servidor detecta si ya lo recibió y no lo duplica. Se marcan como enviados solo cuando el servidor confirma.
- **Datos:**
  - ID local: `String` (UUID)
  - enviado: `bool`
  - intentos: `int`
- **Errores:**
  - "No se pudo sincronizar. Se reintentará automáticamente."
  - "Algunos eventos no se pudieron enviar. Revisa tu conexión."
- **Cómo está hecho (2026-11-24):** La cola la sincroniza Firestore al volver la red. Cada alerta lleva un ID creado en el celular, así un reintento no la duplica. Si una escucha del servidor falla, se vuelve a intentar sola (3 s, 6 s, … hasta cada minuto).

---

### 3.8 Privacidad y permisos

#### RF-30 — Pedir consentimiento explícito y por separado para ubicación y datos médicos
- **Cómo funciona:** Cada permiso se solicita por separado, con una explicación de para qué se usa. Sin consentimiento, las funciones que dependen de ese permiso no se activan.
- **Datos:**
  - consentimiento de ubicación y de datos médicos: 2 `bool`
  - fecha de cada consentimiento: `DateTime`
- **Errores:**
  - "Necesitamos tu permiso de ubicación para enviar alertas con tu posición."
  - "Necesitamos tu consentimiento para guardar tus datos médicos."
  - "Sin este permiso no podemos activar esta función."
- **Cómo está hecho (2026-11-24):** Son tres consentimientos separados, cada uno con su fecha: ubicación en una alerta, ubicación para los cuidadores y datos médicos. Al activar la ronda, si faltan permisos, se explica para qué sirven y Android los pide uno por uno; se puede seguir sin ellos.

#### RF-31 — Ofrecer un panel central de permisos y gestión de contactos
- **Cómo funciona:** Una pantalla de ajustes muestra el estado de cada permiso y permite agregar, editar y eliminar contactos.
- **Datos:** Los mismos de RF-04 y RF-30.
- **Errores:**
  - "No se pudieron cargar tus permisos. Intenta de nuevo."
  - "No se pudo eliminar el contacto. Intenta de nuevo."
  - "Debes mantener al menos un contacto de emergencia."
- **Cómo está hecho (2026-11-24):** Tocar un contacto ofrece editarlo o quitarlo. Si cambia el celular de alguien que cuida a la persona, ese vínculo se corta y hay que invitarlo otra vez. No se acepta el propio número ni números que no sean celulares de Colombia. El panel agrega el permiso de notificaciones, que el cuidador también ve.

#### RF-32 — Si el usuario revoca un permiso, reducir la función y avisarle, sin fallar en silencio
- **Cómo funciona:** La app revisa el estado del permiso al abrirse y al usar la función. Si fue revocado, muestra un aviso y sigue en modo reducido (por ejemplo, alertas sin ubicación) en lugar de fallar en silencio.
- **Datos:**
  - estado del permiso: `enum` (concedido, denegado)
- **Errores:**
  - "Desactivaste el permiso de [ubicación / sensores]. Esta función funcionará de forma limitada."
  - "Las alertas se enviarán sin tu ubicación. Actívala de nuevo en ajustes."
- **Cómo está hecho (2026-11-24):** Además del aviso al quitar un permiso, Inicio muestra "Para estar mejor protegido" con lo que hoy haría que una alerta no llegue bien (sin SMS, sin ubicación, sin notificaciones, sin cuidadores). Al tocar cada aviso se llega a donde se arregla.

#### RF-33 — Borrar las ubicaciones de "Acompáñame" una vez confirmada la llegada segura
> ⛔ **Fuera de alcance** (decisión del 2026-10-25). Se conserva solo como referencia; no se implementa.

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
| 2026-10-05 | RF-01 | El error de código incorrecto indica los intentos restantes. Se agrega un límite de 3 intentos por código, con el mensaje "Demasiados intentos fallidos. Pide un código nuevo.", y una espera de 30 s para pedir otro código. |
| 2026-10-06 | RF-03 / RF-34 | El aviso "no reemplaza al 123" se acepta en el paso 1 del registro, junto con el tipo de cuenta y el nombre. Se agrega el mensaje "Escribe tu nombre para continuar." |
| 2026-10-25 | Alcance | **Fuera de alcance:** accidentes de tránsito (RF-08), microsueños (RF-11), geocercas (RF-18), modo "Acompáñame" (RF-19, RF-33) y cancelar la alerta con PIN, huella o voz (RF-14 queda solo con botón). Desaparecen los perfiles Conductor y Persona en ruta de riesgo. RF-09 ya no descarta frenazos y RF-30 ya no pide consentimiento de cámara. RF-07 (desmayo/inactividad) sigue en duda. |
| 2026-11-05 | RF-23 | Se agregan a la ficha, como opcionales, enfermedades, fecha de nacimiento, notas y la opción de mostrar los medicamentos de RF-20. |
| 2026-11-09 | RF-05 / RF-27 | La invitación se envía con un código que el cuidador escribe en la app, y se agregan los errores de código inválido, invitación vencida para el cuidador e invitación propia. |
| 2026-11-10 | RF-24 / RF-25 | La ficha del QR se consulta en una página web pública. Cerrar sesión o retirar el consentimiento también revocan el QR, y se agrega el error "No pudimos cargar la ficha.". |
| 2026-11-10 | RF-15 / RF-16 / RF-17 / RF-26 | Las alertas son reales: SMS automático a los contactos con la ubicación, y la alerta llega en Rondó a los cuidadores vinculados (sin push por ahora). Se agrega el permiso de SMS, con el aviso "Desactivaste el permiso de SMS. Si hay una alerta, solo les llegará a tus cuidadores con Rondó.". |
| 2026-11-13 | RF-06 / RF-09 / RF-10 | La detección de caídas es real, con la app abierta. Se fijan los umbrales iniciales, los tres motivos de descarte y una espera de 60 s entre alertas. El error del ajuste de sensibilidad de RF-09 queda sin uso. |
| 2026-11-13 | RF-22 | La alarma de toma es una notificación del celular que suena a la hora aunque la app esté cerrada. Se programan 7 días y la toma se registra abriendo la app. |
| 2026-11-23 | RF-02 | Reingreso con huella: oferta única al llegar a Inicio, interruptor en Ajustes, pantalla de huella al abrir la app y plan B con el código SMS. |
| 2026-11-24 | RF-06 / RF-13 / RF-15 | La detección de caídas y las alertas funcionan con la app cerrada, la pantalla apagada y después de reiniciar el celular. La cuenta regresiva ya no depende de la pantalla y lo que no sale se reintenta. |
| 2026-11-24 | RF-14 | Se agregan "Pedir ayuda" en Inicio, "Ya estoy bien, avísales" y "Probar la alerta" en Ajustes. |
| 2026-11-24 | RF-16 | Se corrige el SMS de alerta, que fallaba siempre en los Android nuevos con textos con tildes, y se confirma que salió. |
| 2026-11-24 | RF-26 / RF-30 | La persona puede compartir su ubicación con sus cuidadores, con un consentimiento aparte. Sección 3.4: cambia la nota sobre el uso de la ubicación. |
| 2026-11-24 | RF-31 / RF-32 | Se pueden editar contactos, y se agregan el permiso de notificaciones y los avisos de protección en Inicio. |
| 2026-11-24 | RF-24 | La pantalla del QR dice si el código ya se puede escanear. Si la ficha no se pudo subir, lo muestra y lo reintenta cada 15 s (antes no avisaba ni reintentaba). |
