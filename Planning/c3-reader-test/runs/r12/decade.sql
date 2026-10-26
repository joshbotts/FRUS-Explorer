WITH num AS (
 SELECT (CAST(substr(dd.date_iso,1,4) AS INT)/10)*10 dec, s.volume_id, count(*) n
 FROM s.scope s JOIN document_cache c ON c.volume_id=s.volume_id AND c.document_id=s.document_id AND c.is_front_matter=0 AND c.is_editorial_note=0
 JOIN document_dates dd ON dd.volume_id=s.volume_id AND dd.document_id=s.document_id
 GROUP BY 1,2),
den AS (
 SELECT (CAST(substr(dd.date_iso,1,4) AS INT)/10)*10 dec, count(*) d
 FROM document_cache c JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id
 WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND dd.date_iso IS NOT NULL GROUP BY 1)
SELECT num.dec, sum(num.n) numer, den.d denom, round(1000.0*sum(num.n)/den.d,1) per1000,
 (SELECT n FROM num n2 WHERE n2.dec=num.dec ORDER BY n DESC LIMIT 1) topvol_n,
 (SELECT volume_id FROM num n2 WHERE n2.dec=num.dec ORDER BY n DESC LIMIT 1) topvol,
 round(1.0*(SELECT n FROM num n2 WHERE n2.dec=num.dec ORDER BY n DESC LIMIT 1)/sum(num.n),2) topshare
FROM num JOIN den ON den.dec=num.dec GROUP BY num.dec ORDER BY num.dec;
