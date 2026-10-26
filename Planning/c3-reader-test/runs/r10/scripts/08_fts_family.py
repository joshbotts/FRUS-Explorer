# Run one FTS5 MATCH expression (argv[2]) over frus_documents, keep non-apparatus documents, intersect with the
# Latin American universe (out/doc_paths.tsv, la_flag=1), drop the two second editions, and write the hit list
# (sorted by volume_id, document_id) to out/hits_<name>.tsv with date_iso and path. Prints counts by decade.
# Structural records (document_id not GLOB 'd[0-9]*' / '*_d[0-9]*': chapter and section heading rows) are dropped.
# SQL run (MATCH expression substituted):
#   SELECT f.volume_id, f.document_id FROM frus_documents f
#   JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
#   WHERE frus_documents MATCH :expr AND c.is_front_matter=0 AND c.is_editorial_note=0;
import sqlite3, sys, collections
name, expr = sys.argv[1], sys.argv[2]
DROP = {"frus1951-54IranEd2", "frus1969-76ve15p2Ed2"}
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
meta = {}
for line in open(R + "out/doc_paths.tsv"):
    v, d, fm, ed, di, la, p, isdoc = line.rstrip("\n").split("\t")
    meta[(v, d)] = (di, la, p, isdoc)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows = con.execute("""SELECT f.volume_id, f.document_id FROM frus_documents f
   JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
   WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0""", (expr,)).fetchall()
allhits = [r for r in rows if r[0] not in DROP and meta[r][3] == "1"]
la = sorted([r for r in allhits if meta[r][1] == "1"])
dec_all = collections.Counter((meta[r][0][:3] + "0s") if meta[r][0] else "undated" for r in allhits)
dec_la = collections.Counter((meta[r][0][:3] + "0s") if meta[r][0] else "undated" for r in la)
with open(R + "out/hits_%s.tsv" % name, "w") as f:
    for r in la:
        di, _, p, _ = meta[r]
        f.write("%s\t%s\t%s\t%s\n" % (r[0], r[1], di, p))
print("family", name, "expr:", expr)
print("corpus hits (non-apparatus, Ed2 dropped):", len(allhits), " in LA universe:", len(la), " LA volumes:", len({r[0] for r in la}))
print("decade\tcorpus\tLA")
for k in sorted(set(dec_all) | set(dec_la)):
    print("%s\t%d\t%d" % (k, dec_all[k], dec_la[k]))
