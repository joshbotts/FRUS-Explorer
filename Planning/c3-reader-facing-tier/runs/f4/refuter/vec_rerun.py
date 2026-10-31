#!/usr/bin/env python3
"""Refuter re-run of one neighbour list (anchor frus1917-72PubDipv08/d31) from the bundle's binary,
with an independent decode of the index's run-length segments. Compares with the session's vec_nn.out."""
import json, struct, re
import numpy as np
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
ix = json.load(open(R + "semantic-vectors-index.json"))
blob = open(R + "semantic-vectors-binary.bin", "rb").read()
print("binary magic:", blob[:4], "header ints (version, dims, docs, cents):", struct.unpack("<IIII", blob[4:20]))
ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
bdig = blob[20:52].hex()
print("index provenanceDigest:", ix['provenanceDigest'])
print("binary digest        :", bdig, "equal:", bdig == ix['provenanceDigest'])
mp = open(R + "semantic-map.bin", "rb").read()
print("map digest           :", mp[20:52].hex(), "equal:", mp[20:52].hex() == ix['provenanceDigest'], "map magic:", mp[:4])
sh = open("/Users/jbotts/frus-analysis/c3/SemanticVectors/frus1964-68v01.vec", "rb").read()
print("shard magic:", sh[:4], "shard digest @16:48:", sh[16:48].hex(), "equal:", sh[16:48].hex() == ix['provenanceDigest'])
gen = open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read().strip()
print(".generation:", gen, "equal:", gen == ix['provenanceDigest'])
assert docs == ix['documentCount'] == 314616

# Independent decode: a segment {"s": start offset, "i": first id, "n": run length}; ids in a run are d<base+k>.
def run_ids(seg):
    i, n = seg['i'], seg['n']
    if n == 1:
        return [i]
    m = re.fullmatch(r'd(\d+)', i)
    assert m, (seg,)
    b = int(m.group(1))
    return [f"d{b + k}" for k in range(n)]
rows = {}
doc_of = [None] * docs
for v in ix['volumes']:
    ids = []
    for seg in v['seg']:
        assert seg['s'] == len(ids), (v['v'], seg, len(ids))
        ids.extend(run_ids(seg))
    assert len(ids) == v['n'], (v['v'], len(ids), v['n'])
    for k, i in enumerate(ids):
        rows[(v['v'], i)] = v['r'] + k
        doc_of[v['r'] + k] = (v['v'], i)
assert all(x is not None for x in doc_of)
print("decode: volumes", len(ix['volumes']), "rows", len(rows))

bpr = dims // 8
Sg = np.frombuffer(blob, dtype=np.uint8, count=docs * bpr, offset=64).reshape(docs, bpr)
anchor = ("frus1917-72PubDipv08", "d31")
r = rows[anchor]
dist = np.unpackbits(Sg ^ Sg[r], axis=1).sum(axis=1).astype(np.int32)
dist[r] = 9999
order = np.argsort(dist, kind='stable')
mine = []
for o in order:
    v, i = doc_of[o]
    if v.endswith('Ed2'):
        continue
    mine.append((int(dist[o]), f"{v}/{i}"))
    if len(mine) >= 16:
        break
print("\nMy nearest 16 to", "/".join(anchor), "(Hamming over 512 sign bits, stable argsort; Ed2 skipped, apparatus NOT skipped):")
for d, p in mine:
    print("  ham", d, p)

# Session's list from vec_nn.out
out = open('/Users/jbotts/frus-analysis/c3f/runs/f4/vec_nn.out').read()
sec = out.split('## ANCHOR frus1917-72PubDipv08/d31')[1].split('## ANCHOR')[0]
theirs = re.findall(r'ham (\d+) (\S+)', sec)
theirs = [(int(a), b) for a, b in theirs]
print("\nSession's list (vec_nn.out), 15 rows:")
for d, p in theirs:
    print("  ham", d, p)
mine15 = mine[:15]
print("\nSame 15 pairs as a set:", set(p for _, p in mine15) == set(p for _, p in theirs))
print("Same order:", [p for _, p in mine15] == [p for _, p in theirs])
print("Same distances per pair:", all(dict(mine)[p] == d for d, p in theirs if p in dict(mine)))
diff = set(p for _, p in theirs) ^ set(p for _, p in mine15)
print("Symmetric difference:", diff)
# Also check the d99 distance the memo quotes (90)
print("Hamming d31 -> frus1917-72PubDipv08/d99:", int(dist[rows[('frus1917-72PubDipv08', 'd99')]]))
