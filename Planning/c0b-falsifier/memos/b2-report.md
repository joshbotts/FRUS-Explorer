# Scoping memo: international civil aviation in FRUS

**Question.** How did the United States handle international civil aviation questions — landing
rights, air routes, and the competitive position of American carriers?

**Bottom line.** Your library holds this question well, and it holds it in a shape that is not
obvious from the question's own wording. The corpus's civil-aviation material is heavily
concentrated in **1927–1951**, with a second, differently-shaped cluster in **1964–1976** about
hijacking and the SST, and a third — which my own scoping method missed and text search found — in
**1983** around KAL 007 and Aeroflot's landing rights. There is a workable archival handle — the
State Department's own decimal class `.796`, "Aerial navigation" — that finds 507 documents no
chapter heading reaches; and there are chapters holding 850 documents that carry no `.796` at all.
Neither route alone is sufficient, and **both are blind after about 1960**, so plan on three
instruments, not one. Two of the phrases in your own question — "competitive position" and
"American flag" — measure the corpus rather than the topic, and I would not search on them; the
carrier names (`Sedta`, `LATI`, `SCADTA`, `Condor`, `Panagra`) are the most precise terms in the
whole corpus for the competitive question.

---

## 0. Coverage, and what every number below is conditional on

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library is **complete**: all 552 published volumes are present, 316,839 documents, of which
1,012 are front matter and 8,468 editorial notes. Nothing below is limited by a partial download.
Unless stated otherwise every count excludes front matter and editorial notes and suppresses the
two duplicate second editions (`frus1951-54IranEd2`, `frus1969-76ve15p2Ed2`), which leaves a
denominator of **306,619** documents; where a count needed no Ed2 suppression the denominator is
307,359, and I have said which applies.

**Controls, run in the same pass.**

```sql
SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"Department of State"'; -- 98499
SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ';    -- 0
```

Positive control returns 98,499; negative returns 0. The scan works, so an absence below is
evidence.

---

## 1. Read the editors first: their formulas, not yours

Before writing a single text query I read the editors' own chapter and subchapter headings out of
`volume_structures`. This changed everything about what I then searched for. The scan
(`headings.py`, `headings2.py`, `chapters.py` — all in the run directory) walks every volume's
section tree and matches the title against a civil-aviation vocabulary while excluding military-air
false friends (air strikes, air bases, bombardment, munitions, "national security policy").

**166 sections across 74 volumes** carry a civil-aviation formula. The formulas are highly
repetitive, which is exactly what you want: they are the editors' filing habits, and they change
by period.

| Period | The editors' repeating formula | Example |
|---|---|---|
| 1919–1926 | "Rules for aerial navigation"; the Paris convention of 13 Oct 1919 and its submission to the Senate | `frus1919Parisv01/ch29`, `frus1926v01/ch5` |
| 1927–1936 | **"Good offices of the Department of State in behalf of American interests desiring to establish air lines in Latin America"** | `frus1928v01/ch24`, `frus1929v01/ch17` |
| 1929–1939 | **A repeating *pair*:** "Arrangement between the United States and X regarding air navigation" + "…for pilot licenses to operate civil aircraft" | `frus1933v02` has four such pairs (South Africa, Norway, Sweden…) |
| 1940–1942 | **"Elimination of Axis-controlled / German influence from X airlines"** | Ecuador, Brazil, Colombia, Argentina, Chile, Bolivia, Peru |
| 1943–1944 | "Postwar civil aviation policy"; then the Chicago Conference | `frus1943/ch5subch13`, `frus1944v02/comp9` |
| 1945–1949 | "Air transport (services) agreement between the United States and X" — dozens | `frus1945v05`, `frus1946v05`, `frus1946v11`, `frus1947v08` |
| 1948–1951 | "Civil aviation policy of the United States toward the Soviet Union and Eastern Europe" | `frus1948v04/ch5`, `frus1949v05/ch3` |
| 1964–1976 | "Hijacking"; "Development of the Supersonic Transport Aircraft" | `frus1964-68v34/ch9`, `frus1964-68v34/ch4`, `frus1969-76ve01` |

Two things follow immediately.

**(a) The single largest concentration in the corpus is `frus1944v02` compilation `comp9`,**
*"Preliminary and exploratory discussions regarding International Civil Aviation; Conference held
at Chicago, November 1–December 7, 1944"* — **252 documents**. Nothing else is close. The second
is `frus1929v01/ch17subch1`, *"Pan American Airways, Incorporated"*, **132 documents**.

**(b) A large number of sections carry a heading and *no documents*.** In `frus1946v05` alone,
eleven "Agreement between the United States and X relating to air services" sections have zero
documents attached. These are the treaty-list sections: FRUS *names* the bilateral it concluded and
prints nothing. If your question is "how many bilaterals, with whom, when", these headings are
themselves a finding, and they are the only place that finding lives.

---

## 2. The archival handle that beat text search: decimal class `.796`

I ran the came-from channel (`document_sources`) over the chapter-derived document set and the
result was a gift:

