# Instalación y despliegue (paso a paso)

> Nada de esto se ha hecho todavía en cuentas reales. Crear cuentas y contratar servicios requiere **tu autorización**, porque algunos cobran.

## 0. Requisitos

| Herramienta | Para qué |
|---|---|
| Node.js 22+ | Backend |
| PostgreSQL 15+ o un proyecto de Supabase | Base de datos y autenticación |
| Flutter 3.50+ (Dart 3.14) | App |
| Android Studio + Android SDK | Compilar y firmar Android |
| macOS + Xcode 26+ | Compilar y firmar iOS (no se puede en Linux) |

## 1. Desarrollo local sin cuentas (proveedores simulados)

```bash
# Base de datos local
createdb faithbridge
cd backend && npm ci
DATABASE_URL=postgres://localhost/faithbridge npm run db:migrate -- --dev-shim   # el shim emula Supabase SOLO en local

# Servidor con proveedores SIMULADOS (el texto aparece marcado como [SIMULADO])
APP_ENV=development DATABASE_URL=postgres://localhost/faithbridge \
SUPABASE_JWT_SECRET=un-secreto-local-de-al-menos-16 \
STT_PROVIDER=fake TRANSLATION_PROVIDER=fake npm run dev

# Pruebas automáticas (necesitan PostgreSQL; por defecto usan postgres://postgres@localhost:54329/postgres)
TEST_DATABASE_ADMIN_URL=postgres://postgres@localhost:5432/postgres npm test
```

App:

```bash
cd app
flutter pub get
flutter analyze && flutter test
```

## 2. Supabase (base de datos + inicio de sesión)

1. Crea un proyecto en supabase.com. Elige una región en EE. UU. y apunta cuál es, porque se declara en la política de privacidad.
2. **SQL Editor:** ejecuta en orden `db/migrations/0001_core.sql` y `0002_church_mode.sql`.
   - **No** ejecutes `db/dev/`, que es solo para local.
   - Otra opción: `DATABASE_URL=<cadena del pooler> npm run db:migrate`.
3. **Authentication → Providers → Email:**
   - activa el inicio sin contraseña (OTP);
   - en **Email Templates**, en «Magic Link», incluye el código `{{ .Token }}` para que llegue un código de 6 dígitos.
4. **Authentication → SMTP:** configura un SMTP propio, porque el integrado tiene límites muy bajos. Esto tiene costo y requiere tu autorización.
5. Copia estos valores:
   - **Project URL** → `SUPABASE_URL` (backend y app);
   - **Publishable key** → `SUPABASE_PUBLISHABLE_KEY` (app);
   - **JWKS URL**: `https://<proyecto>.supabase.co/auth/v1/.well-known/jwks.json` → `SUPABASE_JWKS_URL` (backend);
   - **Service role key** → `SUPABASE_SERVICE_ROLE_KEY` (solo backend; se usa para borrar cuentas).

## 3. Deepgram (voz → texto)

1. Crea una cuenta. Incluye un crédito inicial; verifica el monto vigente.
2. Crea una API key con permiso de miembro. Ponla **solo** en el servidor: `DEEPGRAM_API_KEY`.
3. Configura un límite o una alerta de gasto en la consola.
4. Revisa y acepta las condiciones de privacidad. El backend envía `mip_opt_out=true` (ver `privacidad-proveedores.md`).

## 4. Anthropic (traducción)

1. Crea una organización en console.anthropic.com y una API key → `ANTHROPIC_API_KEY`, solo en el servidor.
2. Fija un **límite de gasto mensual** en la consola.
3. Decide `TRANSLATION_MODEL` (ver `costos.md` §4).

## 5. RevenueCat y tiendas

Sigue [`suscripciones.md`](suscripciones.md). Resultado:

- `REVENUECAT_SECRET_API_KEY` y `REVENUECAT_WEBHOOK_AUTH` (backend);
- `REVENUECAT_APPLE_KEY` y `REVENUECAT_GOOGLE_KEY`, que son claves **públicas** del SDK (app).

## 6. Desplegar el backend

Necesitas cualquier servicio que ejecute contenedores Docker y admita WebSocket, por ejemplo:

- Fly.io;
- Render;
- Railway;
- Google Cloud Run (con sesiones largas configuradas);
- un VPS.

```bash
cd backend
docker build -t faithbridge-backend .
# Variables: ver .env.example (todas las de producción son obligatorias; el arranque falla si falta alguna)
docker run -p 8080:8080 --env-file .env faithbridge-backend
```

Además:

- **HTTPS/WSS obligatorio**, con un dominio propio (por ejemplo `api.tudominio.com`).
- **Tiempo de espera de inactividad del balanceador** de al menos 120 s, con WebSocket habilitado. Las sesiones duran hasta 3 h.
- **Tarea diaria:** `npm run db:purge` (retención). Ejecútala con el cron del proveedor.
- **Migraciones:** `npm run db:migrate` desde el repositorio. La imagen Docker no incluye `db/`.
- **Una sola instancia al principio.** Las sesiones activas viven en memoria; la reanudación debe llegar a la misma instancia. Para escalar a varias instancias hay que usar «sticky sessions» por `sessionId` o un bus compartido (pendiente).
- **Webhook en RevenueCat:** `https://api.tudominio.com/webhooks/revenuecat`, con la cabecera Authorization igual a `REVENUECAT_WEBHOOK_AUTH`.
- Comprueba que el servidor responde: `GET https://api.tudominio.com/healthz`.

## 7. Compilar la app

```bash
cd app
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://api.tudominio.com \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=REVENUECAT_GOOGLE_KEY=goog_... \
  --dart-define=REVENUECAT_APPLE_KEY=appl_... \
  --dart-define=PRIVACY_URL=https://tudominio.com/privacidad \
  --dart-define=TERMS_URL=https://tudominio.com/terminos \
  --dart-define=SUPPORT_EMAIL=soporte@tudominio.com
# iOS (en macOS): flutter build ipa --release <mismos --dart-define>
```

La firma de cada plataforma está en [`publicacion.md`](publicacion.md).
