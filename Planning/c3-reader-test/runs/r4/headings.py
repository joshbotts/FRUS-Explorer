# Walks volume_structures.structure_json; prints every section title matching /recogni/i with its document count and ids.
import sqlite3, json, re, sys
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pat = re.compile(r'recogni', re.I)
out = []
def walk(vol, secs, path):
    for s in secs:
        t = s.get('title') or ''
        p = path + [t]
        if pat.search(t):
            ids = list(s.get('documentIds') or [])
            def collect(x):
                for ss in x.get('subsections') or []:
                    ids.extend(ss.get('documentIds') or []); collect(ss)
            collect(s)
            out.append((vol, ' > '.join(p[-3:]), len(ids), ids))
        walk(vol, s.get('subsections') or [], p)
for vol, js in con.execute("SELECT volume_id, structure_json FROM volume_structures"):
    walk(vol, json.loads(js).get('sections', []), [])
json.dump(out, open('/Users/jbotts/frus-analysis/c3/runs/r4/recog_headings.json','w'))
for vol, t, n, ids in out:
    print(vol, '|', n, '|', t[:200])
