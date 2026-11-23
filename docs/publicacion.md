# Preparación para Google Play y Apple App Store

> **Nada se ha publicado.** No se crearon cuentas ni se firmó nada. No se puede garantizar la aprobación de ninguna tienda.
> Los requisitos se verificaron el 23-nov-2026 con fuentes oficiales cuando fue posible. Revísalos de nuevo antes de enviar.

## 1. Identificadores (definitivos)

| Plataforma | Valor definitivo | Dónde está |
|---|---|---|
| Android `applicationId` | `com.faithbridge.app` | `app/android/app/build.gradle.kts` |
| iOS Bundle ID | `com.faithbridge.app` | `app/ios/Runner.xcodeproj` (`PRODUCT_BUNDLE_IDENTIFIER`) |
| Nombre visible | FaithBridge | `AndroidManifest.xml` / `Info.plist` |
| Producto de suscripción | `fb_personal_monthly` | Tiendas + RevenueCat |

⚠️ **Estos identificadores no se pueden cambiar después de publicar.** Quedaron fijados en `com.faithbridge.app`. Regístralos tal cual en App Store Connect (Identifiers) y en Google Play Console. Antes de publicar, verifica que el nombre «FaithBridge» no infrinja marcas registradas.

## 2. Firma — instrucciones seguras

### Android (Play App Signing)

```bash
keytool -genkeypair -v -keystore ~/claves/faithbridge-upload.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload
```

