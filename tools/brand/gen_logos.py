#!/usr/bin/env python3
"""Generate CorpoBiz logo assets: the base logo, the icon, and one 16:9 card per
business module (named from each module's `def.displayName`). Writes SVG, plus
PNG when rsvg-convert is installed. Stdlib only: text is drawn from the outlined
glyphs in glyphs.json (see extract_glyphs.py), so no fonts are needed.

  python3 tools/brand/gen_logos.py           # write assets/brand/
  python3 tools/brand/gen_logos.py --check   # exit 1 if any SVG is missing or stale

Design rules live in BRAND.md.
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "brand"
GLYPHS = json.loads((Path(__file__).parent / "glyphs.json").read_text())

PANEL, FG, MUTED = "#12111b", "#ebe8f5", "#8f8ba8"
YELLOW, CYAN, MAGENTA = "#fcee0a", "#2de2e6", "#ff2a6d"

# A business's name takes the colour of its node on the mark's spine. Add new
# businesses here; unlisted ones get the neutral colour.
ACCENTS = {
    "Rustvale Farm": CYAN,
    "Watson Distillery": MAGENTA,
    "7th Hell": YELLOW,
}

C_SHAPE = "M100 24 L40 24 L22 42 L22 78 L40 96 L100 96 L100 80 L46 80 L38 72 L38 48 L46 40 L100 40 Z"


def n(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def text_paths(text, face, size, x, y, tracking, colors):
    """Outlined text starting at x. colors is a per-character list of fills."""
    g = GLYPHS[face]
    s = size / g["upm"]
    out = []
    for ch, color in zip(text, colors):
        glyph = g["glyphs"].get(ch)
        if glyph is None:
            raise SystemExit(f"no glyph for {ch!r} in {text!r}: extend NAME_CHARS in "
                             "tools/brand/extract_glyphs.py and regenerate glyphs.json")
        if glyph["d"]:
            out.append(f'<path transform="translate({n(x)} {n(y)}) scale({n(s)} {n(-s)})" '
                       f'd="{glyph["d"]}" fill="{color}"/>')
        x += glyph["adv"] * s + tracking
    return "\n".join(out)


def advance(text, face, size):
    g = GLYPHS[face]
    return sum(g["glyphs"][ch]["adv"] for ch in text) * size / g["upm"]


def knock(tag, geom, fill, cut):
    """A shape with a 3px knockout margin around it (reads as cut through what's beneath)."""
    return (f'<{tag} {geom} fill="{cut}" stroke="{cut}" stroke-width="6" stroke-linejoin="miter"/>'
            f'<{tag} {geom} fill="{fill}"/>')


def mark(cut):
    return "\n".join([
        f'<path d="{C_SHAPE}" fill="{YELLOW}"/>',
        knock("polygon", 'points="60,10 68,10 68,110 60,110"', CYAN, cut),
        knock("rect", 'x="58" y="4" width="12" height="12"', CYAN, cut),
        knock("polygon", 'points="64,47 77,60 64,73 51,60"', MAGENTA, cut),
        knock("rect", 'x="58" y="104" width="12" height="12"', YELLOW, cut),
    ])


def card(name):
    """1280x720 logo. name=None gives the base logo (no business line)."""
    shift = 28 if name is None else 0
    word = "CORPOBIZ"
    size = 132
    track = (760 - advance(word, "bold", size)) / (len(word) - 1)
    wordmark = text_paths(word, "bold", size, 260, 552, track, [FG] * 5 + [YELLOW] * 3)

    business = ""
    label = "CorpoBiz"
    if name:
        label = f"CorpoBiz, {name}"
        upper = name.upper()
        size = 40
        width = advance(upper, "medium", size) + 0.32 * size * (len(upper) - 1)
        if width > 880:  # keep long names inside the frame
            size *= 880 / width
            width = 880
        business = text_paths(upper, "medium", size, 640 - width / 2, 640, 0.32 * size,
                              [ACCENTS.get(name, FG)] * len(upper))

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 720" width="1280" height="720" role="img" aria-label="{escape(label, {'"': "&quot;"})}">
<title>{escape(label)}</title>
<defs>
<clipPath id="gl1"><rect x="0" y="29" width="120" height="5"/></clipPath>
<clipPath id="gl2"><rect x="0" y="85" width="120" height="4"/></clipPath>
<filter id="glow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>
<rect width="1280" height="720" fill="{PANEL}"/>
<polygon points="60,32 1248,32 1248,660 1220,688 32,688 32,60" fill="none" stroke="{MUTED}" stroke-width="2" opacity=".45"/>
<rect x="60" y="30" width="54" height="5" fill="{YELLOW}"/>
<rect x="1166" y="685" width="54" height="5" fill="{YELLOW}"/>
<g transform="translate(0 {shift})">
<g transform="translate(480 82) scale(2.5)" filter="url(#glow)">
{mark(PANEL)}
<g clip-path="url(#gl1)"><path d="{C_SHAPE}" transform="translate(7 0)" fill="{CYAN}"/></g>
<g clip-path="url(#gl2)"><path d="{C_SHAPE}" transform="translate(-7 0)" fill="{MAGENTA}"/></g>
</g>
{wordmark}
<rect x="260" y="582" width="760" height="2" fill="{MUTED}" opacity=".4"/>
<rect x="260" y="579" width="54" height="8" fill="{YELLOW}"/>
{business}
</g>
</svg>
'''


def icon():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 144 144" width="512" height="512" role="img" aria-label="CorpoBiz icon">
<title>CorpoBiz icon</title>
<rect width="144" height="144" fill="{PANEL}"/>
<g transform="translate(12 12)">
{mark(PANEL)}
</g>
</svg>
'''


def modules():
    """(folder, displayName) for every module, read from its def.displayName."""
    found = []
    for src in sorted(ROOT.glob("modules/*/*.reds")):
        m = re.search(r'def\.displayName\s*=\s*"([^"]+)"', src.read_text())
        if m:
            found.append((src.parent.name, m.group(1)))
    return found


def expected():
    files = {OUT / "logo.svg": card(None), OUT / "icon.svg": icon()}
    for folder, name in modules():
        files[OUT / "modules" / f"{folder}.svg"] = card(name)
    return files


def main():
    files = expected()
    orphans = [p for p in (OUT / "modules").glob("*.svg") if p not in files]

    if "--check" in sys.argv:
        bad = [p for p, svg in files.items() if not p.exists() or p.read_text() != svg]
        for p in bad:
            print(f"stale or missing: {p.relative_to(ROOT)}")
        for p in orphans:
            print(f"orphaned (no matching module): {p.relative_to(ROOT)}")
        if bad or orphans:
            print("run: make logos")
        return 1 if bad or orphans else 0

    rsvg = shutil.which("rsvg-convert")
    for path, svg in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(svg)
        if rsvg:
            size = ["-w", "512", "-h", "512"] if path.name == "icon.svg" else ["-w", "1280", "-h", "720"]
            subprocess.run([rsvg, *size, "-o", str(path.with_suffix(".png")), str(path)], check=True)
        print(f"wrote {path.relative_to(ROOT)}")
    if not rsvg:
        print("note: rsvg-convert not found, so no PNGs were written (install librsvg)")
    for p in orphans:
        print(f"warning: {p.relative_to(ROOT)} has no matching module; delete it if the module was removed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