```sql
SELECT decimal_class, COUNT(*) c FROM document_sources
WHERE (volume_id,document_id) IN (<the 1,854 chapter documents>)
  AND decimal_class IS NOT NULL GROUP BY 1 ORDER BY c DESC LIMIT 25;
-- 800.796 258 | 810.79611 223 | 832.796 74 | 835.796 55 | 890F.248 51 | 822.796 51 | ...
```

Every leading class ends in **`.796`**. `decimal-class-labels.json` confirms what that is: under
the 1910–1949 schedule, class **8** ("Internal Affairs of States") is country-arranged, and subject
suffix **`796` = "Aerial navigation"**, with a whole subtree under it (`7961` = "Laws and
regulation", `79601`, `796101`…`796905`). `248` = "Aircraft".

So `800.796` is *world / aerial navigation* — international civil aviation in general; `841.796` is
Great Britain's; `811.796` the United States'; `810.79611` Pan-America's.

This gives a **document-grain archival query that is independent of the text**:

```sql
SELECT COUNT(*), COUNT(DISTINCT s.volume_id)
FROM document_sources s
JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id
WHERE d.is_front_matter=0 AND d.is_editorial_note=0
  AND s.decimal_class LIKE '8%'
  AND substr(s.decimal_class, instr(s.decimal_class,'.')+1) LIKE '796%';
-- 1511 | 88
```

**1,511 documents across 88 volumes** were filed by the Department under Aerial navigation.

**The gloss is safe here, and I checked.** `decimal-class-labels.json` ships only the 1910–1949
schedule (the classification was renumbered in 1950, so a `.796` in a 1955 document would gloss
*wrongly*, not merely be a miss). Every one of the 1,511 falls inside that window:

| decade of `frus:doc-dateTime-min` | docs |
|---|---|
| 1920s | 306 |
| 1930s | 116 |
| 1940s | 1,089 |

No 1950s row at all, and none undated. So the reading is licensed.

### The two routes barely overlap, and that is the useful part

```
chapter set (broad)   1,854 docs
.796 set              1,511 docs
overlap               1,004
.796 but NOT in an aviation chapter    507
aviation chapter but NOT .796          850
union                                2,361
```

**507 documents were filed by the Department as aerial navigation but printed by FRUS under a
country or general chapter** — they are invisible to any heading-based scope. **850 documents sit
in an aviation chapter but carry no `.796`** — mostly the post-1949 material (whose classification
changed), the lot-file era, and the Latin-American-airline chapters filed under other classes. Use
both or you lose a third of the material either way.

### A precision problem in the chapter route you should know about

FRUS chapter headings after about 1945 are **compound**. `frus1945v08/ch34` is
*"Extension of financial and economic assistance by the United States to Saudi Arabia; …
the construction of an airfield…"* — **143 documents**, admitted to my set on one clause. Same for
`frus1949v05/ch19` (Yugoslavia, 84 docs) and `frus1951v04p2/ch2subch1` (Eastern Europe, 59 docs).

I therefore built a **tight** set requiring the aviation clause to *head* the title (first clause,
before the first `;` or `.` or "For previous"): **157 sections, 70 volumes, 1,450 documents**; 404
documents dropped. Union with `.796` = **1,969 documents**. I used the tight union as the "gold"
set for the precision tests in §4 and report both numbers everywhere.

---

## 3. Where the material is: ranked volumes

Gold = tight-chapter ∪ `.796`, but the table below shows the broad chapter column too so you can
see which volumes depend on the compound-heading effect. "of vol" is the gold count as a share of
that volume's non-apparatus documents.

| volume | gold | chap(broad) | .796 | of vol | what it is |
|---|---|---|---|---|---|
| `frus1944v02` | 253 | 252 | 245 | 28% | **Chicago Conference, 1944** — the single richest volume |
| `frus1929v01` | 193 | 193 | 186 | 22% | **Pan American Airways, Inc.**; Tri-Motors Safety Airways; Latin American Airways |
| `frus1945v08` | 158 | 158 | 18 | 12% | Near East — Dhahran airfield, bilateral air transport assurances (**compound heading, treat with care**) |
| `frus1949v05` | 111 | 111 | 1 | 20% | Eastern Europe civil aviation policy (**compound heading**) |
| `frus1969-76ve01` | 102 | 102 | 0 | 23% | **Hijacking / attacks on civil aviation, 1969–73** |
| `frus1928v01` | 99 | 57 | 99 | 12% | Latin American air lines, "good offices" |
| `frus1941v06` | 82 | 82 | 81 | 13% | **Eliminating Axis airlines**: Argentina, Brazil, Chile, Bolivia |
| `frus1942v04` | 65 | 15 | 64 | 7% | Air transit rights over Saudi Arabia; UK air services in the Near East |
| `frus1942v05` | 62 | 60 | 58 | 8% | Axis airlines in Brazil and Argentina |
| `frus1951v04p2` | 59 | 59 | 0 | 14% | Eastern Europe (**compound heading**) |
| `frus1940v05` | 55 | 55 | 55 | 4% | German influence in Ecuadoran/Brazilian/Colombian airlines |
| `frus1946v11` | 48 | 37 | 25 | 4% | Brazil, Colombia, Uruguay, Mexico, Argentina bilaterals; Guatemala airline expropriation |
| `frus1948v08` | 43 | 34 | 31 | 5% | China air transport agreement revision |
| `frus1964-68v34` | 38 | 38 | 0 | 13% | **SST development; hijacking** |
| `frus1946v01` | 32 | 32 | 23 | 4% | **Bermuda Conference** |
| `frus1948v04` | 32 | 32 | 5 | 5% | Civil aviation policy toward USSR/Eastern Europe |
| `frus1947v03` | 30 | 4 | 30 | 4% | Portugal transit rights; Newfoundland leased bases |
| `frus1941v02` | 28 | 0 | 28 | 3% | **`.796`-only — no aviation heading at all** |
| `frus1931v03` | 21 | 0 | 21 | 2% | **`.796`-only** |
| `frus1943China` | 18 | 0 | 18 | 2% | **`.796`-only** |

Full table: 2,361 documents across 100 volumes on the broad definition, 1,969 on the tight one.
The bottom three rows are the argument for the `.796` route in one line.

---

## 4. What I would actually search for — and what I would not

Every phrase was run as an FTS5 phrase MATCH with apparatus and Ed2 duplicates excluded, and each
carries its **literal share** (strict = the exact string; tolerant = allowing the plural/singular
fold porter imposes), sampled over `header + dateline + source_note + body_text`.

| phrase | docs | vols | strict | tolerant | verdict |
|---|---|---|---|---|---|
| `"air transport"` | 1,349 | 264 | 0.986 | 0.986 | **best single recall term** |
| `"civil aviation"` | 1,061 | 236 | 0.996 | 0.997 | best precision/recall balance |
| `"air services"` | 551 | 177 | 0.468 | 0.995 | fine — the gap is only *service/services* |
| `"Pan American Airways"` | 521 | 91 | 0.933 | 0.933 | the firm; see §5 |
| `"air routes"` | 377 | 145 | 0.599 | 0.984 | fine — *route/routes* fold |
| `"landing rights"` | 272 | 138 | 0.893 | **0.904** | **usable but needs a literal filter — see below** |
| `"transit rights"` | 252 | 120 | 0.980 | 1.000 | |
| `"air line"` | 251 | 121 | 0.857 | 0.857 | the pre-1940 spelling; keep it separate from `airline` |
| `"aviation agreement"` | 218 | 90 | 0.995 | 0.995 | |
| `"commercial air"` | 210 | 117 | 0.995 | 0.995 | |
| `"commercial aviation"` | 197 | 73 | 0.995 | 0.995 | the 1920s–30s term |
| `"air navigation"` | 188 | 84 | 0.995 | 0.995 | the 1919–39 term of art |
| `"Civil Aeronautics Board"` | 176 | 61 | 1.000 | 1.000 | |
| `"air carriers"` | 140 | 67 | 0.764 | 1.000 | |
| `"fifth freedom"` | 105 | 20 | 0.990 | 0.990 | **highest lift of any term (94x)** |
| `"aerial navigation"` | 93 | 45 | 0.989 | 0.989 | the 1919–29 spelling |
| `"International Civil Aviation Organization"` | 90 | 43 | 0.989 | 0.989 | |
| `"cabotage"` | 73 | 31 | 1.000 | 1.000 | |
| `"traffic rights"` | 54 | 29 | 1.000 | 1.000 | |
| `"Chicago Convention"` | 29 | 26 | 1.000 | 1.000 | thin — the editors mostly say "the Chicago Conference" |
| `"five freedoms"` | 23 | 15 | 0.870 | 0.870 | |
| `"Bermuda Agreement"` | 22 | 13 | 1.000 | 1.000 | thin, but see `frus1946v01/comp22` |

Every strict/tolerant pair is above the 0.80 unusability floor.

### `"landing rights"` — two distinct traps, both verified by reading

**(i) Porter folds it into "land rights".** 26 of 272 documents (9.6%) contain no literal
"landing right". I read ten of the misses. They are `frus1931v03/d123` and `frus1931v03/d294`
(Japanese **land rights** in Manchuria), `frus1911/d422` and `frus1912/d800` (**land** records),
`frus1923v02/d614`, `frus1925v02/d413` (petroleum **lands**), and several where "land" and "right"
merely co-occur. Add `AND lower(body_text) LIKE '%landing right%'`.

**(ii) Before 1910, "landing rights" means submarine telegraph cables.** All six pre-1910 hits are
cable landing rights — I retrieved and read every one:

```sql
SELECT d.volume_id, d.document_id, length(d.body_text), <a 320-char window around 'landing right'>
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE f.frus_documents MATCH '"landing rights"' AND d.is_front_matter=0 AND d.is_editorial_note=0
  AND dd.date_iso < '1910-01-01';
```

`frus1897/d154` concerns "the shore end of the new French cable"; `frus1898/d835`, `d854` and
`d859` all concern "cable-landing rights" in Spanish territory at the Paris peace negotiations;
`frus1874/d302` and `d311` are Queen's-speech extracts where "land" and "rights" merely co-occur.
Aviation is not the referent in any of them.

### The false-friend test: two of the question's own phrases fail it

I measured each phrase's **precision against the gold set** (share of its hits that are in
tight-chapter ∪ `.796`) and its **lift over the corpus baseline** (gold is 2,361 of 306,619
non-apparatus documents = 0.0077). A term at ~1x baseline is measuring the corpus, not the question.

