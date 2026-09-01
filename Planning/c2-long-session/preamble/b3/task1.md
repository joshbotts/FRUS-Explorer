# Task 1 — Chronological coverage of the corpus

## 0. Coverage statement (run first, as required)

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
```

| volumes | documents | front matter | editorial notes |
|---|---|---|---|
| 552 | 316,839 | 1,012 | 8,468 |

**The library is complete for this run: all 552 volumes of the series are present.** Every count
below is still conditional on this local index rather than on the published series, but in this
case the two coincide at the volume level. Where a number is thin I say so explicitly.

## 1. Scope and method

**Periodisation field.** I periodised on **`document_dates.date_iso`**, which I verified is the
date part of the TEI's `frus:doc-dateTime-min` — not the volume's series year. Spot-check against
the XML for `frus1945v06`:

```sql
SELECT volume_id, document_id, date_iso, date_iso_max, date_precision, date_certainty
FROM document_dates WHERE volume_id='frus1945v06' AND document_id IN ('d1','d2','d3','d10');
```
| doc | date_iso | date_iso_max | precision | certainty |
|---|---|---|---|---|
| d1 | 1945-01-04 | 1945-01-04 | day | exact |
| d2 | 1945-01-05 | 1945-01-05 | day | exact |
| d3 | 1945-01-06 | 1945-01-06 | day | exact |
| d10 | 1945-01-24 | 1945-01-24 | day | exact |

against the TEI `<div>` attributes in `/Users/jbotts/Development/frus/volumes/frus1945v06.xml`:
`d1` carries `frus:doc-dateTime-min="1945-01-04T13:00:00-05:00"`, `d3` carries
`frus:doc-dateTime-min="1945-01-06T00:00:00-05:00"` / `-max="1945-01-06T23:59:59-05:00"`. The
index field is the editorial minimum bound, as required.

**Exclusions applied throughout.** `is_front_matter = 1` and `is_editorial_note = 1` are dropped.
The two duplicate second editions are dropped (`frus1951-54IranEd2`, `frus1969-76ve15p2Ed2`);
`frus1977-80v09Ed2` is kept because it has no first edition in the index. Verified:

```sql
SELECT volume_id, COUNT(*) FROM document_cache WHERE volume_id LIKE '%Ed2%' GROUP BY 1;
-- frus1951-54IranEd2 377 | frus1969-76ve15p2Ed2 386 | frus1977-80v09Ed2 418
SELECT volume_id, COUNT(*) FROM document_cache
WHERE volume_id IN ('frus1951-54Iran','frus1969-76ve15p2','frus1977-80v09') GROUP BY 1;
-- frus1951-54Iran 378 | frus1969-76ve15p2 345   (frus1977-80v09 returns no row)
```

**Working denominator.**

```sql
SELECT COUNT(*) AS scoped_docs, COUNT(DISTINCT volume_id) AS vols
FROM document_cache
WHERE is_front_matter=0 AND is_editorial_note=0
  AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
-- 306,619 documents across 550 volumes
```

Of those, **1,339 of 306,619 carry no date at all** and drop out of every decade table:

```sql
SELECT SUM(d.date_iso IS NULL), COUNT(*)
FROM document_cache c JOIN document_dates d USING (volume_id, document_id)
WHERE c.is_front_matter=0 AND c.is_editorial_note=0
  AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
-- 1,339 of 306,619
```
They are spread thin (largest single concentration `frus1919Parisv13`, 167 — the treaty-text
volume). **The dated denominator for everything below is therefore 305,280.**

**Date quality.** Across the whole `document_dates` table:

```sql
SELECT date_precision, date_certainty, COUNT(*) FROM document_dates GROUP BY 1,2 ORDER BY 3 DESC;
```
day/exact 299,568 · day/range 12,385 · day/approximate 2,420 · (null) 2,163 · month/exact 251 ·
year/exact 52. So 299,568 of 316,839 are exact single-day dates. Of the 2,876 in-scope documents
whose min and max differ, only **23 cross a decade boundary**, so periodising on the minimum is
stable at decade grain:

```sql
SELECT COUNT(*), SUM(substr(date_iso,1,4)<>substr(date_iso_max,1,4)),
       SUM(CAST(substr(date_iso,1,4) AS INT)/10 <> CAST(substr(date_iso_max,1,4) AS INT)/10)
