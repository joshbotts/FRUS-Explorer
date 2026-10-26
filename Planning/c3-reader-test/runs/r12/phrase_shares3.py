# Census literal share for "estrada doctrine" across the whole library (non-apparatus documents).
import sqlite3, re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
SEP=r"[\s\-,\(\)\.]*"
hits=db.execute("""SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
 WHERE frus_documents MATCH '"estrada doctrine"' AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY 1,2""").fetchall()
cs=ct=0; vols=set()
for v,d in hits:
    h,dl,sn,b=db.execute("select header,dateline,coalesce(source_note,''),body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    t=re.sub(r"\s+"," "," ".join([h or "",dl or "",sn,b or ""]))
    cs+=bool(re.search(r"estrada doctrine",t,re.I)); ct+=bool(re.search(r"estrada"+SEP+r"doctrines?",t,re.I)); vols.add(v)
print("estrada doctrine | M=%d in %d volumes | census | STRICT %d of %d | TOLERANT %d of %d"%(len(hits),len(vols),cs,len(hits),ct,len(hits)))
# context: how many of the hits are in editors' footnote-like text vs document text cannot be separated here (body_text includes footnotes)
