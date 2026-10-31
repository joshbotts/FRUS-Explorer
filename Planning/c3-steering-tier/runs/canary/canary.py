import json, random, re, sqlite3, statistics, struct
import numpy as np
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
SH = "/Users/jbotts/frus-analysis/c3/SemanticVectors"
idx = json.load(open(RES + "/semantic-vectors-index.json"))

def numeric_part(doc_id):
    digits = doc_id[1:]
    if not doc_id.startswith("d") or not digits.isdigit(): return None
    if len(digits) > 1 and digits[0] == "0": return None
    return int(digits)

row_of, doc_of = {}, {}
ok = 0
for v in idx["volumes"]:
    ids = []
    for seg in v["seg"]:
        assert seg["s"] == len(ids)
        ids.append(seg["i"])
        if seg["n"] > 1:
            base = numeric_part(seg["i"])
            ids.extend(f"d{base + k}" for k in range(1, seg["n"]))
    assert len(ids) == v["n"]
    ok += 1
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k
        doc_of[v["r"] + k] = (v["v"], d)
print("volumes decoded to exactly n:", ok, "of", len(idx["volumes"]))

blob = open(RES + "/semantic-vectors-binary.bin", "rb").read()
ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
print("header: version", ver, "dims", dims, "documents", docs, "centroids", cents)
digests = {"index": idx["provenanceDigest"], "binary": blob[20:52].hex(),
           "map": open(RES + "/semantic-map.bin", "rb").read(52)[20:52].hex(),
           "manifest": json.load(open(RES + "/semantic-shards-manifest.json"))["provenanceDigest"]}
for k, v in digests.items(): print("digest", k, v[:8])
assert len(set(digests.values())) == 1, digests
gen = open(SH + "/.generation").read().strip()
print(".generation:", gen)
shard = open(SH + "/frus1861.vec", "rb").read(64)
print("frus1861.vec magic", shard[:4], "digest@16:", shard[16:48].hex())
print("all equal:", gen.lower() == digests["index"].lower() == shard[16:48].hex())

bits = np.frombuffer(blob, dtype=">u8", count=docs * dims // 64, offset=64).reshape(docs, dims // 64)
ED2 = ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")
skip = np.array([doc_of[r][0] in ED2 for r in range(docs)])

def distances(row):
    d = np.bitwise_count(bits ^ bits[row]).sum(axis=1).astype(np.int64)
    d[skip] = 1 << 20
    d[row] = 1 << 20
    return d

def nearest(key, k=25):
    d = distances(row_of[key])
    return [(int(d[r]), doc_of[int(r)]) for r in np.argsort(d, kind="stable")[:k]]

print("\nten nearest of frus1861/d111:")
for h, (vv, dd) in nearest(("frus1861", "d111"), 10): print("hamming", h, vv + "/" + dd)

rng = random.Random(1877)
pairs = [int(np.bitwise_count(bits[rng.randrange(docs)] ^ bits[rng.randrange(docs)]).sum())
         for _ in range(20000)]
mean, sd = statistics.mean(pairs), statistics.pstdev(pairs)
first_pct = sorted(pairs)[len(pairs) // 100]
kth = sorted(int(np.sort(distances(r))[24]) for r in random.Random(1878).sample(range(docs), 200))
line = mean - 8 * sd
print("\nrandom pairs: mean %.3f sd %.3f 1st pct %d" % (mean, sd, first_pct))
print("median kth:", statistics.median(kth))
print("line: %.3f" % line)

con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
def joined(key):
    return con.execute(
        "SELECT c.header, c.body_text, t.date_iso FROM document_cache c LEFT JOIN document_dates t "
        "ON t.volume_id = c.volume_id AND t.document_id = c.document_id "
        "WHERE c.volume_id = ? AND c.document_id = ?", key).fetchone()

def flagged(anchor, scope, literal, k=25):
    a_date = (joined(anchor) or ("", "", ""))[2] or ""
    rows = []
    for h, key in nearest(anchor, k):
        row = joined(key)
        if row is None:
            rows.append((h, key, "NOT IN THIS DATABASE"))
            continue
        header, body, date = row
        rows.append((h, key, date,
                     "IN-SCOPE" if key in scope else "OUTSIDE",
                     "SAME-DECADE" if date and date[:3] == a_date[:3] else "OTHER-DECADE",
                     "LITERAL" if literal.search(header + " " + body) else "ABSENT"))
    return rows

print("\nflagged(frus1861/d111, scope=set(), /\\bblockade/i, k=10):")
for r in flagged(("frus1861", "d111"), set(), re.compile(r"\bblockade", re.I), k=10): print(r)

def near_duplicates(scope):
    rows = sorted(row_of[k] for k in scope if k in row_of)
    found = []
    for i, a in enumerate(rows[:-1]):
        d = np.bitwise_count(bits[rows[i + 1:]] ^ bits[a]).sum(axis=1)
        found += [(int(h), doc_of[a], doc_of[b]) for h, b in zip(d, rows[i + 1:]) if h < line]
    return sorted(found)

S = {("frus1881", "d405"), ("frus1894app2", "d394"), ("frus1861", "d111")}
print("\nnear_duplicates:", [k in row_of for k in sorted(S)])
for r in near_duplicates(S): print(r)