Después crea `app/android/key.properties`. Este archivo **no se versiona**; ya está en `.gitignore`.

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/ruta/absoluta/faithbridge-upload.jks
```

Reglas de seguridad:

- Guarda el `.jks` y las contraseñas en un gestor de contraseñas, con una copia de seguridad cifrada fuera de tu computadora.
- Activa **Play App Signing**: Google guarda la clave de firma final; tú solo conservas la de subida, que se puede restablecer si la pierdes.
- Sin `key.properties` la compilación de lanzamiento **falla a propósito**. Así nunca se publica un AAB firmado con la clave de depuración.
- Compila con `flutter build appbundle --release …` (ver `instalacion-despliegue.md` §7).

**Estado:** el AAB **no se generó**. El entorno de trabajo no pudo descargar el Android SDK (dl.google.com estaba bloqueado) y no hay clave de firma.

### iOS

Se necesita una Mac con Xcode y una cuenta del Apple Developer Program (USD 99/año).

1. En Xcode → Runner → *Signing & Capabilities*: elige tu equipo y deja la firma automática.
2. Añade la capacidad **In-App Purchase**.
3. No subas certificados `.p12` ni perfiles al repositorio. La firma automática de Xcode los gestiona.
4. `flutter build ipa --release …` → sube con Xcode Organizer o Transporter.

**Estado:** el IPA **no se generó** (no hay macOS en este entorno).

## 3. Requisitos de las tiendas y cómo los cubre la app

| Requisito | Fuente | Estado en la app |
|---|---|---|
| Eliminación de cuenta dentro de la app (Apple 5.1.1(v)) y aviso de que la suscripción sigue cobrándose por la tienda | [developer.apple.com — account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app) | ✅ Ajustes → Eliminar cuenta. Advierte que hay que cancelar en la tienda y ofrece el botón «Administrar en la tienda» |
| Google: eliminación de cuenta dentro de la app **y** desde un enlace web | Política de datos de usuario de Google Play | Dentro de la app ✅. Página web lista en `website/pages/eliminar-cuenta.md` (falta publicarla en tu dominio) |
| Precio, duración, renovación automática, enlaces a términos y privacidad en la pantalla de compra (Apple 3.1.2) | App Review Guidelines (verificar el texto vigente) | ✅ Pantalla Planes. ⚠️ Apple exige un enlace a los Términos (EULA) también en la ficha |
| Restaurar compras | Apple | ✅ |
| Texto de uso del micrófono | Apple (`NSMicrophoneUsageDescription`) | ✅ Bilingüe en `Info.plist` |
| targetSdk ≥ 36 para apps nuevas desde el 31-ago-2026 | [developer.android.com/google/play/requirements/target-sdk](https://developer.android.com/google/play/requirements/target-sdk) | ⚠️ Usa `flutter.targetSdkVersion`. **Verificar** que Flutter 3.50 compile con 36 |
| Prueba cerrada: **12 testers durante 14 días seguidos** (cuentas personales creadas después del 13-nov-2023) | [support.google.com/…/14151465](https://support.google.com/googleplay/android-developer/answer/14151465) | **No aplica:** se usará una cuenta de **organización** (ver §4.1). Se recomienda igualmente una prueba cerrada breve |
| Formulario de seguridad de datos (Google) y etiquetas de privacidad (Apple) | Ambas tiendas | Borradores en §6 |
| Acceso para revisores | Ambas | Ver §7 |

## 4. Guía de pruebas

### 4.1 Cuenta de Google Play de organización (decidido)

Según la ayuda oficial de Google, el requisito de 12 testers × 14 días es para **cuentas personales** creadas después del 13-nov-2023. Con una cuenta de organización no aplica.

A cambio, Google pide verificar la organización. Requisitos habituales (**verifica los vigentes al registrarte**):

1. **Entidad legal** registrada (por ejemplo, una LLC en tu estado). Debe coincidir exactamente con el nombre del perfil de pagos.
2. **Número D-U-N-S** de Dun & Bradstreet a nombre de esa entidad. Es gratuito y se solicita en dnb.com. El trámite puede tardar varias semanas, así que **pídelo primero**. El nombre y la dirección deben coincidir con el registro legal.
3. **Perfil de pagos de Google** de tipo **organización** (no individual), con datos fiscales (EIN) y una cuenta bancaria del negocio.
4. **Sitio web** de la organización, correo y teléfono de contacto. Google puede pedir verificar el dominio y muestra estos datos en la ficha.
5. Pago único de registro (USD 25; verificar).
6. Verificación de identidad de la persona que administra la cuenta.

Consejos:

- Usa el mismo nombre legal en el D-U-N-S, el perfil de pagos, Google Play Console, App Store Connect (Apple también pide D-U-N-S a las organizaciones) y la política de privacidad.
- El mismo D-U-N-S sirve para registrar la **cuenta de organización de Apple**. Así, en la App Store aparecerá el nombre de la empresa y no tu nombre personal.
- La verificación puede tardar días; inicia el registro antes de terminar las pruebas técnicas.

### 4.2 Pruebas en Google Play

1. **Prueba interna** (hasta 100 testers, sin revisión larga): sube el AAB y prueba la compra con «testers con licencia» (Configuración → Pruebas de licencias).
2. **Prueba cerrada (recomendada, no obligatoria con cuenta de organización):** un grupo pequeño de tu iglesia durante 1–2 semanas, con sesiones reales.
3. Con cuenta de organización se puede pasar a producción sin el requisito de 12 testers × 14 días. La revisión de la app se mantiene.
4. Lanzamiento en producción por etapas (por ejemplo, 10 % → 50 % → 100 %).

### Apple (TestFlight)

1. Sube el build → **TestFlight**. Los testers internos (hasta 100 miembros del equipo) no requieren revisión.
2. Testers externos: requiere la «revisión beta». Se invitan por correo o enlace público.
3. Las compras en TestFlight usan sandbox y la prueba gratuita se acorta.
4. Envía a revisión, con la suscripción adjunta al **mismo envío**.

## 5. Ficha de la tienda (borrador)

**Nombre:** FaithBridge — Subtítulos para la iglesia
**Subtítulo / descripción corta (ES):** Transcripción y traducción en vivo de predicaciones, inglés ↔ español.
**Short description (EN):** Live sermon captions and translation, English ↔ Spanish.

**Descripción (ES):**
> FaithBridge te ayuda a comprender la predicación mostrando por escrito lo que se dice y, si quieres, su traducción entre inglés y español.
>
> • Transcripción en vivo en el idioma original
> • Traducción en vivo: solo traducción u original + traducción
> • Traduce después una transcripción guardada o un texto pegado
> • Letra grande ajustable, alto contraste y modo oscuro
> • Compatible con lectores de pantalla
> • Tus transcripciones solo se guardan si tú lo eliges; no guardamos el audio
>
> Importante: la transcripción y la traducción son automáticas, pueden contener errores y aparecen con unos segundos de retraso. Requiere conexión a internet. La calidad depende del sonido del lugar; acércate a un altavoz. Funciona con la app abierta y la pantalla encendida.
>
> Plan Personal: 300 minutos por mes. Prueba gratuita de 7 días con hasta 120 minutos para usuarios elegibles. Renovación automática hasta que canceles en la tienda.

**Description (EN):**
> FaithBridge helps you understand the sermon by showing in writing what is being said and, if you want, its translation between English and Spanish.
>
> • Live transcription in the original language
> • Live translation: translation only, or original + translation
> • Translate a saved transcript or pasted text later
> • Adjustable large text, high contrast and dark mode
> • Screen-reader friendly
> • Transcripts are saved only if you choose; we don't store audio
>
> Important: transcription and translation are automatic, may contain mistakes and appear a few seconds late. Internet connection required. Quality depends on the room's sound; sit near a speaker. Works with the app open and the screen on.
>
> Personal plan: 300 minutes per month. 7-day free trial with up to 120 minutes for eligible users. Auto-renews until you cancel in the store.

**Categoría:** Estilo de vida (o Referencia). **Clasificación:** apta para todo público. Responde el cuestionario: no hay contenido generado por usuarios visible para otros.

**No usar** frases como «traducción perfecta», «instantánea» o «sin errores».

## 6. Borradores de declaraciones de datos (basados en lo que la app hace realmente)

### Google Play — Seguridad de los datos

| Tipo de dato | ¿Se recopila? | ¿Se comparte? | Propósito | Opcional | Notas |
|---|---|---|---|---|---|
| Dirección de correo | Sí | No (los encargados del tratamiento no cuentan como «compartir») | Cuenta | No | Supabase Auth |
| ID de usuario | Sí | No | Cuenta, funcionalidad | No | |
| Grabaciones de voz o sonido | Sí (se procesa en tiempo real) | No* | Funcionalidad de la app | Sí (solo al iniciar una sesión) | **Procesado de forma efímera; no se guarda** |
| Otro contenido generado por el usuario (transcripciones, texto pegado) | Sí | No* | Funcionalidad | Sí (guardar es opcional) | |
| Historial de compras | Sí | No | Funcionalidad (suscripción) | No | Vía RevenueCat |
| Diagnóstico | No (no hay SDK de analítica ni de fallos) | — | — | — | Si añades Crashlytics o Sentry, actualizar |

\*Deepgram, Anthropic, Supabase y RevenueCat actúan como proveedores de servicio que procesan los datos en nombre de FaithBridge. **Confírmalo con sus contratos** antes de declarar «no compartido».

Otras respuestas:
- Datos cifrados en tránsito: **Sí** (HTTPS/WSS obligatorio en producción).
- El usuario puede solicitar la eliminación: **Sí** (en la app; falta el enlace web).

### Apple — Etiquetas de privacidad

| Tipo | Vinculado al usuario | Seguimiento | Propósito |
|---|---|---|---|
| Información de contacto → Correo | Sí | No | Funcionalidad de la app |
| Identificadores → ID de usuario | Sí | No | Funcionalidad de la app |
| Contenido del usuario → Datos de audio | Sí (durante la sesión) | No | Funcionalidad de la app |
| Contenido del usuario → Otro (transcripciones) | Sí | No | Funcionalidad de la app |
| Compras → Historial de compras | Sí | No | Funcionalidad de la app |

No hay seguimiento (tracking) ni publicidad, así que no hace falta el aviso de App Tracking Transparency.

## 7. Acceso para revisores

Inicio de sesión: con el código por correo, el revisor no puede recibir el código. Opciones:

1. **(Recomendada)** Crear un usuario de revisión con un correo tuyo y configurar en Supabase un código fijo de prueba solo para ese correo. Supabase lo permite con la configuración de «test OTP» en Auth; verifica que esté disponible en tu plan.
2. Entregar en «Notas para el revisor»: el correo de prueba, cómo obtener el código y **una explicación de que el micrófono capta la predicación**. Incluye un video corto de demostración.

También se puede dar al usuario de revisión un beneficio interno (fila en `entitlements`) para que pruebe sin comprar. **Aun así, la compra en sandbox debe funcionar.**

## 8. Capturas reales necesarias (con datos REALES, no simulados)

Por idioma (es y en):

- Android: teléfono (mínimo 2, recomendado 4–8) y tableta de 7" y 10" si se declara compatibilidad.
- iOS: iPhone de 6.9" (obligatorio) y iPad si se habilita.

Pantallas a capturar:

1. Bienvenida.
2. Selección de idioma y modo.
3. Subtítulos en vivo: original y traducción, con el indicador de micrófono.
4. Letra grande o alto contraste.
5. Historial.
6. Planes, con el precio de la tienda.
7. Modo oscuro.

⚠️ No uses capturas con el aviso «DATOS SIMULADOS». Las capturas deben mostrar el funcionamiento real.

## 9. Checklist final

- [ ] Identificadores definitivos y nombre verificado
- [ ] Entidad legal + número D-U-N-S (gratuito; puede tardar semanas)
- [ ] Cuenta de Google Play de **organización** (USD 25) y Apple Developer de organización (USD 99/año) — **requiere tu autorización**
- [ ] Acuerdos de apps de pago, datos bancarios y fiscales (W-9/W-8 según el caso)
- [ ] Inscripción en el App Store Small Business Program
- [ ] Productos de suscripción y prueba gratuita en ambas tiendas + RevenueCat
- [ ] Backend desplegado con HTTPS, migraciones aplicadas y webhook configurado
- [ ] `TRANSLATION_MODEL` decidido y costos medidos
- [ ] Política de privacidad y términos revisados por un abogado y publicados en una URL pública
- [ ] Sitio web publicado (`website/`), con la página de eliminación de cuenta (Google)
- [ ] Correo de soporte que funcione
- [ ] Procedimiento de pruebas en dispositivos (`pruebas-dispositivos.md`) superado
- [ ] Prueba cerrada breve en Google (recomendada) y TestFlight
- [ ] Capturas reales e ícono definitivo (el ícono actual es el predeterminado de Flutter)
- [ ] Formularios de seguridad de datos y etiquetas de privacidad
- [ ] Notas y cuenta para revisores
- [ ] Límites de gasto en Deepgram y Anthropic; `daily_cost_limit_usd` ajustado
- [ ] Plan de soporte: tiempo de respuesta, preguntas frecuentes, procedimiento de reembolsos (los gestiona la tienda)