FROM document_cache c JOIN document_dates d USING (volume_id, document_id)
WHERE c.is_front_matter=0 AND c.is_editorial_note=0
  AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
  AND d.date_iso IS NOT NULL AND d.date_iso_max IS NOT NULL AND d.date_iso <> d.date_iso_max;
-- 2,876 ranged | 195 cross a year | 23 cross a decade
```

## 2. Documents per decade of document date

```sql
SELECT (CAST(substr(d.date_iso,1,4) AS INTEGER)/10)*10 AS decade, COUNT(*) AS docs,
       COUNT(DISTINCT c.volume_id) AS vols
FROM document_cache c JOIN document_dates d USING (volume_id, document_id)
WHERE c.is_front_matter=0 AND c.is_editorial_note=0
  AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
  AND d.date_iso IS NOT NULL
GROUP BY 1 ORDER BY 1;
```

| decade | documents | volumes touched |
|---|---|---|
| 1620s–1850s (see §3) | 474 | 15 |
| 1860 | 11,250 | 29 |
| 1870 | 5,798 | 25 |
| 1880 | 6,472 | 21 |
| 1890 | 9,712 | 22 |
| 1900 | 9,924 | 25 |
| 1910 | 30,359 | 52 |
| 1920 | 19,733 | 41 |
| 1930 | 39,196 | 57 |
| **1940** | **74,043** | **103** |
| 1950 | 42,296 | 107 |
| 1960 | 27,650 | 121 |
| 1970 | 22,259 | 95 |
| 1980 | 5,949 | 41 |
| 1990 | 177 | 1 |

Full pre-1861 detail (the same query, `d.date_iso < '1861-01-01'`): 1620s 3 · 1660s 1 · 1690s 1 ·
1740s 1 · 1750s 1 · 1760s 3 · 1770s 5 · 1780s 2 · 1790s 10 · 1800s 13 · 1810s 100 · 1820s 28 ·
1830s 5 · 1840s 139 · 1850s 150. **474 of 305,280 dated documents (0.16%) predate 1861.**

## 3. The pre-1861 tail is not early coverage

```sql
SELECT c.volume_id, COUNT(*), MIN(d.date_iso), MAX(d.date_iso)
FROM document_cache c JOIN document_dates d USING (volume_id, document_id)
WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso < '1861-01-01'
GROUP BY 1 ORDER BY 2 DESC;
```
`frus1872p2v1` 244 (1811-07-18 → 1860-06-24) · `frus1872p2v5` 102 (1620-11-03 → 1859-12-31) ·
`frus1894app2` 43 · `frus1902app2` 32 · `frus1872p2v2` 23 · `frus1873p1v2` 16 · `frus1873p2v3` 5 ·
then eleven volumes with 1–2 documents each.

Every one of these is a **retrospective appendix inside a later annual volume** — the 1872 Part 2
arbitration papers and the 1894/1902 appendix volumes, which reprint precedent documents. Within
`frus1872p2v5` the decade profile is 1840s 65 · 1870s 59 · 1850s 12 · 1820s 6 · 1800s 5 · 1790s 5
· 1620s 3 · …, i.e. a case file, not a chronological volume. **The series' own coverage begins in
1861 and the 474 earlier documents should never be read as evidence that it reaches back further.**

## 4. Per-year shape

Same query grouped by year. Selected values (full run is in the session):

- **1861–1868 Civil War ramp**: 387 · 896 · 1,459 · 1,991 · **2,766 (1865)** · 1,361 · 1,165 · 975
- **1869–1892 trough**: never above 1,082; the low is 359 (1876) and 374 (1889)
- **1893–1913 recovery**: 1,161 · 1,409 · 1,388 … 1,323 (1906) … 1,204 (1911) · 1,803 (1912) · 1,500
- **1914–1919 First World War**: 3,310 · 3,889 · 2,989 · 4,564 · **5,903 (1918)** · 4,185
- **1920s trough**: 2,549 → 1,381 (1924) → back to 2,894 (1929)
- **1930s climb**: 2,255 (1930) → 4,930 (1939)
- **1940–1954 the mass of the corpus**: 5,413 · 6,484 · 5,593 · 7,664 · 8,672 · **11,410 (1945)** ·
  7,951 · 6,365 · 6,998 · 7,493 · 5,094 · 6,658 · 3,741 · 4,356 · 6,269
- **1955–1980 plateau**: 2,106 (1966) to 3,831 (1955); mostly 2,000–3,100
- **1981–1991 cliff**: 475 · 833 · 427 · 486 · 522 · 465 · 486 · 393 · 63 · 116 · 61

Top single years across the whole corpus: **1945 (11,410)**, 1944 (8,672), 1946 (7,951),
1943 (7,664), 1949 (7,493), 1948 (6,998), 1951 (6,658), 1941 (6,484), 1947 (6,365), 1954 (6,269),
**1918 (5,903)**.

## 5. Concentration

```sql
-- period bands over the 305,280 dated in-scope documents
```
| band | documents | of 305,280 | per coverage year |
|---|---|---|---|
| before 1861 | 474 | 0.16% | — (appendix material) |
| 1861–1899 | 33,220 | 10.9% | ~852 |
| 1900–1929 | 60,016 | 19.7% | ~2,001 |
| 1930–1959 | 155,535 | 50.9% | ~5,185 |
| 1960–1980 | 51,708 | 16.9% | ~2,462 |
| after 1980 | 4,327 | 1.4% | ~393 |

**The single sharpest fact: 109,773 of 305,280 dated documents (36.0%) fall in the seventeen years
1938–1954.** Five per cent of the series' 130-year span carries over a third of its documents.

## 6. Is the shape about volume count or about volume thickness? — both

Assigning each volume to its modal decade:

```sql
-- modal decade per volume, then volumes and mean documents per volume
```
| modal decade | volumes | documents | mean docs/volume |
|---|---|---|---|
| 1840 | 1 | 163 | 163 |
| 1860 | 20 | 11,382 | 569 |
| 1870 | 17 | 5,676 | 333 |
| 1880 | 11 | 6,478 | 588 |
| 1890 | 15 | 9,894 | 659 |
| 1900 | 14 | 9,714 | 693 |
| 1910 | 40 | 30,477 | 761 |
| 1920 | 24 | 19,796 | 824 |
| 1930 | 47 | 39,376 | **837** |
| 1940 | 91 | 74,006 | 813 |
| 1950 | 97 | 44,041 | 454 |
| 1960 | 67 | 23,669 | 353 |
| 1970 | 91 | 25,648 | **281** |
| 1980 | 14 | 4,721 | 337 |
| 1990 | 1 | 239 | 239 |

Two independent movements. **Volume count** rises steadily to a 1950s/1960s peak (97, 121 touched)
and the modern era gets *more* books. **Documents per volume** peaks in the 1930s (837) and falls
by two-thirds by the 1970s (281). The 1940s are the only decade where both are high at once, which
is why that bucket is nearly twice its nearest rival.

## 7. Text mass, and why document counts alone mislead

```sql
SELECT (CAST(substr(d.date_iso,1,4) AS INTEGER)/10)*10 AS decade, COUNT(*),
       SUM(LENGTH(c.body_text)), CAST(AVG(LENGTH(c.body_text)) AS INT) ...
