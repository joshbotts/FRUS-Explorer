# Literal-share census for a phrase family over its whole hit list (case-insensitive Python re for both forms)
import sqlite3,re,sys
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL=("SELECT c.volume_id,c.document_id,c.header||' '||coalesce(c.dateline,'')||' '||coalesce(c.source_note,'')||' '||c.body_text FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid "
     "WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY c.volume_id,c.document_id")
q=sys.argv[1]; strict=re.compile(sys.argv[2],re.I); tol=re.compile(sys.argv[3],re.I)
rows=con.execute(SQL,(q,)).fetchall(); print("SQL:",SQL,"MATCH",q)
s=t=0
for v,d,x in rows:
    x=" ".join(x.split()); a=bool(strict.search(x)); b=bool(tol.search(x)); s+=a; t+=b
    print(" ",v,d,"strict" if a else "-", "tolerant" if b else "-")
print(f"STRICT {s} of {len(rows)}; TOLERANT {t} of {len(rows)}")
