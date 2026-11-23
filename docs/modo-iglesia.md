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

## Implementación (fase 2) — código listo, función APAGADA

> Implementado y probado con proveedores **simulados** (9 pruebas de integración en el backend, 4 en la app). **No se ha probado con audio real, consolas ni teléfonos.** El interruptor `app_config.church_mode_enabled` sigue en `false` y el plan Iglesia no existe aún en las tiendas: no se habilita hasta validar el MVP personal y la rentabilidad.

### Flujo

1. **Organizador** (necesita cuenta y plan **Iglesia** activo):
   - registra su iglesia en «Modo iglesia → Organizar» y **declara la autorización del audio** (casilla obligatoria; se guarda la fecha);
   - agrega miembros por correo (la persona debe tener cuenta) con rol *admin* o *member*;
   - crea una sesión: idioma del predicador, traducción (un idioma destino), máximo de asistentes (≤ 30) y si se guarda la transcripción;
   - la app muestra **una sola vez** el código `XXXX-XXXX` y su **QR**. El servidor guarda solo el hash del código, que vence a las 6 h;
   - toca «Iniciar transmisión». Usa la misma pantalla en vivo que el modo personal, con el número de asistentes conectados.
2. **Asistentes** (sin cuenta y **sin micrófono**):
   - «Unirme con código» (o «¿Tu iglesia te dio un código? Unirme sin cuenta» en la pantalla de inicio de sesión);
   - escriben el código o escanean el QR; la cámara solo se activa al tocar «Escanear»;
   - reciben un **acceso anónimo y temporal** (firmado, válido solo para esa sesión);
   - ven la traducción, o el original y la traducción, con letra ajustable.

### Garantías verificadas por pruebas

| Garantía | Prueba |
|---|---|
| Una transcripción y **una traducción por segmento**, sin importar cuántos oyentes | 3 segmentos → 3 traducciones con 2 oyentes |
| Los minutos se descuentan **una vez** del plan del organizador | `usage_periods` = segundos transmitidos |
| Los oyentes no pueden enviar audio (se ignora y no se cobra) | Audio enviado por un oyente → 0 s |
| Los oyentes no reciben datos de cuota ni de uso | Filtro de eventos |
| Límite de asistentes | 2.º oyente con máximo 1 → `session_full` |
| Código inválido, vencido o terminado: mismo error; límite de intentos por IP | `invalid_code`; `JOIN_ATTEMPTS_PER_MINUTE` |
| Aislamiento: un miembro no transmite ni crea sesiones; un ajeno no ve nada (404) | Pruebas de control de acceso + RLS |
| Accesos de oyente falsificados o tokens de usuario normales no sirven | `unauthorized` |
| Si el organizador se desconecta, los oyentes **esperan**; al volver, reciben de nuevo | `broadcast_interrupted` y luego segmentos |
| Al terminar: los oyentes reciben el fin, el código deja de servir, se registra el uso | `church_usage`: minutos transmitidos y pico de asistentes; `church_session_listeners`: conexiones y bytes |
| La transcripción guardada pertenece a la organización (visible para sus miembros) | `transcripts.org_id` |

### Medición separada (`church_usage`, por organización y periodo)

- `broadcast_seconds`: minutos de transmisión (los que cuentan para la cuota).
- `peak_listeners`: máximo de asistentes simultáneos.
- `listener_seconds` y `egress_bytes`: tiempo total de los oyentes y tráfico enviado.

### Para habilitarlo (cuando corresponda)

1. Validar el MVP personal con servicios reales.
2. Probar en el lugar con la consola y la interfaz de audio de la iglesia (tabla de arriba) y hacer una sesión de 90 minutos con varios oyentes.
3. Crear el producto `fb_church_monthly` (USD 29.99) en ambas tiendas, asociado al entitlement `church` y a la offering `church` en RevenueCat (ver `suscripciones.md` §3). La pantalla «Planes» ya lo muestra **solo cuando el modo iglesia está activado**, con el cambio Personal → Iglesia como mejora de plan (sin duplicar suscripciones).
4. Verificar que `LISTENER_TOKEN_SECRET` esté configurado (Fly secrets).
5. `update public.app_config set value = 'true' where key = 'church_mode_enabled';`

### Limitaciones conocidas

- **Una sola instancia del backend:** las transmisiones viven en memoria, igual que las sesiones personales.
- **El QR solo funciona dentro de la app.** La cámara nativa del teléfono no abre la app (no hay enlaces universales; pendiente).
- Los asistentes necesitan internet; el uso de datos es bajo (~3 KB por minuto de texto).
- Si el servidor se reinicia (por ejemplo, al desplegar), la transmisión se corta y el organizador debe volver a iniciarla.
