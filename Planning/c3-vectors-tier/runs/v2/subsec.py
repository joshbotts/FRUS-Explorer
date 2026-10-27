# print subsection titles (and doc ranges) under the Cuba section of given volumes, from volume_structures
import sqlite3, json, sys, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def ids(s):
    r = list(s.get("documentIds", []))
    for x in s.get("subsections", []): r += ids(x)
    return r
def walk(s, depth, inside):
    t = (s.get("title") or "").strip(); hit = inside or bool(re.search(r"cuba", t, re.I))
    if hit:
        i = ids(s); print("  " * depth + f"[{len(i)}] {t[:160]}  {i[0] if i else ''}..{i[-1] if i else ''}")
    for x in s.get("subsections", []): walk(x, depth + 1, hit)
for v in sys.argv[1:]:
    print("=== " + v)
    for s in json.loads(db.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?", (v,)).fetchone()[0])["sections"]: walk(s, 0, False)
