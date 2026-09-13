#!/usr/bin/env python3
"""Independent re-derivation of the measure-errors report's load-bearing figures.

Own reader (gzip/plain jsonl), own maximum bipartite matching (Hopcroft-Karp-style BFS/DFS from the
PREDICTION side, the opposite orientation from score_detections.match), own union scoring.
Does NOT import score_detections or the author's extract script.
"""
import json, gzip, os, collections, sys
M2A = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
GT = os.path.join(M2A, "m2a-ground-truth.jsonl")
GTD = os.path.join(M2A, "m2a-ground-truth-documents.jsonl")
TEXT = os.path.expanduser("~/frus-semantic-raw/text")
MARKED = os.path.expanduser("~/frus-ner-raw")
ARMS = collections.OrderedDict([
    ("filtered_control", os.path.expanduser("~/frus-ner-raw-control-filtered")),
    ("filtered_sweep", os.path.expanduser("~/frus-ner-raw-filtered")),
    ("raw_sweep", "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"),
    ("raw_control", os.path.expanduser("~/frus-ner-raw-control")),
    ("boundary_sweep", os.path.expanduser("~/frus-ner-raw-filtered-boundary")),
])
OUT = os.path.dirname(os.path.abspath(__file__))

def jsonl(path):
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt", encoding="utf-8") as h:
        return [json.loads(l) for l in h if l.strip()]

def layer_file(store, layer, vol):
    c = [os.path.join(store, layer, vol + s) for s in (".jsonl", ".jsonl.gz")]
    c = [p for p in c if os.path.exists(p)]
    assert len(c) == 1, (store, layer, vol, c)
    return c[0]

# ---- gold
gold = {}; bands = {}
for r in jsonl(GT):
    gold.setdefault((r["v"], r["d"]), []).append((r["s"], r["e"], r["n"])); bands[(r["v"], r["d"])] = r["band"]
listed = jsonl(GTD)
for r in listed:
    k = (r["v"], r["d"]); gold.setdefault(k, []); bands[k] = r["band"]
    assert r["mentions"] == len(gold[k])
gold = {k: sorted(v) for k, v in gold.items()}
N_DOCS = len(gold); N_MENT = sum(len(v) for v in gold.values())
print("gold docs", N_DOCS, "mentions", N_MENT, "docs naming no one", sum(1 for v in gold.values() if not v))
vols = sorted({k[0] for k in gold})

# ---- text layer, span verification
texts = {}
for v in vols:
    texts[v] = {r["d"]: r["t"] for r in jsonl(layer_file(TEXT, "", v) if False else [p for p in (os.path.join(TEXT, v + ".jsonl"), os.path.join(TEXT, v + ".jsonl.gz")) if os.path.exists(p)][0])}
for (v, d), spans in gold.items():
    for s, e, n in spans:
        assert texts[v][d][s:e] == n, ("gold span mismatch", v, d, s, e, n)

def load_layer(store, layer):
    out = {}; raw_rows = 0
    for v in vols:
        head = json.load(open(os.path.join(store, layer, v + ".head.json"))) if layer == "detected" else None
        if layer == "detected":
            assert "sampled" in head and not head["sampled"], (store, v, head.get("sampled"))
        rows = jsonl(layer_file(store, layer, v))
        by = {}
        for r in rows:
            by.setdefault(r["d"], set()).add((r["s"], r["e"], r["n"]))
        for (vv, d) in gold:
            if vv != v: continue
            sp = sorted(by.get(d, set()))
            for s, e, n in sp:
                assert texts[v][d][s:e] == n, (store, v, d, s, e, n)
            out[(v, d)] = sp
            raw_rows += sum(1 for r in rows if r["d"] == d)
    return out, raw_rows

editor, _ = load_layer(MARKED, "marked")
preds = {}
for a, p in ARMS.items():
    preds[a], rr = load_layer(p, "detected")
    print("loaded", a, "distinct spans", sum(len(v) for v in preds[a].values()), "raw rows in gold docs", rr)

def ov(a, b):
    return min(a[1], b[1]) - max(a[0], b[0]) > 0

