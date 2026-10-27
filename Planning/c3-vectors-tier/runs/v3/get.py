import sqlite3, sys, os
# usage: get.py volume doc [maxchars] [offset]  -> saves full text to docs/<vol>__<doc>.txt, prints slice
v,d = sys.argv[1], sys.argv[2]
mx = int(sys.argv[3]) if len(sys.argv)>3 else 3000
off = int(sys.argv[4]) if len(sys.argv)>4 else 0
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
r = db.execute("select header, dateline, source_note, body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
os.makedirs("docs",exist_ok=True)
txt = "HEADER: %s\nDATELINE: %s\nSOURCE: %s\n\n%s" % r
open("docs/%s__%s.txt"%(v,d),"w").write(txt)
print(f"== {v}/{d} fulllen(body)={len(r[3])}")
print((r[0] or "")[:200]); print((r[1] or "")[:200])
print(r[3][off:off+mx])
