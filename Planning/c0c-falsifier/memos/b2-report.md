# Scoping memo — "How did the United States pursue and negotiate rights to build and control an isthmian canal?"

**Surfaces used:** the SQLite index (`frus-copy.db`), the TEI XML corpus, and the bundled JSON in
`/Applications/FRUS Explorer.app/Contents/Resources/`. Every number below is labelled with the
surface it came from. Working files, scripts and raw document text are in this directory; every
command is in `queries.log`, nothing elided.

## 0. Coverage, and the caveat that qualifies everything

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library holds **552 volumes / 316,839 documents**, of which 1,012 are front matter and 8,468
editorial notes. That is the full published series, so for once the usual "conditional on your
partial library" caveat is nearly vacuous — but it still applies to *this* database, and every count
below is conditional on these 552 volumes. Where I say a thing is absent I mean absent from these
552.

Unless stated otherwise, all DB counts **exclude** `is_front_matter=1` and `is_editorial_note=1`
(denominator 307,359 documents) and suppress `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2`.

**Controls, run in the same pass** ([DB]): `"Department of State"` → 98,499 documents in 551 of 552
volumes; `ZZZ_IMPOSSIBLE_ZZZ` → 0 documents in 0 volumes. ([TEI], separate pass, tag-stripped):
`\bDepartment of State\b` → 177,102 occurrences in 549 of 550 volumes; `ZZZ_IMPOSSIBLE_ZZZ` → 0.
The scans work.

---

## 1. The headline: this corpus is rich on the question, but the word "canal" will ruin your search

Ranking volumes by the bare stem `canal` puts **frus1955-57v16 (445 hits) first, frus1955-57v17
third, frus1969-76v22/23/25 fourth/fifth/sixth**. Those are Suez and the Middle East. A false-friend
test makes it formal ([DB], apparatus excluded):

| term | 10 on-topic volumes | 5 control volumes | whole corpus |
|---|---|---|---|
| `canal` (bare stem) | 957 of 9,953 (0.096) | **414 of 2,247 (0.184)** | 6,727 of 307,359 (0.0219) |
| `"panama canal"` | 575 of 9,953 (0.058) | 12 of 2,247 (0.005) | 1,872 of 307,359 (0.0061) |
| `"isthmian canal"` | 44 of 9,953 (0.004) | 0 of 2,247 (0.000) | 108 of 307,359 (0.0004) |
| `"Department of State"` (control) | 3,883 of 9,953 (0.390) | 928 of 2,247 (0.413) | 93,643 of 307,359 (0.305) |
| `treaty` (control) | 1,518 of 9,953 (0.153) | 371 of 2,247 (0.165) | 45,970 of 307,359 (0.150) |

Bare `canal` is **more common in the control volumes than in the on-topic ones**. It fails the
false-friend test outright: searching it measures the corpus (and mostly Suez), not your question.
`"panama canal"` and `"isthmian canal"` discriminate by an order of magnitude or more. The two
control terms behave as controls should — near-identical shares on both sides.

`"canal zone"` is a subtler trap: its literal share is a perfect 1.000, but that tests the stemmer,
not the referent. Testing the referent on the same evenly spaced 40 of 1,528: **28 isthmian-only,
4 Suez-only, 1 both, 7 neither** — roughly a quarter of it is not your subject (the Suez Canal Zone
of the Anglo-Egyptian negotiations). By contrast `"panama canal"` sampled 40 of 1,872 gives 39
isthmian-only, 1 both, 0 Suez.

## 2. The set I built, and what it cost to build honestly

**Core set: 2,897 documents in 300 of 552 volumes** (`core_set.tsv`), built in two tiers from an
FTS union of 17 phrases (3,400 raw hits), then filtered in Python:

- **Tier A — 2,366 documents, 290 volumes.** The document literally contains one of ten
  isthmian-named phrases (`isthmian canal`, `interoceanic canal`, `panama canal`,
  `nicaragua(n) canal`, `clayton bulwer`, `hay pauncefote`, `bunau varilla`, `isthmus of panama`,
  `panama railroad`).
- **Tier B — 531 documents, 105 volumes.** A generic canal phrase (`canal zone`, `ship canal`,
  `maritime canal`, `canal treaty`, `canal route`, `canal commission`, `canal tolls`) *plus* an
  isthmian word somewhere in the document.
- **Rejected — 488 documents**, generic canal phrase with no isthmian word; **210 of them mention
  Suez**. These are in `rejected_generic.tsv`, not thrown away.
