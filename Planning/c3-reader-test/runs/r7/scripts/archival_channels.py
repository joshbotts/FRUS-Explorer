# Archival channels for the core set (A|B): came-from = document_sources (one row per document), pointed-at = external_citations
# (many rows per document). Never summed. Writes out/archival_came_from.tsv and out/archival_pointed_at.tsv.
import sqlite3, collections
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows=[l.rstrip("\n").split("\t") for l in open(R+"core_set.tsv")][1:]
core=[(v,d) for v,d,iso,a,b,p in rows]
con.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT, PRIMARY KEY(volume_id, document_id))")
con.executemany("INSERT INTO core VALUES (?,?)", core)
def dump(title, sql, fn, limit=60):
    cur=con.execute(sql); cols=[c[0] for c in cur.description]; data=cur.fetchall()
    with open(R+fn,"w") as f:
        f.write("\t".join(cols)+"\n")
        for r in data: f.write("\t".join("" if x is None else str(x) for x in r)+"\n")
    print("##",title, f"({len(data)} rows; {fn})"); print("\t".join(cols))
    for r in data[:limit]: print("\t".join("" if x is None else str(x) for x in r))
print("core rows:", len(core))
dump("CAME-FROM: documents in core with a document_sources row, by citation_era",
 "SELECT citation_era, COUNT(*) n FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id GROUP BY 1 ORDER BY 2 DESC", "archival_came_from_era.tsv")
dump("CAME-FROM: by repository, record_group, series_name (top)",
 "SELECT repository, record_group, series_name, COUNT(*) n FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 60", "archival_came_from.tsv")
dump("CAME-FROM: decimal classes (top 30)",
 "SELECT decimal_class, COUNT(*) n FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id WHERE decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 30", "archival_came_from_decimal.tsv", 30)
dump("CAME-FROM: lot files (top 30)",
 "SELECT lot_file_norm, series_name, COUNT(*) n FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id WHERE lot_file_norm IS NOT NULL GROUP BY 1,2 ORDER BY 3 DESC LIMIT 30", "archival_came_from_lots.tsv", 30)
dump("POINTED-AT: external_citations rows for core documents, by repository, collection (top 40)",
 "SELECT repository, collection, COUNT(*) n, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id GROUP BY 1,2 ORDER BY 3 DESC LIMIT 40", "archival_pointed_at.tsv", 40)
dump("POINTED-AT: lot files cited (top 30)",
 "SELECT lot_file_norm, collection, COUNT(*) n, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id WHERE lot_file_norm IS NOT NULL GROUP BY 1,2 ORDER BY 3 DESC LIMIT 30", "archival_pointed_at_lots.tsv", 30)
dump("POINTED-AT: decimal classes cited (top 30)",
 "SELECT decimal_class, COUNT(*) n, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id WHERE decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 30", "archival_pointed_at_decimal.tsv", 30)
print("## core docs with any external_citations row:", con.execute("SELECT COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id").fetchone()[0])
print("## earliest external_citations row date in core:", con.execute("SELECT MIN(d.date_iso) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id JOIN document_dates d ON d.volume_id=e.volume_id AND d.document_id=e.document_id").fetchone()[0])
