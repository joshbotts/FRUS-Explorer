# Scoping memo: US policy on international civil aviation in FRUS

**Question:** How did the United States handle international civil aviation questions —
landing rights, air routes, and the competitive position of American carriers?

**Surfaces used:** the SQLite index (coverage, counts, identity, provenance) and the bundled
JSON (archival resolution). I did **not** open the TEI XML, so every question below that is
marked [TEI] in your house rules — spelling-variant scans, counting-surface figures, and any
body-vs-footnote split — is left unanswered rather than approximated. Where that limits a
claim I say so in place.

---

## 0. Coverage and controls

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library is **complete at 552 volumes** — no partial-library caveat is needed for this run,
and nothing below should be read as conditional on a missing download. Every count excludes
`is_front_matter = 1` and `is_editorial_note = 1` unless stated, and suppresses the two second
editions whose first editions are also present (`frus1951-54IranEd2`, `frus1969-76ve15p2Ed2`).

```sql
SELECT 'POSCTRL', COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents
  WHERE frus_documents MATCH '"Department of State"';   -- 98499 | 551
SELECT 'NEGCTRL', COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents
  WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ';      -- 0 | 0
```

Controls pass. Every absence reported below is a measured absence, not a broken scan.

---

## 1. The short answer

This corpus holds the civil-aviation question **very well for 1927–1949 and much less well
afterwards**, and it holds it under a name you would not guess: the State Department's own
filing category **`.796 Aerial navigation`**.

Two independent finders, keyword search and the decimal file, produce sets that **barely
overlap**:

| finder | documents | volumes |
|---|---|---|
| keyword core (17 phrase families) | 4,636 | 435 |
| decimal classes `*.796*` + `579.6*` | 1,535 | 91 |
| **intersection** | **687** | — |
| **union** | **5,484** | **435** |

687 of a 5,484-document union is a 12.5% overlap. Neither finder alone is adequate, and the
decimal file is the one most people would never run. Use both.

---

## 2. What I actually measured, and what broke

### 2.1 Phrase families, tolerant vs strict

The index is porter-stemmed, so I ran every phrase as an FTS `MATCH` (tolerant) and then
recomputed it as a literal substring over `header || dateline || source_note || body_text`
(strict), non-apparatus only:

| phrase | tolerant | strict | strict share | volumes |
|---|---|---|---|---|
| air base | 1,524 | 1,480 | 0.971 | 285 |
| air transport | 1,351 | 1,332 | 0.986 | 266 |
| civil aviation | 1,064 | 1,060 | **0.996** | 237 |
| air service | 551 | 548 | 0.995 | 177 |
| civil air | 525 | 523 | 0.996 | 167 |
| air routes | 378 | 372 | 0.984 | 146 |
| air agreement | 308 | 306 | 0.994 | 105 |
| landing rights | 272 | **246** | **0.904** | 138 |
| air line | 251 | **216** | **0.861** | 121 |
| commercial aviation | 198 | 196 | 0.990 | 74 |
| air navigation | 189 | 188 | 0.995 | 85 |
| traffic rights | 54 | 54 | 1.000 | 29 |

All are above the 0.80 usability floor. The two weakest I read, as your rules require.

### 2.2 Four traps, all of which fired

**(a) `landing rights` → `land rights`.** The 26 tolerant-only hits are the porter stem
`land` folding *landing* into *land*. Reading them: `frus1931v03/d86`, `/d123`, `/d294` are
Japanese–Korean **land tenure in Manchuria** ("taxation, land rights, Koreans in Manchuria");
`frus1925v02/d413` is Mexican **petroleum lands**. Publish 246, not 272.

**(b) `air line` → 19th-century railroad.** `frus1871/d5` contains "…a portion of the
Northern Nebraska Air Line…" — an *air line* in 1871 is a straight-line railway. This is why
the pre-flight decades showed hits at all.

**(c) `%iata%` as a substring.** My first core set matched IATA by substring and picked up
**59 pre-1903 documents** — Spanish *inmediata*. Rebuilt with the acronyms word-bounded
through the FTS index (`MATCH 'icao OR picao OR iata OR cabotage'`). The pre-1910 residue fell
from 30/16/6/7/8 per decade to 3/2/4/8/3. **The first decade table I produced was wrong; the
one below is the corrected one.**

