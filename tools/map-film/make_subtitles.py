#!/usr/bin/env python3
"""Cut a subtitle track from the map film's `frames.csv` (VM §7 step 11 / F-1).

The frame harness already writes one CSV row per frame carrying, as the plan observed, "exactly a
subtitle track's" fields — a frame index, the volume that lands on it, its publication year, and the
running totals. This turns those rows into SubRip and WebVTT.

WHAT THE TRACK IS FOR, because the arithmetic decides it and the answer is not "reading".
    553 frames at 12 fps is 83 ms a frame. Nothing is readable at that rate, and no cue design
    changes that — it is a property of the film's pace, not of the text. So the per-frame track is a
    SCRUBBING AID: pause anywhere and the cue names the volume that just landed, exactly. It is the
    film's provenance made addressable, and the sentence a viewer is meant to READ is burned into
    the frame instead (see `render_caption.swift`), where it does not move.

    `--group-by-year` emits the readable counterpart: one cue per publication year, 154 of them,
    averaging 0.30 s and running to 1.0 s on 1996's twelve volumes. Still brisk, but a year and a
    running total survive a glance where a 95-character title does not. Both tracks are generated
    and both are muxed; the viewer picks. Producing only one would have meant guessing which
    question the viewer had.

THREE THINGS THE DATA FORCES, each found by reading it rather than assuming:

    1. EVERY TITLE OPENS WITH THE SERIES NAME and it is pure redundancy here — every cue in this
       film is a FRUS volume, so "Foreign Relations of the United States, " spends 40 of a subtitle's
       ~62 columns saying what the film is. Stripped, along with the 19th-century series' own
       "Papers Relating to Foreign Affairs, Accompanying the Annual Message of the President ".

    2. TITLES RUN TO 498 CHARACTERS. The median is 95 and the 99th percentile 236, because the early
       appendix volumes list their whole contents in the title (`frus1865p4` names the Lincoln
       assassination correspondence). Wrapped to two lines and truncated with an ellipsis; the cue
       says what it can and the CSV remains the authority.

    3. THE LAST ROW IS NOT A VOLUME. Frame 552 is the closing unscoped frame: `volume_id` and
       `published` are empty and `volume_title` is "Complete series". A formatter that assumed a
       volume prints a cue reading " · 552 volumes" with a leading separator and no year.

Adjacent cues carrying identical text are merged, so a repeat renders as one continuous caption
rather than a flicker between two.

Usage:
    python3 make_subtitles.py [--csv frames.csv] [--fps 12] [--out-dir .] [--group-by-year]
"""

import argparse
import csv
import os
import sys

# Prefixes that carry no information inside this film, longest first so the longest match wins.
REDUNDANT_PREFIXES = (
    "Papers Relating to Foreign Affairs, Accompanying the Annual Message of the President to the ",
    "Papers Relating to the Foreign Relations of the United States, ",
    "Foreign Relations of the United States, ",
    "Papers Relating to Foreign Affairs, ",
)


def strip_series_prefix(title: str) -> str:
    """Removes the series name a cue does not need to repeat."""
    for prefix in REDUNDANT_PREFIXES:
        if title.startswith(prefix):
            rest = title[len(prefix):]
            return rest[0].upper() + rest[1:] if rest else title
    return title


def wrap(text: str, width: int, max_lines: int) -> str:
    """Greedy word wrap, truncated with an ellipsis at `max_lines`."""
    words, lines, line = text.split(), [], ""
    for word in words:
        candidate = word if not line else f"{line} {word}"
        if len(candidate) <= width:
            line = candidate
            continue
        if line:
            lines.append(line)
        if len(lines) == max_lines:
            break
        line = word
    else:
        if line:
            lines.append(line)
    if len(lines) == max_lines and len(" ".join(lines)) < len(text.rstrip()):
        lines[-1] = lines[-1][: width - 1].rstrip(" ,;:") + "…"
    return "\n".join(lines[:max_lines])


def timestamp(seconds: float, comma: bool) -> str:
    """`HH:MM:SS,mmm` for SubRip, `HH:MM:SS.mmm` for WebVTT."""
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}{',' if comma else '.'}{ms:03d}"


