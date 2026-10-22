# Store frames — the composer and its spec

Visual-marketing plan §7 **step 15**, drafted 2026-10-13 in `Planning/Launch-Marketing-Kit-2026-10-13.md`
(the copy, the audiences, the shot list and the capture plan). This folder holds the part that is
reproducible: a spec of every store frame and a script that renders it.

```bash
python3 tools/marketing/compose.py                                           # drafts, half size → Planning/marketing-drafts/
SCALE=1 STAMP=0 OUT_DIR=~/Desktop/store python3 tools/marketing/compose.py   # the frames for App Store Connect: store size, no stamp
ONLY=teachers python3 tools/marketing/compose.py                             # one audience; ONLY=<shot id> or ONLY=<preset> also work
```

| | |
|---|---|
| in | `shots.json` (presets, audiences, shots) and the captures under `Docs/screenshots/` it names |
| out | one PNG per shot, `<audience>-<order>-<id>-<preset>[@0.5x].png`, and `contact-sheet-<audience>.png` |
| needs | Python 3 (stdlib only) and a Chromium: a Playwright headless shell if one is installed, else Google Chrome or Chromium (`CHROME=` overrides) |

**A frame is a page of HTML printed at its size.** The caption band, the capture and the disclosure
row are in flow, so nothing is placed by a guessed pixel offset; a capture bleeds at the foot unless
its shot says `keepFoot`, which fits it whole so a line the app draws at the bottom of its screen
(the map's caveat) stays in the pixels. A shot with no `capture` renders as a placeholder carrying
its `route`, so the set can be reviewed before every capture exists.

**The stamp.** By default every frame is stamped for review, *DRAFT · id · status · the capture's path*,
in its top margin. The stamp is the one thing out of flow, so a draft lays out exactly as its store frame
does, and the disclosure row keeps its width on every preset. `STAMP=0` leaves the stamp out, for the
frames uploaded to App Store Connect, and refuses to run while a shot it would render has no capture, since
an unstamped placeholder would pass for a finished frame. Until 2026-10-22 the stamp shared the
disclosure row and never wrapped, so on the iPhone preset the disclaimer beside it took five lines on
frame 01 and the NARA sentence nine on frame 04 (#1763); each takes two now.

**Google Chrome's new headless mode counts its toolbar in `--window-size`** (measured here: a
1,800-px window gave the page 1,714 and the foot of every frame went unpainted, with no error). The
script probes the viewport once per size, renders that much taller, and cuts the PNG back to size
with a stdlib decoder, then checks the output's dimensions and exits if they are wrong. A headless
shell has no toolbar and needs no correction; it is preferred when found.

**Figures.** No number is typeset that the spec does not carry, and the spec carries only figures
from `Planning/Store-Listing-Draft.md` §5. Change a figure there first.

**Sizes.** The presets' pixel sizes are third-party readings of App Store Connect's table (2026-10-13)
and are to be verified against Apple's own page before an export is uploaded; the kit's §3 says
which two questions (landscape iPad, 6.5-inch iPhone) matter.
