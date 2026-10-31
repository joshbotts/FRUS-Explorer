import sqlite3,sys,re,os
# usage: [VOL=volume_id] python3 q7.py <lo> <hi> <n> [fts5 match]
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
lo,hi,n=sys.argv[1],sys.argv[2],int(sys.argv[3])
q=sys.argv[4] if len(sys.argv)>4 else "corrupt OR bribe OR briberi OR kickback OR payoff OR embezzl OR malfeas OR nepot OR venal"
vol=os.environ.get("VOL","")
rows=con.execute("""SELECT c.volume_id,c.document_id,substr(c.header,1,70),d.date_iso,snippet(frus_documents,6,'[[',']]',' … ',28)
FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso>=? AND d.date_iso<? AND (?='' OR c.volume_id=?) AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
ORDER BY bm25(frus_documents) LIMIT ?""",(q,lo,hi,vol,vol,n)).fetchall()
for r in rows: print(f"{r[0]}/{r[1]} {r[3]} | {r[2]} | {re.sub(chr(10),' ',r[4])}\n")