```
| decade | docs | mean chars/doc | share of corpus text |
|---|---|---|---|
| 1860 | 11,238 | 4,559 | 3.9% |
| 1870 | 5,798 | 8,037 | 3.6% |
| 1880 | 6,472 | 5,436 | 2.7% |
| 1890 | 9,712 | 3,719 | 2.8% |
| 1900 | 9,924 | 3,494 | 2.7% |
| 1910 | 30,359 | 2,806 | 6.5% |
| 1920 | 19,733 | 2,749 | 4.2% |
| 1930 | 39,196 | 2,575 | 7.7% |
| 1940 | 74,043 | 3,297 | 18.7% |
| 1950 | 42,296 | 5,428 | 17.6% |
| 1960 | 27,650 | 5,830 | 12.3% |
| 1970 | 22,259 | 7,892 | 13.4% |
| 1980 | 5,949 | 8,124 | 3.7% |

The mean document length is U-shaped: long in the 1870s, shortest in the 1930s, long again from
the 1950s on. By *text*, the 1950s (17.6%) nearly equal the 1940s (18.7%) despite holding 43%
fewer documents, and the 1970s (13.4%) beat the 1960s.

**Caveat, and it is a real one: `body_text` includes editorial footnotes.** The rise in mean length
after 1945 is partly heavier annotation, not longer documents. This index cannot separate the two —
that is a TEI question, and I have not answered it here.

## 8. The apparatus is a modern invention

```sql
SELECT (CAST(substr(d.date_iso,1,4) AS INTEGER)/10)*10 AS decade,
       SUM(c.is_editorial_note), SUM(CASE WHEN c.is_front_matter=0 THEN 1 ELSE 0 END) ...
