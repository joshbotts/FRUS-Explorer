#!/usr/bin/env python3
"""Independent re-derivation of measure-grains figures. Own reader, own max-matching (Hopcroft–Karp style BFS/DFS,
different traversal from the scorer's Kuhn), own key rule, own bootstrap RNG (seed 9001, not the author's 234).
Read-only. Stdlib only."""
import os, sys, json, gzip, re, random, collections
V = os.path.dirname(os.path.abspath(__file__))
STUDIO = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio"
GOLD = STUDIO + "/frus-m2a/m2a-ground-truth.jsonl"
GOLD_DOCS = STUDIO + "/frus-m2a/m2a-ground-truth-documents.jsonl"
TEXT = "/Users/jbotts/frus-semantic-raw/text"
STORES = {
    "editor": ("/Users/jbotts/frus-ner-raw", "marked"),
    "raw_sweep": (STUDIO + "/frus-ner-raw", "detected"),
    "boundary_sweep": ("/Users/jbotts/frus-ner-raw-filtered-boundary", "detected"),
    "filtered_sweep": ("/Users/jbotts/frus-ner-raw-filtered", "detected"),
    "raw_control": ("/Users/jbotts/frus-ner-raw-control", "detected"),
    "filtered_control": ("/Users/jbotts/frus-ner-raw-control-filtered", "detected"),
}

def jsonl(path):
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt", encoding="utf-8") as h:
        return [json.loads(l) for l in h if l.strip()]

def layer_file(store, layer, vol):
    cands = [os.path.join(store, layer, vol + s) for s in (".jsonl", ".jsonl.gz")]
    present = [c for c in cands if os.path.exists(c)]
    assert len(present) == 1, (store, layer, vol, present)
    return present[0]

# ---- gold
gold = collections.defaultdict(list); bands = {}
for r in jsonl(GOLD):
    gold[(r["v"], r["d"])].append((r["s"], r["e"], r["n"])); bands[(r["v"], r["d"])] = r["band"]
listed = jsonl(GOLD_DOCS)
for r in listed:
    k = (r["v"], r["d"]); assert r["mentions"] == len(gold.get(k, [])), k
    gold.setdefault(k, []); bands[k] = r["band"]
gold = {k: sorted(v) for k, v in gold.items()}
docs = sorted(gold)
n_docs, n_ment = len(docs), sum(len(v) for v in gold.values())
print("gold docs", n_docs, "mentions", n_ment, "naming no one", sum(1 for v in gold.values() if not v),
      "bands", dict(collections.Counter(bands[k] for k in docs)))
# verify gold spans slice
texts = {}
for vol in sorted({v for v, _ in docs}):
    texts[vol] = {r["d"]: r["t"] for r in jsonl(layer_file(TEXT, "", vol) if False else
                  [p for p in (os.path.join(TEXT, vol + ".jsonl"), os.path.join(TEXT, vol + ".jsonl.gz")) if os.path.exists(p)][0])}
for (v, d), spans in gold.items():
    for s, e, n in spans: assert texts[v][d][s:e] == n, (v, d, s, e, n)
print("gold spans slice back: OK")

# ---- predictions
def load_arm(store, layer):
    out = {}
    for vol in sorted({v for v, _ in docs}):
        if layer == "detected":
            head = json.load(open(os.path.join(store, layer, vol + ".head.json")))
            assert head.get("sampled") is False, (store, vol, head.get("sampled"))
        rows = jsonl(layer_file(store, layer, vol))
        by = collections.defaultdict(set)
        for r in rows: by[r["d"]].add((r["s"], r["e"], r["n"]))   # same dedup rule as ner_store.spans_by_document
        for (v, d) in docs:
            if v != vol: continue
            spans = sorted(by.get(d, set()))
            for s, e, n in spans: assert texts[v][d][s:e] == n, (store, v, d, s, e, n)
            out[(v, d)] = spans
    return out
arms = {name: load_arm(*sl) for name, sl in STORES.items()}
print("arms loaded; span totals", {a: sum(len(v) for v in p.values()) for a, p in arms.items()})

