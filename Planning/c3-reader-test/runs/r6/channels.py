# Archival channels over the scope (raw/scope_all.tsv loaded into TEMP table s(volume_id, document_id, rule)).
import sqlite3, sys
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
con.execute("CREATE TEMP TABLE s(volume_id TEXT, document_id TEXT, rule TEXT, PRIMARY KEY(volume_id,document_id))")
for l in open("raw/scope_all.tsv"):
    v,d,r,_=l.rstrip("\n").split("\t"); con.execute("INSERT INTO s VALUES(?,?,?)",(v,d,r))
Q={
"came_from_by_era":"SELECT ds.citation_era, COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id GROUP BY 1 ORDER BY 2 DESC",
"came_from_rows":"SELECT COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id",
"scope_n":"SELECT rule, COUNT(*) FROM s GROUP BY rule",
"came_from_decimal_class_top":"SELECT substr(ds.decimal_class,1,3) AS cls, COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id WHERE ds.decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 25",
"came_from_decimal_full_top":"SELECT ds.decimal_class, COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id WHERE ds.decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 30",
"came_from_repo_series_R3":"SELECT ds.citation_era, coalesce(ds.repository,''), coalesce(ds.record_group,''), coalesce(ds.lot_file_norm,''), coalesce(ds.series_name,''), COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id WHERE s.rule='R3' GROUP BY 1,2,3,4,5 ORDER BY 6 DESC LIMIT 30",
"came_from_lots_all":"SELECT ds.lot_file_norm, coalesce(ds.repository,''), COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id WHERE ds.lot_file_norm IS NOT NULL GROUP BY 1,2 ORDER BY 3 DESC LIMIT 30",
"pointed_at_rows":"SELECT COUNT(*), COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id",
"pointed_at_by_anchor":"SELECT ec.anchor, COUNT(*) FROM s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id GROUP BY 1 ORDER BY 2 DESC",
"pointed_at_decimal_top":"SELECT ec.decimal_class, COUNT(*), COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id WHERE ec.decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 25",
"pointed_at_lots":"SELECT ec.lot_file_norm, coalesce(ec.repository,''), coalesce(ec.collection,''), COUNT(*) FROM s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id WHERE ec.lot_file_norm IS NOT NULL GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 25",
"pointed_at_collections":"SELECT coalesce(ec.repository,''), coalesce(ec.collection,''), COUNT(*) FROM s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id WHERE ec.anchor<>'decimal' GROUP BY 1,2 ORDER BY 3 DESC LIMIT 25",
}
for k in sys.argv[1:] or Q:
    print("##",k,"::",Q[k])
    for r in con.execute(Q[k]): print("|".join(str(x) for x in r))
