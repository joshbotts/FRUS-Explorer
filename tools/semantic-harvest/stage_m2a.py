#!/usr/bin/env python3
"""M2a — stage the exhaustive prose ground truth, and collect it once it is keyed.

M2a is the gate the whole detection half of #234 waits on: until a human has marked
EVERY person mention in a stratified sample of documents, no detector's output can be
scored, and `Planning/People-Early-Era-Program.md` §5 forbids shipping anything derived
from an unscored extraction. This script is the two mechanical halves around the one
part that is irreducibly owner work.

    python3 stage_m2a.py              # stage: write the annotation files + progress.csv
    COLLECT=1 python3 stage_m2a.py    # collect: parse them back into ground-truth spans
    SELFTEST=1 python3 stage_m2a.py   # round-trip over fixtures (see selftest_m2a.py)

Annotation is by editing text, not by typing offsets. Each sampled document is written
out as its exact R-0 text with the editors' own <persName> mentions already wrapped in
⟦…⟧, and the owner wraps the ones the editors left unmarked — which M1a puts at roughly
two thirds of all mentions. Three properties make that safe:

  * offsets are never typed, they are derived by removing the brackets, so an annotation
    lands in exactly the coordinate space the detectors and the chunk vectors use;
  * the collector strips the brackets and requires the result to equal the R-0 text
    character for character, so an accidental edit to the prose is caught rather than
    silently shifting every later span in the document;
  * seeding with the editors' markup cuts the work by about a third AND makes the
    annotator's disagreements visible — a removed ⟦…⟧ is recorded as a rejected editor
    span, and the collector reports how many there were.

The seeding is a deliberate trade with a stated cost: it biases the annotator toward
accepting editor markup. The instructions ask for each seeded span to be checked rather
than assumed, and the count of rejected ones is the only evidence that happened.

Environment:
  STORE       the NER store (default ~/frus-ner-raw) — scope.json + marked/
  TEXT_DIR    the embeddings store's text/ (default ~/frus-semantic-raw/text)
  OUT_DIR     where the annotation files go (default ~/frus-m2a)
  DOCS        documents to stage, split evenly across the four bands (default 72)
  VOLS_PER_BAND  volumes to draw them from, per band (default 6)
  MIN_CHARS / MAX_CHARS  document length window (default 800 / 8000)
  SEED        default 234, m1a_survey.py's seed
  COLLECT     =1 to run the collector instead of the stager
  FORCE       =1 to re-stage over a directory that already holds annotated work
"""

import csv
import hashlib
import json
import os
import random
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ner_store as store  # noqa: E402

STORE = os.path.expanduser(os.environ.get("STORE", "~/frus-ner-raw"))
TEXT_DIR = os.path.expanduser(os.environ.get("TEXT_DIR", "~/frus-semantic-raw/text"))
OUT = os.path.expanduser(os.environ.get("OUT_DIR", "~/frus-m2a"))
DOCS = int(os.environ.get("DOCS", "72"))
VOLS_PER_BAND = int(os.environ.get("VOLS_PER_BAND", "6"))
MIN_CHARS = int(os.environ.get("MIN_CHARS", "800"))
MAX_CHARS = int(os.environ.get("MAX_CHARS", "8000"))
SEED = os.environ.get("SEED", "234")

OPEN, CLOSE = "⟦", "⟧"
BRACKETED = re.compile(OPEN + r"(.*?)" + CLOSE, re.S)

