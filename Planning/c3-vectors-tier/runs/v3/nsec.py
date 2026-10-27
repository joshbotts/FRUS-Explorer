import sqlite3, re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
EXC="AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
q=f"""select d.volume_id,d.document_id,dd.date_iso,d.body_text from frus_documents f join document_cache d on d.rowid=f.rowid join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id
 where frus_documents match '(cuba OR cuban OR cubans OR havana OR habana) AND "national security"' {EXC} and dd.date_iso<'1945' order by dd.date_iso"""
for v,d,dt,t in db.execute(q):
    t=re.sub(r"\s+"," ",t)
    m=re.search(r"national security",t,re.I)
    c=re.search(r"\bcuba\w*|havana|habana",t,re.I)
    print(f"{v}/{d} {dt} len={len(t)} NS@{m.start() if m else None} Cuba@{c.start() if c else None}: ...{t[max(0,m.start()-110):m.end()+90] if m else ''}...")