| phrase | hits | precision | **lift** |
|---|---|---|---|
| `"fifth freedom"` | 105 | 0.724 | **94.0x** |
| `"Pan American Airways"` | 521 | 0.697 | **90.5x** |
| `"cabotage"` | 73 | 0.589 | **76.5x** |
| `"Civil Aeronautics Board"` | 176 | 0.528 | **68.6x** |
| `"air carriers"` | 140 | 0.429 | 55.7x |
| `"air navigation"` | 188 | 0.394 | 51.1x |
| `"commercial aviation"` | 197 | 0.365 | 47.5x |
| `"American carriers"` | 55 | 0.345 | 44.8x |
| `"landing rights"` | 272 | 0.327 | 42.5x |
| `"civil aviation"` | 1,061 | 0.318 | 41.2x |
| `"traffic rights"` | 54 | 0.296 | 38.5x |
| `"air transport"` | 1,349 | 0.285 | 37.1x |
| `"aviation agreement"` | 218 | 0.252 | 32.8x |
| `"air routes"` | 377 | 0.233 | 30.3x |
| `"Chicago Convention"` | 29 | 0.138 | 17.9x |
| `"subsidy"` | 1,978 | 0.033 | 4.3x |
| **`"competitive position"`** | **271** | **0.018** | **2.3x** |
| `"most favored nation"` (control) | 2,803 | 0.006 | **0.7x** |
| **`"American flag"`** | **1,026** | **0.007** | **0.9x** |
| `"Department of State"` (control) | 93,418 | 0.004 | **0.6x** |