- **Literal-share failures — 15 documents** matched by FTS with no literal form present at all
  (`literal_share_failures.tsv`). Union literal share **3,385 of 3,400 = 0.996 tolerant**.

**I got the Tier-B filter wrong the first time and the fix moved the numbers.** My isthmian-word
regex contained the string `canal zone`, so every Suez *Canal Zone* document satisfied its own
test. Both runs are the same script (`core.py`, before/after `sed`), same decisive line:

| | Tier B docs | Tier B vols | rejected | core set |
|---|---|---|---|---|
| circular filter (`canal zone` in the isthmian-word list) | 890 | 172 | 129 | 3,256 |
| corrected (`panama\|panamanian\|panaman\|isthmus\|isthmian\|nicaragua\|nicaraguan\|darien\|darién\|tehuantepec`) | **531** | **105** | **488** | **2,897** |

### Literal shares for every phrase I publish

Regex over `header + dateline + source_note + body_text`, joined and whitespace-collapsed; Python
`re` with `re.I` (case-**in**sensitive, matching SQLite `LIKE`) for the whole family. STRICT = single
spaces. TOLERANT = inflections allowed, separators `[ \-‐‑‒–—,().]+`. Census when M ≤ 300, else 40
evenly spaced indices.

| phrase | M (docs) | sample | STRICT | TOLERANT |
|---|---|---|---|---|
| `isthmian canal` | 108 | census | 108 of 108 (1.000) | **108 of 108 (1.000)** |
| `interoceanic canal` | 213 | census | 204 of 213 (0.958) | **211 of 213 (0.991)** |
| `panama canal` | 1,872 | 40 of 1,872 | 38 of 40 (0.950) | **39 of 40 (0.975)** |
| `canal zone` | 1,528 | 40 of 1,528 | 40 of 40 (1.000) | **40 of 40 (1.000)** |
| `canal treaty` | 674 | 40 of 674 | 32 of 40 (0.800) | **40 of 40 (1.000)** |
| `isthmus of panama` | 263 | census | 258 of 263 (0.981) | **258 of 263 (0.981)** |
| `panama railroad` | 206 | census | 203 of 206 (0.985) | **203 of 206 (0.985)** |
| `freedom of transit` | 261 | census | 261 of 261 (1.000) | **261 of 261 (1.000)** |
| `new granada` | 152 | census | 152 of 152 (1.000) | **152 of 152 (1.000)** |
| `panama canal company` | 125 | census | 125 of 125 (1.000) | **125 of 125 (1.000)** |
| `canal tolls` | 117 | census | 108 of 117 (0.923) | **111 of 117 (0.949)** |
| `canal commission` | 107 | census | 105 of 107 (0.981) | **107 of 107 (1.000)** |
| `ship canal` | 75 | census | 55 of 75 (0.733) | **75 of 75 (1.000)** |
| `canal route` | 54 | census | 43 of 54 (0.796) | **54 of 54 (1.000)** |
| `clayton bulwer` | 53 | census | **3 of 53 (0.057)** | **53 of 53 (1.000)** |
| `nicaraguan canal` | 51 | census | 51 of 51 (1.000) | **51 of 51 (1.000)** |
| `bunau varilla` | 51 | census | 15 of 51 (0.294) | **51 of 51 (1.000)** |
| `maritime canal` | 45 | census | 44 of 45 (0.978) | **45 of 45 (1.000)** |
| `hay pauncefote` | 39 | census | **0 of 39 (0.000)** | **39 of 39 (1.000)** |
| `article xxxv` | 38 | census | 38 of 38 (1.000) | **38 of 38 (1.000)** |
| `nicaragua canal` | 32 | census | 31 of 32 (0.969) | **32 of 32 (1.000)** |
| `perpetual neutrality` | 29 | census | 17 of 29 (0.586) | **17 of 29 (0.586)** ← UNUSABLE |
| `isthmus of tehuantepec` | 26 | census | 26 of 26 (1.000) | **26 of 26 (1.000)** |
| `new panama canal company` | 23 | census | 23 of 23 (1.000) | **23 of 23 (1.000)** |
| `maritime canal company` | 17 | census | 17 of 17 (1.000) | **17 of 17 (1.000)** |
| `wyse concession` | 4 | census | 4 of 4 (1.000) | **4 of 4 (1.000)** |
| `compagnie universelle` | 4 | census | 4 of 4 (1.000) | **4 of 4 (1.000)** |
| `universal interoceanic canal company` | **0** | — | — | **ZERO ROWS** |

Three things to take from this table.

1. **`perpetual neutrality` is below the 0.80 floor (17 of 29 tolerant) and I have not used it
   anywhere.** Do not search it in this form.
