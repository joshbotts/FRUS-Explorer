# Source Explorer: Provenance Rework — Scope

**The trigger (owner, 2026-07-03):** collections listed in a volume's front-matter Sources section — collections the compiling editors demonstrably used — routinely resolve zero archival neighbors. "This is a signal that there is still work to do with the Source Explorer feature, especially in parsing sources and citations during indexing and resolving shared collection references."

**The evidence:** [Source-Explorer-Audit-2026-07-03.md](Source-Explorer-Audit-2026-07-03.md) — a result-oriented audit against the live 552-volume index. Headline numbers: only **3.4%** of front-matter source items resolve any neighbor today; **82%** of zero-resolvers are app-side defects (0% are "era not indexed"); one extraction bug wipes out source-note coverage for **~77,000 documents (1955–1991, <1% coverage)**; the measured post-fix ceiling is **86%** of lot-keyed items resolving (vs 25% today). The Office of the Historian's `frus-sources` repo (local at `~/Development/frus-sources`) contributes the source-note locator recipe and a cross-volume reconciliation model; `~/Development/citations.csv` (267,663 source notes, 520 volumes) is a ready parser-regression corpus.

**Goal.** Every archival collection a volume's editors cite — in front matter or in a document's source note — resolves to (a) its NARA identity and (b) the set of indexed documents drawn from it, across volumes. Kill the zero-neighbor lie: an empty result must mean "nothing in your index cites this," never "we failed to parse it."

This document follows the house scope conventions (cf. `Collections-Authoring-Scope.md`): phases with concrete work items, decision points **S1–S6** (cheap/expensive, owner resolves at implementation time), cross-cutting constraints, per-phase verification targets keyed to the audit's queries.

---

## Architectural spine

Store **normalized match keys at parse time** — both the document side and the front-matter side write the same normal forms (compact lot `64D199`, decimal location, repository authority string). Keep **matching dumb at display time** — indexed equality/prefix lookups, no variant fan-out. Push **cross-volume authority and NARA identity into bundled generator indexes**.

Data-vs-app split:

- **Bundled generators** (SPM, offline): collection authority (alias clusters, lot→NAID via the existing `VolumeSourcesIndexGenerator` cache), era vocabulary (office symbols, subject-numeric classes), the parser eval harness over `citations.csv`.
- **Parse time** (`IndexingPipeline` / `FRUSDocumentParser`): the extraction fix, `SourceNoteParser` v2, `volume_sources` keying/inheritance, normalized-key columns. **Every phase here bumps `currentDateIndexVersion` in the same commit** (house rule — this is exactly the rule whose violation caused the June empty-Sources regression).
- **Display time**: the matcher reads normalized keys; the UI distinguishes three states — *no key* / *keyed, zero matches* / *matches*.

---

## Phase 1 — Extraction fix *(Cheap; the single highest-ROI change in the app)*

Port the `frus-sources` locator chain (`import/import.xq`) into source-note extraction: today `extractSourceNote` (IndexingPipeline.swift:2548) scans **top-level AST nodes only**, but every volume from 1955 on nests `<note type="source">` inside `<head>` — the note is silently dropped.

**Work items**
1. Locator chain, in priority order: `head/note/p/seg[@type='source']` → `head/note[@type='source']` (first paragraph matching `^\[?Source:`) → the existing inline top-level `<note type="source">`. First: verify what `FRUSDocumentParser` currently does with head-nested notes (preserved in the AST vs dropped) — the fix may extend the parser, not just the scan.
2. Strip `[Source: …]` / `Source:` wrappers consistently across both encodings.
3. **S1** (lean: yes, while touching the row shape): split the note per the frus-sources sentence model — sentence 1 = archival citation, sentence 2 = classification markings ("Secret; Nodis"), rest = remarks — and store `classification` alongside the full note. Store-only in Phase 1; Phase 5 surfaces it.
4. Bump `currentDateIndexVersion` in the same commit.

**Unlocks:** ~77k modern documents; `structured` era rows (`.naraCollection` / `.presidentialLibrary`) start existing at all; the per-document Archival Neighbors sheet comes alive for the modern corpus; front-matter lots (a 1950s+ phenomenon) finally have something to match.

**Verification:** source-note coverage by era ≥90% for 1955+ (audit query (a)), measured by indexing real modern TEI volumes; `structured` rows exist for a sampled modern volume.

## Phase 2 — SourceNoteParser v2, era-aware *(Moderate)*

Grammar upgrades, each justified and regression-tested by the `citations.csv` eval corpus (30% of extracted notes are `unrecognized` today):

1. Decimal refs with word/office infixes (`893.51 Manchuria/49`, `740.00112 European War 1939/6363`, `396.1 GE/7–854`) → `.centralFiles` with location = text before `/` — the bulk of 1906–51's 50k unrecognized, all segment-matchable.
2. Lowercase/comma lot style (`…files, lot 60 D 665`), lot-leading notes (`Lot 71–D 440, Box…`).
3. **Unicode dash normalization once, at write time**: store `lot_file_norm` (compact, dash/space-free, uppercase) alongside raw — 185 of 466 distinct stored lot values contain an en/em-dash today, a live mismatch *within* the doc side. The same normal form is written from `volume_sources` (Phase 3).
4. Presidential-library notes without the `Source:` prefix (652 in 1952–63 alone).
5. Named file series (`IO Files: US(P)/A/351`) → repository + series key.
6. **Eval harness** (SPM tool or fixture-driven test): classification-rate by era over the 267k-note corpus; CI-diffable per commit. Targets: unrecognized <10% for 1906–1963, <15% overall.
7. Bump `currentDateIndexVersion`.

