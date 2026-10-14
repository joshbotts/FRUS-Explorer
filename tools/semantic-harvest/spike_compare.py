#!/usr/bin/env python3
"""Paired comparison of two spike stores, beside `spike_gates.py` (Track B, B1).

`spike_gates.py` reports each store's Gate A and ladder on its own. Two models one MRR
point apart over a few hundred queries are not told apart by that alone, so this script
reads the same stores through `spike_gates`' own loaders and instruments and adds:

  paired     per-query reciprocal ranks of a CANDIDATE against a BASELINE over the same
             weak-positive queries: the MRR@10 and hit@10 differences with a paired
             bootstrap interval (fixed seed), and the wins, losses and ties per query.
  width 512  Gate A at the width the app ships since #933: float-512, int8-512, and the
             shipping pipeline's shape (Hamming over 512 sign bits, a pool, int8-512
             rerank). The pool is 200, V-0's spike-scale figure: the app's 800 is sized
             for 314k candidates and would be a third of a 2,198-document spike.
  parity     an optional PARITY store holding the BASELINE's weights embedded through a
             different runtime: per-chunk cosine, and spike_gates' mutual recall@10 and
             rank-1 agreement at float full width. It is the noise floor the paired
             difference is read against.

Environment:
  BASELINE   label=path, e.g. gemma300m=~/frus-semantic-raw (only the spike volumes are read)
  CANDIDATE  label=path
  PARITY     optional label=path
  DB         live index (read-only); default spike_gates' DEFAULT_DB
  OUT        optional path for the JSON result
  BOOT       bootstrap resamples, default 10000

Needs numpy, like spike_gates. Deterministic: fixed seed, sorted keys.
"""

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spike_gates as g  # noqa: E402

SEED = 20261014
POOL = 200
WIDTH = 512


def parse(spec):
    label, path = spec.split("=", 1)
    return label, os.path.expanduser(path)


def ranks_by_query(store, edges_by_volume, score_fn):
    """{(vol, source_row): rank of the first relevant result}, as spike_gates.gate_a ranks."""
    tie_key = np.arange(len(store["keys"]))
    out = {}
    for vol, edges in sorted(edges_by_volume.items()):
        sources = sorted({s for s, _ in edges})
        scores = score_fn(sources)
        by_source = {s: scores[i] for i, s in enumerate(sources)}
        for source, targets in edges:
            order = np.lexsort((tie_key, -np.asarray(by_source[source], dtype=np.float64)))
            ranked = [i for i in order if i != source]
            out[(vol, source)] = min(ranked.index(t) + 1 for t in targets)
    return out


def rr(rank):
    return 1.0 / rank if rank <= g.TOP_K else 0.0


def paired(base, cand, boot, rng):
    keys = sorted(base)
    assert keys == sorted(cand)
    b = np.array([rr(base[k]) for k in keys])
    c = np.array([rr(cand[k]) for k in keys])
    bh = np.array([base[k] <= 10 for k in keys], dtype=np.float64)
    ch = np.array([cand[k] <= 10 for k in keys], dtype=np.float64)
    idx = rng.integers(0, len(keys), size=(boot, len(keys)))
    d_mrr = (c - b)[idx].mean(axis=1)
    d_hit = (ch - bh)[idx].mean(axis=1)
    better = sum(1 for k in keys if cand[k] < base[k])
    worse = sum(1 for k in keys if cand[k] > base[k])
    return {"queries": len(keys),
            "baseline_mrr@10": round(float(b.mean()), 4), "candidate_mrr@10": round(float(c.mean()), 4),
            "delta_mrr@10": round(float((c - b).mean()), 4),
            "delta_mrr@10_ci95": [round(float(np.percentile(d_mrr, 2.5)), 4),
                                  round(float(np.percentile(d_mrr, 97.5)), 4)],
            "delta_hit@10": round(float((ch - bh).mean()), 4),
            "delta_hit@10_ci95": [round(float(np.percentile(d_hit, 2.5)), 4),
                                  round(float(np.percentile(d_hit, 97.5)), 4)],
            "candidate_ranks_better": better, "candidate_ranks_worse": worse,
            "ranks_equal": len(keys) - better - worse}


