import sqlite3, re, collections, json, sys
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
EXC = "AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
CUBA = "(cuba OR cuban OR cubans OR havana OR habana)"
tests = {
 "national security": ('"national security"', re.compile(r"national security", re.I), re.compile(r"\bnation(?:al|s)?['’]?s?['’]?[\s\-,().]+secur(?:ity|ities)\b", re.I)),
 "prosperity": ("prosperity", re.compile(r"prosperity", re.I), re.compile(r"\bprosper(?:ity|ous|ed|ing|s)?\b", re.I)),
}
res={}
for name,(fts,strict,tol) in tests.items():
    q=f"""select d.volume_id,d.document_id,dd.date_iso,d.header||' '||coalesce(d.dateline,'')||' '||coalesce(d.source_note,'')||' '||d.body_text
     from frus_documents f join document_cache d on d.rowid=f.rowid join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id
     where frus_documents match ? {EXC} order by d.volume_id,d.document_id"""
    hits=[];n=0
    ds=collections.Counter(); dt=collections.Counter(); dh=collections.Counter()
    for v,d,dt_,txt in db.execute(q,(CUBA+" AND "+fts,)):
        t=re.sub(r"\s+"," ",txt); n+=1
        s=bool(strict.search(t)); o=bool(tol.search(t))
        dec=dt_[:3]+"0s"
        dh[dec]+=1; ds[dec]+=s; dt[dec]+=o
        hits.append((v,d,dt_,s,o))
    res[name]={"hits":n,"strict":sum(h[3] for h in hits),"tolerant":sum(h[4] for h in hits),
      "by_dec":{k:(dh[k],ds[k],dt[k]) for k in sorted(dh)}}
    first=sorted([h for h in hits if h[3]],key=lambda h:h[2])[:5]
    res[name]["first_strict"]=first
    print(name,res[name]["hits"],res[name]["strict"],res[name]["tolerant"])
    for k in sorted(dh): print("  ",k,"fts",dh[k],"strict",ds[k],"tolerant",dt[k])
    print("  earliest strict:",first)
json.dump(res,open("literal.json","w"),indent=1,default=str)
