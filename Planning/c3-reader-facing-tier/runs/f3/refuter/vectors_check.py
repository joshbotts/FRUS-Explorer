# Refuter f3: digests, header layout, independent decode of the index's segments, and the d31 neighbour list re-run from the bundle's binary.
import json, struct, os, sys
import numpy as np
RES = "/Applications/FRUS Explorer.app/Contents/Resources"; SH = "/Users/jbotts/frus-analysis/c3/SemanticVectors"
idx = json.load(open(RES + "/semantic-vectors-index.json")); dig = idx['provenanceDigest']
blob = open(RES + "/semantic-vectors-binary.bin", 'rb').read(); mp = open(RES + "/semantic-map.bin", 'rb').read()
print("binary size", len(blob), "map size", len(mp))
print("binary header[0:64] hex:", blob[:64].hex())
print("map header[0:64] hex:", mp[:64].hex())
magic = blob[:4]; ver, dims, docs, extra = struct.unpack('<IIII', blob[4:20])
print("binary magic", magic, "ver", ver, "dims", dims, "docs", docs, "word4", extra)
print("index documentCount", idx['documentCount'], "shippingDims", idx['provenance']['shippingDims'])
bpr = dims // 8
print("expected payload 64 + docs*dims/8 =", 64 + docs * bpr, "actual size", len(blob), "match", 64 + docs * bpr == len(blob))
print("digest index:", dig)
print("digest binary@20:", blob[20:52].hex(), "match", blob[20:52].hex() == dig)
print("digest map@20:   ", mp[20:52].hex(), "match", mp[20:52].hex() == dig)
gen = open(SH + "/.generation").read().strip()
print(".generation:", gen, "match", gen == dig)
# decode segments: each volume v has first row r and n docs; seg = list of {i: first id, n: run length, s: start offset}
def numeric_part(x):
    if not x.startswith('d'): return None
    g = x[1:]
    if not g or not g.isdigit() or (len(g) > 1 and g[0] == '0'): return None
    return int(g)
row_of = {}; doc_of = {}; ok = 0; vol_first = {}
for vol in idx['volumes']:
    ids = []
    for s in vol['seg']:
        assert s['s'] == len(ids), (vol['v'], s)
        ids.append(s['i'])
        if s['n'] > 1:
            b = numeric_part(s['i']); assert b is not None, (vol['v'], s)
            ids.extend('d%d' % (b + k) for k in range(1, s['n']))
    ok += len(ids) == vol['n']; vol_first[vol['v']] = vol['r']
    for i, d in enumerate(ids):
        row_of[(vol['v'], d)] = vol['r'] + i; doc_of[vol['r'] + i] = (vol['v'], d)
print("round trip: volumes whose decoded id count == n:", ok, "of", len(idx['volumes']), "| rows decoded", len(doc_of), "| contiguous 0..docs-1:", sorted(doc_of) == list(range(docs)))
S = np.frombuffer(blob, dtype=np.uint8, count=docs * bpr, offset=64).reshape(docs, bpr)
def ham_all(q): return np.bitwise_count(np.bitwise_xor(S, S[q])).sum(axis=1).astype(np.int32)
anchor = ('frus1917-72PubDipv08', 'd31'); q = row_of[anchor]
print("\nanchor", anchor, "row", q)
h = ham_all(q); h[q] = 9999
order = np.argsort(h, kind='stable')
print("top 12 by Hamming alone:")
for r in order[:12]: print("  %s/%s hamming %d" % (doc_of[int(r)][0], doc_of[int(r)][1], h[r]))
session = [('frus1917-72PubDipv07','d106',81),('frus1969-76v38p2','d105',96),('frus1917-72PubDipv08','d99',90),('frus1955-57v09','d190',100),('frus1951v06p2','d105',94),('frus1952-54v13p1','d116',88),('frus1955-57v09','d185',104),('frus1961-63v25','d156',102),('frus1917-72PubDipv06','d150',99),('frus1917-72PubDipv07','d69',95)]
pool800 = set(int(x) for x in order[:800])
print("\nsession's 10 reranked neighbours: my Hamming | session's | in my top-800 pool | rank by Hamming")
rankpos = {int(r): i for i, r in enumerate(order)}
for v, d, hs in session:
    r = row_of[(v, d)]
    print("  %-26s %4d %4d %s pos %d" % (v + '/' + d, h[r], hs, 'POOL' if r in pool800 else 'OUT', rankpos[r]))
