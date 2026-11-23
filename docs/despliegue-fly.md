# Desplegar el backend en Fly.io (paso a paso)

> **Todavía no se ha desplegado nada.** Crear la cuenta de Fly.io tiene costo (pago por uso) y requiere **tu autorización**. Los precios se verificaron el 23-nov-2026 con la página de precios de Fly.io y fuentes secundarias; confírmalos en [fly.io/pricing](https://fly.io/pricing).

## 1. Qué incluye el repositorio

| Archivo | Para qué |
|---|---|
| `fly.toml` (raíz) | Configuración de la app: región `iad`, 1 máquina siempre encendida, HTTPS, chequeo `/healthz`, migraciones automáticas |
| `backend/Dockerfile` | Imagen de producción. Se construye **desde la raíz** porque incluye `db/migrations` |
| `.dockerignore` | Excluye la app móvil, la documentación y los archivos locales |
| `.github/workflows/ci.yml` | Pruebas del backend (con PostgreSQL) y de la app en cada cambio |
| `.github/workflows/deploy-fly.yml` | Despliegue **manual** a Fly.io tras pasar las pruebas |

### Decisiones de configuración y por qué

- **Una sola máquina** (`--ha=false`, `min_machines_running = 1`). Las sesiones en vivo están en la memoria del servidor; con dos máquinas, una reconexión podría llegar a la otra y la sesión se perdería. Por defecto, Fly crea dos máquinas en el primer despliegue; `--ha=false` lo evita.
- **Sin apagado automático** (`auto_stop_machines = "off"`). El proxy de Fly no cierra WebSockets inactivos, pero el apagado automático sí cortaría las sesiones de los usuarios.
- **`shared-cpu-2x` con 1 GB:** margen holgado para Node y unas 200 sesiones simultáneas (límite `hard_limit = 250`). Hay que medirlo con carga real.
- **`kill_timeout = 30s`:** al desplegar, el servidor cierra las sesiones de forma ordenada y guarda el uso.
- **Migraciones en `release_command`:** se aplican en una máquina temporal antes de actualizar. Si fallan, el despliegue se cancela y sigue la versión anterior.
- **Purga de retención dentro del servidor** (`PURGE_INTERVAL_HOURS=6`). No hace falta un cron externo.
- **Región `iad` (Virginia):** conviene crear el proyecto de Supabase en `us-east-1` para que la base de datos quede cerca.

⚠️ **Un despliegue reinicia la máquina y corta las sesiones en vivo de ese momento.** La app intenta reconectar, pero como la sesión vivía en memoria, el usuario tendrá que iniciar una nueva. **Despliega fuera del horario de los servicios** (por ejemplo, no el domingo por la mañana).

## 1.1 Crear las cuentas (lo haces tú, unos 15 minutos)

Estas cuentas exigen tu correo, aceptar términos y (en Fly.io) una tarjeta. Por eso las creas tú.

**Supabase** ([supabase.com/dashboard](https://supabase.com/dashboard)):
1. Regístrate y crea una organización a nombre de tu empresa.
2. **New project:** nombre `faithbridge`, región **East US (North Virginia)** (`us-east-1`), contraseña de base de datos larga guardada en tu gestor de contraseñas.
3. Plan: empieza en Free para configurar; pasa a **Pro (~USD 25/mes)** antes de lanzar (el plan Free pausa los proyectos inactivos).
4. **SQL Editor:** pega y ejecuta `db/migrations/0001_core.sql` y luego `0002_church_mode.sql`. También puedes dejar que Fly las aplique al desplegar.
5. **Authentication → Email:** activa OTP y pon `{{ .Token }}` en la plantilla «Magic Link».
6. Copia en `backend/.env.production`:
   - `DATABASE_URL`: Connect → **Session pooler**;
   - `SUPABASE_URL`;
   - `SUPABASE_JWKS_URL` = `SUPABASE_URL` + `/auth/v1/.well-known/jwks.json`;
   - `SUPABASE_SERVICE_ROLE_KEY`;
   - `DATABASE_CA_CERT`: la **ruta** del certificado descargado (Database Settings → SSL Configuration → Download certificate).

**Fly.io** ([fly.io/app/sign-up](https://fly.io/app/sign-up)):
1. Regístrate (mejor con una organización a nombre de tu empresa) y añade la tarjeta.
2. En **Billing**, configura un límite o alerta de gasto.
3. Instala flyctl (§2).

**Luego, en tu computadora** (desde la raíz del repositorio):

```bash
cp backend/.env.example backend/.env.production   # complétalo; NO se sube a git
bash scripts/fly-setup.sh backend/.env.production
```

El script:
- crea la app si no existe;
- carga los secretos sin mostrarlos (`fly secrets import`);
- despliega con una sola máquina y comprueba `/healthz`.

Si `REVENUECAT_WEBHOOK_AUTH` está vacío, lo genera. Para desplegar necesitas también las claves de Deepgram, Anthropic y RevenueCat (ver `cuentas-proveedores.md`); sin ellas, el servidor se niega a arrancar en producción. **Antes de desplegar, verifica las claves:** `cd backend && npm run check:providers -- .env.production`.

## 2. Instalar flyctl y crear la app

```bash
# macOS:   brew install flyctl
# Linux:   curl -L https://fly.io/install.sh | sh
# Windows: pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
fly auth signup        # o: fly auth login
fly apps create faithbridge-api    # si el nombre está tomado, elige otro y cámbialo en fly.toml
```

## 3. Secretos (nunca en `fly.toml` ni en el repositorio)

```bash
fly secrets set \
  DATABASE_URL='postgresql://postgres.<ref>:<clave>@aws-0-us-east-1.pooler.supabase.com:5432/postgres' \
  DATABASE_CA_CERT="$(cat prod-ca-2021.crt)" \
  SUPABASE_URL='https://<ref>.supabase.co' \
  SUPABASE_JWKS_URL='https://<ref>.supabase.co/auth/v1/.well-known/jwks.json' \
  SUPABASE_SERVICE_ROLE_KEY='...' \
  DEEPGRAM_API_KEY='...' \
  ANTHROPIC_API_KEY='...' \
  REVENUECAT_SECRET_API_KEY='...' \
  REVENUECAT_WEBHOOK_AUTH="$(openssl rand -hex 32)" \
  ALERT_WEBHOOK_URL='...'      # opcional
```

- **`DATABASE_URL`:** usa la cadena del **Session pooler** de Supabase (puerto 5432; Project Settings → Database → Connection string). Funciona por IPv4 e IPv6.
- **`DATABASE_CA_CERT`:** el certificado raíz de Supabase (Database Settings → SSL Configuration → Download certificate). Con él, la conexión usa TLS con verificación estricta del servidor. La verificación nunca se desactiva.
- **`REVENUECAT_WEBHOOK_AUTH`:** guarda el valor generado; hay que ponerlo igual en RevenueCat. Para verlo de nuevo, ejecuta `fly ssh console -C 'printenv REVENUECAT_WEBHOOK_AUTH'`.
- Las variables no secretas (modelo, keyterms, entorno) ya están en `[env]` de `fly.toml`.

## 4. Primer despliegue

```bash
# Desde la RAÍZ del repositorio:
fly deploy --ha=false
fly status                 # 1 máquina en estado "started"
fly logs                   # comprobar que no hay errores de configuración
curl https://faithbridge-api.fly.dev/healthz
# → {"ok":true,"env":"production","stt":"deepgram","translation":"anthropic"}
```

Si falta algún secreto obligatorio, el servidor **se niega a arrancar** y `fly logs` muestra qué variable falta (nunca muestra su valor).

## 5. Dominio propio (recomendado)

```bash
fly certs add api.tudominio.com
# Crea en tu DNS el registro que indica el comando (CNAME a faithbridge-api.fly.dev, o A/AAAA)
fly certs show api.tudominio.com   # esperar a "Issued"
```

Después:
- compila la app con `--dart-define=API_BASE_URL=https://api.tudominio.com`;
- en RevenueCat, configura el webhook `https://api.tudominio.com/webhooks/revenuecat` con Authorization = `REVENUECAT_WEBHOOK_AUTH`.

Usar un dominio propio permite cambiar de proveedor sin publicar una nueva versión de la app.

## 6. Despliegues desde GitHub (opcional)

1. `fly tokens create deploy -x 999999h` → copia el token.
2. GitHub → Settings → Secrets and variables → Actions → **New repository secret**: `FLY_API_TOKEN`.
3. Opcional: GitHub → Settings → Environments → `production` → exige aprobación manual.
4. Actions → **Deploy backend (Fly.io)** → *Run workflow*. Primero se ejecutan las pruebas; si pasan, se despliega.

## 7. Operación diaria

| Tarea | Comando |
|---|---|
| Ver registros | `fly logs` |
| Estado y salud | `fly status` · `fly checks list` |
| Pausar sesiones nuevas (interruptor) | `fly ssh console` y luego en Supabase: `update app_config set value='false' where key='live_sessions_enabled';` |
| Volver a la versión anterior | `fly releases` · `fly deploy --image <imagen-anterior> --ha=false` |
| Cambiar un secreto | `fly secrets set CLAVE=valor` (reinicia la máquina; hazlo fuera del horario de los servicios) |
| Purga manual | `fly ssh console -C 'node dist/scripts/purge.js'` |
| Límite de gasto de Fly | Dashboard → Billing |

## 8. Costo estimado de Fly.io

| Concepto | Estimado |
|---|---|
| 1 máquina `shared-cpu-2x`, 1 GB, siempre encendida | ~USD 6.89/mes (USD 4.39 del preajuste de 512 MB + 0.5 GB extra a ~USD 5/GB; precios del 1-oct-2026) |
| Tráfico de salida en Norteamérica | ~USD 0.02/GB. El audio que sale hacia Deepgram ocupa ~1.9 MB/min: ~USD 0.012 por usuario con 300 min |
| IPv4 compartida | Sin costo. Una IPv4 dedicada cuesta extra y no hace falta |
| Certificado TLS del dominio | Incluido para los primeros certificados (verificar) |

## 9. Limitaciones conocidas

- **Una sola máquina:** sin redundancia. Si Fly reinicia la máquina, las sesiones en curso se cortan; la app avisa y el usuario puede iniciar otra.
- Escalar a varias máquinas requiere que cada reconexión llegue a la máquina original (por ejemplo, con la cabecera `fly-force-instance-id`) o un estado compartido. **Pendiente**, no hace falta para el MVP.
- **No se ha probado en Fly.io real.** Lo que sí se verificó en este entorno:
  - el comando de migración del despliegue sobre una copia de la estructura de la imagen (también al repetirlo sin cambios pendientes);
  - la purga;
  - la sintaxis de `fly.toml` y de los flujos de GitHub Actions.

  La imagen Docker **no** se construyó, porque no había servicio Docker disponible.
