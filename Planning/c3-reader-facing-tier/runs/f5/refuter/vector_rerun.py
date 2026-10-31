# vector_rerun.py: independent decode of semantic-vectors-index.json segments, digest comparison, and a re-run of
# the session's first neighbour list (anchor frus1964-68v01/d122) from the bundle's binary: Hamming over the sign
# bits, then the top-800 reranked by int8 cosine from the shards, as nn.py describes. Also the map figures.
import json, struct, sqlite3, numpy as np, hashlib
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
SH = "/Users/jbotts/frus-analysis/c3/SemanticVectors/"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c = sqlite3.connect(DB, uri=True)
idx = json.load(open(R + "semantic-vectors-index.json"))
print("index keys:", list(idx.keys()))
print("documentCount", idx["documentCount"], "dimensions", idx.get("dimensions"), "generated", idx.get("generated"), "model", idx.get("model"), "provenanceDigest", idx.get("provenanceDigest"))
print("retrieval:", idx.get("retrieval"))

def decode(segs):
    ids = []
    for sg in segs:
        assert sg["s"] == len(ids), ("segment start mismatch", sg)
        ids.append(sg["i"])
        if sg["n"] > 1:
            s = sg["i"][1:]
            assert s.isdigit() and not (len(s) > 1 and s[0] == '0'), sg["i"]
            b = int(s)
            ids.extend(f"d{b+k}" for k in range(1, sg["n"]))
    return ids
row_of = {}; doc_of = [None] * idx["documentCount"]; vol_rows = {}
for v in idx["volumes"]:
    ids = decode(v["seg"]); assert len(ids) == v["n"], v["v"]
    vol_rows[v["v"]] = (v["r"], v["n"])
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k; doc_of[v["r"] + k] = (v["v"], d)
assert all(x is not None for x in doc_of), "gaps in the row space"
print("decoded rows:", len(row_of), "volumes:", len(vol_rows))
# identity check: every decoded (volume, id) exists in document_cache? (sample all; it is one indexed lookup each)
missing = 0
for (v, d) in list(row_of)[:: max(1, len(row_of) // 20000)]:
    if c.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?", [v, d]).fetchone() is None: missing += 1
print("sampled ids absent from document_cache:", missing)

blob = np.fromfile(R + "semantic-vectors-binary.bin", dtype=np.uint8)
magic = blob[:4].tobytes(); ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20].tobytes())
digest_bin = blob[20:52].tobytes().hex()
print("binary magic", magic, "ver", ver, "dims", dims, "docs", docs, "cents", cents, "digest", digest_bin)
m = np.fromfile(R + "semantic-map.bin", dtype=np.uint8)
print("map digest at 20:", m[20:52].tobytes().hex())
mi = json.load(open(R + "semantic-map-index.json"))
print("map-index provenanceDigest:", mi.get("provenanceDigest"), "clusters:", len(mi.get("clusters", [])), "documentCount:", mi.get("documentCount"))
# shards: header digest at 16
import os
sh_ok = sh_bad = 0
for fn in sorted(os.listdir(SH)):
    if not fn.endswith(".vec"): continue
    b = np.fromfile(SH + fn, dtype=np.uint8, count=64)
    (b[16:48].tobytes().hex() == digest_bin and (sh_ok := sh_ok + 1)) or (sh_bad := sh_bad + 1)
print("shards matching the binary's digest:", sh_ok, "mismatching:", sh_bad)
print("three digests equal (index == binary == map):", idx["provenanceDigest"] == digest_bin == m[20:52].tobytes().hex())

bpr = dims // 8
signs = blob[64:64 + docs * bpr].reshape(docs, bpr)
def shard(vol):
    b = np.fromfile(SH + vol + ".vec", dtype=np.uint8)
    ver, d, n = struct.unpack("<III", b[4:16].tobytes())
    codes = b[64:64 + n * d].reshape(n, d).view(np.int8)
    scales = b[64 + n * d:64 + n * d + n * 4].copy().view(np.float32)
    return codes, scales
_sh = {}
def vecof(row):
    v, d = doc_of[row]; r0, n = vol_rows[v]
    if v not in _sh: _sh[v] = shard(v)
    codes, sc = _sh[v]
    return codes[row - r0].astype(np.float32) * sc[row - r0]

def rerun(anchor, k=10, pool=800):
    row = row_of[anchor]
    h = np.bitwise_count(signs ^ signs[row]).sum(axis=1).astype(np.int32); h[row] = 9999
    cand = np.argsort(h, kind='stable')[:pool]
    a = vecof(row)
    cs = np.array([float(np.dot(a, vecof(int(r)))) for r in cand])
    order = np.argsort(-cs, kind='stable')[:k]
    return [(doc_of[int(cand[i])], int(h[cand[i]]), round(float(cs[i]), 3), round((cs[i] - 0.40) / 0.60, 3)) for i in order], h

