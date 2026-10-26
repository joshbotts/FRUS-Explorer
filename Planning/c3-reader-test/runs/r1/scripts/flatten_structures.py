# flatten volume_structures.structure_json into work/structure_flat.tsv: volume_id, document_id, depth, path of section titles
import json, re, sys
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
conn = frus.connect()
rows = frus.sql(conn, "SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id", script="scripts/flatten_structures.py")
out = open(frus.RUN + "/work/structure_flat.tsv", "w")
out.write("volume_id\tdocument_id\tpath\n")
ndocs = 0
def walk(node, path, vid):
    global ndocs
    t = re.sub(r"\s+", " ", node.get("title") or "").strip()
    p = path + [t] if t else path
    for d in node.get("documentIds") or []:
        out.write("%s\t%s\t%s\n" % (vid, d, " > ".join(p)))
        ndocs += 1
    for s in node.get("subsections") or []:
        walk(s, p, vid)
for vid, js in rows:
    j = json.loads(js)
    for s in j.get("sections", []):
        walk(s, [], vid)
out.close()
print(len(rows), "volumes;", ndocs, "document ids placed in sections")
