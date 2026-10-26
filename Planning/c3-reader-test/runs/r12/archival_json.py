# Aggregates bundled JSON (collection-usage-index = came-from-ish usage of citations in the volume's source notes; external-citation-index = pointed-at) for the scope volumes.
import json, sqlite3, collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
s=sqlite3.connect("scope.db")
vols=[r[0] for r in s.execute("select distinct volume_id from scope")]
print("scope volumes",len(vols))
U=json.load(open(R+"collection-usage-index.json"))
E=json.load(open(R+"external-citation-index.json"))
A=json.load(open(R+"collection-authority.json"))
auth={c['id']:c for c in A['collections']}
print("usage keys",list(U.keys()))
uv={v:i for i,v in enumerate(U['volumes'])}
ev={v:i for i,v in enumerate(E['volumes'])}
inU=[v for v in vols if v in uv]; inE=[v for v in vols if v in ev]
print("scope vols in usage index",len(inU),"in external-citation index",len(inE))
# usage: collections rows {k, n[], v[]} -> n[i] count for volume index v[i]
tot=collections.Counter()
for row in U['collections']:
    for n,v in zip(row['n'],row['v']):
        if U['volumes'][v] in vols: tot[U['collectionIds'][row['k']]]+=n
print("USAGE (collection-usage-index, notes in scope volumes), top 25:")
for cid,n in tot.most_common(25):
    c=auth.get(cid,{})
    print(n,cid,'|',(c.get('name') or '')[:110])
print("total collection cites",sum(tot.values()),"distinct",len(tot))
print("coverage keys E:",json.dumps(E['coverage'])[:1500])
print("E targets row sample",E['targets'][:2], "pairs sample", E['pairs'][:2])
tt=collections.Counter()
for row in E['targets']:
    for n,v in zip(row['n'],row['v']):
        if E['volumes'][v] in vols: tt[E['targetIds'][row['k']]]+=n
print("POINTED-AT (external-citation-index) top 25:")
for cid,n in tt.most_common(25):
    c=auth.get(cid,{})
    print(n,cid,'|',(c.get('name') or '')[:110])
print("total",sum(tt.values()),"distinct",len(tt))
json.dump({"usage":tt and tot.most_common(200),"pointed":tt.most_common(200)},open("archival_json_out.json","w"))
