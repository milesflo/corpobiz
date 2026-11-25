#!/usr/bin/env python3
"""One-off: extract outlined glyph data from Chakra Petch (SIL OFL, see OFL.txt)
into glyphs.json for gen_logos.py, so logo generation needs no fonts at runtime.

Needs fontTools (pip install fonttools); gen_logos.py itself is stdlib-only.
Rerun only to change the character set or the font:

  python3 -I tools/brand/extract_glyphs.py ChakraPetch-Medium.ttf ChakraPetch-Bold.ttf tools/brand/glyphs.json
"""
import json
import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

# Business names are set in Medium, uppercased. Extend this to allow more characters.
NAME_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789&'-. "
# The wordmark is Bold and fixed: CORPOBIZ.
WORDMARK_CHARS = "CORPBIZ"


def extract(path, chars):
    font = TTFont(path)
    cmap, glyphs, hmtx = font.getBestCmap(), font.getGlyphSet(), font["hmtx"]
    out = {}
    for ch in chars:
        name = cmap[ord(ch)]
        pen = SVGPathPen(glyphs, ntos=lambda v: f"{v:g}")
        glyphs[name].draw(pen)
        out[ch] = {"adv": hmtx[name][0], "d": pen.getCommands()}
    return {"upm": font["head"].unitsPerEm, "glyphs": out}


if __name__ == "__main__":
    medium, bold, dest = sys.argv[1:4]
    data = {"medium": extract(medium, NAME_CHARS), "bold": extract(bold, WORDMARK_CHARS)}
    with open(dest, "w") as f:
        json.dump(data, f, separators=(",", ":"), sort_keys=True)
        f.write("\n")
