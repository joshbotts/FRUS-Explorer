# Scoping memo — "How did the United States pursue and negotiate rights to build and control an isthmian canal?"

**Run date** 2026-09-06 · **Surfaces used** the SQLite index, the TEI corpus, the bundled JSON.
Working files, scripts and raw reads are all in this directory; `queries.log` holds every
command in order.

---

## 0. Coverage, and the caveat that attaches to every number below

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library is **complete against the 552-volume series** — this is not a partial download, so
nothing below needs the "thin library" flag. Non-apparatus documents: **307,359**
(316,839 − 1,012 front matter − 8,468 editorial notes). Two second editions
(`frus1951-54IranEd2`, `frus1969-76ve15p2Ed2`) are suppressed everywhere below;
`frus1977-80v09Ed2` is kept, having no first edition.

**Controls, run in the same pass as the scan:**

| control | SQL | result |
|---|---|---|
| positive | `MATCH '"Department of State"'` | 98,499 docs / **551** volumes |
| negative | `MATCH 'ZZZ_IMPOSSIBLE_ZZZ'` | **0** docs / 0 volumes |

The scan works. (The positive control reaches 551 of 552 volumes, not all 552 — so a
per-volume absence is worth one check, not an assumption.)

---

## 1. The first thing you need to know: `canal` is a false friend in this corpus

```sql
SELECT volume_id, COUNT(*) n FROM frus_documents WHERE frus_documents MATCH 'canal'
GROUP BY volume_id ORDER BY n DESC LIMIT 5;
-- frus1955-57v16 445 | frus1977-80v29 227 | frus1955-57v17 178 | frus1969-76v22 138 | frus1969-76v23 128
```

The single most canal-dense volume in your library is the **Suez** volume. Corpus-wide,
`MATCH '"Suez Canal"'` returns 1,805 documents against `MATCH '"Panama Canal"'` 1,927 — the two
canals are almost the same size in this corpus. A bare `canal` query is measuring Egypt as much as
Panama, and the contamination reaches into phrases you would think safe:

| phrase | total | also matches `suez` | also matches `panama\|nicaragua\|isthmian` |
|---|---|---|---|
| `"canal zone"` | 1,576 | 185 | 1,168 |
| `"ship canal"` | 79 | 19 | 67 |
| `"canal treaty"` | 688 | 12 | 659 |

`"canal zone"` is the dangerous one: **"Suez Canal Zone"** contains "Canal Zone", and 185 of 1,576
hits co-occur with Suez. It is the standard name for the Anglo-Egyptian base area.

**The formal false-friend test** (share of non-apparatus documents matching, per volume, against
the corpus baseline; `"Department of State"` and `"most favored nation"` as controls):

| term | corpus | frus1903 | frus1912 | frus1977-80v29 | frus1904 | frus1916 |
|---|---|---|---|---|---|---|
| `canal` | 6,727/307,359 = 0.022 | 0.11 | 0.05 | **0.81** | 0.04 | 0.06 |
| `isthmu` | 782/307,359 = 0.003 | 0.09 | 0.02 | **0.00** | 0.03 | 0.00 |
| `"canal zone"` | 1,529/307,359 = 0.005 | 0.00 | 0.02 | 0.20 | 0.02 | 0.01 |
| `concess` (concession) | 17,759/307,359 = 0.058 | 0.06 | 0.03 | 0.06 | 0.03 | 0.05 |
| CONTROL `"Department of State"` | 93,643/307,359 = 0.305 | 0.32 | 0.41 | 0.32 | 0.38 | 0.41 |
| CONTROL `"most favored nation"` | 2,804/307,359 = 0.009 | 0.01 | 0.00 | 0.00 | 0.01 | 0.00 |

Three results, and two of them should change what you search for:

1. **`canal` does discriminate** — 0.022 corpus against 0.81 in `frus1977-80v29`. The controls sit
   flat at their baselines, which is what makes the elevation readable.
2. **`concession` fails the test.** 0.058 corpus, 0.03–0.06 in every on-topic volume. It is at or
   *below* baseline. "Concession" measures the corpus, not this question — it is a nineteenth-century
   diplomatic commonplace (railway, mining, banking). Do not use it as a discriminator; use it only
   as a co-occurrence filter inside an already-canal-bounded set.
3. **`isthmian` / `isthmus` is period-bound vocabulary and would silently lose your largest
   episode.** 0.09 in `frus1903`, **0.00** in `frus1977-80v29`. The Carter-era volume, which holds
   the single biggest concentration of canal documents in the corpus, contains essentially no
   "isthmian". The word in your question is the word of 1899–1914 only.

---

## 2. What the corpus holds

### 2.1 The core set

I built one set and used it throughout, so every number below is re-derivable. The predicate is in
`core_set.sql` and `core_cte.sql`:

```sql
MATCH '"isthmian canal" OR "interoceanic canal" OR "inter oceanic canal" OR "Panama Canal"
    OR "Nicaragua Canal" OR "Nicaraguan Canal" OR "Clayton Bulwer" OR "Hay Pauncefote"
    OR "Hay Herran" OR "Bunau Varilla" OR "Isthmus of Panama" OR "Isthmus of Darien"
    OR "Isthmus of Tehuantepec" OR "canal treaty" OR "canal zone"'
  AND is_front_matter=0 AND is_editorial_note=0
  AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
```

