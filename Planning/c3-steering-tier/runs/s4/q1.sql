.timeout 100000
SELECT 'corrupt', COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt' AND c.is_front_matter=0 AND c.is_editorial_note=0;
SELECT 'positive: Department of State', COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '"department of state"' AND c.is_front_matter=0 AND c.is_editorial_note=0;
SELECT 'negative: ZZZ_IMPOSSIBLE_ZZZ', COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'zzz_impossible_zzz' AND c.is_front_matter=0 AND c.is_editorial_note=0;
SELECT 'header corrupt', COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'header:corrupt';
