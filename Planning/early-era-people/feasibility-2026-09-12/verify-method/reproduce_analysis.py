# Independent reproduction (different RNG seed, own code) of the §7.2 intervals, stopping-rule
# frequency, 8-document simulation, unions, and two measurements the record does not make:
# a segment-1 vs segment-2 split of the 1861-1899 band and a (document, surface)-grain presence score.
import os, sys, json, random, collections, re
SP = os.path.dirname(os.path.abspath(__file__))
D = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
GT = D + "/m2a-ground-truth.jsonl"
os.environ.update(GROUND_TRUTH=GT, DETECTORS="unused", OUT=SP + "/unused.json",
                  TEXT_DIR="/Users/jbotts/frus-semantic-raw/text", STORE="/Users/jbotts/frus-ner-raw")
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import score_detections as sd
ARMS = [("editor", "/Users/jbotts/frus-ner-raw", "marked"),
        ("llm", "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw", "detected"),
        ("llm-boundary", "/Users/jbotts/frus-ner-raw-filtered-boundary", "detected"),
        ("llm-filtered", "/Users/jbotts/frus-ner-raw-filtered", "detected"),
        ("control", "/Users/jbotts/frus-ner-raw-control", "detected"),
        ("control-filtered", "/Users/jbotts/frus-ner-raw-control-filtered", "detected")]
gold, bands = sd.load_ground_truth(GT)
NAMES = [a for a, _, _ in ARMS]
preds = {}
for name, path, layer in ARMS:
    p, refused = sd.collect_predictions(path, layer, gold, True)
    assert not refused, (name, refused); preds[name] = p
DOCS = sorted(gold)
texts = {v: sd.cached_volume_text(v) for v, _ in DOCS}
per = {a: {k: sd.match(gold[k], preds[a].get(k, []))[:2] + (len(preds[a].get(k, [])), len(gold[k])) for k in DOCS} for a in NAMES}
def f1(rows, mode):
    h = sum(r[0 if mode == "strict" else 1] for r in rows); p = sum(r[2] for r in rows); g = sum(r[3] for r in rows)
    P = h / p if p else 0; R = h / g if g else 0
    return (2 * P * R / (P + R) if P + R else 0), P, R
out = {}
BANDS = sorted(set(bands.values())); by_band = {b: [k for k in DOCS if bands[k] == b] for b in BANDS}
out["totals"] = {a: {m: round(f1([per[a][k] for k in DOCS], m)[0], 4) for m in ("strict", "relaxed")} for a in NAMES}
def rule(dbb):
    alld = [k for ks in dbb.values() for k in ks]
    gap = 100 * (f1([per["control"][k] for k in alld], "strict")[0] - f1([per["llm"][k] for k in alld], "strict")[0])
    w = set()
    for b, ks in dbb.items():
        c, l = f1([per["control"][k] for k in ks], "strict")[0], f1([per["llm"][k] for k in ks], "strict")[0]
        w.add("control" if c > l else "llm" if l > c else "tie")
    return gap, w, abs(gap) >= 10 and len(w) == 1 and "tie" not in w
gap, w, met = rule(by_band); out["rule_observed"] = {"gap": round(gap, 2), "winners": sorted(w), "met": met}
rng = random.Random(20260912); B = 10000
pairs = [("control", "llm"), ("control", "llm-filtered"), ("control-filtered", "llm-filtered"), ("llm-filtered", "llm"), ("control-filtered", "control")]
samp = collections.defaultdict(list); rule_met = 0
for _ in range(B):
    draw = {b: [ks[rng.randrange(len(ks))] for _ in ks] for b, ks in by_band.items()}; alld = [k for ks in draw.values() for k in ks]
    for a, b in pairs:
        for m in ("strict", "relaxed"):
            samp[(a, b, m)].append(100 * (f1([per[a][k] for k in alld], m)[0] - f1([per[b][k] for k in alld], m)[0]))
    rule_met += rule(draw)[2]
out["bootstrap_stratified"] = {}
for a, b in pairs:
    for m in ("strict", "relaxed"):
        xs = sorted(samp[(a, b, m)]); obs = 100 * (f1([per[a][k] for k in DOCS], m)[0] - f1([per[b][k] for k in DOCS], m)[0])
        out["bootstrap_stratified"]["%s-%s %s" % (a, b, m)] = {"obs": round(obs, 1), "ci95": [round(xs[int(.025 * B)], 1), round(xs[int(.975 * B)], 1)]}
out["rule_met_pct_stratified"] = 100 * rule_met / B
# unstratified document bootstrap, for comparison
samp2 = collections.defaultdict(list)
for _ in range(B):
    alld = [DOCS[rng.randrange(len(DOCS))] for _ in DOCS]
    for a, b in (("control", "llm-filtered"), ("control", "llm")):
        for m in ("strict", "relaxed"):
            samp2[(a, b, m)].append(100 * (f1([per[a][k] for k in alld], m)[0] - f1([per[b][k] for k in alld], m)[0]))