→ **3,241 documents in 327 volumes** (`core_set.tsv`, 3,241 lines, on disk).

This is a recall-oriented boundary, not a topic. It includes Canal Zone labour disputes,
extradition, radio conventions, and the ~185 Suez-contaminated `canal zone` hits. Treat it as the
frame inside which to work, not as the answer.

### 2.2 Where it sits in time

Periodised on `document_dates.date_iso` (the TEI `frus:doc-dateTime-min`), **not** on volume year.
Rate is per 1,000 dated non-apparatus documents in that decade, because the denominators differ by
an order of magnitude.

| decade | canal docs | dated non-apparatus docs | per 1,000 | top volume's share of the numerator |
|---|---|---|---|---|
| 1860s | 43 | 11,250 | 3.82 | frus1866p3 20 of 43 (0.47) |
| 1870s | 65 | 5,798 | 11.21 | frus1879 19 of 65 (0.29) |
| 1880s | 95 | 6,472 | 14.68 | frus1881 28 of 95 (0.29) |
| 1890s | 48 | 9,712 | 4.94 | frus1894app1 9 of 48 (0.19) |
| **1900s** | 186 | 9,924 | **18.74** | frus1903 81 of 186 (0.44) |
| **1910s** | 482 | 30,359 | 15.88 | frus1912 93 of 482 (0.19) |
| 1920s | 281 | 19,733 | 14.24 | frus1923v02 23 of 281 (0.08) |
| 1930s | 263 | 39,196 | 6.71 | frus1935v04 25 of 263 (0.10) |
| 1940s | 447 | 74,043 | 6.04 | frus1946v11 59 of 447 (0.13) |
| 1950s | 415 | 42,296 | 9.81 | frus1952-54v04 70 of 415 (0.17) |
| 1960s | 203 | 27,650 | 7.34 | frus1964-68v31 64 of 203 (0.32) |
| **1970s** | 664 | 22,259 | **29.83** | frus1977-80v29 197 of 664 (0.30) |
| 1980s | 40 | 5,949 | 6.72 | frus1977-80v29 14 of 40 (0.35) |
| pre-1860 | 0 | 462 | 0.00 | — |

9 of 3,241 core documents carry no `date_iso` and fall out of this table.

Read the top-volume-share column before believing a peak. The **1900s** spike is nearly half one
volume (`frus1903`, the Panama revolution). The **1970s** peak is the highest rate in the corpus
*and* is only 0.30 concentrated — the Carter treaty negotiation is genuinely distributed across
`frus1977-80v29`, `frus1969-76v22`, `frus1969-76ve10`, `frus1977-80v24`, `frus1977-80v01`.
The 1870s–80s rate (11–15 per 1,000) is not an artifact either: it is the Grant/Arthur-era
Nicaragua and Darién survey correspondence, spread thinly across the annual volumes.

### 2.3 Volume concentration

Top of `cut -d'|' -f1 core_set.tsv | sort | uniq -c | sort -rn`:

```
211 frus1977-80v29   123 frus1969-76v22    93 frus1912      81 frus1903     70 frus1952-54v04
 69 frus1915          64 frus1964-68v31    63 frus1969-76ve10  59 frus1946v11  53 frus1952-54v09p2
 52 frus1955-57v07    51 frus1917          51 frus1914      51 frus1913     48 frus1977-80v24
 48 frus1941v07       48 frus1916          47 frus1958-60v05mSupp  44 frus1955-57v16  41 frus1940v05
```

`frus1952-54v09p2` and `frus1955-57v16` in that list are **Suez**, not Panama.

### 2.4 The floor: the corpus cannot hold the founding negotiations

The earliest core-set document is **1861-09-07 (`frus1861/d77`, Adams to Seward)**. The series
begins with 1861, so the 1846 Bidlack–Mallarino treaty with New Granada and the 1850
Clayton–Bulwer treaty — the two instruments the whole question turns on — were negotiated before
FRUS existed. They are present only as **retrospective citation**:

| literal (SQL `LIKE`, case-insensitive, over header+dateline+source_note+body_text, apparatus excluded) | docs / vols |
|---|---|
| `%Clayton-Bulwer%` | 50 / 21 |
| `%treaty of 1846%` | 138 / 44 |
| `%New Granada%` | 154 / 59 |
| `%Bidlack%` | **1** / 1 |
| `%Mallarino%` | **2** / 2 |
| `%Wyse Concession%` | 4 / 3 |
| `%Hay-Bunau-Varilla%` | 6 / 4 |
| `%Bryan-Chamorro%` | 35 / 9 |
| `%Chamorro-Bryan%` | 14 / 5 |
| `%Torrijos%` | 414 / 23 |
| `%Dickinson-Ayon%` | **0** / 0 |
| `%Cass-Yrisarri%` | **0** / 0 |

Two of these are zero rows and I checked the query can return rows at all — the same predicate
returns 154 for `%New Granada%`. So the absence of Dickinson–Ayon and Cass–Yrisarri by name is a
real absence from the printed text, not a broken query. Note also that the modern
name **Bidlack** (1 document) is not how this corpus refers to the 1846 instrument; **`treaty of
1846`** (138) and **`New Granada`** (154) are. That is a vocabulary correction worth making before
you search: the corpus names instruments by date and counterpart, historians name them by
negotiator.

