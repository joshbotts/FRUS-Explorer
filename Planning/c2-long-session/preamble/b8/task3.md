# Task 3 — The 552 volumes as a publication

**Surfaces used:** the bundled JSON (`/Applications/FRUS Explorer.app/Contents/Resources/manifest.json`
— 552 entries, the volume-metadata surface) for subseries, titles, coverage ranges and publication
dates; the SQLite index for cross-checking those ranges against actual document dates. No TEI.

**Cross-surface check first.** The two surfaces name exactly the same 552 volumes — zero on either
side only:
```python
manifest 552 · db 552 · manifest-only [] · db-only []
```
So this is the complete published series as the app defines it, and Task 1's coverage line
(552 volumes, 316,839 documents) applies unchanged.

---

## 1. The series has two publication regimes, and one line in the title separates them

```python
Papers Relating to the Foreign Relations of the United States  : 142 volumes, printed 1862–1947
Foreign Relations of the United States                         : 409 volumes, printed 1895–2025
(other)                                                        :   1  — frus1861, "Message of the
   President of the United States to the Two Houses of Congress…"
```

The first volume is not titled as a series at all. It is a **presidential message to Congress with
the correspondence attached** — which is precisely what FRUS was in 1861 and explains everything in
§4 about lag. The two title forms overlap in print years because appendix and arbitration volumes
carried the shorter form early; the ranges above are as measured, not a clean handover.

---

## 2. Subseries: 107 of them, and they are two different kinds of thing

```python
distinct subseries: 107
single-year labels ("1861", "1945"):  90 subseries, 290 volumes
multi-year  labels ("1969-76"):       17 subseries, 262 volumes
```

**The 90 single-year subseries (290 volumes)** are the annual compilation era. One label per calendar
year, 1861 through roughly 1951, holding between 1 and 16 volumes each. The largest are 1919 (16
volumes — the Paris Peace Conference), 1945 (12), 1946 (11), 1948 (11), 1951 (11), 1949 (10).

**The 17 multi-year subseries (262 volumes)** split cleanly in two:

*Nine administration subseries — 248 volumes, half the series:*

| subseries | volumes | printed from → to | years to complete |
|---|---:|---|---:|
| 1952-54 | 28 | 1979 → 2003 | 25 |
| 1955-57 | 29 | 1985 → 1993 | 9 |
| 1958-60 | 23 | 1986 → 1998 | 13 |
| 1961-63 | 27 | 1988 → 2021 | 34 |
| 1964-68 | 35 | 1992 → 2013 | 22 |
| **1969-76** | **66** | 2001 → 2021 | 21 |
| 1977-80 | 27 | 2013 → 2025 | 13 |
| 1981-88 | 12 | 2015 → 2025 | 11 (incomplete) |
| 1989-92 | 1 | 2025 → 2025 | 1 (incomplete) |

A subseries is not a publishing event but a **multi-decade programme**. The Kennedy years took 34
years to print (1988–2021); the Nixon–Ford years run to 66 volumes, 12% of the whole series for
eight years of policy.

*Eight special/retrospective subseries — 14 volumes:*

| subseries | volumes | what it is |
|---|---:|---|
| 1914-20 | 2 | The Lansing Papers (pub. 1939–40) |
| 1931-41 | 2 | Japan 1931–1941 (pub. 1943) |
| 1933-39 | 1 | The Soviet Union 1933–1939 (pub. 1952) |
| 1941-43 | 1 | The Conferences at Washington (pub. 1958) |
| 1945-50 | 1 | Emergence of the Intelligence Establishment (pub. 1996) |
| 1950-55 | 1 | The Intelligence Community (pub. 2007) |
| 1951-54 | 2 | Iran 1951–1954 + its Second Edition (pub. 2017, 2018) |
| 1917-72 | 4 | Public Diplomacy (pub. 2014–2018) |

These are FRUS reopening a period it had already closed — a personal archive, an intelligence
history, a covert operation, a whole functional channel it had never printed. They are also where
the series' two live Second Editions come from, and why the house rule exists: `frus1951-54IranEd2`
and `frus1969-76ve15p2Ed2` re-print their first editions and must be suppressed in any count.
(`frus1977-80v09Ed2` has no first edition and stays.)

---

## 3. Coverage years: 1861–1991, continuous, and increasingly parallel