# ---- own matching: Hopcroft-Karp on the overlap graph (max cardinality is algorithm-independent)
def ov(a, b): return min(a[1], b[1]) - max(a[0], b[0]) > 0
def max_match(gold_spans, preds):
    adj = [[j for j, p in enumerate(preds) if ov(g, p)] for g in gold_spans]
    # Hopcroft-Karp
    INF = float("inf"); NIL = -1
    pair_u = [NIL] * len(gold_spans); pair_v = [NIL] * len(preds); dist = [0] * len(gold_spans)
    def bfs():
        q = collections.deque(); found = False
        for u in range(len(gold_spans)):
            if pair_u[u] == NIL: dist[u] = 0; q.append(u)
            else: dist[u] = INF
        while q:
            u = q.popleft()
            for v in adj[u]:
                w = pair_v[v]
                if w == NIL: found = True
                elif dist[w] == INF: dist[w] = dist[u] + 1; q.append(w)
        return found
    def dfs(u):
        for v in adj[u]:
            w = pair_v[v]
            if w == NIL or (dist[w] == dist[u] + 1 and dfs(w)):
                pair_u[u] = v; pair_v[v] = u; return True
        dist[u] = INF; return False
    while bfs():
        for u in range(len(gold_spans)):
            if pair_u[u] == NIL: dfs(u)
    used_g = {u for u in range(len(gold_spans)) if pair_u[u] != NIL}
    used_p = {v for v in range(len(preds)) if pair_v[v] != NIL}
    return len(used_g), used_p, used_g
def strict_hits(gold_spans, preds):
    return len({(s, e) for s, e, _ in preds} & {(s, e) for s, e, _ in gold_spans})

def mention_counts(preds):
    out = {}
    for k in docs:
        rel, _, _ = max_match(gold[k], preds[k])
        out[k] = (strict_hits(gold[k], preds[k]), rel, len(preds[k]), len(gold[k]))
    return out
def prf(h, p, g):
    P = h / p if p else 0.0; R = h / g if g else 0.0
    return P, R, (2 * P * R / (P + R) if P + R else 0.0)
def summ(counts, keys):
    s = r = p = g = 0
    for k in keys: a, b, c, d = counts[k]; s += a; r += b; p += c; g += d
    return prf(s, p, g), prf(r, p, g)

# ---- set arithmetic
def union(*xs):
    o = collections.defaultdict(set)
    for x in xs:
        for k, v in x.items(): o[k] |= set(v)
    return {k: sorted(v) for k, v in o.items()}
def inter(keep, against):
    return {k: [s for s in keep[k] if any(ov(s, t) for t in against[k])] for k in keep}

E, FC, FS = arms["editor"], arms["filtered_control"], arms["filtered_sweep"]
arms["intersection_control_side"] = inter(FC, FS)
arms["intersection_sweep_side"] = inter(FS, FC)
arms["editor+filtered_control"] = union(E, FC)
arms["editor+filtered_sweep"] = union(E, FS)
arms["editor+intersection_control_side"] = union(E, arms["intersection_control_side"])
arms["editor+intersection_sweep_side"] = union(E, arms["intersection_sweep_side"])
arms["editor+filtered_control+filtered_sweep"] = union(E, FC, FS)
arms["raw_control_intersect_raw_sweep"] = inter(arms["raw_control"], arms["raw_sweep"])

band_names = sorted(set(bands.values()))
by_band = {b: [k for k in docs if bands[k] == b] for b in band_names}
mc = {a: mention_counts(p) for a, p in arms.items()}
print("\n== MENTION GRAIN (own matcher) ==")
for a in arms:
    (sp, sr, sf), (rp, rr, rf) = summ(mc[a], docs)
    print("%-42s spans %4d strict P %.3f R %.3f F1 %.3f | relaxed P %.3f R %.3f F1 %.3f" % (
        a, sum(len(v) for v in arms[a].values()), sp, sr, sf, rp, rr, rf))
    if a in ("intersection_control_side", "intersection_sweep_side", "editor+intersection_control_side",
             "editor+filtered_control", "editor+filtered_control+filtered_sweep"):
        for b in band_names:
            (sp, sr, sf), (rp, rr, rf) = summ(mc[a], by_band[b])
            print("      %-10s n=%d gold=%d relaxed P %.3f R %.3f F1 %.3f" % (b, len(by_band[b]), sum(len(gold[k]) for k in by_band[b]), rp, rr, rf))

