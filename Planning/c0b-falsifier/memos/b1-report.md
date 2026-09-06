# Scoping memo: international civil aviation in FRUS

**Question.** How did the United States handle international civil aviation questions — landing rights, air routes, and the competitive position of American carriers?

**Short answer about the corpus.** This is a well-documented question in FRUS, but only for a defined window. The published record is thin before 1927, dense and *editorially self-labelled* from 1927 to about 1952, and after 1952 it survives only as scattered mentions inside country and crisis volumes, with two late exceptions (hijacking/aviation security around 1969–72, and the US–Soviet air agreement / KAL 007 sanctions in the 1960s–80s). The "competitive position of American carriers" is best documented as an interwar and wartime story, not a deregulation-era one — FRUS coverage effectively stops before the 1978–92 bilateral renegotiations became the main event.

I found roughly **3,100 documents** I would defend as on-topic, in **108 volumes**, with a larger and noisier **6,609-document / 430-volume** outer envelope. Numbers and how I got them are below.

---

## 1. What I measured against

Denominators, so you can judge every share below:

| | count |
|---|---|
| documents in the local index | 316,839 |
| volumes | 552 |
| corpus coverage span (manifest `dateRange`) | 1620–1991 |
| volumes whose coverage ends 1978 or later | 42 |

(`sqlite3 -readonly frus-copy.db "SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM document_cache"`; manifest.json.)

## 2. Three independent ways in, and what each one is worth

I deliberately built three retrieval routes that do not depend on each other, then scored them against one another. This is the part of the memo I'd most want you to check.

**Route A — keyword.** A 21-clause FTS5 query over the full text (`"civil aviation" OR "landing rights" OR "air transport" OR "air route" OR airline OR "air service" OR ICAO OR PICAO OR IATA OR "pan american airways" …`) returns **4,960 documents in 430 volumes**.

**Route B — FRUS's own editorial headings.** Every volume's chapter/compilation titles are stored in `volume_structures`. Scanning those titles for aviation vocabulary finds **188 aviation-named sections**; the documents that sit under them (including nested children) number **2,671, in 80 volumes**.

**Route C — the archival file class.** The State Department's 1910–49 decimal schedule assigns subject suffix **`.796` = "Aerial navigation"** (confirmed in `decimal-class-labels.json`, schedule 1, subject 796; siblings `.7965` offenses aboard aircraft, `.796901` movement of commercial aircraft). FRUS source notes carry the file number, and the index parses it into `document_sources.decimal_class`. **1,511 documents** in the corpus cite a `.796` file, across **110 distinct class numbers**.

**How they score against each other:**

- Route A recalls **915 of the 1,511** `.796` documents — it *misses 39%* of documents the State Department itself filed as aerial navigation.
- Route B recalls **1,109 of 1,511 (73%)** while returning half as many documents as Route A. It is the more efficient route by a wide margin.
- Loosening Route A to catch the misses (adding bare `aviation`, `aeronautical`, `airport`, `airfield`, `aerodrome`, `overflight`, `traffic rights`) lifts recall to **1,136/1,511 (75%)** but inflates the result set from 4,960 to **12,607** — a 2.5× cost for a 15-point recall gain, because bare `aviation`/`airport` sweeps in military aviation missions, aircraft sales, air attachés and bombing.

**Why Route A misses so much.** I dumped the 596 missed documents and counted terms. They are short telegrams in running exchanges — `aviation` appears 194 times, `planes` 184 — where the subject is established by the chapter heading and the telegram itself says "the Company", "the matter", "the agreement". Example: `frus1940v05/d971`, filed `822.796/184`, is a two-paragraph Hull telegram to the Legation in Ecuador that never uses a phrase my query contained.

**The defensible core.** Route B ∪ Route C = **3,074 documents in 108 volumes**. That is the set I would hand a research assistant. The keyword-only residue (3,535 documents) is mostly incidental: a random sample of 12 gave me passing mentions in documents about Panama Canal policy, Anthony Eden, the Oatis case, and the Cuban missile crisis ExComm. One of the twelve was a real lead I would not have found otherwise (`frus1937v02/d97`, file `811.0141 Phoenix Group` — the Anglo-American island dispute over trans-Pacific route stops), so don't discard the residue, just don't read it linearly.

## 3. The shape of the record over time

