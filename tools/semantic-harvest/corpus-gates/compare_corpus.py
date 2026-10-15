#!/usr/bin/env python3
"""Paired Gate A at corpus scale for two models over the same documents (Track B, step B2).

`gate_a_corpus.py` scores one pooled store; `../spike_compare.py` pairs two stores at spike
scale. This script does the second at the first's scale: the same edges, every document as a
candidate, and the same exact rank semantics for both models, at the width the app has shipped
since #933 (512) and the one before it (256), with the per-query differences and intervals.

Three modes. The first runs once per model, so the two can run in parallel processes:

  MODE=ranks    LABEL, ASSESS (a pool_docs.py folder), DB (the app's frus.db, opened read-only),
                OUT_DIR -> OUT_DIR/ranks-<LABEL>.npz and .json: every configuration's best rank
                for every query. LIMIT=n scores the first n queries only, for a smoke run.
  MODE=sweep    LABEL, ASSESS (after nn_ladder.py has written nn_work/), OUT_DIR
                -> OUT_DIR/sweep-<LABEL>.json: rerank_pool_sweep.py's recall@10 against the
                model's own float-768 neighbours, with the Hamming stage over 512 sign bits as
                the app scans since #933 (rerank_pool_sweep.py scans 256 bits at both widths).
  MODE=compare  BASELINE and CANDIDATE (labels of two ranks runs), OUT_DIR, MANIFEST, optional
                EXCLUDE_DOCS (a JSON list of {"v","d"}; the queries touching them form a
                sensitivity row) -> OUT_DIR/compare.json.

Configurations (the rank of the first relevant document over all candidates, self excluded,
ties by row ascending, as gate_a_corpus.rank_batch):
  float-768, float-512, int8-512, int8-256       every candidate scored
  hamming512-P->int8-512, P in 200/400/800/1600  the app's funnel since #933; 800 ships
  hamming256-800->int8-256                       the funnel the app shipped before #933
A funnel ranks its pool of P by the int8 rerank; a cited document outside the pool ranks after
all P, in row order, as spike_compare.shipping_512_scores does. Hamming distances come from a
float32 product of +1/-1 sign matrices, (width - dot) / 2, which is exact for these widths and
equal to XOR and popcount over pack_bits' rows (zero packs as a set bit, so it maps to +1).

Intervals: a paired bootstrap over queries (spike_compare's method) and, because the queries
of one volume are not independent, a paired bootstrap over citing volumes. 10,000 resamples
each, seed 20261015, drawn in a fixed order. Needs numpy 2.x, like nn_ladder.py.
"""

import json
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gate_a_corpus as ga  # noqa: E402
from nn_ladder import select_topk  # noqa: E402
from pool_docs import truncate  # noqa: E402

SEED = 20261015
BOOT = int(os.environ.get("BOOT", "10000"))
POOLS = [200, 400, 800, 1600]
SHIPPING = "hamming512-800->int8-512"
OUT_DIR = os.path.expanduser(os.environ.get("OUT_DIR", "~/frus-b2/compare"))
MANIFEST = os.environ.get("MANIFEST", "FRUSExplorer/Resources/manifest.json")
BAND_ORDER = ["pre1900", "1900_1945", "post1945"]
# Finer eras by the citing volume's midpoint year, fixed before any result was read. The
# interwar row holds frus1938v01, the spike volume whose loss was outside the noise in stage 1.
ERAS = [("pre1900", None, 1899), ("1900_1918", 1900, 1918), ("1919_1938", 1919, 1938),
        ("1939_1945", 1939, 1945), ("1946_1960", 1946, 1960), ("1961_1976", 1961, 1976),
        ("1977_plus", 1977, None)]
SPLITS = ["same_volume_only", "cross_volume_only", "mixed"]
NAMED_VOLUMES = ["frus1938v01", "frus1948v06"]


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(OUT_DIR, "compare_corpus.log"), "a") as fh:
        fh.write(line + "\n")


