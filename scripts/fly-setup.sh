#!/usr/bin/env bash
# Configura y despliega el backend de FaithBridge en Fly.io.
# Uso (desde la raíz del repositorio, en TU computadora):
#   1. cp backend/.env.example backend/.env.production   y completa los valores
#   2. bash scripts/fly-setup.sh backend/.env.production
# Los secretos se cargan con «fly secrets import» (por stdin): no se imprimen
# ni quedan en el historial de la terminal. Nunca subas .env.production a git.
set -euo pipefail

ENV_FILE="${1:-backend/.env.production}"
APP="$(sed -n 's/^app = "\(.*\)".*/\1/p' fly.toml)"
SECRET_KEYS=(DATABASE_URL DATABASE_CA_CERT SUPABASE_URL SUPABASE_JWKS_URL SUPABASE_SERVICE_ROLE_KEY
  DEEPGRAM_API_KEY ANTHROPIC_API_KEY REVENUECAT_SECRET_API_KEY REVENUECAT_WEBHOOK_AUTH ALERT_WEBHOOK_URL)
REQUIRED=(DATABASE_URL SUPABASE_URL SUPABASE_JWKS_URL DEEPGRAM_API_KEY ANTHROPIC_API_KEY
  REVENUECAT_SECRET_API_KEY REVENUECAT_WEBHOOK_AUTH)

command -v fly >/dev/null || { echo "Instala flyctl: https://fly.io/docs/flyctl/install/"; exit 1; }
[ -f fly.toml ] || { echo "Ejecuta este script desde la raíz del repositorio."; exit 1; }
[ -f "$ENV_FILE" ] || { echo "No existe $ENV_FILE (copia backend/.env.example y complétalo)."; exit 1; }
if git ls-files --error-unmatch "$ENV_FILE" >/dev/null 2>&1; then
  echo "ERROR: $ENV_FILE está versionado en git. Quítalo del repositorio antes de continuar."; exit 1
fi

fly auth whoami >/dev/null 2>&1 || fly auth login

# Lee el archivo sin ejecutarlo (no usa «source»).
declare -A VALS=()
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# || "$line" != *=* ]] && continue
  k="${line%%=*}"; v="${line#*=}"; v="${v%%[[:space:]]#*}"
  k="$(echo "$k" | tr -d '[:space:]')"
  VALS["$k"]="$v"
done < "$ENV_FILE"

# Certificado de la base de datos: se acepta la ruta de un archivo .crt/.pem.
if [ -n "${VALS[DATABASE_CA_CERT]:-}" ] && [ -f "${VALS[DATABASE_CA_CERT]}" ]; then
  VALS[DATABASE_CA_CERT]="$(cat "${VALS[DATABASE_CA_CERT]}")"
fi
# Secreto del webhook: se genera si está vacío (anótalo para RevenueCat).
if [ -z "${VALS[REVENUECAT_WEBHOOK_AUTH]:-}" ]; then
  VALS[REVENUECAT_WEBHOOK_AUTH]="$(openssl rand -hex 32)"
  echo "Se generó REVENUECAT_WEBHOOK_AUTH. Para verlo después: fly ssh console -C 'printenv REVENUECAT_WEBHOOK_AUTH'"
fi

missing=()
for k in "${REQUIRED[@]}"; do [ -n "${VALS[$k]:-}" ] || missing+=("$k"); done
if [ ${#missing[@]} -gt 0 ]; then echo "Faltan valores obligatorios: ${missing[*]}"; exit 1; fi

if ! fly apps list --json | grep -q "\"Name\": *\"$APP\""; then
  echo "Creando la app $APP…"
  fly apps create "$APP"
fi

echo "Cargando secretos (los valores no se muestran)…"
{
  for k in "${SECRET_KEYS[@]}"; do
    v="${VALS[$k]:-}"
    [ -z "$v" ] && continue
    if [[ "$v" == *$'\n'* ]]; then printf '%s="""%s"""\n' "$k" "$v"; else printf '%s=%s\n' "$k" "$v"; fi
  done
} | fly secrets import --app "$APP" --stage

echo "Desplegando (una sola máquina; aplica migraciones antes de actualizar)…"
fly deploy --ha=false --app "$APP"

echo "Comprobando /healthz…"
curl -fsS "https://$APP.fly.dev/healthz" && echo && echo "Listo. Siguiente: dominio propio (docs/despliegue-fly.md §5)."
