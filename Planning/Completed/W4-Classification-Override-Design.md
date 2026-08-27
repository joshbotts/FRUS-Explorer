# W-4 / #279 — Per-Document Classification Override (O-4 design record)

**Status: SHIPPED 2026-08-26** (with W-5, one PR, one CloudKit deploy block). This is the
one-page design the plan of record's O-4 row asked for, written as a record of what shipped
and why — including the one owner decision that went against the recommendation.

## What an override is

FRUS TEI mistags some documents: `subtype="editorial-note"` present where the content is a
primary document, or absent where it is an editorial note. The app's flag
(`document_cache.is_editorial_note`) is a faithful read of that attribute, so a mistag reaches
every badge, filter, facet, count, and export. An override is the researcher's **reversible**
assertion of the correct classification for one document:
`DocumentClassificationOverride` — a CloudKit-synced `@Model` on the `PersonClusterOverride`
precedent (stable `(volumeId, documentId)` string anchor, all defaults, no relationships,
silent no-op when the volume is unindexed, reactivating when it indexes).

## The owner's decisions (recorded verbatim in effect)

1. **Scope: "Also restyle the body"** — against the metadata-only recommendation. The
   override changes the rendered document body, not just chrome: `FRUSDocumentAST.
   applyingClassificationOverride(isEditorialNote:)` rewraps/unwraps the `.editorialNote`
   container (idempotent; metadata preserved), applied in `DocumentViewModel.load` from the
   effective flag, on both platforms. The rail control reloads the host VM so the open
   document restyles immediately.
2. The reclassify control lives in the **Research rail** (a Classification block), with a
   `confirmationDialog` carrying the anomaly warning: body styling, badges, filters, counts
   and exports follow the override on all devices; **bundled series-analytics dashboards are
   computed from the published corpus and structurally cannot see it**; other windows reflect
   it on reopen.
3. **Undo** is everywhere the override is visible: "Restore FRUS's Classification" in the
   rail, and a corrections manager (Settings ▸ Search ▸ Classification Corrections…) on the
   `PersonCorrectionsSheet` pattern — value-snapshot rows, undo re-fetches by id, a miss
   reads as already-undone elsewhere.

## Replay, not clobber — the architecture in one paragraph

The ONE seam nearly every consumer reads live is `document_cache.is_editorial_note` (search
type filter, facets, browse, chronology, related, cross-references, Zotero export).
`IndexingPipeline.applyClassificationOverrides` writes the override into that column
(value-guarded; the column is unindexed in FTS5, so no trigger fires) — one pass honors an
override everywhere with **no per-consumer change**. The index upsert deliberately keeps
restoring the parsed TEI value on re-index, because an upstream TEI fix must keep propagating
for every non-overridden document; overrides are therefore **replayed** — at boot (after the
summary/note replay) and per-volume after `indexVolume`, from a set cached on the actor —
exactly the way summaries and notes are. `parsedIsEditorialNote` stores what the TEI said at
override time so un-overriding restores it without a re-parse; the next re-index corrects any
drift. Same-anchor conflicts from two devices resolve by apply order: `snapshot()` is oldest
first, so the newest assertion wins the last write.

**No index-version bump**: the override is applied *after* parsing, to an existing index —
parse output is unchanged, so the W-1b batching clause in the plan-of-record row turned out
to be moot.

## Known traps, each handled

- `ProjectLeadEntry.isEditorialNote` is a second synced snapshot (dismissed leads never
  refresh): `ProjectHomeView` consults a live `@Query` of overrides before trusting it.
- `DocumentBrowserEntry.isEditorialNote` defaults `false` at ~13 construction sites: the
  document views now resolve the badge through `pipeline.effectiveIsEditorialNote`, which
  also repairs that pre-existing inconsistency.
- Bundled analytics artifacts (e.g. AdministrationProfiles) cannot see overrides — disclosed
  in the anomaly warning rather than papered over.
- Registrations: `frusModelTypes` (+7 CloudKit identifiers, in `identifiersAwaitingDeploy`
  boarding the reserved W-4+W-5 promotion), `ResetInventory.erased`, `DeduplicableRecord` +
  `dedupeSimple`, erase-warning key minted anew
  (`settings.erase.warning.inventory.corrections`) with the `EditableContent.md` mirror
  repointed.

## Tests

`DocumentClassificationOverrideTests.swift`: store upsert/ordering/removal; AST transform
shape/idempotence/round-trip; pipeline apply + re-index replay + the volume-scoped restore
path (proving it does not cache) + unindexed no-op + **the search type filter honoring an
override with no per-consumer change** (a real `SearchService.searchCount` over a real
fixture index).
