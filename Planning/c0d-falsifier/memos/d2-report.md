# Scoping memo — "How did the United States negotiate and administer international postal conventions?"

**Surfaces used:** the SQLite index (all counts below unless marked), and the bundled JSON in
`/Applications/FRUS Explorer.app/Contents/Resources/`. **I did not touch the TEI XML.** Nothing
below is a spelling-variant census, a counting-surface figure, or an apparatus/body split — where
the question needed one, I say so and stop rather than answering it in SQL.

**Coverage, and it conditions every number here.**

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library is the whole published series — 552 volumes, 316,839 documents, of which 307,359 are
non-apparatus (`is_front_matter=0 AND is_editorial_note=0`), the denominator for every share below.
So thinness in what follows is a property of FRUS, not of your download. Nothing here is
partial-library thin.

**Controls, same pass.** Positive `"Department of State"` → 93,643 documents in 551 of 552 volumes.
Negative `ZZZ_IMPOSSIBLE_ZZZ` → 0. The scan works. (One volume has no non-apparatus
"Department of State"; I did not chase which.)

---

## 1. The headline

**FRUS documents the *administration* of postal relations reasonably well and the *negotiation* of
postal conventions almost not at all — and there is a documented reason, printed inside the corpus
itself.** The Postmaster General, not the Secretary of State, concluded these instruments.
`frus1947v01/d20` (Paper Prepared in the Office of Special Political Affairs, 5 March 1947 —
retrieved whole, 6,895 characters) says it in so many words:

> "by Act of 1872 and again in 1934 the Congress authorized the Postmaster General, with the
> approval of the President, to conclude postal treaties or conventions. (17 Stat. 304 and 48 Stat.
> 943). Pursuant to this authorization the Postmaster General concluded in 1874 the Treaty
> concerning the formation of a General Postal Union"

That single sentence explains the shape of everything below, and it is the document I would open
this project with. It is not in a postal chapter — it is in a 1947 legal memorandum about what
counts as a treaty.

