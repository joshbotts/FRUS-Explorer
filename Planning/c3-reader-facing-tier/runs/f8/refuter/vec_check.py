"""Independent re-run of one neighbour list from the bundle's binary.
Decode of the index's segments (A.3 shape: each volume has rows r..r+n-1; a segment {i,n,s}
names ids i, i+1, ... for n rows starting at local offset s), sign bits at byte 64, dims/8 bytes a row,
Hamming over the 512 sign bits."""
import json, struct, hashlib, numpy as np, sqlite3
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
idx = json.load(open(R + "semantic-vectors-index.json"))
blob = open(R + "semantic-vectors-binary.bin", "rb").read()
print("magic", blob[:4], "header", struct.unpack("<IIII", blob[4:20]))
ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
print("index documentCount", idx["documentCount"], "binary docs", docs)
print("digest index", idx["provenanceDigest"])
print("digest bin  ", blob[20:52].hex())
mp = open(R + "semantic-map.bin", "rb").read()
print("digest map  ", mp[20:52].hex(), "map magic", mp[:4])
print("sha256 of binary file", hashlib.sha256(blob).hexdigest())
bpr = dims // 8
print("file size", len(blob), "expected sign block", 64 + docs * bpr, "remaining", len(blob) - 64 - docs * bpr, "(centroids: %d x %d bytes = %d)" % (cents, bpr, cents*bpr))

def ids_of(v):
    out = []
    for s in v["seg"]:
        assert s["s"] == len(out), (v["v"], s)
        base = s["i"]
        out.append(base)
        if s["n"] > 1:
            m = base[1:]
            assert base.startswith("d") and m.isdigit(), (v["v"], s)
            out.extend("d%d" % (int(m) + k) for k in range(1, s["n"]))
    assert len(out) == v["n"], (v["v"], len(out), v["n"])
    return out

row_of = {}; doc_of = {}
for v in idx["volumes"]:
    for k, i in enumerate(ids_of(v)):
        row_of[(v["v"], i)] = v["r"] + k
        doc_of[v["r"] + k] = (v["v"], i)
print("volumes decoded", len(idx["volumes"]), "rows", len(row_of))
S = np.frombuffer(blob, dtype=np.uint8, count=docs * bpr, offset=64).reshape(docs, bpr)
# popcount table (no np.bitwise_count dependency)
POP = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint8)
def ham(row):
    return POP[np.bitwise_xor(S, S[row])].sum(axis=1, dtype=np.int32)

c = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for anchor in ["frus1917-72PubDipv08/d31", "frus1969-76v38p2/d105"]:
    v, d = anchor.split("/")
    r = row_of[(v, d)]
    h = ham(r)
    order = np.argsort(h, kind="stable")
    print("== anchor", anchor, "row", r, "self distance", int(h[r]))
    n = 0
    for o in order:
        if o == r: continue
        vv, di = doc_of[int(o)]
        hd = c.execute("SELECT substr(header,1,70), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (vv, di)).fetchone()
        print(int(h[o]), f"{vv}/{di}", hd)
        n += 1
        if n >= 12: break