2. **The strict/tolerant gap is the whole story for treaty names.** `hay pauncefote` strict = 0 of
   39; `clayton bulwer` strict = 3 of 53. Nothing is wrong with the FTS hits — the corpus writes
   these hyphenated, and `unicode61` drops the hyphen so the phrase matches anyway. My *first*
   tolerant regex also read 0.795 and 0.943 on these, because its separator class had ASCII hyphen
   but not en dash; modern FRUS volumes use `–`. Adding `‐‑‒–—` took both to 1.000. If you see a
   share near but below 0.80 on a proper-name pair, check your dash class before you condemn the
   family.
3. **A zero is a zero only after you prove the query works.** `universal interoceanic canal company`
   returns no rows; `compagnie universelle` (4) and `new panama canal company` (23) do. De
   Lesseps's company is in the corpus under its French name and its American successor's name, not
   the translated one.

---

## 3. What the corpus actually holds — read the editors' headings first

I walked `volume_structures.structure_json` for all 552 volumes (`headings.py` →
`headings_canal.tsv`, 622 matching headings in 129 volumes). The editors' formulas are repeating and
nothing like modern phrasing. The ones that matter:

- **"Correspondence concerning the convention between the United States and Colombia for the
  construction of an interoceanic canal across the Isthmus of Panama"** — `frus1903`, chapter `ch23`,
  **121 documents**. This is the Hay–Herrán negotiation and its collapse, in one chapter.
- **"Proposed interoceanic canal treaty between the United States and Nicaragua, and protests of
  Salvador and Costa Rica in relation thereto"** — the same title, verbatim, in `frus1913` (14 docs),
  `frus1914` (18), `frus1915` (19), continuing as **"Interoceanic Canal treaty between the United
  States and Nicaragua"** (`frus1916`, **36 documents** — the largest single
  instalment) and **"Chamorro-Bryan Canal Treaty. Suit of Costa Rica and Salvador against Nicaragua
  before the Central American Court of Justice"** (`frus1917`, 2). A five-volume serial run under an
  editors' formula; `frus1916` also carries **"Nicaraguan Canal Route—Convention between the United
  States and Nicaragua"** (8).
- **"Treaties between the United States and the Republics of Panama and Colombia relating to the
  Panama Canal"** — `frus1909` (1), **`frus1910` (49 documents)**, `frus1911` (1). The tripartite
  settlement attempts; almost all of it sits in the 1910 volume.
- **"Negotiation and Signing of the Panama Canal Treaties, October 6, 1976–September 9, 1977"** (95
  docs) and **"Ratification of the Panama Canal Treaties, September 12, 1977–April 18, 1978"** (73
  docs) — `frus1977-80v29`, chapters `ch1` and `ch2`.
- **"Negotiations between the United States and Panama for the revision of the treaty of November 18,
  1903"** — `frus1934v05` (17 documents). The Hull–Alfaro round, named by treaty date, not by
  negotiators — and `Hull-Alfaro` itself returns **zero** occurrences in the TEI (§4).

One false friend lives inside the headings themselves: `frus1916`'s **"Huai River conservancy
project … improvement of the Grand Canal in Kiangsu and Shantung"** (21 documents) and `frus1917`'s
sequel (33) match any canal-word heading scan. They are China, not the isthmus.

**Before 1894 there is essentially no canal-titled chapter.** The nineteenth-century volumes are
organised by country, and the canal correspondence sits inside chapters called *Colombia*,
*Nicaragua*, *Great Britain* under headers like `No. 329. Mr. Blaine to Mr. Lowell.` If you browse
by heading you will conclude the corpus is silent on the formative period. It is not.

### Decade shape ([DB], periodised on `document_dates.date_iso` = `frus:doc-dateTime-min`)

2,889 of the 2,897 core documents carry a date. Rates are per 1,000 **dated, non-apparatus** documents
of that decade, and the top-volume share of the numerator is beside each:

