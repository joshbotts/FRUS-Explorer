# Session 04 — SwiftData Models & CloudKit Sync

## Goal
Define all SwiftData model types and configure CloudKit sync. This session establishes the complete data model that all subsequent sessions read from and write to.

## Prerequisites
- Session 01 complete

## Specification References
- Section 5: Data Architecture
- Section 15: Project & Global Context
- Section 22: Coding Standards

## Outputs
- All `@Model` types in `Models/` group
- CloudKit container configuration
- iCloud Keychain access group setup

## SwiftData Models to Implement

Implement all models defined in Specification Section 5, with these implementation notes:

### General Requirements
- Every model carries `lastModified: Date?` (must be updated **explicitly at the call site** whenever a mutation occurs — `didSet`/`willSet` observers are syntactically accepted by `@Model` but are unreliable because the macro transforms stored properties to computed properties; do not rely on them for `lastModified` housekeeping)
- Every model carries `createdAt: Date` (set at initialization, never mutated)
- All `UUID` primary keys generated at initialization
- All array properties that map to CloudKit use appropriate relationship types

### `Project`
```swift
/// A Project is an activity lens, not a content container.
/// It tags the user's activity (notes, summaries, collections, reading history)
/// rather than owning documents. Multiple projects can tag the same activity record.
/// The activeProjectId in AppState determines which project lens is currently active.
@Model final class Project { ... }
```

### `ResearchNote`
```swift
/// A user annotation on a FRUS document.
/// projectIds carries one or more project tags applied at creation and
/// subsequently managed by the user. The note remains associated with
/// its creation project in the app's activity tracking regardless of
/// whether the project tag is later removed.
@Model final class ResearchNote { ... }
```

### `GeneratedSummary`, `UserTag`, `Collection`, `CollectionEntry`, `ReadingHistoryEntry`, `SummarizationPrompt`
Implement per Specification Section 5.

### `StructuredSummarySchema`
```swift
/// Defines the field structure for a structured summarization prompt.
/// Used with ResponseFormat.structured to enforce schema-conformant AI output.
struct StructuredSummarySchema: Codable, Sendable {
    struct Field: Codable, Sendable {
        let name: String
        let description: String
    }
    let fields: [Field]
}
```

### `ResponseFormat`
```swift
enum ResponseFormat: Codable, Sendable {
    case general
    case structured(schema: StructuredSummarySchema)
}
```

## CloudKit Configuration
- Configure `ModelContainer` with CloudKit `containerIdentifier`
- Enable CloudKit sync for all model types
- Verify sync works in simulator with two accounts

## iCloud Keychain
- Define the shared Keychain access group identifier
- Implement `KeychainStore` — a simple wrapper for reading/writing the NARA API key:
```swift
/// KeychainStore manages encrypted credential storage in the iCloud Keychain.
/// The NARA Catalog API key is stored here and synced across the user's devices
/// via the shared Keychain access group defined in the app's entitlements.
actor KeychainStore {
    func setNARACatalogAPIKey(_ key: String) throws
    func getNARACatalogAPIKey() throws -> String?
    func deleteNARACatalogAPIKey() throws
}
```

## Tests
- **ModelInitializationTest**: Each model type initializes with correct defaults
- **LastModifiedTest**: `lastModified` advances when explicitly assigned at the call site (do not test via property mutation — `didSet` is unreliable in `@Model` classes)
- **ResponseFormatCodingTest**: `ResponseFormat` round-trips through `Codable` correctly for both cases
- **KeychainStoreTest**: Set, get, and delete the NARA API key via `KeychainStore`

## Coding Standards Checklist
- [ ] All model types documented with their role in the project
- [ ] `lastModified` explicit-update pattern documented (set at call site, not via observer)
- [ ] `[SwiftData]` prefix on `#if DEBUG` model operation logs
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 05 — Volume Download & Storage Manager

## Goal
Implement the download pipeline for FRUS volumes from GitHub, including concurrent downloads, offline queue management, progress tracking, and storage reporting.

## Prerequisites
- Sessions 01, 02, 04 complete

## Specification References
- Section 6: Volume Manifest (live manifest fetch)
- Section 9: Search & Indexing (storage transparency)
- Section 16: User Experience (onboarding download initiation, offline behavior)

## Key Types

