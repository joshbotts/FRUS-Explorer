import json
res=json.load(open("scan1_counts.json"))
la=set(l.split("\t")[0] for l in open("la_volumes.tsv"))
keys=["withhold_recognition","nonrecognition","de_facto_gov","tobar","estrada_doctrine","recognition_policy","military_junta"]
score={}
for k in keys:
    for v,c in res[k].items():
        score.setdefault(v,{})[k]=c
rows=[]
for v,d in score.items():
    rows.append((sum(d.values()),v,v in la,d))
rows.sort(reverse=True)
with open("rank1.tsv","w") as f:
    for s,v,inla,d in rows:
        f.write(f"{s}\t{v}\t{'LA' if inla else '-'}\t{json.dumps(d)}\n")
for r in rows[:60]: print(r[0],r[1],"LA" if r[2] else "-",r[3])
