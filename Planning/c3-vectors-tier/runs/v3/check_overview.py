import re, glob
txt=open("overview.md",encoding="utf-8").read()
bodies={}
import os
for f in glob.glob("raw/*.body.txt"):
    bodies[os.path.basename(f)]=re.sub(r"\s+"," ",open(f,encoding="utf-8").read())
spans=re.findall(r'"([^"]{6,})"',txt)
bad=0
for sp in spans:
    c=re.sub(r"\s+"," ",sp)
    if c.startswith("Cuba, national security and prosperity"): continue
    hit=[k for k,b in bodies.items() if c in b]
    if not hit:
        bad+=1; print("NOT FOUND:",sp[:100])
print("double-quoted spans checked:",len(spans),"unmatched:",bad)
# document URLs cited vs collection
import json
col=json.load(open("collection.fruscollection"))
pairs={(e["volumeId"],e["documentId"]) for e in col["entries"] if e["kind"]=="document"}
urls=set(re.findall(r"historicaldocuments/([^/\s)]+)/([^\s),.]+)",txt))
urls={(a,b.rstrip(".,;)")) for a,b in urls}
print("cited URLs:",len(urls),"missing from collection:",sorted(urls-pairs),"collection docs not cited:",sorted(pairs-urls))
