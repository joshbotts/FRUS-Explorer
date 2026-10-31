import sqlite3, sys, os, re
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB,uri=True)
SQL="SELECT c.volume_id,c.document_id,c.header,c.dateline,c.source_note,c.body_text,length(c.body_text),t.date_iso FROM document_cache c LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=? AND c.is_front_matter=0 AND c.is_editorial_note=0"
log=open("reading.log","a")
for arg in sys.argv[1:]:
    v,d=arg.split("/")
    r=con.execute(SQL,(v,d)).fetchone()
    if not r: print("MISSING",arg); continue
    txt=r[5]
    open(f"docs/{v}__{d}.txt","w").write(txt)
    meta=f"{v}/{d} date={r[7]} header={r[2][:90]!r} dateline={r[3]!r} len_chars={r[6]} captured={len(txt)}"
    log.write(meta+"\n")
    print(meta)