def load_keys(pool):
    keys = []
    with open(os.path.join(pool, "doc_keys.jsonl")) as fh:
        for line in fh:
            row = json.loads(line)
            keys.append((row["v"], row["d"]))
    return keys


# ---------------------------------------------------------------- MODE=ranks

def funnel_ranks(width, pools, signs_src, rerank_q, rerank_s, sources, target_sets, n):
    """Best ranks under Hamming top-P over `width` sign bits, then the int8 rerank."""
    signs = np.where(signs_src >= 0, 1.0, -1.0).astype(np.float32)
    pmax = max(pools)
    out = {p: np.empty(len(sources), dtype=np.int64) for p in pools}
    t0 = time.time()
    batch = 256
    for lo in range(0, len(sources), batch):
        rows = sources[lo:lo + batch]
        dots = signs[rows] @ signs.T
        neg_dist = -((width - dots) / 2.0)
        for j, src in enumerate(rows):
            cands = select_topk(neg_dist[j], src, pmax)
            ts = target_sets[lo + j]
            ts_arr = np.asarray(ts)
            for p in pools:
                carr = np.asarray(cands[:p])
                scores = (rerank_q[carr].astype(np.int32) @ rerank_q[src].astype(np.int32)
                          ) * rerank_s[carr] * rerank_s[src]
                ranked = carr[np.lexsort((carr, -scores))]
                pos = np.flatnonzero(np.isin(ranked, ts_arr))
                if pos.size:
                    out[p][lo + j] = int(pos[0]) + 1
                else:
                    tmin = ts[0]
                    out[p][lo + j] = (p + 1 + tmin - int(np.count_nonzero(carr < tmin))
                                      - (1 if src < tmin else 0))
        if (lo // batch) % 40 == 0:
            log("hamming%d: %d/%d queries (%.0fs)" % (width, lo + len(rows), len(sources),
                                                      time.time() - t0))
    log("hamming%d: done in %.0fs" % (width, time.time() - t0))
    return out


def mode_ranks():
    label = os.environ["LABEL"]
    assess = os.path.expanduser(os.environ["ASSESS"])
    db = os.path.expanduser(os.environ["DB"])
    pool = os.path.join(assess, "pool")
    ga.LOG = os.path.join(OUT_DIR, "gate_a_corpus-%s.log" % label)
    started = time.time()
    keys = load_keys(pool)
    index = {k: i for i, k in enumerate(keys)}
    ga.keys = keys
    n = len(keys)
    pairs, census, pair_cross, _ = ga.load_edges(db, index)
    sources = sorted(pairs)
    if os.environ.get("LIMIT"):  # a smoke run over the first LIMIT queries
        sources = sources[:int(os.environ["LIMIT"])]
    target_sets = [sorted(pairs[s]) for s in sources]
    split = []
    for s, ts in zip(sources, target_sets):
        crosses = [(s, t) in pair_cross for t in ts]
        split.append(1 if all(crosses) else (0 if not any(crosses) else 2))
    log("%s: %d docs, %d queries, %d pairs" % (label, n, len(sources),
                                               sum(len(t) for t in target_sets)))

    f32 = np.load(os.path.join(pool, "doc_f32_768.npy"))
    ranks = {}
    ranks["float-768"] = ga.score_config("float-768", lambda rows: f32[rows] @ f32.T,
                                         sources, target_sets, n)
    cut512 = truncate(f32, 512).astype(np.float32)
    ranks["float-512"] = ga.score_config("float-512", lambda rows: cut512[rows] @ cut512.T,
                                         sources, target_sets, n)
    int8 = {}
    for dims in (512, 256):
        q = np.load(os.path.join(pool, "doc_int8_%d.npy" % dims))
        scale = np.load(os.path.join(pool, "doc_scale_%d.npy" % dims))
        int8[dims] = (q, scale)
        qf = q.astype(np.float32)
        s64 = scale.astype(np.float64)
        chk = sources[:: max(1, len(sources) // 8)][:8]
        assert np.array_equal((qf[chk] @ qf.T).astype(np.int64),
                              (q[chk].astype(np.int32) @ q.T.astype(np.int32)).astype(np.int64)), \
            "float32 int8 dots are not exact at %d" % dims
        ranks["int8-%d" % dims] = ga.score_config(
            "int8-%d" % dims,
            lambda rows, qf=qf, s64=s64: (qf[rows] @ qf.T).astype(np.float64)
            * s64[rows][:, None] * s64[None, :],
            sources, target_sets, n)
        del qf

    funnel = funnel_ranks(512, POOLS, cut512, int8[512][0], int8[512][1],
                          sources, target_sets, n)
    for p in POOLS:
        ranks["hamming512-%d->int8-512" % p] = funnel[p]
    del cut512
    cut256 = truncate(f32, 256).astype(np.float32)
    funnel = funnel_ranks(256, [800], cut256, int8[256][0], int8[256][1],
                          sources, target_sets, n)
    ranks["hamming256-800->int8-256"] = funnel[800]

    offsets = np.cumsum([0] + [len(t) for t in target_sets])
    np.savez(os.path.join(OUT_DIR, "ranks-%s.npz" % label),
             sources=np.asarray(sources, dtype=np.int64),
             targets=np.asarray([t for ts in target_sets for t in ts], dtype=np.int64),
             target_offsets=np.asarray(offsets, dtype=np.int64),
             split=np.asarray(split, dtype=np.int8),
             **{name: np.asarray(r, dtype=np.int64) for name, r in ranks.items()})
    json.dump({"label": label, "assess": assess, "db": db, "docs": n, "census": census,
               "queries": len(sources), "configs": sorted(ranks),
               "elapsed_secs": round(time.time() - started, 1)},
              open(os.path.join(OUT_DIR, "ranks-%s.json" % label), "w"), indent=2, sort_keys=True)
    log("%s: ranks written in %.0fs" % (label, time.time() - started))


# ---------------------------------------------------------------- MODE=sweep

def mode_sweep():
    label = os.environ["LABEL"]
    assess = os.path.expanduser(os.environ["ASSESS"])
    pool, work = os.path.join(assess, "pool"), os.path.join(assess, "nn_work")
    manifest = json.load(open(MANIFEST))
    vol_band = {}
    for e in manifest:
        mid = (int(e["dateRange"]["earliest"][:4]) + int(e["dateRange"]["latest"][:4])) / 2.0
        vol_band[e["volumeId"]] = ("pre1900" if mid < 1900
                                   else ("1900_1945" if mid <= 1945 else "post1945"))
    keys = load_keys(pool)
    row_band = np.array([BAND_ORDER.index(vol_band[v]) for v, _ in keys], dtype=np.int8)
    qrows = np.load(os.path.join(work, "queries.npz"))["qrows"]
    truth = np.load(os.path.join(work, "truth.npz"))["rows"]
    q_band = row_band[qrows]
    f32 = np.load(os.path.join(pool, "doc_f32_768.npy"))
    results = {}
    for width in (512, 256):
        cut = truncate(f32, width).astype(np.float32)
        signs = np.where(cut >= 0, 1.0, -1.0).astype(np.float32)
        del cut
        q = np.load(os.path.join(pool, "doc_int8_%d.npy" % width))
        s = np.load(os.path.join(pool, "doc_scale_%d.npy" % width))
        rows_out = {p: np.empty((len(qrows), ga.TOP_K), dtype=np.int64) for p in POOLS}
        for lo in range(0, len(qrows), 300):
            batch = qrows[lo:lo + 300]
            neg_dist = -((width - signs[batch] @ signs.T) / 2.0)
            for j, i in enumerate(batch):
                cands = select_topk(neg_dist[j], i, max(POOLS))
                for p in POOLS:
                    carr = np.asarray(cands[:p])
                    sc = (q[carr].astype(np.int32) @ q[i].astype(np.int32)) * s[carr] * s[i]
                    rows_out[p][lo + j] = carr[np.lexsort((carr, -sc))[:ga.TOP_K]]
        for p in POOLS:
            r = np.array([len(set(truth[k]) & set(rows_out[p][k])) / ga.TOP_K
                          for k in range(len(qrows))])
            out = {"overall": round(float(r.mean()), 4)}
            for bi, b in enumerate(BAND_ORDER):
                out[b] = round(float(r[q_band == bi].mean()), 4)
            results["hamming%d-%d->int8-%d" % (width, p, width)] = out
        log("%s: sweep at %d done" % (label, width))
    json.dump({"label": label, "queries": int(len(qrows)), "recall_at_10_vs_float768": results},
              open(os.path.join(OUT_DIR, "sweep-%s.json" % label), "w"), indent=2, sort_keys=True)
    print(json.dumps(results, indent=2, sort_keys=True))


# ---------------------------------------------------------------- MODE=compare

def rr(ranks):
    return np.where(ranks <= ga.TOP_K, 1.0 / ranks, 0.0)


def query_interval(diff, rng):
    n = len(diff)
    est = []
    for lo in range(0, BOOT, 200):
        k = min(200, BOOT - lo)
        est.append(diff[rng.integers(0, n, size=(k, n))].mean(axis=1))
    est = np.concatenate(est)
    return [round(float(np.percentile(est, 2.5)), 4), round(float(np.percentile(est, 97.5)), 4)]


def volume_interval(diff, vols, rng):
    names, inverse = np.unique(vols, return_inverse=True)
    if len(names) < 2:
        return None
    sums = np.bincount(inverse, weights=diff)
    counts = np.bincount(inverse).astype(np.float64)
    idx = rng.integers(0, len(names), size=(BOOT, len(names)))
    est = sums[idx].sum(axis=1) / counts[idx].sum(axis=1)
    return [round(float(np.percentile(est, 2.5)), 4), round(float(np.percentile(est, 97.5)), 4)]


def paired(base, cand, vols, rng):
    d_rr = rr(cand) - rr(base)
    d_hit = (cand <= 10).astype(np.float64) - (base <= 10).astype(np.float64)
    return {
        "queries": int(len(base)), "volumes": int(len(np.unique(vols))),
        "baseline_mrr@10": round(float(rr(base).mean()), 4),
        "candidate_mrr@10": round(float(rr(cand).mean()), 4),
        "delta_mrr@10": round(float(d_rr.mean()), 4),
        "delta_mrr@10_ci95_queries": query_interval(d_rr, rng),
        "delta_mrr@10_ci95_volumes": volume_interval(d_rr, vols, rng),
        "baseline_hit@10": round(float((base <= 10).mean()), 4),
        "candidate_hit@10": round(float((cand <= 10).mean()), 4),
        "delta_hit@10": round(float(d_hit.mean()), 4),
        "delta_hit@10_ci95_queries": query_interval(d_hit, rng),
        "delta_hit@10_ci95_volumes": volume_interval(d_hit, vols, rng),
        "candidate_ranks_better": int((cand < base).sum()),
        "candidate_ranks_worse": int((cand > base).sum()),
        "ranks_equal": int((cand == base).sum()),
    }


def mode_compare():
    base_label, cand_label = os.environ["BASELINE"], os.environ["CANDIDATE"]
    zb = np.load(os.path.join(OUT_DIR, "ranks-%s.npz" % base_label))
    zc = np.load(os.path.join(OUT_DIR, "ranks-%s.npz" % cand_label))
    mb = json.load(open(os.path.join(OUT_DIR, "ranks-%s.json" % base_label)))
    mc = json.load(open(os.path.join(OUT_DIR, "ranks-%s.json" % cand_label)))
    for name in ("sources", "targets", "target_offsets", "split"):
        assert np.array_equal(zb[name], zc[name]), "the two runs read different edges: " + name
    keys = load_keys(os.path.join(mb["assess"], "pool"))
    assert keys == load_keys(os.path.join(mc["assess"], "pool")), "document sets diverge"
    sources, split = zb["sources"], zb["split"]
    targets, offsets = zb["targets"], zb["target_offsets"]
    pair_counts = np.diff(offsets)
    vols = np.array([keys[s][0] for s in sources])
    poolsize = len(keys) - 1

    manifest = json.load(open(MANIFEST))
    mid = {e["volumeId"]: (int(e["dateRange"]["earliest"][:4])
                           + int(e["dateRange"]["latest"][:4])) / 2.0 for e in manifest}
    bands = ga.volume_bands()
    band = np.array([bands[v] for v in vols])

    def era_of(v):
        year = int(mid[v])
        for name, lo, hi in ERAS:
            if (lo is None or year >= lo) and (hi is None or year <= hi):
                return name
    era = np.array([era_of(v) for v in vols])

    scopes = [("overall", np.ones(len(sources), dtype=bool))]
    scopes += [("band:" + b, band == b) for b in BAND_ORDER]
    scopes += [("era:" + e[0], era == e[0]) for e in ERAS]
    scopes += [("split:" + s, split == i) for i, s in enumerate(SPLITS)]
    scopes += [("volume:" + v, vols == v) for v in NAMED_VOLUMES]

    excluded = None
    if os.environ.get("EXCLUDE_DOCS"):
        index = {k: i for i, k in enumerate(keys)}
        rows = {index[(r["v"], r["d"])] for r in json.load(open(os.environ["EXCLUDE_DOCS"]))}
        touch = np.array([s in rows or any(t in rows for t in targets[offsets[i]:offsets[i + 1]])
                          for i, s in enumerate(sources)])
        excluded = {"documents": len(rows), "queries_touching": int(touch.sum())}
        scopes += [("untouched:" + name, mask & ~touch) for name, mask in scopes[:4]]

    rng = np.random.default_rng(SEED)
    configs = [c for c in zb.files if c not in ("sources", "targets", "target_offsets", "split")]
    configs.sort()
    result = {"baseline": base_label, "candidate": cand_label, "seed": SEED, "bootstrap": BOOT,
              "db": mb["db"], "docs": len(keys), "queries": int(len(sources)),
              "pairs": int(pair_counts.sum()), "census": mb["census"],
              "eras": {name: [lo, hi] for name, lo, hi in ERAS},
              "excluded_text_differences": excluded,
              "scope_queries": {name: int(mask.sum()) for name, mask in scopes},
              "gate_a": {base_label: {}, cand_label: {}}, "paired": {}}
    for config in configs:
        b, c = zb[config], zc[config]
        for label, ranks in ((base_label, b), (cand_label, c)):
            result["gate_a"][label][config] = {
                name: ga.summarize(ranks[mask], pair_counts[mask].sum(), poolsize)
                for name, mask in scopes if mask.any()}
        result["paired"][config] = {name: paired(b[mask], c[mask], vols[mask], rng)
                                    for name, mask in scopes if mask.any()}
        log("paired %s" % config)

    # Per citing volume at the shipping shape: the spread a single overall figure hides.
    b, c = zb[SHIPPING], zc[SHIPPING]
    per_volume = []
    for v in sorted(set(vols)):
        m = vols == v
        d = rr(c[m]) - rr(b[m])
        per_volume.append({"volume": v, "era": era_of(v), "queries": int(m.sum()),
                           "baseline_mrr@10": round(float(rr(b[m]).mean()), 4),
                           "candidate_mrr@10": round(float(rr(c[m]).mean()), 4),
                           "delta_mrr@10": round(float(d.mean()), 4),
                           "delta_mrr@10_ci95_queries": query_interval(d, rng) if m.sum() > 1 else None})
    result["per_volume_" + SHIPPING] = per_volume
    json.dump(result, open(os.path.join(OUT_DIR, "compare.json"), "w"), indent=2, sort_keys=True)
    log("wrote compare.json")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    mode = os.environ.get("MODE")
    if mode == "ranks":
        mode_ranks()
    elif mode == "sweep":
        mode_sweep()
    elif mode == "compare":
        mode_compare()
    else:
        sys.exit("MODE must be ranks, sweep or compare")
