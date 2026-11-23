# Modo iglesia: entrada de audio de una consola (investigación)

> **No se asume compatibilidad con ninguna mezcladora ni adaptador en particular.** Cada combinación debe probarse.

## Objetivo

El organizador envía **una** fuente de audio autorizada (la mezcla del predicador) al backend. Los asistentes reciben solo texto, sin usar su micrófono.

## Opciones de conexión (de la más recomendada a la menos)

| Opción | Cómo | Ventajas | Riesgos y pruebas necesarias |
|---|---|---|---|
| **A. Interfaz de audio USB «class compliant» → teléfono o tableta del organizador** | Salida auxiliar o de grabación de la consola (línea) → interfaz USB → USB-C (Android o iPhone 15+) o adaptador Lightning-USB 3 (iPhone anterior) | Sin computadora; la interfaz convierte la señal de línea | El dispositivo debe reconocer la interfaz como USB Audio Class. Hay que alimentarla (algunas interfaces necesitan hub con energía) y confirmar que la app capte la entrada USB y no el micrófono interno. **Probar cada modelo** |
| **B. Consola con salida USB → computadora** | Muchas consolas digitales (y algunas analógicas) envían audio por USB a una computadora | Calidad digital directa | Requiere una app de escritorio o web para el organizador (no está en el alcance actual). Cada consola tiene drivers propios |
| **C. Cable de salida de línea → adaptador TRRS → entrada de micrófono del teléfono** | Salida auxiliar → atenuador o adaptador TRS-a-TRRS | Barato | Niveles incompatibles (línea vs. micrófono: puede saturar), ruido de tierra; muchos teléfonos ya no tienen conector de 3.5 mm. **No recomendado** sin atenuador |
| **D. Micrófono del teléfono cerca de un altavoz de monitoreo** | Igual que el modo personal | Funciona hoy | Eco, ruido y calidad variable |

## Recomendaciones técnicas

- Usar una **salida auxiliar dedicada** (envío post-fader solo con el púlpito), no la mezcla principal con música. Mejora el reconocimiento.
- Nivel: señal de línea **bien atenuada**, sin picos.
- El backend ya acepta PCM 16 kHz mono. La interfaz puede grabar a 44.1 o 48 kHz; el paquete `record` convierte a 16 kHz.
- Probar sesiones de 90 minutos con el dispositivo conectado a la corriente.

## Diseño de software previsto (fase 2)

1. **Organizador** (miembro `owner` o `admin` de la organización):
   - crea una `church_session`;
   - declara su autorización (`audio_authorization_attested_at`);
   - elige un idioma destino;
   - la app muestra un **código** de 6–8 caracteres y un **QR** (se guarda solo su hash, con vencimiento de 6 h).
2. El organizador transmite por el mismo WebSocket `/v1/live`, con `mode=church`. Una `LiveSession` con N suscriptores.
3. **Asistentes:** `GET /v1/church/join` con el código → token de oyente de corta duración → WebSocket de **solo lectura** (no se envía audio). Sin cuenta obligatoria.
4. Límites:
   - `max_listeners` (30 en el plan inicial);
   - el plan Iglesia descuenta **minutos de transmisión** una sola vez;
   - `church_usage` registra por separado asistentes pico, segundos-oyente y bytes enviados.
5. Privacidad:
   - sesiones privadas por defecto;
   - nunca listadas;
   - aislamiento por organización con RLS (ya probado);
   - el código caduca;
   - el organizador puede cerrar la sesión.
6. **Habilitar el plan Iglesia solo después** de medir costos reales (ver `costos.md` §5).
