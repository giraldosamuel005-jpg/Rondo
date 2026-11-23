# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users
- **Persona que se cuida (cuenta "para mí")**: adulto mayor, muchas veces con poca práctica con el celular. Usa la app en casa y en la calle, con manos que pueden temblar y vista cansada. Es el usuario más exigente.
- **Cuidador**: familiar o contacto que recibe las alertas, ve el estado y la ubicación de quien cuida y debe actuar rápido.
- Un mismo usuario puede combinar roles. Hablan español de Colombia y se les trata de "tú".

## Product Purpose
Rondó detecta emergencias personales (hoy: caídas) con los sensores del celular y avisa a los contactos con la ubicación, por SMS y dentro de la app. Además guarda una ficha médica consultable con un QR por quien atienda la emergencia y ayuda a controlar medicamentos. Es el proyecto de la materia Computación Móvil; se entrega como APK/demo, no se publica en Play Store.

## Positioning
Alguien pendiente, siempre. La app funciona con o sin internet (SMS con enlace a Google Maps, alarma local) y la ficha médica se abre sin instalar nada.

## Operating Context
- Solo Android (Flutter). Backend Firebase: Auth por SMS, Firestore, Hosting para la ficha del QR.
- La alerta de caída tiene cuenta regresiva de 10 s con alarma, y debe poder leerse y cancelarse al instante.
- Alcance recortado el 2026-10-25: sin accidentes de tránsito, microsueños, geocercas, Acompáñame ni cancelar con PIN/huella/voz. Desmayo (RF-07) en duda.

## Capabilities and Constraints
- Requerimientos en `docs/requisitos.md` (fuente de verdad). Textos de error tal cual.
- Trato de "tú" en toda la app.
- Coral solo para errores; ámbar solo para alerta de emergencia (regla de producto, se conserva aunque cambie el aspecto).
- El usuario está aprendiendo Flutter: el código debe quedar claro y comentado en español.

## Brand Commitments
- Nombre: Rondó. Lema: "Alguien pendiente, siempre."
- El logo actual (arco abierto con línea de pulso) no es vinculante.

## Evidence on Hand
No hay fotos, testimonios ni cifras reales. No inventar ninguno.

## Product Principles
1. En una emergencia, lo importante se lee y se toca sin pensar.
2. Calma cuando todo está bien; urgencia solo cuando hace falta.
3. Pensada para el adulto mayor primero: texto grande, toques amplios, nada escondido.
4. Honesta: dice lo que la app puede y no puede hacer (no reemplaza al 123).

## Accessibility & Inclusion
Adultos mayores: cuerpo 17, secundarios 13–15, mínimo 12; toques de al menos 48 dp; contraste 4.5:1 en claro y oscuro; respetar el tamaño de texto del sistema hasta 1,3; lector de pantalla con etiquetas.
