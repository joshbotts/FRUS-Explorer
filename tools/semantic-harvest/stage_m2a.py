#!/usr/bin/env python3
"""M2a — stage the exhaustive prose ground truth, and collect it once it is keyed.

M2a is the gate the whole detection half of #234 waits on: until a human has marked
EVERY person mention in a stratified sample of documents, no detector's output can be
scored, and `Planning/People-Early-Era-Program.md` §5 forbids shipping anything derived
from an unscored extraction. This script is the two mechanical halves around the one
part that is irreducibly owner work.

    python3 stage_m2a.py              # stage: write the annotation files + progress.csv
    COLLECT=1 python3 stage_m2a.py    # collect: parse them back into ground-truth spans, plus
                                      # the list of annotated documents (m2a-ground-truth-documents.jsonl)
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
  CONVERT_ASCII_BRACKETS  =1 with COLLECT=1: rewrite an annotator's INSERTED ASCII [ ] as ⟦ ⟧ before
              collecting, keeping the files as typed; refuses, converting nothing, if any is ambiguous
"""

import csv
import hashlib
import json
import os
import random
import re
import shutil
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
# What an annotator types when they miss the instruction above. FRUS prints these itself —
# `[Translation.]`, `[Received 4:43 p.m.]`, a bracketed sign-off — so they are never markup on their own;
# only one INSERTED relative to the R-0 text can be (see `ascii_bracket_plan`).
ASCII_OPEN, ASCII_CLOSE = "[", "]"
CONVERT_ASCII_BRACKETS = os.environ.get("CONVERT_ASCII_BRACKETS") == "1"

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

**Type %(open)s and %(close)s, not [ and ].** The documents print square brackets of their own —
`[Translation.]`, `[Received 4:43 p.m.]`, a bracketed sign-off such as `[Braden.]` — so a mention
typed in [ ] cannot be told apart from the text. The easy way to get the right ones is to copy a
pair from any seeded span. (The first sitting was typed with [ ] throughout; the collector now names
such documents, and `CONVERT_ASCII_BRACKETS=1` rewrites them where the text leaves no doubt.)

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
               "documents_with_overlapping_marked_spans": 0,
               "documents_with_span_mismatch": 0}
    span_mismatches = []
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
                # Counted, not aborted. `check_spans` raises SystemExit, and raising it HERE is
                # exactly what the comment above the text-layer skip says must not happen: the
                # .txt files staged so far are already on disk, while progress.csv, the
                # instructions and the manifest are all written after this loop — a directory
                # that looks staged, cannot be collected, and re-stages over its own orphans on
                # the next run. The mismatch is still fatal, just fatal AFTER the output
                # directory is coherent; see the exit below the manifest write.
                try:
                    store.check_spans(text, doc_spans, "%s/%s" % (volume, doc_id))
                except SystemExit as mismatch:
                    skipped["documents_with_span_mismatch"] += 1
                    if len(span_mismatches) < 5:
                        span_mismatches.append(str(mismatch))
                    continue
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

    # Now that progress.csv, the instructions and the manifest exist, a span mismatch can be
    # fatal without leaving a half-written directory behind. It IS fatal: the marked layer and
    # the R-0 text describing different corpora is not a per-document accident, and a sample
    # quietly missing whichever documents tripped it would be keyed, annotated, and quoted as
    # the measurement. The staged files stay on disk so the failure can be inspected.
    if skipped["documents_with_span_mismatch"]:
        sys.exit("%d document(s) were skipped because their marked spans do not slice back out "
                 "of the R-0 text — the two describe different corpora.\n%s\n"
                 "Everything else is staged in %s and the manifest records the skips; re-harvest "
                 "the marked layer against this text before keying the sample."
                 % (skipped["documents_with_span_mismatch"],
                    "\n".join("  " + m for m in span_mismatches), OUT))

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


def inserted_brackets(source, annotated):
    """Align `annotated` onto `source`, allowing only INSERTED bracket glyphs (⟦ ⟧ [ ]).

    Returns [(source_offset, glyph, annotated_index)] in file order, or None when the file differs
    from the source in any other way — a prose edit, which no bracket rule may paper over.

    Greedy leftmost matching is complete for this: a character is taken as inserted only when it
    cannot be the source's next character, so if ANY alignment exists whose extra characters are all
    brackets, this one's are too. Where an inserted bracket sits beside a printed bracket of the same
    glyph, the text cannot say which of the two was typed, and the alignment's choice there is
    arbitrary — `ascii_bracket_plan` refuses those rather than inherit it.
    """
    inserted, cursor = [], 0
    for index, char in enumerate(annotated):
        if cursor < len(source) and char == source[cursor]:
            cursor += 1
        elif char in (OPEN, CLOSE, ASCII_OPEN, ASCII_CLOSE):
            inserted.append((cursor, char, index))
        else:
            return None
    return inserted if cursor == len(source) else None


