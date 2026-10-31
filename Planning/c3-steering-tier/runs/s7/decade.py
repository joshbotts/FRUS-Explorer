import sys,collections
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3s/runs/s7")
from db import *
match=sys.argv[1]
den=dict(q("SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM document_dates d JOIN document_cache c ON c.volume_id=d.volume_id AND c.document_id=d.document_id WHERE d.date_iso IS NOT NULL AND "+NONAPP+" AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1",(),"decade-den"))
rows=q("SELECT substr(d.date_iso,1,3)||'0s', c.volume_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH ? AND d.date_iso IS NOT NULL AND "+NONAPP+" AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')",(match,),"decade-num")
by=collections.defaultdict(collections.Counter)
for dec,v in rows: by[dec][v]+=1
print("match",match,"total",len(rows))
for dec in sorted(den):
    c=by.get(dec,collections.Counter()); n=sum(c.values())
    top=c.most_common(1)
    print(dec,n,den[dec],"%.2f"%(1000*n/den[dec]), (top[0][0]+" %d of %d"%(top[0][1],n)) if top else "-")
