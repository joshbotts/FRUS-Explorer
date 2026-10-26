# Walk volume_structures JSON; print every section title matching a regex (case-insensitive), with its volume and doc count
import sqlite3, json, re, sys
pat = re.compile(sys.argv[1], re.I)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def walk(v, secs, path):
    for s in secs:
        t = s.get("title") or ""
        ids = s.get("documentIds") or []
        def alld(x):
            n = list(x.get("documentIds") or [])
            for c in x.get("subsections") or []: n += alld(c)
            return n
        if pat.search(t):
            d = alld(s)
            print(f"{v}\t{len(d)}\t{' > '.join(path+[t])[:220]}\t{','.join(d[:3])}..{','.join(d[-1:])}")
        walk(v, s.get("subsections") or [], path+[t])
for v, sj in con.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id"):
    j = json.loads(sj)
    walk(v, j.get("sections") or [], [])
