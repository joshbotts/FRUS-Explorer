import sqlite3,json,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
rows=[l.rstrip("\n").split("\t") for l in open("scope_hits_post1950_AR.tsv",encoding="utf-8")]
vols=sorted(set(r[0] for r in rows))
paths={}
def walk(vid,sec,path):
    t=" ".join((sec.get("title") or "").split())
    p=path+[t] if t else path
    for d in sec.get("documentIds",[]): paths[(vid,d)]=" > ".join(p)
    for s in sec.get("subsections",[]): walk(vid,s,p)
for vid,sj in db.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id IN (%s)"%",".join("'%s'"%v for v in vols)):
    for s in json.loads(sj).get("sections",[]): walk(vid,s,[])
agg=collections.defaultdict(list)
for r in rows: agg[(r[0],paths.get((r[0],r[1]),"?"))].append((r[1],r[2]))
with open("chapters_post1950_AR.tsv","w") as f:
    for (v,p),ds in sorted(agg.items()):
        f.write(f"{v}\t{p}\t{len(ds)}\t{','.join(d for d,_ in ds)}\n")
        print(v,"|",p[:120],"|",len(ds),"|",",".join(d for d,_ in ds)[:120])
