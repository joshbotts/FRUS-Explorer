import sqlite3,csv,collections,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
c.execute("CREATE TEMP TABLE s(v TEXT,d TEXT)")
c.executemany("INSERT INTO s VALUES(?,?)",[tuple(r) for r in csv.reader(open(sys.argv[1]))])
print("set size", c.execute("SELECT COUNT(*) FROM s").fetchone())
print("== CAME-FROM (document_sources), top 25 by repository|record_group|lot_file_norm|series_name")
Q1="SELECT coalesce(ds.repository,'?'),coalesce(ds.record_group,'-'),coalesce(ds.lot_file_norm,'-'),coalesce(substr(ds.series_name,1,60),'-'),ds.citation_era,COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d GROUP BY 1,2,3,4,5 ORDER BY 6 DESC LIMIT 25"
print(Q1)
for r in c.execute(Q1): print(' ',r)
print("rows with a document_sources row:", c.execute("SELECT COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d").fetchone())
print("== POINTED-AT (external_citations), top 20 by repository|collection|lot_file_norm, counted as distinct documents")
Q2="SELECT coalesce(ec.repository,'?'),coalesce(substr(ec.collection,1,60),'-'),coalesce(ec.lot_file_norm,'-'),ec.anchor,COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN external_citations ec ON ec.volume_id=s.v AND ec.document_id=s.d GROUP BY 1,2,3,4 ORDER BY 5 DESC LIMIT 20"
print(Q2)
for r in c.execute(Q2): print(' ',r)
