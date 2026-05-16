# Sessions 36–42 — Extended TEI Indexing

**Version**: 1.0
**Date**: 2026-05-16
**Planning document**: `36-42-Extended-Indexing-Plan.md` (external, provided before sessions began)

These seven sessions indexed TEI data that the post-Session 31 audit identified as missing from the search pipeline. Each session was self-contained and produced its own tests. Sessions 36–39 were completed in the order listed; 36–37 depended on 35; 38 depended on all prior sessions; 39→40→41 were sequentially dependent.

---

## Session Sequence

| # | Task | Key Output | Depends On |
|---|---|---|---|
| 36 | Structured date indexing | `.date` AST node; `extractStructuredDate`; `DateCertainty` | 07, 09 |
| 37 | Cross-reference context population | `cross_references.context` populated; edge labels in graph UI | 17, 18 |
| 38 | Editorial note distinction | `is_editorial_note` in `document_cache`; `DocumentTypeFilter` search control | 09, 16 |
| 39 | `<persName @ref>` indexing — data layer | `person_mentions` table; `PersonMentionStore`; `SearchParameters.personRef` | 09 |
| 40 | `<persName @ref>` indexing — UI | Person-filter in Search view; mention count in `PersonDetailSheet`; `pendingSearch` navigation | 39, 16, 12 |
| 41 | Persons and terms glossaries persisted | `persons` and `terms` SQLite tables; `PersonMentionStore` extensions; SQLite-first `DocumentViewModel` | 39 |
| 42 | `<note @n>` footnote number indexing | `printedNumber` in AST and render model; `displayLabel` used for rendering | 07, 13 |

---

## Session 36 — Structured Date Indexing

### Goal

Replace the `parseDateISO` plain-text heuristic with extraction of `@when`, `@from`, `@to`, `@notBefore`, and `@notAfter` attributes from `<date>` elements inside `<dateline>`. Eliminates silent false negatives from failed plain-text parses; adds a data migration flag to trigger background re-index on first launch after update.

### Key Changes

**`FRUSASTNode`** — new `.date(when:from:to:notBefore:notAfter:children:)` case and `DateCertainty` enum (`.exact`, `.range`, `.approximate`, `.textOnly`).

**`FRUSDocumentParser`** — `buildNode` maps `<date>` to `.date` node capturing all five attributes.

**`ASTToRenderNodeConverter`** — `.date` passthrough to `convertNodes(children)` (display unchanged).

**`IndexingPipeline`** — `extractStructuredDate(from:)` with five-level priority order:
1. `@when` on `.date` inside `.dateline`
2. `@from` on `.date` inside `.dateline`
3. `@notBefore` on `.date` inside `.dateline`
4. `@when` on `.date` anywhere in body
5. Plain-text `parseDateISO` fallback (retained as `private static`)

`UserDefaults` migration flag `frus.dateIndexVersion = 2` triggers background re-index of all downloaded volumes on first launch.

**FRUS-API.openapi.yaml** — `DocumentDate` schema updated with `certainty` field.

### Tests

`DateAttributeParsingTests` (5 cases) and `DateIndexingAccuracyTests` (8 cases) — covering attribute capture, priority ordering, plain-text fallback, null output, and end-to-end date-range query.

---

## Session 37 — Cross-Reference Context Population

### Goal

Populate `cross_references.context` (always `NULL` since Session 17) with the plain text of the enclosing `<note>` or `<div type="editorialNote">`. Surface context in the cross-reference graph info panel.

### Key Changes

**`IndexingPipeline.extractCrossReferences`** — new `enclosingText: String?` parameter; passed down through recursion; set when entering a `.footnote` or `.editorialNote` node; written to `CrossReferenceRow.context` (truncated at 500 characters at a word boundary with `"…"` suffix).

**`CrossReferenceGraphView`** — new `EdgeContextView` in the hover/tap popover below `header` and `dateline`; shows context when non-nil; "Show more / Show less" disclosure for long strings.

**FRUS-API.openapi.yaml** — `CrossReferenceEdge.context` documented as now populated.

### Tests

`CrossReferenceContextTests` (4 cases) in `IndexingPipelineTests` — footnote context extraction, 500-char truncation with word boundary, null context for top-level `<ref>`, editorial note context.

`CrossReferenceStoreTests` — context round-trip through store.

---

## Session 38 — Editorial Note Distinction