**S2** (lean: SPM tool): eval harness as a standalone SPM generator (offline, diffable output file) vs a test-target fixture (runs in CI but slower suite). Either must be re-runnable in one command.

## Phase 3 — volume_sources keying & tree inheritance *(Moderate)*

1. Designator-agnostic lot regex (`\d{2,3}\s*[–-]?\s*[A-Z]\s*[–-]?\s*\d+` — F/W/M designators included; boundary fix for run-together text like `Lot 90 D 313Records…`). 507 no-key items literally contain "Lot" today.
2. **Context inheritance down the outline tree**: RG/repository/library live on parent headings; children (`Central Files 1967–69: POL 27 ARAB–ISR`) inherit them at parse time (the `depth` tree already exists).
3. New match paths in `makeNeighborsTarget` + `archivalNeighbors(forLotFile:…)`: presidential-library (repository + collection prefix — `relatedByPresidentialLibrary` exists on the doc side but volume-level entries have no path to it), and decimal/subject-numeric class leaves (`POL 27 ARAB–ISR` → decimal-location prefix match against `citation_era IN ('decimal','cfpf')`).
4. Exclude bibliography (`listofworks`) rows from collection affordances — 2,634 items that should never look like resolvable collections.
5. Matcher simplification: `lot_file_norm =` single indexed lookup replaces the 4-variant `IN`; `relatedByCollection` becomes a normalized prefix match (the doc side appends `, Box N`; exact equality is the wrong grain — 81/539 resolve today).
6. Bump `currentDateIndexVersion`.

**S3** (lean: cheap): decimal-class leaf matching — prefix-match only (cheap) vs full `DecimalFileSegment` period-aware matching for front-matter leaves (expensive; the doc-side segmenter exists — port if cheap in practice).

## Phase 4 — Cross-volume collection authority *(Expensive; the frus-sources idea, done right)*

Bundled `collection-authority.json` (extend `VolumeSourcesIndexGenerator`): cluster front-matter + citation collections corpus-wide by normalized key and leading-segment hierarchy (the `merge.xq` model — tokenize citation sentences on `", "`, merge by leading segments), attach NAIDs and alias forms. The app gains "this collection, across N volumes and M documents" from any surface, and a browse-by-collection tree in Source Explorer.

**S4** (lean: two levels): segment-tree depth — full hierarchical location tree (frus-sources-style; expensive) vs two levels (collection + sub-series; probably 90% of the value).
**S5** (lean: local): per-user indexed-document counts recomputed locally vs shipped estimates (the user's index defines them — local).

## Phase 5 — UI truth & polish *(Cheap)*

1. Three-state neighbor affordance: *no key* (no button — but now rare and honest) / *keyed, zero matches* ("nothing in your index cites this") / *n matches*.
2. Classification chips from the S1 column (document view + search rows where cheap).
3. Wire the cross-volume authority into `VolumeSourcesView` and the document Source sheet.
4. **S6** (owner call, from the UI audit): Archival Neighbors as a **window** on macOS (the audit's sheet→window list) — natural to do while touching these surfaces.
5. Docs pass per house rule (Docs/ manuals, TestFlight notes, ResearchGuideView, IndexingEducationView).

---

## Verification (result-oriented, every phase)

Re-run the audit's queries (reproduction scripts preserved with the audit) on a reindexed database:
- **(a)** source-note coverage by era — ≥90% for 1955+ after Phase 1;
- **(b)** unrecognized rate by era — <10% (1906–1963), <15% overall after Phase 2;
- **(c)** keyed-item resolution rate — lot-keyed items ≥80% resolving after Phases 1–3 (measured ceiling: 86%);
- **(d)** the 100-sample root-cause bucketing re-run — buckets B2/B3 (extraction + parse gaps) ≈ 0.

## Cross-cutting constraints

- Parse-output changes bump `currentDateIndexVersion` in the same commit — no exceptions.
- Schema changes to `document_sources`/`volume_sources` follow the drop-and-recreate-on-migration pattern established by the Session-170 rewrite (tables are derived; the version bump repopulates).
- Coding standards as ever (`String(localized:)`, doc comments, Apache headers, version histories, audit tests).
- `frus-sources` is a **quarry, not a dependency** (88 volumes, stale); `citations.csv` is an eval corpus, never a runtime data source.

## Explicit non-goals

Pre-1906 despatch-number provenance (separate program: `BigPicture-Pre1910-CentralFiles.md`); NARA API live lookups beyond current behavior; retroactive migration of existing databases without reindex (the index-version bump *is* the migration mechanism).

## Sequencing summary

| # | Phase | Cost | Index bump | Payoff |
|---|-------|------|-----------|--------|
| 1 | Extraction fix | Cheap | yes | ~77k documents gain source notes; modern-corpus neighbors come alive |
| 2 | Parser v2 + eval harness | Moderate | yes | unrecognized 30% → <15%; normalized keys begin |
| 3 | volume_sources keying + inheritance + matcher | Moderate | yes | front-matter resolution 25% → ~86% ceiling; new match paths |
| 4 | Cross-volume authority | Expensive | no (bundled) | corpus-wide collection identity + browse-by-collection |
| 5 | UI truth + docs | Cheap | no | honest empty states; classification chips; authority surfaced |

**Status:** scoped 2026-07-03 from the audit; Phase 1 unblocked (S1 lean: yes) and started immediately per owner direction; S2–S6 resolve at their phases.