| decade | core docs | dated non-apparatus docs | per 1,000 | top volume's share of numerator |
|---|---|---|---|---|
| 1850s | 1 | 150 | 6.67 | frus1872p2v1, 1 of 1 |
| 1860s | 56 | 11,250 | 4.98 | frus1866p3, 23 of 56 |
| 1870s | 71 | 5,798 | 12.25 | frus1879, 19 of 71 |
| 1880s | 104 | 6,472 | 16.07 | frus1881, 28 of 104 |
| 1890s | 45 | 9,712 | 4.63 | frus1893, 8 of 45 |
| 1900s | 177 | 9,924 | 17.84 | frus1903, 71 of 177 |
| 1910s | 474 | 30,359 | 15.61 | frus1912, 92 of 474 |
| 1920s | 261 | 19,733 | 13.23 | frus1923v02, 23 of 261 |
| 1930s | 238 | 39,196 | 6.07 | frus1935v04, 26 of 238 |
| 1940s | 379 | 74,043 | 5.12 | frus1946v11, 56 of 379 |
| 1950s | 227 | 42,296 | 5.37 | frus1952-54v04, 61 of 227 |
| 1960s | 182 | 27,650 | 6.58 | frus1964-68v31, 60 of 182 |
| **1970s** | **635** | 22,259 | **28.53** | frus1977-80v29, 199 of 635 |
| 1980s | 39 | 5,949 | 6.56 | frus1977-80v29, 14 of 39 |

Two peaks, and they are *not* the same kind of object. The 1900s–1910s peak is spread across many
volumes (frus1903 is only 71 of 177; frus1912 only 92 of 474) — a subject genuinely diffused through
the annual series. The 1970s peak is one volume: `frus1977-80v29` supplies **199 of 635**, and the
1980s row's apparent life is the same volume's tail (14 of 39). Read the 1970s rate as "the
Office of the Historian devoted a volume to this", not as "the archive suddenly filled up".

### Densest volumes (`top_volumes.tsv`)

| volume | core docs | Tier A | Tier B | volume's non-apparatus docs |
|---|---|---|---|---|
| frus1977-80v29 | 213 | 196 | 17 | 276 |
| frus1969-76v22 | 123 | 103 | 20 | 145 |
| frus1912 | 92 | 76 | 16 | 1,868 |
| frus1903 | 71 | 64 | 7 | 836 |
| frus1915 | 70 | 40 | 30 | 1,942 |
| frus1969-76ve10 | 63 | 48 | 15 | 674 |
| frus1952-54v04 | 61 | 35 | 26 | 676 |
| frus1964-68v31 | 60 | 30 | 30 | 505 |
| frus1946v11 | 56 | 43 | 13 | 1,143 |
| frus1914 | 52 | 35 | 17 | 1,888 |
| frus1917 | 52 | 34 | 18 | 1,487 |
| frus1881 | 28 | 28 | 0 | 755 |
| frus1866p3 | 23 | 22 | 1 | 223 |

**72 volumes carry ≥ 10 core documents; 121 carry only 1–2.** `frus1977-80v29` is 213 of its own 276
non-apparatus documents — effectively a monograph. `frus1969-76v22` is 123 of 145. `frus1866p3` at 23
of 223 is the highest early-era density and is worth opening first for the Seward period.

---

## 4. [TEI] Spelling and hyphenation — and a recall gap in my own SQL

The index stores porter stems and `unicode61` drops punctuation, so it cannot answer a variant
question. I scanned all 550 TEI volumes (`teiscan.py`). **Counting surface: tag-stripped
(`<[^>]*>` → space) + whitespace-collapsed**, occurrences not documents.

| variant | occurrences | volumes |
|---|---|---|
| `Clayton-Bulwer` (hyphen/dash) | 246 | 25 |
| `Clayton Bulwer` (space) | 3 | 3 |
| `Hay-Pauncefote` (hyphen/dash) | 141 | 22 |
| `Hay Pauncefote` (space) | **0** | 0 |
| `Hay-Herrán/Herran` (any separator) | 74 | 6 |
| `Bunau-Varilla` (alone) | 125 | 20 |
| `Hay-Bunau-Varilla` | 37 | 13 |
| `Bryan-Chamorro` | 187 | 17 |
| `Chamorro-Bryan` | 47 | 5 |
| `Thomson-Urrutia` | 9 | 3 |
| `Frelinghuysen-Zavala` | **2** | 1 |
| `Dickinson-Ayon/Ayón` | **0** | 0 |
| `Torrijos-Carter` | **0** | 0 |
| `Carter-Torrijos` | 5 | 2 |
| `Remón-Eisenhower` | 1 | 1 |
| `Hull-Alfaro` | **0** | 0 |
| `interoceanic` (solid) | 917 | 85 |
| `inter-oceanic` (hyphenated) | **121** | 41 |
| `isthmian canal` | 258 | 36 |
| `ship canal` / `ship-canal` | 98 / 47 | 40 / 12 |
| `Panama Canal` | 4,524 | 260 |
| `Canal Zone` | 4,303 | 198 |
| `Nicaragua(n) Canal` | 118 | 35 |

**Two consequences.**

