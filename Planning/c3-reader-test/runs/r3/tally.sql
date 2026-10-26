
CREATE TEMP TABLE p(v TEXT,d TEXT);
INSERT INTO p VALUES ('frus1913','d7'),('frus1913','d894'),('frus1917','d379'),('frus1917','d407'),('frus1919v01','d869'),('frus1920v03','d199'),('frus1921v02','d344'),('frus1921v02','d349'),('frus1923v02','d481'),('frus1926v02','d476'),('frus1930v01','d375'),('frus1930v01','d476'),('frus1931v02','d208'),('frus1932v05','d478'),('frus1934v05','d218'),('frus1933v05','d430'),('frus1933v05','d508'),('frus1934v05','d75'),('frus1943v05','d33'),('frus1943v05','d34'),('frus1943v05','d142'),('frus1944v07','d403'),('frus1945v09','d1170'),('frus1948v09','d7'),('frus1949v02','d446'),('frus1949v02','d448'),('frus1955-57v06','d354'),('frus1958-60v05mSupp','es_d33'),('frus1958-60v05mSupp','es_d40'),('frus1961-63v12','d421'),('frus1961-63v12','d423'),('frus1964-68v31','d141'),('frus1964-68v31','d152'),('frus1964-68v31','d518'),('frus1969-76v21','d358'),('frus1969-76ve08','d6'),('frus1900','d530'),('frus1911','d353');
SELECT 'pairs/volumes', count(*), count(DISTINCT v) FROM p;
SELECT 'came-from by era/repository/RG', s.citation_era, s.repository, coalesce(s.record_group,''), count(*) FROM p JOIN document_sources s ON s.volume_id=p.v AND s.document_id=p.d GROUP BY 2,3,4 ORDER BY 5 DESC;
SELECT 'pointed-at rows', count(*), count(DISTINCT e.volume_id||'/'||e.document_id) FROM p JOIN external_citations e ON e.volume_id=p.v AND e.document_id=p.d;
SELECT 'whole-text capture', count(*), sum(length(c.body_text)) FROM p JOIN document_cache c ON c.volume_id=p.v AND c.document_id=p.d;

SELECT 'pointed-at rows by anchor', e.anchor, count(*), count(DISTINCT e.volume_id||'/'||e.document_id) FROM p JOIN external_citations e ON e.volume_id=p.v AND e.document_id=p.d GROUP BY 2;
SELECT 'came-from rows total', count(*) FROM p JOIN document_sources s ON s.volume_id=p.v AND s.document_id=p.d;
