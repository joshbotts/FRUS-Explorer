# Literal check of compare_corpus.funnel_ranks: the spike_compare shape (pool scores, -inf
# elsewhere, a full lexsort by (-score, row)), on queries of a smoke run.
import os, sys, json, numpy as np
sys.path.insert(0, "tools/semantic-harvest/corpus-gates")
from pool_docs import truncate, pack_bits
assess, smoke, label = sys.argv[1], sys.argv[2], sys.argv[3]
z = np.load(os.path.join(smoke, "ranks-%s.npz" % label))
F = np.load(os.path.join(assess, "pool/doc_f32_768.npy"))
cut = truncate(F, 512).astype(np.float32)
packed = np.ascontiguousarray(pack_bits(cut)).view(np.uint64)
q = np.load(os.path.join(assess, "pool/doc_int8_512.npy")); s = np.load(os.path.join(assess, "pool/doc_scale_512.npy"))
n = len(F); tie = np.arange(n)
src, tg, off = z["sources"], z["targets"], z["target_offsets"]
picks = list(range(0, len(src), 31))[:20]
bad = 0
for i in picks:
    a = src[i]; ts = tg[off[i]:off[i + 1]]
    dist = np.bitwise_count(packed[a][None, :] ^ packed).sum(axis=1)
    order = np.lexsort((tie, dist)); order = order[order != a]
    for p in (200, 800, 1600):
        pool = order[:p]
        sc = np.full(n, -np.inf)
        sc[pool] = (q[pool].astype(np.int32) @ q[a].astype(np.int32)) * s[pool] * s[a]
        ranked = np.lexsort((tie, -sc)); ranked = ranked[ranked != a]
        pos = np.flatnonzero(np.isin(ranked, ts))[0] + 1
        if pos != z["hamming512-%d->int8-512" % p][i]:
            bad += 1; print("MISMATCH", i, p, pos, z["hamming512-%d->int8-512" % p][i])
    # full float-768 rank
    sf = F[a] @ F.T
    ranked = np.lexsort((tie, -sf)); ranked = ranked[ranked != a]
    pos = np.flatnonzero(np.isin(ranked, ts))[0] + 1
    if pos != z["float-768"][i]:
        bad += 1; print("MISMATCH float", i, pos, z["float-768"][i])
print("checked", len(picks), "queries x 4 configs, mismatches", bad)