**(d) `carrier` is at baseline — do not use it.** This is the one that matters for your third
sub-question. False-friend test over the ten most aviation-dense volumes vs the whole corpus:

| term | on-topic 10 vols (n=9,209) | whole corpus (n=307,359) | enrichment |
|---|---|---|---|
| `landing right` | 0.413% | 0.080% | **5.2×** |
| `air route` | 0.956% | 0.121% | **7.9×** |
| `air carrier` | 0.152% | 0.046% | 3.3× |
| `carrier` (bare) | 1.118% | 0.855% | **1.31× — baseline** |
| control: `department of state` | 14.888% | 30.215% | 0.49× |

Bare `carrier` is measuring the corpus, not the question — it is aircraft carriers, mail
carriers, common carriers and disease carriers. Two of the question's three supplied terms
are excellent; the third must be replaced. See §5 for what to use instead.

---

## 3. Where the material is: chronology

Periodised on `document_dates.date_iso` (the document's own date), **not** the volume's series
year. Rate is per 1,000 dated non-apparatus documents in that decade, because the 1940s holds
74,043 dated documents and the 1870s 5,798.

| decade | hits | dated docs | per 1,000 | volumes | largest single volume |
|---|---|---|---|---|---|
| 1860s–1900s | 3–8 each | — | <1 | — | *residual false friends only* |
| 1910s | 68 | 30,359 | 2.24 | 15 | frus1919Parisv07 (13) |
| 1920s | 141 | 19,733 | 7.15 | 21 | **frus1929v01 (50 = 35%)** |
| 1930s | 290 | 39,196 | 7.40 | 46 | frus1933v04 (26) |
| **1940s** | **1,964** | 74,043 | **26.53** | **93** | frus1944v02 (191 = 10%) |
| 1950s | 700 | 42,296 | 16.55 | 93 | frus1952-54v04 (32) |
| 1960s | 689 | 27,650 | 24.92 | 91 | frus1964-68v34 (59) |
| 1970s | 524 | 22,259 | 23.54 | 84 | frus1969-76ve01 (53) |
| 1980s | 178 | 5,949 | **29.92** | 28 | **frus1981-88v04 (55 = 31%)** |

**Two of these rates are traps, and I would have misled you if I had reported raw counts alone.**

**The 1980s "peak" is one shootdown.** 47 of the 55 hits in `frus1981-88v04` (*Soviet Union,
Jan 1983–Mar 1985*) mention KAL / Korean Air / flight 007. That is a civil-aviation *incident*,
not route economics. Corpus-wide, KAL 007 accounts for 51 core documents across six
`frus1981-88` volumes.

**The 1960s–70s rates are inflated by a different question.** Splitting the core by vocabulary:

| decade | core | hijacking/sabotage | landing-rights / routes / bilateral agreements |
|---|---|---|---|
| 1930s | 290 | 0 | 43 |
| **1940s** | 1,964 | 0 | **455** |
| 1950s | 700 | 2 | 153 |
| 1960s | 689 | 42 | 98 |
| 1970s | 524 | **78** | 68 |
| 1980s | 178 | 13 | 16 |

The commercial-rights question peaks in the 1940s and **declines monotonically thereafter**.
By the 1970s, aviation in FRUS is more often a security subject than a commercial one. The
1960s–70s core is also substantially *neither* — aviation appearing incidentally (airlift,
aviation fuel, aircraft transfers).

The commercial-rights subset on its own is **887 documents in 231 volumes**, led by
`frus1945v08` (45), `frus1943` (39), `frus1944v02` (37), `frus1946v01` (22), `frus1947v08` (20).

**Origin point.** The earliest genuine hits are 1917–1919 — armistice aviation clauses and the
Paris Peace Conference (`frus1919Parisv03/d62`, `frus1919Parisv11/d204`, both in the
`Paris Peace Conf. 180.03101` / `184` files), leading to the 1919 Convention on Aerial
Navigation. The 1903 and 1904 hits are false friends. There is no pre-flight negative to
report and no earlier vocabulary to test: the subject does not exist before its technology.

---

## 4. Read the editors' headings before you write queries

I extracted every chapter/compilation heading from `volume_structures` matching aviation
vocabulary: **170 headings**. They fall into repeating editorial formulae, which are far better
search strings than modern phrasing. Verbatim from the result set:

- **Latin American route rivalry, 1927–1929** — "Good offices of the Department of State in
  behalf of American interests desiring to establish air lines in Latin America" (recurs
  1928v01, 1929v01); "Representations to the Guatemalan Government against proposed concession
  of monopoly for Central American air line" (1927v03).
