# Privacidad: qué datos van a terceros y qué se verificó

> Este documento sirve para que la política de privacidad no prometa algo que los proveedores no pueden cumplir.
> **Las condiciones de los proveedores cambian.** Hay que releer sus contratos (DPA, términos comerciales) antes de publicar.

## Flujo de datos

| Dato | Desde | Hacia | Para qué | ¿Se guarda? |
|---|---|---|---|---|
| Audio del micrófono (PCM) y términos del glosario (keyterms) | Teléfono | Backend FaithBridge → **Deepgram** | Convertir voz en texto (los términos mejoran el reconocimiento de palabras cristianas) | **Backend: no** (solo cuenta los bytes). Deepgram: ver abajo |
| Texto transcrito (segmentos + 3 de contexto) | Backend | **Anthropic** (API de Claude) | Traducir | Backend: solo si el usuario activa «Guardar». Anthropic: ver abajo |
| Correo, id de usuario | Teléfono | **Supabase** (Auth + PostgreSQL) | Cuenta | Sí, hasta eliminar la cuenta |
| Transcripciones guardadas, glosario | Backend | Supabase | Historial | Sí, hasta borrarlas o hasta que venza el plazo de retención (365 días por defecto) |
| Compras, id de usuario | Tienda / teléfono | **RevenueCat** | Suscripción | Sí. Al eliminar la cuenta se pide su borrado (`DELETE /subscribers`) |
| Registros (logs) | Backend | Proveedor de hosting | Operación | Solo metadatos (tipo de evento, códigos de error). **Nunca audio ni texto** (redacción en `app.ts` y en los mensajes de error) |

## Verificaciones por proveedor

### Deepgram

- La documentación oficial describe el **Model Improvement Program** y el parámetro `mip_opt_out=true`, que excluye la solicitud del programa.
- Según su documentación, con la exclusión los datos se conservan solo el tiempo necesario para procesarlos. El backend **siempre** envía `mip_opt_out=true`.
- Precio: el registro de cambios de Deepgram del 5-mar-2026 indica que excluirse no afecta las tarifas de pago por uso. Una fuente más antigua decía lo contrario; **confírmalo** en la cuenta.
- Fuente: [developers.deepgram.com — Model Improvement Partnership Program](https://developers.deepgram.com/docs/the-deepgram-model-improvement-partnership-program). El acceso directo estaba bloqueado en este entorno; se usó el resumen de búsqueda.

### Anthropic (API comercial)

- Según los términos comerciales de Anthropic, los datos de la API **no** se usan para entrenar modelos por defecto.
- Anthropic conserva las entradas y salidas de la API durante un periodo limitado (por seguridad y abuso).
- Existe un acuerdo de **retención cero (ZDR)** para organizaciones elegibles, que hay que solicitar.
- **Verifica el plazo vigente** en la política de privacidad y los términos comerciales de Anthropic antes de redactar la política final.

### Supabase

- Es la base de datos principal: los datos se guardan en la región que elijas, cifrados en reposo según su documentación.
- Firma su DPA si aplica.

### RevenueCat

- Guarda el historial de compras y el `appUserID`, que es el id de Supabase y **no** el correo.
- Recibe los recibos de las tiendas.

## Qué NO hacemos (y la app lo dice)

- No guardamos audio.
- No usamos el contenido para entrenar modelos. `profiles.training_consent` existe y vale `false` por defecto, pero **ningún flujo lo usa**. Si algún día se quisiera usar el contenido, haría falta un consentimiento separado y explícito.
- No hay analítica de terceros, publicidad ni seguimiento.
- No hay directorios públicos de sesiones ni de iglesias.

## Retención y eliminación

| Elemento | Plazo |
|---|---|
| Audio | No se conserva (solo en memoria mientras se transmite) |
| Transcripciones guardadas | Hasta que el usuario las borre, o 30/90/365 días (configurable; 365 por defecto). Purga diaria con `npm run db:purge` |
| Texto en memoria del servidor | Se borra al terminar la sesión (`segments.clear()`) |
| Cuenta | Eliminación inmediata desde la app. Las copias de seguridad de Supabase rotan según su plan (verificar el plazo y declararlo) |
| Registro de eliminación | Solo el hash SHA-256 del id y la fecha (`account_deletions`), como prueba de cumplimiento |
| Webhooks | 90 días |

## Modo iglesia (fase 2)

- El organizador debe declarar que tiene **autorización para transmitir y procesar el audio** (`organizations.audio_authorization_attested_at`).
- Las leyes sobre grabación y procesamiento de voz cambian según el estado y el país. Por ejemplo, algunos estados de EE. UU. exigen consentimiento de todas las partes para grabar conversaciones privadas. Un sermón público puede tratarse de otra forma.
- **Hay que revisar las reglas aplicables con un abogado** y avisar a los asistentes (por ejemplo, con un aviso en el templo o en la pantalla).