The consequence is measurable. The Bern congress that founded the General Postal Union met in
October 1874. In `frus1874`, **7 non-apparatus documents contain the stem `postal` and not one of
them contains the phrase "General Postal Union"** (1 more in that volume's apparatus). The corpus's
first use of the phrase is `frus1875v02/d356`, Beardsley to Fish from Egypt, 4 February 1875 —
reporting a foreign government's accession, not an American negotiation. FRUS did not print the
founding of the Universal Postal Union because State did not negotiate it.

---

## 2. What to search for — and what not to

### 2a. The editors' own headings almost never name this subject

I walked `volume_structures` for every section title in all 552 volumes matching
`post(al|age|s)?\b|\bmail` (script: `headings.py`, output: `headings.txt`; 118 titles matched, then
filtered by hand for the Latin `post,` "below" false friend and for mail-steamer incidents).

**In 552 volumes, exactly two chapter headings name the postal-union machinery, and both are in one
volume:**

- `frus1898` — "Circulars to the United States legations—International Postal Congress" (1 doc)
- `frus1898` — "Postal Union, adhesion of Great Britain to" (1 doc)

Every other postal-ish heading is a *different question*: mail censorship and interference
1914–1918 and 1939–1941 (the largest block by far — `frus1916Supp` "Interference with the mails by
belligerent governments", 37 documents), air-mail route contracts 1928–1929, second-class mail into
Iran 1936–1937, and POW relief mail to Japanese-held territory 1943–1945.

Caveat you should hold against that finding: subject-style chapter headings only appear from the
mid-1890s. The 1861–1893 volumes are organised by *country*, so heading-scanning structurally
cannot find a postal chapter there even if the documents exist — and they do (§2b). Read this
result as "the editors never compiled a postal-convention chapter," not as "the material is absent."

### 2b. Phrase families, with the literal share every one of them owes

The index is porter-stemmed, so a phrase `MATCH` returns inflections and near-stems. Every count
below is paired with a **census** (not a sample — every set is under 300) of the literal share over
`header + dateline + source_note + body_text`, whitespace-collapsed, using **Python `re` with
`IGNORECASE`** (one engine for the whole family; the SQL `LIKE` probes elsewhere in this memo are
separately labelled). STRICT = single spaces, exact words. TOLERANT = each word allowed its
inflections (including `treaty`/`treaties`), separated by any run of space, hyphen, comma,
parenthesis or full stop. Scripts: `share.py`, `share2.py`; results: `share-results.json`,
`share2-results.json`.

| MATCH phrase | docs | vols | TOLERANT share | STRICT share |
|---|---:|---:|---|---|
| `"postal union"` | 105 | 62 | **105 of 105 = 1.000** | 105 of 105 = 1.000 |
| `"Universal Postal Union"` | 67 | 40 | **67 of 67 = 1.000** | 67 of 67 = 1.000 |
| `"postal convention"` | 95 | 51 | **95 of 95 = 1.000** | 83 of 95 = 0.874 |
| `"parcel post"` | 125 | 65 | **125 of 125 = 1.000** | 99 of 125 = 0.792 |
| `"postal service"` | 201 | 112 | **201 of 201 = 1.000** | 169 of 201 = 0.841 |
| `"Postmaster General"` | 273 | 128 | **273 of 273 = 1.000** | 209 of 273 = 0.766 |
| `"Post Office Department"` | 186 | 87 | **185 of 186 = 0.995** | 138 of 186 = 0.742 |
| `"money order"` | 91 | 60 | **91 of 91 = 1.000** | 35 of 91 = 0.385 |
| `"postal treaty"` | 21 | 16 | **21 of 21 = 1.000** | 16 of 21 = 0.762 |
| `"postal arrangement"` | 18 | 14 | **18 of 18 = 1.000** | 3 of 18 = 0.167 |
| `"postal agreement"` | 10 | 10 | **10 of 10 = 1.000** | 8 of 10 = 0.800 |
| `"postal congress"` | 5 | 5 | **5 of 5 = 1.000** | 5 of 5 = 1.000 |
| `"General Postal Union"` | 5 | 4 | (not censused) | — |
| `"postal card"` | 25 | 19 | (not censused) | — |
| `"postal rates"` | 19 | 17 | (not censused) | — |

No family falls below the 0.80 tolerant floor, so all are usable in their published form. But note
what the strict column is telling you: for `money order` (0.385) and `postal arrangement` (0.167),
the *plural* is the corpus's normal form — search `money orders` and `postal arrangements` if you
go to a plain-text tool that does not stem.

**One correction I am flagging because it changes a published number.** My first pass reported
`postal treaty` at TOLERANT 16 of 21 = 0.762 and would have condemned the family as unusable. That
was wrong: my tolerant regex allowed only `-s`/`-es`, so every miss was the word *treaties*. All
five misses (`frus1866p3/d201`, `frus1875v01/d17`, `frus1903/d333`, `frus1914-20v01/d282`,
`frus1947v01/d20`) are the referent, read in a KWIC window before I changed anything. Corrected:
21 of 21 = 1.000. The one genuine tolerant miss anywhere in the table is
`frus1958-60v16/d56` for `Post Office Department`.

**A 1.000 share tests the stemmer, not the referent, so I tested two referents separately.**

- **`money order` is 0.659 on-referent.** Only **60 of 91** documents put a
  `money orders?` occurrence within 120 characters of `postal|post.office|mail|postmaster`.
  The other 31 are banking and consular remittances. Filter, don't count raw.
- **`Postmaster General` is 0.154 on-referent, and this is the trap of the whole topic.** Only
  **42 of 273** documents put a `Postmaster.General` occurrence within 200 characters of
  `convention|treaty/treaties|postal union|congress|agreement`. See §3.

### 2c. False-friend test: drop "convention"

The question hands you the word *convention*. It fails.

`convention` corpus-wide (non-apparatus): **17,473 of 307,359 = 5.7%**. Inside five on-topic
volumes: `frus1875v01` 34 of 308 (11.0%), `frus1878` 49 of 550 (8.9%), `frus1951v02` 48 of 824
(5.8%), `frus1898` 43 of 1,196 (3.6%), `frus1934v03` 26 of 749 (3.5%). **At or below the corpus
baseline in three of five.** Searching `convention` measures the corpus, not the question. Stop
using it alone.

The control passes: `postal` corpus-wide is **1,230 of 307,359 = 0.4%**, and in those same five
volumes runs 2.1× to 9.7× baseline (`frus1934v03` 29 of 749 = 3.9%). `postal` is the discriminating
token; every phrase family above is anchored on it or on `Postmaster`/`Post Office`.

---

## 3. The decoy you must know about before you read a hit list

45 documents in 15 volumes have a header naming a Postmaster General
(`header LIKE '%Postmaster General%'`, non-apparatus). **Fifteen of those 45 are in `frus1941v04`,
and fourteen of the fifteen contain no postal word at all** — not `postal`, not `post office`, not
`mail` (SQL `LIKE`, case-insensitive):

```sql
SELECT document_id, length(body_text),
  CASE WHEN body_text LIKE '%postal%' OR body_text LIKE '%post office%' OR body_text LIKE '%mail%'
       THEN 'POSTAL-WORD' ELSE 'no-postal-word' END
FROM document_cache WHERE volume_id='frus1941v04'
  AND header LIKE '%Postmaster General%' AND is_front_matter=0 AND is_editorial_note=0;
-- 15 rows; only d43 is POSTAL-WORD
```

That is Frank Walker acting as a private channel in the 1941 Japanese talks — the volume also
carries "Bishop James E. Walsh to the Postmaster General (Walker)". It is the single largest
concentration of Postmaster-General documents in FRUS and it is not about the post office.
Combined with the 42-of-273 referent share in §2b, treat `"Postmaster General"` as a **retrieval
aid, never a count**.

The genuine interagency correspondence — State ↔ Post Office Department on postal business — is
smaller and legible, and it is where your "administer" question actually lives:

- `frus1911/d488`, `frus1911/d492` (Secretary ↔ Postmaster General)
- `frus1914Supp/d859`, `frus1915Supp/d1042`, `/d1043`, `/d1051`, `/d1130`, `/d1133`,
  `frus1916Supp/d795`, `/d797`, `/d799`, `frus1918Supp02/d1`, `/d468`, `/d469` (Burleson, wartime
  mail censorship — including two Postmaster General **Orders**, 211 and 212)
- `frus1928v03/d261`, `frus1929v01/d437`, `/d440`, `frus1931v02/d658` (air-mail contracts; note
  the Second Assistant Postmaster General writes to the *Chief of the Division of Latin American
  Affairs*, i.e. desk-to-desk, not principal-to-principal)
- `frus1934v03/d164`, `/d173`, `frus1936v03/d467`, `/d468`, `/d469`, `/d470` (Farley/Howes/Purdum)
- `frus1964-68v05/d124`, `frus1964-68v06/d161` (O'Brien to LBJ)
- `frus1915Supp/d1041` is the only document whose header names the Post Office Department itself.

`frus1934v03/d173` (Acting Postmaster General Eilenberger to the Secretary of State, 11 July 1934;
retrieved whole, 2,930 characters) is a good type case of the administrative channel — the two
departments settling who owes whom transit charges for mail crossing "Manchukuo", with the League of
Nations waiting on the answer.

---

## 4. The chronology, with rates

Periodised on **`document_dates.date_iso`** (the editorial `frus:doc-dateTime-min`), *not* on the
volume's series year. Family = the six-phrase negotiation core
(`"postal convention" OR "postal union" OR "postal treaty" OR "postal congress" OR "postal arrangement" OR "postal agreement"`),
non-apparatus: **221 documents in 105 of 552 volumes**, of which 216 carry a date.

| decade | hits | dated non-apparatus docs | per 1,000 | top volume (its share of the numerator) |
|---|---:|---:|---:|---|
| 1850s | 1 | 150 | 6.67 | frus1879 (1 of 1) |
| 1860s | 26 | 11,250 | 2.31 | frus1863p2 (6 of 26) |
| **1870s** | **30** | **5,798** | **5.17** | frus1871 (5 of 30) |
| 1880s | 16 | 6,472 | 2.47 | frus1887 (4 of 16) |
| 1890s | 7 | 9,712 | 0.72 | frus1893 (3 of 7) |
| 1900s | 21 | 9,924 | 2.12 | frus1904 (4 of 21) |
| 1910s | 29 | 30,359 | 0.96 | frus1912 (3 of 29) |
| 1920s | 10 | 19,733 | 0.51 | frus1924v01 (2 of 10) |
| 1930s | 21 | 39,196 | 0.54 | **frus1934v03 (10 of 21)** |
| 1940s | 17 | 74,043 | 0.23 | frus1946v04 (3 of 17) |
| 1950s | 24 | 42,654 | 0.56 | **frus1951v02 (8 of 24)** |
| 1960s | 2 | 27,650 | 0.07 | frus1964-68v16 (1 of 2) |
| 1970s | 12 | 22,641 | 0.53 | frus1969-76v05 (3 of 12) |
| 1980s | 0 | 5,949 | 0.00 | — |

Read the rate column, not the raw column: the **1870s are the peak by a factor of two** (5.17 per
1,000 against a 0.23–2.5 range elsewhere), and the 1850s "6.67" is a single document. The two
decades whose raw counts look respectable — 1930s and 1950s — are each carried by one volume
(10 of 21 and 8 of 24). Those two volumes are where the concentrated material is:

- **`frus1934v03`** — Wilson at Geneva, the Advisory Committee on the Far Eastern situation, and
  whether the US postal administration may exchange mails with "Manchukuo" without recognising it.
  Ten documents, April–December 1934.
- **`frus1951v02`** — the UPU and Chinese representation. `frus1951v02/d181`
  (Secretary of State to Certain Diplomatic Offices, circular airgram to 20 American-republic
  embassies, 3 April 1951; retrieved whole, 3,097 characters) sets it out: the UPU Director General
  is polling every member's *postal administration* by ballot returnable to Bern by 20 April on
  whether National China or Communist China is represented. That is a Cold War vote-counting
  operation conducted through post offices, and it is the best-documented single postal episode in
  the corpus.

The 1969–76 tail (`frus1969-76v05/d435`, `/d441`, `/d447`, October–November 1971) is the same
question a generation later — the specialized agencies after the UN seating change.

---

## 5. The archival channels — and the one search that changes the project

House rule, and it matters here: `document_sources` (where a printed document **came from**, one
row per document) and `external_citations` (what a footnote **points at**, many rows per document)
are two different numbers over one scope. I never sum them.

### 5a. Came-from, over the 221-document core

119 of the 221 carry a source row at all; the other 102 are 19th-century volumes, which print no
source notes. Of the 119: decimal 92, structured 10, unrecognized 7, published 3, CFPF 3,
named_series 2, lot_file 2. Only four lot files appear across the whole core (`M88`, `82D103`,
`81F1`, `60D224`) — this topic is a **central-files** topic, not a lot-file topic.

### 5b. The finding: State had a file number for the post, and it is not the word "postal"

The decimal classes in that came-from list (`841.711`, `891.711`, `893.711`, `893.71`) resolve
against the bundled `decimal-class-labels.json` (schedule `1910-1949`, 9 classes, 198 countries,
692 class-8 suffixes; source: *RG 59 Department of State Classification of Correspondence, August
1910 – December 1949*). Under class **8 — Internal Affairs of States**:

| suffix | gloss |
|---|---|
| `.71` | Post |
| `.711` | Laws and regulations |
| `.712` | Concessions. Contracts. Subsidies |
| `.713` | Rates. Postage |
| `.715` | Parcel post |
| `.716` | Money orders |
| `.717` | Postal savings banks |
| `.718` | Complaints against service |
| `.71A` | Postal adviser |
| `.71086` / `.7111` / `.7112` | Tampering with mail / Fraudulent use of mail / Unmailable matter |

So `841.711` is *Great Britain — post — laws and regulations*, `893.71` is *China — post*.
**Searching by file number finds documents the word-search misses, and the two barely overlap:**

```sql
WITH dec AS (SELECT s.volume_id v, s.document_id dd FROM document_sources s
   JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id
   WHERE d.is_front_matter=0 AND d.is_editorial_note=0
     AND s.decimal_class GLOB '[0-9][0-9][0-9].71*'),
 txt AS (SELECT f.volume_id v, f.document_id dd FROM frus_documents f
   JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
   WHERE frus_documents MATCH 'postal' AND d.is_front_matter=0 AND d.is_editorial_note=0)
SELECT (SELECT COUNT(*) FROM dec), (SELECT COUNT(*) FROM txt),
       (SELECT COUNT(*) FROM dec JOIN txt USING(v,dd));
-- 504 | 1230 | 116
```

**504 documents are filed under a `.71` number; 1,230 contain the stem `postal`; only 116 are
both.** Roughly 388 documents printed out of a postal file never say the word.

Two refinements, because the glob is broader than the schedule:

- **Glossable (class 8, `8XX.71*`): 325 documents in 46 volumes.** Top classes: `841.711` (107),
  `893.711` (47), `811.711` (24, US internal post), `893.71` (19), `837.711` (18, Cuba),
  `891.711` (17, Iran), `851.711`/`852.711` (Italy/Spain). Top volumes: `frus1916Supp` 33,
  `frus1918Supp01v02` 26, `frus1914Supp` 20, `frus1939v02` 16, `frus1934v03` 16.
  484 of the 504 fall inside the schedule's own 1910–1949 span, so the gloss is in-range.
- **Not glossable: 179 documents in 37 volumes** carry a `.71` suffix under classes 1, 6 or 7
  (`125.7146`, `611.7131`, `711.71`, `761.71`). This shipped schedule glosses only classes 6 and 8
  (and class 6 has exactly one suffix), and it lists `6,7,8` as country-arranged. **I did not gloss
  these and you should not either** — the classification was renumbered in 1950 and composing
  outside the table returns a plausible wrong reading, not a miss.

Note the shape of `8XX.71`: class 8 is *Internal Affairs of States*, so this channel documents the
United States watching **other countries' postal administrations** — which is exactly the
"administer" half of your question, and exactly *not* the bilateral-convention half. Bilateral
instruments would sit in class 7, and the schedule cannot gloss class 7's suffixes.

### 5c. The file series named for the Union

```sql
SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM document_sources WHERE decimal_class = '399.10-UPU';
-- 20 | 1
```

**Twenty documents, all in `frus1951v02`, all filed `399.10 UPU`** — a decimal designator naming the
Universal Postal Union outright (`399.10– UPU /1–1551` through `/4–1351`, January to April 1951:
`frus1951v02/d138` through `/d156`, plus `/d179`, `/d180`, `/d181`). If you request one thing from
NARA on this topic, request that file.

*Method note:* my first attempt used `raw_text LIKE '%UPU%'`, which is case-insensitive in SQLite
and returned three false hits — "s**crupu**lous", "s**crupu**lously", and the Cypriot name
"Urg**upu**lu". The 20 is from the anchored `decimal_class = '399.10-UPU'`.

### 5d. Pointed-at, and its floor

`external_citations` holds **62 citations across 52 documents** to a `[0-9][0-9][0-9].71*` class
(top: `611.71` 6, `651.71` 5, `761.71` 5, `661.7131` 4, `893.711` 4). Before you rank anything on
this channel: it has **no row earlier than 1910-12-06** (verified), stores the citation fragment
rather than the sentence, and holds only lot, library and decimal anchors. It is silent for the
entire 1861–1910 half of this topic, which is the half where the negotiation happened.

### 5e. The archival negative — and the answer it obliges

**RG 28 (Records of the Post Office Department) and RG 43 (International Conferences, Commissions,
and Expositions) appear zero times in this corpus, in either channel.**

```sql
-- positive control                                            -- 12259 (came-from), 781 (pointed-at)
SELECT COUNT(*) FROM document_sources WHERE raw_text GLOB '*RG 59[^0-9]*' OR raw_text GLOB '*RG 59';
-- negative control                                            -- 0
SELECT COUNT(*) FROM document_sources WHERE raw_text GLOB '*RG 99999[^0-9]*';
-- RG 28                                                       -- 0
SELECT COUNT(*) FROM document_sources WHERE raw_text GLOB '*RG 28[^0-9]*' OR raw_text GLOB '*RG 28';
-- RG 43                                                       -- 0
SELECT COUNT(*) FROM document_sources WHERE raw_text GLOB '*RG 43[^0-9]*' OR raw_text GLOB '*RG 43';
```

*Method note, because it nearly cost me the finding:* I first wrote `[!0-9]`. SQLite's GLOB negates
with `^`, not `!`, so `[!0-9]` is the literal character set `{!,0-9}` — it reported 97 for RG 28
(all of them "RG 286", USAID) and **0 for the RG 59 positive control**. The failing control is what
exposed the broken predicate. The corrected numbers are above.

Corroborating the same absence from three more surfaces:

- `volume_sources` (the volumes' own front-matter source lists, 33,764 rows): **0** entries whose
  text names `postal` or `Post Office`; record groups present are 59, 330, 84, 306, 218, 56, 383,
  286, 273, 40, 429, 319, 472, 334, 46, 263, 63, 469, 374, 364 — no 28, no 43.
- **[JSON]** `series-facts-index.json` (schemaVersion **2**): 695 series, 397 creator headings —
  **0** headings match `postal|post office`.
- **[JSON]** `collection-authority.json`: 4,429 collections — **0** match `postal|post office`.

**So: a corpus-scoping negative, and here is the series that answers it.** The instruments
themselves and the American delegation records to the UPU congresses (Bern 1874, Paris 1878, Lisbon
1885, Vienna 1891, **Washington 1897**, Rome 1906, Madrid 1920, Cairo 1934, Paris 1947 …) are in
**RG 28, Records of the Post Office Department** — the department that, per `frus1947v01/d20`, held
the negotiating authority — and delegation/conference files in **RG 43**. Neither is in this app's
offline stack, so I cannot resolve either to a series NAID from here and I am not going to guess
one. Two things I *can* tell you from the bundled data: the offline stack reaches almost nothing
before 1940 anyway, and the 1897 Washington congress in particular is a US-hosted event whose
records will not be in State's central files. Treat that as the next research step, not as a
finding.

**[JSON] corroboration of the decimal counts.** `collection-usage-index.json` (schemaVersion 1;
coverage: 264,464 notes, 552 volumes scanned, 501 with notes) independently reproduces §5b exactly:
32 class keys matching `^8\d\d\.71`, **325 documents**, same top volumes (`frus1916Supp` 33,
`frus1918Supp01v02` 26, `frus1914Supp` 20), and `399.10-UPU` at **20**. Two surfaces built by
different routes agree to the document. Aggregation script output kept at
`usage-class8-postal.json`.

---

## 6. What I would actually search, in order

1. **`frus1947v01/d20`** first — it is the constitutional key and it reframes the question.
2. The **six-phrase negotiation core** (§4), 221 documents in 105 volumes, then read the two
   concentrated volumes whole: `frus1934v03` (Manchukuo mail, 1934) and `frus1951v02` (UPU and
   Chinese representation, 1951).
3. The **1870s seam** by hand — it is the corpus's own peak (5.17 per 1,000) and it is scattered
   one document per country chapter: `frus1871/d4` ("[Report of the Postmaster General.]"),
   `frus1871/d121`, `/d189`, `/d218`, `/d268`; `frus1874/d62`, `/d234`; `frus1875v01/d17`, `/d73`,
   `/d114`, `/d124`, `/d193`; `frus1875v02/d213`, `/d356`; `frus1877/d48`, `/d50`, `/d52`, `/d114`;
   `frus1878/d7`, `/d13`, `/d30`, `/d57`, `/d257`; `frus1879/d19`, `/d189`, `/d213`, `/d471`.
4. The **file-number channel** — `document_sources.decimal_class GLOB '8[0-9][0-9].71*'`, 325
   documents in 46 volumes, of which only 116 of 504 overlap the word `postal` at all.
5. The **interagency channel** — the 45 Postmaster-General headers minus the 15 `frus1941v04`
   decoys (§3).
6. **`399.10-UPU`** as an archival request, not a search.

Vocabulary to carry into any non-stemming tool: *postal convention(s)*, *postal treaty/treaties*,
*postal arrangement**s***, *postal union*, *General Postal Union*, *Universal Postal Union*,
*International Postal Congress*, *parcel(s) post*, *money order**s***, *postal card*, *Bern/Berne*,
*Postmaster General*, *Post Office Department*, *postal administration*. Drop *convention* alone
(§2c). The glossary table confirms **UPU** is the corpus's own abbreviation, defined in 11 volumes
(`frus1949v07p1`, `frus1949v07p2`, `frus1950v02`, `frus1951v02`, `frus1951v04p1`, `frus1951v04p2`,
`frus1952-54v03`, `frus1961-63v17`, `frus1961-63v18`, `frus1961-63v20`, `frus1961-63v25`,
`frus1964-68v30`, `frus1969-76v05`), and it introduces **CEPT** (European Conference of Postal and
Telecommunications Administrations) in `frus1961-63v25`.

---

## 7. Caveats, corrections, and what I did not do

- **`body_text` includes editorial footnotes.** Every frequency above blends document language with
  editors' language, and this index cannot separate them by column. **I have not separated document
  text from apparatus below the front-matter/editorial-note level.** Doing so is a TEI job and I
  did not open the TEI.
- **No TEI pass.** So: no spelling-variant census, no counting-surface statement, no
  footnote-vs-body split. If you want "how many times does the corpus say *postal convention*"
  rather than "how many documents match", that is a TEI question and this memo does not answer it.
- **Second editions.** Of the three `Ed2` volumes in the index, only `frus1977-80v09Ed2` appears in
  the `postal` set, and it has no first edition to duplicate, so no suppression was needed. Counted
  on this index with apparatus excluded.
- **`citation_era` is a citation form, not a date** — §5a's 92/10/7/3/3/2/2 split is a distribution
  of citation *shapes*, and I have not plotted it as a timeline.
- **`person_rollup` / `person_mentions` untouched.** I did not attempt to identify the negotiators;
  name clustering under-merges and TEI person tagging is uneven, so any delegate count would have
  been a lower bound of unknown tightness. Worth a separate pass.
- **Two documented file-shape surprises** (I read each file's own top-level keys first, as your
  rules require, and they did not match the descriptions in your brief):
  `decimal-class-labels.json` has top-level keys `generated / provenance / schedules /
  schemaVersion` and **no `coverage` object at all**, so there is no `glossableYears` or
  `notShipped` to gate on — I gated on the schedule's own `startYear`/`endYear` (1910/1949) instead
  and reported the in-range count separately. `series-facts-index.json` is **schemaVersion 2** with
  no top-level `legend`.
- **Reading accounting.** I retrieved **4 documents whole** and kept them on disk with the SELECT
  that produced them — `frus1947v01/d20` (6,895 chars), `frus1934v03/d173` (2,930),
  `frus1951v02/d181` (3,097), `frus1952-54v03/d48` (8,115); each captured file is exactly
  `length(body_text) + 1` characters, the extra being the newline `sqlite3` appends. (The byte
  sizes differ — 6,924 / 2,961 / 3,109 / 8,142 — because the corpus is UTF-8; the accounting above
  is in characters.) I **quoted 4** of them. `misses.py` additionally pulled 6 documents whole into
  memory (`frus1866p3/d201`, `frus1875v01/d17`, `frus1903/d333`, `frus1914-20v01/d282`,
  `frus1947v01/d20`, `frus1958-60v16/d56`) and kept only ±70-character windows; the two windows I
  quote in §2b come from that printed output, not from memory.
- **Nothing returned zero unexpectedly** except the RG 28 / RG 43 probes, and those were controlled
  in the same pass (§5e) before I drew the conclusion.
- **Files on disk in this run directory:** `headings.py` / `headings.txt` / `headings.err`
  (chapter-heading scan, §2a); `share.py` / `share-results.json` and `share2.py` /
  `share2-results.json` (literal shares and referent tests, §2b); `misses.py` (the KWIC read);
  `usage-class8-postal.json` (bundled-JSON aggregation, §5e); the four `read-*.txt` documents;
  and `queries.log`.
