# Documento de costos y rentabilidad

**Fecha de consulta de tarifas:** 23 de noviembre de 2026.
**Tablas detalladas:** [`costos-escenarios.md`](costos-escenarios.md), generadas con `python3 scripts/cost_model.py`.
Todo lo de este documento son **estimaciones**. No prometen ganancias. Hay que confirmarlas midiendo en sandbox (ver §8).

---

## 1. Resumen en palabras sencillas

- El costo principal por minuto es **convertir la voz en texto** (Deepgram: unos USD 0.0077 por minuto).
- La **traducción** puede costar casi nada o ser lo más caro. Depende del modelo de IA:
  - Claude **Haiku 5.5**: unos USD 0.001 por minuto → el plan de USD 5.99 **deja margen**.
  - Claude **Opus 5.5**: unos USD 0.024–0.055 por minuto → el plan de USD 5.99 **pierde dinero** con cualquier uso medio o alto.
- Con Haiku 5.5, un usuario que gasta sus 300 minutos completos cuesta unos **USD 2.69** al mes. Tras la comisión de la tienda (15 %) entran USD 5.09. Quedan unos **USD 2.40** para pagar gastos fijos.
- Con 10 clientes no se cubren los gastos fijos (~USD 94/mes). Con 100 clientes el resultado ya es positivo en los tres niveles de uso.
- El plan Iglesia (USD 29.99 / 600 min) es rentable con Haiku 5.5 (~USD 20 de margen), porque los minutos **no** se multiplican por asistentes.

## 2. Tarifas usadas y fuentes