def ascii_bracket_plan(source, annotated):
    """(pairs, problems) for a file whose only edits are inserted brackets, some of them ASCII.

    pairs    — [(start, end)] in R-0 offsets, one per inserted [ … ] pair;
    problems — why those pairs cannot be converted safely; empty when they can.

    Returns None when the file is NOT this case: it has some other edit, or no ASCII bracket was
    inserted at all. The four refusals are each a way a mechanical rewrite would put a span somewhere
    the annotator did not: an inserted bracket touching a printed one of the same glyph (ambiguous),
    brackets that do not alternate [ ] [ ], an empty or blank pair, and a pair overlapping a ⟦ ⟧ span.
    """
    inserted = inserted_brackets(source, annotated)
    if inserted is None:
        return None
    typed = [(pos, char) for pos, char, _ in inserted if char in (ASCII_OPEN, ASCII_CLOSE)]
    if not typed:
        return None

    def where(pos):
        return "offset %d (…%s…)" % (pos, source[max(0, pos - 18):pos + 18].replace("\n", " "))

    problems = []
    for pos, char in typed:
        # Only the PREVIOUS source character can be the same glyph: the alignment records a bracket as
        # inserted only when it is not the next source character, so a bracket typed just before a
        # printed one is aligned onto the printed one and the printed one reads as inserted just after it.
        if pos > 0 and source[pos - 1] == char:
            problems.append("an inserted %s at %s touches a printed %s, so which of them is markup is "
                            "ambiguous" % (char, where(pos), char))
    pairs, open_at = [], None
    for pos, char in typed:
        if char == ASCII_OPEN:
            if open_at is not None:
                problems.append("an inserted [ at %s opens inside the one at offset %d" % (where(pos), open_at))
            open_at = pos
        elif open_at is None:
            problems.append("an inserted ] at %s closes nothing" % where(pos))
        else:
            if not source[open_at:pos].strip():
                problems.append("an inserted [ ] pair at %s is empty" % where(open_at))
            pairs.append((open_at, pos))
            open_at = None
    if open_at is not None:
        problems.append("an inserted [ at %s is never closed" % where(open_at))
    wrapped, wrap_open = [], None
    for pos, char, _ in inserted:
        if char == OPEN:
            wrap_open = pos
        elif char == CLOSE and wrap_open is not None:
            wrapped.append((wrap_open, pos))
            wrap_open = None
    for start, end in pairs:
        for wrap_start, wrap_end in wrapped:
            if start < wrap_end and wrap_start < end:
                problems.append("the inserted [ ] pair at %s overlaps the %s%s pair at offset %d"
                                % (where(start), OPEN, CLOSE, wrap_start))
    return pairs, problems


