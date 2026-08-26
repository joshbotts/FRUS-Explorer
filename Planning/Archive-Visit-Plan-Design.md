# Archive Visits — the archival research plan (design v3, 2026-08-26)

**Status: DECIDED — every §7 decision is answered; ready to execute at Phase 0.** v1 answered the owner's first direction
(seeding surfaces, per-document source/references choice, persistence). **v2 revises it against
the owner's second direction**, which changed two things v1 got wrong and one it under-scoped:

1. The plan's working grain is the **research target** — the archival thing a researcher will
   consult — not the document. The UI must filter targets by repository and group them into
   user-assigned **priority buckets**; when one document seeds several targets (its source plus
   its external references), each target is treated independently. So the model carries
   **per-target** state, not only per-document flags.
2. The packet the app derives is **narrowed and customizable**. The app's job is FRUS, not NARA:
   present FRUS-derived data in the form most useful for research planning and archivist
   consultation, and point to repository-specific guidance — not walk a researcher through a
   visit. Three core deliverables: (a) repository visit-planning links, (b) the
   repository-filtered, priority-grouped target list with consultation metadata, (c) a draft
   inquiry email per repository.

Everything cited was verified against tree `979aa413`. **v2.1** folded in per-target seeding
links + verbatim reference context in (b) — which resolved the W-18 claims question — and
user-defined priority tiers.

**v3 (this revision) records the owner's decisions and fixes three defects the verification pass
found in v2.1 itself.** Decisions: chapters 1/3/7 **dropped**; name **"Archive Visit"**; schema
timing **coupled to the W-4+W-5 promotion** (no holding-state ship); orphaned targets **report
coverage**; **child `@Model` per target** (the owner made this conditional on it genuinely
protecting multi-device data — §2a answers that on the merits, and it does); **full CRUD** for
plans. Defects fixed: the target key contained `claim`, contradicting v2.1's own "one unit row"
promise (§2); `tripPacketGroupKey` is **not unit-grain** for the commonest citation form (§2b —
the most consequential correction here); and "fold substitutes into a per-target marker" is not
supported by the data (§3).

## 1. What exists today (unchanged from v1)

The trip packet is ephemeral — `TripPacketSheet(documents:title:researchQuestion:)` builds
`[(volumeId, documentId)]` at presentation time, persists nothing (`TripPacketSheet.swift:37-44`);
four collection-shaped entry points; it reads only `document_sources` (W-18 covers the footnote
references). The accepted Tier A step-1 fixes stand: the Project Home seed/gate defects, smart
collections, excerpts, the never-written `TripPacketTopicSentence.edited`
(`TripPacketModel.swift:32`), and the uncapped chapter-3 roster.

## 2. The model, revised: documents seed, targets are the working grain

**A target is an archival unit under one claim.** Its identity is citation-derived and stable —
never a NAID, never anything an artifact refresh or reindex re-mints:

- a **drawn-from** target keys on the packet's existing group key,
  `tripPacketGroupKey(for: SourceRecord)` — structured repository/recordGroup/lotFile/seriesName
  when present, else the raw note text (`CollectionGeneratedBlocks.swift:495-510`). This is
  deliberately the same key the packet and the Sources blocks already share, so a plan target IS
  a packet group.
- a **pointed-at** target keys on the analogous fields of its `external_citations` rows —
  `lot_file_norm`, else `repository|collection` (`IndexingPipeline.swift:5544-5559`), under the
  same normalization the W-18 pipeline applies.

Resolution (NAID, facility, HMS/MLR, restriction status) stays **render-time**, through the same
`ArchivalResolver` / `ExternalCitationAuthorityJoin` routes — so improving artifacts improve a
plan's display without touching stored state. A target whose key no longer materializes after a
reindex keeps its stored state silently (bytes are tiny); a "no longer cited by this plan's
documents" row is disclosed, not deleted.

**The blob (one synced `ArchivalResearchPlan` @Model, WorkingCorpus shape — unchanged from v1)
now carries two levels:**

