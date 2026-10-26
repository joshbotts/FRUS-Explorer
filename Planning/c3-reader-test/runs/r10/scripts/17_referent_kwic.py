# Referent test for a condition family: take its documents that are also R2 documents in the given era window
# [argv[2], argv[3]), sample argv[4] evenly from the (volume_id, document_id)-sorted list, and print the first
# tolerant-regex context (300 characters either side) for each. argv[1] = family name in scripts/conditions.json.
# SQL run (5 per call): SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache
#   WHERE (volume_id, document_id) IN (VALUES (?,?),...);
import json, re, sqlite3, sys
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
name, d0, d1, n = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
spec = json.load(open(R + "scripts/conditions.json"))[name]
rt = re.compile(spec["tolerant"], re.I)
r2 = {}
for line in open(R + "out/hits_R2.tsv"):
    v, d, di, p = line.rstrip("\n").split("\t"); r2[(v, d)] = di
ids = []
for line in open(R + "out/cond_hits_%s.tsv" % name):
    v, d, di, s, t = line.rstrip("\n").split("\t")
    if (v, d) in r2 and d0 <= di < d1:
        ids.append((v, d))
ids = sorted(ids); M = len(ids)
samp = ids if M <= n else [ids[int(i * M / n)] for i in range(n)]
print("family", name, "window", d0, d1, "R2-and-family documents:", M, "sample:", len(samp))
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for i in range(0, len(samp), 5):
    chunk = samp[i:i + 5]
    q = "SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache WHERE (volume_id, document_id) IN (VALUES %s)" % ",".join(["(?,?)"] * len(chunk))
    for v, d, h, dl, sn, b in sorted(con.execute(q, [x for k in chunk for x in k])):
        t = " ".join(" ".join([h or "", dl or "", sn or "", b or ""]).split())
        m = rt.search(t)
        ctx = t[max(0, m.start() - 300): m.end() + 300] if m else "(no tolerant match)"
        print("== %s/%s %s\n   %s" % (v, d, r2[(v, d)], ctx))
