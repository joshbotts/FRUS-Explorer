import csv, sqlite3, collections
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
rows=list(csv.DictReader(open("scan2.csv")))
core=collections.Counter(r["volume_id"] for r in rows if int(r["nfam"])>=3)
top=[v for v,_ in core.most_common(10)]
print("top10 core volumes",[(v,core[v]) for v in top])
ex="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
def counts(match):
    # docs per volume matching
    d=collections.Counter()
    for v,n in con.execute("SELECT d.volume_id,COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN %s GROUP BY d.volume_id"%ex,(match,)): d[v]=n
    return d
tot=collections.Counter()
for v,n in con.execute("SELECT volume_id,COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN %s GROUP BY volume_id"%ex): tot[v]=n
fam=collections.Counter(r["volume_id"] for r in rows if int(r["nfam"])>=1)
ctl=counts('"Department of State"'); neg=counts('ZZZ_IMPOSSIBLE_ZZZ')
for name,c in (("corruption family (>=1, regex)",fam),("control phrase 'Department of State' (FTS)",ctl),("negative ZZZ_IMPOSSIBLE_ZZZ",neg)):
    a=sum(c[v] for v in top); A=sum(tot[v] for v in top)
    b=sum(c[v] for v in tot if v not in top); B=sum(tot[v] for v in tot if v not in top)
    print(name,"| top10:",a,"of",A,round(a/A,3),"| other volumes:",b,"of",B,round(b/B,3))
print("volumes with zero Department of State:",sum(1 for v in tot if ctl[v]==0),"of",len(tot))