**(a) My own `"interoceanic canal"` count was short, and I can quantify it.** `unicode61` splits
`inter-oceanic` into two tokens, so the phrase `"interoceanic canal"` never matches the hyphenated
spelling. Verified in SQL:

```sql
MATCH '"inter oceanic canal"'                              -> 37 documents
MATCH '"inter oceanic canal" AND "interoceanic canal"'     ->  8 documents
MATCH '"inter oceanic canal" OR  "interoceanic canal"'     -> 242 documents
```

29 of 242 documents (12%) hold only the hyphenated form. Against the built core set, adding the
hyphenated and split forms brings in **33 documents not already there** — and the sample is
`frus1861/d300, frus1865p3/d34, frus1866p2/d241, frus1870/d210, frus1871/d276, frus1871/d326,
frus1872p1/d353, frus1872p1/d409, frus1873p1v1/d298, frus1875v01/d118` — i.e. **the gap is
concentrated in exactly the 1861–1875 period the question is most interested in**, where
"inter-oceanic" was the standard orthography. A corrected core set is **2,930 documents**. Treat
2,897 as a floor.

**(b) Do not search FRUS for treaty names historians use.** `Hull-Alfaro`, `Torrijos-Carter` and
`Dickinson-Ayon` return **zero occurrences in 550 volumes**; `Frelinghuysen-Zavala` returns 2 in one
volume. The editors name these instruments by date ("the treaty of November 18, 1903") or by the
reversed pair (`Chamorro-Bryan`, 47 occurrences, is how frus1917's own chapter heading spells what
you would call Bryan-Chamorro). Search the date and the reversed form.

---

## 5. What I would actually search for

**High-precision, use directly:** `"isthmian canal"`, `"interoceanic canal"` **OR** `"inter oceanic
canal"`, `"panama canal"`, `"nicaraguan canal"`, `"clayton bulwer"`, `"hay pauncefote"`,
`"bunau varilla"`, `"isthmus of panama"`, `"isthmus of tehuantepec"`, `"panama railroad"`,
`"maritime canal company"`, `"new panama canal company"`, `"compagnie universelle"`,
`"wyse concession"`, `"freedom of transit"`, `"article xxxv"`, `"new granada"`.

**Use only with an isthmian co-occurrence:** `"canal zone"`, `"ship canal"`, `"canal treaty"`,
`"canal tolls"`, `"canal route"`, `"canal commission"`.

**Do not use:** bare `canal` (fails the false-friend test); `perpetual neutrality` (0.586 tolerant
share); the subject-tag axis (§7); `Hull-Alfaro`, `Torrijos-Carter`, `Dickinson-Ayon` (zero in TEI).

**Search the editors' formulas as phrases** — they are more reliable than any keyword: *"proposed
interoceanic canal treaty between the United States and Nicaragua"*, *"convention between the United
States and Colombia for the construction of an interoceanic canal"*, *"treaties between the United
States and the Republics of Panama and Colombia"*, *"revision of the treaty of November 18, 1903"*.

---

## 6. The nineteenth-century spine, which the headings hide

Sorting the early volumes by date ([DB], full query in `queries.log` §12) gives the negotiating
thread the chapter titles conceal. `"clayton bulwer"` alone runs `frus1861/d77` (Adams to Seward,
1861-09-07) → `frus1867p2/d438` (Dickinson to Seward, 1867-10-22 — the Nicaragua transit treaty) →
`frus1872p2v1/d2` → the Blaine/Frelinghuysen–Granville exchange of 1881–83 (`frus1881/d339`,
`frus1881/d342`, `frus1881/d345`, `frus1882/d203`, `frus1882/d204`, `frus1882/d181`, `frus1882/d182`,
`frus1883/d277`).

I retrieved **9 documents whole** (captured length = `length(body_text)` in all 9; `read.py`,
`read_manifest.json`, text in `docs/`) and **quote 2**. `frus1881/d333` (Blaine to Lowell,
Department of State, 24 June 1881, 12,165 characters) opens the American claim to exclude Europe:

> "the great powers of Europe may possibly be considering the subject of jointly guaranteeing the
> neutrality of the interoceanic canal now projected across the Isthmus of Panama"

and `frus1901/d233` (7,752 characters) is the Senate print of Hay–Pauncefote II with its own
procedural history attached —

> "December 16, 1901.—Ratified; injunction of secrecy removed from proposed amendments and votes
> thereon, and vote of ratification. Amendments appear in italics. Article III was stricken out by
> the Senate."

