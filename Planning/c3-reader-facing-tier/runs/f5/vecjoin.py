# vecjoin.py: semantic join (Appendix A.5): neighbours of anchors -> document_dates and document_sources; and era-matched map baseline
import sys,collections; sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
import vec, numpy as np
from h import *
from nn import nn
c=conn()
anchors=[("frus1964-68v01","d122"),("frus1952-54v13p1","d116"),("frus1917-72PubDipv08","d31"),("frus1969-76v38p2","d105")]
pool={}
for a in anchors:
    for r,hm,cs,cal in nn(a,k=25):
        pool.setdefault(vec.doc_of[r],[]).append((a,hm,round(cal,3)))
print("distinct neighbours (top 25 of 4 anchors):",len(pool))
dec=collections.Counter(); rg=collections.Counter(); notidx=0; inscope=0
SQLD="SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?"
SQLS="SELECT repository, record_group, series_name FROM document_sources WHERE volume_id=? AND document_id=?"
run(c,SQLD,[ "<vol>","<doc>"],"semantic join dates (per neighbour)") if False else None
open(LOG,"a").write("SQL [semantic join, per neighbour]: "+SQLD+" ; "+SQLS+"\n")
for (v,d) in pool:
    r=c.execute(SQLD,[v,d]).fetchone()
    y=(r[0] or '')[:4] if r else ''
    dec[(y[:3]+'0s') if y else 'undated']+=1
    s=c.execute(SQLS,[v,d]).fetchone()
    rg[(s[0],s[1]) if s else ('no source row',None)]+=1
    if v in SCOPE: inscope+=1
print("decades:",sorted(dec.items()))
print("repository/record group:",rg.most_common(8))
print("neighbours in the 77-volume scope:",inscope,"of",len(pool),"; outside it:",len(pool)-inscope)
# baseline: share of non-apparatus documents by decade across the 77 scope volumes + 4 PubDip
SQLB="SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.volume_id LIKE 'frus1917-72PubDipv0%' AND d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY 1"
print("PubDip v06-v08 documents by decade:",run(c,SQLB,[],"PubDip by decade"))
# map: unclustered share, era-matched (volumes dated by mean of first and last year, rounded down)
import json
man=json.load(open(vec.R+"manifest.json"))
yr={}
for v in man:
    a=int(v['dateRange']['earliest'][:4]); b=int(v['dateRange']['latest'][:4]); yr[v['volumeId']]=(a+b)//2
m=np.fromfile(vec.R+"semantic-map.bin",dtype=np.uint8)
pl=m[64:64+vec.docs*6].reshape(vec.docs,6); cl=pl[:,4:6].copy().view(np.uint16).reshape(-1)
tot=un=0
for v,(r0,n) in vec.vol_rows.items():
    if v in yr and 1945<=yr[v]<=1980:
        tot+=n; un+=int((cl[r0:r0+n]==0xFFFF).sum())
print("era-matched map baseline, volumes dated 1945-1980 by mean year: unclustered",un,"of",tot)