# rerank with the shards (int8 cosine), as the session did, to see whether the order reproduces
def shard(v):
    p = SH + '/%s.vec' % v
    if not os.path.exists(p): return None
    b = open(p, 'rb').read(); d = struct.unpack('<I', b[8:12])[0]; n = struct.unpack('<I', b[12:16])[0]
    assert b[16:48].hex() == dig, 'shard digest mismatch ' + v
    assert len(b) == 64 + n * d + 4 * n, ('shard size', v, len(b), 64 + n * d + 4 * n)
    codes = np.frombuffer(b, dtype=np.int8, count=n * d, offset=64).reshape(n, d).astype(np.float32)
    sc = np.frombuffer(b, dtype=np.float32, count=n, offset=64 + n * d)
    return codes, sc
b = open(SH + '/frus1917-72PubDipv08.vec', 'rb').read()
print("\nshard header[0:64] hex:", b[:64].hex())
cache = {}
def vec(row):
    v, d = doc_of[row]
    if v not in cache: cache[v] = shard(v)
    s = cache[v]
    if s is None: return None
    i = row - vol_first[v]; return s[0][i] * s[1][i]
qv = vec(q); res = []
for r in order[:800]:
    x = vec(int(r)); cos = float(np.dot(qv, x)) if x is not None else None
    res.append((int(r), int(h[r]), cos))
res.sort(key=lambda t: -(t[2] if t[2] is not None else -9))
print("my rerank (top 800 Hamming -> int8 cosine), top 10:")
for r, hh, cos in res[:10]:
    v, d = doc_of[r]; print("  %-26s hamming %d raw cos %.3f calibrated %.3f" % (v + '/' + d, hh, cos, (cos - 0.40) / 0.60))
mine = [doc_of[r] for r, _, _ in res[:10]]; sess = [(v, d) for v, d, _ in session]
print("order reproduces session's list:", mine == sess)
print("qv norm", float(np.linalg.norm(qv)), "| shards opened", len([k for k in cache if cache[k] is not None]), "| volumes without a shard among pool", len([k for k in cache if cache[k] is None]))
# near-duplicate claims
for a, b2 in [(('frus1955-57v09','d190'),('frus1955-57v09','d185')), (('frus1955-57v09','d190'),('frus1955-57v09','d207'))]:
    d = int(np.bitwise_count(np.bitwise_xor(S[row_of[a]], S[row_of[b2]])).sum()); print("Hamming %s/%s vs %s/%s = %d" % (a + b2 + (d,)))
r190 = row_of[('frus1955-57v09','d190')]; h190 = ham_all(r190); h190[r190] = 9999; n = int(np.argmin(h190)); print("nearest of d190:", doc_of[n], int(h190[n]))
# baseline reproduction (same seeds as the session)
import random
rng = random.Random(1877); pr = []
for _ in range(20000):
    a = rng.randrange(docs); b2 = rng.randrange(docs)
    if a != b2: pr.append(int(np.bitwise_count(np.bitwise_xor(S[a], S[b2])).sum()))
pr = np.array(pr); print("random pairs n %d mean %.1f sd %.1f p1 %d min %d" % (len(pr), pr.mean(), pr.std(), np.percentile(pr, 1), pr.min()))
# map cluster of the anchor and of its neighbours
pl = np.frombuffer(mp, dtype=np.int16, count=docs * 3, offset=64).reshape(docs, 3); cl = pl[:, 2].view(np.uint16)
print("map expected size 64 + docs*6 =", 64 + docs * 6, "actual", len(mp))
print("anchor d31 cluster:", int(cl[q]), "| neighbours' clusters:", [int(cl[row_of[(v, d)]]) for v, d, _ in session])
mi = json.load(open(RES + "/semantic-map-index.json"))
for c in [138, 29, 7, 31]:
    x = [k for k in mi.get('clusters', []) if k.get('id') == c]; print("cluster", c, x[0].get('terms') if x else None, x[0].get('documentCount') if x else None)