```python
coverage years across the manifest: 1620 – 1991   (pre-1861 = arbitration exhibits, see Task 1)
years 1861–1991 with no volume covering them: 0
```

**Not one year in 131 is uncovered.** But *how* a year is covered changed completely.

Volumes whose coverage touches a given year:

| year | volumes | | year | volumes |
|---|---:|---|---|---:|
| 1861 | 19 | | 1950 | 26 |
| 1875 | 8 | | 1955 | 33 |
| 1890 | 12 | | 1960 | 32 |
| 1900 | 12 | | 1965 | 33 |
| 1910 | 12 | | 1970 | 36 |
| 1918 | 31 | | **1977** | **44** |
| 1925 | 14 | | 1985 | 9 |
| 1935 | 19 | | 1991 | 1 |

Busiest years overall: 1977 (44 volumes), 1969 (43), 1972 (42), 1952 and 1973 (40). The 1985 and
1991 figures are the publication frontier, not thin coverage — the Reagan subseries is 12 of a
planned many and the Bush subseries has one volume out.

**Span per volume** (`latest − earliest + 1` from the manifest):
```python
min 1   median 4   mean 6   max 253
span 1y: 38 vols · 2y: 78 · 3y: 147 · 4y: 86 · 5y: 82 · 6y: 38 · >10y: 30
```
The modal volume covers **three years** — the administration subseries' natural unit. The
253-year and 207-year outliers are `frus1872p2v5` and `frus1902app2`, the two arbitration case
files Task 1 identified; they are not coverage.

**The volume is a stable physical object.** Median file size by decade of printing barely moves
across 164 years: 5.99 MB (1860s), 5.76 (1930s), 5.42 (1950s), 7.31 (1970s), 5.09 (1990s), 5.86
(2010s). What changed is not how big a volume is but how many of them a year needs — and, per Task
1, how many documents fit inside one (719 per volume in the 1940s, 145 in the 1980s).

---

## 4. The gap between covering and printing — the central finding

Lag = publication year − last year the volume covers, computed per volume from the manifest.

```python
across all 552:  min −4   median 27   mean 23.3   max 95
```

**By decade of publication:**

| printed in | volumes | median lag (years) | range |
|---|---:|---:|---|
| 1860s | 19 | **1** | 0–2 |
| 1870s | 19 | **0** | −1–1 |
| 1880s | 10 | 0.5 | 0–1 |
| 1890s | 13 | **0** | 0–1 |
| 1900s | 13 | 1 | 0–2 |
| 1910s | 7 | 2 | 1–7 |
| 1920s | 8 | 8.5 | −4–13 |
| 1930s | 25 | 14 | 4–22 |
| 1940s | 42 | 14 | 1–28 |
| 1950s | 46 | 16 | 10–19 |
| 1960s | 38 | 21 | 0–23 |
| 1970s | 49 | 25 | 22–29 |
| 1980s | 54 | **30** | 24–35 |
| 1990s | 73 | 32 | 27–46 |
| 2000s | 54 | 33 | 28–51 |
| 2010s | 68 | **37** | 27–95 |
| 2020s | 14 | 36 | 32–58 |

This is a single monotonic curve with no reversal, and it is the whole institutional history of the
series in one column:

- **1861–1910: FRUS is current journalism.** Median lag 0–1 year. The papers went to Congress with
  the President's annual message, in the same season as the events. Two volumes have *negative*
  lag by this measure.
- **1920s–1930s: the break.** Lag jumps from 2 to 8.5 to 14 in twenty years. FRUS stops being an
  annual report and becomes a historical edition.
- **1950s–1970s: steady drift**, 16 → 21 → 25.
- **1980s: the 30-year line is reached.** Median lag hits exactly 30.
- **1990s onward: the line is crossed and never recovered.** 32 → 33 → **37**. The statutory
  expectation of publication within thirty years of the events is, on this data, met in the 1980s
  and missed in every decade since — by a widening margin, peaking at a median of 37 years in the
  2010s.

**By decade of coverage end** the same curve appears from the other side: a volume ending in the
1890s waited a median of 0 years; one ending in the 1970s waited 35, and in the 1980s 35.

**The extremes:**

