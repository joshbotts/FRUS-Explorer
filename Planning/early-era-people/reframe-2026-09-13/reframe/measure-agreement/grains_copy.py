#!/usr/bin/env python3
"""measure-grains: re-score the 64-document M2a gold at mention grain and at DOCUMENT-PRESENCE grain,
adding the intersection / union arms the record does not have. POST-HOC: every arm and the presence
grain were chosen after the published §7.2 scores existed.

Matching rule is the scorer's own: score_detections.load_ground_truth / collect_predictions / match / prf.
Stdlib only. Read-only on every store.
"""
import os
import sys
import json
import random
import re
import collections

SCRATCH = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
STUDIO = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio"

# The scorer reads these at module level, so set them BEFORE the import.
os.environ["GROUND_TRUTH"] = STUDIO + "/frus-m2a/m2a-ground-truth.jsonl"
os.environ["STORE"] = "/Users/jbotts/frus-ner-raw"
os.environ["TEXT_DIR"] = "/Users/jbotts/frus-semantic-raw/text"
os.environ["DETECTORS"] = ""
os.environ["OUT"] = os.path.join(SCRATCH, "unused-scorer-out.json")
sys.path.insert(0, REPO + "/tools/semantic-harvest")
import score_detections as sd  # noqa: E402

STORES = {
    "editor": (os.environ["STORE"], "marked"),
    "raw_sweep": (STUDIO + "/frus-ner-raw", "detected"),
    "boundary_sweep": ("/Users/jbotts/frus-ner-raw-filtered-boundary", "detected"),
    "filtered_sweep": ("/Users/jbotts/frus-ner-raw-filtered", "detected"),
    "raw_control": ("/Users/jbotts/frus-ner-raw-control", "detected"),
    "filtered_control": ("/Users/jbotts/frus-ner-raw-control-filtered", "detected"),
}

RESAMPLES = 10000
SEED = 234

# ---------------------------------------------------------------- set arithmetic on span lists

def overlaps(a, b):
    return min(a[1], b[1]) - max(a[0], b[0]) > 0


def union_exact(*arms):
    """Concatenate prediction sets, remove EXACT duplicate (s, e, surface) spans."""
    out = {}
    for arm in arms:
        for key, spans in arm.items():
            out.setdefault(key, set()).update(spans)
    return {key: sorted(spans) for key, spans in out.items()}


def union_overlap(first, second):
    """Keep all of `first`; add a `second` span only when it overlaps NO span of `first`."""
    out = {}
    for key in set(first) | set(second):
        kept = list(first.get(key, []))
        for span in second.get(key, []):
            if not any(overlaps(span, k) for k in first.get(key, [])):
                kept.append(span)
        out[key] = sorted(set(kept))
    return out


def intersection(keep, against):
    """Spans of `keep` that overlap (>0 chars) at least one span of `against`, per document."""
    out = {}
    for key in keep:
        out[key] = sorted(s for s in keep[key] if any(overlaps(s, t) for t in against.get(key, [])))
    return out


# ---------------------------------------------------------------- presence-grain key

HONORIFICS = [
    "mr", "mrs", "ms", "miss", "messrs", "dr", "hon", "sir", "lord", "lady", "general", "gen",
    "colonel", "col", "captain", "capt", "major", "maj", "lieutenant", "lieut", "lt", "admiral",
    "adm", "commodore", "commander", "cmdr", "president", "secretary", "senator", "ambassador",
    "minister", "consul", "judge", "governor", "gov", "count", "countess", "baron", "baroness",
    "earl", "duke", "prince", "princess", "king", "queen", "señor", "senor", "don", "monsieur",
    "m", "madame", "mme", "herr", "rev", "reverend", "professor", "prof", "the", "acting", "vice",
    "privy", "his", "her", "excellency", "chairman", "marshal", "premier", "chancellor", "bishop",
    "archbishop", "cardinal", "father", "brother", "sister",
]
HONORIFIC_SET = set(HONORIFICS)
POSSESSIVE = re.compile(r"(?:['’]s|['’])$")


