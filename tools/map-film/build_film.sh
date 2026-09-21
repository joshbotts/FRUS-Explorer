#!/usr/bin/env bash
#
# Finish the semantic-map film: crop the dead width, burn a title ABOVE the map and each frame's
# volume BELOW it, and write the volume sequence out as subtitle sidecars. (Visual-marketing plan §7
# step 11 / plan-of-record F-1; layout revised 2026-09-20.)
#
# NO RE-RENDER. It consumes the PNGs the capture harness already wrote; the frames are the
# expensive part and they are correct. This stage is assembly.
#
# THE GEOMETRY IS MEASURED, NOT ASSUMED, and that is the point of the preflight below. Measured on
# the 2026-09-09 artifact's 1920x1080 frames the drawn content occupies x 418..1501 (1084 px) and
# y 58..1021 (964 px) — so 836 px, 43.5% of the width, is empty ground, which is the "~44% dead
# width" the plan names. Cropping to 1440 removes 480 of it and leaves ~178 px of margin a side.
#
# THE FRAME IS A STACK, BUILT FROM MEASUREMENTS (2026-09-20):
#
#     [ title band  ]  one line; the band is sized to the text itself (`render_caption.swift --fit-height`)
#     [ map         ]  the drawn content's rows, less any leading island (see the top trim)
#     [ volume band ]  the frame's own volume, two lines; the band is sized from the font
#
# Each part is measured and the frame is then exactly as tall as the three of them, so no caption's
# room depends on how much empty sky a UMAP projection happens to leave — which is how the film came
# to be unbuildable when the 2026-09-09 layout moved the content's top edge from y=109 to y=58.
#
# THE TOP TRIM IS THE ONE PLACE THE FILM STOPS DRAWING WHAT THE HARNESS DREW, and it is why the
# frame is no longer the source's 1080. The bounding box's top edge is set by the map's extreme
# point, and on the 2026-09-09 artifact that is a single blob of 19 ink pixels with 157 empty rows
# under it: framed to the box, the title stood 9 px off the map's EXTENT and 248 px off anything
# that reads as the map, while the bottom edge was dense to its last row. `top_trim` drops such an
# island only when it is both negligible (within `TOP_TRIM_MAX_SHARE` of the map's ink) and detached
# (a gap of `TOP_TRIM_MIN_GAP` rows), prints exactly what it dropped, and stops at the first real
# cluster. `--keep-full-extent` frames the whole box as before.
#
# WHY THE VOLUME CAPTION IS BURNED IN, when it used to be a soft subtitle track: the track was muxed
# `default=1`, every player showed it, and a player draws a subtitle wherever it likes — over the
# bottom of the picture, three lines tall, on the lower map for the whole film. Placement belonged to
# the player, so no padding in the file could keep it off the map. See `render_frame_captions.swift`.
#
# THREE INVARIANTS ARE CHECKED BEFORE ANYTHING IS ENCODED, because each fails silently otherwise:
#
#   1. THE BOUNDING BOX MUST BE THE SAME ON THE FIRST FRAME AS ON THE LAST. It is, today, because
#      out-of-scope documents are GHOSTED rather than removed, so every frame draws all 314,571
#      points and the extent never moves. If a future harness stopped drawing the ghosts, the box
#      would grow through the film and a single crop would clip the later frames — with no error.
#   2. THE WIDTH CROP MUST NOT CLIP THE CONTENT. A width chosen for composition can be narrower than
#      the map; the script refuses rather than quietly cutting documents off the side of a figure.
#      Vertically it DOES cut, deliberately and under a cap — see the top trim below.
#   3. THE FRAME IS SIZED TO THE STACK, so there is no leftover to distribute and no arrangement in
#      which a caption and the map can be further apart than a band's own margin.
#
# `cropdetect` IS THE WRONG TOOL HERE and was tried first: run against `map.mp4` at limit 2, 8 and 24
# it reports no crop at all, because h264 ringing in the flat #0f1217 ground lifts border pixels over
# the threshold. The box has to be measured on the PNGs.
#
# THE CAPTIONS ARE RENDERED BY SWIFT SCRIPTS, not by ffmpeg: this ffmpeg build has no `drawtext`, no
# `subtitles` and no `ass` filter — it can mux a subtitle track but cannot draw a glyph. See
# `render_caption.swift` and `render_frame_captions.swift`.
#
# Usage:  ./build_film.sh [--frames-dir DIR] [--width 1440] [--fps 12] [--caption TEXT]
#                         [--font-size 26] [--volume-font-size 20] [--caption-margin-y 7] [--crf 18]

