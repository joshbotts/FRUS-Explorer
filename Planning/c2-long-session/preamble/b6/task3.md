# Task 3 — How the 552 volumes are organised as a publication

Sources: `manifest.json` from the installed app bundle (552 records: volumeId, subseries,
title, editors, publicationDate, dateRange, sizeBytes, tags), cross-checked against the
document counts in `frus-copy.db` and the TEI filenames in
`/Users/jbotts/Development/frus/volumes/`.

All 552 records have `status: published`. Total 3.3 GB of TEI, 316,839 indexed documents,
median volume 5.8 MB / 574 documents (range 31 to 1,945 documents).

## 1. The organising unit is the *subseries*, and there are 107 of them

A subseries is the block of years a set of volumes is issued under. The manifest carries
107 distinct labels. Their shape changes fundamentally partway through the series:

- **290 volumes belong to single-year subseries** (`1861`, `1894`, `1930`, `1951`…)
- **262 belong to multi-year subseries** (`1952-54`, `1969-76`, `1981-88`…)

The transition is at 1952. Every year from 1861 to 1951 has its own subseries; from 1952
onward the series is issued in blocks aligned to presidential terms:

| subseries | volumes | years covered | volumes per covered year |
|---|---|---|---|
| 1861–1913 (annual) | 82 | 52 | 1.6 |
| 1914–1951 (annual) | 208 | 38 | 5.5 |
| 1952–54 | 28 | 3 | 9.3 |
| 1955–57 | 29 | 3 | 9.7 |
| 1958–60 | 23 | 3 | 7.7 |
| 1961–63 | 27 | 3 | 9.0 |
| 1964–68 | 35 | 5 | 7.0 |
| **1969–76** | **66** | 8 | 8.2 |
| 1977–80 | 27 | 4 | 6.8 |
| 1981–88 | 12 | 8 | **1.5** (incomplete) |
| 1989–92 | 1 | 4 | **0.2** (just begun) |

The three columns account for all 552: 82 volumes in single-year subseries up to 1913,
208 in single-year subseries 1914–1951, and 262 in multi-year subseries — of which 248 are
the term blocks above and **14 belong to 8 retrospective/thematic subseries** compiled
decades after the fact and sitting chronologically inside territory another subseries
already covers: `1914-20`, `1917-72` (Public Diplomacy, 4 volumes), `1931-41`, `1933-39`,
`1941-43`, `1945-50` (Intelligence), `1950-55` (Intelligence), `1951-54` (Iran, 2 volumes —
a first and a second edition). A ninth retrospective, `frus1952-54Guat` (Guatemala), is
filed inside the ordinary `1952-54` subseries.

Within the annual run the growth is steep and steady: 1–2 volumes a year through 1913,
2–3 a year in the 1920s, 5 a year in the mid-1930s, 7–12 a year for 1941–1951 (1945 alone
runs to 12 volumes, 1919 to 16).

## 2. What a "volume" is called, and the five kinds

Volume ids encode the structure:

| pattern | n | example |
|---|---|---|
| `frusYYYYvNN` — numbered volume in a subseries | 341 | `frus1964-68v20` |
| named / thematic | 99 | `frus1945Berlinv01`, `frus1943CairoTehran`, `frus1951-54Iran` |
| bare year — the whole year is one volume | 47 | `frus1883` |
| `pN` — a volume split into physical parts | 26 (+8 `pNvNN`) | `frus1952-54v06p1` |
| `veNN` — **electronic-only volume** | 22 | `frus1969-76ve07` |
| `Supp` — wartime supplement | 9 | `frus1917Supp02v01` |

Three special categories are worth naming because they change what a "volume" means:

- **22 e-volumes** (`ve01`…), all in the 1969–76 subseries — published online only, never
  printed.
- **5 microfiche supplements** (`frus1958-60v03mSupp`, `frus1961-63v10-12mSupp`, …) — the
  overflow documents that would not fit the printed book.
- **3 second editions**: `frus1951-54IranEd2`, `frus1977-80v09Ed2`, `frus1969-76ve15p2Ed2`.
  The Iran second edition (2018) re-does a 1989 compilation, so the corpus contains two
  different editorial treatments of the same years.

The series title itself changes twice. The 1861 volume is titled *Message of the President
of the United States…*; 18 Civil War volumes are *Papers Relating to Foreign Affairs*;
124 are *Papers Relating to the Foreign Relations of the United States*; and 409 —
everything from the 1930s–40s onward — are simply *Foreign Relations of the United States*.

## 3. From chronology to topic

The early volumes are undifferentiated: `frus1930v01/v02/v03` are titled *Papers Relating to
the Foreign Relations of the United States, 1930, Volume I/II/III* and nothing more — the
year's correspondence, split for length, ordered by country. The modern volumes are
compilations with subjects:

```
frus1969-76v01  Foundations of Foreign Policy, 1969–1972
frus1969-76v03  Foreign Economic Policy; International Monetary Policy
frus1969-76v05  United Nations, 1969–1972
frus1969-76v06  Vietnam, January 1969–July 1970
frus1969-76v07  Vietnam, July 1970–January 1972
```