```
Dated editorial notes by decade: 1860s–1890s **0** · 1900s 1 · 1910s 11 · 1920s 0 · 1930s 1 ·
1940s 1,637 · **1950s 3,835 (8.3% of dated non-front-matter items)** · 1960s 2,167 (7.3%) ·
1970s 623 (2.7%) · 1980s 174 (2.8%).

The editors' summarising note — the device that stands in for documents they could not print —
does not exist in this corpus before the Second World War and is at its heaviest in the 1950s.

## 9. The post-1980 cliff is a publication frontier, not an editorial judgement

From the bundled `manifest.json` (552 entries), volumes per late subseries:

| subseries | volumes in the series |
|---|---|
| 1969-76 | 66 |
| 1977-80 | 27 |
| 1981-88 | 12 |
| 1989-92 | 1 |

Only one volume in this whole corpus holds documents dated 1990 or later:

```sql
SELECT c.volume_id, COUNT(*), MIN(d.date_iso), MAX(d.date_iso)
FROM document_cache c JOIN document_dates d USING (volume_id, document_id)
WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso >= '1990-01-01'
GROUP BY 1;
-- frus1989-92v31 | 177 | 1990-01-04 | 1991-11-20
```

Twelve books for 1981–88 against 66 for 1969–76 is a publishing programme in progress, not a
decision that the 1980s mattered less. **Any reading of the 1980s and 1990s buckets as
"editorial priority" is wrong**; they measure how far the Office of the Historian has got.

(A related trap I avoided: the latest dates in the raw table run to 2024-03-01, but every
post-1992 row is an "About the Series" or "Press Release" item — `is_front_matter = 1` — and the
exclusion removes all of them.)

## 10. What the shape suggests about editorial priorities

1. **The series is a war-and-aftermath publication.** Every peak is a war or a peace settlement:
   1865 (2,766), 1918 (5,903), 1945 (11,410). The 1938–1954 block alone is 109,773 of 305,280
   dated documents — 36.0% of the corpus for 13% of its span.
2. **Two long troughs mark the periods the editors treated as routine**: 1869–1892 (never above
   1,082 documents in a year, low of 359 in 1876) and 1920–1926 (1,381 in 1924). Peacetime
   commercial and consular diplomacy is printed thinly.
3. **The editorial unit changed around 1950.** Before it, a volume is a thick annual gathering of
   many short despatches (837 documents/volume in the 1930s, 2,575 characters each). After it, a
   volume is a thinner topical or regional selection of longer items (281 documents/volume in the
   1970s, 7,892 characters each). The series stopped trying to print the year's traffic and
   started printing a curated argument about a policy problem — the editorial-note counts in §8
   are the same shift seen from another angle.
4. **Coverage begins in 1861 and effectively stops in 1980.** The 474 earlier documents are
   appendices to arbitration cases; the 4,327 later ones are the leading edge of a subseries with
   12 of its volumes out.
5. **Document counts and text mass rank the eras differently.** By count the 1940s dominate
   (74,043); by text the 1940s and 1950s are near-equal (18.7% vs 17.6%). Any claim about "how
   much the series says" about a period should state which of the two it means.

## Caveats carried forward

- All figures are from this local index (552 volumes, complete at the volume level), with front
  matter, editorial notes and two duplicate second editions excluded; the dated denominator is
  305,280.
- `body_text` blends document prose with editorial footnotes; §7's length figures inherit that.
- 1,339 in-scope documents are undated and appear in no decade.
- The archival question — which record groups these documents came out of, and which the
  footnotes point at — is not addressed here. It is a JSON-surface question and belongs to a
  scoping pass, not to a chronological profile.
