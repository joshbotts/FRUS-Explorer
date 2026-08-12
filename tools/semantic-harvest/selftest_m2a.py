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
  * a detector that sampled without recording its document ids is refused, not scored.
"""

import csv
import gzip
import io
import json
import os
import shutil
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
            body = head + FILLER + " A closing word from %s. " % names[1]
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

    shutil.rmtree(root, ignore_errors=True)
    failed = [label for label, ok, _ in CHECKS if not ok]
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    if failed:
        print("FAILED: " + "; ".join(failed))
        sys.exit(1)
    print("SELFTEST PASSED")
