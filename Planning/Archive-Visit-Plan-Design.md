# Archive Visits — the archival research plan (design, 2026-08-26)

**Status: OPEN DESIGN — ten owner decisions pending (§6).** Written from the owner's direction of
2026-08-26: explicit archival-research-planning entry points on Source Explorer, Project Home, and
Archival Analytics — plus Archival Neighbors and Collections — any of which can seed documents
into a research plan; and per-document UI choosing whether the plan includes only that document's
**archival source location** (its source note), only its **external archival references** (#784's
per-document `external_citations` — the footnotes pointing outside the printed record), or both.
The owner suggested adapting the collections UI and asked what the alternatives are. This document
is that comparison, a recommendation, and the phased plan. It absorbs the accepted Tier A step-1
fixes (the 2026-08-26 reachability audit) as Phase 0 and W-18 as Phase 1.

Everything cited here was verified against tree `979aa413` (file:line refs are to that tree).

## 1. What exists today, in one paragraph

The trip packet is **ephemeral**: `TripPacketSheet(documents:title:researchQuestion:)` takes
`[(volumeId, documentId)]`, builds at presentation time, persists nothing
(`TripPacketSheet.swift:37-44`). Its four entry points are all collection-shaped (Project Home
"Plan a Visit"; the iOS collection editor's two size-class Add menus; the macOS collection
manager). The packet reads only `document_sources` — each document's own source note; the
editors' footnote citations never reach it (that is W-18). The reachability audit (2026-08-26)
found five scoping defects the owner accepted as Tier A step 1: the Project Home seed walks only
collections while Suggested Next three sections up unions collections ∪ notes ∪ focus tags
(`ProjectHomeView.swift:268` vs `ProjectLeadsService.swift:147-149`); the gate tests attachment,
not content (`:308`); smart collections have no route; excerpt entries are filtered out despite
carrying document ids; and the project's research question is baked verbatim into the shareable
inquiry draft — `TripPacketTopicSentence.edited` is written by nothing (`TripPacketModel.swift:32`).
Chapter 3's pull worksheet is the one uncapped chapter (`TripPacketExporter.swift:277-279`).

## 2. The two claims the per-document toggle separates

"**Drawn from**" (the document's own source note → chapters 2–5) and "**pointed at**" (its
footnotes' external references → W-18's separate per-repository section) are distinct claims the
pipeline keeps in separate methods since #783, and W-18 mandates they never merge. The owner's
three-way choice — source only / references only / both — therefore maps onto an existing seam:
a per-document pair `(includeSource, includeExternalRefs)`, projected at build time into **two
document lists** (`sourceDocuments`, `referenceDocuments`) handed to the builder. Flags are never
threaded through the build loop itself — that would corrupt the unresolved-count accounting and
blur the #783 separation.