**`"competitive position"` (2.3x) and `"American flag"` (0.9x) are false friends.** "American flag"
lands *exactly* on the two controls — in this corpus it is overwhelmingly a maritime and shipping
phrase, not an aviation one. **Do not search on the question's own words for the third leg.** The
terms that actually carry "the competitive position of American carriers" are `fifth freedom`,
`cabotage`, `chosen instrument`, `air carriers`, `American carriers`, and the carrier names.

Precision here is a *lower bound* on topicality, because the gold set deliberately excludes
aviation documents printed under headings that never mention aviation. Lift is the number to read.

### `"chosen instrument"` — the right term, but period-bound

89 documents, 59 volumes, literal share 0.989, lift 10.3x — much weaker than the aviation family,
and reading explains why. It has **two unrelated senses**. I retrieved twelve and read them:
`frus1865p4/d1090` ("Andrew Johnson the chosen instrument of the American people"),
`frus1866p1/d251` ("chosen instrument of God"), `frus1912/d424`, `frus1917-72PubDipv07/d127` and
`frus1948v04/d60` all use it non-aviationally. But **seven of the twelve are the 1944 aviation
policy debate** and are exactly what you want: `frus1944v02/d319`, `d345`, `d393`, `d450`, `d462`,
`d463`, `d466` — Senator Clark on whether the US would "proceed on a chosen instrument monopoly
theory"; Winant reporting on the repeal of the BOAC act and "the abandonment of the chosen
instrument"; C. D. Howe on the Canadian position. **Scope it to the 1940s and it is a precision
instrument for the monopoly-versus-competition argument.**

### The carriers themselves are the sharpest terms in the whole scope

Company names beat every abstract phrase. Run with the **tight** gold set (1,969 of 307,359
non-apparatus documents = 0.00641 baseline, Ed2 *retained* in the denominator — so these lifts are
on a slightly different footing from the §4 table, which used the broad gold set and suppressed
Ed2; compare within each table, not across).

