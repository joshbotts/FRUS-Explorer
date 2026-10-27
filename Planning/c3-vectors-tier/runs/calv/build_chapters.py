# Builds scratch db chapters.db: (volume_id, document_id, ord, chapter_id, chapter_header) from document_cache in rowid order. Read-only on the source.
import sqlite3
src=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
dst=sqlite3.connect("/Users/jbotts/frus-analysis/c3/runs/r5/chapters.db")
dst.execute("DROP TABLE IF EXISTS ch"); dst.execute("CREATE TABLE ch(volume_id,document_id,ord INTEGER,chapter_id,chapter_header,is_heading INTEGER,PRIMARY KEY(volume_id,document_id))")
cur=src.execute("SELECT volume_id,document_id,header,is_front_matter,is_editorial_note FROM document_cache ORDER BY volume_id,rowid")
pv=None;chid=None;chh=None;o=0;rows=[]
for v,d,h,fm,en in cur:
    if v!=pv: pv=v;chid=None;chh=None;o=0
    o+=1
    heading = d.startswith('ch') or d in('preface',) or (not d.startswith('d'))
    if d.startswith('ch'):
        chid=d;chh=' '.join(h.split())
    rows.append((v,d,o,chid,chh,1 if d.startswith('ch') else 0))
    if len(rows)>50000: dst.executemany("INSERT INTO ch VALUES(?,?,?,?,?,?)",rows);rows=[]
dst.executemany("INSERT INTO ch VALUES(?,?,?,?,?,?)",rows);dst.commit()
print(dst.execute("select count(*) from ch").fetchone())
