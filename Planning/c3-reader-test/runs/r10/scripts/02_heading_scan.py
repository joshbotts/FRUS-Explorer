# Walk every volume's editorial structure (volume_structures.structure_json) and print every heading whose
# title matches the pattern given on the command line (case-insensitive), with its path and document count.
# SQL run: SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id;
import json, re, sqlite3, sys
pat = re.compile(sys.argv[1], re.I)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows = con.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id").fetchall()
print("volumes with a structure row:", len(rows))
def alldocs(sec):
    out = list(sec.get("documentIds") or [])
    for s in sec.get("subsections") or []:
        out += alldocs(s)
    return out
hits = 0
for vid, sj in rows:
    st = json.loads(sj)
    def walk(secs, path):
        global hits
        for s in secs:
            t = (s.get("title") or "").replace("\n", " ")
            t = re.sub(r"\s+", " ", t)
            p = path + [t]
            if pat.search(t):
                hits += 1
                d = alldocs(s)
                print("%s\t%s\t%d\t%s\t%s" % (vid, s.get("sectionId"), len(d), " > ".join(p), (d[0] + ".." + d[-1]) if d else ""))
            walk(s.get("subsections") or [], p)
    walk(st.get("sections") or [], [])
print("headings matched:", hits)
