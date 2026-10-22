"""Generate the README illustrations (animated SVGs) in docs/assets/.

Usage:
    uv run python scripts/make_readme_assets.py

Colours follow Atom Learning's palette (primary blue #2986ff, navy #15245e, brand green / yellow /
red). The conversion curve is drawn from the STA seeds; the other numbers are from the verification
run recorded in the README (2026-10-22). Re-run this after the numbers change.
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "assets"

BLUE, BLUE_DARK, NAVY, INK = "#2986ff", "#0f67f5", "#15245e", "#0c132c"
SKY, SKY_2, SKY_3, SKY_4 = "#f3f8ff", "#e5f1ff", "#c2dfff", "#99c9ff"
GREEN, YELLOW, RED, GREY = "#4fbf5e", "#ffb61a", "#f75050", "#5d6c7b"
FONT = "Inter, 'Segoe UI', Helvetica, Arial, sans-serif"
HEAD = "'National B Condensed', 'Arial Narrow', 'Roboto Condensed', 'Segoe UI', sans-serif"

STYLE = f"""
  .t {{ font-family: {FONT}; fill: {NAVY}; }}
  .h {{ font-family: {HEAD}; font-weight: 800; fill: {NAVY}; }}
  .cap {{ font-family: {FONT}; font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; }}