INSTRUCTIONS = """# M2a — exhaustive person-mention annotation

One file per document, named `<volume>__<documentId>.txt`. Each is the exact text a
detector sees. Some mentions are already wrapped in %(open)s…%(close)s — those are the ones the
FRUS editors marked up themselves. **Your job is every mention they did not.**

## The rule

Wrap every span of text that **names an individual human being**, exactly as printed:

* include the title or honorific when it is attached to the name — %(open)sMr. Bevin%(close)s,
  %(open)sSir Edward Grey%(close)s, %(open)sCount Bernstorff%(close)s;
* include a bare surname when it names a person — %(open)sMarshall%(close)s;
* include signature lines, and names inside parenthetical identifications such as
  the Under Secretary of State ( %(open)sLovett%(close)s );
* **exclude** countries, cities, ships, treaties, conferences, legations, departments,
  companies, and every other non-person name;
* **exclude** a title with no name attached — "the Secretary of State" on its own is not
  a mention.

Wrap **every occurrence**, not the first one. If a name appears eleven times, it is
eleven mentions. That is what makes this *exhaustive*, and it is what recall is measured
against.

## Checking what is already wrapped

The seeded spans are the editors' markup, not ground truth. If one is wrong — a place
name marked as a person, a span that swallows a title it should not, a mention that runs
into the next word — **remove its brackets**. The collector counts those, and that count
is the only evidence anyone reviewed them rather than trusting them.

## The one hard rule

**Change nothing but the brackets.** Do not fix a typo, re-wrap a line, or delete a
stray character. The collector strips the brackets and compares the result to the
original character for character; a document that fails that check is rejected with its
name printed, because a single edited character moves every span after it.

## When a document is done

Mark it `y` in the `annotated` column of `progress.csv`. The collector ignores every row
that is not marked, so a half-finished sitting costs nothing — it just yields a smaller
ground truth, and the collector tells you how much smaller.

If you read a document and there is genuinely nothing to add — every mention was already
wrapped — mark it **`none`** rather than `y`. The collector refuses a `y` on a file that
is byte-identical to what was staged, because that is far likelier to be a mis-marked row
than a real verdict, and collecting it would promote the editors' seed to ground truth and
report the markup share as 100%%.
""" % {"open": OPEN, "close": CLOSE}