— which is to say the corpus carries not just the treaty but the Senate's amendments to it. Two
requested ids returned **no row**: `frus1903/d1247` (out of range) and `frus1977-80v29/d1`, which
exists but is `is_editorial_note=1` and is therefore excluded by the standing rule.

**The 1846 foundation is present as cited authority, not as printed text.** The manifest's earliest
coverage is `frus1861` (dateRange.earliest `1860-12-31`), so the Bidlack–Mallarino treaty of 1846 and
the Clayton–Bulwer treaty of 1850 both predate the series. But `"article xxxv"` — the transit and
neutrality guarantee the United States argued from for seventy years — appears in **38 documents**
(1.000 literal share), `"new granada"` in **152 documents across 59 volumes**, and `"new granada"
AND "treaty of 1846"` runs from `frus1866p3/d165` (1865-11-04) through `frus1879/d146`. The
instrument is not printed; the argument over it is, continuously.

---

## 7. Subject tags: unusable here, and the one canal in the vocabulary is the wrong one

2,502 of the 2,897 core documents carry at least one subject ref. But the bundled 491-term
vocabulary (`document-subject-index.json`) contains **exactly one canal**: subject 325, **"Suez
Canal"** (category *Warfare*). There is no Panama, isthmian, Nicaragua or canal-construction subject
at all. The tags are string-matched candidates, not semantic analysis — the artifact's own
provenance says so — and here they cannot express the question.

They are still diagnostic as a *signature*. Enrichment = (core share) ÷ (corpus share):

| subject (category) | core docs | corpus docs | enrichment |
|---|---|---|---|
| Sovereignty (International Law) | 430 | 9,883 | 4.6× |
| Water (Foreign Economic Policy) | 276 | 6,385 | 4.6× |
| Jurisdiction (International Law) | 407 | 9,621 | 4.5× |
| Neutrality (Warfare) | 275 | 7,776 | 3.8× |
| Labor (Foreign Economic Policy) | 285 | 9,568 | 3.2× |
| Treaties and international agreements | 967 | 43,140 | 2.4× |
| War (Warfare) | 778 | 58,480 | 1.4× |

Sovereignty, jurisdiction and neutrality at 4–5× against Treaties at 2.4× and War at 1.4× is a fair
summary of what the canal question *is* in this corpus: a dispute about who exercises which rights
over a strip of another state's territory.

**Cross-references are of little use here.** 2,971 unbroken outbound references from the core set
(2 broken, excluded), but the top targets are page anchors (`frus1904/pg_543`, 40; `frus1903/pg_375`,
19), not documents — these are the annual volumes' internal "see p. 543" apparatus. Only 147 unbroken
references point *into* the core set, 75 of them from outside it.

---

## 8. Archival scope — where these documents came from, and what their footnotes point at

**Two channels, never summed.**

### Channel 1 — CAME-FROM (`document_sources`, one row per document), scope = the 2,897 core documents

**2,438 of 2,897 core documents carry a source row.** Citation *form* (not a date):
decimal 1,423 · structured 703 · lot_file 115 · cfpf 83 · published 65 · unrecognized 27 ·
named_series 22.

Repositories: Department of State 1,621 · Carter Library 260 · National Archives 208 · (null) 114 ·
Nixon Presidential Materials 67 · Johnson Library 47 · CIA 36 · Eisenhower Library 32 · Ford
Library 24 · Kennedy Library 15 · Library of Congress 7 · Reagan Library 2.

**Central-file classes, glossed [JSON] under `decimal-class-labels.json` schedule `1910-1949` and
gated on each class's own document dates** (`decimal_gloss.tsv`):

| class | docs | document dates | gloss |
|---|---|---|---|
| 817.812 | 59 | 1913-04-17 … 1939-10-06 | Internal Affairs of States / **Nicaragua** / **Canals** |
| 819.00 | 45 | 1912-05-20 … 1949-12-03 | Internal Affairs / Panama / Political affairs |
| 819.74 | 41 | 1911-12-11 … 1947-09-03 | Internal Affairs / Panama / Wireless telegraph |
| 819.77 | 33 | 1911-09-20 … 1917-06-16 | Internal Affairs / Panama / Railway |
| 817.51 | 23 | 1912-01-22 … 1928-05-23 | Internal Affairs / Nicaragua / Financial conditions |
| 819.154 | 16 | 1917-04-27 … 1948-10-14 | Internal Affairs / Panama / Roads. Streets. Highways |
| 611.19 | 39 | **1950-07-07 … 1962-11-08** | **NOT GLOSSED — outside 1910–1949** |
| 611.1913 | 18 | **1953-03-16 … 1962-01-19** | **NOT GLOSSED — outside 1910–1949** |

