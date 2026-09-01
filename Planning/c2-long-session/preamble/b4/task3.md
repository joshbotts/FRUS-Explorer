# Task 3 — How the 552 volumes are organised as a publication

Sources: `manifest.json` (volume id, title, subseries, coverage `dateRange`,
`publicationDate`, editors, XML size) cross-checked against per-volume document counts
from `document_cache`. All 552 volumes are flagged `published`; `documentCount` in the
manifest is 0 for every record and unusable, so counts below come from the index.
Total corpus: **3.3 GB of TEI XML, 316,839 indexed documents**, median volume 5.8 MB
and 483 documents (range 31 to 1,945 documents).

## 1. The unit of publication is the *subseries*, not the volume

The 552 volumes belong to **107 subseries**, and the subseries is what the Office of
the Historian actually plans and prints. Their sizes are wildly uneven:

| Volumes in subseries | Number of subseries |
|---|---:|
| 1 | 40 |
| 2 | 22 |
| 3–5 | 23 |
| 6–12 | 14 |
| 16 | 1 (1919) |
| 23–29 | 4 (1958-60, 1952-54, 1955-57, 1961-63) |
| 35 | 1 (1964-68) |
| 66 | 1 (1969-76) |

Forty subseries are a single volume; one (1969-76) is sixty-six. That range is the
whole publication history in one number.

**The naming scheme changes twice.** Through 1951 a subseries is labelled by a single
calendar year — `1861`, `1932`, `1949`. From 1952 it is labelled by a presidential
term or span — `1952-54`, `1955-57`, `1958-60`, `1961-63`, `1964-68`, `1969-76`,
`1977-80`, `1981-88`, `1989-92`. Seven further subseries are **retrospective or
thematic** and break the chronology entirely: `1914-20` (Lansing Papers), `1931-41`
(Japan, printed 1943), `1933-39` (The Soviet Union, 1952), `1941-43` (Conferences at
Washington, 1958), `1945-50` (Emergence of the Intelligence Establishment, 1996),
`1950-55` (The Intelligence Community, 2007), `1951-54` (Iran, 2017–18) and `1917-72`
(Public Diplomacy, 2014–18). These were commissioned to fill acknowledged gaps in
volumes already printed, sometimes half a century later.

**How a subseries divides internally also changes.** In 1861 a "volume" is the
President's annual message to Congress with correspondence appended. By the 1930s it is
year plus world region — *1932, General* / *The British Commonwealth, Europe, Near East
and Africa* / *The Far East* (two volumes) / *The American Republics*. From the 1950s
it is period plus policy topic or single country — *1952–1954, National Security
Affairs*, *1952–1954, Guatemala*, *1969–1976, Volume VI, Vietnam, January 1969–July
1970*. Region gives way to subject.

Physical forms proliferate late: **93 part-volumes** (`…v01p1`, `…p2`, `…p3`), **22
electronic-only volumes** (`…ve11`), **5 microfiche supplements** (`…mSupp`), and **3
second editions**. Only one second edition duplicates a first edition also in the
corpus — `frus1951-54Iran` (2017, 378 docs) and `frus1951-54IranEd2` (2018, 377 docs),
about 755 near-identical documents. The other two (`frus1969-76ve15p2Ed2`,
`frus1977-80v09Ed2`) replaced first editions that are *not* in the manifest.

## 2. Output rate: 552 volumes over 165 years

Volumes printed per decade:

| Decade | Volumes | | Decade | Volumes |
|---|---:|---|---|---:|
| 1860s | 19 | | 1950s | 46 |
| 1870s | 19 | | 1960s | 38 |
| 1880s | 10 | | 1970s | 49 |
| 1890s | 13 | | 1980s | 54 |
| 1900s | 13 | | 1990s | **73** |
| 1910s | 7 | | 2000s | 54 |
| 1920s | 8 | | 2010s | 68 |
| 1930s | 25 | | 2020s (part) | 14 |
| 1940s | 42 | | | |

The series nearly stops in the 1910s–20s (15 volumes in twenty years) and then
industrialises: 249 volumes printed since 1990, 45% of the whole corpus. Output is high
today; what has changed is not productivity but distance from the events.

Structurally, the number of volumes devoted to a year of coverage peaked in the annual
regime and has fallen since:

| Regime (by subseries) | Subseries | Volumes | Volumes per nominal year | Documents | Median lag |
|---|---:|---:|---:|---:|---:|
| 1861–1905, annual | 44 | 72 | 1.6 | 39,665 | 0 yrs |
| 1906–1918, annual | 15 | 33 | 2.5 | 29,872 | 12 yrs |
| 1919–1939, annual | 23 | 88 | 4.2 | 65,173 | 15 yrs |
| 1940–1951, annual | 16 | 111 | 9.2 | 89,134 | 23 yrs |
| 1952–1968, multi-year | 5 | 142 | 8.4 | 60,383 | 32 yrs |
| 1969–1992, multi-year | 4 | 106 | 4.4 | 32,612 | 35 yrs |

## 3. Spread of coverage