- **Bilateral air navigation arrangements, 1931–1939** — "Arrangement between the United States
  and *X* regarding air navigation, effected by exchange of notes": Italy 1931, Germany 1932,
  South Africa and Norway and Sweden 1933, Denmark 1934, United Kingdom 1935, Irish Free State
  1937, Canada 1938, France and Liberia 1939. The Netherlands negotiation recurs *unresolved*
  in 1932, 1933, 1934 and 1935 — a four-year serial worth following.
- **The Havana Convention** — "Interpretation of article IV of Habana Convention on Commercial
  Aviation adopted February 20, 1928" (1933v04, 1934v04, 1935v04).
- **Ocean routes, 1935–1938** — "Negotiations for the establishment of a trans-Atlantic air
  transport service" (1935v01); "Conflicting American and British claims to various islands in
  the Pacific Ocean; question of use for trans-Pacific aviation" (1938v02).
- **Displacing Axis carriers, 1940–1942** — "Cooperation of the United States in the
  elimination of German influence from Brazilian / Colombian / Ecuadoran airlines" (1940v05);
  the same formula for Argentina, Bolivia, Chile (1941v06–v07, 1942v05).
- **Postwar settlement, 1943–1946** — "Postwar civil aviation policy" (1943, twice);
  "Preliminary and exploratory discussions regarding International Civil Aviation; Conference
  held at Chicago, November 1–December 7, 1944" (1944v02); "United States policy with respect
  to international civil aviation questions: the Bermuda Conference and related developments"
  (1946v01); "Civil aviation policy" (1945Berlinv01, v02).
- **The bilateral air-transport series, 1944–1951** — dozens under "Agreement between the
  United States and *X* relating to air services between their respective territories".
- **Cold War closure, 1948–1951** — "Civil aviation policy of the United States toward the
  Soviet Union and Eastern Europe" (1948v04, 1949v05, 1951v04p2).
- **Competitive-position language, explicitly** — "Assurances sought by the United States that
  the United Kingdom would not oppose efforts by the United States to conclude bilateral civil
  air transport agreements with various governments in the Near and Middle East" (1945v06,
  1945v08); "United States concern at certain air agreements departing from the principles of
  the Bermuda Agreement of 1946" (1949v01).

Note what stops: after **1951** the aviation headings essentially cease, except
"U.S. Policy Towards Terrorism, Hijacking of Aircraft, and Attacks on Civil Aviation"
(1969-76ve01). FRUS's topical-compilation-by-treaty practice ended, and with it the visible
aviation series.

---

## 5. What I would search for

**Use (high enrichment, verified above):** `civil aviation`, `air transport`, `civil air`,
`air navigation`, `air route`, `landing right`, `commercial aviation`, `air agreement`,
`traffic rights`, `aeronautic`, and the acronyms `ICAO` / `PICAO` / `IATA` / `cabotage`
**word-bounded, never as substrings**.

**Do not use:** bare `carrier` (baseline, §2.2d); `air base` (1,524 documents, overwhelmingly
military basing rather than civil aviation); bare `aviation` and `air service` (they widened
the candidate set from 4,630 to 6,738 almost entirely with military material).

**For the carrier-competition question specifically, use the actors' names.** Measured
corpus-wide, non-apparatus:

| term | documents | volumes |
|---|---|---|
| Pan American Airways | 486 | 85 |
| Civil Aeronautics Board | 176 | 61 |
| fifth freedom | 104 | 20 |
| Aeroflot | 101 | 37 |
| Habana/Havana Convention | 79 | 30 |
| cabotage | 73 | 31 |
| Lufthansa | 58 | 28 |
| Imperial Airways / BOAC | 50 | 18 |
| SEDTA (Ecuador) | 47 | 3 |
| LATI (Italy) | 41 | 4 |
| Pan American World Airways | 30 | 17 |
| SCADTA (Colombia) | 30 | 9 |
| Chicago Convention | 29 | 26 |
| Bermuda Agreement | 22 | 13 |
| freedoms of the air | 13 | 6 |
| Trans World / Transcontinental & Western | 13 | 9 |