| Concepto | Tarifa usada | Fuente | ¿Verificada en página oficial? |
|---|---|---|---|
| Deepgram Nova-3 monolingüe, streaming, pay-as-you-go | USD 0.0077/min (regular) | [deepgram.com/pricing](https://deepgram.com/pricing) vía resultados de búsqueda y terceros | **Parcial.** La web oficial muestra USD 0.0048/min promocional (hasta 31-dic-2026). La tarifa regular 0.0077 proviene de terceros. El entorno de trabajo bloqueó el acceso directo a deepgram.com. |
| Deepgram keyterms (glosario en el reconocimiento) | +USD 0.0013/min | Terceros | **No.** Por eso está desactivado por defecto (`DEEPGRAM_KEYTERMS_ENABLED=false`). |
| Deepgram, crédito inicial | USD 200 | Terceros y página oficial | Parcial |
| Claude Opus 5.5 | USD 4 entrada / 20 salida por millón de tokens; lectura de caché 0.20 | Documentación de Anthropic (tabla de modelos, actualizada 2026-11-03) | Sí (documentación oficial del SDK) |
| Claude Sonnet 5.5 | USD 2 / 10; caché 0.10 | Ídem | Sí |
| Claude Haiku 5.5 | USD 0.10 / 0.50 (prompts < 100K tokens) | Ídem | Sí. La tarifa de lectura de caché de Haiku 5.5 **no** estaba en la fuente; se supuso 10 % de la entrada. |
| Google Cloud Translation (NMT), referencia | USD 20 por millón de caracteres | [cloud.google.com/translate/pricing](https://cloud.google.com/translate/pricing) (versiones en caché) | Parcial |
| Apple, comisión | 15 % (Small Business Program, < USD 1 M al año); 30 % estándar; 15 % en suscripciones tras el primer año | [developer.apple.com/app-store/small-business-program](https://developer.apple.com/app-store/small-business-program/) | **Sí** (página oficial leída). Hay que **inscribirse** en el programa. |
| Google Play, comisión de suscripciones | 15 % en total (desde 30-jun-2026 en EE. UU.: 10 % de servicio + tarifa de facturación) | [Blog de Android Developers, jun-2026](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html) y terceros | Parcial. El desglose 10 % + 5 % proviene de terceros. |
| RevenueCat | Gratis hasta USD 2,500 de ingreso mensual rastreado; luego 1 % de todo lo rastreado | [revenuecat.com/pricing](https://www.revenuecat.com/pricing) | Sí (resultados de la página oficial) |
| Supabase Pro | USD 25/mes (incluye 250 GB de salida) | Terceros 2026 | No. Verificar en supabase.com/pricing. |
| Servidor backend | ~USD 40/mes (supuesto) | Estimación | No (depende del proveedor que elijas). |
| Tráfico de salida | USD 0.09/GB (supuesto) | Estimación típica de nube | No |
| Apple Developer Program | USD 99/año | Conocimiento general | Verificar al inscribirte |
| Google Play Console | USD 25 pago único | Conocimiento general | Verificar al inscribirte |

**No se encontraron** cifras oficiales comprobables de Azure Speech (la página mostraba los precios vacíos).
Google Speech-to-Text aparece a unos USD 0.016/min en sus páginas en caché, el doble que Deepgram. Por eso no se eligió.

## 3. Cómo se calculó el costo de traducción

Se midió el prompt real que usa el backend (`buildSystemPrompt`):

- Instrucciones + glosario + nombres de los 66 libros bíblicos: unos 3,700 caracteres, **~1,150 tokens**.
- Contexto reciente (3 pares) + segmento: **~200 tokens**.
- **7 segmentos por minuto** (se corta cada 8–9 s por pausa o fin de oración).
- Salida: ~45 tokens por segmento en Haiku y ~120 en Opus 5.5. Opus 5.5 no permite desactivar el razonamiento interno, que también se factura.

El caché del prompt puede bajar mucho el costo, pero solo funciona si el prefijo supera el mínimo cacheable del modelo. **Se calculó sin caché (escenario conservador)** y se muestra también la cifra con caché. Hay que medirlo (campo `cache_read_input_tokens` en la respuesta).

## 4. Modelo de traducción — decidido: `claude-haiku-5-5`

| Opción | Costo traducción/min | Margen Personal con uso completo | Comentario |
|---|---|---|---|
| `claude-haiku-5-5` | ~USD 0.001 | **+USD 2.40** | **Recomendado para el MVP**, si las pruebas de fidelidad (docs/pruebas-dispositivos.md §3) son aceptables. |
| `claude-sonnet-5-5` | ~USD 0.009–0.025 | −USD 4.62 (sin caché) | Solo viable con caché efectivo o un precio más alto. |
| `claude-opus-5-5` | ~USD 0.024–0.055 | **−USD 13.65** | Máxima calidad, pero **inviable** a USD 5.99. |
| Google NMT (no implementado) | ~USD 0.017 | ~−USD 0.50 | Más caro que Haiku y sin contexto ni reglas de fidelidad. |

**Decisión del dueño del producto (23-nov-2026): se usa `claude-haiku-5-5`.** Ya es el valor por defecto de `TRANSLATION_MODEL`, y las tarifas para estimar gasto (`COST_TRANSLATION_INPUT_USD_PER_MTOK=0.10`, `COST_TRANSLATION_OUTPUT_USD_PER_MTOK=0.50`) también están ajustadas.

Con Haiku 5.5 el backend desactiva el razonamiento interno y usa esfuerzo bajo. Haiku 5.5 no tiene respaldo automático en el servidor ante un rechazo: si ocurre, ese segmento se marca «[traducción no disponible]» y nunca se inventa.

Antes de lanzar, hay que confirmar la calidad con el procedimiento de fidelidad (`pruebas-dispositivos.md` §2). Si no fuera aceptable, el cambio es una sola variable, pero las tablas de §5 muestran el impacto en el margen.

## 5. ¿Cubren costos los planes propuestos?

- **Personal USD 5.99 / 300 min:** sí, **solo con un modelo de traducción económico** (Haiku 5.5). El margen de contribución es de ~USD 2.40 a 4.55 por usuario según el uso. Con la comisión de Apple del 30 % el margen baja a ~USD 1.50.
- **Prueba 7 días / 120 min:** con Haiku cuesta ~USD 1.08 por prueba con uso completo. Con una conversión del 25 % equivale a ~USD 2–4 por cliente que paga. Es aceptable.
- **Iglesia USD 29.99 / 600 min / 30 asistentes:** margen de ~USD 20 con Haiku. No habilitar hasta implementar y medir la fase 2.

**Si no se aprueba un modelo económico**, propongo alguna de estas alternativas antes de comercializar:
1. Personal a USD 9.99 con 150 minutos y Sonnet 5.5 con caché medido.
2. Mantener USD 5.99 y dejar la traducción en vivo como un plan superior.

## 6. Lo que NO incluyen los números

- Tu tiempo de atención al cliente y de soporte.
- Asesoría legal y contable.
- Diseño de capturas e ícono.
- Correo transaccional SMTP para los códigos de inicio de sesión (Supabase limita mucho su correo integrado).
- Monitoreo avanzado.
- Cambios de tarifas futuros.
- Reembolsos y contracargos. La tienda devuelve el dinero, pero el costo de la API ya se gastó.
- Fraude.
- **Impuestos:** las tiendas recaudan el impuesto sobre ventas en EE. UU. en la mayoría de los estados. El impuesto sobre la renta de tu negocio es una partida separada y no se calcula aquí. Consúltalo con un contador.
- A 1,000 clientes los costos fijos subirán (más servidores y soporte). El modelo los mantiene en ~USD 94 solo como referencia.

## 7. Controles de gasto implementados

| Control | Dónde | Cómo se usa |
|---|---|---|
| Medición de consumo en servidor | `live_sessions`, `usage_events`, `usage_periods` | Se cuenta por segundos de audio recibido; un minuto se cobra una sola vez |
| Límite de gasto diario | `app_config.daily_cost_limit_usd` (por defecto 25) | Al alcanzarlo se rechazan nuevas sesiones (`daily_budget_reached`) |
| Alertas de presupuesto | 50 %, 80 % y 100 % del límite diario | Se registran en el log y se envían a `ALERT_WEBHOOK_URL` |
| Estimación de gasto | `spend_ledger` (por día y proveedor) | Tarifas configurables en `COST_*` |
| Interruptor operativo | `app_config.live_sessions_enabled` / `text_translation_enabled` | `update app_config set value='false' where key='live_sessions_enabled';` → bloquea sesiones nuevas sin tocar las transcripciones guardadas |
| Capacidad máxima | `app_config.max_concurrent_live_sessions` | Protege ante picos |
| Anti-abuso | 1 sesión activa por usuario, 12 inicios/hora, máximo 3 h por sesión, máximo 20,000 caracteres por traducción de texto, una segunda prueba no recibe minutos | `config.ts` |
| Sin excedentes | Al agotar la cuota la sesión termina | No existe ningún cobro automático por minutos extra |

**Recomendado además (fuera del código):** configurar límites de gasto mensuales en las consolas de Deepgram y Anthropic.

## 8. Cómo medir el costo real antes de lanzar

1. Configura claves de prueba y ejecuta 10 sesiones de 10 minutos con predicaciones reales (en inglés y en español).
2. Revisa `spend_ledger` y compáralo con los paneles de uso de Deepgram y Anthropic.
3. Calcula el costo real por minuto y actualiza `scripts/cost_model.py`.
4. Regenera `costos-escenarios.md`.
