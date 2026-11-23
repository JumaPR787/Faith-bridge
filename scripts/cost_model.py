#!/usr/bin/env python3
"""
Modelo de costos de FaithBridge (reproducible).

Uso:  python3 scripts/cost_model.py > docs/costos-escenarios.md

TODAS las tarifas y supuestos están en SUPUESTOS. Cámbialos cuando tengas
contratos o mediciones reales; no son garantías ni promesas de ganancia.
Fecha de consulta de tarifas: 2026-11-23 (ver docs/costos.md para fuentes y
qué cifras no se pudieron verificar en la página oficial).
"""

SUPUESTOS = {
    # ── Reconocimiento de voz (Deepgram Nova-3 monolingüe, streaming) ──
    "stt_usd_min": 0.0077,          # tarifa regular pay-as-you-go (conservadora)
    "stt_promo_usd_min": 0.0048,    # tarifa promocional mostrada en la web oficial (vence 2026-12-31)
    "keyterm_usd_min": 0.0013,      # cifra de terceros, sin verificar
    "keyterms_enabled": True,       # activados (glosario cristiano en el reconocimiento)
    # ── Traducción: tokens por minuto de predicación (medido sobre el prompt real) ──
    "segments_per_min": 7,          # cortes por pausa/oración (~8-9 s cada uno)
    "input_tokens_per_segment": 1350,  # ~1,150 de sistema (reglas+glosario+libros) + ~200 de contexto y segmento
    "system_tokens": 1150,
    "chars_per_min": 850,           # texto hablado por minuto (para traductores por carácter)
    "models": {
        # nombre: (USD/M entrada, USD/M salida, USD/M lectura de caché, tokens de salida por segmento)
        "claude-opus-5-5": (4.00, 20.00, 0.20, 120),   # razonamiento no desactivable: más salida
        "claude-sonnet-5-5": (2.00, 10.00, 0.10, 80),
        "claude-haiku-5-5": (0.10, 0.50, 0.01, 45),    # caché: supuesto 10 % de la entrada
    },
    "google_nmt_usd_per_mchar": 20.0,
    # ── Infraestructura ──
    "audio_mb_per_min": 1.92,       # PCM16 16 kHz mono (subida teléfono→backend→proveedor)
    "egress_usd_per_gb": 0.02,      # Fly.io, salida en Norteamérica (backend→Deepgram)
    "fixed_monthly": {
        "Supabase Pro (base de datos + auth)": 25.0,
        "Fly.io: 1 máquina shared-cpu-2x 1 GB": 6.89,
        "Monitoreo / correo / dominio": 20.0,
        "Cuentas de desarrollador (Apple 99/año + Google 25 único, prorrateado)": 8.25 + 25 / 24,
    },
    # ── Tienda y suscripción ──
    "price_personal": 5.99,
    "price_church": 29.99,
    "store_fee": 0.15,              # Apple Small Business Program / Google suscripciones
    "store_fee_standard": 0.30,     # Apple sin programa (primer año de cada suscripción)
    "revenuecat_free_mtr": 2500.0,
    "revenuecat_pct": 0.01,
    # ── Uso ──
    "quota_personal_min": 300,
    "quota_trial_min": 120,
    "quota_church_min": 600,
}

S = SUPUESTOS


def translation_cost_per_min(model: str, cached: bool) -> float:
    pin, pout, pcache, out_tok = S["models"][model]
    n = S["segments_per_min"]
    if cached:
        inp = (S["system_tokens"] * pcache + (S["input_tokens_per_segment"] - S["system_tokens"]) * pin) / 1e6
    else:
        inp = S["input_tokens_per_segment"] * pin / 1e6
    return n * (inp + out_tok * pout / 1e6)


def google_cost_per_min() -> float:
    return S["chars_per_min"] * S["google_nmt_usd_per_mchar"] / 1e6


def egress_per_min() -> float:
    return S["audio_mb_per_min"] / 1024 * S["egress_usd_per_gb"]


def var_cost_per_min(model: str, cached=False, translate_share=1.0, stt=None) -> float:
    if stt is None:
        stt = S["stt_usd_min"] + (S["keyterm_usd_min"] if S["keyterms_enabled"] else 0.0)
    return stt + egress_per_min() + translate_share * translation_cost_per_min(model, cached)


def revenuecat_fee(mtr: float) -> float:
    # Gratis hasta 2,500 USD de ingreso mensual rastreado; por encima, 1 % de TODO lo rastreado.
    return mtr * S["revenuecat_pct"] if mtr > S["revenuecat_free_mtr"] else 0.0


def money(x: float) -> str:
    sign = "-" if x < 0 else ""
    return f"{sign}${abs(x):,.2f}"


