import sqlite3,re,json
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
title={v['volumeId']:re.sub(r'\s+',' ',v['title']) for v in m}
pairs=[l.split() for l in open("/Users/jbotts/frus-analysis/c3/runs/r11/cited.txt")]
for v,d in pairs:
    r=con.execute("SELECT document_number, header, dateline, source_note, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    dt=con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    print("%s/%s docnum=%s date=%s fm=%s en=%s len=%s\n   VOL: %s\n   HDR: %s\n   DL : %s\n   SRC: %s"%(v,d,r[0],dt[0] if dt else None,r[5],r[6],r[4],title.get(v),re.sub(r'\s+',' ',r[1])[:200],(r[2] or '')[:120],re.sub(r'\s+',' ',r[3] or '')[:160]))
