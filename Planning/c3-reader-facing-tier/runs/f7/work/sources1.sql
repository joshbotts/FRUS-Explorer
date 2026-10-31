.mode list
.print === document_sources for PubDip v06-08, 38p2, 77-80v30 documents with EAP/Asia in header (came-from channel)
SELECT s.record_group, s.repository, s.citation_era, substr(s.series_name,1,70), COUNT(*)
FROM document_sources s JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id
WHERE s.volume_id IN ('frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30')
AND d.is_front_matter=0 AND d.is_editorial_note=0
AND (d.header LIKE '%East Asia%' OR d.header LIKE '%Far East%' OR d.header LIKE '%Vietnam%' OR d.header LIKE '%Viet-Nam%' OR d.header LIKE '%Japan%' OR d.header LIKE '%Indonesia%' OR d.header LIKE '%Thailand%' OR d.header LIKE '%Laos%' OR d.header LIKE '%China%' OR d.header LIKE '%Korea%' OR d.header LIKE '%Pacific%')
GROUP BY 1,2,3,4 ORDER BY 5 DESC LIMIT 25;
.print === count of such documents
SELECT COUNT(*) FROM document_cache d WHERE d.volume_id IN ('frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30') AND d.is_front_matter=0 AND d.is_editorial_note=0
AND (d.header LIKE '%East Asia%' OR d.header LIKE '%Far East%' OR d.header LIKE '%Vietnam%' OR d.header LIKE '%Viet-Nam%' OR d.header LIKE '%Japan%' OR d.header LIKE '%Indonesia%' OR d.header LIKE '%Thailand%' OR d.header LIKE '%Laos%' OR d.header LIKE '%China%' OR d.header LIKE '%Korea%' OR d.header LIKE '%Pacific%');
