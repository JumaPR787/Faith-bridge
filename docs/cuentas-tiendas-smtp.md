# Cuentas de Apple, Google Play y correo SMTP

> **Autorizado por el dueño del producto el 23-nov-2026.** Estas cuentas las creas tú: requieren tu identidad, la de la empresa, aceptar acuerdos legales y pagar. Requisitos verificados el 23-nov-2026; confírmalos al registrarte.

## 0. Orden recomendado (hay dependencias)

```
1. Entidad legal (LLC) + EIN ─┐
2. Dominio (tudominio.com) ───┼─► 3. Correo de trabajo @tudominio.com
                              │   4. Sitio web público (website/)
                              └─► 5. D-U-N-S (gratis; ~5 días hábiles, a veces más)
                                       ├─► 6. Apple Developer (organización)
                                       └─► 7. Google Play (organización)
   8. SMTP (Resend) ◄── requiere el dominio (registros DNS)
```

**Empieza hoy por la LLC, el dominio y el D-U-N-S:** son lo que más tarda.

## 1. Dominio, correo y sitio web (requisitos de Apple y Google)

Apple exige para las organizaciones:
- un **sitio web público y funcional** en un dominio de la organización;
- que el correo de la cuenta pertenezca a ese dominio;
- que la persona que se inscribe tenga **autoridad legal** para firmar por la empresa.

Google también muestra el sitio y el correo en la ficha, y pide una **página web para solicitar la eliminación de la cuenta**.

1. Compra un dominio (por ejemplo `faithbridge.app` o el de tu empresa). Verifica que esté disponible y que no choque con marcas.
2. Crea un correo de trabajo, por ejemplo `soporte@tudominio.com` o `tu.nombre@tudominio.com`, con Google Workspace, Microsoft 365, Zoho u otro.
3. **Sitio web:** el repositorio incluye `website/`, con inicio, privacidad, términos, **eliminación de cuenta** y soporte, en español e inglés.
   ```bash
   pip install markdown
   python3 scripts/build_website.py --company "Tu Empresa LLC" --support-email soporte@tudominio.com \
       --deletion-days 30 --backup-days 30
   # → website/public/ (HTML estático)
   ```
   - El script **se niega a generar el sitio** mientras `docs/legal/*.md` tenga campos `[por completar]` o la marca BORRADOR. Así no se publican textos sin revisión legal.
   - Para una vista previa: `--allow-draft`, que muestra una franja roja «BORRADOR — NO PUBLICAR».
   - **Alojamiento: Cloudflare Pages** (decidido; plan gratuito). Ver [`sitio-web-cloudflare.md`](sitio-web-cloudflare.md).
   - URL a usar en la app y en las tiendas: `https://tudominio.com/privacidad.html`, `/terminos.html` y `/eliminar-cuenta.html`.

## 2. D-U-N-S

