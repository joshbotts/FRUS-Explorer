# Walk volume_structures; list every section whose title mentions Cuba (case-insensitive regex r'cuba|havana'), with doc count incl. descendants
import sqlite3, json, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pat = re.compile(r'cuba|havana', re.I)
out = []
def count(s):
    return len(s.get("documentIds", [])) + sum(count(x) for x in s.get("subsections", []))
def ids(s):
    r = list(s.get("documentIds", []))
    for x in s.get("subsections", []): r += ids(x)
    return r
def walk(v, s, path):
    t = (s.get("title") or "").strip()
    p = path + [t]
    if pat.search(t):
        out.append((v, " > ".join(p), count(s), ids(s)))
        return
    for x in s.get("subsections", []): walk(v, x, p)
for v, js in db.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id"):
    for s in json.loads(js).get("sections", []): walk(v, s, [])
with open("cuba_chapters.tsv", "w") as f:
    for v, p, n, i in out:
        f.write(f"{v}\t{n}\t{p}\t{','.join(i)}\n")
for v, p, n, i in out: print(v, n, p[:150])
print("TOTAL sections", len(out), "docs", sum(x[2] for x in out))
