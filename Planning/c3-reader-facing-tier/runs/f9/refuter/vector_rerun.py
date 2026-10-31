# Refuter: independent re-run of the nearest-neighbour list for anchor frus1917-72PubDipv08/d31 from the bundle's binary,
# with the index's run-length id decode, Hamming over the sign bits, a pool of 800, and the Tier-2 int8 cosine rerank.
import json, struct, sys
import numpy as np
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
SV = "/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix = json.load(open(RES + "semantic-vectors-index.json"))
print("index keys:", list(ix.keys()))
for k in ('schema', 'schemaVersion', 'generated', 'harvestGenerated', 'provenanceDigest', 'documentCount', 'dimensions', 'retrieval', 'scoreCalibration', 'encoding', 'idEncoding', 'legend', 'note'):
    if k in ix: print(f"  {k}: {json.dumps(ix[k])[:400]}")
v0 = ix['volumes'][0]
print("  first volume entry:", json.dumps(v0)[:400])
DIG = ix['provenanceDigest']

def numeric_part(i):
    if not i.startswith('d'): return None
    g = i[1:]
    if not g.isdigit() or (len(g) > 1 and g[0] == '0'): return None
    return int(g)
def decode(segs):
    ids = []
    for s in segs:
        assert s['s'] == len(ids), (s, len(ids))
        ids.append(s['i'])
        if s['n'] > 1:
            b = numeric_part(s['i']); assert b is not None
            ids.extend(f"d{b+k}" for k in range(1, s['n']))
    return ids
row_of = {}; doc_of = {}; vol_rows = {}; ok = 0
for v in ix['volumes']:
    ids = decode(v['seg']); ok += (len(ids) == v['n']); vol_rows[v['v']] = (v['r'], v['n'])
    for k, i in enumerate(ids): row_of[(v['v'], i)] = v['r'] + k; doc_of[v['r'] + k] = (v['v'], i)
print("decode round-trip volumes:", ok, "of", len(ix['volumes']), "rows:", len(doc_of), "documentCount:", ix['documentCount'])

blob = open(RES + "semantic-vectors-binary.bin", "rb").read()
print("binary bytes:", len(blob), "magic:", blob[:4])
ver, dims, docs, cents = struct.unpack('<IIII', blob[4:20])
print("header ver/dims/docs/cents:", ver, dims, docs, cents, "digest at 20 matches index:", blob[20:52].hex() == DIG)
mb = open(RES + "semantic-map.bin", "rb").read()
print("map digest at 20 matches:", mb[20:52].hex() == DIG)
bpr = dims // 8
S = np.frombuffer(blob, dtype=np.uint8, count=docs * bpr, offset=64).reshape(docs, bpr)

anchor = ('frus1917-72PubDipv08', 'd31')
q = row_of[anchor]
print("anchor row:", q)
h = np.bitwise_count(np.bitwise_xor(S, S[q])).sum(axis=1).astype(np.int32)
h[q] = 9999
order = np.argsort(h, kind='stable')
pool = order[:800]
print("Hamming top-15 (sign bits only):")
for r in order[:15]:
    print(f"   ham {h[r]:3d} {doc_of[r][0]}/{doc_of[r][1]}")

shards = {}
def shard(v):
    if v not in shards:
        bl = open(SV + v + ".vec", "rb").read()
        d = struct.unpack('<I', bl[8:12])[0]; n = struct.unpack('<I', bl[12:16])[0]
        assert bl[16:48].hex() == DIG, v
        codes = np.frombuffer(bl, dtype=np.int8, count=n * d, offset=64).reshape(n, d).astype(np.float32)
        sc = np.frombuffer(bl, dtype=np.float32, count=n, offset=64 + n * d)
        shards[v] = (codes, sc, d, n)
    return shards[v]
bl = open(SV + anchor[0] + ".vec", "rb").read()
print("shard header first 64 bytes:", bl[:16], struct.unpack('<IIII', bl[:16]), "digest@16 ok:", bl[16:48].hex() == DIG, "n==vol n:", struct.unpack('<I', bl[12:16])[0] == vol_rows[anchor[0]][1])
def vec(row):
    v, i = doc_of[row]; r0, n = vol_rows[v]; codes, sc, d, nn = shard(v)
    assert nn == n
    return codes[row - r0] * sc[row - r0]
qa = vec(q)
print("anchor vector norm:", float(np.linalg.norm(qa)))
cos = np.array([float(np.dot(qa, vec(r))) for r in pool])
top = np.argsort(-cos, kind='stable')[:15]
print("\nRerank top-15 by int8 cosine after Hamming-800 pool (raw cosine; calibrated = (cos-0.40)/0.60):")
mine = []
for o in top:
    r = pool[o]; v, d = doc_of[r]
    mine.append((f"{v}/{d}", int(h[r]), round(float(cos[o]), 3)))
    print(f"   ham {h[r]:3d} cos {cos[o]:.3f} cal {(cos[o]-0.40)/0.60:.3f} {v}/{d}")
memo = ["frus1917-72PubDipv07/d106", "frus1969-76v38p2/d105", "frus1917-72PubDipv08/d99", "frus1955-57v09/d190", "frus1951v06p2/d105",
        "frus1952-54v13p1/d116", "frus1955-57v09/d185", "frus1961-63v25/d156", "frus1917-72PubDipv06/d150", "frus1917-72PubDipv07/d69",
        "frus1917-72PubDipv07/d32", "frus1950v06/d9", "frus1977-80v30/d68", "frus1917-72PubDipv07/d94", "frus1955-57v09/d207"]
print("\nsession's vectors.txt order reproduced exactly:", [m[0] for m in mine] == memo)
print("set equal:", set(m[0] for m in mine) == set(memo))
# the specific figures the memo quotes
for name, hm, cs in [("frus1917-72PubDipv07/d106", 81, 0.920), ("frus1969-76v38p2/d105", 96, 0.917), ("frus1952-54v13p1/d116", 88, 0.906)]:
    got = [m for m in mine if m[0] == name]
    print("  memo:", name, hm, cs, "| mine:", got)
# also the near-duplicate figure: d190-d185 Hamming 32
a = row_of[('frus1955-57v09', 'd190')]; b = row_of[('frus1955-57v09', 'd185')]
print("Hamming d190-d185:", int(np.bitwise_count(np.bitwise_xor(S[a], S[b])).sum()), "(memo 32)")
# map cluster of d31 and d116
def place(row): return struct.unpack('<hhH', mb[64 + row * 6: 64 + row * 6 + 6])
print("map d31:", place(q), "d116:", place(row_of[('frus1952-54v13p1', 'd116')]), "(memo: d31 unclustered 65535; d116 cluster 29)")
# baselines quick: random pairs with the memo's seed
import random
rng = random.Random(1877); A = [rng.randrange(docs) for _ in range(20000)]; B = [rng.randrange(docs) for _ in range(20000)]
rp = np.bitwise_count(np.bitwise_xor(S[A], S[B])).sum(axis=1)
print("random pairs (seed 1877): mean %.1f sd %.1f p1 %d min %d (memo 167.2 14.9 131 90)" % (rp.mean(), rp.std(), np.percentile(rp, 1), rp.min()))
