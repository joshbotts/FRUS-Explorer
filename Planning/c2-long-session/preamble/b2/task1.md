# Task 1 — Chronological coverage of the corpus

## 0. Coverage statement (run first, per house rules)

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
```

| volumes | documents | front matter | editorial notes |
|---|---|---|---|
| **552** | **316,839** | 1,012 | 8,468 |

The local library holds **552 of the 552 volumes** in the series — this is a complete
snapshot, not a partial one, so nothing below needs the usual "may reflect my partial
library" hedge on volume availability. (It remains a snapshot of a *live* series: FRUS is
still being published, and §4 below shows exactly where that frontier bites.)

**Analysis scope used throughout.** Apparatus excluded (`is_front_matter=0 AND
is_editorial_note=0`) and the two duplicate second editions suppressed
(`frus1951-54IranEd2`, `frus1969-76ve15p2Ed2`; `frus1977-80v09Ed2` is *kept* — it has no
first edition to duplicate):

```sql
SELECT COUNT(DISTINCT volume_id) AS volumes, COUNT(*) AS docs
FROM document_cache
WHERE is_front_matter=0 AND is_editorial_note=0
  AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
```
→ **550 volumes, 306,619 documents.**

Of those, **1,339 of 306,619 carry no parsable date** and drop out of every count below,
leaving **305,280 dated documents**. The undated residue is concentrated in the Great War
and Second World War volumes (`frus1919Parisv13` alone accounts for 167 of the 1,339).

**Periodisation.** All decades below are keyed on `document_dates.date_iso`, which is the
TEI `frus:doc-dateTime-min` — the **document's own date**, *not* the volume's series year.
That distinction is load-bearing and §3 shows why.

**Robustness of that choice.** 12,385 documents corpus-wide are `date_certainty='range'`.
Re-running the decade assignment on `date_iso_max` instead of `date_iso` moves only
**23 of 305,280** documents into a different decade (195 into a different *year*):

```sql
SELECT COUNT(*) AS dated_docs,
 SUM(CASE WHEN (CAST(substr(date_iso,1,4) AS INTEGER)/10)*10
        <> (CAST(substr(date_iso_max,1,4) AS INTEGER)/10)*10 THEN 1 ELSE 0 END) AS decade_differs,
 SUM(CASE WHEN substr(date_iso,1,4) <> substr(date_iso_max,1,4) THEN 1 ELSE 0 END) AS year_differs
FROM document_dates dd JOIN document_cache dc USING(volume_id,document_id)
WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso<>'';
```
The min/max choice is immaterial. Nothing below turns on it.

**Scan controls** (run in one pass, per house rules):

```sql
SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents
WHERE frus_documents MATCH '"Department of State"';   -- 98,499 hits / 551 volumes
SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents
WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ';      -- 0 hits / 0 volumes
```
Positive control fires in **551 of 552** volumes; negative control returns zero. The scan
works. The single miss is `frus1919Parisv05` — the Paris Peace Conference council minutes,
which are proceedings of an inter-Allied body and speak of "the American Delegation", not
the Department. A real absence with a documentary reason, not a broken query.

---

## 1. Documents per decade of document date

```sql
SELECT (CAST(substr(dd.date_iso,1,4) AS INTEGER)/10)*10 AS decade,
       COUNT(*) AS docs,
       COUNT(DISTINCT dc.volume_id) AS volumes
FROM document_cache dc
JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id
WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
  AND dd.date_iso IS NOT NULL AND dd.date_iso<>''
GROUP BY 1 ORDER BY 1;
```

| decade | documents | share of 305,280 | volumes touching | docs per touching volume |
|---|---:|---:|---:|---:|
| 1620s–1850s (13 sparse decades) | 462 | 462 of 305,280 | 15 | — |
| 1860s | 11,250 | 11,250 of 305,280 | 29 | 388 |
| 1870s | 5,798 | 5,798 of 305,280 | 25 | 232 |
| 1880s | 6,472 | 6,472 of 305,280 | 21 | 308 |
| 1890s | 9,712 | 9,712 of 305,280 | 22 | 442 |
| 1900s | 9,924 | 9,924 of 305,280 | 25 | 397 |
| 1910s | 30,359 | 30,359 of 305,280 | 52 | 584 |
| 1920s | 19,733 | 19,733 of 305,280 | 41 | 481 |
| 1930s | 39,196 | 39,196 of 305,280 | 57 | 688 |
| **1940s** | **74,043** | **74,043 of 305,280** | 103 | 719 |
| 1950s | 42,296 | 42,296 of 305,280 | 107 | 395 |
| 1960s | 27,650 | 27,650 of 305,280 | 121 | 229 |
| 1970s | 22,259 | 22,259 of 305,280 | 95 | 234 |
| 1980s | 5,949 | 5,949 of 305,280 | 41 | 145 |
| 1990s | 177 | 177 of 305,280 | 1 | 177 |

Quartiles of the dated in-scope documents, by year: **p10 = 1896, p25 = 1920, median =
1943, p75 = 1954, p90 = 1969.** Half the printed corpus falls in the 34 years 1920–1954.

## 2. The same distribution normalised by year

Decades are a poor unit when the series' own publishing rhythm changes. Per calendar year:

```sql
WITH y AS (SELECT CAST(substr(dd.date_iso,1,4) AS INTEGER) yr
 FROM document_cache dc JOIN document_dates dd USING(volume_id,document_id)
 WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
   AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso<>'')
