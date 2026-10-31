.mode list
SELECT volume_id||'/'||document_id, substr(replace(header,char(10),' '),1,170), length(body_text) FROM document_cache
WHERE volume_id IN ('frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08') AND is_front_matter=0 AND is_editorial_note=0
AND (header LIKE '%Asia%' OR header LIKE '%Vietnam%' OR header LIKE '%Japan%' OR header LIKE '%Korea%' OR header LIKE '%Indonesia%' OR header LIKE '%Philippin%' OR header LIKE '%Thailand%' OR header LIKE '%China%' OR header LIKE '%Laos%' OR header LIKE '%Pacific%' OR header LIKE '%Taiwan%' OR header LIKE '%Australia%' OR header LIKE '%Cambodia%' OR header LIKE '%Malaysia%' OR header LIKE '%Singapore%' OR header LIKE '%Burma%')
ORDER BY volume_id, rowid;
