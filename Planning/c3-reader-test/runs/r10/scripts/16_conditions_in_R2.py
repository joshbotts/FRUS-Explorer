# Condition families restricted to the R2 documents (documents in the Latin American universe that use the
# recognition-of-a-government phrases), by era: N of M where M = R2 documents of the era. Reads out/hits_R2.tsv and
# out/cond_hits_<family>.tsv (13_conditions.py; the latter lists S2 documents matching each family's FTS expression,
# with strict/tolerant regex flags). Reports FTS-matched counts and, beside them, tolerant-regex-confirmed counts.
import collections, json
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
def era(di):
    if not di: return "undated"
    if di < "1913": return "E1_to1912"
    if di < "1930": return "E2_1913-29"
    if di < "1943": return "E3_1930-42"
    if di < "1949": return "E4_1943-48"
    if di < "1961": return "E5_1949-60"
    return "E6_1961-88"
ERAS = ["E1_to1912", "E2_1913-29", "E3_1930-42", "E4_1943-48", "E5_1949-60", "E6_1961-88"]
r2 = {}
for line in open(R + "out/hits_R2.tsv"):
    v, d, di, p = line.rstrip("\n").split("\t")
    r2[(v, d)] = era(di)
M = collections.Counter(r2.values())
fams = json.load(open(R + "scripts/conditions.json"))
print("era denominators (R2 documents):", {e: M[e] for e in ERAS})
print("family\t" + "\t".join(ERAS))
for name in fams:
    c = collections.Counter(); ct = collections.Counter()
    for line in open(R + "out/cond_hits_%s.tsv" % name):
        v, d, di, s, t = line.rstrip("\n").split("\t")
        if (v, d) in r2:
            c[r2[(v, d)]] += 1
            if t == "1": ct[r2[(v, d)]] += 1
    print(name + "\t" + "\t".join("%d of %d (tol %d)" % (c[e], M[e], ct[e]) for e in ERAS))
