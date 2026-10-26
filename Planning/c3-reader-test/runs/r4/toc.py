# Prints section titles (depth<=3) with document counts for the volumes given on argv.
import sqlite3, json, sys
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def cnt(s):
    n=len(s.get('documentIds') or [])
    for ss in s.get('subsections') or []: n+=cnt(ss)
    return n
def walk(secs, d):
    for s in secs:
        if s.get('divType')=='front' or s.get('divType')=='back': continue
        print('  '*d + (s.get('title') or '')[:160], '|', cnt(s), '|', ','.join((s.get('documentIds') or [])[:1]))
        if d<2: walk(s.get('subsections') or [], d+1)
for vol in sys.argv[1:]:
    js=con.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?", (vol,)).fetchone()[0]
    print('==',vol); walk(json.loads(js)['sections'],0)
