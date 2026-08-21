# Research Trip Packet — T-0 prereqs and decisions (#830)

**Date:** 2026-08-21 · **Version:** 1.1 · **Status:** owner gate — **decisions settled
2026-08-21; the fact confirmation (§3.2) remains owner-only and is now incremental by D7**. No
code rides this document. Companion to `Planning/Research-Trip-Packet-Scope.md` (v1.3) and the owner gate
recorded at [#830 comment 5248318037](https://github.com/joshbotts/FRUS-Explorer/issues/830#issuecomment-5248318037).

The gate's instruction is explicit: *"the first act of the T-0 session is to bring the
repository-fact table to the owner for confirmation, item by item — not to draft it and
proceed."* This document is that first act. It contains (§1) the T-0 data audit, run offline
against the shipped artifacts; (§2) what the audit changes about the plan; (§3) the fact
inventory split by whether it can be verified inside this repository; (§4) the decisions put
to the owner, with a recommendation for each — **all ten now settled**; (§5) what T-1 may start
on.

**Nothing here confirms a fact about a real institution.** archives.gov is unreachable from the
development container, which is why the FAQ was deposited verbatim in the first place. §3 sorts
the claims; it does not settle any of them.

---

## 1. The T-0 data audit

The plan asks for a measurement "on a real project." A container holds no user library, so the
audit was run corpus-wide against the shipped artifacts — the ceiling any real project's numbers
sit under, and the same denominators the packet's own resolution path uses. Sources: the
committed `Planning/source-explorer-export/source-explorer-export-summary.json` (2026-07-29,
264,464 source notes over 552 volumes), `FRUSExplorer/Resources/central-files-index.json`,
`collection-authority.json`, `collection-usage-index.json`, `series-facts-index.json`,
`volume-sources-index.json`.

### 1.1 How far a source note gets toward NARA's four-field inquiry line

NARA's effective-inquiry spec asks records be identified by **record group, entry number, and
series title**, plus a **NAID** link. Measured, by resolution route:

| Route | Notes | Share | Reaches RG | Entry no. | Series title | NAID |
|---|---:|---:|---|---|---|---|
| Lot file, resolved by the bundled index | 8,256 | 3.1% | yes | **yes** (1,057 of 1,065 lots carry HMS/MLR, 99.2%) | yes | yes |
| Decimal file, resolved via volume-sources | 189,345 | 71.6% | yes | no | **no — record group only** | yes (of the RG) |
| `naraCollection`, resolved via volume-sources | 9,540 | 3.6% | yes | no | partial | yes (of the RG) |
| 1906–10 Numerical File rolls | 2,783 | 1.1% | yes | no (microfilm M862) | yes (roll file unit) | yes |
| Lot file, unresolved (live route only) | 6,230 | 2.4% | yes | no | no | no |
| Presidential library | 29,093 | 11.0% | n/a | n/a | collection name | **no — 0 resolve offline** |
| CFPF (1963–73) | 4,030 | 1.5% | yes (59) | no | no | no |
| No resolution (intelligence, named series, foreign, published, unrecognized) | 12,750 | 4.8% | no | no | no | no |

**The headline: 3.1% of source notes reach NARA's full four-field form.** Another 75.2% reach a
*record group and its NAID* — which is honest, but a record group is not a series, and an
inquiry naming only "RG 59" is the shape the FAQ names as useless ("everything you have").

The cause is specific and fixable in curation, not code: the app has a series identity for the
1906–10 Numerical File and for the pre-1906 country series (5 categories), but **none for the
1910–1963 Central Decimal File or the 1963–73 CFPF** — the two files that carry 73% of the
corpus's notes. Note the constraint the tree already records: the live "Central Decimal Files"
series carries **23 entry numbers** (`CentralFilesIndex.swift:169`), so naming the series is
possible while naming *the* entry number is not, absent a date-block mapping.

### 1.2 Repository, measured

`document_sources.repository` **stores the creating agency, not a visitable facility**
(`IndexingPipeline.swift:6166-6218`): a lot file and a decimal file both write the literal
`"Department of State"`; a CIA job writes `"Central Intelligence Agency"`. Neither is a place a
researcher can go. The packet's "one repository per chapter" therefore cannot key on this
column — the holding facility has to be derived.

The cross-volume authority carries 27 distinct repository strings. Joined to
`collection-usage-index.json`, by documents:

| Documents | Volumes | `repository` string | What a researcher would actually visit |
|---:|---:|---|---|
| 38,277 | 325 | Department of State | derived — a NARA facility, not State |
| 7,971 | 67 | **Nixon** (unsuffixed) | Nixon Library, Yorba Linda — but these materials moved from College Park in 2007 |
| 5,487 | 208 | *(no repository field)* | unknown |
| 4,628 | 60 | Johnson Library | Austin, TX |
| 4,618 | 29 | Carter Library | Atlanta, GA |
| 3,220 | 89 | Eisenhower Library | Abilene, KS |
| 2,353 | 31 | Kennedy Library | Boston, MA |
| 1,922 | 40 | Ford Library | Ann Arbor, MI |
| 1,651 | 109 | National Archives | derived |
| 1,418 | 126 | Central Intelligence Agency | CREST — served at College Park, not at CIA |
| 1,339 | 13 | Reagan Library | Simi Valley, CA |
| 1,045 | 86 | Library of Congress | LC Manuscript Division — non-NARA |
| 405 | 33 | Roosevelt Library | Hyde Park, NY |
| 241 | 29 | National Defense University | non-NARA |
| 104 | 23 | Truman Library | Independence, MO |
| 70 | 6 | Center of Military History | non-NARA |
| 52 | 6 | Naval Historical | non-NARA |
| 51 | 11 | **Washington National Records Center** | **not a public research room** |
| 10 | 2 | Bush Library | College Station, TX |
| ≤9 each | | Department of Defense · University of Montana · Minnesota Historical Society · Yale · Hoover Institution · University of Arkansas · Princeton · U.S. Army Military History Institute | eight non-NARA rows, 45 documents between them |

Two of these would send a researcher somewhere they cannot be served: **Washington National
Records Center** is a records centre, not a research room, and **Central Intelligence Agency**
is a creator whose FRUS-cited material is consulted as CREST at College Park. A chapter headed
with either string is a wrong claim about a real institution, which is precisely what the gate
exists to prevent.

Against that, one measurement shrinks the NARA side of the table to nearly nothing:
`series-facts-index.json` carries NARA's own **reference unit** for every series the app can
name, and it is **694 of 695 "National Archives at College Park — Textual Reference"** (the
695th is College Park Motion Pictures). The NARA facility is not a curation problem; it is a
field the catalogue already answers.

### 1.3 The A4 lead-time flag engine, priced

| A4 criterion | Fires on | Share of notes |
|---|---:|---:|
| Records of sensitive agencies ("such as State, Defense…") | 212,192 State notes + 2,933 intelligence | **81.4%** |
| Records dated 1960s and later | 56,417 | 21.3% |
| Lot-file numbers that "do not always carry over" | 6,230 unresolved of 14,487 lot notes | 43.0% of lot notes; 2.4% of all |

The sensitive-agency criterion fires on four notes in five, and on essentially every project
(FRUS *is* State Department records). A per-series chip that is lit on every row carries no
information; the criterion is still true and still NARA's own, so it belongs in the packet as a
stated constant, not as a discriminating flag. The two criteria that actually discriminate
between projects are the date test and the unresolved-lot test.

### 1.4 T-3's inputs, re-scoped from the tree

The plan's §2 table marks four riders "Pending N-7/N-2." Three shipped and one was measured out:

| Rider | Plan says | Tree says |
|---|---|---|
| Restriction triage (`accessRestriction`) | Pending N-7 | **Shipped.** 695 series: 138 **Restricted — Fully** (19.9%), 265 Restricted — Partly, 78 Possibly, 214 Unrestricted. 404 carry FOIA exemptions, 399 of them (b)(1) National Security |
| Already-digitised / mandatory substitutes | Pending N-7/N-2 | **Shipped.** `digitized-ranges-index.json` (624 decimal ranges), `roll-scans-index.json` (1,238 roll scans, M862) |
| Series date-check | Pending N-7 | **Shipped.** `y0`/`y1` present on 695 of 695 series |
| `numberingNote` | Pending N-7 | **Retired by measurement.** Projected on 385 records corpus-wide but reaching **1** of the app's 622 named series (`HarvestShardReader.swift:47-49`, pinned in `SeriesFactsIndexTests.swift:203`) |

The restriction figure is the one that changes priorities: **69.2% of the series a packet can
name are restricted to some degree, and one in five is closed outright.** A researcher who flies
to College Park to pull a fully-restricted series has lost the trip — which is the exact harm
§3's honesty rules exist to prevent — and the data to warn them shipped months ago.

---

## 2. What the audit changes about the plan

1. **The repository table is not ~16 curated rows of NARA facts.** NARA's own catalogue answers
   the facility for 694 of 695 series. What needs curating is the **non-NARA and
   presidential-library tail** — and a rule for the two strings that name no visitable place.
2. **The plan's grouping key does not exist as a field.** `repository` is the creator. Facility
   is a derived value, and deriving it is T-1 work that the plan does not currently name.
3. **The pull worksheet's series grain is available for 3.1% of notes, not for most.** Either
   the decimal-file date blocks get curated series identities, or the worksheet's honest unit
   for three-quarters of the corpus is the record group plus the file number — which
   `decimal-class-labels.json` can now render in words (`812.6363` → *Mexico — Petroleum*).
4. **Restriction triage should lead, not trail.** It is shipped data answering the question that
   decides whether the trip is worth taking.
5. **T-3 as scoped is nearly empty** — three inputs landed, one is retired. What remains is
   assembly, which belongs wherever the sections ship.

---

## 3. The fact inventory, sorted by what can be checked here

The gate lists ~40 institutional facts. They divide cleanly, and the division is what makes the
gate tractable: one half is verifiable inside this repository right now, the other half cannot
be verified from this container at all.

### 3.1 Deposited — verbatim in `Planning/reference/nara-research-visit-faqs-2026-08-04.md`

Checkable against the in-repo text; no external access needed. Confirm the *transcription* was
faithful, not the fact.

- Appointments **strongly encouraged** for Washington DC and College Park; **required** at all
  other field facilities and St. Louis.
- Reference inquiry is **part of appointment scheduling outside the DC area**; strongly
  encouraged for DC-area rooms.
- **Send to only one address**; main contact box when the facility is unknown.
- **Minimum 4 weeks**; a few days to register; **10 business days** for a staff response; write
  **even sooner** for complex or ongoing questions.
- NARA staff **"cannot undertake research for you."**
- The six-element inquiry spec, including **record group, entry number, series title** and
  **NAID** links.
- **One agency or a group of closely related agencies** per inquiry; multiple inquiries expected.
- The extra-notice list: **1960s and later**; **"State, Defense, Justice, the FBI, and the
  intelligence agencies"**; **lot-file numbers that "do not always carry over into use by the
  National Archives"**; recently transferred; cold storage; off-site storage.
- The not-well-described advisory, and that it **"cannot be done effectively on an ad hoc basis
  while researchers wait in a research room."**
- **"Researchers must use microfilm and online resources when those options are available."**
- Records may be **moved to a Presidential Library or a field facility**; may be temporarily
  unavailable; may need review before release.
- Record Group / Presidential Library / Donated Collections Explorers; **History Hub**.

### 3.2 Search-verified only — no in-repo source; owner must confirm before T-2 prints them

Every item below is a hard claim about a real institution that a researcher will act on, and
none can be checked from here.

- **−2 business days** advance notice for off-site records.
- College Park **pull times** (M–F 9:30 / 10:30 / 11:30 / 1:00 / 2:00 / 3:00) and **nothing
  signed out after 5:15**.
- **Day-0 registration** for a researcher ID card.
- The literal **NACP address** (8601 Adelphi Road) and the **one inquiry address**
  (`archives2reference@nara.gov`).
- The **3rd-floor consultation area**, 9–4 M–F.
- The **senior foreign-affairs specialist, Wednesdays 9:30–10:30**, mornings by request.
- **Room rules**: lockers; flatbed and overhead scanners allowed; no auto-feed or hand-held
  scanners, no personal copiers; one box and one folder at a time; airport-style screening.
- **Withdrawal notices route to FOIA/MDR**; declassification stamping on copies.
- The **NACP citation format** (GIL 17 and the two State-records citation PDFs).
- **Eventbrite** for DC-area research appointments; College Park's reservation page.
- Presidential libraries: **write, phone, or email ahead**, *and* the separate **"confirm the
  materials are at this location"** claim — the mock's source mark sits after the second, leaving
  the first uncovered.
- **Per-library** address, inquiry email, and appointment policy — eleven rows.
- **Library of Congress Manuscript Division** as a non-NARA pointer row with its own guidance.

### 3.3 The correction the gate already recorded

The honesty rule is a stamp **per volatile fact** ("as of ⟨date⟩" with its archives.gov link).
Artboard 1k draws a single aggregate stamp per card. **The per-fact form is the one to
implement** — and it has a second use worth naming: if `verifiedDate` is per fact and nullable,
and the packet **omits** an unverified fact rather than printing it undated, then T-1 and T-2
can build against a partially confirmed table and each confirmed fact lights up a line. That
turns the gate from one all-or-nothing sitting into an incremental one, without weakening it:
an unconfirmed fact still never prints.

---

## 4. Decisions

### 4.1 Settled, 2026-08-21

**D1 — Worksheet grain for the decimal-file mass: curate the date-block series.** T-0 gains a
second curation item beside the repository table: a NARA series identity (title + NAID, and an
HMS/MLR entry number where the block has one of its own) per **Central Decimal File date block**
— 1910–29, 1930–39, 1940–44, 1945–49, 1950–54, 1955–59, 1960–63 — and per **CFPF** block.
Roughly ten rows, converting ~73% of the corpus's notes from record-group grain to series grain
and to NARA's four-field inquiry line.

The constraint the tree already records is the whole reason this is curation and not a
generator run: the live "Central Decimal Files" series carries **23 entry numbers**
(`CentralFilesIndex.swift:169`), so a resolver can name the series and its NAID but cannot name
*the* entry number — the date-block mapping is exactly the judgement a machine cannot make here.
Rows are hand-authored, each carrying its own source, and the file follows
`curated-lot-resolutions.json`'s precedent: **no generator writes it**, so a re-harvest can
never overwrite human archival judgement.

**D2 — Repository table: derive the NARA facility, curate only the tail.** The facility for a
NARA series comes from `series-facts-index.json`'s reference unit — data, not curation, and
measured at 694 of 695 "National Archives at College Park." Hand-curation is scoped to what the
catalogue cannot answer: the **11 presidential libraries** and the **non-NARA tail** (Library of
Congress Manuscript Division, National Defense University, Center of Military History, Naval
Historical, and the eight rows carrying 45 documents between them). This shrinks the
fabrication surface to the rows where a wrong sentence is possible at all.

**D3 — Non-visitable repository strings map to the serving facility.** Bare *Department of
State* and *Central Intelligence Agency* both route to **College Park**, with the creating
agency named as provenance and never as a destination (CIA-cited material is consulted as CREST
at NACP, not at CIA). *Washington National Records Center* prints an explicit note that the
records were later accessioned or remain in a records centre, and that staff must confirm the
location — it is never a chapter heading a researcher could travel to. No chapter in this packet
may be headed with a string that names no place a researcher can be served.

**D4 — Restriction triage promotes to the first shipping cut.** It moves out of T-3 and into
T-2, beside chapters 1–3 and 6–7. The measurement is the argument: 481 of 695 series (69.2%) are
restricted to some degree and **138 (19.9%) are Restricted — Fully**. A researcher who flies to
College Park to pull a closed series has lost the trip, the data to warn them shipped months
ago, and no other page in the packet answers a question that large.

### 4.2 Settled by the owner, 2026-08-21

The gate's remaining six, answered in the same sitting. Each is recorded with the reason the
recommendation stood, so a later reader can tell a decision from a default.

**D5 — Visit date is optional, with relative lead times as the fallback** (scope §5.1). A packet
is most useful *before* the trip is booked, so requiring a date would gate the packet on the
decision the packet exists to inform. With a date the checklist prints absolute rows ("write by
12 September"); without one it prints the same rows relatively ("at least 4 weeks before you
arrive"). Both forms carry the A4 escalation — the flag engine does not depend on the date.

**D6 — Presidential libraries ship in v1 at collection grain** (§5.3). 29,093 notes (11.0%) over
ten libraries, and **zero** of them resolve to a NAID offline — the libraries sit outside every
record group, so the catalogue harvest structurally cannot reach them. That coarseness is the
argument *for* inclusion rather than against it: A12's ask is to confirm the materials are at
that location before you travel, and a library trip is a flight rather than a Metro ride.
`curated-library-resolutions.json`'s 185 owner-fetched finding-aid URLs stand in for the series
identity the catalogue cannot supply, and the chapter says which of the two it is showing.

**D7 — Per-fact nullable `verifiedDate`; an unverified fact is omitted, never printed undated**
(§5.4). Snapshot semantics, not a re-verification gate on every release. This is also the gate's
own correction to artboard 1k, which draws one aggregate stamp per card where the honesty rule
asks for a stamp per volatile fact. The nullability is what makes the gate incremental: T-1 and
T-2 build against a table with zero confirmed rows, and each fact the owner confirms lights up
one line rather than the whole feature waiting on one sitting.

**D8 — The topic sentence is SEEDED from `Project.researchQuestion` and remains EDITABLE.**
Refines the standing recommendation, which said only "quote it". The project's research question
is exactly NARA's "succinct description of your research interest", so it is the right default —
but it is an internal note written for the researcher's own use, and the draft is an email to
NARA reference staff. So T-2 owes an **editable** topic-sentence field pre-filled from the
project, not a quoted string baked into the export: the researcher edits before sending, and a
project with no research question gets the placeholder rather than an empty paragraph. This is a
UI obligation on T-2, not only a copy rule — the export path must read the edited value.

**D9 — The sensitive-agency criterion prints ONCE as a standing checklist sentence** (§1.3);
per-series chips are reserved for the two criteria that discriminate between projects (documents
dated ≥1960; unresolved lot citations). The measurement is the reason: the criterion fires on
81.4% of source notes because FRUS *is* State Department records, and a chip lit on every row
carries no information while costing the two informative chips their salience. A4's
quote-which-criterion-fired requirement is still met — the standing sentence quotes the FAQ's
own list, and the chips quote theirs.

**D10 — `numberingNote` is dropped from T-3.** Confirmed. The plan's "385 series" is corpus-wide;
the app-reachable count is **1 of 622** (`HarvestShardReader.swift:47-49`, pinned at
`SeriesFactsIndexGeneratorTests/SeriesFactsIndexTests.swift:203`). No alternative is proposed:
the ordering instruction a researcher needs is the RG/entry/series/box line the pull worksheet
already prints.

With D1–D10 settled, **the T-0 gate's engineering half is unblocked**. What remains owner-only is
the fact confirmation itself (§3.2), and D7 is what lets that proceed fact by fact instead of all
at once.

## 5. What T-1 may start on

With the decisions settled, the whole platform-neutral half is open:

- The facility-derivation function and its fixtures — **now fully specified by D2 and D3**:
  reference unit for a NARA series, the curated row for a library or non-NARA repository, and
  the serving-facility mapping for the three strings that name no visitable place.
- `TripPacketModel` over `CollectionGeneratedBlocks.archivalSourceRows` — the grouping key at
  `:492` already carries repository / RG / lot / series.
- The A4 date and unresolved-lot tests, which are computable from data the app holds — and D9
  now fixes their presentation too: two chips, plus one standing sentence for the third criterion.
- The restriction-triage read over `series-facts-index`, which D4 moved into the first cut.
- The repository table's **schema** — nullable per-fact `verifiedDate` per D7 — which can be
  written, enrolled, and tested with zero confirmed rows in it.
- The checklist's two lead-time forms (absolute and relative), per D5.
- The editable topic-sentence field seeded from `Project.researchQuestion`, per D8 — the edited
  value, not the stored one, is what the exporter reads.

What T-1 may **not** do is print an institutional fact from §3.2 that the owner has not
confirmed. The empty-table-that-still-builds shape in §3.3 is what makes that separation
enforceable rather than aspirational.

---

## Version history

- **1.1 (2026-08-21)** — Owner settled the remaining six decisions (§4.2): visit date optional
  with relative fallback; presidential libraries in v1 at collection grain; per-fact nullable
  `verifiedDate` with unverified facts omitted; the inquiry topic sentence seeded from the
  project's research question **and editable** (a refinement of the recommendation, and a T-2 UI
  obligation); the sensitive-agency criterion as one standing sentence rather than a per-series
  chip; `numberingNote` dropped from T-3. The engineering half of the T-0 gate is unblocked; the
  owner-only fact confirmation (§3.2) remains, now incremental by D7.

- **1.0 (2026-08-21)** — T-0 data audit run offline against the shipped artifacts; the
  repository-field finding (`repository` is the creating agency); the reference-unit measurement
  that shrinks the NARA side of the table; the four-field coverage table; the A4 flag pricing;
  T-3 re-scoped from the tree; the fact inventory split deposited/search-verified; ten decisions
  put to the owner, of which D1–D4 were settled the same day (curate the decimal date-block
  series; derive the NARA facility and curate only the tail; map non-visitable strings to the
  serving facility; promote restriction triage to the first cut).
