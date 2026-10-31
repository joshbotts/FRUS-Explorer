# Refuter's independent re-run of one neighbour list from the bundle's binary.
# Decode written from the index's own layout (volumes[].v, .r, .n, .seg[].{i,s,n}): row r+s+k holds document i incremented by k.
import json, struct, sys
import numpy as np
B = "/Applications/FRUS Explorer.app/Contents/Resources/"
idx = json.load(open(B + "semantic-vectors-index.json"))
blob = open(B + "semantic-vectors-binary.bin", "rb").read()
magic = blob[:4]; ver, dims, ndocs, ncent = struct.unpack("<IIII", blob[4:20]); dig_bin = blob[20:52].hex()
mp = open(B + "semantic-map.bin", "rb").read(64)
print("binary magic", magic, "version", ver, "dims", dims, "docs", ndocs, "centroids", ncent)
print("index documentCount", idx["documentCount"], "shippingDims", idx["provenance"]["shippingDims"])
print("digest index :", idx["provenanceDigest"])
print("digest binary:", dig_bin)
print("digest map   :", mp[20:52].hex(), "(map header magic", mp[:4], ")")
sh = open("/Users/jbotts/frus-analysis/c3/SemanticVectors/frus1917-72PubDipv08.vec", "rb").read(64)
print("shard header bytes 0..64:", sh.hex())
print("digest shard (bytes 16..48):", sh[16:48].hex())
print("ALL EQUAL:", len({idx["provenanceDigest"].lower(), dig_bin, mp[20:52].hex(), sh[16:48].hex()}) == 1)

# decode
suffixed = 0
def inc(doc, k):
    global suffixed
    if k == 0:
        return doc                      # the run's first id is stored verbatim (suffixed ids such as d373a occur only in runs of length 1)
    m = __import__("re").match(r"^(d)(\d+)$", doc)
    if not m: raise ValueError(("a run longer than 1 starts at a non-numeric id", doc, k))
    return f"d{int(m.group(2)) + k}"
row_of = {}; doc_of = {}
rows_total = 0
for v in idx["volumes"]:
    ids = []
    for seg in v["seg"]:
        if seg["s"] != len(ids): raise ValueError(("segment offset mismatch", v["v"], seg))
        ids.extend(inc(seg["i"], k) for k in range(seg["n"]))
    if len(ids) != v["n"]: raise ValueError(("count mismatch", v["v"], len(ids), v["n"]))
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k; doc_of[v["r"] + k] = (v["v"], d)
    rows_total += v["n"]
print("rows decoded", rows_total, "== documentCount:", rows_total == idx["documentCount"], "; distinct rows", len(doc_of), "; volumes", len(idx["volumes"]))
# rows must tile 0..ndocs-1
print("rows tile 0..N-1:", set(doc_of) == set(range(ndocs)))

bpr = dims // 8
S = np.frombuffer(blob, dtype=np.uint8, count=ndocs * bpr, offset=64).reshape(ndocs, bpr)
print("bytes after header consumed by rows:", 64 + ndocs * bpr, "of", len(blob), "(remainder", len(blob) - 64 - ndocs * bpr, "bytes = centroids etc.)")
POP = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint8)
def ham_all(r):
    return POP[np.bitwise_xor(S, S[r])].sum(axis=1)

for a in sys.argv[1:]:
    v, d = a.split("/")
    r = row_of[(v, d)]
    h = ham_all(r)
    order = np.argsort(h, kind="stable")
    print(f"\nANCHOR {a} (row {r}); top 12 by Hamming over {dims} sign bits:")
    n = 0
    for o in order:
        if o == r: continue
        print(f"   {int(h[o]):3d}  {doc_of[int(o)][0]}/{doc_of[int(o)][1]}"); n += 1
        if n == 12: break
