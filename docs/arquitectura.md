# Arquitectura y fases

## 1. Visión general

```
┌──────────── Teléfono (Flutter) ────────────┐         ┌──────────── Backend (Node/TS) ─────────────┐        ┌─ Proveedores ─┐
│ Interfaz (features/*)                      │         │ Auth (verifica JWT de Supabase)            │        │               │
│ Controladores (LiveController, Account…)   │  WSS    │ LiveSession: medición + segmentación       │  WSS   │ Deepgram      │
│ Datos: AudioSource → LiveConnection ───────┼────────▶│   ├─ SttProvider (Deepgram | simulado) ────┼───────▶│ (voz→texto)   │
│        ApiClient (HTTPS) ──────────────────┼────────▶│   └─ Translator (Claude | simulado) ───────┼───────▶│ Anthropic     │
│        PurchasesService (RevenueCat SDK)   │         │ Cuotas, beneficios, guardas de gasto       │        │ (traducción)  │
│        AuthGateway (Supabase Auth)         │         │ Webhook RevenueCat (idempotente)           │◀───────│ RevenueCat    │
└────────────────────────────────────────────┘         │ PostgreSQL (Supabase) con RLS              │        └───────────────┘
                                                       └────────────────────────────────────────────┘
```

**Principios aplicados:**

- **Ningún secreto vive en la app.** El teléfono solo tiene:
  - la URL del backend;
  - la clave pública de Supabase;
  - las claves públicas del SDK de RevenueCat.

  Las claves de Deepgram, Anthropic y RevenueCat (secreta) están solo en el servidor.
- **El teléfono no decide nada que cueste dinero.** Cuotas, beneficios y pruebas se calculan en el servidor. RevenueCat valida los recibos con Apple y Google, y el backend consulta su API.
- **El audio pasa por el backend** en lugar de ir directo del teléfono a Deepgram. Así:
  - el servidor mide los segundos reales;
  - corta al agotar la cuota;
  - la clave nunca sale del servidor;
  - la misma tubería sirve para el modo iglesia.

  Deepgram ofrece tokens temporales (`/v1/auth/grant`) si en el futuro se quiere conexión directa. En ese caso habría que mover la medición a otra parte.
- **Adaptadores sustituibles:** `SttProvider` y `Translator` son interfaces. Cambiar de proveedor requiere una clase nueva, no una reescritura.

## 2. ¿Por qué Flutter?

Una sola base de código para Android e iOS, con buen soporte para lo que se necesita:

- audio en streaming (`record`);
- WebSocket;
- compras en las tiendas (`purchases_flutter`);
- Supabase;
- accesibilidad (`Semantics`, escalado de texto).

No se encontró ninguna incompatibilidad que obligue a usar código nativo.

**Una nota técnica:** Flutter 3.50 trasladó Material a un paquete aparte (`material_ui`). El código ya lo usa.

## 3. Flujo de una sesión en vivo (protocolo v1)

1. El usuario toca **Iniciar** → se pide el permiso de micrófono en ese momento → se abre `wss://…/v1/live`.
2. Primer mensaje del cliente: `{type:"start", token, protocol:1, sourceLang, targetLang|null, saveTranscript}`. El token va en el mensaje, no en la URL, para que no quede en registros.
3. El servidor valida en este orden:
   - el token;
   - el interruptor operativo;
   - la capacidad;
   - el presupuesto diario;
   - el límite de inicios;
   - el beneficio y la cuota.

   Si todo está bien, crea `live_sessions`, abre Deepgram y responde `ready`.
4. El cliente envía audio PCM16, 16 kHz, mono, en mensajes binarios. El servidor:
   - cuenta los bytes → segundos → cuota;
   - reenvía a Deepgram;
   - recibe resultados provisionales y definitivos.
5. El **Segmenter** emite:
   - `interim` (provisional, siempre con el `seq` del próximo segmento);
   - `segment` (confirmado: `seq` creciente, `startMs`, `endMs`, texto estable; palabras de baja confianza → `[?]`).