print("\n== RE-RUN: nearest neighbours of frus1964-68v01/d122 (compare nn_run1.txt) ==")
out, h = rerun(("frus1964-68v01", "d122"))
for (v, d), hm, cs, cal in out: print(f"  ham {hm:3d} cos_raw {cs:.3f} cal {cal:.3f} {v}/{d}")
print("  Hamming-only top 10:", [(doc_of[int(i)], int(h[i])) for i in np.argsort(h, kind='stable')[:10]])
session = ["frus1917-72PubDipv07/d13", "frus1917-72PubDipv07/d37", "frus1917-72PubDipv07/d16", "frus1964-68v01/d177", "frus1964-68v02/d160", "frus1964-68v01/d197", "frus1917-72PubDipv07/d32", "frus1917-72PubDipv07/d78", "frus1917-72PubDipv07/d157", "frus1964-68v01/d127"]
mine = [f"{v}/{d}" for (v, d), _, _, _ in out]
print("  reproduces the session's list in order:", mine == session)
print("  as a set:", set(mine) == set(session))

print("\n== RE-RUN: nearest neighbours of frus1917-72PubDipv08/d31 (the list that surfaced d99) ==")
out, _ = rerun(("frus1917-72PubDipv08", "d31"))
for (v, d), hm, cs, cal in out: print(f"  ham {hm:3d} cos_raw {cs:.3f} cal {cal:.3f} {v}/{d}")
print("\n== RE-RUN: nearest neighbours of frus1969-76v38p2/d105 (the list that surfaced d104) ==")
out, _ = rerun(("frus1969-76v38p2", "d105"))
for (v, d), hm, cs, cal in out: print(f"  ham {hm:3d} cos_raw {cs:.3f} cal {cal:.3f} {v}/{d}")

print("\n== MAP: the 31 collection documents ==")
col = json.load(open("/Users/jbotts/frus-analysis/c3f/runs/f5/collection.fruscollection"))
SET = [(e['volumeId'], e['documentId']) for e in col['entries'] if e['kind'] == 'document']
pl = m[64:64 + docs * 6].reshape(docs, 6); cl = pl[:, 4:6].copy().view(np.uint16).reshape(-1)
unc = sum(1 for v, d in SET if cl[row_of[(v, d)]] == 0xFFFF)
print("  unclustered among the 31:", unc, "of", len(SET), "| corpus-wide unclustered:", int((cl == 0xFFFF).sum()), "of", docs)
man = json.load(open(R + "manifest.json"))
yr = {v['volumeId']: (int(v['dateRange']['earliest'][:4]) + int(v['dateRange']['latest'][:4])) // 2 for v in man}
tot = un = 0
for v, (r0, n) in vol_rows.items():
    if v in yr and 1945 <= yr[v] <= 1980: tot += n; un += int((cl[r0:r0 + n] == 0xFFFF).sum())
print("  era-matched baseline 1945-1980 by mean year: unclustered", un, "of", tot)

print("\n== NEAR-DUPLICATES claimed ==")
for a, b, claimed in [(("frus1964-68v01", "d122"), ("frus1917-72PubDipv07", "d13"), 45), (("frus1964-68v01", "d177"), ("frus1917-72PubDipv07", "d16"), 37), (("frus1961-63v04", "d81"), ("frus1917-72PubDipv06", "d140"), 53), (("frus1955-57v22", "d484"), ("frus1958-60v15", "d548"), 63), (("frus1955-57v09", "d190"), ("frus1955-57v09", "d185"), 32), (("frus1949v07p2", "d386"), ("frus1951v06p1", "d12"), 49)]:
    hm = int(np.bitwise_count(signs[row_of[a]] ^ signs[row_of[b]]).sum())
    print(f"  {a[0]}/{a[1]} vs {b[0]}/{b[1]}: Hamming {hm} (claimed {claimed}) {'OK' if hm == claimed else 'DIFFERS'}")

print("\n== BASELINE spot check: random pairs (own seed) ==")
rng = np.random.default_rng(7)
ii = rng.integers(0, docs, 20000); jj = rng.integers(0, docs, 20000)
hh = np.bitwise_count(signs[ii] ^ signs[jj]).sum(axis=1)
print("  mean", round(float(hh.mean()), 1), "sd", round(float(hh.std()), 1), "p1", int(np.percentile(hh, 1)), "min", int(hh.min()), "(session: 167.1, 14.8, 132, 95)")
