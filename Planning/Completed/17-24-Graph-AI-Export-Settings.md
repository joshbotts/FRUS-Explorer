# Session 17 — Cross-Reference Graph — Data

## Goal
Implement cross-reference edge table queries and the data layer that feeds the graph renderer in Session 18.

## Prerequisites
- Session 09 complete (edge table populated during indexing)

## Specification References
- Section 11: Cross-Reference Graph

## Key Types

```swift
/// CrossReferenceEdge represents a directed reference between two FRUS documents.
/// Edges are extracted from <ref> elements in footnotes and editorial notes
/// during the indexing pass and stored in the SQLite cross_references table.
struct CrossReferenceEdge: Sendable {
    let sourceDocumentId: String
    let sourceVolumeId: String
    let targetDocumentId: String
    let targetVolumeId: String
    let context: String?          // footnote or editorial note text
    let referenceType: ReferenceType
}

enum ReferenceType: String, Sendable {
    case footnote
    case editorialNote
}

/// CrossReferenceGraph is the ego graph centered on a single document.
struct CrossReferenceGraph: Sendable {
    let centralDocumentId: String
    let centralVolumeId: String
    let inboundEdges: [CrossReferenceEdge]   // references TO this document
    let outboundEdges: [CrossReferenceEdge]  // references FROM this document
    let hasUndownloadedSources: Bool         // true if inbound from undownloaded volumes may exist
}

/// CrossReferenceStore queries the SQLite edge table.
actor CrossReferenceStore {
    func graph(forDocumentId: String, volumeId: String) async throws -> CrossReferenceGraph
    func inboundEdges(forDocumentId: String, volumeId: String) async throws -> [CrossReferenceEdge]
    func outboundEdges(forDocumentId: String, volumeId: String) async throws -> [CrossReferenceEdge]
    func edgeCount(forDocumentId: String, volumeId: String) async throws -> Int
}
```

