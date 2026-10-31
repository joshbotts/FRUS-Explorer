import sqlite3, re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
for phrase,strict,tol in [('"foreign corrupt practices"',r"foreign corrupt practices",r"foreign[\s,\-()\.]*corrupt\w*[\s,\-()\.]*practice\w*"),('"questionable payments"',r"questionable payments",r"questionabl\w*[\s,\-()\.]*payment\w*")]:
    sql="SELECT c.volume_id,c.document_id,c.header||' '||COALESCE(c.dateline,'')||' '||COALESCE(c.source_note,'')||' '||c.body_text FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN "+ED2+" ORDER BY 1,2"
    rows=con.execute(sql,(phrase,)).fetchall()
    S=sum(1 for r in rows if re.search(strict,re.sub(r"\s+"," ",r[2]),re.I)); T=sum(1 for r in rows if re.search(tol,re.sub(r"\s+"," ",r[2]),re.I))
    print(f"PHRASE {phrase}: FTS docs {len(rows)} (census, all); STRICT literal {S} of {len(rows)}; TOLERANT literal {T} of {len(rows)}")
    print("  docs:",[r[0]+"/"+r[1] for r in rows])
