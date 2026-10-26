import sqlite3, json, re, sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pat=re.compile(sys.argv[1],re.I); ctry=re.compile(sys.argv[2],re.I)
lo,hi=sys.argv[3],sys.argv[4]
for vid,sj in db.execute("select volume_id,structure_json from volume_structures order by volume_id"):
    yr=re.match(r'frus(\d{4})',vid)
    if not yr or not (lo<=yr.group(1)<=hi): continue
    j=json.loads(sj)
    def walk(secs,path):
        for s in secs:
            t=re.sub(r'\s+',' ',(s.get('title') or ''))
            p=path+[t]
            full=' > '.join(p)
            if pat.search(t) and ctry.search(full):
                def cnt(s):
                    return len(s.get('documentIds',[]))+sum(cnt(x) for x in s.get('subsections',[]))
                print(vid,'|',' > '.join(p[-2:])[:230],'|',cnt(s))
            walk(s.get('subsections',[]),p)
    walk(j.get('sections',[]),[])