# ---- presence grain (own key rule written from the report's description)
HON = set("mr mrs ms miss messrs dr hon sir lord lady general gen colonel col captain capt major maj lieutenant lieut lt admiral adm commodore commander cmdr president secretary senator ambassador minister consul judge governor gov count countess baron baroness earl duke prince princess king queen señor senor don monsieur m madame mme herr rev reverend professor prof the acting vice privy his her excellency chairman marshal premier chancellor bishop archbishop cardinal father brother sister".split())
assert len(HON) == 74, len(HON)
def key(n):
    s = " ".join(n.casefold().split())
    s = re.sub(r"(?:['’]s|['’])$", "", s).strip()
    t = s.split(); i = 0
    while i < len(t) and t[i].rstrip(".") in HON: i += 1
    k = " ".join(t[i:]); return k or s
def presence_counts(preds):
    out = {}; false_k = collections.Counter(); miss_k = collections.Counter(); true_k = collections.Counter()
    for k in docs:
        _, used_p, used_g = max_match(gold[k], preds[k])
        gk = collections.defaultdict(bool); pk = collections.defaultdict(bool)
        for i, (_, _, n) in enumerate(gold[k]): gk[key(n)] |= i in used_g
        for i, (_, _, n) in enumerate(preds[k]): pk[key(n)] |= i in used_p
        out[k] = (sum(pk.values()), len(pk), sum(gk.values()), len(gk))
        for kk, v in pk.items(): (true_k if v else false_k)[kk] += 1
        for kk, v in gk.items():
            if not v: miss_k[kk] += 1
    return out, false_k, miss_k, true_k
def psumm(counts, keys):
    a = [0, 0, 0, 0]
    for k in keys:
        for i in range(4): a[i] += counts[k][i]
    P = a[0] / a[1] if a[1] else 0.0; R = a[2] / a[3] if a[3] else 0.0
    return P, R, (2 * P * R / (P + R) if P + R else 0.0), a
pc = {}; pf = {}; pm = {}; pt = {}
print("\n== PRESENCE GRAIN (own matcher, own key) ==")
for a in arms:
    pc[a], pf[a], pm[a], pt[a] = presence_counts(arms[a])
    P, R, F, tot = psumm(pc[a], docs)
    print("%-42s P %.3f R %.3f F1 %.3f | pred keys %d true %d false %d | gold keys %d found %d | false distinct %d occ %d | missed distinct %d occ %d" % (
        a, P, R, F, tot[1], tot[0], tot[1] - tot[0], tot[3], tot[2], len(pf[a]), sum(pf[a].values()), len(pm[a]), sum(pm[a].values())))
print("\n== PRESENCE by band ==")
for a in ("editor", "filtered_control", "filtered_sweep", "intersection_control_side", "editor+filtered_control",
          "editor+intersection_control_side", "editor+intersection_sweep_side", "editor+filtered_sweep"):
    row = []
    for b in band_names:
        P, R, F, tot = psumm(pc[a], by_band[b]); row.append("%s n=%d gk=%d %.3f/%.3f/%.3f" % (b, len(by_band[b]), tot[3], P, R, F))
    print("%-36s %s" % (a, " ; ".join(row)))
print("\n== FALSE KEY LISTS ==")
for a in ("intersection_control_side", "intersection_sweep_side", "filtered_control", "editor+filtered_control",
          "editor+intersection_control_side", "editor+intersection_sweep_side"):
    print(a, len(pf[a]), sorted("%s%s" % (k, "(x%d)" % c if c > 1 else "") for k, c in pf[a].items()))
