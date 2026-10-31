import json,pickle,sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
S=[tuple(x) for x in json.load(open("work/set.json"))]

json.dump(S,open("work/set.json","w"))
fam=set(map(tuple,json.load(open("work/family_hits.json"))))
nx=open("nexus.txt").read().strip()
nxs=set(con.execute("SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ?",(nx,)).fetchall())
q9=set(con.execute("""SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '"questionable payments" OR "foreign corrupt practices" OR (lockheed AND (bribe OR briberi OR corrupt))'""").fetchall())
nb=pickle.load(open("work/neighbors.pkl","rb"))
nbset={}
for a,rows in nb.items():
    for r in rows: nbset.setdefault(r[1],[]).append(a)
print("doc | in family FTS | in nexus FTS | in lockheed/FCPA FTS | in a vector neighbour list of")
for f,v,d in S:
    k=(v,d)
    print(f"{f} {v}/{d} | {k in fam} | {k in nxs} | {k in q9} | {nbset.get(k,'-')}")
