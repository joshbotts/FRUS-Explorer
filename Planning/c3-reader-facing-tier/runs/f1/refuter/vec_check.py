#!/usr/bin/env python3
"""Refuter reproduction of the session's vector operations from the bundle's binary, with my own decode."""
import json, struct, random, sys
import numpy as np
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
SV = "/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx = json.load(open(R + "semantic-vectors-index.json"))
D = idx['provenanceDigest']
print("index digest:", D, "generated", idx['generated'], idx['harvestGenerated'], "documentCount", idx['documentCount'])

# --- §A.3 decode: each volume lists run-length segments {s: start ordinal in volume, i: first id, n: run length}
def decode(segs):
    ids = []
    for s in segs:
        assert s['s'] == len(ids), ("segment start mismatch", s)
        ids.append(s['i'])
        if s['n'] > 1:
            m = re.match(r'^d([1-9]\d*)$', s['i'])
            assert m, ("non-numeric run start", s)
            b = int(m.group(1))
            ids.extend(f"d{b + k}" for k in range(1, s['n']))
    return ids
import re
row_of = {}; doc_of = [None] * idx['documentCount']; vol_base = {}
good = 0; total = 0
for v in idx['volumes']:
    ids = decode(v['seg'])
    good += (len(ids) == v['n'] and len(set(ids)) == v['n']); total += 1
    vol_base[v['v']] = v['r']
    for k, i in enumerate(ids):
        row_of[(v['v'], i)] = v['r'] + k
        doc_of[v['r'] + k] = (v['v'], i)
print(f"decode: {good} of {total} volumes decode to n with unique ids; rows assigned {len(row_of)}; rows unfilled {sum(1 for x in doc_of if x is None)}")
rs = sorted(v['r'] for v in idx['volumes']); print("volume row offsets contiguous:", all(rs[i] + [v['n'] for v in sorted(idx['volumes'], key=lambda v: v['r'])][i] == rs[i+1] for i in range(len(rs)-1)))

blob = open(R + "semantic-vectors-binary.bin", "rb").read()
magic = blob[:4]; ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20]); dbin = blob[20:52].hex()
mp = open(R + "semantic-map.bin", "rb").read(); dmap = mp[20:52].hex()
gen = open(SV + ".generation").read().strip()
print("binary:", magic, ver, dims, docs, cents, "digest match index:", dbin == D)
print("map digest match:", dmap == D, "; shards .generation match:", gen == D)
bpr = dims // 8
print("size check: 64 + docs*bpr + cents*dims + cents*4 =", 64 + docs * bpr + cents * dims + cents * 4, "file", len(blob))
S = np.frombuffer(blob, dtype=np.uint8, count=docs * bpr, offset=64).reshape(docs, bpr)
POP = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint8)
def ham(qrow):
    return POP[np.bitwise_xor(S, S[qrow])].sum(axis=1, dtype=np.int32)

# --- baselines
rng = random.Random(1877); pairs = [(rng.randrange(docs), rng.randrange(docs)) for _ in range(20000)]
a = np.array([p[0] for p in pairs]); b = np.array([p[1] for p in pairs])
rp = POP[np.bitwise_xor(S[a], S[b])].sum(axis=1, dtype=np.int32)
print("random pairs (20,000, Random(1877)): mean %.1f sd %.1f p1 %d min %d" % (rp.mean(), rp.std(), np.percentile(rp, 1), rp.min()))
rng2 = random.Random(1878); samp = [rng2.randrange(docs) for _ in range(200)]
k1 = []; k25 = []
for qrow in samp:
    h = ham(qrow); h[qrow] = 9999; s = np.sort(h); k1.append(s[0]); k25.append(s[24])
print("k-th neighbour over 200 random docs: nearest median %d (q1 %d q3 %d); 25th median %d (q1 %d q3 %d)" % (np.median(k1), np.percentile(k1, 25), np.percentile(k1, 75), np.median(k25), np.percentile(k25, 25), np.percentile(k25, 75)))

# --- shards
def shard(vol):
    f = open(SV + vol + ".vec", "rb").read(); assert f[:4] == b"FRSS", vol
    _, dd, n = struct.unpack("<III", f[4:16]); dg = f[16:48].hex(); assert dg == D, ("shard digest", vol)
    assert len(f) == 64 + n * dd + n * 4, ("shard size", vol, len(f))
    codes = np.frombuffer(f, dtype=np.int8, count=n * dd, offset=64).reshape(n, dd).astype(np.int32)
    sc = np.frombuffer(f, dtype=np.float32, count=n, offset=64 + n * dd)
    assert n == next(v['n'] for v in idx['volumes'] if v['v'] == vol), ("shard n vs index n", vol)
    return codes, sc
