# Scoping memo: international civil aviation in FRUS

**Question.** How did the United States handle international civil aviation questions — landing rights, air routes, and the competitive position of American carriers?

**Corpus.** The local FRUS Explorer index: 316,839 documents across 552 volumes (`SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM document_cache`). Bundled reference data from `/Applications/FRUS Explorer.app/Contents/Resources/`. No network; nothing written outside my scratch directory.

---

## 1. Bottom line

This is a well-served question, and unusually so: **FRUS's own editors treated international civil aviation as a named compilation topic for roughly a quarter-century (1927–1951)**, so for that period you are not reverse-engineering a subject out of a keyword search — you are reading chapters the Office of the Historian already assembled under headings like *"Good offices of the Department of State in behalf of American interests desiring to establish air lines in Latin America"* and *"Preliminary and exploratory discussions regarding International Civil Aviation; Conference held at Chicago, November 1–December 7, 1944."*

The centre of gravity is **1943–1948**, and the single richest object in the corpus is a **252-document, ~618,000-character compilation in `frus1944v02`** running from September 1943 to December 1944 — the entire American internal debate and Anglo-American negotiation leading into the Chicago Conference, closing with Roosevelt–Churchill correspondence and Berle's 38,000-character final report to the President.

After 1951 the topic does **not** disappear, but it stops being a named compilation and dissolves into country volumes (Soviet Union, China) and thematic "global issues" volumes. Retrieval there requires different instruments, described in §3.

**Rough size of the field:** depending on how tightly you draw it, between **1,511 and 6,643 documents** (0.5%–2.1% of the corpus). See §4 for why that range is so wide and which end I would trust.

---

## 2. What the corpus actually holds — the structural evidence

The strongest single finding of this pass came from scanning FRUS's own table-of-contents structure rather than from searching text. `volume_structures` stores each volume's chapter/subchapter tree; I matched section titles against `aviat|air transport|air navig|airline|air line|air route|landing right|aeronaut|air servic|civil air|airway` and got **187 matching sections**. A condensed picture of what those headings show:

**Phase 1 — Latin America and the carrier-promotion state (1927–1942).**
The topic *enters* FRUS not as aviation policy but as commercial protection. `frus1928v01` and `frus1929v01` carry a chapter literally titled *"Good offices of the Department of State in behalf of American interests desiring to establish air lines in Latin America"*, with **Pan American Airways, Incorporated** as a named subchapter (45 documents in 1928, **132** in 1929), plus subchapters for Tri-Motors Safety Airways and Latin American Airways. Adjacent 1927 material: representations to Guatemala against a *monopoly concession for a Central American air line*. By 1940–42 the same geography turns strategic: five consecutive chapters on *"elimination of German influence from"* Brazilian, Colombian, Ecuadoran, Bolivian and Chilean airlines, and *"Axis-controlled airlines"* in Argentina and Chile. The carrier-competition question and the security question are the same documents.

**Phase 2 — The bilateral technical network (1929–1939).**
A long, dull, and very complete run of *"Arrangement between the United States and X regarding air navigation, effected by exchange of notes"* — Italy 1931, Germany 1932, South Africa 1933, Norway 1933, Sweden 1933, Denmark 1934, the UK 1935, the Irish Free State 1937, Canada 1938, France 1939, Liberia 1939 — usually paired with a companion arrangement on *pilot licenses*. Alongside them: American participation in the **International Commission for Air Navigation** (Paris 1929), the **Warsaw** private-air-law conference (1929), the **Rome** conference on private aerial law (1933), the **Habana Convention on Commercial Aviation** article IV interpretation dispute (running as a chapter in 1933, 1934 *and* 1935), and the **Inter-American Technical Aviation Conference** (Lima 1937).

