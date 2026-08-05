# Session 09 — Search Index Pipeline

## Goal
Build the indexing pipeline that processes downloaded FRUS volumes into the FTS5 search index and cross-reference edge table. Implements concurrent indexing, incremental updates, and the full-text search service used by the Search view.

## Prerequisites
- Sessions 03, 05, 07, 08 complete

## Specification References
- Section 9: Search & Indexing

## Key Types

### `IndexingPipeline`
```swift
/// IndexingPipeline processes FRUS volume XML files into the FTS5 search index
/// and cross-reference edge table. It runs concurrently across volumes using
/// TaskGroup, with a configurable concurrency limit.
///
/// Incremental updates: individual volumes, summaries, and research notes
/// can be added without triggering a full reindex.
actor IndexingPipeline {
    func indexVolume(_ volumeId: String) async throws
    func indexAllVolumes() async throws
    func removeVolume(_ volumeId: String) async throws
    func updateSummary(_ summary: GeneratedSummary) async throws
    func updateResearchNote(_ note: ResearchNote) async throws
    var progress: AsyncStream<IndexingProgress> { get }
}
```

### `SearchService`
```swift
/// SearchService is the primary search interface for the application.
/// It translates user search parameters into FTS5Query objects and
/// returns typed SearchResult values for display in the Search view.
actor SearchService {
    func search(parameters: SearchParameters) async throws -> [SearchResult]
    func searchCount(parameters: SearchParameters) async throws -> Int
}

struct SearchParameters: Sendable {
    var keywords: String?
    var phrase: String?
    var booleanMode: BooleanMode
    var excludedTerms: [String]
    var prefixWildcard: String?
    var dateRange: DateRange?
    var subjectTagIds: [String]
    var userTagIds: [String]
    var volumeIds: [String]?       // nil = all volumes
    var includeSummaries: Bool
    var includeNotes: Bool
    var projectId: UUID?           // nil = all projects (global context)
}
```

## Tasks
1. Implement `IndexingPipeline` with `TaskGroup`-based concurrent volume processing
2. Implement per-volume indexing: parse TEI (via `FRUSDocumentParser`), extract plain text, insert into `FTS5Store`, extract cross-references into edge table
3. Implement subject tag integration during indexing (from `SubjectTagStore`)
4. Implement `IndexingProgress` AsyncStream for UI progress reporting
5. Implement `removeVolume` — deletes all FTS5 documents for that volume, removes cross-reference edges, and removes page_ranges rows for that volume
6. Implement incremental summary and research note updates
7. Implement `SearchService` translating `SearchParameters` → `FTS5Query` → `[SearchResult]`
8. Add date range filtering (documents outside the range excluded from results)
9. **Implement `page_ranges` table** (required by Session 30 — Citation Lookup):
   - Create table and indexes in the same SQLite database as cross-references:
     ```sql
     CREATE TABLE page_ranges (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         volume_id TEXT NOT NULL,
         document_id TEXT NOT NULL,
         section_id TEXT NOT NULL,
         page_number_type TEXT NOT NULL,
         page_number_int INTEGER,
         page_number_raw TEXT NOT NULL
     );
     CREATE INDEX idx_page_ranges_volume ON page_ranges(volume_id, page_number_type, page_number_int);
     CREATE INDEX idx_page_ranges_document ON page_ranges(volume_id, document_id);
     ```
   - During per-volume indexing, extract all `pageBreak` AST nodes, record the containing document ID and section ID (parent compilation or chapter `@xml:id`), and insert rows into `page_ranges`
   - Section grouping handles pagination restarts between volume sections
10. Update `FRUS-API.openapi.yaml` with `GET /search` and `GET /volumes/{volumeId}/page-ranges` endpoints