cache = {}
def vec(p):
    v, i = p
    if v not in cache: cache[v] = shard(v)
    codes, sc = cache[v]; r = row_of[p] - vol_base[v]
    return codes[r], float(sc[r])
def cos(p, q):
    c1, s1 = vec(p); c2, s2 = vec(q); return s1 * s2 * float(np.dot(c1, c2))

# --- Operation 2: nearest neighbours of PubDipv08/d31, Hamming-800 then int8 cosine rerank
anchor = ("frus1917-72PubDipv08", "d31"); qa = row_of[anchor]
h = ham(qa); h[qa] = 9999
pool = np.argsort(h, kind='stable')[:800]
res = sorted(((cos(anchor, doc_of[x]), int(h[x]), doc_of[x]) for x in pool), reverse=True)
print("\nOperation 2 re-run: 10 nearest of frus1917-72PubDipv08/d31 (Hamming-800, int8 cosine rerank, calibrated (cos-0.40)/0.60):")
mine = []
for cc, hh, dd in res[:10]:
    print("  %s/%s hamming %d raw-cos %.3f calibrated %.0f%%" % (dd[0], dd[1], hh, cc, 100 * (cc - 0.40) / 0.60))
    mine.append((f"{dd[0]}/{dd[1]}", hh, round(cc, 3)))
sess = []
for line in open("/Users/jbotts/frus-analysis/c3f/runs/f1/vec_nn.txt"):
    m = re.match(r'^(\S+) hamming (\d+) raw-cos ([\d.]+)', line)
    if m: sess.append((m.group(1), int(m.group(2)), float(m.group(3))))
print("session's list:", sess)
print("REPRODUCES (same 10 in the same order, same Hamming, same cosine to 3 d.p.):", mine == sess)
print("pure Hamming top-10 (before rerank):", [(doc_of[x][0] + '/' + doc_of[x][1], int(h[x])) for x in np.argsort(h, kind='stable')[:10]])

# --- Operation 1: near-duplicates, the three the memo reports plus the unmeasured one
print("\nOperation 1 re-run (3 nearest Hamming neighbours):")
for p in [("frus1917-72PubDipv06", "d146"), ("frus1917-72PubDipv06", "d128"), ("frus1917-72PubDipv06", "d140"), ("frus1917-72PubDipv06", "d150")]:
    hh = ham(row_of[p]); hh[row_of[p]] = 9999; o = np.argsort(hh, kind='stable')[:3]
    print("  %s/%s" % p, [(doc_of[x][0] + '/' + doc_of[x][1], int(hh[x])) for x in o])
pr = row_of[("frus1917-72PubDipv06", "d150")]; qr = row_of[("frus1961-63v25", "d156")]
print("  PubDipv06/d150 vs frus1961-63v25/d156 Hamming (not measured by the session):", int(POP[np.bitwise_xor(S[pr], S[qr])].sum()))
# full dups re-run against session's vec_dups.txt
sess_d = {}
for line in open("/Users/jbotts/frus-analysis/c3f/runs/f1/vec_dups.txt"):
    m = re.match(r'^(\S+) \[(.*)\]$', line.strip())
    if m: sess_d[m.group(1)] = m.group(2)
agree = 0
for key in sess_d:
    v, i = key.split('/'); hh = ham(row_of[(v, i)]); hh[row_of[(v, i)]] = 9999; o = np.argsort(hh, kind='stable')[:3]
    mine_s = ", ".join("('%s/%s', %d)" % (doc_of[x][0], doc_of[x][1], int(hh[x])) for x in o)
    if mine_s == sess_d[key]: agree += 1
    else: print("  DIFF", key, "mine:", mine_s, "session:", sess_d[key])
print(f"dups lists reproduced for {agree} of {len(sess_d)} anchors")
# semantic join: the four checked neighbours in the confirmed set
import csv
conf = set(tuple(r) for r in csv.reader(open("/Users/jbotts/frus-analysis/c3f/runs/f1/scope_confirmed.csv")))
for p in [("frus1917-72PubDipv07", "d106"), ("frus1917-72PubDipv08", "d99"), ("frus1955-57v09", "d190"), ("frus1955-57v09", "d185")]:
    print("  join:", p, "in confirmed set:", p in conf)
print("all 10 neighbours' volumes in the index:", all(v in vol_base for v, _ in [(s[0].split('/')[0], None) for s in sess]))
