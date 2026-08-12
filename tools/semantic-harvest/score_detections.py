#!/usr/bin/env python3
"""Score a detector's `detected/` layer against the M2a ground truth.

This is the step that turns the harvest's descriptive numbers (how much did it find, how
grounded was it) into evaluative ones (was it right). It scores any number of stores in
one run — the LM Studio pilots and the `NLTagger` control side by side — plus the
editors' own markup as a baseline, because "does this beat the free option" is the
question the whole detector route has to answer.

    GROUND_TRUTH=~/frus-m2a/m2a-ground-truth.jsonl \\
    DETECTORS=~/frus-ner-raw-pilot-a,~/frus-ner-raw-control \\
    python3 score_detections.py

Two matching rules are reported and neither is the "real" one on its own:

  * **strict** — the predicted span equals a gold span exactly. This is the number that
    matters for anything that will later slice text by offset.
  * **relaxed** — any overlap, in a maximum-cardinality one-to-one matching. This is the number
    that says whether the detector found the *mention* while disagreeing about where a
    title ends, which is the commonest boundary quarrel in this corpus
    ("Mr. Bevin" vs "Bevin", "Sir Edward Grey" vs "Edward Grey").

A detector is scored ONLY over documents it actually scanned. A sampled run records its
document ids in `detected/<vol>.head.json`; a store that sampled without recording them
is refused rather than scored, because a document the detector never saw would otherwise
count as a page of misses and depress recall by an arbitrary amount.

Environment:
  GROUND_TRUTH  default ~/frus-m2a/m2a-ground-truth.jsonl
  DETECTORS     comma-separated store directories (required)
  STORE         the marked-layer store for the editor baseline (default ~/frus-ner-raw)
  TEXT_DIR      default ~/frus-semantic-raw/text — used only to verify spans slice back
  OUT           default ./score-detections.json
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ner_store as store  # noqa: E402

GROUND_TRUTH = os.path.expanduser(os.environ.get("GROUND_TRUTH", "~/frus-m2a/m2a-ground-truth.jsonl"))
DETECTORS = [p.strip() for p in os.environ.get("DETECTORS", "").split(",") if p.strip()]
MARKED_STORE = os.path.expanduser(os.environ.get("STORE", "~/frus-ner-raw"))
TEXT_DIR = os.path.expanduser(os.environ.get("TEXT_DIR", "~/frus-semantic-raw/text"))
OUT = os.path.expanduser(os.environ.get("OUT", "./score-detections.json"))


def load_ground_truth(path):
    """{(volume, document): [(s, e, surface)]} plus {(volume, document): band}."""
    if not os.path.exists(path):
        raise SystemExit("no ground truth at %s.\nM2a is the gate: stage it with "
                         "stage_m2a.py, key it, collect it (COLLECT=1), then score."
                         % path)
    gold, bands = {}, {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            row = json.loads(line)
            key = (row["v"], row["d"])
            gold.setdefault(key, []).append((row["s"], row["e"], row["n"]))
            bands[key] = row.get("band")
    return {key: sorted(spans) for key, spans in gold.items()}, bands


def scanned_documents(store_dir, volume, fallback_documents):
    """Which documents of `volume` this store's detector actually looked at.

    Returns None when the store sampled but did not record which documents — the caller
    refuses to score that volume rather than guessing.
    """
    head = store.layer_head(store_dir, "detected", volume)
    if head is None:
        # A body with no head is a killed run, not a volume the detector skipped: the head is
        # written last precisely so its absence means "unfinished". Refuse it by name rather
        # than dropping its documents out of the denominator without saying so.
        return None if store.layer_path(store_dir, "detected", volume) else set()
    if "sampled" not in head:
        return None                    # cannot tell a full pass from a sample: refuse
    if not head["sampled"]:
        return set(fallback_documents)
    ids = head.get("sampled_doc_ids")
    if ids is None:
        return None
    return set(ids)


def match(gold, predicted):
    """(strict_hits, relaxed_hits, matched_prediction_indices, matched_gold_indices).

    Relaxed matching is a MAXIMUM-CARDINALITY one-to-one matching over the overlap graph
    (Kuhn's augmenting paths), not a greedy pass. Greedy is not the same thing and the
    difference is not academic: with gold spans "Mr. Bevin" and "Grey" against predictions
    "Mr. Bevin and Grey" and "Bevin", greedy takes the largest overlap first, pairs the long
    prediction with "Mr. Bevin", and leaves "Grey" unmatched — reporting a miss and a false
    positive where a matching exists that pairs both. It scores a detector down for a defect
    it does not have.

    Determinism: gold spans are visited in index order and each one's candidates are tried
    by descending overlap then index, so the same input always yields the same pairing.
    """
    strict_gold = {(s, e) for s, e, _ in gold}
    # Over DISTINCT predicted spans: `spans_by_document` de-duplicates on (start, end, surface),
    # so two rows sharing offsets with different surfaces would otherwise both score and push
    # recall above 1.0. The precision denominator still counts both, which is the honest way
    # round — a detector that emits a span twice has emitted two predictions.
    strict = len({(s, e) for s, e, _ in predicted} & strict_gold)

    candidates = {}
    for gold_index, (gold_start, gold_end, _) in enumerate(gold):
        overlapping = []
        for pred_index, (pred_start, pred_end, _) in enumerate(predicted):
            overlap = min(gold_end, pred_end) - max(gold_start, pred_start)
            if overlap > 0:
                overlapping.append((-overlap, pred_index))
        candidates[gold_index] = [index for _, index in sorted(overlapping)]

    matched = {}                       # prediction index -> gold index

    def assign(gold_index, visited):
        for pred_index in candidates[gold_index]:
            if pred_index in visited:
                continue
            visited.add(pred_index)
            if pred_index not in matched or assign(matched[pred_index], visited):
                matched[pred_index] = gold_index
                return True
        return False

    for gold_index in range(len(gold)):
        assign(gold_index, set())
    return strict, len(matched), set(matched), set(matched.values())


def prf(hits, predicted_count, gold_count):
    precision = hits / predicted_count if predicted_count else 0.0
    recall = hits / gold_count if gold_count else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    return {"precision": round(precision, 4), "recall": round(recall, 4),
            "f1": round(f1, 4), "hits": hits, "predicted": predicted_count,
            "gold": gold_count}


def score_one(name, per_document_predictions, gold, bands, skipped_volumes):
    """Aggregate one detector over the ground-truth documents it scanned."""
    totals = {"strict": 0, "relaxed": 0, "predicted": 0, "gold": 0}
    by_band, false_positives, misses = {}, [], []
    scored_documents = 0
    for key, gold_spans in sorted(gold.items()):
        if key not in per_document_predictions:
            continue
        predicted = per_document_predictions[key]
        scored_documents += 1
        strict, relaxed, used_pred, used_gold = match(gold_spans, predicted)
        totals["strict"] += strict
        totals["relaxed"] += relaxed
        totals["predicted"] += len(predicted)
        totals["gold"] += len(gold_spans)
        band = bands.get(key) or "?"
        bucket = by_band.setdefault(band, {"strict": 0, "relaxed": 0, "predicted": 0,
                                           "gold": 0, "documents": 0})
        bucket["strict"] += strict
        bucket["relaxed"] += relaxed
        bucket["predicted"] += len(predicted)
        bucket["gold"] += len(gold_spans)
        bucket["documents"] += 1
        for index, (_, _, surface) in enumerate(predicted):
            if index not in used_pred and len(false_positives) < 40:
                false_positives.append({"v": key[0], "d": key[1], "n": surface})
        for index, (_, _, surface) in enumerate(gold_spans):
            if index not in used_gold and len(misses) < 40:
                misses.append({"v": key[0], "d": key[1], "n": surface})

    return {
        "detector": name,
        "documents_scored": scored_documents,
        "documents_in_ground_truth": len(gold),
        "volumes_refused": sorted(skipped_volumes),
        "strict": prf(totals["strict"], totals["predicted"], totals["gold"]),
        "relaxed": prf(totals["relaxed"], totals["predicted"], totals["gold"]),
        "by_band": {band: {"strict": prf(b["strict"], b["predicted"], b["gold"]),
                           "relaxed": prf(b["relaxed"], b["predicted"], b["gold"]),
                           "documents": b["documents"]}
                    for band, b in sorted(by_band.items())},
        "false_positive_examples": false_positives,
        "missed_examples": misses,
    }


def collect_predictions(store_dir, layer, gold, verify_text):
    """{(volume, document): [(s, e, surface)]} for the ground-truth documents it scanned."""
    wanted = {}
    for volume, document in gold:
        wanted.setdefault(volume, set()).add(document)
    predictions, refused = {}, []
    for volume, documents in sorted(wanted.items()):
        rows = store.volume_layer(store_dir, layer, volume)
        if layer == "detected":
            scanned = scanned_documents(store_dir, volume, documents)
            if scanned is None:
                refused.append(volume)
                continue
        else:
            # An absent marked file is not "this volume has no editor spans": it is a volume the
            # harvest never wrote. Scoring it as a page of misses halves the baseline's recall,
            # and a halved number is likelier to be believed than a zeroed one.
            if store.layer_path(store_dir, "marked", volume) is None:
                refused.append(volume)
                continue
            scanned = documents
        by_document = store.spans_by_document(rows)
        texts = store.volume_text(TEXT_DIR, volume) if verify_text else None
        for document in sorted(documents & scanned):
            spans = by_document.get(document, [])
            if texts is not None:
                if document not in texts:
                    sys.exit("%s/%s is in the ground truth but not in the R-0 text layer at %s.\n"
                             "The ground truth and the text layer describe different corpora."
                             % (volume, document, TEXT_DIR))
                store.check_spans(texts[document], spans, "%s %s/%s"
                                  % (store_dir, volume, document))
            predictions[(volume, document)] = spans
    return predictions, refused


def main():
    if not DETECTORS:
        sys.exit("Set DETECTORS to one or more store directories (comma-separated).")
    gold, bands = load_ground_truth(GROUND_TRUTH)
    verify_text = os.path.isdir(TEXT_DIR)
    if not verify_text:
        print("note: TEXT_DIR absent, skipping the span-slices-back check")
    else:
        # Verify the GOLD spans first, before any detector is read. A ground truth staged
        # against an older copy of the corpus still parses, still scores, and reports a
        # perfect detector as a total strict failure — a wrong answer with no error anywhere.
        # This is the same check the predictions get, applied to the side everything is
        # measured against.
        by_volume = {}
        for (volume, document), spans in gold.items():
            by_volume.setdefault(volume, []).append((document, spans))
        for volume in sorted(by_volume):          # one decompression per volume, not per document
            texts = store.volume_text(TEXT_DIR, volume)
            for document, spans in sorted(by_volume[volume]):
                if document not in texts:
                    sys.exit("ground truth names %s/%s, which the R-0 text layer does not hold."
                             % (volume, document))
                store.check_spans(texts[document], spans,
                                  "ground truth %s/%s" % (volume, document))

    if not os.path.isdir(os.path.join(MARKED_STORE, "marked")):
        sys.exit("no marked/ layer at %s — set STORE to the NER store harvest_ner.py wrote.\n"
                 "Without it the editor baseline would score 0.000 recall and look like a "
                 "finding." % MARKED_STORE)

    results = []
    baseline_predictions, _ = collect_predictions(MARKED_STORE, "marked", gold, verify_text)
    results.append(score_one("editor markup (baseline)", baseline_predictions, gold, bands, []))
    for path in DETECTORS:
        expanded = os.path.expanduser(path)
        predictions, refused = collect_predictions(expanded, "detected", gold, verify_text)
        results.append(score_one(os.path.basename(expanded.rstrip("/")), predictions,
                                 gold, bands, refused))

    json.dump({"ground_truth": GROUND_TRUTH, "documents": len(gold),
               "mentions": sum(len(v) for v in gold.values()), "results": results},
              open(OUT, "w"), indent=1, sort_keys=True)

    print("\n%-28s %6s %6s %6s   %6s %6s %6s  %5s"
          % ("detector", "P", "R", "F1", "P~", "R~", "F1~", "docs"))
    print("%s  (~ = relaxed, any-overlap)" % ("-" * 78))
    for result in results:
        strict, relaxed = result["strict"], result["relaxed"]
        print("%-28s %6.3f %6.3f %6.3f   %6.3f %6.3f %6.3f  %5d"
              % (result["detector"][:28], strict["precision"], strict["recall"],
                 strict["f1"], relaxed["precision"], relaxed["recall"], relaxed["f1"],
                 result["documents_scored"]))
        if result["volumes_refused"]:
            print("    refused (unfinished, or sampled without recording document ids): %s"
                  % ", ".join(result["volumes_refused"]))
    print("\nGround truth: %d mentions over %d documents. Full detail, including false "
          "positives\nand misses to read by hand: %s"
          % (sum(len(v) for v in gold.values()), len(gold), OUT))
    print("The baseline row is the editors' own markup scored as if it were a detector — "
          "its\nrecall is the share of mentions the free layer already gives you.")


if __name__ == "__main__":
    if os.environ.get("SELFTEST"):
        import selftest_m2a
        selftest_m2a.run()
    else:
        main()
