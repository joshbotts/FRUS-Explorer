# prints chapter headings (structure_json) for volumes given as args
import sqlite3,json,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def walk(n,d=0):
    if isinstance(n,dict):
        t=n.get('title') or n.get('head') or n.get('name')
        ids=n.get('documentIds') or n.get('documents') or []
        if t: print('  '*d+str(t)[:120], ('['+str(len(ids))+' docs: '+(str(ids[0])+'..'+str(ids[-1]) if ids else '')+']') if ids else '')
        for k in ('children','sections','chapters','subsections'):
            for ch in n.get(k,[]) or []: walk(ch,d+1)
    elif isinstance(n,list):
        for x in n: walk(x,d)
for v in sys.argv[1:]:
    r=c.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?",(v,)).fetchone()
    print('==',v); 
    if not r: print('none'); continue
    j=json.loads(r[0]); 
    if isinstance(j,dict): print('keys',list(j.keys()))
    walk(j)
