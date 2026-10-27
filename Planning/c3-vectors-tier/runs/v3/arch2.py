import sqlite3, collections, json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
db.execute("create temp table setA(volume_id text, document_id text)")
db.executemany("insert into setA values(?,?)",[tuple(l.rstrip("\n").split("\t")[:2]) for l in open("setA.tsv")])
q="""select substr(dd.date_iso,1,3)||'0s' dec, s.decimal_class, count(*) from document_sources s join setA a on a.volume_id=s.volume_id and a.document_id=s.document_id
 join document_dates dd on dd.volume_id=s.volume_id and dd.document_id=s.document_id where s.citation_era='decimal' group by 1,2 order by 1,3 desc"""
by=collections.defaultdict(list)
for dec,c,n in db.execute(q): by[dec].append((c,n))
for dec in sorted(by): print(dec,sum(n for c,n in by[dec]),by[dec][:6])
lab=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json"))
print(list(lab.keys())); print(json.dumps(lab.get("coverage"))[:1500])
