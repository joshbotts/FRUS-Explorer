# Independent re-run of one neighbour list from the bundle's binary (sign bits, Hamming over 512 bits),
# with the index's segment decode written from the index's own structure (A.3): a segment {i,n,s} names
# the first document id, the count, and the start offset within the volume; later ids increment the numeric part.
import json, struct, sys
import numpy as np
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
ix = json.load(open(R + "semantic-vectors-index.json"))
blob = open(R + "semantic-vectors-binary.bin", "rb").read()
magic = blob[:4]; ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20]); dg = blob[20:52].hex()
assert magic == b"FRSV" and dims == 512 and docs == ix["documentCount"] and dg == ix["provenanceDigest"], (magic, dims, docs, dg)
bpr = dims // 8
assert len(blob) == 64 + docs * bpr + cents * (dims + 4), "layout"
def decode(v):
    ids = []
    for s in sorted(v["seg"], key=lambda s: s["s"]):
        assert s["s"] == len(ids), (v["v"], s)
        first = s["i"]; ids.append(first)
        if s["n"] > 1:
            m = __import__("re").fullmatch(r"d(\d+)", first)
            assert m, (v["v"], first)
            base = int(m.group(1))
            ids.extend("d%d" % (base + k) for k in range(1, s["n"]))
    assert len(ids) == v["n"], (v["v"], len(ids), v["n"])
    return ids
doc_of = [None] * docs; row_of = {}
r_expected = 0
for v in sorted(ix["volumes"], key=lambda v: v["r"]):
    assert v["r"] == r_expected, (v["v"], v["r"], r_expected)
    for j, d in enumerate(decode(v)):
        doc_of[v["r"] + j] = (v["v"], d); row_of[(v["v"], d)] = v["r"] + j
    r_expected += v["n"]
assert r_expected == docs and None not in doc_of and len(row_of) == docs
print("decode: volumes", len(ix["volumes"]), "rows", len(row_of), "(round-trip ok)")
bits = np.frombuffer(blob, dtype=np.uint8, count=docs * bpr, offset=64).reshape(docs, bpr)
# popcount without numpy.bitwise_count (portable)
POP = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint8)
def ham(a):
    x = bits ^ bits[a]
    return POP[x].sum(axis=1).astype(np.int32)
import sqlite3
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
anchors = [("frus1969-76v38p2", "d105"), ("frus1917-72PubDipv08", "d31")]
for a in anchors:
    ar = row_of[a]; d = ham(ar); d[ar] = 9999
    order = np.argsort(d, kind="stable")
    print("\nANCHOR %s/%s nearest %d 25th %d" % (a[0], a[1], d[order[0]], d[order[24]]))
    for r in order[:12]:
        v, dd = doc_of[r]
        h = db.execute("select substr(replace(header,char(10),' '),1,80) from document_cache where volume_id=? and document_id=?", (v, dd)).fetchone()
        print("  ham %3d  %s/%s  %s" % (d[r], v, dd, h[0] if h else "NOT IN document_cache"))
# verify the memo's reported distances for the two vector-reached documents
for t in [("frus1969-76ve12", "d10"), ("frus1977-80v22", "d104")]:
    a = row_of[("frus1969-76v38p2", "d105")]; b = row_of[t]
    print("distance d105 ->", t, int(POP[bits[a] ^ bits[b]].sum()))
# random-pair baseline, seed 1877 as the session did (python random over row indices)
import random
rnd = random.Random(1877); ds = []
for _ in range(20000):
    x = rnd.randrange(docs); y = rnd.randrange(docs)
    while y == x: y = rnd.randrange(docs)
    ds.append(int(POP[bits[x] ^ bits[y]].sum()))
ds = np.array(ds); print("random pairs (seed 1877): mean %.1f sd %.1f p1 %.0f min %d" % (ds.mean(), ds.std(), np.percentile(ds, 1), ds.min()))
