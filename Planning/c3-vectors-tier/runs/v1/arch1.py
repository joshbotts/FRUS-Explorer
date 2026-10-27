import csv,sqlite3,collections
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
c.execute("CREATE TEMP TABLE sc(volume_id TEXT, document_id TEXT, date TEXT)")
rows=[(r["volume_id"],r["document_id"],r["date"]) for r in csv.DictReader(open("scope.csv"))]
c.executemany("INSERT INTO sc VALUES(?,?,?)",rows)
print("scope docs",len(rows))
def band(d):
    y=int(d[:4]); 
    return "1870-1899" if y<1900 else "1900-1939" if y<1940 else "1940-1957" if y<1958 else "1958-1989"
SQL1="SELECT s.date,ds.citation_era,ds.repository,ds.record_group,ds.lot_file_norm,ds.series_name FROM sc s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id"
SQL2="SELECT s.date,ec.anchor,ec.repository,ec.collection,ec.lot_file_norm FROM sc s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id"
tot=collections.Counter(band(d) for _,_,d in rows)
a=collections.Counter(); 
src=collections.defaultdict(collections.Counter)
for d,era,repo,rg,lot,ser in c.execute(SQL1):
    b=band(d); a[b]+=1; src[b][(era,repo,rg)]+=1
print("CAME-FROM channel (document_sources) joined to scope: band: docs in scope, docs with a source row")
for b in tot: print(b,tot[b],a[b])
for b in tot:
    print("--",b); 
    for k,v in src[b].most_common(8): print("   ",v,k)
e=collections.defaultdict(collections.Counter); n=collections.Counter(); docs=collections.defaultdict(set)
for d,anchor,repo,coll,lot in c.execute(SQL2):
    b=band(d); n[b]+=1; e[b][(anchor,repo,coll,lot)]+=1
print("POINTED-AT channel (external_citations) rows joined to scope")
for b in tot:
    print("--",b,"citation rows",n[b])
    for k,v in e[b].most_common(10): print("   ",v,k)