"""


def svg(name, w, h, body, extra_style=""):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
        f'role="img">\n<style>{STYLE}{extra_style}</style>\n{body}\n</svg>\n', encoding="utf-8")
    print("wrote", (OUT / name).relative_to(ROOT))


def card(x, y, w, h, fill="#ffffff", stroke=SKY_3, r=18, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="2" {extra}/>'


def text(x, y, s, size=18, cls="t", anchor="start", weight=400, fill=None, extra=""):
    f = f' style="fill:{fill}"' if fill else ""
    return (f'<text x="{x}" y="{y}" class="{cls}" font-size="{size}" font-weight="{weight}" '
            f'text-anchor="{anchor}"{f} {extra}>{s}</text>')


def fade_in(begin, dur=8, show=0.08):
    """Opacity animation: appear at `begin` seconds, stay, fade near the end of a `dur` loop."""
    k1 = begin / dur
    return (f'<animate attributeName="opacity" dur="{dur}s" repeatCount="indefinite" '
            f'values="0;0;1;1;0" keyTimes="0;{k1:.3f};{min(k1 + show, 0.9):.3f};0.92;1"/>')


# --------------------------------------------------------------------------------------- hero
def hero():
    chips = [(700, 236, "108", 0), (760, 70, "97", 1.3), (1080, 250, "114", 2.6), (720, 150, "101", 3.9)]
    chip_svg = ""
    for x, y, s, d in chips:
        chip_svg += f"""
  <g opacity="0">
    <rect x="{x}" y="{y}" width="78" height="40" rx="20" fill="#ffffff" opacity="0.95"/>
    <text x="{x + 39}" y="{y + 27}" class="h" font-size="22" text-anchor="middle" fill="{BLUE}">{s}</text>
    <animate attributeName="opacity" values="0;1;1;0" keyTimes="0;0.15;0.75;1" dur="5.2s" begin="{d}s" repeatCount="indefinite"/>
    <animateTransform attributeName="transform" type="translate" values="0 18;0 0;0 -22" dur="5.2s" begin="{d}s" repeatCount="indefinite"/>
  </g>"""
    orbits = ""
    for i, rot in enumerate((0, 60, 120)):
        path = "M 870 160 a 110 42 0 1 0 220 0 a 110 42 0 1 0 -220 0"
        orbits += f"""
  <g transform="rotate({rot} 980 160)">
    <path d="{path}" fill="none" stroke="{SKY_4}" stroke-width="2" opacity="0.55"/>
    <circle r="8" fill="{[YELLOW, GREEN, '#ffffff'][i]}">
      <animateMotion dur="{4 + i}s" repeatCount="indefinite" path="{path}"/>
    </circle>
  </g>"""
    body = f"""
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{NAVY}"/><stop offset="1" stop-color="{BLUE_DARK}"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="320" rx="28" fill="url(#bg)"/>
  <circle cx="1130" cy="40" r="120" fill="{BLUE}" opacity="0.25"/>
  <circle cx="80" cy="330" r="140" fill="{BLUE}" opacity="0.18"/>
  {text(64, 92, "TAKE-HOME TASK · DATA ENGINEERING", 16, "cap", fill=SKY_4)}
  {text(64, 158, "SATs-style scaled scores", 62, "h", fill="#ffffff")}
  {text(64, 206, "From raw pupil activity to KS1 &amp; KS2 scaled scores,", 24, fill=SKY_2)}
  {text(64, 238, "re-runnable and point-in-time, with dbt on BigQuery.", 24, fill=SKY_2)}
  <rect x="64" y="262" width="96" height="6" rx="3" fill="{YELLOW}"/>
  {chip_svg}
  {orbits}
  <circle cx="980" cy="160" r="22" fill="{YELLOW}"/>
  <circle cx="980" cy="160" r="22" fill="none" stroke="{YELLOW}" stroke-width="3">
    <animate attributeName="r" values="22;40" dur="2.4s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="0.8;0" dur="2.4s" repeatCount="indefinite"/>
  </circle>"""
    svg("hero.svg", 1200, 320, body)


# -------------------------------------------------------------------------------------- stats
def stats():
    tiles = [("63,707", "responses profiled", BLUE), ("242", "pupils", NAVY),
             ("399", "pupil × subject scores", GREEN), ("45 ✓", "dbt tests passing", BLUE_DARK)]
    body = f'<rect width="1200" height="170" rx="24" fill="{SKY}"/>'
    for i, (n, label, colour) in enumerate(tiles):
        x = 24 + i * 292
        body += f"""
  <g opacity="0">
    {card(x, 24, 268, 122, r=20)}
    <rect x="{x}" y="24" width="8" height="122" rx="4" fill="{colour}"/>
    {text(x + 134, 92, n, 46, "h", "middle", fill=colour)}
    {text(x + 134, 124, label, 17, anchor="middle", fill=GREY)}
    <animate attributeName="opacity" from="0" to="1" begin="{0.25 * i}s" dur="0.6s" fill="freeze"/>
    <animateTransform attributeName="transform" type="translate" from="0 14" to="0 0" begin="{0.25 * i}s" dur="0.6s" fill="freeze"/>
  </g>"""
    svg("stats.svg", 1200, 170, body)


# ------------------------------------------------------------------------------------ pipeline
def pipeline():
    w, h = 250, 52
    cols = {"raw": 36, "stg": 336, "trf": 636, "ready": 920}
    boxes = {
        "r_resp": ("raw", 96, "responses", "63,707 rows"),
        "r_sit": ("raw", 160, "assessment_sittings", "2,509 rows"),
        "r_pup": ("raw", 224, "pupils", "242 rows"),
        "r_hier": ("raw", 288, "course_hierarchy", "10,552 questions"),
        "r_sta": ("raw", 392, "GOV.UK · STA tables", "KS1 + KS2, 2024–26"),
        "s_resp": ("stg", 96, "stg_responses", "view"),
        "s_sit": ("stg", 160, "stg_assessment_sittings", "view · key stage"),
        "s_pup": ("stg", 224, "stg_pupils", "view"),
        "s_hier": ("stg", 288, "stg_course_hierarchy", "view"),
        "s_conv": ("stg", 392, "stg_scaled_score_conversion", "seeds unioned"),
        "t_ks": ("trf", 120, "trf_assessment_key_stage", "majority key stage"),
        "t_daily": ("trf", 220, "trf_pupil_subject_daily", "incremental · 3-day lookback"),
        "t_look": ("trf", 392, "trf_percent_to_scaled_score", "% → scaled score lookup"),
        "y_year": ("ready", 250, "pupil_subject_year_scores", "per year group"),
        "y_app": ("ready", 340, "pupil_subject_sats_scores", "the app table"),
    }
    styles = {"raw": ("#ffffff", SKY_3, NAVY), "stg": (SKY, SKY_3, NAVY), "trf": (SKY_2, SKY_4, NAVY),
              "ready": (BLUE, BLUE, "#ffffff")}
    body = f'<rect width="1200" height="480" rx="24" fill="#ffffff" stroke="{SKY_2}" stroke-width="2"/>'
    for col, label in (("raw", "RAW · de_raw"), ("stg", "STAGING"), ("trf", "TRANSFORM"), ("ready", "READY")):
        body += text(cols[col] + w / 2, 56, label, 15, "cap", "middle", fill=BLUE)

    edges = [("r_resp", "s_resp"), ("r_sit", "s_sit"), ("r_pup", "s_pup"), ("r_hier", "s_hier"),
             ("r_sta", "s_conv"), ("s_sit", "t_ks"), ("s_resp", "t_daily"), ("s_sit", "t_daily"),
             ("s_pup", "t_daily"), ("s_hier", "t_daily"), ("t_ks", "t_daily"), ("s_conv", "t_look"),
             ("t_daily", "y_year"), ("t_look", "y_year"), ("y_year", "y_app")]

    def anchor(key, side):
        col, y, *_ = boxes[key]
        return (cols[col] + (w if side == "r" else 0), y + h / 2)

    paths = ""
    for i, (a, b) in enumerate(edges):
        (x1, y1), (x2, y2) = anchor(a, "r"), anchor(b, "l")
        if a == "t_ks" and b == "t_daily":  # vertical hop within the transform column
            x1, y1, x2, y2 = cols["trf"] + w / 2, 120 + h, cols["trf"] + w / 2, 220
            d = f"M {x1} {y1} L {x2} {y2}"
        elif a == "y_year":
            x1, y1, x2, y2 = cols["ready"] + w / 2, 250 + h, cols["ready"] + w / 2, 340
            d = f"M {x1} {y1} L {x2} {y2}"
        else:
            d = f"M {x1} {y1} C {x1 + 50} {y1}, {x2 - 50} {y2}, {x2} {y2}"
        paths += f'\n  <path d="{d}" fill="none" stroke="{SKY_3}" stroke-width="2.5"/>'
        colour = YELLOW if a in ("r_sta", "s_conv", "t_look") else BLUE
        paths += (f'\n  <circle r="5" fill="{colour}"><animateMotion dur="2.6s" begin="{(i % 5) * 0.5}s" '
                  f'repeatCount="indefinite" path="{d}"/></circle>')
    body += paths
    for key, (col, y, title, sub) in boxes.items():
        fill, stroke, ink = styles[col]
        if key == "r_sta":
            fill, stroke = "#fff4e0", YELLOW
        if key in ("t_daily", "y_app"):
            stroke = YELLOW
        x = cols[col]
        body += f"""
  {card(x, y, w, h, fill, stroke, r=14)}
  {text(x + 16, y + 23, title, 15, weight=700, fill=ink)}
  {text(x + 16, y + 42, sub, 13, fill=ink if col == "ready" else GREY)}"""
    svg("pipeline.svg", 1200, 480, body)


# ------------------------------------------------------------------------------------- scoring
def scoring():
    steps = [
        ("1 · ADD UP", "157 / 181", "answers correct", "Year 2 · English"),
        ("2 · % CORRECT", "86%", "86.7%, rounded down", ""),
        ("3 · RAW MARKS", "34 · 34", "GPS /40 · reading /40", "⌊86 × 40 / 100⌋"),
        ("4 · STA TABLES", "109 · 107", "KS1 2025 tables", "GPS · reading"),
        ("5 · SCALED SCORE", "108", "½ GPS + ½ reading", "KS1 scale 85–115"),
    ]
    dur = 9
    body = f'<rect width="1200" height="300" rx="24" fill="{SKY}"/>'
    for i, (cap, big, mid, small) in enumerate(steps):
        x = 24 + i * 234
        final = i == len(steps) - 1
        fill, ink, sub = (BLUE, "#ffffff", SKY_2) if final else ("#ffffff", BLUE, GREY)
        arrow = "" if final else (f'<path d="M {x + 214} 150 l 14 0 m -6 -7 l 7 7 l -7 7" fill="none" '
                                  f'stroke="{SKY_4}" stroke-width="3" stroke-linecap="round"/>')
        bar = ""
        if i == 1:
            bar = f"""<rect x="{x + 22}" y="196" width="166" height="12" rx="6" fill="{SKY_2}"/>
    <rect x="{x + 22}" y="196" width="0" height="12" rx="6" fill="{GREEN}">
      <animate attributeName="width" from="0" to="143" begin="1.2s" dur="1s" fill="freeze"/>
    </rect>"""
        body += f"""
  <g opacity="0">
    {card(x, 40, 210, 220, fill, BLUE if final else SKY_3, r=20)}
    {text(x + 105, 78, cap, 13, "cap", "middle", fill=sub if final else BLUE)}
    {text(x + 105, 142, big, 44 if len(big) < 8 else 34, "h", "middle", fill=ink)}
    {text(x + 105, 178, mid, 15, anchor="middle", fill=sub)}
    {text(x + 105, 232, small, 14, anchor="middle", fill=sub)}
    {bar}
    <animate attributeName="opacity" from="0" to="1" begin="{0.2 + i * 0.8:.1f}s" dur="0.6s" fill="freeze"/>
    <animateTransform attributeName="transform" type="translate" from="0 16" to="0 0" begin="{0.2 + i * 0.8:.1f}s" dur="0.6s" fill="freeze"/>
  </g>
  {arrow}"""
    svg("scoring.svg", 1200, 300, body)


# --------------------------------------------------------------------------------------- curve
def curve():
    def table(ks, year, test):
        rows = {}
        path = ROOT / "seeds" / "scaled_scores" / f"seed_scaled_scores_{ks}_{year}.csv"
        with path.open(encoding="utf-8") as f:
            for r in csv.DictReader(f):
                if r["test_name"] == test:
                    rows[int(r["raw_score"])] = (int(r["scaled_score"]) if r["scaled_score"] else int(r["min_scaled_score"]),
                                                 int(r["max_raw_score"]))
        return rows

    x0, y0, pw, ph = 110, 430, 1040, 340  # plot origin (bottom-left), width, height

    def px(p):
        return x0 + p / 100 * pw

    def py(s):
        return y0 - (s - 80) / 40 * ph

    def line_for(rows):
        max_raw = next(iter(rows.values()))[1]
        pts = []
        for p in range(0, 101):
            s = rows[p * max_raw // 100][0]
            pts.append(f"{px(p):.1f},{py(s):.1f}")
        return "M " + " L ".join(pts)

    ks2, ks1 = table("ks2", 2025, "maths"), table("ks1", 2025, "maths")
    grid = ""
    for s in range(80, 121, 10):
        grid += f'<line x1="{x0}" y1="{py(s)}" x2="{x0 + pw}" y2="{py(s)}" stroke="{SKY_2}" stroke-width="1.5"/>'
        grid += text(x0 - 14, py(s) + 6, s, 15, anchor="end", fill=GREY)
    for p in range(0, 101, 20):
        grid += text(px(p), y0 + 30, f"{p}%", 15, anchor="middle", fill=GREY)
    draw = """
  .draw { stroke-dasharray: 2600; stroke-dashoffset: 2600; animation: draw 3.2s ease-out forwards; }
  .draw2 { animation-delay: 0.8s; }
  @keyframes draw { to { stroke-dashoffset: 0; } }
  .pop { opacity: 0; animation: pop 0.6s ease-out 3.4s forwards; }
  @keyframes pop { to { opacity: 1; } }
"""
    body = f"""
  <rect width="1200" height="520" rx="24" fill="#ffffff" stroke="{SKY_2}" stroke-width="2"/>
  {text(40, 50, "% CORRECT → SCALED SCORE · MATHS, 2025 TABLES", 15, "cap", fill=BLUE)}
  {grid}
  <line x1="{x0}" y1="{py(100)}" x2="{x0 + pw}" y2="{py(100)}" stroke="{YELLOW}" stroke-width="2.5" stroke-dasharray="8 6"/>
  {text(x0 + 8, py(100) - 10, "expected standard (100)", 14, fill="#bd4b00", weight=700)}
  <line x1="{px(0)}" y1="{py(80)}" x2="{px(100)}" y2="{py(120)}" stroke="{GREY}" stroke-width="2" stroke-dasharray="4 7" opacity="0.6"/>
  <path class="draw" d="{line_for(ks2)}" fill="none" stroke="{BLUE}" stroke-width="4" stroke-linejoin="round"/>
  <path class="draw draw2" d="{line_for(ks1)}" fill="none" stroke="{GREEN}" stroke-width="4" stroke-linejoin="round"/>
  <g class="pop">
    <circle cx="{px(90)}" cy="{py(112)}" r="8" fill="{BLUE}"/>
    <circle cx="{px(90)}" cy="{py(116)}" r="7" fill="#ffffff" stroke="{GREY}" stroke-width="2.5"/>
    <line x1="{px(90)}" y1="{py(112) + 8}" x2="{px(90)}" y2="{py(101)}" stroke="{BLUE}" stroke-width="2"/>
    {text(px(90), py(101) + 22, "90% → 112 on the table", 15, anchor="middle", weight=700, fill=BLUE)}
    {text(px(90) - 16, py(116) - 12, "a straight line would say 116", 14, anchor="end", fill=GREY)}
  </g>
  <g transform="translate(130 80)">
    {card(0, 0, 380, 96, SKY, SKY_2, 14)}
    <line x1="20" y1="30" x2="56" y2="30" stroke="{BLUE}" stroke-width="4"/>{text(68, 36, "KS2 maths (80–120)", 16, weight=700)}
    <line x1="20" y1="62" x2="56" y2="62" stroke="{GREEN}" stroke-width="4"/>{text(68, 68, "KS1 maths (85–115)", 16, weight=700)}
    <line x1="232" y1="30" x2="264" y2="30" stroke="{GREY}" stroke-width="2" stroke-dasharray="4 6"/>{text(274, 36, "linear", 15, fill=GREY)}
  </g>"""
    svg("curve.svg", 1200, 520, body, draw)


# ---------------------------------------------------------------------------------- key stage
def key_stage():
    import random
    random.seed(7)

    def tokens(x, y, n_ok, n_bad, ok_col, bad_col, label_ok, label_bad):
        out = ""
        cells = [(ok_col, False)] * n_ok + [(bad_col, True)] * n_bad
        random.shuffle(cells)
        for i, (col, bad) in enumerate(cells):
            cx, cy = x + 30 + (i % 9) * 40, y + 30 + (i // 9) * 40
            if bad:
                out += f"""
    <g>
      <circle cx="{cx}" cy="{cy}" r="14" fill="{col}" opacity="0.35"/>
      <circle cx="{cx}" cy="{cy}" r="16" fill="none" stroke="{RED}" stroke-width="2">
        <animate attributeName="r" values="14;22" dur="1.8s" repeatCount="indefinite"/>
        <animate attributeName="opacity" values="0.9;0" dur="1.8s" repeatCount="indefinite"/>
      </circle>
      <path d="M {cx - 8} {cy - 8} L {cx + 8} {cy + 8} M {cx + 8} {cy - 8} L {cx - 8} {cy + 8}" stroke="{RED}" stroke-width="4" stroke-linecap="round"/>
    </g>"""
            else:
                out += f'\n    <circle cx="{cx}" cy="{cy}" r="14" fill="{col}"/>'
        return out

    body = f"""
  <rect width="1200" height="420" rx="24" fill="{SKY}"/>
  {text(40, 50, "EACH ASSESSMENT GETS THE KEY STAGE MOST OF ITS SITTINGS ARE IN", 15, "cap", fill=BLUE)}
  {card(40, 80, 520, 250, r=22)}
  {text(64, 120, "Mainly-KS1 assessment", 24, "h")}
  {text(64, 146, "KS2 pupils' responses here aren't scored", 15, fill=GREY)}
  {tokens(64, 160, 22, 3, GREEN, BLUE, "", "")}
  {card(640, 80, 520, 250, r=22)}
  {text(664, 120, "Mainly-KS2 assessment", 24, "h")}
  {text(664, 146, "KS1 pupils' responses here aren't scored", 15, fill=GREY)}
  {tokens(664, 160, 22, 3, BLUE, GREEN, "", "")}
  <circle cx="60" cy="372" r="11" fill="{GREEN}"/>{text(80, 378, "KS1 pupil (Years 1–2)", 16, weight=700)}
  <circle cx="300" cy="372" r="11" fill="{BLUE}"/>{text(320, 378, "KS2 pupil (Years 3–6)", 16, weight=700)}
  {text(1160, 378, "566 responses dropped · 1.2% of English &amp; Maths · no ties", 16, anchor="end", weight=700, fill=RED)}"""
    svg("key_stage.svg", 1200, 420, body)


# ------------------------------------------------------------------------------ academic year
def academic_year():
    x0, x1 = 60, 1140
    months = [(2025, m) for m in range(1, 13)] + [(2026, m) for m in range(1, 13)]
    step = (x1 - x0) / len(months)

    def mx(year, month):
        return x0 + ((year - 2025) * 12 + month - 1) * step

    ticks = ""
    for (yy, m) in months:
        x = mx(yy, m)
        ticks += f'<line x1="{x}" y1="196" x2="{x}" y2="{206 if m != 1 else 214}" stroke="{SKY_4}" stroke-width="2"/>'
        if m in (1, 6, 9):
            ticks += text(x, 236, f"{['Jan', '', '', '', '', 'Jun', '', '', 'Sep'][m - 1]} {yy}", 14, anchor="middle", fill=GREY)
    body = f"""
  <rect width="1200" height="300" rx="24" fill="#ffffff" stroke="{SKY_2}" stroke-width="2"/>
  {text(40, 50, "WHICH TABLES A SCORE USES: THE ACADEMIC YEAR (SEP–AUG) OF THE PUPIL'S LATEST ANSWER", 15, "cap", fill=BLUE)}
  <rect x="{mx(2025, 9)}" y="120" width="{12 * step}" height="66" rx="14" fill="{BLUE}"/>
  {text(mx(2025, 9) + 20, 150, "Academic year 2025/26", 18, weight=700, fill="#ffffff")}
  {text(mx(2025, 9) + 20, 174, "→ uses the 2025 tables", 16, fill=SKY_2)}
  <rect x="{mx(2026, 9)}" y="120" width="{4 * step}" height="66" rx="14" fill="{SKY_3}"/>
  {text(mx(2026, 9) + 14, 150, "2026/27", 18, weight=700)}
  {text(mx(2026, 9) + 14, 174, "→ 2026 tables", 16, fill=NAVY)}
  <line x1="{x0}" y1="196" x2="{x1}" y2="196" stroke="{SKY_4}" stroke-width="3"/>
  {ticks}
  <g>
    <circle cx="{mx(2025, 6)}" cy="100" r="9" fill="{GREEN}"/><circle cx="{mx(2025, 7)}" cy="100" r="9" fill="{YELLOW}"/>
    {text(mx(2025, 7) + 18, 106, "STA publishes KS1 (Jun) &amp; KS2 (Jul) tables", 14, weight=700)}
  </g>
  <rect x="{mx(2025, 11)}" y="252" width="{mx(2026, 9) + step - mx(2025, 11)}" height="10" rx="5" fill="{GREEN}" opacity="0.8"/>
  {text(mx(2025, 11), 284, "our data: Nov 2025 – Sep 2026", 14, fill=GREEN, weight=700)}

  {text(1140, 284, "calendar year: 2026 tables needed before they exist", 14, anchor="end", fill=RED)}"""
    svg("academic_year.svg", 1200, 300, body)


# -------------------------------------------------------------------------------------- funnel
def funnel():
    rows = [("All responses", 63707, NAVY, ""),
            ("Sitting missing from assessment_sittings", -1433, RED, "excluded"),
            ("Survey sittings (Wellbeing)", -3936, RED, "no right answers"),
            ("Pupil's key stage ≠ assessment's", -566, RED, "KS1 on KS2 or reverse"),
            ("Scored: % correct, every subject", 57772, BLUE, ""),
            ("…of which English &amp; Maths get scaled scores", 45989, GREEN, "")]
    scale = 760 / 63707
    body = f'<rect width="1200" height="430" rx="24" fill="{SKY}"/>'
    body += text(40, 50, "WHICH RESPONSES ARE SCORED", 15, "cap", fill=BLUE)
    for i, (label, n, col, note) in enumerate(rows):
        y = 80 + i * 56
        w = max(abs(n) * scale, 10)
        body += f"""
  {text(40, y + 26, label, 16, weight=700)}
  <rect x="400" y="{y + 6}" width="0" height="30" rx="8" fill="{col}">
    <animate attributeName="width" from="0" to="{w:.0f}" begin="{0.3 * i}s" dur="0.9s" fill="freeze"/>
  </rect>
  {text(400 + w + 12 if w < 600 else 400 + w - 12, y + 27, f"{n:+,}" if n < 0 else f"{n:,}", 16,
        anchor="start" if w < 600 else "end", weight=700, fill=col if w < 600 else "#ffffff")}
  {text(1160, y + 27, note, 14, anchor="end", fill=GREY)}"""
    svg("funnel.svg", 1200, 430, body)


# ------------------------------------------------------------------------------------- results
def results():
    rows = [("English · KS1", [85, 96, 99, 102, 115], 0.50, 48, GREEN, (85, 115)),
            ("English · KS2", [87, 98, 101, 105, 120], 0.65, 106, BLUE, (80, 120)),
            ("Maths · KS1", [92, 96, 98, 100, 110], 0.40, 48, GREEN, (85, 115)),
            ("Maths · KS2", [80, 97, 101, 105, 114], 0.60, 104, BLUE, (80, 120))]
    x0, pw = 260, 700

    def sx(s):
        return x0 + (s - 80) / 40 * pw

    body = f'<rect width="1200" height="430" rx="24" fill="#ffffff" stroke="{SKY_2}" stroke-width="2"/>'
    body += text(40, 50, "CURRENT SCALED SCORES (MIN · QUARTILES · MAX)", 15, "cap", fill=BLUE)
    body += text(1160, 50, "MEET EXPECTED", 13, "cap", "end", fill=GREY)
    for s in range(80, 121, 10):
        body += f'<line x1="{sx(s)}" y1="76" x2="{sx(s)}" y2="380" stroke="{SKY_2}" stroke-width="1.5"/>'
        body += text(sx(s), 404, s, 14, anchor="middle", fill=GREY)
    body += f'<line x1="{sx(100)}" y1="70" x2="{sx(100)}" y2="384" stroke="{YELLOW}" stroke-width="2.5" stroke-dasharray="7 6"/>'
    for i, (label, (lo, q1, med, q3, hi), pct, n, col, (smin, smax)) in enumerate(rows):
        y = 104 + i * 72
        body += f"""
  {text(40, y + 6, label, 18, weight=700)}
  {text(40, y + 28, f"{n} pupils", 14, fill=GREY)}
  <rect x="{sx(smin)}" y="{y - 22}" width="{sx(smax) - sx(smin)}" height="44" rx="10" fill="{SKY}"/>
  <g opacity="0">
    <line x1="{sx(lo)}" y1="{y}" x2="{sx(hi)}" y2="{y}" stroke="{col}" stroke-width="3"/>
    <rect x="{sx(q1)}" y="{y - 14}" width="{sx(q3) - sx(q1)}" height="28" rx="7" fill="{col}" opacity="0.85"/>
    <line x1="{sx(med)}" y1="{y - 18}" x2="{sx(med)}" y2="{y + 18}" stroke="{NAVY}" stroke-width="4"/>
    {text(sx(med), y - 24, med, 14, anchor="middle", weight=700)}
    <animate attributeName="opacity" from="0" to="1" begin="{0.3 * i}s" dur="0.7s" fill="freeze"/>
  </g>
  <rect x="1010" y="{y - 10}" width="150" height="20" rx="10" fill="{SKY_2}"/>
  <rect x="1010" y="{y - 10}" width="0" height="20" rx="10" fill="{col}">
    <animate attributeName="width" from="0" to="{150 * pct:.0f}" begin="{0.3 * i + 0.4}s" dur="0.9s" fill="freeze"/>
  </rect>
  {text(1085, y + 36, f"{pct:.0%}", 14, anchor="middle", weight=700, fill=col)}"""
    body += text(sx(80), 424, "shaded band = the key stage's scale", 13, fill=GREY)
    svg("results.svg", 1200, 430, body)


# ---------------------------------------------------------------------------------------- gcse
def gcse():
    feats = [("Scores, Year 1 → Year 6", "scaled score + % per subject", BLUE),
             ("% correct elsewhere", "Screeners, VR / NVR aptitude", BLUE),
             ("Engagement", "volume, consistency, skips, time", GREEN),
             ("Context (with care)", "school, deprivation (IDACI)", YELLOW)]
    probs = [0.01, 0.02, 0.04, 0.09, 0.17, 0.24, 0.22, 0.14, 0.07]  # illustrative grades 1-9
    body = f'<rect width="1200" height="400" rx="24" fill="{SKY}"/>'
    body += text(40, 50, "ILLUSTRATIVE: FROM SCORES TO A GCSE GRADE DISTRIBUTION", 15, "cap", fill=BLUE)
    for i, (title, sub, col) in enumerate(feats):
        y = 78 + i * 74
        body += f"""
  {card(40, y, 330, 60, r=14)}
  <rect x="40" y="{y}" width="8" height="60" rx="4" fill="{col}"/>
  {text(62, y + 26, title, 17, weight=700)}
  {text(62, y + 47, sub, 14, fill=GREY)}
  <path d="M 370 {y + 30} C 420 {y + 30}, 430 200, 480 200" fill="none" stroke="{SKY_4}" stroke-width="2.5"/>
  <circle r="5" fill="{col}"><animateMotion dur="2.2s" begin="{0.4 * i}s" repeatCount="indefinite" path="M 370 {y + 30} C 420 {y + 30}, 430 200, 480 200"/></circle>"""
    body += f"""
  {card(480, 140, 230, 120, BLUE, BLUE, 22)}
  {text(595, 182, "XGBoost", 28, "h", "middle", fill="#ffffff")}
  {text(595, 210, "· LightGBM ·", 18, anchor="middle", fill="#ffffff", weight=700)}
  {text(595, 238, "per GCSE subject", 15, anchor="middle", fill=SKY_2)}
  <path d="M 710 200 L 770 200" stroke="{SKY_4}" stroke-width="3"/><path d="M 762 192 l 8 8 l -8 8" fill="none" stroke="{SKY_4}" stroke-width="3"/>
  {card(780, 70, 380, 290, r=22)}
  {text(800, 104, "P(grade) for one pupil, GCSE Maths", 15, weight=700)}"""
    for g, p in enumerate(probs, 1):
        x = 806 + (g - 1) * 38
        hgt = p * 640
        col = GREEN if g >= 4 else SKY_4
        body += f"""
  <rect x="{x}" y="{320 - hgt:.0f}" width="26" height="{hgt:.0f}" rx="6" fill="{col}">
    <animate attributeName="height" from="0" to="{hgt:.0f}" begin="{0.15 * g}s" dur="0.8s" fill="freeze"/>
    <animate attributeName="y" from="320" to="{320 - hgt:.0f}" begin="{0.15 * g}s" dur="0.8s" fill="freeze"/>
  </rect>
  {text(x + 13, 344, g, 14, anchor="middle", fill=GREY)}"""
    body += text(800, 130, "P(grade 4 or above) = 93%", 16, weight=700, fill=GREEN)
    svg("gcse.svg", 1200, 400, body)


if __name__ == "__main__":
    for fn in (hero, stats, pipeline, scoring, curve, key_stage, academic_year, funnel, results, gcse):
        fn()
