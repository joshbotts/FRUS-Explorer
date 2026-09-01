# Task 3 — How the 552 volumes are organised as a publication

## 0. Coverage statement

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 volumes | 316,839 documents | 1,012 front matter | 8,468 editorial notes
```
All 552 volumes are present, and the bundled `manifest.json` also holds exactly 552 entries, so the
publication-level questions below are answered over the complete set. Document counts still exclude
front matter, editorial notes and the two duplicate second editions (550 volumes, 306,619
documents).

**Surfaces used.** Subseries, titles, publication dates and coverage ranges come from the bundled
`manifest.json` [JSON]. Document counts and per-year coverage come from the index. Printed page
extents come from the index's `page_ranges` table. `manifest.json`'s own `documentCount` field is
**0 for all 552 entries** and is unusable:

```python
sum(1 for v in manifest if v['documentCount'])   # -> 0
```

## 1. Two publication regimes, and a small third

Parsing each entry's `subseries` field gives 107 distinct subseries:

| regime | volumes | subseries | nominal span |
|---|---|---|---|
| **annual** (one subseries per calendar year) | 290 | 90 | 1861–1951 |
| **administration** (multi-year presidential blocks) | 248 | 9 | 1952–1992 |
| **special / retrospective** | 14 | 8 | 1914–1972 |

The break is sharp and dated: **the last annual subseries is 1951; the first administration block
is 1952-54.** Everything printed for events after 1951 is organised by presidency, not by year.

The nine administration blocks:

| subseries | volumes | years covered | volumes per covered year |
|---|---|---|---|
| 1952-54 | 28 | 3 | 9.33 |
| 1955-57 | 29 | 3 | 9.67 |
| 1958-60 | 23 | 3 | 7.67 |
| 1961-63 | 27 | 3 | 9.00 |
| 1964-68 | 35 | 5 | 7.00 |
| 1969-76 | 66 | 8 | 8.12 |
| 1977-80 | 27 | 4 | 6.75 |
| 1981-88 | **12** | 8 | **1.50** |
| 1989-92 | **1** | 4 | **0.25** |

(Counts exclude the two duplicate second editions; 1969-76 is 66 in the manifest, 65 after the
`ve15p2Ed2` drop.)

The eight special subseries, with their titles from the manifest:

| id | printed | title |
|---|---|---|
| `frus1914-20v01/v02` | 1939, 1940 | The Lansing Papers, 1914–1920 |
| `frus1931-41v01/v02` | 1943 | Japan, 1931–1941 |
| `frus1933-39` | 1952 | The Soviet Union, 1933–1939 |
| `frus1941-43` | 1958 | The Conferences at Washington, 1941–1942, and Casablanca |
| `frus1945-50Intel` | 1996 | Emergence of the Intelligence Establishment |
| `frus1950-55Intel` | 2007 | The Intelligence Community, 1950–1955 |
| `frus1951-54Iran` (+ Ed2) | 2017, 2018 | Iran, 1951–1954 |
| `frus1917-72PubDip` ×4 | 2014–2018 | Public Diplomacy, 1917–1972 |

These are retrospective repairs: subjects the series had covered inadequately at the time
(intelligence, covert action in Iran, public diplomacy) reopened decades later.

## 2. Volume format census

```python
# regex over the 552 volumeIds
```
| form | count |
|---|---|
| multi-part volumes (`…pN`) | 108, in 46 parent stems (38 stems of 2 parts, 2 of 3, 2 of 4) |
| electronic-only volumes (`…vE…`) | 22 |
| microfiche supplements (`…mSupp`) | 5 |
| appendix volumes (`…app…`) | 5 |
| second editions (`…Ed2`) | 3 |
| named / topical volumes (no plain volume number) | 49 |

The 49 named volumes are worth listing by kind, because they mark where the series broke its own
grid: the wartime supplements (`frus1914Supp` … `frus1918Supp02`), the thirteen-volume
`frus1919Paris` Peace Conference set, the summit volumes (`frus1943CairoTehran`, `frus1944Quebec`,
`frus1945Malta`, `frus1945Berlinv01/v02`), the country files (`frus1894Nicaragua`, `frus1901China`,
`frus1918Russiav01–v03`, `frus1919Russia`, `frus1942China`, `frus1943China`, `frus1952-54Guat`,
`frus1951-54Iran`), and the two intelligence retrospectives.

## 3. Spread of coverage years

**The typical volume covers one to four years.** Computed from the index, per volume, over body
documents only, using the years holding the central 90% of the volume's documents:

```sql
SELECT c.volume_id, CAST(substr(d.date_iso,1,4) AS INT) AS yr, COUNT(*)
FROM document_cache c JOIN document_dates d USING (volume_id,document_id)
WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso IS NOT NULL
GROUP BY 1,2;
```
| span (years) | volumes |
|---|---|
| 1 | 200 |
| 2 | 120 |
| 3 | 102 |
| 4 | 75 |
| 5 | 29 |
| 6–8 | 14 |
| 11–21 | 6 |
| 45, 54, 76, 131 | 4 |

Median core span **2 years**, mean 3.1. Raw min-to-max span: median 3, mean 5.8. **200 of 550
volumes put 90% of their documents in a single calendar year.**

The four extreme volumes are the retrospective arbitration appendices, not broad-coverage books:
`frus1902app2` (core span 131 years), `frus1872p2v5` (76; raw 253, back to 1620), `frus1872p2v1`
(54), `frus1894app2` (45).

**Volumes per covered year, across the whole run** (annual era from the manifest's single-year
subseries; administration era from §1):

| covered | volumes | per year |
|---|---|---|
| 1860s | 19 | 1.9 |
| 1870s | 19 | 1.9 |
| 1880s | 11 | 1.1 |
| 1890s | 14 | 1.4 |
| 1900s | 15 | 1.5 |
| 1910s | 37 | 3.7 |
| 1920s | 24 | 2.4 |
| 1930s | 45 | 4.5 |
| 1940s | 88 | 8.8 |
| 1950–51 (annual) | 18 | 9.0 |
| 1952–1980 (administration) | 209 | ~7.2 |
| 1981–1992 (administration) | 13 | ~1.1 |

The series grows from about two volumes per covered year in the 1860s to roughly nine by the 1940s
and holds there through 1980. The 1981-onward figure is the unfinished edge, not a decision.

## 4. The gap between coverage and printing

Lag = publication year − last year of nominal coverage. Over all 552 volumes: **min 0, median 27,
mean 23.5, max 64.**

**By publication decade** — this is the clearest single table in the file:

| printed | volumes | median lag (years) | range |
|---|---|---|---|
| 1860s | 19 | **1** | 0–2 |
| 1870s | 19 | **0** | 0–1 |
| 1880s | 10 | 1 | 0–1 |
| 1890s | 13 | 1 | 1–1 |
| 1900s | 13 | 1 | 1–3 |
| 1910s | 7 | 5 | 3–7 |
| 1920s | 8 | 9 | 7–14 |
| 1930s | 25 | 15 | 12–19 |
| 1940s | 42 | 15 | 2–28 |
| 1950s | 46 | 17 | 10–19 |
| 1960s | 38 | 22 | 15–24 |
| 1970s | 49 | 26 | 24–29 |
| 1980s | 54 | 30.5 | 25–35 |
| 1990s | 73 | 32 | 24–46 |
| 2000s | 54 | 32 | 25–52 |
| 2010s | 68 | 36 | 27–64 |
| 2020s | 14 | **36** | 32–58 |

The lag is monotonic across sixteen decades. **FRUS began as a near-contemporaneous annual
publication of the year's diplomatic correspondence — the 1870s volumes appeared in the year they
covered — and is now a historical edition appearing about 36 years after the events.**

Against the commonly cited 30-year benchmark (I did not retrieve the statute in this session, so
treat 30 as a reference line rather than a quoted requirement):

```
lag <= 5 years:   81 of 552
lag <= 10 years:  89 of 552
lag <= 20 years: 198 of 552
lag <= 25 years: 253 of 552
lag <= 30 years: 352 of 552
lag <= 35 years: 490 of 552
```
Restricted to the 202 volumes printed in 1991 or later: **35 of 202 came out within 30 years of
their coverage; the median lag for that group is 33 years.**

**By administration subseries**, the lag is essentially flat once the modern regime starts, but the
*publication window per block* is enormous:

| subseries | volumes | median lag | lag range | printed across |
|---|---|---|---|---|
| 1952-54 | 28 | 30 | 25–49 | 1979–2003 |
| 1955-57 | 29 | 32 | 28–36 | 1985–1993 |
| 1958-60 | 23 | 33 | 26–38 | 1986–1998 |
| 1961-63 | 27 | 32 | 25–58 | 1988–2021 |
| 1964-68 | 35 | 32 | 24–45 | 1992–2013 |
| 1969-76 | 66 | 34 | 25–45 | 2001–2021 |
| 1977-80 | 27 | 36 | 33–45 | 2013–2025 |
| 1981-88 | 12 | 33 | 27–37 | 2015–2025 |
| 1989-92 | 1 | 33 | 33 | 2025 |

A three-year presidency's documents can take a **24-year publication window** to appear (1961-63,
printed 1988 to 2021). Anyone scoping a subseries should know that its volumes were edited decades
apart under different rules and different declassification regimes.

**The longest lags** (excluding the second editions at 63–64): `frus1961-63v10-12mSupp` 58 years
(printed 2021), `frus1950-55Intel` 52 (2007), `frus1952-54Guat` 49 (2003), `frus1917-72PubDipv07`
and `v08` 46 (2018), `frus1945-50Intel` 46 (1996), `frus1964-68v23` (Congo) 45,
`frus1977-80v27` 45 (2025). Every one is intelligence, covert action, public diplomacy or a
declassification supplement — the categories the series had to come back to.

## 5. A caution about the manifest's coverage ranges

`manifest.json`'s `dateRange` is computed over all divisions including editorial notes, so it can
overstate a volume's coverage. The clean case: `frus1915` is listed as covering 1911–1928 though it
was printed in 1924. The index explains it:

```sql
SELECT document_id, date_iso, date_iso_max, date_precision, date_certainty,
       is_front_matter, is_editorial_note
