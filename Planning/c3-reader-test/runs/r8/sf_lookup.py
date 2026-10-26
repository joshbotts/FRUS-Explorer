import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
sf=json.load(open(R+"series-facts-index.json")); km=sf["legend"]["keys"]
def expand(row):
    d={}
    for k,v in row.items():
        m=km.get(k,{}); name=m.get("field",k); into=m.get("into")
        if into and into in sf:
            v=[sf[into][i] for i in v] if isinstance(v,list) else sf[into][v]
        d[name]=v
    return d
for naid in ["654171","2363840","1750062","602231","610077","2839192","27023004","26309182","26309216","1164","193236","567979","567985","560131","560151"]:
    r=sf["byNaId"].get(naid); print(naid, json.dumps(expand(r),ensure_ascii=False)[:400] if r else "NOT IN series-facts-index")
