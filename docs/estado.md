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
| Publicar | Prueba cerrada de Google (12 testers × 14 días), TestFlight y revisión |

## ❓ Decisiones que necesito de ti

1. **Modelo de traducción** (`TRANSLATION_MODEL`). Con `claude-opus-5-5`, el valor por defecto actual, el plan de USD 5.99 **pierde** ~USD 13.65 por usuario con uso completo. Con `claude-haiku-5-5` **gana** ~USD 2.40. Recomiendo probar Haiku 5.5 con el procedimiento de fidelidad y decidir con datos. Ver `costos.md` §4.
2. **Identificadores definitivos** (`com.faithbridge.app` es provisional) y la verificación de la marca «FaithBridge».
3. **Tipo de cuenta de Google Play:** personal (exige 12 testers × 14 días) u organización (requiere D-U-N-S).
4. **Hosting del backend** y dominio (`api.tudominio.com`).
5. **Autorización** para crear cuentas y gastar en: Supabase Pro, Deepgram, Anthropic, RevenueCat, Apple, Google y SMTP.
6. ¿Activar los **keyterms** de Deepgram (glosario en el reconocimiento)? Tienen costo extra por minuto; hay que medir si mejoran los resultados.
7. **Plan de texto:** hoy, traducir texto pegado cuesta 1 minuto de cuota por cada 1,000 caracteres. ¿Te parece bien?