### `DownloadManager`
```swift
/// DownloadManager coordinates all volume download activity.
/// It fetches the live GitHub manifest at launch, manages a concurrent
/// download queue (respecting the user-configured concurrency limit),
/// and persists a download queue to UserDefaults for offline resumption.
///
/// All volumes < 20,000 bytes (per GitHub API) are excluded automatically.
/// Downloads resume on next launch when the device comes online.
actor DownloadManager {
    func fetchLiveManifest() async throws -> [GitHubVolumeEntry]
    func diffManifests(live: [GitHubVolumeEntry], bundled: [VolumeManifestEntry]) -> ManifestDiff
    func enqueueDownload(volumeId: String) async
    func cancelDownload(volumeId: String) async
    func deleteVolume(volumeId: String) async throws
    func storageReport() async throws -> StorageReport
}
```

### `StorageReport`
```swift
struct StorageReport: Sendable {
    let totalVolumesBytes: Int
    let totalIndexBytes: Int
    let totalSummariesBytes: Int
    let perVolume: [VolumeStorageEntry]
}
```

## Tasks
1. Implement live manifest fetch from GitHub API
2. Implement manifest diff logic (`ManifestDiff` type)
3. Implement concurrent download queue (URLSession background downloads; respect concurrency limit from Settings; default 4)
4. Implement offline detection and queue persistence (UserDefaults)
5. Implement volume file storage in Application Support
6. Implement `deleteVolume` — removes XML file and triggers index cleanup (hook for Session 09)
7. Implement `StorageReport` computation
8. Update `FRUS-API.openapi.yaml` with `GET /volumes/{volumeId}/download` endpoint note

## Tests
- **LiveManifestFetchTest**: Mock GitHub API response; verify decoding and 20kb filter
- **ManifestDiffTest**: Fixture-based diff tests covering all three cases (both, live-only, bundled-only)
- **ConcurrencyLimitTest**: Verify no more than N simultaneous downloads occur
- **OfflineQueueTest**: Enqueue downloads offline; verify queue persists; verify resumption mock
- **StorageReportTest**: Create fixture volume files; verify `StorageReport` sums correctly

## Coding Standards Checklist
- [ ] `[DownloadManager]` prefix on `#if DEBUG` logs
- [ ] Offline queue persistence documented
- [ ] `FRUS-API.openapi.yaml` updated
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 06 — TEI Parser — Core Elements

## Goal
Implement the first two layers of the TEI rendering pipeline: XML Parser → Swift AST, and AST → Rendering Model, covering the core FRUS TEI elements needed to make the Document view functional.

## Prerequisites
- Session 01 complete
- **Edge case fixture documents must be assembled before this session** (see Specification Section 7)

## Specification References
- Section 7: TEI Rendering
- Section 22: Coding Standards

## Scope — Core Elements
This session covers the elements needed for a functional Document view:
- `<div type="document">` — document container
- `<head>` — document header
- `<dateline>` — dateline
- `<opener>`, `<closer>`, `<salute>` — letter elements
- `<p>` — paragraphs
- `<note>` — footnotes (various types)
- `<gloss>` — glossary references (link to Terms list)
- `<persName>` — person name references (link to List of Persons)
- `<ref>` — cross-references (extract target, store for Session 17)
- `<hi>` — typographic emphasis (italic, bold, smallcaps)
- `<term>` — technical terms

Full element coverage (tables, lists, editorial notes, appendices) is deferred to Session 07.

## Key Types

### `FRUSDocumentAST`
```swift
/// The Swift AST representation of a parsed FRUS TEI document.
/// Each node corresponds to a TEI element defined in FRUS.odd.
/// Unknown elements are preserved as .unknown nodes — never dropped.
/// This ensures forward compatibility when new elements are added to the schema.
indirect enum FRUSASTNode: Sendable {
    case document(id: String, attributes: [String: String], children: [FRUSASTNode])
    case head(children: [FRUSASTNode])
    case dateline(text: String)
    case paragraph(children: [FRUSASTNode])
    case footnote(id: String?, type: FootnoteType, children: [FRUSASTNode])
    case persName(ref: String?, children: [FRUSASTNode])
    case gloss(ref: String?, children: [FRUSASTNode])
    case crossReference(target: String, targetVolumeId: String?, children: [FRUSASTNode])
    case emphasis(style: EmphasisStyle, children: [FRUSASTNode])
    case text(String)
    case unknown(name: String, attributes: [String: String], children: [FRUSASTNode])
}
```

