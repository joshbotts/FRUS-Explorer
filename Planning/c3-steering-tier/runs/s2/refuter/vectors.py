# Refuter: independent decode of the bundle's semantic-vectors index, the three provenance digests,
# and a re-run of the session's reported neighbour list for frus1961-63v22/d202 (and d131) from the
# bundle's binary; compare with vec_neighbours.json.
import json, struct, sqlite3
import numpy as np
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
SH = "/Users/jbotts/frus-analysis/c3/SemanticVectors"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s2"
idx = json.load(open(RES + "/semantic-vectors-index.json"))
blob = open(RES + "/semantic-vectors-binary.bin", "rb").read()
mp = open(RES + "/semantic-map.bin", "rb").read(64)
man = json.load(open(RES + "/semantic-shards-manifest.json"))
print("binary magic", blob[:4], "header <IIII at 4..20:", struct.unpack("<IIII", blob[4:20]), "len", len(blob))
ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
print("index documentCount", idx["documentCount"], "generated", idx["generated"], "volumes", len(idx["volumes"]))
d_index, d_bin, d_map, d_man = idx["provenanceDigest"], blob[20:52].hex(), mp[20:52].hex(), man["provenanceDigest"]
d_gen = open(SH + "/.generation").read().strip()
print("digest index   ", d_index)
print("digest binary  ", d_bin)
print("digest map     ", d_map)
print("digest manifest", d_man)
print("digest .generation", d_gen)
print("all equal:", len({d_index, d_bin, d_map, d_man, d_gen}) == 1)
print("map magic/header:", mp[:4], struct.unpack("<IIII", mp[4:20]))

# decode the id segments: each volume {v, n, r, seg:[{s,i,n}]}; row = r + offset; ids run d(base+k)
def numeric(did):
    s = did[1:]
    return int(s) if did.startswith("d") and s.isdigit() and not (len(s) > 1 and s[0] == "0") else None
row_of, doc_of = {}, {}
total = 0
for v in idx["volumes"]:
    ids = []
    for seg in v["seg"]:
        assert seg["s"] == len(ids), (v["v"], seg)
        base = numeric(seg["i"])
        for k in range(seg["n"]):
            ids.append(seg["i"] if k == 0 else "d%d" % (base + k))
    assert len(ids) == v["n"], (v["v"], len(ids), v["n"])
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k; doc_of[v["r"] + k] = (v["v"], d)
    total += v["n"]
print("decoded rows:", total, "== header docs:", total == docs, "; rows are 0..docs-1 contiguous:", sorted(doc_of) == list(range(docs)))

# the bits: rows of dims/64 big-endian u64 words from offset 64 (as the session read them); check the
# file length is consistent with that layout
words = dims // 64
expected_min = 64 + docs * words * 8
print("file length", len(blob), ">= 64 + docs*dims/8 =", expected_min, "->", len(blob) >= expected_min, "; remainder", len(blob) - expected_min, "(centroids etc.)")
bits = np.frombuffer(blob, dtype=">u8", count=docs * words, offset=64).reshape(docs, words)

# cross-check the row mapping against one per-volume shard: frus1961-63v22.vec
shard = open(SH + "/frus1961-63v22.vec", "rb").read()
print("shard header bytes 0..16:", shard[:16], struct.unpack("<IIII", shard[:16]) if len(shard) >= 16 else None, "len", len(shard))
v22 = [v for v in idx["volumes"] if v["v"] == "frus1961-63v22"][0]
print("frus1961-63v22 n", v22["n"], "r", v22["r"])
# try to locate the volume's first row bits inside the shard
first = bits[v22["r"]].tobytes()
pos = shard.find(first)
print("volume's first row bytes found in shard at offset:", pos)
if pos >= 0:
    sb = np.frombuffer(shard, dtype=">u8", count=v22["n"] * words, offset=pos).reshape(v22["n"], words)
    print("shard rows == binary rows r..r+n:", bool((sb == bits[v22["r"]:v22["r"] + v22["n"]]).all()))

