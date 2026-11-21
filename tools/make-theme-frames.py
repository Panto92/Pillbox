#!/usr/bin/env python3
"""Generate the rounded 9-slice frames of the Pillbox Plasma style.

  widgets/viewitem.svg   list and grid highlights (hover, selected) – rounded, accent-tinted
  widgets/lineedit.svg   text fields, KRunner's search field included – a soft capsule,
                         the accent colour as a ring while you type

Plasma cuts each frame into nine pieces named <prefix>-topleft … <prefix>-center and
stretches the edges; <prefix>-hint-*-margin set the inner padding. Colours come from the
colour scheme (ColorScheme-Text / ColorScheme-Highlight), so light and dark themes and the
accent colour all follow.

Usage: make-theme-frames.py PLASMA_STYLE_DIR      SPDX-License-Identifier: MIT"""
import os, sys

def frame(prefix, ox, r, cls, fill, stroke, sw=1.0, scls=None):
    """Nine pieces of a rounded rectangle with corner radius r, placed at x offset ox."""
    scls = scls or cls
    X, Y, h = ox, 0, sw / 2
    out = []
    def piece(name, x, y, w, hh, d, s):
        g = f'<g id="{prefix}-{name}"><rect x="{X + x}" y="{Y + y}" width="{w}" height="{hh}" fill="none"/>'
        if fill: g += f'<path class="{cls}" d="{d}" fill="currentColor" fill-opacity="{fill}"/>'
        if stroke and s: g += f'<path class="{scls}" d="{s}" fill="none" stroke="currentColor" stroke-opacity="{stroke}" stroke-width="{sw}"/>'
        out.append(g + '</g>')
    R = r
    piece('topleft', 0, 0, R, R, f'M{X+R} {Y}A{R} {R} 0 0 0 {X} {Y+R}H{X+R}Z', f'M{X+R} {Y+h}A{R-h} {R-h} 0 0 0 {X+h} {Y+R}')
    piece('top', R, 0, R, R, f'M{X+R} {Y}h{R}v{R}h{-R}Z', f'M{X+R} {Y+h}h{R}')
    piece('topright', 2*R, 0, R, R, f'M{X+2*R} {Y}A{R} {R} 0 0 1 {X+3*R} {Y+R}H{X+2*R}Z', f'M{X+2*R} {Y+h}A{R-h} {R-h} 0 0 1 {X+3*R-h} {Y+R}')
    piece('left', 0, R, R, R, f'M{X} {Y+R}h{R}v{R}h{-R}Z', f'M{X+h} {Y+R}v{R}')
    piece('center', R, R, R, R, f'M{X+R} {Y+R}h{R}v{R}h{-R}Z', None)
    piece('right', 2*R, R, R, R, f'M{X+2*R} {Y+R}h{R}v{R}h{-R}Z', f'M{X+3*R-h} {Y+R}v{R}')
    piece('bottomleft', 0, 2*R, R, R, f'M{X} {Y+2*R}H{X+R}V{Y+3*R}A{R} {R} 0 0 1 {X} {Y+2*R}Z', f'M{X+h} {Y+2*R}A{R-h} {R-h} 0 0 0 {X+R} {Y+3*R-h}')
    piece('bottom', R, 2*R, R, R, f'M{X+R} {Y+2*R}h{R}v{R}h{-R}Z', f'M{X+R} {Y+3*R-h}h{R}')
    piece('bottomright', 2*R, 2*R, R, R, f'M{X+2*R} {Y+2*R}H{X+3*R}A{R} {R} 0 0 1 {X+2*R} {Y+3*R}Z', f'M{X+3*R-h} {Y+2*R}A{R-h} {R-h} 0 0 1 {X+2*R} {Y+3*R-h}')
    return "".join(out)

def margins(prefix, ox, left, top, right, bottom):
    return (f'<rect id="{prefix}-hint-left-margin" x="{ox}" y="40" width="{left}" height="1" fill="none"/>'
            f'<rect id="{prefix}-hint-right-margin" x="{ox}" y="42" width="{right}" height="1" fill="none"/>'
            f'<rect id="{prefix}-hint-top-margin" x="{ox}" y="44" width="1" height="{top}" fill="none"/>'
            f'<rect id="{prefix}-hint-bottom-margin" x="{ox}" y="52" width="1" height="{bottom}" fill="none"/>')

STYLE = ('<style id="current-color-scheme" type="text/css">'
         '.ColorScheme-Text{color:#e9eef2}.ColorScheme-Highlight{color:#ff8a4c}.ColorScheme-Background{color:#10141a}.ColorScheme-ViewBackground{color:#161b22}</style>')

def svg(comment, width, body):
    return (f'<!-- {comment} SPDX-License-Identifier: MIT -->\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="64" viewBox="0 0 {width} 64">{STYLE}'
            # stretch the edges and the centre instead of tiling them
            '<rect id="hint-stretch-borders" x="0" y="62" width="1" height="1" fill="none"/>'
            f'{body}</svg>\n')

def viewitem():
    R, body = 10, ""
    states = [("normal", "ColorScheme-Text", 0, 0), ("hover", "ColorScheme-Text", 0.07, 0.06),
              ("selected", "ColorScheme-Highlight", 0.22, 0.45), ("selected+hover", "ColorScheme-Highlight", 0.30, 0.6)]
    for k, (p, cls, f, s) in enumerate(states):
        body += frame(p, k * 40, R, cls, f, s)
    return svg("Pillbox: list and grid highlights, rounded and tinted with the accent colour.", 160, body)

def lineedit():
    # one quiet capsule; no separate hover / focus ring (nested fields such as KRunner's
    # would show it twice) – the cursor shows where you type
    R = 12
    body = frame("base", 0, R, "ColorScheme-ViewBackground", 1.0, 0)      # opaque and borderless: nested fields merge into one
    body += margins("base", 0, 10, 6, 10, 6)
    return svg("Pillbox: text fields as soft, opaque capsules.", 40, body)

def main(out):
    d = os.path.join(out, "widgets")
    os.makedirs(d, exist_ok=True)
    # viewitem: Pillbox's own list highlight drew stray "ears" in KRunner's result list, so
    # Breeze's (already rounded) highlight is used until that is solved – see viewitem()
    old = os.path.join(d, "viewitem.svg")
    if os.path.exists(old): os.remove(old)
    for name, text in (("lineedit.svg", lineedit()),):
        with open(os.path.join(d, name), "w") as f:
            f.write(text)
    print("wrote lineedit.svg to", d)

if __name__ == "__main__":
    main(sys.argv[1])
