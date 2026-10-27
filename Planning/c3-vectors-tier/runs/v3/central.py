import sqlite3, re, collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
EXC="AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
pat=re.compile(r"\bCub(?:a|an|ans)\b|\bHa[bv]ana\b",re.I)
tot=collections.Counter(); c5=collections.Counter(); c1=collections.Counter()
q=f"""select dd.date_iso, d.header||' '||coalesce(d.dateline,'')||' '||coalesce(d.source_note,'')||' '||d.body_text from frus_documents f join document_cache d on d.rowid=f.rowid
 join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id and dd.date_iso is not null where frus_documents match '(cuba OR cuban OR cubans OR havana OR habana)' {EXC}"""
for dt,t in db.execute(q):
    n=len(pat.findall(t)); dec=dt[:3]+"0s"; tot[dec]+=1; c1[dec]+= n>=1; c5[dec]+= n>=5
for d in sorted(tot):
    if "1860s"<=d<="1980s": print(d,"fts hits",tot[d],"literal>=1:",c1[d],"literal>=5:",c5[d],f"{c5[d]}/{tot[d]}={c5[d]/tot[d]:.2f}")
