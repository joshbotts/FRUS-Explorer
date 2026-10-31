.timeout 100000
CREATE TEMP TABLE hits AS SELECT c.volume_id, c.document_id, c.rowid AS rid FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt OR bribe OR briberi OR kickback OR payoff OR venal OR embezzl OR malfeas OR misappropri OR nepot OR payola' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
SELECT 'broad family docs', COUNT(*) FROM hits;
SELECT substr(d.date_iso,1,3)||'0s' AS decade, COUNT(*) AS n, (SELECT COUNT(*) FROM document_cache c2 JOIN document_dates d2 ON d2.volume_id=c2.volume_id AND d2.document_id=c2.document_id WHERE c2.is_front_matter=0 AND c2.is_editorial_note=0 AND substr(d2.date_iso,1,3)=substr(d.date_iso,1,3) AND c2.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')) AS denom
FROM hits h JOIN document_dates d ON d.volume_id=h.volume_id AND d.document_id=h.document_id GROUP BY 1 ORDER BY 1;
SELECT 'undated', COUNT(*) FROM hits h LEFT JOIN document_dates d ON d.volume_id=h.volume_id AND d.document_id=h.document_id WHERE d.date_iso IS NULL;
