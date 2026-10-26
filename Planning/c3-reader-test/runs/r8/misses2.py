import sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ids=[("frus1913","d1104"),("frus1914","d776"),("frus1914","d865"),("frus1916","d223"),("frus1916","d229"),("frus1916","d235"),("frus1919v01","d886"),("frus1920v02","d628"),("frus1930v03","d135"),("frus1930v03","d653"),("frus1933v05","d420"),("frus1944v07","d236")]
for v,d in ids:
    r=db.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    t=" ".join(" ".join(p or "" for p in r).split())
    ms=[m.group(0) for m in re.finditer(r".{25}constitut\w*\W+govern\w*.{25}",t,re.I)]
    print(v,d,"|",ms[:2] if ms else "NO constitut*+govern* adjacency")
