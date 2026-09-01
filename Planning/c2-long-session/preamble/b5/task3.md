# Task 3 — How the 552 volumes are organised as a publication

Source: the bundled `manifest.json` (552 volumes: `volumeId`, `subseries`, `title`,
`publicationDate`, `dateRange`), joined to per-volume document counts from `document_cache`.
All 552 volumes carry `status: "published"` and a `publicationDate`; none is a placeholder.

## 1. The unit of organisation: 107 subseries

The 552 volumes are grouped into **107 subseries**. The distribution is extremely uneven:

| subseries size | how many subseries |
|---|---|
| 1 volume | 40 |
| 2–3 volumes | 31 |
| 4–5 volumes | 14 |
| 6–12 volumes | 14 |
| 16–35 volumes | 7 |
| 66 volumes | 1 (`1969-76`) |

Two organising principles, applied in sequence:

**(a) Annual subseries, 1861–1951 (90 of the 107).** One subseries per calendar year, named for
that year. Ninety consecutive years with **exactly one gap — 1869**, for which no volume exists
(1868 and 1870 are both present). Early years are single volumes or two-to-four "parts"
(`frus1864p1`…`frus1864p4`); by the 1930s a year routinely runs to five volumes and by the late
1940s to eight to twelve (`1945` = 12, `1946` = 11, `1948` = 11, `1951` = 11).

**(b) Presidential-term subseries, 1952 onward (9 of the 107).** From `1952-54` the series stops
following the calendar and follows the administration: `1952-54`, `1955-57`, `1958-60` (28/29/23
volumes), `1961-63` (27), `1964-68` (35), `1969-76` (66), `1977-80` (27), `1981-88` (12),
`1989-92` (1). Each such subseries is subdivided **thematically and regionally** rather than
chronologically — the volume number denotes a subject (Arab–Israeli dispute, START I, Public
Diplomacy), not a slice of time.

**(c) Eight retrospective/special subseries** sit outside both schemes and are worth naming
because they break every chronological assumption:

| subseries | volumes | what it is | published |
|---|---|---|---|
| `1914-20` | 2 | The Lansing Papers | 1939–1940 |
| `1931-41` | 2 | Japan, 1931–1941 | 1943 |
| `1933-39` | 1 | The Soviet Union, 1933–1939 | 1952 |
| `1941-43` | 1 | The Conferences at Washington | 1958 |
| `1945-50` | 1 | Emergence of the Intelligence Establishment | 1996 |
| `1950-55` | 1 | The Intelligence Community | 2007 |
| `1951-54` | 2 | Iran, 1951–1954 (and its **second edition**) | 2017, 2018 |
| `1917-72` | 4 | Public Diplomacy, spanning 1917–1972 | 2014–2018 |

**Volume-form variants.** 107 volume ids are "parts" of a larger volume (`p1`, `p2`); 14 are
Supplements (concentrated in 1914–1918 and again in 1955–1963); 5 are Appendices (all
nineteenth-century arbitration compilations); 22 are **electronic-only** volumes, every one of
them in `1969-76`, published 2005–2021 — the series' one structural format innovation, used to
release material that would not otherwise fit the print schedule; and 3 are **second editions**
(`frus1951-54IranEd2` 2018, `frus1969-76ve15p2Ed2` 2021, `frus1977-80v09Ed2` 2018). A researcher
counting documents must decide whether a second edition is a new volume or a replacement; the
manifest treats it as a new volume, so the corpus double-counts that material.

## 2. The spread of coverage years

Coverage in the manifest is **descriptive, not editorial**: `dateRange` is derived from the
documents a volume actually contains — zero of the 314,487 dated documents fall outside their own
volume's declared range. So the range tells you what is in the book, not what the editors
intended it to cover.

* **Median coverage span: 4 years. Mean: 6.** 263 volumes (48%) span 1–3 years; 168 span 4–5;
  91 span 6–10; 30 span more than 10.
* The twelve longest-spanning volumes are all retrospective arbitration compilations —
  `frus1872p2v5` nominally spans 253 years (1620–1872) because the *Alabama* claims papers
  reproduce colonial-era documents as evidence; `frus1902app2` spans 207 years for the same
  reason. These are not multi-century volumes in any useful sense.
* **Volumes and their nominal labels agree closely, and agreement improves over time.** In the
  term subseries, 96–99% of a subseries' documents are dated inside its nominal window
  (`1958-60`: 98.6%; `1981-88`: 98.8%; `1969-76`: 97.2%). In the annual era the fit is looser and
  earlier is looser still: of documents in the 1861–1899 annual volumes only **79.7%** are dated
  in the volume's own nominal year, rising to 89.1% for 1900–1929 and 97.4% for 1930–1951. The
  early volumes were annual *transmittals* to Congress, so a volume laid before Congress in
  December 1894 naturally carries a tail of 1893 correspondence.
