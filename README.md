# FRUS Explorer

A macOS, iPadOS, and iOS application providing tools to help researchers use the
[Foreign Relations of the United States (FRUS)](https://history.state.gov/historicaldocuments)
series more effectively.

## Features

- Full-text search and filtering across the FRUS corpus (FTS5, English stemming, BM25 ranking)
- TEI-rendered document view faithful to history.state.gov content and annotation
- Structured date indexing from TEI `<date>` attributes; accurate date-range filtering
- Editorial note distinction: index and filter primary documents vs. editorial notes separately
- Person mention indexing: cross-volume search by person reference with mention counts
- Persons and terms glossaries persisted to SQLite; live autocomplete person picker
- Accurate footnote numbers from TEI `@n` attributes (matching printed volume numbering)
- Cross-reference graph with node and edge labels, hover/click edge-context disclosure, 1°/2°/3° neighbourhood expansion, node context menu (Recenter Graph / Open in Main Window), page-based reference resolution, and an info popover explaining the graph
- Document-level research notes and user tagging
- **Research window / tab**: browse all annotated documents organized by user tag (document count descending); opens documents in the main window; macOS `⌘⌥R` shortcut; iOS Research tab (third tab)
- AI summarization via Apple Intelligence (FoundationModels framework)
- User-configurable summarization prompts with structured output support
- Citation formatter (history.state.gov recommended style)
- Citation lookup: resolve citations encountered in publications to FRUS documents (⌘⇧F on macOS, Find by Citation button in the macOS search window)
- NARA Source Explorer: link document source notes to NARA Catalog records
- Composable document collections with PDF, HTML, and DOCX export; document header (from indexed TEI `document_cache`) shown per row; per-entry delete, multi-note attachment, and inline date sort; configurable table-of-contents label style and per-document body/note inclusion
- Corpus Analytics: corpus-wide term frequency histograms (Swift Charts) with Decade / Year / Month / Day / Subseries granularity, optional linear regression fit line, year-range filter, and metric explanation popover
- CloudKit-synced user data (notes, tags, collections, projects) with live sync monitoring: macOS status bar and iOS Settings surface "Syncing…", "Synced", or "Sync Error" (with error detail) in real time via `NSPersistentCloudKitContainer.eventChangedNotification`
- Offline functionality with download queue; volumes indexed automatically after download
- Live indexing progress (stage, document count, throughput) in the volume browser; document list loads automatically on completion without navigating away; macOS status bar shows a tappable queue popover with per-volume progress, combined ETA, and pending-volume list for multi-volume batches
- macOS Settings → Storage: per-category usage breakdown (volume XML / search index / AI summaries / total); indexing controls (Index Remaining, Reindex All, Delete & Rebuild) positioned above the volume list for immediate access; per-volume reindex and remove controls
- Breadcrumb navigation trail in the volume browser
- Front matter sections (preface, introduction, errata) browsable directly from the corpus
- Accurate subseries grouping in the volume browser and manifest diff
- **iOS/iPadOS**: five-tab navigation — Browse, Search, Research, Collections, Settings
- **macOS**: up to 7,500 ranked search results with true-total count, TEI-derived context snippets, date-sort by structured ISO date, and scope-aware column filtering; native Settings scene (⌘,); `.help()` tooltips on all icon-only controls and toolbar buttons throughout the app

## Requirements

- **Xcode 26.0+** (macOS 26 SDK required)
- **macOS 26.0+** (development machine)
- **Swift 6.0+** with strict concurrency enabled
- Apple Developer account with the following capabilities:
  - iCloud (CloudKit + iCloud Documents)
  - iCloud Keychain Sharing
  - App Sandbox

## Project Structure

```
FRUSExplorer/
├── FRUSExplorer.xcodeproj        Xcode project (iOS/iPadOS + macOS app targets)
├── project.yml                   XcodeGen spec — edit this, not the .xcodeproj directly
├── FRUSExplorer/                 Main app source
│   ├── App/                      Entry point, AppState, root views
│   ├── Browser/                  Corpus / subseries / volume browser views
│   ├── CrossReference/           Cross-reference graph, volume connection graph
│   ├── Collections/              Collection editor, PDF/HTML/DOCX exporters
│   ├── Research/                 Research window / tab (annotated documents by tag)
│   ├── Search/                   SearchService, IndexingPipeline, SearchView
│   ├── DocumentView/             Document display, research notes, cross-reference links
│   ├── Summarization/            Apple Intelligence integration, prompt management
│   ├── Analytics/                Corpus Analytics with Swift Charts
│   ├── Citation/                 Citation formatter, lookup engine, BibTeX/RIS export
│   ├── SourceExplorer/           NARA catalog integration
│   ├── Downloads/                DownloadManager, download queue UI
│   ├── Models/                   SwiftData models, manifest structs, supporting types
│   ├── Settings/                 macOS FRUSSettingsView + iOS SettingsView
│   ├── TEI/                      XML parser, AST types, renderer
│   ├── Distribution/             Direct-distribution-only code (SparkleUpdater)
│   ├── Resources/                Bundled data (manifest, taxonomy, subject tags)
│   └── Localizable.strings       English base localisation
├── FRUSExplorerTests/            Unit tests (517 tests, all passing)
├── FRUSExplorerUITests/          UI tests
├── ManifestGenerator/            SPM tool: generates manifest.json from FRUS GitHub
├── TaxonomyGenerator/            SPM tool: generates volume-tag-taxonomy.json
├── Package.swift                 SPM manifest for command-line tools
├── FRUS-API.openapi.yaml         Living OpenAPI spec (future FRUS API)
└── Planning/                     Specification and development plan documents
```

## Building

### iOS / iPadOS

Select the **FRUSExplorer** scheme in Xcode. Build for any iOS/iPadOS simulator or device.

### macOS — App Store

Select the **FRUSExplorerMac** scheme with the **AppStore** build configuration.

### macOS — Direct Distribution

Select the **FRUSExplorerMac** scheme with the **DirectDistribution** build configuration.
This configuration:
- Links **Sparkle 2** for automatic updates (configured in `project.yml`)
- Sets the `-DDIRECT_DISTRIBUTION` compiler flag to enable `Distribution/SparkleUpdater.swift`
- Uses `CODE_SIGN_STYLE: Manual` with Developer ID signing
- Includes a "Check for Updates…" menu item in the application menu

#### Release workflow (Direct Distribution)

**Prerequisites:**

1. Export credentials to your environment:
   ```sh
   export TEAM_ID=XXXXXXXXXX
   ```

2. Create a notarytool credential profile (one-time setup):
   ```sh
   xcrun notarytool store-credentials "FRUS-Notary" \
     --apple-id "your@email.com" \
     --team-id "$TEAM_ID" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

3. Update the `SUFeedURL` in `project.yml` to point to your actual appcast endpoint:
   ```yaml
   INFOPLIST_KEY_SUFeedURL: "https://your-domain.example.com/appcast.xml"
   ```

4. Set `CODE_SIGN_IDENTITY` and `PROVISIONING_PROFILE_SPECIFIER` in `project.yml`
   (or pass them on the command line) matching your Developer ID certificate.

**Build, notarize, and package:**

```sh
# Full workflow (archive → export → notarize → staple → DMG):
TEAM_ID=XXXXXXXXXX ./Scripts/notarize.sh

# Dry run to preview commands without executing them:
TEAM_ID=XXXXXXXXXX ./Scripts/notarize.sh --dry-run

# With an explicit app bundle and custom notarytool profile:
TEAM_ID=XXXXXXXXXX ./Scripts/notarize.sh \
  --app-path build/export/FRUS\ Explorer.app \
  --profile MyNotaryProfile
```

The script produces:
- `build/FRUSExplorer.xcarchive` — Xcode archive
- `build/export/FRUS Explorer.app` — notarized, stapled app bundle
- `build/FRUSExplorer.dmg` — distributable disk image

**Verifying notarization manually:**

```sh
xcrun stapler validate "build/export/FRUS Explorer.app"
spctl --assess --type execute --verbose "build/export/FRUS Explorer.app"
```

#### Release workflow (App Store)

1. Select the **AppStore** build configuration
2. In Xcode Product → Archive
3. Distribute via Xcode Organizer → "Distribute App" → App Store Connect

### Regenerating the Xcode Project

If `project.yml` is modified, regenerate the `.xcodeproj` using XcodeGen:

```sh
xcodegen generate --spec project.yml
```

> **Note:** XcodeGen regenerates all file references. New source files added to directories
> already tracked by the project (e.g. `FRUSExplorer/Research/`) will appear automatically
> after regeneration. When XcodeGen is unavailable, file references can be added manually
> to `project.pbxproj` following the existing `AA…` UUID pattern.

### Command-Line Tools

```sh
# Regenerate manifest.json before each app release:
swift run ManifestGenerator

# Regenerate volume-tag-taxonomy.json when the taxonomy changes:
swift run TaxonomyGenerator
```

## Running Tests

```sh
# All unit tests (iOS simulator)
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17"

# Quick filter to a single test suite
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing FRUSExplorerTests/CitationParserTests
```

### Manual Integration Tests

The following integration tests require a live device, downloaded volumes, or
network access and must be verified manually before each release:

| Test | How to verify |
|---|---|
| **FullOnboardingTest** | Fresh install → onboarding → download ≥1 volume → confirm browser appears |
| **AutoIndexTest** | Download a volume; confirm it appears in search results without manual reindex |
| **LargeCorpusIndexTest** | Index 10+ volumes; confirm search returns correct results |
| **PersonMentionTest** | Search by person reference; confirm results filtered correctly |
| **DateRangeFilterTest** | Filter search by date range; confirm only documents with `<date @when>` in range returned |
| **EditorialNoteFilterTest** | Switch Document Type filter; confirm editorial notes included/excluded correctly |
| **FrontMatterTest** | Navigate to a volume preface; confirm "Read" button appears and opens document |
| **IndexingProgressInBrowserTest** | Trigger "Index Now" from a CompilationView; confirm live progress bar appears (stage label + doc count + throughput), then doc list populates automatically on completion without navigating away |
| **MacQueueProgressPanelTest** | Trigger download of ≥2 volumes simultaneously on macOS; confirm status-bar popover shows "Volume N of M", current-volume progress bar, combined ETA, and expandable pending-volume list; confirm popover closes when indexing finishes |
| **StorageReindexTest** | Open Settings → Storage; confirm indexing controls appear above the volume list; confirm per-volume indexed badge; tap Reindex on an indexed volume; confirm it re-indexes and badge updates; confirm per-category size breakdown (volumes / index / summaries / total) is displayed |
| **DeleteIndexRebuildTest** | Open Settings → Storage; tap "Delete Index & Rebuild"; confirm confirmation alert appears; confirm that after accepting, all volumes are re-indexed from scratch and search results are correct |
| **CrossRefNavigationTest** | Tap a cross-reference link in a document; confirm DocumentView loads the target document body (not just updates the nav title) |
| **CrossRefGraphTest** | Open the cross-reference graph for a document with ≥3 direct references; hover over an edge midpoint to see footnote context; right-click a node and verify "Recenter Graph" and "Open in Main Window" options appear; switch to 2° and confirm 2nd-degree nodes appear in grey with connections to their 1st-degree neighbours; tap the info button (ⓘ) and confirm the explanation popover opens |
| **SearchResultNavigationTest** | Select a search result; confirm the full document body loads in DocumentView, not just the header |
| **SearchResultDisplayTest** | Run a keyword search; confirm result rows show the original document header and dateline text (e.g. "Memorandum of Conversation", "Washington, January 20, 1969."), not Porter-stemmed tokens |
| **iOSSearchCapTest** | Run a broad search on iOS with a large corpus; confirm up to 500 results are returned with an over-cap guidance message when the cap is hit |
| **MacSearchCapTest** | Run a broad search on macOS with a large corpus; confirm result count label shows "N of M total" when results are capped at 7,500, with guidance text below the list |
| **SearchPerformanceTest** | Search a large corpus; results appear in <1 second |
| **GraphRenderPerformanceTest** | Open a document with 20+ cross-references; confirm smooth animation; hover an edge to see context |
| **AnalyticsGranularityTest** | Open Corpus Analytics; change the "Group by" picker through Decade / Year / Month / Day / Subseries; confirm chart updates at each granularity; toggle the fit-line switch and confirm the regression line appears/disappears; tap the info button and confirm the metric explanation popover opens |
| **CollectionEnhancementsTest** | Open a collection with ≥3 entries; confirm the document header (from indexed TEI) appears between the document number and volume title; tap the trash icon to remove an entry; attach multiple notes via the note picker and confirm the row shows "N notes"; tap Sort by Date and confirm entries reorder chronologically; resize the Collections window and confirm the document list expands to fill the new height |
| **FindByCitationMacTest** | On macOS, use both the ⌘⇧F shortcut and the "Find by Citation" button in the search window to open the Citation Lookup sheet; confirm a citation resolves to the correct document |
| **CloudKitSyncTest** | Create a research note on device A; confirm it appears on device B; verify the macOS status bar shows "Synced" after sync completes and "Sync Error" (with tooltip detail) if sync fails |
| **CloudKitSyncDiagnosticsTest** | On iOS, open Settings; confirm an "iCloud Sync" section appears at the top showing the live sync state (enabled / syncing / synced / error with message) |
| **ResearchWindowTest** | On macOS, open the Research window (⌘⌥R or Window menu); confirm the sidebar lists tags sorted by document count descending with a count badge; select a tag and confirm the document list shows only documents whose notes carry that tag; click a row and confirm the document opens in the main window; right-click and confirm "Show Cross-References" opens the graph window |
| **ResearchTabTest** | On iOS, tap the Research tab (third tab); confirm "All Annotated Documents" entry shows the correct count; confirm tag entries appear sorted by document count; tap a tag and verify the document list; tap a document row and confirm navigation to the Browse tab with the document loaded |
| **OfflineResilienceTest** | Disable network mid-session; confirm no crash or data loss |
| **CrossPlatformVerification** | Verify all major workflows on macOS, iPadOS, and iPhone |
| **iOSTabNavigationTest** | Verify all five tabs (Browse, Search, Research, Collections, Settings) on iPhone |
| **macOSSettingsSceneTest** | Open macOS Settings via ⌘,; verify all panes open correctly; in the Notes pane, confirm rows have consistent horizontal padding; in Storage, confirm per-category breakdown appears and indexing controls are above the volume list |
| **MacTooltipsTest** | On macOS, hover over icon-only toolbar buttons throughout the app (document view toolbar, search window, corpus viewer, Source Explorer, Collections, Analytics, Research window); confirm `.help()` tooltip appears for each |

## Coding Standards

All code must comply with the following standards (see `Planning/FRUS-Explorer-Specification.md` §22):

- **Swift 6 strict concurrency** — zero warnings under `SWIFT_STRICT_CONCURRENCY=complete`
- **Localization** — all user-facing strings use `String(localized:)`; no hardcoded literals
- **Documentation** — every new type, function, and significant property carries a doc comment
- **Telemetry** — `#if DEBUG` print statements for all significant operations; log prefixes match `[TypeName]` convention
- **Testing** — each development session produces unit tests; all prior tests must continue passing
- **OpenAPI** — `FRUS-API.openapi.yaml` updated in any session touching the API surface; must remain valid OpenAPI 3.1.0

The `CodingStandardsAuditTests` suite in `FRUSExplorerTests/` enforces many of these requirements automatically.

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  SwiftUI Views                    │
│  iOS: MainTabView (Browse, Search, Research,      │
│        Collections, Settings)                     │
│  macOS: NavigationSplitView + Window scenes +     │
│          Settings scene (⌘,)                      │
├──────────────────────────────────────────────────┤
│              Service Layer                        │
│  (Summarization, Search, Export, Citation,        │
│   NARA Resolution, Download, Indexing)            │
├──────────────────┬───────────────────────────────┤
│   SwiftData      │   SQLite FTS5 + Auxiliary DB   │
│  (User Data +    │   (Search Index +              │
│   CloudKit Sync) │    Cross-References +          │
│   [live sync     │    Page Ranges +               │
│    monitoring])  │    Person Mentions +            │
│                  │    Persons/Terms Glossaries +  │
│                  │    Document Cache)             │
├──────────────────┴───────────────────────────────┤
│           TEI Rendering Pipeline                  │
│    (XML Parser → Swift AST → SwiftUI)             │
│    AST nodes: date, persName, footnote(@n), …     │
├──────────────────────────────────────────────────┤
│           Network & Storage Layer                 │
│  (GitHub API, NARA API, Volume Files,             │
│   Manifest, iCloud Keychain)                      │
└──────────────────────────────────────────────────┘
```

### macOS Window Scenes

| Scene ID | Title | Shortcut | Purpose |
|---|---|---|---|
| `frus.search` | Search | ⌘F | Full-text search with filters and pagination |
| `frus.corpusBrowser` | Corpus Browser | — | Subseries/volume browser with volume-level graph |
| `frus.crossReferenceGraph` | Cross-Reference Graph | — | Document ego graph with degree expansion |
| `frus.sourceExplorer` | Source Explorer | — | NARA catalog integration |
| `frus.analytics` | Corpus Analytics | — | Term frequency charts |
| `frus.collections` | Collections | ⇧⌘K | Document collection editor and exporter |
| `frus.research` | Research | ⌘⌥R | Annotated documents organized by user tag |
| `about` | About FRUS Explorer | — | Version and acknowledgements |

## Bundle Identifiers

| Target | Bundle ID |
|--------|-----------|
| iOS/iPadOS app | `bottsywattsy.FRUS-Explorer` |
| macOS app | `bottsywattsy.FRUS-Explorer` |
| CloudKit container | `iCloud.bottsywattsy.FRUS-Explorer` |

The bundle identifier is registered in App Store Connect. Do not change it.

## License

Apache 2.0. See [LICENSE](LICENSE) for the full license text.

All source files carry the Apache 2.0 license header.

## Contributing

1. Read `Planning/FRUS-Explorer-Specification.md` to understand the full application design
2. Read `Planning/DEVELOPMENT-PLAN.md` for the session sequence and dependency graph
3. Each session's task file (e.g. `Planning/36-42-Extended-Indexing.md`) describes
   prerequisites, key changes, and tests for that block of sessions
4. Ensure all existing tests pass before committing session output
5. Update `FRUS-API.openapi.yaml` if your session touches any stored or queryable data surface
6. After every commit, both `FRUSExplorer` (iOS) and `FRUSExplorerMac` (macOS) must build
   cleanly with zero warnings under Swift 6 strict concurrency
