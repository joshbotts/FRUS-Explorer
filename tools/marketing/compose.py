#!/usr/bin/env python3
# Copyright 2026 Joshua Botts
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Compose captioned App Store frames from the repository's screenshots (Visual-Marketing-Plan §7 step 15).

A store frame is a caption band over a capture, at the exact pixel size App Store Connect takes for
one device class. This script lays each frame out as a page of HTML, prints it with a headless
Chromium at that size, and writes a PNG. It reads `shots.json` beside it: one entry per frame, naming
the capture under `Docs/screenshots/` it stands on, the device preset, the headline and the subline.
A frame whose capture does not exist yet (every iPhone frame, on 2026-10-13) renders as a labelled
placeholder carrying the route to capture, so the set can be reviewed whole before the captures exist.

    python3 tools/marketing/compose.py                  # drafts at half size into Planning/marketing-drafts/
    SCALE=1 STAMP=0 OUT_DIR=~/Desktop/store python3 tools/marketing/compose.py   # the frames for App Store Connect
    ONLY=researchers python3 tools/marketing/compose.py # one audience, or ONLY=<shot id>

Environment:
  SCALE      1 writes the store size the preset names; 0.5 (the default) writes a review draft at half
             the pixels, which is what the committed drafts are
  STAMP      1 (the default) stamps each frame for review: DRAFT, the shot's id, its status and its
             capture's path, in the frame's top margin; 0 leaves the stamp out, for the frames uploaded
             to App Store Connect, and refuses a shot that has no capture
  OUT_DIR    where the frames and the contact sheets go       (default Planning/marketing-drafts)
  ONLY       an audience name or a shot id, to render a subset (default: everything)
  CHROME     the browser binary; found by itself in the usual places otherwise (Playwright's
             /opt/pw-browsers on a cloud container; Google Chrome or Chromium in /Applications on a Mac)
  SHOTS      another spec file                                 (default tools/marketing/shots.json)

