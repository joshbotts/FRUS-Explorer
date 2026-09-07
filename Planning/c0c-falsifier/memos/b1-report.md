# Scoping memo: the isthmian canal in FRUS

**Question.** How did the United States pursue and negotiate rights to build and control an
isthmian canal?

**Corpus.** The local FRUS Explorer index: 552 volumes, 316,839 documents (`document_cache`),
with an FTS5 mirror (`frus_documents`, porter stemming) plus per-document date, source-note,
person, cross-reference and subject tables, and the app's bundled JSON reference files.

**Bottom line.** The corpus is strong on this question but is not organised for it, and the two
retrieval axes you would reach for first — full-text search on *canal*, and the bundled subject
taxonomy — both fail in specific, measurable ways. The reliable axis is the **printed compilation
heading**, which FRUS's own editors wrote and which the index preserves in `volume_structures`.

---

## 1. What the corpus actually holds

### 1.1 The record is continuous from 1861 to 1980, but it begins in the middle

FRUS starts with 1861. The two founding instruments of American isthmian rights — the
Bidlack–Mallarino treaty with New Granada (1846) and the Clayton–Bulwer treaty with Britain
(1850) — predate the series. They are present only as **argument about prior instruments**, not
as negotiating records:

| probe | documents |
|---|---|
| `"Clayton-Bulwer"` | 57 (top volume: `frus1883`, 8) |
| `(“treaty of 1846” OR “convention of 1846” OR Bidlack OR Mallarino) AND (canal OR isthmus OR transit)` | 98 |

So the corpus opens on the **abrogation/modification** phase rather than the acquisition phase.
The richest early exchange is Blaine's and Frelinghuysen's 1881–83 campaign to get Britain out of
Clayton–Bulwer. Verified by reading, not inferred:

- `frus1881/d342` — Blaine to Lowell, 19 Nov 1881: "…in pursuance of the premises laid down in my
  circular note of June 24 … touching the guarantee of neutrality for the Interoceanic canal at
  Panama, it becomes my duty to call your attention to the convention of April 19, 1850…"
- `frus1881/d345` — Blaine to Lowell, 29 Nov 1881, the second note.
- `frus1882/d181` — Frelinghuysen to Lowell, 8 May 1882, answering Granville's two replies.
- `frus1883/d277`, `frus1883/d310` — Granville to West, the British side of the same argument.

### 1.2 The treaty texts themselves are in the corpus

Not merely cited — printed in full:

- **Hay–Pauncefote II (18 Nov 1901).** `frus1901/d233`: "message from the president of the united
  states, transmitting a convention between the united states and great britain, to facilitae
  [sic] the construction of a ship canal to connect the atlantic and pacific oceans, signed at
  washington, november 18, 1901," with the Senate's calendar of readings. `frus1901/d232a` is the
  companion Senate document. Note the OCR-level typo in the printed heading — it is in the source.
- **Hay–Bunau-Varilla (18 Nov 1903).** `frus1904/d542`, a presidential proclamation whose body
  runs 25,446 characters and contains the treaty verbatim under its own title, "isthmian canal
  convention."
- The 1901 "Interoceanic canal" section of `frus1901` is a reprint of Senate Doc. No. 85, 57th
  Cong., 1st sess. — i.e. the Walker Commission material reaches you through a congressional
  reprint, not through the Department's files.

### 1.3 The 1903 crisis is the densest single compilation in the corpus

`frus1903` carries 206 documents under canal/isthmus headings, in six named compilations,
including "Correspondence concerning the convention between the United States and Colombia for
the construction of an interoceanic canal across the Isthmus of Panama" (121 documents on its own
heading). Structurally this is: Hay → Beaupré instructions, Beaupré → Hay despatches from Bogotá
across March–October 1903 (the Hay–Herrán ratification fight), then the November telegram traffic
from Panama and Colón, then Buchanan's special mission and Bunau-Varilla's own notes to Hay
(`frus1903/d329`, `d330`). `frus1904` adds 51 more under headings for the transfer of the New
Panama Canal Company's property, the transfer of the Zone, the canal indemnity, and the
establishment of US ports and post offices in the Zone.

### 1.4 The question does not end in 1904 — the corpus tracks the *control* half for 75 more years

Reading the compilation headings in date order gives a clean spine (document counts are the
documents the editors filed under a canal- or isthmus-titled heading):

