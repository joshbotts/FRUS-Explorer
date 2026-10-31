import sqlite3, csv, json, collections
from final_set import FINAL
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols={v for v,d in FINAL}
hits=[(r["volume_id"],r["document_id"]) for r in csv.DictReader(open("scan1.csv")) if r["volume_id"] in vols]
print("corruption-family hit documents in the",len(vols),"finding volumes:",len(hits))
cnt=collections.Counter(); docs=collections.defaultdict(set)
SQL="SELECT anchor,repository,collection,lot_file_norm,decimal_class FROM external_citations WHERE volume_id=? AND document_id=?"
tot=0
for k in hits:
    for a,rep,col,lot,dc in con.execute(SQL,k):
        tot+=1
        key=(a,rep,lot if a=="lotFile" else (col or dc))
        cnt[key]+=1; docs[key].add(k)
print("external_citations rows on those documents:",tot)
for key,n in cnt.most_common(25): print(n,len(docs[key]),key)
