# Walk every volume_structures.structure_json tree; write one row per section:
# volume_id, depth, breadcrumb (titles joined by ' > '), title, n_docs_direct, doc_ids (direct).
# SQL run: SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id;
import json, re, sqlite3
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
out = open("out/headings.tsv", "w")
out.write("volume_id\tdepth\tbreadcrumb\ttitle\tn_docs\tdoc_ids\n")
n = 0
def walk(vol, node, depth, crumbs):
    global n
    t = re.sub(r"\s+", " ", node.get("title") or "").strip()
    ids = node.get("documentIds") or []
    path = crumbs + [t]
    out.write("\t".join([vol, str(depth), " > ".join(path), t, str(len(ids)), ",".join(ids)]) + "\n")
    n += 1
    for s in node.get("subsections") or []:
        walk(vol, s, depth + 1, path)
for vol, sj in con.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id"):
    d = json.loads(sj)
    for s in d.get("sections") or []:
        walk(vol, s, 0, [])
out.close()
print("rows", n)
