#!/usr/bin/env python3
"""Readers for the early-era NER store and the embeddings store's R-0 text layer.

Shared by stage_m2a.py (ground-truth staging) and score_detections.py (scoring), so
those two cannot disagree about what a document's text is, which span coordinates mean,
or which volumes are in scope. harvest_ner.py writes these files; this module only ever
reads them.

Stdlib only. The store contract is documented in NER-RUNBOOK.md §6; the one thing worth
repeating here is the coordinate rule, because everything downstream rests on it:

    s/e are CHARACTER OFFSETS, half-open, into the R-0 text of one document —
    the same text the embeddings harvest wrote to text/<vol>.jsonl.gz and chunked
    into the vectors. Not byte offsets, not offsets into the TEI.

Python string indices are code points, which is what "character" means here and in
harvest_ner.py. A reader in another language must index code points too, or its spans
address a different document than everything else in this program.
"""

import gzip
import json
import os
import re

BANDS = ((1861, 1899, "1861-1899"), (1900, 1929, "1900-1929"),
         (1930, 1945, "1930-1945"), (1946, 2100, "1946-"))
VOLUME_YEAR = re.compile(r"frus(\d{4})")


def band_of(volume_id):
    """The era band a volume belongs to — m1a_survey.py's four, same boundaries."""
    match = VOLUME_YEAR.search(volume_id)
    if not match:
        return None
    year = int(match.group(1))
    for low, high, label in BANDS:
        if low <= year <= high:
            return label
    return None


def read_jsonl_gz(path):
    """[dict] from a JSON-lines file, gzipped or not.

    Both, because the two producers differ by design: `harvest_ner.py` writes `.jsonl.gz`
    (mtime=0, byte-stable), while the Swift control writes plain `.jsonl` — nothing in the
    Swift repo reads or writes gzip, and adding a compression subprocess to save disk
    nobody is short of would be the wrong trade. A reader that took only one extension
    would silently score one detector and report the other as having found nothing.
    """
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def one_jsonl(directory, volume_id, label):
    """One volume's JSON-lines file in `directory`, gzipped or plain, or None if neither exists.

    Refuses when BOTH exist. The readers of these directories resolved the ambiguity in
    opposite orders — Python preferred the gzip, the Swift control prefers the plain file —
    so a stale copy left beside a fresh one had them reading different rows with nothing to
    say so. Refusing costs an `rm`; disagreeing costs a wrong comparison.

    Shared by `layer_path` and `volume_text` rather than written twice, which is how the R-0
    text directory came to have no refusal at all: `volume_text` had its own loop, took the
    first extension it found, and so silently preferred the gzip in the one directory the
    Swift control ALSO reads — the exact disagreement this function exists to prevent, in the
    exact place it mattered most.
    """
    present = [os.path.join(directory, volume_id + suffix)
               for suffix in (".jsonl", ".jsonl.gz")
               if os.path.exists(os.path.join(directory, volume_id + suffix))]
    if len(present) > 1:
        raise SystemExit("%s/%s exists as both .jsonl and .jsonl.gz — delete the stale one; "
                         "a reader cannot tell which you meant." % (label, volume_id))
    return present[0] if present else None


def layer_path(store, layer, volume_id):
    """The path to one volume's layer file, gzipped or plain, or None if neither exists."""
    return one_jsonl(os.path.join(store, layer), volume_id, layer)


def scope_volumes(store):
    """The volume ids the harvest derived, in the order scope.json lists them."""
    path = os.path.join(store, "scope.json")
    if not os.path.exists(path):
        raise SystemExit("no scope.json in %s — run harvest_ner.py first (N-0)." % store)
    return json.load(open(path))["volumes"]


def volume_text(text_dir, volume_id):
    """{doc_id: text} for one volume, from the embeddings store's R-0 layer."""
    path = one_jsonl(text_dir, volume_id, "text")
    if path is None:
        raise SystemExit("R-0 text layer missing: %s\nPoint TEXT_DIR at the embeddings "
                         "store's text/ directory."
                         % os.path.join(text_dir, volume_id + ".jsonl.gz"))
    return {row["d"]: row["t"] for row in read_jsonl_gz(path)}


def volume_layer(store, layer, volume_id):
    """Rows of one volume's `marked` or `detected` layer; [] when the volume is absent.

    Absent is not an error here: a detector store built from a sample legitimately holds
    no file for a volume it never scanned, and the caller decides what that means.
    """
    path = layer_path(store, layer, volume_id)
    if path is None:
        return []
    return read_jsonl_gz(path)


def layer_head(store, layer, volume_id):
    """One volume's head.json for a layer, or None."""
    path = os.path.join(store, layer, volume_id + ".head.json")
    if not os.path.exists(path):
        return None
    return json.load(open(path))


def spans_by_document(rows):
    """{doc_id: [(start, end, surface)]}, each list sorted and de-duplicated."""
    grouped = {}
    for row in rows:
        grouped.setdefault(row["d"], set()).add((row["s"], row["e"], row["n"]))
    return {doc: sorted(spans) for doc, spans in grouped.items()}


def check_spans(text, spans, where):
    """Every span must slice back to its own surface. Raises naming the first that does not.

    Cheap, and it is the only check that catches a store built against a different copy
    of the corpus — the failure that produces plausible offsets pointing at the wrong
    words rather than an error.
    """
    for start, end, surface in spans:
        if text[start:end] != surface:
            raise SystemExit("span does not match its text in %s: [%d,%d) is %r, row says %r"
                             % (where, start, end, text[start:end], surface))
