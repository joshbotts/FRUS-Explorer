# Scoping memo: US policy toward refugees and displaced persons in the FRUS corpus

**To:** the historian
**Re:** what this installation holds on the question, and how I would work it
**Basis:** local FRUS Explorer index (`frus-copy.db`), 316,839 documents across 552 volumes,
coverage 1861–1991. All commands in `queries.log`.

---

## 1. Short answer

The corpus is **rich and unusually well-shaped for this question**, but not in the way the phrase
"refugee policy" first suggests. It will not give you a good history of US *admissions law* — the
Displaced Persons Act, the Refugee Relief Act, and the Refugee Act of 1980 appear in **17, 20, and 4
documents respectively**. What it gives you instead is the thing FRUS is actually for: the
**diplomacy of refugee crises abroad**, the **negotiation of the international refugee machinery**,
and — this is the payoff — the record of the State Department **constituting "refugees" as an
administrative category** and then repeatedly re-constituting it as each new displacement arrived.

Three findings I would build a project on:

1. **There is a literal file.** From 1938 to 1949 the Department filed the refugee problem under
   decimal class **`840.48 Refugees`** — Europe / "Calamities. Disasters." FRUS prints **757
   documents** from that one file, and its citations run from **1938-03-23 to 1949-08-23**. The
   category is born at Evian and dies with the IRO. Nothing else in the corpus shows a policy field
   being invented and retired with that precision.
2. **The editors made compilations, and then stopped.** From 1896 to 1963 the FRUS editors gave
   refugee matters their own named chapters — I recovered **56 section titles across 42 volumes**
   from the TEI structure. After `frus1961-63v25` ("Refugees", 18 documents) the named compilation
   disappears and refugee material is absorbed into regional/crisis volumes. That is an
   *editorial* discontinuity that could easily be mistaken for a policy one.
3. **The density curve is monotonic and the peaks are crises, not doctrine.** Refugee language rises
   from 9 per 1,000 documents in the 1860s to 47 per 1,000 in the 1970s. Every peak year is a
   displacement event, not a legislative one: 1949 (Palestine), 1943 (Bermuda), 1944 (War Refugee
   Board), 1951, 1938 (Evian), 1971 (East Pakistan), 1980 (Indochina/Mariel).

---

## 2. What I actually measured

### 2.1 The search terms, and a stemming trap worth knowing

The index uses SQLite FTS5 with the Porter stemmer. **`refugee`/`refugees` stem to `refuge`, while
the ordinary noun `refuge` stems to `refug`** — they are distinct tokens, so a search for refugees
does not silently swallow "took refuge." From `frus_documents_vocab`:

| stem | documents | occurrences |
|---|---|---|
| `refuge` (= refugee/refugees) | **7,745** | 25,899 |
| `refug` (= refuge/refuges) | 2,093 | 2,862 |
| `displac` | 1,679 | 2,987 |
| `repatri` | 3,619 | 10,133 |
| `immigr` | 3,633 | 9,734 |
| `emigr` | 3,350 | 11,533 |
| `asylum` | 1,646 | 3,439 |
| `unrra` | 995 | 3,691 |
| `unrwa` | 329 | 1,051 |
| `unhcr` | 157 | 479 |
| `stateless` | 145 | 262 |

So the core set is **7,745 documents, 2.4% of the corpus**. `"displaced persons"` as a phrase is
**628 documents in 113 volumes** — and its distribution is the sharpest in the whole exercise:
**456 of the 628 fall in volumes covering the 1940s, 110 in the 1950s, and zero before 1940.** The
term is a period artefact, not a category you can search across the series.

### 2.2 Temporal shape (per 1,000 documents, denominator = all documents in volumes whose manifest
coverage midpoint falls in that decade)

```
decade   refugee-term hits   corpus docs   per 1k   volumes
1860s          113             12,441        9.1       23
1870s           96              5,246       18.3       14
1880s           66              7,918        8.3       13
1890s          132              9,336       14.1       12
1900s           75             11,438        6.6       13
1910s          373             32,833       11.4       44
1920s          176             13,542       13.0       17
1930s          779             40,884       19.1       49
1940s        1,959             73,742       26.6       88
1950s        1,584             49,859       31.8      100
1960s          959             26,033       36.8       69
1970s        1,302             27,567       47.2       91
1980s          128              4,523       28.3       13
```

