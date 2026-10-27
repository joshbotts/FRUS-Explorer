#!/usr/bin/env python3
"""Runbook §1 for the vectors tier: reproduce Appendix A's verified neighbour list for
frus1861/d111 from the bundle binary, with §A.3's decode and §A.4's layout, and check the digests
the canary will check. Prints what it finds; exits 1 on any disagreement."""
import json, struct, hashlib, heapq, sys, os
R = '/Applications/FRUS Explorer.app/Contents/Resources/'
SH = os.path.expanduser('~/frus-analysis/c3/SemanticVectors/')
idx = json.load(open(R + 'semantic-vectors-index.json'))
man = json.load(open(R + 'semantic-shards-manifest.json'))
blob = open(R + 'semantic-vectors-binary.bin', 'rb').read()
magic = blob[:4]; ver, dims, docs, cents = struct.unpack('<IIII', blob[4:20]); bdig = blob[20:52].hex()
print('binary:', magic, 'version', ver, 'dims', dims, 'docs', docs, 'centroids', cents)
ok = True
def chk(cond, msg):
    global ok
    print(('ok  ' if cond else 'FAIL'), msg); ok = ok and cond
chk(bdig == idx['provenanceDigest'] == man['provenanceDigest'] == open(SH + '.generation').read().strip(), 'four digests agree: ' + bdig[:16])
chk(docs == idx['documentCount'], f'document count {docs} == index {idx["documentCount"]}')

def numeric_part(doc_id):
    if not doc_id.startswith('d'): return None
    digits = doc_id[1:]
    if not digits or not digits.isdigit(): return None
    if len(digits) > 1 and digits[0] == '0': return None
    return int(digits)
def decode_segments(segments):
    ids = []
    for seg in segments:
        assert seg['s'] == len(ids)
        ids.append(seg['i'])
        if seg['n'] > 1:
            base = numeric_part(seg['i'])
            ids.extend(f'd{base + k}' for k in range(1, seg['n']))
    return ids
row_of, doc_of = {}, {}
bad = 0
vol_rows = {}
for v in idx['volumes']:
    ids = decode_segments(v['seg'])
    if len(ids) != v['n']: bad += 1
    vid = v.get('id') or v.get('v') or v.get('volumeID') or v.get('volume'); vol_rows[vid] = (v['r'], v['n'])
    for k, d in enumerate(ids):
        row_of[(vid, d)] = v['r'] + k; doc_of[v['r'] + k] = (vid, d)
chk(bad == 0 and len(row_of) == docs, f'round trip: {len(idx["volumes"]) - bad} of {len(idx["volumes"])} volumes decode to n; {len(row_of)} rows keyed')

bpr = dims // 8
def sign_row(row):
    o = 64 + row * bpr
    return int.from_bytes(blob[o:o + bpr], 'big')
anchor = row_of[('frus1861', 'd111')]
q, best = sign_row(anchor), []
for row in range(docs):
    if row == anchor: continue
    d = bin(q ^ sign_row(row)).count('1')
    if len(best) < 10: heapq.heappush(best, (-d, row))
    elif -best[0][0] > d: heapq.heapreplace(best, (-d, row))
got = sorted((-d, doc_of[r]) for d, r in best)
# Appendix A §A.5 prints the 300m generation's list (87 frus1862/d130 first); at this digest the list is:
exp = [(57, ('frus1861', 'd119')), (62, ('frus1861', 'd39')), (70, ('frus1863p1', 'd254')), (75, ('frus1862', 'd130')),
       (77, ('frus1861', 'd203')), (77, ('frus1862', 'd262')), (78, ('frus1861', 'd20')), (78, ('frus1862', 'd111')),
       (78, ('frus1862', 'd455')), (79, ('frus1862', 'd118'))]
for d, (v, doc) in got: print(f'  hamming {d:3d}  {v}/{doc}')
chk(sorted(got) == sorted(exp), "the ten neighbours of frus1861/d111 match the list re-taken at digest 89481b18 (the canary's known answer)")
# one shard: header digest and manifest sha256
sh = open(SH + 'frus1861.vec', 'rb').read()
m1 = next(s for s in man['shards'] if s['volumeID'] == 'frus1861')
smagic = sh[:4]; sver, sdims, sdocs = struct.unpack('<III', sh[4:16]); sdig = sh[16:48].hex()
chk(smagic == b'FRSS' and sdig == bdig and sdims == dims, f'frus1861.vec header: {smagic} dims {sdims} docs {sdocs} digest matches')
chk(hashlib.sha256(sh).hexdigest() == m1['sha256'] and len(sh) == m1['bytes'], 'frus1861.vec sha256 and size match the shards manifest')
chk(sdocs == vol_rows['frus1861'][1], f'shard docs {sdocs} == index n {vol_rows["frus1861"][1]}')
n_sh = len([f for f in os.listdir(SH) if f.endswith('.vec')])
chk(n_sh == len(man['shards']) == 553, f'{n_sh} shards present of {len(man["shards"])} in the manifest')
print('ALL OK' if ok else 'DISAGREEMENT'); sys.exit(0 if ok else 1)