## Tests
- **IndexVolumeTest**: Index a fixture volume; verify documents appear in search results
- **CrossReferenceExtractionTest**: Index a fixture volume with known `<ref>` elements; verify edge table contains expected edges
- **SubjectTagIndexTest**: Verify subject tags are searchable after indexing
- **IncrementalUpdateTest**: Index volume; add summary; verify summary text searchable
- **RemoveVolumeTest**: Index then remove volume; verify documents no longer searchable; verify page_ranges rows removed
- **SearchParametersTest**: Fixture-based tests for keyword, phrase, boolean, date range, and tag filters
- **ConcurrencyTest**: Index multiple volumes concurrently; verify no data corruption
- **PageRangeInsertTest**: Index fixture volume with known `<pb>` elements; verify page_ranges rows present with correct volume_id, document_id, section_id, and page_number values
- **PageRangeSectionGroupingTest**: Fixture volume with pagination restart between sections; verify section_id correctly distinguishes the two page sequences

## Coding Standards Checklist
- [ ] `[IndexingPipeline]` and `[SearchService]` log prefixes
- [ ] Concurrency limit documented and configurable
- [ ] `page_ranges` table population documented with section grouping rationale
- [ ] `FRUS-API.openapi.yaml` updated with `GET /search` and `GET /volumes/{volumeId}/page-ranges`
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 10 — Onboarding View
**Updated**: 2026-05-14 — Volume browser uses sortable/filterable tag-based list; no abstract display

## Goal
Implement the full onboarding flow shown when no volumes are downloaded or sideloaded. Includes FRUS introduction, volume selection from bundled manifest (sortable by subseries or filterable by volume-level tag), download initiation, and guided initial project creation.

## Prerequisites
- Sessions 02, 05, 08, 09 complete (manifest, download manager, tag stores, indexing pipeline)

## Specification References
- SPEC-UPDATE-Manifest-Tags.md (volume browser design)
- Section 16: User Experience — Onboarding View

## Tasks
1. Implement onboarding trigger: check at every launch whether any volumes exist; show onboarding if none
2. FRUS introduction screen (draw from history.state.gov/historicaldocuments/about-frus; fetch at launch if online; fall back to bundled text if offline)
3. Volume browser with two modes, using `VolumeLevelTagStore` for tag data:
   - **Sort by subseries** (default): volumes grouped by subseries label in chronological order
   - **Browse by tag**: tag picker organized by taxonomy hierarchy (People / Places / Topics → subcategory → tag); searchable; multi-select with AND logic via `VolumeLevelTagStore.volumes(forTagSlugs:)`
   - Volume list item: title, subseries, date range, document count, up to 5 tag chips (by category priority: People first, then Places, then Topics; overflow count for remainder)
   - Tag chips tappable → activates as filter
   - "Newly available" badge for live-only volumes (no tag data available)
   - Multi-select for download
4. Storage requirement display before download confirmation
5. Download confirmation and initiation (hands off to `DownloadManager`)
6. Download progress display (non-blocking; user can proceed to project creation while downloads run)
7. Guided initial project creation: name, research question, default date range, default subject/country tags
8. Guided initial summarization prompt creation (or skip)
9. Offline state: inform user, show bundled manifest, queue downloads for next online launch
10. Re-entry: onboarding reappears identically when triggered again after all volumes deleted

## Tests
- **OnboardingTriggerTest**: No volumes → onboarding shown; one volume → onboarding not shown
- **SubseriesSortTest**: Volume list in default mode; verify volumes grouped by subseries in chronological order
- **TagFilterTest**: Select a tag slug via picker; verify volume list filtered to volumes with that tag
- **MultiTagFilterTest**: Select two tag slugs; verify AND logic — only volumes with both tags shown
- **TagChipTapTest**: Tap a tag chip in the volume list; verify that tag activated as filter
- **NewlyAvailableTest**: Live-only volume appears with badge; no tag chips displayed for it
- **OfflineOnboardingTest**: Mock offline state; verify bundled manifest shown; verify queue established
- **ProjectCreationTest**: Complete guided flow; verify `Project` created in SwiftData with correct fields

## Coding Standards Checklist
- [ ] All strings localized
- [ ] `[Onboarding]` log prefix
- [ ] Accessibility: all interactive elements labeled
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 11 — Browser View
**Updated**: 2026-05-14 — Volume level displays tag chips; subseries level adds tag filter; no abstract display

## Goal
Implement the hierarchical browser view that scales from corpus to subseries to volume to compilation to chapter to document. Each level displays contextually appropriate information with navigation up and down the hierarchy.