```
ArchiveVisitPlan   { id, name, inquiryText?, projectIds, tiersData: Data,
                     deliverableToggles, createdAt, lastModified }     // ~11 identifiers
PlanDocument       { id (derived), plan, documentKey,
                     includeSource: Bool, includeExternalRefs: Bool,
                     stateData: Data?, lastModified }                  // ~12
PlanTarget         { id (derived), plan, targetKey,
                     tierId: UUID?, included: Bool, userNote: String?,
                     stateData: Data?, lastModified }                  // ~12
```

### 2a. Why a child `@Model` per target, on the merits

The owner made this conditional on genuine multi-device protection. It is, and the reason is
mechanical rather than a preference: SwiftData mirrors **one `@Model` to one CKRecord and one
stored property to one CKRecord field** (`CloudKitSchemaInventory.swift:44`). So:

| two devices… | one blob | child `@Model` per target |
|---|---|---|
| edit **different** targets | both rewrite the one field — the loser loses **its whole session** (every tier, note, and newly minted target), silently | different records: **nothing conflicts, both survive** |
| edit the **same** target | one winner | one winner, but the loss is bounded to that target |
| one adds seeds while the other tiers | whichever writes second wins the blob | inserts vs a different record: **both survive** |

The blob's failure is not "one entry lost" — it is a whole-array clobber that still renders as a
coherent, partly stale document. The child model's residual cost is duplicate rows, which are
visible and repairable, where a silent revert is neither. **Cost: ~35 identifiers across three
record types, one deploy** — the reserved W-4+W-5 promotion, per the owner's timing decision.

Three consequences follow, all of which the design adopts:

- **Targets are a STATE OVERLAY, not a materialized list.** A `PlanTarget` row is minted only when
  the user gives that target state (a tier, a note, an exclusion). An untouched target is a pure
  render-time derivation from the plan's seeds. Record count is bounded by what the user touched;
  duplicates become near-impossible (two devices deriving the same list independently create zero
  records); and the rendered list is `derived(seeds) ∪ stored-state rows`, which **is** the
  coverage-reporting doctrine the owner chose for orphans.
- **Child ids are DERIVED, not random** — a namespace hash over `planId | key` — because SwiftData
  under CloudKit cannot declare `@Attribute(.unique)`, and `DuplicateRecordCleanup` groups by `id`.
  Two devices seeding from the same document mint the same row *deterministically*, which is
  exactly the case a random id hides from that pass. Enrol both types in `dedupeSimple`.
- **No `didSet` on any new model** (the array-observer trap `WorkingCorpus` documents); stamp
  through `ModelModificationStamper`. Relationships take `.nullify` inverses like
  `Collection`/`CollectionEntry`, with an explicit cascading delete helper (§5a).

**This also moots the CloudKit record-size question** — one record per touched target, rather than
one blob that crosses the 1 MB CKRecord limit at roughly 4,600 seeded documents. The ceiling
discussion disappears rather than needing an answer.

### 2b. The target key — and the correction that matters most

Two fixes to v2.1:

**(i) The key does not contain `claim`.** v2.1 keyed on `{claim, identity}`, which would mint two
rows for a unit cited both ways — contradicting its own §3 promise of "one unit row, claims
itemized inside it." Claim belongs to the **seeding**, not the target.

**(ii) `tripPacketGroupKey` is not unit-grain, and using it would have wrecked the feature.** For a
decimal citation the parser puts the **file identifier** into `seriesName`
(`IndexingPipeline.swift:6238`), so the packet's group key yields one group per file number —
measured, ~25 groups from 30 pre-1950 documents, i.e. nearly one per document. Since central
decimal files are the commonest form in the corpus, target-grain prioritization would have
degenerated to per-document rows for most plans. The archival unit a researcher actually consults
is the decimal **class**, and the app already stores it: `document_sources.decimal_class`, indexed,
canonical (`IndexingPipeline.swift:6198`), with #828's labels making it read in words.

So the target key is **form-aware**:

| citation form | target key | the per-seeding detail |
|---|---|---|
| central decimal | `decimal_class` (e.g. `611.51`) | the full file number |
| lot file | `lot_file_norm` | folder/box designation |
| library / named collection | `repository \| collection` | box/folder |
| unrecognized | the raw note text | — |

