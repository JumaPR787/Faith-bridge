# Escenarios de costos (generado por `scripts/cost_model.py`)

> Cifras **estimadas** con los supuestos del script (tarifas consultadas el 2026-11-23). No son garantía de resultados. Medir costos reales en sandbox antes de fijar precios.

## 1. Costo variable por minuto de audio

| Componente | USD / minuto |
|---|---|
| Deepgram Nova-3 streaming (regular) | 0.0077 |
| Deepgram Nova-3 streaming (promoción hasta 2026-12-31) | 0.0048 |
| Keyterms de Deepgram (activados) | +0.0013 |
| Tráfico de salida del audio | 0.0002 |
| Traducción claude-opus-5-5 (sin caché) | 0.0546 |
| Traducción claude-opus-5-5 (con caché del prompt) | 0.0240 |
| Traducción claude-sonnet-5-5 (sin caché) | 0.0245 |
| Traducción claude-sonnet-5-5 (con caché del prompt) | 0.0092 |
| Traducción claude-haiku-5-5 (sin caché) | 0.0011 |
| Traducción claude-haiku-5-5 (con caché del prompt) | 0.0004 |
| Traducción Google Cloud NMT (referencia, sin contexto) | 0.0170 |

Un minuto se cobra UNA vez aunque se muestren transcripción y traducción; en modo «solo transcripción» no hay costo de traducción.

## 2. Costo por usuario Personal al mes según modelo de traducción

Precio $5.99; ingreso neto tras tienda 15 %: $5.09.

| Modelo | Uso 60 min (bajo) | Uso 150 min (medio) | Uso 300 min (completo) | Margen de contribución con uso completo |
|---|---|---|---|---|
| claude-opus-5-5 | $3.83 | $9.57 | $19.13 | -$14.04 |
| claude-sonnet-5-5 | $2.02 | $5.05 | $10.10 | -$5.01 |
| claude-haiku-5-5 | $0.62 | $1.54 | $3.08 | $2.01 |

## 3. Escenarios mensuales — traducción con `claude-haiku-5-5` (sin caché, conservador)

Supuestos: 80 % de los minutos con traducción; nuevas pruebas cada mes = 30 % de la base de pago; uso medio de la prueba = 60 min; conversión de prueba a pago = 25 %.

| Clientes de pago | Uso | Ingresos brutos | Comisión tienda (15 %) | RevenueCat | Costo variable (uso) | Costo de pruebas | Margen de contribución | Costos fijos | Resultado neto (antes de impuestos) |
|---|---|---|---|---|---|---|---|---|---|
| 10 | bajo 60 | $59.90 | $8.99 | $0.00 | $6.03 | $7.24 | $37.65 | $94.29 | -$56.64 |
| 10 | medio 150 | $59.90 | $8.99 | $0.00 | $15.08 | $7.24 | $28.60 | $94.29 | -$65.69 |
| 10 | completo 300 | $59.90 | $8.99 | $0.00 | $30.15 | $7.24 | $13.53 | $94.29 | -$80.77 |
| 100 | bajo 60 | $599.00 | $89.85 | $0.00 | $60.30 | $72.37 | $376.48 | $94.29 | $282.19 |
| 100 | medio 150 | $599.00 | $89.85 | $0.00 | $150.76 | $72.37 | $286.02 | $94.29 | $191.73 |
| 100 | completo 300 | $599.00 | $89.85 | $0.00 | $301.52 | $72.37 | $135.26 | $94.29 | $40.97 |
| 1000 | bajo 60 | $5,990.00 | $898.50 | $59.90 | $603.05 | $723.65 | $3,704.90 | $94.29 | $3,610.61 |
| 1000 | medio 150 | $5,990.00 | $898.50 | $59.90 | $1,507.61 | $723.65 | $2,800.33 | $94.29 | $2,706.04 |
| 1000 | completo 300 | $5,990.00 | $898.50 | $59.90 | $3,015.23 | $723.65 | $1,292.72 | $94.29 | $1,198.43 |

## 3. Escenarios mensuales — traducción con `claude-opus-5-5` (sin caché, conservador)

Supuestos: 80 % de los minutos con traducción; nuevas pruebas cada mes = 30 % de la base de pago; uso medio de la prueba = 60 min; conversión de prueba a pago = 25 %.

