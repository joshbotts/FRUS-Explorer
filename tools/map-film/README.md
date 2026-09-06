# The semantic-map film — finishing stage

Visual-marketing plan §7 **step 11**, plan-of-record row **F-1**. The capture harness
(`FRUSExplorerTests/SemanticMapFrameSequenceTests`) renders 553 frames; this turns them into a
publishable film. **No re-render** — the frames are the expensive part and they are already correct.

```bash
tools/map-film/build_film.sh              # defaults: ~/Desktop/frus-map-film, 1440 wide, 12 fps
```

| | |
|---|---|
| in | `frame-0000.png` … `frame-0552.png` (1920×1080), `frames.csv`, `provenance.txt` |
| out | `map-film.mp4` (1440×1080, 46.08 s, 1.94 MB), `caption-band.png`, `map-subtitles{,-years}.{srt,vtt}` |

## What was measured, and why the crop is what it is

The drawn content occupies **x 418..1501 (1084 px) and y 109..970 (862 px)** of the 1920×1080 frame.
So **836 px — 43.5% of the width — is empty ground**, which is the plan's "~44% dead width", measured
rather than estimated. The crop takes 1440, reclaiming 480 px and leaving ~178 px of margin a side,
with the 109 px band above the map carrying the grain sentence.

**The box is identical on the first frame and the last**, because out-of-scope documents are
*ghosted* rather than removed — every frame draws all 314,483 points. `build_film.sh` re-checks that
before it encodes, since a harness that stopped drawing the ghosts would make the extent grow through
the film and one crop would clip the later frames with no error anywhere.

**`cropdetect` is the wrong tool and reports no crop at all.** Run against `map.mp4` at limit 2, 8 and
24 it returns `crop=1920:1080:0:0` every time: h264 ringing in the flat `#0f1217` ground lifts border
pixels over the threshold. The box has to be measured on the PNGs.

## Two constraints this machine imposes

**This ffmpeg cannot draw text.** No `drawtext`, no `subtitles`, no `ass` filter; the build carries
neither `--enable-libfreetype` nor `--enable-libass`. It *can* mux subtitles (`mov_text`, `srt`,
`webvtt` encoders are present) but it cannot render a glyph. Hence `render_caption.swift`, which
rasterises the caption with CoreText — and which **fails rather than clipping**, because CoreText
drops overflowing lines silently and a half-printed disclosure line is the one failure that matters.

**The grain sentence is read from `provenance.txt`, never hard-coded.** If the harness rewords it,
the film follows rather than asserting the old wording.

## The subtitle tracks, and why there are two

553 frames at 12 fps is **83 ms a frame**. Nothing is readable at that rate and no cue design changes
that — so the per-frame track (553 cues) is a **scrubbing aid**: pause anywhere and it names the
volume that just landed. The `--group-by-year` track (154 cues, 0.30 s mean, 1.0 s on 1996's twelve
volumes) is the one that reads at speed. Both are muxed; the viewer picks. The sentence a viewer is
meant to *read* is burned into the frame, where it does not move.

**Each cue carries the `volume_id`**, and that is not decoration: for the 19th-century volumes the
title does not identify anything within a subtitle's room. `frus1865p4`'s title runs to **498
characters** and the part that distinguishes it — the Lincoln assassination correspondence — sits past
character 300, so every truncation loses it. The id is eleven characters, unique, and is the path
component in `history.state.gov/historicaldocuments/{volumeId}/{documentId}`.

Verified: both tracks were muxed, extracted back out and compared cue for cue — **553/553 and 154/154
identical**. (`ffprobe` reports `nb_frames` 554 and 155 for them; that is a container-level count, not
an extra cue.)

## Reproducible

A second run over the same frames produces **byte-identical** output — `map-film.mp4`,
`caption-band.png` and both `.srt` files all `cmp`-clean, measured 2026-09-06. x264 at a fixed CRF
and preset is deterministic here, so the film can be rebuilt and diffed rather than kept as the only
copy of itself.

## Refusals kept from the plan

§8 refusal 1 still stands: **this is a publication asset, not the App Preview.** The camera never
moves, it is ~12 fps, and it carries no app chrome.