def max_matching(gold_spans, pred_spans):
    """Maximum-cardinality matching, augmenting from the PREDICTION side (opposite of the scorer).
    Returns (matched_pred_idx -> gold_idx)."""
    adj = {i: [j for j, g in enumerate(gold_spans) if ov(p, g)] for i, p in enumerate(pred_spans)}
    match_g = {}  # gold idx -> pred idx
    def try_p(i, seen):
        for j in adj[i]:
            if j in seen: continue
            seen.add(j)
            if j not in match_g or try_p(match_g[j], seen):
                match_g[j] = i; return True
        return False
    for i in range(len(pred_spans)):
        try_p(i, set())
    return {i: j for j, i in match_g.items()}

def score(pred_by_doc, label):
    hits = strict = npred = ngold = 0
    fps, misses = [], []
    band_t = collections.defaultdict(lambda: [0, 0, 0, 0])
    for k in sorted(gold):
        g, p = gold[k], pred_by_doc[k]
        m = max_matching(g, p)
        hits += len(m); npred += len(p); ngold += len(g)
        strict += len({(s, e) for s, e, _ in p} & {(s, e) for s, e, _ in g})
        bt = band_t[bands[k]]; bt[0] += len(m); bt[1] += len(p); bt[2] += len(g)
        used_g = set(m.values())
        for i, sp in enumerate(p):
            if i not in m: fps.append((k, sp))
        for j, sp in enumerate(g):
            if j not in used_g: misses.append((k, sp))
    P = hits / npred; R = hits / ngold; F = 2 * P * R / (P + R)
    print("%-28s relaxed hits %d pred %d gold %d P %.4f R %.4f F1 %.4f | strict hits %d P %.4f R %.4f F1 %.4f | FP %d miss %d"
          % (label, hits, npred, ngold, P, R, F, strict, strict / npred, strict / ngold,
             2 * (strict / npred) * (strict / ngold) / ((strict / npred) + (strict / ngold)), len(fps), len(misses)))
    return {"hits": hits, "pred": npred, "gold": ngold, "P": P, "R": R, "F1": F, "strict": strict, "fps": fps, "misses": misses,
            "by_band": {b: t for b, t in band_t.items()}}

res = {}
res["editor"] = score(editor, "editor markup")
for a in ARMS:
    res[a] = score(preds[a], a)

# ---- unions (post-hoc): editor + arm, spans deduped on (s,e,n)
for a in ("filtered_control", "filtered_sweep"):
    u = {k: sorted(set(editor[k]) | set(preds[a][k])) for k in gold}
    res["union_editor+" + a] = score(u, "UNION editor+" + a)

# ---- compare FP / miss identity with the author's errors-raw.json
author = json.load(open("/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-errors/errors-raw.json"))
def keyset(items): return {(k[0], k[1], sp[0], sp[1]) for k, sp in items}
for a in ARMS:
    if a not in author["arms"]: continue
    A_fp = {(x["v"], x["d"], x["s"], x["e"]) for x in author["arms"][a]["false_positives"]}
    A_ms = {(x["v"], x["d"], x["s"], x["e"]) for x in author["arms"][a]["misses"]}
    print("identity vs author", a, "FP same", A_fp == keyset(res[a]["fps"]), "|sym diff|", len(A_fp ^ keyset(res[a]["fps"])),
          "miss same", A_ms == keyset(res[a]["misses"]), "|sym diff|", len(A_ms ^ keyset(res[a]["misses"])))

# ---- ME-6/7/8 cross-arm facts, computed from my own FP/miss lists
def found_by(arm, missed):
    k, sp = missed
    return any(ov(sp, q) for q in preds[arm][k])
def editor_covers(missed):
    k, sp = missed
    return any(ov(sp, q) for q in editor[k])
fc_miss = res["filtered_control"]["misses"]; fs_miss = res["filtered_sweep"]["misses"]; rs_miss = res["raw_sweep"]["misses"]
print("control misses", len(fc_miss), "found by filtered sweep", sum(found_by("filtered_sweep", m) for m in fc_miss),
      "editor covers", sum(editor_covers(m) for m in fc_miss),
      "editor covers by band", dict(collections.Counter(bands[m[0]] for m in fc_miss if editor_covers(m))),
      "misses by band", dict(collections.Counter(bands[m[0]] for m in fc_miss)))