def cue_text(row: dict, width: int, max_lines: int) -> str:
    """One cue: the identifying line, then as much of the title as fits.

    THE VOLUME ID IS ON THE FIRST LINE and that is not decoration. This track exists to be paused
    on, and for the 19th-century volumes the title does not identify anything within a subtitle's
    room: `frus1865p4`'s runs to 498 characters and the part that distinguishes it — the Lincoln
    assassination correspondence — sits past character 300, so every truncation loses it. The id is
    eleven characters, unique, and is the key the reader would actually use: it is the path
    component in `history.state.gov/historicaldocuments/{volumeId}/{documentId}`.
    """
    volumes = int(row["cumulative_volumes"])
    documents = int(row["cumulative_documents"])
    published = row["published"].strip()
    counts = (f"{volumes:,} volume{'' if volumes == 1 else 's'} · "
              f"{documents:,} document{'' if documents == 1 else 's'}")
    # The closing frame has no year and no volume of its own; it is the whole series at rest.
    if not published:
        return f"{row['volume_title']} · {counts}"
    return (f"{published} · {row['volume_id']} · {counts}\n"
            f"{wrap(strip_series_prefix(row['volume_title']), width, max_lines)}")


def year_cue_text(published: str, rows: list, volumes: int, documents: int) -> str:
    """One cue per publication year: what landed that year, and the running total.

    A year that published exactly one volume names it, because the id fits and a bare "1 volume
    published this year" throws away the only fact the cue had room for. 45 of the 154 years are
    single-volume years, so this is most of the track's specificity, not an edge case.
    """
    counts = f"{volumes:,} volume{'' if volumes == 1 else 's'} · {documents:,} documents"
    if not published:
        return f"{rows[0]['volume_title']} · {counts}"
    added = len(rows)
    landed = (rows[0]["volume_id"] if added == 1
              else f"{added} volumes published this year")
    return f"{published} · {counts}\n{landed}"


def build_cues(rows, fps, width, max_lines, group_by_year):
    """Returns `(start_seconds, end_seconds, text)` triples, adjacent duplicates merged."""
    spans = []
    if group_by_year:
        run = []
        for row in rows:
            if run and run[-1]["published"] != row["published"]:
                spans.append(run)
                run = []
            run.append(row)
        if run:
            spans.append(run)
        raw = [(int(g[0]["frame"]), int(g[-1]["frame"]) + 1,
                year_cue_text(g[0]["published"], g,
                              int(g[-1]["cumulative_volumes"]), int(g[-1]["cumulative_documents"])))
               for g in spans]
    else:
        raw = [(int(r["frame"]), int(r["frame"]) + 1, cue_text(r, width, max_lines)) for r in rows]

    merged = []
    for start, end, text in raw:
        if merged and merged[-1][2] == text and merged[-1][1] == start:
            merged[-1][1] = end
        else:
            merged.append([start, end, text])
    return [(s / fps, e / fps, t) for s, e, t in merged]


def write_srt(cues, path):
    with open(path, "w", encoding="utf-8") as handle:
        for index, (start, end, text) in enumerate(cues, start=1):
            handle.write(f"{index}\n{timestamp(start, True)} --> {timestamp(end, True)}\n{text}\n\n")


def write_vtt(cues, path):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("WEBVTT\n\n")
        for start, end, text in cues:
            handle.write(f"{timestamp(start, False)} --> {timestamp(end, False)}\n{text}\n\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", default="frames.csv")
    parser.add_argument("--fps", type=float, default=12.0)
    parser.add_argument("--out-dir", default=".")
    parser.add_argument("--width", type=int, default=62, help="wrap columns for the title line")
    parser.add_argument("--max-lines", type=int, default=2, help="title lines before truncation")
    parser.add_argument("--group-by-year", action="store_true")
    parser.add_argument("--stem", default=None)
    args = parser.parse_args()

    with open(args.csv, encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        print(f"no rows in {args.csv}", file=sys.stderr)
        return 1

    frames = [int(r["frame"]) for r in rows]
    if frames != list(range(len(rows))):
        # A hole here means the film and the track would drift apart from that frame on, silently.
        print(f"frame column is not 0..{len(rows) - 1} with no gaps; refusing", file=sys.stderr)
        return 1

    cues = build_cues(rows, args.fps, args.width, args.max_lines, args.group_by_year)
    stem = args.stem or ("map-subtitles-years" if args.group_by_year else "map-subtitles")
    os.makedirs(args.out_dir, exist_ok=True)
    srt, vtt = os.path.join(args.out_dir, stem + ".srt"), os.path.join(args.out_dir, stem + ".vtt")
    write_srt(cues, srt)
    write_vtt(cues, vtt)
    print(f"{len(rows)} rows -> {len(cues)} cues, {cues[-1][1]:.2f}s -> {srt}, {vtt}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
