import sqlite3,json,re,collections
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
SQL="SELECT volume_id, structure_json FROM volume_structures"
print("SQL:",SQL)
out=[]
def walk(n,vol,path):
    if isinstance(n,dict):
        t=n.get('title') or n.get('head') or ''
        if isinstance(t,str) and re.search(r'cuba',t,re.I):
            ids=[]
            out.append((vol,' '.join(t.split()),len(n.get('documentIds',n.get('documents',[]) or []))))
        for k,v in n.items():
            if isinstance(v,(list,dict)): walk(v,vol,path)
    elif isinstance(n,list):
        for x in n: walk(x,vol,path)
first=True
for vol,js in c.execute(SQL):
    j=json.loads(js)
    if first: print("keys:",list(j)[:10] if isinstance(j,dict) else type(j)); first=False
    walk(j,vol,[])
print(len(out),"headings matching /cuba/i")
for o in out: print(o)
