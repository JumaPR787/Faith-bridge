# Micrófono en segundo plano: limitaciones reales

## Comportamiento actual de FaithBridge (ambas plataformas)

- El micrófono **solo** se activa al tocar «Iniciar».
- Si la app pasa a segundo plano (otra app, botón de inicio o pantalla bloqueada), la sesión **se pausa**: se detiene la captura y el servidor deja de contar minutos. Al volver aparece «Reanudar», y **reanudar requiere tocar el botón**.
- Si una llamada u otra app de audio interrumpe la captura, el sistema la pausa. La app avisa y espera a que el usuario toque «Reanudar».
- Por eso la opción **«Mantener la pantalla encendida»** está activada por defecto durante la sesión.

## Por qué no se graba en segundo plano (todavía)

### iOS

- Para captar audio en segundo plano hay que declarar `UIBackgroundModes: audio` en `Info.plist`. Mientras la app capta audio en segundo plano, iOS muestra un indicador (barra o isla de color).
- Apple revisa que el modo de fondo «audio» esté justificado. Debe ser una función clara para el usuario.
- Una llamada telefónica **siempre** interrumpe la sesión de audio. La app no puede impedirlo.
- Esta versión **no** declara el modo de fondo. Hacerlo es posible en el futuro, pero requiere probarlo en dispositivos y justificarlo ante la revisión de Apple.

### Android

- En Android 14 y posteriores, captar el micrófono con la app en segundo plano exige un **servicio en primer plano** con tipo `microphone`. Eso implica:
  - el permiso `FOREGROUND_SERVICE_MICROPHONE`;
  - una notificación permanente;
  - iniciar el servicio mientras la app está visible.
- Google Play pide declarar y justificar el tipo de servicio en primer plano en la Play Console.
- Algunos fabricantes cierran apps en segundo plano para ahorrar batería.
- Esta versión **no** declara servicio en primer plano.

## Recomendación

Para el MVP, mantener la pantalla encendida es lo más fiable y lo más fácil de aprobar. Si las pruebas con usuarios muestran que el segundo plano es imprescindible, implementarlo como una fase propia y probarlo en dispositivos reales:

- iOS: `UIBackgroundModes audio`;
- Android: un servicio en primer plano con notificación.
