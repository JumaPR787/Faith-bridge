#!/usr/bin/env python3
"""
Genera el sitio web estático de FaithBridge (website/public/).

Uso:
  pip install markdown
  python3 scripts/build_website.py --company "Tu Empresa LLC" --support-email soporte@tudominio.com \
      --deletion-days 30 --backup-days 30

Páginas: inicio, privacidad, términos, eliminar cuenta, soporte.
Las páginas legales salen de docs/legal/*.md. Si todavía contienen campos
[entre corchetes] o la marca BORRADOR, el script se NIEGA a generar el sitio,
salvo con --allow-draft (añade una franja visible «BORRADOR — no publicar»).
"""
import argparse
import html
import shutil
import re
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
PAGES = ROOT / "website" / "pages"
LEGAL = ROOT / "docs" / "legal"
OUT = ROOT / "website" / "public"

CSS = """
:root{--bg:#fbfaf7;--fg:#1d2430;--muted:#4a5568;--accent:#2f4a6d;--card:#fff;--line:#e4e1da}
@media (prefers-color-scheme:dark){:root{--bg:#12161d;--fg:#eef1f5;--muted:#b8c0cc;--accent:#9fc1ea;--card:#1a2029;--line:#2c3440}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:18px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:760px;margin:0 auto;padding:32px 20px 64px}a{color:var(--accent)}h1{font-size:1.9rem;line-height:1.25}
h2{margin-top:2rem;border-top:1px solid var(--line);padding-top:1.2rem}blockquote{margin:1rem 0;padding:.6rem 1rem;border-left:4px solid var(--accent);background:var(--card)}
nav{font-size:.95rem;margin-bottom:24px}nav a{margin-right:14px}.draft{background:#b42318;color:#fff;padding:10px;text-align:center;font-weight:700}
footer{margin-top:48px;color:var(--muted);font-size:.9rem}
"""

NAV = ('<nav aria-label="Sitio"><a href="index.html">FaithBridge</a><a href="privacidad.html">Privacidad</a>'
       '<a href="terminos.html">Términos</a><a href="eliminar-cuenta.html">Eliminar cuenta</a><a href="soporte.html">Soporte</a></nav>')

PLACEHOLDER = re.compile(r"\[(?!\?\])[^\]\n]{2,80}\](?!\()")


def render(title: str, body_md: str, draft: bool, lang: str = "es") -> str:
    body = markdown.markdown(body_md, extensions=["extra", "sane_lists"])
    banner = '<div class="draft" role="alert">BORRADOR — NO PUBLICAR / DRAFT — DO NOT PUBLISH</div>' if draft else ""
    return f"""<!doctype html>
<html lang="{lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><meta name="robots" content="index,follow"><style>{CSS}</style></head>
<body>{banner}<main>{NAV}{body}<footer>FaithBridge</footer></main></body></html>
"""


def split_front(text: str) -> tuple[str, str]:
    m = re.match(r"^---\ntitle: (.+?)\n---\n", text)
    return (m.group(1), text[m.end():]) if m else ("FaithBridge", text)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--company", required=True)
    ap.add_argument("--support-email", required=True)
    ap.add_argument("--deletion-days", default="30")
    ap.add_argument("--backup-days", default="30")
    ap.add_argument("--allow-draft", action="store_true")
    a = ap.parse_args()

    subs = {"{{COMPANY}}": a.company, "{{SUPPORT_EMAIL}}": a.support_email,
            "{{DELETION_DAYS}}": a.deletion_days, "{{BACKUP_DAYS}}": a.backup_days}

    def fill(t: str) -> str:
        for k, v in subs.items():
            t = t.replace(k, v)
        return t

    problems = []
    legal = {}
    for name, src in (("privacidad", "politica-privacidad.md"), ("terminos", "terminos.md")):
        text = (LEGAL / src).read_text(encoding="utf-8")
        # Quita la nota interna para revisión legal (líneas que empiezan con ">").
        text = "\n".join(l for l in text.splitlines() if not l.startswith(">"))
        found = sorted(set(PLACEHOLDER.findall(text)))
        if found or "BORRADOR" in text:
            problems.append(f"{src}: {len(found)} campos por completar {found[:6]}{'…' if len(found) > 6 else ''}"
                            + ("; contiene la palabra BORRADOR" if "BORRADOR" in text else ""))
        legal[name] = text

    if problems and not a.allow_draft:
        print("NO se generó el sitio: los textos legales no están listos para publicar.", file=sys.stderr)
        for p in problems:
            print(" -", p, file=sys.stderr)
        print("Completa y haz revisar docs/legal/*.md, o usa --allow-draft para una vista previa (con franja BORRADOR).", file=sys.stderr)
        return 1

    draft = bool(problems)
    if OUT.exists():
        shutil.rmtree(OUT)  # sin restos de versiones anteriores
    OUT.mkdir(parents=True)
    for p in PAGES.glob("*.md"):
        title, body = split_front(p.read_text(encoding="utf-8"))
        (OUT / f"{p.stem}.html").write_text(render(title, fill(body), draft), encoding="utf-8")
    for name, text in legal.items():
        title = "Política de privacidad — FaithBridge" if name == "privacidad" else "Términos de uso — FaithBridge"
        (OUT / f"{name}.html").write_text(render(title, fill(text), draft), encoding="utf-8")
    # Archivos estáticos de Cloudflare Pages (_headers, etc.).
    for f in (ROOT / "website" / "static").glob("*"):
        if f.is_file():
            (OUT / f.name).write_bytes(f.read_bytes())
    print(f"Sitio generado en {OUT} ({'BORRADOR' if draft else 'listo para publicar'})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