def sha256_text(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def stage():
    volumes = store.scope_volumes(STORE)
    by_band = {}
    for volume in volumes:
        band = store.band_of(volume)
        if band:
            by_band.setdefault(band, []).append(volume)

    os.makedirs(OUT, exist_ok=True)
    # Re-staging over a directory that already holds keyed work would destroy it silently:
    # the .txt files are overwritten with fresh seeds and progress.csv is rewritten empty.
    existing = os.path.join(OUT, "progress.csv")
    if os.path.exists(existing) and not os.environ.get("FORCE"):
        with open(existing, newline="", encoding="utf-8") as handle:
            keyed = [row for row in csv.DictReader(handle) if (row.get("annotated") or "").strip()]
        if keyed:
            sys.exit("%s already holds %d annotated document(s). Re-staging would overwrite the "
                     "files and the progress marks.\nCollect first, or stage into a different "
                     "OUT_DIR, or set FORCE=1 if you really mean to discard the sitting."
                     % (OUT, len(keyed)))
    staged = []
    skipped = {"volumes_without_marked_layer": 0, "volumes_without_text_layer": 0,
               "documents_with_bracket_char": 0,
               "documents_with_overlapping_marked_spans": 0}
    outside_window = 0

    # DOCS is the number of documents, not a hint: floor division twice made the achievable
    # count a multiple of bands x volumes-per-band, so DOCS=60 staged 48 and DOCS=12 staged 24
    # — a sample size nobody asked for, quoted later as if they had. Remainders are distributed
    # instead, and a volume is allowed to contribute nothing.
    band_names = sorted(by_band)
    band_base, band_extra = divmod(DOCS, max(1, len(band_names)))
    for band_index, band in enumerate(band_names):
        band_target = band_base + (1 if band_index < band_extra else 0)
        picker = random.Random("%s:%s" % (SEED, band))
        pool = sorted(by_band[band])
        chosen_volumes = sorted(picker.sample(pool, min(VOLS_PER_BAND, len(pool))))
        staged_in_band = len(staged)
        # Documents are drawn per volume so the sample spreads across the band rather
        # than landing in whichever volume happens to be largest.
        base, extra = divmod(band_target, len(chosen_volumes))
        for position, volume in enumerate(chosen_volumes):
            want_each = base + (1 if position < extra else 0)
            if want_each == 0:
                continue
            marked = store.volume_layer(STORE, "marked", volume)
            if not marked and store.layer_head(STORE, "marked", volume) is None:
                skipped["volumes_without_marked_layer"] += 1
                continue
            # scope.json comes from the TEI corpus and TEXT_DIR from a separate embeddings
            # harvest, so the two drifting apart by a volume is a real state. Skipping it is
            # recoverable; aborting mid-loop would leave annotation files on disk with no
            # manifest and no progress.csv, which reads as a corrupt output directory.
            if not any(os.path.exists(os.path.join(TEXT_DIR, volume + suffix))
                       for suffix in (".jsonl.gz", ".jsonl")):
                skipped["volumes_without_text_layer"] += 1
                continue
            texts = store.volume_text(TEXT_DIR, volume)
            spans = store.spans_by_document(marked)
            candidates = sorted(doc for doc, text in texts.items()
                                if MIN_CHARS <= len(text) <= MAX_CHARS)
            outside_window += len(texts) - len(candidates)
            if not candidates:
                continue
            doc_picker = random.Random("%s:%s:docs" % (SEED, volume))
            for doc_id in sorted(doc_picker.sample(candidates,
                                                   min(want_each, len(candidates)))):
                text = texts[doc_id]
                if OPEN in text or CLOSE in text:
                    skipped["documents_with_bracket_char"] += 1
                    continue
                doc_spans = spans.get(doc_id, [])
                store.check_spans(text, doc_spans, "%s/%s" % (volume, doc_id))
                if any(a[1] > b[0] for a, b in zip(doc_spans, doc_spans[1:])):
                    skipped["documents_with_overlapping_marked_spans"] += 1
                    continue
                name = "%s__%s.txt" % (volume, doc_id)
                staged_body = wrap(text, doc_spans)
                with open(os.path.join(OUT, name), "w", encoding="utf-8") as handle:
                    handle.write(staged_body)
                staged.append({"file": name, "volume": volume, "document": doc_id,
                               "band": band, "chars": len(text),
                               "seeded_spans": len(doc_spans),
                               # The spans as staged, not just how many. The collector needs
                               # to know which spans the annotator was SHOWN, and re-deriving
                               # them from the marked layer at collect time would silently
                               # follow a re-harvest: a shifted span would then read as the
                               # annotator having rejected one and added another.
                               "seeded": [[start, end] for start, end, _ in doc_spans],
                               "text_sha256": sha256_text(text),
                               # The bytes as HANDED OVER. An annotated file that still hashes
                               # to this was never touched, and collecting it would promote the
                               # editors' own seed to ground truth and report the markup share
                               # as 100% — a measurement of nothing, phrased as the real one.
                               "staged_sha256": sha256_text(staged_body)})

    with open(os.path.join(OUT, "progress.csv"), "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["file", "volume", "document", "band", "chars", "seeded_spans",
                         "annotated"])
        for row in staged:
            writer.writerow([row["file"], row["volume"], row["document"], row["band"],
                             row["chars"], row["seeded_spans"], ""])
    open(os.path.join(OUT, "M2a-INSTRUCTIONS.md"), "w", encoding="utf-8").write(INSTRUCTIONS)
    json.dump({"generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
               "seed": SEED, "docs_requested": DOCS, "vols_per_band": VOLS_PER_BAND,
               "min_chars": MIN_CHARS, "max_chars": MAX_CHARS,
               "store": STORE, "text_dir": TEXT_DIR,
               "documents_outside_length_window": outside_window,
               "skipped": skipped, "documents": staged},
              open(os.path.join(OUT, "m2a-manifest.json"), "w"), indent=1, sort_keys=True)

    if not staged:
        sys.exit("staged nothing: %d documents fell outside the %d–%d character window and %d "
                 "volume(s) had no marked layer.\nWiden MIN_CHARS/MAX_CHARS or check STORE — an "
                 "empty sample reads downstream as an un-keyed one."
                 % (outside_window, MIN_CHARS, MAX_CHARS,
                    skipped["volumes_without_marked_layer"]))

    seeded = sum(row["seeded_spans"] for row in staged)
    print("staged %d documents (%d chars, %d seeded spans) -> %s"
          % (len(staged), sum(r["chars"] for r in staged), seeded, OUT))
    for band in sorted({row["band"] for row in staged}):
        rows = [r for r in staged if r["band"] == band]
        print("  %-10s %3d docs, %6d chars, %4d seeded"
              % (band, len(rows), sum(r["chars"] for r in rows),
                 sum(r["seeded_spans"] for r in rows)))
    print("skipped: %s; %d documents fell outside the %d–%d character window"
          % (skipped, outside_window, MIN_CHARS, MAX_CHARS))
    if len(staged) != DOCS:
        print("note: staged %d, not the %d requested — some volumes had too few documents in "
              "the length window." % (len(staged), DOCS))
    empty_bands = [band for band in band_names
                   if not any(row["band"] == band for row in staged)]
    if empty_bands:
        print("!! WARNING: no documents staged for %s. Era stratification is the reason this "
              "sample exists; a band with nothing in it cannot be scored."
              % ", ".join(empty_bands))
    print("\nNext: read M2a-INSTRUCTIONS.md, annotate, mark progress.csv, then\n"
          "  COLLECT=1 OUT_DIR=%s python3 stage_m2a.py" % OUT)