The single most useful key for you is **`817.812` = Nicaragua / Canals**, and its subject suffix
`812 Canals` (with `8123 Tolls` beneath it) is the schedule's own term — so `819.812`, `811F.812`
and their neighbours are the class family to pull.

**Three caveats I will not paper over.** (i) The two `611.*` rows are 1950s–60s documents and the
shipped file carries only the 1910–1949 schedule; the classification was renumbered in 1950, so
composing a gloss there would produce a plausible *wrong* reading, not a miss. I left them blank.
(ii) `811F.504` (52 docs) and `711F.1914` (87 docs) are almost certainly Canal Zone keys in State
Department practice, but **this bundle's country table has 198 entries and no Canal Zone code**; it
glosses lower-case `11f` as *Naos Island*. I am not asserting a Canal Zone reading the shipped
authority does not support — flag these as unresolved. (iii) `schedules[0].subjects['7']` is
**empty**, so every class-7 key (`711.21` = US–Colombia relations, 24 docs; `711.1928`, 33 docs) can
be glossed to the two countries and no further. That is structural, not a parsing failure.

**Lot files → NARA series [JSON]. All 15 top lots resolved** (`lot_resolution.tsv`,
`central-files-index.json` schemaVersion 3, generated 2026-08-27; `series-facts-index.json`
schemaVersion 2 — note this bundle has no `legend` key):

| lot | core docs | NAID | series title | creator | inclusive dates | extent | access |
|---|---|---|---|---|---|---|---|
| **78D300** | 33 | 26309204 | Official and Personal Files of Ambassador at Large Ellsworth Bunker | Dept. of State, Office of Ambassador at Large Ellsworth Bunker | 1974–1978 | 10 ft 2 in | Restricted – Fully |
| **81F1** | 27 | 297910144 | Political Program Files | Dept. of State, U.S. Embassy Panama, Political Section | 1964–1977 | 6 ft 2 in | Restricted – Fully |
| 81D113 | 11 | 1487627 | Records of Deputy Secretary Warren Christopher | Office of the Deputy Secretary | — | — | — |
| 63D351 | 10 | 2839192 | Records Relating to NSC Policy Papers | Executive Secretariat | — | — | — |
| 84D241 | 10 | 26309216 | Briefing Books of Cyrus R. Vance | Office of the Secretary | 1978–1978 | 1 ft | Restricted – Partly |
| **60D667** | 7 | 597824 | **Records Relating to Panama** | Bureau of Inter-American Affairs, **Office of Panamanian Affairs** | 1955–1965 | 5 ft 8 in | Restricted – Partly |
| **80F162** | 4 | 297636345 | Program Files of Ambassador William Jorden | U.S. Embassy, Panama | 1956–1978 | 3 ft 1 in | Restricted – Fully |

If you travel for the 1970s treaty negotiation, **78D300 (Bunker) and 81F1 (Embassy Panama political
section)** are the two to request; they are also the top two lots in the *pointed-at* channel
(below), which is unusual and means the editors both printed from them and cited around them.
**60D667, "Records Relating to Panama" from the Office of Panamanian Affairs, 1955–1965**, is the
one that covers the 1955 Remón–Eisenhower treaty and the 1964 flag riots. Four of the fifteen are
**divided lots** — NARA splits them across several series and `central-files-index.json` stores one
NAID each: 64D563 has **12** claimants, 62D430 has 4, and 84D241, 62D1 and 57D295 have 3 apiece
(`lot-claimants-index.json`). Ask for the claimant list, not the single series.

### Channel 2 — POINTED-AT (`external_citations`, many rows per document), same scope

**630 citation rows from 397 of the 2,897 core documents.** This channel is thin and structurally
late: it has no row anywhere in the database before **1910-12-06**, stores the citation fragment
rather than the sentence, and holds only lot, library and decimal anchors.

Repositories pointed at: Department of State 372 · Carter Library 172 · Johnson Library 35 ·
Eisenhower Library 15 · Nixon Presidential Materials 14 · Ford Library 13 · Kennedy Library 8.
Collections: National Security Affairs 99 · Presidential Materials 29 · National Security File 20 ·
NSC Files 12. Lots pointed at: **81F1 (34)**, **78D300 (31)**, 63D351 (10), 80F162 (9), 81D113 (6).

### The pre-1910 archival hole, which is the main negative finding

```
era        core docs   with came-from row   with pointed-at row
1910+           2435                 2403                  397
pre-1910         454                   35                    0
undated            8                    0                    0
```