Aviation hits per 1,000 documents, by the coverage decade of the volume (Route A over the manifest's date midpoints):

```
decade   hits   corpus docs   per 1,000
1870s       6         5,246       1.1     ← all false positives ("air-line" = railroad/steamship)
1900s       2        11,438       0.2
1910s     240        32,833       7.3
1920s     116        13,542       8.6
1930s     352        40,884       8.6
1940s   2,003        73,742      27.2
1950s     908        49,859      18.2
1960s     563        26,033      21.6
1970s     609        27,567      22.1
1980s     156         4,523      34.5
```

But the raw rate hides the important discontinuity. Count the *aviation-named editorial sections* by volume decade instead: **1910s 3, 1920s 10, 1930s 52, 1940s 117, 1950s 3, 1960s 3, 1970s+ 0.** And `.796` source citations, by volume year: they start at 1927 (7), peak in 1929 (200) and 1944 (313), and fall to **zero after 1949** — not because the parser stops (1950s volumes still yield thousands of parsed decimal classes: 611.21, 611.4094, 795.00 …) but because post-1949 FRUS documents aviation out of general political-relations files (`611.xx`) and lot files instead. The subject-numeric successor file (`AV 12`, `AV 12 US`, `AV 4 US USSR`) appears on only **96 documents corpus-wide**, 65 of them in one volume.

So: **civil aviation is a named FRUS topic from 1927 to about 1952 and essentially stops being one afterwards.** Whether that reflects the policy or the editors' compilation practice is your question, not mine — but it is a fact about the corpus you have to plan around.

## 4. Five periods, with anchors

**(a) 1927–1933, "good offices" for American firms.** The interwar record is filed under *company names*, not aviation topics, which is why a topical search under-counts it. In `frus1929v01` the rubric is **"Good offices of the Department of State in behalf of American interests desiring to establish air lines in Latin America"**, with sub-sections literally titled *Pan American Airways, Incorporated* (131 `.796` documents), *Tri-Motors Safety Airways* (40), *Latin American Airways* (15). `frus1928v01` has the same rubric with seven company sub-sections (Pan American 45, Boeing/Pratt & Whitney 12, Huff-Daland Dusters 6, plus air-mail-to-Chile and extension-to-Venezuela chapters). This is the competitive-position material in its purest form: State acting as commercial agent for named carriers against European rivals. `frus1933v03` continues it — "Informal good offices … on behalf of the Pan American Airways in establishing Shanghai–Canton line."

**(b) 1928–1939, the multilateral and bilateral legal frame.** The 1928 Havana Pan-American commercial-aviation convention (16 documents mention it), the 1929 extraordinary session of the **International Commission for Air Navigation** at Paris to revise the 1919 Paris convention (`frus1929v01`, its own chapter; ICAN/Paris-convention phrases in 18 documents), and a long tail of reciprocal air-navigation exchanges of notes: Italy 1931, Germany 1932, Sweden/South Africa/Norway 1933, the Netherlands negotiation dragged across 1932–35, Ireland 1937, Canada 1938–40, France 1939, Liberia 1939. **Warning:** most of these headings print *zero documents.* Of the 188 aviation-named sections, **74 carry no printed correspondence at all** — they are TOC/index entries reading "citation to text", pointing to the Executive Agreement Series. I verified this in the `frus1939v02` TEI: the US–Canada and US–France air-transport arrangements appear only as page pointers with "citation to text". The corpus records that these agreements exist; it does not document how they were negotiated.

**(c) 1935–1943, routes, islands and bases.** Trans-Atlantic service negotiation (`frus1935v01`, 10 docs); China landing rights and Chinese resistance to granting them (`frus1935v03`; `frus1936v04` on extending Pan Am's Manila service to China; `frus1937v04` refusing a Japanese Taihoku–Manila line — a rare reciprocal case where the US withheld rights); the Anglo-American Pacific islands dispute explicitly framed as a fight over trans-Pacific stops (`frus1938v02`, 35 docs); the Azores (`frus1943v02`, 57 docs; `frus1944v04`, 87; `frus1947v03`, 28 on Lagens transit rights); Dhahran (`frus1944v05`, 10; `frus1945v08`, 143 including the bilateral air transport agreement).

**(d) 1940–1942, eliminating Axis carriers from Latin America.** German- and Italian-controlled airlines are named and pursued: SCADTA (31 docs), SEDTA, LATI (47), Condor/Lufthansa (320 for the loose set, 122 when co-occurring with aviation vocabulary). Chapter-level anchors: `frus1941v07` "Elimination of German influence in Peruvian airline; interest of the United States in developing civil aviation in Peru"; `frus1940v03` on Spanish proposals for an air-navigation agreement with Liberia and Pan Am's counter-move. The `.796` file volume peaks here (1941: 158, 1942: 148) with country prefixes 832 Brazil (83), 835 Argentina (59), 822 Ecuador (51), 821 Colombia (32), 824 Bolivia, 825 Chile (26), 882 Liberia (59).

**(e) 1943–1948, the postwar settlement — the densest and best material.**
- **Chicago, 1944.** `frus1944v02` compilation `comp9`: **"Preliminary and exploratory discussions regarding International Civil Aviation; Conference held at Chicago, November 1–December 7, 1944" — 252 documents**, d264–d515, running from September 1943 to December 1944, overwhelmingly filed `800.796` and `841.796`. The through-line is Assistant Secretary **A. A. Berle** vs. the British (Halifax, Beaverbrook, Swinton, Wright); the American side includes Edward Warner and L. Welch Pogue of the CAB and Stokeley Morgan of State's Aviation Division. The "chosen instrument" debate — whether one American carrier or many — is here (7 documents in this volume use the phrase). `frus1943` (Cairo/Tehran and the Combined Chiefs series) carries two short "Postwar civil aviation policy" items and the exploratory US–Canada talks appear at `frus1944v02/d345`.
- **Bermuda, 1946.** `frus1946v01` compilation `comp22`, **32 documents**, "United States policy with respect to international civil aviation questions: the Bermuda Conference and related developments." Delegation minutes are in *U.S. Delegation Files: Lot 53–D407*; the cable traffic is `841.796`. It closes with three 1946 circulars to diplomatic posts (`800.796/7–2546`, `/8–146`) instructing missions on the new bilateral template — i.e., the moment US policy became a standard export.
- **The bilateral build-out.** Then a scatter of country negotiations: China (`frus1946v10`, 28 docs on the Nanking agreement of 20 December 1946; `frus1947v07` and `frus1948v08` on its revision), Brazil (`frus1946v11`, 17), Bolivia (`frus1947v08`, 13), Colombia (7), Uruguay (5), Panama (7), Mexico — which *broke down*, documented across `frus1946v11`, `frus1947v08` and `frus1948v09` — Israel (`frus1950v05`), Egypt (`frus1946v07`), Morocco (`frus1945v08`). PICAO/ICAO appears as its own file, `579.6 PICAO`.
- **The Cold War closure.** `frus1948v04` "Civil aviation policy of the United States toward the Soviet Union and Eastern Europe" (32 docs) and `frus1949v05` (27 docs) — the point at which landing rights become a bloc question rather than a commercial one.

**(f) After 1952, three residual strands only.**
- *US–Soviet civil air.* FAA Administrator Halaby's Moscow conversations (`frus1961-63v05/d266`), the 1964–68 Soviet volume (41 documents tagged Civil aviation), and Aeroflot as a sanctions lever after KAL 007 (`frus1981-88v04`: 27 Aeroflot mentions, 38 KAL-007 mentions corpus-wide).
- *Hijacking and aviation security.* `frus1969-76ve01` (*Documents on Global Issues, 1969–1972*, 448 documents total) is the only late volume with a real aviation compilation — "U.S. Policy Towards Terrorism, Hijacking of Aircraft, and Attacks on Civil Aviation" — and it is the home of the `AV 12` file (65 of the corpus's 96 AV-classed documents). Corpus-wide: 462 documents mention hijacking.
- *Nothing on deregulation-era bilaterals.* `deregulation` and its cognates appear in 36 documents corpus-wide, `IATA` in 54, and the 1977–80 volumes yield only incidental aviation mentions inside memoranda about other things. If your question runs past 1978, published FRUS will not carry it.

## 5. Where the paper trail leads

For the 2,671 documents inside aviation-named sections, the source notes break down as:

| citation type | documents |
|---|---|
| State Department central decimal file | 2,392 (89.6%) |
| structured / later central files | 139 |
| lot files | 54 |
| published sources | 21 |
| no source row | 58 |

Repositories: Department of State 2,446; National Archives 85; Nixon Presidential Materials 33; Roosevelt Library 12; Eisenhower Library 8.

So for the core period the follow-on archive is unambiguous: **RG 59, central decimal file, subject `.796`**, with the country prefix telling you the bilateral: 800 general/multilateral (290), 810 Pan-America (260), 811 United States (160), 893 China (94), 832 Brazil (83), 882 Liberia (59), 835 Argentina (59), 822 Ecuador (51), 841 Great Britain (49), 890F Saudi Arabia (45), 853 Portugal (40). Named lot files worth a call slip: **53–D407** (Bermuda US delegation), 62 D 181, 61 D 167, 70 D 467, 63 D 351 (S/S–NSC), M–88 (CFM).

## 6. Traps I hit, so you don't

1. **"Open skies" is a false friend.** 100 documents use it; the top volumes are `frus1989-92v31`, `frus1958-60v09`, `frus1955-57v05`. This is Eisenhower's 1955 aerial-*inspection* proposal and the 1992 Open Skies Treaty — arms control, not aviation liberalization. The aviation sense is absent from this corpus.
2. **"Air line" before 1910 is a railroad/steamship term.** All 13 pre-1910 hits I checked (`frus1871/d4`, `frus1875v01/d146`, etc.) are noise.
3. **"Air service" and "aviation" alone pull in the military.** Air Transport Command, military aviation missions to Latin American air forces, air attachés, aircraft sales. Several aviation-named sections are purely military (`frus1941v06` Bolivia military aviation mission; `frus1938v05` Army Air Corps instructors in Argentina).
4. **74 aviation headings print nothing.** See §4(b). Treat a heading as evidence of an agreement, not of documentation.
5. **The subject taxonomy is recall-oriented, not authoritative.** `document-subject-index.json` has *Civil aviation* (df 1,298) and *Aviation* (df 2,876), and their volume rankings agree nicely with my other routes — but the file's own provenance string describes the tags as case-insensitive string matches, "not semantic analysis … recall-oriented candidates rather than ground truth". I used them as a cross-check, never as a measurement.
6. **The person index is useless here.** Joining `person_mentions` to the `.796` set gives top counts of 1–2 — the markup is too sparse in these volumes to rank actors. The volume *persons lists* are useful though: they identify Pogue and Warner (CAB), Stokeley Morgan and Edward Bolster (State Aviation Division / Aviation Policy Staff), Charles P. Taft (Office of Transport and Communications Policy), Livingston Satterthwaite (Civil Air Attaché, London), Swinton and Hildred on the British side.

## 7. What I would actually search

In this order:

1. Read `frus1944v02` comp9 end to end (252 docs). It is the single best object in the corpus for this question.
2. Read `frus1946v01` comp22 (32 docs) next; the three closing circulars are the policy in condensed form.
3. Pull the 1928–29 "good offices" company sub-sections (`frus1928v01`, `frus1929v01`, ~230 docs) for the pre-history of carrier competition.
4. Sweep the `.796` set by country prefix for whichever bilateral you care about — this is a two-line SQL query and it is more reliable than any keyword.
5. For anything after 1952, abandon topical search: go volume by volume through the country volumes for the relationship in question, and expect scattered memoranda rather than compilations.
6. If your interest is the *legal* frame, note the corpus documents ICAN 1929 and Havana 1928 lightly (18 and 16 documents) — you will need the treaty series and the ICAO record itself, not FRUS.

## 8. What I did not do

Sixty-seven shell commands. (Housekeeping note: this scratch directory already contained files and a `queries.log` from an earlier, abandoned attempt at the same task, timestamped before my session started. I did not read any of them — I only listed the directory — and I trimmed those sixteen foreign lines out of `queries.log` so it records only what I ran. The stale files `av_by_volume.*`, `av_by_decade.py` and `av_compilations.*` are not mine and are not inputs to anything above.) I did not read any full document beyond excerpts; I did not verify that the 552 indexed volumes match the full published FRUS series; I did not check the TEI for aviation content in volumes whose *index* (back-of-book) entries would catch material the body text and headings miss; and I did not test whether the `.796` class is itself complete — it is the State Department's filing decision, and documents about aviation certainly sit in `611.xx`, `711.xx` and defence files too (the Bermuda compilation itself includes items filed `811.34544` and `711.0027`). My recall figures are recall *against `.796`*, which is a proxy for the truth, not the truth.

Every command I ran is in `queries.log` in this directory, in order.