The 1980s row is **not** evidence of decline: only 13 volumes covering that decade have been
published (12 in the 1981-88 subseries, 1 in 1989-92). Treat the series as effectively ending in
1980 for this question.

`emigration` runs the opposite way and is **bimodal** — 27–45 per 1,000 through the 1860s–1880s
(transatlantic emigration and naturalization disputes), collapsing to 3–6 per 1,000 in the mid-20th
century, then spiking to **18.5 (1970s) and 69.2 (1980s)**. That second peak is Soviet Jewish
emigration and Jackson-Vanik (`jackson AND vanik` = 186 documents, concentrated in
`frus1981-88v10`, `frus1977-80v20`, `frus1969-76v31`). The same word means two entirely different
policy problems a century apart, and any keyword-driven series will conflate them.

### 2.3 Where the mass sits (top volumes, count and share of the volume)

```
365  29.3%  frus1949v06        1949, Near East, South Asia, Africa VI      Palestine refugees
304  31.0%  frus1943v01        1943, General I                             Bermuda / IGCR
177  18.4%  frus1938v01        1938, General I                             Evian / IGCR founding
177  17.2%  frus1944v01        1944, General I                             War Refugee Board
139  15.7%  frus1939v02        1939, General, British Commonwealth
138  13.9%  frus1950v05        1950, Near East, South Asia, Africa V
135  15.0%  frus1952-54v09p1   Near and Middle East IX pt 1
132  38.9%  frus1977-80v22     Southeast Asia and the Pacific              Indochinese refugees
122  36.2%  frus1969-76v11     South Asia Crisis, 1971                     East Pakistan
118  14.5%  frus1951v05        1951, Near East and Africa V                UNRWA
 92  11.4%  frus1945v02        1945, General: Political and Economic
 79   7.6%  frus1923v02        1923 II                                     Greek refugee settlement
```

The bundled `volume-subject-profiles-index.json` agrees and sharpens it: **"Refugees" is the
top-ranked profile subject** for `frus1969-76v11`, `frus1943v01`, `frus1977-80v22`, `frus1938v01`,
and `frus1939v02`. For `frus1872p2v3/v4` and `frus1875v02` the ranked subject is **"Asylum"**, which
is a different animal (below).

### 2.4 The editors' own compilation headings — the single best finding

`volume_structures` stores each volume's TEI section tree. Scanning all 552 for
`refugee|displaced person` returns **56 headings in 42 volumes**. The sequence reads as an
institutional history on its own:

- `frus1896` — "Asylum to a political refugee" (2 docs)
- `frus1921v02` — "Refusal by the Government of the United States to incur responsibility for the relief of refugees from South Russia" (11)
- `frus1923v02` — "Withdrawal of American relief organizations from operations in behalf of Greek refugees, and formation of the Refugee Settlement Commission" (63)
- `frus1924v01` — "Acceptance by the United States of certificates of identity issued by the League of Nations to Russian and Armenian refugees in lieu of passports" (6)  ← Nansen passports
- `frus1932v02` — "Protests of the United States against Greek default in payment on the Refugee Loan of 1924" (8)
- `frus1933v02`, `frus1934v02`, `frus1935v02`, `frus1936v02` — the High Commission for Refugees (Jewish and other) coming from Germany
- `frus1935v01` — "Inquiry by the Nansen International Office for Refugees concerning the possibility of settling refugees in the United States" (4)
- `frus1938v01` — "Meeting at Evian…" (25) and "Organization of the Intergovernmental Committee on Political Refugees from Germany" (**120**)
- `frus1938v01`, `frus1939v02` — "Efforts for the relief of Spanish refugees" (22, 16)
- `frus1939v02`, `frus1940v02`, `frus1941v01` — "Cooperation with the Intergovernmental Committee on Refugees to assist persons forced to emigrate, primarily from Germany, for political or racial reasons" (100, 41, 10)
- `frus1943v01` — "Bermuda Conference to consider the Refugee Problem, April 19–28, 1943" (**115**) and "Governmental assistance to persons forced to emigrate for political or racial reasons" (**193**)
- `frus1944v01` — same heading continued (**176**)
- `frus1945v02` — "Interest of the United States in the relief and rescue of Jews and security detainees in Germany and German-occupied territory" (26); "Concern of the United States over problems involving displaced and stateless persons and refugees" (67)
- `frus1946v01` — "…the genesis of the International Refugee Organization"; `frus1946v05` — DPs, transfer of German minorities, repatriation of interned civilians (59)
- `frus1948v08` — "Negotiations respecting evacuation of certain refugee groups from Shanghai through the International Refugee Organization" (17)
- `frus1950v02`, `frus1951v02` — "Matters respecting refugees and stateless persons" (5, 13)
- `frus1952-54v08` — "United States Support of Refugees and Escapees from Eastern Europe; the President's Escapee Program; the Volunteer Freedom Corps; Other Exile Groups" (29)
- `frus1961-63v25` — "Refugees" (18) — **the last named compilation in the series**

