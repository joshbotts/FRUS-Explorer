import sqlite3,json,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
la=set(l.split("\t")[0] for l in open("la_volumes.tsv"))
pat=re.compile(r"recogni",re.I)
out=[]
def walk(vid,sec,path):
    t=" ".join((sec.get("title") or "").split())
    p=path+[t] if t else path
    ids=sec.get("documentIds",[])
    if t and pat.search(t):
        out.append((vid," > ".join(p),len(ids),ids[:1]+ids[-1:]))
    for s in sec.get("subsections",[]): walk(vid,s,p)
for vid,sj in db.execute("SELECT volume_id, structure_json FROM volume_structures"):
    j=json.loads(sj)
    for s in j.get("sections",[]): walk(vid,s,[])
with open("headings_recognition.tsv","w") as f:
    for r in out: f.write("\t".join([r[0],r[1],str(r[2]),",".join(r[3])])+"\n")
print(len(out),"headings;", sum(1 for r in out if r[0] in la),"in LA-tagged volumes")
for r in out: print(r[0],"|",r[1][:150],"|",r[2],r[3])