**One term to drop:** `chosen instrument` looks perfect for the single-carrier-policy debate
and is not. It appears in 88 documents across 58 volumes, but only **10 documents in 4 volumes**
co-occur with any aviation vocabulary. It is overwhelmingly "chosen instrument of policy" in
other contexts.

**A caveat I owe you on all of these.** These are index counts over a porter-stemmed,
flattened text. Counting hyphenation, spacing and case variants properly (`air-line` vs
`air line` vs `airline`; `B.O.A.C.` vs `BOAC`) is a [TEI] question and I did not have that
surface. Treat the table as a ranking, not as a variant census. Note in particular that
`body_text` **includes editorial footnotes**, so these blend the actors' language with the
editors' — and this index cannot separate the two.

---

## 6. Archival scope: where these documents came from

Two channels, reported separately and never summed, per your rules.

### 6.1 Came-from (`document_sources`, one row per document)

4,547 of the 4,636 core documents carry a source row. Citation *form*:

| form | n |
|---|---|
| decimal | 2,733 |
| structured | 1,029 |
| lot_file | 421 |
| named_series | 200 |
| cfpf | 106 |
| published | 32 |

Split by the document's own date, this resolves into **three distinct filing regimes**:

| band | dominant form | counts |
|---|---|---|
| pre-1950 | **decimal** | decimal 2,138 · named_series 175 · lot 93 |
| 1950–63 | mixed | decimal 564 · lot 243 · structured 213 |
| 1964+ | **structured** (libraries/NSC) | structured 800 · cfpf 106 · lot 85 · decimal 31 |

### 6.2 `.796 Aerial navigation` — the single most useful finding in this pass

The recurring `.796` suffix across country classes resolves, in
`decimal-class-labels.json`, under the **1910–1949 schedule** (class 8, *Internal Affairs of
States*):

```
.24     Equipment and supplies
.248    Aircraft
.79     Other means of communication and transportation
.796    Aerial navigation
.7961   Laws and regulation
.7962   Stations. Landing fields. Mooring towns. Seadromes. Fueling. Fuel stations
.7965   Offenses committed on aircraft
.7969   Other matters respecting matter of aircraft
.796A   Aeronautic advisers
```

The gloss gate is satisfied and I checked it: all 1,511 `.796` documents in this corpus date
between **1927-01-19 and 1949-11-08**, entirely inside the schedule's own 1910–1949 span, so
composing the key is legitimate here. (Outside that window it would not be — the classification
was renumbered in 1950 and the file has no gloss for the later eras.)

```sql
SELECT COUNT(*), COUNT(DISTINCT s.volume_id), MIN(dt.date_iso), MAX(dt.date_iso)
FROM document_sources s
JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id
LEFT JOIN document_dates dt ON dt.volume_id=s.volume_id AND dt.document_id=s.document_id
WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND s.decimal_class LIKE '%.796%';
-- 1511 | 88 | 1927-01-19 | 1949-11-08
```

Top classes: `800.796` (263 — *World*, i.e. general/multilateral), `810.79611` (224 —
Pan-America, laws and regulation), `832.796` (75 — Brazil), `893.796` (69 — China),
`835.796` (59 — Argentina), `822.796` (51 — Colombia), `890F.7962` (37 — landing fields,
Saudi Arabia), `882.7962` (34 — Liberia), `841.796` (32 — United Kingdom).

**Only 672 of those 1,511 are in my keyword core.** The 839 the keyword scan missed are
squarely on topic — sampled at random: `frus1928v01/d643` (825.796) *The Acting Secretary of
State to the Pan American Airways, Inc.*; `frus1940v05/d785` (832.796) Ambassador Caffery from
Brazil; `frus1942v04/d475` (882.7962) to the Chargé in Liberia; `frus1948v08/d696` (893.796A —
*Aeronautic advisers*) to the Consul General at Shanghai. They were missed because individual
letters say "the Company", "the service", "the concession" without ever using an
aviation-specific phrase.

**Practical consequence:** for 1927–1949, `document_sources.decimal_class LIKE '%.796%'` is a
better recall instrument than any keyword search. It recovers four times as much in
`frus1929v01` (50 → 206) and three times as much in `frus1928v01` (32 → 106).

A companion class for the **multilateral** track is `579.6*` (class 5, *Congresses and
Conferences*): small but precise — 24 documents, including `579.6D1` (ICAN Paris 1929, 6 docs),
`579.6L2`/`579.6L3` (private air law, Warsaw 1929 and Rome 1933), `579.6AE1` (the 1939 London
fuel-taxation conference, 7 docs), and `579.6-PICAO` (1946).