**Phase 3 — Wartime route-grabbing and the postwar settlement (1943–1948).**
This is the dense core. Beyond the Chicago compilation, note:
- `frus1943` (the Washington/Quebec conferences volume) has two subsections flatly titled *"Postwar civil aviation policy"*.
- `frus1944v05` (Near East) carries four consecutive subchapters on **postwar civil air rights in Egypt, India, Iran (especially Abadan)**, and *"use of an air route over Saudi Arabia and the construction of an airfield near Dhahran."* This is where aviation, oil and basing meet.
- `frus1945Berlinv01` and `v02` both contain a *"Civil aviation policy"* subsection — i.e. it was on the Potsdam agenda.
- `frus1945v06` / `frus1945v08`: *"Assurances sought by the United States that the United Kingdom would not oppose efforts by the United States to conclude bilateral civil air transport agreements"* — the American bilateral strategy stated as a heading.
- `frus1946v01`: *"United States policy with respect to international civil aviation questions: **the Bermuda Conference** and related developments"* (32 documents).
- `frus1946v05` alone lists **twelve** signed bilateral air agreements/arrangements (Bermuda/UK, Australia, India, New Zealand, Belgium, Denmark ×2, France ×2, Norway, Spain, Sweden), and `frus1946v07`/`v08`/`v10`/`v11`, `frus1947v03`/`v05`/`v08`, `frus1948v09` add Egypt, Greece, Lebanon, Siam, China (Nanking, 20 Dec 1946), Argentina, Brazil, Colombia, Mexico, Uruguay, Bolivia, Chile, Paraguay, Newfoundland/Fiji, Syria, Israel. **The bilateral network is documented country by country, and it is the direct evidence for "competitive position of American carriers."**

**Phase 4 — Cold War closure and a new problem set (1948–1980s).**
`frus1948v04` and `frus1949v05` carry *"Civil aviation policy of the United States toward the Soviet Union and Eastern Europe"* (32 + 27 documents) — the closing of the East. `frus1949v09` has *"Sino-Soviet negotiations respecting trade and aviation rights in Sinkiang."* Then the named headings stop. Post-1951 the only aviation section titles in the whole corpus are `frus1964-68v34` (*"Development of the Supersonic Transport Aircraft"*, 19 docs; *"Hijacking"*, 19 docs) and `frus1969-76ve01` (*"U.S. Policy Towards Terrorism, Hijacking of Aircraft, and Attacks on Civil Aviation"*, with sub-chapters on the **U.S.–Cuba hijacking agreement 1969–73** (21 docs), the **Beirut airport raid and TWA 840** (36 docs), and the **PFLP hijackings and anti-hijacking measures** (45 docs)).

---

## 3. What I would search for — three independent axes, and why you need all three

No single retrieval handle covers this topic. I used three and measured their overlap.

### Axis A — text (FTS5, porter-stemmed)
Composite query, run against `frus_documents`:

```
"civil aviation" OR "landing rights" OR "air transport" OR "air navigation"
OR "air route" OR "commercial aviation" OR "air service" OR "traffic rights"
OR "fifth freedom" OR cabotage OR "aviation agreement" OR "air agreement"
```
→ **3,669 documents in 414 volumes.**

Individual phrase counts (documents, whole corpus):

| phrase | docs | | phrase | docs |
|---|---|---|---|---|
| aviation | 4,061 | | airport | 2,548 |
| air base | 1,557 | | air transport | 1,485 |
| airline(s) | 1,255 | | civil aviation | 1,169 |
| aeronautics | 924 | | airways | 888 |
| air service(s) | 563 | | air route(s) | 386 |
| landing rights | 274 | | air line | 260 |
| commercial aviation | 202 | | air navigation | 199 |
| fifth freedom | 107 | | cabotage | 73 |
| traffic rights | 56 | | air services agreement | 10 |

Named entities and instruments: Pan American Airways 546, ICAO 254, Civil Aeronautics Board 223, International Civil Aviation Organization 162, Civil Air Transport 158, Panagra 136, Aeroflot 103, China National Aviation Corporation 88, KLM 83, Lufthansa 58, Trans-World 48, British Overseas Airways 45, Trans World Airlines 42, Braniff 41, Pan American World Airways 40, Aerovias 33, "freedoms of the air" 32, SCADTA 31, Chicago convention 31, PICAO 26, "five freedoms" 24, Imperial Airways 23, Bermuda agreement 22, Warsaw convention 6.