def shipping_512_scores(store):
    """Score functions for Gate A at 512: float, int8, and Hamming pool -> int8 rerank."""
    cut = g.truncate(store["float_full"], WIDTH)
    q, scale = g.int8_quantize(cut)
    packed = g.pack_bits(cut)
    n = len(cut)
    tie_key = np.arange(n)

    def float_fn(rows):
        return cut[rows] @ cut.T

    def int8_fn(rows):
        return g.int8_scores(q, scale, np.array(rows))

    def pipeline_fn(rows):
        dist = g.hamming_distances(packed, np.array(rows))
        out = np.full((len(rows), n), -np.inf)
        for qi, i in enumerate(rows):
            # The pool leaves the anchor out, as spike_gates.shipping_top1 does; a document
            # outside it scores -inf and ranks after every pooled one, in key order.
            cands = g.top_k_from_scores(-dist[qi].astype(np.float32), i, POOL, tie_key)
            out[qi, cands] = (q[cands].astype(np.int32) @ q[i].astype(np.int32)) * scale[cands] * scale[i]
        return out

    return {"float-512": float_fn, "int8-512": int8_fn,
            "hamming%d->int8-512" % POOL: pipeline_fn}


def summarize(ranks):
    by_vol = {}
    for (vol, _), r in ranks.items():
        by_vol.setdefault(vol, []).append(r)
    out = {vol: g.summarize_ranks(rs) for vol, rs in sorted(by_vol.items())}
    out["overall"] = g.summarize_ranks(list(ranks.values()))
    return out


def chunk_parity(path_a, path_b):
    """Per-chunk cosine between two stores of the same chunks (same text layer, same meta)."""
    cos = []
    for vol in g.SPIKE_VOLUMES:
        heads = [json.load(open(os.path.join(p, "vectors", vol + ".head.json"))) for p in (path_a, path_b)]
        assert heads[0]["chunks"] == heads[1]["chunks"] and heads[0]["dim"] == heads[1]["dim"]
        metas = [open(os.path.join(p, "vectors", vol + ".meta.jsonl")).read() for p in (path_a, path_b)]
        assert metas[0] == metas[1], "chunk spans differ: %s" % vol
        a, b = (np.fromfile(os.path.join(p, "vectors", vol + ".bin"), dtype="<f4")
                .reshape(heads[0]["chunks"], heads[0]["dim"]).astype(np.float64) for p in (path_a, path_b))
        cos.append((a * b).sum(axis=1) / (np.linalg.norm(a, axis=1) * np.linalg.norm(b, axis=1)))
    cos = np.concatenate(cos)
    return {"chunks": int(len(cos)), "cosine_min": round(float(cos.min()), 6),
            "cosine_mean": round(float(cos.mean()), 6),
            "cosine_p01": round(float(np.percentile(cos, 1)), 6)}


def main():
    base_label, base_path = parse(os.environ["BASELINE"])
    cand_label, cand_path = parse(os.environ["CANDIDATE"])
    db = os.environ.get("DB", g.DEFAULT_DB)
    boot = int(os.environ.get("BOOT", "10000"))
    stores = {base_label: g.load_store(base_path), cand_label: g.load_store(cand_path)}
    assert stores[base_label]["keys"] == stores[cand_label]["keys"], "doc sets diverge"
    edges, dropped, pairs = g.load_edges(db, stores[base_label]["index"])

    result = {"baseline": base_label, "candidate": cand_label, "db": db, "seed": SEED, "bootstrap": boot,
              "pool_at_512": POOL, "weak_positive_resolved_pairs": pairs, "weak_positive_drops": dropped,
              "gate_a": {}, "paired": {}}
    ranks = {}
    for label, store in stores.items():
        fns = {"float-full": lambda rows, m=store["float_full"]: m[rows] @ m.T}
        fns.update(shipping_512_scores(store))
        ranks[label] = {name: ranks_by_query(store, edges, fn) for name, fn in fns.items()}
        result["gate_a"][label] = {name: summarize(r) for name, r in ranks[label].items()}
    rng = np.random.default_rng(SEED)
    for name in ranks[base_label]:
        result["paired"][name] = {"overall": paired(ranks[base_label][name], ranks[cand_label][name], boot, rng)}
        for vol in sorted(edges):
            sub = lambda r: {k: v for k, v in r.items() if k[0] == vol}  # noqa: E731
            result["paired"][name][vol] = paired(sub(ranks[base_label][name]), sub(ranks[cand_label][name]),
                                                 boot, rng)
    result["neighbours_candidate_vs_baseline_float_full"] = g.quant_pair_agreement(
        stores[base_label], stores[cand_label])

    if os.environ.get("PARITY"):
        par_label, par_path = parse(os.environ["PARITY"])
        par = g.load_store(par_path)
        assert par["keys"] == stores[base_label]["keys"]
        result["parity"] = {"store": par_label, "chunks": chunk_parity(base_path, par_path),
                            "float_full": g.quant_pair_agreement(stores[base_label], par)}

    text = json.dumps(result, indent=2, sort_keys=True)
    if os.environ.get("OUT"):
        open(os.environ["OUT"], "w").write(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