**454 core documents are dated before 1910; 35 of them carry any came-from row and none carries a
pointed-at row.** The whole formative negotiation — Seward and Burton on the 1846 treaty, the 1867
Nicaragua transit convention, Blaine and Frelinghuysen against Granville over Clayton–Bulwer, the
Frelinghuysen–Zavala treaty, Hay–Pauncefote — is **archivally unresolved by the offline stack**.
This is the documented limit of the bundled indexes (11 of 695 bundled series reach before 1940),
not evidence that the records are missing.

**And a corpus-scoping negative is not a research negative.** Those despatches were printed from
what is now RG 59 — *Despatches from U.S. Ministers to Colombia / to Central America* and
*Diplomatic Instructions of the Department of State*, the pre-1906 function-separated series, and
after 1906 the Numerical File. Nothing in this database or these bundles will name them for you: the
19th-century FRUS volumes print no source notes at all, which is exactly why the came-from column is
empty. For that period the finding aid, not this index, is the tool.

### A scope warning on `collection-usage-index.json`

I aggregated it over the 72 volumes with ≥ 10 core documents (`collection_usage_scope.tsv`). Its top
rows are Central Files (1,630 docs), Carter Library / National Security Affairs (1,013), Nixon NSC
Files (540) — and its top *class* rows are `812.00` (1,620), `817.00` (826), `837.00` (572), i.e.
Mexico, Nicaragua and Cuba political affairs. **That index is a per-volume aggregate, so scoping it
by volume counts everything those 72 volumes contain, not the canal thread.** Use the document-grain
came-from figures above for the canal question and treat the usage index as a picture of the
volumes' overall archival base. Two channels over one scope are two different numbers; two grains
over one scope are two more.

---

## 9. Honest limits

1. **The core set is a floor, not a census: 2,897 built, 2,930 corrected** once hyphenated
   `inter-oceanic` is admitted, and the 33 additions cluster in 1861–1875.
2. **`body_text` includes editorial footnotes.** Every count in §1–§3 blends document language with
   the editors' twentieth-century annotation. This database can drop front matter and editorial notes
   by column; it **cannot** separate a footnote from a body. No density here is apparatus-separated,
   and where I report a "core document" in a modern volume some share of the match may be an editor's
   note. Separating them is a TEI job I did not do.
3. **Person coverage untested.** I ran no person queries: `person_mentions` is TEI-tagged only and
   uneven, `person_rollup` under-merges, and bare surnames (Hay, Blaine, Bunker) are unusable. Any
   negotiator-centred pass needs full-name and inverted forms, checked per volume.
4. **`citation_era` is a form, not a date** — I used it only as a form, and periodised on
   `document_dates.date_iso` throughout.
5. **The 1970s spike is one volume.** 199 of 635 documents in that decade are `frus1977-80v29`. A
   rate is not a discovery when a single editorial decision produced it.
6. **Nothing here is thin enough to be an artefact of a partial library** — this database holds all
   552 volumes — but the pre-1910 archival emptiness *is* an artefact of the bundled indexes' reach,
   and should never be reported as an archival absence.

## 10. One correction to this memo, made before you read it

My first draft gave `frus1910`'s tripartite-treaty chapter as 17 documents and `frus1916`'s
Nicaragua canal-treaty chapter as 21. Both were wrong: I had read counts off a truncated column, and
21 and 33 actually belong to `frus1916`/`frus1917`'s **Huai River / Grand Canal** chapters, which are
China. The decisive check, run over the same `headings_canal.tsv` both sides, is in `queries.log`
§21. Corrected figures: frus1910 = **49**, frus1916 = **36**, frus1917 Chamorro-Bryan = **2**,
frus1934v05 = **17**.

## 11. Files

`core_set.tsv` (2,897 rows, tier-labelled) · `rejected_generic.tsv` (488) ·
`literal_share_failures.tsv` (15) · `headings_canal.tsv` (622) · `decade_table.tsv` ·
`top_volumes.tsv` (300 volumes) · `share_family1.json` `share_family2.json` `share_family3.json` ·
`tei_variants.json` + `teiscan_ckpt.json` · `decimal_gloss.tsv` · `lot_resolution.tsv` ·
`collection_usage_scope.tsv` · `class_usage_scope.tsv` · `subject_tags.tsv` ·
`read_manifest.json` + `docs/*.txt` (9 documents, full text) · scripts `headings.py` `share.py`
`share2.py` `core.py` `decade.py` `topvols.py` `falsefriend.py` `read.py` `archival.py` `gloss.py`
`gloss2.py` `lots.py` `usage.py` `teiscan.py` · `queries.log`.
