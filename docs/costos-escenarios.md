# Escenarios de costos (generado por `scripts/cost_model.py`)

> Cifras **estimadas** con los supuestos del script (tarifas consultadas el 2026-11-23). No son garantía de resultados. Medir costos reales en sandbox antes de fijar precios.

## 1. Costo variable por minuto de audio

| Componente | USD / minuto |
|---|---|
| Deepgram Nova-3 streaming (regular) | 0.0077 |
| Deepgram Nova-3 streaming (promoción hasta 2026-12-31) | 0.0048 |
| Keyterms de Deepgram (activados) | +0.0013 |
| Tráfico de salida del audio (Fly.io) | 0.00004 |
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
| claude-opus-5-5 | $3.82 | $9.55 | $19.09 | -$14.00 |
| claude-sonnet-5-5 | $2.01 | $5.03 | $10.06 | -$4.97 |
| claude-haiku-5-5 | $0.61 | $1.52 | $3.04 | $2.05 |

## 3. Escenarios mensuales — traducción con `claude-haiku-5-5` (sin caché, conservador)

Supuestos: 80 % de los minutos con traducción; nuevas pruebas cada mes = 30 % de la base de pago; uso medio de la prueba = 60 min; conversión de prueba a pago = 25 %.

| Clientes de pago | Uso | Ingresos brutos | Comisión tienda (15 %) | RevenueCat | Costo variable (uso) | Costo de pruebas | Margen de contribución | Costos fijos | Resultado neto (antes de impuestos) |
|---|---|---|---|---|---|---|---|---|---|
| 10 | bajo 60 | $59.90 | $8.99 | $0.00 | $5.95 | $7.14 | $37.82 | $61.18 | -$23.36 |
| 10 | medio 150 | $59.90 | $8.99 | $0.00 | $14.88 | $7.14 | $28.89 | $61.18 | -$32.29 |
| 10 | completo 300 | $59.90 | $8.99 | $0.00 | $29.76 | $7.14 | $14.01 | $61.18 | -$47.17 |
| 100 | bajo 60 | $599.00 | $89.85 | $0.00 | $59.52 | $71.42 | $378.21 | $61.18 | $317.03 |
| 100 | medio 150 | $599.00 | $89.85 | $0.00 | $148.79 | $71.42 | $288.94 | $61.18 | $227.76 |
| 100 | completo 300 | $599.00 | $89.85 | $0.00 | $297.59 | $71.42 | $140.14 | $61.18 | $78.96 |
| 1000 | bajo 60 | $5,990.00 | $898.50 | $59.90 | $595.17 | $714.20 | $3,722.23 | $61.18 | $3,661.04 |
| 1000 | medio 150 | $5,990.00 | $898.50 | $59.90 | $1,487.93 | $714.20 | $2,829.47 | $61.18 | $2,768.29 |
| 1000 | completo 300 | $5,990.00 | $898.50 | $59.90 | $2,975.85 | $714.20 | $1,341.55 | $61.18 | $1,280.36 |

## 3. Escenarios mensuales — traducción con `claude-opus-5-5` (sin caché, conservador)

Supuestos: 80 % de los minutos con traducción; nuevas pruebas cada mes = 30 % de la base de pago; uso medio de la prueba = 60 min; conversión de prueba a pago = 25 %.

