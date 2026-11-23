# Escenarios de costos (generado por `scripts/cost_model.py`)

> Cifras **estimadas** con los supuestos del script (tarifas consultadas el 2026-11-23). No son garantía de resultados. Medir costos reales en sandbox antes de fijar precios.

## 1. Costo variable por minuto de audio

| Componente | USD / minuto |
|---|---|
| Deepgram Nova-3 streaming (regular) | 0.0077 |
| Deepgram Nova-3 streaming (promoción hasta 2026-12-31) | 0.0048 |
| Keyterms de Deepgram (opcional, desactivado) | +0.0013 |
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
| claude-opus-5-5 | $3.75 | $9.37 | $18.74 | -$13.65 |
| claude-sonnet-5-5 | $1.94 | $4.86 | $9.71 | -$4.62 |
| claude-haiku-5-5 | $0.54 | $1.35 | $2.69 | $2.40 |

## 3. Escenarios mensuales — traducción con `claude-haiku-5-5` (sin caché, conservador)

Supuestos: 80 % de los minutos con traducción; nuevas pruebas cada mes = 30 % de la base de pago; uso medio de la prueba = 60 min; conversión de prueba a pago = 25 %.

| Clientes de pago | Uso | Ingresos brutos | Comisión tienda (15 %) | RevenueCat | Costo variable (uso) | Costo de pruebas | Margen de contribución | Costos fijos | Resultado neto (antes de impuestos) |
|---|---|---|---|---|---|---|---|---|---|
| 10 | bajo 60 | $59.90 | $8.99 | $0.00 | $5.25 | $6.30 | $39.36 | $94.29 | -$54.93 |
| 10 | medio 150 | $59.90 | $8.99 | $0.00 | $13.13 | $6.30 | $31.49 | $94.29 | -$62.80 |
| 10 | completo 300 | $59.90 | $8.99 | $0.00 | $26.25 | $6.30 | $18.36 | $94.29 | -$75.93 |
| 100 | bajo 60 | $599.00 | $89.85 | $0.00 | $52.50 | $63.01 | $393.64 | $94.29 | $299.35 |
| 100 | medio 150 | $599.00 | $89.85 | $0.00 | $131.26 | $63.01 | $314.88 | $94.29 | $220.59 |
| 100 | completo 300 | $599.00 | $89.85 | $0.00 | $262.52 | $63.01 | $183.62 | $94.29 | $89.33 |
| 1000 | bajo 60 | $5,990.00 | $898.50 | $59.90 | $525.05 | $630.05 | $3,876.50 | $94.29 | $3,782.21 |
| 1000 | medio 150 | $5,990.00 | $898.50 | $59.90 | $1,312.61 | $630.05 | $3,088.93 | $94.29 | $2,994.64 |
| 1000 | completo 300 | $5,990.00 | $898.50 | $59.90 | $2,625.23 | $630.05 | $1,776.32 | $94.29 | $1,682.03 |

## 3. Escenarios mensuales — traducción con `claude-opus-5-5` (sin caché, conservador)

Supuestos: 80 % de los minutos con traducción; nuevas pruebas cada mes = 30 % de la base de pago; uso medio de la prueba = 60 min; conversión de prueba a pago = 25 %.

| Clientes de pago | Uso | Ingresos brutos | Comisión tienda (15 %) | RevenueCat | Costo variable (uso) | Costo de pruebas | Margen de contribución | Costos fijos | Resultado neto (antes de impuestos) |
|---|---|---|---|---|---|---|---|---|---|
| 10 | bajo 60 | $59.90 | $8.99 | $0.00 | $30.93 | $37.12 | -$17.13 | $94.29 | -$111.42 |
| 10 | medio 150 | $59.90 | $8.99 | $0.00 | $77.32 | $37.12 | -$63.52 | $94.29 | -$157.81 |
| 10 | completo 300 | $59.90 | $8.99 | $0.00 | $154.65 | $37.12 | -$140.85 | $94.29 | -$235.14 |
| 100 | bajo 60 | $599.00 | $89.85 | $0.00 | $309.29 | $371.15 | -$171.29 | $94.29 | -$265.59 |
| 100 | medio 150 | $599.00 | $89.85 | $0.00 | $773.23 | $371.15 | -$635.23 | $94.29 | -$729.52 |
| 100 | completo 300 | $599.00 | $89.85 | $0.00 | $1,546.46 | $371.15 | -$1,408.46 | $94.29 | -$1,502.76 |
| 1000 | bajo 60 | $5,990.00 | $898.50 | $59.90 | $3,092.92 | $3,711.51 | -$1,772.83 | $94.29 | -$1,867.13 |
| 1000 | medio 150 | $5,990.00 | $898.50 | $59.90 | $7,732.31 | $3,711.51 | -$6,412.22 | $94.29 | -$6,506.51 |
| 1000 | completo 300 | $5,990.00 | $898.50 | $59.90 | $15,464.62 | $3,711.51 | -$14,144.53 | $94.29 | -$14,238.83 |

## 4. Costo de la prueba gratuita por cliente que paga

| Conversión | Uso medio 30 min | Uso medio 60 min | Uso completo 120 min |
|---|---|---|---|
| 10 % (claude-haiku-5-5) | $2.69 | $5.38 | $10.77 |
| 25 % (claude-haiku-5-5) | $1.08 | $2.15 | $4.31 |
| 40 % (claude-haiku-5-5) | $0.67 | $1.35 | $2.69 |
| 10 % (claude-opus-5-5) | $18.74 | $37.48 | $74.96 |
| 25 % (claude-opus-5-5) | $7.50 | $14.99 | $29.98 |
| 40 % (claude-opus-5-5) | $4.69 | $9.37 | $18.74 |

## 5. Plan Iglesia (fase 2) — una sola transcripción/traducción por fuente

Los minutos NO se multiplican por asistentes. El costo por asistente es solo tráfico de texto (~3 KB/min).

| Modelo | Asistentes | Minutos | Costo IA+voz | Tráfico de texto | Costo total | Ingreso neto (tienda 15 %) | Margen |
|---|---|---|---|---|---|---|---|
| claude-haiku-5-5 | 10 | 300 | $2.69 | $0.00 | $2.69 | $25.49 | $22.80 |
| claude-haiku-5-5 | 10 | 600 | $5.38 | $0.00 | $5.38 | $25.49 | $20.11 |
| claude-haiku-5-5 | 30 | 300 | $2.69 | $0.00 | $2.69 | $25.49 | $22.80 |
| claude-haiku-5-5 | 30 | 600 | $5.38 | $0.00 | $5.39 | $25.49 | $20.10 |
| claude-opus-5-5 | 10 | 300 | $18.74 | $0.00 | $18.74 | $25.49 | $6.75 |
| claude-opus-5-5 | 10 | 600 | $37.48 | $0.00 | $37.48 | $25.49 | -$11.99 |
| claude-opus-5-5 | 30 | 300 | $18.74 | $0.00 | $18.74 | $25.49 | $6.75 |
| claude-opus-5-5 | 30 | 600 | $37.48 | $0.00 | $37.49 | $25.49 | -$11.99 |

## 6. Sensibilidad: comisión estándar de Apple (30 %)

- `claude-haiku-5-5`: ingreso neto $4.19, costo con uso completo $2.69 → margen $1.50
- `claude-opus-5-5`: ingreso neto $4.19, costo con uso completo $18.74 → margen -$14.55

## 7. Supuestos usados

```
stt_usd_min: 0.0077
stt_promo_usd_min: 0.0048
keyterm_usd_min: 0.0013
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
