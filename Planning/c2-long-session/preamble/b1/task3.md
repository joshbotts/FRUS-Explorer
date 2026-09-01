# Task 3 — The 552 volumes as a publication

Sources: `manifest.json` (titles, subseries, coverage `dateRange`, `publicationDate`, editors,
file size) from the app bundle; `volume_structures` and `document_cache` from `frus-copy.db`.

## 1. The shape of the set

552 volumes, all flagged `published`, occupying 3.34 GB of TEI (median volume 5.8 MB, from
`frus1919Parisv10` at 531 KB to `frus1958-60v03mSupp` at 13.1 MB). They hold **315,827 documents**
excluding front matter — a median of 480 per volume, from 31 (`frus1919Parisv10`) to 1,944
(`frus1915`).

Note in passing: `manifest.json` carries a `documentCount` field and it is **0 for all 552
volumes**. It is dead metadata; the real counts have to come from the index.

## 2. Subseries: 107 of them, and the grouping rule changes twice

Every volume belongs to exactly one `subseries` label. There are 107, and reading them in order
tells the publication's institutional history:

**(a) 1861–1951 — annual.** Ninety-one labels, one per year, each holding between one and sixteen
volumes. The series began as a yearly report: the very first volume is not even called *Foreign
Relations*, it is titled *"Message of the President of the United States to the Two Houses of
Congress…"*. From 1862 the running title is *Papers Relating to the Foreign Relations of the United
States* (142 volumes, published 1862–1947); the modern *Foreign Relations of the United States*
form first appears on an 1894 appendix in 1895 and takes over completely thereafter (409 volumes).

Annual subseries swell where events do: 1919 has 16 volumes (two annual, one on Russia, and the
thirteen-volume *Paris Peace Conference* set), 1945 has 12, 1946 and 1948 and 1951 have 11 each.

**(b) 1952 onward — presidential terms.** The annual label is abandoned for multi-year blocks that
track administrations:

| subseries | volumes | documents | published | years to complete |
|---|---|---|---|---|
| 1952–54 | 28 | 15,181 | 1979–2003 | 24 |
| 1955–57 | 29 | 11,292 | 1985–1993 | 8 |
| 1958–60 | 23 | 9,564 | 1986–1998 | 12 |
| 1961–63 | 27 | 10,476 | 1988–2021 | 33 |
| 1964–68 | 35 | 13,515 | 1992–2013 | 21 |
| **1969–76** | **66** | **19,522** | 2001–2021 | 20 |
| 1977–80 | 27 | 8,286 | 2013–2025 | 12 |
| 1981–88 | 12 | 4,229 | 2015–2025 | (in progress) |
| 1989–92 | 1 | — | 2025 | (in progress) |

The Nixon–Ford subseries at 66 volumes is the largest single unit of the whole publication. The
last two are visibly incomplete — twelve volumes for eight Reagan years, one for Bush — which is
why Task 1's histogram falls off a cliff after 1980.

**(c) Eight retrospective / thematic subseries** cut across the chronological spine and are the
most interesting objects in the set, because each exists to publish something the ordinary
schedule had skipped:

- `1914-20` — *The Lansing Papers* (2 vols, 1939–40)
- `1931-41` — *Japan, 1931–1941* (2 vols, both 1943 — published two years after the coverage ends,
  in the middle of the war)
- `1933-39` — *The Soviet Union, 1933–1939* (1952)
- `1941-43` — *The Conferences at Washington and Casablanca* (1958)
- `1945-50` and `1950-55` — *Emergence of the Intelligence Establishment* (1996) and
  *The Intelligence Community* (2007)
- `1951-54` — *Iran, 1951–1954* (2017) **and its Second Edition** (2018)
- `1917-72` — *Public Diplomacy* (4 vols, 2014–18), spanning fifty-five years in one label

## 3. Coverage years

Measured from each volume's own documents (`dateRange` in the manifest is the *empirical* span of
its content, not a nominal label), the publication runs from **1620-11-03** to **1991-11-20**.

The extreme early end is not the series reaching back: it is the arbitration volumes reprinting
their exhibits. `frus1872p2v5` is recorded as spanning 1620–1872 because the Treaty of Washington
case printed a 1620 document, and `frus1902app2` reaches back to 1697 for Spanish colonial decrees
in the Pious Fund case.

Typical volumes are tight. The median empirical span is **4 years**; 431 of 552 volumes span 5
years or fewer. Volumes routinely bleed past their nominal year — `frus1945v09` holds material from
1942 to 1946 — so the subseries label is an editorial address, not a filter.

Volumes by coverage decade (dateRange midpoint):

```
1860s 23   1870s 14   1880s 13   1890s 12   1900s 13
1910s 44   1920s 17   1930s 49   1940s 88   1950s 100
1960s 69   1970s 91   1980s 13
```

The 1950s (100) and 1970s (91) each get more volumes than the whole of 1861–1909 (75), for a fraction
of the documents — the same document-density change Task 1 found, seen from the shelf.

## 4. The gap between coverage and printing

Comparing each volume's publication year against the end year of its subseries label:

| coverage ends in | volumes | median lag (yrs) | range |
|---|---|---|---|
| 1860s | 19 | 1 | 0–2 |
| 1870s | 19 | 0 | 0–1 |
| 1880s | 11 | 1 | 0–1 |
| 1890s | 14 | 1 | 1–3 |
| 1900s | 15 | 1 | 1–5 |
| 1910s | 37 | 15 | 5–28 |
| 1920s | 26 | 15 | 14–20 |
| 1930s | 46 | 17 | 13–19 |
| 1940s | 91 | 23 | 2–29 |
| 1950s | 79 | 31 | 25–64 |
| 1960s | 85 | 32 | 24–58 |
| 1970s | 70 | 34 | 25–46 |
| 1980s | 39 | 36 | 27–45 |