## Prerequisites
- Sessions 05, 06, 08 complete

## Specification References
- SPEC-UPDATE-Manifest-Tags.md (volume-level tag display and filtering)
- Section 16: User Experience — Browser View

## Hierarchy Levels and Display

### Corpus Level
- Total volumes, total documents, earliest/latest document date, earliest/latest publication date
- List of subseries (tappable → subseries level)

### Subseries Level
- Total volumes, total documents, earliest/latest document date, earliest/latest publication date
- Count of partially published volumes; count of planned-but-unpublished volumes
- **Tag filter bar**: tag picker (same as onboarding) filters the volume list within this subseries; multi-select with AND logic; uses `VolumeLevelTagStore`
- List of volumes (tappable → volume level)

### Volume Level
- Title, volume number, editors, general editor, publication date
- **Tag chips** for all volume-level tags, organized by category (People first, then Places, then Topics)
- Tapping a tag chip activates that tag as a filter in the parent subseries view, narrowing the volume list to volumes sharing that tag
- Volume-level tag chips are displayed without confidence distinction (authoritative; no curated/string-match indicator needed — contrast with document-level subject tag chips in Session 12)
- List of top-level components: front matter, compilations, appendices, errata, back matter (tappable → compilation/chapter level)

### Compilation / Chapter Level
- List of documents and editorial notes
- Per item: header, dateline, source note, user tags (if any), latest generated summary preview (if any)
- Tapping a document → Document view (Session 12)

### Filtering
- Project-level default filters pre-applied at all levels
- Tag filter (using `VolumeLevelTagStore`) available at corpus and subseries levels
- User can adjust date range, document-level subject tag, and user tag filters at chapter level
- Filter adjustments persist for the session but do not override project defaults permanently

## Tasks
1. Implement `BrowserViewModel` with navigation state and hierarchy data loading
2. Implement corpus-level statistics computation (from manifest + index)
3. Implement subseries-level view with partially-published and planned counts
4. Implement tag filter bar at subseries level using `VolumeLevelTagStore.volumes(forTagSlugs:)`; tag picker organized by taxonomy hierarchy
5. Implement volume-level tag chip display (all tags, organized by category)
6. Implement tag chip tap → activates as subseries-level filter
7. Implement volume-level component list from parsed TEI structure
8. Implement chapter-level document list with metadata
9. Implement filter bar (date range, document-level subject tags, user tags) at chapter level
10. Platform-adaptive layout: sidebar navigation on macOS/iPadOS; push navigation on iPhone
11. Update `FRUS-API.openapi.yaml` with `GET /volumes/{volumeId}/documents` endpoint

## Tests
- **HierarchyNavigationTest**: Navigate down from corpus to document level; verify correct data at each level
- **TagFilterTest**: Apply volume-level tag filter at subseries level; verify volume list respects filter
- **MultiTagFilterTest**: Apply two tag slugs; verify AND logic
- **TagChipTapTest**: Tap volume-level tag chip; verify parent subseries view filter updated
- **VolumeTagDisplayTest**: Volume with known tags; verify chips displayed organized by category
- **EmptyStateTest**: Subseries with no downloaded volumes shows appropriate empty state
- **NoAbstractTest**: Verify no abstract text appears anywhere in browser hierarchy

## Coding Standards Checklist
- [ ] All strings localized
- [ ] `[BrowserView]` log prefix
- [ ] Accessibility: navigation hierarchy expressed via accessibility containers
- [ ] `FRUS-API.openapi.yaml` updated
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 12 — Document View — Core

## Goal
Implement the Document view that renders FRUS documents using the TEI rendering pipeline, with its toolbar, tag display, citation access, and summary display.

## Prerequisites
- Sessions 06, 07, 08, 04 complete

## Specification References
- Section 16: User Experience — Document View

## ⚠️ Accessibility Open Questions (resolve before this session)
See Specification Section 18:
- VoiceOver label pattern for tag chips
- Document view VoiceOver reading order preference

