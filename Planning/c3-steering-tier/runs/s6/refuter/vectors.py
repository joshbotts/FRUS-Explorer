#!/usr/bin/env python3
# Refuter: own decode of the semantic index's id segments and own Hamming scan over the bundle's binary. Read-only.
import json, struct, numpy as np, hashlib, glob, os
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
SV = "/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix = json.load(open(R + "semantic-vectors-index.json"))

def decode(segs):
    # each segment: s = first position in the volume's rows, i = first document id, n = run length of consecutive numeric ids
    ids = []
    for s in segs:
        assert s["s"] == len(ids), ("non-contiguous segment", s)
        ids.append(s["i"])
        if s["n"] > 1:
            m = s["i"]
            assert m.startswith("d") and m[1:].isdigit(), m
            base = int(m[1:])
            ids.extend("d%d" % (base + k) for k in range(1, s["n"]))
    return ids
row_of = {}; doc_of = [None] * ix["documentCount"]
for v in ix["volumes"]:
    ids = decode(v["seg"]); assert len(ids) == v["n"], v["v"]
    for k, i in enumerate(ids):
        row_of[(v["v"], i)] = v["r"] + k; doc_of[v["r"] + k] = (v["v"], i)
assert all(x is not None for x in doc_of), "rows unassigned"
print("decoded", len(row_of), "ids over", len(ix["volumes"]), "volumes; documentCount", ix["documentCount"])

blob = open(R + "semantic-vectors-binary.bin", "rb").read()
magic = blob[:4]; ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20]); dig = blob[20:52].hex()
print("binary:", magic, "version", ver, "dims", dims, "docs", docs, "centroids", cents, "| digest", dig)
assert docs == ix["documentCount"] and dims == 512
bpr = dims // 8
signs = np.frombuffer(blob, dtype=np.uint8, count=docs * bpr, offset=64).reshape(docs, bpr)
print("sign block bytes:", docs * bpr, "| file size", len(blob), "| centroid block expected at", 64 + docs * bpr)

# digests
mp = open(R + "semantic-map.bin", "rb").read(64)
gen = open(SV + ".generation").read().strip()
shard_d = set()
for f in glob.glob(SV + "*.vec"):
    with open(f, "rb") as fh: h = fh.read(64)
    shard_d.add(h[16:48].hex())
print("digests: index", ix["provenanceDigest"][:16], "| binary", dig[:16], "| map", mp[20:52].hex()[:16], "| .generation", gen[:16], "| shards", [s[:16] for s in shard_d], "n shards", len(glob.glob(SV + "*.vec")))
print("all equal:", len({ix["provenanceDigest"], dig, mp[20:52].hex(), gen, *shard_d}) == 1)

popcount = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint8)
def ham_all(row):
    x = np.bitwise_xor(signs, signs[row])
    return popcount[x].sum(axis=1).astype(np.int32)
def neighbours(key, k):
    r = row_of[key]; d = ham_all(r); d[r] = 10**6
    order = np.lexsort((np.arange(docs), d))[:k]   # distance, then row order (stable)
    return [(int(d[i]), doc_of[i]) for i in order]

# shard cosine for a cross-check of the raw cosine
_sh = {}
def shard(v):
    if v not in _sh:
        b = open(SV + v + ".vec", "rb").read()
        mg = b[:4]; sver, sdims, n = struct.unpack("<III", b[4:16])
        assert mg == b"FRSS" and sdims == 512, (mg, sdims)
        codes = np.frombuffer(b, dtype=np.int8, count=n * 512, offset=64).reshape(n, 512).astype(np.float32)
        sc = np.frombuffer(b, dtype=np.float32, count=n, offset=64 + n * 512)
        assert len(b) == 64 + n * 512 + n * 4, (len(b), n)
        _sh[v] = (codes, sc)
    return _sh[v]
def vec_of(key):
    v = key[0]; base = next(x["r"] for x in ix["volumes"] if x["v"] == v)
    c, s = shard(v); r = row_of[key] - base
    return c[r] * s[r]
def cos(a, b):
    x, y = vec_of(a), vec_of(b); return float(x @ y / (np.linalg.norm(x) * np.linalg.norm(y)))

for anchor, k in ((("frus1943China", "d202"), 10), (("frus1969-76ve12", "d224"), 10), (("frus1969-76ve09p2", "d122"), 25)):
    print("\n## anchor %s/%s, top %d by Hamming over the bundle's sign bits (ties by row order)" % (anchor[0], anchor[1], k))
    for rank, (dist, key) in enumerate(neighbours(anchor, k), 1):
        c = cos(anchor, key)
        print("  %2d. ham %3d  %s/%s  raw_cos %.3f  calibrated %.0f%%" % (rank, dist, key[0], key[1], c, 100 * (c - 0.40) / 0.60))

# the specific distances the memo states
pairs = [(("frus1943China", "d202"), ("frus1948v07", "d590"), 67), (("frus1969-76ve12", "d224"), ("frus1969-76ve12", "d222"), 96),
         (("frus1969-76ve09p2", "d122"), ("frus1977-80v18", "d206"), 109), (("frus1969-76ve15p2", "d292"), ("frus1969-76ve15p2Ed2", "d292"), 0),
         (("frus1947v07", "d591"), ("frus1948v07", "d590"), 56)]
print("\n## stated pairwise distances")
for a, b, stated in pairs:
    d = int(popcount[np.bitwise_xor(signs[row_of[a]], signs[row_of[b]])].sum())
    print("  %s/%s - %s/%s: Hamming %d (memo %d) %s | raw cos %.3f" % (a[0], a[1], b[0], b[1], d, stated, "OK" if d == stated else "DIFFERS", cos(a, b)))

# baselines: random pairs with the memo's seed
import random
rnd = random.Random(1877); ds = []
for _ in range(20000):
    a = rnd.randrange(docs); b = rnd.randrange(docs)
    if a == b: continue
    ds.append(int(popcount[np.bitwise_xor(signs[a], signs[b])].sum()))
ds = np.array(ds)
print("\nrandom pairs (seed 1877): n", len(ds), "mean %.1f sd %.1f p1 %d min %d" % (ds.mean(), ds.std(), np.percentile(ds, 1), ds.min()))
rr = random.Random(7); sample = [rr.randrange(docs) for _ in range(200)]
k1 = []; k10 = []; k25 = []
for r in sample:
    d = ham_all(r); d[r] = 10**6; s = np.sort(d)[:25]; k1.append(s[0]); k10.append(s[9]); k25.append(s[24])
print("k-th neighbour over 200 docs (seed 7): 1st median %d (q %d,%d) | 10th median %d | 25th median %d (q %d,%d)" % (np.median(k1), np.percentile(k1, 25), np.percentile(k1, 75), np.median(k10), np.median(k25), np.percentile(k25, 25), np.percentile(k25, 75)))
