# Store frames — the composer and its spec

Visual-marketing plan §7 **step 15**, drafted 2026-10-13 in `Planning/Launch-Marketing-Kit-2026-10-13.md`
(the copy, the audiences, the shot list and the capture plan). This folder holds the part that is
reproducible: a spec of every store frame and a script that renders it.

```bash
python3 tools/marketing/compose.py                                           # drafts, half size → Planning/marketing-drafts/
SCALE=1 STAMP=0 OUT_DIR=~/Desktop/store python3 tools/marketing/compose.py   # the frames for App Store Connect: store size, no stamp
ONLY=teachers python3 tools/marketing/compose.py                             # one audience; ONLY=<shot id> or ONLY=<preset> also work
```

The listing's words are not here: `Planning/app-store-connect/` has them, counted and ready to paste, with
the owner's page-by-page entry sheet.

| | |
|---|---|
| in | `shots.json` (presets, audiences, shots) and the captures under `Docs/screenshots/` it names |
| out | one PNG per shot, `<audience>-<order>-<id>-<preset>[@0.5x].png`, and `contact-sheet-<audience>.png`; on a store run, `upload/<preset>/NN-<id>.png` as well |
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

**The upload folders.** App Store Connect keeps a slot's screenshots in the order they arrive, and the
frames' own names sort by audience (`all`, `analysts`, `researchers`, `teachers`), which is not the
listing's order; nor does a slot take all fourteen. `shots.json`'s `listing` names, for each preset, the
frames its slot takes, in order: the ten of the kit's §3 for the iPad and the Mac, and five for the iPhone.
A store run (`SCALE=1 STAMP=0`, with no `ONLY`) copies them to `upload/<preset>/NN-<id>.png` under
`OUT_DIR`, so that a folder's files, dragged into its slot together, arrive in order. A folder's earlier
numbered frames are removed first. The run exits before it renders anything when `listing` names a shot
its preset does not have.

`uploadAlso` then names a folder that repeats another preset's upload frames at a second size:
`upload/iphone-6.3/` holds the iPhone's five at 1206 × 2622. Each is its 6.9-inch frame printed again as
an image filling a page of that size, so it is the frame the owner reviewed, scaled (by 0.9136 across
and 0.9142 down), and not a second layout nobody has read.

**Google Chrome's new headless mode counts its toolbar in `--window-size`** (measured here: a
1,800-px window gave the page 1,714 and the foot of every frame went unpainted, with no error). The
script probes the viewport once per size, renders that much taller, and cuts the PNG back to size
with a stdlib decoder, then checks the output's dimensions and exits if they are wrong. A headless
shell has no toolbar and needs no correction; it is preferred when found.

**Figures.** No number is typeset that the spec does not carry, and the spec carries only figures
from `Planning/Store-Listing-Draft.md` §5. Change a figure there first.

**Sizes.** The presets' pixel sizes were third-party readings of App Store Connect's table (2026-10-13)
until 2026-11-10, when each was read on Apple's own page (App Store Connect Help, Screenshot
specifications): 2752 × 2064 is one of the 13-inch iPad's two landscape sizes, 2880 × 1800 one of the
Mac's four, and 1320 × 2868 one of the 6.9-inch iPhone's three, with no 6.5-inch set asked for beside
it. Each preset's `note` in `shots.json` says so. The page's list of required sizes names the iPhone's
medium display (1206 × 2622 or 1179 × 2556), and the page also says a larger set is scaled down for
smaller sizes: `uploadAlso` is for the case in which App Store Connect wants the medium size itself. Apple takes PNG or JPEG with no alpha channel, and
the frames are RGB PNGs. Read the page again before a later release's export: Apple changes the table.