| volume | covers to | printed | lag |
|---|---:|---:|---:|
| `frus1917-72PubDip` | 1919 | 2014 | **95** |
| `frus1951-54IranEd2` | 1954 | 2018 | 64 |
| `frus1951-54Iran` | 1954 | 2017 | 63 |
| `frus1961-63v10-12mSupp` | 1963 | 2021 | 58 |
| `frus1917-72PubDipv06` | 1963 | 2017 | 54 |
| `frus1950-55Intel` | 1956 | 2007 | 51 |
| `frus1945-50Intel` | 1950 | 1996 | 46 |

Every one of the seven longest lags is a **retrospective** volume from §2 — public diplomacy,
intelligence, or Iran. The tail of the lag distribution is not the series running late. It is the
series going back for what it did not print the first time, and the two things should never be
averaged together.

---

## 5. Editorial credit, as a structural marker

| printed in | median named editors | volumes naming a general editor |
|---|---:|---:|
| 1860s–1910s | 0 | 1 of 81 |
| 1920s | 1 | 7 of 8 |
| 1930s–1940s | 1 | 67 of 67 |
| 1950s | 4.5 | 41 of 46 |
| 1970s | 4 | 26 of 49 |
| 1990s | 2 | 73 of 73 |
| 2010s–2020s | 1 | 82 of 82 |

No pre-1920 volume names an editor: it was a Department compilation, not an edited book. Credit
appears in the 1920s, peaks in the 1950s–70s at four or five named editors per volume, and settles
at one. `generalEditor` is present on 418 of 552 volumes. The arrival of the named editor and the
opening of the lag (§4) are the same event seen twice.

---

## 6. Two manifest defects found by cross-checking against the index

Comparing each volume's manifest `dateRange` with the actual min/max `date_iso` in the index
(552 volumes compared), seven volumes have a manifest `latest` overshooting the index by ≥2 years.
Five are explained by an apparatus row inside the range. **Two are not supported by any row at all:**

```sql
SELECT volume_id, MAX(d.date_iso) FROM document_cache c JOIN document_dates d USING(volume_id,document_id)
WHERE c.volume_id IN ('frus1915','frus1910') AND d.date_iso<>'' GROUP BY 1;
```
| volume | manifest says covers to | latest dated row in the volume (any kind) |
|---|---|---|
| `frus1915` | 1928-10-22 | **1915-12-31** |
| `frus1910` | 1914 | **1911-02-09** |

`frus1915` has **zero** documents dated after 1916 and was printed in 1924 — the manifest's 1928 is
impossible. Anyone computing lag from the manifest alone gets −4 years for that volume. It is one
volume in 552 and moves no aggregate here, but it is why §4's medians are quoted rather than its
minima.

---

## 7. The archival channels, labelled (per house rule — never summed)

The publication has an apparatus, and it is not evenly distributed either:

| channel | rows | volumes |
|---|---:|---:|
| **came-from** — `document_sources`, one row per document's own source note | 264,487 | **501 of 552** |
| **pointed-at** — `external_citations`, what the editors' footnotes cite | 49,687 | **440 of 552** |
| front-matter Sources section — `volume_sources` | 33,764 | **258 of 552** |

Three different numbers about three different questions. Only 258 volumes tell you as a body where
their documents came from; 501 tell you document by document. The volumes that do neither are, as
in Task 2, the early ones — and the offline archival stack behind them is thin before 1940, so a
19th-century volume's provenance is a research question, not a lookup.

---

## 8. Summary

FRUS is not one publication but two wearing the same title. Between 1861 and about 1910 it was a
near-annual government report: 19 volumes covering 1861, printed with a median lag of one year, no
named editor, no source apparatus. Since roughly 1925 it has been a scholarly documentary edition:
administration subseries of 12 to 66 volumes each, taking 9 to 34 years to complete, printed a
median of 30 to 37 years after the events, with named editors and per-document provenance.

The turn happens in the 1920s and is visible in four independent measures at once — the lag opens
(2 → 14 years), the editor is named, the annual label gives way to the administration label, and
(from Task 1) the documents get shorter and far more numerous before getting longer and fewer again.

Coverage is continuous across all 131 years from 1861 to 1991 and increasingly parallel — 44
volumes touch 1977 against 8 touching 1875. The two visible frontiers are the Reagan subseries
(12 volumes) and the Bush subseries (1), and both will fill. Every count here is conditional on this
library, which holds all 552 published volumes.