| carrier | hits | vols | in gold | precision | lift |
|---|---|---|---|---|---|
| `"Sedta"` (German-controlled, Ecuador) | 47 | 3 | 45 | **0.957** | 149.5x |
| `"LATI"` (Italian, to Brazil) | 47 | 5 | 41 | 0.872 | 136.2x |
| `"American Export Airlines"` | 13 | 7 | 11 | 0.846 | 132.1x |
| `"SCADTA"` (German-controlled, Colombia) | 30 | 9 | 25 | 0.833 | 130.1x |
| `"Deutsche Lufthansa"` | 6 | 4 | 5 | 0.833 | 130.1x |
| `"Imperial Airways"` | 23 | 9 | 18 | 0.783 | 122.2x |
| `"British Overseas Airways"` | 22 | 11 | 17 | 0.773 | 120.6x |
| `"Pan American-Grace"` | 65 | 14 | 50 | 0.769 | 120.1x |
| `"Pan American Airways"` | 521 | 91 | 361 | 0.693 | 108.2x |
| `"Aerovias"` | 29 | 10 | 20 | 0.690 | 107.7x |
| `"Avianca"` | 24 | 7 | 16 | 0.667 | 104.1x |
| `"Panagra"` | 130 | 20 | 77 | 0.592 | 92.5x |
| `"Condor"` (German-controlled, Brazil) | 139 | 37 | 80 | 0.576 | 89.8x |
| `"Lufthansa"` | 58 | 28 | 33 | 0.569 | 88.8x |
| `"BOAC"` | 59 | 27 | 30 | 0.508 | 79.4x |
| `"United States carriers"` | 45 | 25 | 15 | 0.333 | 52.0x |
| `"American carriers"` | 55 | 34 | 18 | 0.327 | 51.1x |
| `"Braniff"` | 41 | 15 | 13 | 0.317 | 49.5x |
| `"Air France"` | 75 | 39 | 23 | 0.307 | 47.9x |
| `"Trans World Airlines"` | 14 | 7 | 3 | 0.214 | 33.4x |
| `"American aviation"` | 190 | 85 | 34 | 0.179 | 27.9x |
| `"KLM"` | 59 | 38 | 8 | 0.136 | 21.2x |
| **`"Aeroflot"`** | **101** | **37** | **0** | **0.000** | **0.0x** |

Two things to take from this.

**First: the Axis-airline names are the highest-precision terms in the corpus for this question.**
`Sedta`, `LATI`, `SCADTA`, `Condor` and `Deutsche Lufthansa` are 83–96% on-topic. If the
competitive position of American carriers is your interest, the 1938–42 campaign to displace
German and Italian carriers from South America is where FRUS argues it most explicitly, and these
five names are the way in. `Panagra` and `Pan American-Grace` (the Pan Am–W. R. Grace joint
venture) are the American counterpart and are far more precise than `Pan American Airways` itself.

**Second, and this is a hole in my own scope: `"Aeroflot"` returns 101 documents in 37 volumes and
NOT ONE of them is in the gold set.** That is not a false friend — 0.0x lift here means the term
is real and my scope missed it entirely. Aeroflot appears only from 1961 onward, concentrated in
`frus1981-88v04` (27 documents, 1983-09-01 to 1985-03-10), `frus1981-88v05` (9), `frus1977-80v06`
(7) and `frus1969-76v40` (7, all 1971).

Both of my scoping routes are structurally blind to it: the `.796` decimal route stops at 1949, and
no post-1960 volume carries a civil-aviation *chapter heading* outside the hijacking and SST
compilations. **The Cold War civil-aviation story — Aeroflot landing rights, the US–Soviet air
services agreement, and its suspension — is in this corpus and is reachable only by text search.**
`frus1981-88v04`'s date range for the Aeroflot cluster begins on 1 September 1983, the day
KAL 007 was shot down.

---

## 5. The people, and a warning that matters here

`person_mentions` covers TEI `<persName>` markup only, and for this topic the unevenness is total,
not partial:

```sql
SELECT d.volume_id, COUNT(*) docs,
       SUM(CASE WHEN EXISTS(SELECT 1 FROM person_mentions m
             WHERE m.volume_id=d.volume_id AND m.document_id=d.document_id) THEN 1 ELSE 0 END)
FROM document_cache d WHERE d.volume_id IN (...) AND is_front_matter=0 AND is_editorial_note=0
GROUP BY 1;
```

| volume | non-apparatus docs | with any `<persName>` |
|---|---|---|
| `frus1928v01` | 844 | **0** |
| `frus1929v01` | 858 | **0** |
| `frus1941v06` | 629 | **0** |
| `frus1944v02` | 914 | **0** |
| `frus1949v05` | 546 | **0** |
| `frus1964-68v34` | 289 | 279 |
| `frus1969-76ve01` | 443 | 428 |

**Person markup is entirely absent from the 1919–1951 heart of this topic and near-total in the
1960s–70s.** Any person-based ranking over the gold set therefore returns only hijacking-era names
(Rogers, Frank E. Loy, Kissinger, Knut Hammarskjöld of IATA, Najeeb Halaby of the FAA, Talcott
Seelye of the Jordan Hijacking Working Group — 138 distinct tagged persons, all late). It does not
mean the earlier period had no protagonists; it means the markup is not there.

For the pre-1951 period use **full-name FTS**, never a bare surname:
`"Adolf A. Berle"` returns **144 documents**, `"Berle, Adolf"` a further 52 (the index form).
Berle is the Assistant Secretary who runs the 1943–44 aviation negotiations and he is the author of
document after document in `frus1944v02`.

**The office names are the other route, and reading the document headers found them:**

```sql
SELECT o, COUNT(*) n, COUNT(DISTINCT volume_id) v FROM (
  SELECT volume_id, CASE
    WHEN lower(header) LIKE '%aviation division%' THEN 'Aviation Division'
    WHEN lower(header) LIKE '%office of transport and communications%' THEN 'Office of Transport and Communications'
    ... END o
  FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0)
WHERE o IS NOT NULL GROUP BY 1 ORDER BY n DESC;
```

