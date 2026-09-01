# Task 3 — How the 552 volumes are organised as a publication

## 0. Coverage statement and surfaces used

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
```
**552 volumes, 316,839 documents, 1,012 front matter, 8,468 editorial notes.** The local
library holds the complete 552-volume series, so the structural picture below is not
conditioned on a partial download.

Two surfaces are in play and each answers a different half of this task:

- **`manifest.json`** (bundled, `/Applications/FRUS Explorer.app/Contents/Resources/`) —
  552 entries, one per volume, carrying `subseries`, `dateRange.earliest/latest`,
  `publicationDate`, `title`, `editors`, `generalEditor`. Every one of the 552 has a
  `publicationDate` and a `dateRange`; `status` is `published` for all 552. **`documentCount`
  is 0 for all 552 and is unusable** — every document count below comes from the database.
- **The index** — document counts, apparatus flags, document dates.

Document counts throughout use the Task 1 scope: apparatus excluded, `frus1951-54IranEd2`
and `frus1969-76ve15p2Ed2` suppressed → **550 volumes, 305,280 dated documents**. Volume
*structure* counts use all 552, since a suppressed duplicate is still a published volume.

---

## 1. Three organising regimes, not one

The `subseries` field takes **107 distinct values** across the 552 volumes. Ninety of them
are bare four-digit years; seventeen are spans. Splitting on that boundary recovers the
series' actual publishing history:

| regime | subseries | volumes | documents | docs per volume |
|---|---:|---:|---:|---:|
| **A. Annual series**, 1861–1951 (single-year labels) | 90 | 290 | 214,611 | ~740 |
| **B. Administration blocks**, 1952–1992 | 9 | 248 | 85,694 | ~346 |
| **C. Special / retrospective compilations** | 8 | 14 | 4,975 | ~355 |

### A. The annual series, 1861–1951

One subseries per calendar year, for ninety of the ninety-one years from 1861 to 1951
(there is no 1869 subseries). It begins as literally one book a year and swells:

| label decade | year-subseries | volumes | documents | docs/vol |
|---|---:|---:|---:|---:|
| 1860s | 8 | 19 | 10,870 | 572 |
| 1870s | 10 | 19 | 6,351 | 334 |
| 1880s | 10 | 11 | 6,478 | 588 |
| 1890s | 10 | 14 | 9,696 | 692 |
| 1900s | 10 | 15 | 9,912 | 660 |
| 1910s | 10 | 37 | 29,320 | 792 |
| 1920s | 10 | 24 | 19,796 | 824 |
| 1930s | 10 | 45 | 37,861 | 841 |
| 1940s | 10 | 88 | 72,802 | 827 |
| 1950s (1950, 1951 only) | 2 | 18 | 11,525 | 640 |

Thirty-five of the ninety year-subseries are a single volume; the largest is **1919 with 16
volumes** (the Paris Peace Conference set), followed by 1945 with 12, and 1946/1948/1951
with 11 each. The transition from "a volume" to "a set" is the 1910s.

### B. The administration blocks, 1952 onward

From 1952 the annual label is abandoned for presidential-term spans. This is the modern
series and it holds nearly half the volumes:

| subseries | volumes | documents | docs/vol | published |
|---|---:|---:|---:|---|
| 1952-54 | 28 | 14,031 | 501 | 1979–2003 |
| 1955-57 | 29 | 10,335 | 356 | 1985–1993 |
| 1958-60 | 23 | 8,418 | 366 | 1986–1998 |
| 1961-63 | 27 | 9,714 | 359 | 1988–2021 |
| 1964-68 | 35 | 12,767 | 364 | 1992–2013 |
| **1969-76** | **66** | 18,107 | 278 | 2001–2021 |
| 1977-80 | 27 | 8,031 | 297 | 2013–2025 |
| **1981-88** | **12** | 4,052 | 337 | 2015–2025 |
| **1989-92** | **1** | 239 | 239 | 2025 |

The Nixon–Ford block at 66 volumes is the largest single subseries in the series. The last
two blocks are visibly incomplete — 12 volumes for eight Reagan years, 1 volume for
Bush — which is the publication frontier discussed in §4.

### C. Eight special compilations, 14 volumes

Thematic or retrospective sets that sit outside both schemes:

| subseries | vols | docs | coverage | published |
|---|---:|---:|---|---|
| 1914-20 | 2 | 1,120 | 1914–1921 | 1939–1940 |
| **1917-72 (Public Diplomacy)** | 4 | 544 | 1917–1972 | 2014–2018 |
| 1931-41 | 2 | 1,102 | 1931–1942 | 1943 |
| 1933-39 | 1 | 836 | 1932–1939 | 1952 |
| 1941-43 | 1 | 346 | 1941–1943 | 1958 |
| 1945-50 (Intelligence) | 1 | 435 | 1945–1950 | 1996 |
| 1950-55 (Intelligence) | 1 | 234 | 1950–1956 | 2007 |
| 1951-54 (Iran) | 2 | 358 | 1951–1954 | 2017–2018 |

Two of these — the Iran and Intelligence retrofits — exist because the original volumes
omitted covert action. `frus1951-54Iran` (2017) is the acknowledged replacement for the
1952-54 Iran coverage; it is one of the two volumes in the series with a second edition.

### Volume-id shapes worth knowing

Of the 552 ids: **94 carry a part suffix** (`p1`/`p2`/`p3` — one nominal volume issued in
several physical parts), **22 are electronic-only supplements** (`ve…`, all 22 in the
1969-76 block, 6,764 documents), **14 are `Supp`** (wartime supplements), **5 are `app`**
(arbitration appendices), and **3 end in `Ed2`**.

---

## 2. The spread of coverage years

Coverage is not one year per volume. Per-volume span width (`dateRange.latest` minus
`dateRange.earliest`, in years):

- median **3**, mean **5.0**, p90 **7**, max **252**
- **116 of 552** volumes span one calendar year or less
- **121 of 552** span five years or more

The extreme spans are the arbitration appendices identified in Task 1:
`frus1872p2v5` covers 1620–1872 (252 years), `frus1902app2` 1697–1903 (206 years). These
are printed exhibit files, and they are the reason a naive "coverage decade" axis puts
volumes into the seventeenth century.

Counting the *decades a volume's span touches*, the series' coverage is heaviest in the
Cold War and thinnest at both ends:

| decade touched | volumes |
|---|---:|
| 1620s–1850s | 1–9 each |
| 1860s | 30 |
| 1870s | 25 |
| 1880s | 21 |
| 1890s | 23 |
| 1900s | 25 |
| 1910s | 55 |
| 1920s | 42 |
| 1930s | 59 |
| 1940s | 104 |
| 1950s | 111 |
| **1960s** | **122** |
| 1970s | 97 |
| 1980s | 41 |
| 1990s | 1 |

Note the contrast with Task 1: the 1960s are touched by the *most volumes* (122) but hold
far fewer documents (27,650) than the 1940s (74,043 across 104 volumes). More volumes,
each much thinner. Volume size confirms it directly — across the 550 in-scope volumes,
documents per volume run min 2 / p25 311 / **median 459** / p75 792 / max 1,913, with the
largest volumes being the pre-WWI annuals (`frus1915` 1,913; `frus1914` 1,864;
`frus1912` 1,860) and the smallest being the Paris Peace Conference parts
(`frus1919Parisv13` has just 2 dated documents against 167 undated ones).

### A caveat on the coverage field

The manifest's `dateRange` and the documents' own dates mostly agree, but not always. Over
all 552 volumes: the manifest's earliest year differs from the earliest document date in
**25 of 552** volumes, and the latest year differs in **29 of 552**. Ten disagree by three
years or more, e.g.:

| volume | manifest span | document span |
|---|---|---|
| frus1915 | 1911–**1928** | 1913–**1915** |
| frus1945v08 | 1944–**1957** | 1944–**1946** |
| frus1910 | 1907–**1914** | 1907–**1911** |
| frus1945Berlinv02 | 1945–**1960** | (Potsdam, 1945) |

Verified in the index: `SELECT MIN(date_iso), MAX(date_iso) … WHERE volume_id='frus1915'`
returns 1911-09-26 … **1915-12-31**, with no document after 1916 at all. The manifest's
1928 is spurious. So the coverage field is reliable for 523+ of 552 volumes but should not
be trusted per-volume without a check against document dates.

---

## 3. The gap between coverage and printing

`publicationDate` runs from **1861 to 2025** — the series has been appearing continuously
for **164 years**. Volumes issued per decade:

| decade | vols | | decade | vols |
|---|---:|---|---|---:|
| 1860s | 19 | | 1950s | 46 |
| 1870s | 19 | | 1960s | 38 |
| 1880s | 10 | | 1970s | 49 |
| 1890s | 13 | | 1980s | 54 |
| 1900s | 13 | | **1990s** | **73** |
| 1910s | 7 | | 2000s | 54 |
| 1920s | 8 | | 2010s | 68 |
| 1930s | 25 | | 2020s (part) | 14 |
| 1940s | 42 | | | |

The trough is the 1910s–20s (15 volumes in twenty years); the peak is the 1990s (73).

**Lag = publication year − coverage-latest year**, over all 552 volumes:

| | |
|---|---|
| minimum | −4 |
| p10 | 1 |
| p25 | 14 |
| **median** | **27** |
| p75 | 33 |
| p90 | 36 |
| maximum | 95 |
| mean | 23.3 |

The distribution is not a spread around a norm; it is **a regime change**, and it appears
whichever way you slice it.

By **publication era**:

| published | n | median lag | min | max |
|---|---:|---:|---:|---:|
| 1861–1900 | 61 | **0** | −1 | 2 |
| 1901–1920 | 21 | 1 | 0 | 7 |
| 1921–1940 | 35 | 14 | −4 | 22 |
| 1941–1960 | 88 | 16 | 0 | 28 |
| 1961–1980 | 85 | 24 | 12 | 29 |
| 1981–2000 | 133 | 32 | 24 | 46 |
| 2001–2025 | 129 | **35** | 27 | 95 |

By **coverage decade** — the same climb, read the other way:

| covers | n | median lag | range |
|---|---:|---:|---|
| 1860s | 19 | 1 | 0…2 |
| 1870s | 19 | 0 | −1…1 |
| 1880s | 10 | 0.5 | 0…1 |
| 1890s | 14 | 0 | 0…2 |
| 1900s | 14 | 1 | 0…2 |
| 1910s | 32 | 13 | 1…95 |
| 1920s | 29 | 14 | −4…27 |
| 1930s | 46 | 16 | 8…18 |
| 1940s | 88 | 22 | 1…29 |
| 1950s | 85 | 30 | 12…64 |
| 1960s | 88 | 32 | 0…58 |
| 1970s | 67 | **35** | 28…46 |
| 1980s | 40 | **35** | 27…44 |
| 1990s | 1 | 34 | — |

**What this means.** For its first fifty years FRUS was a *current* publication: the 1861
volume was laid before Congress in 1861, and through 1900 the median volume appeared the
same year its documents ended. It was an instrument of executive accountability to
Congress, printed while the events were live. The lag opens in the 1910s (median 13
years), settles near 16 through the interwar and wartime volumes, reaches 24 by the
1960s–70s, and then locks at **32–35 years from 1981 onward** — the plateau that
corresponds to the 30-year line the 1991 FRUS statute made statutory, plus a few years of
routine slippage. The series changed from a contemporary parliamentary paper into a
retrospective scholarly edition, and the lag column is the clean quantitative trace of it.

**Two negative lags**, both explained rather than dismissed:
- `frus1872p2v2` — manifest publication 1872, but the index shows three real documents
  dated 1873 (`d259`–`d261`, Schenck–Fish correspondence to 1873-03-06). The 19th-century
  `publicationDate` is a nominal series year, not a press date.
- `frus1915` — publication 1924 against a manifest coverage-latest of 1928, which §2 shows
  is a bad manifest value; the real documents end 1915-12-31, so the true lag is +9.

**The longest lags** are all retrospective compilations, not late annual volumes:
`frus1917-72PubDip` (covers 1917–1919, published 2014 — a 95-year lag);
`frus1951-54Iran` (63); `frus1961-63v10-12mSupp` (58); `frus1950-55Intel` (51);
`frus1945-50Intel` (46). Four of the five exist to print material — covert action, public
diplomacy — that the contemporaneous volumes left out. **The lag distribution's right tail
is a map of what the series originally suppressed.**

---

## 4. Editorship, and the frontier

`generalEditor` is present on **418 of 552** volumes, naming **23** people. The largest
attributions are Tyler Dennett (66 volumes), Edward C. Keefer (54), John P. Glennon (50),
Adam M. Howard (49), David S. Patterson (37), Glenn W. LaFantasie (34), Gustave A.
Nuermberger (33), S. Everett Gleason (25). The 134 volumes without one are the
nineteenth-century annuals, which were compiled departmentally and carry no named general
editor — itself a marker of the shift from state paper to scholarly edition.

**The series is unfinished, and the shape of the unfinished part is visible.** The latest
coverage year anywhere in the manifest is **1991**. The Reagan block holds 12 volumes
against 27 for Carter's four years and 66 for Nixon–Ford's eight; the Bush block holds one.
At the observed cadence — roughly 5–8 volumes a year through the 2010s, falling to 1–3 a
year since 2019 — the 1981–1992 period is many years from complete. Any statement about
what FRUS "covers" for the 1980s is a statement about a work in progress.

---

## 5. Summary

FRUS is not one publication but three stacked on each other: a **near-contemporaneous
annual state paper** (1861–1951, 290 volumes, published at a median lag of 0–2 years and
running ~740 documents to the volume); an **administration-block scholarly edition**
(1952–1992, 248 volumes, published at a median lag of 32–35 years and running ~350
documents to the volume); and a thin layer of **14 retrospective compilations** that go
back to print what the first two regimes left out, at lags up to 95 years. The 107
subseries labels, the doubling of volume count against the halving of documents per
volume, and the monotone climb of the publication lag from 0 to 35 years are three
independent measurements of the same transformation.

## 6. What this section does not establish

- Nothing here touches the **archival channel**. Which record groups, lot files and
  presidential-library collections these volumes were drawn out of, and which units their
  footnotes point at without printing, are separate questions requiring the bundled
  archival indexes (`collection-usage-index.json` for came-from,
  `external-citation-index.json` for pointed-at) — two channels, never summed.
- `publicationDate` is a **year** for 551 of 552 volumes (only `frus1969-76v32` carries a
  full date, 2010-11-05), so all lags are year-resolution and ±1.
- The manifest's own coverage bounds disagree with the documents in 29 of 552 volumes;
  §2 lists the ten material cases.
