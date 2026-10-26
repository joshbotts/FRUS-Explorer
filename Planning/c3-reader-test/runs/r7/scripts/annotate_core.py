# Adds header, dateline and body length to the core set -> out/core_set_annotated.tsv (for choosing readings; no body text).
import sqlite3
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows=[l.rstrip("\n").split("\t") for l in open(R+"core_set.tsv")][1:]
out=open(R+"core_set_annotated.tsv","w")
for v,d,iso,a,b,p in rows:
    h,dl,n = con.execute("SELECT header, dateline, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    h=" ".join((h or "").split())[:110]; dl=" ".join((dl or "").split())[:60]
    out.write(f"{v}\t{d}\t{iso}\t{a}{b}\t{n}\t{h}\t{dl}\t{p[:90]}\n")
out.close(); print("ok", len(rows))
