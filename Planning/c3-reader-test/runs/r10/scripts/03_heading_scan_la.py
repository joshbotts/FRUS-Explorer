# Walk every volume's editorial structure and print each heading whose title matches TOPIC and whose full
# path (ancestors + title) mentions a Latin American country or regional term. Prints the volume, section id,
# number of documents under the heading, the path, and the first..last document ids.
# SQL run: SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id;
import json, re, sqlite3, sys
topic = re.compile(sys.argv[1], re.I)
LA = re.compile(r"Argentin|Bolivi|Brazil|Chile|Colombia|Costa Rica|Cuba|Dominican|Santo Domingo|Ecuador|Salvador|"
                r"Guatemala|Haiti|Honduras|Mexic|Nicaragua|Panam|Paraguay|Peru|Uruguay|Venezuela|Central America|"
                r"American Republics|Latin America|Western Hemisphere|Inter-American|Hemisphere|Caribbean", re.I)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows = con.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id").fetchall()
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
            t = re.sub(r"\s+", " ", (s.get("title") or ""))
            p = path + [t]
            if topic.search(t) and LA.search(" > ".join(p)):
                hits += 1
                d = alldocs(s)
                print("%s\t%s\t%d\t%s\t%s" % (vid, s.get("sectionId"), len(d), " > ".join(p), (d[0] + ".." + d[-1]) if d else ""))
            walk(s.get("subsections") or [], p)
    walk(st.get("sections") or [], [])
print("headings matched:", hits)