print("\n== MISSED KEY HEADS ==")
for a in ("intersection_sweep_side", "editor"):
    print(a, pm[a].most_common(12))
print("three-way missed:", sorted(pm["editor+filtered_control+filtered_sweep"].items()))

# ---- bootstrap, own RNG, band-stratified, shared draws
rng = random.Random(9001); NB = 10000
draws = [[k for b in band_names for k in (by_band[b][rng.randrange(len(by_band[b]))] for _ in by_band[b])] for _ in range(NB)]
def ci(v): v = sorted(v); return (round(v[int(0.025 * (NB - 1))], 3), round(v[int(0.975 * (NB - 1))], 3))
def stat_m(a, keys):
    (sp, sr, sf), (rp, rr, rf) = summ(mc[a], keys); return {"rP": rp, "rR": rr, "rF": rf, "sF": sf, "sP": sp}
def stat_p(a, keys):
    P, R, F, _ = psumm(pc[a], keys); return {"P": P, "R": R, "F": F}
print("\n== BOOTSTRAP CIs (own RNG seed 9001) ==")
for a in ("intersection_control_side", "intersection_sweep_side", "editor+intersection_control_side",
          "editor+intersection_sweep_side", "editor+filtered_control", "editor+filtered_control+filtered_sweep",
          "filtered_control", "filtered_sweep", "editor"):
    m = collections.defaultdict(list); p = collections.defaultdict(list)
    for d in draws:
        for k, v in stat_m(a, d).items(): m[k].append(v)
        for k, v in stat_p(a, d).items(): p[k].append(v)
    print("%-42s mention rP %s rR %s rF %s sF %s | presence P %s R %s F %s" % (
        a, ci(m["rP"]), ci(m["rR"]), ci(m["rF"]), ci(m["sF"]), ci(p["P"]), ci(p["R"]), ci(p["F"])))
print("\n== PAIRED DIFFERENCES (own RNG) ==")
for a, b in (("editor+intersection_sweep_side", "editor+filtered_control"), ("editor+intersection_control_side", "editor+filtered_control"),
             ("editor+filtered_control", "editor+filtered_sweep"), ("editor+filtered_control", "editor"),
             ("editor+intersection_sweep_side", "editor"), ("intersection_control_side", "filtered_control"),
             ("intersection_sweep_side", "filtered_sweep"), ("filtered_control", "filtered_sweep"),
             ("editor+filtered_control+filtered_sweep", "editor+filtered_control")):
    dm = collections.defaultdict(list); dp = collections.defaultdict(list)
    for d in draws:
        sa, sb = stat_m(a, d), stat_m(b, d)
        for k in sa: dm[k].append(sa[k] - sb[k])
        pa, pb = stat_p(a, d), stat_p(b, d)
        for k in pa: dp[k].append(pa[k] - pb[k])
    pt_m = {k: stat_m(a, docs)[k] - stat_m(b, docs)[k] for k in ("rF", "sF", "rP", "rR")}
    pt_p = {k: stat_p(a, docs)[k] - stat_p(b, docs)[k] for k in ("F", "P", "R")}
    print("%-38s - %-38s | mention rF %+.3f %s sF %+.3f %s rP %+.3f %s | presence F %+.3f %s P %+.3f %s R %+.3f %s" % (
        a, b, pt_m["rF"], ci(dm["rF"]), pt_m["sF"], ci(dm["sF"]), pt_m["rP"], ci(dm["rP"]),
        pt_p["F"], ci(dp["F"]), pt_p["P"], ci(dp["P"]), pt_p["R"], ci(dp["R"])))
# key spot-check
print("\nkey spot-check", {s: key(s) for s in ["Mr. Mariscal’s", "General Stoessel", "Sir Edward Grey", "Earl Russell", "Señor Romero's", "Vyshinsky’s", "Rt. Hon. Lord Lyons", "the Secretary"]})
