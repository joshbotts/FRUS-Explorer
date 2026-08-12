#!/usr/bin/env python3
"""Gate A (cross-reference weak positives) at CORPUS scale.

Reuses spike_gates.py load_edges()/gate_a()/summarize_ranks() semantics EXACTLY,
with two deliberate differences mandated by the task:
  1. cross-volume targets are NOT dropped — an edge counts whenever BOTH endpoints
     exist in the pooled matrix (page anchors resolve through page_ranges of the
     TARGET volume, which in the spike was always == source volume);
  2. the candidate pool is the full 314,483-doc corpus.

Rank semantics are identical to the spike's lexsort path but computed by counting
(rank_t = 1 + #{j != source: (-score_j, j) < (-score_t, t)}), which is exact:
ranks follow the (score desc, row asc) sort order, so the best-ranked relevant doc
is the one with (max score, min row), and its rank is a vectorized count.

int8 dots are computed with float32 BLAS: products of int8 values are integers
<= 127*127 = 16129 and any partial sum of 256 of them is an integer < 2^24, so
float32 accumulation is EXACT (verified in-run against the pinned int32 path).

Deterministic: fixed seed (18610810), ORDER BY id scan, explicit sorts, sorted keys.
"""

import json
import os
import random
import sqlite3
import sys
import time

import numpy as np

SEED = 18610810
TOP_K = 10
BASE = os.path.expanduser(os.environ.get("ASSESS_DIR", "~/frus-semantic-gates"))
POOL = os.path.join(BASE, "pool")
DB = os.path.join(BASE, "db", "frus.db")
MANIFEST = os.environ.get("MANIFEST", "FRUSExplorer/Resources/manifest.json")
OUT = os.path.join(BASE, "weakpos.json")
LOG = os.path.join(BASE, "gate_a_corpus.log")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(LOG, "a") as fh:
        fh.write(line + "\n")


# ---------------------------------------------------------------- edge loading

def load_keys():
    keys = []
    with open(os.path.join(POOL, "doc_keys.jsonl")) as fh:
        for line in fh:
            row = json.loads(line)
            keys.append((row["v"], row["d"]))
    index = {k: i for i, k in enumerate(keys)}
    assert len(index) == len(keys), "key collision"
    return keys, index


