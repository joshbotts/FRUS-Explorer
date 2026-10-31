import sqlite3,json,re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pat=re.compile(r"corrupt|brib|graft|scandal|kickback|payoff|embezzl|malfeas|venal|nepot|misconduct|irregularit|improper",re.I)
out=[]
def walk(v,n):
    t=n.get("title","")
    if pat.search(t): out.append((v,re.sub(r"\s+"," ",t)))
    for s in n.get("subsections",[]): walk(v,s)
nvol=0
for v,j in con.execute("select volume_id,structure_json from volume_structures"):
    nvol+=1
    for s in json.loads(j)["sections"]: walk(v,s)
print("volumes scanned:",nvol,"; headings matching",pat.pattern,":",len(out))
for o in out: print(o[0],"|",o[1][:200])
print("headings matching corrupt|brib|graft|scandal|kickback|payoff|embezzl|malfeas|venal|nepot only:");[print("  ",o[0],"|",o[1][:300]) for o in out if re.search(r"corrupt|brib|graft|scandal|kickback|payoff|embezzl|malfeas|venal|nepot",o[1],re.I)]
