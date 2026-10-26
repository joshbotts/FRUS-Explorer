# Print FTS5 snippets for documents in a hit list (argv[1], TSV with volume_id, document_id first) that match an FTS
# expression (argv[2]), restricted to a document-date window [argv[3], argv[4]), ordered by date.
# SQL run: SELECT f.volume_id, f.document_id, snippet(frus_documents, -1, '[[', ']]', '…', 40) FROM frus_documents f
#          WHERE frus_documents MATCH :expr AND f.volume_id=:v AND f.document_id=:d;
#          SELECT header FROM document_cache WHERE volume_id=:v AND document_id=:d;
import sqlite3, sys
hits_file, expr, d0, d1 = sys.argv[1:5]
ids = []
for line in open(hits_file):
    f = line.rstrip("\n").split("\t")
    ids.append((f[2], f[0], f[1]))
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
n = 0
for di, v, d in sorted(ids):
    if not (d0 <= di < d1): continue
    r = con.execute("SELECT snippet(frus_documents, -1, '[[', ']]', '…', 40) FROM frus_documents f WHERE frus_documents MATCH ? AND f.volume_id=? AND f.document_id=?", (expr, v, d)).fetchone()
    if not r: continue
    h = con.execute("SELECT header FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0]
    n += 1
    print("%s %s/%s | %s\n    %s" % (di, v, d, " ".join(h.split())[:110], " ".join(r[0].split())))
print("documents printed:", n)
