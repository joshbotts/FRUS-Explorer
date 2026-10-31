# Independent decode of the bundle's binary: no import of the session's vec.py.
import json, struct, re, sys
import numpy as np
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
idx = json.load(open(RES + "semantic-vectors-index.json"))
blob = open(RES + "semantic-vectors-binary.bin", "rb").read()
assert blob[:4] == b"FRSV", blob[:4]
ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
digest_bin = blob[20:52].hex()
print("binary header:", ver, dims, docs, cents, "digest", digest_bin)
print("index digest:", idx["provenanceDigest"], "equal:", idx["provenanceDigest"] == digest_bin)
print("map digest:", open(RES + "semantic-map.bin", "rb").read(52)[20:52].hex())
print("shards manifest digest:", json.load(open(RES + "semantic-shards-manifest.json"))["provenanceDigest"])
print(".generation:", open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read().strip())
sh = open("/Users/jbotts/frus-analysis/c3/SemanticVectors/frus1964-68v05.vec", "rb").read(64)
print("one shard header bytes 0-16:", sh[:16], "bytes 16-48:", sh[16:48].hex())

# decode the id segments: each volume has base row r, n rows, and segments (s = start within the volume, i = first id, n = run length)
row_of, doc_of = {}, {}
for v in idx["volumes"]:
    ids = []
    for seg in v["seg"]:
        assert seg["s"] == len(ids), (v["v"], seg)
        first = seg["i"]
        ids.append(first)
        if seg["n"] > 1:
            m = re.fullmatch(r"d([1-9]\d*)", first)
            assert m, (v["v"], first)
            base = int(m.group(1))
            ids += [f"d{base + k}" for k in range(1, seg["n"])]
    assert len(ids) == v["n"], (v["v"], len(ids), v["n"])
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k
        doc_of[v["r"] + k] = (v["v"], d)
print("volumes:", len(idx["volumes"]), "rows mapped:", len(row_of), "== docs:", len(row_of) == docs, "max row+1:", max(doc_of) + 1)
bytes_per = dims // 8
bits = np.frombuffer(blob, dtype=np.uint8, count=docs * bytes_per, offset=64).reshape(docs, bytes_per)
ED2 = ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")
skip = np.array([doc_of[r][0] in ED2 for r in range(docs)])
POP = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint8)
def dist_all(row):
    x = np.bitwise_xor(bits, bits[row])
    d = POP[x].sum(axis=1).astype(np.int64)
    d[skip] = 1 << 20; d[row] = 1 << 20
    return d
def nearest(key, k=25):
    d = dist_all(row_of[key])
    order = np.argsort(d, kind="stable")[:k]
    return [(int(d[r]), doc_of[int(r)]) for r in order]

# parse the session's reported lists
out = open("/Users/jbotts/frus-analysis/c3s/runs/s4/vec_neighbors.out").read()
blocks = re.split(r"\n### ANCHOR ", out)[1:]
theirs = {}
for b in blocks:
    head, *rows = b.strip().split("\n")
    m = re.search(r"\('([^']+)', '([^']+)'\)", head)
    anchor = (m.group(1), m.group(2))
    lst = []
    for r in rows:
        mm = re.match(r"(\d+) (\S+)/(\S+) ", r)
        if mm: lst.append((int(mm.group(1)), (mm.group(2), mm.group(3))))
    theirs[anchor] = lst
for anchor in [("frus1922v01", "d864"), ("frus1947v07", "d582"), ("frus1969-76ve09p2", "d161")]:
    mine = nearest(anchor)
    t = theirs.get(anchor)
    same_set = {x[1] for x in mine} == {x[1] for x in t}
    same_order = mine == t
    print(f"\nANCHOR {anchor}: my 25 == session's 25 as a set: {same_set}; identical order and distances: {same_order}")
    if not same_order:
        for a, b in zip(mine, t):
            if a != b: print("  differs:", a, "vs", b)
    print("  my list:", [(h, f"{v}/{d}") for h, (v, d) in mine])
# the d872 distance
a = row_of[("frus1922v01", "d864")]; b = row_of[("frus1922v01", "d872")]
print("\nHamming(frus1922v01/d864, d872) =", int(POP[np.bitwise_xor(bits[a], bits[b])].sum()))
# baseline: random pairs with the session's seed, and the collection set's nearest neighbours
import random, statistics
rng = random.Random(1877)
pairs = [int(POP[np.bitwise_xor(bits[rng.randrange(docs)], bits[rng.randrange(docs)])].sum()) for _ in range(20000)]
print("random pairs seed 1877 n=20000: mean %.2f sd %.2f 1st pct %d; mean-8sd %.2f" % (statistics.mean(pairs), statistics.pstdev(pairs), sorted(pairs)[200], statistics.mean(pairs) - 8 * statistics.pstdev(pairs)))
coll = json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s4/collection.fruscollection"))
cd = [(e["volumeId"], e["documentId"]) for e in coll["entries"] if e["kind"] == "document"]
rows = [row_of[k] for k in cd]
nn = []
for k in cd:
    r = row_of[k]
    d = POP[np.bitwise_xor(bits[rows], bits[r])].sum(axis=1).astype(int)
    d[rows.index(r)] = 1 << 20
    j = int(np.argmin(d)); nn.append((int(d[j]), k, cd[j]))
nn.sort()
print("collection set (35): NN distances min %d median %d max %d; closest:" % (nn[0][0], nn[len(nn) // 2][0], nn[-1][0]), nn[:3])
# Ed2 twins of d292/d293
for d in ("d292", "d293"):
    a = row_of[("frus1969-76ve15p2", d)]; b = row_of[("frus1969-76ve15p2Ed2", d)]
    print(f"Hamming(ve15p2/{d}, Ed2/{d}) =", int(POP[np.bitwise_xor(bits[a], bits[b])].sum()))
