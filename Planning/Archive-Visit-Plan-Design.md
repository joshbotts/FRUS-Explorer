# Archive Visits — the archival research plan (design v2, 2026-08-26)

**Status: OPEN DESIGN — owner decisions pending (§7).** v1 answered the owner's first direction
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

Everything cited was verified against tree `979aa413`.

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
PlanDocument { documentKey, includeSource: Bool, includeExternalRefs: Bool }
PlanTarget   { targetKey: {claim: drawnFrom|pointedAt, identity}, 
               priority: Int (bucket), included: Bool, userNote: String? }
```

Per-document flags control **what a document contributes** (the v1 three-way choice, unchanged at
add time); per-target state controls **how each resulting target is treated** — include, priority
bucket, a private note. Membership (which documents feed which target, and the counts) is derived
at render time from the included documents; per-target state persists across membership changes
because it keys on the stable identity. This two-level shape is exactly the owner's "not only
per-document override affordances, but also per-target ones," and the blob absorbs it with no
schema change beyond v1's single model — the reason the blob was the right call.

Record-grain last-write-wins, sync, R-7 mechanics, and the rejection of plan-as-Collection
(21-file surface tax, mixed-build masquerade), device-local storage, and the ephemeral tray all
stand as v1 argued.

## 3. The deliverables, narrowed

The seven-chapter packet inverts: the three core deliverables lead, everything else becomes
per-target metadata or an opt-in appendix.

**(a) Repository visit-planning links.** Already built: `RepositoryFactTable`'s per-facility
visit + finding-aids link pairs (D16, link-checked per release). Rendered once per repository
represented in the filtered plan. This — not prose — is how the app "points users toward
repository-specific guidance."

**(b) The target list.** Filtered by repository (UI filter; the export groups by repository),
grouped by the user's priority buckets, one row per included target carrying the consultation
metadata: the records line (RG · entry number · series title · NAID · years), HMS/MLR where
resolved, the **claim** ("drawn from N documents in this plan" / "pointed at by the footnotes of
N documents"), the citing FRUS citations (compactly), and two markers folded down from v1's
chapters: **restriction status** (RestrictionTriage's data as a per-target flag, not a chapter)
and **digitized/filmed substitute** (MandatorySubstitutes' data likewise). A target that resolves
to nothing renders its raw citation verbatim and routes to (c) — the A5 help-me-locate rule,
unchanged.

**(c) The inquiry email, per repository.** Chapter 2's machinery, now central: the editable topic
sentence (Phase 0's editor — the missing `edited` writer), the repository's targets summarized
with their priorities, unresolved citations quoted verbatim as help-me-locate items, and the
consultation framing ("seeking further advice") the owner named. One draft per repository in the
filtered set.

**Demoted to opt-in appendices (default off) or dropped — owner decision §7.5:** the pre-arrival
checklist with lead times (ch1), the reading-room pull worksheet as a distinct artifact (ch3 —
largely subsumed by (b)), substitutes and triage as chapters (ch4/ch5 — folded into (b)'s
markers), NARA's citation forms (ch6), the visit-day card (ch7). "Customizable" = deliverable and
appendix toggles on the plan, blob-stored.

**The claims question W-18 forces (§7.4).** W-18 mandated a *separate* per-repository section for
pointed-at references, "never folded into chapter 3's pull rosters" — written when the roster was
the artifact. Deliverable (b) is a different artifact: one repository-grouped list whose every row
**names its claim**. The #783 principle — the two claims never blur — is preserved at the row
grain, and the pipeline keeps its separate methods regardless. Default: one list, claim-labeled
rows, with the plan-editor filter able to show either claim alone. Alternative (strict W-18
reading): two sub-lists per repository.

## 4. The UI, revised

**The plan editor is a target list, not a document list.** Primary view: targets grouped by
repository (section headers = repositories, with the (a) links in the header), each row showing
identity, claim, priority control, citing-document count, and the availability-honesty captions
from v1 (a claim with nothing behind it never renders a dead control). A secondary "Documents"
tab lists the seeds with their per-document contribution flags (v1's two pickers) — this is where
"this document's references: off" lives. **Priority buckets**: default three, "Must see / If time
allows / Background" (§7.2), stored as Int so the vocabulary can grow blob-side.

**Add flows are unchanged from v1** (PlanPickerSheet cloning CollectionPickerSheet; Source
Explorer's section-local add with the three-way choice and the references count; Project Home
create-or-open from the leads union; Neighbors' N-shown/M-cohort menu with source-only preset;
Analytics routed through Neighbors for count disclosure; Collections' one verb) — they set the
per-document flags; targets mint from them.

**Sparsity honesty (unchanged):** references exist on ≲6% of documents; counts shown at add time,
captions for absent halves, never a dead toggle. **Mac prerequisite (unchanged):** Unprinted
Material is iOS-only (9 refs vs 0 in `MacSourceExplorerView`); the Mac scope control waits on the
port.

## 5. The build seam, revised

v1's two-list seam (`sourceDocuments` / `referenceDocuments`) survives as the pipeline boundary,
but the exporter reorganizes around targets: build both channels through their separate methods
(#783), mint target rows keyed as §2, join per-target state, filter to included, group by
repository → priority, render (a)/(b)/(c) + enabled appendices. Chapter-3's cap question becomes
(b)'s citing-citations display rule — per-target citation lists elide past a threshold with exact
counts (the shipped 12/8/20 truncation grammar), which also answers unit-grain seeding's tail
(p99 = 506, max 17,606) without a separate regime.

## 6. Phasing, revised

- **Phase 0 — unchanged.** The Tier A step-1 fixes (seed/gate/smart/excerpts, the topic-sentence
  editor, a minimal chapter-3 cap on the *existing* exporter so ephemeral packets stop being
  unbounded meanwhile). No schema. Ships now.
- **Phase 1 — the pipeline + the narrowed exporter.** Batched `externalCitations(for:)` (today
  per-document only, `IndexingPipeline.swift:6087`); the two-channel builder; **target minting**
  (keys as §2) with restriction/substitute markers folded in; the narrowed (a)/(b)/(c) exporter
  with appendix toggles defaulted per §7.5 — this *is* W-18's delivery, in the revised shape; the
  Mac Unprinted Material port. Ephemeral (collection-seeded) packets get the narrowed artifact
  with all-targets-included defaults — no plan object needed yet.
- **Phase 2 — the @Model** (unchanged: ~8 identifiers, blob per §2, boards the reserved W-4+W-5
  promotion, honest holding state).
- **Phase 3 — the surfaces + the plan editor** (revised: the target-grain editor of §4, plus the
  add flows).
- **Phase 4 — unit-grain entry UI + the live-index sparsity re-measure.**

## 7. Owner decisions (v2; defaults first — v1 decisions not listed here carried unchanged)

1. **Naming** — "Archive Visit" / "Archive Visits" (unchanged from v1).
2. **Priority vocabulary** — default three fixed buckets, "Must see / If time allows /
   Background"; alternative: user-defined labels (more UI, blob-free either way).
3. **Target grain** — default: unit-grain targets + per-document contribution flags (§2). The
   finer (document × unit) exclusion grain is deliberately NOT offered — excluding a document's
   contribution is done on the document row.
4. **Claims presentation** — default: one repository-grouped list with claim-labeled rows
   (supersedes W-18's separate-section wording for the new artifact; pipeline separation intact);
   alternative: two sub-lists per repository.
5. **Appendix disposition** — which of ch1/ch3/ch4-as-chapter/ch5-as-chapter/ch6/ch7 survive as
   opt-in appendices vs are dropped outright. Default: checklist (ch1) and citation forms (ch6)
   as opt-in appendices; pull worksheet, substitutes chapter, triage chapter, visit-day card
   dropped (their load-bearing data lives in (b)'s rows).
6. **Orphaned target state** — default: retain silently, disclose "no longer cited by this plan's
   documents" rows rather than deleting them.
7. **Ephemeral entry points now vs Phase 3 picker** — unchanged from v1 (default: wait).
8. **Schema timing / conflict grain / unit grain in v1 / Mac timing** — unchanged from v1
   (batched promotion; record-level LWW; blob headroom only; iOS first).

## 8. What v2 explicitly does not change

The persistence verdicts (§3 of v1, absorbed above), the seeding-surface designs, the sparsity
and Mac-port constraints, the W-1b independence (affinity, not a gate), and Phase 0's content.
W-18's plan-of-record row will need a disposition note once this design is approved — its
delivery becomes Phase 1 in the revised shape.
