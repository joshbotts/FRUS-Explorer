import sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
core=[l.split("\t")[:2] for l in open("core_scope.tsv")]
db.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT, PRIMARY KEY(volume_id,document_id))"); db.executemany("INSERT INTO core VALUES(?,?)",core)
for name,q,tol,stem in [("constitutional government",'"constitutional government"',r"constitutional(?:ly)?[\s,\-\.\(\)]+governments?",r".{40}constitution\w*[\s,\-\.\(\)]+govern\w*.{40}"),
 ("withhold recognition",'NEAR(withhold recognition, 4) OR NEAR(withheld recognition, 4) OR NEAR(withholding recognition, 4)',r"withh(?:old|eld|olding)[\s,\-\.\(\)]+(?:\w+[\s,\-\.\(\)]+){0,3}recognition",r".{60}withh\w+.{80}")]:
    hits=db.execute("SELECT d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN core c ON c.volume_id=d.volume_id AND c.document_id=d.document_id WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0",(q,)).fetchall()
    print("##",name,len(hits))
    for v,d,*parts in hits:
        t=" ".join(" ".join(p or "" for p in parts).split())
        if not re.search(tol,t,re.I):
            m=re.search(stem,t,re.I); print(" MISS",v,d,"::",(m.group(0) if m else "no stem context")[:170])
