import json,re,sys
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
la_tags={"mexico","guatemala","honduras","el-salvador","nicaragua","costa-rica","panama","cuba","haiti","dominican-republic","colombia","venezuela","ecuador","peru","bolivia","chile","argentina","brazil","paraguay","uruguay"}
title_re=re.compile(r"American Republics|Western Hemisphere|Latin America|Inter-American|Mexico|Central America|Caribbean|Cuba|Chile|Argentina|Brazil|Dominican|Guatemala|Panama|Nicaragua|Haiti|Peru|Venezuela|Bolivia|Colombia|Ecuador|Honduras|Salvador|Uruguay|Paraguay",re.I)
out=[]
for v in m:
    t=" ".join(v["title"].split())
    tagged=len(la_tags & set(v.get("tags",[])))
    if title_re.search(t) or tagged>=3:
        out.append((v["volumeId"],v["dateRange"]["earliest"][:4],v["dateRange"]["latest"][:4],v.get("publicationDate"),tagged,t[:110]))
out.sort(key=lambda r:r[1])
with open("la_volumes.tsv","w") as f:
    for r in out: f.write("\t".join(map(str,r))+"\n")
print(len(out))
