# Task 3 — How the 552 volumes are organised as a publication

## Coverage statement

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
```
→ **552 volumes**, 316,839 rows, 1,012 front matter, 8,468 editorial notes. The full series is here.

## Surfaces used

Publication metadata — subseries, coverage `dateRange`, `publicationDate`, `title`, `editors`,
`sizeBytes`, `status` — is **[JSON]**, from the bundled manifest at
`/Applications/FRUS Explorer.app/Contents/Resources/manifest.json` (552 entries). Coverage years are
cross-checked against `document_dates` in the SQLite index. The two surfaces name the **same 552
volumes**, verified:

```python
mv = {entry['volumeId'] for entry in manifest}          # 552
dbv = {row[0] for row in db.execute('SELECT DISTINCT volume_id FROM document_cache')}  # 552
mv == dbv    # True — symmetric difference empty in both directions
```

Second editions `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2` are suppressed (their first editions
are present); `frus1977-80v09Ed2` is kept. **550 volumes** in every figure below unless stated.

`status` is `published` for all 552 — the manifest carries no forthcoming volumes, so nothing here
can speak to what is planned but unprinted.

## 1. Subseries: 107 of them, and they change kind halfway through

```python
collections.Counter(v['subseries'] for v in manifest)   # 107 distinct labels
```

The label is a coverage period, and its *form* is the structural story. 90 subseries are labelled
with a single year; 17 with a span.

| group | volumes | subseries | median publication lag | published across | median volume size |
|---|---|---|---|---|---|
| annual, 1861–1905 | 72 | 44 | **1 year** | 1861–1906 | 5.98 MB |
| annual, 1906–1930 | 70 | 25 | 15 years | 1909–1947 | 5.76 MB |
| annual, 1931–1951 | 148 | 21 | 22 years | 1946–1985 | 6.20 MB |
| multi-year subseries | 260 | 17 | **33 years** | 1939–2025 | 5.59 MB |

The annual subseries run **1861 through 1951**. Every subseries from **1952–54** onward covers
several years. That is the single structural break in the publication: FRUS stops being an annual
and becomes an administration-scale retrospective edition. The seventeen multi-year subseries:

| subseries | volumes | published |
|---|---|---|
| 1914-20 | 2 | — |
| 1917-72 (Public Diplomacy) | 4 | 2014–2018 |
| 1931-41 | 2 | — |
| 1933-39 | 1 | — |
| 1941-43 | 1 | — |
| 1945-50 (Intelligence) | 1 | 1996 |
| 1950-55 (Intelligence) | 1 | 2007 |
| 1951-54 (Iran) | 1 | 2017 |
| **1952-54** | 28 | 1979–2003 |
| **1955-57** | 29 | 1985–1993 |
| **1958-60** | 23 | 1986–1998 |
| **1961-63** | 27 | 1988–2021 |
| **1964-68** | 35 | 1992–2013 |
| **1969-76** | **66 (65 after Ed2)** | 2001–2019 |
| **1977-80** | 27 | 2013–2025 |
| **1981-88** | 12 | 2015–2025 |
| 1989-92 | 1 | 2025 |

The nine bolded ones are the modern presidential/administration subseries and they hold 247 of the
550 volumes — **45% of the whole series covers the 36 years 1952–1988**.

Volumes per year of coverage, which is the honest density measure once the subseries stop being
annual:

| subseries | years covered | volumes | volumes per covered year |
|---|---|---|---|
| 1861 | 1 | 1 | 1.0 |
| 1875 | 1 | 2 | 2.0 |
| 1900 | 1 | 1 | 1.0 |
| 1917 | 1 | 4 | 4.0 |
| 1919 | 1 | 16 | 16.0 |
| 1932 | 1 | 5 | 5.0 |
| 1941 | 1 | 7 | 7.0 |
| 1945 | 1 | 12 | 12.0 |
| 1948 | 1 | 11 | 11.0 |
| 1951 | 1 | 11 | 11.0 |
| 1952-54 | 3 | 28 | 9.3 |
| 1955-57 | 3 | 29 | 9.7 |
| 1958-60 | 3 | 23 | 7.7 |
| 1961-63 | 3 | 27 | 9.0 |
| 1964-68 | 5 | 35 | 7.0 |
| 1969-76 | 8 | 65 | 8.1 |
| 1977-80 | 4 | 27 | 6.8 |
| 1981-88 | 8 | 12 | **1.5 (incomplete)** |
| 1989-92 | 4 | 1 | **0.2 (incomplete)** |

One volume a year in 1861; sixteen for 1919 alone; twelve for 1945; then a plateau at seven to ten
per covered year that has held from 1952 to 1980. The 1981-88 and 1989-92 figures are not a
policy change — those subseries are still being published, and Task 1's document counts show the
same cliff.

## 2. The physical shape

- **Total 3,326 MB of TEI** across 550 volumes; median volume 5.82 MB, smallest 0.53 MB, largest
  13.14 MB. Volume size is remarkably flat across 164 years — the median barely moves between the
  1861–1905 annuals (5.98 MB) and the modern subseries (5.59 MB). A FRUS volume has been about the
  same physical object throughout; what changed is how many of them cover a given year and how many
  documents fit inside one (Task 1: 388 documents per volume in the 1860s, 145 in the 1980s).

- **Volume identifiers encode the internal divisions.** Stripping the year prefix and normalising
  digits:

  `v#` 341 · `v#p#` 53 · *(bare, single-volume year)* 47 · `p#` 26 · `Parisv#` 13 · **`ve#` 11** ·
  **`ve#p#` 10** · `p#v#` 8 · `Supp#v#` 5 · `app#` 4 · `PubDipv#` 3 · `Russiav#` 3 · `v#mSupp` 3 ·
  `Intel` 2 · `Berlinv#` 2 · plus singletons `China`, `Nicaragua`, `CairoTehran`, `Quebec`, `Supp`,
  `app`, `Russia`, `PubDip`.

  **21 volumes are electronic-only** (`ve#`, `ve#p#`) — a publication form that exists only in the
  1969-76 and later subseries.

