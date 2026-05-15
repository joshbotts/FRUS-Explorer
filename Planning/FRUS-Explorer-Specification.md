# FRUS Explorer — Full Development Specification

**Version**: 2.0  
**Date**: 2026-05-14  
**Status**: Approved for development

*Version 2.0 consolidates all updates from the planning session into a single authoritative document. The separate SPEC-UPDATE-Manifest-Tags.md patch document is now superseded and archived.*

---

## Table of Contents

1. [Application Purpose](#1-application-purpose)
2. [Definitions](#2-definitions)
3. [Platform & Toolchain](#3-platform--toolchain)
4. [Architecture Overview](#4-architecture-overview)
5. [Data Architecture](#5-data-architecture)
6. [Volume Manifest](#6-volume-manifest)
7. [TEI Rendering](#7-tei-rendering)
8. [Subject Tag Data](#8-subject-tag-data)
9. [Search & Indexing](#9-search--indexing)
10. [AI Summarization](#10-ai-summarization)
11. [Cross-Reference Graph](#11-cross-reference-graph)
12. [Citation Formatter](#12-citation-formatter)
13. [NARA Source Explorer](#13-nara-source-explorer)
14. [Collection Export](#14-collection-export)
14b. [Citation Lookup](#14b-citation-lookup)
15. [Project & Global Context](#15-project--global-context)
16. [User Experience](#16-user-experience)
17. [App Identity & Distribution](#17-app-identity--distribution)
18. [Accessibility](#18-accessibility)
19. [Localization](#19-localization)
20. [Telemetry & Analytics](#20-telemetry--analytics)
21. [OpenAPI / Future FRUS API](#21-openapi--future-frus-api)
22. [Coding Standards](#22-coding-standards)
23. [Placeholders Requiring Future Input](#23-placeholders-requiring-future-input)

---

## 1. Application Purpose

FRUS Explorer provides tools on macOS, iPadOS, and iOS to help researchers use the Foreign Relations of the United States (FRUS) series more effectively. Core capabilities include:

- Document-level user notes and tagging
- Expanded search and filtering across the full FRUS corpus
- Cross-reference visualization highlighting linkages between documents
- User-configurable AI summarization prompts
- Linking document source notes to NARA Catalog information
- Composable document collections with export
- Offline functionality with download queue management
- Subject tagging from an experimental taxonomy pipeline
- Citation lookup to locate documents from citations encountered in publications

---

## 2. Definitions

| Term | Definition |
|---|---|
| **FRUS volume** (volume) | Contents of an XML file conforming to the frus.odd schema |
| **FRUS document** (document) | An element of a FRUS volume with `@type="document"` |
| **Collection** (custom collection) | A user-selected compilation of FRUS documents |
| **Research Note** | A user-defined annotation related to a FRUS document |
| **User Tag** | A user-defined label related to one or more FRUS documents |
| **Project** | A user research initiative requiring locating, analyzing, and/or sharing historical information; implemented as an activity lens that tags user actions rather than a container that owns content |
| **Generated Summary** | An LLM's response to a summarization prompt |
| **Subject Tag** | A label applying to one or more FRUS documents, supplied from application-bundled JSON data derived from the experimental subject taxonomy pipeline |
| **Active Project** | The single project currently in focus; stored in AppState and persisted via UserDefaults |
| **Global Context** | The view of all user activity regardless of project tag |
| **Project Context** | The view of user activity filtered to those carrying the active project's tag |

---

## 3. Platform & Toolchain

### Deployment Targets
- **macOS**: 26+
- **iPadOS**: 26+
- **iOS**: 26+

### Package Manager
Swift Package Manager (SPM) exclusively. No CocoaPods or Carthage.

### Swift Version
Swift 6 with strict concurrency enforced throughout. All code must compile without concurrency warnings under Swift 6's complete concurrency checking mode.

### Key Frameworks
- **SwiftUI**: All UI across all platforms; adaptive design with availability checks for platform-specific APIs
- **SwiftData**: Structured user data persistence
- **CloudKit**: Sync backend via SwiftData's CloudKit integration
- **FoundationModels**: Apple Intelligence summarization
- **PDFKit**: PDF export
- **SQLite3**: FTS5 search index via project-written Swift wrapper

### SPM Dependencies
- **Sparkle**: Update delivery for direct distribution macOS build only

---

## 4. Architecture Overview

FRUS Explorer is organized into the following layers, each with a clear boundary and testable interface:

```
┌─────────────────────────────────────────────┐
│                  SwiftUI Views               │
├─────────────────────────────────────────────┤
│              Service Layer                   │
│  (Summarization, Search, Export, Citation,  │
│   NARA Resolution, Download, Indexing)       │
├──────────────────┬──────────────────────────┤
│   SwiftData      │   SQLite FTS5 + Edge DB  │
│  (User Data +    │   (Search Index +        │
│   CloudKit Sync) │    Cross-References)     │
├──────────────────┴──────────────────────────┤
│           TEI Rendering Pipeline             │
│    (XML Parser → Swift AST → SwiftUI)        │
├─────────────────────────────────────────────┤
│           Network & Storage Layer            │
│  (GitHub API, NARA API, Volume Files,        │
│   Manifest, iCloud Keychain)                 │
└─────────────────────────────────────────────┘
```

### Concurrency Model
All network, file I/O, parsing, and indexing operations execute off the main actor. SwiftUI views bind to `@Observable` model objects on the main actor. Service layer types are either actors or isolated via Swift concurrency primitives. The project must compile cleanly under Swift 6 strict concurrency checking at all times — this is a non-negotiable ongoing requirement, not a final cleanup step.

### OpenAPI Living Document
A `FRUS-API.openapi.yaml` file is maintained alongside the codebase. It is updated in each development session wherever a method calls GitHub APIs or locally cached volume data, describing the ideal FRUS API endpoint that could replace that call in the future. See Section 21.

---

## 5. Data Architecture

### SwiftData Models (CloudKit-Synced)

All SwiftData models carry a `lastModified: Date` timestamp for conflict resolution. CloudKit uses last-write-wins; the timestamp ensures this is predictable.

#### Project
```
id: UUID
name: String
researchQuestion: String?
defaultDateRangeStart: Date?
defaultDateRangeEnd: Date?
defaultSubjectTagIds: [String]
defaultCountryTagIds: [String]
createdAt: Date
lastModified: Date
```

#### ResearchNote
```
id: UUID
documentId: String
volumeId: String
bodyText: String
projectIds: [UUID]           // carries one or more project tags
userTagIds: [UUID]
selectedSummaryIds: [UUID]   // summaries promoted to draft content
createdAt: Date
lastModified: Date
```

#### GeneratedSummary
```
id: UUID
documentId: String
volumeId: String
promptId: UUID
responseText: String
responseFormat: ResponseFormat   // .general | .structured(schema:)
wasChunked: Bool
projectId: UUID?                 // project active at generation time
createdAt: Date
lastModified: Date
```

#### UserTag
```
id: UUID
name: String
createdAt: Date
lastModified: Date
```
User tags are global — never project-scoped.

#### Collection
```
id: UUID
name: String
note: String?
projectIds: [UUID]
documentEntries: [CollectionEntry]
createdAt: Date
lastModified: Date
```

#### CollectionEntry
```
id: UUID
collectionId: UUID
documentId: String
volumeId: String
sortOrder: Int
researchNoteId: UUID?
```

#### ReadingHistoryEntry
```
id: UUID
documentId: String
volumeId: String
projectId: UUID?       // project active at time of access; nil = untagged
accessedAt: Date
```

#### SummarizationPrompt
```
id: UUID
name: String
promptText: String
responseFormat: ResponseFormat
isStandard: Bool       // true = shipped with app; false = user-created
schema: StructuredSummarySchema?
createdAt: Date
lastModified: Date
```

### SQLite Database (Local Only)

Stored in Application Support. Excluded from iCloud Backup via `isExcludedFromBackupKey`. Contains two logical components:

**FTS5 Search Index** — full text of all FRUS documents plus generated summaries and research notes, with English stemming tokenizer.

**Cross-Reference Edge Table**
```sql
CREATE TABLE cross_references (
    id INTEGER PRIMARY KEY,
    source_document_id TEXT NOT NULL,
    source_volume_id TEXT NOT NULL,
    target_document_id TEXT NOT NULL,
    target_volume_id TEXT NOT NULL,
    context TEXT,           -- footnote or editorial note text
    reference_type TEXT     -- 'footnote' | 'editorialNote'
);
```

**Page Range Table** — maps `<pb>` page numbers to the documents that contain them. Used by the Citation Lookup feature to resolve page-based citations to document numbers. Section grouping (`section_id`) handles pagination restarts between volume sections.
```sql
CREATE TABLE page_ranges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    volume_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    section_id TEXT NOT NULL,       -- parent compilation or chapter @xml:id
    page_number_type TEXT NOT NULL, -- 'arabic' | 'roman' | 'prefixed'
    page_number_int INTEGER,        -- NULL for non-arabic/roman types
    page_number_raw TEXT NOT NULL   -- always stored for display
);
CREATE INDEX idx_page_ranges_volume ON page_ranges(volume_id, page_number_type, page_number_int);
CREATE INDEX idx_page_ranges_document ON page_ranges(volume_id, document_id);
```

### iCloud Keychain

NARA Catalog API key stored encrypted in a shared Keychain access group, synced across the user's devices via iCloud Keychain sharing. Requires `com.apple.developer.icloud-keychain-sharing` entitlement and a shared access group identifier established during project setup.

### Local Volume Storage

Downloaded and sideloaded FRUS volume XML files stored in Application Support alongside the SQLite database. Not synced. Users manage storage via the Settings screen.

---

## 6. Volume Manifest

### Purpose
Provides rich metadata for all known FRUS volumes to support onboarding, browsing, and download management without requiring the app to parse full volume XML at runtime.

### Two-Layer Design

**Layer 1 — Bundled Manifest** (`manifest.json`, ships with app)

Generated at release time by a Swift command-line tool (SPM executable target) that fetches and parses only the `<teiHeader>` of each volume XML from the HistoryAtState GitHub repository. Committed to the app repository.

Schema per volume entry:
```json
{
  "volumeId": "frus1969-76v01",
  "filename": "frus1969-76v01.xml",
  "subseries": "1969-76",
  "title": "...",
  "dateRange": { "earliest": "1969-01-01", "latest": "1972-12-31" },
  "publicationDate": "2003-01-01",
  "status": "published",
  "editors": ["..."],
  "generalEditor": "...",
  "documentCount": 342,
  "sizeBytes": 4521000,
  "tags": ["iran", "kissinger-henry-a", "arms-control-and-disarmament"]
}
```

The `tags` field contains volume-level subject tag slugs extracted from:
```
/TEI/teiHeader/profileDesc/textClass/keywords[@scheme="https://history.state.gov/tags"]/term
```
These are authoritative OH-curated tags embedded in each volume's published TEI. Slugs resolve against the bundled `volume-tag-taxonomy.json` for display names and hierarchy. An empty array is valid for volumes predating the tagging system.

No abstract field. Volumes are presented to users as a browsable, sortable list — not described by abstracts.

**Layer 2 — Live GitHub Manifest** (fetched at launch when online)

GitHub API call to the HistoryAtState/frus volumes directory. Provides filename, file size (bytes), SHA, and download URL. Volumes under 20kb are excluded from all download functionality.

At launch, the app diffs the live manifest against the bundled manifest:
- Volume present in both → use bundled metadata
- Volume present in live only → display as "newly available" with parsed subseries and a badge; no title, tags, or other rich metadata
- Volume present in bundled only → treat as no longer published; hide from download UI but do not affect already-downloaded volumes

### Volume Tag Taxonomy

The tag slugs in `manifest.json` resolve against a bundled taxonomy file (`volume-tag-taxonomy.json`) that provides:
- Humanized display names (e.g., `kissinger-henry-a` → `Kissinger, Henry A.`)
- Category (`people` | `places` | `topics`)
- Subcategory (e.g., `secretaries-of-state`, `near-east`, `arms-control-and-disarmament`)
- Optional description (where provided on history.state.gov/tags/all)
- Parent tag slug (for hierarchical display)

This taxonomy is derived from history.state.gov/tags/all, which defines a three-level hierarchy:

**People**
- Presidents (chronological)
- Secretaries of State (chronological)

**Places**
- Sovereign Territories (by region: Sub-Saharan Africa, East Asia and Pacific, Europe, Near East, South and Central Asia, Western Hemisphere)
- Dependencies and Areas of Special Sovereignty
- Other (Antarctica, Palestine, disputed territories)

**Topics**
- Arms Control and Disarmament
- Department of State
- Foreign Economic Policy
- Global Issues
- Human Rights
- Information Programs
- International Law
- International Organizations
- Politico-Military Issues
- Science and Technology
- Warfare

The bundled `volume-tag-taxonomy.json` is generated by the `TaxonomyGenerator` SPM executable target, which fetches and parses history.state.gov/tags/all. It is updated manually when the taxonomy changes and committed to the repository. It is small (< 100KB) and changes rarely.

### Volume List UI — Sort and Browse

The volume list (in onboarding and the Browser view) supports two modes:

**Sort by subseries** (default)
Volumes grouped by subseries label in chronological order. This is the primary orientation for most researchers.

**Browse by tag**
A tag picker — searchable, organized by the three-level taxonomy hierarchy (People / Places / Topics → subcategory → tag) — allows the user to select one or more tags. The volume list is filtered to volumes carrying all selected tags. Multi-tag filtering uses AND logic: selecting Iran AND Arms Control shows only volumes tagged with both. Tag display uses humanized names from `volume-tag-taxonomy.json`; tags are organized hierarchically in the picker, not as a flat alphabetical list.

### Generation Tools

**`ManifestGenerator`** — SPM executable target. Parses `<teiHeader>` only (not full document XML) to minimize bandwidth. Run before each app release. Output committed as `Sources/FRUSExplorer/Resources/manifest.json`.

**`TaxonomyGenerator`** — SPM executable target. Fetches and parses history.state.gov/tags/all to produce `Sources/FRUSExplorer/Resources/volume-tag-taxonomy.json`. Run manually when the taxonomy changes, not as part of the regular release process.

### Offline Behavior
If no network is available at launch, the app operates entirely from the bundled manifest. A non-modal indicator notes that the volume list may not reflect the most recent releases.

---

## 7. TEI Rendering

### Approach
A three-layer ODD-informed Swift renderer. The FRUS.odd schema (github.com/historyatstate/frus/schema/frus.odd) governs which elements are recognized and how they map to rendering behaviors. Schema changes require updating the mapping layer configuration; they do not require architectural changes.

### Layer 1: XML Parser → Swift AST

A streaming `XMLParser`-based pass produces a typed Swift AST representing the FRUS document tree. Element types are defined by FRUS.odd. The parser handles:
- Whitespace normalization (leading/trailing/inter-element)
- Deeply nested elements (older volumes with complex hierarchy)
- Flat hierarchy (newer volumes)
- Unknown elements (preserved in AST as `.unknown(name:, attributes:, children:)` — never dropped, never crashes)

**Session prerequisite**: Before the TEI parsing session begins, a fixture set of edge-case documents must be assembled, including:
- Known table and list inconsistency examples from the epub conversion work
- Examples of the deepest nesting patterns in older volumes
- Examples of the flat hierarchy in newer volumes
- Any FRUS-specific TEI extensions or attribute usages differing from standard TEI

### Layer 2: AST → Rendering Model

A mapping layer that converts AST nodes to rendering instructions. Governed by a bundled configuration file (`tei-rendering-config.json`) that defines element-to-behavior mappings. When FRUS.odd changes:
1. Review the ODD diff
2. Add/modify AST cases if new elements were introduced
3. Update the configuration file

Configuration is bundled with the app and updated via app releases. Adequate lead time exists between TEI schema changes and availability of volumes using new elements.

### Layer 3: SwiftUI Renderer

Consumes the rendering model and produces SwiftUI view hierarchies. Platform-adaptive (macOS vs. iPadOS/iOS layout differences handled here). Thin — all logic lives in Layers 1 and 2.

### Rendering Requirements
- All textual content represented faithfully
- All editorial annotation (footnotes, editorial notes, source notes) represented
- `<persName>` elements link to the volume's List of Persons
- `<gloss>` elements link to the volume's Terms and Abbreviations list
- Tables and lists rendered correctly across all known variants
- Rendered output need not be pixel-identical to history.state.gov but must be equivalent in content and editorial annotation

### Development Sequencing
1. **Core elements session**: header, dateline, paragraphs, footnotes, source note, persName, gloss — sufficient for Document view
2. **Full element coverage session**: tables, lists, editorial notes, appendices, all known edge cases
3. **Render quality session**: informed by edge case fixture review

### Vector Embedding Readiness
When FRUS TEI is updated to include vector embedding elements, the AST gains a new case and the rendering layer surfaces the capability (e.g., enabling semantic search) rather than rendering raw embedding data. No architectural changes required.

---

## 8. Subject Tag Data

### Two Tag Systems

FRUS Explorer uses two distinct tag systems serving different purposes at different granularities:

| | Volume-level tags | Document-level subject tags |
|---|---|---|
| Source | TEI `<teiHeader>` (authoritative, published) | Experimental pipeline (bundled JSON) |
| Granularity | Per volume | Per document |
| Coverage | All published volumes | 551 of 560 volumes (string-match); 11 volumes curated |
| Taxonomy | history.state.gov/tags/all (three-level) | 1,375 subjects across 13 categories (LCSH-mapped) |
| UI use | Volume browsing and filtering | Document search filtering and tagging |
| Confidence distinction | Not needed (authoritative) | Required (curated vs. string-match) |

Volume-level tags are described in Section 6. This section covers document-level subject tags.

### Source
Experimental subject taxonomy pipeline maintained in a private GitHub repository at the Office of the Historian, U.S. Department of State.

### Bundled Artifacts

**`taxonomy.json`** — derived from `subject-taxonomy-lcsh.xml`:
```json
{
  "subjects": [
    {
      "id": "...",
      "name": "...",
      "category": "...",
      "lcshUri": "...",
      "variantNames": ["..."],
      "broaderTermId": "..."
    }
  ]
}
```
1,375 subjects across 13 categories with LCSH authority URIs and hierarchical broader-term relationships.

**`subject-appearances.json`** — document-to-subject mappings:
```json
{
  "volumeId": {
    "documentId": [
      { "subjectId": "...", "confidence": "curated" }
    ]
  }
}
```

### Confidence Tiers

| Tier | Source | Volumes | UI Treatment |
|---|---|---|---|
| `.curated` | Reviewed annotation XML | 11 (1969–1988) | Standard subject tag chip |
| `.stringMatch` | String-match results JSON | ~540 | Visually distinct chip + indicator |
| None | 9 index/placeholder volumes | — | No tags displayed |

Color is never the sole distinguishing signal between tiers. A non-color indicator (icon, label, or both — see Section 18 open question) accompanies any visual style difference.

### Data Model
```swift
// SubjectTag carries confidence from day one to support both
// the experimental bundle path and the future TEI-native path.
struct SubjectTag {
    let id: String
    let name: String
    let category: String
    let lcshUri: String?
    let confidence: SubjectTagConfidence  // .curated | .stringMatch
}
```

### Future Migration Path
When subject tags are incorporated natively into FRUS TEI as `<rs>` elements, the TEI parser reads them directly from the AST. The bundled artifact is retired. This is designed as a single localized change to the data source resolution logic — the `SubjectTag` type and all call sites remain unchanged.

### Update Cadence
Bundled with app releases during the experimental period. No live fetch of subject tag data.

---

## 9. Search & Indexing

### Technology
SQLite FTS5 accessed via a project-written, well-documented thin Swift wrapper (`FTS5Store`). The wrapper is a first-class documented component designed for reuse outside FRUS Explorer.

### FTS5Store — Wrapper Requirements
The wrapper must cover:
- Connection lifecycle management (open, close, WAL mode)
- Schema creation and migration
- FTS5 virtual table creation with custom English stemming tokenizer
- Document insertion, update, and deletion (incremental — no full reindex on new volume)
- Full query surface: phrase (`"cold war"`), boolean AND/OR/NOT, prefix wildcard (`negoti*`)
- BM25 relevance ranking
- Snippet extraction for search result display
- Error handling with typed Swift errors
- Async/await interface compatible with Swift 6 strict concurrency

Suffix wildcard search (`*gotiate`) is not supported. This limitation is documented clearly in the UI search help text.

### Index Persistence
Stored in Application Support alongside volume XML files. Excluded from iCloud Backup via `isExcludedFromBackupKey`. The exclusion is explained briefly in the Settings storage management UI.

### Stemming
Required. English stemming applied via a custom FTS5 tokenizer registered at index creation time. Searching "negotiate" matches "negotiated," "negotiating," "negotiations," etc.

### What Is Indexed
- Full text of all FRUS documents (all downloaded and sideloaded volumes)
- Generated summaries (all prompts)
- Research note body text
- Document metadata: header, dateline, source note, volume ID, document number, subseries
- Subject tag IDs and names (enabling tag-based search)

### Incremental Updates
New volume downloads, new generated summaries, and new research notes are added to the index without triggering a full reindex. The indexing pipeline processes one volume at a time concurrently (maximum concurrent operations configurable; default: 4).

### Cross-Reference Edge Table
Populated in the same indexing pass as FTS5. `<ref>` elements within footnotes and editorial note text are extracted and inserted as directed edges. Both intra-volume and inter-volume references are captured.

### Subject Tag Integration
Bundled subject tag appearance data is read during the indexing pass and associated with document records in the search index, enabling subject-tag-filtered search queries.

### User Communication During Indexing
While indexing is in progress, the app displays a non-modal progress indicator and informs the user which functionality is available immediately (e.g., summarization prompt customization) vs. which requires indexing to complete (e.g., full-text search).

### Storage Transparency
Settings screen displays:
- Total space used by downloaded volumes
- Total space used by the search index
- Total space used by generated summaries
- Per-volume breakdown sortable by size, with delete action per volume
- Explanation that deleting a volume removes its XML and its index portion but preserves research notes, tags, and collections

Onboarding includes a brief, honest indication of storage requirements before first download.

---

## 10. AI Summarization

### Provider Architecture

All summarization is routed through a `SummarizationProvider` protocol:

```swift
/// SummarizationProvider defines the interface any AI backend must satisfy.
/// Current default implementation uses Apple Intelligence (FoundationModels).
/// Alternative implementations (OpenAI, Anthropic, local models) can be
/// substituted without changing any call sites in the application.
/// To add a provider: implement this protocol and add a Settings option.
protocol SummarizationProvider {
    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPrompt
    ) async throws -> SummarizationResult
}
```

The active provider is resolved at runtime from Settings, defaulting to Apple Intelligence.

### Default Provider: Apple Intelligence

Accessed via the `FoundationModels` framework. On-device inference, no API key required.

- `LanguageModelSession` used for general prompts
- `@Generable` macro used for structured output schema enforcement
- Availability checked at runtime; devices without Apple Intelligence support see a clear explanation in Settings and summarization is disabled gracefully

### Response Formats

```swift
enum ResponseFormat {
    /// Free-form prose — rendered as text above document in Document view
    case general
    /// Structured output conforming to user-defined schema —
    /// rendered as labeled field list in Document view
    case structured(schema: StructuredSummarySchema)
}
```

### Structured Prompt Schema Templates

> **⚠️ PLACEHOLDER — ACTION REQUIRED**  
> Schema template content must be confirmed before the summarization UI development session.  
> Six template slots are reserved. Provide field names and descriptions for each template.  
> Temporary working names: Diplomatic Exchange, Policy Decision, Intelligence Report,  
> Meeting Record, Crisis Event, Biographical Reference.

Templates are starting points only. Users can modify field names, add fields, or remove fields. A "Start from scratch" option is always available alongside templates in the prompt creation flow.

### Standard Prompts

> **⚠️ PLACEHOLDER — ACTION REQUIRED**  
> Standard summarization prompt text (both general and structured variants shipped  
> with the app) must be provided before the summarization background service session.

### Long Document Handling

The chunking and synthesis pipeline lives in the service layer, above the provider abstraction. All providers benefit automatically.

1. **Length assessment** — estimate token count; if within context window (minus prompt overhead), submit directly
2. **Semantic chunking** — split at TEI structural boundaries (paragraph, section, element breaks); chunk size set conservatively below context window
3. **Per-chunk summarization** — each chunk summarized independently using the same prompt; intermediate summaries not surfaced to user
4. **Synthesis pass** — intermediate summaries combined in a single synthesis prompt producing the final result
5. **Result storage** — `wasChunked: Bool` flag set on `GeneratedSummary`; UI may optionally note long-document origin

### Background Summarizer

Triggered from Settings screen. Runs concurrent summarization tasks against a user-defined scope:
- By subseries
- By volume
- By subject tag
- By date range

Behavior:
- Graceful handling of `LanguageModelSession` rate limit errors with retry and exponential backoff
- Non-modal completion notification
- Progress visible in Settings without blocking the UI
- Respects user-configured concurrency limit

### Unavailable Device Handling
If `FoundationModels` is unavailable on a device (older hardware without Apple Intelligence support), summarization features are hidden from the UI with a Settings explanation. All other app functionality is unaffected.

---

## 11. Cross-Reference Graph

### Data Source
`<ref>` elements extracted from TEI during the indexing pass. Stored in the SQLite cross-reference edge table (see Section 9). Both footnote references and editorial note references are captured.

### Renderer
Custom SwiftUI `Canvas` with:
- Cubic Bézier curve edges
- SF Symbols node icons (`doc.text` or equivalent)
- Three-column directed layout: [Inbound] → [Central] → [Outbound]

### Standard Layout (≤20 cross-references)

- Central node anchored at canvas midpoint
- Inbound nodes distributed evenly in left column, vertically centered as group
- Outbound nodes distributed evenly in right column, vertically centered as group
- Minimum 60pt vertical separation between nodes
- Canvas sized to fit all nodes; no scrolling required at this scale
- Pinch-to-zoom and drag-to-pan supported via `MagnificationGesture` and `DragGesture`

### Fallback Layout (21–100 cross-references)

- Force-directed spring layout (~100 lines of Swift; no external library)
- Central node pinned to canvas center
- Animated settling on appearance; respects system Reduce Motion setting (immediate final positions when enabled)
- Volume-based clustering when node count exceeds 30: documents from same volume grouped into cluster node
- Cluster nodes expand on tap/click

Transition between standard and fallback layout is automatic based on node count.

### Interaction Model

| Action | macOS | iPadOS/iOS |
|---|---|---|
| See document info | Hover over node | Tap node once |
| Navigate to document | Click node | Tap info display |
| Zoom | Pinch or scroll wheel | Pinch |
| Pan | Click and drag | Drag |
| Expand cluster | Click cluster node | Tap cluster node |
| Switch filter | Toolbar segmented control | Toolbar segmented control |

### Filter Modes
Toolbar segmented control: Project-level filters | Custom filter | Unfiltered

### Undownloaded Volume Handling
- Note displayed at top of view if cross-references to the central document from undownloaded volumes may exist
- Outbound references to undownloaded volumes show question marks for unknown fields
- Navigating to a node in an undownloaded volume initiates download

---

## 12. Citation Formatter

### Architecture

```swift
/// CitationFormatter generates formatted citations for FRUS documents.
/// Currently implements history.state.gov recommended style only.
/// Future styles (Chicago footnote, Chicago bibliography, etc.) are
/// added by implementing this protocol and adding a CitationStyle enum case.
protocol CitationFormatter {
    func format(document: FRUSDocument, volume: FRUSVolume) -> String
}
```

### Source Data (all from TEI)
- Document header (`<head>`)
- Dateline (`<dateline>`)
- Document number
- Volume title, number, subseries name and number, series name
- Editors, general editor
- Publication date, publication place, publisher

### Current Style
history.state.gov recommended style. Session prerequisite: fetch and review the current citing-frus page (history.state.gov/historicaldocuments/citing-frus) at the start of the citation formatter session to confirm the style has not changed since this specification was written.

### Future Styles
`CitationStyle` enum accommodates future additions: `.historyAtState`, `.chicagoFootnote`, `.chicagoBibliography`, etc. Active style is user-configurable in Settings when multiple styles are available.

### Delivery
- Displayed in a sheet from the Document view toolbar
- Copied to system clipboard via the toolbar copy action
- No network call required

### Test Requirement
A fixture set of expected citation strings, drawn from the history.state.gov citing-frus page, covering:
- Standard document citation
- Document with multiple editors
- Document without dateline
- Editorial note citation
- Volume with subseries

These fixtures are used in automated tests validating formatter output.

---

## 13. NARA Source Explorer

### Trigger
Tapping/clicking a document source note or external (non-FRUS) cross-reference in the Document view presents a sheet with the Source Explorer view.

### API Key
NARA Catalog API key stored in iCloud Keychain (shared access group, same entitlement as established in project setup). Synced across the user's devices.

### Parser

> **⚠️ PLACEHOLDER — ACTION REQUIRED**  
> Source note format patterns and multi-era examples must be provided at the start  
> of the NARA Source Explorer development session. Examples should span different  
> historical eras with different formatting conventions so the parser can attempt  
> multiple pattern strategies.

Parser strategy: attempt format patterns from most-specific to most-general. On no match, display raw source note text with an explanation that automated resolution was unavailable.

### Provenance Switching

| Detected provenance | Resolution |
|---|---|
| State Dept. central files | NARA RG-59 central files webpage — no API call |
| State Dept. lot files | NARA Catalog API query for file series description |
| Presidential Library | NARA Catalog API query for file series description |
| Foreign government archive | Parsed reference text displayed |
| Previously published source | Parsed reference text displayed |
| No pattern matched | Raw source note text with explanation |

### No API Key State
Provenance types requiring an API call display a prompt explaining the key's purpose and linking to the Settings screen. Provenance types not requiring an API call function normally regardless of key status.

### Session Prerequisite
Review current NARA Catalog API documentation (archives.gov/research/catalog/help/api) at session start to confirm current endpoint patterns and authentication headers.

### Future Roadmap (not in scope for v1)
- More granular resolution to NARA Catalog matches at item level
- Exploring record group hierarchies
- Linking pre-1906 FRUS documents to file unit-level digitized sources

---

## 14. Collection Export

### Export Pipeline Architecture

```swift
/// CollectionExporter defines the interface for all export format implementations.
/// Current implementations: PDF, HTML.
/// Future implementation: DOCX (Open XML writer).
/// Adding a format requires implementing this protocol only — no pipeline changes.
protocol CollectionExporter {
    func export(
        collection: Collection,
        documents: [RenderedFRUSDocument],
        format: ExportFormat
    ) async throws -> Data
}

enum ExportFormat {
    case pdf
    case html
    case docx  // future; architectural hook in place
}
```

### Supported Formats

**PDF** — PDFKit (`UIGraphicsPDFRenderer` on iPadOS/iOS; `NSGraphicsPDFContext` on macOS)
- Internal document links from table of contents to full rendered documents
- Professional typography
- Full TEI-rendered document content

**HTML** — Native string construction with embedded CSS
- Internal anchor links
- Full CSS typography control
- Self-contained single file
- Opens in any browser; printable to PDF from browser

**DOCX** — Deferred to future session
- Minimal Open XML writer (DOCX is a ZIP of XML files; no external library needed for the structured content required)
- `CollectionExporter` protocol accepts format parameter from day one

### Export Contents
1. Collection name
2. Collection note (if present)
3. Linked document list: header, source note, parent volume ID, document number — each entry internally linked to the full rendered document
4. Full rendered documents, each preceded by its selected research notes

### Style
Formal, professional default template. User-defined templates/stylesheets planned for future roadmap.

### Delivery
System share sheet on all platforms:
- iPadOS/iOS: `UIActivityViewController`
- macOS: `NSSharingServicePicker`

Save to Files is available as an option within the share sheet on all platforms.


---

## 14b. Citation Lookup

### Purpose
Allows researchers to paste or manually enter a citation to a FRUS document and receive a ranked list of matches. Handles diverse citation formats and styles, resolves page numbers to documents via `<pb>` page range data, recovers gracefully from malformed citations, and applies a two-stage strategy for citations resolving to undownloaded volumes.

### Interface Location
Dedicated top-level view accessible from the main navigation (tab bar on iPhone; sidebar on iPad and macOS). Linked from the Search view with a "Find by Citation" prompt. Also accessible from the Document view toolbar.

### Input Modes
Two modes via segmented control:

**Paste Citation** (default) — free-form text field; parser extracts structured fields in real time, populating the editable structured fields below as feedback.

**Structured Entry** — individual labeled fields: subseries / year range, volume number, document number (optional), page number (optional), volume title fragment (optional). At least one of document number or page number must be provided to attempt a match.

### Citation Format Coverage
The parser handles:
- history.state.gov recommended style
- Chicago footnote (full and short forms)
- Informal/abbreviated (FRUS + year range + vol + doc/page)
- Page-only citations (primary path for pre-1955–57 volumes)
- Potentially malformed citations (OCR artifacts, missing punctuation, variant separators)

### Era Handling
- **Post-1955–57**: document numbers are native to the original publication; exact match is the primary path
- **Pre-1955–57**: document numbers were superimposed editorially during digitization; page range lookup is the primary path; document number matches are labeled accordingly
- **Microfiche supplements**: document number matching works normally; page range lookup not applicable

### Matching Strategy (priority order)

| Priority | Strategy | Confidence label |
|---|---|---|
| 1 | Exact document number (post-1955–57) | "Exact match" |
| 2 | Page range match | "Matched by page number" |
| 3 | Superimposed document number (pre-1955–57) | "Match — document number assigned digitally" |
| 4 | Fuzzy document number | "Possible match — document N not found; nearest is M" |
| 5 | Title fragment volume disambiguation | "Matched via volume title; verify volume is correct" |
| 6 | Manifest only (volume not downloaded) | "Volume identified — download to find specific document" |
| 7 | Best guess | "Best guess — [plain-language explanation]" |

Confidence labels are explicit and always displayed alongside each result.

### Two-Stage Behavior for Undownloaded Volumes
Stage 1: resolve citation to a volume using manifest metadata; return match with download prompt.
Stage 2: after download and indexing complete, re-run full match to resolve to specific document and page.

### Result Display
Results use the identical `SearchResultView` component from the Search view, maintaining consistency. Each result is preceded by its explicit confidence label; correction notes appear below the result card where applicable.

---

## 15. Project & Global Context

### The Mental Model
A Project is an activity lens, not a content container. Working within a project context silently tags the user's actions with that project. The project context view filters to activity carrying that tag. The global context view shows all activity regardless of tag.

### Active Project
One project is active at a time (or none). Stored in `AppState` (`@Observable`). Persisted via `UserDefaults`. Switching projects is instantaneous — a state change, not a data migration.

### Activity Tagging Rules

| Record type | Project tag behavior |
|---|---|
| `ReadingHistoryEntry` | Tagged with active project at time of access; nil if no active project |
| `ResearchNote` | Tagged with active project at creation; user can add/remove project tags afterward |
| `GeneratedSummary` | Tagged with active project at generation time |
| `Collection` | Tagged with active project at creation; can carry multiple project tags |
| `UserTag` | Global — never project-scoped |
| `SubjectTag` | Global — never project-scoped |

### Cross-Project Visibility

When viewing a document in Project B's context, research notes tagged only with Project A are:
- **Hidden by default**
- **Signaled** by a footer indicator: *"2 notes from other projects"* with a disclosure control
- **Revealable** on demand in a visually distinct (muted/labeled) style showing which project each note belongs to
- **Promotable**: from the revealed state, the user can add Project B's tag to a note, bringing it into full visibility in Project B going forward

The same pattern applies to collections viewed across project contexts.

Reading history entries do not follow this pattern — they are historical records of past events, not annotations, and carry no cross-project ambiguity.

### Project-Level Defaults
Each project carries user-configurable defaults that pre-populate (but do not lock) the Browser and Search views when that project is active:
- Default chronological range for date filtering
- Default subject tag filters
- Default country tag filters
- Research question / goals (used for summarization prompt emphasis)

---

## 16. User Experience

### Onboarding View
Presented whenever no volumes are downloaded or sideloaded. Re-evaluates at every launch (not a one-time flag).

Content:
- Introduction to the FRUS series drawn from history.state.gov/historicaldocuments/about-frus
- Volume browser drawing from bundled manifest, organized by subseries, allowing multi-select for initial download
- Storage requirement indication before download confirmation
- Guided summarization prompt creation for the user's initial project
- Download initiation (maximum concurrent downloads; configurable)

Offline behavior: if no network available, inform user; show bundled manifest only; note that downloads will queue for next online launch.

All download functionality filters out volumes reported under 20kb by the GitHub API.

### Browser View
Scales across the full FRUS hierarchy. At each level, displays information appropriate to that context with links up and down the hierarchy.

**Corpus level**: total volumes, total documents, earliest/latest document, earliest/latest publication date, list of subseries

**Subseries level**: total volumes, total documents, earliest/latest document, earliest/latest publication date, count of partially published volumes, count of planned-but-unpublished volumes, list of volumes

**Volume level**: title, volume number, editor(s), general editor, publication date, list of top-level components (front matter, compilations, appendices, errata, back matter)

**Compilation level**: list of top-level components (or documents if no intermediate level)

**Chapter level**: list of documents and editorial notes with header, dateline, source note, user tags (if any), latest generated summary (if any)

Project-level filters apply across all levels and can be adjusted at any level.

### Document View
Renders document TEI per history.state.gov style and conventions.

**Toolbar** (top): add research note, view research notes, add user tag, view user tags, add to new collection, add to existing collection, view citation, copy citation, explore cross-references

**Above document**: active summarization result with control to view other generated summaries

**Document body**: full TEI-rendered content; `<persName>` and `<gloss>` elements link to volume reference lists

**Below document**: subject tag chips and user tag chips (clickable, resolve to Search view with that tag as filter); action button for tagging or adding a research note

**Research note cross-project indicator**: *"N notes from other projects"* disclosure if applicable

### Search View
Composable search and filtering interface.

Filter options:
- Full-text keywords (phrase, boolean, prefix wildcard)
- Date range
- Subject tags
- User tags
- Generated summaries (all prompts, or a single selected prompt)
- Research notes

Scope options: all loaded volumes, generated summaries, research notes (any combination).

Project-level filters pre-populate but can be overridden.

Results list per item: document header, dateline, source note, latest generated summary (if available), parent volume ID, document number, user tags, subject tags.

### Global Context View
Aggregated explorable information:
- Volumes and documents accessed and read (across all projects and untagged)
- Research notes browsable by project tag or their own user tags
- Custom collections browsable by project tag

### Research Note Editor
- Rich text editor for note body
- Tag selector (user tags)
- List of saved generated summaries; select one or more to promote as initial draft content
- Project tag inherited automatically at creation; user can add/remove project tags (note remains in project context regardless)

### Collection Editor
- Collection note (optional free text above document list)
- Reorderable document list (same display as search results)
- Selecting a document: choose existing research note, create new one, or none
- Last row: "Add more documents" control — select a user tag; all documents with that tag not already in the collection are appended
- Sort by date button
- Export button (PDF or HTML; share sheet)

### Settings Screen
- **Volume management**: configure concurrent download limit, view current downloads, delete downloaded volumes, download undownloaded volumes, check for new volumes (re-fetch live manifest)
- **Storage management**: per-volume and aggregate storage display; delete actions; iCloud Backup exclusion explanation
- **Sideload**: import single XML file; schema validation; distinct error messages
- **Reindex**: trigger full reindex of all loaded volumes
- **User tags**: manage (rename, delete, merge)
- **Summarization prompts**: view standard prompts; view/edit user prompts; aggregate summary count per prompt; review summaries with link to associated document; trigger background summarization with scope configuration
- **NARA API key**: entry field (stored in iCloud Keychain)
- **Reset**: restore app to initial state (with confirmation)

### About Screen
- Attribution: **⚠️ PLACEHOLDER — to be provided during development**
- FRUS series description: bundled prose text (see Session 26 task file for full text); no runtime fetch required
- Links: history.state.gov, github.com/HistoryAtState
- TEI Publisher Lib acknowledgement (Apache 2.0 / license-appropriate)
- NARA Catalog API required disclaimers

---

## 17. App Identity & Distribution

### Name
FRUS Explorer

### License
Apache 2.0. All source files carry the Apache 2.0 license header. The LICENSE file is included in the repository root.

### Attribution
> **⚠️ PLACEHOLDER — to be provided before About screen development session**

### iOS / iPadOS Distribution
App Store only.

### macOS Distribution
App Store + Direct Distribution (Developer ID).

Two build configurations maintained from project setup:
- `AppStore` — App Store provisioning profile, App Store entitlements
- `DirectDistribution` — Developer ID certificate, Developer ID entitlements

Both configurations maintain identical sandbox posture. Direct distribution build requires manual notarization via `notarytool` before release.

### Update Mechanism
Direct distribution macOS build uses **Sparkle** (SPM dependency) for update delivery. App Store builds use App Store update mechanism.

### Bundle Identifier
`bottsywattsy.FRUS-Explorer` — registered in App Store Connect. Do not change.

### CloudKit Container
`iCloud.bottsywattsy.FRUS-Explorer`

### Required Entitlements (both configurations)
- iCloud (CloudKit + iCloud Keychain sharing)
- `com.apple.developer.icloud-keychain-sharing`
- Network access (outbound: GitHub API, NARA Catalog API, Apple Intelligence)
- App Sandbox

---

## 18. Accessibility

### Baseline
All SwiftUI accessibility features used correctly throughout. VoiceOver labels, Dynamic Type scaling, and sufficient contrast are requirements, not stretch goals. Accessibility must be considered in every development session, not added afterward.

### Coding Requirement
Every custom view must provide explicit accessibility labels, hints, and traits where SwiftUI cannot infer them automatically. Custom `Canvas`-based views (cross-reference graph) require explicit accessibility element overlays.

### Reduced Motion
The force-directed graph layout animation respects the system Reduce Motion setting — when enabled, nodes appear in their final positions immediately. All other animations introduced during development must be reviewed against this requirement and flagged in session task files.

### Color Independence
Color is never the sole conveyor of meaning. The curated vs. string-match subject tag distinction requires a non-color indicator in addition to any visual style difference.

### Tap Target Sizes
Minimum 44×44pt tap targets throughout on iPadOS/iOS. macOS mouse targets may be smaller where appropriate but must remain clearly clickable.

### Open Questions (resolve before relevant UI sessions)

> **⚠️ OPEN — ANSWER BEFORE DOCUMENT VIEW SESSION**  
> 1. VoiceOver label pattern for subject tag chips and cross-reference nodes (e.g., "Berlin Crisis, subject tag, button" — confirm or adjust)
> 2. Preferred reading order in Document view: toolbar → summary → document → tags, or summary after document?

> **⚠️ OPEN — ANSWER BEFORE CROSS-REFERENCE GRAPH SESSION**  
> 3. Cross-reference graph VoiceOver alternative: structured list of inbound/outbound references (recommended) or different approach?
> 4. Additional animations beyond the graph settling effect that should respect Reduce Motion

> **⚠️ OPEN — ANSWER BEFORE SUBJECT TAG UI SESSION**  
> 5. Non-color indicator for curated vs. string-match tag distinction: icon, label suffix, tooltip/popover, or combination?

> **⚠️ OPEN — ANSWER BEFORE FINAL UI REVIEW SESSION**  
> 6. macOS tap target policy: confirm whether smaller targets are acceptable on mouse-driven surfaces

---

## 19. Localization

English only for v1. Architecture supports future localization from day one:

- All user-facing strings use `String(localized:)` — no hardcoded string literals in UI code
- All string literals stored in `.strings` / `.stringsdict` files
- No assumptions about string length in layout (adaptive layout throughout)
- Date and number formatting uses locale-aware formatters

This is a **coding standard** enforced in every session. Session task files will explicitly require compliance.

---

## 20. Telemetry & Analytics

### Console Logging
Conditional on build configuration:
```swift
#if DEBUG
print("[FRUSExplorer] \(message)")
#endif
```
Logging covers both success and error paths for all significant operations. Applied as code is written, not added afterward.

### Crash Reporting
TestFlight symbolicated crash logs for beta builds. No additional instrumentation required.

### Analytics
None. No external analytics frameworks.

### External Telemetry
None. No data leaves the device except: CloudKit sync (user data), NARA Catalog API calls (user-initiated, with user-provided key), Apple Intelligence (on-device), GitHub API (volume manifest and downloads).

---

## 21. OpenAPI / Future FRUS API

A living OpenAPI document (`FRUS-API.openapi.yaml`) is maintained in the repository root. It describes the ideal FRUS API that could replace current GitHub API calls and local volume parsing with efficient, purpose-built endpoints.

### Update Requirement
Every development session that introduces a method calling:
- The GitHub API (manifest, volume downloads)
- Locally cached FRUS volume XML
- The HistoryAtState GitHub repository in any form

...must add or update the corresponding endpoint in `FRUS-API.openapi.yaml`, documenting what a future FRUS API could deliver more efficiently.

### Initial Endpoints to Define (as development proceeds)
- `GET /volumes` — manifest with rich metadata (replaces bundled manifest + GitHub API diff)
- `GET /volumes/{volumeId}` — single volume metadata
- `GET /volumes/{volumeId}/documents` — document list with metadata
- `GET /volumes/{volumeId}/documents/{documentId}` — full document TEI or pre-rendered content
- `GET /subjects` — full subject taxonomy
- `GET /subjects/appearances/{volumeId}` — document-subject mappings for a volume
- `GET /search` — full-text search across corpus
- `GET /volumes/{volumeId}/page-ranges` — page number to document mappings
- `GET /citation-lookup` — resolve a FRUS citation to matching documents

---

## 22. Coding Standards

These standards apply to every development session without exception.

### Documentation
- Every new type, function, and significant property carries a documentation comment explaining what it does, how it fits into the project, and any non-obvious behavior
- Modified code has its documentation updated to reflect the change, with a brief version history note
- Open source contributor clarity is the target audience for all documentation

### Telemetry Logging
- `#if DEBUG` conditional print statements for all significant operations
- Both success and error paths logged
- Log prefix: `[FRUSExplorer]` for app-level; `[FTS5Store]` for the SQLite wrapper; `[TEIParser]` for the rendering pipeline; etc.

### Concurrency
- Swift 6 strict concurrency throughout
- No `@unchecked Sendable` without explicit documented justification
- All network, file I/O, and parsing off the main actor

### Localization
- `String(localized:)` for all user-facing strings
- No hardcoded string literals in view code

### Testing
- Each session produces unit tests covering the new functionality
- Test targets share the workspace; tests from prior sessions continue to pass
- Fixture-based testing for TEI parsing, citation formatting, and source note parsing

### OpenAPI
- `FRUS-API.openapi.yaml` updated in any session touching GitHub API or local volume data

---

## 23. Placeholders Requiring Future Input

The following items must be resolved before their respective development sessions begin. Each is marked in the relevant section above.

| # | Item | Needed Before |
|---|---|---|
| 1 | Structured prompt schema template content (6 templates) | Summarization UI session |
| 2 | Standard summarization prompt text (general + structured) | Background summarizer session |
| 3 | Source note format patterns and multi-era examples | NARA Source Explorer session |
| 4 | About screen attribution text | About screen session |
| 5 | VoiceOver label pattern for tag chips and graph nodes | Document view session |
| 6 | Document view VoiceOver reading order preference | Document view session |
| 7 | Cross-reference graph VoiceOver alternative representation | Cross-reference graph session |
| 8 | Additional Reduce Motion animation surfaces | Cross-reference graph session |
| 9 | Non-color indicator for curated vs. string-match tags | Subject tag UI session |
| 10 | macOS tap target policy for mouse-driven surfaces | Final UI review session |
