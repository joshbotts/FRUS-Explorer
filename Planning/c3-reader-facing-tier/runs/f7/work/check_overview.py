import re,sqlite3,json,sys
sys.path.insert(0,"work")
from docs_spec import *
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
s=open("overview.md",encoding="utf-8").read()
def norm(t): return " ".join(t.replace("’","'").replace("‘","'").replace("“",'"').replace("”",'"').split())
pairs=[p for _,L in FINDINGS for p in L]
bodies={p:norm(db.execute("select body_text from document_cache where volume_id=? and document_id=?",p).fetchone()[0]) for p in pairs}
allbody=" ||| ".join(bodies.values())
frags=re.findall(r'"([^"]{6,})"',s)
bad=0
for f in frags:
    parts=[x.strip(" ,;.") for x in re.split(r"\.\.\.",f)]
    for x in parts:
        if len(x)<6: continue
        if norm(x) not in allbody:
            print("NOT FOUND:",x[:100]); bad+=1
print("quoted fragments",len(frags),"not found",bad)
urls=set(re.findall(r"historicaldocuments/(frus[\w\-]+)/(d\w+)",s))
missing=[u for u in urls if u not in set(pairs)]
print("distinct documents cited by URL",len(urls),"not in collection",missing)
