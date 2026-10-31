import sys; sys.path.insert(0,".")
import vec, json, sqlite3, numpy as np, itertools
keys=[tuple(k.split("/")) for k in open("scope_keys.txt").read().split()]
rows=[vec.row_of[k] for k in keys]
S=vec.signs[rows]
pairs=[]
for i,j in itertools.combinations(range(len(keys)),2):
    pairs.append((int(np.bitwise_count(np.bitwise_xor(S[i],S[j])).sum()),keys[i],keys[j]))
pairs.sort()
print("pairwise Hamming among the",len(keys),"cited documents: 6 smallest")
for p in pairs[:6]: print(" ",p[0],"/".join(p[1]),"/".join(p[2]))
print("min",pairs[0][0],"median",int(np.median([p[0] for p in pairs])))
# Ed2 check
print("cited volumes ending Ed2:",[k for k in keys if k[0].endswith("Ed2")])
# nearest-neighbour hamming to Ed2 twin for d292
print("d292 vs Ed2 twin:",int(np.bitwise_count(np.bitwise_xor(vec.signs[vec.row_of[('frus1969-76ve15p2','d292')]],vec.signs[vec.row_of[('frus1969-76ve15p2Ed2','d292')]])).sum()))
# semantic join: neighbours (top 25) of Saudi airgram into dates and sources
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
print("semantic join: 25 nearest neighbours of frus1969-76ve09p2/d122 -> document_dates.date_iso, document_sources.repository/record_group")
for dist,key in vec.neighbours(vec.row_of[('frus1969-76ve09p2','d122')],25):
    r=con.execute("SELECT dd.date_iso,ds.repository,ds.record_group FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id LEFT JOIN document_sources ds ON ds.volume_id=d.volume_id AND ds.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?",key).fetchone()
    print(" ",dist,"/".join(key),r if r else "NOT IN document_cache")