def surface_key(surface):
    """casefold -> collapse whitespace -> strip trailing possessive -> strip leading honorifics
    (repeatedly, each token compared with its trailing '.' removed). If stripping would leave
    nothing, the un-stripped (casefolded, collapsed, de-possessived) form is the key."""
    s = " ".join(surface.casefold().split())
    s = POSSESSIVE.sub("", s).strip()
    tokens = s.split()
    i = 0
    while i < len(tokens) and tokens[i].rstrip(".") in HONORIFIC_SET:
        i += 1
    stripped = " ".join(tokens[i:])
    return stripped if stripped else s


# ---------------------------------------------------------------- per-document counting

def mention_doc_counts(gold, preds):
    """{key: (strict, relaxed, predicted, gold)} over the documents the arm covers."""
    out = {}
    for key, gold_spans in gold.items():
        if key not in preds:
            continue
        predicted = preds[key]
        strict, relaxed, _, _ = sd.match(gold_spans, predicted)
        out[key] = (strict, relaxed, len(predicted), len(gold_spans))
    return out


def presence_doc_counts(gold, preds):
    """{key: (pred_key_hits, pred_keys, gold_key_hits, gold_keys)} plus the false / missed keys.

    Per document: scorer's relaxed match at mention level, then collapse to normalised surface keys.
    A gold KEY is found if any of its mentions matched; a predicted KEY is false if none of its
    mentions matched.
    """
    out, false_keys, missed_keys, true_keys = {}, collections.Counter(), collections.Counter(), collections.Counter()
    false_by_doc, missed_by_doc = [], []
    for key, gold_spans in gold.items():
        if key not in preds:
            continue
        predicted = preds[key]
        _, _, used_pred, used_gold = sd.match(gold_spans, predicted)
        gold_keys = collections.defaultdict(bool)
        for i, (_, _, n) in enumerate(gold_spans):
            gold_keys[surface_key(n)] |= (i in used_gold)
        pred_keys = collections.defaultdict(bool)
        for i, (_, _, n) in enumerate(predicted):
            pred_keys[surface_key(n)] |= (i in used_pred)
        gk_hits = sum(1 for v in gold_keys.values() if v)
        pk_hits = sum(1 for v in pred_keys.values() if v)
        out[key] = (pk_hits, len(pred_keys), gk_hits, len(gold_keys))
        for k, v in pred_keys.items():
            if v:
                true_keys[k] += 1
            else:
                false_keys[k] += 1
                false_by_doc.append("%s/%s: %s" % (key[0], key[1], k))
        for k, v in gold_keys.items():
            if not v:
                missed_keys[k] += 1
                missed_by_doc.append("%s/%s: %s" % (key[0], key[1], k))
    return out, false_keys, missed_keys, true_keys, false_by_doc, missed_by_doc


# ---------------------------------------------------------------- aggregation + bootstrap

def prf_from(hits, predicted, gold):
    return sd.prf(hits, predicted, gold)


def aggregate(counts, keys):
    a = [0, 0, 0, 0]
    for k in keys:
        c = counts[k]
        for i in range(4):
            a[i] += c[i]
    return a


def mention_summary(counts, keys):
    s, r, p, g = aggregate(counts, keys)
    return {"strict": prf_from(s, p, g), "relaxed": prf_from(r, p, g), "documents": len(keys)}


def presence_summary(counts, keys):
    pk_hits, pk, gk_hits, gk = aggregate(counts, keys)
    precision = pk_hits / pk if pk else 0.0
    recall = gk_hits / gk if gk else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    return {"precision": round(precision, 4), "recall": round(recall, 4), "f1": round(f1, 4),
            "predicted_keys": pk, "predicted_keys_true": pk_hits, "predicted_keys_false": pk - pk_hits,
            "gold_keys": gk, "gold_keys_found": gk_hits, "gold_keys_missed": gk - gk_hits,
            "documents": len(keys)}


def make_resamples(bands, doc_keys):
    """Band-stratified document bootstrap: per resample, draw n_b documents with replacement within
    each band. One fixed set of resamples (seed 234) is shared by every arm and grain, so intervals
    are paired across arms."""
    rng = random.Random(SEED)
    by_band = collections.defaultdict(list)
    for k in sorted(doc_keys):
        by_band[bands.get(k) or "?"].append(k)
    band_names = sorted(by_band)
    resamples = []
    for _ in range(RESAMPLES):
        draw = {}
        for b in band_names:
            docs = by_band[b]
            draw[b] = [docs[rng.randrange(len(docs))] for _ in docs]
        resamples.append(draw)
    return band_names, by_band, resamples


