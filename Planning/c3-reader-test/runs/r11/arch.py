# Archival channels over the 938-document scope. came-from: document_sources (one row per doc). pointed-at: external_citations (many rows per doc). Never summed.
import collections,json
from db import q
S=sorted(set(tuple(l.split()) for l in open("scope_final.tsv")))
Sset=set(S)
ds=q("SELECT volume_id, document_id, repository, record_group, lot_file_norm, series_name, citation_era, decimal_class FROM document_sources",tag="arch-camefrom")
cf=[r for r in ds if (r[0],r[1]) in Sset]
print("CAME-FROM: scope docs with a document_sources row:",len(cf),"of",len(S))
for k,i in (("citation_era",6),("repository",2),("record_group",3),("lot",4),("series",5)):
    c=collections.Counter(r[i] for r in cf); print(k,c.most_common(12))
dc=collections.Counter((r[7] or "")[:3] for r in cf if r[6]=="decimal"); print("decimal class first3",dc.most_common(10))
ec=q("SELECT volume_id, document_id, anchor, repository, collection, lot_file_norm, decimal_class, raw_text FROM external_citations WHERE inherited=0",tag="arch-pointedat")
pa=[r for r in ec if (r[0],r[1]) in Sset]
print("POINTED-AT: rows",len(pa),"in docs",len({(r[0],r[1]) for r in pa}),"of",len(S))
print("anchor",collections.Counter(r[2] for r in pa).most_common())
print("repo/collection",collections.Counter((r[3],r[4]) for r in pa).most_common(15))
print("lots",collections.Counter(r[5] for r in pa if r[5]).most_common(15))
json.dump({"camefrom":cf,"pointedat":pa},open("arch_rows.json","w"))