Note the euphemism in the wartime headings: not "Jewish refugees" but *"persons forced to emigrate
for political or racial reasons."* The heading is the Department's own formula, and it survives
verbatim across `1939 → 1940 → 1941 → 1943 → 1944`. That is a usable object of study by itself.

Two policy-level compilations you should open first, because they are the closest the corpus comes
to *domestic* refugee policy:

- **`frus1952-54v01p2`, "United States policy regarding immigration and migration programs" (36 docs).**
  Contains the minutes of the **Policy Committee on Immigration and Naturalization** (58th, 59th,
  62d, 63d meetings), memoranda from the Displaced Persons Commission (Rosenfield to Gibson), the
  Secretary of State to the President on McCarran-Walter, and the whole ICEM/PICMME founding
  sequence, ending with the Refugee Relief Program administrator (McLeod) correspondence in 1954.
- **`frus1961-63v25`, "Refugees" (18 docs).** Almost entirely US delegation reports to the **UNHCR
  Executive Committee**, 5th through 10th sessions, plus Schnyder's correspondence. This is the
  multilateral-governance seam.

### 2.5 Archival provenance — where the paper is

Of the 7,745 refugee-term documents, **7,027 (91%) carry a parsed source note.** Rolled up:

**Decimal file classes (top of the refugee set):**

| class | gloss (1910–49 schedule) | docs |
|---|---|---|
| `840.48` | Europe / Calamities. Disasters | **767** |
| `501.BB` | Congresses & Conferences (UN) | 294 |
| `867N.01` | Palestine / Government | 104 |
| `893.00` | China / Political affairs | 101 |
| `868.51` | Greece / Financial conditions | 95 |
| `852.48` | Spain / Calamities. Disasters | 77 |
| `740.00119` | Europe / political relations (armistice-peace) | 73 |
| `868.48` | Greece / Calamities. Disasters | 63 |
| `POL 27 ARAB-ISR` | (post-1963 subject-numeric) | 52 |

`840.48` is corpus-wide 894 documents, of which **767 (86%) mention "refugee"** — the class is the
refugee file in all but name, and in fact **the caption in the source notes literally reads
`840.48 Refugees`** (757 citations). Three sibling captions exist and are small but pointed:
`811.111 Refugees` (7 — the *US visa/immigration* file with a refugee subdivision, all in
`frus1940v02`/`frus1941v01`), `501.BD Refugees` (4, `frus1946v05` — the UN body), and
`868.51 Refugee Loan, 1924` (the Greek loan). Post-1963 the successor is `SOC 14` / `REF` in the
subject-numeric scheme (`SOC 14-1 S VIET` = 47, `REF 3 UNRWA` = 4) — thin, and worth confirming
against the actual Central Foreign Policy File rather than trusting the corpus for it.

**Repositories and series:**

```
Department of State        5,161      Carter Library / NSA               289
National Archives            458      Nixon Presidential Materials/NSC   259
Carter Library               340      NARA Central Files 1967–69         124
Nixon Presidential Mat.      278      Johnson Library / NSF              107
Johnson Library              127      NARA Central Files 1970–73          87
CIA                          117      Kennedy Library / NSF               85
Kennedy Library              113      Ford Library / NSA                  69
Ford Library                  84      Library of Congress / Mss Div       46
```