### Axis B — subject tags
The bundled `document-subject-index.json` vocabulary contains four relevant subjects, and `document_subject_refs` in the DB uses the same integer ids (verified: the per-subject document counts equal the vocabulary's `df` exactly):

| id | category / subcategory / name | docs |
|---|---|---|
| 324 | Science and Technology / General / **Aviation** | 2,876 |
| 335 | Global Issues / Air Safety / **Civil aviation** | 1,298 |
| 366 | International Law / General / **Airspace** | 242 |
| 376 | Global Issues / Air Safety / **Aviation security** | 7 |

Union of the four: **4,423 documents.** This is the axis that *works after 1951*, where headers are generic ("Memorandum of Conversation") and tell you nothing. Top volumes on subject 335 alone: `frus1944v02` (245), `frus1964-68v14` (41), `frus1969-76ve01` (34), `frus1961-63v05` (28), `frus1945v02` (27), `frus1946v11` (24), `frus1949v05` (23).

**Caveat, in the artifact's own words:** these tags are *"Detected topics from case-insensitive string matching of subject names and variants, NOT semantic analysis — treat as recall-oriented candidates rather than ground truth."* I spot-checked three tagged documents in `frus1964-68v14` (d3, d11, d22) and all three genuinely concern the U.S.–Soviet **Civil Air Agreement** — see §5.

### Axis C — the State Department's own filing class (the best of the three)
This is the axis I would push hardest, and I did not expect it to be this clean.

`document_sources.decimal_class` holds the central-file number from each printed document's source note. The bundled 1910–1949 classification schedule (`decimal-class-labels.json`) glosses the relevant suffix tree:

```
.79      Other means of communication and transportation
.796     Aerial navigation
.7961    Laws and regulation      .796101 Registration/Enrollment/License/Permit
.7962    Stations. Landing fields. Mooring towns. Seadromes. Fueling
.79601   Fees                     .796023 Rates
.7965    Offenses committed on aircraft
.7968    Complaints against the service
.7969    Other matters respecting aircraft   .796901 Movement of commercial aircraft
.796A    Aeronautic advisers
```

Documents whose source note cites any `.796` class: **1,511, across 88 volumes.** Breakdown by suffix: `.796` general 868, `.7961` laws/licensing 316, `.7962` **landing fields/stations 230**, `.7969` 59, `.7968` 38.

The class number is composed as *class digit + country number + suffix*, so it also yields a **geography of the question**, straight out of the Department's own filing rather than out of my vocabulary:

| docs | class | country |
|---|---|---|
| 290 | 800.796 | World / general |
| 260 | 810.796xx | America. Pan-America |
| 157 | 811.796xx | United States |
| 94 | 893.796 | China |
| 83 | 832.796 | Brazil |
| 59 | 835.796 | Argentina |
| 59 | 882.796 | **Liberia** |
| 51 | 822.796 | Ecuador |
| 49 | 841.796 | Great Britain |
| 45 | 890F.7962 | Asia |
| 32 | 821.796 | Colombia |
| 28 | 859B.7962 | Denmark (Greenland) |
| 26 each | 825/853B | Chile, Portugal (Azores) |
| 24 each | 812/814 | Mexico, Guatemala |

Latin America plus China plus Liberia dominates — which is the same story the section titles tell, arrived at independently. (The Liberia figure concentrates in `frus1942v04` (41) and `frus1943v04` (18): the Pan Am trans-African route and Roberts Field.)

The source notes also expose **named company subfiles**, which is a direct handle into NARA RG 59: `810.79611 Pan American Airways, Inc.`, `810.79611 Tri-Motors Safety Airways`, `814.796 Latin American Airways`, `810.79611 Tampa-New Orleans-Tampico Airlines`, `811.79690 Pan American Airways`.

Repository profile for the text-core set: Department of State 2,540; National Archives 201; Nixon Presidential Materials 85; Carter Library 68; Johnson 54; Kennedy 45; CIA 33; Eisenhower 28; Reagan 26; Ford 24; Roosevelt 13. Most-cited lot files: **M–88 (47)**, **63 D 351 (29)**, 54–D270 (16), 79–R01012A (7), 62 D 1 (7).

---

## 4. What I measured — the overlap, and why the answer is a range

Three axes, computed over the same 316,839 documents:

|  | documents |
|---|---|
| A — text core | 3,669 |
| B — subject tags (324/335/366/376) | 4,423 |
| C — `.796` decimal class | 1,511 |
| A ∩ B | 2,097 |
| A ∩ C | 585 |
| B ∩ C | 779 |
| **A ∪ B ∪ C** | **6,643** (2.10% of corpus) |
| in C but in neither A nor B | **685** |

**Read the A ∩ C cell.** Only 585 of the 1,511 documents the Department itself filed under *Aerial navigation* contain any of my twelve core phrases. **926 of them (61%) are invisible to the obvious keyword search.** I sampled 15 of the 685 that are invisible to *both* other axes and read two in full:

- `frus1929v01/d400`, source note `810.79611 Pan American Airways, Inc./602` — the Vice Consul at Port-of-Spain reporting that Trinidad had granted Pan Am *"temporary authorization to operate … and to use temporary landing place"*, with Atlantic Airways of Toronto negotiating in parallel. Landing rights, verbatim — but phrased as "landing place."
- `frus1940v05/d872`, source note `821.796 Avianca/126` — Ambassador Braden in Bogotá on Avianca absorbing Arco, with the Colombian President's personal guarantee. Carrier competition and airline nationalisation, containing none of my phrases.

This is the central methodological result of the pass: **the vocabulary of the topic changed faster than the filing did.** If you search only for modern terms of art ("landing rights", "traffic rights", "fifth freedom") you will systematically lose the 1920s–30s, where the same transactions are described as landing *places*, *permits*, *concessions* and *good offices*.

**Chronology.** Documents in axis A by document date, against the corpus's own decade totals:

| decade | axis A | all docs | rate |
|---|---|---|---|
| 1910s | 40 | 30,391 | 0.13% |
| 1920s | 134 | 19,740 | 0.68% |
| 1930s | 242 | 39,202 | 0.62% |
| **1940s** | **1,667** | 75,680 | **2.20%** |
| 1950s | 537 | 46,521 | 1.15% |
| 1960s | 443 | 29,859 | 1.48% |
| 1970s | 288 | 23,275 | 1.24% |
| 1980s | 92 | 6,123 | 1.50% |

The 1940s peak is real in both absolute and relative terms. The 1950s–80s plateau at ~1.2–1.5% is roughly double the interwar rate — i.e. the topic did not fade after Bermuda, it merely lost its own chapter headings.

**Extent.** Axis A is 3,669 documents / 35.3M characters (~7.1M words). Axis C is 1,511 documents / 3.2M characters (~640k words). The mean axis-C document is 2,118 characters; the mean axis-A document is 9,611. Axis A is dragging in long conference minutes and editorial notes where an aviation phrase appears once in passing; **axis C is the precision instrument and axis B is the recall instrument.**

---

## 5. Where I would start reading

Ranked by aviation density (axis A∪B∪C hits as a share of the volume's own documents, minimum 30 hits):

| volume | hits | vol. docs | density | what it is |
|---|---|---|---|---|
| `frus1944v02` | 298 | 915 | **32.6%** | 1944 Economic & Social Matters — the Chicago Conference compilation |
| `frus1929v01` | 213 | 859 | 24.8% | Pan Am in Latin America; ICAN Paris; Warsaw private air law |
| `frus1964-68v14` | 55 | 339 | 16.2% | Soviet Union — the U.S.–Soviet Civil Air Agreement |
| `frus1941v06` | 95 | 631 | 15.1% | American Republics — eliminating Axis airlines |
| `frus1928v01` | 112 | 845 | 13.3% | Pan Am in Latin America, first instalment |
| `frus1942China` | 83 | 657 | 12.6% | CNAC, the Hump, wartime China routes |
| `frus1969-76ve01` | 55 | 448 | 12.3% | Global Issues — hijacking and attacks on civil aviation |
| `frus1941v07` | 61 | 538 | 11.3% | American Republics — Ecuador, Peru, Colombia airlines |
| `frus1943` | 69 | 658 | 10.5% | Washington/Quebec conferences — "Postwar civil aviation policy" |
| `frus1961-63v05` | 36 | 392 | 9.2% | Soviet Union — FAA Administrator talks, Nov 1962 |
| `frus1964-68v34` | 31 | 338 | 9.2% | Energy/Science — SST and hijacking |
| `frus1946v11` | 82 | 1,145 | 7.2% | American Republics — the Latin bilateral round |
| `frus1948v08` | 73 | 897 | 8.1% | China — revision of the 1946 air transport agreement |
| `frus1942v04` | 73 | 954 | 7.7% | Near East/Africa — Liberia, Anglo-American Middle East air services |

**Read `frus1944v02` first.** Its aviation compilation is 252 documents / ~618k characters, opening 28 Sept 1943 with a Berle memorandum of conversation and closing 7 Dec 1944 with Berle's report to Roosevelt from Chicago (38,085 characters — effectively a monograph). Between them sit Winant's London telegrams, Halifax's notes, and five Churchill–Roosevelt messages in the final fortnight (d508, d512, d514). The Anglo-American fight over the fifth freedom is *in* this compilation, not reconstructed from it.

**Institutional handle for the "who".** The `persons` table carries 129 role descriptions containing "aviation"/"aeronautic" (100 distinct people), and they name the bureaucratic home of the question as it moves: **Aviation Division, Department of State** (Stokeley W. Morgan, chief; John O. Bell; later Henry T. Snowdon) → **Office of Transport and Communications Policy** (Charles P. Taft, director; J. Paul Barringer; Raymond Vernon on the Commercial Policy Staff) → **Aviation Policy Staff** (Edward A. Bolster, 1954). Externally: Civil Aeronautics Board chairmen, the ICAO Council presidency (Walter Binaghi), FAA international affairs. Searching on these office titles is a better handle on the policy machinery than searching on individuals.

---

## 6. Traps — things I got wrong first, so you don't have to

**(a) The FTS index is porter-stemmed, and it breaks the single most obvious query term.** `MATCH '"landing rights"'` returns **274** documents; only **248** contain the literal string; the other **26 (9.5%) are stem artifacts** — the stemmer folds *landing → land*, so the query also matches "land rights" and "landed rights." Two of the four earliest hits in the whole corpus are of this kind (`frus1911/d422`: *"a more perfect system of landed rights"*; `frus1912/d800`: *"authoritative record of land rights"* in Korea). Verified with `snippet()`. There is no compensating under-match: every literal occurrence is also an FTS hit.

**(b) `cabotage` is a shipping word before it is an aviation word.** The earliest corpus hit, `frus1909/d329`, is a Honduran dispute over *"comercio de cabotage"* — coastwise maritime trade. Filter by date or read the context.

**(c) "open skies" is a homonym trap and the wrong sense dominates.** 100 hits, peaking in the **1950s (48)** and 1960s (26): that is Eisenhower's 1955 aerial-inspection proposal, an arms-control term, not aviation liberalisation. Same for **"overflight"** (1,002 hits, peaking 1960s at 465) — that is reconnaissance, U-2 and successors, not commercial transit rights.

**(d) "air service" is *mostly* safe but not entirely.** In a random sample of 12 snippets, 10 were civil route service (Moscow–New York, trans-Pacific, Chungking); 2 were military ("the Naval Air Service of Peru", "the air services of Hungary"). The explicit military compounds (`"army air service"`, `"naval air service"`, `"air service command"`) total only 14 documents corpus-wide, so the contamination is small.

**(e) `person_mentions` is not a useful topical axis here.** Ranking people by mentions inside the axis-A set returns Rusk (170), Kissinger (133), Nixon (119), Kennedy (80), Dulles (70) — i.e. the standing cast of every post-1945 volume, not the aviation actors. The person index is dense for the Cold War volumes and thin for the interwar ones, so it measures volume-era, not subject. Use the *role* field instead (§5).

**(f) There is no aviation cluster in the semantic map.** `semantic-map-index.json` has 179 clusters over 314,483 documents; none of their term labels contains an aviation word. At corpus scale the topic is dispersed across regional clusters rather than forming one of its own. That is a fact about the map, not about the sources — but do not expect the map view to hand you this subject.

**(g) The section-title scan under-detects after 1951 by construction.** Only 14 of 187 matching section titles fall in 1952+ volumes, and I do not think that reflects the documentary record: post-1952 FRUS is organised by country and by crisis rather than by transaction type, so aviation content sits inside chapters named for the bilateral relationship. Cross-check with axes B and C before concluding anything about decline.

**(h) File-count mismatch worth noting.** `/Users/jbotts/Development/frus/volumes/` contains **694** XML files while the index and manifest cover **552** volumes. I did not investigate the 142 extras; if you go to the TEI directly, do not assume file presence means indexed coverage.

---

## 7. What this pass did *not* do

- I did not read the TEI XML at all — every measurement above is from the SQLite index and the bundled JSON.
- I did not evaluate precision of the subject tags systematically; I spot-checked 3 documents in one volume and 2 class-only documents. The artifact's own provenance string warns they are recall-oriented candidates.
- I did not chase the multilateral institutional record (ICAO/PICAO governance, the Chicago Convention's ratification, the Two Freedoms and Five Freedoms agreements) beyond counting mentions. `frus1946v01`'s Bermuda compilation and the ICAO/PICAO counts (254/26) suggest there is a real institutional thread I only touched.
- I did not look at `cross_references` or `external_citations`, either of which would show how the aviation compilations cite each other and what archival material outside the printed record the footnotes point to.
- I did not attempt an era-by-era vocabulary expansion. Given finding §4 — that 61% of the Department's own aviation-filed documents miss my keyword net — **the highest-value next step is to derive period-specific vocabulary from the axis-C documents themselves** (take the 685 class-only documents, extract their distinctive terms, and feed those back into axis A). That is the move most likely to expand this from 6,643 candidates to a defensible corpus.

---

## Appendix — exact SQL for the composite queries

`queries.log` records every command in order as it was run; a handful of the longer multi-line SQL statements are logged with a `<description>` placeholder rather than inline. Those statements, in full:

```sql
-- CORE (used throughout as axis A)
-- '"civil aviation" OR "landing rights" OR "air transport" OR "air navigation"
--   OR "air route" OR "commercial aviation" OR "air service" OR "traffic rights"
--   OR "fifth freedom" OR cabotage OR "aviation agreement" OR "air agreement"'

-- three-way overlap (§4)
WITH t AS (SELECT volume_id,document_id FROM frus_documents WHERE frus_documents MATCH '<CORE>'),
     s AS (SELECT volume_id,document_id FROM document_subject_refs WHERE subject IN (324,335,366,376)),
     c AS (SELECT volume_id,document_id FROM document_sources WHERE decimal_class LIKE '%.796%')
SELECT (SELECT COUNT(*) FROM t), (SELECT COUNT(*) FROM s), (SELECT COUNT(*) FROM c),
       (SELECT COUNT(*) FROM t JOIN s USING(volume_id,document_id)),
       (SELECT COUNT(*) FROM t JOIN c USING(volume_id,document_id)),
       (SELECT COUNT(*) FROM s JOIN c USING(volume_id,document_id)),
       (SELECT COUNT(*) FROM (SELECT * FROM t UNION SELECT * FROM s UNION SELECT * FROM c));
-- returns: 3669|4423|1511|2097|585|779|6643

-- landing-rights stemmer measurement (§6a)
WITH f AS (SELECT volume_id,document_id FROM frus_documents WHERE frus_documents MATCH '"landing rights"'),
     l AS (SELECT volume_id,document_id FROM document_cache
           WHERE body_text LIKE '%landing right%' OR header LIKE '%landing right%'
              OR source_note LIKE '%landing right%')
SELECT (SELECT COUNT(*) FROM f), (SELECT COUNT(*) FROM l),
       (SELECT COUNT(*) FROM f JOIN l USING(volume_id,document_id)),
       (SELECT COUNT(*) FROM f WHERE NOT EXISTS(SELECT 1 FROM l WHERE l.volume_id=f.volume_id AND l.document_id=f.document_id)),
       (SELECT COUNT(*) FROM l WHERE NOT EXISTS(SELECT 1 FROM f WHERE f.volume_id=l.volume_id AND f.document_id=l.document_id));
-- returns: 274|248|248|26|0

-- volume density ranking (§5)
WITH t AS (...), s AS (...), c AS (...),
     u AS (SELECT * FROM t UNION SELECT * FROM s UNION SELECT * FROM c),
     g AS (SELECT volume_id, COUNT(*) n FROM u GROUP BY 1),
     v AS (SELECT volume_id, COUNT(*) tot FROM document_cache GROUP BY 1)
SELECT g.volume_id, g.n, v.tot, ROUND(100.0*g.n/v.tot,1)
FROM g JOIN v USING(volume_id) WHERE g.n>=30 ORDER BY 4 DESC;
```

Three helper Python scripts were written to `/tmp` and are named in `queries.log` at the point of use: `/tmp/sec.py` (corpus-wide section-title scan, 187 hits), `/tmp/sec2.py` (the same restricted to 1952+ volumes, 14 hits), `/tmp/geo.py` (mapping `.796` class numbers to the 1910–49 schedule's country table). All three read the database read-only via `mode=ro`.
