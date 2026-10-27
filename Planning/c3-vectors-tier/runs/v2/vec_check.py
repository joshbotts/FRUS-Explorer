# Round trip, digest check, random-pair baseline (20,000 pairs, random.Random(1877)).
import random, statistics
from veclib import *
print("index digest", IDX["provenanceDigest"]); print("binary digest", DIGEST); print("map digest", MAP_DIGEST)
print("generation file", open(SH + ".generation").read().strip())
print("volumes decoded", len(vol_rows), "rows", len(doc_of), "header docs", DOCS, "dims", DIMS, "centroids", CENTS)
rng = random.Random(1877); d = []
for _ in range(20000):
    a, b = rng.randrange(DOCS), rng.randrange(DOCS)
    if a != b: d.append(ham(a, b))
d.sort(); print("random pairs n", len(d), "mean %.1f sd %.1f p1 %d min %d" % (statistics.mean(d), statistics.pstdev(d), d[len(d)//100], d[0]))