I deliberately **exclude `.248 Aircraft`** (613 documents, 57 volumes) from the aviation core:
it sits under *Equipment and supplies* and is dominated by military aircraft transfer, a
different question.

### 6.3 The concentration: `frus1944v02`

From `collection-usage-index.json`, the ranked archival targets for the densest volume:

```
frus1944v02 (914 source notes)  top class keys:
  800.796  231     840.70  117     840.50  115     800.85  53     800.515  42
```

**231 of 914 source notes in that volume — a quarter — come from the world aerial-navigation
file.** This is the Chicago Conference volume (*1944, General: Economic and Social Matters*).
`frus1946v01` shows `841.796` at rank 5 (18 notes) — the UK file behind Bermuda.

### 6.4 Pointed-at (`external_citations`, many rows per document)

Thinner and later, exactly as your rules warn. 743 of 4,636 core documents carry any external
citation at all, over 1,264 rows; the channel has **no row before 1910-12-06**, stores the
citation fragment rather than the sentence, and holds only lot, library and decimal anchors.
Ranked collections are almost entirely post-1945 presidential libraries:

| repository / collection | rows |
|---|---|
| Nixon Presidential Materials / NSC Files | 54 |
| Carter Library / National Security Affairs | 45 |
| Johnson Library / National Security File | 21 |
| Eisenhower Library / Whitman File | 16 |
| Kennedy Library / National Security Files | 12 |

Top pointed-at lots: `66D95` (35 rows, 18 volumes), `63D351` (22), `62D1` (12).
**Do not add these to §6.1's numbers** — they answer a different question.

### 6.5 Lot files: no dedicated aviation lot except one

The top came-from lots for the core are **generic policy files**, not aviation files —
resolved through `central-files-index.json`:

| lot | docs | resolves to |
|---|---|---|
| M88 | 51 | not in central-files-index (CFM Files) |
| 63D351 | 40 | NAID 2839192 — *Records Relating to National Security Council Policy Papers* |
| 62D1 | 16 | NAID 2838992 — *Records Relating to Activities with the National Security Council* |
| 72D316 | 12 | NAID 603185 — *National Security Action Memorandum Files* |
| 93D188 | 14 | NAID 431966115 — *Memoranda of Conversations… Haig, Shultz, Baker* |

Searching all 1,065 lot files in the bundled index for aviation titles returns **exactly one**:

> **Lot 65A987 — RG 59 — NAID 2945755 — HMS/MLR entry P 184 —
> *Records Relating to the Havana Convention on Commercial Aviation***

That is the archival counterpart to the 1933–1935 "Interpretation of article IV" compilations.
None of the aviation NAIDs above appear in `series-facts-index.json` (695 series), so I cannot
give you creator, extent, facility or access status for any of them offline. Your rules note
that the offline stack barely reaches before 1940; that is what I hit.

### 6.6 After 1963: the `AV` category, and why it is nearly empty

Post-1963 the Central Foreign Policy File uses a subject-numeric designator. Volume front-matter
Sources lists name it explicitly — `AV 9 JAPAN–US, Aviation routes and schedules`
(frus1964-68v29p2), `AV 12–1 CZECH` and `AV 9 CZECH–US` (frus1964-68v17), `AV 12–2 S AFR`
(frus1964-68v09), `AV 12, aircraft and aeronautical equipment` (frus1969-76v24). But measured:

```sql
SELECT COUNT(*), COUNT(DISTINCT s.volume_id) FROM document_sources s
JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id
WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND s.decimal_class LIKE 'AV%';
-- 96 | 8
```

**96 documents in 8 volumes**, and dominated by `AV 12` (aircraft/equipment, 45) and `AV 12 US`
(39) — the hijacking and transfer files. `AV 9` (*routes and schedules*), the class that
actually holds your question, yields **2 documents**.

This is a corpus-scoping negative, and per your rules it deserves its positive counterpart:
**FRUS is not where post-1963 route economics lives.** The subject moved to agencies FRUS does
not compile — the Civil Aeronautics Board and the Bureau of Economic Affairs. The FRUS trail
for your question runs 1927–1951 and then thins to high-politics incidents. The corresponding
NARA series is `AV 9` within the RG 59 Central Foreign Policy File, plus CAB records in RG 197;
I could not resolve either offline, and say so rather than leaving the negative bare.

