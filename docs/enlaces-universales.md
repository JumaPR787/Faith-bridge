# Enlaces universales: el QR abre la app

> **Implementado y probado** con pruebas automáticas (formato del enlace, validación del dominio, apertura de «Unirme» con el código, duplicados, archivos de verificación). **No se ha probado en teléfonos reales**: la verificación de dominio de Apple y Google solo ocurre con la app firmada y el sitio publicado.

## Cómo funciona

1. Con `JOIN_LINK_BASE` configurado, el QR del organizador contiene un enlace corto, por ejemplo `https://tudominio.com/j/ABCD2345`.
2. El asistente lo escanea con **la cámara normal del teléfono**:
   - **Con la app instalada:** se abre FaithBridge en «Unirme», con el código ya escrito, y se une sola.
   - **Sin la app:** se abre la página `tudominio.com/j/...` del sitio, con instrucciones y enlaces a las tiendas.
3. El escáner dentro de la app también entiende el enlace.

Sin `JOIN_LINK_BASE`, el QR sigue usando el formato anterior (`FAITHBRIDGE:ABCD-2345`), que solo lee la app.

**Seguridad:** la app solo acepta enlaces `https` de **tu** dominio con la ruta `/j/CODIGO`. Un enlace de otro dominio se ignora. El enlace contiene solo el código de unirse, que ya es público para quien ve la pantalla de la iglesia; vence a las 6 horas y es inútil cuando la sesión termina.

## Qué configurar (todo con TU dominio)

| Dónde | Qué | Valor de ejemplo |
|---|---|---|
| Backend (`fly.toml` `[env]` o `fly secrets set`) | `JOIN_LINK_BASE` | `https://tudominio.com/j` |
| App, compilación | `--dart-define=APP_LINK_HOST=…` | `tudominio.com` |
| Android | `app/android/gradle.properties` → `faithbridge.appLinkHost` | `tudominio.com` |
| iOS | `app/ios/Flutter/Debug.xcconfig` y `Release.xcconfig` → `APP_LINK_HOST` | `tudominio.com` |
| Sitio web (GitHub → Variables) | `APPLE_TEAM_ID` | 10 caracteres, en developer.apple.com → Membership |
| Sitio web (GitHub → Variables) | `ANDROID_CERT_SHA256` | Huella SHA-256 del **certificado de firma de la app** en Play Console → Configuración → Integridad de la app → Firma de apps (si quieres que también funcione con builds de prueba, agrega la huella de la clave de subida, separada por coma) |
| Sitio web (GitHub → Variables) | `APP_STORE_URL`, `PLAY_STORE_URL` | Enlaces de la ficha, cuando existan |

Hoy los cuatro primeros valores dicen `CAMBIAR.example.com` o están vacíos. **Mientras no los cambies, el QR no abrirá la app.** El resto sigue funcionando: código escrito y escáner dentro de la app.

## Archivos que publica el sitio (Cloudflare Pages)

- `/.well-known/apple-app-site-association`: Apple verifica que tu dominio autoriza a la app `TEAMID.com.faithbridge.app` a abrir `/j/*`.
- `/.well-known/assetlinks.json`: Google verifica que tu dominio autoriza a `com.faithbridge.app`, firmada con esa huella.
- `/j/*` → `join.html` (reescritura en `_redirects`): la página de respaldo si no hay app.

`scripts/build_website.py` los genera con `--apple-team-id` y `--android-sha256`, y valida su formato.

## Comprobar después de publicar

```bash
curl -sI https://tudominio.com/.well-known/apple-app-site-association | grep -i content-type   # application/json
curl -s  https://tudominio.com/.well-known/assetlinks.json                                    # JSON con tu huella
curl -sI https://tudominio.com/j/ABCD2345 | head -1                                            # 200 (página de respaldo)
```

- **Apple:** el archivo debe servirse **sin redirecciones** y por HTTPS. Apple lo descarga a través de su CDN al instalar la app, así que los cambios pueden tardar.
- **Android:** al instalar la app (desde Play o con `adb`), revisa `adb shell pm get-app-links com.faithbridge.app`. Debe decir `verified`. La herramienta oficial de Google es *Statement List Generator and Tester*.
- **Cloudflare Pages y `.well-known`:** verifica con los `curl` de arriba que los archivos se publicaron. Algunas herramientas ignoran las carpetas que empiezan con punto.

## Requisitos de las cuentas

- **Apple:** el App ID `com.faithbridge.app` necesita la capacidad **Associated Domains**. Con la firma automática de Xcode se activa sola al detectar `Runner/Runner.entitlements`.
- **Google:** ningún paso extra en Play Console aparte de la huella.

## Pruebas en dispositivos

| # | Caso | Esperado |
|---|---|---|
| 24 | Escanear el QR con la cámara nativa (iPhone y Android), con la app instalada | Se abre FaithBridge en «Unirme» y se une sola |
| 25 | Igual, sin la app | Se abre la página del sitio con instrucciones |
| 26 | Escanear con la app cerrada por completo | Igual que el caso 24 (enlace inicial) |
| 27 | Enlace de un código vencido | La app muestra «Código no válido, vencido o de una sesión terminada» |
