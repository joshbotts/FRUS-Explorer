# Research Trip Packet — scope against NARA's own pre-visit guidance

**Date:** 2026-08-04 · **Version:** 1.1 · **Status:** scoping for owner review — no code
rides this document. Follows from `Planning/Feature-Priorities-Review-2026-08.md` §5a.2.

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
| A8 | **Off-site records need two business days' advance pull notice**; pull times at College Park are scheduled (M–F 9:30/10:30/11:30/1:00/2:00/3:00, nothing signed out after 5:15). *(research/start/plan-your-visit; college-park/researcher-info — search-verified; spot-check)* | Checklist row (−2 business days) + visit-day card, both stamped "as of ⟨generation date⟩ — confirm at ⟨link⟩". |
| A9 | **Register on arrival** for a researcher ID card. *(plan-your-visit — search-verified)* | Visit-day card line item. |
| A10 | **Restrictions**: classified/withdrawn material; declassification stamping on copies; withdrawal notices → FOIA/MDR. *(research-room rules/regulations; self-service-copying — search-verified)* | **Restriction triage** per series from `accessRestriction` (N-7 rider; the consolidated plan already calls it "exactly what a researcher planning a College Park trip needs *before* booking"), plus a withdrawal-notice/MDR explainer. Feeds the future declassification-gap explorer; does not depend on it. |
| A11 | **Foreign-affairs researchers get dedicated help**: RDT2 (`archives2reference@nara.gov`, 8601 Adelphi Road), 3rd-floor consultation area 9–4 M–F, **senior foreign-affairs specialist Wednesdays 9:30–10:30** and mornings by request; RG 59 has its own FAQ PDF and finding aids. *(research/foreign-policy/assistance — search-verified)* | College Park visit-day card names the consultation area and the Wednesday slot; packet links the RG 59 FAQ PDF the app already links. Day-of fallback for A5's unresolved items. |
| A12 | **Presidential libraries**: write/phone/email ahead to confirm materials are at that location; include postal address and phone; the inquiry is part of appointment scheduling outside DC. *(presidential-libraries/visit — search-verified; consistent with [FAQ] on non-DC units)* | Each library chapter gets its own inquiry draft (A2/A3 template, that library's address, required-appointment wording) — doubly valuable while resolutions are collection-grain (N-4). |
| A13 | **Citation practice**: GIL 17; NARA's "Citing Foreign Affairs Records" — first citation carries full series title + RG + entry; lot citations name bureau/office and folder title; box numbers when the series is large. *(17-citing-records.html; state-dept citations.pdf + guidance PDF — search-verified)* | The **citation crib**: one worked example per series type present in the packet, pre-filled from the project's own documents, linking both PDFs. |
| A14 | **Room rules**: lockers; laptops/cameras/flatbed+overhead scanners allowed, no auto-feed or hand-held scanners or personal copiers; locking bags; one box and one folder at a time; airport-style screening. *(research-room-rules; nara-regulations; building-access-security-requirements — search-verified)* | Visit-day card, condensed to what changes packing or planning. Dated + linked like A8. |

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
3. **Date and link every volatile fact** (pull times, hours, appointment policy): packet
   generation date + the repository row's `verifiedDate` + the archives.gov link. NARA changed
   pull times in 2017 and visit procedures after 2020; the packet is a snapshot and says so.
4. **Range-grain for scans** (inherited from N-7 verbatim): "scanned microfilm for file range
   763.72/1476–1635" — a range, never a document.
5. **Availability is never promised.** Per A6, records can be off-site, in preservation, under
   review, moved to a library, or not yet transferred — all packet availability language is
   "confirm with staff," and the inquiry drafts ask.

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
   export.
3. **Pull worksheet** — RG → series (title · entry · NAID → Catalog link · dates ·
   `numberingNote`) → document roster (FRUS citation · file/folder designation) · blank Box
   column.
4. **Mandatory substitutes** — digitised series and microfilm publications first, framed per
   A6's "must use" rule, range-grain.
5. **Restriction triage** — per-series `accessRestriction`, withdrawal/MDR explainer (A10).
6. **Citation crib** — per series type, worked from this packet's documents (A13).
7. **Visit-day card** — pull times, consultation area + Wednesday foreign-affairs specialist
   (College Park), room rules, screening (A8/A11/A14).

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

## 5. Open decisions for the owner

1. **Visit-date input**: required (enables the countdown) or optional (relative lead times)?
   Recommend optional with relative fallback.
2. ~~Inquiry drafts: one per repository or combined?~~ **Resolved from source (v1.1):** one
   address per repository, split per agency cluster within it — the FAQ's one-address and
   one-agency rules dictate the shape.
3. **Presidential libraries in v1**: include with collection-grain rows now (recommended — A12's
   confirm-before-travel ask is *more* valuable when resolution is coarse), or hold for N-4?
4. **Repository-table maintenance**: `verifiedDate`-stamped snapshot with links (recommended,
   matches §3.3), or gate each release on re-verification?
5. **Research-question reuse**: drafts quote the project's stored research question as the
   topic sentence (recommended; it is exactly A3's "succinct description"), or leave a
   placeholder?

---

## Version history

- **1.1 (2026-08-04)** — Rebuilt against the verbatim FAQ text (deposited at
  `Planning/reference/nara-research-visit-faqs-2026-08-04.md`): added the effective-inquiry
  spec (A3), the extra-lead-time flag engine (A4), the not-well-described/ad-hoc advisory
  routing unresolved citations into the inquiry (A5), the mandatory-substitutes rule (A6), the
  Explorers/History Hub links (A7); resolved the inquiry-structure decision from source;
  premise re-anchored on the FAQ's "official documentary publications" passage.
- **1.0 (2026-08-04)** — Initial scope from search-gathered guidance: traceability table, data
  inventory, honesty rules, packet shape, sessions T-0…T-3, open decisions.
