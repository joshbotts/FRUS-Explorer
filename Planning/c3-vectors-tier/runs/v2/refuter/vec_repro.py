# Independent decode of the bundle's semantic-vector artifacts (no import of the session's veclib) and a re-run of the
# session's reported neighbour lists for frus1961-63v10/d202 and frus1881/d405 by Hamming distance over the sign block.
import json, struct, os, hashlib
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
SH = "/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx = json.load(open(R + "semantic-vectors-index.json"))
print("index keys:", sorted(idx.keys()))
print("index provenanceDigest:", idx.get("provenanceDigest"), "| generated:", idx.get("generated"), "| harvestGenerated:", idx.get("harvestGenerated"))
print("retrieval:", json.dumps(idx.get("retrieval"))[:300])
print("first volume entry:", json.dumps(idx["volumes"][0])[:300])
# --- decode the run-length id segments: each seg {s: first row offset within volume, i: first id, n: run length}
def expand(seg):
    first = seg["i"]; n = seg["n"]
    if n == 1: return [first]
    assert first.startswith("d") and first[1:].isdigit(), seg
    base = int(first[1:]); return [f"d{base + k}" for k in range(n)]
rows = []; row_of = {}; vol_centroid_index = {}
for vi, v in enumerate(idx["volumes"]):
    ids = []
    for seg in v["seg"]:
        assert seg["s"] == len(ids), (v["v"], seg)
        ids += expand(seg)
    assert len(ids) == v["n"], (v["v"], len(ids), v["n"])
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k; rows.append((v["v"], d))
    vol_centroid_index[v["v"]] = vi
print("volumes", len(idx["volumes"]), "rows decoded", len(rows), "distinct", len(row_of))
assert [row_of[k] for k in rows] == list(range(len(rows))), "rows are not contiguous from 0"
B = open(R + "semantic-vectors-binary.bin", "rb").read()
print("binary magic", B[:4], "size", len(B))
ver, dims, docs, cents = struct.unpack("<IIII", B[4:20]); bpr = dims // 8
print("version", ver, "dims", dims, "docs", docs, "centroids", cents, "bytes/row", bpr)
print("binary digest (bytes 20..52):", B[20:52].hex())
print("layout check: 64 + docs*bpr + cents*(dims+4) =", 64 + docs * bpr + cents * (dims + 4), "file size", len(B), "diff", len(B) - (64 + docs * bpr + cents * (dims + 4)))
assert docs == len(rows)
M = open(R + "semantic-map.bin", "rb").read(); print("map magic", M[:4], "map digest (20..52):", M[20:52].hex(), "map size", len(M), "64+6*docs =", 64 + 6 * docs)
print("shard folder .generation:", open(SH + ".generation").read().strip()[:80], "| shard files:", len([f for f in os.listdir(SH) if f.endswith(".vec")]))
print("sha256 of semantic-vectors-binary.bin:", hashlib.sha256(B).hexdigest())
signs = [int.from_bytes(B[64 + r * bpr: 64 + (r + 1) * bpr], "big") for r in range(docs)]
def neighbours(v, d, k=15):
    a = signs[row_of[(v, d)]]; ar = row_of[(v, d)]
    ds = sorted((bin(a ^ s).count("1"), r) for r, s in enumerate(signs) if r != ar)
    return ds[:k], ds[24][0]
for v, d in [("frus1961-63v10", "d202"), ("frus1881", "d405")]:
    top, k25 = neighbours(v, d)
    print(f"\n== anchor {v}/{d} row {row_of[(v, d)]}; 25th-neighbour distance {k25}")
    for h, r in top: print("  ", h, "/".join(rows[r]))
print("\nfrus1898/ch83 in index:", ("frus1898", "ch83") in row_of, "| frus1969-76ve10/d205 row:", row_of.get(("frus1969-76ve10", "d205")))
# near-duplicate pairs the memo names
for a, b in [(("frus1881","d405"),("frus1894app2","d394")), (("frus1969-76v12","d211"),("frus1969-76ve10","d225")), (("frus1969-76v12","d212"),("frus1969-76ve10","d225")), (("frus1865p2","d33"),("frus1865p2","d647"))]:
    print("hamming", "/".join(a), "/".join(b), bin(signs[row_of[a]] ^ signs[row_of[b]]).count("1"))