def percentile(values, q):
    values = sorted(values)
    idx = q * (len(values) - 1)
    lo, hi = int(idx), min(int(idx) + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (idx - lo)


def ci(values):
    return [round(percentile(values, 0.025), 4), round(percentile(values, 0.975), 4)]


def bootstrap_mention(counts, resamples, band_names):
    """95% percentile intervals on strict/relaxed P, R, F1 — overall and per band."""
    acc = {"overall": collections.defaultdict(list)}
    for b in band_names:
        acc[b] = collections.defaultdict(list)
    for draw in resamples:
        tot = [0, 0, 0, 0]
        for b in band_names:
            s, r, p, g = aggregate(counts, draw[b])
            for i, v in enumerate((s, r, p, g)):
                tot[i] += v
            _push_mention(acc[b], s, r, p, g)
        _push_mention(acc["overall"], *tot)
    return {scope: {m: ci(v) for m, v in vals.items()} for scope, vals in acc.items()}


def _push_mention(bucket, s, r, p, g):
    for name, hits in (("strict", s), ("relaxed", r)):
        pr = hits / p if p else 0.0
        rc = hits / g if g else 0.0
        f1 = 2 * pr * rc / (pr + rc) if (pr + rc) else 0.0
        bucket[name + "_precision"].append(pr)
        bucket[name + "_recall"].append(rc)
        bucket[name + "_f1"].append(f1)


def bootstrap_presence(counts, resamples, band_names):
    acc = {"overall": collections.defaultdict(list)}
    for b in band_names:
        acc[b] = collections.defaultdict(list)
    for draw in resamples:
        tot = [0, 0, 0, 0]
        for b in band_names:
            c = aggregate(counts, draw[b])
            for i, v in enumerate(c):
                tot[i] += v
            _push_presence(acc[b], *c)
        _push_presence(acc["overall"], *tot)
    return {scope: {m: ci(v) for m, v in vals.items()} for scope, vals in acc.items()}


def _push_presence(bucket, pk_hits, pk, gk_hits, gk):
    pr = pk_hits / pk if pk else 0.0
    rc = gk_hits / gk if gk else 0.0
    f1 = 2 * pr * rc / (pr + rc) if (pr + rc) else 0.0
    bucket["precision"].append(pr)
    bucket["recall"].append(rc)
    bucket["f1"].append(f1)


# ---------------------------------------------------------------- main

def main():
    gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
    n_docs, n_mentions = len(gold), sum(len(v) for v in gold.values())
    print("gold: %d documents, %d mentions, bands %s" % (
        n_docs, n_mentions, dict(collections.Counter(bands.values()))))
    assert (n_docs, n_mentions) == (64, 406), (n_docs, n_mentions)

    verify_text = os.path.isdir(os.environ["TEXT_DIR"])
    assert verify_text
    arms = {}
    refused_all = {}
    for name, (path, layer) in STORES.items():
        preds, refused = sd.collect_predictions(path, layer, gold, verify_text)
        arms[name] = preds
        refused_all[name] = refused
        assert not refused, (name, refused)
        assert set(preds) == set(gold), name

    # ---- positive control 1: the six published rows, via the scorer's own score_one
    published = {"editor": (0.215, 0.356), "raw_sweep": (0.492, 0.538), "boundary_sweep": (0.502, 0.548),
                 "filtered_sweep": (0.608, 0.662), "raw_control": (0.398, 0.689), "filtered_control": (0.413, 0.709)}
    control1 = {}
    for name, exp in published.items():
        res = sd.score_one(name, arms[name], gold, bands, [])
        got = (round(res["strict"]["f1"], 3), round(res["relaxed"]["f1"], 3))
        control1[name] = {"expected": exp, "got": got, "ok": got == exp}
        print("control1 %-18s expected %s got %s %s" % (name, exp, got, "OK" if got == exp else "MISMATCH"))
    assert all(v["ok"] for v in control1.values())

    # ---- positive control 2: the runbook's post-hoc unions (§7.2: 0.794 P .816 R .773; 0.646 P .493 R .936)
    control2 = {}
    for label, other, exp in (("editor+filtered_control", "filtered_control", (0.794, 0.816, 0.773)),
                              ("editor+filtered_sweep", "filtered_sweep", (0.646, 0.493, 0.936))):
        for defn, fn in (("exact_dedup", lambda a, b: union_exact(a, b)),
                         ("overlap_dedup_editor_first", lambda a, b: union_overlap(a, b))):
            res = sd.score_one(label, fn(arms["editor"], arms[other]), gold, bands, [])
            rel = res["relaxed"]
            got = (round(rel["f1"], 3), round(rel["precision"], 3), round(rel["recall"], 3))
            control2["%s/%s" % (label, defn)] = {"expected_relaxed_f1_p_r": exp, "got": got, "ok": got == exp,
                                                  "strict_f1": res["strict"]["f1"]}
            print("control2 %-24s %-28s expected %s got %s %s" % (label, defn, exp, got, "OK" if got == exp else "no"))

    # ---- derived arms (post-hoc)
    E, FC, FS = arms["editor"], arms["filtered_control"], arms["filtered_sweep"]
    arms["intersection_control_side"] = intersection(FC, FS)   # (i) filtered-control spans overlapping >=1 filtered-sweep span
    arms["intersection_sweep_side"] = intersection(FS, FC)     # symmetric: filtered-sweep spans overlapping >=1 filtered-control span
    arms["editor+filtered_control"] = union_exact(E, FC)
    arms["editor+filtered_sweep"] = union_exact(E, FS)
    arms["editor+intersection_control_side"] = union_exact(E, arms["intersection_control_side"])   # (ii)
    arms["editor+intersection_sweep_side"] = union_exact(E, arms["intersection_sweep_side"])
    arms["editor+filtered_control+filtered_sweep"] = union_exact(E, FC, FS)                        # (iii)
    arms["raw_control_intersect_raw_sweep"] = intersection(arms["raw_control"], arms["raw_sweep"])  # reference only

    doc_keys = sorted(gold)
    band_names, by_band, resamples = make_resamples(bands, doc_keys)
    print("bootstrap: %d resamples, seed %d, strata %s" % (
        RESAMPLES, SEED, {b: len(v) for b, v in by_band.items()}))

    mention_grain, presence_grain = {}, {}
    for name, preds in arms.items():
        # mention grain: point estimates through the scorer's score_one; CI from per-doc counts
        res = sd.score_one(name, preds, gold, bands, [])
        counts = mention_doc_counts(gold, preds)
        mine = mention_summary(counts, doc_keys)
        assert mine["strict"] == res["strict"] and mine["relaxed"] == res["relaxed"], name
        per_band = {b: mention_summary(counts, by_band[b]) for b in band_names}
        for b in band_names:
            assert per_band[b]["strict"] == res["by_band"][b]["strict"], (name, b)
        cis = bootstrap_mention(counts, resamples, band_names)
        mention_grain[name] = {"overall": mine, "overall_ci95": cis["overall"],
                               "by_band": {b: dict(per_band[b], ci95=cis[b]) for b in band_names}}
        print("mention  %-40s strict F1 %.3f [%.3f,%.3f]  relaxed P %.3f [%.3f,%.3f] R %.3f F1 %.3f [%.3f,%.3f]" % (
            name, mine["strict"]["f1"], *cis["overall"]["strict_f1"],
            mine["relaxed"]["precision"], *cis["overall"]["relaxed_precision"],
            mine["relaxed"]["recall"], mine["relaxed"]["f1"], *cis["overall"]["relaxed_f1"]))

        # presence grain
        pcounts, false_keys, missed_keys, true_keys, false_by_doc, missed_by_doc = presence_doc_counts(gold, preds)
        psum = presence_summary(pcounts, doc_keys)
        pband = {b: presence_summary(pcounts, by_band[b]) for b in band_names}
        pcis = bootstrap_presence(pcounts, resamples, band_names)
        presence_grain[name] = {
            "overall": psum, "overall_ci95": pcis["overall"],
            "by_band": {b: dict(pband[b], ci95=pcis[b]) for b in band_names},
            "false_predicted_keys_distinct": len(false_keys),
            "false_predicted_keys_document_occurrences": sum(false_keys.values()),
            "false_predicted_keys": [{"key": k, "false_in_documents": c,
                                      "also_true_in_documents": true_keys.get(k, 0)}
                                     for k, c in sorted(false_keys.items(), key=lambda kv: (-kv[1], kv[0]))],
            "false_predicted_keys_by_document": sorted(false_by_doc),
            "missed_gold_keys_distinct": len(missed_keys),
            "missed_gold_keys_document_occurrences": sum(missed_keys.values()),
            "missed_gold_keys": [{"key": k, "missed_in_documents": c}
                                 for k, c in sorted(missed_keys.items(), key=lambda kv: (-kv[1], kv[0]))],
            "missed_gold_keys_by_document": sorted(missed_by_doc),
        }
        print("presence %-40s P %.3f [%.3f,%.3f] R %.3f [%.3f,%.3f] F1 %.3f [%.3f,%.3f]  false keys %d (distinct %d)  missed %d (distinct %d)" % (
            name, psum["precision"], *pcis["overall"]["precision"], psum["recall"], *pcis["overall"]["recall"],
            psum["f1"], *pcis["overall"]["f1"], psum["predicted_keys_false"], len(false_keys),
            psum["gold_keys_missed"], len(missed_keys)))

    out = {
        "label": "POST-HOC: these arms (intersection, unions) and the document-presence grain were chosen after "
                 "the published NER-RUNBOOK §7.2 scores existed. Read as direction, not as a pre-registered result.",
        "sample": {"documents": n_docs, "mentions": n_mentions, "documents_naming_no_one":
                   sum(1 for v in gold.values() if not v), "bands": {b: len(v) for b, v in by_band.items()},
                   "ground_truth": os.environ["GROUND_TRUTH"]},
        "stores": {k: v[0] + " [" + v[1] + "]" for k, v in STORES.items()},
        "matching": "score_detections.match (strict = exact (s,e); relaxed = any-overlap, max-cardinality Kuhn)",
        "union_definition": "concatenation of the prediction sets with exact-duplicate (s,e,surface) spans removed",
        "intersection_definition": {
            "intersection_control_side": "filtered-control spans that overlap (>0 chars) >=1 filtered-sweep span in the same document",
            "intersection_sweep_side": "filtered-sweep spans that overlap (>0 chars) >=1 filtered-control span in the same document",
            "raw_control_intersect_raw_sweep": "reference only: raw-control spans overlapping >=1 raw-sweep span"},
        "presence_grain_definition": {
            "what": "per document: scorer relaxed match at mention level, then collapse mentions to a normalised "
                    "surface key; a gold KEY is found if any of its mentions matched; a predicted KEY is false if "
                    "none of its mentions matched. P = true predicted keys / predicted keys; R = found gold keys / "
                    "gold keys; both summed over (document, key) pairs, which is what person_mentions stores.",
            "key": "casefold -> collapse whitespace -> strip trailing possessive ('s / ’s / trailing apostrophe) -> "
                   "strip leading honorific tokens repeatedly (token compared with trailing '.' removed); if nothing "
                   "would remain, keep the un-stripped form",
            "honorifics": HONORIFICS},
        "bootstrap": {"resamples": RESAMPLES, "seed": SEED, "design": "band-stratified document bootstrap; "
                      "per resample draw n_b documents with replacement within each band; one shared resample set "
                      "for every arm and grain (paired); 95% percentile interval"},
        "positive_control_1_published_rows": control1,
        "positive_control_2_runbook_unions": control2,
        "mention_grain": mention_grain,
        "presence_grain": presence_grain,
    }
    with open(os.path.join(SCRATCH, "grains.json"), "w") as h:
        json.dump(out, h, indent=1, sort_keys=True, ensure_ascii=False)
    print("wrote", os.path.join(SCRATCH, "grains.json"))


if __name__ == "__main__":
    main()
