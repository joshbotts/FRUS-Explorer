import sys;sys.path.insert(0,"work")
from vec_lib import *
from docs_spec import *
import sqlite3,json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pairs=[p for _,L in FINDINGS for p in L]
rows=[row_of[p] for p in pairs]
H=np.array([[int(np.bitwise_count(np.bitwise_xor(signs[a],signs[b])).sum()) for b in rows] for a in rows])
iu=np.triu_indices(len(rows),1);vals=H[iu]
print("PAIRWISE Hamming among the 33 collection documents: n=%d min %d median %.0f; random-pair baseline mean 167.1 sd 14.8 min 95 (20000 pairs, Random(1877))"%(len(vals),vals.min(),np.median(vals)))
order=np.argsort(vals)[:8]
for o in order:
    i,j=iu[0][o],iu[1][o];print("  ham %3d  %s/%s  %s/%s"%(vals[o],*pairs[i],*pairs[j]))
print("pairs under 60:",int((vals<60).sum()),"; pairs under 40 (near-duplicate range flagged):",int((vals<40).sum()))
# unclustered share of public diplomacy volumes vs era-matched baseline
mp=np.fromfile(R+"semantic-map.bin",dtype=np.uint8);pl=mp[64:64+docs*6].reshape(docs,6)
cl=pl[:,4:6].copy().view(np.uint16).reshape(-1)
def share(vs):
    n=u=0
    for v in vs:
        o,k=vol_off[v];n+=k;u+=int((cl[o:o+k]==0xFFFF).sum())
    return u,n
pd=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
print("unclustered in the 5 public-diplomacy volumes: %d of %d"%share(pd))
u=sum(int(cl[row_of[p]]==0xFFFF) for p in pairs);print("unclustered among the 33 collection documents: %d of 33"%u)
# semantic join of neighbour lists: parse vec2.out ids
import re
ids=re.findall(r"(frus[\w\-]+)/(d\w+)",open("work/vec2.out").read())
seen=[];[seen.append(x) for x in ids if x not in seen]
print("neighbour documents listed (all anchors, incl. anchors):",len(seen))
q="select ds.record_group,ds.repository,substr(ds.series_name,1,50),substr(dd.date_iso,1,4) from document_sources ds join document_dates dd on dd.volume_id=ds.volume_id and dd.document_id=ds.document_id where ds.volume_id=? and ds.document_id=?"
for v,d in seen[:0]: pass