486 of 552 volumes carry a topical or geographic subtitle. The 1969–76 subseries devotes
five consecutive volumes to Vietnam alone, sliced by date. The manifest's per-volume tag
lists (438 distinct tags, median 35 per volume, up to 154) reflect the same shift.

Editorial attribution follows the same arc: **81 volumes list no editor at all** (the
19th-century congressional submissions), 220 list one, and modern volumes list up to nine.

## 4. Spread of coverage years

Nominal coverage runs **1861 to 1992**. Actual document dates run much wider, because
volumes print older evidence as annex material (see Task 1: the 1872 Alabama Claims volume
reaches back to 1620).

Measured against each volume's own nominal subseries years:

- **289 of 552 volumes (52%) contain documents dated earlier than their nominal start**
- **264 of 552 (48%) contain documents dated later than their nominal end**
- Median content span is **4 years**; mean 6.0; distribution: 38 volumes span 1 year,
  78 span 2, 147 span 3, 86 span 4, 82 span 5, and a tail beyond.

Biggest reaches backward: `frus1872p2v5` (252 years), `frus1902app2` (205),
`frus1902app1` (82) — all arbitration case files. Biggest forward: `frus1952-54Guat`
(+21 years, running to 1975), `frus1945Berlinv02` (+15, to 1960).

So a volume's label is a *filing convention*, not a boundary. Any query that trusts the
subseries label to bound its documents will lose about half the corpus's edge cases.

## 5. The gap between coverage and printing

This is the sharpest structural fact about FRUS as a publication. Publication dates in this
snapshot run **1861 to 2025**. Lag = publication year − nominal coverage end year:

- **minimum 0, maximum 64, mean 23.5, median 27 years.** No volume is ever published before
  the year it covers.

By coverage decade:

| coverage ends in | volumes | median lag | range |
|---|---|---|---|
| 1860s | 19 | **1 yr** | 0–2 |
| 1870s | 19 | 0 | 0–1 |
| 1880s | 11 | 1 | 0–1 |
| 1890s | 14 | 1 | 1–3 |
| 1900s | 15 | 1 | 1–5 |
| 1910s | 37 | **15** | 5–28 |
| 1920s | 26 | 15 | 14–20 |
| 1930s | 46 | 17 | 13–19 |
| 1940s | 91 | 23 | 2–29 |
| 1950s | 79 | **31** | 25–64 |
| 1960s | 85 | 32 | 24–58 |
| 1970s | 70 | 34 | 25–46 |
| 1980s | 39 | **36** | 27–45 |

The series began as a **current-year document**: the 1861–1905 volumes were transmitted to
Congress with the President's annual message, essentially contemporaneously. The lag then
grows monotonically — about 15 years for the 1910s–30s, 23 for the 1940s, and settles at
**30-something years from the 1950s onward**, hovering just above the thirty-year standard
that governs the modern series. Distribution of all 552 lags: 79 volumes under 5 years,
9 at 5–9, 105 at 10–19, 134 at 20–29, **207 at 30–39**, 14 at 40–49, 4 at 50+.

The extreme lags are all retrospective compilations: `frus1951-54IranEd2` (64 years),
`frus1951-54Iran` (63), `frus1961-63v10-12mSupp` (58), `frus1950-55Intel` (52),
`frus1952-54Guat` (49) — volumes about covert operations, released long after the events.

**A subseries is not published at once.** Its volumes trickle out over decades:

| subseries | volumes | published across |
|---|---|---|
| 1943 | 9 | 1957–1970 (13 yrs) |
| 1945 | 12 | 1955–1969 (14 yrs) |
| 1952–54 | 28 | 1979–2003 (24 yrs) |
| 1961–63 | 27 | 1988–2021 (33 yrs) |
| 1964–68 | 35 | 1992–2013 (21 yrs) |
| 1969–76 | 66 | 2001–2021 (20 yrs) |
| 1977–80 | 27 | 2013–2025 (12 yrs) |

## 6. What this means for reading the corpus

1. **The publication is still in progress and the corpus is a snapshot.** 136 of the 552
   volumes (25%) were published in 2000 or later; 68 in the 2010s and 14 already in the
   2020s. The 1981–88 subseries has 12 volumes where 1969–76 has 66, and 1989–92 has one.
   Thinness at the recent end is a publication schedule, not an editorial verdict.
2. **The organising principle changed twice** — from annual congressional submission
   (1861–1951, contemporaneous, undifferentiated by subject) to term-block thematic
   compilation (1952– , thirty years late, organised by region and issue). Comparisons
   across that boundary compare two different publications wearing one name.
3. **Volume boundaries are soft.** Half the volumes hold documents outside their nominal
   years, and 14 subseries are retrospective compilations that sit chronologically inside
   territory another subseries already covers — including two editions of the same Iran
   compilation. Deduplicating or bounding by subseries alone will misfile documents.
4. **"Volume" covers five different physical objects**: a printed book, one part of a
   split book, an electronic-only volume, a microfiche supplement, and a second edition.