### 6.7 Can you see any of it before travelling? Mostly no

`digitized-ranges-index.json` covers **18 decimal classes only** — `131`, `131.1`, `133`,
`133.1` (visa and passport) and the `763.72*` family (the First World War political file).
**No `.796` class is digitized**, and the bundled `roll-scans-index.json` in this app copy
contains 0 scans.

*I got this wrong the first time and am recording the error.* My first test compared the full
class number (`800.796`) against each range's `low`/`high` and reported 22 "covering ranges".
Those fields are **document serials within a class**, not class numbers, so the test was
meaningless. The corrected test matches on the `decimalClass` field itself and returns an empty
set. Both queries are in `queries.log` in order.

---

## 7. Documents read

Retrieved whole, with `captured_length = length(body_text)`; SQL in `grab.sql`, raw text kept
at `read-whole.txt`:

| document | source note | captured length |
|---|---|---|
| frus1944v02/d267 | 800.796/472 | 5,327 |
| frus1944v02/d469 | 841.796/10–944 | 1,485 |
| frus1946v01/d779 | 579.6 PICAO /5–1846 | 6,016 |
| frus1946v01/d784 | 711.0027/9–1946: Circular telegram | 5,006 |
| frus1928v01/d643 | 825.796/27 | 1,213 |

**5 retrieved whole, 0 quoted at length.** Short strings I quote elsewhere in this memo
(headers, chapter titles, the "Northern Nebraska Air Line" fragment, the decimal glosses) all
came back in result sets in this session. `frus1946v01/d779` is worth your attention as a
starting point: the Acting Secretary instructing William A. M. Burden, chairman of the US
delegation to the PICAO Interim Assembly — the intersection of multilateral organisation and
national carrier interest that your question sits on.

---

## 8. Where I would start

1. **`frus1944v02`** — the Chicago Conference volume; a quarter of its source notes are
   `800.796`. 254 documents in the union.
2. **`frus1946v01`** — Bermuda and PICAO. Then `frus1946v05` and `frus1946v11` for the
   bilateral series with the UK and Latin America.
3. **`frus1928v01` + `frus1929v01`** — the Latin American route rivalry. 206 and 106 documents
   in the union, but only 50 and 32 by keyword. **Run the decimal query, not the keyword one.**
4. **`frus1940v05`, `frus1941v06`, `frus1942v05`** — displacing SCADTA, SEDTA, Condor and LATI.
   Use the airline names; the phrase "elimination of German influence" is the editors' formula.
5. **`frus1945v08`** — Near East landing rights, 45 commercial-rights documents, the most of any
   volume.
6. For the archives: **RG 59 decimal `.796`** by country number for 1927–1949, **Lot 65A987 /
   NAID 2945755** for the Havana Convention, and **`AV 9`** in the Central Foreign Policy File
   for 1963 onward — none digitized.

---

## 9. Caveats

- **[TEI] not consulted.** No variant census, no counting-surface figure, no apparatus/body
  split. `body_text` includes editorial footnotes throughout, so every frequency here blends
  the actors' and the editors' language.
- **Two of my own numbers were wrong and are corrected above**: the first decade table
  (contaminated by `%iata%` matching Spanish *inmediata*) and the digitization containment test
  (§6.7). One further query, a foreign-carrier count, was contaminated by my own
  `AND`/`OR` precedence error and was re-run; only the corrected figures appear in §5.
- **Rates, not counts, in §3** — and even the rates mislead where a single volume dominates.
  The 1980s figure is 31% one volume and 85% one shootdown.
- `citation_era` in §6.1 is a citation *form*, not a date; the chronology in §3 comes from
  `document_dates`.
- `person_rollup` and `person_mentions` were not used; person counts would be lower bounds and
  I had no need of them.
- Subject tags (`document_subject_refs`) were not used: they come from string matching, and I
  had two better-grounded finders.
- **`queries.log` format note.** The log was appended as I went, in order, and never
  reconstructed. Entries beginning `python3 (...)` are one-line descriptions of a `python3`
  heredoc rather than the literal multi-line script; the scripts themselves are inlined in the
  transcript and the SQL they accompany is on disk in this directory (`*.sql`, `phrase.sh`).