## Tasks
1. Implement `DocumentViewModel` — loads document AST, renders via Layer 3, loads tags and summaries from SwiftData and `SubjectTagStore`
2. Implement document toolbar: research note actions, user tag actions, collection actions, citation button, copy citation button, cross-reference button
3. Implement summary display above document (active summary + control to view others)
4. Implement rendered TEI document body (using Session 06/07 SwiftUI renderer)
5. Implement `<persName>` tap → List of Persons sheet
6. Implement `<gloss>` tap → Terms and Abbreviations sheet
7. Implement `<ref>` tap → navigate to target document (download if needed)
8. Implement subject tag chips and user tag chips below document — tappable → Search view with tag filter
9. Implement action button (tag document / add research note)
10. Implement cross-project research note indicator ("N notes from other projects" disclosure)
11. Record `ReadingHistoryEntry` on document open
12. Update `FRUS-API.openapi.yaml` with `GET /volumes/{volumeId}/documents/{documentId}`

## Tests
- **DocumentRenderTest**: Load fixture document; verify rendered view contains expected text content
- **ReadingHistoryTest**: Open document; verify `ReadingHistoryEntry` created with correct `projectId`
- **TagChipTest**: Document with known tags; verify chips displayed and tappable
- **CrossProjectIndicatorTest**: ResearchNote with different projectId than active; verify indicator shown, note hidden by default, revealable

## Coding Standards Checklist
- [ ] All strings localized
- [ ] `[DocumentView]` log prefix
- [ ] Accessibility: toolbar items labeled; tag chips labeled; reading order correct per resolved open question
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 13 — Citation Formatter

## Goal
Implement the `CitationFormatter` with the history.state.gov recommended style. Produce a validated, tested formatter with a fixture-based test suite.

## Prerequisites
- Sessions 06, 12 complete

## Specification References
- Section 12: Citation Formatter

## ⚠️ Session Prerequisite
Fetch and review the current history.state.gov/historicaldocuments/citing-frus page at the start of this session to confirm the style rules and fixture expected outputs.

## Key Types

```swift
/// CitationFormatter generates formatted citations for FRUS documents.
/// Currently implements history.state.gov recommended style.
/// Additional styles are added by implementing CitationFormatterProtocol
/// and adding a CitationStyle enum case — no call site changes required.
protocol CitationFormatterProtocol {
    func format(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata) -> String
}

struct HistoryAtStateCitationFormatter: CitationFormatterProtocol {
    func format(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata) -> String
}

/// All data needed for citation generation, extracted from TEI.
struct FRUSDocumentMetadata: Sendable {
    let documentId: String
    let documentNumber: String?
    let header: String
    let dateline: String?
}

struct FRUSVolumeMetadata: Sendable {
    let title: String
    let volumeNumber: String
    let subseries: String
    let seriesName: String
    let editors: [String]
    let generalEditor: String?
    let publicationDate: String
    let publicationPlace: String
    let publisher: String
}
```

## Tasks
1. Implement `HistoryAtStateCitationFormatter` per current citing-frus rules
2. Wire into Document view toolbar (citation sheet + copy to clipboard)
3. Create fixture test set from citing-frus page examples

## Tests
- **StandardCitationTest**: Fixture-based; output matches expected string exactly
- **MultipleEditorsTest**: Volume with 3 editors; verify correct formatting
- **NoDatelineTest**: Document without dateline; verify graceful omission
- **EditorialNoteTest**: Editorial note citation; verify correct format
- **SubseriesTest**: Verify subseries appears correctly in citation

## Coding Standards Checklist
- [ ] `CitationFormatterProtocol` documented with extension path for future styles
- [ ] All strings localized (citation format strings)
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 14 — Research Note Editor

## Goal
Implement the research note creation and editing interface, including tag management, summary promotion, and cross-project visibility.

## Prerequisites
- Sessions 04, 12 complete

## Specification References
- Section 16: User Experience — Research Note Editor
- Section 15: Project & Global Context (cross-project visibility)

