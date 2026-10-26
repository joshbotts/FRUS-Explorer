.mode column
.headers on
SELECT MIN(date_iso) AS earliest, MAX(COALESCE(date_iso_max, date_iso)) AS latest, COUNT(*) AS dated_rows FROM document_dates
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24') AND date_iso IS NOT NULL AND date_iso <> '';
SELECT volume_id, MIN(date_iso) AS earliest, MAX(COALESCE(date_iso_max, date_iso)) AS latest FROM document_dates
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24') AND date_iso IS NOT NULL AND date_iso <> '' GROUP BY volume_id ORDER BY volume_id;
SELECT COUNT(DISTINCT volume_id) AS frus1981_88_volumes_in_index FROM document_cache WHERE volume_id LIKE 'frus1981-88%';
SELECT volume_id, COUNT(*) AS docs FROM document_cache WHERE volume_id LIKE 'frus1981-88%' GROUP BY volume_id ORDER BY volume_id;
-- Kennedy Library NSF sub-series ranking in the nine, from document_sources
SELECT series_name, COUNT(*) AS n FROM document_sources
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24')
  AND repository LIKE '%Kennedy Library%' AND raw_text LIKE '%National Security Files%'
GROUP BY series_name ORDER BY n DESC LIMIT 12;
SELECT SUBSTR(raw_text, 1, 60) AS raw_head, COUNT(*) AS n FROM document_sources
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp')
  AND raw_text LIKE '%Kennedy Library, National Security Files%'
GROUP BY raw_head ORDER BY n DESC LIMIT 12;
SELECT COUNT(DISTINCT decimal_class) AS distinct_decimal_classes_nine FROM document_sources
WHERE volume_id IN ('frus1961-63v10','frus1961-63v11','frus1961-63v12','frus1961-63v10-12mSupp','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1977-80v23','frus1977-80v24') AND decimal_class IS NOT NULL AND decimal_class<>'';