- **33 volumes are named rather than numbered** — thematic or conference volumes standing outside
  the numbered run: the 13 Paris Peace Conference volumes (1919, published 1942–1947), 4 Russia
  volumes (1918–1919), the Berlin/Potsdam pair (1945, published 1960), Malta and Yalta (1945, 1955),
  Cairo and Tehran (1943, published 1961), Quebec (1944, published 1972), three China volumes (1901,
  1942, 1943), Nicaragua (1894, published 1895), two Intelligence retrospectives (1996, 2007), the
  four-volume Public Diplomacy series (2014–2018), and the Iran retrospective (2017).

- **Editorial attribution is partial.** 416 of 550 volumes name a `generalEditor`; 23 distinct
  people hold them. Tyler Dennett 66 · Edward C. Keefer 54 · John P. Glennon 50 · Adam M. Howard 48 ·
  David S. Patterson 37 · Glenn W. LaFantasie 34 · Gustave A. Nuermberger 33 · S. Everett Gleason 25 ·
  William Z. Slany 21 · Kathleen B. Rasmussen 12. The 134 volumes with no general editor are the
  early annuals, which were compiled as congressional documents rather than edited historical
  editions.

## 3. The spread of coverage years

Each volume's coverage core is taken as the 5th–95th percentile of its documents' `date_iso`
(apparatus and Ed2 excluded), which is robust to the reprinted-exhibit strays Task 1 identified:

```sql
SELECT dc.volume_id, CAST(substr(dd.date_iso,1,4) AS INT)
FROM document_cache dc JOIN document_dates dd USING(volume_id,document_id)
WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dd.date_iso IS NOT NULL;
```

**Volumes are chronologically tight.** Median core span is **1 year**; mean 2.1. 201 of 550 volumes
have a core span of 0 years (all their documents in one calendar year), 120 span 2 years, 102 span
3, 75 span 4. Only a handful reach beyond 7, and the maximum (130 years) is `frus1872p2v5`, the
Geneva arbitration appendix that reprints documents back to 1620.

**Coverage is continuous.** Every calendar year from **1861 to 1991** is inside the core span of at
least one volume. The only year in that range with none is 1992. Thinnest years: 1989, 1990 and 1991
with one volume each (all `frus1989-92v31`); then 1913 with 2; then 1903, 1904, 1908, 1909, 1910,
1912, 1921, 1925 with 3 apiece. Thickest: **1971 and 1972 with 35 volumes each**, 1970 with 34, 1973
with 31, 1967 and 1969 with 30.

So the series covers 131 consecutive years, but a reader of 1971 has thirty-five volumes to work
through and a reader of 1913 has two.

## 4. The gap between covering and printing

Three definitions of the lag, all computed over the same 550 volumes:

| definition | min | p25 | median | p75 | max | mean |
|---|---|---|---|---|---|---|
| publication year − manifest `dateRange.latest` | −4 | 14 | **27** | 33 | 95 | 23.1 |
| publication year − 95th pct of document years | 0 | 15 | **27** | 33 | 96 | 23.9 |
| publication year − subseries end year | 0 | 15 | **27** | 36 | 101 | 25.7 |

All three give a median of **27 years**. The first produces impossible negatives (`frus1915` has a
`dateRange.latest` of 1928 against a 1924 publication — a stray document date, exactly the
contamination Task 1 found), so the percentile definition is used below.

**The lag is not a constant. It grew by a factor of thirty-seven.**

