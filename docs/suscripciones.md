# Suscripciones, prueba gratuita y sandbox

## 1. Diseño

- **Compras:** solo con las compras oficiales de cada tienda (StoreKit en iOS y Google Play Billing en Android), a través del SDK de **RevenueCat**. La app **nunca** pide tarjetas.
- **Fuente de verdad:** el backend, que consulta el API de RevenueCat (`GET /v1/subscribers/{id}`).
  - Lo hace tras cada webhook y tras cada compra o restauración (`POST /v1/subscription/sync`).
  - El resultado se guarda en `entitlements`.
  - Como siempre se recalcula desde el estado completo, el orden de los webhooks no importa.
- **Webhook:** autenticado con secreto compartido (comparación en tiempo constante) e idempotente por `event.id`. Si algo falla responde 500, para que RevenueCat reintente.
- **Identidad:** el `appUserID` de RevenueCat es el id de usuario de Supabase. Así el beneficio se sincroniza entre dispositivos de la misma cuenta.

### ¿Por qué RevenueCat?

Ahorra implementar la validación de recibos de Apple (App Store Server API) y de Google (Play Developer API), las notificaciones del servidor de ambas tiendas, la elegibilidad de pruebas y la restauración.

**Costo:** gratis hasta USD 2,500 de ingreso mensual rastreado; después, 1 %.

**Dependencias:**
- el SDK `purchases_flutter` en la app;
- una cuenta de RevenueCat;
- su disponibilidad. Si RevenueCat falla, `/v1/subscription/sync` responde 502 y el acceso existente no cambia.

**Alternativa sin RevenueCat:** integrar `in_app_purchase` y validar en el servidor con las API de cada tienda. Son más semanas de trabajo; se puede migrar después, porque el backend aísla esta parte en `billing/`.

## 2. Estados que maneja el servidor

| Estado | Acceso | Cuándo |
|---|---|---|
| `trial` | Sí, 120 min | Prueba introductoria vigente |
| `active` | Sí, 300 min por periodo | Pagado y se renovará |
| `cancelled_active` | Sí, hasta fin del periodo | Canceló, pero el periodo sigue pagado |
| `billing_issue` | Sí, hasta el vencimiento | Falló el cobro |
| `grace` | Sí (sin minutos nuevos) | Periodo de gracia de la tienda |
| `expired` | No | Venció |
| `refunded` | No | Reembolso: el acceso se quita de inmediato |

Reglas adicionales:

- **Prueba agotada:** el servidor solo detiene el uso; **no** hace nada que adelante el cobro. La tienda cobra al terminar los 7 días.
- **Prueba duplicada:**
  - Apple permite una oferta introductoria por grupo de suscripción y por Apple ID;
  - Google aplica la elegibilidad de «nuevo cliente» por cuenta de Google;
  - además, el servidor **no da minutos de prueba por segunda vez a la misma cuenta** de FaithBridge (`trialAlreadyUsed`).
- **Sandbox:** `SANDBOX_PURCHASES=allow` es necesario porque **Apple revisa la app con compras de sandbox** incluso en la versión de producción. Cada compra queda marcada como `is_sandbox`.

## 3. Configurar productos (requiere tus cuentas)

### App Store Connect

1. Crea la app con el Bundle ID definitivo `com.faithbridge.app`.
2. Firma el acuerdo **Paid Apps Agreement** y completa los datos bancarios y fiscales.
3. Ve a **Monetización → Suscripciones → Grupo** «FaithBridge Personal» → producto `fb_personal_monthly`, duración 1 mes, precio USD 5.99. La tienda genera los precios locales.
4. **Oferta introductoria:** «Gratis», duración 1 semana, para nuevos suscriptores.
5. Añade nombre y descripción localizados (es/en) y la captura de revisión.
6. Inscríbete en el **App Store Small Business Program** para pagar el 15 % de comisión.

### Google Play Console

1. Crea la app con el applicationId `com.faithbridge.app`.
2. Ve a **Monetizar → Suscripciones** → `fb_personal_monthly` → plan base mensual de renovación automática, USD 5.99.
3. **Oferta:** prueba gratuita de 7 días, elegibilidad «Adquisición de clientes nuevos».
4. Configura la cuenta de servicio para RevenueCat (Play Developer API) y las notificaciones en tiempo real (Pub/Sub), siguiendo la guía de RevenueCat.

### RevenueCat

1. Crea un proyecto y conecta las apps de iOS y Android (credenciales de cada tienda).
2. **Entitlement:** `personal`. Más adelante, `church`.
3. **Offering:** `default`, con el paquete `$rc_monthly` asociado a `fb_personal_monthly` en ambas tiendas.
4. **Integraciones → Webhooks:**
   - URL: `https://api.tudominio.com/webhooks/revenuecat`;
   - Authorization: el valor de `REVENUECAT_WEBHOOK_AUTH`.
5. Copia la **Secret API key (v1)** → backend, y las **Public SDK keys** (Apple y Google) → app.

## 4. Pruebas en sandbox (procedimiento)

| # | Caso | Pasos | Esperado |
|---|---|---|---|
| 1 | Prueba y elegibilidad | Usuario nuevo de sandbox → Planes | Se muestra el texto de la prueba con el precio localizado de la tienda |
| 2 | Inicio de prueba | Comenzar prueba | `status=trial`, 120 min en la app y en `entitlements` |
| 3 | No elegible | Mismo Apple ID o cuenta de Google tras la prueba | **No** se muestra la oferta gratuita; aparece solo el precio |
| 4 | Agotar la prueba | `update usage_periods set used_seconds=quota_seconds` | La sesión no inicia (`quota_exhausted`); no hay cobro anticipado; la app muestra la fecha del primer cobro |
| 5 | Conversión | Esperar el fin de la prueba (en sandbox dura minutos) | Webhook `RENEWAL` → `active`, periodo nuevo de 300 min |
| 6 | Cancelación | Cancelar en la tienda | `cancelled_active`, acceso hasta fin del periodo |
| 7 | Vencimiento | Esperar el vencimiento | `expired`, sin acceso |
| 8 | Reembolso | Apple: solicitar reembolso en sandbox. Google: reembolsar desde la Play Console | `refunded`, sin acceso inmediato |
| 9 | Fallo de pago | Google: tarjeta de prueba «rechazada» | `billing_issue` → `grace` → `expired` |
| 10 | Restaurar | Reinstalar → Restaurar compras | Acceso recuperado |
| 11 | Otro dispositivo | Misma cuenta de FaithBridge en otro teléfono | Mismo beneficio y misma cuota |
| 12 | Webhook duplicado | Reenviar un evento desde RevenueCat | `duplicate: true`, sin cambios |

Las pruebas automáticas (`backend/test/billing.test.ts`) ya cubren los casos 2, 4, 5, 7, 8, 11 y 12, la transferencia y el anti-abuso, con un RevenueCat simulado. **Las tiendas reales no se han probado.**