set -euo pipefail

FRAMES_DIR="${HOME}/Desktop/frus-map-film"
WIDTH=1440
FPS=12
FONT_SIZE=26
VOLUME_FONT_SIZE=20
CRF=18
# The title is the owner's (2026-09-20). It REPLACED the harness's grain sentence — still line 1 of
# `provenance.txt`, and still the visual-marketing plan §5's disclosure for a scoped-map animation —
# so a film that should carry that sentence instead is one flag away:
#   --caption "$(head -1 provenance.txt | sed 's/^# *//')"
CAPTION="Visualizing FRUS: Documents are placed on the semantic map in volume publication order."
# Vertical breathing room inside each caption band, above and below its text. The bands are sized to
# their text, so this is what sets the gap between a caption and the map, and 7 px is the largest
# value that still fits the 964 px map, both bands and the frame's 1080.
#
# MEASURED ON THE ENCODED FILM rather than inferred from the band, because a band's edge is not its
# ink: at 7 the title's descenders end 9 px above the map's first point and the volume caption's cap
# height starts 12 px below the map's last. The two differ because a text box carries a little slack
# under its descenders and the caption's ascent sits above its cap height.
CAPTION_MARGIN_Y=7
# The top trim (2026-09-20, owner decision). A leading island of the map is dropped when the ink
# above the gap below it is within this share of the map's total AND that gap runs at least this many
# rows. `--keep-full-extent` sets the share to 0, which frames the whole bounding box as before.
TOP_TRIM_MAX_SHARE=0.001
TOP_TRIM_MIN_GAP=40
# The corner badge (2026-09-20): the app's own icon and wordmark. It goes inside the MAP region, not
# in a caption band — a long volume title reaches to within 70 px of either edge — and it is guarded
# against covering the map itself, see `== badge ==`.
BADGE=1
BADGE_CORNER=bottom-right
BADGE_MARGIN=24
BADGE_ICON_SIZE=52
BADGE_FONT_SIZE=22
BADGE_TEXT="FRUS Explorer"
ICON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/FRUSExplorer/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --frames-dir) FRAMES_DIR="$2"; shift 2 ;;
    --width)      WIDTH="$2";      shift 2 ;;
    --fps)        FPS="$2";        shift 2 ;;
    --font-size)  FONT_SIZE="$2";  shift 2 ;;
    --volume-font-size) VOLUME_FONT_SIZE="$2"; shift 2 ;;
    --caption)    CAPTION="$2";    shift 2 ;;
    --caption-margin-y) CAPTION_MARGIN_Y="$2"; shift 2 ;;
    --keep-full-extent) TOP_TRIM_MAX_SHARE=0; shift ;;
    --top-trim-share)   TOP_TRIM_MAX_SHARE="$2"; shift 2 ;;
    --no-badge)         BADGE=0; shift ;;
    --badge-corner)     BADGE_CORNER="$2"; shift 2 ;;
    --badge-text)       BADGE_TEXT="$2"; shift 2 ;;
    --icon)             ICON="$2"; shift 2 ;;
    --crf)        CRF="$2";        shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

cd "$FRAMES_DIR"
[[ -f frames.csv ]]     || { echo "no frames.csv in $FRAMES_DIR" >&2; exit 1; }
[[ -f provenance.txt ]] || { echo "no provenance.txt in $FRAMES_DIR" >&2; exit 1; }

LAST=$(printf 'frame-%04d.png' "$(( $(grep -c '' frames.csv) - 2 ))")
[[ -f "$LAST" ]] || { echo "last frame $LAST is missing" >&2; exit 1; }

