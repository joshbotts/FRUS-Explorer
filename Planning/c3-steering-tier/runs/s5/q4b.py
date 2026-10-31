import sqlite3, collections
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
EXPRS = {
 "core": 'body_text:(corrupt OR brib* OR graft OR embezzl OR kickback OR "questionable payments" OR "illicit payments")',
 "corrupt_only": 'body_text:corrupt',
}
den = dict(db.execute("""SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
 WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND d.date_iso IS NOT NULL GROUP BY 1""").fetchall())
for name, e in EXPRS.items():
    rows = db.execute("""SELECT c.volume_id, c.document_id, substr(d.date_iso,1,3)||'0s' FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
      LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
      WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')""",(e,)).fetchall()
    print("==",name,"total docs",len(rows),"volumes",len({r[0] for r in rows}), "undated", sum(1 for r in rows if r[2] is None))
    bydec = collections.defaultdict(collections.Counter)
    for v,dd,dec in rows:
        if dec: bydec[dec][v]+=1
    for dec in sorted(bydec):
        n=sum(bydec[dec].values()); tv,tn=bydec[dec].most_common(1)[0]
        if dec>='1840s': print(f"{dec} {n:5d} of {den[dec]:6d} per1000={1000*n/den[dec]:6.2f} topvol={tv} {tn} ({tn/n:.2f})")
    if name=="core":
        import json; json.dump([(v,d) for v,d,_ in rows], open("core_hits_ed2suppressed.json","w"))
