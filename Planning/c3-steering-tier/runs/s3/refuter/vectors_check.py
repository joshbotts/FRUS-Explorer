"""Refuter step 6: independent decode of the bundle's binary and a re-run of the session's neighbour lists.
Decode of the index (its run-length segments): each volume entry gives its first row r, its count n and
segments {s: row offset within the volume, i: the first document id, n: the run length}; a run of n > 1
names d<base+k> for k < n. Row k of the binary (offset 64 + 64*k) holds document k's 512 sign bits.
"""
import json, struct, sys
import numpy as np
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
SV = "/Users/jbotts/frus-analysis/c3/SemanticVectors"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s3/"

idx = json.load(open(RES + "/semantic-vectors-index.json"))
blob = open(RES + "/semantic-vectors-binary.bin", "rb").read()
magic = blob[:4]; ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
print("binary magic", magic, "version", ver, "dims", dims, "docs", docs, "centroids", cents, "size", len(blob), "= 64 + docs*64 + cents*516 ->", 64 + docs * 64 + cents * 516)

# three provenance digests the guide names: the index's, the binary's, the map's; plus the shards manifest, one shard and the folder's generation
d_index = idx["provenanceDigest"]; d_bin = blob[20:52].hex(); d_map = open(RES + "/semantic-map.bin", "rb").read(52)[20:52].hex()
d_man = json.load(open(RES + "/semantic-shards-manifest.json"))["provenanceDigest"]
d_shard = open(SV + "/frus1947v07.vec", "rb").read(48)[16:48].hex(); d_gen = open(SV + "/.generation").read().strip()
print("digests: index", d_index[:16], "binary", d_bin[:16], "map", d_map[:16], "shards-manifest", d_man[:16], "shard frus1947v07", d_shard[:16], ".generation", d_gen[:16])
print("all six agree:", len({d_index, d_bin, d_map, d_man, d_shard, d_gen}) == 1, "| memo's digest:", "89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101" == d_index)

# independent decode
row_of = {}; doc_of = {}
for v in idx["volumes"]:
    ids = []
    for seg in v["seg"]:
        assert seg["s"] == len(ids), (v["v"], seg)
        first = seg["i"]; ids.append(first)
        if seg["n"] > 1:
            assert first[0] == "d" and first[1:].isdigit(), (v["v"], seg)
            base = int(first[1:]); ids += ["d%d" % (base + k) for k in range(1, seg["n"])]
    assert len(ids) == v["n"], (v["v"], len(ids), v["n"])
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k; doc_of[v["r"] + k] = (v["v"], d)
print("decoded rows", len(row_of), "volumes", len(idx["volumes"]), "| header docs", docs, "| rows contiguous 0..n-1:", sorted(doc_of) == list(range(docs)))

bits = np.frombuffer(blob, dtype=np.uint8, count=docs * (dims // 8), offset=64).reshape(docs, dims // 8)
popc = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint8)
ED2 = ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")
skip = np.array([doc_of[r][0] in ED2 for r in range(docs)])

def nearest(key, k=25):
    r = row_of[key]
    d = popc[np.bitwise_xor(bits, bits[r])].sum(axis=1).astype(np.int64)
    d[r] = 1 << 20; d[skip] = 1 << 20
    order = np.argsort(d, kind="stable")[:k]
    return [(int(d[i]), doc_of[int(i)]) for i in order]

reported = json.load(open(RUN + "vectors_out.json"))["neighbours"]
for key in [("frus1922v01", "d841"), ("frus1969-76ve09p2", "d122"), ("frus1947v07", "d583"), ("frus1969-76ve11p1", "d159")]:
    mine = nearest(key)
    rep = [(int(r[0]), tuple(r[1])) for r in reported["%s/%s" % key]]
    same = [m == r for m, r in zip(mine, rep)]
    print("\nANCHOR", key, "row", row_of[key], "| 25 of 25 identical (distance and pair, in order):", all(same), sum(same))
    for (dm, km), (dr, kr) in zip(mine, rep):
        flag = "" if (dm, km) == (dr, kr) else "   <-- differs from the session's %s %s" % (dr, kr)
        print("  ", dm, "%s/%s" % km, flag)
    if key == ("frus1969-76ve09p2", "d122"):
        hit = [(h, k) for h, k in mine if k == ("frus1969-76ve09p2", "d155")]
        print("  d155 in the 25 nearest of d122:", hit)

# the baselines, re-drawn with the session's seeds and procedure (random.Random(1877) pairs; Random(1878) 25th-neighbour rows)
import random, statistics
rng = random.Random(1877)
pairs = []
for _ in range(20000):
    a = rng.randrange(docs); b = rng.randrange(docs)
    pairs.append(int(popc[np.bitwise_xor(bits[a], bits[b])].sum()))
mean, sd = statistics.mean(pairs), statistics.pstdev(pairs); first = sorted(pairs)[len(pairs) // 100]
print("\nrandom pairs (seed 1877): mean %.1f sd %.1f 1st pct %d | memo: 167.1, 14.8, 132 | near-dup line mean-8sd = %.1f (memo 49.0)" % (mean, sd, first, mean - 8 * sd))
rows = random.Random(1878).sample(range(docs), 200)
kth = []
for r in rows:
    d = popc[np.bitwise_xor(bits, bits[r])].sum(axis=1).astype(np.int64); d[r] = 1 << 20; d[skip] = 1 << 20
    kth.append(int(np.sort(d)[24]))
kth.sort()
print("25th-neighbour over 200 random rows (seed 1878): min %d p10 %d median %d p90 %d | memo: 73, 93, 107, 119" % (kth[0], kth[20], kth[100], kth[180]))
