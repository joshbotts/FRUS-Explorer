import sqlite3,json,sys,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=sys.argv[1:]
paths={}
def walk(vid,sec,path):
    t=" ".join((sec.get("title") or "").split()); p=path+[t] if t else path
    for d in sec.get("documentIds",[]): paths[(vid,d)]=" > ".join(p)
    for s in sec.get("subsections",[]): walk(vid,s,p)
for vid,sj in db.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id IN (%s)"%",".join("'%s'"%v for v in vols)):
    for s in json.loads(sj).get("sections",[]): walk(vid,s,[])
agg=collections.defaultdict(list)
for l in open("scope_hits.tsv",encoding="utf-8"):
    r=l.rstrip("\n").split("\t")
    if r[0] in vols: agg[(r[0],paths.get((r[0],r[1]),"?"))].append(r[1])
for k,v in sorted(agg.items()): print(k[0],"|",k[1][:130],"|",len(v),"|",",".join(v)[:100])
