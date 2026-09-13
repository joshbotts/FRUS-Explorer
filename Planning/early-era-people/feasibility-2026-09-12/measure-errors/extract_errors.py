#!/usr/bin/env python3
"""List every relaxed-matching false positive and miss for the M2a arms, driving the real scorer.

Positive control: the totals printed must reproduce score-detections.json's relaxed hits/predicted/gold.
Writes errors-raw.json (every FP / miss with ~60 chars of R-0 context on each side) and one
readable listing per arm for hand categorisation.
"""
import json, os, sys, collections

GT = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/m2a-ground-truth.jsonl"
os.environ["GROUND_TRUTH"] = GT
os.environ["STORE"] = "/Users/jbotts/frus-ner-raw"
os.environ["TEXT_DIR"] = os.path.expanduser("~/frus-semantic-raw/text")
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, os.path.join(REPO, "tools/semantic-harvest"))
import score_detections as sd  # noqa
import ner_store as store  # noqa

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
ARMS = collections.OrderedDict([
    ("filtered_control", "/Users/jbotts/frus-ner-raw-control-filtered"),
    ("filtered_sweep", "/Users/jbotts/frus-ner-raw-filtered"),
    ("raw_sweep", "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"),
    ("raw_control", "/Users/jbotts/frus-ner-raw-control"),
])
CTX = 60

gold, bands = sd.load_ground_truth(GT)
print("gold documents", len(gold), "mentions", sum(len(v) for v in gold.values()))

# editor markup, for the union question
editor, editor_refused = sd.collect_predictions(os.environ["STORE"], "marked", gold, True)
assert not editor_refused, editor_refused

arm_preds = {}
for name, path in ARMS.items():
    preds, refused = sd.collect_predictions(path, "detected", gold, True)
    assert not refused, (name, refused)
    assert set(preds) == set(gold), name
    arm_preds[name] = preds


def overlaps(span, spans):
    s, e = span[0], span[1]
    return [x for x in spans if min(e, x[1]) - max(s, x[0]) > 0]


def context(text, s, e):
    left = text[max(0, s - CTX):s].replace("\n", "⏎")
    right = text[e:e + CTX].replace("\n", "⏎")
    return left, right


result = {"gold_documents": len(gold), "gold_mentions": sum(len(v) for v in gold.values()), "arms": {}}
for name, preds in arm_preds.items():
    totals = collections.Counter()
    fps, misses = [], []
    for key in sorted(gold):
        g, p = gold[key], preds[key]
        strict, relaxed, used_p, used_g = sd.match(g, p)
        totals["strict"] += strict; totals["relaxed"] += relaxed
        totals["predicted"] += len(p); totals["gold"] += len(g)
        text = sd.cached_volume_text(key[0])[key[1]]
        band = bands[key]
        ed = editor.get(key, [])
        for i, sp in enumerate(p):
            if i in used_p:
                continue
            l, r = context(text, sp[0], sp[1])
            fps.append({"id": "%s:%s/%s:%d-%d" % (name, key[0], key[1], sp[0], sp[1]),
                        "v": key[0], "d": key[1], "band": band, "s": sp[0], "e": sp[1], "n": sp[2],
                        "left": l, "right": r,
                        "overlaps_gold": bool(overlaps(sp, g)),      # should be False under relaxed unless gold span already claimed
                        "gold_overlapped": [x[2] for x in overlaps(sp, g)],
                        "editor_overlap": [x[2] for x in overlaps(sp, ed)],
                        "in_other_arms": [o for o, op in arm_preds.items() if o != name and overlaps(sp, op[key])]})
        for i, sp in enumerate(g):
            if i in used_g:
                continue
            l, r = context(text, sp[0], sp[1])
            misses.append({"id": "%s:%s/%s:%d-%d" % (name, key[0], key[1], sp[0], sp[1]),
                           "v": key[0], "d": key[1], "band": band, "s": sp[0], "e": sp[1], "n": sp[2],
                           "left": l, "right": r,
                           "pred_overlapped": [x[2] for x in overlaps(sp, p)],  # a prediction existed but was claimed by another gold span
                           "editor_covers": bool(overlaps(sp, ed)),
                           "found_by_other_arms": [o for o, op in arm_preds.items() if o != name and overlaps(sp, op[key])]})
    P = totals["relaxed"] / totals["predicted"]; R = totals["relaxed"] / totals["gold"]
    print("%-18s relaxed hits %d predicted %d gold %d  P %.4f R %.4f  FP %d misses %d  strict %d"
          % (name, totals["relaxed"], totals["predicted"], totals["gold"], P, R, len(fps), len(misses), totals["strict"]))
    assert len(fps) == totals["predicted"] - totals["relaxed"]
    assert len(misses) == totals["gold"] - totals["relaxed"]
    result["arms"][name] = {"store": ARMS[name], "relaxed": {"hits": totals["relaxed"], "predicted": totals["predicted"],
                            "gold": totals["gold"], "precision": round(P, 4), "recall": round(R, 4)},
                            "strict_hits": totals["strict"], "false_positives": fps, "misses": misses}
    with open(os.path.join(OUT_DIR, "listing-%s.txt" % name), "w") as h:
        h.write("== FALSE POSITIVES (%d) ==\n" % len(fps))
        for k, x in enumerate(fps):
            h.write("FP%03d [%s] %s/%s  ed=%s other=%s\n    …%s⟦%s⟧%s…\n" % (k, x["band"], x["v"], x["d"], x["editor_overlap"], ",".join(x["in_other_arms"]), x["left"], x["n"], x["right"]))
        h.write("\n== MISSES (%d) ==\n" % len(misses))
        for k, x in enumerate(misses):
            h.write("MS%03d [%s] %s/%s  editor=%s predov=%s other=%s\n    …%s⟦%s⟧%s…\n" % (k, x["band"], x["v"], x["d"], x["editor_covers"], x["pred_overlapped"], ",".join(x["found_by_other_arms"]), x["left"], x["n"], x["right"]))

json.dump(result, open(os.path.join(OUT_DIR, "errors-raw.json"), "w"), indent=1, ensure_ascii=False)
