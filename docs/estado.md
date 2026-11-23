# Estado del proyecto — lista honesta

**Fecha:** 23-nov-2026.

## ✅ Terminado y verificado en este entorno

| Área | Qué | Cómo se verificó |
|---|---|---|
| Backend | Servidor Node 22/TypeScript: autenticación con JWT de Supabase, WebSocket en vivo, segmentación provisional/confirmada con `seq` y tiempos, traducción una vez por segmento con contexto limitado, glosario cristiano y libros bíblicos (solo nombres), marcado `[?]`, defensa contra inyección en el prompt | `tsc` sin errores; **55 pruebas automáticas pasan** (`npm test`) |
| Backend | Cuotas en servidor (un minuto cuenta una vez), prueba de 120 min / plan de 300 min, segunda prueba sin minutos, fin de sesión al agotar sin cargos | Pruebas `live.test.ts` y `billing.test.ts` |
| Backend | Webhook de RevenueCat autenticado e idempotente con reintento; estados trial/active/cancelada/billing_issue/gracia/vencida/reembolsada; transferencias; sincronización tras compra | Pruebas con RevenueCat **simulado** |
| Backend | Reconexión del proveedor de voz con límite de intentos; reanudación del cliente con reenvío de lo faltante; periodo de gracia; pausa sin cobro; una sesión activa por usuario | Pruebas de integración por WebSocket real |
| Backend | Interruptor operativo, límite diario de gasto, alertas al 50/80/100 %, capacidad máxima, límite de inicios por hora, sesiones huérfanas | Pruebas + revisión |
| Backend | Rechazo de arranque en producción con proveedores simulados o configuración insegura | Ejecutado manualmente |
| Backend | Prueba de humo del servidor compilado contra PostgreSQL: sesión completa por WebSocket con transcripción guardada | Ejecutado manualmente (proveedores simulados) |
| Base de datos | Migraciones con RLS: aislamiento por usuario y por organización, tablas operativas inaccesibles, sin listado público, purga por retención | Aplicadas en PostgreSQL 16; pruebas `rls.test.ts` |
| App Flutter | Bienvenida, privacidad y permisos, inicio de sesión por código, inicio (modos), preparación de sesión, subtítulos en vivo, historial, detalle, traducción de texto con estimación previa, planes y prueba, suscripción, ajustes (letra, contraste, tema, pantalla encendida, retención, glosario), ayuda, eliminación de cuenta, modo iglesia «próximamente» | `flutter analyze`: **sin problemas**; **13 pruebas pasan** (`flutter test`), incluida una prueba de interfaz del recorrido en vivo |
| App | Micrófono solo con acción explícita; indicador visible; pausa en segundo plano y ante interrupciones; búfer de audio acotado a 5 s; reanudación de sesión | Pruebas de widget y de conexión con canal simulado |
| Docs | Arquitectura, costos con fuentes, escenarios generados, instalación/despliegue, suscripciones/sandbox, publicación, privacidad de proveedores, borradores legales, pruebas en dispositivos, limitaciones del micrófono, investigación del modo iglesia | — |

## ⏳ Pendiente (no se pudo o no correspondía hacerlo aún)

- **Nada se probó con Deepgram, Anthropic, Supabase ni RevenueCat reales.** Todo el recorrido se probó con proveedores **simulados** (claramente marcados `[SIMULATED]` / `[SIM→xx]`, con un aviso en la app).
  - El adaptador de Deepgram se escribió según su protocolo documentado, pero **no se ha ejecutado** contra el servicio.
  - El de Claude usa el SDK oficial (los tipos se verificaron con el compilador).
- **No se ejecutó la app en ningún teléfono ni emulador.** El permiso de micrófono, la captura PCM, la pantalla encendida, el lector de pantalla, la batería y la latencia están **sin medir**.
- **Compras:** no se probaron en sandbox de las tiendas (no hay cuentas).
- **Ícono, pantalla de inicio y capturas** definitivos.
- **Página web** de eliminación de cuenta (requisito de Google) y publicación de la política y los términos.
- **Varias instancias del backend:** las sesiones viven en memoria; para escalar hace falta afinidad por sesión o un bus compartido.
- **Modo iglesia:** solo están la estructura de datos, las reglas de acceso y el diseño. Faltan rutas, QR, oyentes y plan.
- Textos localizados de `InfoPlist.strings` (hoy el texto del micrófono es bilingüe en un solo texto).

## 🚫 Bloqueado (requiere tu acción o autorización)

| Bloqueo | Qué se necesita |
|---|---|
| Compilar el **AAB de Android** | Android SDK (este entorno bloqueó dl.google.com) y tu clave de subida |
| Compilar el **IPA de iOS** | macOS + Xcode + cuenta de Apple Developer |
| Pruebas reales de voz y traducción | Cuentas y claves de Deepgram y Anthropic (tienen costo) |
| Base de datos y auth reales | Proyecto de Supabase (y SMTP propio para los códigos) |
| Suscripciones reales | Cuentas de Apple Developer (USD 99/año) y Google Play (USD 25), productos y RevenueCat |
| Verificar algunas tarifas | deepgram.com y support.google.com estaban bloqueados desde este entorno; algunas cifras vienen de resultados de búsqueda o de terceros (marcadas en `costos.md`) |
| Publicar | Cuenta de organización (entidad legal + D-U-N-S), TestFlight y revisión de las tiendas |

## ❓ Decisiones que necesito de ti

1. ~~Modelo de traducción~~ → **decidido: `claude-haiku-5-5`** (margen estimado ~USD 2.05 por usuario con uso completo, incluidos los keyterms). Pendiente: validar la fidelidad con predicaciones reales (`pruebas-dispositivos.md` §2).
2. ~~Identificadores~~ → **decidido: `com.faithbridge.app`** en Android e iOS. Pendiente: verificar que la marca «FaithBridge» no infrinja marcas registradas.
3. ~~Tipo de cuenta de Google Play~~ → **decidido: organización** (sin el requisito de 12 testers × 14 días). Pendiente: entidad legal, D-U-N-S y verificación (ver `publicacion.md` §4.1).
4. ~~Hosting del backend~~ → **decidido: Fly.io** (ver `despliegue-fly.md`). Cuentas de Fly.io y Supabase **autorizadas**; debes crearlas tú (correo, términos y tarjeta). Luego ejecuta `scripts/fly-setup.sh` (ver `despliegue-fly.md` §1.1). Pendiente: dominio propio (`api.tudominio.com`).
5. **Cuentas autorizadas:** Fly.io, Supabase, Deepgram, Anthropic y RevenueCat. Las creas tú; guía en `cuentas-proveedores.md` y verificación con `npm run check:providers`. **Pendientes de autorización:** Apple Developer y Google Play (de organización) y un SMTP para los códigos de inicio de sesión.
6. ~~Keyterms de Deepgram~~ → **activados** (glosario en el reconocimiento, con respaldo automático si Deepgram los rechaza). Pendiente: confirmar el precio y medir la mejora en el reconocimiento.
7. ~~Plan de texto~~ → **decidido: 1 minuto por cada 1,000 caracteres** (redondeo hacia arriba; se muestra y se confirma antes de procesar).