### Goal

Index `<div type="editorialNote">` elements as their own rows in `document_cache` and the FTS5 index, with an `is_editorial_note` flag. Add a Document Type filter to the Search view. Render editorial note entries distinctly in `CompilationView`.

### Background

Before Session 38, editorial note content flowed into the surrounding document's `bodyText` via the `isTransparent` passthrough; editorial note IDs did not appear in `VolumeSection.documentIds`. This session promotes them to full document entries.

### Key Changes

**`FRUSDocumentParser.TEIParserDelegate`** — `<div type="editorialNote">` branch in `didEndElement` parallel to the `<div type="document">` branch; wraps children in `.editorialNote([children])` and appends a `FRUSDocumentAST`.

**`VolumeStructureParserDelegate`** — records `xml:id` of `<div type="editorialNote">` elements in the parent section's `documentIds`.

**`IndexingPipeline`** — schema migration adds `is_editorial_note INTEGER NOT NULL DEFAULT 0` to `document_cache`; `parseAndExtract` detects top-level `.editorialNote` wrapper and sets the flag.

**`FTS5Column`** — new `.isEditorialNote` case marked `UNINDEXED`.

**`SearchModels`** — `DocumentTypeFilter` enum (`.all`, `.documentsOnly`, `.editorialNotesOnly`); added to `SearchParameters`.

**`SearchService`** — applies `documentTypeFilter` in post-processing.

**`SearchView`** — Document Type segmented control in the filter panel.

**`DocumentBrowserEntry`** — `isEditorialNote: Bool`; populated from `document_cache`.

**`CompilationView`** — editorial note rows render with italic title and `text.badge.checkmark` symbol.

**FRUS-API.openapi.yaml** — `isEditorialNote` added to document schemas; `documentType` parameter added to `GET /search`.

### Tests

`EditorialNoteIndexingTests` (3 cases) in `TEIParserTests`; `EditorialNoteFilterTests` (4 cases) in `IndexingPipelineTests`.

---

## Session 39 — Person Mention Indexing — Data Layer

### Goal

Index every `<persName @ref>` occurrence into a `person_mentions` SQLite table, creating a queryable link between documents and the persons they mention. Implement `PersonMentionStore` and extend `SearchParameters` with a `personRef` filter.

### Key Changes

**`IndexingPipeline`** — `person_mentions` table (`volume_id`, `document_id`, `person_ref`; indexed on `person_ref` and on `(volume_id, document_id)`); `extractPersonRefs(from:)` returns a deduplicated `Set<String>` (one row per person per document); `auxInsertPersonMentions` follows the existing transaction pattern; `removeVolume` deletes from `person_mentions`.

**`PersonMentionStore`** — new actor; `documents(forPersonRef:)`, `personRefs(forDocumentId:volumeId:)`, `documentCount(forPersonRef:)`.

**`SearchParameters`** — `personRef: String?`; `SearchService.search` applies it as a pre-filter whitelist before FTS5.

**`AppState`** — instantiates and vends `PersonMentionStore`.

**FRUS-API.openapi.yaml** — `GET /volumes/{volumeId}/persons/{ref}/documents` endpoint note; `personRef` added to `GET /search`.

### Tests

`PersonMentionIndexingTests` (3 cases) in `IndexingPipelineTests`; new `PersonMentionStoreTests.swift` (4 cases).

---

## Session 40 — Person Mention Indexing — UI

### Goal

Surface the `person_mentions` data layer in the Search view (person-ref filter) and in the Document view `PersonDetailSheet` (mention count and "Find all mentions" navigation).

### Key Changes

**`SearchView`** — person name field in the filter panel; wired to `SearchParameters.personRef` via `SearchViewModel.personRefText`; active-filter badge with clear button.

**`AppState`** — `pendingSearch: SearchParameters?` for cross-view navigation (set by "Find all mentions" button; consumed by `BrowserView.onChange`).

**`BrowserView`** — observes `pendingSearch`; opens Search sheet pre-filled with `initialParameters`.

**`DocumentViewModel`** — `personMentionStore` dependency; `selectedPersonMentionCount`; `loadPersonMentionCount(for:)` async method.

**`PersonDetailSheet`** — "Mentioned in N indexed documents" footer loaded via `.task(id:)`; "Find all mentions" button sets `appState.pendingSearch` and dismisses.