* Because volumes overlap, a given year's documents are scattered across many books: 1894's 1,409
  documents sit in 11 volumes; 1945's 11,540 sit in 31; 1969's in 40; 1972's in 40.

**Volume size.** 31 to 1,944 documents, mean 572, median about 480. The largest are the annual
volumes of the 1910s (`frus1915` 1,944; `frus1914` 1,889; `frus1912` 1,868); the smallest are
1919 Paris Peace Conference volumes (`frus1919Parisv10` 31) and the arbitration appendices. Size
per volume *falls* as the series modernises: `1944` averages 1,081 documents a volume across 8
volumes, `1969-76` only 295 across 66. The modern series prints fewer, longer items and spreads
them over many more, thinner, thematically-defined books.

## 3. The gap between coverage and printing

Defining lag = publication year − last year of coverage:

* Range: −4 to +95 years. **Median 27, mean 23.** (Two negative lags are artefacts: `frus1915`
  carries a small tail of documents dated after its 1924 printing, and `frus1872p2v2` likewise.)
* The distribution is **bimodal**, which is the single most important fact about the series:

| lag | volumes |
|---|---|
| 0–2 years | 80 |
| 3–10 years | 10 |
| 11–20 years | 114 |
| 21–30 years | 128 |
| 31–40 years | 200 |
| 41–50 years | 12 |
| over 50 years | 6 |

The 80 near-instantaneous volumes are the nineteenth-century annual transmittals; almost
everything else is a historical edition prepared decades after the fact.

**Median lag by decade of coverage end:**

| coverage ends | volumes | median lag | slowest in the group |
|---|---|---|---|
| 1860s | 19 | 1 | `frus1864p4` (pub. 1866) |
| 1870s | 19 | 0 | `frus1872p2v4` (1873) |
| 1880s | 10 | 0 | `frus1886` (1887) |
| 1890s | 14 | 0 | `frus1898` (1901) |
| 1900s | 14 | 1 | `frus1907p1` (1910) |
| 1910s | 32 | **13** | `frus1917-72PubDip` (2014, lag 95) |
| 1920s | 29 | 14 | `frus1919Parisv12` (1947) |
| 1930s | 46 | 16 | `frus1933v05` (1952) |
| 1940s | 88 | 22 | `frus1949v08` (1978) |
| 1950s | 85 | 30 | `frus1951-54IranEd2` (2018, lag 64) |
| 1960s | 88 | 32 | `frus1961-63v10-12mSupp` (2021) |
| 1970s | 67 | 35 | `frus1969-76v19p2` (2018) |
| 1980s | 40 | 35 | `frus1977-80v27` (2025) |
| 1990s | 1 | 34 | `frus1989-92v31` (2025) |

The transition is abrupt and datable: it happens at the First World War. Volumes covering 1909
and earlier were printed within a year or two; volumes covering 1914 onward were printed a decade
or more later; and from the 1950s the lag settles at roughly **30–35 years**, where it has stayed.
FRUS ceased being a current-accountability document and became a historical edition governed by a
declassification cycle.

## 4. Production, as distinct from coverage

Volumes published per decade: 19 (1860s), 19, 10, 13, 13, 7 (1910s), 8, 25, 42, 46, 38, 49, 54,
**73 (1990s)**, 54, **68 (2010s)**, 14 (2020s to date).

Three consequences follow:

* **Production peaked in the 1990s and 2010s**, not in the nineteenth century. The series' output
  as a publishing operation is a twentieth-century phenomenon.
* **Recent output has slowed sharply.** 2015 saw 10 volumes; 2019–2025 average 2.3 a year
  (2, 2, 4, 1, 1, 3, 3). Any projection of when the 1980s or 1990s will be completely covered
  should use the recent rate, not the historical one.
* **Subseries are produced over decades and overlap.** `1952-54` took from 1979 to 2003;
  `1961-63` from 1988 to 2021; `1964-68` 1992–2013; `1969-76` 2001–2021; `1977-80` 2013–2025;
  `1981-88` 2015–2025 and still running with only 12 of an eventual ~40 volumes out; `1989-92` has
  exactly one volume, printed in 2025. At any moment the office is working on four or five
  presidential terms at once, and a subseries' volumes may be separated by thirty years of
  editorial practice, declassification policy, and staff.

**Practical warning for corpus work.** "The 552 volumes" is a snapshot of a live publication as of
2025, not a closed set. The subseries after 1980 are radically incomplete, the second editions
duplicate their firsts, the electronic-only volumes exist only in `1969-76`, and the 1869 gap is
real. Nothing in the corpus is a random or representative sample of American diplomacy; it is the
current state of a 164-year-old editorial project.
