import sqlite3,json,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=sys.argv[1:]
for v in vols:
    r=c.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?",(v,)).fetchone()
    print("=====",v)
    if not r: print("  (no structure)"); continue
    def walk(secs,d):
        for s in secs:
            if s.get('divType') in ('front','back') : continue
            ids=s.get('documentIds',[])
            print("  "*d+f"- {s['title'][:110]} [{len(ids)}] {ids[0] if ids else ''}-{ids[-1] if ids else ''}")
            walk(s.get('subsections',[]),d+1)
    walk(json.loads(r[0])['sections'],1)