| Clientes de pago | Uso | Ingresos brutos | Comisión tienda (15 %) | RevenueCat | Costo variable (uso) | Costo de pruebas | Margen de contribución | Costos fijos | Resultado neto (antes de impuestos) |
|---|---|---|---|---|---|---|---|---|---|
| 10 | bajo 60 | $59.90 | $8.99 | $0.00 | $31.71 | $38.05 | -$18.85 | $94.29 | -$113.14 |
| 10 | medio 150 | $59.90 | $8.99 | $0.00 | $79.27 | $38.05 | -$66.41 | $94.29 | -$160.70 |
| 10 | completo 300 | $59.90 | $8.99 | $0.00 | $158.55 | $38.05 | -$145.68 | $94.29 | -$239.97 |
| 100 | bajo 60 | $599.00 | $89.85 | $0.00 | $317.09 | $380.51 | -$188.45 | $94.29 | -$282.75 |
| 100 | medio 150 | $599.00 | $89.85 | $0.00 | $792.73 | $380.51 | -$664.09 | $94.29 | -$758.38 |
| 100 | completo 300 | $599.00 | $89.85 | $0.00 | $1,585.46 | $380.51 | -$1,456.82 | $94.29 | -$1,551.12 |
| 1000 | bajo 60 | $5,990.00 | $898.50 | $59.90 | $3,170.93 | $3,805.11 | -$1,944.43 | $94.29 | -$2,038.73 |
| 1000 | medio 150 | $5,990.00 | $898.50 | $59.90 | $7,927.31 | $3,805.11 | -$6,700.82 | $94.29 | -$6,795.11 |
| 1000 | completo 300 | $5,990.00 | $898.50 | $59.90 | $15,854.62 | $3,805.11 | -$14,628.14 | $94.29 | -$14,722.43 |

## 4. Costo de la prueba gratuita por cliente que paga

| Conversión | Uso medio 30 min | Uso medio 60 min | Uso completo 120 min |
|---|---|---|---|
| 10 % (claude-haiku-5-5) | $3.08 | $6.16 | $12.33 |
| 25 % (claude-haiku-5-5) | $1.23 | $2.47 | $4.93 |
| 40 % (claude-haiku-5-5) | $0.77 | $1.54 | $3.08 |
| 10 % (claude-opus-5-5) | $19.13 | $38.26 | $76.52 |
| 25 % (claude-opus-5-5) | $7.65 | $15.30 | $30.61 |
| 40 % (claude-opus-5-5) | $4.78 | $9.57 | $19.13 |

## 5. Plan Iglesia (fase 2) — una sola transcripción/traducción por fuente

Los minutos NO se multiplican por asistentes. El costo por asistente es solo tráfico de texto (~3 KB/min).

| Modelo | Asistentes | Minutos | Costo IA+voz | Tráfico de texto | Costo total | Ingreso neto (tienda 15 %) | Margen |
|---|---|---|---|---|---|---|---|
| claude-haiku-5-5 | 10 | 300 | $3.08 | $0.00 | $3.08 | $25.49 | $22.41 |
| claude-haiku-5-5 | 10 | 600 | $6.16 | $0.00 | $6.16 | $25.49 | $19.33 |
| claude-haiku-5-5 | 30 | 300 | $3.08 | $0.00 | $3.08 | $25.49 | $22.41 |
| claude-haiku-5-5 | 30 | 600 | $6.16 | $0.00 | $6.17 | $25.49 | $19.32 |
| claude-opus-5-5 | 10 | 300 | $19.13 | $0.00 | $19.13 | $25.49 | $6.36 |
| claude-opus-5-5 | 10 | 600 | $38.26 | $0.00 | $38.26 | $25.49 | -$12.77 |
| claude-opus-5-5 | 30 | 300 | $19.13 | $0.00 | $19.13 | $25.49 | $6.36 |
| claude-opus-5-5 | 30 | 600 | $38.26 | $0.00 | $38.27 | $25.49 | -$12.77 |

## 6. Sensibilidad: comisión estándar de Apple (30 %)

- `claude-haiku-5-5`: ingreso neto $4.19, costo con uso completo $3.08 → margen $1.11
- `claude-opus-5-5`: ingreso neto $4.19, costo con uso completo $19.13 → margen -$14.94

## 7. Supuestos usados

```
stt_usd_min: 0.0077
stt_promo_usd_min: 0.0048
keyterm_usd_min: 0.0013
keyterms_enabled: True
segments_per_min: 7
input_tokens_per_segment: 1350
system_tokens: 1150
chars_per_min: 850
models: {'claude-opus-5-5': (4.0, 20.0, 0.2, 120), 'claude-sonnet-5-5': (2.0, 10.0, 0.1, 80), 'claude-haiku-5-5': (0.1, 0.5, 0.01, 45)}
google_nmt_usd_per_mchar: 20.0
audio_mb_per_min: 1.92
egress_usd_per_gb: 0.09
fixed_monthly: {'Supabase Pro (base de datos + auth)': 25.0, 'Servidor backend (1-2 instancias pequeñas)': 40.0, 'Monitoreo / correo / dominio': 20.0, 'Cuentas de desarrollador (Apple 99/año + Google 25 único, prorrateado)': 9.291666666666666}
price_personal: 5.99
price_church: 29.99
store_fee: 0.15
store_fee_standard: 0.3
revenuecat_free_mtr: 2500.0
revenuecat_pct: 0.01
quota_personal_min: 300
quota_trial_min: 120
quota_church_min: 600
```
