.mode list
.headers on
-- Q1: decade shape of stem 'corrupt' (frus_documents MATCH body_text), apparatus excluded; denominator = dated non-apparatus docs per decade
WITH hits AS (
 SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
 WHERE frus_documents MATCH 'body_text:corrupt' AND c.is_front_matter=0 AND c.is_editorial_note=0),
den AS (
 SELECT substr(d.date_iso,1,3)||'0s' dec, COUNT(*) n FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
 WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso IS NOT NULL GROUP BY 1),
num AS (
 SELECT substr(d.date_iso,1,3)||'0s' dec, COUNT(*) n FROM hits h JOIN document_dates d ON d.volume_id=h.volume_id AND d.document_id=h.document_id GROUP BY 1)
SELECT den.dec, num.n hits, den.n denom, round(1000.0*num.n/den.n,2) per1000 FROM den LEFT JOIN num USING(dec) ORDER BY 1;
SELECT 'total hits', COUNT(*) FROM hits;
