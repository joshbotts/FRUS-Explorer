.mode list
.print === USIA phrase, volumes top
SELECT d.volume_id, COUNT(*) n FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH '"information agency" OR "information service" OR "information program" OR "psychological strategy" OR "psychological warfare" OR "voice of america" OR propaganda'
AND d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY d.volume_id ORDER BY n DESC LIMIT 60;
