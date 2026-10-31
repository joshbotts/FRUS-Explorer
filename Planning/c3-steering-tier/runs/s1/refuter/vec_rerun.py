import json, struct, os, hashlib, re, sqlite3
import numpy as np
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
SH = "/Users/jbotts/frus-analysis/c3/SemanticVectors"
idx = json.load(open(RES + "/semantic-vectors-index.json"))
print("index top keys:", list(idx.keys()))
print("one volume entry (keys):", {k: (v if not isinstance(v, list) else f"list[{len(v)}] first={v[0]}") for k, v in idx["volumes"][0].items()})
for k in ("provenanceDigest", "generated", "harvestGenerated", "documentCount", "dimensions", "dims"):
    if k in idx:
        print(k, "=", idx[k])
if "retrieval" in idx:
    print("retrieval:", {k: idx["retrieval"][k] for k in idx["retrieval"] if k != "scoreCalibration"})
    print("scoreCalibration:", {k: v for k, v in idx["retrieval"].get("scoreCalibration", {}).items() if k != "measuredBy"})
if "provenance" in idx:
    print("provenance:", {k: v for k, v in idx["provenance"].items() if isinstance(v, (str, int, float))})
# binary header
blob = open(RES + "/semantic-vectors-binary.bin", "rb").read()
print("binary size:", len(blob), "magic:", blob[:4])
ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
print("header: version", ver, "dims", dims, "docs", docs, "centroids", cents)
print("64 + docs*dims/8 =", 64 + docs * dims // 8, "; + centroids*dims/8 =", 64 + docs * dims // 8 + cents * dims // 8)
dig_bin = blob[20:52].hex()
dig_map = open(RES + "/semantic-map.bin", "rb").read(52)[20:52].hex()
dig_man = json.load(open(RES + "/semantic-shards-manifest.json"))["provenanceDigest"]
dig_gen = open(SH + "/.generation").read().strip()
print("digests: index", idx["provenanceDigest"]); print("         binary", dig_bin); print("         map   ", dig_map); print("         shards manifest", dig_man); print("         .generation", dig_gen)
print("all agree:", len({idx["provenanceDigest"], dig_bin, dig_map, dig_man, dig_gen}) == 1)

# my own decode of the run-length id encoding (seg: s = start offset in the volume, i = first id, n = run length)
row_of, doc_of = {}, {}
for v in idx["volumes"]:
    ids = []
    for seg in v["seg"]:
        assert seg["s"] == len(ids), (v["v"], seg)
        first = seg["i"]
        ids.append(first)
        if seg["n"] > 1:
            mm = re.fullmatch(r"d(\d+)", first)
            assert mm, (v["v"], first, "a run must start with a plain d<number> id")
            b = int(mm.group(1))
            ids.extend("d%d" % (b + k) for k in range(1, seg["n"]))
    assert len(ids) == v["n"], (v["v"], len(ids), v["n"])
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k
        doc_of[v["r"] + k] = (v["v"], d)
print("rows decoded:", len(row_of), "== header docs:", len(row_of) == docs, "| rows are 0..docs-1 contiguous:", sorted(doc_of) == list(range(docs)))
# sanity: ids decoded for a volume match document_cache's ids for that volume
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for vol in ("frus1950v06", "frus1964-68v05", "frus1969-76ve12"):
    dbids = {d for (d,) in con.execute("SELECT document_id FROM document_cache WHERE volume_id=?", (vol,))}
    vids = {d for (vv, d) in row_of if vv == vol}
    print(vol, "index ids", len(vids), "db ids", len(dbids), "| index-not-db:", sorted(vids - dbids)[:5], "| db-not-index:", sorted(dbids - vids)[:5])

rowbytes = dims // 8
bits = np.frombuffer(blob, dtype=np.uint8, count=docs * rowbytes, offset=64).reshape(docs, rowbytes)
ED2 = ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")
skip = np.array([doc_of[r][0] in ED2 for r in range(docs)])
def ham(row):
    x = np.bitwise_xor(bits, bits[row])
    d = np.unpackbits(x, axis=1).sum(axis=1).astype(np.int64)
    d[skip] = 1 << 20
    d[row] = 1 << 20
    return d
def nearest(key, k=25):
    d = ham(row_of[key])
    order = np.argsort(d, kind="stable")[:k]
    return [(int(d[r]), doc_of[int(r)]) for r in order]

# session's PHIL-1950 list, parsed from vec2.out
sess = {}
cur = None
for line in open("/Users/jbotts/frus-analysis/c3s/runs/s1/vec2.out"):
    mm = re.match(r"### ANCHOR (\S+) (\S+)/(\S+)", line)
    if mm:
        cur = mm.group(1); sess[cur] = []; continue
    mm = re.match(r"\s*(\d+) (\S+)/(\S+) ", line)
    if mm and cur:
        sess[cur].append((int(mm.group(1)), (mm.group(2), mm.group(3))))
anchors = {"PHIL-1950": ("frus1950v06", "d832"), "HAITI-1978": ("frus1977-80v23", "d252"), "HOND-1975": ("frus1969-76ve11p1", "d159"), "CHINA-1943": ("frus1943China", "d202"), "VIET-1967": ("frus1964-68v05", "d258")}
for name, a in anchors.items():
    mine = nearest(a, 25)
    theirs = sess.get(name, [])
    same_set = [p for _, p in mine] == [p for _, p in theirs]
    same_dist = [h for h, _ in mine] == [h for h, _ in theirs]
    print(f"\n{name} {a[0]}/{a[1]}: exact same 25 in order: {same_set}; same distances: {same_dist}")
    if not same_set:
        print("  mine  :", mine[:6]); print("  theirs:", theirs[:6])
        print("  set overlap:", len({p for _, p in mine} & {p for _, p in theirs}), "of 25")
    else:
        print("  first three:", mine[:3])
# the rank of d841 in the Philippines list
ph = nearest(("frus1950v06", "d832"), 25)
print("\nd841 in PHIL-1950 top 25:", [(i + 1, h) for i, (h, p) in enumerate(ph) if p == ("frus1950v06", "d841")])
# nearest within the final set (d244/d249 = 75?)
r1, r2 = row_of[("frus1961-63v22", "d244")], row_of[("frus1961-63v22", "d249")]
print("Hamming d244-d249:", int(np.unpackbits(np.bitwise_xor(bits[r1], bits[r2])).sum()), "(memo: 75)")
# random-pair baseline, independent seed, to compare with the memo's mean 167.14 sd 14.77
import random
rng = random.Random(20261030)
pairs = []
for _ in range(20000):
    a, b = rng.randrange(docs), rng.randrange(docs)
    pairs.append(int(np.unpackbits(np.bitwise_xor(bits[a], bits[b])).sum()))
import statistics
print("random pairs (my seed): mean %.2f sd %.2f min %d" % (statistics.mean(pairs), statistics.pstdev(pairs), min(pairs)), "| memo: 167.14 / 14.77 / 95")