| office named in a document header | docs | volumes |
|---|---|---|
| Aviation (other office forms) | 55 | 24 |
| **Aviation Division** | 40 | 11 |
| **Office of Transport and Communications** | 19 | 10 |
| Civil Air* | 12 | 10 |
| Transport and Communications (other) | 2 | 1 |

`frus1944v02/d275` is *"Memorandum of Conversation, by the Acting Chief of the Aviation Division
(Walstrom)"*. Searching on the **office** rather than the person is the way into the working level
for the pre-tagging era.

---

## 6. Archival scope — where these documents came from, and what the footnotes point at

**These are two different channels over the same scope and I have not summed them.**

### Channel 1 — CAME-FROM (`document_sources`, one row per document), 1,854 broad-chapter documents

1,819 of 1,854 carry a source row. Citation **form** (not a date):

| form | rows |
|---|---|
| decimal | 1,615 |
| structured | 136 |
| lot_file | 38 |
| published | 19 |
| unrecognized | 5 |
| named_series | 5 |
| foreign | 1 |

Record group: **RG 59 in 1,754 of 1,819** (1,651 as `RG-59` plus 103 as `59`); 63 with none; 2 in
RG 256 (the Paris Peace Conference records). This is a Department-of-State story almost without
exception — the corpus does not route you to RG 197 (Civil Aeronautics Board) or RG 237 (FAA) at
all, which is itself worth knowing before you plan a trip.

Lot files are few and, revealingly, **generic rather than aviation-specific**. Resolved against
`central-files-index.json`:

| lot | n | RG | NAID | series | HMS/MLR entry |
|---|---|---|---|---|---|
| 61D167 | 8 | 59 | 2198167 | Alphabetical Files | A1 1583A, A1 1583B |
| 74D164 | 6 | 59 | 621879 | President's Evening Reading Reports | A1 5049 |
| 70D467 | 5 | 59 | 2173131 | Master Files of "Current Economic Developments" | A1 1579 |
| 63D351 | 4 | 59 | 2839192 | Records Relating to National Security Council Policy Paper | A1 1586E |
| 53D407 | 3 | 59 | 2600741 | Delegation Files | A1 5472 |
| 62D1 | 3 | 59 | 2838992 | Records Relating to Activities with the National Security … | A1 1583E, A1 1583F |
| 53D250 | 5 | — | — | **unresolved in `central-files-index.json`** | |
| 52M45, M88, 60D641, 58D609, 58F53 | 1–2 each | — | — | **unresolved** | |

**There is no aviation-office lot file in the corpus's source notes.** The postwar aviation material
FRUS printed came out of the central files, not out of a Bureau of Transport and Communications lot.

### Channel 2 — POINTED-AT (`external_citations`, many rows per document)

```
external_citations corpus-wide: 49,687 rows
rows whose citing document is in the gold set: 368, from 230 citing documents in 39 volumes
```

**This channel is thin for this topic and I would not rank anything on it.** Its structural limits
apply with full force here: it holds no row before 1910-12-06, it stores the citation fragment
rather than the sentence, and it carries lot, library and decimal anchors only. What is there:

- repository: Department of State 367, Franklin D. Roosevelt Library 1
- lot files: 61D167 (4), 58D609 (2), then six lots with one reference each — **eleven references
  in total**
- decimal anchors, top: `890F.7962` (27), `711.4027` (27), `660H.119` (14), `890F.51` (13),
  `760H.61` (12), `800.796` (10), `814.796` (8), `841.796` (5), `810.7962` (5), `832.796` (4)

The editors' aviation footnotes point *back into the same decimal file the documents came out of*.
That is a real finding about editorial practice and a small one about archives.

### The roadmap: what to request, and whether you can see it first

**1919–1949.** RG 59, Central Decimal File, class **`800.796`** (general/international) and
**`<country>.796`** — e.g. `841.796` Great Britain, `810.79611` Pan-America, `832.796`, `835.796`,
`822.796`, `814.796`. Subdivisions: `7961` laws and regulation; `248` aircraft. The decimal-file
series NAIDs are **2555709** and **302021** (named in `digitized-ranges-index.json`).

**Is it digitised? No.** Of the 624 digitised decimal ranges NARA has published for those two
series, **zero** are `.796`. The digitised ranges cover only classes 131, 131.1, 133, 133.1 (visa
and passport) and 763.72* (WWI Austria-Hungary/Germany). The artifact's own note says the omitted
digitised file units are name-filed, so this is a genuine absence, not an indexing gap. **You will
have to go to College Park.**

**1950–1963.** The decimal file continues but **the classification was renumbered in 1950 and this
stack ships no gloss for it** — `decimal-class-labels.json` carries only the 1910–1949 schedule.
Do not carry `.796 = aerial navigation` across 1950. One concrete 1961–63 pointer does appear in
`frus1961-63v22`'s own Sources section: **`611.9494: U.S.-Japan aviation negotiations`**.

**1963–1973 (Central Foreign Policy File, subject-numeric).** The designator is **`AV`**, and FRUS's
own front-matter Sources sections gloss the subdivisions for you:

