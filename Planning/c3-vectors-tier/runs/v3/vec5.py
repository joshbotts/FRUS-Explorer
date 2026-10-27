from vec import *
import collections, sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
m=json.load(open(R+"semantic-map-index.json")); cl={c["id"]:c for c in m["clusters"]}
tot=collections.Counter(); unc=collections.Counter()
for v,d,dt in db.execute("select c.volume_id,c.document_id,dd.date_iso from document_cache c join document_dates dd on dd.volume_id=c.volume_id and dd.document_id=c.document_id where c.is_front_matter=0 and c.is_editorial_note=0 and c.volume_id not in ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"):
    r=row_of.get((v,d))
    if r is None: continue
    dec=dt[:3]+"0s"; tot[dec]+=1; unc[dec]+=(map_place(r)[2]==0xFFFF)
print("ALL docs unclustered by decade:",{k:f"{unc[k]}/{tot[k]}={unc[k]/tot[k]:.2f}" for k in sorted(tot) if k>="1860s" and k<="1980s"})
setA=[l.rstrip("\n").split("\t") for l in open("setA.tsv")]
by=collections.defaultdict(collections.Counter)
for v,d,dt,t in setA:
    c=map_place(row_of[(v,d)])[2]; by[dt[:3]+"0s"][c]+=1
for dec in sorted(by):
    n=sum(by[dec].values()); top=by[dec].most_common(4)
    print(dec,n,[(("unclustered" if c==0xFFFF else f"c{c}:"+",".join(cl[c]["terms"])),k) for c,k in top])
