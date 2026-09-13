#!/usr/bin/env python3
"""Fixability classification of every relaxed FP and miss of filtered_control and filtered_sweep
(errors.json, 2026-09-12). One reader's judgement, applied as explicit rules + named overrides.
Classes: 1 document-resolvable; 2 needs outside knowledge; 3 annotation-convention boundary;
4 candidate-recall failure (no editor / filtered-control / filtered-sweep span overlaps the gold span);
5 other (named)."""
import json, collections, sys
ERR = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-errors/errors.json"
d = json.load(open(ERR))
POOL_ARMS = {"filtered_control", "filtered_sweep"}

# Items needing context beyond the local sentence (still class 1 at document scope) - hand list, by (arm, kind, index)
WIDER = {("filtered_control","false_positives",33): "first 'President Harding': the ship reading is fixed only by 'sailing on the President Harding' later in the document",
         ("filtered_sweep","false_positives",157): "same",
         ("filtered_control","false_positives",34): "'sold by Hunzedal to an Antwerp firm': firm reading fixed by 'the Hunzedal Company' later",
         ("filtered_sweep","false_positives",160): "same",
         ("filtered_control","false_positives",30): "'Commanding General Seville': post reading fixed by dateline/heading 'Consul at Seville' and parallel 'Military Governor Bilbao'",
         ("filtered_sweep","false_positives",153): "same",
         ("filtered_control","false_positives",47): "'Leg Cairo': needs the cable abbreviation Leg = Legation (parallel 'Secdel', 'Dept' in the same text)",
         }
NATURE_OF_CLASS4 = {"King’s": "2 (gold marks a person; in a London telegram 'King's judgment' could be the monarch - not settled by the document)"}

def classify_fp(arm, i, x):
    c = x["category"]
    if c in ("partial-name-boundary", "other:citation-caption-name"):
        return 3, ("nested/duplicate boundary of a gold person" if c == "partial-name-boundary"
                   else "real person's name inside a file-number caption; gold convention excludes citation furniture")
    return 1, "non-person (%s) resolvable from the document under the annotation rule" % c

def classify_miss(arm, i, x):
    c = x["category"]
    pool_hit = x["editor_covers"] or bool(set(x["found_by_other_arms"]) & POOL_ARMS) or bool(x["pred_overlapped"])
    if not pool_hit:
        nat = NATURE_OF_CLASS4.get(x["n"], "1 (a person a careful reader marks from the document)")
        raw = [a for a in x["found_by_other_arms"] if a.startswith("raw")]
        return 4, "no editor/filtered span overlaps; nature %s; raw arms proposing: %s" % (nat, raw or "none")
    if c == "other:list-span-merged":
        return 3, "arm emitted one span for two people; one-to-one matching credits one"
    if c == "other:footnote-doubled-name":
        return 5, "R-0 text layer inlines the footnote name beside the text name; arm's merged span can satisfy only one of the two gold spans"
    return 1, "person the arm did not propose; %s" % ("proposed by " + ",".join(sorted((set(x["found_by_other_arms"]) & POOL_ARMS) | ({"editor"} if x["editor_covers"] else set()))))

out = {"method": __doc__, "arms": {}}
for arm in ("filtered_control", "filtered_sweep"):
    A = d["arms"][arm]
    rows = []
    for kind, fn in (("false_positives", classify_fp), ("misses", classify_miss)):
        for i, x in enumerate(A[kind]):
            cls, why = fn(arm, i, x)
            rows.append({"kind": kind, "i": i, "doc": "%s/%s" % (x["v"], x["d"]), "band": x["band"], "n": x["n"],
                         "left": x["left"], "right": x["right"], "category": x["category"], "class": cls, "why": why,
                         "wider_context": WIDER.get((arm, kind, i))})
    counts = collections.defaultdict(lambda: collections.Counter())
    for r in rows:
        counts[r["kind"]][r["class"]] += 1
        counts[r["kind"] + "|" + r["band"]][r["class"]] += 1
    out["arms"][arm] = {"rows": rows, "counts": {k: dict(sorted(v.items())) for k, v in sorted(counts.items())}}
    print("==", arm)
    for k, v in sorted(counts.items()):
        print("  %-32s %s  total %d" % (k, dict(sorted(v.items())), sum(v.values())))
    print("  wider-context class-1 items:", sum(1 for r in rows if r["wider_context"]))
    for cls in (2, 3, 4, 5):
        ex = [r for r in rows if r["class"] == cls]
        print("  class", cls, "n=%d" % len(ex))
        for r in ex[:40]:
            print("    %s %s [%s] …%s⟦%s⟧%s… — %s" % (r["kind"][:4], r["doc"], r["band"], r["left"][-30:], r["n"], r["right"][:25], r["why"]))
json.dump(out, open("fixability.json", "w"), indent=1, ensure_ascii=False)