def load_edges(db_path, doc_index):
    """spike_gates.load_edges, corpus-wide, cross-volume retained.

    Returns pairs {source_row: set(target_rows)}, drop census, resolved pair count,
    per-pair cross-volume tally, and the missing-endpoint census for sampling.
    """
    con = sqlite3.connect("file:%s?mode=ro" % db_path, uri=True)
    pages = {}  # (vol, page_int) -> [doc_id] — ALL volumes, arabic only (pinned)
    for vol, doc, page in con.execute(
            "SELECT volume_id, document_id, page_number_int FROM page_ranges "
            "WHERE page_number_type='arabic' "
            "ORDER BY volume_id, page_number_int, document_id"):
        pages.setdefault((vol, page), []).append(doc)
    log("page_ranges: %d (vol,page) buckets" % len(pages))

    dropped = {"self": 0, "unresolved_page": 0, "not_in_store": 0, "cross_volume": 0}
    not_in_store_url_shaped = 0
    missing = {}  # (side, vol, doc) -> occurrence count
    pairs = {}    # source_row -> set(target_row)
    pair_cross = set()   # (source_row, target_row) resolved via tv != svol
    pair_same = set()
    resolved_pairs = 0
    edges_retained = 0
    edges_retained_cross = 0
    scanned = 0

    rows = con.execute(
        "SELECT source_volume_id, source_document_id, target_volume_id, target_document_id "
        "FROM cross_references WHERE is_broken=0 ORDER BY id")
    for svol, sdoc, tvol, tdoc in rows:
        scanned += 1
        tv = tvol if tvol else svol  # NULL target volume == same volume
        if tdoc.startswith("pg_"):
            try:
                targets = pages.get((tv, int(tdoc[3:])), [])
            except ValueError:
                targets = []  # roman-numeral front-matter page
            if not targets:
                dropped["unresolved_page"] += 1
                continue
        else:
            targets = [tdoc]
        source = doc_index.get((svol, sdoc))
        target_keys = [(tv, t) for t in targets]
        in_index = [k for k in target_keys if k in doc_index]
        target_rows = frozenset(doc_index[k] for k in in_index if k != (svol, sdoc))
        if source is None or (not target_rows and in_index):
            if source is None:
                dropped["not_in_store"] += 1
                missing[("source", svol, sdoc)] = missing.get(("source", svol, sdoc), 0) + 1
            else:
                dropped["self"] += 1
            continue
        if not target_rows:
            dropped["not_in_store"] += 1
            if tdoc.startswith("http://") or tdoc.startswith("https://"):
                not_in_store_url_shaped += 1
            for k in target_keys:
                missing[("target",) + k] = missing.get(("target",) + k, 0) + 1
            continue
        edges_retained += 1
        if tv != svol:
            edges_retained_cross += 1
        bucket = pairs.setdefault(source, set())
        before = len(bucket)
        for t in sorted(target_rows):
            bucket.add(t)
            key = keys[t]
            (pair_cross if key[0] != svol else pair_same).add((source, t))
        resolved_pairs += len(bucket) - before
    con.close()
    # A pair reachable both same-volume (NULL tvol) and cross-volume can appear in both
    # tally sets; classify it same-volume (the reader's local edge wins) for the split.
    pair_cross -= pair_same
    census = {"scanned_clean_edges": scanned, "dropped": dropped,
              "not_in_store_url_shaped_targets": not_in_store_url_shaped,
              "edges_retained": edges_retained,
              "edges_retained_cross_volume": edges_retained_cross,
              "resolved_pairs": resolved_pairs,
              "distinct_missing_endpoints": len(missing)}
    return pairs, census, pair_cross, missing


# ---------------------------------------------------------------- era bands

def volume_bands():
    m = json.load(open(MANIFEST))
    bands = {}
    for v in m:
        vol = v["filename"][:-4]
        y0 = int(v["dateRange"]["earliest"][:4])
        y1 = int(v["dateRange"]["latest"][:4])
        mid = (y0 + y1) / 2.0
        bands[vol] = "pre1900" if mid < 1900 else ("1900_1945" if mid <= 1945 else "post1945")
    return bands


# ---------------------------------------------------------------- ranking

def rank_batch(scores, sources, target_sets, arange):
    """Exact lexsort-equivalent best ranks for one batch.

    scores: (B, N) float; sources: list of B source rows; target_sets: list of B
    sorted target lists. Returns list of B int ranks.
    """
    ranks = []
    for i in range(scores.shape[0]):
        s = scores[i]
        # best target under (score desc, row asc)
        ts = target_sets[i]
        t_star = min(ts, key=lambda t: (-s[t], t))
        s_star = s[t_star]
        gt = int(np.count_nonzero(s > s_star))
        eq_lt = int(np.count_nonzero((s == s_star) & (arange < t_star)))
        src = sources[i]
        corr = 1 if (s[src] > s_star or (s[src] == s_star and src < t_star)) else 0
        ranks.append(gt + eq_lt - corr + 1)
    return ranks