ED2 = ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")
skip = np.array([doc_of[r][0] in ED2 for r in range(docs)])
def nearest(key, k=25):
    row = row_of[key]
    d = np.bitwise_count(bits ^ bits[row]).sum(axis=1).astype(np.int64)
    d[skip] = 1 << 20; d[row] = 1 << 20
    order = np.argsort(d, kind="stable")[:k]
    return [(int(d[r]), "/".join(doc_of[int(r)])) for r in order]

sess = json.load(open(RUN + "/vec_neighbours.json"))
for anchor in ("frus1961-63v22/d202", "frus1958-60v01/d131"):
    key = tuple(anchor.split("/"))
    mine = nearest(key)
    theirs = [(r[0], r[1]) for r in sess[anchor]]
    print(f"\n=== {anchor}: my nearest 25 vs the session's")
    same_order = [m[1] for m in mine] == [t[1] for t in theirs]
    same_set = {m[1] for m in mine} == {t[1] for t in theirs}
    same_dist = [m[0] for m in mine] == [t[0] for t in theirs]
    print("   same ids in the same order:", same_order, "; same set:", same_set, "; same distances:", same_dist)
    for m, t in zip(mine, theirs):
        print(f"   {m[0]:4d} {m[1]:28s} | session {t[0]:4d} {t[1]}")

# the baselines the session reports: random pairs seed 1877, 25th-neighbour seed 1878 (re-run)
import random, statistics
rng = random.Random(1877)
pairs = [int(np.bitwise_count(bits[rng.randrange(docs)] ^ bits[rng.randrange(docs)]).sum()) for _ in range(20000)]
mean, sd = statistics.mean(pairs), statistics.pstdev(pairs)
print(f"\nrandom pairs (20000, seed 1877): mean {mean:.1f} sd {sd:.1f} 1st pct {sorted(pairs)[len(pairs)//100]}  line mean-8sd = {mean-8*sd:.1f}")
kth = sorted(int(np.sort((np.bitwise_count(bits ^ bits[r]).sum(axis=1)))[25])  # index 25 skips self (distance 0 at index 0)
             for r in random.Random(1878).sample(range(docs), 200))
print(f"25th-neighbour (self excluded) over 200 random docs (seed 1878): min {kth[0]} p10 {kth[20]} median {kth[100]} p90 {kth[180]}")
kth_s = sorted(int(np.sort(np.where(skip, 1 << 20, np.bitwise_count(bits ^ bits[r]).sum(axis=1)))[24]) for r in random.Random(1878).sample(range(docs), 200))
print(f"session's form (index 24 of a sort that keeps self at 0): min {kth_s[0]} p10 {kth_s[20]} median {kth_s[100]} p90 {kth_s[180]}")
# the d202 -> d204 distance
a, b = row_of[("frus1961-63v22", "d202")], row_of[("frus1961-63v22", "d204")]
print("Hamming d202-d204:", int(np.bitwise_count(bits[a] ^ bits[b]).sum()))
# near-duplicate check over the 19 cited pairs (the session ran it over 18)
cited = [tuple(l.strip().split("/")) for l in open(RUN + "/cited.txt") if l.strip()]
rs = [row_of[k] for k in cited]
line = mean - 8 * sd
nd = []
for i in range(len(rs)):
    for j in range(i + 1, len(rs)):
        h = int(np.bitwise_count(bits[rs[i]] ^ bits[rs[j]]).sum())
        if h < line: nd.append((h, cited[i], cited[j]))
print("cited pairs:", len(cited), "all have a vector row:", all(k in row_of for k in cited), "near-duplicates under the line among the 19:", nd)
# d204's nearest in the cited set
dd = [(int(np.bitwise_count(bits[b] ^ bits[r]).sum()), "/".join(doc_of[r])) for r in rs if r != b]
print("d204 nearest in cited set:", min(dd))
