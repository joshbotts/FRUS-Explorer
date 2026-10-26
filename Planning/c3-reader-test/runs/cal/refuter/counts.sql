.mode column
.headers on
-- distinct volumes in the index
SELECT COUNT(DISTINCT volume_id) AS volumes_in_document_cache FROM document_cache;
SELECT COUNT(*) AS volume_structures_rows FROM volume_structures;
-- per-volume document counts for the nine
SELECT volume_id, COUNT(*) AS all_rows,
       SUM(CASE WHEN is_front_matter=0 THEN 1 ELSE 0 END) AS non_front,
       SUM(CASE WHEN is_front_matter=0 AND is_editorial_note=0 THEN 1 ELSE 0 END) AS non_front_non_ednote,
       SUM(CASE WHEN is_front_matter=1 THEN 1 ELSE 0 END) AS front_matter,
       SUM(CASE WHEN is_editorial_note=1 THEN 1 ELSE 0 END) AS ed_notes
FROM document_cache
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24')
GROUP BY volume_id ORDER BY volume_id;
SELECT 'TOTAL' AS volume_id, COUNT(*) AS all_rows,
       SUM(CASE WHEN is_front_matter=0 THEN 1 ELSE 0 END) AS non_front,
       SUM(CASE WHEN is_front_matter=0 AND is_editorial_note=0 THEN 1 ELSE 0 END) AS non_front_non_ednote
FROM document_cache
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24');
-- source-note coverage (non-front-matter documents)
SELECT COUNT(*) AS docs, SUM(CASE WHEN source_note IS NOT NULL AND TRIM(source_note)<>'' THEN 1 ELSE 0 END) AS with_source_note,
       ROUND(100.0*SUM(CASE WHEN source_note IS NOT NULL AND TRIM(source_note)<>'' THEN 1 ELSE 0 END)/COUNT(*),1) AS pct
FROM document_cache
WHERE is_front_matter=0 AND volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24');
SELECT COUNT(*) AS docs_all_rows, SUM(CASE WHEN source_note IS NOT NULL AND TRIM(source_note)<>'' THEN 1 ELSE 0 END) AS with_source_note_all_rows
FROM document_cache
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24');
-- document_sources rows for the nine
SELECT COUNT(*) AS ds_rows,
       SUM(CASE WHEN repository IS NOT NULL AND repository<>'' THEN 1 ELSE 0 END) AS with_repository,
       SUM(CASE WHEN series_name IS NOT NULL AND series_name<>'' THEN 1 ELSE 0 END) AS with_series_name,
       SUM(CASE WHEN lot_file_norm IS NOT NULL AND lot_file_norm<>'' THEN 1 ELSE 0 END) AS with_lot,
       SUM(CASE WHEN decimal_class IS NOT NULL AND decimal_class<>'' THEN 1 ELSE 0 END) AS with_decimal_class,
       SUM(CASE WHEN record_group IS NOT NULL AND record_group<>'' THEN 1 ELSE 0 END) AS with_record_group
FROM document_sources
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24');
SELECT citation_era, COUNT(*) AS n FROM document_sources
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24')
GROUP BY citation_era ORDER BY n DESC;
-- corpus baseline
SELECT COUNT(*) AS corpus_docs_nonfront FROM document_cache WHERE is_front_matter=0;
SELECT COUNT(*) AS corpus_ds_rows, SUM(CASE WHEN series_name IS NOT NULL AND series_name<>'' THEN 1 ELSE 0 END) AS with_series_name,
       SUM(CASE WHEN repository IS NOT NULL AND repository<>'' THEN 1 ELSE 0 END) AS with_repository,
       SUM(CASE WHEN citation_era<>'unrecognized' THEN 1 ELSE 0 END) AS recognized FROM document_sources;
-- external_citations for the nine
SELECT volume_id, COUNT(*) AS ec_rows, SUM(inherited) AS inherited FROM external_citations
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24')
GROUP BY volume_id ORDER BY volume_id;
SELECT COUNT(*) AS ec_total, COUNT(DISTINCT COALESCE(repository,'')||'|'||COALESCE(collection,'')||'|'||COALESCE(lot_file_norm,'')) AS distinct_units FROM external_citations
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24');
