#!/usr/bin/env python3
"""Re-take Appendix A's worked figures at the shipped digest (EmbeddingGemma 2, 89481b18…), since the
§A.5 example was taken on the 300m generation: the ten neighbours of frus1861/d111, the random-pair
baseline (20,000 pairs, default_rng(1877) -> here random.Random(1877), the sampling differs), a random
512-bit pattern's minimum to the corpus, a sample's 25th-nearest-neighbour distance, the volumes
nearest frus1861 by centroid cosine, the map placement of frus1929v03/d17, and the unclustered share."""
import json, struct, heapq, random, os, math, statistics
R = '/Applications/FRUS Explorer.app/Contents/Resources/'
idx = json.load(open(R + 'semantic-vectors-index.json')); blob = open(R + 'semantic-vectors-binary.bin', 'rb').read()
ver, dims, docs, cents = struct.unpack('<IIII', blob[4:20]); bpr = dims // 8
def numeric_part(d):
    if not d.startswith('d'): return None
    s = d[1:]
    if not s or not s.isdigit() or (len(s) > 1 and s[0] == '0'): return None
    return int(s)
row_of, doc_of, vols = {}, {}, []
for v in idx['volumes']:
    ids = []
    for seg in v['seg']:
        ids.append(seg['i'])
        if seg['n'] > 1:
            base = numeric_part(seg['i']); ids.extend(f'd{base + k}' for k in range(1, seg['n']))
    vols.append(v['v'])
    for k, d in enumerate(ids): row_of[(v['v'], d)] = v['r'] + k; doc_of[v['r'] + k] = (v['v'], d)
rows = [int.from_bytes(blob[64 + r * bpr: 64 + (r + 1) * bpr], 'big') for r in range(docs)]
pc = lambda x: bin(x).count('1')
out = {'digest': blob[20:52].hex(), 'dims': dims, 'docs': docs}
def knn(q, k, skip=None):
    best = []
    for r, x in enumerate(rows):
        if r == skip: continue
        d = pc(q ^ x)
        if len(best) < k: heapq.heappush(best, (-d, r))
        elif -best[0][0] > d: heapq.heapreplace(best, (-d, r))
    return sorted((-d, r) for d, r in best)
a = row_of[('frus1861', 'd111')]
out['neighbours_frus1861_d111'] = [(d, '/'.join(doc_of[r])) for d, r in knn(rows[a], 10, a)]
rng = random.Random(1877)
pairs = [pc(rows[rng.randrange(docs)] ^ rows[rng.randrange(docs)]) for _ in range(20000)]
pairs.sort()
out['random_pairs'] = {'n': 20000, 'mean': round(statistics.mean(pairs), 1), 'sd': round(statistics.pstdev(pairs), 1), 'p1': pairs[200], 'min': pairs[0]}
out['random_pattern_min_to_corpus'] = sorted(min(pc(rng.getrandbits(dims) ^ x) for x in rows) for _ in range(10))
sample = rng.sample(range(docs), 200)
k25 = [knn(rows[r], 25, r)[-1][0] for r in sample]
out['kth_neighbour_25_over_200_sample'] = {'median': statistics.median(k25), 'p25': sorted(k25)[50], 'p75': sorted(k25)[150]}
# centroids: after the sign block, 660 × (dims + 4): int8 codes then float32 scale; 553 volumes then 107 subseries
cb = 64 + docs * bpr
def centroid(i):
    o = cb + i * (dims + 4)
    codes = struct.unpack('<%db' % dims, blob[o:o + dims]); scale = struct.unpack('<f', blob[o + dims:o + dims + 4])[0]
    return [c * scale for c in codes]
cvs = [centroid(i) for i in range(len(vols))]
def cos(u, v):
    nu = math.sqrt(sum(x * x for x in u)); nv = math.sqrt(sum(x * x for x in v))
    return sum(x * y for x, y in zip(u, v)) / (nu * nv)
c0 = cvs[vols.index('frus1861')]
sims = sorted(((cos(c0, cvs[i]), vols[i]) for i in range(len(vols)) if vols[i] != 'frus1861'), reverse=True)[:5]
out['volumes_nearest_frus1861_by_centroid'] = [(round(s, 3), v) for s, v in sims]
# map
mb = open(R + 'semantic-map.bin', 'rb').read(); mver, mdocs, mclusters, mextent = struct.unpack('<IIII', mb[4:20])
out['map'] = {'docs': mdocs, 'clusters': mclusters, 'digest_matches': mb[20:52].hex() == out['digest']}
unclustered = sum(1 for r in range(mdocs) if struct.unpack('<H', mb[64 + r * 6 + 4: 64 + r * 6 + 6])[0] == 0xFFFF)
out['map']['unclustered'] = unclustered; out['map']['unclustered_share'] = round(unclustered / mdocs, 4)
mi = json.load(open(R + 'semantic-map-index.json'))
r = row_of.get(('frus1929v03', 'd17'))
if r is not None:
    x, y, cl = struct.unpack('<hhH', mb[64 + r * 6: 64 + r * 6 + 6])
    out['map']['frus1929v03_d17'] = {'x': x, 'y': y, 'cluster': cl}
    clusters = mi.get('clusters') or mi
    if isinstance(clusters, list):
        hit = next((c for c in clusters if c.get('id') == cl or c.get('cluster') == cl), None)
        out['map']['frus1929v03_d17']['label'] = (hit or {}).get('terms') or (hit or {}).get('label')
        out['map']['frus1929v03_d17']['count'] = (hit or {}).get('count') or (hit or {}).get('documents')
    else:
        out['map']['index_keys'] = list(mi)[:10]
json.dump(out, open('appendix_recheck.json', 'w'), indent=2)
print(json.dumps(out, indent=2))
