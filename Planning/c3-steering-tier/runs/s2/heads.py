# editors' headings (volume_structures.structure_json) that name the subject
import sqlite3, json, re
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL="SELECT volume_id, structure_json FROM volume_structures"
print("SQL:", SQL)
pat = re.compile(r"corrupt|brib|graft|kickback|embezzl|lockheed|payoff|pay-off|illicit payment|improper payment|questionable payment|Corrupt Practices", re.I)
def walk(o, path, vol):
    if isinstance(o, dict):
        t = o.get("title") or o.get("head") or o.get("name")
        if isinstance(t,str) and pat.search(t): print(vol, "|", t[:200])
        for v in o.values(): walk(v, path, vol)
    elif isinstance(o, list):
        for v in o: walk(v, path, vol)
n=0
for v, s in con.execute(SQL):
    n+=1
    if n==1: print("keys sample:", list(json.loads(s).keys())[:10])
    walk(json.loads(s), [], v)
print("volumes read", n)