## Tasks
1. Implement `ResearchNoteEditorView` — rich text editor (SwiftUI `TextEditor` with formatting toolbar), tag selector, summary list
2. Implement project tag inheritance at creation (active project tag applied automatically)
3. Implement user tag management within the editor (add existing tags, create new tags)
4. Implement project tag management (add/remove project tags; note on behavior of removing creation project tag)
5. Implement generated summary list — select one or more summaries to promote as draft content
6. Implement promoted summary → note body text insertion
7. Implement save, delete, and discard actions
8. Wire cross-project indicator from Session 12 to reveal notes with different project tags

## Tests
- **NoteCreationTest**: Create note while project A is active; verify projectIds contains project A's UUID
- **TagInheritanceTest**: Verify project tag automatically applied; verify user can remove it
- **SummaryPromotionTest**: Select a GeneratedSummary; verify its text inserted into note body
- **CrossProjectRevealTest**: Note with project A tag viewed in project B context; verify hidden by default, revealable, promotable to project B

## Coding Standards Checklist
- [ ] All strings localized
- [ ] `[ResearchNoteEditor]` log prefix
- [ ] Accessibility: editor labeled; tag chips labeled
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 15 — Project & Global Context

## Goal
Implement project creation, switching, and context management. Implement the global context view. Wire activity tagging throughout the app.

## Prerequisites
- Sessions 04, 14 complete

## Specification References
- Section 15: Project & Global Context

## Tasks
1. Implement project creation UI (name, research question, default filters)
2. Implement project switching via a toolbar or sidebar picker — instantaneous state change in `AppState`
3. Implement "no active project" (global context) as a selectable state
4. Verify activity tagging: `ReadingHistoryEntry`, `GeneratedSummary`, `Collection` all correctly tagged with active `projectId` at creation time (integration tests across Sessions 09, 12, 14)
5. Implement global context view: aggregated reading history, notes browser (by project tag or user tag), collections browser
6. Implement project settings editing (name, research question, default filters)
7. Implement project deletion (with confirmation; associated activity records retain their project tag IDs but project is removed from the project list)

## Tests
- **ProjectSwitchTest**: Switch from project A to project B; verify `AppState.activeProjectId` updated; verify new activity records tagged with project B
- **GlobalContextTest**: No active project; create reading history entry; verify `projectId == nil`
- **ActivityTaggingIntegrationTest**: Open document in project A context; verify `ReadingHistoryEntry` has correct `projectId`
- **ProjectDeletionTest**: Delete project; verify activity records still exist with orphaned `projectId`

## Coding Standards Checklist
- [ ] `[ProjectContext]` log prefix
- [ ] Project switching documented (instantaneous, no data migration)
- [ ] All strings localized
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 16 — Search View

## Goal
Implement the full composable search interface with all filter types, scope selection, and results display.

## Prerequisites
- Sessions 09, 08, 15 complete

## Specification References
- Section 16: User Experience — Search View

## Tasks
1. Implement `SearchViewModel` bound to `SearchService`
2. Implement keyword search field with phrase, boolean, and prefix wildcard support; document suffix wildcard limitation in help text
3. Implement date range picker filter
4. Implement subject tag multi-select filter (browsable by category, searchable)
5. Implement user tag multi-select filter
6. Implement scope selector (volumes, summaries, notes — any combination)
7. Implement generated summary filter (all prompts or single selected prompt)
8. Pre-populate filters from active project defaults (overridable)
9. Implement results list: header, dateline, source note, summary preview, volume ID, document number, tags
10. Implement result tap → Document view navigation
11. Implement tag chip taps in results → update search filter
12. Implement search result count display

## Tests
- **KeywordSearchTest**: Search for a known term; verify expected documents in results
- **PhraseSearchTest**: Search for a known phrase; verify only documents with exact phrase returned
- **DateRangeFilterTest**: Apply date range; verify results respect range
- **SubjectTagFilterTest**: Apply subject tag filter; verify only tagged documents returned
- **ScopeTest**: Search summaries only; verify only summary text matches returned
- **ProjectDefaultsTest**: Switch to project with default filters; verify search pre-populated

## Coding Standards Checklist
- [ ] Suffix wildcard limitation documented in UI help text and in code
- [ ] All strings localized
- [ ] `[SearchView]` log prefix
- [ ] Accessibility: filter controls labeled; results list accessible
- [ ] Swift 6 strict concurrency: zero warnings