def convert_ascii_brackets(source, annotated):
    """`annotated` with its INSERTED ASCII brackets rewritten as ⟦ ⟧; printed brackets untouched.

    Only meaningful once `ascii_bracket_plan` has returned no problems for the same two texts.
    """
    chars = list(annotated)
    for _, char, index in inserted_brackets(source, annotated):
        if char == ASCII_OPEN:
            chars[index] = OPEN
        elif char == ASCII_CLOSE:
            chars[index] = CLOSE
    return "".join(chars)


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

    texts = {}

    def source_text(entry):
        """The R-0 text a document was staged from, or None when it cannot be recovered EXACTLY."""
        volume = entry["volume"]
        if volume not in texts:
            try:
                texts[volume] = store.volume_text(TEXT_DIR, volume)
            except (OSError, ValueError, SystemExit):
                texts[volume] = None          # no text layer here: say nothing rather than guess
        text = (texts[volume] or {}).get(entry["document"])
        return text if text is not None and sha256_text(text) == entry["text_sha256"] else None

    def ascii_case(name):
        """`ascii_bracket_plan` for a marked document whose text check fails, else None."""
        entry, path = by_file.get(name), os.path.join(OUT, name)
        if entry is None or not os.path.exists(path):
            return None
        annotated = open(path, encoding="utf-8").read()
        # A fast path, not a guard: a document that passes needs no alignment (it could hold no inserted
        # ASCII bracket), and skipping it spares loading its volume's text layer in CONVERT mode.
        if sha256_text(unwrap(annotated)[0]) == entry["text_sha256"]:
            return None
        source = source_text(entry)
        return None if source is None else ascii_bracket_plan(source, annotated)

    if CONVERT_ASCII_BRACKETS:
        # All or nothing, and every rewrite is computed before any file is touched: a sitting
        # half-converted, half-typed is worse than one the annotator can fix by hand. No re-check of the
        # rewrite follows it: with the plan clean, stripping ⟦ ⟧ from it reproduces the R-0 text by
        # construction, and a guard no input can reach is one no test can keep honest.
        plans, refusals = {}, []
        for name in sorted(done):
            case = ascii_case(name)
            if case is None:
                continue
            pairs, problems = case
            if problems:
                refusals.append("%s: %s" % (name, "; ".join(problems)))
                continue
            typed = open(os.path.join(OUT, name), encoding="utf-8").read()
            plans[name] = (typed, convert_ascii_brackets(source_text(by_file[name]), typed), len(pairs))
        if refusals:
            sys.exit("CONVERT_ASCII_BRACKETS=1 converted nothing: %d marked document(s) hold inserted ASCII "
                     "brackets that cannot be converted safely.\n  %s\nRetype those as %s %s by hand — the "
                     "documents print square brackets of their own, so there the text cannot say which is "
                     "markup — then collect again." % (len(refusals), "\n  ".join(refusals), OPEN, CLOSE))
        if plans:
            backup_root = os.path.join(OUT, "ascii-bracket-originals")
            stamp = time.strftime("%Y%m%dT%H%M%S")
            backup_dir, suffix = os.path.join(backup_root, stamp), 1
            while os.path.exists(backup_dir):
                suffix += 1
                backup_dir = os.path.join(backup_root, "%s-%d" % (stamp, suffix))
            os.makedirs(backup_dir)
            for name, (typed, converted, _) in sorted(plans.items()):
                with open(os.path.join(backup_dir, name), "w", encoding="utf-8") as handle:
                    handle.write(typed)
                with open(os.path.join(OUT, name), "w", encoding="utf-8") as handle:
                    handle.write(converted)
            print("converted %d inserted ASCII [ ] pair(s) to %s %s in %d document(s); the files as typed "
                  "are in %s" % (sum(n for _, _, n in plans.values()), OPEN, CLOSE, len(plans), backup_dir))
        else:
            print("CONVERT_ASCII_BRACKETS=1: no marked document holds inserted ASCII brackets")

    rows, rejected_total, added_total = [], 0, 0
    per_band = {}
    # One row per ANNOTATED DOCUMENT, beside the one-row-per-span ground truth. The span file cannot
    # represent a document that names no one: a document read and marked `none` yields zero spans,
    # so it produced zero rows, and the scorer — which built its document set from those rows —
    # never saw it. Every detection in such a document is a false positive and none were counted.
    # Measured on the first 24-document sitting, frus1946v01/d483 hid 6 of the qwen3 sweep's.
    annotated_documents = []
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
            case = ascii_case(name)
            if case is not None:
                # The symptom below is right and names no cause; for this cause the cause is the useful
                # part, and it is usually the whole sitting, so name every document that shares it.
                affected = [(other, ascii_case(other)) for other in sorted(done)]
                affected = [(other, found) for other, found in affected if found is not None]
                listing = "\n".join("  %s — %d pair(s)%s" % (other, len(found[0]),
                                     "; cannot be converted: " + "; ".join(found[1]) if found[1] else "")
                                     for other, found in affected)
                sys.exit("%s: the annotator typed ASCII brackets.\nStripping %s %s leaves only inserted "
                         "[ and ] — %d pair(s) in this document, and no other change to the prose — but a "
                         "mention must be wrapped in %s %s: the documents print square brackets of their "
                         "own, so [ ] cannot be told apart from the text. %d marked document(s) show the "
                         "same pattern:\n%s\nRetype those as %s %s, or collect with CONVERT_ASCII_BRACKETS=1 "
                         "to rewrite exactly the inserted brackets (the files as typed are kept)."
                         % (name, OPEN, CLOSE, len(case[0]), OPEN, CLOSE, len(affected), listing,
                            OPEN, CLOSE))
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
        annotated_documents.append({"v": entry["volume"], "d": entry["document"],
                                    "band": entry["band"], "mentions": len(spans),
                                    "mark": marks[name]})
        for start, end, surface in spans:
            rows.append({"v": entry["volume"], "d": entry["document"], "s": start,
                         "e": end, "n": surface, "seeded": (start, end) in seeded,
                         "band": entry["band"]})

    if not done:
        sys.exit("nothing marked annotated in progress.csv — no ground truth to collect.\n"
                 "That is the gate, not a bug: mark documents `y` as you finish them.")

    out_path = os.path.join(OUT, "m2a-ground-truth.jsonl")
    with open(out_path, "w", encoding="utf-8") as handle:
        for row in sorted(rows, key=lambda r: (r["v"], r["d"], r["s"], r["e"])):
            handle.write(json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n")
    # JSON lines with `v`/`d` on every row, the shape both ONLY_DOCUMENTS readers already take, so a
    # targeted detector pass can be pointed at THIS file and scan the documents that name no one too.
    # One restricted by the span file cannot: it has no row for them.
    documents_path = os.path.join(OUT, "m2a-ground-truth-documents.jsonl")
    with open(documents_path, "w", encoding="utf-8") as handle:
        for row in sorted(annotated_documents, key=lambda r: (r["v"], r["d"])):
            handle.write(json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n")
    without_mentions = sum(1 for row in annotated_documents if row["mentions"] == 0)

    total = len(rows)
    kept_seeded = sum(b["seeded_kept"] for b in per_band.values())
    summary = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "documents_annotated": len(done), "documents_staged": len(by_file),
        "documents_without_mentions": without_mentions,
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
    print("  %d annotated document(s) name no one; every annotated document is listed in %s,"
          "\n  so the scorer counts each detection in them as a false positive"
          % (without_mentions, documents_path))
    if not total:
        print("  no mentions at all yet: the scorer refuses a ground truth with nothing to recall, so key a"
              "\n  document that names someone before scoring")
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