echo "== preflight: measuring the drawn content =="
read -r FW FH X0 X1 Y0 Y1 TRIM_Y TRIM_INK TOTAL_INK < <(
  python3 - "frame-0000.png" "$LAST" "$TOP_TRIM_MAX_SHARE" "$TOP_TRIM_MIN_GAP" <<'PY'
import subprocess, sys, numpy as np

def bbox(path):
    raw = subprocess.run(
        ["ffmpeg", "-hide_banner", "-v", "error", "-i", path, "-pix_fmt", "gray", "-f", "rawvideo", "-"],
        stdout=subprocess.PIPE, check=True).stdout
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height", "-of", "csv=p=0", path],
        stdout=subprocess.PIPE, text=True, check=True).stdout.strip().split(",")
    w, h = int(probe[0]), int(probe[1])
    a = np.frombuffer(raw, dtype=np.uint8).reshape(h, w)
    # The ground is the modal luma; anything a few levels above it is drawn.
    mask = a > np.bincount(a.ravel()).argmax() + 4
    cols, rows = mask.any(axis=0).nonzero()[0], mask.any(axis=1).nonzero()[0]
    return w, h, int(cols.min()), int(cols.max()), int(rows.min()), int(rows.max()), mask.sum(axis=1)


def top_trim(profile, y0, y1, max_share, min_gap):
    """The row the map should start at, dropping leading ISLANDS its body is far away from.

    The bounding box is set by the map's extreme points, and its topmost is a single blob with a
    long emptiness under it — measured on the 2026-09-09 artifact, 19 ink pixels at rows 58..62 and
    then 157 empty rows. Framed to the box, the title stood 9 px off the map's EXTENT and 248 px off
    anything that reads as the map, while the bottom edge was dense to its last row.

    An island is cut only when it is BOTH negligible and detached: the ink above the gap below it
    must be within `max_share` of the map's total, and that gap must run at least `min_gap` rows.
    Cutting is then repeated, so a chain of specks goes in one pass and a real cluster stops it.

    This is the ONE place the film stops drawing everything the harness drew, so the caller prints
    what went: in ink pixels and as a share, never in documents, because a point may be a pixel or
    several and this measures pixels.
    """
    total = int(profile.sum())
    start = y0
    while True:
        y, gap = start, None
        while y <= y1:
            if profile[y]:
                y += 1
                continue
            run_end = y
            while run_end <= y1 and not profile[run_end]:
                run_end += 1
            if run_end - y >= min_gap and run_end <= y1:
                gap = (y, run_end)
                break
            y = run_end
        if gap is None:
            break
        above = int(profile[start:gap[0]].sum())
        if above > total * max_share:
            break
        start = gap[1]
    return start, int(profile[y0:start].sum()), total


first, last = bbox(sys.argv[1]), bbox(sys.argv[2])
# Invariant 1: the ghosted points hold the extent still. One pixel of antialiasing drift is fine.
for i, name in enumerate(("width", "height", "x0", "x1", "y0", "y1")):
    if abs(first[i] - last[i]) > 2:
        sys.exit(f"content {name} moved between the first and last frame "
                 f"({first[i]} -> {last[i]}). One crop cannot serve the whole film; "
                 f"the harness may have stopped drawing out-of-scope documents.")
max_share = float(sys.argv[3])
trim_y, trim_ink, total_ink = (last[4], 0, int(last[6].sum())) if max_share <= 0 else \
    top_trim(last[6], last[4], last[5], max_share, int(sys.argv[4]))
print(" ".join(str(v) for v in last[:6]) + f" {trim_y} {trim_ink} {total_ink}")
PY
)

CONTENT_W=$(( X1 - X0 + 1 ))
CONTENT_H=$(( Y1 - Y0 + 1 ))
DEAD_W=$(( FW - CONTENT_W ))
echo "   frame ${FW}x${FH}; content x ${X0}..${X1} (${CONTENT_W}) y ${Y0}..${Y1} (${CONTENT_H})"
printf '   dead width %d px (%.1f%% of the frame)\n' "$DEAD_W" \
  "$(python3 -c "print($DEAD_W / $FW * 100)")"

# The map's rows, after dropping any leading island — see `top_trim` above. Printed whatever it
# decides, including when it decides nothing, because this is where the film stops drawing
# everything the harness drew.
MAP_H=$(( Y1 - TRIM_Y + 1 ))
if (( TRIM_Y > Y0 )); then
  printf '   top trim: map starts at row %d, not %d — dropping %d of %d ink px (%.4f%%) and reclaiming %d rows\n' \
    "$TRIM_Y" "$Y0" "$TRIM_INK" "$TOTAL_INK" \
    "$(python3 -c "print($TRIM_INK / $TOTAL_INK * 100)")" "$(( TRIM_Y - Y0 ))"
