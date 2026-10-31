import sqlite3, csv, collections
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
rows=list(csv.DictReader(open("scan1.csv")))
nf={(r["volume_id"],r["document_id"]):int(r["nfam"]) for r in rows}
den=collections.Counter()
dec_of={}
for v,d,di in con.execute("SELECT d.volume_id,d.document_id,dd.date_iso FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso IS NOT NULL AND dd.date_iso<>''"):
    dec=di[:3]+"0s"; den[dec]+=1; dec_of[(v,d)]=dec
for label,thr in (("any>=1",1),("core>=3",3)):
    print("##",label)
    num=collections.Counter(); byv=collections.defaultdict(collections.Counter)
    for k,c in nf.items():
        if c>=thr and k in dec_of:
            num[dec_of[k]]+=1; byv[dec_of[k]][k[0]]+=1
    tot=0
    for dec in sorted(den):
        if dec<"1840s": continue
        n=num[dec]; tv=byv[dec].most_common(1)
        print(dec,n,"of",den[dec],round(1000*n/den[dec],1),"per1000", ("top vol "+tv[0][0]+" %d of %d"%(tv[0][1],n)) if tv else "")
        tot+=n
    print("total dated",tot)
core=[k for k,c in nf.items() if c>=3]
print("core docs",len(core),"volumes",len({k[0] for k in core}))
core5=[k for k,c in nf.items() if c>=5]
print(">=5 docs",len(core5),"volumes",len({k[0] for k in core5}))
