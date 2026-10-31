import sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ea=[l.strip() for l in open("work/ea_vols_list.txt")]
pd=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
for lab,L in (("PUBLIC DIPLOMACY (5 vols)",pd),("EAST ASIA (74 vols)",ea)):
    ph=",".join("?"*len(L))
    print("==",lab)
    print(" total citation rows, docs:",db.execute(f"select count(*),count(distinct volume_id||'/'||document_id) from external_citations e where volume_id in ({ph})",L).fetchone())
    print(" earliest document with a pointed-at row in the whole index:", db.execute("select min(substr(dd.date_iso,1,10)) from external_citations e join document_dates dd on dd.volume_id=e.volume_id and dd.document_id=e.document_id").fetchone())
    sql=f"""select repository, coalesce(lot_file_norm,''), substr(coalesce(collection,''),1,60), count(*), count(distinct volume_id||'/'||document_id)
    from external_citations where volume_id in ({ph}) and lot_file_norm is not null and lot_file_norm<>'' group by 1,2,3 order by 4 desc limit 12"""
    for r in db.execute(sql,L): print("  LOT",r)
    sql=f"""select repository, substr(coalesce(collection,''),1,70), count(*), count(distinct volume_id||'/'||document_id)
    from external_citations where volume_id in ({ph}) and (lot_file_norm is null or lot_file_norm='') and repository is not null group by 1,2 order by 3 desc limit 10"""
    for r in db.execute(sql,L): print("  NONLOT",r)
