# Research Trip Packet — scope against NARA's own pre-visit guidance

**Date:** 2026-08-04 · **Version:** 1.4 · **Status:** scoping for owner review — no code
rides this document. **The T-0 gate is under way in
`Planning/Research-Trip-Packet-T0-Prereqs.md` (2026-08-21)**, which carries the offline data
audit and settles four decisions this document did not anticipate; where the two disagree, the
prereqs memo is later and wins. Follows from `Planning/Feature-Priorities-Review-2026-08.md` §5a.2.

**Primary source, deposited in-repo:** NARA's research-visit FAQ, "How can I make my visit more
successful?" (https://www.archives.gov/research/start/research-visit-faqs), captured verbatim
2026-08-04 in `Planning/reference/nara-research-visit-faqs-2026-08-04.md` (owner-supplied text;
archives.gov is unreachable from the development container). Companion pages — plan-your-visit,
College Park researcher info, the foreign-affairs assistance page, research-room rules, the two
citation PDFs, presidential-library visit guidance — were gathered by web search the same day
and are cited inline; those still deserve an owner spot-check before T-2 ships copy.

**The premise is NARA's own sentence.** The FAQ's answer to "what should I consult before
visiting?" reads: *"official documentary publications often cite records or provide examples of
records now in the National Archives. These can provide entry points for starting research on a
particular topic. Be sure to take note of records descriptions and file citations and note those
in your reference inquiries and bring your notes with you when you visit."* FRUS is **the**
official documentary publication for U.S. foreign relations, and FRUS Explorer already turns its
source notes into records descriptions and file citations. The Research Trip Packet is that
sentence, executed: the notes taken, the citations organized, the inquiry drafted — generated
from the documents the researcher has already collected.

Three more FAQ passages fit this app so precisely they read like a requirements memo:

1. **The effective-inquiry spec asks for exactly what the app computes.** "If you are interested
   in specific records, please identify them by **record group, entry number, and series
   title**. **NAID Numbers** are useful for linking to record series within the Catalog. Include
   NAID links…" — record group, entry (HMS/MLR), series title, and NAID are the four fields of
   the app's bundled lot and volume-sources indexes.
2. **NARA names the app's hardest problem by name.** Extra advance notice is needed for "records
   for which you have incomplete or partial identification (records center accession numbers or
   **agency-assigned numbers, such as Department of State 'Lot File' numbers, that do not always
   carry over into use by the National Archives**)." That is #375's 581 unresolved lots,
   described by NARA as the expected case — the packet must treat an unresolved lot as a
   *predicted* condition with a prescribed remedy (name it in the advance inquiry), not as an
   app failure.
3. **The State Department is on NARA's extra-lead-time list explicitly**, along with "more
   recent records (1960s and later)" — i.e., most of the modern FRUS subseries. Nearly every
   packet this feature generates should carry the write-early flag on NARA's own criteria.

---

## 1. NARA's advisories → packet obligations (the traceability table)

Sources: **[FAQ]** = the deposited research-visit-faqs text; others cited per row.

