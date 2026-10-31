import sqlite3, re
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB, uri=True); q=lambda s: con.execute(s).fetchall()
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
HITS=f"SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}"
print("== per-volume ranking (top 8) ==")
for r in q(f"SELECT c.volume_id, COUNT(*) n FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2} GROUP BY 1 ORDER BY 2 DESC, 1 LIMIT 8"): print("  ",r)
print("rank of frus1948v07:", q(f"WITH pv AS (SELECT c.volume_id v, COUNT(*) n FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2} GROUP BY 1) SELECT (SELECT COUNT(*) FROM pv p2 WHERE p2.n > p1.n)+1, p1.n FROM pv p1 WHERE v='frus1948v07'"))
print("== decade table ==")
for r in q(f"WITH hits AS ({HITS}), base AS (SELECT c.volume_id, c.document_id, substr(d.date_iso,1,3)||'0s' dec FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso IS NOT NULL AND c.volume_id NOT IN {ED2}) SELECT b.dec, COUNT(*), SUM(h.document_id IS NOT NULL), ROUND(1000.0*SUM(h.document_id IS NOT NULL)/COUNT(*),1) FROM base b LEFT JOIN hits h ON h.volume_id=b.volume_id AND h.document_id=b.document_id WHERE b.dec BETWEEN '1860s' AND '1980s' GROUP BY b.dec"): print("  ",r)
print("== 1890s top volume ==", q(f"WITH hits AS ({HITS}) SELECT h.volume_id, COUNT(*) FROM hits h JOIN document_dates d ON d.volume_id=h.volume_id AND d.document_id=h.document_id WHERE d.date_iso LIKE '189%' GROUP BY 1 ORDER BY 2 DESC LIMIT 2"))
print("== false-friend / density table ==")
for r in q(f"WITH base AS (SELECT c.rowid rid, CASE WHEN c.volume_id IN ('frus1947v07','frus1948v07','frus1958-60v01','frus1964-68v04','frus1964-68v05','frus1964-68v06','frus1961-63v22','frus1969-76ve09p2','frus1969-76ve12','frus1969-76ve15p2','frus1969-76ve09p1','frus1977-80v15') THEN 'on_topic_12' ELSE 'rest' END grp FROM document_cache c WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}), cor AS (SELECT rowid rid FROM frus_documents WHERE frus_documents MATCH 'corrupt*'), ctl AS (SELECT rowid rid FROM frus_documents WHERE frus_documents MATCH '\"Department of State\"') SELECT grp, COUNT(*), SUM(rid IN (SELECT rid FROM cor)), SUM(rid IN (SELECT rid FROM ctl)) FROM base GROUP BY grp"): print("  ",r)
print("== census replication (same regexes as raw/census.py, no files written) ==")
rows=con.execute(f"SELECT c.volume_id, c.document_id, c.header||' '||coalesce(c.dateline,'')||' '||coalesce(c.source_note,'')||' '||c.body_text FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2} ORDER BY c.volume_id, c.document_id").fetchall()
strict=re.compile(r"\bcorrupt"); tol=re.compile(r"\bcorrupt\w*",re.I)
garble=re.compile(r"corrupt(?:ed)?[\s,.\-()]+(?:group|groups|text|word|words|passage|in transmission|telegram|portion|figures?)|(?:group|groups|text|passage|word|words|figures?|garbled)[\s,.\-()]+(?:\w+[\s,.\-()]+)?corrupt",re.I)
ns=nt=ng=0; garbled=[]
for v,d,t in rows:
    t=" ".join(t.split()); m=list(tol.finditer(t)); g=bool(garble.search(t))
    allg = g and all(garble.search(t[max(0,x.start()-60):x.end()+60]) for x in m)
    ns+=bool(strict.search(t)); nt+=bool(m); ng+=allg
    if allg: garbled.append(f"{v}/{d}")
print(f"  N={len(rows)} strict={ns} tolerant={nt} garble_only={ng} -> {garbled}")
N=len(rows); idx=[round(i*(N-1)/39) for i in range(40)]; print("  sample40 ids (first 5):",[f"{rows[i][0]}/{rows[i][1]}" for i in idx[:5]],"... matches session sample40_corrupt.json first id frus1862/d406:", rows[idx[0]][:2]==("frus1862","d406"))