def wrap(text, spans):
    """The document with each span bracketed. Spans must be sorted and non-overlapping."""
    pieces, cursor = [], 0
    for start, end, _ in spans:
        pieces.append(text[cursor:start])
        pieces.append(OPEN + text[start:end] + CLOSE)
        cursor = end
    pieces.append(text[cursor:])
    return "".join(pieces)


def unwrap(annotated):
    """(plain_text, [(start, end, surface)]) — offsets into the bracket-free text."""
    pieces, spans, cursor, length = [], [], 0, 0
    for match in BRACKETED.finditer(annotated):
        before = annotated[cursor:match.start()]
        pieces.append(before)
        length += len(before)
        surface = match.group(1)
        spans.append((length, length + len(surface), surface))
        pieces.append(surface)
        length += len(surface)
        cursor = match.end()
    pieces.append(annotated[cursor:])
    return "".join(pieces), spans


def collect():
    manifest_path = os.path.join(OUT, "m2a-manifest.json")
    if not os.path.exists(manifest_path):
        sys.exit("no m2a-manifest.json in %s — stage before collecting." % OUT)
    manifest = json.load(open(manifest_path))
    if manifest.get("store") and manifest["store"] != STORE:
        sys.exit("this sample was staged against %s but STORE is %s.\nThe seeded/added split is "
                 "computed from the store that staged it; collecting against another one would "
                 "mis-attribute the annotator's work. Set STORE to the staging store."
                 % (manifest["store"], STORE))
    by_file = {row["file"]: row for row in manifest["documents"]}

    done, marks, seen = [], {}, set()
    with open(os.path.join(OUT, "progress.csv"), newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            mark = (row.get("annotated") or "").strip().lower()
            if mark not in ("y", "yes", "1", "done", "none"):
                continue
            if row["file"] in seen:
                sys.exit("progress.csv names %s twice. A duplicated row collects the document "
                         "twice, doubling its mentions in the ground truth and halving the "
                         "recall of a detector that got it right." % row["file"])
            seen.add(row["file"])
            marks[row["file"]] = mark
            done.append(row["file"])

    rows, rejected_total, added_total = [], 0, 0
    per_band = {}
    for name in sorted(done):
        entry = by_file.get(name)
        if entry is None:
            sys.exit("progress.csv names a file the manifest does not: %s" % name)
        path = os.path.join(OUT, name)
        if not os.path.exists(path):
            sys.exit("progress.csv marks %s annotated, but the file is not in %s.\nRestore it "
                     "or clear its mark — a document cannot be collected from its manifest row."
                     % (name, OUT))
        annotated = open(path, encoding="utf-8").read()
        # An untouched file is the quiet failure this whole loop has to defend against: it
        # still parses, still round-trips, and collects the EDITORS' seed as though a human
        # had verified it — reporting the markup share as 100% and calling it the real
        # measurement. `none` is how you say "read it, nothing to add"; a bare `y` on
        # unchanged bytes is far likelier to be a mis-marked row than a real verdict.
        if entry.get("staged_sha256") and sha256_text(annotated) == entry["staged_sha256"] \
                and marks.get(name) != "none":
            sys.exit("%s is byte-identical to what was staged — nothing was annotated.\nIf you "
                     "read it and there is genuinely nothing to add, mark it `none` in "
                     "progress.csv rather than `y`; otherwise annotate it or clear the mark."
                     % name)
        plain, spans = unwrap(annotated)
        leftover = plain.find(OPEN) if OPEN in plain else plain.find(CLOSE)
        if leftover != -1:
            sys.exit("%s: a stray %s or %s survives at offset %d — a nested pair, an unclosed "
                     "one, or a reversed one.\nThe brackets must nest not at all and match "
                     "exactly; fix that pair and collect again."
                     % (name, OPEN, CLOSE, leftover))
        empty = [start for start, end, surface in spans if not surface.strip()]
        if empty:
            sys.exit("%s: an empty or blank %s%s pair at offset %d.\nIt would enter the ground "
                     "truth as a mention no detector can match and no reader can check. Remove "
                     "it (or wrap the name you meant) and collect again."
                     % (name, OPEN, CLOSE, empty[0]))
        if sha256_text(plain) != entry["text_sha256"]:
            sys.exit("%s: the text changed under the brackets.\nStripping them must "
                     "reproduce the R-0 text exactly — a single edited character moves "
                     "every span after it. Restore the prose (the brackets are the only "
                     "permitted edit) and collect again." % name)
        seeded = {(start, end) for start, end in entry.get("seeded", [])}
        kept = {(s, e) for s, e, _ in spans}
        rejected = len(seeded - kept)
        added = len(kept - seeded)
        rejected_total += rejected
        added_total += added
        band = per_band.setdefault(entry["band"], {"docs": 0, "spans": 0, "seeded_kept": 0,
                                                   "added": 0, "rejected": 0})
        band["docs"] += 1
        band["spans"] += len(spans)
        band["seeded_kept"] += len(seeded & kept)
        band["added"] += added
        band["rejected"] += rejected
        for start, end, surface in spans:
            rows.append({"v": entry["volume"], "d": entry["document"], "s": start,
                         "e": end, "n": surface, "seeded": (start, end) in seeded,
                         "band": entry["band"]})

    if not rows:
        sys.exit("nothing marked annotated in progress.csv — no ground truth to collect.\n"
                 "That is the gate, not a bug: mark documents `y` as you finish them.")

    out_path = os.path.join(OUT, "m2a-ground-truth.jsonl")
    with open(out_path, "w", encoding="utf-8") as handle:
        for row in sorted(rows, key=lambda r: (r["v"], r["d"], r["s"], r["e"])):
            handle.write(json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n")

    total = len(rows)
    kept_seeded = sum(b["seeded_kept"] for b in per_band.values())
    summary = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "documents_annotated": len(done), "documents_staged": len(by_file),
        "mentions": total, "from_editor_markup": kept_seeded, "added_by_annotator": added_total,
        "editor_spans_rejected": rejected_total,
        "measured_markup_share": round(kept_seeded / total, 4) if total else None,
        "by_band": per_band,
    }
    json.dump(summary, open(os.path.join(OUT, "m2a-collection-summary.json"), "w"),
              indent=1, sort_keys=True)
    print("collected %d mentions over %d of %d staged documents -> %s"
          % (total, len(done), len(by_file), out_path))
    print("  %d from editor markup, %d added, %d editor spans rejected"
          % (kept_seeded, added_total, rejected_total))
    if total:
        print("  measured markup share: %.1f%%  (M1a's regex proxy estimated ~34%% and "
              "called itself a lower bound — this is the real measurement)"
              % (100.0 * kept_seeded / total))
    for band in sorted(per_band):
        stats = per_band[band]
        share = stats["seeded_kept"] / stats["spans"] if stats["spans"] else 0
        print("  %-10s %3d docs  %5d mentions  %.1f%% marked up"
              % (band, stats["docs"], stats["spans"], 100.0 * share))


def main():
    if os.environ.get("COLLECT"):
        collect()
    else:
        stage()


if __name__ == "__main__":
    if os.environ.get("SELFTEST"):
        import selftest_m2a
        selftest_m2a.run()
    else:
        main()
