import sqlite3, json, re, sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pat=re.compile(sys.argv[1],re.I)
for vid,sj in db.execute("select volume_id,structure_json from volume_structures order by volume_id"):
    j=json.loads(sj)
    def walk(secs,path):
        for s in secs:
            t=(s.get('title') or '').replace('\n',' ')
            t=re.sub(r'\s+',' ',t)
            p=path+[t]
            if pat.search(t):
                print(vid,'|',' > '.join(p[-3:]),'|',len(s.get('documentIds',[])),'docs-direct')
            walk(s.get('subsections',[]),p)
    walk(j.get('sections',[]),[])
