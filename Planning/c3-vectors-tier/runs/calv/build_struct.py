# Builds struct.db: doc -> section path from volume_structures.structure_json (read-only on source)
import sqlite3,json
src=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
dst=sqlite3.connect("/Users/jbotts/frus-analysis/c3/runs/r5/struct.db")
dst.execute("DROP TABLE IF EXISTS sd");dst.execute("CREATE TABLE sd(volume_id,document_id,section_id,path,PRIMARY KEY(volume_id,document_id))")
n=0
def walk(v,node,path,rows):
    t=' '.join((node.get('title') or '').split())
    p=path+[t] if t else path
    for d in node.get('documentIds',[]) or []:
        rows.append((v,d,node.get('sectionId'),' > '.join(p)))
    for s in node.get('subsections',[]) or []:
        walk(v,s,p,rows)
for v,js in src.execute("select volume_id,structure_json from volume_structures"):
    j=json.loads(js);rows=[]
    for s in j['sections']: walk(v,s,[],rows)
    dst.executemany("INSERT OR REPLACE INTO sd VALUES(?,?,?,?)",rows);n+=len(rows)
dst.commit();print(n)
