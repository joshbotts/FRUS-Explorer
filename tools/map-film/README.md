# The semantic-map film — finishing stage

Visual-marketing plan §7 **step 11**, plan-of-record row **F-1**. The capture harness
(`FRUSExplorerTests/SemanticMapFrameSequenceTests`) renders 554 frames; this turns them into a
publishable film. **No re-render** — the frames are the expensive part and they are already correct.

```bash
tools/map-film/build_film.sh              # defaults: ~/Desktop/frus-map-film, 1440 wide, 12 fps
```

| | |
|---|---|
| in | `frame-0000.png` … `frame-0553.png` (1920×1080), `frames.csv`, `provenance.txt` |
| out | `map-film.mp4` (1440×916, 46.17 s, 3.08 MB, no subtitle track), `caption-band.png`, `badge.png`, `captions/caption-NNNN.png`, `frame-captions.tsv`, `map-subtitles{,-years}.{srt,vtt}` |

## The frame, top to bottom

```
  title   Visualizing FRUS: Documents are placed on the semantic map in volume publication order.
  map     the drawn content's rows, less the top trim — 802 of 964; never scaled
                                                        [icon] FRUS Explorer   <- badge, over ground
  volume  1983 · frus1952-54v04 · 301 volumes · 224,056 documents
          1952–1954, The American Republics, Volume IV
```

**Every part is measured and the frame is sized to their sum** (2026-09-20). The title band comes
from its own text (`render_caption.swift --fit-height`, one line at 26 pt: **46 px**), the volume
band from its font (two lines at 20 pt: **68 px**), and the map from the bounding box less the top
trim (**802 px**). 46 + 802 + 68 = **916**, which is the frame. There is no leftover to distribute,
so no arrangement can put a caption further from the map than a band's own margin.

**Measured on the encoded film** (frame 299, ink at least 60 levels above the `#0f1217` ground, so
h264 ringing does not count): the title's descenders end at row 37 and the map's first ink is row 46
— **8 px**; the map's last ink is row 847 and the volume caption's cap height starts at row 860 —
**12 px**. The two differ because a text box carries slack under its descenders while a caption's
ascent sits above its cap height. `--caption-margin-y` (default 7) moves both.

## The top trim

**The film stops drawing one thing the harness drew, and this is it.** The bounding box's top edge is
the map's extreme point, and on the 2026-09-09 artifact that is a single blob — 19 ink pixels at
source rows 58..62 — with **157 empty rows** under it. Framed to the box, the title stood 9 px off the
map's *extent* and **248 px off anything that reads as the map**, while the bottom edge was dense to
its last row.