| period | volumes | what the headings say |
|---|---|---|
| 1894–1902 | `frus1894`, `frus1896`, `frus1897`, `frus1901`, `frus1902` | "Nicaraguan canal"; "Nicaragua Canal"; "Interoceanic canal"; the Hay–Pauncefote convention; the 1846 transit guarantee |
| 1903–05 | `frus1903` (206), `frus1904` (51), `frus1905` | acquisition, revolution, transfer, indemnity |
| 1908–11 | `frus1908`, `frus1909`, `frus1910` (49), `frus1911` | the tripartite Panama/Colombia/US treaties of 1909; Zone damage claims |
| 1912–17 | `frus1912` (39), `frus1913` (16), `frus1914` (53), `frus1915` (48), `frus1916` (44), `frus1917` | canal tolls exemption and its repeal; the Colombia settlement treaty; the Nicaragua canal treaty with Costa Rican and Salvadoran protests; the Central American Court cases |
| 1920–29 | `frus1920v03`, `frus1921v02`, `frus1923v01`, `frus1923v02`, `frus1925v02`, `frus1927v03`, `frus1928v03`, `frus1929v03` | land acquisitions for canal defence; British objection to the tolls exemption; a Costa Rica canal protocol; recurring Panamanian objections to Zone jurisdiction |
| 1933–41 | `frus1933v05`, `frus1934v05` (27), `frus1935v04` (17), `frus1938v05` (12), `frus1939v05` (31), `frus1940v05` (25), `frus1941v07` | the 1936 Hull–Alfaro revision; the devalued-dollar annuity dispute; a Nicaraguan canal amendment; defence-site leases |
| 1942–48 | `frus1942v06`, `frus1944v07`, `frus1945v09`, `frus1947v08`, `frus1948v09` (22) | Zone labour discrimination; defence-site withdrawal; the Atrato–Truando route reconnaissance with Colombia |
| 1952–63 | `frus1952-54v04`, `frus1955-57v07`, `frus1958-60v05mSupp`, `frus1961-63v12` | filed as "Panama" rather than as "canal"; the 1955 Remón treaty and its aftermath |
| 1964–76 | `frus1964-68v31` (92), `frus1969-76ve10` (46), `frus1969-76v22` (146) | the 1964 flag riots and rupture; the Robles drafts; NSSM 86; the Kissinger–Tack principles; the 1973–76 rounds |
| 1977–80 | `frus1977-80v29` (277) | "Negotiation and Signing of the Panama Canal Treaties" (95) and "Ratification of the Panama Canal Treaties" (73) |

The 1977–80 volume is a full negotiating record, not a selection of highlights: PRM tasking
(`d2`), a Policy Review Committee meeting (`d6`), Vance to Carter (`d7`), Carter's letter to
co-negotiator Linowitz (`d12`), Linowitz's own memorandum for the files (`d14`).

### 1.5 The State Department filed "Canals" as its own subject

For the 1910–1963 central-files era the corpus preserves the decimal file number in
`document_sources.decimal_class`. The 1910–49 schedule (bundled at
`decimal-class-labels.json`) glosses subject suffix **`.812` as "Canals"** and `.8123` as
"Tolls" under class 8, Internal Affairs of States. Corpus-wide there are 161 such rows:

```
817.812  Nicaragua — Canals    124
811f.812 Canal Zone — Canals     25   (811f.812 + 811F.812 + 811f.8123)
883.812  Egypt — Canals           3   (Suez)
821.812  Colombia — Canals        1
```