---

## 3. The editors' own headings — search these formulas, not your phrasing

I walked all 552 `volume_structures` trees and regexed every `title`/`name`/`label` node for
`canal|isthm|interocean`: **128 headings matched, 127 distinct, 98 isthmian after dropping Suez /
Kiel / Grand Canal / Lynn Canal / Canal de Haro / Baltic / Massena / Huai / Great Lakes / Kaiser
Wilhelm.** The editors use a small set of repeating formulas. Verbatim examples:

- *Nicaraguan canal* (1894, 1896) · *Nicaragua Canal* (1897)
- *Interoceanic canal* (1901, and again 1913–1916, 1923)
- *Treaty between the United States and Great Britain to facilitate the construction of a ship canal* (1902)
- *Correspondence concerning the convention between the United States and Colombia for the construction of an interoceanic canal across the Isthmus of Panama* (1903)
- *Revolution on the Isthmus of Panama and establishment of independent Republic* (1903)
- *Guaranty by United States of transit across the Isthmus of Panama under treaty of 1846* (1902)
- *Transfer of the New Panama Canal Company's property to the United States* (1904)
- *Payment of the canal indemnity* (1904)
- *Panama Canal tolls; exemption of vessels in the coastwise trade* (1912, 1913, 1914)
- *Proposed interoceanic canal treaty between the United States and Nicaragua, and protests of Salvador and Costa Rica in relation thereto* (1913, 1914, 1915 — an explicitly continued series)
- *Chamorro-Bryan Canal Treaty* (1917)
- *Nicaraguan canal survey* (1929)
- *proposed canalization of the San Juan River* (1939)
- *Agreement by the Colombian Government to preliminary reconnaissance of the Atrato–Truando: interoceanic canal route* (1948)
- *Negotiation and Signing of the Panama Canal Treaties, October 6, 1976–September 9, 1977* / *Ratification of the Panama Canal Treaties* (1977-80v29)

