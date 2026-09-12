#!/usr/bin/env python3
"""End-to-end self-test for the M2a machinery: stage -> annotate -> collect -> score.

    SELFTEST=1 python3 stage_m2a.py        (or score_detections.py — same suite)

Runs anywhere python3 does: it builds a fixture NER store and R-0 text layer in a temp
directory, stages annotation files from them, simulates an annotator (adding a mention,
rejecting a seeded one, and in one case corrupting the prose), collects, and scores two
synthetic detectors plus the editor baseline. What it pins:

  * staging seeds the editors' spans and writes text that is byte-identical once the
    brackets come off;
  * the collector derives offsets that slice their own surface back out of the R-0 text;
  * a document typed with ASCII [ ] instead of ⟦ ⟧ is DIAGNOSED by name, with its own pair count and every
    marked document sharing the pattern (each with its own count and reasons); conversion — asked for through
    the ENVIRONMENT, as documented — rewrites exactly the inserted brackets byte for byte (a CRLF file stays
    CRLF), keeps the files as typed byte for byte, never writes into an earlier conversion's backups, and
    collects the same ground truth as a sitting typed correctly; it converts NOTHING, and the diagnosis stops
    recommending it, when any inserted bracket touches a printed one of the same glyph (either side), opens
    inside another, closes nothing, is never closed, is empty or blank, crosses a ⟦ ⟧ span in any of four
    shapes, or sits beside a stray or blank ⟦ ⟧ — one fixture each, each tripping only its own refusal, and
    all-or-nothing whichever document sorts first; unmarked documents are out of scope; a mixed-ending file is
    refused; a real prose edit (letters, whitespace, a trimmed end) keeps the original message in both modes
    with conversion saying truthfully why it did nothing; and with no, moved-on or truncated text layer the
    collector keeps the symptom, says it could not check, and never crashes — while a PASSING document's
    unreadable layer is never reported;
  * a document whose prose was edited under the brackets is REJECTED, not collected —
    the failure that would otherwise shift every later span silently, and so are a stray
    bracket, a duplicated progress row, and a file named in progress.csv but absent;
  * an UNTOUCHED file marked `y` is refused (it would collect the editors' seed as ground
    truth and report the markup share as 100%), while `none` collects it deliberately;
  * only documents marked in progress.csv are collected, and every collected mention
    reaches the ground truth and its band bucket;
  * strict scoring counts an exact span, relaxed scoring counts a boundary disagreement,
    one gold mention cannot be matched twice, precision and recall use their own
    denominators (pinned on a fixture where the two counts differ), and a detector is
    scored only over the documents it scanned;
  * a detector that sampled without recording its document ids is refused, not scored;
  * a document with no spans is LISTED by the collector by its span count (not by its `none` mark —
    the fixture keeps the two apart) and scored as empty gold, so a detection in it lowers precision
    and it counts in `documents_scored` and its band; a ground truth with no list still scores, says
    what it cannot see, and reports the empty-document count as unknown; a list that disagrees with its
    span file (a missing document, a wrong count either way, a wrong band, a duplicate row) is refused,
    each by its own fixture, as is the list handed over as GROUND_TRUTH; main()'s notes name which
    documents went unscored and why — including the real sample's shape, an empty document alone in a
    refused volume — without blaming a thin sample on the span file; a collection whose only document
    names no one is written, and the scorer refuses it.
"""

import csv
import glob
import gzip
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

CHECKS = []


def _raises(thunk):
    """True when `thunk` refuses with SystemExit — used to pin guards that must refuse.

    SystemExit specifically, not BaseException. Catching everything meant a guard test passed
    when the code under test raised NameError, AttributeError or TypeError instead of refusing:
    misspell a variable inside `check_spans` and the suite still printed 27 ok, while the only
    check pinning the corpus-mismatch guard measured nothing at all. Every guard in these
    scripts refuses with `sys.exit`, so anything else reaching here is a bug in the guard and
    should fail the round trip rather than satisfy it.
    """
    try:
        thunk()
    except SystemExit:
        return True
    return False


def check(label, condition, detail=""):
    CHECKS.append((label, bool(condition), detail))
    print("  %s %s%s" % ("ok  " if condition else "FAIL", label,
                         "" if condition or not detail else "  <- " + str(detail)))