`top_trim` drops such an island when it is both **negligible** (its ink within `TOP_TRIM_MAX_SHARE`,
0.1%, of the map's total) and **detached** (a gap of at least `TOP_TRIM_MIN_GAP` = 40 rows), then
repeats, so a chain of specks goes in one pass and the first real cluster stops it. On this artifact
it cuts once, at source row 220: **19 of 296,745 ink pixels — 0.0064% — for 162 rows**. The run
prints that line whatever it decides, including when it decides nothing.

Measured alternatives, for anyone re-tuning it: cutting at the first row carrying 20 px (278) would
cost 430 px, 0.145%; at the first carrying 100 px (295), 1,271 px, 0.428%. The cap is what keeps the
rule on the cheap side of that curve. **`--keep-full-extent`** frames the whole bounding box as
before, at 1440×1078.

The count is in **ink pixels, never documents**: a point may be one pixel or several, and this
measures pixels.

This replaces two earlier layouts, and each failed differently. The first used the map's own top
margin as the caption band (`BAND_H=$Y0`), so the 2026-09-09 layout — whose content starts at y=58
rather than y=109 — halved the band and `render_caption.swift` refused. The second reserved a
constant 110 px band above the map and left the bottom to the player, which drew the per-volume
subtitle over the lower map.

## What was measured, and why the crop is what it is

The drawn content occupies **x 418..1501 (1084 px) and y 58..1021 (964 px)** of the 1920×1080 frame.
So **836 px — 43.5% of the width — is empty ground**, which is the plan's "~44% dead width", measured
rather than estimated. The crop takes 1440, reclaiming 480 px and leaving ~178 px of margin a side.
Vertically the box is taken from row 220 rather than 58 — see the top trim above.

**The box is identical on the first frame and the last**, because out-of-scope documents are
*ghosted* rather than removed — every frame draws all 314,571 points. `build_film.sh` re-checks that
before it encodes, since a harness that stopped drawing the ghosts would make the extent grow through
the film and one crop would clip the later frames with no error anywhere.

**`cropdetect` is the wrong tool and reports no crop at all.** Run against `map.mp4` at limit 2, 8 and
24 it returns `crop=1920:1080:0:0` every time: h264 ringing in the flat `#0f1217` ground lifts border
pixels over the threshold. The box has to be measured on the PNGs.

## Two constraints this machine imposes

**This ffmpeg cannot draw text.** No `drawtext`, no `subtitles`, no `ass` filter; the build carries
neither `--enable-libfreetype` nor `--enable-libass`. It *can* mux subtitles (`mov_text`, `srt`,
`webvtt` encoders are present) but it cannot render a glyph. Hence two CoreText scripts:
`render_caption.swift` for the title, which **fails rather than clipping** because CoreText drops
overflowing lines silently, and `render_frame_captions.swift` for the 554 volume captions.

**ffmpeg's MP4 muxer will not keep a subtitle track switched off.** Built with `-disposition:s:0 0`,
the year track came back `default=1`: when no subtitle track in a file is marked default, the muxer
enables the first one. That is how the per-frame track was on screen in every player, and it is why
this film carries no subtitle track at all — see below.

## The title

**The title is the owner's** (2026-09-20): *Visualizing FRUS: Documents are placed on the semantic
map in volume publication order.* It replaced the harness's grain sentence — *"Each frame lights every
document in the volumes published so far — a scope is a set of volumes, so a frame shows where those
volumes' documents sit, never the documents about any particular subject"* — which is still line 1 of
`provenance.txt` and is still the visual-marketing plan §5's disclosure for a scoped-map animation. A
film that should carry it instead is one flag away:

```bash
tools/map-film/build_film.sh --caption "$(head -1 ~/Desktop/frus-map-film/provenance.txt | sed 's/^# *//')"
```

## The badge

`render_badge.swift` draws the app's **own icon** and wordmark to a transparent PNG, and the build
places it in a corner of the MAP region — not in a caption band, where a long volume title reaches to
within 70 px of either edge.

**The icon is read from the app's asset catalog, never copied here.** A copy would be a second thing
to update when the icon changes, and it would go stale silently: the badge would keep rendering, just
with last year's mark. It is drawn ROUNDED, because `AppIcon-1024.png` is the unmasked artwork iOS
masks at draw time — as-is it would put the one hard-cornered square in the film. The radius is
22.37% of the side, the standard approximation of the platform's continuous-corner squircle.

**Where it goes is measured, not chosen.** Both bottom corners of the map region are empty on this
artifact, and the right has the more clearance: the map's nearest ink in the left 360 px column
reaches row 693, in the right 360 px column row 570. **What is under the badge is a property of the
projection**, though — a re-clustered artifact could put a cluster there — so the build converts the
badge's rect back to source coordinates, measures the ink under it on the same frame the bounding box
came from, and refuses above the cap the top trim uses. Today it reports **0 ink px**.

`--badge-corner bottom-left`, `--badge-text`, `--icon` and `--no-badge` are the levers.

## The volume caption, and why it is in the picture

**It used to be a soft subtitle track, and it sat on the map.** The per-frame track was muxed
`default=1`, so every player showed it, and a player draws a subtitle where it likes — over the
bottom of the picture, three lines tall. Placement belonged to the player, so no padding in the file
could keep it off the map. Burned in, it lands in its own band under the map, every frame.

554 frames at 12 fps is **83 ms a frame**, so the caption's SECOND line — the volume's own title —
is a **scrubbing aid**: pause anywhere and it names the volume that just landed. The FIRST line is
the one that reads in motion, because the publication year advances slowly and the two running
totals climb. That is also why the year subtitle track is gone rather than merely switched off:
everything it said is on that line already.

**Each caption carries the `volume_id`**, and that is not decoration: for the 19th-century volumes the
title does not identify anything within a line's room. `frus1865p4`'s title runs to **498 characters**
and the part that distinguishes it — the Lincoln assassination correspondence — sits past character
300. The id is eleven characters, unique, and is the path component in
`history.state.gov/historicaldocuments/{volumeId}/{documentId}`. The header line is therefore never
truncated: a header too wide for the band fails the build, naming the frame.

**The title line is cut by glyph width, not by column count.** `render_frame_captions.swift` uses
`CTLineCreateTruncatedLine` against the band's real width; 7 of 554 titles are cut, each ending in an
ellipsis. Both lines sit on **fixed baselines taken from the font**, so no frame's text moves
vertically — at 83 ms a frame, geometry that followed the string would make the band twitch.

**One formatter feeds both the pixels and the sidecars.** `make_subtitles.py --captions-tsv` writes
the per-frame text the renderer draws, from the same function that writes `map-subtitles.srt`, so the
burned-in caption and the sidecar cannot disagree about what a frame says. Both `.srt`/`.vtt` pairs
are still written — the per-frame one because text burned into pixels can be neither searched nor
copied — and the refactor that split the formatter left all four byte-identical.

**The file is larger, for a reason that is visible.** 3.08 MB against 1.93 MB before: a caption
that changes every frame is high-contrast detail the encoder cannot carry forward from the frame
before.

## Reproducible

A second run over the same frames produces **byte-identical** output. Re-measured 2026-09-20 over
the whole stage, trim included: `map-film.mp4`, `caption-band.png`, both `.srt` files,
`badge.png`, `frame-captions.tsv` and all **554** caption PNGs are `cmp`-clean between two
consecutive runs. x264 at a fixed CRF and preset is
deterministic here, and CoreText's rasterisation is too, so the film can be rebuilt and diffed rather
than kept as the only copy of itself.

## Refusals kept from the plan

§8 refusal 1 still stands: **this is a publication asset, not the App Preview.** The camera never
moves, it is ~12 fps, and it carries no app chrome.