concentrated in `frus1916` (43), `frus1915` (28), `frus1914` (21), `frus1939v05` (16),
`frus1938v05` (12). This is a genuinely independent axis: it is the Department's own contemporary
classification, and it is what makes the Salvadoran and Costa Rican protests against the
Bryan–Chamorro treaty findable (see §2.2). It is also a narrow one — the great mass of canal
business was filed under `711.19*` (US–Panama political relations and treaties), `811F.*` (the
Zone as US territory) and `819.*` (Panama's internal affairs), which is where the top of the
class distribution actually sits: `711F.1914` (107), `817.812` (74 within my candidate set),
`811F.504` (53, Zone labour), `711.1928` (51), `819.00` (47).

### 1.6 Provenance

Of 3,101 topically-matching documents, 2,631 carry a parsed source note. Repositories:

```
Department of State           1763
Carter Library                 272
National Archives              225
Nixon Presidential Materials    69
Johnson Library                 50
Eisenhower Library              40
Central Intelligence Agency     38
Ford Library                    27
Kennedy Library                 16
```

Footnote citations to material *outside* the printed record (`external_citations`): 686 on those
documents, led by Carter Library / National Security Affairs (106), Carter Library /
Presidential Materials (29), Johnson Library / National Security File (20). Lot files worth
requesting: `78D300` (39 documents), `81F1` (27), `63D351` (11), `81D113` (11), `84D241` (10).

---

## 2. What I would search for, and the two traps

### 2.1 Trap one: *canal* is the wrong word, because of Suez

`canal` alone matches 6,957 documents. The largest volumes by that count are **not** about the
isthmus:

```
frus1955-57v16   445   (Suez crisis)
frus1977-80v29   227   (Panama Canal treaties)
frus1955-57v17   178   (Suez aftermath)
frus1969-76v22   138   (Panama 1973-76)
frus1969-76v23   128   (Arab-Israeli dispute)
frus1969-76v25   122   (Arab-Israeli crisis 1973)
```

`canal AND Suez` matches 2,070 — 30% of all *canal* documents. A further 1,939 match `canal` and
none of Suez/Panama/Nicaragua/isthmus/interoceanic: the Kiel canal, the Kaiser Wilhelm canal, the
Grand Canal in Kiangsu, the Lynn Canal in Alaska, the Canal de Haro boundary, the Baltic canal,
the Massena canal, and Great Lakes navigation. Several of these have their own titled
compilations, which I list in §3 so you can exclude them by name.

The workable topical query is:

```
canal AND (isthmus OR isthmian OR Panama OR Nicaragua OR interoceanic OR "inter-oceanic")
```

→ **3,101 documents in 310 volumes.** I drew a seeded random sample of 30 (`random.seed(7)`) and
read the snippets: 28 are genuinely about the isthmus; 2 are lists of states that happen to name
Panama and Nicaragua (`frus1919Parisv01/d337`, `frus1969-76v05/d447`). Call it ~93% precision for
*topic*. Precision for *your* question is lower, because much of the set is Zone administration
— quarantine rules, liquor transit, labour discrimination, extradition — which bears on control
but not on the negotiation of rights.

Tightened to the negotiation itself:

```
canal AND (isthmus OR isthmian OR Panama OR Nicaragua OR interoceanic)
      AND (treaty OR convention OR negotiation OR negotiate OR ratification OR protocol OR concession)
NOT Suez
```

→ **2,168 documents**, top volumes `frus1977-80v29` (221), `frus1969-76v22` (136), `frus1903`
(59), `frus1964-68v31` (54), `frus1969-76ve10` (53), `frus1952-54v04` (48). Adding `NOT Suez`
removes 122 documents, so the Suez bleed survives even a treaty-word filter.

### 2.2 Trap two: keyword search silently loses ~43% of a compilation

This is the finding I would most want you to check. I built a second set structurally: every
document the editors filed under a section heading containing *canal* or *isthm*, excluding the
Suez/Kiel/Grand-Canal/Lynn/Haro/Baltic/Massena/Great-Lakes families by name.

```
STRUCTURAL CORE      1,024 documents in 47 volumes
   of which a residual Suez leak: 35 (frus1955-57v16, "Anglo-French Assault On the Canal Zone")
   clean:            ~989

intersection with the topical FTS query   584
in the core but NOT found by FTS          440   (43% of the core)
found by FTS but outside any core heading 2,517
```

The 440 are not noise. A seeded sample (`random.seed(3)`) of 14:

- `frus1903/d270` — Beaupré to Hay, telegram, Bogotá, 9 Nov 1903 (the collapse of ratification
  and the revolution, filed under the canal heading, never using the word).
- `frus1903/d205`, `frus1903/d155` — more Beaupré despatches from the same compilation.
- `frus1914/d1693`, `frus1915/d1723`, `frus1916/d1222`, `frus1916/d1230`, `frus1916/d1246` —
  Salvadoran and British protests over the Nicaragua canal treaty, each stamped **File No.
  817.812/…**, i.e. filed by the Department under *Nicaragua — Canals*, and each invisible to a
  text search for *canal*.
- `frus1910/d361` — Minister Dawson from Bogotá, under the 1909 treaties heading.
- `frus1912/d1613`, `frus1912/d1617` — 819.77 railway-concession telegrams under the heading
  "Railway concessions to foreigners and their relation to the Canal."
- `frus1977-80v29/d162` — a Carter note under the ratification heading.

The lesson: a diplomatic exchange about the canal is often *about* a protest, a concession, a
ratification vote, and the editors supplied the canal context in the heading rather than the
document. **Retrieve by compilation, then read; do not retrieve by keyword and expect the
compilation.** The `volume_structures` table is where the headings live.

If you widen the structural axis to include the postwar "Panama" country chapters (which is how
1952–76 canal business is filed), you get 3,272 documents in 80 volumes — but this over-reaches:
it sweeps in `frus1940v01`'s 56 documents on belligerent violations of the **Declaration of
Panama** security zone, and `frus1917Supp01v01`'s 69 documents on Panama's declaration of war on
Austria-Hungary. Neither has anything to do with canal rights. I would take the 1952–76 Panama
chapters individually rather than by pattern.

### 2.3 Trap three: the bundled subject taxonomy does not have this topic

`document-subject-index.json` carries 491 subjects over 877,817 document–subject pairs. Searching
its vocabulary for *canal | panama | isthm | waterway | transit | nicaragua | colombia* returns
**exactly one entry**: `Suez Canal`, document-frequency 2,178, filed under the category
*Warfare*. There is no Panama Canal subject, no isthmian subject, no Panama country subject. So
the subject-tag browse axis is not merely thin here — used naively it will hand you the wrong
canal. (The bundled provenance for that file also describes the tags as case-insensitive string
matching, "recall-oriented candidates rather than ground truth," which is worth carrying into any
count you take from it.)

### 2.4 A fourth, milder trap: the person axis is half-covered and name-collides

`persons` is populated for 285 of 552 volumes, and only 3,293 rows fall before `frus1930`. The
canal's founding cast has **no** person records: Bunau-Varilla, Pauncefote, Herrán and Beaupré
all return zero rows. The modern cast does: Torrijos Herrera, Omar (7 volumes), Linowitz, Sol M.
(11), Tack, Juan Antonio (5). Two cautions:

- **Ellsworth Bunker** appears in 47 volumes, described as "U.S. Ambassador to the Republic of
  Vietnam." He is the right man — he was co-negotiator with Linowitz — but his name is a poor
  filter.
- **Linowitz** shows 79 document-mentions in `frus1977-80v15` (Central America) and 50 in
  `frus1977-80v09Ed2` (Arab-Israeli Dispute), because he also served as Carter's Middle East
  negotiator. Person-name retrieval bleeds across his two careers exactly as *canal* bleeds
  across two isthmuses.

---

## 3. Named compilations to exclude by name

These carry canal-matching headings and are irrelevant to the question: Canal de Haro boundary
(`frus1872p2v5`), Northern Baltic / Kaiser Wilhelm canal (`frus1895p1`, `frus1901`), Great
Lakes–Atlantic deep-water canals (`frus1895p1`), Lynn Canal / Alaska boundary (`frus1899`),
Suez warship passage (`frus1898`), Interoceanic Railway of Guatemala (`frus1908`), Huai River and
Grand Canal conservancy (`frus1916`, `frus1917`, `frus1919v01`), Kiel canal clauses of Versailles
(`frus1919Parisv13`), Massena canal / St Lawrence (`frus1933v02`), and the whole Anglo-Egyptian /
Suez family (`frus1947v05`, `frus1950v05`, `frus1951v05`, `frus1952-54v09p2`, `frus1955-57v15`,
`frus1955-57v16`, `frus1955-57v17`).

Ambiguous and worth a decision from you: `frus1955-57v07`'s heading is "Political and military
relations of the United States and Panama; **impact of the Suez Canal crisis**" — a single
compilation that is genuinely about both canals, and the reason Nasser's nationalisation belongs
in an isthmian bibliography at all.

---

## 4. Episode probes (a starting bibliography by count)

Each figure is a document count from the FTS index; the top volumes tell you where to start.

| episode | probe | docs | top volumes |
|---|---|---|---|
| Clayton–Bulwer revision | `"Clayton-Bulwer"` | 57 | `frus1883` 8, `frus1903` 6, `frus1893` 5, `frus1912` 5 |
| Named canal treaties (all) | Clayton-Bulwer / Hay-Pauncefote / Hay-Herran / Bunau-Varilla / Bryan-Chamorro / Thomson-Urrutia / Frelinghuysen-Zavala | 222 | — |
| Walker Commission | `"Isthmian Canal Commission"` | 57 | — |
| Route competition | `"Nicaragua route" OR "Nicaraguan route"` | 34 | — |
| Colombian alternative | `Atrato` | 28 | incl. `frus1948v09` reconnaissance |
| Hay–Herrán | `Herran OR "Hay-Herran"` | 47 | `frus1903` |
| The grant language | `"use, occupation and control"` (+ comma variant) | 28 | `frus1904` → `frus1961-63v10`; the phrase is re-litigated for 60 years |
| Tolls | `tolls AND canal` | 425 | `frus1912`–`frus1921v02` |
| Bryan–Chamorro | `"Bryan-Chamorro"` | 54 | `frus1917` 10, `frus1916` 10, `frus1938v05` 7 |
| 1936 revision | `"Hull-Alfaro" OR ("treaty of 1936" AND Panama)` | 52 | `frus1941v07` 12, `frus1946v11` 10 |
| Remón / 1955 | `"Remon" OR "Remón"` | 71 | `frus1952-54v04` 40 |
| 1955 Treaty of Mutual Understanding | exact phrase | 13 | `frus1958-60v05mSupp` 6 |
| 1964 riots | `"Canal Zone" AND riot*` | 105 | `frus1964-68v31` |
| Robles drafts | `Robles AND canal` | 32 | `frus1964-68v31` 20 |
| Sea-level study | `"sea-level canal" OR "Sea Level Canal Study"` | 120 | `frus1977-80v29` 22, `frus1969-76ve10` 20, `frus1964-68v31` 19 |
| Kissinger–Tack | `"Tack" AND canal` | 98 | — |
| 1977 treaties | `"Torrijos" AND (treaty OR treaties)` | 269 | `frus1977-80v29` 113, `frus1969-76v22` 82 |
| Neutrality Treaty | `"Neutrality Treaty" AND canal` | 41 | `frus1977-80v29` 38 |
| Senate ratification | `DeConcini` | 25 | `frus1977-80v29` 14 |

---

## 5. Shape of the evidence over time

Decade distribution of the 3,101 topical matches, by the index's parsed document date:

```
1860s   27
1870s   55
1880s   94
1890s   47
1900s  174
1910s  502
1920s  267
1930s  282
1940s  422
1950s  276
1960s  206
1970s  684
1980s   41
(22 documents have no parsed date; one stray each in the 1850s and 2010s bucket)
```

Two peaks, not one. The 1910s peak is tolls, the Colombian settlement, and the Nicaragua treaty
— i.e. the consolidation of rights already taken. The 1970s peak is their surrender. **The
1900s decade, the acquisition itself, is the third-smallest of the twentieth-century buckets
(174).** That is a real property of FRUS, not of my query: the annual volumes of 1903–05 print a
concentrated, self-contained dossier, while the 1970s volumes print the internal deliberative
record of a modern policy process. If your argument turns on comparing the two moments, you are
comparing two different genres of publication, and the memo you write should say so.

Connectivity: the 3,101 documents carry 3,477 outbound cross-references and receive only 157
inbound. The canal literature in FRUS cites outward far more than it is cited — consistent with
compilations that constantly refer the reader back to prior annual volumes ("Continued from For.
Rel. 1914, pp. …"), which is itself how the editors chained the tolls and Nicaragua-treaty
stories across years.

---

## 6. What I did not do

- I did not read the TEI XML at `/Users/jbotts/Development/frus/volumes/`. Everything above comes
  from the SQLite index and the bundled JSON. If a heading or a document body looks wrong, the XML
  is the authority.
- I did not use the semantic-vector or map artifacts (`semantic-map-index.json`,
  `semantic-vectors-*`). Given how badly the lexical axis behaves here, a nearest-neighbour pass
  seeded on `frus1903/d105` or `frus1977-80v29/d14` is the obvious next experiment, and would test
  the §2.2 claim from a different direction.
- I did not verify the completeness of `volume_structures` against the printed tables of contents;
  all 552 volumes have a structure row, but I did not check that every printed heading survives.
- Counts here are FTS5 document counts with porter stemming, so `canal`/`canals` and
  `negotiate`/`negotiation` conflate. Phrase probes in quotation marks are exact.
- The `-readonly` flag was used on every `sqlite3` invocation and `mode=ro` on every Python
  connection; nothing was written to the index. Every command is in `queries.log` beside this
  file, in order.
