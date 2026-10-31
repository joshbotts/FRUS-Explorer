-- Q2: volumes by number of docs with stem corrupt (body_text), apparatus excluded
SELECT c.volume_id, COUNT(*) n, (SELECT COUNT(*) FROM document_cache x WHERE x.volume_id=c.volume_id AND x.is_front_matter=0 AND x.is_editorial_note=0) denom
FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
WHERE frus_documents MATCH 'body_text:corrupt' AND c.is_front_matter=0 AND c.is_editorial_note=0
GROUP BY c.volume_id ORDER BY n DESC LIMIT 45;
SELECT 'total', COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
WHERE frus_documents MATCH 'body_text:corrupt' AND c.is_front_matter=0 AND c.is_editorial_note=0;
