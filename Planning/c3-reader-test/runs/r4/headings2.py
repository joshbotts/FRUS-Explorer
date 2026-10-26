# Same walk as headings.py; titles matching coup/junta/overthrow/de facto/diplomatic relations/military government, volumes 1945 onward.
import sqlite3, json, re
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pat = re.compile(r"coup|junta|overthrow|de facto|continuity of|military government|military regime|resumption of (diplomatic )?relations|recogni", re.I)
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
            print(vol, '|', len(ids), '|', ' > '.join(p[-3:])[:220], '|', ','.join(ids[:3]))
        walk(vol, s.get('subsections') or [], p)
for vol, js in con.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id >= 'frus1945' ORDER BY volume_id"):
    walk(vol, json.loads(js).get('sections', []), [])