1. Busca primero si tu empresa ya tiene uno: [developer.apple.com/support/D-U-N-S](https://developer.apple.com/support/D-U-N-S/). Apple tiene su propio buscador.
2. Si no tiene, solicítalo **gratis** desde ese mismo enlace. Apple indica hasta 5 días hábiles para recibirlo y hasta 2 días hábiles más para que Apple reciba los datos de Dun & Bradstreet.
3. El **nombre legal y la dirección** deben coincidir exactamente con el registro de la LLC. No se aceptan nombres comerciales (DBA).

## 3. Apple Developer Program (organización)

1. Crea un Apple Account con el **correo del dominio** y activa la **verificación en dos pasos**.
2. Inscríbete en [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/) como **Organization**. Necesitas:
   - el D-U-N-S;
   - el sitio web;
   - tus documentos de registro;
   - USD 99 al año.
3. Apple puede llamarte para verificar. Algunos desarrolladores reportan esperas de semanas; si pasan más de 2 semanas, contacta al soporte de Apple.
4. Cuando te aprueben:
   - **Agreements, Tax, and Banking:** firma el **Paid Apps Agreement** y completa los datos fiscales (formulario W-9) y bancarios. **Sin esto no funcionan las suscripciones.**
   - Inscríbete en el **App Store Small Business Program** para pagar el 15 % de comisión en lugar del 30 %.
   - **Identifiers:** registra el Bundle ID `com.faithbridge.app` con la capacidad In-App Purchase.
   - **App Store Connect:** crea la app y el producto `fb_personal_monthly` con la prueba de 7 días (ver `suscripciones.md` §3).
   - Crea la **App Store Connect API key / In-App Purchase key** que pide RevenueCat y súbela a RevenueCat.
5. Invita a TestFlight a tus testers internos.

## 4. Google Play Console (organización)

Sigue `publicacion.md` §4.1. En resumen:
1. Crea un **perfil de pagos de organización** con el EIN y la cuenta bancaria de la empresa.
2. Regístrate en [play.google.com/console](https://play.google.com/console/signup) como **Organización**, con el D-U-N-S, el sitio web, el correo y el teléfono. Pago único de USD 25.
3. Completa la verificación de identidad.
4. Crea la app (`com.faithbridge.app`) y la suscripción `fb_personal_monthly`, con la oferta de prueba de 7 días para clientes nuevos.
5. En Google Cloud, crea la **cuenta de servicio** y las **notificaciones en tiempo real (Pub/Sub)** para RevenueCat, siguiendo su guía.
6. En «Política de la app → Eliminación de cuenta», indica la URL `https://tudominio.com/eliminar-cuenta.html`.

## 5. SMTP para los códigos de inicio de sesión

**Por qué:** el correo integrado de Supabase tiene límites muy bajos y no sirve para producción. Con un SMTP propio, Supabase envía los códigos desde tu dominio.

**Recomendación: [Resend](https://resend.com/pricing)**, con guía oficial de integración con Supabase.

| Proveedor | Plan gratuito (según fuentes de nov-2026, verificar) | Primer plan de pago |
|---|---|---|
| **Resend** | 3,000 correos al mes, **máximo 100 al día** | ~USD 20 al mes (50,000 correos) |
| Postmark | 100 correos al mes (solo para pruebas) | ~USD 15 al mes |
| Brevo | 300 al día | Variable |
| Amazon SES | Sin nivel gratuito permanente | Pago por uso |

Cada inicio de sesión nuevo envía un correo; los usuarios que ya iniciaron sesión no reciben más. Con 100 al día, el plan gratuito sirve para las pruebas cerradas. **Antes del lanzamiento público, pasa al plan de pago.**

Pasos:
1. Crea la cuenta en Resend y añade tu dominio. Para envío es mejor un subdominio, como `mail.tudominio.com`.
2. **DNS:** crea los registros **SPF, DKIM y DMARC** que indica Resend. Sin ellos los códigos acaban en spam. Espera a que el dominio aparezca como «Verified».
3. Crea una **API key** con permiso solo de envío.
4. **Supabase → Authentication → SMTP Settings → Enable custom SMTP:**
   - Host `smtp.resend.com`, puerto `465`, usuario `resend`, contraseña = la API key;
   - Remitente: `FaithBridge <no-reply@mail.tudominio.com>`.
5. **Supabase → Authentication → Rate Limits:** ajusta el límite de correos por hora a tu plan. Mantén un límite razonable contra el abuso.
6. **Plantilla «Magic Link»:** incluye el código `{{ .Token }}`. Agrega un texto bilingüe, por ejemplo: «Tu código de FaithBridge es {{ .Token }} / Your FaithBridge code is {{ .Token }}».
7. **Prueba:** inicia sesión desde la app y comprueba que el código llega a la bandeja de entrada y no a spam (Gmail, Outlook, iCloud).

La clave de Resend **solo** va en Supabase. El backend y la app no la usan.

## 6. Checklist

- [ ] LLC registrada + EIN
- [ ] Dominio + correo de trabajo
- [ ] Textos legales revisados por un abogado → `build_website.py` sin `--allow-draft` → sitio publicado
- [ ] D-U-N-S recibido (nombre y dirección iguales que en la LLC)
- [ ] Apple Developer (organización) aprobado + Paid Apps Agreement + Small Business Program
- [ ] Google Play (organización) verificado + perfil de pagos
- [ ] Resend: dominio verificado (SPF/DKIM/DMARC) + SMTP en Supabase + plantilla con `{{ .Token }}`
- [ ] Productos de suscripción en ambas tiendas y conectados a RevenueCat
