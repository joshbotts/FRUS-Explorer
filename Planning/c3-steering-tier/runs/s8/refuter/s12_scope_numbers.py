import sqlite3
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB, uri=True)
q=lambda s,*a: con.execute(s,a).fetchall()
pairs=[tuple(l.strip().split("|")) for l in open("/Users/jbotts/frus-analysis/c3s/runs/s8/raw/set.txt") if l.strip()]
print("pairs in raw/set.txt:",len(pairs),"distinct:",len(set(pairs)))
vals=",".join(f"('{v}','{d}')" for v,d in pairs)
print("distinct volumes among the 28:", q(f"WITH s(v,d) AS (VALUES {vals}) SELECT COUNT(DISTINCT v) FROM s"))
print("date span of the 28:", q(f"WITH s(v,d) AS (VALUES {vals}) SELECT MIN(dd.date_iso), MAX(dd.date_iso), COUNT(dd.date_iso) FROM s LEFT JOIN document_dates dd ON dd.volume_id=s.v AND dd.document_id=s.d"))
print("apparatus flags of the 28:", q(f"WITH s(v,d) AS (VALUES {vals}) SELECT COUNT(*), SUM(c.is_front_matter), SUM(c.is_editorial_note) FROM s JOIN document_cache c ON c.volume_id=s.v AND c.document_id=s.d"))
# coverage line
print("coverage:", q("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache"))
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
print("corrupt* set:", q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}"))
print("Ed2 suppressed hits:", q(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN {ED2}"))
print("denominator:", q(f"SELECT COUNT(*) FROM document_cache c WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}"))
# came-from: Central Decimal File 8 of 28
rows=q(f"WITH s(v,d) AS (VALUES {vals}) SELECT s.v, s.d, coalesce(ds.citation_era,'NONE'), coalesce(ds.repository,''), coalesce(ds.record_group,''), coalesce(ds.series_name,''), coalesce(ds.lot_file_norm,''), substr(coalesce(c.source_note,''),1,110) FROM s LEFT JOIN document_cache c ON c.volume_id=s.v AND c.document_id=s.d LEFT JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d ORDER BY s.v, s.d")
for r in rows: print("  CAMEFROM", "|".join(str(x) for x in r))
cdf=[r for r in rows if 'Central Decimal' in (r[5] or '') or 'Decimal' in (r[5] or '')]
print("rows whose series_name holds 'Decimal':",len(cdf),[(r[0],r[1]) for r in cdf])
# other overview figures
for label,sql in [
 ("Lockheed family", f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id), MIN(d.date_iso), MAX(d.date_iso) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH 'Lockheed AND (brib* OR payoff* OR payment*)' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}"),
 ("Church family", f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id), MIN(d.date_iso), MAX(d.date_iso) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH '\"Church Subcommittee\" OR \"Multinational Subcommittee\" OR \"Subcommittee on Multinational Corporations\"' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}"),
 ("FCPA family", f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id), MIN(d.date_iso), MAX(d.date_iso) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH '\"foreign corrupt practic*\"' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}"),
 ("positive control vols", "SELECT COUNT(*) vols, SUM(n=0) zero_vols FROM (SELECT v.volume_id, (SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '\"Department of State\"' AND c.volume_id=v.volume_id) n FROM (SELECT DISTINCT volume_id FROM document_cache) v)"),
 ("Paris v05 United States", "SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '\"United States\"' AND c.volume_id='frus1919Parisv05'"),
 ("negative control", f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ'"),
 ("pointed-at min date", "SELECT MIN(d.date_iso) FROM external_citations e JOIN document_dates d ON d.volume_id=e.volume_id AND d.document_id=e.document_id"),
 ("corrupt docs with sources row", f"WITH hits AS (SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}) SELECT COUNT(*) FROM hits h JOIN document_sources s ON s.volume_id=h.volume_id AND s.document_id=h.document_id"),
 ("pre-1911 corrupt hits (dated)", f"WITH hits AS (SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}) SELECT SUM(d.date_iso < '1910-12-06'), SUM(d.date_iso < '1900-01-01'), SUM(d.date_iso IS NULL) FROM hits h LEFT JOIN document_dates d ON d.volume_id=h.volume_id AND d.document_id=h.document_id"),
]:
    print(label, q(sql))
