.timeout 100000
CREATE TEMP TABLE nx AS SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'NEAR(corrupt aid, 25) OR NEAR(corrupt assistance, 25) OR NEAR(corrupt support, 25) OR NEAR(corrupt withhold, 25) OR NEAR(corrupt condition, 25) OR NEAR(corrupt suspend, 25) OR NEAR(corrupt confidence, 25) OR NEAR(corrupt congress, 25) OR NEAR(corrupt reform, 25)' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
SELECT 'nexus docs', COUNT(*) FROM nx;
SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM nx JOIN document_dates d ON d.volume_id=nx.volume_id AND d.document_id=nx.document_id GROUP BY 1 ORDER BY 1;
