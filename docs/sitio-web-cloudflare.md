# Sitio web en Cloudflare Pages

> **Decidido: Cloudflare Pages.** Todavía no se ha publicado nada: la cuenta de Cloudflare la creas tú (es gratuita) y el sitio **no se publicará mientras los textos legales sean borradores**.
> Límites del plan gratuito según la documentación oficial (23-nov-2026): 500 compilaciones al mes, 100 dominios propios por proyecto, 20,000 archivos y peticiones a archivos estáticos **gratuitas e ilimitadas**. El sitio usa 7 archivos y no consume compilaciones de Cloudflare (se compila en GitHub Actions).

## 1. Qué incluye el repositorio

| Archivo | Para qué |
|---|---|
| `website/pages/*.md` | Inicio, eliminación de cuenta, soporte, 404 (español e inglés) |
| `docs/legal/*.md` | Privacidad y términos (fuente única: se convierten en páginas del sitio) |
| `website/static/_headers` | Cabeceras de seguridad: CSP sin scripts, HSTS, sin marcos, sin acceso a cámara ni micrófono |
| `scripts/build_website.py` | Genera `website/public/`. **Se niega a generar el sitio** si quedan campos `[por completar]` o la palabra BORRADOR |
| `.github/workflows/deploy-website.yml` | Despliegue **manual**: compila (con el control de borradores) y publica con Wrangler |

El sitio no tiene JavaScript, cookies, analítica ni formularios. Por eso no hace falta un aviso de cookies.

## 2. Crear la cuenta y el proyecto (lo haces tú)

1. Regístrate en [dash.cloudflare.com](https://dash.cloudflare.com/sign-up) con el correo de la empresa y activa la verificación en dos pasos.
2. **Recomendado: lleva tu dominio a Cloudflare.**
   - *Add a site* → tu dominio → plan Free → cambia los *nameservers* en tu registrador por los que te indique Cloudflare.
   - Así gestionas en un solo lugar el DNS del sitio, de `api.` (Fly.io) y de los registros de correo (Resend, correo de trabajo).
   - Según la documentación de Cloudflare, para usar el dominio raíz (`tudominio.com`, sin `www`) en Pages, el dominio debe estar en Cloudflare. Verifícalo al configurarlo.
3. Crea el proyecto, una sola vez. Puedes hacerlo desde *Workers & Pages → Create → Pages → Direct Upload*, con el nombre **`faithbridge-web`**, o con:
   ```bash
   npx wrangler pages project create faithbridge-web --production-branch=main
   ```

## 3. Conectar GitHub Actions

1. **Token de API:** Cloudflare → *My Profile → API Tokens → Create Token → Custom*. Permiso **Account → Cloudflare Pages → Edit**, limitado a tu cuenta.
2. Copia tu **Account ID** (aparece en la página principal de *Workers & Pages*).
3. En GitHub → *Settings → Secrets and variables → Actions*:
   - **Secrets:** `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID`.
   - **Variables:**
     - `COMPANY_NAME` (nombre legal exacto, igual que en el D-U-N-S);
     - `SUPPORT_EMAIL` (por ejemplo `soporte@tudominio.com`);
     - `DELETION_DAYS` y `BACKUP_DAYS` (los plazos reales que confirme Supabase; 30 por defecto).
4. Opcional: *Settings → Environments → `production`* con aprobación manual. El mismo entorno protege el despliegue del backend.

## 4. Publicar

1. Completa los campos `[…]` de `docs/legal/politica-privacidad.md` y `terminos.md` y **hazlos revisar por un abogado**. Después quita la nota de borrador y la palabra BORRADOR.
2. Comprueba en tu computadora:
   ```bash
   pip install -r website/requirements.txt
   python3 scripts/build_website.py --company "Tu Empresa LLC" --support-email soporte@tudominio.com
   ```
   Si dice «listo para publicar», sigue al paso 3.
3. GitHub → *Actions → Deploy website (Cloudflare Pages) → Run workflow*.
4. Queda publicado en `https://faithbridge-web.pages.dev`.

**Vista previa antes de la revisión legal:** `--allow-draft` genera el sitio con una franja roja «BORRADOR — NO PUBLICAR». El flujo de GitHub **no** usa esa opción, así que nunca publica borradores.

## 5. Dominio propio

En el proyecto `faithbridge-web` → *Custom domains → Set up a custom domain* → `tudominio.com`, y opcionalmente `www.tudominio.com`. Si el DNS está en Cloudflare, los registros se crean solos.

URL finales:

| Uso | URL |
|---|---|
| Sitio (Apple y Google: «sitio web de la organización») | `https://tudominio.com` |
| Política de privacidad (tiendas y app: `PRIVACY_URL`) | `https://tudominio.com/privacidad.html` |
| Términos (tiendas y app: `TERMS_URL`) | `https://tudominio.com/terminos.html` |
| Eliminación de cuenta (Google Play) | `https://tudominio.com/eliminar-cuenta.html` |
| Soporte | `https://tudominio.com/soporte.html` |

## 6. DNS del resto del proyecto (si el dominio está en Cloudflare)

| Registro | Destino | Proxy de Cloudflare |
|---|---|---|
| `tudominio.com`, `www` | Cloudflare Pages (automático) | Activado |
| `api` | `CNAME faithbridge-api.fly.dev` (o los A/AAAA que indique `fly certs add`) | **Desactivado («DNS only», nube gris)**. Fly.io emite su propio certificado, y el proxy de Cloudflare podría cerrar los WebSockets de sesiones largas (verificar sus tiempos de espera vigentes). |
| `mail` (Resend) | SPF, DKIM y DMARC que indique Resend | No aplica (TXT/MX) |
| Correo de trabajo | MX del proveedor (Google Workspace, Microsoft 365, etc.) | No aplica |

## 7. Actualizar el sitio

Edita `website/pages/*.md` o `docs/legal/*.md` → sube el cambio → *Run workflow*.

Al cambiar la política de privacidad, actualiza la fecha y, si el cambio es importante, avisa a los usuarios (lo exige la propia política).