FROM document_cache c JOIN document_dates d USING (volume_id,document_id)
WHERE volume_id='frus1915' ORDER BY date_iso_max DESC LIMIT 2;
-- d1137 | 1911-09-26 | 1928-10-22 | day | range | 0 | 1   <- an editorial note
-- d1027 | 1915-12-31 | 1915-12-31 | day | exact | 0 | 0
```
One editorial note spanning 1911–1928 widens the whole volume's stated range. **Use the manifest's
dateRange for orientation and the index's body-document dates for anything measured.** Verified the
other way for four volumes where the two agree closely (`frus1969-76v32` 1969-02-13→1972-10-04 in
both; `frus1977-80v04` 1976-07-26→1981-01-15 in both).

## 6. The physical book barely changed; its contents did

Printed extent from `page_ranges` (arabic span per volume, `MAX − MIN + 1`; 549 volumes carry
arabic page data):

```sql
SELECT volume_id, MIN(page_number_int), MAX(page_number_int)
FROM page_ranges WHERE page_number_type='arabic' AND page_number_int IS NOT NULL GROUP BY 1;
```

| covered decade | volumes | median printed pages | total pages |
|---|---|---|---|
| 1860s | 19 | 702 | 13,714 |
| 1870s | 19 | 676 | 12,907 |
| 1880s | 11 | 931 | 9,970 |
| 1890s | 14 | 761 | 11,137 |
| 1900s | 15 | 806 | 11,441 |
| 1910s | 43 | 861 | 36,199 |
| 1920s | 24 | 950 | 22,248 |
| 1930s | 48 | 894 | 42,502 |
| 1940s | 90 | 1,060 | 98,376 |
| 1950s | 100 | 908 | 101,389 |
| 1960s | 127 | 852 | 102,429 |
| 1970s | 26 | 969 | 24,747 |
| 1980s | 13 | 1,195 | 15,670 |

**Series total: 502,729 printed pages over 549 volumes.** The median volume has been between 700
and 1,200 pages for 130 years.

What changed is what fits in those pages:

| regime | volumes | documents | median docs/volume | median pages | documents per page |
|---|---|---|---|---|---|
| annual 1861–1899 | 63 | 33,410 | 529 | 731 | 0.70 |
| annual 1900–1929 | 76 | 59,550 | 822 | 872 | **0.89** |
| annual 1930–1951 | 151 | 122,958 | 811 | 990 | 0.77 |
| administration 1952–1968 | 142 | 55,285 | 359 | 851 | 0.42 |
| administration 1969–1992 | 105 | 30,436 | 297 | 944 | **0.34** |
| special / retrospective | 13 | 4,980 | 358 | 793 | 0.53 |

**Documents per printed page falls by more than half between the annual and administration eras
(0.89 → 0.34).** The book is the same size; the documents inside are longer and carry far heavier
editorial apparatus. (Caveat: page counts are the arabic-numeral span, which includes apparatus
pages, and the index's `body_text` blends document prose with footnotes — so "longer documents" and
"more annotation" cannot be separated on this surface.)

## 7. The editorial apparatus appears with the modern series

`manifest.json` names a general editor on 418 of 552 volumes, and the transition is dated:

| printed | general editor named |
|---|---|
| 1860s–1900s | 0 of 74 |
| 1910s | 1 of 7 |
| 1920s | 7 of 8 |
| 1930s–1950s | 108 of 113 |
| 1960s | 13 of 38 |
| 1970s | 26 of 49 |
| 1980s onward | 263 of 263 |

Median named editors per volume: 0 through the 1910s, 1 in the 1920s–1940s, 4.5 in the 1950s, back
to 1 from the 2000s. Eighty-one volumes name no editor at all — the nineteenth-century books, which
were transmitted to Congress by the President rather than edited by a historical office.

## 8. Summary

1. **Two publications share one name.** An annual congressional document (1861–1951, 290 volumes,
   90 yearly subseries, printed within a year or two of the events) and a scholarly historical
   edition (1952–1992, 248 volumes, 9 presidential blocks, printed about a third of a century
   later). The hinge year is 1951/1952.
2. **A volume is a narrow slice of time.** Median core coverage 2 years; 200 of 550 volumes sit
   inside a single year. The wide-span volumes are arbitration appendices, not surveys.
3. **The publication lag has grown monotonically for sixteen decades**, from 0–1 years in the 1870s
   to a median of 36 in the 2020s, and only 35 of the 202 volumes printed since 1991 came out
   within 30 years of their subject.
4. **A subseries is not a cohort.** The 1961-63 volumes were printed between 1988 and 2021; the
   1969-76 volumes between 2001 and 2021. Comparing volumes inside one block compares different
   editorial and declassification regimes.
5. **The series is unfinished at the front.** 1981-88 has 12 of its volumes out, 1989-92 has 1, and
   both are still appearing (printed 2015–2025).
6. **The physical book is a constant; the editorial density is not.** ~500,000 printed pages, median
   volume 700–1,200 pages throughout, but documents per page have fallen from 0.89 to 0.34.

## Caveats carried forward

- 552 volumes in both the index and the manifest; document counts use 550 (two duplicate second
  editions removed) and exclude front matter and editorial notes.
- `manifest.json`'s `documentCount` is zero everywhere and was not used; its `dateRange` includes
  editorial notes and can overstate a volume's coverage (§5).
- `publicationDate` is a bare year for 551 of 552 entries (`frus1969-76v32` carries a full date);
  all lags are therefore integer years.
- Nominal coverage end comes from the `subseries` string, so a volume whose documents run past its
  block (e.g. `frus1977-80v04`, documents to 1981-01-15) has a slightly understated lag.
- Page extents are the arabic-numeral span and include apparatus pages; 549 of 552 volumes have
  arabic page data, 3 have none.
- The 30-year figure in §4 is used as a reference line; I did not retrieve the governing statute in
  this session.
- **Not addressed here:** which archival units these volumes drew on, and which their footnotes
  point at. That is a JSON-surface question over `collection-usage-index.json` and
  `external-citation-index.json`, and no count in this file speaks to it.