## Tasks
1. Implement `CrossReferenceStore` querying the SQLite edge table
2. Implement `hasUndownloadedSources` detection (compare known volume IDs against downloaded volumes list)
3. Implement document metadata resolution for graph nodes: for each edge endpoint, load header, dateline, document number (from FTS5 index or volume metadata)
4. Implement undownloaded volume node representation: return placeholder metadata with nil fields
5. Implement filter application: project-level filter (only edges where both endpoints match project's document scope), custom filter, unfiltered

## Tests
- **InboundEdgeQueryTest**: Insert fixture edges; query inbound; verify correct edges returned
- **OutboundEdgeQueryTest**: Insert fixture edges; query outbound; verify correct edges returned
- **UndownloadedDetectionTest**: Edge pointing to volume not in downloaded list; verify `hasUndownloadedSources == true`
- **MetadataResolutionTest**: Query graph; verify node metadata (header, dateline) populated from index

## Coding Standards Checklist
- [ ] `[CrossReferenceStore]` log prefix
- [ ] `hasUndownloadedSources` logic documented
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 18 — Cross-Reference Graph — UI

## Goal
Implement the cross-reference graph renderer using SwiftUI Canvas, including both standard (≤20 nodes) and fallback (21–100 nodes) layouts.

## Prerequisites
- Sessions 17, 12 complete

## Specification References
- Section 11: Cross-Reference Graph

## ⚠️ Accessibility Open Questions (resolve before this session)
See Specification Section 18:
- Cross-reference graph VoiceOver alternative representation
- Additional Reduce Motion surfaces beyond graph settling animation

## Tasks

### Canvas Renderer
1. Implement `CrossReferenceGraphView` using SwiftUI `Canvas`
2. Implement Bézier curve edge drawing between nodes
3. Implement SF Symbols node icons (`doc.text` or equivalent)
4. Implement three-column layout: [Inbound] → [Central] → [Outbound]

### Standard Layout (≤20 nodes)
5. Implement static vertical distribution algorithm: even spacing in left/right columns, 60pt minimum separation, centered as groups
6. Implement pinch-to-zoom (`MagnificationGesture`) and drag-to-pan (`DragGesture`)

### Fallback Layout (21–100 nodes)
7. Implement force-directed spring layout (~100 lines Swift; no external library):
   - Spring forces between connected nodes
   - Repulsion forces between all nodes
   - Central node pinned to canvas center
   - Iterative relaxation until stable
8. Implement animated settling effect; respect system Reduce Motion setting
9. Implement volume-based clustering (when node count > 30): group nodes from same volume; cluster node expandable on tap/click

### Interaction
10. Implement hover (macOS) and tap (iPadOS/iOS) to show node info panel (document ID, header, dateline)
11. Implement click (macOS) and second-tap (iPadOS/iOS) to navigate to Document view
12. Implement cluster expand/collapse
13. Implement filter toolbar segmented control (project-level / custom / unfiltered)
14. Implement undownloaded volume note banner at top of view
15. Implement "download on navigate" for undownloaded volume nodes

### Accessibility
16. Implement accessibility element overlay for VoiceOver: structured list of inbound/outbound references (per resolved open question)

## Tests
- **StandardLayoutTest**: Graph with 10 nodes; verify all nodes positioned within canvas bounds with ≥60pt vertical separation
- **FallbackLayoutTest**: Graph with 50 nodes; verify force-directed positions are within canvas bounds; verify no node overlap
- **ClusteringTest**: 35 nodes from 3 volumes; verify volume cluster nodes appear
- **ReduceMotionTest**: Mock `accessibilityReduceMotion = true`; verify no animation on layout
- **InteractionTest**: Simulate tap on node; verify info panel appears
- **AccessibilityTest**: Verify VoiceOver accessibility elements present and labeled

## Coding Standards Checklist
- [ ] Force-directed algorithm documented with physics model explanation
- [ ] Reduce Motion handling documented
- [ ] Accessibility overlay documented
- [ ] All strings localized
- [ ] `[CrossReferenceGraph]` log prefix
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 19 — AI Summarization — Core

## Goal
Implement the `SummarizationProvider` protocol, the Apple Intelligence default implementation, and the chunking-and-synthesis pipeline for long documents.

## Prerequisites
- Sessions 04, 06 complete

## Specification References
- Section 10: AI Summarization

## Key Types

```swift
/// SummarizationProvider defines the interface any AI backend must satisfy.
/// Current default: Apple Intelligence via FoundationModels.
/// To add a provider: implement this protocol and add a Settings option.
/// No call sites change when a new provider is added.
protocol SummarizationProvider: Actor {
    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPrompt
    ) async throws -> SummarizationResult
    
    var isAvailable: Bool { get }
    var contextWindowTokenLimit: Int { get }
}

struct SummarizationRequest: Sendable {
    let documentId: String
    let volumeId: String
    let chunks: [String]       // pre-chunked document text; single element if fits in context
    let isSynthesisPass: Bool  // true when combining chunk summaries
}

struct SummarizationResult: Sendable {
    let text: String
    let responseFormat: ResponseFormat
    let wasChunked: Bool
}
```

### Apple Intelligence Provider
```swift
/// AppleIntelligenceProvider wraps FoundationModels.LanguageModelSession.
/// Uses @Generable for structured output when ResponseFormat is .structured.
/// Availability is checked at runtime — devices without Apple Intelligence
/// support receive isAvailable == false and summarization is disabled gracefully.
actor AppleIntelligenceProvider: SummarizationProvider { ... }
```

### Chunking Pipeline
```swift
/// SummarizationService manages the full summarization lifecycle:
/// token estimation → chunking → per-chunk summarization → synthesis.
/// The chunking pipeline is provider-agnostic; all providers benefit automatically.
actor SummarizationService {
    func summarize(
        documentId: String,
        volumeId: String,
        prompt: SummarizationPrompt,
        provider: any SummarizationProvider
    ) async throws -> GeneratedSummary
    
    private func chunk(text: String, maxTokens: Int) -> [String]
    private func synthesize(partialSummaries: [String], prompt: SummarizationPrompt) async throws -> String
}
```

## Tasks
1. Implement `SummarizationProvider` protocol
2. Implement `AppleIntelligenceProvider` using `FoundationModels.LanguageModelSession`
3. Implement `@Generable`-based structured output for `ResponseFormat.structured`
4. Implement availability check and graceful degradation path
5. Implement token estimation (character-based heuristic acceptable; document the approximation)
6. Implement semantic chunking at TEI structural boundaries (paragraph, section breaks from AST)
7. Implement per-chunk summarization loop
8. Implement synthesis pass
9. Persist result as `GeneratedSummary` in SwiftData with `wasChunked` flag and active `projectId`

## Tests
- **ProviderAvailabilityTest**: Mock unavailable device; verify `isAvailable == false`; verify no crash
- **ShortDocumentTest**: Document fitting in context window; verify single-pass summarization; `wasChunked == false`
- **LongDocumentChunkingTest**: Document exceeding context window; verify chunking occurs; verify synthesis pass called; `wasChunked == true`
- **StructuredOutputTest**: Structured prompt; verify result text conforms to schema field structure
- **PersistenceTest**: Completed summary; verify `GeneratedSummary` saved to SwiftData with correct fields

## Coding Standards Checklist
- [ ] Provider protocol documented with extension instructions for future providers
- [ ] Chunking algorithm documented with TEI boundary rationale
- [ ] Token estimation approximation documented
- [ ] `[SummarizationService]` log prefix
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 20 — AI Summarization — UI & Prompts

## Goal
Implement the summarization prompt management UI, schema template selection, and Document view integration for summaries.

## Prerequisites
- Sessions 19, 12, 15 complete

## Specification References
- Section 10: AI Summarization (schema templates, standard prompts)

## ⚠️ Placeholders (resolve before this session)
See Specification Section 23:
- Structured prompt schema template content (6 templates)
- Standard summarization prompt text

## Tasks
1. Implement prompt management UI: view standard prompts, create/edit user prompts, view summary counts per prompt
2. Implement schema template selector in prompt creation flow: 6 pre-defined templates + "Start from scratch"
3. Implement `StructuredSummarySchema` builder UI (add/remove/rename fields)
4. Implement Document view summary panel: active summary display, control to view other summaries for this document
5. Implement summary generation trigger from Document view
6. Implement `wasChunked` indicator in summary display (subtle label for long-document summaries)
7. Implement summary → research note promotion (select summary in note editor)

## Tests
- **PromptCreationTest**: Create user prompt; verify saved to SwiftData
- **TemplateSelectionTest**: Select template; verify fields pre-populated in schema builder
- **SummaryDisplayTest**: Document with multiple summaries; verify active summary displayed; verify control to view others works
- **PromotionTest**: Select summary in note editor; verify text inserted into note body

## Coding Standards Checklist
- [ ] All strings localized
- [ ] Standard prompt placeholder clearly marked in code comments
- [ ] `[SummarizationUI]` log prefix
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 21 — Background Summarizer

## Goal
Implement the background summarization service that processes volumes or document scopes concurrently, with Settings integration and non-modal completion notification.

## Prerequisites
- Sessions 19, 20 complete

## Specification References
- Section 10: AI Summarization — Background Summarizer

## ⚠️ Placeholder (resolve before this session)
Standard summarization prompt text must be provided (used as default for background summarization scope).

## Tasks
1. Implement `BackgroundSummarizationService` actor with scope definition (subseries, volume, subject tag, date range)
2. Implement concurrent summarization task queue (respect user-configured concurrency limit)
3. Implement exponential backoff retry on `LanguageModelSession` rate limit errors
4. Implement progress tracking: documents processed / total
5. Implement non-modal completion notification (system notification or in-app banner)
6. Wire into Settings screen: scope configuration UI, start/stop controls, progress display
7. Implement "already summarized" skip logic (don't re-summarize if summary exists for this prompt)

## Tests
- **ScopeResolutionTest**: Scope by volume; verify correct document IDs resolved
- **RateLimitRetryTest**: Mock rate limit error; verify retry with backoff; verify eventual success
- **SkipExistingTest**: Summary already exists; verify document skipped
- **CompletionNotificationTest**: Background summarization completes; verify notification triggered

## Coding Standards Checklist
- [ ] Backoff strategy documented
- [ ] `[BackgroundSummarizer]` log prefix
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 22 — Collection Editor & Export

## Goal
Implement the collection management interface and export pipeline (PDF and HTML).

## Prerequisites
- Sessions 04, 12, 14 complete

## Specification References
- Section 14: Collection Export
- Section 16: User Experience — Collection Editor

## Tasks

### Collection Editor
1. Implement collection list view (project-scoped or global)
2. Implement collection detail: optional note, reorderable document list
3. Implement document selection: associate existing research note, create new note, or none
4. Implement "Add more documents" control: user tag selector → append unincluded tagged documents
5. Implement sort by date button
6. Cross-project collection indicator (same pattern as research notes)

### Export Pipeline
7. Implement `CollectionExporter` protocol with `ExportFormat` enum (`.pdf`, `.html`, `.docx` as future hook)
8. Implement `PDFCollectionExporter` using PDFKit:
   - Collection name and note
   - Linked document list (internal PDF links)
   - Full rendered documents with preceding research notes
   - Professional typography
9. Implement `HTMLCollectionExporter`:
   - Self-contained single HTML file with embedded CSS
   - Internal anchor links
   - Professional CSS typography
10. Implement share sheet presentation on export completion

## Tests
- **CollectionCreationTest**: Create collection; add documents; verify saved to SwiftData
- **DocumentNoteAssociationTest**: Associate research note with collection document; verify stored
- **AddByTagTest**: Add documents via user tag; verify correct documents appended, duplicates skipped
- **SortByDateTest**: Unsorted collection; sort by date; verify `sortOrder` updated
- **PDFExportTest**: Export fixture collection; verify PDF data non-nil; verify internal links present
- **HTMLExportTest**: Export fixture collection; verify HTML string contains collection name, document headers, and anchor links

## Coding Standards Checklist
- [ ] `CollectionExporter` protocol documented with DOCX future extension note
- [ ] All strings localized
- [ ] `[CollectionExport]` log prefix
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 23 — NARA Source Explorer

## Goal
Implement the Source Explorer sheet with source note parsing, provenance-based switching, and NARA Catalog API integration.

## Prerequisites
- Session 12 complete (Document view trigger point)

## ⚠️ Session Prerequisite — ACTION REQUIRED
Source note format patterns and multi-era examples must be provided before this session begins. Examples should span different historical eras with different formatting conventions. See Specification Section 23, Placeholder #3.

Also: review current NARA Catalog API documentation (archives.gov/research/catalog/help/api) at session start.

## Key Types

```swift
/// SourceNoteParser attempts to identify provenance type and extract
/// structured metadata from FRUS source note strings.
/// Patterns are attempted from most-specific to most-general.
/// On no match, returns .unrecognized with the raw source note text.
struct SourceNoteParser {
    func parse(_ sourceNote: String) -> ParsedSourceNote
}

enum ParsedSourceNote: Sendable {
    case centralFiles(recordGroup: String, fileIdentifier: String)
    case lotFile(lotNumber: String, fileIdentifier: String?)
    case presidentialLibrary(library: String, collection: String, fileIdentifier: String?)
    case foreignGovernmentArchive(description: String)
    case previouslyPublished(citation: String)
    case unrecognized(rawText: String)
}

/// NARACatalogClient performs API queries using the user's stored API key.
actor NARACatalogClient {
    func resolveRG59CentralFiles(fileIdentifier: String) -> URL  // static URL, no API call
    func resolveLotFile(lotNumber: String) async throws -> NARACatalogResult?
    func resolvePresidentialLibrary(library: String, collection: String) async throws -> NARACatalogResult?
}
```

## Tasks
1. Implement `SourceNoteParser` with multi-pattern matching (patterns provided at session start)
2. Implement `NARACatalogClient` with NARA API authentication (key from `KeychainStore`)
3. Implement `SourceExplorerView` sheet with provenance switching per Specification Section 13 table
4. Implement RG-59 central files resolution (static URL mapping; no API call)
5. Implement lot file NARA Catalog API query and result display
6. Implement Presidential Library NARA Catalog API query and result display
7. Implement no-API-key state: prompt with explanation and Settings link
8. Implement unrecognized pattern state: raw text with explanation

## Tests
- **ParserTest**: Fixture source note strings for each provenance type; verify correct `ParsedSourceNote` returned
- **MultiEraTest**: Source notes from different eras with different conventions; verify parser handles all
- **NoMatchTest**: Unrecognizable source note; verify `.unrecognized` returned gracefully
- **APIKeyAbsenceTest**: No API key stored; verify API-dependent views show prompt
- **CentralFilesURLTest**: Known RG-59 file identifier; verify correct NARA URL constructed

## Coding Standards Checklist
- [ ] Pattern matching strategy documented (most-specific to most-general)
- [ ] NARA API authentication documented
- [ ] `[SourceExplorer]` log prefix
- [ ] All strings localized
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 24 — Settings Screen

## Goal
Implement the complete Settings screen with all panels specified in Section 16.

## Prerequisites
- Sessions 05, 09, 21, 23 complete (all services the Settings screen controls)

## Specification References
- Section 16: User Experience — Settings Screen
- Section 9: Search & Indexing (storage management, reindex)

## Tasks
1. **Volume management panel**: concurrent download limit picker, active downloads list with cancel, downloaded volumes list with delete, download undownloaded volumes, check for new volumes (re-fetch live manifest)
2. **Storage management panel**: aggregate and per-volume storage display, delete actions, iCloud Backup exclusion explanation
3. **Sideload panel**: document picker (XML files), schema validation, error messages for non-FRUS/schema errors/duplicates
4. **Reindex panel**: trigger full reindex with progress display
5. **User tag management panel**: list, rename, delete, merge tags
6. **Summarization prompts panel**: standard prompts (read-only), user prompts (edit/delete), summary counts, summaries list with document links, background summarization trigger with scope configuration
7. **NARA API key panel**: entry field, save to `KeychainStore`, clear action
8. **Reset panel**: restore to initial state with double-confirmation

## Tests
- **SideloadValidationTest**: Sideload valid FRUS XML; verify accepted. Sideload non-XML; verify rejected with correct error. Sideload invalid FRUS XML; verify schema error message.
- **StorageReportDisplayTest**: Verify storage panel shows correct values from `DownloadManager.storageReport()`
- **ReindexTriggerTest**: Trigger reindex from Settings; verify `IndexingPipeline.indexAllVolumes()` called
- **NARAPIKeyTest**: Enter key in Settings; verify stored via `KeychainStore`; verify retrievable

## Coding Standards Checklist
- [ ] All strings localized
- [ ] `[Settings]` log prefix
- [ ] Accessibility: all settings controls labeled
- [ ] Swift 6 strict concurrency: zero warnings
