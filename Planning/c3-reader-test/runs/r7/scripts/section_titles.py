# Dumps every section title in volume_structures to out/section_titles.tsv: volume_id, path of titles, divType, n documents
import sqlite3, json, sys
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
out = open("/Users/jbotts/frus-analysis/c3/runs/r7/out/section_titles.tsv", "w")
def walk(vid, secs, path):
    for s in secs:
        title = (s.get("title") or "").replace("\n"," ").replace("\t"," ")
        title = " ".join(title.split())
        p = path + [title]
        ndocs = len(s.get("documentIds") or [])
        out.write("\t".join([vid, s.get("divType",""), s.get("sectionId",""), str(ndocs), " > ".join(p)]) + "\n")
        walk(vid, s.get("subsections") or [], p)
n=0
for vid, sj in con.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id"):
    walk(vid, json.loads(sj).get("sections", []), [])
    n+=1
out.close()
print("volumes:", n)
