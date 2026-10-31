# Census of the corrupt* / brib* hit sets: literal shares (strict/tolerant), garble-sense vs venality-sense
import sqlite3, re, json, sys
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB, uri=True)
fam=sys.argv[1]; match=sys.argv[2]
SQL=("SELECT c.volume_id, c.document_id, c.header||' '||coalesce(c.dateline,'')||' '||coalesce(c.source_note,'')||' '||c.body_text "
     "FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? "
     "AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') "
     "ORDER BY c.volume_id, c.document_id")
print("SQL:",SQL,"param:",match)
rows=con.execute(SQL,(match,)).fetchall()
strict={"corrupt":re.compile(r"\bcorrupt"),"brib":re.compile(r"\bbrib")}[fam]   # case-sensitive lowercase stem as printed
tol={"corrupt":re.compile(r"\bcorrupt\w*",re.I),"brib":re.compile(r"\bbrib\w*",re.I)}[fam]
garble=re.compile(r"corrupt(?:ed)?[\s,.\-()]+(?:group|groups|text|word|words|passage|in transmission|telegram|portion|figures?)|(?:group|groups|text|passage|word|words|figures?|garbled)[\s,.\-()]+(?:\w+[\s,.\-()]+)?corrupt",re.I)
out=[]; ns=nt=ng=nv=0
for v,d,t in rows:
    t=" ".join(t.split())
    s=bool(strict.search(t)); m=list(tol.finditer(t)); g=bool(garble.search(t))
    allg = g and all(garble.search(t[max(0,x.start()-60):x.end()+60]) for x in m)
    ns+=s; nt+=bool(m); ng+=allg; nv+= bool(m) and not allg
    ctx=[t[max(0,x.start()-90):x.end()+90] for x in m[:3]]
    out.append({"v":v,"d":d,"strict":s,"tol":bool(m),"n":len(m),"garble_only":allg,"ctx":ctx})
json.dump(out,open(f"/Users/jbotts/frus-analysis/c3s/runs/s8/raw/census_{fam}.json","w"))
N=len(rows); print(f"{fam}: N={N} strict={ns} of {N} tolerant={nt} of {N} garble_only={ng} of {N} venality_or_other={nv} of {N}")
# evenly spaced sample of 40
idx=[round(i*(N-1)/39) for i in range(40)]
sam=[out[i] for i in idx]
print("SAMPLE40 strict",sum(x["strict"] for x in sam),"of 40; tolerant",sum(x["tol"] for x in sam),"of 40; garble_only",sum(x["garble_only"] for x in sam),"of 40")
json.dump(sam,open(f"/Users/jbotts/frus-analysis/c3s/runs/s8/raw/sample40_{fam}.json","w"),indent=1)