| # | NARA advisory | What the packet must therefore do |
|---|---|---|
| A1 | **Appointments**: strongly encouraged for DC (A1) and College Park (A2); **required at all other field facilities and St. Louis**; per-facility details on the Visit Us page. [FAQ] Booked via Eventbrite for the DC area *(archives.gov search; eventbrite.com "National Archives DC-area Research Appointments")* | Visit checklist row per repository, with that repository's policy (encouraged vs required) and link. |
| A2 | **Reference inquiry in advance**: part of appointment scheduling outside DC; strongly encouraged for DC-area rooms; **send to only one address**; if facility unknown, the main Contact Us box; **minimum 4 weeks** before arrival — a few days to register the inquiry, then **10 business days** for a staff response; **write even sooner for complex/ongoing questions**; NARA staff provide information about records but **"cannot undertake research for you."** [FAQ] | Generate the **advance inquiry draft(s)** with the correct single address per repository, a countdown that treats 4 weeks as the *minimum* (and says "sooner" when the packet spans many series), and framing that asks *about records* — locations, entries, availability, off-site status — never for research. |
| A3 | **The effective-inquiry spec**: succinct, narrow topic (never "everything you have"); **one agency or closely related agencies per inquiry** — multiple inquiries are the expected shape; specific dates; named individuals (full name, federal relationship, dates, alphabetized); a list of specific questions; records identified by **RG + entry number + series title**, with **NAID links to the Catalog**. [FAQ] | The draft's structure is dictated, not designed: topic sentence from the project's research question (Projects already store one); the date span from the packet's documents; the series table in NARA's own four-field format with catalog NAID links; a generated question list (boxes, off-site status, availability). **One draft per record-group cluster within a repository** — State-cluster RGs (59/84/…) may share one; unrelated agencies (e.g. RG 218 JCS) get their own. This resolves former open decision 2 from the source. |
| A4 | **Extra advance notice** needed for: recent records (**1960s and later**); **sensitive agencies — "such as State, Defense, Justice, the FBI, and the intelligence agencies"**; incomplete/partial identification (**lot-file numbers "do not always carry over"**); recently transferred records; cold storage; off-site storage. [FAQ] | A **lead-time flag engine**: the packet marks each series/section that trips a criterion (document dates ≥1960; RG in the sensitive set — nearly always; unresolved or partially resolved lot citations) and escalates the checklist copy from "4 weeks minimum" to "write early — NARA's FAQ lists your records among those needing extra notice," quoting which criterion fired. |
| A5 | **Not everything is well described**, and resolving poorly-described records "**cannot be done effectively on an ad hoc basis while researchers wait in a research room**" — it may involve transfer documentation, preliminary finding aids, classified indexes, even the agency of origin; "by writing in advance, some of the problems may be overcome." [FAQ] | The **unresolved-citations section** routes into the *advance inquiry*, not the consultation desk: every unresolved source note appears verbatim (with its FRUS citation) inside the relevant inquiry draft as a "help me locate" item. The in-room consultation desk (A11) is the day-of fallback, and the packet says so in that order. |
| A6 | **Advance contact also surfaces**: facility hours/holidays; procedures; **records available online or on Microfilm Publications — "Researchers must use microfilm and online resources when those options are available"**; records never transferred (destroyed under schedules) or not yet transferred (agency of origin); records temporarily unavailable (preservation/digitisation); records **moved to a Presidential Library or field facility**; off-site storage; pending declassification/restriction review. [FAQ] | Three packet consequences: (i) the **"already digitised — you must use these anyway"** section is strengthened from convenience to NARA policy — series with digital objects or microfilm publications (M820 etc.) lead the packet, framed as *mandatory substitutes* for pulls; (ii) inquiry drafts ask the availability/off-site/moved questions the app cannot answer; (iii) the packet never promises a record is pullable — availability language is always "confirm with staff." |
| A7 | **Do your homework in the Catalog first**; the Record Group / Presidential Library / Donated Collections Explorers are the entry points; **History Hub** is NARA's hosted Q&A community. [FAQ] | Every series row links its NAID in the Catalog; each RG chapter links its Record Group Explorer page; the packet's help footer offers History Hub as the public-question venue alongside the one-address inquiry rule. |
| A8 | **Off-site records need two business days' advance pull notice**; pull times at College Park are scheduled (M–F 9:30/10:30/11:30/1:00/2:00/3:00, nothing signed out after 5:15). *(research/start/plan-your-visit; college-park/researcher-info — search-verified; spot-check)* | **Rescoped 2026-08-21 (T-0 §3.2).** Both halves are negated as printed facts. The −2 business-day countdown is *uncomputable*: per A6 the app cannot know which records are off-site, so it could never key the row to anything, and generically it is dominated by A2’s −4 weeks. Pull times are the most volatile fact in the set (changed 2017). The card says pulls run on a fixed schedule and **links** the page, stamped per D12. |
| A9 | **Register on arrival** for a researcher ID card. *(plan-your-visit — search-verified)* | Visit-day card line item. |
| A10 | **Restrictions**: classified/withdrawn material; declassification stamping on copies; withdrawal notices → FOIA/MDR. *(research-room rules/regulations; self-service-copying — search-verified)* | **Restriction triage** per series from `accessRestriction` (N-7 rider; the consolidated plan already calls it "exactly what a researcher planning a College Park trip needs *before* booking"), plus a withdrawal-notice/MDR explainer. Feeds the future declassification-gap explorer; does not depend on it. |
| A11 | **Foreign-affairs researchers get dedicated help**: RDT2 (`archives2reference@nara.gov`, 8601 Adelphi Road), 3rd-floor consultation area 9–4 M–F, **senior foreign-affairs specialist Wednesdays 9:30–10:30** and mornings by request; RG 59 has its own FAQ PDF and finding aids. *(research/foreign-policy/assistance — search-verified)* | **Split 2026-08-21 (T-0 §3.2).** The address and inquiry email are **kept and verified** — A2’s one-address rule is the inquiry mechanic. The *existence* of dedicated foreign-affairs reference staff and the consultation desk is asserted (it is A5’s day-of fallback). The floor, the hours, and the Wednesday window are negated and linked: one person’s calendar is the fastest-rotting claim available, and a trip booked around a slot that no longer exists is a trip lost. |
| A12 | **Presidential libraries**: write/phone/email ahead to confirm materials are at that location; include postal address and phone; the inquiry is part of appointment scheduling outside DC. *(presidential-libraries/visit — search-verified; consistent with [FAQ] on non-DC units)* | Each library chapter gets its own inquiry draft (A2/A3 template, that library's address, required-appointment wording) — doubly valuable while resolutions are collection-grain (N-4). |
| A13 | **Citation practice**: GIL 17; NARA's "Citing Foreign Affairs Records" — first citation carries full series title + RG + entry; lot citations name bureau/office and folder title; box numbers when the series is large. *(17-citing-records.html; state-dept citations.pdf + guidance PDF — search-verified)* | The **citation crib**: one worked example per series type present in the packet, pre-filled from the project’s own documents, linking both PDFs — **quoted and attributed to NARA, never prescribed** (D13). Publishers and style guides disagree on archival form, and the app already declines to ratify one (`CitationStyle` ships three, marking History at State "Recommended"). Deposit the PDFs and this row becomes a transcription check. |
| A14 | **Room rules**: lockers; laptops/cameras/flatbed+overhead scanners allowed, no auto-feed or hand-held scanners or personal copiers; locking bags; one box and one folder at a time; airport-style screening. *(research-room-rules; nara-regulations; building-access-security-requirements — search-verified)* | Visit-day card, condensed to what changes packing or planning — and **that rule negates two of these four** (T-0 §3.2). The scanner rule changes what you pack; lockers change what you carry in. One-box-one-folder and airport screening change nothing the researcher would do differently, so they are linked rather than printed. |

---

## 2. What the app already has, per packet section

The packet is an **exporter over resolutions the app already computes**, plus fields arriving
with N-7. Inventory:

| Packet need | Backing data | Status |
|---|---|---|
| RG + entry + series title + NAID (A3's four fields) | `SourceNoteParser` per-document parses; `central-files-index.json` (971 lots → NAID, RG numbers, **HMS/MLR entry numbers** from the #315A `ENRICH_LOTS` pass); `volume-sources-index.json` (31 RG headers); `collection-authority.json`; N-3/N-4 curated NAIDs as they land | **Shipped** (curation lanes still filling) |
| Grouping engine | `CollectionGeneratedBlocks.archivalSourceRows` groups by (repository, recordGroup, lotFile, seriesName) | **Shipped — reuse**, extended with per-series document rosters |
| Research topic + dates for the inquiry (A3) | `Project` research question; document date spans from the engaged set | **Shipped** |
| Lead-time flags (A4) | Document dates (≥1960); RG membership (sensitive set is a constant); unresolved-lot detection (the resolver's misses, already surfaced honestly in Source Explorer) | **Shipped** — flag logic is new but all inputs exist |
| Restriction triage (A10) | `accessRestriction` — 100% of harvest records carry it | **Pending N-7 rider** |
| Already-digitised / mandatory-substitutes (A6) | N-7's digital-object bundle (~4,800 rows); microfilm-publication identity for RG 256 M820 comes with N-2 | **Pending N-7/N-2** |
| Per-series ordering instructions | `numberingNote` (385 series) | **Pending N-7 rider** |
| Series date-check | `inclusiveStartDate`/`inclusiveEndDate` (100% of series) — flags a resolution whose dates don't cover the citing document | **Pending N-7 rider** |
| Citation crib (A13) | `CitationFormatter` + parses supply the FRUS side; archival-side templates are static copy from NARA's two PDFs | **New copy, no new data** |
| Repository table (A1/A2/A8/A11/A12/A14) | Does not exist. Hand-curated bundled JSON (~16 rows): College Park, Archives I (DC), the presidential libraries the index cites (1,363 (repository, collection) pairs; ~14 library rows cover them), LC Manuscript Division (non-NARA — pointer row), manuscript repositories (N-2d static guidance pointer). Each row: name, address, inquiry email (the **one** address, per A2), appointment policy + link, pull-time note + link, `verifiedDate` | **New — the one genuinely new artifact** |
| Visit-date checklist (A1/A2/A8) | User-entered visit date; computed lead times (−4 weeks minimum, escalated by A4 flags; −2 business days) | **New, trivial** |
| Export | PDF via existing `CollectionExporter` infrastructure; inquiry drafts additionally as plain text via share sheet / `mailto:` | **Reuse** |

---

## 3. Honesty rules (what the packet must refuse to claim)

House culture applies — a confident wrong claim in an archive packet costs the researcher a
trip. Five rules:

1. **Never fabricate box numbers.** Source notes cite decimal/file/folder designations, not
   boxes; the worksheet's Box column ships blank and the inquiry draft asks for it. (The FAQ's
   effective-inquiry spec asks for RG/entry/series/NAID — box numbers are what staff and finding
   aids supply back.)
2. **Unresolved lots are NARA's predicted case, not an app defect.** Copy quotes the FAQ: lot
   numbers "do not always carry over into use by the National Archives." The remedy is A5's —
   into the advance inquiry, verbatim, with the FRUS citation.
3. **Date and link every volatile fact** — and prefer *not printing it at all*. The stamp is
   **per fact**, never per card (the gate's correction to artboard 1k), and an unverified fact is
   **omitted** rather than printed undated (D7). The 2026-08-21 walkthrough took this further:
   where a link serves as well as a sentence, the packet links. NARA changed pull times in 2017
   and visit procedures after 2020, and a stale schedule is worse than none — the researcher
   plans around it. What the packet asserts is what it **computes from the researcher's own
   documents**; what any reader can take off archives.gov in ten seconds, it links.
4. **Range-grain for scans** (inherited from N-7 verbatim): "scanned microfilm for file range
   763.72/1476–1635" — a range, never a document.
5. **Availability is never promised.** Per A6, records can be off-site, in preservation, under
   review, moved to a library, or not yet transferred — all packet availability language is
   "confirm with staff," and the inquiry drafts ask.
6. **Report a recommendation; never ratify one.** Archival citation form is governed by the
   researcher's publisher, journal, or style guide, and those disagree. The crib prints NARA's
   guidance *as NARA's*, attributed and quoted, with the note that the publisher's requirements
   govern (D13). The app already holds this line elsewhere: `CitationStyle` ships three styles and
   marks History at State "Recommended", not correct.
7. **A link is a claim too, and a weaker one than it looks.** A 200 proves a URL resolves, not
   that the page still says what the packet says about it — NARA reorganises, and a dead deep link
   characteristically redirects to a section index that answers 200. So the checker follows
   redirects and treats a changed final URL as *needs review* (D12), and the text attached to each
   link stays minimal: "visiting information", not "pull times are 9:30, 10:30, 11:30".

---

## 4. Proposed shape

**Entry points:** Project Home ("Plan an archive visit" over the engaged set) and a collection's
overflow menu. Both feed the same aggregation: documents → parses → resolutions →
repository/RG/series rollup.

**The packet (PDF, one repository per chapter):**

1. **Cover & checklist** — project, document/series counts, visit-date countdown with A4
   escalation ("write early: your packet includes State Department records and post-1960
   material — NARA's own extra-notice criteria"), appointment + registration rows (A1/A9).
2. **Advance inquiry draft(s)** — per repository, split per record-group cluster (A3); NARA's
   six-element structure; unresolved citations embedded as locate-requests (A5); plain-text
   export. The topic sentence is **seeded from the project's research question and editable**,
   and the exporter reads the edited value (D8). **Presidential libraries get a
   confirm-before-you-travel prompt instead of a drafted letter** (D11) — at collection grain the
   packet can name neither series nor NAID, so it prints A12's actual ask beside the library's
   contact page and the curated finding-aid URL.
3. **Pull worksheet** — RG → series (title · entry · NAID → Catalog link · dates ·
   `numberingNote`) → document roster (FRUS citation · file/folder designation) · blank Box
   column.
4. **Mandatory substitutes** — digitised series and microfilm publications first, framed per
   A6's "must use" rule, range-grain.
5. **Restriction triage** — per-series `accessRestriction`, withdrawal/MDR explainer (A10).
6. **Citation crib** — per series type, worked from this packet's documents (A13), printed as
   an **attributed quotation of NARA's guidance** with the publisher-governs note (D13).
7. **Visit-day card** — **rescoped 2026-08-21 to what does not rot** (T-0 §3.2): day-0
   registration, the scanner and locker rules, the existence of the consultation desk and of
   dedicated foreign-affairs reference staff, and stamped links out for the rest. Pull times, the
   5:15 cutoff, the consultation area's floor and hours, the Wednesday specialist window, and two
   of A14's four room rules are **negated** — the last two by A14's own "changes packing or
   planning" test.

**Sessions:**

- **T-0 (S): data audit + repository table.** Measure on a real project: engaged documents
  resolving to a series with an entry number; presidential-library share; unresolved share.
  Decide minimum-viable grain from measurement. Hand-curate the repository JSON; owner verifies
  each row's links and the companion-page facts (the FAQ itself is already deposited).
- **T-1 (M): aggregation + flag engine** — extend `archivalSourceRows` into a `TripPacketModel`
  (repository → RG → series → roster + A4 flags), platform-neutral, unit-tested on fixture
  projects.
- **T-2 (M): exporter + entry points** — chapters 1–3 and 6–7 (nothing needing N-7), inquiry
  drafts, checklist. Ships useful *before* N-7.
- **T-3 (S): the N-7 riders** — chapters 4–5 plus `numberingNote` and series date-checks, the
  day the N-7 bundle lands. T-3 is the standing reason the N-7 bundle should carry
  `accessRestriction`, `numberingNote`, and the inclusive dates from its first cut.

**Release-checklist obligation (D12).** Repository links carry a stamped `verifiedDate`; an
owner-run checker re-fetches them before a release, follows redirects, and flags a changed final
URL as *needs review* rather than as a pass. Staleness degrades the sentence ("last checked ⟨date⟩;
confirm current guidance"), never the build. The structural half — every printed link carries a
date — is an offline test, and is checkable in CI precisely because it asks nothing of the network.

**Verification oracle:** build the packet for a fixture project spanning a decimal-file
citation, a lot file (one resolved, one unresolved), a presidential-library collection, and a
post-1960 document; then walk the deposited FAQ advisory-by-advisory (A1–A7) and the
search-verified companions (A8–A14), showing each is satisfied by a packet section or
consciously excluded here. A packet claim with no source in this table is a defect.

**Out of scope:** live Eventbrite/scheduling integration (link only); box-number inference;
NARA API dependency at generation time (fully offline from bundles); person-list inquiries (A3's
named-individuals element — FRUS research is records-first; revisit if the People program
lands); non-NARA repository depth beyond the N-2d guidance pointer (LC gets a row, not a
program); History Hub posting integration (link only).

---

## 5. Open decisions — all settled

**Status, 2026-08-21** (full reasoning in `Research-Trip-Packet-T0-Prereqs.md` §4): **every
decision in this section is now settled**, together with four the T-0 audit forced and this
document did not anticipate.

Settled by the audit: curate Central Decimal File date-block series identities (the worksheet's
grain for 73% of notes); derive the NARA facility from `series-facts-index`'s reference unit and
hand-curate only the presidential libraries and the non-NARA tail; map *Department of State* /
*Central Intelligence Agency* / *Washington National Records Center* to a serving facility rather
than heading a chapter with them; and **promote restriction triage from T-3 into the first
shipping cut** (138 of 695 series are Restricted — Fully).

1. **Visit-date input** — **Optional**, with relative lead times as the fallback. A packet is
   most useful before the trip is booked; the A4 escalation does not depend on the date.
2. ~~Inquiry drafts: one per repository or combined?~~ **Resolved from source (v1.1):** one
   address per repository, split per agency cluster within it — the FAQ's one-address and
   one-agency rules dictate the shape.
3. **Presidential libraries in v1** — **Include, at collection grain.** Zero of the 29,093
   library notes resolve to a NAID offline, and that coarseness is the argument for inclusion:
   A12's confirm-before-you-travel ask matters most when the resolution is weakest, and a library
   trip is a flight. The 185 curated finding-aid URLs stand in for the missing series identity.
4. **Repository-table maintenance** — **Per-fact nullable `verifiedDate`**; an unverified fact is
   **omitted**, never printed undated. Snapshot semantics per §3.3, and the gate's correction to
   artboard 1k's single aggregate stamp. Nullability makes the owner's fact confirmation
   incremental: the packet builds with zero confirmed rows.
5. **Research-question reuse** — **Seed and let the researcher edit.** `Project.researchQuestion`
   pre-fills the draft's topic sentence (it is exactly A3's "succinct description"), but the field
   is editable and the exporter reads the edited value: the stored question is an internal note
   and the draft is an email to reference staff. No question stored → the placeholder.

Two further calibrations settled the same day: the A4 **sensitive-agency criterion prints once as
a standing checklist sentence** rather than as a per-series chip (it fires on 81.4% of notes,
because FRUS *is* State Department records), leaving per-series chips to the two criteria that
discriminate — documents ≥1960 and unresolved lots; and **`numberingNote` is dropped from T-3**,
reaching 1 of 622 app-reachable series.

---

## Version history

- **1.4 (2026-08-21)** — The fact walkthrough (T-0 §§3.2–3.5), which rescopes chapters rather
  than verifying facts: A8, A11 and A14 rewritten in the traceability table; chapter 7 reduced to
  what does not rot; the library half of chapter 2 downgraded from a drafted letter to a
  confirm-before-you-travel prompt (D11); chapter 6 reframed as an attributed quotation of NARA's
  guidance rather than a ratified format (D13), on the precedent that `CitationStyle` already
  marks its default "Recommended"; honesty rule 3 rewritten around *prefer not printing it*, and
  rules 6 and 7 added. A release-checklist link obligation replaces per-fact re-verification for
  URLs (D12). Net: ~40 owner-confirmable facts → four claims plus a set of URLs.
- **1.3 (2026-08-21)** — §5 closed: all five open decisions settled by the owner at the T-0 gate
  (visit date optional; libraries in v1 at collection grain; per-fact nullable `verifiedDate`
  with unverified facts omitted; the topic sentence seeded from the project's research question
  and editable), plus the A4 flag calibration and the `numberingNote` drop. Cross-references the
  T-0 audit's four forced decisions. No change to §§1–4.
- **1.2 (2026-08-21)** — Status pointer to `Research-Trip-Packet-T0-Prereqs.md`: the T-0 audit
  ran offline against the shipped artifacts, four unanticipated decisions were settled (worksheet
  grain, repository-table scope, non-visitable repository strings, restriction-triage placement),
  and §2's rider table is stale in both directions — `accessRestriction`, digitised ranges and
  inclusive series dates all shipped, while `numberingNote` was measured out. No scope text was
  rewritten; the memo is the current record.
- **1.1 (2026-08-04)** — Rebuilt against the verbatim FAQ text (deposited at
  `Planning/reference/nara-research-visit-faqs-2026-08-04.md`): added the effective-inquiry
  spec (A3), the extra-lead-time flag engine (A4), the not-well-described/ad-hoc advisory
  routing unresolved citations into the inquiry (A5), the mandatory-substitutes rule (A6), the
  Explorers/History Hub links (A7); resolved the inquiry-structure decision from source;
  premise re-anchored on the FAQ's "official documentary publications" passage.
- **1.0 (2026-08-04)** — Initial scope from search-gathered guidance: traceability table, data
  inventory, honesty rules, packet shape, sessions T-0…T-3, open decisions.