| designator | gloss, quoted from the volume's Sources section | volume |
|---|---|---|
| `AV 2 INDIA` | "general aviation reports and statistics, India" | `frus1969-76v11`, `frus1969-76ve07` |
| `AV 3 ICAO` | "International Civil Aviation Organization" | `frus1964-68v34` |
| `AV 9 JAPAN–US` | "Aviation routes and schedules" | `frus1964-68v29p2` |
| `AV 9 CZECH–US`, `AV 12–1 CZECH` | "aviation issues" | `frus1964-68v17` |
| `AV 12–2 S AFR` | "Aviation (civil); purchase by, sale, or transfer to South Africa" | `frus1964-68v09` |

Only **96 documents in 8 volumes** carry an `AV` source in the came-from channel (`AV 12` 45,
`AV 12 US` 39, then singletons). That is a small printed footprint over a large file — the strongest
"FRUS selected, the file is bigger" signal in this scope.

**Where the offline stack stops.** `series-facts-index.json` has **no entry** for NAID 2555709 or
302021, so I cannot give you creator, extent, facility or access status for the central decimal
file. That is the documented limit of this stack (695 series carry facts; it barely reaches before
1940), not evidence about the records.

---

## 7. Subject tags — usable as a candidate generator, not as a scope

Three aviation tags exist in `document-subject-index.json`: **324** "Aviation" (Science and
Technology/General), **335** "Civil aviation" (Global Issues/Air Safety), **376** "Aviation
security".

| tag | docs | vols | in gold | precision | lift |
|---|---|---|---|---|---|
| 324 Aviation | 2,845 | 346 | 613 | 0.215 | 33.6x |
| 335 Civil aviation | 1,270 | 235 | 375 | 0.295 | 46.1x |
| 376 Aviation security | 7 | 4 | 0 | 0.000 | 0.0x |

Recall of all three combined over the 1,969-document gold set: **809 of 1,969 (41%)**. They are
string matches, not semantic analysis, and tag 324 is a bare word that will pull in military
aviation, aviation gasoline and aviation instructors. Good for widening a search; bad as a
definition of the topic.

---

## 8. The decade shape, with rates

Raw counts alone would mislead badly here — the 1940s hold 74,043 dated non-apparatus documents and
the 1870s 5,798. Rate is per 1,000 dated non-apparatus documents of that decade, periodised on
`document_dates.date_iso` (**`frus:doc-dateTime-min`**, the editorial document date — *not* the
volume's series year).

**`"civil aviation"`**

| decade | raw | denominator | per 1,000 | top volume's share of the numerator |
|---|---|---|---|---|
| 1910s | 2 | 30,359 | 0.07 | `frus1919Parisv08` 2/2 |
| 1920s | 6 | 19,733 | 0.30 | `frus1928v01` 3/6 |
| 1930s | 50 | 39,196 | 1.28 | `frus1932v01` 12/50 |
| **1940s** | **525** | 74,043 | **7.09** | `frus1944v02` 126/525 |
| 1950s | 187 | 42,296 | 4.42 | `frus1951v06p1` 14/187 |
| 1960s | 105 | 27,650 | 3.80 | `frus1969-76ve01` 13/105 |
| 1970s | 126 | 22,259 | 5.66 | `frus1969-76ve01` 21/126 |
| **1980s** | 52 | 5,949 | **8.74** | `frus1981-88v04` 16/52 |

**`"air transport"`**

| decade | raw | denominator | per 1,000 | top volume's share |
|---|---|---|---|---|
| 1920s | 24 | 19,733 | 1.22 | `frus1929v01` 18/24 |
| 1930s | 36 | 39,196 | 0.92 | `frus1935v01` 4/36 |
| **1940s** | **740** | 74,043 | **9.99** | `frus1944v02` 60/740 |
| 1950s | 253 | 42,296 | 5.98 | `frus1952-54v13p1` 18/253 |
| 1960s | 193 | 27,650 | 6.98 | `frus1961-63v21` 14/193 |
| 1970s | 55 | 22,259 | 2.47 | `frus1969-76ve01` 8/55 |
| 1980s | 10 | 5,949 | 1.68 | `frus1981-88v13` 3/10 |

Three notes on the tails. **The 1940s rate rests on 525 documents with the top volume holding only
126** — broad and real. The pre-1910 "landing rights" rows are the cable false friend of §4, not
aviation, and I have excluded them from any claim.

**The 1980s row deserves a correction to what I first wrote.** The rate of 8.74 per 1,000 is the
highest in the series, and on 52 documents against a 5,949-document decade my first reading was
"thin decade, not a resurgence". Following the `Aeroflot` thread changed that. The 1980s cluster is
concentrated in `frus1981-88v04` and is **coherent, not scattered**: its 27 Aeroflot documents run
from **1983-09-01** — `frus1981-88v04/d86`, `d87`, `d88`, a briefing memorandum from the Assistant
Secretary for European Affairs, a Fortier NSC memorandum, and Shultz to Reagan, all dated the day
KAL 007 was shot down — through `d95`, **National Security Decision Directive 102** (1983-09-05),
to `d99`, Eagleburger to Reagan (1983-09-06). `"KAL 007"` returns 22 documents in 6 volumes;
`"Korean Air Lines"` 11 in 4. So the 1980s peak is one crisis and its landing-rights sanctions —
which is exactly the kind of "small decade's rate is one negotiation" case the rate column exists to
expose, except that here the negotiation is squarely on your topic. It is thin *and* on point.

---

## 9. What I would do next, in order

1. **Start with `frus1944v02/comp9`** (252 documents, `800.796` throughout). Everything in the
   1943–46 policy argument — the five freedoms, the chosen instrument, cabotage, the Anglo-American
   split — is staged there. Then `frus1946v01/comp22` for Bermuda.
2. **Run the `.796` query, not a text search, for 1919–1949.** It finds 507 documents no aviation
   heading reaches, including all of `frus1941v02` (28), `frus1931v03` (21) and `frus1943China` (18).
3. **For the Latin American story** — which is the largest single body after Chicago — read the
   two repeating formulas as one arc: "Good offices … in behalf of American interests desiring to
   establish air lines in Latin America" (1927–33, `frus1928v01/ch24`, `frus1929v01/ch17`) and
   "Elimination of Axis-controlled airlines" (1940–42, six countries). The competitive-position
   question is answered more directly there than anywhere else in the corpus.
4. **Drop "competitive position" and "American flag" from your search vocabulary.** Use
   `fifth freedom`, `cabotage`, `chosen instrument` (scoped to the 1940s), `air carriers`,
   `American carriers`, and the carrier names.
5. **For 1963–73 use the `AV` designators**, not text search — the printed footprint is 96
   documents but the designators name the file you would order.
6. **Do not trust either of my scoping routes after 1960.** The `.796` route stops at 1949 and no
   post-1960 volume carries a civil-aviation chapter heading outside hijacking and the SST. The
   Cold War bilateral story — the US–Soviet air services agreement, Aeroflot's landing rights and
   their suspension after KAL 007 — is in the corpus (101 `Aeroflot` documents in 37 volumes,
   1961–1988) and is reachable **only** by text search. Start at `frus1981-88v04/d86`–`d99`
   (1–6 September 1983, including NSDD 102) and `frus1969-76v40` (7 documents, all 1971).
7. **Before travelling**: nothing in class `.796` is digitised. Budget for College Park.

---

## Appendix A — what I measured, and honest limits

- **Documents read.** I retrieved and read **28 documents' text windows** (6 pre-1910
  "landing rights"; 10 non-literal "landing rights" misses; 12 "chosen instrument"), each with its
  full `length(body_text)` captured beside it, saved to `prelanding.txt` and
  `chosen_instrument.txt` in the run directory. I retrieved **windows, not whole bodies** — I did
  not capture any document at its full `length(body_text)`, and no claim above rests on having read
  a document end to end. I have quoted short fragments from **11** of them, all from result sets
  retrieved in this session. I also read **headers only** (no body) for 14 `frus1944v02` documents
  and 8 `frus1981-88v04` documents.