6. Cada segmento confirmado se traduce **una sola vez**, con 2 traducciones simultáneas como máximo y contexto de los 3 anteriores. El servidor emite `translation {seq, status, text}`. Si la traducción llega tarde o desordenada, el cliente la coloca en su `seq`.
7. Cada 10 s el servidor guarda el uso y envía `usage`. A falta de 5 min envía `quota_warning`. Al agotarse la cuota, la sesión termina con `quota_exhausted`, sin cobro extra.
8. Si se corta la red:
   - el cliente reintenta (1, 2, 4, 8 y 16 s) con `resumeSessionId` + `lastSeq`;
   - el servidor reenvía solo lo que faltó;
   - el servidor espera 60 s antes de cerrar la sesión.
9. Mientras no hay conexión, el cliente guarda **como máximo 5 s** de audio y descarta lo más antiguo. Nunca acumula audio sin límite.
10. Si Deepgram se cae, el servidor reintenta con espera y un límite de intentos. Si no lo logra, cierra la sesión con `stt_unavailable`.

## 4. Datos y acceso

- **Migraciones:**
  - `db/migrations/0001_core.sql`: perfiles, beneficios, cuotas, sesiones, transcripciones, glosario, webhooks, operación, RLS y purga.
  - `db/migrations/0002_church_mode.sql`: estructura del modo iglesia.
- **RLS:**
  - cada usuario solo **lee y borra** sus propios datos;
  - las organizaciones solo son visibles para sus miembros;
  - no hay ningún listado público;
  - las tablas operativas (webhooks, configuración, gasto, eliminaciones) no tienen políticas, así que son inaccesibles para usuarios.
- **Escrituras:** el backend escribe con el rol de servicio y valida la propiedad en cada consulta (`where user_id = $1`).
- **Retención:**
  - las transcripciones vencen según `profiles.transcript_retention_days` (365 por defecto, configurable a 30/90/365 desde la app);
  - `npm run db:purge` (diario) borra lo vencido;
  - los webhooks antiguos se borran a los 90 días.

## 5. Modo iglesia (fase 2) — implementado, deshabilitado por interruptor

La arquitectura ya contempla:

- `LiveSession` admite varios suscriptores. Una transcripción y una traducción por fuente se reparten a N asistentes **sin** llamadas extra a la IA.
- Tablas `church_sessions` (código guardado solo como hash, privada por defecto, un idioma destino, máximo de asistentes), `church_session_listeners` y `church_usage`. Esta última cuenta por separado los minutos transmitidos, los asistentes y el tráfico.
- Aislamiento por organización (`is_org_member`), comprobado con pruebas.
- `app_config.church_mode_enabled=false`.

**Implementado:**
- rutas de organizaciones, miembros, sesiones y para unirse;
- WebSocket de oyente de solo lectura (`/v1/church/listen`);
- accesos anónimos firmados;
- `ChurchRegistry`, que reparte una transmisión a N oyentes;
- pantallas de organizador y asistente con QR.

Detalle, garantías probadas y pasos para habilitarlo en [`modo-iglesia.md`](modo-iglesia.md).

## 6. Fases

| Fase | Contenido | Estado |
|---|---|---|
| 1. MVP personal | Micrófono → STT → traducción → subtítulos; cuotas; historial opcional; traducción de texto; suscripción y prueba | Código completo y probado con proveedores simulados; **falta probar con claves reales y en dispositivos** |
| 2. Validación | Pruebas reales (calidad, latencia, costo, batería, 90 min), sandbox de tiendas, decisión de modelo | Pendiente (requiere cuentas) |
| 3. Publicación | Fichas, privacidad, pruebas cerradas, TestFlight | Documentado; pendiente de cuentas |
| 4. Modo iglesia | Organizador/asistentes, QR, plan Iglesia | Código implementado y probado con proveedores simulados; **apagado**. Falta el producto del plan Iglesia en las tiendas y las pruebas en el lugar |

## 7. Entornos

| Variable | Desarrollo | Pruebas automáticas | Staging/Producción |
|---|---|---|---|
| `APP_ENV` | development | test | staging / production |
| Proveedores | `fake` o reales | `fake` | **reales obligatorios** (el arranque falla si no) |
| Verificación de JWT | secreto HS256 | secreto HS256 | JWKS de Supabase (obligatorio) |
| App | `--dart-define=APP_ENV=development` | — | `APP_ENV=production`, `API_BASE_URL` con https (obligatorio) |
