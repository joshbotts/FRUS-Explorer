#!/usr/bin/env bash
#
# Finish the semantic-map film: crop the dead width, burn the grain sentence into the reclaimed
# margin, and mux the subtitle tracks. (Visual-marketing plan §7 step 11 / plan-of-record F-1.)
#
# NO RE-RENDER. It consumes the 553 PNGs the capture harness already wrote; the frames are the
# expensive part and they are correct. This stage is assembly.
#
# THE GEOMETRY IS MEASURED, NOT ASSUMED, and that is the point of the preflight below. Measured on
# the shipped 1920x1080 frames the drawn content occupies x 418..1501 (1084 px) and y 109..970
# (862 px) — so 836 px, 43.5% of the width, is empty ground, which is the "~44% dead width" the plan
# names. Cropping to 1440 removes 480 of it and leaves ~178 px of margin a side, plus the 109 px band
# above the map that the grain sentence goes into.
#
# TWO INVARIANTS ARE CHECKED BEFORE ANYTHING IS ENCODED, because both fail silently otherwise:
#
#   1. THE BOUNDING BOX MUST BE THE SAME ON THE FIRST FRAME AS ON THE LAST. It is, today, because
#      out-of-scope documents are GHOSTED rather than removed, so every frame draws all 314,483
#      points and the extent never moves. If a future harness stopped drawing the ghosts, the box
#      would grow through the film and a single crop would clip the later frames — with no error.
#   2. THE CROP MUST NOT CLIP THE CONTENT. A width chosen for composition can be narrower than the
#      map; the script refuses rather than quietly cutting documents off the edge of a figure.
#
# `cropdetect` IS THE WRONG TOOL HERE and was tried first: run against `map.mp4` at limit 2, 8 and 24
# it reports no crop at all, because h264 ringing in the flat #0f1217 ground lifts border pixels over
# the threshold. The box has to be measured on the PNGs.
#
# THE CAPTION IS RENDERED BY A SWIFT SCRIPT, not by ffmpeg: this ffmpeg build has no `drawtext`, no
# `subtitles` and no `ass` filter — it can mux a subtitle track but cannot draw a glyph. See
# `render_caption.swift`.
#
# Usage:  ./build_film.sh [--frames-dir DIR] [--width 1440] [--fps 12] [--font-size 26] [--crf 18]

set -euo pipefail

FRAMES_DIR="${HOME}/Desktop/frus-map-film"
WIDTH=1440
FPS=12
FONT_SIZE=26
CRF=18
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --frames-dir) FRAMES_DIR="$2"; shift 2 ;;
    --width)      WIDTH="$2";      shift 2 ;;
    --fps)        FPS="$2";        shift 2 ;;
    --font-size)  FONT_SIZE="$2";  shift 2 ;;
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
read -r FW FH X0 X1 Y0 Y1 < <(
  python3 - "frame-0000.png" "$LAST" <<'PY'
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
    return w, h, int(cols.min()), int(cols.max()), int(rows.min()), int(rows.max())

first, last = bbox(sys.argv[1]), bbox(sys.argv[2])
# Invariant 1: the ghosted points hold the extent still. One pixel of antialiasing drift is fine.
for i, name in enumerate(("width", "height", "x0", "x1", "y0", "y1")):
    if abs(first[i] - last[i]) > 2:
        sys.exit(f"content {name} moved between the first and last frame "
                 f"({first[i]} -> {last[i]}). One crop cannot serve the whole film; "
                 f"the harness may have stopped drawing out-of-scope documents.")
print(" ".join(str(v) for v in last))
PY
)

CONTENT_W=$(( X1 - X0 + 1 ))
CONTENT_H=$(( Y1 - Y0 + 1 ))
DEAD_W=$(( FW - CONTENT_W ))
echo "   frame ${FW}x${FH}; content x ${X0}..${X1} (${CONTENT_W}) y ${Y0}..${Y1} (${CONTENT_H})"
printf '   dead width %d px (%.1f%% of the frame)\n' "$DEAD_W" \
  "$(python3 -c "print($DEAD_W / $FW * 100)")"

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
BAND_H=$Y0
echo "   crop ${WIDTH}x${FH}+${OFFSET}+0, reclaiming $(( FW - WIDTH )) px; caption band ${WIDTH}x${BAND_H}"

echo "== caption =="
# The sentence comes from the harness's own sidecar, never a literal here: if the harness rewords
# the grain statement, the film must follow it rather than assert the old one.
GRAIN=$(head -1 provenance.txt | sed 's/^# *//')
[[ -n "$GRAIN" ]] || { echo "provenance.txt line 1 is empty; nothing to caption" >&2; exit 1; }
swift "$HERE/render_caption.swift" --out caption-band.png \
  --width "$WIDTH" --height "$BAND_H" --font-size "$FONT_SIZE" \
  --margin-x 70 --margin-y 12 --text "$GRAIN"

echo "== subtitles =="
python3 "$HERE/make_subtitles.py" --fps "$FPS"
python3 "$HERE/make_subtitles.py" --fps "$FPS" --group-by-year

echo "== encode =="
ffmpeg -hide_banner -v warning -y \
  -framerate "$FPS" -i frame-%04d.png -i caption-band.png \
  -filter_complex "[0:v]crop=${WIDTH}:${FH}:${OFFSET}:0[c];[c][1:v]overlay=0:0,format=yuv420p" \
  -c:v libx264 -crf "$CRF" -preset slow -movflags +faststart map-film-silent.mp4

echo "== mux the tracks =="
# Soft subtitles, both tracks, so the viewer picks: the per-frame track is a scrubbing aid and the
# year track is the one that reads at speed. `mov_text` is the MP4-native subtitle codec.
ffmpeg -hide_banner -v warning -y -i map-film-silent.mp4 \
  -i map-subtitles.srt -i map-subtitles-years.srt \
  -map 0:v -map 1 -map 2 -c:v copy -c:s mov_text \
  -metadata:s:s:0 language=eng -metadata:s:s:0 title="Volumes (per frame)" \
  -metadata:s:s:1 language=eng -metadata:s:s:1 title="Years" \
  map-film.mp4
rm -f map-film-silent.mp4

echo "== result =="
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,nb_frames \
        -show_entries format=duration,size -of default=noprint_wrappers=1 map-film.mp4