SELECT CASE
  WHEN yr<1861 THEN 'a. pre-1861 (retrospective annexes)'
  WHEN yr<=1913 THEN 'b. 1861-1913'   WHEN yr<=1918 THEN 'c. 1914-1918 (Great War)'
  WHEN yr<=1938 THEN 'd. 1919-1938'   WHEN yr<=1945 THEN 'e. 1939-1945 (WWII)'
  WHEN yr<=1968 THEN 'f. 1946-1968'   WHEN yr<=1980 THEN 'g. 1969-1980'
  ELSE 'h. 1981-1991' END AS band,
 COUNT(*) docs, MIN(yr) y0, MAX(yr) y1, ROUND(1.0*COUNT(*)/(MAX(yr)-MIN(yr)+1),0) docs_per_year
FROM y GROUP BY 1 ORDER BY 1;
```

| band | documents | docs / year |
|---|---:|---:|
| pre-1861 (retrospective annexes) | 474 | 2 |
| 1861–1913 | 48,663 | 918 |
| **1914–1918 (Great War)** | 20,655 | **4,131** |
| 1919–1938 | 58,184 | 2,909 |
| **1939–1945 (Second World War)** | 50,166 | **7,167** |
| 1946–1968 | 96,514 | 4,196 |
| 1969–1980 | 26,297 | 2,191 |
| 1981–1991 | 4,327 | 393 |

Peak single years, from the annual series: **1945 = 11,410 documents**, 1918 = 5,903,
1944 = 8,672, 1949 = 7,493, 1943 = 7,664. The single deepest trough after the series
begins is **1869 = 238**.

## 3. Where the earliest documents actually live — and why they are not "coverage"

Every one of the 474 pre-1861 documents sits in a handful of arbitration and claims
appendices, not in a volume that covers those years:

```sql
SELECT dc.volume_id, COUNT(*) AS docs, MIN(dd.date_iso) AS earliest, MAX(dd.date_iso) AS latest
FROM document_cache dc JOIN document_dates dd USING(volume_id,document_id)
WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND dd.date_iso<>'' AND CAST(substr(dd.date_iso,1,4) AS INTEGER) < 1861
GROUP BY 1 ORDER BY 2 DESC;
```

| volume | docs | earliest | latest |
|---|---:|---|---|
| frus1872p2v1 | 244 | 1811-07-18 | 1860-06-24 |
| frus1872p2v5 | 102 | **1620-11-03** | 1859-12-31 |
| frus1894app2 | 43 | 1826-12-23 | 1855-01-31 |
| frus1902app2 | 32 | 1697-01-01 | 1859-01-01 |
| frus1872p2v2 | 23 | 1803-05-04 | 1859-10-12 |
| frus1873p1v2 | 16 | 1802-04-14 | 1860-08-25 |
| frus1873p2v3 | 5 | 1793-08-23 | 1860-12-09 |
| (8 further volumes) | 1 each | — | — |

The earliest document in the whole corpus is `frus1872p2v5/d4`, dated 1620-11-03 —
Hudson's Bay Company charter material submitted as evidence in the Northwest Water
Boundary arbitration and printed in the 1872 volume. `frus1902app2` is the Pious Fund of
the Californias arbitration: Spanish colonial decrees of the 1760s–90s printed in 1902.
These are **not misparsed dates**; they are genuine document dates for genuine documents.
But they measure the reach of *litigation exhibits*, not the reach of the series.

**The series' real chronological floor is 1861.** 1860 yields 12 documents across 9
volumes; 1861 yields 387 across 9. This is the concrete methodological warning for anyone
using this corpus: a query filtered on document date will return 17th- and 18th-century
material that FRUS never set out to document, because a 19th-century arbitration case file
carries its exhibits' own dates.

## 4. The 1980s cliff is a publication frontier, not an editorial judgement

The drop from 22,259 documents (1970s) to 5,949 (1980s) to 177 (1990s) looks like the
editors losing interest. It is not. From the bundled `manifest.json` (volume coverage
spans and subseries), the series' published volume count by subseries at the modern end:

| subseries | volumes published in this snapshot |
|---|---:|
| 1964-68 | 35 |
| 1969-76 | 66 |
| 1977-80 | 27 |
| **1981-88** | **12** |
| **1989-92** | **1** |

The Reagan subseries is roughly one-fifth complete against the Nixon–Ford one, and the
Bush subseries has a single volume. The latest coverage year anywhere in the manifest is
**1991**. So the 1980s and 1990s columns in §1 are measuring *how far the Office of the
Historian has got*, and will keep rising for decades. Any per-decade rate computed over
1981–1991 is a floor, not an estimate.

## 5. What the shape says about editorial priorities

**(a) The series is a war-and-crisis series, by volume of paper.** The two clearest
excursions above trend are the Great War (4,131 docs/yr against 918 for the preceding
half-century) and the Second World War (7,167 docs/yr, the highest sustained rate in the
corpus). 1945 alone — 11,410 documents — is more than the entire 1870s and 1880s combined
(12,270). The Cold War's opening decade sustains that: 1946–1951 never falls below 5,000.

**(b) Editorial density and volume count moved in opposite directions after 1950.** Docs
per touching volume peaks in the 1940s at 719 and falls to 229 in the 1960s — while the
number of volumes touching each decade *rises* from 103 to 121. The post-war series
publishes **more volumes containing fewer documents each**. That is a change in what a
volume is: the 19th-century annual volume is a bound omnibus of the year's despatches,
whereas 1969-76's 66 volumes are thematic and regional slices, each admitting a smaller,
more heavily selected set. The subseries counts in the manifest make the transition
visible — one volume per year from 1861 through 1913, then multi-volume annual sets, then
in 1952 a switch to administration blocks (1952-54: 28 volumes; 1955-57: 29; 1964-68: 35;
1969-76: 66).

**(c) The 19th century is thin, and unevenly thin.** 1861–1913 averages 918 documents a
year, but the annual pattern within it is jagged in a way that tracks the Department's own
publishing effort rather than the volume of diplomacy: 1865 = 2,766, then 1869 = 238, then
back to 613 in 1871. The Civil War years are documented at four to ten times the rate of
Reconstruction. Whatever else it is, this is not a constant editorial standard applied
across time.

**(d) The modern apparatus is a post-1940 invention, measurably.** Editorial notes — which
these counts exclude — are almost entirely absent before the Second World War:

```sql
SELECT (CAST(substr(dd.date_iso,1,4) AS INTEGER)/10)*10 AS decade,
       SUM(CASE WHEN dc.is_editorial_note=1 THEN 1 ELSE 0 END) AS ed_notes