### `FRUSDocumentParser`
```swift
/// FRUSDocumentParser converts a FRUS volume XML file into a Swift AST.
/// Implemented as a streaming SAX-style parser using Foundation's XMLParser.
///
/// Whitespace handling: inter-element whitespace is normalized (collapsed to
/// single space or dropped at block boundaries). Inline whitespace within
/// text content is preserved.
///
/// Deep nesting: the parser uses an explicit stack rather than recursion
/// to handle the deep element nesting found in older FRUS volumes without
/// stack overflow risk.
actor FRUSDocumentParser {
    func parse(volumeURL: URL) async throws -> [FRUSDocumentAST]
    func parseDocument(documentId: String, volumeURL: URL) async throws -> FRUSDocumentAST?
}
```

### `TEIRenderingConfig`
```swift
/// Loaded from the bundled tei-rendering-config.json.
/// Maps TEI element names to rendering behaviors.
/// Updated when FRUS.odd changes; no code changes required for most schema updates.
struct TEIRenderingConfig: Codable, Sendable {
    struct ElementBehavior: Codable, Sendable {
        let elementName: String
        let renderAs: RenderBehavior
        let preserveWhitespace: Bool
    }
    let elements: [ElementBehavior]
    let schemaVersion: String    // tracks which FRUS.odd version this config targets
}
```

## Tasks
1. Implement `FRUSASTNode` enum with all core element cases
2. Implement `FRUSDocumentParser` using `XMLParser` in streaming mode with explicit element stack
3. Implement whitespace normalization rules (document these thoroughly)
4. Implement `TEIRenderingConfig` loading from bundle
5. Implement AST → Rendering Model conversion for core elements
6. Implement basic SwiftUI renderer (Layer 3) for core elements — sufficient for Document view
7. Implement `<persName>` → List of Persons lookup (returns a `PersonEntry?`)
8. Implement `<gloss>` → Terms and Abbreviations lookup
9. Implement `<ref>` target extraction (stored for Session 17; not yet rendered as graph)
10. Create `tei-rendering-config.json` with core element mappings

## Tests
- **ParseCoreElementsTest**: Parse fixture documents containing each core element; verify AST structure
- **WhitespaceTest**: Parse documents with leading/trailing/inter-element whitespace; verify normalization
- **DeepNestingTest**: Parse fixture documents with deep hierarchy; verify correct AST without stack overflow
- **UnknownElementTest**: Parse document with an unknown element; verify `.unknown` node preserved, no crash
- **PersNameLookupTest**: Verify `<persName ref="...">` resolves to the correct `PersonEntry`
- **CrossReferenceExtractionTest**: Verify `<ref>` targets are correctly extracted from parsed AST
- **RenderingConfigLoadTest**: Verify `tei-rendering-config.json` loads and decodes correctly

## Coding Standards Checklist
- [ ] `[TEIParser]` prefix on `#if DEBUG` logs
- [ ] Whitespace normalization rules documented
- [ ] Deep nesting stack approach documented
- [ ] Unknown element handling documented (forward compatibility rationale)
- [ ] `FRUS-API.openapi.yaml` updated with `GET /volumes/{volumeId}/documents/{documentId}`
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 07 — TEI Parser — Full Element Coverage

## Goal
Extend the TEI parser from Session 06 to cover all FRUS TEI elements, with particular attention to the known edge cases in tables, lists, and deep nesting documented in the fixture set.

## Prerequisites
- Session 06 complete
- Edge case fixture documents assembled (required before Session 06; same fixtures used here)

## Specification References
- Section 7: TEI Rendering (full element coverage, edge case fixtures)

## Additional Elements to Cover
- `<pb>` — page breaks; surfaced in AST as `pageBreak(pageNumber: PageNumber)` with normalized `@n` attribute; required by Session 30 (Citation Lookup) for page range resolution. `PageNumber` enum: `.arabic(Int)`, `.roman(Int)`, `.prefixed(String)`, `.unparseable(String)`. Normalization rules: strip leading zeros; parse Roman numerals; preserve prefixed forms; log warning for unparseable values; never drop the element.
- `<table>`, `<row>`, `<cell>` — tables (all known variant structures)
- `<list>`, `<item>` — lists (all known variant structures)
- `<div type="editorialNote">` — editorial notes
- `<div type="compilation">`, `<div type="chapter">` — structural divisions
- `<figure>`, `<graphic>` — images (display as placeholder if no image data available)
- `<formula>` — mathematical or chemical formulas
- `<supplied>`, `<sic>`, `<corr>` — editorial correction elements
- `<lb>` — line breaks
- Front matter elements: `<titlePage>`, `<div type="preface">`, `<div type="contents">`
- Back matter elements: `<div type="index">`, `<div type="appendix">`
- List of Persons: `<div type="persons">` parser (already needed by Session 06 lookups)
- Terms and Abbreviations: `<div type="terms">` parser

