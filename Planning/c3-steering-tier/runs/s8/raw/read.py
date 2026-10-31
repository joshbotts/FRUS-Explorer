# Retrieve documents whole to raw/docs/, print length and windows around a regex. usage: read.py REGEX v/d v/d ...
import sqlite3, re, sys
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL="SELECT c.header, coalesce(c.dateline,''), coalesce(c.source_note,''), c.body_text, length(c.body_text), d.date_iso FROM document_cache c LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?"
rx=re.compile(sys.argv[1],re.I); W=int(__import__('os').environ.get('W','260'))
for p in sys.argv[2:]:
    v,d=p.split("/"); r=con.execute(SQL,(v,d)).fetchone()
    if not r: print("MISSING",p); continue
    h,dl,sn,b,L,di=r
    open(f"raw/docs/{v}_{d}.txt","w").write(f"HEADER: {h}\nDATELINE: {dl}\nSOURCE: {sn}\nDATE_ISO: {di}\nLEN(body_text)={L}\n\n{b}")
    t=" ".join(b.split())
    print(f"=== {p} | {' '.join(h.split())[:110]} | {di} | len={L} captured={len(b)}")
    print("   DL:", " ".join(dl.split())[:120])
    for m in list(rx.finditer(t))[:int(__import__('os').environ.get('K','3'))]:
        print("   ...",t[max(0,m.start()-W):m.end()+W],"...")