FROM document_cache dc JOIN document_dates dd USING(volume_id,document_id)
WHERE dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
  AND dd.date_iso<>'' AND CAST(substr(dd.date_iso,1,4) AS INTEGER)>=1860
GROUP BY 1 ORDER BY 1;
```
1860s–1930s: **13 editorial notes in total across eight decades.** 1940s: 1,637. 1950s:
3,835. 1960s: 2,167. 1970s: 623. 1980s: 174. The editors' own interpolated voice — the
device used to narrate a meeting whose record is still classified, or to bridge a gap in
the printed record — appears only once FRUS becomes a scholarly compilation prepared long
after the fact rather than a near-contemporary publication of correspondence. **8,437 of
the 8,449 dated editorial notes fall in 1940–1989.**

## 6. Caveats on these numbers

- Every count is **documents**, not pages or words. A one-line telegram and a 40-page
  conference minute each count once. The 1940s' dominance is partly a genre effect: the
  wartime record is telegraphic and therefore document-dense.
- `body_text` in this index includes editorial footnotes, so any *text*-based measure
  (which none of the above are) would blend document and editor language. The counts here
  are row counts on `document_cache`, so they are unaffected.
- 1,339 of 306,619 in-scope documents are undated and are silently absent from §1 and §2.
- The corpus is a **selection**. These curves describe what the Office of the Historian
  chose to print, not what the Department produced. The archival channel — which record
  groups and lot files this printed material was drawn out of, and which the footnotes
  point at without printing — is a separate question that this database cannot answer;
  it needs the bundled archival indexes.