## Edge Case Requirements
Using the assembled fixture documents, implement and test:
- Tables with merged cells (`@rows`, `@cols` spanning attributes)
- Tables with missing cells
- Nested lists
- Lists within table cells
- Elements with mixed content (text and element children interleaved)
- Documents with both old deep-hierarchy and new flat-hierarchy structure

## Tests
- Fixture-based tests for every element added this session
- Edge case tests for each documented table/list inconsistency
- Regression tests: all Session 06 tests must continue to pass

## Additional Tests (Session 07)
- **PageBreakArabicTest**: Parse `<pb n="47"/>`; verify `.arabic(47)` returned
- **PageBreakRomanTest**: Parse `<pb n="iv"/>`; verify `.roman(4)` returned
- **PageBreakPrefixedTest**: Parse `<pb n="A-12"/>`; verify `.prefixed("A-12")` returned
- **PageBreakUnparseableTest**: Parse `<pb n="??"/>`; verify `.unparseable("??")` returned and warning logged; no crash

## Coding Standards Checklist
- [ ] All new AST node cases documented
- [ ] `<pb>` normalization rules documented with reference to Session 31 dependency
- [ ] Edge case handling documented with reference to fixture source
- [ ] `tei-rendering-config.json` updated with new element mappings
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 08 — Subject Tag Bundle Integration
**Updated**: 2026-05-14 — Removed abstract substitution task; added VolumeLevelTagStore for volume-level tags

## Goal
Load and integrate two distinct tag systems:

1. **Volume-level tags** (`VolumeLevelTagStore`) — resolves tag slugs from `manifest.json` against the bundled `volume-tag-taxonomy.json`. Used by the Browser view and onboarding volume picker for browsing and filtering volumes by tag.

2. **Document-level subject tags** (`SubjectTagStore`) — loads the experimental subject taxonomy and document-appearance data from `taxonomy.json` and `subject-appearances.json`. Used by the Document view and Search view to tag and filter individual documents.

These two systems are architecturally distinct and serve different UI surfaces. See SPEC-UPDATE-Manifest-Tags.md for the full comparison.

## Prerequisites
- Session 02 complete (manifest.json and volume-tag-taxonomy.json generated and bundled)
- Session 04 complete (SwiftData models)
- Bundled `taxonomy.json` and `subject-appearances.json` populated with current pipeline output

## Specification References
- SPEC-UPDATE-Manifest-Tags.md (volume-level tags, updated Section 8)
- Original Section 8: Subject Tag Data (document-level tags, unchanged)

## Key Types

### Volume-Level Tag Types (from Session 02 — confirm already defined)
`VolumeLevelTag`, `TagCategory`, and `TagTaxonomyEntry` are defined in Session 02.
This session implements `VolumeLevelTagStore`.

### `VolumeLevelTagStore`
```swift
/// VolumeLevelTagStore resolves volume-level tag slugs from the manifest
/// against the bundled volume-tag-taxonomy.json.
///
/// Volume-level tags are authoritative (sourced from published TEI headers
/// curated by OH staff) and carry no confidence distinction.
///
/// Used by: Browser view subseries/volume levels, onboarding volume picker.
/// Distinct from SubjectTagStore (document-level, experimental pipeline).
///
/// Version history:
///   1.0 — Session 08: initial implementation
actor VolumeLevelTagStore {
    func load() async throws
    func tag(forSlug: String) -> VolumeLevelTag?
    func tags(forSlugs: [String]) -> [VolumeLevelTag]
    func allTags() -> [VolumeLevelTag]
    func allTags(inCategory: TagCategory) -> [VolumeLevelTag]
    func allTags(inSubcategory: String) -> [VolumeLevelTag]
    /// Returns volumeIds for all volumes carrying this tag slug.
    /// Derived from manifest.json at load time.
    func volumes(forTagSlug: String) -> [String]
    /// AND logic: returns volumeIds carrying ALL of the provided tag slugs.
    func volumes(forTagSlugs: [String]) -> [String]
}
```

