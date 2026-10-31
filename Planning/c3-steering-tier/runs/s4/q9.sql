.timeout 100000
SELECT 'FCPA phrase', COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '"foreign corrupt practices"' AND c.is_front_matter=0 AND c.is_editorial_note=0;
SELECT 'questionable payments', COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '"questionable payments"' AND c.is_front_matter=0 AND c.is_editorial_note=0;
SELECT 'lockheed', COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'lockheed' AND c.is_front_matter=0 AND c.is_editorial_note=0;
SELECT 'lockheed AND bribe*', COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'lockheed AND (bribe OR briberi OR corrupt OR payment)' AND c.is_front_matter=0 AND c.is_editorial_note=0;