out["bootstrap_unstratified"] = {"%s-%s %s" % (a, b, m): [round(sorted(v)[int(.025 * B)], 1), round(sorted(v)[int(.975 * B)], 1)] for (a, b, m), v in samp2.items()}
# the 8 unkeyed, simulated from their own bands
missing = {"1900-1929": 2, "1930-1945": 3, "1946-": 3, "1861-1899": 0}; gaps = []; mets = 0
for _ in range(B):
    extra = {b: by_band[b] + [by_band[b][rng.randrange(len(by_band[b]))] for _ in range(missing[b])] for b in BANDS}
    g, _, m = rule(extra); gaps.append(g); mets += m
gaps.sort()
out["sim8"] = {"met": mets, "gap_min_max": [round(gaps[0], 1), round(gaps[-1], 1)], "gap_95": [round(gaps[int(.025 * B)], 1), round(gaps[int(.975 * B)], 1)]}
# unions: (a) as the harness did (set union of tuples); (b) dedupe overlapping detector spans against editor spans
out["unions"] = {}
for arm in NAMES[1:]:
    rows_a, rows_b = [], []
    for k in DOCS:
        ed = preds["editor"].get(k, []); det = preds[arm].get(k, [])
        merged = sorted({tuple(x) for x in ed + det}); st, rl, _, _ = sd.match(gold[k], merged); rows_a.append((st, rl, len(merged), len(gold[k])))
        keep = list(ed) + [d for d in det if not any(min(d[1], e[1]) - max(d[0], e[0]) > 0 for e in ed)]
        st, rl, _, _ = sd.match(gold[k], keep); rows_b.append((st, rl, len(keep), len(gold[k])))
    out["unions"][arm] = {"tuple_union relaxed F1/P/R": [round(x, 3) for x in f1(rows_a, "relaxed")], "tuple_union strict": round(f1(rows_a, "strict")[0], 3),
                          "overlap_deduped relaxed F1/P/R": [round(x, 3) for x in f1(rows_b, "relaxed")]}
# segment-1 vs segment-2 within the 1861-1899 band
seg1 = {"frus1864p2", "frus1865p1", "frus1866p3", "frus1872p2v5"}
out["band1_split"] = {}
for label, ks in (("seg1", [k for k in by_band["1861-1899"] if k[0] in seg1]), ("seg2", [k for k in by_band["1861-1899"] if k[0] not in seg1])):
    out["band1_split"][label] = {"docs": len(ks), "mentions": sum(len(gold[k]) for k in ks),
        **{a: {m: round(f1([per[a][k] for k in ks], m)[0], 3) for m in ("strict", "relaxed")} for a in ("llm", "llm-filtered", "control", "control-filtered")}}
# (document, surface)-grain presence: a gold surface (lower-cased, leading title tokens and possessive stripped) in a document counts once
TITLE = set("mr mrs ms miss messrs dr general gen admiral president señor senor sir lord earl hon generalissimo secretary ambassador minister senator governor m mme monsieur herr prince marshal colonel col captain capt commander consul judge chief justice premier major mayor citizen chargé right acting rear-admiral".split())
def norm(s):
    toks = s.replace("’", "'").split(); i = 0
    while i < len(toks) - 1 and toks[i].rstrip(".,").lower() in TITLE: i += 1
    t = " ".join(toks[i:]).lower()
    t = re.sub(r"'s?$", "", t).rstrip(".,;:")
    return t
out["doc_surface_grain"] = {}
for arm in NAMES:
    hit = pred_n = gold_n = 0
    for k in DOCS:
        gs = gold[k]; ps = preds[arm].get(k, [])
        st, rl, used_p, used_g = sd.match(gs, ps)
        gsurf = collections.defaultdict(list)
        for i, (s, e, n) in enumerate(gs): gsurf[norm(n)].append(i)
        psurf = collections.defaultdict(list)
        for i, (s, e, n) in enumerate(ps): psurf[norm(n)].append(i)
        gold_n += len(gsurf); pred_n += len(psurf)
        hit += sum(1 for surf, idx in gsurf.items() if any(i in used_g for i in idx))
        # a predicted surface is a hit if any of its spans matched a gold span
        hitp = sum(1 for surf, idx in psurf.items() if any(i in used_p for i in idx))
        out["doc_surface_grain"].setdefault(arm, {"hitP": 0})["hitP"] += hitp
    P = out["doc_surface_grain"][arm]["hitP"] / pred_n; R = hit / gold_n
    out["doc_surface_grain"][arm].update({"P": round(P, 3), "R": round(R, 3), "F1": round(2 * P * R / (P + R), 3), "gold_surfaces": gold_n, "pred_surfaces": pred_n})
# per-document: how many documents does each arm cover completely at relaxed grain / with zero FPs
out["doc_level"] = {}
for arm in NAMES:
    full = sum(1 for k in DOCS if per[arm][k][1] == per[arm][k][3]); clean = sum(1 for k in DOCS if per[arm][k][1] == per[arm][k][2])
    out["doc_level"][arm] = {"docs_all_gold_found_relaxed": full, "docs_no_false_positive_relaxed": clean, "docs": len(DOCS)}
# duplicate (s,e) predictions with differing surfaces in gold docs
out["dup_offsets"] = {a: sum(len(preds[a].get(k, [])) - len({(s, e) for s, e, _ in preds[a].get(k, [])}) for k in DOCS) for a in NAMES}
json.dump(out, open(SP + "/reproduce_analysis.json", "w"), indent=1)
print(json.dumps(out, indent=1))
