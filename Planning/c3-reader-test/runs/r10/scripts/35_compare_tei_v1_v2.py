# Compare the two TEI scans (v1 joined text fragments with a space, v2 without) — total DOC and NOTE occurrences per
# variant over all documents of all volumes. Shows how much the joining rule moved each count.
import os, collections
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
VAR = open(R + "out/tei_columns.txt").readline().rstrip("\n").split("\t")[5:]
def tot(d):
    c = collections.Counter()
    for fn in os.listdir(d):
        for line in open(d + fn):
            f = line.rstrip("\n").split("\t")
            if len(f) < 5: continue
            for i, k in enumerate(VAR):
                a, b = f[5 + i].split("|"); c[k + "|DOC"] += int(a); c[k + "|NOTE"] += int(b)
    return c
v1 = tot(R + "out/tei_v1_spacejoin/"); v2 = tot(R + "out/tei/")
print("variant\tv1_DOC\tv2_DOC\tv1_NOTE\tv2_NOTE")
for k in VAR:
    print("%s\t%d\t%d\t%d\t%d" % (k, v1[k + "|DOC"], v2[k + "|DOC"], v1[k + "|NOTE"], v2[k + "|NOTE"]))
