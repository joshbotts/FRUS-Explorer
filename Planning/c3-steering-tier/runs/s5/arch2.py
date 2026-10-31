import sqlite3, json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
EXC={"frus1951-54IranEd2","frus1969-76ve15p2Ed2"}
hits=[tuple(x) for x in json.load(open("core_hits.json")) if x[0] not in EXC]
db.execute("CREATE TEMP TABLE hit(volume_id TEXT, document_id TEXT)"); db.executemany("INSERT INTO hit VALUES(?,?)",hits)
print("core-vocabulary hit documents (apparatus excluded, Ed2 suppressed):",len(hits))
print("\n-- CAME-FROM (document_sources, one row per document) over the hit documents")
q="""SELECT COALESCE(s.repository,'(none)') repo, COALESCE(s.record_group,'-') rg, s.citation_era, COUNT(*) FROM hit h LEFT JOIN document_sources s ON s.volume_id=h.volume_id AND s.document_id=h.document_id GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 14"""
print("SQL:",q)
for r in db.execute(q): print(r)
print("hit docs with no document_sources row:",db.execute("SELECT COUNT(*) FROM hit h LEFT JOIN document_sources s ON s.volume_id=h.volume_id AND s.document_id=h.document_id WHERE s.volume_id IS NULL").fetchone()[0])
print("\n-- POINTED-AT (external_citations, many rows per document) over the hit documents, by anchor type")
q2="""SELECT e.anchor, COUNT(*) citations, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs FROM hit h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id GROUP BY 1 ORDER BY 2 DESC"""
print("SQL:",q2)
for r in db.execute(q2): print(r)
q3="""SELECT e.repository, COALESCE(NULLIF(e.collection,''),NULLIF(e.lot_file_norm,''),'(decimal/class)') tgt, COUNT(*) FROM hit h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id WHERE e.anchor IN ('lotFile','presidentialLibrary') GROUP BY 1,2 ORDER BY 3 DESC LIMIT 14"""
print("SQL:",q3)
for r in db.execute(q3): print(r)
print("earliest external_citations document date among all rows:",db.execute("SELECT MIN(d.date_iso) FROM external_citations e JOIN document_dates d ON d.volume_id=e.volume_id AND d.document_id=e.document_id").fetchone())