- **One finding I got wrong first and corrected.** My §8 draft called the 1980s "civil aviation"
  peak "a thin decade, not a resurgence". Chasing the `Aeroflot` zero-lift result showed the
  cluster is a single coherent crisis (KAL 007). The correction is in §8 with the decisive query —
  the per-volume `Aeroflot` date-range query — and both readings are stated there rather than the
  first being quietly deleted.
- **What the two "sets" are.** Neither the chapter route nor the `.796` route is ground truth. The
  chapter route over-captures on compound headings (documented, and quantified: 404 documents) and
  the `.796` route stops at 1949. The gold set is a scoping instrument, not a definition of the
  topic, and precision figures against it are lower bounds.
- **Never combined.** Came-from (`document_sources`) and pointed-at (`external_citations`) are
  reported separately throughout and are never summed. `citation_era` is reported as a citation
  *form*, never as a timeline.
- **Not answered here.** I did not run any spelling-variant or apparatus/document-split count on
  the TEI XML. `body_text` in this index contains editorial footnotes, so **every term frequency
  above blends document language with editors' language, and I have not separated them.** A real
  density claim — how much of the *printed document text* (as against the apparatus) is aviation —
  needs the TEI, and I did not go there in a scoping pass.
- **One procedural note.** My first phrase-count pass was a shell loop that spawned a fresh
  `sqlite3` per query and was still running when I replaced it with a single-connection Python
  pass; I stopped it mid-run. Its partial output agreed exactly with the replacement on all eight
  phrases both computed (civil aviation 1,061/236; air transport 1,349/264; landing rights 272/138;
  air routes 377/145; air navigation 188/84; commercial aviation 197/73; traffic rights 54/29; air
  services 551/177). `queries.log` contains both passes' commands in the order they were issued.
- **Files on disk** in the run directory: `aviation_sections.tsv` (165 sections),
  `aviation_docs.tsv` (1,853 broad pairs), `aviation_docs_tight.tsv` (1,449 tight pairs),
  `prelanding.txt`, `chosen_instrument.txt`, `phrases2.out`, `comp.out`, and every script named
  above.
