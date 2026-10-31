import sqlite3, json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
d=json.load(open("collection.fruscollection"))
pairs=[(e["volumeId"],e["documentId"]) for e in d["entries"] if e["kind"]=="document"]
db.execute("CREATE TEMP TABLE coll(volume_id TEXT, document_id TEXT)"); db.executemany("INSERT INTO coll VALUES(?,?)",pairs)
q="""SELECT COALESCE(s.repository,'(no source row)') repo, COALESCE(s.record_group,'-') rg, COALESCE(s.citation_era,'-') era, COUNT(*) n, group_concat(c.volume_id||'/'||c.document_id,' ') docs
FROM coll c LEFT JOIN document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id GROUP BY 1,2,3 ORDER BY n DESC"""
print("SQL:",q.replace("\n"," "))
for r in db.execute(q): print(r)
q2="""SELECT s.repository, s.record_group, COUNT(*) FROM coll c JOIN document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.repository IN ('Department of State','National Archives') AND s.record_group='59' AND s.citation_era IN ('decimal','subject_numeric') GROUP BY 1,2"""
print("SQL:",q2.replace("\n"," "))
for r in db.execute(q2): print(r)