def main() -> None:
    out = []
    p = out.append
    p("# Escenarios de costos (generado por `scripts/cost_model.py`)\n")
    p("> Cifras **estimadas** con los supuestos del script (tarifas consultadas el 2026-11-23). "
      "No son garantía de resultados. Medir costos reales en sandbox antes de fijar precios.\n")

    p("## 1. Costo variable por minuto de audio\n")
    p("| Componente | USD / minuto |")
    p("|---|---|")
    p(f"| Deepgram Nova-3 streaming (regular) | {S['stt_usd_min']:.4f} |")
    p(f"| Deepgram Nova-3 streaming (promoción hasta 2026-12-31) | {S['stt_promo_usd_min']:.4f} |")
    p(f"| Keyterms de Deepgram ({'activados' if S['keyterms_enabled'] else 'desactivados'}) | +{S['keyterm_usd_min']:.4f} |")
    p(f"| Tráfico de salida del audio (Fly.io) | {egress_per_min():.5f} |")
    for m in S["models"]:
        p(f"| Traducción {m} (sin caché) | {translation_cost_per_min(m, False):.4f} |")
        p(f"| Traducción {m} (con caché del prompt) | {translation_cost_per_min(m, True):.4f} |")
    p(f"| Traducción Google Cloud NMT (referencia, sin contexto) | {google_cost_per_min():.4f} |")
    p("")
    p("Un minuto se cobra UNA vez aunque se muestren transcripción y traducción; "
      "en modo «solo transcripción» no hay costo de traducción.\n")

    p("## 2. Costo por usuario Personal al mes según modelo de traducción\n")
    p(f"Precio {money(S['price_personal'])}; ingreso neto tras tienda 15 %: {money(S['price_personal'] * (1 - S['store_fee']))}.\n")
    p("| Modelo | Uso 60 min (bajo) | Uso 150 min (medio) | Uso 300 min (completo) | Margen de contribución con uso completo |")
    p("|---|---|---|---|---|")
    net = S["price_personal"] * (1 - S["store_fee"])
    for m in S["models"]:
        c = var_cost_per_min(m)
        p(f"| {m} | {money(60 * c)} | {money(150 * c)} | {money(300 * c)} | {money(net - 300 * c)} |")
    p("")

    for model in ["claude-haiku-5-5", "claude-opus-5-5"]:
        p(f"## 3. Escenarios mensuales — traducción con `{model}` (sin caché, conservador)\n")
        p("Supuestos: 80 % de los minutos con traducción; nuevas pruebas cada mes = 30 % de la base de pago; "
          "uso medio de la prueba = 60 min; conversión de prueba a pago = 25 %.\n")
        p("| Clientes de pago | Uso | Ingresos brutos | Comisión tienda (15 %) | RevenueCat | Costo variable (uso) | Costo de pruebas | Margen de contribución | Costos fijos | Resultado neto (antes de impuestos) |")
        p("|---|---|---|---|---|---|---|---|---|---|")
        fixed = sum(S["fixed_monthly"].values())
        for n in (10, 100, 1000):
            for label, minutes in (("bajo 60", 60), ("medio 150", 150), ("completo 300", 300)):
                gross = n * S["price_personal"]
                store = gross * S["store_fee"]
                rc = revenuecat_fee(gross)
                cpm = var_cost_per_min(model, translate_share=0.8)
                usage = n * minutes * cpm
                trials = n * 0.30 / 0.25  # pruebas iniciadas para reponer 30 % de la base con 25 % de conversión
                trial_cost = trials * 60 * cpm
                contrib = gross - store - rc - usage - trial_cost
                p(f"| {n} | {label} | {money(gross)} | {money(store)} | {money(rc)} | {money(usage)} | {money(trial_cost)} | {money(contrib)} | {money(fixed)} | {money(contrib - fixed)} |")
        p("")

    p("## 4. Costo de la prueba gratuita por cliente que paga\n")
    p("| Conversión | Uso medio 30 min | Uso medio 60 min | Uso completo 120 min |")
    p("|---|---|---|---|")
    for model in ["claude-haiku-5-5", "claude-opus-5-5"]:
        cpm = var_cost_per_min(model)
        for conv in (0.10, 0.25, 0.40):
            p(f"| {int(conv * 100)} % ({model}) | {money(30 * cpm / conv)} | {money(60 * cpm / conv)} | {money(120 * cpm / conv)} |")
    p("")

    p("## 5. Plan Iglesia (fase 2) — una sola transcripción/traducción por fuente\n")
    p("Los minutos NO se multiplican por asistentes. El costo por asistente es solo tráfico de texto (~3 KB/min).\n")
    p("| Modelo | Asistentes | Minutos | Costo IA+voz | Tráfico de texto | Costo total | Ingreso neto (tienda 15 %) | Margen |")
    p("|---|---|---|---|---|---|---|---|")
    net_c = S["price_church"] * (1 - S["store_fee"])
    for model in ["claude-haiku-5-5", "claude-opus-5-5"]:
        for listeners in (10, 30):
            for minutes in (300, 600):
                core = minutes * var_cost_per_min(model)
                text_gb = listeners * minutes * 3 / 1024 / 1024
                traffic = text_gb * S["egress_usd_per_gb"]
                total = core + traffic
                p(f"| {model} | {listeners} | {minutes} | {money(core)} | {money(traffic)} | {money(total)} | {money(net_c)} | {money(net_c - total)} |")
    p("")

    p("## 6. Sensibilidad: comisión estándar de Apple (30 %)\n")
    for model in ["claude-haiku-5-5", "claude-opus-5-5"]:
        c = var_cost_per_min(model)
        net30 = S["price_personal"] * (1 - S["store_fee_standard"])
        p(f"- `{model}`: ingreso neto {money(net30)}, costo con uso completo {money(300 * c)} → margen {money(net30 - 300 * c)}")
    p("")
    p("## 7. Supuestos usados\n")
    p("```")
    for k, v in S.items():
        p(f"{k}: {v}")
    p("```")
    print("\n".join(out))


if __name__ == "__main__":
    main()