This also resolves the dropped chapter 3 cleanly: the isolated **file designation** the pull
worksheet uniquely carried now lives on the seeding row under a class-grain target — which is
where a pull slip needs it anyway.

The rejection of plan-as-Collection (21-file surface tax, mixed-build masquerade), of
device-local storage, and of the ephemeral tray all stand as v1 argued. `stateData` on both
children is the reserved evolution column (the `SavedSearch.parametersData` pattern), so future
per-target properties cost no further deploy.

## 3. The deliverables, narrowed

The seven-chapter packet inverts: the three core deliverables lead, everything else becomes
per-target metadata or an opt-in appendix.

**(a) Repository visit-planning links.** Already built: `RepositoryFactTable`'s per-facility
visit + finding-aids link pairs (D16, link-checked per release). Rendered once per repository
represented in the filtered plan. This — not prose — is how the app "points users toward
repository-specific guidance."

**(b) The target list.** Filtered by repository (UI filter; the export groups by repository),
grouped by the user's priority tiers, one row per included target carrying the consultation
metadata: the records line (RG · entry number · series title · NAID · years), HMS/MLR where
resolved, and two markers folded down from v1's chapters: **restriction status**
(RestrictionTriage's data as a per-target flag, not a chapter) and **digitized/filmed
substitute** (MandatorySubstitutes' data likewise).

**Each target itemizes its seeding, by claim.** For every FRUS document that seeded the target: a
**link to the document** (in-app, the row navigates; in the text/PDF export, the short citation
plus its history.state.gov URL — the same link grammar the composer already resolves in reverse)
and the **reference context** that document provides — for a drawn-from seeding, the source note
as printed ("Source: Department of State, Conference Files: Lot 60 D 627, CF 1"); for a
pointed-at seeding, the footnote citation verbatim with its footnote anchor, and `inherited`
(`Ibid.`) rows saying so ("cited as 'Ibid., CF 1' — inherited from the preceding footnote's
citation"). Verbatim context is the packet's existing discipline (A5 quotes unresolved citations
verbatim; #784's safety verdict rested on reading samples). Per-seeding context lists elide past
a threshold with exact counts, per the shipped truncation grammar. A target that resolves to
nothing renders its raw citation verbatim and routes to (c) — the A5 help-me-locate rule,
unchanged.

**(c) The inquiry email, per repository.** Chapter 2's machinery, now central: the editable topic
sentence (Phase 0's editor — the missing `edited` writer), the repository's targets summarized
with their priorities, unresolved citations quoted verbatim as help-me-locate items, and the
consultation framing ("seeking further advice") the owner named. One draft per repository in the
filtered set — **and each draft carries its own Copy affordance**, because a draft's entire
purpose is to be pasted into an email to that one archivist; a draft reachable only inside a
grouped document must be carved out by hand every time.

**Export scoping (owner question, 2026-08-26).** The share surface carries a **repository scope**:
**All repositories** (default — one artifact, per-repository sections, the researcher's own master
reference) or **any single repository** — a self-contained artifact holding that facility's (a)
links, its (b) targets, its (c) draft, and the coverage report, which is plan-level and travels
with **every** export regardless of scope (the honesty block is not divisible). The exporter
already builds per-repository sections, so a scoped export is a render filter, not a second
pipeline. No one divides an export by hand.

### 3a. The seven chapters, decided (owner, 2026-08-26)

**Dropped outright: ch1 (Before you go), ch3 (Pull worksheet), ch7 (On the day).** ch1 and ch7 are
wholly NARA-procedural — and ch7 unconditionally printed College Park's rules even for a
library-only plan. ch3's only unique payload, the isolated file designation, moves to (b)'s
seeding rows (§2b); its blank Box column was an affordance, not data, and the packet never
fabricated a box number.

**ch4 — substitutes: fold to the SEEDING row, not the target.** v2.1 said per-target; the shipped
code refuses that correspondence in as many words ("a substitute is range-grain and a worksheet
row is group-grain, so naming the affected rows here would assert a correspondence the data does
not support", `TripPacketExporter.swift:242-248`) because `MandatorySubstitutes.Row` keys on the
**digitized unit's** NAID and carries no target key. The document-grain fold *is* exact — the
lookup is already built one `CitedFile` per placed document — but it is **blocked today**:
`CitedFile` carries `identifier` and `year` and no document key, so Phase 1 must add one and have
`build` return a per-document match. Four facts have no row to sit on and must ride in the
plan-level coverage report (§3c) or be lost: the `coverageNote` denominators (documents tested /
with a substitute), `partiallyDigitizedCount` ("the class is digitized but not this serial" — by
design never a row), the `isSoleClaimant` layered-digitization warning, and the chapter's closing
microfilm-publication rule. **Substitutes are tested on drawn-from seedings only** — a footnote
reference is a pointer, not a thing you were going to pull. **An empty result must never render as
absence**: the coverage line prints unconditionally, because the type's own doc warns that an
empty chapter with no caveat "would read as a clearance to pull everything."

**ch5 — restrictions: fold to a per-target marker, plus a plan-level line — but the join is not
1:1 and the design says so.** `RestrictionTriage` keys on **series** NAID; a target keys on a lot,
class or collection. The shipped lot-claimants artifact carries 123 divided lots, one claimed by
up to 13 series, so "is this target restricted?" can have several different answers. Rejected:
*show the most severe* (invents certainty), *unanimity-or-silence* (goes silent on most divided
lots), and *single-pick* (today's behavior — prints one claimant's status as if it were the lot's).
Adopted: **one line, not a badge** — the worst *covered* status, the series it belongs to, and how
many claimants are unmeasured — and the divided lot routes into (c) **as a question for the
archivist**, which is what a divided lot actually is.

**ch6 — citation crib: opt-in appendix, default OFF.** At most three sections drawn from four
verbatim NARA forms, selected by designation form; zero overlap with (b), so it cannot fold. Do
**not** render a per-target citation form (it would repeat one form under 14–25 targets). One
exception worth folding: on central-file targets only, NARA's no-box rule as a single line. *A
live defect to fix while porting*: the Example-8 gate is `category == .lotFile` where it should be
"any target that is not a central-file target."

### 3b. What "customizable" means

Deliverable toggles — (a)/(b)/(c) and the ch6 appendix — are plan-level, stored in
`ArchiveVisitPlan`. Defaults: (a), (b), (c) on; ch6 off.

### 3c. The coverage report — one honest home for the homeless facts

The owner's orphaned-target decision (report coverage, the `WorkingCorpus` pattern) creates the
place these facts belong. One block, stated in true denominators: targets derived vs. stored-state
rows that no longer derive; documents indexed on this device vs. seeded; substitutes tested vs.
found, with the partial-digitization count; restriction claimants measured vs. unmeasured. **The
cause of a non-deriving target is usually a device with fewer indexed volumes, not a data defect**
— and citation-derived identity means an authority re-clustering never moves a key.

### 3d. The claims question W-18 forces — resolved by (b)'s reference context (§7.4)

 W-18 mandated
a *separate* per-repository section for pointed-at references, "never folded into chapter 3's
pull rosters" — written when the roster was the artifact and a folded row would have carried a
bare, unattributed count. In (b), every seeding is itemized **with its claim and its verbatim
context**, so the reader sees exactly which kind of assertion each citing document makes — a
stronger form of the #783 separation than a section split, applied at the evidence grain rather
than the layout grain. Two rules keep it honest, and both are testable: **counts never sum across
claims** (a target cited both ways shows "drawn from 3 · pointed at by 2", never "5"), and the
two claim groups are **visibly distinct within the row** (labeled, contexts itemized under their
own claim). This also settles the both-ways target: one unit row, claims itemized inside it —
which is what an archivist consultation wants. The pipeline keeps its separate methods
regardless; the plan editor's filter can still show either claim alone.

## 4. The UI, revised

**The plan editor is a target list, not a document list.** Primary view: targets grouped by
repository (section headers = repositories, with the (a) links in the header), each row showing
identity, claim, priority control, citing-document count, and the availability-honesty captions
from v1 (a claim with nothing behind it never renders a dead control). A secondary "Documents"
tab lists the seeds with their per-document contribution flags (v1's two pickers) — this is where
"this document's references: off" lives. **Priority tiers**: the §2 user-defined list — add,
rename (label optional), reorder, delete; targets assign by swipe/context menu or the row's tier
control; the implicit Unprioritized group holds everything else.

**Add flows are unchanged from v1** (PlanPickerSheet cloning CollectionPickerSheet; Source
Explorer's section-local add with the three-way choice and the references count; Project Home
create-or-open from the leads union; Neighbors' N-shown/M-cohort menu with source-only preset;
Analytics routed through Neighbors for count disclosure; Collections' one verb) — they set the
per-document flags; targets mint from them.

**Sparsity honesty (unchanged):** references exist on ≲6% of documents; counts shown at add time,
captions for absent halves, never a dead toggle. **Mac prerequisite (unchanged):** Unprinted
Material is iOS-only (9 refs vs 0 in `MacSourceExplorerView`); the Mac scope control waits on the
port.

### 4a. Plan management — full CRUD (owner requirement)

**Where the list lives.** iOS: the **Research tab**, as a pinned entry beside Project Home — the
tab bar is full and this is research-workspace furniture, not a corpus axis. macOS: one singleton
`Window("Archive Visits", id: "frus.archiveVisits")` reached from the existing My Research menu,
matching how the other research surfaces get windows.

**Create** — no naming dialog. Seeded creation auto-names from its seed (the collection's name,
the project's name, the archival unit's label); an empty plan is "Untitled Archive Visit,"
renameable in place. **Read** — row shows name, then `N targets · M repositories · lastModified`;
empty state explains what a plan is and how to seed one. **Update** — rename via context menu
(alert with a text field) and inline in the editor header, both shipped grammars. **Duplicate** —
offered in the context menu: a plan is a working hypothesis, and forking one before re-scoping is
the natural move; duplication copies seeds, tiers and per-target state under fresh derived ids.
**Delete** — swipe action plus destructive context item, with a confirmation dialog naming what
goes, and an explicit cascading delete of the children (`.nullify` inverses do not cascade by
themselves — §2a).

**Settings registration is mandatory and test-pinned**: the three new types must join
`ResetInventory.erased` (a suite asserts erased + retained == `frusModelTypes` exactly), the
research-data item counts a user checks before erasing, and `ModelModificationStamper`.

## 5. The build seam, revised

v1's two-list seam (`sourceDocuments` / `referenceDocuments`) survives as the pipeline boundary,
but the exporter reorganizes around targets: build both channels through their separate methods
(#783), mint target rows keyed as §2, join per-target state, filter to included, group by
repository → priority, render (a)/(b)/(c) + enabled appendices. Chapter-3's cap question becomes
(b)'s citing-citations display rule — per-target citation lists elide past a threshold with exact
counts (the shipped 12/8/20 truncation grammar), which also answers unit-grain seeding's tail
(p99 = 506, max 17,606) without a separate regime.

## 6. Phasing, revised

- ~~**Phase 0.**~~ **SHIPPED 2026-08-26** — the Tier A step-1 fixes: the Project Home seed is
  `gatherSeed`'s union by construction with a content gate; the three collection surfaces hand
  the sheet the collection and `TripPacketSeed` resolves membership in one place (smart → the
  export's own `smartRefs`; static → documents + excerpts, deduplicated); the topic-sentence
  editor writes the never-written `edited`; chapter 3 joined the truncation grammar
  (20/group · 200/packet · ≥500 elision, all disclosed); the empty states name their actual
  causes. No schema.
- ~~**Phase 1 — the pipeline + the narrowed exporter.**~~ **SHIPPED 2026-08-26** — batched
  `IndexingPipeline.externalCitationsByKey`; the two-channel builder behind a
  `TripPacketReferenceDataSource` refinement; **target minting** under the §2b form-aware keys
  (`TripPacketBuilder.targetKey` / `referenceKey`; the Sources block keeps its own key, the
  divergence documented at both seams) with the §3a folds — per-seeding substitute markers via
  `MandatorySubstitutes.matchesByDocument` + `CitedFile.documentKey`, the claimant-aware
  per-target access line, the central-file no-box line, the fixed Example-8 gate; the narrowed
  (a)/(b)/(c) exporter with the whole-plan coverage report, the repository scope and the
  per-draft Copy on the sheet, the crib as an opt-in appendix (ephemeral packets default it
  off per §3b); the Mac Unprinted Material port (reusing the iOS view's own pointer type and
  join). W-18 delivered in this shape and struck in the plan of record. Chapters 1/3/7 deleted
  (`TripChecklist`/`AdvanceNoticeFlags` removed with their tests). No schema.
- ~~**Phase 2 — the @Model.**~~ **SHIPPED 2026-08-26** — the three record types of §2/§2a
  exactly (`ArchiveVisitPlan` + `ArchiveVisitDocument` + `ArchiveVisitTarget`, 32 CloudKit
  identifiers; the parenthetical this bullet used to carry — "~8 identifiers, blob" — was v1's
  shape, superseded by the owner's child-model decision). Derived child ids
  (`derivedChildId(planId:key:)`, pinned by fixture), tiers and deliverable toggles as
  tolerant-decoding blobs, `"%@ copy"` duplication under the feature's own key with tier ids
  preserved and child ids re-derived, explicit cascade delete. Registered everywhere the
  design mandates: `frusModelTypes` (R-7 gate followed; the 32 identifiers hold in
  `identifiersAwaitingDeploy` for the W-4+W-5 promotion — the honest holding state),
  `ResetInventory.erased` (children → plan → Project order), `ModelModificationStamper`,
  `DuplicateRecordCleanup` (children via `dedupeSimple` on derived ids; the plan re-parents
  like Collections), the Data & Recovery Contents inventory + erase warning (new keys), and
  `ResearchDataExporter` format 6 (plan whole — seeds, tiers, toggles, every stored target
  state including orphans; never the derived packet). No UI surfaces yet — Phase 3.
- **Phase 3 — the surfaces + the plan editor** (revised: the target-grain editor of §4, plus the
  add flows).
- **Phase 4 — unit-grain entry UI + the live-index sparsity re-measure.**

## 7. Decisions — resolved and remaining

**Resolved by the owner, 2026-08-26:** naming ("Archive Visit"); chapters 1/3/7 dropped, 4/5 folded
per §3a, 6 an opt-in appendix defaulting off; schema timing coupled to the W-4+W-5 promotion;
conflict grain = child `@Model` per target (§2a answers the owner's condition: yes, on the
merits); orphaned targets = report coverage (§3c); priority tiers user-defined, any number
(§2); claims presentation = one claim-labeled list (§3d); full CRUD (§4a).

**Resolved by the verification pass, recorded here rather than re-asked:**
- **CloudKit record size** — moot under child models (§2a); the ceiling discussion is deleted
  rather than answered.
- **Collections menu (§7.3)** — *keep* "Plan an Archive Visit…" as the ephemeral verb through
  Phases 1–2, then replace it in Phase 3. Coupling the schema to W-4+W-5 means the ephemeral
  packet is the only packet for a while; removing its verb first would leave a gap.
- **Neighbors entry point (§7.7)** — land it in **Phase 1**, for the same reason, as one honest
  option over the documents shown rather than an N-shown/M-cohort menu. It must live in the shared
  content core, not the sheet, or it is missing from the macOS and Stage-Manager windows.
- **Mac timing (§7.10)** — the Unprinted Material port lands in **Phase 1**: the Mac view already
  holds every dependency, so deferring it buys nothing and costs the Mac its scope control.
- **Tier placeholders (§7.2 sliver)** — start empty. (The duplicate-prompts scar is *not* the
  supporting argument — that was a two-platform seeding-duplication bug, a different failure. The
  argument is simply that per-object state starts empty here, as focus tags do.)
- **`ResearchDataExporter`** — bump `currentFormatVersion` to 6 and carry the plan header, its
  seeds, its tier definitions and every stored target state **including orphans**; never the
  derived packet, which is a rendering and not the user's work.

**Resolved by the owner, 2026-08-26 (closing the set — no decisions remain open):**
- **Duplicate naming** — a duplicated plan takes the `"%@ copy"` suffix and keeps it until the user
  renames it. This is the shipped grammar exactly: `Collection.duplicate(in:)` formats
  `collection.duplicate.name %@` as `"%@ copy"` over a base that falls back to the untitled name
  (`Collection.swift:800-807`). Archive Visits reuse the pattern with their own key
  (`archiveVisit.duplicate.name %@`) — a **new** key rather than the collection's, since reusing
  another view's localization key is a silent i18n collision.
- **Citation-crib toggle** — **per-plan**, alongside the (a)/(b)/(c) deliverable toggles in
  `ArchiveVisitPlan` (§3b), not a global preference. It travels with the plan, so a plan shared or
  re-opened on another device renders the same artifact, and a researcher who wants the crib for a
  lot-file trip but not a library one does not have to remember to flip a global setting.

## 7a. The UI design handoff — DELIVERED and checked in

The brief (`Archive-Visit-Design-Handoff/README.md`) was answered by the owner-supplied design on
2026-08-26, now checked in byte-identical beside it: `Archive-Visits.dc.html` + nine artboards
(1a–1i) + `PROVENANCE.md`. **The `.dc.html` is the copy authority, not the PNGs** (1b is captured
with its info popover open). Implementation of Phase 3 works from these artboards; the artboard →
phase mapping is: 1e (Neighbors add control) and the 1g inquiry editor's underlying seam land in
**Phase 1**; 1i's Settings registration is **Phase 2**; 1a/1b/1c/1d/1f and the rest of 1e/1g/1h
are **Phase 3**.

## 7b. Check-in assessment (2026-08-26)

**Verdict: conforms to this design.** Verified against the tree and the decided rules, not by
reading alone: no summed claim counts anywhere in the copy; coverage lines use the both-numbers
grammar ("38 of 51 seeding documents ○ indexed on this device — targets from the other 13 may be
missing"); the absent-half captions render as captions, never dead toggles; the orphan row is
kept and labeled ("Kept with your tier and notes; it never deletes itself"); restriction is a
line with worst-covered status + the unmeasured claimant count, routed into the inquiry; the
tier-delete confirmation is drawn; "%@ copy", "Untitled Archive Visit", and the topic-sentence
placeholder match the shipped strings; and the two ●-marked institutional facts in 1g were
checked against `RepositoryFactTable` — `Archives2reference@nara.gov` and the research-visit-faqs
URL are both real `VerifiedFact`s.

**Three annotation-level flags, none blocking:**
1. **1b's filter chip is a mock-state artifact** — "Claim: Drawn from ✕" is drawn active while
   pointed-at rows still show. Do not infer filter semantics from the capture; the filter's
   behavior is this document's (§4).
2. **The plan-delete confirmation is specified in the 1a annotation ("confirmation names what
   goes") but not drawn.** Reuse the drawn tier-delete dialog's grammar (1c: "Delete "If time
   allows"?" / destructive "Delete Tier").
3. **1g renders the inquiry email lowercase** where the fact table stores
   `Archives2reference@nara.gov` — moot in implementation, which reads the table.
4. **1g draws the unscoped artifact only** (two share buttons over the whole plan). The
   repository-scope menu on the share surface and the per-draft Copy affordance (§3c, added on
   the owner's export-scoping question) are **additive to 1g at implementation** — the delivered
   `.dc.html` stays as delivered; this plan governs.

## 8. What v3 does not change

The persistence verdicts against plan-as-Collection, device-local storage and the ephemeral tray;
the seeding-surface designs; the sparsity constraint (references on ≲6% of documents — counts at
add time, captions for absent halves, never a dead toggle); W-1b independence (affinity, not a
gate); and Phase 0's content. W-18's plan-of-record row needs a disposition note on approval — its
delivery is Phase 1 in this shape.