else
  echo "   top trim: none — the map's full ${CONTENT_H} rows are framed"
fi

# Invariant 2: never crop into the map.
if (( WIDTH < CONTENT_W )); then
  echo "refusing: --width $WIDTH is narrower than the drawn content ($CONTENT_W px); it would clip documents" >&2
  exit 1
fi
OFFSET=$(( (FW - WIDTH) / 2 ))
if (( OFFSET > X0 || OFFSET + WIDTH <= X1 )); then
  echo "refusing: a centred ${WIDTH}px crop at x=${OFFSET} would clip content spanning ${X0}..${X1}" >&2
  exit 1
fi
echo "== text =="
# One formatter for both the sidecar tracks and the burned-in volume caption: `make_subtitles.py`
# writes the `.srt`/`.vtt` files AND the per-frame TSV the renderer draws from, so the pixels and the
# sidecar cannot disagree about what a frame says. The per-frame sidecar is still written although it
# is no longer muxed — it is the film's provenance made addressable, and text burned into pixels can
# be neither searched nor copied.
python3 "$HERE/make_subtitles.py" --fps "$FPS" --captions-tsv frame-captions.tsv
python3 "$HERE/make_subtitles.py" --fps "$FPS" --group-by-year

echo "== captions =="
swift "$HERE/render_caption.swift" --out caption-band.png \
  --width "$WIDTH" --fit-height --font-size "$FONT_SIZE" \
  --margin-x 70 --margin-y "$CAPTION_MARGIN_Y" --text "$CAPTION"
# Cleared first: ffmpeg reads an image sequence until the first gap, so captions left by a longer
# earlier run would outlive this film's last frame.
rm -rf captions
swift "$HERE/render_frame_captions.swift" --tsv frame-captions.tsv --out-dir captions \
  --width "$WIDTH" --font-size "$VOLUME_FONT_SIZE" --margin-x 70 --margin-y "$CAPTION_MARGIN_Y"