Three usable facts fall out of this. (a) **"Interoceanic canal" is the editors' own head-word for
the negotiation, from 1901 through 1948** — it is a better spine for this question than "isthmian".
(b) The 1913–1917 Nicaragua chapter is *explicitly continued volume to volume* ("Continued from
For. Rel. 1915, p. 1104"), so it is one negotiation across five volumes, not five topics.
(c) Two routes besides Panama and Nicaragua are named: **Tehuantepec** and **Atrato–Truando**
(Colombia, 1948). The Atrato route is the one a modern reader will not think to search for.

---

## 4. What I would actually search for, and the literal share of each

House rule (a) and (b): every phrase count below carries its literal share as "N of M", labelled
STRICT and TOLERANT. Surface = `header + dateline + source_note + body_text`, whitespace-collapsed;
**Python `re`, `re.I` — case-INSENSITIVE**, applied to this whole family. STRICT = single spaces
between the words. TOLERANT = each word may take an inflection, separator = any run of space,
hyphen, comma, parenthesis or full stop. Census where M ≤ 300, otherwise an evenly spaced sample of
40 from the (volume_id, document_id)-sorted hit list. Script: `share.py`; results:
`share_results.json`.

| phrase (FTS `MATCH`) | M (docs) | mode | STRICT | TOLERANT | verdict |
|---|---|---|---|---|---|
| `"isthmian canal"` | 108 | census | 108 of 108 (1.000) | 108 of 108 (1.000) | clean |
| `"interoceanic canal"` | 213 | census | 204 of 213 (0.958) | 211 of 213 (0.991) | clean |
| `"ship canal"` | 75 | census | 55 of 75 (0.733) | 75 of 75 (1.000) | clean; strict loses "ship-canal" |
| `"Clayton Bulwer"` | 53 | census | **3 of 53 (0.057)** | 53 of 53 (1.000) | clean; the hyphen is the whole gap |
| `"Hay Pauncefote"` | 39 | census | **0 of 39 (0.000)** | 39 of 39 (1.000) | clean; always hyphenated |
| `"Hay Herran"` | 24 | census | **0 of 24 (0.000)** | 24 of 24 (1.000) | clean; always hyphenated |
| `"Bunau Varilla"` | 51 | census | 15 of 51 (0.294) | 51 of 51 (1.000) | clean |
| `"Nicaragua Canal"` | 32 | census | 31 of 32 (0.969) | 32 of 32 (1.000) | clean |
| `"Nicaraguan Canal"` | 51 | census | 51 of 51 (1.000) | 51 of 51 (1.000) | clean |
| `"Isthmus of Panama"` | 263 | census | 258 of 263 (0.981) | 258 of 263 (0.981) | 5 misses = **"Isthmus of Panamá"**, accented |
| `"canal treaty"` | 674 | sample 40 of 674 | 32 of 40 (0.800) | 32 of 40 (0.800) → **40 of 40 (1.000)** | see below |
| `"Panama Canal"` | 1,872 | sample 40 of 1,872 | 38 of 40 (0.950) | 39 of 40 (0.975) | 1 miss = "Panamá Canal" |
| `"canal zone"` | 1,528 | sample 40 of 1,528 | 40 of 40 (1.000) | 40 of 40 (1.000) | clean |
| `"Panama Canal Company"` | 125 | census | 125 of 125 (1.000) | 125 of 125 (1.000) | clean |
| `"canal tolls"` | 117 | census | 108 of 117 (0.923) | 111 of 117 (0.949) → 117 of 117 | 6 misses = singular "canal toll" |

**Two of these needed a second pass and I am reporting the correction, not the first number.**
`"canal treaty"` looked like the one family below the 0.80 usability floor. I read the misses
before condemning it — every one of the eight is `Canal Treaties`, and my inflection rule allowed
`s/es/ed/ing` but not `y → ies`. Re-run with `\bcanals?[ \-,().]+treat(?:y|ies|ys)\b`:
**40 of 40 (1.000)**, zero misses. Same for `"canal tolls"` — the six misses are the literal
singular `canal toll` / `Canal Toll`, which my plural-anchored pattern could not reach. Both
families are usable; the shortfall was in my regex, not in the corpus.

A 1.000 tolerant share tests the stemmer, not the referent, so I tested the referent separately:
see §1 (`"canal zone"` is 1.000 literal **and** 185 of 1,576 Suez) and §5 (`"canal treaty"` is
1.000 literal and 12 of 688 Suez).

### 4.1 Three places the index will silently under-count, measured

The [TEI] variant census (§6) implied three blind spots. I checked each against SQL:

| what | measurement | consequence |
|---|---|---|
| `inter-oceanic` splits into two tokens | `MATCH '"interoceanic canal"'` = 219; `MATCH '"inter oceanic canal"'` = 39; `LIKE '%inter-oceanic canal%'` = 37; OR of both phrases = **250** | the obvious single query gets **219 of 250** (0.876). Always OR the two. |
| `sea-level` likewise | `frus_documents_vocab` term `sealevel` = **4 docs**; `MATCH '"sea level canal"'` = **120**; `LIKE '%sea-level canal%'` = 79; `LIKE '%sea level canal%'` = 54 | a vocab lookup for the solid form understates the lock-vs-sea-level engineering debate **30-fold** |
| the editors write the 1914 treaty both ways | `Bryan-Chamorro` only 30, `Chamorro-Bryan` only 9, both 5 | querying only the common order gets **35 of 44** (0.795); only the rare order gets **14 of 44** (0.318) |

### 4.2 The search list I would hand you

Spine (highest precision, lowest recall): `"interoceanic canal"` OR `"inter oceanic canal"`,
`"isthmian canal"`, `"ship canal"`, `"Panama Canal"`, `"canal treaty"`, `"Nicaragua Canal"` OR
`"Nicaraguan Canal"`, `"Isthmus of Panama"` (accept `Panamá`), `"Isthmus of Darien"`,
`"Isthmus of Tehuantepec"`, `Atrato` OR `Truando`, `"San Juan River"`, `"sea level canal"`,
`"lock canal"`, `"canal tolls"` (accept the singular).

Instruments and persons, hyphen-insensitive: `Clayton Bulwer`, `Hay Pauncefote`, `Hay Herran`
(accept `Herrán`), `Bunau Varilla`, `Bryan Chamorro` **and** `Chamorro Bryan`, `Torrijos`,
`Linowitz`, `Bunker`.

Do **not** use: bare `canal` (Suez), `concession` (fails the false-friend test), bare `isthmian`
as a period-spanning term (zero in the Carter volumes), or a bare surname (the house rule, and
here `Hay` collides with Spanish *hay*).

---

## 5. What the corpus contains that a modern reader would not predict

- **The tolls fight is bigger than the acquisition.** `"canal tolls"` reaches 117 documents and the
  1912–1914 volumes carry three separate chapters on the coastwise exemption. `frus1912/d756` is
  the Secretary of State's verbatim testimony to the Senate Committee on Foreign Relations,
  **82,893 characters** — the longest thing I retrieved. If the question is "control", tolls is
  where control was contested in public.
- **Nicaragua is not a footnote to Panama.** `817.812` (Nicaragua — Canals) carries **124** documents
  corpus-wide in the came-from channel against 25 for the Canal Zone equivalent, and the
  1913–1917 chapter runs continuously through five volumes with Costa Rica and El Salvador as
  protesting third parties before the Central American Court of Justice.
- **A fourth route.** `Atrato`/`Truando` — 74 occurrences in 17 volumes in the TEI census, with an
  explicit 1948 chapter heading. Colombia, not Panama or Nicaragua.
- **The corpus prints the treaty transmittals themselves.** `frus1901/d233` is the presidential
  message transmitting the second Hay–Pauncefote convention (7,752 characters); `frus1902/d519` and
  `frus1904/d542` carry the header *"By the President of the United States of America."*

---

## 6. [TEI] Variant census — the count the index structurally cannot do

**COUNTING SURFACE: tag-stripped + whitespace-collapsed.** Bytes → strip `<!--…-->` → strip every
`<…>` → collapse `\s+`. **Whole volume files, so apparatus (front matter, abbreviation lists,
footnotes, indexes) IS INCLUDED — I have not separated document text from apparatus in this table
and no density is claimed from it.** 600 file slots, **1,413,683,012 characters**. Ed2 duplicates
skipped in-script. Script `tei_variants.py`; aggregate `tei_variants.json`; chunks
`tei_chunk_*.json`. Occurrences, not documents.

| variant | occurrences | volumes |
|---|---:|---:|
| POSITIVE CONTROL `Department of State` | 175,198 | 587 |
| `Panama Canal` | 4,534 | 261 |
| `Canal Zone` | 4,305 | 198 |
| `canal treaty/treaties` | 1,738 | 77 |
| `Isthmus of Panama/Panamá` | 672 | 80 |
| **`interoceanic` (solid)** | **603** | 67 |
| `sea-level canal` | 488 | 21 |
| `isthmian canal` (any case) | 261 | 37 |
| `Clayton-Bulwer` (hyphen) | 246 | 25 |
| `San Juan River` | 239 | 42 |
| `canal tolls` (any case) | 216 | 36 |
| `Bryan-Chamorro` | 185 | 17 |
| `Nicaragua(n) canal` | 184 | 42 |
| `Hay-Pauncefote` | 141 | 22 |
| `ship canal` | 98 | 40 |
| **`inter-oceanic` (hyphenated)** | **91** | 29 |
| `Bunau-Varilla` | 88 | 13 |
| `lock canal` | 77 | 13 |
| `Atrato`/`Truando` | 74 | 17 |
| `Hay-Herran/Herrán` | 74 | 6 |
| `ship-canal` (hyphen) | 47 | 12 |
| `Chamorro-Bryan` | 47 | 5 |
| `Isthmus of Tehuantepec` | 39 | 22 |
| `Isthmus of Darien/Darién` | 36 | 13 |
| `Panama canal` (lower-case c) | 24 | 17 |
| `Hay-Bunau-Varilla` | 10 | 6 |
| `Clayton Bulwer` (space, no hyphen) | 3 | 3 |
| NEGATIVE CONTROL `ZZZ_IMPOSSIBLE_ZZZ` | **0** | 0 |

Note the note-worthy splits: **hyphenated `inter-oceanic` is 91 of 694 (13%) of that family**;
`ship-canal` is 47 of 145 (32%); the minority name-order `Chamorro-Bryan` is 47 of 232 (20%); and
`Clayton Bulwer` unhyphenated is 3 of 249 (1.2%) — the hyphen is effectively obligatory, which is
why the STRICT share for that phrase was 0.057.

---

## 7. Archival scope — two channels, never summed

### 7.1 Channel: **came-from** (`document_sources`, one row per document)

**2,795 of 3,241** core documents carry a source row.

Citation *form* (`citation_era` is a FORM, not a date — not plotted):
`decimal 1,674 · structured 763 · lot_file 154 · cfpf 85 · published 67 · unrecognized 27 ·
named_series 24 · foreign 1`.

Record groups named: `RG-59 1,809 · 59 211 · 330 46 · 84 25 · RG-84 10 · RG-256 9 · 218 8 ·
**185 6** · 306 4 · 383 2 · 63 1 · 286 1`.

**The single most useful archival fact this run produced.** The State Department decimal file has a
dedicated subject suffix for the thing you are asking about. From
`decimal-class-labels.json` (schemaVersion **1**; the *only* schedule it ships is **1910–1949**,
so I glossed a key only where the **document's own date** falls inside that span, and refused
otherwise). Class-8 subject keys in that file are stored **dotless**:

- **`812` = Canals**
- **`8123` = Tolls**

Applied to the came-from channel corpus-wide:

| key | documents | volumes | gloss |
|---|---|---|---|
| `817.812` | 124 | — | class 8 Internal Affairs of States · country 17 **Nicaragua** · subject 812 **Canals** |
| `811f.812` + `811F.812` | 25 | — | class 8 · country 11F · subject 812 **Canals** |
| `811f.8123` | 3 | — | class 8 · country 11F · subject 8123 **Tolls** |
| `821.812` | 1 | — | class 8 · country 21 **Colombia** · subject 812 Canals |
| `883.812` / `883.8123` | 2 / 1 | — | class 8 · country 83 **Egypt** · Canals / Tolls (Suez — the same shelf grammar) |
| any `*.812` | 161 | 20 | |
| `811F*` (any suffix) | 102 | 17 | |
| `711F*` (any suffix) | 187 | 10 | |

**A correction you must carry: the bundled country table glosses `11F` as "Naos Island". That is
wrong for this purpose, and I disproved it with documents.** The table lists `11C` Porto Rico,
`11D` Guam, `11E` Tutuilla, `11F` Naos Island, `11G` St. John Island — a run of US insular
possessions. But every `811f.812` document I pulled is the **Panama Canal Zone**:

```
frus1912/d658  1911-12-21  The President to Congress          source note: File No. 811f.812/296.
frus1912/d659  1912-07-08  The British Chargé d'Affaires…     source note: File No. 811f.812/300.
frus1912/d662  1912-08-27  The British Chargé d'Affaires…     source note: File No. 811f.812/320.
```

— i.e. the 1912 Anglo-American tolls dispute under Hay–Pauncefote. Likewise `711F.1914` runs
1940-07-03 → 1949-01-18 and is the **Panama defence-sites negotiation** (`frus1940v05/d1159–d1164`,
Secretary of State ↔ Ambassador Dawson in Panama). Read `11F` as the Canal Zone, not Naos Island;
and note that `decimal-class-labels.json` **cannot** compose class-7 keys at all, because `711F.19`
is a country *pair* (Canal Zone–Panama) and the file states class 7's stems only, without the
second country. The `711F.1914` subject digits are ungloassable in this bundle and I have not
guessed them.

The top came-from lots, resolved through `central-files-index.json` (schemaVersion 3, generated
**2026-08-27**, 1,065 `lotFiles` rows) and `series-facts-index.json` (schemaVersion **2** in this
bundle — it has no `legend` key, so it is not the schema-3 shape; `generated` 2026-08-19,
695 rows). Divided lots from `lot-claimants-index.json` (123 rows):

| lot | n (came-from) | RG | NAID | entry | series title | creator |
|---|---:|---|---|---|---|---|
| `78D300` | 33 | 59 | 26309204 | UD-08D 10 | Official and Personal Files of Ambassador at Large Ellsworth Bunker | Office of Ambassador at Large Ellsworth Bunker · incl 1974-1978 · 10 ft 2 in |
| `81F1` | 27 | **84** | 297910144 | UD-23D 59 | Political Program Files | U.S. Embassy, Panama. Political Section · 1964-1977 · 6 ft 2 in |
| `63D351` | 13 | 59 | 2839192 | A1 1586E | Records Relating to NSC Policy Papers | Executive Secretariat · 1947-1979 |
| `81D113` | 11 | 59 | 1487627 | P 14 | Records of Deputy Secretary Warren Christopher | 1975-1981 |
| `84D241` | 10 | 59 | 26309216 | UD-14D 69 | Briefing Books of Cyrus R. Vance | **DIVIDED, 3 claimants** (26309214/26309215/26309216) |
| `62D1` | 10 | 59 | 2838992 | A1 1583E/F | Records Relating to Activities with the NSC | Policy Planning Council · **DIVIDED, 3 claimants** |
| `59D95` | 8 | — | — | — | **not in `central-files-index.json`** | unresolved |
| `57D295` | 8 | 59 | 2108778 | A1 1134 | Reviews of Foreign Operations Missions | ARA/Office of the Assistant Secretary · **DIVIDED, 3 claimants** |
| `60D667` | 7 | 59 | 597824 | A1 1154 | Records Relating to Panama | **Office of Panamanian Affairs** · 1955-1965 · 5 ft 8 in |

### 7.2 Channel: **pointed-at** (`external_citations`, many rows per document)

Read the constraints first: this channel has **no row before 1910-12-06** (I verified —
`SELECT MIN(date_iso)` over the joined table returns exactly that), it stores the citation
*fragment* not the sentence, and it holds lot, library and decimal anchors only. So it is
structurally silent on the entire nineteenth-century and 1901–1910 half of your question.

**495 of 3,241** core documents carry at least one row; **792 rows** in total.

| repository \| collection | rows |
|---|---:|
| Department of State \| (null) | 507 |
| Carter Library \| National Security Affairs | 100 |
| Carter Library \| Presidential Materials | 29 |
| Johnson Library \| National Security File | 23 |
| Nixon Presidential Materials \| NSC Files | 17 |
| Eisenhower Library \| Whitman File | 13 |
| Kennedy Library \| National Security Files | 13 |

Top pointed-at lots: `81F1` 34 · `78D300` 31 · `63D351` 13 · `80F162` 9 · `66D95` 8 · `81D113` 6.
Top pointed-at decimal classes: `641.74` 42 · `611.1913` 25 · `711F.1914` 15 · `719.00` 14 ·
`611.19` 14. Note `641.74` and `611.19*` documents date 1950–1962 and **cannot be glossed** —
outside the only shipped schedule, and the classification was renumbered in 1950, so composing a
reading anyway would return a plausible wrong answer, not a miss.

The two channels overlap in their leaders (`81F1`, `78D300`, `63D351`) but rank them differently
and count different things. **They are not summed anywhere above.**

### 7.3 A corpus-scoping negative, and the series that answers it

FRUS is a selection, and here is what it selected *away*. From `series-facts-index.json`, filtering
creator headings on `panama|isthm|canal`, one heading is named for your question outright:

> **Department of State. Bureau of Inter-American Affairs. Office of Inter-Oceanic Canal
> Negotiations. Office of the Special U.S. Representative for Interoceanic Canal Negotiations.**
> → NAID **2694616**, lot **73D286**, entry **A1 5427**, inclusive **1964–1967**,
> access *Restricted - Partly*, extent *Negligible*,
> series title **"Records Relating to the Negotiations about the Panama Canal"**.
>
> **came-from = 0. pointed-at = 0.** FRUS never cites it, in either channel.

Beside it, from the same filter — NAID 1254407 (`66D329`, `75D414`, `75D457`, `77D14`,
A1 5745, "Records Relating to Panama", Office of the Director for Panama, 1963–1974, 10 ft 1 in)
draws **2 came-from rows and 3 pointed-at rows** across its four lots (`66D329` 0/0, `75D414` 0/1, `75D457` 1/1, `77D14` 1/1) for a ten-foot series; NAID 597824 (`60D667`/`64D67`/`65D176`,
A1 1154, Office of Panamanian Affairs, 1955–1965) is the best-used of the group at 13 came-from
and 10 pointed-at.

And the largest hole is a whole record group. **RG 185, Records of the Panama Canal**, is named by
exactly **6 source notes in the entire 552-volume corpus** — and `central-files-index.json` reaches
only RG 59 (985 lots), 84 (57), 306 (17), 353 (3), 43 (3). RG 185 is **outside the offline stack
entirely**. The construction, operation, tolls administration and Canal Zone government records
are there; FRUS prints the diplomacy about them. For anything about *control* as exercised rather
than negotiated, RG 185 is the next stop and this stack cannot road-map it for you.

Two further reach limits, stated rather than discovered: the offline stack barely reaches before
1940 (the guide's figure is 11 of 695 bundled series), and the pre-1910 canal correspondence sits
in the **1906–1910 Numerical File** and, before that, in the country despatch/instruction series —
`central-files-index.json` carries a `numericalFile` block and a 12-key `countrySeries` block for
exactly this, which I did not exercise beyond confirming they exist.

### 7.4 One instrument that does **not** answer this question

`collection-usage-index.json` (schemaVersion 1, generated 2026-08-19; coverage: 264,464 notes,
552 volumes scanned, 501 with notes, 1,839 of 4,429 authority collections reached) ranks archival
targets **per volume**, and there is no way to narrow it to a document set. Run over the 18
canal-heaviest volumes (16,011 source notes as the denominator), its top class key is
**`812.00` with 1,560 documents** — country 12 is *Mexico*, and that is the Mexican Revolution
inside `frus1912`–`frus1917`, not the canal. For a document-grain question, the `document_sources`
join in §7.1 is the right instrument and this file is not. I am reporting it because the
mis-scoping is easy to make and the output looks authoritative.

---

## 8. Channels I checked and would not lean on

**Subject tags.** The bundled taxonomy (`document-subject-index.json`, 491 subjects) contains
**no Panama Canal or isthmian subject at all**. The only canal subject is **`325 Suez Canal`**
(corpus df 2,178) — and 187 of my 3,241 core documents carry it, which is the tagger string-matching
"canal". A reader browsing by subject would be routed to the wrong canal. Lift over the
corpus baseline (share in core ÷ share among the 238,302 tagged documents) for the top tags:

| subject | in core | corpus df | lift |
|---|---|---:|---:|
| Suez Canal | 187 of 3,241 | 2,178 | 6.31× |
| **Sovereignty** | 463 of 3,241 | 9,883 | **3.44×** |
| Water | 296 of 3,241 | 6,385 | 3.41× |
| **Jurisdiction** | 414 of 3,241 | 9,621 | **3.16×** |
| **Neutrality** | 283 of 3,241 | 7,776 | **2.68×** |
| Labor | 314 of 3,241 | 9,568 | 2.41× |
| Arbitration | 167 of 3,241 | 5,202 | 2.36× |
| Treaties and international agreements | 1,040 of 3,241 | 43,140 | 1.77× |
| War | 896 of 3,241 | 58,480 | 1.13× |
| Peace | 536 of 3,241 | 37,998 | 1.04× |

The generator's own provenance string calls these "**Detected topics from case-insensitive string
matching of subject names and variants, NOT semantic analysis — treat as recall-oriented candidates
rather than ground truth**", so this table is a hint, not evidence. But the hint is a good one:
*sovereignty*, *jurisdiction* and *neutrality* are the three most discriminating non-Suez tags, and
they are precisely the legal architecture the whole question runs on — the Hay–Pauncefote neutrality
rules, the 1903 grant "as if sovereign", the Canal Zone jurisdiction disputes, and Article IV of the
1977 Neutrality Treaty. *War* and *Peace* sit at baseline and tell you nothing.

**Persons.** `person_mentions` covers TEI-tagged mentions only and `person_rollup` under-merges, so
counts are lower bounds. Both defects are visible in the top-15 for the core set: `Torrijos Herrera,
Omar` (134) and `Torrijos Herrera, Omar Efrain` (74) are one man in two rows; so are
`Brzezinski, Zbigniew K.` (109) / `Brzezinski, Zbigniew` (68) and `Vance, Cyrus R.` (166) /
`Vance, Cyrus` (66). More important for scoping: **the entire top-15 is post-1950** — Kissinger 197,
Bunker 172, Vance 166, Carter 147, Torrijos 134, Dulles 110, Brzezinski 109, Nixon 98, Linowitz 75,
Ford 69, Eisenhower 69, Rusk 63. Not one figure from the 1901–1914 episodes appears. Person markup
does not reach the volumes that hold half your question; do not use it to periodise.

**Cross-references.** Restricted to `is_broken = 0`, the most-cited targets from inside the core set
are overwhelmingly **page anchors, not documents** — `frus1904/pg_543` (39 inbound),
`frus1903/pg_375` (19), `frus1923v02/pg_29` (9), `frus1916/pg_849` (9), `frus1912/pg_487` (7).
That is the nineteenth/early-twentieth-century citation idiom (the editors point at a printed page,
not a document number). The only document-keyed targets in the top twelve are modern:
`frus1964-68v31/d367`, `frus1969-76ve10/d555`, `frus1964-68v31/d439`. Also note
`cross_references.reference_type` defaults body references to `'footnote'` and cannot support a
body-vs-footnote split, so I have not attempted one.

---

## 9. Reading accounting

I retrieved **14 documents whole** (captured length == `length(body_text)` for all 14; the SELECT is
`SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE
volume_id=? AND document_id=?`; raw text is on disk in `read_docs/`). I **quoted 3** — the opening
420 characters each of `frus1901/d233`, `frus1903/d321`, `frus1912/d756`, all retrieved in a result
set in this session.

| document | characters | note |
|---|---:|---|
| `frus1901/d233` | 7,752 | presidential message transmitting the second Hay–Pauncefote convention |
| `frus1903/d321` | 44,492 | Hay to General Reyes, 5 Jan 1904 — the US reply to Colombia's "statement of grievances" |
| `frus1903/d326` | 6,342 | Buchanan to Hay, Panama, 25 Dec 1903 (Legation on Special Mission) |
| `frus1912/d756` | 82,893 | Secretary of State's testimony to the Senate Committee on Foreign Relations, 24 May 1911 |
| `frus1912/d658` | 6,344 | The President to Congress · source note `File No. 811f.812/296.` |
| `frus1913/d1310` | 4,806 | Minister of Costa Rica to the Secretary of State · `File No. 817.812/22.` |
| `frus1916/d1255` | 7,275 | By the President of the United States · source note `Treaty series, No. 624` |
| `frus1916/d1101` | 46,375 | (retrieved; Mexican, off-topic — see below) |
| `frus1948v09/d480` | 2,680 | Secretary of State to the Secretary of the Army · `811F.812 Protection/5–2548` |
| `frus1969-76ve10/d541` | 6,321 | NSC memorandum · Nixon Presidential Materials |
| `frus1948v09/d442` | 2,769 | Memorandum of Conversation, Chief of the Division of Central America and Panama Affairs · `811.0141 SW/4–2748` |
| `frus1865p4/d130` | 1,107 | International Committee of the Darien Canal Company (translation) |
| `frus1977-80v29/d1` | 4,642 | headerless |
| `frus1904/d497` | 932 | **my mis-pick** — Gummeré to Hay from Tangier; Morocco, not the canal |

Two of the fourteen (`frus1904/d497`, `frus1916/d1101`) turned out to be off-topic picks made
before I read them. I am listing them rather than quietly dropping them, because they are the
measure of how much of the core set is incidental.

---

## 10. Caveats, in one place

1. **Coverage.** Full 552 volumes; every count is over 307,359 non-apparatus documents with the two
   Ed2 duplicates suppressed. I counted on **this index**, not the vector artifacts; the guide notes
   the Ed2 overlap is 701 documents in this index with apparatus excluded.
2. **`body_text` includes editorial footnotes.** Every SQL frequency above blends the documents'
   language with the editors'. This index cannot separate them — only the TEI can, and §6's TEI
   table does not attempt it either (it includes all apparatus). No density is published anywhere
   in this memo.
3. **`citation_era` is a form, not a date.** Not plotted.
4. **Case sensitivity is stated per family.** SQL `LIKE` (case-insensitive) for §2.4 and §4.1;
   Python `re` with `re.I` for the whole share-check family in §4; Python `re` with explicit
   case-sensitive patterns for the case-variant rows in §6 (`Panama canal` lower-case c).
5. **The two archival channels are never summed.** 2,795 came-from source rows and 792 pointed-at
   citation rows are answers to two different questions over one document set.
6. **The pointed-at channel starts at 1910-12-06** and covers none of the 1846–1910 story.
7. **Decimal glosses are gated.** Only the 1910–1949 schedule ships in this bundle; anything
   outside is left ungloassed rather than composed against the wrong schedule.
8. **`11F ≠ Naos Island`** for this question — disproved against documents in §7.1. Treat NARA and
   NARA-derived attribution as a decoy surface until checked.
9. **What I did not do.** I did not exercise `central-files-index.json`'s `numericalFile` or
   `countrySeries` blocks beyond confirming they exist, did not touch
   `presidential-library-catalog.json` or `digitized-ranges-index.json` (both of which would tell
   you what is already scanned), and did not open the offline NARA harvest — no `[HARVEST]` path
   was given in this brief, so that surface is unavailable to me and no count here is labelled
   from it.

---

## 11. Files on disk in this directory

`core_set.sql` · `core_cte.sql` · `core_set.tsv` (3,241 rows) · `share.py` ·
`share_results.json` · `resolve.py` · `resolve2.py` · `resolve_out.txt` · `gloss.py` ·
`gloss_out.txt` · `usage.py` · `usage2.py` · `usage_out.txt` · `tei_variants.py` ·
`tei_chunk_0_60.json` … `tei_chunk_540_600.json` (10 files) · `tei_variants.json` ·
`read_docs.py` · `read_docs/` (14 `.txt` files, one per document retrieved whole) ·
`queries.log` · `report.md`.

Which file holds which number: the decade table and every SQL count are re-derivable from the
predicates pasted in `queries.log`; the §4 share table is `share_results.json`; the §6 TEI table is
`tei_variants.json`; the §7.1 lot and gloss tables are `resolve_out.txt` and `gloss_out.txt`;
the §7.4 volume-scope ranking is `usage_out.txt`; the §9 reading is `read_docs/`.