The stamp is drawn over the frame's top margin, out of the layout's flow, so a stamped draft lays out
exactly as the store frame does. It used to share the foot's row and never wrapped, so on the iPhone
preset the foot beside it was a column a few words wide: five lines for the disclaimer on frame 01,
nine for the NARA sentence on frame 04 (#1763).

Rules the layout keeps, because each is one of the plan's disclosure obligations (§5):
  - A capture is placed whole, never cropped on the left, right or top, so a disclosure the app draws
    at the foot of a screen (the map's "distances between far regions are not meaningful") stays
    in the pixels when the frame bleeds at the bottom: the spec marks such captures `keepFoot`, and
    the layout then fits the capture entirely instead of bleeding it.
  - No number is typeset into a frame that the spec does not carry, and the spec carries only
    figures measured in `Planning/Store-Listing-Draft.md` §5.
  - A frame of an experimental surface keeps the app's own "Experimental" line in the capture and
    the caption never contradicts it.

Stdlib only, on purpose: a Mac that archives the app has Chrome or Chromium and nothing else this
needs. The default output is a stamped draft for the owner's design pass; STAMP=0 at SCALE=1 writes
the frames that are uploaded.
"""

import glob
import html
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPEC = Path(os.environ.get("SHOTS", REPO / "tools" / "marketing" / "shots.json"))
OUT = Path(os.environ.get("OUT_DIR", REPO / "Planning" / "marketing-drafts")).expanduser()
SCALE = float(os.environ.get("SCALE", "0.5"))
STAMP = os.environ.get("STAMP", "1")
ONLY = os.environ.get("ONLY")

CHROME_CANDIDATES = [
    os.environ.get("CHROME"),
    # A headless shell treats --window-size as the viewport. Google Chrome's new headless mode
    # counts its toolbar in the window (measured here: 86 px of 1,800 unpainted), which `render`
    # detects with a probe and corrects by rendering taller and cropping. Prefer the shell.
    *sorted(glob.glob("/opt/pw-browsers/chromium_headless_shell-*/chrome-linux/headless_shell")),
    *sorted(glob.glob(os.path.expanduser("~/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-mac*/headless_shell"))),
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    shutil.which("chromium"),
    shutil.which("chromium-browser"),
    shutil.which("google-chrome"),
    *sorted(glob.glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome")),
]

PALETTE = {
    # The launch screen's background and title (Assets.xcassets/LaunchBackground, LaunchTitle) and
    # the one brand colour the app asserts beyond its icon, FRUSTheme.provenanceFRUS (0xA61C2A).
    "light": {"bg": "#F2F2F4", "ink": "rgba(0,0,0,0.90)", "sub": "rgba(0,0,0,0.55)", "accent": "#A61C2A",
              "frame": "rgba(0,0,0,0.12)", "panel": "#FFFFFF"},
    # The map film's ground (#0f1217, tools/map-film) for frames whose capture is itself dark.
    "dark": {"bg": "#0F1217", "ink": "rgba(255,255,255,0.95)", "sub": "rgba(255,255,255,0.60)", "accent": "#E8798A",
             "frame": "rgba(255,255,255,0.14)", "panel": "#15181E"},
}


def find_chrome():
    for candidate in CHROME_CANDIDATES:
        if candidate and Path(candidate).exists():
            return candidate
    sys.exit("No Chromium found. Set CHROME=/path/to/chrome (Google Chrome or Chromium both work).")


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


PRESET_RANK = {"ipad-13-landscape": 0, "ipad-13-portrait": 1, "mac": 2, "iphone-6.9": 3}


def frame_html(shot, preset, spec, stamped=True):
    """One frame as a page: a caption band, the capture (bleeding at the foot unless `keepFoot`), and
    the disclosure line. Everything is in flow, so a long subline pushes the capture down rather than
    sliding under it, and the foot keeps its own row rather than printing over the capture.

    `stamped` draws the review stamp over the top margin (`padTop`), the one thing out of flow, so a
    stamped and an unstamped frame lay out alike and the foot has its row to itself."""
    w, h = preset["width"], preset["height"]
    t = PALETTE[shot.get("theme", "light")]
    typo = preset["type"]
    margin = typo["margin"]
    audience = spec["audiences"].get(shot["audience"], {}).get("eyebrow", shot["audience"].upper())
    capture = shot.get("capture")
    capture_path = REPO / capture if capture else None
    if capture_path and capture_path.exists():
        mode = "fit" if shot.get("keepFoot") else "bleed"
        body = f'<div class="shot {mode}"><img src="file://{capture_path}" alt=""></div>'
        status = shot.get("status", "stand-in")
    else:
        route = html.escape(shot.get("route", "capture needed"))
        body = (f'<div class="placeholder"><div class="ph-label">CAPTURE NEEDED</div>'
                f'<div class="ph-route">{route}</div></div>')
        status = "placeholder"
    foot = html.escape(shot.get("foot", ""))
    stamp = ""
    if stamped:
        label = html.escape(f'DRAFT · {shot["id"]} · {status} · {capture or "no capture"}')
        stamp = f'<div class="stampband"><div class="stamp">{label}</div></div>'
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><style>
  html,body{{margin:0;width:{w}px;height:{h}px;overflow:hidden;background:{t['bg']};
    font-family:"Inter Display","Inter",-apple-system,"SF Pro Display","Helvetica Neue",Helvetica,Arial,sans-serif;
    -webkit-font-smoothing:antialiased}}
  .page{{position:relative;display:flex;flex-direction:column;width:{w}px;height:{h}px;box-sizing:border-box;overflow:hidden;
    padding:{typo['padTop']}px {margin}px 0 {margin}px}}
  .stampband{{position:absolute;top:0;left:{margin}px;right:{margin}px;height:{typo['padTop']}px;
    display:flex;align-items:center;justify-content:flex-end}}
  .stamp{{font-size:{typo['foot']*0.7:.0f}px;line-height:1.2;color:{t['sub']};opacity:0.7;text-align:right;overflow-wrap:anywhere;
    font-family:"DejaVu Sans Mono","SF Mono",Menlo,monospace}}
  .band{{flex:0 0 auto;padding-bottom:{typo['gap']}px}}
  .eyebrow{{font-size:{typo['eyebrow']}px;font-weight:600;letter-spacing:0.14em;color:{t['accent']};margin-bottom:{typo['eyebrow']*0.9:.0f}px}}
  .headline{{font-size:{typo['headline']}px;line-height:1.08;font-weight:600;letter-spacing:-0.02em;color:{t['ink']};
    max-width:{typo.get('measure', 100)}%}}
  .subline{{font-size:{typo['subline']}px;line-height:1.3;font-weight:400;color:{t['sub']};margin-top:{typo['subline']*0.55:.0f}px;
    max-width:{typo.get('measure', 100)}%}}
  .stage{{flex:1 1 0px;min-height:0;position:relative;display:flex;justify-content:center;align-items:flex-start;overflow:hidden}}
  .shot{{border-radius:{typo['radius']}px;overflow:hidden;background:{t['panel']};line-height:0;
    box-shadow:0 0 0 {typo['border']}px {t['frame']}, 0 {typo['border']*6}px {typo['border']*24}px rgba(0,0,0,0.18)}}
  .shot.bleed{{width:100%}} .shot.bleed img{{width:100%;height:auto;display:block}}
  .shot.fit{{max-width:100%;max-height:100%;display:inline-block}} .shot.fit img{{max-width:100%;max-height:{h}px;display:block}}
  .placeholder{{width:100%;height:100%;box-sizing:border-box;border-radius:{typo['radius']}px;border:{typo['border']*2}px dashed {t['frame']};
    display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:{margin}px}}
  .ph-label{{font-size:{typo['eyebrow']*1.4:.0f}px;font-weight:700;letter-spacing:0.14em;color:{t['accent']}}}
  .ph-route{{font-size:{typo['subline']}px;line-height:1.4;color:{t['sub']};margin-top:{typo['subline']}px;max-width:90%}}
  .footrow{{flex:0 0 auto;padding:{typo['gap']*0.6:.0f}px 0 {typo['footBottom']}px 0}}
  .foot{{font-size:{typo['foot']}px;color:{t['sub']};line-height:1.3;max-width:78%}}
</style></head><body><div class="page">{stamp}
  <div class="band">
    <div class="eyebrow">{html.escape(audience)}</div>
    <div class="headline">{html.escape(shot['headline'])}</div>
    <div class="subline">{html.escape(shot.get('subline', ''))}</div>
  </div>
  <div class="stage">{body}</div>
  <div class="footrow"><div class="foot">{foot}</div></div>
</div></body></html>"""


def contact_sheet_html(title, sections, cols, cell_w, pad, caption_h):
    """A review sheet: one grid per device preset, so portrait and landscape frames never share a row."""
    parts = []
    for preset_name, rows in sections:
        cards = "".join(
            f'<figure><img src="file://{png}"><figcaption>{html.escape(label)}</figcaption></figure>'
            for png, label in rows
        )
        parts.append(f'<h2>{html.escape(preset_name)}</h2><div class="grid">{cards}</div>')
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
  body{{margin:0;background:#E9E9EC;font-family:"Inter",-apple-system,Helvetica,Arial,sans-serif;padding:{pad}px}}
  h1{{font-size:{pad*1.2:.0f}px;margin:0 0 {pad}px 0;color:#1C1C1E;font-weight:600;line-height:1.2;height:{pad*1.5:.0f}px}}
  h2{{font-size:{pad*0.8:.0f}px;margin:{pad}px 0 {pad/2:.0f}px 0;color:#48484A;font-weight:600;height:{pad:.0f}px;line-height:1.2}}
  .grid{{display:grid;grid-template-columns:repeat({cols},{cell_w}px);gap:{pad}px;align-items:start}}
  figure{{margin:0;width:{cell_w}px}} figure img{{width:{cell_w}px;display:block;border-radius:{pad/3:.0f}px;box-shadow:0 2px 12px rgba(0,0,0,.18)}}
  figcaption{{font-size:{pad*0.55:.0f}px;color:#3A3A3C;margin-top:{pad/3:.0f}px;line-height:1.3;height:{caption_h}px;overflow:hidden}}
</style></head><body><h1>{html.escape(title)}</h1>{''.join(parts)}</body></html>"""


def chrome_args(chrome, width, height, scale, profile):
    return [
        chrome, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
        "--default-background-color=00000000",
        f"--force-device-scale-factor={scale}",
        f"--window-size={width},{height}",
        f"--user-data-dir={profile}",
    ]


_VIEWPORT_SHORTFALL = {}


def viewport_shortfall(chrome, width, height):
    """How many CSS px of a `--window-size` height this browser does not give the page.

    Measured once per (browser, size) with a probe page that writes `window.innerHeight` into its
    title; Google Chrome's new headless mode answers 86 short, a headless shell answers 0."""
    key = (chrome, width, height)
    if key in _VIEWPORT_SHORTFALL:
        return _VIEWPORT_SHORTFALL[key]
    with tempfile.TemporaryDirectory() as tmp:
        probe = Path(tmp) / "probe.html"
        probe.write_text("<!doctype html><title>?</title><script>document.title='vh='+window.innerHeight</script>")
        cmd = chrome_args(chrome, width, height, 1, f"{tmp}/profile") + ["--dump-dom", probe.as_uri()]
        dom = subprocess.run(cmd, capture_output=True, text=True, timeout=60).stdout
    seen = dom.split("<title>vh=")[1].split("<")[0] if "<title>vh=" in dom else None
    short = height - int(seen) if seen and seen.isdigit() else 0
    _VIEWPORT_SHORTFALL[key] = max(0, short)
    return _VIEWPORT_SHORTFALL[key]


def crop_png_rows(path, keep_rows):
    """Keep the first `keep_rows` scanlines of an 8-bit, non-interlaced RGB or RGBA PNG, in place.

    Stdlib only: the PNG is unfiltered scanline by scanline, cut, and re-encoded with filter 0.
    That is enough for what Chromium writes; anything else raises rather than guessing."""
    import struct
    import zlib

    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos, chunks, idat = 8, [], b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IDAT":
            idat += body
        else:
            chunks.append((kind, body))
        pos += 12 + length
    ihdr = dict(zip(("w", "h", "depth", "ctype", "comp", "filt", "interlace"), struct.unpack(">IIBBBBB", chunks[0][1])))
    if ihdr["depth"] != 8 or ihdr["ctype"] not in (2, 6) or ihdr["interlace"] != 0:
        raise ValueError(f"crop_png_rows handles 8-bit RGB/RGBA non-interlaced PNGs only, got {ihdr}")
    bpp = 3 if ihdr["ctype"] == 2 else 4
    stride = ihdr["w"] * bpp
    raw = zlib.decompress(idat)
    prev = bytearray(stride)
    out = bytearray()
    for row in range(min(keep_rows, ihdr["h"])):
        start = row * (stride + 1)
        f = raw[start]
        line = bytearray(raw[start + 1:start + 1 + stride])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 0xFF
            elif f == 2:
                line[i] = (line[i] + b) & 0xFF
            elif f == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 0xFF
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        out += b"\x00" + line
        prev = line

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    new_ihdr = struct.pack(">IIBBBBB", ihdr["w"], keep_rows, 8, ihdr["ctype"], 0, 0, 0)
    png = data[:8] + chunk(b"IHDR", new_ihdr)
    for kind, body in chunks[1:]:
        if kind != b"IEND":
            png += chunk(kind, body)
    png += chunk(b"IDAT", zlib.compress(bytes(out), 6)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def render(chrome, html_text, out_png, width, height, scale):
    """Print one page to a PNG of exactly width×height CSS px at `scale`. The page is laid out at
    its own fixed size, so a browser that gives the window less viewport than asked paints the foot
    of the page nowhere: the shortfall is probed once and the render made taller, then cut back."""
    short = viewport_shortfall(chrome, width, height)
    out_png = Path(out_png)
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "frame.html"
        page.write_text(html_text, encoding="utf-8")
        cmd = chrome_args(chrome, width, height + short, scale, f"{tmp}/profile") + [f"--screenshot={out_png}", page.as_uri()]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        if not out_png.exists():
            sys.exit(f"Chromium wrote nothing for {out_png}:\n{result.stderr[-2000:]}")
    if short:
        crop_png_rows(out_png, round(height * scale))
    ow, oh = png_size(out_png)
    expected = (round(width * scale), round(height * scale))
    if (ow, oh) != expected:
        sys.exit(f"{out_png} is {ow}×{oh}, expected {expected[0]}×{expected[1]}")


def main():
    if STAMP not in ("0", "1"):
        sys.exit(f"STAMP={STAMP}: use 1 (the default, a stamped review draft) or 0 (no stamp, for App Store Connect)")
    stamped = STAMP == "1"
    chrome = find_chrome()
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    shots = spec["shots"]
    if ONLY:
        shots = [s for s in shots if s["audience"] == ONLY or s["id"] == ONLY or s.get("preset") == ONLY]
        if not shots:
            sys.exit(f"ONLY={ONLY} matches no audience, preset or shot id")
    if not stamped:
        # An unstamped placeholder would pass for a finished frame, so a frame without its stamp must
        # stand on a capture. Checked before anything is written.
        missing = [f"{s['id']} ({s['preset']})" for s in shots
                   if not (s.get("capture") and (REPO / s["capture"]).exists())]
        if missing:
            sys.exit("STAMP=0 writes the frames for App Store Connect, and these have no capture: " + ", ".join(missing))
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for shot in shots:
        preset = spec["presets"][shot["preset"]]
        w, h = preset["width"], preset["height"]
        suffix = "" if SCALE == 1 else f"@{SCALE:g}x"
        out_png = OUT / f"{shot['audience']}-{shot['order']:02d}-{shot['id']}-{shot['preset']}{suffix}.png"
        render(chrome, frame_html(shot, preset, spec, stamped), out_png, w, h, SCALE)
        ow, oh = png_size(out_png)
        print(f"{out_png.relative_to(REPO) if out_png.is_relative_to(REPO) else out_png}  {ow}×{oh}")
        written.append((shot, out_png))

    # One contact sheet per audience, grouped by device, so a set is judged as the store shows it.
    by_audience = {}
    for shot, png in written:
        by_audience.setdefault(shot["audience"], []).append((shot, png))
    cols, cell_w, pad, caption_h = 4, 560, 28, 44
    for audience, items in by_audience.items():
        items.sort(key=lambda it: (PRESET_RANK.get(it[0]["preset"], 9), it[0]["order"]))
        sections, height = [], pad * 2 + pad * 1.5 + pad
        for preset_name in sorted({s["preset"] for s, _ in items}, key=lambda n: PRESET_RANK.get(n, 9)):
            rows = [(png, f"{s['order']:02d} · {s['headline']}") for s, png in items if s["preset"] == preset_name]
            sections.append((preset_name, rows))
            aspect = max(png_size(png)[1] / png_size(png)[0] for png, _ in rows)
            n_rows = math.ceil(len(rows) / cols)
            height += pad * 2 + n_rows * (cell_w * aspect + pad / 3 + caption_h) + (n_rows - 1) * pad
        sheet_w = cols * cell_w + (cols + 1) * pad
        title = spec["audiences"].get(audience, {}).get("title", audience)
        sheet = OUT / f"contact-sheet-{audience}.png"
        render(chrome, contact_sheet_html(title, sections, cols, cell_w, pad, caption_h), sheet, sheet_w, int(height), 1)
        print(f"{sheet.relative_to(REPO) if sheet.is_relative_to(REPO) else sheet}  (contact sheet)")


if __name__ == "__main__":
    main()
