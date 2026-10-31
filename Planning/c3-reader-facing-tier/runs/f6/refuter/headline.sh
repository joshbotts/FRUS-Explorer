#!/bin/zsh
DB=/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db
IN=$(cat /Users/jbotts/frus-analysis/c3f/runs/f6/eap_in.txt)
INFO=$(cat /Users/jbotts/frus-analysis/c3f/runs/f6/info_in.txt)
QA='(USIA OR USIS OR "Information Agency" OR "Information Service" OR "Voice of America" OR "information program" OR "psychological program" OR "psychological strategy" OR "cultural exchange" OR "educational exchange")'
echo "M2 EAP set: volumes | non-apparatus docs"
sqlite3 -readonly $DB "SELECT COUNT(DISTINCT volume_id), SUM(is_front_matter=0 AND is_editorial_note=0) FROM document_cache WHERE volume_id IN ($IN);"
echo "M3 info set:"
sqlite3 -readonly $DB "SELECT COUNT(DISTINCT volume_id), SUM(is_front_matter=0 AND is_editorial_note=0) FROM document_cache WHERE volume_id IN ($INFO);"
echo "M4 QA family over EAP (docs | volumes):"
sqlite3 -readonly $DB "SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$QA' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN);"
echo "M13 pointed-at over the QA family (anchor|repo|collection|lot|citations|docs), top 12:"
sqlite3 -readonly $DB "WITH hits AS (SELECT d.volume_id v, d.document_id id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$QA' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN)) SELECT e.anchor, ifnull(e.repository,''), ifnull(e.collection,''), ifnull(e.lot_file_norm,''), count(*) c, count(distinct e.volume_id||'/'||e.document_id) docs FROM external_citations e JOIN hits h ON h.v=e.volume_id AND h.id=e.document_id GROUP BY 1,2,3,4 ORDER BY c DESC LIMIT 12;"
echo "M13 total over family (citations | docs):"
sqlite3 -readonly $DB "WITH hits AS (SELECT d.volume_id v, d.document_id id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$QA' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN)) SELECT count(*), count(distinct e.volume_id||'/'||e.document_id) FROM external_citations e JOIN hits h ON h.v=e.volume_id AND h.id=e.document_id;"
echo "M14 absence scans (docs | volumes):"
for q in '(USIA OR USIS) AND (poll OR survey OR "opinion research" OR "research report" OR "audience research")' '(leaflet OR leaflets OR "radio script" OR "film script" OR "VOA script") AND (USIA OR USIS OR "Voice of America")' '"Peace Corps"' '("binational center" OR "bi-national center" OR "Binational Centers")' '"soft power"' '"Department of State"' '"ZZZ_IMPOSSIBLE_ZZZ"'; do
  sqlite3 -readonly $DB "SELECT '$q', COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$q' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN);"
done
echo "M8 soft power whole index:"
sqlite3 -readonly $DB "SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '\"soft power\"';"
echo "external_citations earliest date (house figure 1910-12-06):"
sqlite3 -readonly $DB "SELECT MIN(dd.date_iso), COUNT(*) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id;"
sqlite3 -readonly $DB ".schema external_citations"
echo "M13 per-lot doc counts, re-derived separately (lot_file_norm):"
sqlite3 -readonly $DB "WITH hits AS (SELECT d.volume_id v, d.document_id id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$QA' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN)) SELECT e.lot_file_norm, count(*), count(distinct e.volume_id||'/'||e.document_id) FROM external_citations e JOIN hits h ON h.v=e.volume_id AND h.id=e.document_id WHERE e.lot_file_norm IN ('66D95','62D430','63D351','62D1') GROUP BY 1;"
echo "M13 central file decimal anchors docs:"
sqlite3 -readonly $DB "WITH hits AS (SELECT d.volume_id v, d.document_id id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$QA' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN)) SELECT e.anchor, count(*), count(distinct e.volume_id||'/'||e.document_id) FROM external_citations e JOIN hits h ON h.v=e.volume_id AND h.id=e.document_id WHERE e.anchor='centralFileClass' GROUP BY 1;"