Nominal span: **1620 to 1991**. The 1620–1860 end is spurious — those are older papers
reprinted as evidence inside the 1872 arbitration and 1894 appendix volumes. The real
span is 1861–1991, and **every single year in it is covered by at least one volume**.
There are no chronological holes.

Coverage overlaps heavily, because a volume's date range runs past its nominal year
(enclosures, prior correspondence). Volumes whose span touches a given year:

```
1860 ███████████████ 15      1930 █████████████ 13
1865 ██████████████████ 18    1935 ███████████████████ 19
1875 ████████ 8               1945 ████████████████████████████████ 32
1885 ███████████ 11           1955 █████████████████████████████████ 33
1895 █████████████ 13         1965 █████████████████████████████████ 33
1905 ███████████ 11           1970 ████████████████████████████████████ 36
1915 █████████████████ 17     1975 █████████████████████████████████ 33
1920 ████████████████████████ 24   1980 ███████████████████████████████ 31
1925 ██████████████ 14        1985 █████████ 9
                              1990 █ 1
```

Two facts stand out. The 1945–1980 plateau (roughly 30–36 volumes touching each year)
is the mature series working at full width. The collapse after 1980 is *not* thinner
coverage of the 1980s — it is a subseries still in press: `1981-88` has 12 volumes
against `1977-80`'s 27 for half as many years, and `1989-92` has exactly one
(`frus1989-92v31`, printed 2025).

## 4. The gap between coverage and printing

Defining lag as publication year minus the volume's last covered year:

- **Median 27 years, mean 23.3, range −4 to 95.**
- Two volumes have a negative lag (`frus1915` printed 1924 with stray 1928 material;
  `frus1872p2v2` printed 1872 with an 1873 document) — metadata edge cases, not
  time travel.

The distribution is bimodal, which is the signature of two different publications
sharing a name:

| Lag | Volumes | Share |
|---|---:|---:|
| ≤2 years | 82 | 14.9% |
| 3–10 years | 10 | 1.8% |
| 11–20 years | 114 | 20.7% |
| 21–30 years | 128 | 23.2% |
| 31–40 years | 200 | 36.2% |
| 41–50 years | 12 | 2.2% |
| >50 years | 6 | 1.1% |

The lag grows almost perfectly monotonically with publication date:

| Printed in | Volumes | Median lag | Range |
|---|---:|---:|---|
| 1860s | 19 | 1 yr | 0–2 |
| 1870s | 19 | 0 | −1–1 |
| 1880s | 10 | 0.5 | 0–1 |
| 1890s | 13 | 0 | 0–1 |
| 1900s | 13 | 1 | 0–2 |
| 1910s | 7 | 2 | 1–7 |
| 1920s | 8 | 8.5 | −4–13 |
| 1930s | 25 | 14 | 4–22 |
| 1940s | 42 | 14 | 1–28 |
| 1950s | 46 | 16 | 10–19 |
| 1960s | 38 | 21 | 0–23 |
| 1970s | 49 | 25 | 22–29 |
| 1980s | 54 | 30 | 24–35 |
| 1990s | 73 | 32 | 27–46 |
| 2000s | 54 | 33 | 28–51 |
| 2010s | 68 | 37 | 27–95 |
| 2020s | 14 | 36 | 32–58 |

**FRUS began as a current-affairs publication and became a historical edition.** Until
about 1905 the volumes were laid before Congress within a year of the events — the
1861 volume literally *is* the President's message to the Thirty-seventh Congress. The
lag opens in the 1910s, passes a decade in the 1920s, twenty years by the 1960s, thirty
by the 1980s, and has settled near 35–37 years. That is above the statutory 30-year
target the series is meant to meet, and it explains everything about the corpus's
recent edge: coverage stops at 1991 because material after that has not cleared
declassification and compilation.

The longest lags are the retrospective volumes — `frus1917-72PubDip` at 95 years,
the two Iran volumes at 63 and 64, the 1961-63 microfiche supplement at 58, the
intelligence volumes at 46 and 51 — commissioned precisely because the original
volumes were printed too early to include the material.

## 5. Editorial attribution

`editors` is empty for exactly **81 volumes, all printed before 1930** — the era when
the volumes were anonymous congressional documents. From the 1930s every volume names
its compilers: **204 distinct editors** across the series, the most prolific being
Joseph V. Fuller (66 volumes), John G. Reid (45), Charles S. Sampson (42), Rogers P.
Churchill (36) and Francis C. Prescott (35).

## 6. Cautions

- Coverage `dateRange` is derived from documents inside the volume, so it is wider than
  the nominal title span and the overlap counts above are generous.
- One duplicated volume pair (`frus1951-54Iran` / `…Ed2`) means ~755 documents are
  present twice; any corpus-wide count including both double-counts them.
- Subseries labels are not a clean chronological key: seven of them are thematic spans
  that overlap the numbered series, so grouping by subseries and grouping by coverage
  year give different answers.
- The 1981-88 and 1989-92 subseries are incomplete. Any comparison that treats them as
  finished understates the 1980s by an unknown but large factor.