| Clientes de pago | Uso | Ingresos brutos | Comisión tienda (15 %) | RevenueCat | Costo variable (uso) | Costo de pruebas | Margen de contribución | Costos fijos | Resultado neto (antes de impuestos) |
|---|---|---|---|---|---|---|---|---|---|
| 10 | bajo 60 | $59.90 | $8.99 | $0.00 | $31.63 | $37.96 | -$18.67 | $61.18 | -$79.85 |
| 10 | medio 150 | $59.90 | $8.99 | $0.00 | $79.08 | $37.96 | -$66.12 | $61.18 | -$127.30 |
| 10 | completo 300 | $59.90 | $8.99 | $0.00 | $158.15 | $37.96 | -$145.19 | $61.18 | -$206.38 |
| 100 | bajo 60 | $599.00 | $89.85 | $0.00 | $316.31 | $379.57 | -$186.72 | $61.18 | -$247.90 |
| 100 | medio 150 | $599.00 | $89.85 | $0.00 | $790.76 | $379.57 | -$661.18 | $61.18 | -$722.36 |
| 100 | completo 300 | $599.00 | $89.85 | $0.00 | $1,581.53 | $379.57 | -$1,451.94 | $61.18 | -$1,513.12 |
| 1000 | bajo 60 | $5,990.00 | $898.50 | $59.90 | $3,163.05 | $3,795.66 | -$1,927.11 | $61.18 | -$1,988.29 |
| 1000 | medio 150 | $5,990.00 | $898.50 | $59.90 | $7,907.62 | $3,795.66 | -$6,671.68 | $61.18 | -$6,732.87 |
| 1000 | completo 300 | $5,990.00 | $898.50 | $59.90 | $15,815.25 | $3,795.66 | -$14,579.31 | $61.18 | -$14,640.49 |

## 4. Costo de la prueba gratuita por cliente que paga

| Conversión | Uso medio 30 min | Uso medio 60 min | Uso completo 120 min |
|---|---|---|---|
| 10 % (claude-haiku-5-5) | $3.04 | $6.08 | $12.17 |
| 25 % (claude-haiku-5-5) | $1.22 | $2.43 | $4.87 |
| 40 % (claude-haiku-5-5) | $0.76 | $1.52 | $3.04 |
| 10 % (claude-opus-5-5) | $19.09 | $38.18 | $76.36 |
| 25 % (claude-opus-5-5) | $7.64 | $15.27 | $30.55 |
| 40 % (claude-opus-5-5) | $4.77 | $9.55 | $19.09 |

## 5. Plan Iglesia (fase 2) — una sola transcripción/traducción por fuente

Los minutos NO se multiplican por asistentes. El costo por asistente es solo tráfico de texto (~3 KB/min).

| Modelo | Asistentes | Minutos | Costo IA+voz | Tráfico de texto | Costo total | Ingreso neto (tienda 15 %) | Margen |
|---|---|---|---|---|---|---|---|
| claude-haiku-5-5 | 10 | 300 | $3.04 | $0.00 | $3.04 | $25.49 | $22.45 |
| claude-haiku-5-5 | 10 | 600 | $6.08 | $0.00 | $6.08 | $25.49 | $19.41 |
| claude-haiku-5-5 | 30 | 300 | $3.04 | $0.00 | $3.04 | $25.49 | $22.45 |
| claude-haiku-5-5 | 30 | 600 | $6.08 | $0.00 | $6.09 | $25.49 | $19.41 |
| claude-opus-5-5 | 10 | 300 | $19.09 | $0.00 | $19.09 | $25.49 | $6.40 |
| claude-opus-5-5 | 10 | 600 | $38.18 | $0.00 | $38.18 | $25.49 | -$12.69 |
| claude-opus-5-5 | 30 | 300 | $19.09 | $0.00 | $19.09 | $25.49 | $6.40 |
| claude-opus-5-5 | 30 | 600 | $38.18 | $0.00 | $38.18 | $25.49 | -$12.69 |

## 6. Sensibilidad: comisión estándar de Apple (30 %)

- `claude-haiku-5-5`: ingreso neto $4.19, costo con uso completo $3.04 → margen $1.15
- `claude-opus-5-5`: ingreso neto $4.19, costo con uso completo $19.09 → margen -$14.90

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
egress_usd_per_gb: 0.02
fixed_monthly: {'Supabase Pro (base de datos + auth)': 25.0, 'Fly.io: 1 máquina shared-cpu-2x 1 GB': 6.89, 'Monitoreo / correo / dominio': 20.0, 'Cuentas de desarrollador (Apple 99/año + Google 25 único, prorrateado)': 9.291666666666666}
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