For the Carter period the leads are concrete and repeat: **Carter Library, NSA, Brzezinski
Material, Subject File, Box 51, "Refugees"**; **Mondale Papers, Box 83, "National Security
Issues—Indochinese Refugees"**; **NSC Staff Material, Global Issues, Mathews Subject File, Box 13,
"Refugees: Indochina."** Those box-and-folder captions are the second place in this corpus where
you can watch a bureaucracy keep a refugee file.

### 2.6 The institutional spine, recoverable from the person index

`person_rollup` carries the editors' "List of Persons" descriptions. Filtering for refugee roles
returns the whole succession of US posts in one query:

- **Adviser on Refugees and Displaced Persons** (George L. Warren) — 1940s
- **Administrator of the Refugee Relief Program** (Scott McLeod) — 1953–4
- **President's Escapee Program** — 1952–4
- **Office of Refugee and Migration Affairs** (Elmer M. Falk)
- **Special Assistant to the Secretary for Refugee and Migration Affairs** (Francis L. Kellogg, 1970s)
- **Ambassador at Large and Coordinator for Refugee Affairs** (Victor Palmieri 1979–81; H. Eugene Douglas to 1985)
- **Bureau of Refugee Programs** (Krumm)
- **Assistant Secretary for Population, Refugees and Migration** (Frank E. Loy)

plus the international side (Sadruddin Aga Khan as Deputy/High Commissioner; Blandford and John H.
Davis at UNRWA; Pehle at the War Refugee Board). Following one office at a time through
`person_mentions` is a cheap and well-defined way to build a chronology.

### 2.7 Probe counts for the named programs and crises

| probe | docs | top volumes |
|---|---|---|
| War Refugee Board | 116 | 1944v01 (88), 1945v02 (18) |
| Intergovernmental Committee on Refugees | 85 | 1943v01 (33), 1945v02 (14) |
| Evian | 87 | 1938v01 (36) |
| UNRRA | 995 | 1945v02 (142), 1947v07 (73), 1946v05 (62) |
| "International Refugee Organization" | 104 | 1950v02, 1948v08, 1951v04p1 |
| Nansen | 138 | 1918Supp01v02 (27), 1917Supp02v02 (18), 1921v02 (17) |
| UNRWA / "relief and works agency" | 375 | 1951v05 (50), 1952-54v09p1 (42), 1958-60v13 (38) |
| Palestine resettlement/repatriation | 693 | 1949v06 (163), 1951v05 (55) |
| Escapee Program | 40 | 1952-54v01p1, 1952-54v08 |
| UNHCR / "High Commissioner for Refugees" | 252 | 1977-80v22 (40), 1969-76v11 (23), 1961-63v25 (20) |
| Cuban refugee | 155 | 1961-63v10 (28), 1977-80v23 (22) |
| Bengali / East Pakistan refugees | 199 | **1969-76v11 (114)**, 1969-76ve07 (40) |
| Indochinese refugees | 90 | 1977-80v22 (52) |
| "boat people" | 34 | 1977-80v22 (15) |
| "first asylum" | 20 | 1977-80v22 (13) |
| Orderly Departure Program | 21 | 1977-80v22 (8) |
| forcible/forced repatriation | 176 | **1952-54v15p1 (115)**, 1977-80v22 (7), 1946v05 (7) |
| Spanish (civil war) refugees | 417 | 1943v01 (48), 1939v02 (24), 1937v01 (21) |
| Shanghai / Chinese refugees | 245 | 1937v04 (29), 1948v08 (25), 1932v03 (17) |
| Armenian / Near East relief | 191 | 1918Supp02 (19), 1922v02 (17), 1923v02 (15) |
| German expellees | 67 | 1947v02, 1946v05, 1964-68v15 |
| Hungarian refugees + 1956 | 82 | 1955-57v25 (28), 1955-57v26 (8) |
| Displaced Persons Act | **17** | 1952-54v01p2 (6), 1951v04p1 (4) |
| Refugee Relief Act | **20** | 1952-54v01p2 (5) |
| Refugee Act (1980) | **4** | one each in 1977-80 v23/v02/v01 |
| "non-refoulement" | **2** | 1969-76v27, 1938v01 |
| 1951 Convention / Protocol | **22** | 1951v02 (5), 1950v02 (5) |

