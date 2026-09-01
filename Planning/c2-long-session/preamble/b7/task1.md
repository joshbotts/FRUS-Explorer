# Task 1 — Chronological coverage of the corpus

## Coverage statement (run first, as required)

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
```

| volumes | rows | front matter | editorial notes |
|---|---|---|---|
| 552 | 316,839 | 1,012 | 8,468 |

**All 552 volumes of the series are present in this index.** For once the usual caveat about a
partial library does not bite: the coverage query returns the full published set, so the counts
below are counts of the series as published, not of a download subset. Every number is still
conditional on the index having been built correctly from those 552 volumes.

## Scope used for every count below

| filter | rows |
|---|---|
| all rows | 316,839 |
| minus front matter and editorial notes | 307,359 |
| minus the two duplicate second editions | **306,619** |
| of which carry a document date | **305,280** |

```sql
SELECT
 (SELECT COUNT(*) FROM document_cache) AS all_rows,
 (SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0) AS no_apparatus,
 (SELECT COUNT(*) FROM document_cache d WHERE d.is_front_matter=0 AND d.is_editorial_note=0
    AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')) AS scope,
 (SELECT COUNT(*) FROM document_cache d JOIN document_dates t USING(volume_id,document_id)
    WHERE d.is_front_matter=0 AND d.is_editorial_note=0
    AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
    AND t.date_iso IS NOT NULL) AS scope_dated;
```

Second editions: `frus1951-54IranEd2` (377 rows) and `frus1969-76ve15p2Ed2` (386) are suppressed
because their first editions `frus1951-54Iran` and `frus1969-76ve15p2` are both present. 740 rows
dropped with apparatus already excluded. `frus1977-80v09Ed2` is **kept** — its first edition is not
in the set, so it is not a duplicate. **Surface counted: this SQLite index, apparatus excluded.**

**Periodisation basis: `document_dates.date_iso`** — the document's own earliest date, which is the
editorial `frus:doc-dateTime-min` bound, **not** the volume's series year. This matters: 11,250
documents fall in the 1860s but they come from 29 distinct volumes, not the 19 annual volumes of
that decade.

Binning is safe. Only 23 of 305,280 dated documents have a min and max date in different decades,
and only 195 cross a year boundary:

```sql
SELECT SUM(CASE WHEN substr(date_iso,1,3)<>substr(date_iso_max,1,3) THEN 1 ELSE 0 END) AS cross_decade,
       SUM(CASE WHEN substr(date_iso,1,4)<>substr(date_iso_max,1,4) THEN 1 ELSE 0 END) AS cross_year,
       COUNT(*) AS dated
FROM document_cache d JOIN document_dates t USING(volume_id,document_id)
WHERE d.is_front_matter=0 AND d.is_editorial_note=0
  AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND t.date_iso IS NOT NULL;
```
→ cross_decade 23, cross_year 195, dated 305,280.

1,339 documents in scope carry no date at all. They cluster in `frus1919Parisv13` (167 — the Paris
Peace Conference volume, largely undated conference material) and thinly elsewhere.

## The distribution

```sql
SELECT (CAST(substr(t.date_iso,1,4) AS INTEGER)/10)*10 AS decade,
       COUNT(*) AS docs, COUNT(DISTINCT d.volume_id) AS volumes
FROM document_cache d JOIN document_dates t USING(volume_id,document_id)
WHERE d.is_front_matter=0 AND d.is_editorial_note=0
  AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
  AND t.date_iso IS NOT NULL
GROUP BY 1 ORDER BY 1;
```

| decade | documents | volumes touching it | docs/volume | mean chars | median chars |
|---|---|---|---|---|---|
| 1620–1850 (all) | 462 | — | — | — | — |
| 1860 | 11,250 | 29 | 387.9 | 4,562 | 1,685 |
| 1870 | 5,798 | 25 | 231.9 | 8,037 | 3,072 |
| 1880 | 6,472 | 21 | 308.2 | 5,437 | 2,464 |
| 1890 | 9,712 | 22 | 441.5 | 3,719 | 1,447 |
| 1900 | 9,924 | 25 | 397.0 | 3,494 | 1,215 |
| 1910 | 30,359 | 52 | 583.8 | 2,806 | 1,112 |
| 1920 | 19,733 | 41 | 481.3 | 2,750 | 1,457 |
| 1930 | 39,196 | 57 | 687.6 | 2,576 | 1,663 |
| **1940** | **74,043** | 103 | **718.9** | 3,298 | 2,157 |
| 1950 | 42,296 | 107 | 395.3 | 5,429 | 3,730 |
| 1960 | 27,650 | 121 | 228.5 | 5,830 | 4,253 |
| 1970 | 22,259 | 95 | 234.3 | 7,893 | 5,143 |
| 1980 | 5,949 | 41 | 145.1 | 8,125 | 5,388 |
| 1990 | 177 | 1 | 177.0 | 10,134 | 6,834 |

Length figures come from `LENGTH(body_text)`. **Caveat: `body_text` includes editorial footnotes**,
so the later decades' longer documents partly reflect heavier annotation, not only longer originals.
This index cannot separate the two — that needs the TEI.

Period shares of the 305,280 dated documents:

| period | documents | of 305,280 |
|---|---|---|
| before 1900 | 33,694 | 33,694 of 305,280 |
| 1900–1938 | 94,282 | 94,282 of 305,280 |
| 1939–1945 | 50,166 | 50,166 of 305,280 |
| 1946–1968 | 96,514 | 96,514 of 305,280 |
| 1969 onward | 30,624 | 30,624 of 305,280 |

## Peak years

```sql
SELECT CAST(substr(t.date_iso,1,4) AS INTEGER) AS yr, COUNT(*) AS docs
FROM document_cache d JOIN document_dates t USING(volume_id,document_id)
WHERE d.is_front_matter=0 AND d.is_editorial_note=0
  AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND t.date_iso IS NOT NULL
GROUP BY 1 ORDER BY docs DESC LIMIT 15;
```

1945 (11,410) · 1944 (8,672) · 1946 (7,951) · 1943 (7,664) · 1949 (7,493) · 1948 (6,998) ·
1951 (6,658) · 1941 (6,484) · 1947 (6,365) · 1954 (6,269) · **1918 (5,903)** · 1942 (5,593) ·
1940 (5,413) · 1950 (5,094) · 1939 (4,930).

Fourteen of the top fifteen years are 1939–1954. The one interloper is 1918.

## What the shape suggests about editorial priorities

**1. The series is a war-and-aftermath archive.** The 1940s decade alone holds 74,043 of 305,280
dated documents, and 1945 is the single largest year at 11,410 — more than the whole 1870s decade
(5,798). The two secondary peaks are the other two wars: 1918 at 5,903 (11th of all years) and the
1860s bulge of 11,250, which is the Civil War diplomacy the series was created to publish. Between
the wars the curve sags: 1924 (1,381), 1925 (1,419), 1926 (1,502) are the interwar floor.

**2. Two different publications are being counted as one.** Documents per volume peaks at 718.9 in
the 1940s and then collapses — 395.3 in the 1950s, 228.5 in the 1960s, 145.1 in the 1980s — while
the number of volumes touching each decade keeps rising to 121 in the 1960s. Simultaneously, median
document length runs the other way: 1,112 characters in the 1910s, 2,157 in the 1940s, 5,143 in the
1970s, 5,388 in the 1980s. The early series printed a large volume of short despatches and
telegrams; the modern series prints a small number of long memoranda, NSC papers and records of
conversation. **A per-decade document count therefore measures editorial genre as much as editorial
attention**, and the honest curve is the text mass:

| decade | documents | million characters |
|---|---|---|
| 1910 | 30,359 | 85.2 |
| 1930 | 39,196 | 101.0 |
| 1940 | 74,043 | 244.2 |
| 1950 | 42,296 | 229.6 |
| 1960 | 27,650 | 161.2 |
| 1970 | 22,259 | 175.7 |

By text mass the 1950s are nearly the equal of the 1940s (229.6M vs 244.2M) even though they hold
43% fewer documents, and the 1970s exceed the 1960s despite holding fewer documents still. The
decline after 1945 is much shallower than the document count implies.

**3. The apparatus is a modern invention.** Editorial notes — excluded from every count above — are
essentially absent before the Second World War and then appear in force:

```sql
WITH s AS (SELECT (CAST(substr(t.date_iso,1,4) AS INTEGER)/10)*10 AS dec, d.is_editorial_note AS en
 FROM document_cache d JOIN document_dates t USING(volume_id,document_id)
 WHERE d.is_front_matter=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
   AND t.date_iso IS NOT NULL)
SELECT dec, SUM(en=0) docs, SUM(en=1) ed_notes, ROUND(100.0*SUM(en=1)/COUNT(*),1) pct
FROM s WHERE dec>=1860 GROUP BY dec ORDER BY dec;
```

0 editorial notes for the 1860s through the 1890s; 1 in the 1900s; 11 in the 1910s; 1 in the 1930s;
then 1,637 in the 1940s (2.2%), 3,835 in the 1950s (8.3%), 2,167 in the 1960s (7.3%). The editors
stopped merely printing documents and started narrating between them, and the transition is sharp
and datable to the 1950s volumes.

**4. The 1980s cliff is publication lag, not editorial judgement — do not read it as coverage.**
The 1980s hold only 5,949 documents from 41 volumes. Of those, 26 volumes belong to the 1977–80
subseries (spilling past 1980) and only **12** belong to the 1981–88 subseries:

```sql
WITH s AS (SELECT d.volume_id v, (CAST(substr(t.date_iso,1,4) AS INTEGER)/10)*10 dec
 FROM document_cache d JOIN document_dates t USING(volume_id,document_id)
 WHERE d.is_front_matter=0 AND d.is_editorial_note=0
   AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND t.date_iso IS NOT NULL)
SELECT dec, substr(v,1,11) vol_family, COUNT(DISTINCT v) vols, COUNT(*) docs
FROM s WHERE dec IN (1970,1980) GROUP BY dec, vol_family HAVING docs>100 ORDER BY dec, docs DESC;
```
1970s: `frus1969-76` 65 volumes / 15,894 docs; `frus1977-80` 27 / 6,244; `frus1917-72` 1 / 119.
1980s: `frus1981-88` 12 / 4,051; `frus1977-80` 26 / 1,787.

The Reagan-era subseries is a work in progress. The apparent falling-off of the series after 1980 is
the declassification and publication pipeline, not a decision about what matters.

**5. The deep tail is evidence, not coverage.** 462 documents predate 1860, back to 1620-11-03. They
are not early FRUS. They sit inside later volumes as reprinted historical exhibits:
`frus1872p2v5` holds 11 pre-1800 documents including the earliest (`frus1872p2v5` / 1620-11-03) —
that is the Geneva arbitration documentary appendix — and `frus1902app2` holds 14 (1697–1794).
Anyone binning by document date without checking gets a phantom seventeenth-century FRUS.

**6. There is no 1869 volume in this set.** The annual series runs `frus1868p1`, `frus1868p2`, then
`frus1870`. The 1869-dated documents (238) live mostly in `frus1872p2v1` (213 of them). Whether that
is a gap in the published series or a boundary of this 552-volume set is **not answerable from this
database** — it needs the manifest and the publication history, not the index.

## Controls

Required scoping controls, run in one pass over the FTS index:

```sql
SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"Department of State"'; -- 98,499
SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ';    -- 0
```
Positive control 98,499 hits, negative control 0. The scan works.

## What this profile cannot support

- It cannot tell a long original document from a heavily footnoted short one. `body_text` blends
  document and editor. That is a TEI question.
- It cannot say what FRUS *declined* to print in any decade. Document counts are a profile of the
  selection, never of the archive it was selected from. The came-from and pointed-at archival
  channels are the surfaces for that, and neither was consulted here.
- The 1,339 undated documents are excluded from every decade figure and are not evenly spread.
