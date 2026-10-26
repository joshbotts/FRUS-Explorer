# Scope documents by decade of document_dates.date_iso (from frus:doc-dateTime-min), with per-1,000 of the decade's dated non-apparatus documents
# and the top volume's share of each decade's numerator.
import collections
from db import q
S=[tuple(l.split()) for l in open("scope_final.tsv")]
S=sorted(set(S))
dates=dict(((v,d),di) for v,d,di in q("SELECT volume_id, document_id, date_iso FROM document_dates",tag="decades"))
den=dict(q("SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_dates dd JOIN document_cache c ON c.volume_id=dd.volume_id AND c.document_id=dd.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND dd.date_iso IS NOT NULL AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1",tag="decades"))
num=collections.Counter(); top=collections.defaultdict(collections.Counter); und=0
for v,d in S:
    di=dates.get((v,d))
    if not di: und+=1; continue
    k=di[:3]+"0s"; num[k]+=1; top[k][v]+=1
print("scope docs",len(S),"undated",und)
for k in sorted(num):
    tv,tn=top[k].most_common(1)[0]
    print("%s\t%d\tof %d\t%.2f per 1000\ttop vol %s %d of %d"%(k,num[k],den[k],1000*num[k]/den[k],tv,tn,num[k]))