def write_jsonl_gz(path, rows):
    with open(path, "wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as zipped:
            with io.TextIOWrapper(zipped, encoding="utf-8") as out:
                for row in rows:
                    out.write(json.dumps(row, ensure_ascii=False) + "\n")


FILLER = "The negotiations continued through the winter without material progress. " * 12


def build_fixture(root):
    """A two-volume store: one 1861-1899 volume, one 1946- volume, two documents each."""
    text_dir = os.path.join(root, "text")
    store_dir = os.path.join(root, "store")
    for path in (text_dir, os.path.join(store_dir, "marked")):
        os.makedirs(path)

    documents = {}
    for volume, names in (("frus1872p1", ("Hamilton Fish", "Seward")),
                          ("frus1948v06", ("Mr. Bevin", "Marshall"))):
        rows, texts = [], []
        for index in range(2):
            head = "%s wrote to %s about the matter. " % (names[0], names[1])
            # Printed square brackets, as FRUS has them: an editorial note and a bracketed sign-off.
            # The ASCII-bracket fixtures need the printed ones to tell an annotator's [ ] from the text.
            # Printed square brackets, as FRUS has them — a name directly after an editorial "]", a
            # bracketed receipt line ending on a name, a bracketed sign-off — and line breaks, so the
            # ASCII-bracket fixtures can tell an annotator's [ ] from the text and keep a file's endings.
            body = (head + "\n" + FILLER + "\n[Translation.]%s wrote again. [Received from %s] A closing word. [%s.] "
                    % (names[1], names[1], names[1]))
            doc_id = "d%d" % (index + 1)
            texts.append({"d": doc_id, "o": index, "t": body})
            # Only the first name of each pair is "marked up by the editors", which is
            # what leaves the annotator something to add.
            start = body.index(names[0])
            rows.append({"d": doc_id, "o": index, "s": start, "e": start + len(names[0]),
                         "n": names[0], "t": "from", "x": None, "c": None})
        write_jsonl_gz(os.path.join(text_dir, volume + ".jsonl.gz"), texts)
        write_jsonl_gz(os.path.join(store_dir, "marked", volume + ".jsonl.gz"), rows)
        json.dump({"volume": volume, "docs": 2, "mentions": len(rows)},
                  open(os.path.join(store_dir, "marked", volume + ".head.json"), "w"))
        documents[volume] = {row["d"]: row["t"] for row in texts}
    json.dump({"volumes": ["frus1872p1", "frus1948v06"]},
              open(os.path.join(store_dir, "scope.json"), "w"))
    return text_dir, store_dir, documents


def write_detector(root, name, per_document_spans, sampled_ids=None, record_ids=True):
    """A synthetic `detected/` store, optionally a sampled one."""
    path = os.path.join(root, name)
    os.makedirs(os.path.join(path, "detected"), exist_ok=True)
    by_volume = {}
    for (volume, document), spans in per_document_spans.items():
        by_volume.setdefault(volume, []).extend(
            {"d": document, "o": 0, "s": s, "e": e, "n": n, "ci": 0} for s, e, n in spans)
    for volume, rows in by_volume.items():
        write_jsonl_gz(os.path.join(path, "detected", volume + ".jsonl.gz"), rows)
        head = {"volume": volume, "sampled": sampled_ids is not None,
                "docs_scanned": len({r["d"] for r in rows})}
        if sampled_ids is not None and record_ids:
            head["sampled_doc_ids"] = sorted(sampled_ids.get(volume, []))
        elif sampled_ids is not None:
            head["sampled_doc_ids"] = None
        json.dump(head, open(os.path.join(path, "detected", volume + ".head.json"), "w"))
    return path


def run():
    root = tempfile.mkdtemp(prefix="m2a-selftest-")
    text_dir, store_dir, documents = build_fixture(root)
    out_dir = os.path.join(root, "m2a")

    os.environ.update({"STORE": store_dir, "TEXT_DIR": text_dir, "OUT_DIR": out_dir,
                       "DOCS": "8", "VOLS_PER_BAND": "6", "MIN_CHARS": "100",
                       "MAX_CHARS": "5000", "SEED": "234"})
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import ner_store            # noqa: E402
    import stage_m2a as stage   # noqa: E402
    import score_detections     # noqa: E402
    # The modules read their configuration at import time, and the fixture paths only
    # exist now, so re-bind what this run needs rather than relying on import order.
    stage.STORE = store_dir
    stage.TEXT_DIR = text_dir
    stage.OUT = out_dir
    stage.DOCS = 8
    stage.MIN_CHARS = 100
    stage.MAX_CHARS = 5000

    print("\n== stage ==")
    stage.stage()
    manifest = json.load(open(os.path.join(out_dir, "m2a-manifest.json")))
    staged = {row["file"]: row for row in manifest["documents"]}
    check("both bands staged",
          {row["band"] for row in staged.values()} == {"1861-1899", "1946-"},
          sorted({row["band"] for row in staged.values()}))
    check("every staged document seeded its editor span",
          all(row["seeded_spans"] == 1 for row in staged.values()),
          [(k, v["seeded_spans"]) for k, v in staged.items()])

    sample_file = sorted(staged)[0]
    entry = staged[sample_file]
    original = documents[entry["volume"]][entry["document"]]
    annotated = open(os.path.join(out_dir, sample_file), encoding="utf-8").read()
    plain, spans = stage.unwrap(annotated)
    check("brackets come off to the exact R-0 text", plain == original)
    check("the staged file actually carries the editors' brackets",
          len(spans) == entry["seeded_spans"] and len(spans) > 0, (len(spans), entry))
    check("the seeded span slices back to its name",
          spans and all(plain[s:e] == n for s, e, n in spans), spans)
    check("the staged bytes are recorded, so an untouched file is detectable",
          entry.get("staged_sha256") and entry["staged_sha256"] != entry["text_sha256"])

    print("\n== annotate (simulated) ==")
    # Annotator adds every unmarked occurrence of the second name, and in one document
    # rejects the seeded span by removing its brackets.
    marked_rows = {}
    for index, name in enumerate(sorted(staged)):
        row = staged[name]
        path = os.path.join(out_dir, name)
        text = documents[row["volume"]][row["document"]]
        second = "Seward" if row["volume"] == "frus1872p1" else "Marshall"
        rebuilt, cursor = [], 0
        seeded = sorted(ner_store.spans_by_document(
            ner_store.volume_layer(store_dir, "marked", row["volume"])
        ).get(row["document"], []))
        additions = []
        start = text.find(second)
        while start != -1:
            additions.append((start, start + len(second), second))
            start = text.find(second, start + 1)
        keep_seeded = index != 0          # document 0: the annotator rejects the editors' span
        allspans = sorted(additions + (seeded if keep_seeded else []))
        for s, e, _ in allspans:
            rebuilt.append(text[cursor:s])
            rebuilt.append(stage.OPEN + text[s:e] + stage.CLOSE)
            cursor = e
        rebuilt.append(text[cursor:])
        open(path, "w", encoding="utf-8").write("".join(rebuilt))
        marked_rows[name] = len(allspans)

    corrupted = sorted(staged)[1]
    with open(os.path.join(out_dir, corrupted), encoding="utf-8") as handle:
        body = handle.read()

    with open(os.path.join(out_dir, "progress.csv"), newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    for row in rows:
        row["annotated"] = "y"
    rows[-1]["annotated"] = ""            # one document left unfinished on purpose
    unfinished = rows[-1]["file"]
    with open(os.path.join(out_dir, "progress.csv"), "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print("\n== the untouched-file guard ==")
    # A `y` on a file nobody edited would collect the editors' own seed as ground truth and
    # report the markup share as 100%. That is the failure this loop most has to defend against.
    untouched_name = sorted(staged)[-1]
    untouched_body = open(os.path.join(out_dir, untouched_name), encoding="utf-8").read()
    with open(os.path.join(out_dir, untouched_name), "w", encoding="utf-8") as handle:
        handle.write(stage.wrap(documents[staged[untouched_name]["volume"]]
                                [staged[untouched_name]["document"]],
                                sorted(ner_store.spans_by_document(
                                    ner_store.volume_layer(store_dir, "marked",
                                                           staged[untouched_name]["volume"])
                                ).get(staged[untouched_name]["document"], []))))
    with open(os.path.join(out_dir, "progress.csv"), newline="", encoding="utf-8") as handle:
        saved_rows = list(csv.DictReader(handle))
    def write_progress(rows_out):
        with open(os.path.join(out_dir, "progress.csv"), "w", newline="",
                  encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows_out[0].keys()))
            writer.writeheader()
            writer.writerows(rows_out)
    marked_all = [dict(row, annotated="y") for row in saved_rows]
    write_progress(marked_all)
    try:
        stage.collect()
        check("an untouched file marked `y` is refused", False, "it collected")
    except SystemExit as exit_code:
        check("an untouched file marked `y` is refused",
              "byte-identical to what was staged" in str(exit_code), exit_code)
    write_progress([dict(row, annotated="none" if row["file"] == untouched_name else "y")
                    for row in saved_rows])
    stage.collect()
    check("`none` collects it as read-with-nothing-to-add", True)

    print("\n== duplicate and missing rows ==")
    write_progress(marked_all + [dict(marked_all[0])])
    try:
        stage.collect()
        check("a duplicated progress row is refused", False, "it collected")
    except SystemExit as exit_code:
        check("a duplicated progress row is refused", "twice" in str(exit_code), exit_code)
    write_progress(marked_all)     # the missing file must be MARKED for the guard to be reached
    os.rename(os.path.join(out_dir, untouched_name), os.path.join(out_dir, "moved.txt"))
    try:
        stage.collect()
        check("a file named in progress.csv but absent is refused", False, "it collected")
    except SystemExit as exit_code:
        check("a file named in progress.csv but absent is refused",
              "not in" in str(exit_code), exit_code)
    os.rename(os.path.join(out_dir, "moved.txt"), os.path.join(out_dir, untouched_name))
    with open(os.path.join(out_dir, untouched_name), "w", encoding="utf-8") as handle:
        handle.write(untouched_body)
    write_progress(saved_rows)

    print("\n== collect ==")
    stage.collect()
    truth = [json.loads(line) for line in
             open(os.path.join(out_dir, "m2a-ground-truth.jsonl"), encoding="utf-8")
             if line.strip()]
    summary = json.load(open(os.path.join(out_dir, "m2a-collection-summary.json")))
    left_out = (staged[unfinished]["volume"], staged[unfinished]["document"])
    check("the unfinished document is not collected",
          left_out not in {(r["v"], r["d"]) for r in truth}, left_out)
    check("collected documents match progress.csv",
          summary["documents_annotated"] == len(rows) - 1, summary["documents_annotated"])
    check("a rejected editor span is counted",
          summary["editor_spans_rejected"] == 1, summary["editor_spans_rejected"])
    check("added mentions are counted", summary["added_by_annotator"] > 0, summary)
    check("every gold span slices back to the R-0 text",
          all(documents[r["v"]][r["d"]][r["s"]:r["e"]] == r["n"] for r in truth))
    check("seeded flag distinguishes editor spans from added ones",
          {r["seeded"] for r in truth} == {True, False},
          sorted({r["seeded"] for r in truth}))
    check("every collected mention reaches the ground truth",
          summary["mentions"] == len(truth)
          and sum(b["spans"] for b in summary["by_band"].values()) == len(truth),
          (summary["mentions"], len(truth)))
    check("a span check catches a store built against different text",
          _raises(lambda: ner_store.check_spans("wrong text entirely",
                                                [(0, 4, "Fish")], "fixture")))

    print("\n== the corruption guard ==")
    open(os.path.join(out_dir, corrupted), "w", encoding="utf-8").write(
        body.replace("winter", "wintor", 1))
    try:
        stage.collect()
        check("prose edited under the brackets is rejected", False, "it collected")
    except SystemExit as exit_code:
        check("prose edited under the brackets is rejected",
              "the text changed under the brackets" in str(exit_code), exit_code)
    open(os.path.join(out_dir, corrupted), "w", encoding="utf-8").write(body)
    stage.collect()

    print("\n== ASCII brackets ==")
    # 2026-09-12: the owner keyed 23 documents with every added mention typed as [ … ]. The collector said
    # only "the text changed under the brackets", which was true and named no cause. The fixture documents
    # print "[Translation.]" (a name directly after its ]), "[Received from Name]" and "[Name.]", and carry
    # line breaks, so a rule that treated any [ ] as markup — or rewrote a file's line endings — fails here.
    instructions = open(os.path.join(out_dir, "M2a-INSTRUCTIONS.md"), encoding="utf-8").read()
    check("the instructions say to type ⟦ ⟧, not [ ]",
          ("Type %s and %s, not [ and ]" % (stage.OPEN, stage.CLOSE)) in instructions)

    truth_path = os.path.join(out_dir, "m2a-ground-truth.jsonl")
    reference_truth = open(truth_path, encoding="utf-8").read()
    marked_names = sorted(row["file"] for row in saved_rows if row["annotated"])
    seeded_marked = [name for name in marked_names if name != sorted(staged)[0]]   # doc 0 rejected its seed
    doc_a, doc_b = seeded_marked[0], seeded_marked[1]
    bodies = {name: open(os.path.join(out_dir, name), encoding="utf-8").read() for name in staged}
    backup_root = os.path.join(out_dir, "ascii-bracket-originals")

    def source_of(name):
        return documents[staged[name]["volume"]][staged[name]["document"]]

    def boxed(text):
        return stage.OPEN + text + stage.CLOSE

    def bracketed(text):
        return "[" + text + "]"

    def touches_printed(source, start, end):
        return ((start > 0 and source[start - 1] == "[") or source[start:start + 1] == "["
                or source[end - 1:end] == "]" or source[end:end + 1] == "]")

    def retype(name, render):
        """The document with each of its annotated spans re-rendered by `render(source, s, e, seed)`."""
        source = source_of(name)
        _, spans = stage.unwrap(bodies[name])
        seeds = {tuple(pair) for pair in staged[name]["seeded"]}
        pieces, cursor = [], 0
        for start, end, _ in spans:
            pieces.append(source[cursor:start])
            pieces.append(render(source, start, end, (start, end) in seeds))
            cursor = end
        pieces.append(source[cursor:])
        return "".join(pieces)

    def ascii_where_safe(source, start, end, seed):
        return boxed(source[start:end]) if seed or touches_printed(source, start, end) else bracketed(source[start:end])

    def typing(*forms):
        """The k-th safe (non-seed, not bracket-adjacent) addition typed as forms[k](name); the rest ⟦ ⟧."""
        seen = [0]

        def render(source, start, end, seed):
            text = source[start:end]
            if seed or touches_printed(source, start, end):
                return boxed(text)
            index, seen[0] = seen[0], seen[0] + 1
            return forms[index](text) if index < len(forms) else boxed(text)
        return render

    def typing_where(predicate):
        """Non-seed spans satisfying predicate(source, start, end) typed in [ ]; every other span ⟦ ⟧."""
        def render(source, start, end, seed):
            text = source[start:end]
            return bracketed(text) if not seed and predicate(source, start, end) else boxed(text)
        return render

    def put(name, text):
        with open(os.path.join(out_dir, name), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)

    def put_bytes(name, data):
        with open(os.path.join(out_dir, name), "wb") as handle:
            handle.write(data)

    def read(name):
        return open(os.path.join(out_dir, name), encoding="utf-8").read()

    def read_bytes(name):
        return open(os.path.join(out_dir, name), "rb").read()

    def pairs_in(name, text):
        return text.count("[") - source_of(name).count("[")

    def listing_line(message, name):
        return next((line for line in (message or "").splitlines() if line.startswith("  %s — " % name)), "")

    def collecting(convert):
        """collect() in the given mode: (SystemExit message or None, printed output)."""
        buffer, real = io.StringIO(), sys.stdout
        stage.CONVERT_ASCII_BRACKETS = convert
        sys.stdout = buffer
        try:
            stage.collect()
            return None, buffer.getvalue()
        except SystemExit as exit_code:
            return str(exit_code), buffer.getvalue()
        finally:
            sys.stdout = real
            stage.CONVERT_ASCII_BRACKETS = False

    def restore_all():
        for name in staged:
            put(name, bodies[name])
        shutil.rmtree(backup_root, ignore_errors=True)

    typed_a = retype(doc_a, ascii_where_safe)          # every safe addition, one directly after a printed ]
    typed_b = retype(doc_b, typing(bracketed))          # only the first safe addition
    pairs_a, pairs_b = pairs_in(doc_a, typed_a), pairs_in(doc_b, typed_b)
    check("the fixtures differ in pair count, type one pair right after a printed ], and carry line breaks",
          pairs_a >= 2 and pairs_b == 1 and ".][" in typed_a and source_of(doc_a).count("\n") >= 2,
          (pairs_a, pairs_b))

    put(doc_a, typed_a)
    put(doc_b, typed_b)
    message, _ = collecting(False)
    check("a document typed with ASCII brackets is diagnosed as such, with its own pair count",
          message is not None and ("%s: the annotator typed ASCII brackets" % doc_a) in message
          and ("%d pair(s) in this document" % pairs_a) in message
          and "must be wrapped in %s %s" % (stage.OPEN, stage.CLOSE) in message
          and "the text changed under the brackets" not in message,
          (message or "")[:400])
    check("the diagnosis lists every marked document with its own count, offers conversion, and rewrites none",
          message is not None and "2 marked document(s) show the same pattern" in message
          and listing_line(message, doc_a) == "  %s — %d pair(s)" % (doc_a, pairs_a)
          and listing_line(message, doc_b) == "  %s — %d pair(s)" % (doc_b, pairs_b)
          and "or collect with CONVERT_ASCII_BRACKETS=1, which rewrites exactly the inserted brackets" in message
          and read(doc_a) == typed_a and read(doc_b) == typed_b,
          (message or "")[-500:])

    # The documented way to ask for conversion is the environment variable, so drive that, in a process of its own.
    run_env = dict(os.environ, COLLECT="1", CONVERT_ASCII_BRACKETS="1", OUT_DIR=out_dir, STORE=store_dir,
                   TEXT_DIR=text_dir, SELFTEST="")
    converted_run = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                                 "stage_m2a.py")],
                                   env=run_env, capture_output=True, text=True, timeout=600)
    check("CONVERT_ASCII_BRACKETS=1 in the environment converts, as the runbook documents",
          converted_run.returncode == 0 and read(doc_a) == bodies[doc_a] and read(doc_b) == bodies[doc_b]
          and ("converted %d inserted ASCII [ ] pair(s)" % (pairs_a + pairs_b)) in converted_run.stdout,
          (converted_run.returncode, converted_run.stdout[-300:], converted_run.stderr[-300:]))
    restore_all()

    # In process, with a CRLF file and the clock pinned into a collision with an earlier conversion's backups.
    crlf_a = typed_a.replace("\n", "\r\n").encode("utf-8")
    put_bytes(doc_a, crlf_a)
    put(doc_b, typed_b)
    fixed_stamp = "20990101T000000"
    earlier = os.path.join(backup_root, fixed_stamp)
    os.makedirs(earlier)
    with open(os.path.join(earlier, "earlier.keep"), "w", encoding="utf-8") as handle:
        handle.write("an earlier conversion's backups")
    real_strftime = stage.time.strftime
    stage.time.strftime = lambda fmt, *rest: fixed_stamp
    try:
        message, output = collecting(True)
    finally:
        stage.time.strftime = real_strftime
    backup_dir = os.path.join(backup_root, fixed_stamp + "-2")
    check("conversion rewrites exactly the inserted brackets, byte for byte, keeping a CRLF file CRLF",
          message is None and read_bytes(doc_a) == bodies[doc_a].replace("\n", "\r\n").encode("utf-8")
          and read_bytes(doc_b) == bodies[doc_b].encode("utf-8"),
          (message, output[:300]))
    check("...collects the same ground truth a sitting typed with ⟦ ⟧ does",
          open(truth_path, encoding="utf-8").read() == reference_truth)
    check("...and keeps the files as typed, byte for byte, beside an earlier conversion from the same second",
          os.path.isdir(backup_dir) and sorted(os.listdir(backup_dir)) == sorted([doc_a, doc_b])
          and open(os.path.join(backup_dir, doc_a), "rb").read() == crlf_a
          and open(os.path.join(backup_dir, doc_b), "rb").read() == typed_b.encode("utf-8")
          and os.listdir(earlier) == ["earlier.keep"]
          and ("converted %d inserted ASCII [ ] pair(s)" % (pairs_a + pairs_b)) in output
          and "in 2 document(s)" in output,
          (sorted(os.listdir(backup_root)), output[:300]))
    restore_all()

    mixed = typed_a.replace("\n", "\r\n", 1).encode("utf-8")
    put_bytes(doc_a, mixed)
    put(doc_b, typed_b)
    message, _ = collecting(True)
    check("a file with mixed line endings is refused rather than normalised, and nothing is converted",
          message is not None and "converted nothing" in message and "line endings" in message
          and read_bytes(doc_a) == mixed and read(doc_b) == typed_b and not os.path.exists(backup_root),
          (message or "")[:300])
    restore_all()

    REFUSALS = ("touches a printed", "opens inside", "closes nothing", "is never closed", "is empty or blank",
                "overlaps the", "a stray", "a blank %s%s" % (stage.OPEN, stage.CLOSE))

    def refused_in_both_modes(label, expected, unsafe_doc, unsafe_text, safe_doc, safe_text, detail=None, absent=None):
        """The unsafe typing in one document, a SAFE one in the other: both are listed, only the unsafe one
        with its own reason, and conversion touches neither. Each fixture trips ONLY its own refusal."""
        put(unsafe_doc, unsafe_text)
        put(safe_doc, safe_text)
        diagnosed, _ = collecting(False)
        refused, _ = collecting(True)
        unsafe_line, safe_line = listing_line(diagnosed, unsafe_doc), listing_line(diagnosed, safe_doc)
        tripped = [phrase for phrase in REFUSALS if phrase in (diagnosed or "") + (refused or "")]
        check(label,
              diagnosed is not None and "cannot be converted" in unsafe_line and expected in unsafe_line
              and (detail is None or detail in unsafe_line) and (absent is None or absent not in unsafe_line)
              and safe_line.startswith("  %s — " % safe_doc) and "cannot be converted" not in safe_line
              and "CONVERT_ASCII_BRACKETS=1 converts nothing while any cannot be converted" in diagnosed
              and refused is not None and "converted nothing: 1 marked document(s)" in refused
              and expected in refused and unsafe_doc in refused and tripped == [expected]
              and read(unsafe_doc) == unsafe_text and read(safe_doc) == safe_text
              and not os.path.exists(backup_root),
              (tripped, unsafe_line[:200], safe_line[:120], (refused or "")[:200]))
        restore_all()

    after_open = lambda source, start, end: start > 0 and source[start - 1] == "["
    before_close = lambda source, start, end: source[end:end + 1] == "]"
    refused_in_both_modes("an inserted [ right after a printed [ is refused, and nothing is converted",
                          "touches a printed", doc_a, retype(doc_a, typing_where(after_open)), doc_b, typed_b,
                          detail="touches a printed [", absent="touches a printed ]")
    refused_in_both_modes("an inserted ] right after a printed ] is refused",
                          "touches a printed", doc_a, retype(doc_a, typing_where(before_close)), doc_b, typed_b,
                          detail="touches a printed ]", absent="touches a printed [")
    refused_in_both_modes("...and conversion is all or nothing when the refused document sorts LAST",
                          "touches a printed", doc_b, retype(doc_b, typing_where(after_open)), doc_a, typed_a)
    refused_in_both_modes("an inserted [ that opens inside another is refused", "opens inside",
                          doc_a, retype(doc_a, typing(lambda t: "[" + t, bracketed)), doc_b, typed_b)
    refused_in_both_modes("an inserted ] that closes nothing is refused", "closes nothing",
                          doc_a, retype(doc_a, typing(lambda t: t + "]")), doc_b, typed_b)
    refused_in_both_modes("an inserted [ that is never closed is refused", "is never closed",
                          doc_a, retype(doc_a, typing(lambda t: "[" + t)), doc_b, typed_b)
    refused_in_both_modes("an empty inserted [] pair is refused", "is empty or blank",
                          doc_a, retype(doc_a, typing(lambda t: "[]" + boxed(t))), doc_b, typed_b)
    body_a = bodies[doc_a]
    seed_open, seed_close = body_a.index(stage.OPEN), body_a.index(stage.CLOSE)
    refused_in_both_modes("a blank inserted [ ] pair, around a space, is refused", "is empty or blank",
                          doc_a, body_a[:seed_close + 1] + "[ ]" + body_a[seed_close + 2:], doc_b, typed_b)
    # Four ways a [ ] pair can cross a ⟦ ⟧ span, one fixture each.
    shapes = (
        ("that opens inside a ⟦ ⟧ span", body_a[:seed_open + 2] + "[" + body_a[seed_open + 2:seed_close + 4] + "]"
         + body_a[seed_close + 4:]),
        ("that opens before a ⟦ ⟧ span and closes inside it", body_a[:seed_open] + "[" + body_a[seed_open:seed_open + 4]
         + "]" + body_a[seed_open + 4:]),
        ("that contains a ⟦ ⟧ span", body_a[:seed_open] + "[" + body_a[seed_open:seed_close + 3] + "]"
         + body_a[seed_close + 3:]),
        ("that opens at the offset where a ⟦ ⟧ span closes, before its ⟧", body_a[:seed_close] + "["
         + body_a[seed_close:seed_close + 7] + "]" + body_a[seed_close + 7:]),
    )
    for shape, text in shapes:
        refused_in_both_modes("an inserted [ ] pair %s is refused" % shape, "overlaps the", doc_a, text, doc_b, typed_b)

    # Two defects the collector's own checks catch BEFORE the text check, so diagnosis never sees them — but
    # conversion runs first, and must refuse rather than write a file the loop then rejects (or, worse, one
    # whose stray bracket the non-greedy pairing silently adopts).
    for label, text, expected, loop_message in (
            ("a stray ⟧ beside ASCII pairs", typed_a.replace(stage.OPEN, "", 1), "a stray",
             "a stray %s or %s survives" % (stage.OPEN, stage.CLOSE)),
            ("a blank ⟦ ⟧ pair beside ASCII pairs",
             typed_a[:typed_a.index(stage.CLOSE) + 1] + boxed(" ") + typed_a[typed_a.index(stage.CLOSE) + 2:],
             "a blank %s%s" % (stage.OPEN, stage.CLOSE), "an empty or blank %s%s pair" % (stage.OPEN, stage.CLOSE))):
        put(doc_a, text)
        put(doc_b, typed_b)
        refused, _ = collecting(True)
        plain_refusal, _ = collecting(False)
        tripped = [phrase for phrase in REFUSALS if phrase in (refused or "")]
        check("conversion refuses %s, writing nothing, and the loop still names it" % label,
              refused is not None and "converted nothing" in refused and tripped == [expected]
              and read(doc_a) == text and read(doc_b) == typed_b and not os.path.exists(backup_root)
              and plain_refusal is not None and loop_message in plain_refusal,
              (tripped, (refused or "")[:300], (plain_refusal or "")[:200]))
        restore_all()

    # Scope: only MARKED documents are converted or can block conversion; and a document with a stray bracket
    # but no ASCII bracket is not an ASCII case at all.
    unfinished_unsafe = retype(unfinished, typing_where(after_open))
    put(unfinished, unfinished_unsafe)
    put(doc_a, typed_a)
    put(doc_b, typed_b)
    message, output = collecting(True)
    check("an unmarked document is neither converted nor able to block conversion",
          message is None and read(unfinished) == unfinished_unsafe and read(doc_a) == bodies[doc_a]
          and "in 2 document(s)" in output, (message, output[:300]))
    restore_all()
    stray_only = bodies[doc_a].replace(stage.OPEN, "", 1)
    put(doc_a, stray_only)
    put(doc_b, typed_b)
    message, output = collecting(True)
    check("a document with a stray bracket and no ASCII bracket is not converted as one",
          message is not None and "a stray %s or %s survives" % (stage.OPEN, stage.CLOSE) in message
          and ("converted %d inserted ASCII [ ] pair(s)" % pairs_b) in output and "in 1 document(s)" in output
          and read(doc_a) == stray_only, (message, output[:300]))
    restore_all()

    # A real prose edit beside ASCII brackets keeps the original message in both modes, and conversion says
    # truthfully why it did nothing.
    edits = (("a changed letter", lambda text: text.replace("winter", "wintor", 1)),
             ("a deleted letter", lambda text: text.replace("winter", "wintr", 1)),
             ("an inserted letter", lambda text: text.replace("winter", "winterx", 1)),
             ("a doubled space", lambda text: text.replace(" wrote to ", " wrote  to ", 1)),
             ("a deleted space", lambda text: text.replace(" wrote to ", " wroteto ", 1)),
             ("an inserted line break", lambda text: text.replace(" wrote to ", " wrote\nto ", 1)),
             # The one deletion an alignment can mistake for nothing: at the END, where the file simply runs out.
             ("a trimmed final character", lambda text: text[:-1]))
    for label, edit in edits:
        edited = edit(typed_a)
        put(doc_a, edited)
        diagnosed, _ = collecting(False)
        refused, output = collecting(True)
        check("a real prose edit (%s) beside ASCII brackets keeps the original message, in both modes" % label,
              edited != typed_a and diagnosed is not None and "the text changed under the brackets" in diagnosed
              and "typed ASCII brackets" not in diagnosed
              and refused is not None and "the text changed under the brackets" in refused
              and read(doc_a) == edited and "converted nothing" in output
              and ("were not converted because they fail for a reason other than inserted brackets: %s" % doc_a) in output
              and "no marked document holds" not in output,
              ((diagnosed or "")[:160], (refused or "")[:160], output[:300]))
    restore_all()

    # Diagnosis needs the EXACT text the document was staged from. Without it — no text layer, one that has moved
    # on, or one truncated in transfer — the collector keeps the symptom, says it could not check, and never crashes.
    saved_text_dir = stage.TEXT_DIR
    moved, truncated = os.path.join(root, "moved-text"), os.path.join(root, "truncated-text")
    entry_a = staged[doc_a]
    for directory in (moved, truncated):
        os.makedirs(directory, exist_ok=True)
    for volume in {row["volume"] for row in staged.values()}:
        original_gz = os.path.join(text_dir, volume + ".jsonl.gz")
        rows_out = ner_store.read_jsonl_gz(original_gz)
        if volume == entry_a["volume"]:
            for row in rows_out:
                if row["d"] == entry_a["document"]:
                    row["t"] = row["t"].replace("[Translation.]", "Translation.]", 1)
        write_jsonl_gz(os.path.join(moved, volume + ".jsonl.gz"), rows_out)
        data = open(original_gz, "rb").read()
        with open(os.path.join(truncated, volume + ".jsonl.gz"), "wb") as handle:
            handle.write(data[:len(data) // 2] if volume == entry_a["volume"] else data)
    try:
        for label, directory in (("no text layer", os.path.join(root, "no-text-layer-here")),
                                 ("a text layer that no longer matches the staged hash", moved),
                                 ("a truncated text layer", truncated)):
            stage.TEXT_DIR = directory
            put(doc_a, typed_a)
            diagnosed, _ = collecting(False)
            refused, output = collecting(True)
            check("with %s, the original message stands and says the cause could not be checked, in both modes" % label,
                  diagnosed is not None and "the text changed under the brackets" in diagnosed
                  and "could not be checked" in diagnosed and "typed ASCII brackets" not in diagnosed
                  and refused is not None and "the text changed under the brackets" in refused
                  and ("could not be checked for ASCII brackets" in output and doc_a in output)
                  and read(doc_a) == typed_a,
                  ((diagnosed or "")[-200:], output[:300]))
        # A document that PASSES is never charged to its volume's text layer: truncate the OTHER volume's
        # layer, and the ASCII diagnosis for doc_a must not claim anything "could not be checked".
        other_volume_marked = next(name for name in marked_names if staged[name]["volume"] != entry_a["volume"])
        other_truncated = os.path.join(root, "other-truncated-text")
        os.makedirs(other_truncated, exist_ok=True)
        for volume in {row["volume"] for row in staged.values()}:
            data = open(os.path.join(text_dir, volume + ".jsonl.gz"), "rb").read()
            with open(os.path.join(other_truncated, volume + ".jsonl.gz"), "wb") as handle:
                handle.write(data[:len(data) // 2] if volume == staged[other_volume_marked]["volume"] else data)
        stage.TEXT_DIR = other_truncated
        put(doc_a, typed_a)
        diagnosed, _ = collecting(False)
        check("a passing document's unreadable text layer is not reported as a document that could not be checked",
              diagnosed is not None and ("%s: the annotator typed ASCII brackets" % doc_a) in diagnosed
              and "could not be checked" not in diagnosed,
              (diagnosed or "")[-300:])
    finally:
        stage.TEXT_DIR = saved_text_dir
    restore_all()

    write_progress(saved_rows)
    stage.collect()
    check("the sample is restored for the checks that follow",
          open(truth_path, encoding="utf-8").read() == reference_truth)

    print("\n== score ==")
    gold, bands = score_detections.load_ground_truth(
        os.path.join(out_dir, "m2a-ground-truth.jsonl"))
    perfect = {key: [(s, e, n) for s, e, n in spans] for key, spans in gold.items()}
    # A detector that shifts every boundary by one character: no strict hits, all relaxed.
    shifted = {key: [(s, max(s + 1, e - 1), n[:-1] or n) for s, e, n in spans]
               for key, spans in gold.items()}
    scanned = {}
    for volume, document in gold:
        scanned.setdefault(volume, set()).add(document)

    perfect_store = write_detector(root, "det-perfect", perfect, sampled_ids=scanned)
    shifted_store = write_detector(root, "det-shifted", shifted, sampled_ids=scanned)
    blind_store = write_detector(root, "det-blind", perfect, sampled_ids=scanned,
                                 record_ids=False)

    score_detections.TEXT_DIR = text_dir
    score_detections.MARKED_STORE = store_dir
    predictions, refused = score_detections.collect_predictions(perfect_store, "detected",
                                                                gold, False)
    result = score_detections.score_one("perfect", predictions, gold, bands, refused)
    check("a perfect detector scores 1.0 strict",
          result["strict"]["precision"] == 1.0 and result["strict"]["recall"] == 1.0, result["strict"])

    predictions, refused = score_detections.collect_predictions(shifted_store, "detected",
                                                                gold, False)
    result = score_detections.score_one("shifted", predictions, gold, bands, refused)
    check("a boundary-shifted detector scores 0 strict but 1.0 relaxed",
          result["strict"]["hits"] == 0 and result["relaxed"]["recall"] == 1.0,
          (result["strict"], result["relaxed"]))

    predictions, refused = score_detections.collect_predictions(blind_store, "detected",
                                                                gold, False)
    check("a sampled store with no document ids is refused",
          refused and not predictions, (refused, len(predictions)))

    # The Swift control writes plain .jsonl (nothing in the Swift repo speaks gzip). A reader
    # that took only .jsonl.gz would report it as having found nothing, which reads as a
    # detector result rather than as a reader bug — so pin both extensions.
    plain_store = os.path.join(root, "det-plain")
    os.makedirs(os.path.join(plain_store, "detected"), exist_ok=True)
    with open(os.path.join(plain_store, "detected", "frus1872p1.jsonl"), "w",
              encoding="utf-8") as handle:
        for (volume, document), spans in sorted(perfect.items()):
            if volume != "frus1872p1":
                continue
            for s, e, n in spans:
                handle.write(json.dumps({"d": document, "o": 0, "s": s, "e": e, "n": n,
                                         "ci": 0}) + "\n")
            json.dump({"volume": volume, "sampled": True,
                       "sampled_doc_ids": sorted(scanned[volume])},
                      open(os.path.join(plain_store, "detected", volume + ".head.json"), "w"))
    plain_rows = ner_store.volume_layer(plain_store, "detected", "frus1872p1")
    check("an uncompressed .jsonl layer is read (the Swift control's output)",
          plain_rows and all(r["n"] for r in plain_rows), len(plain_rows))

    doubled = {key: sorted(spans + [(s, e + 1, n) for s, e, n in spans])
               for key, spans in gold.items()}
    doubled_store = write_detector(root, "det-doubled", doubled, sampled_ids=scanned)
    predictions, refused = score_detections.collect_predictions(doubled_store, "detected",
                                                                gold, False)
    result = score_detections.score_one("doubled", predictions, gold, bands, refused)
    check("two overlapping predictions cannot match one gold span twice",
          result["relaxed"]["hits"] == result["relaxed"]["gold"], result["relaxed"])

    # Asymmetric counts: precision and recall have different denominators, and a fixture where
    # every detector predicts exactly as many spans as there are gold spans cannot tell them
    # apart — a swap of the two divisors passes such a suite.
    thin = {key: spans[:1] for key, spans in gold.items()}
    thin_store = write_detector(root, "det-thin", thin, sampled_ids=scanned)
    predictions, refused = score_detections.collect_predictions(thin_store, "detected",
                                                                gold, False)
    result = score_detections.score_one("thin", predictions, gold, bands, refused)
    check("precision and recall use their own denominators",
          result["strict"]["precision"] == 1.0
          and result["strict"]["recall"] == round(len(thin) / len(truth), 4),
          (result["strict"], len(thin), len(truth)))

    # One document of the sample, to pin the rule the module's docstring leads with: a detector
    # is scored only over what it scanned.
    one_key = sorted(gold)[0]
    subset_store = write_detector(root, "det-subset", {one_key: gold[one_key]},
                                  sampled_ids={one_key[0]: {one_key[1]}})
    predictions, refused = score_detections.collect_predictions(subset_store, "detected",
                                                                gold, False)
    result = score_detections.score_one("subset", predictions, gold, bands, refused)
    check("a detector is scored only over the documents it scanned",
          result["documents_scored"] == 1
          and result["strict"]["gold"] == len(gold[one_key]), result["strict"])

    baseline, baseline_refused = score_detections.collect_predictions(
        store_dir, "marked", gold, False)
    result = score_detections.score_one("editor markup", baseline, gold, bands, baseline_refused)
    check("the editor baseline scores below 1.0 recall (it is the gap M2 is for)",
          0 < result["strict"]["recall"] < 1.0, result["strict"])

    # A volume the ground truth covers and the detector produced NOTHING for. This used to read
    # as "it scanned zero of those documents", dropping them out of BOTH sides of the ratio: a
    # detector that died on a volume scored identically to one that swept the whole sample.
    volumes = sorted({volume for volume, _ in gold})
    partial = {key: spans for key, spans in gold.items() if key[0] == volumes[0]}
    partial_store = write_detector(root, "det-partial", partial)
    predictions, refused = score_detections.collect_predictions(partial_store, "detected",
                                                                gold, False)
    result = score_detections.score_one("partial", predictions, gold, bands, refused)
    check("a volume the detector produced nothing for is refused by name, not scored as empty",
          volumes[1] in result["volumes_refused"]
          and result["documents_scored"] < result["documents_in_ground_truth"],
          (result["volumes_refused"], result["documents_scored"]))

    # The same accounting on the baseline side, where it decides the number the whole
    # detector-versus-free-layer question is settled against — and driven through `main()`,
    # not by re-assembling its steps. The defect was in main's CALL, which discarded the
    # refusal list (`, _`) and passed a literal `[]`; a check that called collect_predictions
    # and score_one itself passed against the bug, which a mutation sweep proved by restoring
    # it and watching the suite stay green.
    thin_marked = os.path.join(root, "marked-thin")
    os.makedirs(os.path.join(thin_marked, "marked"), exist_ok=True)
    shutil.copy(os.path.join(store_dir, "marked", volumes[0] + ".jsonl.gz"),
                os.path.join(thin_marked, "marked", volumes[0] + ".jsonl.gz"))
    scored_path = os.path.join(root, "scored.json")
    saved = (score_detections.GROUND_TRUTH, score_detections.DETECTORS,
             score_detections.MARKED_STORE, score_detections.TEXT_DIR, score_detections.OUT)
    try:
        score_detections.GROUND_TRUTH = os.path.join(out_dir, "m2a-ground-truth.jsonl")
        score_detections.DETECTORS = [subset_store]
        score_detections.MARKED_STORE = thin_marked
        score_detections.TEXT_DIR = text_dir
        score_detections.OUT = scored_path
        score_detections.TEXT_CACHE.clear()
        score_detections.main()
    finally:
        (score_detections.GROUND_TRUTH, score_detections.DETECTORS,
         score_detections.MARKED_STORE, score_detections.TEXT_DIR,
         score_detections.OUT) = saved
    written = json.load(open(scored_path, encoding="utf-8"))
    baseline_row = written["results"][0]
    check("the baseline reports the volumes whose marked layer is missing",
          baseline_row["detector"].startswith("editor markup")
          and baseline_row["volumes_refused"] == [volumes[1]],
          (baseline_row["detector"], baseline_row["volumes_refused"]))

    # The R-0 text directory gets the same both-present refusal the layer reader has. It had its
    # own resolver, which silently preferred the .gz — in the one directory the Swift control
    # also reads, and which prefers the plain file.
    ambiguous = os.path.join(root, "ambiguous-text")
    os.makedirs(ambiguous, exist_ok=True)
    shutil.copy(os.path.join(text_dir, volumes[0] + ".jsonl.gz"),
                os.path.join(ambiguous, volumes[0] + ".jsonl.gz"))
    open(os.path.join(ambiguous, volumes[0] + ".jsonl"), "w").write("")
    check("the text layer refuses a volume present as both .jsonl and .jsonl.gz",
          _raises(lambda: ner_store.volume_text(ambiguous, volumes[0])))

    print("\n== a document that names no one ==")
    # The span file holds one row per gold span, so a document with no spans had no row and vanished
    # from scoring: every detection in it was a false positive nobody counted. "No spans" and "marked
    # `none`" are DIFFERENT facts and the fixture keeps them apart, or code reading the mark instead of the
    # span count passes: the unfinished document is stripped of every bracket but marked `y` (no
    # mentions), and two others are marked `none` while keeping their seeded span (one mention each).
    gt_path = os.path.join(out_dir, "m2a-ground-truth.jsonl")
    docs_path = os.path.join(out_dir, "m2a-ground-truth-documents.jsonl")
    empty_entry = staged[unfinished]
    empty_key = (empty_entry["volume"], empty_entry["document"])
    empty_label = "%s/%s" % empty_key
    empty_text = documents[empty_entry["volume"]][empty_entry["document"]]
    others = [name for name in sorted(staged) if name != unfinished]
    kept_seed = others[:2]
    for name in kept_seed:
        row = staged[name]
        seeds = sorted(ner_store.spans_by_document(
            ner_store.volume_layer(store_dir, "marked", row["volume"])).get(row["document"], []))
        with open(os.path.join(out_dir, name), "w", encoding="utf-8") as handle:
            handle.write(stage.wrap(documents[row["volume"]][row["document"]], seeds))
    with open(os.path.join(out_dir, unfinished), "w", encoding="utf-8") as handle:
        handle.write(empty_text)
    marks = {name: ("none" if name in kept_seed else "y") for name in staged}
    write_progress([dict(row, annotated=marks[row["file"]]) for row in saved_rows])
    stage.collect()
    listed = [json.loads(line) for line in open(docs_path, encoding="utf-8") if line.strip()]
    truth_now = [json.loads(line) for line in open(gt_path, encoding="utf-8") if line.strip()]
    summary_now = json.load(open(os.path.join(out_dir, "m2a-collection-summary.json")))
    by_doc = {(row["v"], row["d"]): row for row in listed}
    seeded_keys = [(staged[n]["volume"], staged[n]["document"]) for n in kept_seed]
    check("the collector lists a document with no spans by its span count, not by its mark",
          by_doc.get(empty_key, {}).get("mentions") == 0 and by_doc[empty_key]["mark"] == "y"
          and by_doc[empty_key]["band"] == empty_entry["band"]
          and empty_key not in {(r["v"], r["d"]) for r in truth_now}
          and all(by_doc[key]["mark"] == "none" and by_doc[key]["mentions"] == 1 for key in seeded_keys),
          listed)
    check("the document list names every annotated document with its own mention count",
          len(listed) == summary_now["documents_annotated"] == len(saved_rows)
          and all(row["mentions"] == sum(1 for t in truth_now if (t["v"], t["d"]) == (row["v"], row["d"]))
                  for row in listed),
          listed)
    check("the collection summary counts documents with no spans, not documents marked `none`",
          summary_now["documents_without_mentions"] == 1, summary_now["documents_without_mentions"])

    captured, real_stdout = io.StringIO(), sys.stdout
    sys.stdout = captured
    try:
        gold_e, bands_e = score_detections.load_ground_truth(gt_path)
    finally:
        sys.stdout = real_stdout
    check("the scorer loads that document as empty gold, in its band, and the `none` ones with their seed",
          gold_e.get(empty_key) == [] and bands_e.get(empty_key) == empty_entry["band"]
          and all(len(gold_e[key]) == 1 for key in seeded_keys) and len(gold_e) == len(listed),
          (gold_e.get(empty_key), bands_e.get(empty_key), [gold_e.get(k) for k in seeded_keys]))
    check("with the list present, the no-list note stays silent", "note:" not in captured.getvalue(),
          captured.getvalue()[:200])

    pair = ("Hamilton Fish", "Seward") if empty_key[0] == "frus1872p1" else ("Mr. Bevin", "Marshall")
    tagged = []
    for name in pair:
        at = empty_text.find(name)
        while at != -1:
            tagged.append((at, at + len(name), name))
            at = empty_text.find(name, at + 1)
    tagged.sort()
    overeager = {key: list(spans) for key, spans in gold_e.items()}
    overeager[empty_key] = tagged
    everything = {}
    for volume, document in gold_e:
        everything.setdefault(volume, set()).add(document)
    overeager_store = write_detector(root, "det-overeager", overeager, sampled_ids=everything)
    predictions, refused = score_detections.collect_predictions(overeager_store, "detected",
                                                                gold_e, False)
    result = score_detections.score_one("overeager", predictions, gold_e, bands_e, refused)
    mentioned = sum(len(spans) for spans in gold_e.values())
    check("detections in a document that names no one lower precision and leave recall alone",
          len(tagged) >= 2 and result["strict"]["recall"] == 1.0
          and result["strict"]["predicted"] == mentioned + len(tagged)
          and result["strict"]["precision"] == round(mentioned / (mentioned + len(tagged)), 4),
          (result["strict"], len(tagged)))
    in_band = sum(1 for row in listed if row["band"] == empty_entry["band"])
    check("documents_scored and the band table both count the empty document",
          result["documents_scored"] == len(listed)
          and result["by_band"][empty_entry["band"]]["documents"] == in_band
          and result["by_band"][empty_entry["band"]]["strict"]["predicted"]
          == sum(len(overeager[k]) for k in overeager if bands_e[k] == empty_entry["band"]),
          (result["documents_scored"], result["by_band"]))

    # Backward compatibility: a ground truth collected before the list existed still scores — and
    # scores exactly as the gap did, which is why it has to say so.
    os.rename(docs_path, docs_path + ".hidden")
    captured, real_stdout = io.StringIO(), sys.stdout
    sys.stdout = captured
    try:
        gold_old, bands_old = score_detections.load_ground_truth(gt_path)
    finally:
        sys.stdout = real_stdout
    predictions, refused = score_detections.collect_predictions(overeager_store, "detected",
                                                                gold_old, False)
    old_result = score_detections.score_one("overeager", predictions, gold_old, bands_old, refused)
    check("without a document list the scorer loads the span file and names what it cannot see",
          empty_key not in gold_old and "Re-run COLLECT=1" in captured.getvalue()
          and "m2a-ground-truth-documents.jsonl" in captured.getvalue(),
          captured.getvalue()[:160])
    check("...and scores precision exactly as the gap hid it",
          old_result["strict"]["precision"] == 1.0
          and old_result["documents_scored"] == len(listed) - 1, old_result["strict"])

    def run_main(detectors, ground_truth=gt_path):
        """main() with this fixture's paths: (written report, printed output). Raises what main raises."""
        out_json = os.path.join(root, "scored-%d.json" % len(CHECKS))
        saved_globals = (score_detections.GROUND_TRUTH, score_detections.DETECTORS,
                         score_detections.MARKED_STORE, score_detections.TEXT_DIR, score_detections.OUT)
        buffer, real = io.StringIO(), sys.stdout
        try:
            score_detections.GROUND_TRUTH = ground_truth
            score_detections.DETECTORS = detectors
            score_detections.MARKED_STORE = store_dir
            score_detections.TEXT_DIR = text_dir
            score_detections.OUT = out_json
            score_detections.TEXT_CACHE.clear()
            sys.stdout = buffer
            score_detections.main()
        finally:
            sys.stdout = real
            (score_detections.GROUND_TRUTH, score_detections.DETECTORS,
             score_detections.MARKED_STORE, score_detections.TEXT_DIR,
             score_detections.OUT) = saved_globals
        return json.load(open(out_json, encoding="utf-8")), buffer.getvalue()

    written_old, output_old = run_main([overeager_store])
    os.rename(docs_path + ".hidden", docs_path)
    check("without a list, main() reports the empty-document count as unknown, not zero",
          written_old["document_list"] is None and written_old["documents_without_mentions"] is None
          and "cannot be counted" in output_old,
          (written_old["document_list"], written_old["documents_without_mentions"]))

    # A list that disagrees with its span file is from another collection. One fixture per way it can.
    listing_text = open(docs_path, encoding="utf-8").read()
    list_lines = [line for line in listing_text.splitlines() if line.strip()]
    with_mentions = next(line for line in list_lines if json.loads(line)["mentions"] > 0)
    empty_line = next(line for line in list_lines if json.loads(line)["mentions"] == 0)
    def rewrite(lines_out):
        with open(docs_path, "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines_out) + "\n")
    def refusal(expected, path=gt_path):
        buffer, real = io.StringIO(), sys.stdout
        sys.stdout = buffer
        try:
            score_detections.load_ground_truth(path)
        except SystemExit as exit_code:
            return expected in str(exit_code)
        finally:
            sys.stdout = real
        return False
    rewrite([line for line in list_lines if line != with_mentions])
    check("a list missing a document that has mentions is refused", refusal("does not list"))
    rewrite([json.dumps(dict(json.loads(line), mentions=json.loads(line)["mentions"] + 1))
             if line == with_mentions else line for line in list_lines])
    check("a list whose count for a document WITH spans disagrees is refused", refusal("mention(s)"))
    rewrite([json.dumps(dict(json.loads(line), mentions=1)) if line == empty_line else line
             for line in list_lines])
    check("a list claiming mentions for a document with NO span rows is refused", refusal("mention(s)"))
    rewrite([json.dumps(dict(json.loads(line), band="1900-1929"))
             if line == with_mentions else line for line in list_lines])
    check("a list that puts a document in another band is refused", refusal("in band"))
    original_row = json.loads(with_mentions)
    differing = dict(original_row, mark="y" if original_row["mark"] == "none" else "none")
    check("the duplicate fixture really differs from the row it repeats", differing != original_row)
    rewrite(list_lines + [json.dumps(differing)])
    check("a list naming a document twice is refused, even with differing rows", refusal("twice"))
    with open(docs_path, "w", encoding="utf-8") as handle:
        handle.write(listing_text)
    check("the document list handed to GROUND_TRUTH is refused by name, not a KeyError",
          refusal("not a ground-truth span file", path=docs_path))

    # Through main(), one detector per run so each note is attributable to the detector that earned it.
    written, output = run_main([overeager_store])
    check("main() writes the empty document into every denominator it reports, and prints no note",
          written["documents"] == len(listed) and written["documents_without_mentions"] == 1
          and written["document_list"] == docs_path
          and written["results"][1]["documents_scored"] == len(listed)
          and written["results"][1]["strict"]["precision"] < 1.0
          and "not scored" not in output,
          (written["documents"], written["documents_without_mentions"], output[-300:]))

    # A pass restricted by the span file, where the empty document shares a volume with ones that have
    # spans: the volume has a head that simply omits it.
    spans_only = {}
    for volume, document in gold_e:
        if gold_e[(volume, document)]:
            spans_only.setdefault(volume, set()).add(document)
    targeted_store = write_detector(root, "det-targeted",
                                    {k: v for k, v in gold_e.items() if v}, sampled_ids=spans_only)
    written, output = run_main([targeted_store])
    check("a span-file-restricted pass that omitted the empty document is told which one, and what to use",
          written["results"][1]["documents_not_scored_naming_no_one"] == [empty_label]
          and ("1 document(s) that name no one were not scored for this detector (%s)" % empty_label) in output
          and "restrict it with m2a-ground-truth-documents.jsonl instead, into a fresh OUT_DIR" in output
          and "with mentions were outside" not in output,
          output[-700:])

    # The real sample's shape: the empty document is ALONE in what the detector saw of its volume, so a
    # span-file-restricted pass writes no head for that volume at all and the volume is refused. The note
    # must still fire — subtracting refused volumes silenced it here.
    other_volume = next(volume for volume, _ in gold_e if volume != empty_key[0])
    headless = write_detector(root, "det-headless",
                              {k: v for k, v in gold_e.items() if k[0] == other_volume},
                              sampled_ids={other_volume: {d for v, d in gold_e if v == other_volume}})
    written, output = run_main([headless])
    check("an empty document inside a refused volume is still named, with the refusal's real causes",
          written["results"][1]["volumes_refused"] == [empty_key[0]]
          and "not run on it" in output
          and ("that name no one were not scored for this detector (%s)" % empty_label) in output
          and "with mentions were outside" not in output,
          output[-700:])

    # A sample that left out a document WITH mentions is not a span-file restriction and must not be
    # blamed on one.
    thin_key = next(key for key in sorted(gold_e) if gold_e[key] and key != empty_key)
    thinned = {}
    for volume, document in gold_e:
        if (volume, document) != thin_key:
            thinned.setdefault(volume, set()).add(document)
    sampler = write_detector(root, "det-sampler", {k: v for k, v in gold_e.items() if k != thin_key},
                             sampled_ids=thinned)
    written, output = run_main([sampler])
    check("a thin sample of documents with mentions gets a neutral note naming them, and no ONLY_DOCUMENTS advice",
          ("1 document(s) with mentions were outside this detector's sample and are not scored: %s/%s"
           % thin_key) in output
          and "ONLY_DOCUMENTS" not in output and "name no one were not scored" not in output,
          output[-500:])

    # A collection whose only annotated document names no one is written; the scorer refuses it, since a
    # detector that predicts nothing would tie with one that predicts noise. Nothing marked is still refused.
    write_progress([dict(row, annotated="y" if row["file"] == unfinished else "") for row in saved_rows])
    stage.collect()
    only_listed = [json.loads(line) for line in open(docs_path, encoding="utf-8") if line.strip()]
    check("a collection whose only document names no one is written, not refused as empty",
          open(gt_path, encoding="utf-8").read().strip() == ""
          and [(r["v"], r["d"], r["mentions"]) for r in only_listed] == [empty_key + (0,)],
          only_listed)
    try:
        run_main([overeager_store])
        check("...and the scorer refuses a ground truth with no mentions at all", False, "it scored")
    except SystemExit as exit_code:
        check("...and the scorer refuses a ground truth with no mentions at all",
              "no mentions at all" in str(exit_code), exit_code)
    write_progress([dict(row, annotated="") for row in saved_rows])
    try:
        stage.collect()
        check("nothing marked at all is still refused", False, "it collected")
    except SystemExit as exit_code:
        check("nothing marked at all is still refused",
              "nothing marked annotated" in str(exit_code), exit_code)

    shutil.rmtree(root, ignore_errors=True)
    failed = [label for label, ok, _ in CHECKS if not ok]
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    if failed:
        print("FAILED: " + "; ".join(failed))
        sys.exit(1)
    print("SELFTEST PASSED")
