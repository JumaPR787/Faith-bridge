# FaithBridge

App para Android e iPhone que **muestra por escrito lo que se dice en un servicio cristiano** y, si se desea, **lo traduce entre inglés y español** en vivo. También traduce después una transcripción guardada o un texto pegado.

> La transcripción y la traducción son automáticas: pueden tener errores y llegan con unos segundos de retraso. Requiere internet. No hay modo sin conexión.

## Estado en una línea

El **MVP del modo personal está implementado y probado con proveedores simulados**: 55 pruebas del backend y 13 de la app pasan, y el análisis estático está limpio. **Aún no se ha probado con servicios reales ni en teléfonos**, y nada se ha publicado. Detalle completo: [`docs/estado.md`](docs/estado.md).

## Estructura

```
app/        App Flutter (Android + iOS)
  lib/core/       configuración por entorno, textos es/en, tema accesible
  lib/domain/     modelos y almacén de subtítulos (lógica pura)
  lib/data/       micrófono, conexión en vivo, API, auth (Supabase), compras (RevenueCat)
  lib/features/   pantallas
  test/           pruebas unitarias y de interfaz
backend/    Servidor Node.js 22 + TypeScript (Fastify + WebSocket)
  src/providers/  adaptadores sustituibles: voz (Deepgram | simulado), traducción (Claude | simulado)
  src/live/       protocolo, segmentación, sesión en vivo
  src/billing/    RevenueCat: cálculo de beneficios, webhook, sincronización
  src/quota/      cuotas medidas en servidor
  src/ops/        interruptor, límite de gasto, alertas, anti-abuso
  test/           pruebas unitarias e integración (PostgreSQL real)
  .env.example    variables sin secretos
db/migrations/  esquema PostgreSQL/Supabase con reglas de acceso (RLS)
scripts/        modelo de costos reproducible
docs/           documentación (en español)
```

## Inicio rápido (local, sin cuentas)

```bash
# Backend (requiere PostgreSQL)
cd backend && npm ci
createdb faithbridge
DATABASE_URL=postgres://localhost/faithbridge npm run db:migrate -- --dev-shim
APP_ENV=development DATABASE_URL=postgres://localhost/faithbridge \
  SUPABASE_JWT_SECRET=un-secreto-local-de-al-menos-16 \
  STT_PROVIDER=fake TRANSLATION_PROVIDER=fake npm run dev
npm test                       # pruebas (ver TEST_DATABASE_ADMIN_URL en docs)

# App
cd app && flutter pub get && flutter analyze && flutter test
```

Con `STT_PROVIDER=fake` y `TRANSLATION_PROVIDER=fake` el servidor **simula** la voz y la traducción. El texto sale marcado `[SIMULATED]` y la app muestra el aviso «DATOS SIMULADOS». En staging y producción el servidor se niega a arrancar con proveedores simulados.

## Documentación

| Documento | Contenido |
|---|---|
| [docs/estado.md](docs/estado.md) | Terminado, pendiente, bloqueado y **decisiones que necesito de ti** |
| [docs/arquitectura.md](docs/arquitectura.md) | Arquitectura, protocolo en vivo, datos, fases y entornos |
| [docs/costos.md](docs/costos.md) | Tarifas con fuentes y fechas, rentabilidad y controles de gasto |
| [docs/costos-escenarios.md](docs/costos-escenarios.md) | Escenarios de 10/100/1,000 clientes, pruebas e iglesia (generado) |
| [docs/instalacion-despliegue.md](docs/instalacion-despliegue.md) | Instalación y despliegue paso a paso |
| [docs/despliegue-fly.md](docs/despliegue-fly.md) | Despliegue del backend en Fly.io, secretos, dominio, operación y costos |
| [docs/suscripciones.md](docs/suscripciones.md) | Productos, prueba de 7 días, RevenueCat, casos de sandbox |
| [docs/publicacion.md](docs/publicacion.md) | Checklist de Google Play y App Store, firma, ficha, declaraciones de datos |
| [docs/privacidad-proveedores.md](docs/privacidad-proveedores.md) | Qué datos van a cada proveedor y qué se verificó |
| [docs/legal/](docs/legal/) | Borradores de política de privacidad y términos (**para revisión legal**) |
| [docs/pruebas-dispositivos.md](docs/pruebas-dispositivos.md) | Procedimiento de pruebas reales y métricas |
| [docs/limitaciones-microfono.md](docs/limitaciones-microfono.md) | Micrófono en segundo plano en iOS y Android |
| [docs/modo-iglesia.md](docs/modo-iglesia.md) | Opciones de audio de consola y diseño de la fase 2 |

## Seguridad en pocas palabras

- La app no contiene claves privadas.
- El servidor valida cuotas, pagos y acceso.
- Las tablas tienen reglas de acceso por usuario y organización.
- Los registros nunca incluyen audio ni texto transcrito.
- El audio no se guarda y las transcripciones solo se guardan si el usuario lo elige.
