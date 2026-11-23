# Crear las cuentas de Deepgram, Anthropic y RevenueCat

> **Autorizado por el dueño del producto el 23-nov-2026.** Las cuentas las creas tú: requieren tu correo, aceptar los términos y, en las de pago, una tarjeta. **No compartas las claves por chat ni las subas a git:** van solo en `backend/.env.production` (ignorado por git) y en los secretos de Fly.io.

## 1. Deepgram (voz → texto)

1. Regístrate en [console.deepgram.com](https://console.deepgram.com/signup), preferiblemente con el correo de la empresa. Las cuentas nuevas reciben un crédito inicial; verifica el monto vigente.
2. Crea un proyecto `FaithBridge` → **API Keys → Create a New API Key**:
   - nombre: `faithbridge-backend-prod`;
   - permiso: **Member**;
   - sin vencimiento (o con rotación periódica).
3. Copia la clave en `DEEPGRAM_API_KEY`. **Solo se muestra una vez.**
4. **Billing:** añade la tarjeta cuando se acabe el crédito y configura alertas de uso y un límite si está disponible.
5. Revisa los términos de privacidad. El backend siempre envía `mip_opt_out=true` (no participar en el programa de mejora de modelos).
6. Para pruebas, crea una segunda clave separada (`faithbridge-staging`). Así puedes revocarla sin afectar producción.

## 2. Anthropic (traducción con Claude)

1. Regístrate en [platform.claude.com](https://platform.claude.com) y crea una **organización** a nombre de tu empresa.
2. **Billing:** compra créditos o añade la tarjeta, y fija un **límite de gasto mensual** (por ejemplo, USD 25 al principio).
3. **API Keys → Create Key:**
   - nombre: `faithbridge-backend-prod`;
   - en un *workspace* propio de FaithBridge si lo usas, para separar el gasto.
4. Copia la clave en `ANTHROPIC_API_KEY`.
5. Verifica que el modelo `claude-haiku-5-5` esté disponible en tu cuenta.
6. Revisa los términos comerciales y el plazo de retención de datos de la API. Si lo necesitas, solicita **retención cero (ZDR)**. Ver `privacidad-proveedores.md`.

## 3. RevenueCat (suscripciones)

1. Regístrate en [app.revenuecat.com](https://app.revenuecat.com/signup). Es gratis hasta USD 2,500 de ingreso mensual rastreado; luego cobra el 1 %.
2. Crea el proyecto `FaithBridge`.
3. Las apps de iOS y Android se conectan **después**, cuando existan las cuentas de Apple Developer y Google Play de organización (requieren entidad legal y D-U-N-S). Ver `suscripciones.md` §3.
4. **Project settings → API keys:**
   - **Secret API key (v1)** → `REVENUECAT_SECRET_API_KEY` (backend). No uses la clave pública del SDK aquí.
   - Las claves **públicas** del SDK (`appl_…`, `goog_…`) aparecen al conectar cada app → `REVENUECAT_APPLE_KEY` / `REVENUECAT_GOOGLE_KEY` (app).
5. Crea el entitlement `personal` y la offering `default` (ver `suscripciones.md` §3).
6. El **webhook** se configura después de desplegar en Fly.io:
   - URL: `https://api.tudominio.com/webhooks/revenuecat`;
   - Authorization: el valor de `REVENUECAT_WEBHOOK_AUTH`.

## 4. Verificar las claves antes de desplegar

En tu computadora:

```bash
cd backend
npm ci
npm run check:providers -- .env.production
```

Ejemplo de salida esperada:

```
✅ Deepgram (voz → texto): conexión en 450 ms; keyterms aceptados
✅ Anthropic (traducción): claude-haiku-5-5 en 900 ms · «Buenos días, iglesia. …» · tokens: … · ~USD 0.0002
✅ RevenueCat (suscripciones): clave secreta válida; secreto del webhook OK
```

Cada verificación hace una llamada real mínima:
- Deepgram: 1 s de audio;
- Anthropic: una frase (fracciones de centavo);
- RevenueCat: consulta y borra un cliente técnico (`faithbridge-healthcheck`).

Las claves nunca se imprimen.

Si las tres salen ✅, ejecuta `bash scripts/fly-setup.sh backend/.env.production` (ver `despliegue-fly.md`).

## 5. Buenas prácticas con las claves

- **Separación:** una clave por entorno (producción y pruebas).
- **Rotación:** crea una clave nueva, ejecuta `fly secrets set CLAVE=nueva` y luego revoca la anterior.
- **Si una clave se filtra** (chat, captura, repositorio): revócala de inmediato en la consola del proveedor.
- **Límites de gasto:** actívalos en las tres consolas. Además, el backend tiene su propio límite diario (`app_config.daily_cost_limit_usd`).