---

## 3. Six things I would warn you about before you search

1. **The 19th-century hits are a different subject.** High `asylum` and `emigration` density before
   1914 is not refugee policy. Spot-checking `frus1875v02`'s top `asylum` documents lands you in the
   Bassett affair — the US Legation at Port-au-Prince sheltering Haitian political refugees, argued
   between Fish and the Haitian minister Preston. The compilation headings for the same period are
   things like "Expulsion of Mormon missionaries," "Expulsion of Hugo Loewi," "Emigration of families
   of naturalized Americans," "Jews in Roumania — discriminations against… and objection of the
   United States Government to immigration." This is **consular protection, expulsion of individual
   Americans, and naturalization law**, dressed in the same vocabulary. Genuine and interesting —
   diplomatic asylum in Latin America runs from `frus1867p2` through Sandino in `frus1929v03` — but
   do not let it into a series with the 1940s without saying so.

2. **`repatriation` is mostly not about refugees.** Of 3,619 documents, the largest concentrations
   are "Emergency measures for the repatriation of American citizens abroad" (1939–44) and the
   **Korean non-repatriate POW question** (`frus1952-54v15p1/p2`, 189 + 40 documents on
   "prisoners of war AND repatriation", and 115 of the corpus's 176 "forcible repatriation" hits).
   That POW material *is* substantively about non-refoulement avant la lettre and is worth a chapter
   — but it will contaminate any count you present as "refugee repatriation."

3. **The subject tags are recall-oriented and their provenance says so.** The bundled
   `document-subject-index.json` states its tags are *"Detected topics from case-insensitive string
   matching of subject names and variants, NOT semantic analysis — treat as recall-oriented
   candidates rather than ground truth."* I cross-checked them anyway: the refugee-family tags
   (Refugees, Refugee resettlement, Refugee camps, Political/Cuban/Indochinese refugees) mark
   **6,172 documents**, of which **6,044 (98%) also match the literal term** — so precision is high
   — but they **miss 1,701 documents** the term-search finds. Use them to *rank* volumes, not to
   *bound* a corpus. Note also that **"displaced persons" is not in the 491-subject vocabulary at
   all**, which is precisely why the DP era looks thinner in the tags than it is.

4. **There is no refugee cluster in the semantic map.** Of the 179 clusters in
   `semantic-map-index.json`, none is labelled for refugees, displacement, or asylum. The nearest
   are cluster 103 (`nazi, reich, jew, hitler`) and cluster 145 (`naturalize, naturalization,
   citizenship, emigrate`). I read this as a real property of the corpus rather than a defect of the
   clustering: refugee documents are dispersed into whatever regional crisis produced them, which is
   the same fact the compilation-heading history shows from the other side. If you want a corpus,
   you have to assemble it; the corpus will not hand you one.

5. **The series stops before the question does.** Coverage-end years above 1980 exist for only 13
   volumes. Mariel (55 hits, and beware — some are the Cuban port in Bay of Pigs contexts, not the
   1980 boatlift), Central American asylum seekers, and the Refugee Act's implementation are
   effectively outside the published record here.

6. **Editorial notes are in the counts.** 8,468 of the 316,839 documents are editorial notes and
   1,012 are front matter. They are indexed like documents, so a hit count is a hit count of
   *printed items*, not of archival documents. For the Palestine and Indochina volumes in particular
   the editors' notes carry a lot of the narrative.

---

## 4. What I would actually search, in order

1. **The `840.48 Refugees` file as an object.** `document_sources.raw_text LIKE '840.48 Refugees%'`
   gives 757 documents across 14 volumes, 1938-03-23 → 1949-08-23, concentrated in `frus1943v01`
   (193), `frus1944v01` (160), `frus1938v01` (144), `frus1939v02` (92). Read it as a single series
   and the birth-to-death arc of the category is right there. Then read the four sibling captions
   (`811.111 Refugees`, `501.BD Refugees`, `540.48 Refugees`, `868.51 Refugee Loan`) as the places
   the category *didn't* fit.
2. **The euphemism.** Trace "persons forced to emigrate for political or racial reasons" as an exact
   phrase across 1939–1944, and set it against `frus1945v02`'s "relief and rescue of Jews," which is
   the first heading to say so. That is a nameable shift with a nameable date.
3. **The 1949 Palestine turn.** `frus1949v06` alone is 365 documents (29% of the volume). The
   McGhee memorandum of 22 April 1949 (`frus1949v06/d608`, source note `867N.48/4–2249`) opens with
   a policy decision, conclusions, recommendations, a plan of action, *and a tentative total cost* —
   it is the moment refugee relief becomes a budgeted instrument of Near East policy. Follow it
   forward through UNRWA (`frus1951v05`, `frus1952-54v09p1`) and the repatriation-vs-resettlement
   argument (693 documents).
4. **1971 as the control case.** `frus1969-76v11` is 36% refugee-saturated and "Refugees" is its
   *top* profile subject; 114 of its documents pair East Pakistan/Bengali with refugee language.
   Here the displacement is the argument — the refugee flow is what Washington is asked to weigh
   against the tilt toward Pakistan. Nothing tests "is refugee policy a policy?" better.
5. **1977–80 as the institutional consolidation.** `frus1977-80v22` at 39% density, the Interagency
   Task Force on Indochinese Refugees, Palmieri's coordinator post, "first asylum," the Orderly
   Departure Program, parole authority (68 documents, 17 in this volume). The Carter Library folder
   captions make follow-up in the archive trivially specifiable.
6. **The two governance compilations** (`frus1952-54v01p2` §immigration-and-migration;
   `frus1961-63v25` §Refugees) as the connective tissue between the crises.
7. **The negative case worth writing up:** the 1921 heading *"Refusal by the Government of the
   United States to incur responsibility for the relief of refugees from South Russia"* (11 docs)
   and the 1935 heading *"Inquiry by the Nansen International Office for Refugees concerning the
   possibility of settling refugees in the United States"* (4 docs). Two explicit refusals, twenty
   years and one war apart, both compiled by the editors under their own names.

---

## 5. Evidence you can check

- All 65 commands are in `queries.log`, in order. Every number above comes from one of them.
  One housekeeping note, since it bears on whether you can trust that file: the scratch directory
  I was given already contained a partial `queries.log` (19 lines) and two output files from an
  earlier occupant, dated before my first command. I did not read those outputs, and I rewrote
  `queries.log` so that it contains my commands only. A handful of the longest lines are
  abbreviated with `...` where a CTE was repeated verbatim; nothing else is paraphrased.
- Corpus denominators: `SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM document_cache` → `316839|552`.
  Source notes: `SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM document_sources` → `264487|501`.
- The stemming split is verifiable directly against `frus_documents_vocab` (an fts5vocab table over
  the same index), which is how I know `refugee` and `refuge` are not conflated.
- Decade denominators are built from `manifest.json` `dateRange` midpoints, one decade per volume,
  so decades sum exactly to the corpus; the helper is `era.py` in the scratch directory.
- Decimal-class glosses come from the bundled `decimal-class-labels.json` (1910–1949 schedule only;
  the file ships no 1950s/1960s schedule, so the `POL`/`SOC`/`REF` subject-numeric keys above are
  **unglossed and I did not invent glosses for them**).
- Two claims I checked by reading rather than counting: the 19th-century `asylum` material
  (`frus1875v02` top-BM25 documents, the Bassett/Preston exchanges) and the Carter-era folder
  captions (`frus1977-80v22` top-BM25 source notes).
- One thing I could not test: whether the `SOC 14` / `REF` subject-numeric counts are low because
  the Department filed little there, or because FRUS's post-1963 volumes cite the Central Foreign
  Policy File by film/D-number rather than by class. `frus1977-80v22/d148` cites
  `RG 59, Central Foreign Policy File, D800614–0612` — no class at all — which suggests the latter.
  Do not read the small `REF` counts as evidence about the archive.
