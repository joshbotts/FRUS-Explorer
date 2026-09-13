#!/usr/bin/env python3
"""Distributions, token anchor, packing simulation over docs.tsv + anchor-per-volume.json."""
import csv, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
rows = list(csv.DictReader(open(os.path.join(HERE, "docs.tsv")), delimiter="\t"))
for r in rows:
    for k in r:
        if k not in ("vol", "doc"): r[k] = int(r[k])
anc = json.load(open(os.path.join(HERE, "anchor-per-volume.json")))
def pct(xs, q):
    xs = sorted(xs); return xs[min(len(xs) - 1, int(q * len(xs)))]
def dist(xs):
    n = len(xs); return {"n": n, "sum": sum(xs), "mean": round(sum(xs) / n, 2), "p50": pct(xs, .5), "p90": pct(xs, .9), "p99": pct(xs, .99), "max": max(xs), "zero": sum(1 for x in xs if x == 0)}
res = {}
ch = [r["chars"] for r in rows]
res["doc_chars"] = dist(ch)
res["doc_chars_thresholds"] = {str(t): {"docs_over": sum(1 for x in ch if x > t), "chars_in_docs_over": sum(x for x in ch if x > t)} for t in (8000, 20000, 40000, 100000, 200000, 400000, 600000, 3000000)}
for f in ("marked", "fctrl", "fsweep", "union_exact", "union_merged", "union_surfaces", "union_surface_chars", "union_span_chars"):
    res["per_doc_" + f] = dist([r[f] for r in rows])
res["chunks_recon_total"] = sum(r["chunks"] for r in rows)
res["chunk_chars_recon_total"] = sum(r["chunk_chars"] for r in rows)
# anchor
A = {k: sum((a[k] or 0) for a in anc) for k in ("chunks_recon", "chunk_chars_recon", "head_chunks", "head_chars", "prompt_tokens", "completion_tokens", "mentions", "returned", "truncated", "secs", "docs_scanned")}
res["anchor_totals"] = A
res["anchor_chunk_mismatch_volumes"] = [a["vol"] for a in anc if a["chunks_recon"] != a["head_chunks"]]
# regression prompt_tokens = a*chunks + b*chunk_chars (no intercept), per volume, using reconstructed chars where chunks agree
X = [(a["head_chunks"], a["chunk_chars_recon"], a["prompt_tokens"]) for a in anc if a["chunks_recon"] == a["head_chunks"] and a["prompt_tokens"]]
s11 = sum(c * c for c, _, _ in X); s12 = sum(c * x for c, x, _ in X); s22 = sum(x * x for _, x, _ in X)
t1 = sum(c * y for c, _, y in X); t2 = sum(x * y for _, x, y in X)
det = s11 * s22 - s12 * s12
a = (t1 * s22 - t2 * s12) / det; b = (s11 * t2 - s12 * t1) / det
resid = [y - (a * c + b * x) for c, x, y in X]
res["anchor_regression"] = {"volumes": len(X), "overhead_tokens_per_chunk": round(a, 2), "tokens_per_char": round(b, 5), "chars_per_token": round(1 / b, 4),
    "max_abs_resid_share": round(max(abs(r) / y for r, (_, _, y) in zip(resid, X)), 4)}
# per-volume chars/token after the fitted overhead, and naive
cpt = sorted(x / (y - a * c) for c, x, y in X)
res["per_volume_chars_per_token_after_overhead"] = {"min": round(cpt[0], 3), "p10": round(pct(cpt, .1), 3), "p50": round(pct(cpt, .5), 3), "p90": round(pct(cpt, .9), 3), "max": round(cpt[-1], 3)}
res["naive_chars_per_token_including_overhead"] = round(A["chunk_chars_recon"] / A["prompt_tokens"], 4)
res["completion_tokens_per_returned_string"] = round(A["completion_tokens"] / A["returned"], 3) if A["returned"] else None
res["completion_tokens_per_chunk"] = round(A["completion_tokens"] / A["head_chunks"], 2)
# by band via volume year
import re
def band(v):
    y = int(re.search(r"frus(\d{4})", v).group(1)); return "1861-1899" if y < 1900 else "1900-1929" if y < 1930 else "1930-1945" if y < 1946 else "1946-"
bb = {}
for r in rows:
    d = bb.setdefault(band(r["vol"]), {"docs": 0, "chars": 0, "union_exact": 0, "union_surfaces": 0, "marked": 0})
    d["docs"] += 1; d["chars"] += r["chars"]; d["union_exact"] += r["union_exact"]; d["union_surfaces"] += r["union_surfaces"]; d["marked"] += r["marked"]
res["by_band"] = bb
# packing simulation: greedy in volume/doc order, target chars per request; docs longer than CAP are chunked into pieces of CAP with OVERLAP
def pack(target, cap, overlap):
    reqs = 0; cur = 0; pieces = 0; billed = 0
    for r in rows:
        L = r["chars"]
        if L > cap:
            if cur: reqs += 1; cur = 0
            step = cap - overlap
            n = 1 + max(0, -(-(L - cap) // step))
            reqs += n; pieces += n; billed += L + (n - 1) * overlap
            continue
        if cur + L > target and cur:
            reqs += 1; cur = 0
        cur += L; billed += L
    if cur: reqs += 1
    return {"requests": reqs, "chunked_pieces": pieces, "billed_chars": billed}
res["packing"] = {}
for target, cap, ov in ((0, 3200, 480), (0, 40000, 2000), (8000, 40000, 2000), (20000, 40000, 2000), (40000, 40000, 2000), (80000, 80000, 2000), (0, 400000, 4000), (200000, 400000, 4000)):
    res["packing"]["target%d_cap%d_ov%d" % (target, cap, ov)] = pack(target, cap, ov)
json.dump(res, open(os.path.join(HERE, "analysis.json"), "w"), indent=1)
print(json.dumps(res, indent=1))