**`SearchModels.SearchParameters`** — conforms to `Equatable` (required for `onChange`).

**`FTS5Query.BooleanMode`** — conforms to `Equatable`.

### Tests

`PersonFilterTests` (2 cases) in `SearchViewTests`; `PersonMentionBadgeTests` (2 cases) in `DocumentViewTests`.

---

## Session 41 — Persons and Terms Glossaries Persisted to SQLite

### Goal

Persist per-volume persons and terms glossaries into SQLite tables during `indexVolume`, eliminating repeated XML re-parses on every document open and enabling cross-volume person search by name.

### Key Changes

**`IndexingPipeline`** — `persons` table (`volume_id`, `ref`, `name`, `description`; `PRIMARY KEY (volume_id, ref)`; `idx_persons_name` index) and `terms` table (same structure with `term`/`definition`); `auxInsertPersons` and `auxInsertTerms` with `INSERT OR REPLACE`; `removeVolume` clears both tables.

**`PersonMentionStore`** — extended with `person(forRef:volumeId:)`, `allPersons(forVolumeId:)`, `personsMatchingName(_:limit:)`; term lookup methods.

**`DocumentViewModel`** — SQLite-first glossary resolution; XML parse kept as fallback for unindexed volumes.

**`SearchView`** — raw-ref text field (Session 40) replaced with live autocomplete picker backed by `personsMatchingName`; displays volume provenance alongside each match.

**FRUS-API.openapi.yaml** — `GET /volumes/{volumeId}/persons`, `GET /volumes/{volumeId}/terms`, `GET /persons?name={query}` endpoint notes.

### Tests

`GlossaryPersistenceTests` (4 cases) in `IndexingPipelineTests`; `PersonsByNameTests` (4 cases) in `PersonMentionStoreTests`.

---

## Session 42 — Footnote Number Indexing (`<note @n>`)

### Goal

Capture the `@n` attribute on `<note>` elements (the printed footnote number) and propagate it through the AST and render model so displayed footnote numbers match the printed volume when `@n` is present.

### Background

The `ASTToRenderNodeConverter` previously assigned sequential numbers starting from 1. FRUS footnotes sometimes have non-sequential `@n` values (gaps occur when footnotes are renumbered during editing or when `type="source"` notes are excluded from the main sequence), causing citation errors.

### Key Changes

**`FRUSASTNode.footnote`** — adds `printedNumber: String?` (breaking change; compiler verified all sites).

**`FRUSDocumentParser`** — captures `attributes["n"]` as `printedNumber`.

**`ASTToRenderNodeConverter`** — `displayLabel = printedNumber ?? "\(sequentialNumber)"`; sequential counter still increments to maintain consistent bookkeeping.

**`FRUSRenderNode.footnoteBody`** — adds `printedNumber: String?`, `sequentialNumber: Int`, `displayLabel: String` (breaking change).

**`FRUSRenderNode.footnoteMarker`** — replaces `number: Int` with `displayLabel: String` (breaking change).

**`FRUSDocumentRenderer`** — uses `displayLabel` in body prefix and inline superscript.

All pattern-match sites updated: `IndexingPipeline` (×4), `DocumentViewModel` (×1), `TEIParserTests` (×5), `FRUSParserSession07Tests` (×2), `IndexingPipelineTests` (×5).

### Tests

`FootnoteNumberTests` (4 cases) in `TEIParserTests` — `@n` captured, `nil` when absent, non-sequential gaps produce correct `displayLabel`, marker and body label parity verified end-to-end.

---

## OpenAPI Updates by Session

| Session | Change |
|---|---|
| 36 | `DocumentDate.certainty` field added (`exact`, `range`, `approximate`, `textOnly`) |
| 37 | `CrossReferenceEdge.context` documented as populated; example updated |
| 38 | `isEditorialNote: boolean` in document schemas; `documentType` enum in `GET /search` |
| 39 | `GET /volumes/{volumeId}/persons/{ref}/documents`; `personRef` in `GET /search` |
| 40 | `GET /search personRef` description updated for name-based resolution note |
| 41 | `GET /volumes/{volumeId}/persons`; `GET /volumes/{volumeId}/terms`; `GET /persons?name=` |
| 42 | `FRUSRenderNode` schemas: `footnoteBody` and `footnoteMarker` gain `displayLabel` and `printedNumber` |