Across all 552 volumes the median lag is **27 years**; the mean is 23.5 (dragged down by the
19th-century tail); the range is 0 to 64.

Read the other way — by when the volume was *printed* — the lag grows monotonically and never
recovers: 0–1 years for anything printed before 1910, 5 (1910s), 9 (1920s), 15 (1930s–40s), 17
(1950s), 22 (1960s), 26 (1970s), 30.5 (1980s), 32 (1990s–2000s), **36 (2010s and 2020s)**.

Three things follow.

**a) FRUS changed genre.** Through 1909 it was a current government document: the papers of the
year just ended, laid before Congress within a year. That is a different publication from the one
being printed today, which is a historical edition of a generation-old record. The break is sharp —
lag jumps from 1 year to 15 between volumes covering the 1900s and the 1910s.

**b) The 30-year statutory target is not being met in this corpus.** Of the 194 volumes published
in 1992 or later, only **33 (17%)** appeared within 30 years of the end of their coverage period;
the median for that group is 33 years.

**c) The longest lags are declassification stories, and they cluster.** The ten slowest volumes are
almost all covert-action or intelligence titles:

| lag | volume | covers | printed |
|---|---|---|---|
| 64 | `frus1951-54IranEd2` — *Iran, Second Edition* | 1951–54 | 2018 |
| 63 | `frus1951-54Iran` — *Iran* | 1951–54 | 2017 |
| 58 | `frus1961-63v10-12mSupp` — Cuba microfiche supplement | 1961–63 | 2021 |
| 52 | `frus1950-55Intel` — *The Intelligence Community* | 1950–55 | 2007 |
| 49 | `frus1952-54Guat` — *Guatemala* | 1952–54 | 2003 |
| 46 | `frus1945-50Intel` — *Emergence of the Intelligence Establishment* | 1945–50 | 1996 |
| 46 | `frus1917-72PubDipv07`, `v08` — *Public Diplomacy* | 1917–72 | 2018 |

The Iran volume is the clearest case in the set: a compilation the series had effectively suppressed,
published 63 years late in 2017 and then reissued in an expanded second edition the following year.
Note that both editions are counted as volumes here, so the Iran material is present twice — as is
`frus1969-76ve15p2` and `frus1977-80v09`, each of which also has an `Ed2`. **Three of the 552
volumes are second editions of another volume in the same set**, and a naive corpus-wide count
double-counts their documents.

## 5. Physical and editorial forms inside the count

The "552 volumes" are not 552 books:

- **22 electronic-only volumes** (`…ve01`, `…ve15p2`…), all in the 1969–76 and 1964–68 subseries —
  born-digital supplements with no print counterpart.
- **5 microfiche supplements** (`…mSupp`), published 1986–2021 for volumes whose bulk exceeded print.
- **95 volumes are one part of a multi-part volume** (`…p1`, `…p2`, `…p3`).
- **3 second editions**, as above.
- **9 wartime supplements** (`frus1914Supp`, `frus1917Supp02v01`…) sitting beside the annual volumes.

## 6. Internal organisation, and how it changed

`volume_structures` gives each volume's top-level divisions: 4,030 `compilation` sections, 154
`chapter`, plus front and back matter. Compilations per volume, by publication era:

```
printed 1860s   median  2
printed 1880s   median 25
printed 1900s   median 32
printed 1920s   median 13
printed 1940s   median  4
printed 1960s   median  8
printed 1980s   median  1
printed 2000s   median  1
printed 2020s   median  1
```

The turn-of-the-century volumes are omnibuses divided country by country — thirty-odd compilations
in one book, everything the department did that year. The modern volume is a monograph: one
compilation, one subject, one region.

Front matter changed with it. Of 552 volumes, 489 have a table of contents, 407 a preface, 310 an
abbreviations list, **280 a Persons list**, 262 a Sources note, and **44 a "Note on U.S. Covert
Actions"** — the last three being modern editorial apparatus that simply does not exist in the
19th-century volumes. (The 280 Persons lists are the same constraint that limits Task 2's ranking.)

Attribution followed the same arc: **81 volumes name no editor at all, and every one of them was
published between 1861 and 1922** — compiled anonymously as a government document. The other 471
name 204 distinct volume editors under 23 general-editor strings (really about 18 people; the
manifest carries `Gustave A. Nuermberger` and `Nuermberger`-as-`Nuremberger`, `Fredrick`/`Frederick
Aandahl`, `Adam M. Howard`/`Adam Howard` and `John P. Glennon`/`Glennon, John P.` as separate
values). Tyler Dennett is credited on 66 volumes, Edward C. Keefer on 54, John P. Glennon on 50.

## 7. Summary

The 552 volumes are one publication in name and three in practice: an annual congressional
document (1861–c.1909, printed within a year, organised country by country, unsigned); a
retrospective series finding its footing (c.1910–1950, lag growing from 5 to 25 years); and a
modern scholarly edition (1952–, organised by presidential term into 66-volume blocks, one subject
per volume, with a named editorial staff, a source note, a persons index and a covert-action
disclaimer, printed a median 33 years after the events). The count of 552 also includes 22
electronic volumes, 5 microfiche supplements and 3 second editions, so it is a count of publication
units rather than of distinct bodies of material.