| publication decade | volumes published | median lag | coverage reached |
|---|---|---|---|
| 1860s | 19 | **1** | 1861–1868 |
| 1870s | 19 | **0** | 1869–1879 |
| 1880s | 10 | 1 | 1880–1888 |
| 1890s | 13 | 1 | 1889–1897 |
| 1900s | 13 | 1 | 1898–1906 |
| 1910s | 7 | 5 | 1907–1912 |
| 1920s | 8 | 9 | 1913–1917 |
| 1930s | 25 | 15 | 1917–1924 |
| 1940s | 42 | 15 | 1918–1941 |
| 1950s | 46 | 17 | 1933–1945 |
| 1960s | 38 | 22 | 1940–1946 |
| 1970s | 49 | 26 | 1943–1954 |
| 1980s | 54 | 31 | 1950–1961 |
| 1990s | **73** | 32 | 1949–1968 |
| 2000s | 54 | 33.5 | 1954–1976 |
| 2010s | 67 | **37** | 1918–1988 |
| 2020s (to 2025) | 13 | 36 | 1963–1991 |

Seen from the other side — by what the volume covers rather than when it was printed — the same
curve:

| coverage decade | volumes | median lag | min | max |
|---|---|---|---|---|
| 1860 | 20 | 1 | 0 | 3 |
| 1870 | 18 | 0 | 0 | 1 |
| 1880 | 11 | 1 | 0 | 1 |
| 1890 | 14 | 1 | 0 | 3 |
| 1900 | 15 | 1 | 1 | 5 |
| 1910 | 39 | 15 | 5 | 96 |
| 1920 | 25 | 15 | 14 | 26 |
| 1930 | 46 | 17 | 13 | 19 |
| 1940 | 92 | 23 | 2 | 47 |
| 1950 | 79 | 31 | 25 | 63 |
| 1960 | 85 | 32 | 26 | 58 |
| 1970 | 67 | 36 | 29 | 46 |
| 1980 | 38 | 36 | 28 | 45 |

**What this says about the publication.** For its first forty-five years FRUS was a *current
government document*: the President's annual message with the accompanying diplomatic
correspondence, laid before Congress in the same or the following year. Nineteen volumes appear in
the 1870s at a median lag of **zero**. That is not a historical edition; it is a report.

The lag begins to open in the 1910s (5 years), doubles in the 1920s (9), and reaches 15 by the
1930s. From there it climbs steadily and has never reversed: 22 in the 1960s, 31 in the 1980s, 37 in
the 2010s. Year by year since 2000 the frontier is flat rather than closing —

2000: 32 · 2004: 36 · 2008: 34 · 2011: 37 · 2014: 38 · 2015: 39 · 2017: 40.5 · 2019: 41 · 2021: 36 ·
2024: 36 · 2025: 37.

The series has settled at a **34-to-40-year** remove and shows no movement back toward the 30-year
standard it is held to. The most recent volume in the manifest covers 1989–1991 and was published in
2025.

**The longest lags are the retrospectives**, and they are a different kind of object: the
Public Diplomacy volume `frus1917-72PubDip` covers 1917–1919 and was published in **2014** — a lag of
96 years. `frus1951-54Iran` (2017, lag 63), `frus1961-63v10-12mSupp` (2021, lag 58),
`frus1950-55Intel` (2007, lag 51), `frus1945-50Intel` (1996, lag 46). These are declassification
supplements and thematic reopenings of periods the series had already covered, not first passes.
Any lag statistic that treats them as ordinary volumes overstates the tail — they are the reason the
2010s row shows a coverage range beginning at 1918.

## 5. Three shapes in one publication

1. **1861–c.1906, an annual congressional report.** 72 volumes, 44 annual subseries, one or two
   volumes a year, printed within a year of the events. Median lag 1.
2. **c.1906–1951, a transitional annual historical edition.** 218 volumes across 46 annual
   subseries, growing to 11–16 volumes per covered year for 1919, 1945, 1948 and 1951, printed at a
   15-to-22-year remove.
3. **1952–present, a multi-year retrospective edition.** 260 volumes in 17 subseries organised by
   administration, 7–10 volumes per covered year, printed at a 33-year median remove, with
   21 volumes published electronically only and 33 named thematic or conference volumes standing
   outside the numbered run.

## What this cannot answer

- Nothing about volumes **planned or in preparation**: `status` is `published` for all 552, so the
  under-published 1981–88 and 1989–92 subseries look thin here and I cannot say how thin they
  really are.
- The 1980s and 1990s figures are a **snapshot of an unfinished publication**, not an editorial
  judgement, and no query in this session can distinguish the two.
- Publication dates are years, not months, so intra-year sequencing is unavailable.
- 134 of 550 volumes carry no `generalEditor`, so editor-based analysis is a 416-volume analysis.
- **Archival channel not consulted.** This describes how FRUS was assembled and printed, not the
  archives it was drawn from. The came-from and pointed-at channels ([JSON]:
  `collection-usage-index.json`, `external-citation-index.json`) would answer that, and would need
  to be reported separately and never summed with anything here.