echo "== layout =="
height_of() { ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$1"; }
width_of()  { ffprobe -v error -select_streams v:0 -show_entries stream=width  -of csv=p=0 "$1"; }
# Ink inside a rect of a SOURCE frame, by the same modal-luma rule the preflight measures the bbox
# with, so "covers the map" means here what it means there.
ink_in() {
  python3 "$HERE/.ink_in.py" "$@"
}
TOP_H=$(height_of caption-band.png)
BOT_H=$(height_of captions/caption-0000.png)
STACK_H=$(( TOP_H + MAP_H + BOT_H ))
# Invariant 3: THE FRAME IS SIZED TO THE STACK. The output used to be the source's 1080 and the map
# was fitted into what the captions left; now the map's rows are decided first — by the bounding box
# and the top trim — and the frame is exactly as tall as the three parts need, rounded up to an even
# number for h264. So there is no leftover to distribute and no arrangement in which a caption and
# the map can be further apart than a band's own margin.
OUT_H=$(( STACK_H + STACK_H % 2 ))
if (( OUT_H > FH )); then
  echo "refusing: title ${TOP_H}px + map ${MAP_H}px + volume caption ${BOT_H}px = ${OUT_H}px, taller than the ${FH}px source frame" >&2
  exit 1
fi
SLACK=$(( OUT_H - STACK_H ))
TOP_Y=$(( SLACK / 2 ))
MAP_Y=$(( TOP_Y + TOP_H ))
CAP_Y=$(( MAP_Y + MAP_H ))
echo "   crop ${WIDTH}x${MAP_H}+${OFFSET}+${TRIM_Y}, reclaiming $(( FW - WIDTH )) px of width"
echo "   frame ${WIDTH}x${OUT_H}: title ${TOP_H} @ y=${TOP_Y} | map ${MAP_H} @ y=${MAP_Y} | volume ${BOT_H} @ y=${CAP_Y}"

BADGE_STAGE=""
BADGE_INPUT=()
if (( BADGE )); then
  echo "== badge =="
  [[ -f "$ICON" ]] || { echo "no app icon at $ICON; pass --icon or --no-badge" >&2; exit 1; }
  swift "$HERE/render_badge.swift" --out badge.png --icon "$ICON" \
    --icon-size "$BADGE_ICON_SIZE" --font-size "$BADGE_FONT_SIZE" --text "$BADGE_TEXT"
  BADGE_W=$(width_of badge.png)
  BADGE_H=$(height_of badge.png)
  case "$BADGE_CORNER" in
    bottom-right) BADGE_X=$(( WIDTH - BADGE_MARGIN - BADGE_W )) ;;
    bottom-left)  BADGE_X=$BADGE_MARGIN ;;
    *) echo "unknown --badge-corner $BADGE_CORNER (bottom-left, bottom-right)" >&2; exit 2 ;;
  esac
  BADGE_Y=$(( MAP_Y + MAP_H - BADGE_MARGIN - BADGE_H ))

  # THE BADGE MAY NOT COVER THE MAP, and that is measured rather than eyeballed. It sits over ground
  # in a corner of the map region, but what is under it is a property of the projection: a
  # re-clustered artifact could put a cluster there and the badge would quietly hide documents. The
  # rect is converted back to source coordinates and measured on the same frame the bbox came from,
  # against the same cap the top trim uses.
  UNDER=$(ink_in "$LAST" "$(( OFFSET + BADGE_X ))" "$(( TRIM_Y + BADGE_Y - MAP_Y ))" "$BADGE_W" "$BADGE_H")
  LIMIT=$(python3 -c "print(int($TOTAL_INK * $TOP_TRIM_MAX_SHARE))")
  if (( UNDER > LIMIT )); then
    echo "refusing: a ${BADGE_CORNER} badge would cover ${UNDER} ink px of the map (cap ${LIMIT}); try --badge-corner, --badge-margin or --no-badge" >&2
    exit 1
  fi
  echo "   badge ${BADGE_W}x${BADGE_H} ${BADGE_CORNER} at (${BADGE_X},${BADGE_Y}); it covers ${UNDER} ink px of the map"
  BADGE_INPUT=(-i badge.png)
  BADGE_STAGE="[c];[c][3:v]overlay=${BADGE_X}:${BADGE_Y}"
fi

echo "== encode =="
# The map is cropped to exactly its drawn rows and padded back to the frame with the map's own
# ground, so the join is invisible; the two captions are laid over the padding, never over the map.
# Both image sequences run at the same rate from frame 0, so overlay pairs frame N's volume caption
# with frame N of the film.
ffmpeg -hide_banner -v warning -y \
  -framerate "$FPS" -i frame-%04d.png -i caption-band.png \
  -framerate "$FPS" -i captions/caption-%04d.png "${BADGE_INPUT[@]}" \
  -filter_complex "[0:v]crop=${WIDTH}:${MAP_H}:${OFFSET}:${TRIM_Y},pad=${WIDTH}:${OUT_H}:0:${MAP_Y}:color=0x0F1217[m];[m][1:v]overlay=0:${TOP_Y}[t];[t][2:v]overlay=0:${CAP_Y}${BADGE_STAGE},format=yuv420p" \
  -c:v libx264 -crf "$CRF" -preset slow -movflags +faststart map-film.mp4

# NO SUBTITLE TRACK IS MUXED, and both halves of the reason were measured on the 2026-09-20 build.
#
# The per-frame track's text is in the picture now; a player showing it as well would draw a second
# copy of the volume caption on top of the first. And the year track CANNOT be muxed switched off:
# built with `-disposition:s:0 0`, it came back `default=1`, because ffmpeg's MP4 muxer enables the
# first subtitle track of a file when none is marked default — which is how the per-frame track came
# to be on screen, over the map, in every player. Enabled, the year cue would land on the new volume
# band. It would also say nothing the band does not: the year and both running totals are the band's
# first line, on every frame.
#
# Both tracks are still WRITTEN, as `.srt`/`.vtt` sidecars beside the film (see `== text ==`), for
# anyone who wants the volume sequence as searchable, copyable text.

echo "== result =="
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,nb_frames:stream_disposition=default \
        -show_entries format=duration,size -of default=noprint_wrappers=1 map-film.mp4
