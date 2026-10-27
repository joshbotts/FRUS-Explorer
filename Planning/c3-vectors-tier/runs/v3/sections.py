import sqlite3, json, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
out=[]
def walk(vid, secs, path):
    for s in secs:
        t = s.get("title") or ""
        p = path+[t]
        if re.search(r'cuba|havana|guant', t, re.I):
            ids = s.get("documentIds") or []
            sub = 0
            def cnt(x):
                n=len(x.get("documentIds") or [])
                for y in x.get("subsections") or []: n+=cnt(y)
                return n
            out.append((vid, " > ".join(p[-3:]), cnt(s), (ids[:1]+ids[-1:])))
        walk(vid, s.get("subsections") or [], p)
for vid, js in db.execute("select volume_id, structure_json from volume_structures order by volume_id"):
    walk(vid, json.loads(js).get("sections") or [], [])
with open("cuba_sections.tsv","w") as f:
    for r in out: f.write("\t".join(map(str,r))+"\n")
print(len(out))