**Sparsity is a design input**: external references exist on roughly ≤6% of documents corpus-wide
(lot + library kinds, per the shipped corpus aggregate; the live per-document histogram is
re-measured in Phase 4 — this session's read of the live index was TCC-blocked). "References
only" is a niche, deliberate state; the UI must show per-document availability (a count) and
must never render a dead toggle — absent halves get fixed captions ("This document carries no
source note" — true of pre-1906 by design; "No unprinted references in this document's
footnotes").

## 3. The approaches, compared

| | A. Plan-as-Collection | B. Dedicated @Model (WorkingCorpus shape) | C. Device-local store | D. Ephemeral tray | E. Unit-grain entries |
|---|---|---|---|---|---|
| Schema cost | 3 identifiers on the most-shared models | ~8 identifiers, ONE new record type | none | none | rides B's blob — none extra |
| CloudKit deploy | boards reserved W-4+W-5 promotion | same | avoided | avoided | none |
| Sync | yes | yes | **no** — plan stranded off the reading-room device | no | — |
| Per-document toggles | 2 new `Bool?` on `CollectionEntry` | in the entries blob | same shape | in-memory | blob `kind` field |
| Surface tax | **21 files** hold `[Collection]` and must each decide plan visibility; mixed builds show plans as empty collections | none — new type is invisible to every collection surface | none | none | none |
| UI cost | composer "free" but ~1,400 lines of irrelevant machinery to hide | list + picker + editor to build (modest; the real UI is new either way) | same as B | cheapest | deferred |

**A (the owner's suggested adaptation) — reject.** The schema saving is small and the tax is
permanent: 21 non-test files fetch or hold `[Collection]` (pickers, lists, leads, exporters, word
cloud, duplicate cleanup, smart snapshots) and every one — plus every future collection surface —
must remember to filter plan-kind collections. `Collection` has no `kind` field or tolerant-kind
machinery today, so on a mixed-build iCloud account a plan created on build 44 appears on build 43
as an ordinary empty-config collection: openable in the composer, exportable, its plan-ness
silently invisible. The composer's body-depth/TOC/heading machinery is all irrelevant to a plan
and would be hidden by kind-checks scattered through the editor rather than by not mounting it.
What survives from the idea: the **UI grammar** (picker contract, per-entry override pickers,
disabled-not-hidden gates) and a one-way "New Archive Visit from this collection" import.

**B (recommended) — one CloudKit-synced `ArchivalResearchPlan` @Model, WorkingCorpus shape.**
`WorkingCorpus` is the house precedent, and its doc comment argues the shape: a value array of
stable composite keys, **no child @Model, no relationship** (`WorkingCorpus.swift:42-56`).
Entries live in **one Codable `Data` blob** — `[PlanEntry{documentKey, includeSource,
includeExternalRefs, kind}]` — following `SavedSearch.parametersData`, whose promotion rationale
is recorded in the schema inventory itself: one archived value instead of enumerated fields is
"one identifier and not a recurring tax" (`CloudKitSchemaInventory.swift:364-378`). Today's two
Bools, tomorrow's pull-priority or resolved-marker, and E's unit-grain entries all evolve
deploy-free. Honest cost: record-grain last-write-wins — two devices editing different entries of
one plan concurrently lose one device's change wholesale. For a single-author artifact edited in
bursts before a trip, that is the right trade, and it is the trade `WorkingCorpus.replaceMembership`
already makes.

**C (device-local) — reject.** Every research-data type syncs; the only deliberately-local things
are device policy and caches. The plan is the artifact you most need on the *other* device — built
on the Mac against Source Explorer, carried on the iPad into the reading room. And the deploy it
would dodge is already reserved.

**D (ephemeral tray) — reject as persistence, keep as gesture.** The add-to-plan flow in front of
the model is D; the model is B. No UserDefaults/SceneStorage draft beside the model (the #862
stale-sibling class).

**E (unit-grain entries — "pull everything citing lot 64 D 563") — the genuine "other" answer.**
A plan entry that names an archival *unit* rather than a document. Adopted as **blob headroom in
v1** (`kind: .document/.unit` from day one), UI deferred to Phase 4 — it is real, but the
document-grain flow must exist first, and unit-grain seeding is exactly where the uncapped
chapter-3 roster would bind (measured: p99 = 506 documents per unit, max 17,606).

## 4. The recommendation in one paragraph

Ship **B with E's headroom**: one synced `ArchivalResearchPlan` @Model (single record, blob
entries), user-facing noun **"Archive Visit"** (§6.1), boarding the one reserved W-4+W-5
Production promotion (`Plan-Of-Record-2026-08-23.md` §4). The trip packet stops being the object
and becomes the plan's **Share/Export**; `TripPacketSheet` gains a plan-backed initializer, and
per-entry flags project into the two-list builder seam. Collection-only users keep a one-step
flow; plan users get accumulation across surfaces and sessions, with per-document scope control.

## 5. The phased plan

**Phase 0 — Tier A step 1: packet honesty (no schema; ships immediately).**
(a) Project Home seed → the `ProjectLeadsService` union; gate on content, not attachment; smart
collections resolve through `smartRefs`; excerpt entries included. (b) The research-question
editor at sheet level: hold `TripPacketModel` in `@State`, add the inline editable topic-sentence
field that writes `topicSentence.edited` — the missing writer — re-render on commit. This is the
schema-free 80% and serves collection-only users forever. (c) Chapter-3 cap joining the shipped
truncation grammar: 20 rows/group, ~200-row packet budget, ≥500-docs elision printing the
records-line + exact count + finding-aid sentence. (d) Optionally the two ephemeral entry points
(Collection detail, Archival Neighbors) — owner decision §6.7.

**Phase 1 — W-18 + the build seam + the Mac prerequisite (read-only; no schema; no index bump).**
(a) Batched `externalCitations(for: [(volumeId, documentId)])` mirroring `documentSourcesByKey`
(verified absent: `IndexingPipeline.swift:6087` is per-document). (b)
`TripPacketBuilder.build(sourceDocuments:referenceDocuments:…)` — callers pass the same list
twice until plans exist. (c) The W-18 per-repository "also cited by this reading list's
footnotes" section: lot refs through `ArchivalResolver.documentResolution(lotFile:)`, library
refs through `ExternalCitationAuthorityJoin` + `ResearchFacilityResolver`; unresolved refs into
the advance-inquiry draft as their own labeled sub-list; lot + library kinds only (no decimal
classes — 28,721 RG 59 rows would bulk the section into noise); pre-1945 empty states name the
filing-practice reason. (d) **Port Unprinted Material to `MacSourceExplorerView`** (verified
iOS-only: 9 references vs 0) — hard prerequisite for the Mac scope control, nothing else.

**Phase 2 — the @Model (the schema phase; boards the reserved promotion).** ~8 identifiers;
R-7 checklist verbatim; enroll in `ResetService`, `ModelModificationStamper`,
`ResearchDataExporter`; `plan.inquiryText` seeded once from `project.researchQuestion`, the sheet
editor writes through. If plan UI is ready before W-4/W-5 unblock, ship in the
`identifiersAwaitingDeploy` holding state — app-reported, honest, by design.

**Phase 3 — the surfaces.** `PlanPickerSheet` cloning `CollectionPickerSheet`'s contract, with a
`.sheet(item:)` payload carrying documents + preset scope + a seed-provenance basis string.
Source Explorer (iOS): section-local "Add to Archive Visit…" menu with the three add-time
choices, references labeled with their count, absent halves disabled with captions; Mac follows
1(d). Project Home: "Plan a Visit" keeps its key, lands in create-or-open seeded from the leads
union — one-time copy plus explicit "Re-seed from project", never a live mirror (it would
resurrect pruned documents). Archival Neighbors: toolbar menu "Add these N / Add all M sharing
this source" honoring the current `NeighborScope`, per-row context add, source-only preset
(§6.5). Archival Analytics: "Add citing documents to a plan…" beside "Show Archival Neighbors"
in the node/endpoint action clusters — routed **through** Neighbors so the count is disclosed
before anything is added. Collections: `collection.planVisit` becomes create-plan-from-collection
(§6.3). The plan editor: two Default/On/Off override pickers per row (the
`CollectionEntryInspector` grammar), availability captions, a "contributes nothing" warning chip
when both halves are off/absent, row badges ("source ✓ · 3 refs") batch-loaded.

**Phase 4 — unit grain + polish.** Unit-entry UI reusing Phase 0(c)'s elision regime;
collection→plan import affordance; re-measure the per-document ref histogram against the live
index to finalize picker copy.

## 6. Owner decisions (default first)

1. **Naming** — default **"Archive Visit" / "Archive Visits"** (extends the shipped verb family
   "Plan a Visit" / "Plan an Archive Visit…"; "Collection" collides with the archival authority;
   "Research Plan" joins a crowded Research namespace). Alternative: "Archival Research Plan".
2. **Schema timing** — default: build in Phase 2, board the batched W-4+W-5 promotion; ship in
   the holding state if the UI is ready first.
3. **Collections menu** — default: **replace** the ephemeral mount with plan creation (one verb,
   one intent); alternative keeps a secondary "Share packet now" for one-shot users.
4. **References plan-level default** — default: **on where present** (empty states are honest;
   per-entry override available).
5. **Neighbors-seeded entries** — default: preset **source-only** (they were selected for their
   shared source); Collections/Project seeds take plain both-defaults.
6. **Conflict grain** — default: accept record-level last-write-wins (the alternative is a child
   @Model with a recurring R-7 tax).
7. **Ephemeral entry points now vs picker later** — default: **wait for Phase 3's picker** rather
   than shipping a throwaway flow twice; alternative lands them in Phase 0 against the existing
   sheet if the owner wants those surfaces serving packets this build.
8. **Chapter-3 thresholds** — default 20/group, 200/packet, 500-docs elision (matches the shipped
   12/8/20 grammar).
9. **Unit grain in v1** — default: blob headroom only; UI in Phase 4.
10. **Mac scope control** — default: iOS ships first; the Mac control waits on the Unprinted
    Material port rather than honestly offering one of three options.