### Document-Level Subject Tag Types (unchanged)
```swift
/// A subject tag from the experimental FRUS subject taxonomy pipeline.
/// Confidence distinguishes editorially reviewed (curated) annotations
/// from automated string-match annotations.
///
/// Distinct from VolumeLevelTag (volume-level, authoritative, no confidence):
///   - SubjectTag: per-document, experimental, confidence .curated | .stringMatch
///   - VolumeLevelTag: per-volume, authoritative, no confidence distinction
///
/// Future migration: when subject tags are incorporated natively into FRUS TEI
/// as <rs> elements, this type is populated from the parsed AST instead of
/// the bundle. The type itself and all call sites remain unchanged.
///
/// Version history:
///   1.0 — Session 08: initial implementation
struct SubjectTag: Identifiable, Sendable {
    let id: String
    let name: String
    let category: String
    let lcshUri: URL?
    let broaderTermId: String?
    let confidence: SubjectTagConfidence
}

enum SubjectTagConfidence: String, Sendable {
    case curated      // reviewed annotation XML (11 volumes, 1969–1988)
    case stringMatch  // automated string-match (remaining ~540 volumes)
}
```

### `SubjectTagStore`
```swift
/// SubjectTagStore loads the bundled taxonomy and appearance data at launch
/// and provides efficient lookup by document ID, subject ID, and category.
///
/// The store is read-only at runtime — all data comes from the bundle.
/// Updates require an app release with a new bundle.
///
/// Version history:
///   1.0 — Session 08: initial implementation
actor SubjectTagStore {
    func load() async throws
    func tags(forDocumentId: String, volumeId: String) -> [SubjectTag]
    func documents(forSubjectId: String) -> [(documentId: String, volumeId: String)]
    func allSubjects() -> [SubjectTag]
    func subject(id: String) -> SubjectTag?
    func subjects(inCategory: String) -> [SubjectTag]
}
```

## Tasks

### Volume-Level Tags
1. Implement `VolumeLevelTagStore` actor loading from `volume-tag-taxonomy.json`
2. Build efficient in-memory indexes: by slug, by category, by subcategory
3. Build volume-by-tag index at load time by scanning `manifest.json` tag arrays
4. Implement `volumes(forTagSlugs:)` with AND logic (intersection of per-tag volume sets)
5. Implement graceful handling of slugs present in manifest but absent from taxonomy (return nil, log warning — taxonomy may occasionally lag behind newly published volumes)
6. Wire `VolumeLevelTagStore` into `AppState` (loaded at startup alongside `SubjectTagStore`)

### Document-Level Subject Tags
7. Implement `SubjectTag` and `SubjectTagConfidence` types
8. Implement `SubjectTagStore` actor with bundle loading of `taxonomy.json` and `subject-appearances.json`
9. Implement efficient in-memory indexes: by documentId, by subjectId, by category
10. Wire `SubjectTagStore` into `AppState` (loaded at startup)

## Tests

### Volume-Level Tag Tests
- **TaxonomyLoadTest**: `volume-tag-taxonomy.json` loads without error
- **SlugResolutionTest**: Known slugs resolve to correct displayName, category, subcategory
- **UnknownSlugTest**: Slug absent from taxonomy returns nil gracefully, no crash
- **VolumesByTagTest**: Known tag slug; verify correct volumeIds returned from manifest data
- **VolumesByMultipleTagsTest**: Two slugs; verify AND logic (only volumes with both tags)
- **CategoryFilterTest**: `allTags(inCategory: .places)` returns only place tags
- **SubcategoryFilterTest**: `allTags(inSubcategory: "near-east")` returns only Near East tags

### Document-Level Subject Tag Tests
- **BundleLoadTest**: `taxonomy.json` and `subject-appearances.json` load without error
- **DocumentTagLookupTest**: Fixture-based; correct tags returned for known document IDs
- **ConfidenceTierTest**: Curated and string-match documents return correct confidence values
- **SubjectCategoryFilterTest**: `subjects(inCategory:)` returns only subjects in that category

## Coding Standards Checklist
- [ ] `VolumeLevelTagStore` documented: distinction from `SubjectTagStore` explicitly noted
- [ ] `SubjectTag.confidence` documented with migration path note
- [ ] Unknown slug handling documented (graceful, with warning log)
- [ ] AND logic for `volumes(forTagSlugs:)` documented
- [ ] `[VolumeLevelTagStore]` and `[SubjectTagStore]` log prefixes
- [ ] Swift 6 strict concurrency: zero warnings
