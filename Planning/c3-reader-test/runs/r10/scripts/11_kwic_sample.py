# Print the first tolerant-regex context (KWIC, 230 chars either side) for each document in the sample line of a
# literal-share output file (10_literal_share.py), plus the document's heading path, for the referent test.
# SQL run (5 per call): SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache
#   WHERE (volume_id, document_id) IN (VALUES (?,?),...);
import re, sqlite3, sys
share_file, tol_file = sys.argv[1], sys.argv[2]
tol = re.compile(open(tol_file).read().strip(), re.I)
ids = []
for line in open(share_file):
    if line.startswith("sample ids:"):
        ids = [tuple(x.split("/")) for x in line.split(":", 1)[1].split()]
paths = {}
for line in open("/Users/jbotts/frus-analysis/c3/runs/r10/out/doc_paths.tsv"):
    f = line.rstrip("\n").split("\t")
    paths[(f[0], f[1])] = (f[4], f[6])
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for i in range(0, len(ids), 5):
    chunk = ids[i:i + 5]
    q = "SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache WHERE (volume_id, document_id) IN (VALUES %s)" % ",".join(["(?,?)"] * len(chunk))
    for v, d, h, dl, sn, b in sorted(con.execute(q, [x for k in chunk for x in k])):
        t = " ".join(" ".join([h or "", dl or "", sn or "", b or ""]).split())
        m = tol.search(t)
        ctx = t[max(0, m.start() - 230): m.end() + 230] if m else "(no tolerant match)"
        di, p = paths.get((v, d), ("", ""))
        print("== %s/%s | %s | %s\n   %s\n" % (v, d, di, p[-140:], ctx))
