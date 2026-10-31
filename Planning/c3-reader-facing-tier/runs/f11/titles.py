import json,re,sqlite3
from docs_list import COLL
m={v["filename"][:-4]:re.sub(r"\s+"," ",v["title"]) for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
out={}
for v,d in COLL:
    r=db.execute("SELECT document_number,dateline,substr(replace(header,char(10),' '),1,150) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    out[v+"/"+d]={"title":m[v],"docnum":r[0],"dateline":r[1],"header":re.sub(r"\s+"," ",r[2])}
    print(v+"/"+d,"|",r[0],"|",r[1],"|",m[v])
json.dump(out,open("titles.json","w"),indent=1)