print("sweep misses", len(fs_miss), "found by filtered control", sum(found_by("filtered_control", m) for m in fs_miss),
      "editor covers", sum(editor_covers(m) for m in fs_miss), "by band", dict(collections.Counter(bands[m[0]] for m in fs_miss)))
print("sweep misses covered by editor:", [(m[0], m[1][2]) for m in fs_miss if editor_covers(m)])
neither = [m for m in fc_miss if not editor_covers(m) and not found_by("filtered_sweep", m)]
print("gold found by neither editor nor either filtered arm:", len(neither), [(m[0][0], m[0][1], m[1][2]) for m in neither])
print("raw sweep misses", len(rs_miss), "shared with filtered sweep misses", len(keyset(rs_miss) & keyset(fs_miss)),
      "filtered-only misses:", [(m[0], m[1][2], "found by raw:", found_by("raw_sweep", m)) for m in fs_miss if (m[0][0], m[0][1], m[1][0], m[1][1]) not in keyset(rs_miss)])
gw = [(k, sp, [a for a in ARMS if found_by(a, (k, sp))], editor_covers((k, sp))) for k in gold for sp in gold[k] if "Washington" in sp[2]]
print("gold spans containing 'Washington':", gw)
# implied union recall from the author's arithmetic
print("author arithmetic (406-91)/406 =", (406 - 91) / 406, "; my union recall hits", res["union_editor+filtered_control"]["hits"])

# ---- ME-9: raw sweep FPs absent from the filtered store; survivors == filtered FPs?
fs_all = {(k[0], k[1], s, e, n) for k in gold for s, e, n in preds["filtered_sweep"][k]}
rs_fp = res["raw_sweep"]["fps"]
removed = [(k, sp) for k, sp in rs_fp if (k[0], k[1], sp[0], sp[1], sp[2]) not in fs_all]
survive = keyset([(k, sp) for k, sp in rs_fp if (k[0], k[1], sp[0], sp[1], sp[2]) in fs_all])
print("raw sweep FP", len(rs_fp), "removed by filter (absent from filtered store)", len(removed), "survivors", len(survive),
      "survivors == filtered sweep FP set", survive == keyset(res["filtered_sweep"]["fps"]))
surf = collections.Counter(" ".join(sp[2].casefold().replace("’", "'").split()).strip(",;: ") for k, sp in rs_fp)
surf2 = collections.Counter()
for s, c in surf.items():
    surf2[s[4:] if s.startswith("the ") else s] += c
print("raw sweep FP top surfaces (phrase-folded):", surf2.most_common(30))
wash = [(k, sp, (k[0], k[1], sp[0], sp[1], sp[2]) in fs_all) for k, sp in rs_fp if sp[2].casefold() == "washington"]
print("raw FP 'washington' count", len(wash), "any survive filter?", any(w[2] for w in wash))
# raw sweep spans removed by filter that were HITS (the recall cost of the filter)
rs_hit_removed = []
for k in gold:
    for s, e, n in preds["raw_sweep"][k]:
        if (k[0], k[1], s, e, n) not in fs_all and any(ov((s, e), g) for g in gold[k]):
            rs_hit_removed.append((k, n))
print("raw-sweep spans overlapping gold that the filter removed:", rs_hit_removed)
# total raw removed in gold docs
print("raw sweep distinct spans in gold docs", sum(len(v) for v in preds["raw_sweep"].values()), "filtered", sum(len(v) for v in preds["filtered_sweep"].values()))

json.dump({a: {k: v for k, v in r.items() if k not in ("fps", "misses")} for a, r in res.items()}, open(os.path.join(OUT, "verify-totals.json"), "w"), indent=1)
json.dump({a: {"fps": [(k[0], k[1], sp[0], sp[1], sp[2]) for k, sp in r["fps"]], "misses": [(k[0], k[1], sp[0], sp[1], sp[2]) for k, sp in r["misses"]]} for a, r in res.items()}, open(os.path.join(OUT, "verify-lists.json"), "w"), indent=1, ensure_ascii=False)