def score_config(name, score_batch_fn, sources, target_sets, n, batch=512):
    arange = np.arange(n)
    ranks = np.zeros(len(sources), dtype=np.int64)
    t0 = time.time()
    for lo in range(0, len(sources), batch):
        hi = min(lo + batch, len(sources))
        scores = score_batch_fn(sources[lo:hi])
        ranks[lo:hi] = rank_batch(scores, sources[lo:hi], target_sets[lo:hi], arange)
        if (lo // batch) % 20 == 0:
            log("%s: %d/%d queries (%.0fs)" % (name, hi, len(sources), time.time() - t0))
    log("%s: done %d queries in %.0fs" % (name, len(sources), time.time() - t0))
    return ranks


# ---------------------------------------------------------------- summaries

def summarize(ranks, pair_counts, poolsize):
    """spike summarize_ranks + p90 + percentile stats + pair count."""
    arr = np.asarray(ranks)
    if len(arr) == 0:
        return {"queries": 0, "pairs": int(pair_counts)}
    pct = arr / float(poolsize)
    return {
        "queries": int(len(arr)),
        "pairs": int(pair_counts),
        "mrr@10": round(float(np.where(arr <= TOP_K, 1.0 / arr, 0.0).mean()), 4),
        "hit@10": round(float((arr <= 10).mean()), 4),
        "hit@50": round(float((arr <= 50).mean()), 4),
        "hit@100": round(float((arr <= 100).mean()), 4),
        "median_rank": int(np.median(arr)),
        "p90_rank": int(np.percentile(arr, 90)),
        "median_rank_pct": round(float(np.median(pct)), 6),
        "p90_rank_pct": round(float(np.percentile(pct, 90)), 6),
    }


def main():
    global keys
    open(LOG, "w").close()
    log("loading pool ...")
    keys, index = load_keys()
    n = len(keys)
    log("pool: %d docs" % n)

    pairs, census, pair_cross, missing = load_edges(DB, index)
    log("edges loaded: %s" % json.dumps(census))

    bands = volume_bands()
    sources = sorted(pairs)
    target_sets = [sorted(pairs[s]) for s in sources]
    pair_count_per_query = [len(t) for t in target_sets]
    total_pairs = sum(pair_count_per_query)
    assert total_pairs == census["resolved_pairs"]

    # query classification
    q_band, q_split = [], []
    for s, ts in zip(sources, target_sets):
        svol = keys[s][0]
        q_band.append(bands.get(svol, "unknown"))
        crosses = [1 if (s, t) in pair_cross else 0 for t in ts]
        q_split.append("cross_volume_only" if all(crosses)
                       else ("same_volume_only" if not any(crosses) else "mixed"))
    vols_with_query = len({keys[s][0] for s in sources})
    log("queries: %d, pairs: %d, volumes with >=1 query: %d"
        % (len(sources), total_pairs, vols_with_query))
    log("splits: %s" % json.dumps({v: q_split.count(v) for v in set(q_split)}))
    log("bands: %s" % json.dumps({v: q_band.count(v) for v in set(q_band)}))

    # seeded sample of 10 missing endpoints (deterministic)
    rng = random.Random(SEED)
    miss_keys = sorted(missing)
    store_vols = {v for v, _ in keys}
    sample = rng.sample(miss_keys, min(10, len(miss_keys)))
    miss_sample = [{"side": side, "volume": vol, "docId": doc,
                    "occurrences": missing[(side, vol, doc)],
                    "volume_in_store": vol in store_vols}
                   for side, vol, doc in sorted(sample)]
    log("missing endpoint sample: %s" % json.dumps(miss_sample))

    # ---------------- config (a): int8-256 (shipping Tier-2)
    q8 = np.load(os.path.join(POOL, "doc_int8_256.npy"))
    scale = np.load(os.path.join(POOL, "doc_scale_256.npy")).astype(np.float64)
    q8f = q8.astype(np.float32)
    assert q8.shape == (n, 256) and scale.shape == (n,)

    # exactness check: float32 BLAS dots == pinned int32 dots, on 8 queries
    chk = sources[:: max(1, len(sources) // 8)][:8]
    dots_f = (q8f[chk] @ q8f.T)
    dots_i = q8[chk].astype(np.int32) @ q8.T.astype(np.int32)
    assert np.array_equal(dots_f.astype(np.int64), dots_i.astype(np.int64)), \
        "float32 BLAS int8 dots are not exact"
    log("int8 float32-BLAS exactness check passed on %d queries" % len(chk))

    def int8_batch(rows):
        dots = (q8f[rows] @ q8f.T).astype(np.float64)
        # pinned int8_scores order: dots * scale[q][:,None] * scale[None,:]
        return dots * scale[rows][:, None] * scale[None, :]

    ranks_int8 = score_config("int8-256", int8_batch, sources, target_sets, n)
    np.save(os.path.join(BASE, "gate_a_ranks_int8_256.npy"), ranks_int8)
    del q8, q8f, scale

    # ---------------- config (b): float-768 (the ceiling) — full query set
    f32 = np.load(os.path.join(POOL, "doc_f32_768.npy"))
    assert f32.shape == (n, 768)

    def f768_batch(rows):
        return f32[rows] @ f32.T  # float32, matching the pinned gate_a float path

    ranks_f768 = score_config("float-768", f768_batch, sources, target_sets, n)
    np.save(os.path.join(BASE, "gate_a_ranks_f768.npy"), ranks_f768)
    del f32

    # ---------------- summaries
    poolsize = n - 1  # self excluded
    q_band_arr = np.array(q_band)
    q_split_arr = np.array(q_split)
    pair_arr = np.array(pair_count_per_query)

    def config_summary(ranks):
        out = {"overall": summarize(ranks, total_pairs, poolsize)}
        by_split = {}
        for split in ["same_volume_only", "cross_volume_only", "mixed"]:
            m = q_split_arr == split
            by_split[split] = summarize(ranks[m], pair_arr[m].sum(), poolsize)
        out["by_relevant_set"] = by_split
        by_band = {}
        for band in ["pre1900", "1900_1945", "post1945", "unknown"]:
            m = q_band_arr == band
            if m.any():
                by_band[band] = summarize(ranks[m], pair_arr[m].sum(), poolsize)
        out["by_era_band"] = by_band
        return out

    spike = {"config": "gemma int8-256 overall, 3-volume spike store, pool 2197",
             "mrr@10": 0.0733, "hit@10": 0.2189, "hit@50": 0.4528, "hit@100": 0.5849,
             "median_rank": 67, "queries": 265, "resolved_pairs": 369,
             "median_rank_pct": round(67 / 2196.0, 6)}

    results = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "task": "Gate A weak positives at corpus scale (cross-volume retained)",
        "seed": SEED,
        "db": DB,
        "pool_docs": n,
        "candidate_poolsize_self_excluded": poolsize,
        "pooling": "char-length-weighted mean of unit-norm chunk vectors, L2-renormalized",
        "edge_semantics": "spike_gates.load_edges with cross-volume targets retained; "
                          "page anchors resolve through target volume's arabic page_ranges; "
                          "NULL target_volume_id means same volume",
        "tie_break": "score desc, then row asc (lexsort-equivalent, computed by exact counting)",
        "census": census,
        "queries": len(sources),
        "volumes_with_query": vols_with_query,
        "query_split_counts": {v: int((q_split_arr == v).sum())
                               for v in ["same_volume_only", "cross_volume_only", "mixed"]},
        "query_band_counts": {v: int((q_band_arr == v).sum())
                              for v in sorted(set(q_band))},
        "missing_endpoint_sample": miss_sample,
        "configs": {
            "int8_256": config_summary(ranks_int8),
            "float_768": config_summary(ranks_f768),
        },
        "float_768_subsampled": False,
        "spike_reference": spike,
        "caveats": [
            "Edge labels are noisy: page-anchor resolution maps 'see p. N' to whichever "
            "document spans that page, so absolute numbers understate retrieval quality; "
            "at corpus scale this is a distribution, not a verdict.",
            "Ranks over 314,483 candidates are not directly comparable to the spike's ranks "
            "over 2,197; compare rank-percentile (rank/poolsize) columns instead.",
        ],
    }
    with open(OUT, "w") as fh:
        json.dump(results, fh, indent=2, sort_keys=True)
    log("wrote %s" % OUT)


if __name__ == "__main__":
    keys = None
    main()
