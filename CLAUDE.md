# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**It is loaded into every request, so it has a budget.** `CodingStandardsAuditTests.guideStaysUnderItsBudget` fails when it reaches 60,000 characters or a line of it 4,000, and when a file under `.claude/rules/` reaches the 40,000 Claude Code reads. Put detail in a rules file loaded by path or in a runbook, and leave a paragraph here that names it.

## Project Overview

FRUS Explorer is a native iOS/iPadOS/macOS app for researching the Foreign Relations of the United States (FRUS) document series published by the State Department. It is a **Swift 6** project using **SwiftUI**, **SwiftData + CloudKit**, and **SQLite3 FTS5** for full-text search.

The project uses **XcodeGen** — `project.yml` is the source of truth for the Xcode project. Regenerate after any changes to `project.yml`:

```bash
xcodegen generate --spec project.yml
```

> **Warning:** `xcodegen generate` deletes `xcshareddata/xcschemes/` and regenerates schemes from scratch with incorrect values. After any `xcodegen generate` run, always restore the scheme files:
> ```bash
> git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/
> ```

**Bumping the build number or version** — do NOT run `xcodegen generate`. Edit the files directly:
- Build number: change `CURRENT_PROJECT_VERSION` in `project.yml`, then replace all occurrences in `project.pbxproj` (`replace_all: true`)
- Version string: change `MARKETING_VERSION` the same way
- `README.md`: its `Current build: **N** (version X.Y)` line states both, and `CodingStandardsAuditTests.readmeStatesCurrentBuild` fails until it matches `project.yml`. The README is mirrored whole in `Docs/EditableContent/03-Repository-README.md`, so make the same edit there
- Both TestFlight notes, `Docs/TestFlight-Instructions-ios.md` and `Docs/TestFlight-Instructions-mac.md`, rewritten for the new build (4,000 characters each at most; count them with Python's `len()`, because `wc -m` counts bytes in this shell's locale)
- Before the archive: `./Scripts/fetch-llama-dsyms.sh` (see "Before ANY archive" below) and `./Scripts/check_cloudkit_schema.py` (#1531). The second reads Production's CloudKit schema, compares it with `CloudKitSchemaInventory.installedIdentifiers`, and writes the stamp that the archive-only "Check CloudKit schema" build phase on both app targets requires: an archive fails without it. It needs a CloudKit management token saved on the Mac (`xcrun cktool save-token --type management`); `notarize.sh` runs it itself

`DEVELOPMENT_TEAM` and `MARKETING_VERSION` are now declared in `project.yml` so they survive `xcodegen generate`. If Xcode ever sets additional build settings that need to persist, add them to `project.yml` before running xcodegen.

## Build & Test Commands

**One heavy job at a time on this Mac, across every session: run it through `Scripts/heavy.sh`.** A heavy job is any of these:
- an `xcodebuild` build, test or archive;
- `swift build` or `swift test`;
- a `swift run` of a generator;
- `tools/mac-check-copy/build.sh`.

Prefix the command: `Scripts/heavy.sh xcodebuild test …`. The script takes one lock with `/usr/bin/lockf` on a file outside every worktree, so a second job waits for the first however many sessions are running, and prints who holds the lock. `FRUS_HEAVY_WAIT=<seconds>` gives up after that long, with exit status 75. A UI run is a heavy job too, so no build can start in the middle of one.

Why: on 2026-10-18 two sessions ran three builds from empty and a UI run at once on the M5 MacBook Air (fanless, 10 cores, 32 GB).
- The load average reached 785 under thermal pressure.
- The Claude app froze for up to 84 s at a time, and tore one session down after 996 s with no output.
- The Mac had to be restarted.

A request by message between the two sessions had not held.

Four habits go with the lock:
- Run a long job in the background, since the wait is part of its run.
- Reuse a worktree's DerivedData: a build from empty is the costliest job there is.
- Keep one simulator booted, and shut it down after its run.
- Put steps that must follow one another with nothing between them, such as a build and the runs that must use it, in one script under one `heavy.sh` call. Waiters are not served in order (L20, 2026-11-16), and a queued job builds the tree as it stands when it takes the lock, with any edit made while it waited.

**CI** (`.github/workflows/ci.yml`, since 2026-11-26) runs three advisory checks: **A** `Scripts/check_repo_hygiene.py`, the rules no test checks (run it yourself before a pull request: it takes seconds); **B** `swift test`, `build-for-testing` and the Mac build, with no warning but the two known ones; **C** `FRUSExplorerTests` on the iPhone 17 under iOS 27.0, but for the one test `ci.yml` skips and says why. A and B run on every pull request to `v2`, and all three on every push to it, which is after each merge, and by hand. B and C run on GitHub's `xcode-27` image, a preview, about five times slower than the Mac (B 37–50 min and C 60–77, against 6–7 and 12–13 on the Mac, measured 2026-11-26), so do not wait for them: a session's own runs on the Mac stay the check before a merge. The UI suites, device checks and the kits' Linux build stay where they were.

**Run all tests (iOS Simulator):**
```bash
Scripts/heavy.sh xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

**Run a single test suite:**
```bash
Scripts/heavy.sh xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -only-testing FRUSExplorerTests/CitationParserTests
```

**UI suites: which devices, and where the detail is.** One destination gives one idiom's tests, and
a suite that self-skips on the wrong device reports green. `.claude/rules/ui-tests.md` holds the
index (one row per suite: the devices to run it on, and the counts and skips to expect) and the five
rules that hold for every UI run. Claude Code loads it when a session reads or edits a file under
`FRUSExplorerUITests/`; a session that only runs a suite, and a lane's agent, read it first. Each
suite's full entry is in `Planning/UI-Test-Destinations-Runbook.md`: why it needs those devices,
what it measured on the unfixed code, and the exact commands. **Read a suite's row and its entry
before you run it, change it or read its result as a guard** (`grep -n '<SuiteName>'` finds each).
Two of the five rules hold for a unit run as well: an `-only-testing` name that matches nothing
runs zero tests and reports green, so name the test TYPE and read the count back; and a device name
does not name an OS, so pin `OS=` or a UDID.

**Command-line tools: what exists, and where the detail is.** Every generator is a package target
run from the repo root (`swift run -c release <Name>`); a few corpus tools are stdlib-only Python
under `tools/`. `.claude/rules/generators.md` holds the index (one row per tool: what it writes, and
what it reads beyond the corpus) and the rules that span entries. Claude Code loads it when a
session reads or edits a generator's source, a file under `tools/` or a JSON file under
`FRUSExplorer/Resources/`; a session that only runs a tool, and a lane's agent, read it first. Each
tool's entry in `Planning/Generators-Runbook.md` gives its inputs and environment variables, the
figures it last measured, when it refuses to write, and what must be regenerated after it. **Read a
tool's row and its entry before you run it, edit it or quote a figure from its artifact**
(`grep -n '<ToolName>'` finds each). Three of the spanning rules bind a session that opens no
generator, and the rules file has each in full:

- **A refreshed JSON under `FRUSExplorer/Resources/` owes `swift test` and the unit target.** A new
  or renamed bundled resource also needs `xcodegen generate` with the scheme restore, and a new
  bundled JSON a row in `BundledArtifactProvenance.table`.
- **Files that come out of one run are committed together.**
- **A keyed NARA harvest spends a metered quota**: confirm the invocation first.

**Before ANY archive — TestFlight, App Store, or the notarized DMG — cache the query encoder's
debug symbols once:** `./Scripts/fetch-llama-dsyms.sh`. An archive-only build phase on both app
targets ("Embed llama dSYM") **FAILS the archive** when the cache is missing or stale; it never
runs on a plain build or test, and `notarize.sh` runs the fetch itself. `.claude/rules/archive.md`
has the rest: why the dSYMs are not committed, what the phase checks, why a change to it is tested
with `-derivedDataPath` on a real path and never under `/tmp`, and what a rebuild of
`Vendor/llama.xcframework` owes. Claude Code loads it when a session reads or edits a file under
`Scripts/` or `Vendor/`; read it before changing that phase or rebuilding the framework.

**macOS Direct Distribution (notarize + DMG):**
```bash
TEAM_ID=XXXXXXXXXX ./Scripts/notarize.sh
TEAM_ID=XXXXXXXXXX ./Scripts/notarize.sh --dry-run
```

## Architecture

### Layer Overview

```
SwiftUI Views (iOS MainTabView / macOS MainWindowView + window scenes)
        ↓
Service Layer (SearchService, SummarizationService, DownloadManager, etc.)
  (SearchService and the IndexingPipeline that fills the FTS5 index are FRUSCoreKit's)
        ↓
  SwiftData + CloudKit          SQLite FTS5
  (user data: notes, tags,      (search index, cross-refs,
   collections, highlights,      persons, glossaries, dates)
   prompts, projects)
        ↓
TEI Rendering Pipeline: XML → FRUSDocumentParser → FRUSASTNode
                             → ASTToRenderNode → FRUSDocumentRenderer → SwiftUI
  (the parser, the AST, the converter and the HTML serializer are FRUSCoreKit's: Foundation only)
```

### Key Data Flows

- **Download → Index**: `DownloadManager` queues volume files; on completion `IndexingPipeline` parses TEI XML and populates FTS5 tables (documents, persons, cross-references, dates). **`frus:doc-dateTime-min`/`-max` is an INSTANT, not a day**: the corpus's own build writes it through `adjust-dateTime-to-timezone` at `-PT5H`, which preserves the moment and rewrites the local fields, so its first ten characters are the day *at −05:00*. Reading them as the calendar day put 11,847 documents on the wrong one across 480 volumes (#1326, index v54) — a Washington telegram printed 22 October 1962 was stored as the 21st, because the stylesheet uses EST all year round. `IndexingPipeline.sameInstantDay` takes the day from the document's own `<date>` wherever the two name the same instant, and leaves the attribute alone where they do not. `AdministrationProfilesIndexGeneratorCore.DocumentDateExtractor` mirrors that rule; the two are pinned by their own fixtures, not shared code. (The reason given until October 2026, that the app target is not linkable from the SPM package, no longer holds: `IndexingPipeline` is a package target, `FRUSCoreKit`, since #1573. The mirror is still a mirror.) **A volume's `volume_structures` row is also the record that its last store pass finished (#1566)**: `storeIndexData` removes it before it writes anything and writes it last, so it stays the last write of any store path. A volume with documents and no such row was cut short (`volumesWithUnfinishedStore()`); the launch reconcile finishes one the interrupted-indexing sentinel does not name, which is what a power loss leaves, and leaves one it does name to the reader's amber badge. **Since index version 75 the row also names the file the pass parsed (#1909)**: `file_blob_sha1` and `file_size_bytes`, the git blob SHA-1 (`VolumeUpdateChecker.gitBlobSHA1(for:)`, the corrections check's own) and the length of the bytes the pass read once, hashed and parsed through a stream over them (`FRUSDocumentParser.parseVolumeFull(volumeData:named:)`, which gives the delegates the events a parse of the file gives, where `XMLParser(data:)` splits text at other places). So a pass cut short leaves no record rather than a stale one, and an export names the files it was made from (`IndexedVolumeFile`, `indexedVolumeFiles()`).
- **Search**: `SearchService` queries FTS5 with BM25 ranking and English stemming; results flow to `SearchView`. A search stops when its task is cancelled (#1680): the pipeline's connection (`auxDb`) carries one SQLite progress handler (`SearchStatementStop`), which stops only the statements `searchDocuments` and `searchDocumentsCount` arm with a task-local value, and `SearchService`'s snippet loop checks cancellation at each row. A connection has one progress handler, so **register no other on `auxDb`**: it would silently replace this one.
- **Document rendering**: TEI XML is parsed into an AST (`FRUSASTNode`), converted to render nodes, and displayed via `FRUSDocumentRenderer`. Highlights are overlaid post-render.
- **Figure images (#1516)**: when a volume's download finishes, `DownloadManager` fetches the images its `<figure>`s name — the `<graphic url>` outside the title page — from `https://static.history.state.gov/frus/<volume>/<url>.png` into `{Volumes}/<volume>.figures/`, removes them with the volume, and counts them in Volumes & Storage. **The rule is "a `<graphic>` in a `<figure>`", never "every `<graphic>`"**: a page's scan is a `<graphic>` too, in `<facsimile><surface>`, and the 553 manifest volumes hold 1,143,043 of those against 992 in figures. `.png` is added to every name (`OpenPitMine.jpg` is served only as `OpenPitMine.jpg.png`), and a file the host does not have answers **403**, not 404. Measured 2026-10-01 by HEAD request at corpus `8e5da08c1`: 553 images, 140,994,857 bytes, in 96 volumes, and 13 more names refused; a second pass read each one's first 24 bytes, and all 553 open with the PNG signature (the widest is 19,043 pixels). **A volume already on the device — downloaded before build 49, or left short by a failed or interrupted run — is brought up to its images by `DownloadManager.fetchMissingFigureImages(among:)`, which the app starts at launch and each time the device comes back online**, for catalogue volumes only; a volume whose run ended with nothing left to fetch is recorded in `{Volumes}/.figure-images-complete.json` against its XML's size and modification date, so the library is scanned once and not at every launch, and the pass stops after three volumes in a row whose transfers all fail. Until the pass reaches a volume, the reader and a PDF, Word or HTML export fetch the one image they need (`FigureImageStore`), only while online; BibTeX, RIS and the Zotero send fetch none. **In a unit test's host the app's store is left unconfigured and the pass is not started** (`FigureImageStore.isUnitTestHost`): the tests run inside the app, whose boot would otherwise point every default at the simulator's own volumes and at the network. The reader draws an image through `frusexplorer://figure/…` (`FRUSURLSchemeHandler`); PDF, Word and HTML exports embed it. **A figure's head, captions and placeholder, and the space between two inline elements (`.elementSpace`), are drawn under `data-skip` and are not flat text**, so `renderingVersion`, `body_hash`, `body_text` and every stored highlight stayed where they were and the change took no index version. `renderingVersion` cannot see drawn text that leaks out of `data-skip`; only `FigureReaderTests`' Swift/JS parity, in a real web view, does.
- **Summarization**: `SummarizationService` and `BackgroundSummarizationService` call Apple's `FoundationModels` framework (on-device); summaries stored in SwiftData and indexed in FTS5.
- **User data sync**: SwiftData models sync automatically via CloudKit (`iCloud.bottsywattsy.FRUS-Explorer`).

### Platform Layout Split

- **iOS/iPadOS**: `MainTabView` with 5 tabs — Browse, Search, Research, Collections, Settings. iPad adds `.inspector(isPresented:)` panels (Search's Facets among them), the document's Research rail as a trailing column the reader draws itself (R6a, F8: an open `.inspector` becomes a sheet as a window narrows) and Stage Manager multi-window scenes.
- **macOS**: `MainWindowView` with sidebar navigation plus dedicated window scenes for Search, Browser, CrossReference, SourceExplorer, and Collections.

The `#if os(iOS)` / `#if os(macOS)` conditional compilation pattern is used extensively throughout views.

### Directory Map (`FRUSExplorer/`)

| Directory | Purpose |
|-----------|---------|
| `App/` | `@main` entry point, `AppState`, `ContentView`, routing |
| `Models/` | SwiftData model types and tag/person/highlight models; the manifest structs, `CountCopy`, `PersonMentionStore`, the summary formats and authorship (`SummaryTypes.swift`), an Archives Visit's tiers and deliverables (`ArchiveVisitValues.swift`) and, since FRUS Explorer Light's S30b, the order a duplicate is kept by (`DuplicateRecordOrder.swift`, which `DuplicateRecordCleanup` forwards to) are in `FRUSCoreKit/Models/`, and so, since S17b, are the research layer's rules over values: the working corpus's resolver, the document gate and the capture's truncation (`WorkingCorpusResolver.swift`), a volume scope's resolution (`CustomScopeResolver.swift`), the trail's sessions (`ResearchTrailSessions.swift`), the projects' and tags' tallies (`ResearchItemCounts.swift`), All Notes' rows and filters (`NotesPaneSnapshot.swift`), a corpus's coverage (`DocumentEngagement.swift`) and `CollectionEntryKind`; their fetches stay here (`ResearchTrailSessions+App.swift`, `ResearchItemCounts+App.swift`, `NotesPaneSnapshot+App.swift`). Since S21a the live listing's diff (`Manifest/ManifestLiveDiff.swift`) and the catalogue of side-loaded volumes (`Manifest/LocalVolumeCatalog.swift`) are in `FRUSCoreKit/Models/` too; `ManifestStore` and its fetch stay here. The highlight colours (`HighlightColor`) and the shape the reader's renderer reads (`ReaderHighlight`, which `DocumentHighlight.HighlightDTO` names) are in `FRUSCoreKit/TEI/` |
| `Search/` | `SearchView`, its view models and the search UI; `IndexingPipeline+App.swift` (the pipeline's Spotlight donation, its bundled data files and the initialiser the app calls) and `CollocationService.swift` (Collocates' live configuration and the scan behind the readiness gate; the scan itself is `FRUSCoreKit/Search/SearchService+Collocation.swift` since FRUS Explorer Light's S29b); `SearchService` and `IndexingPipeline` (the largest file) are in `FRUSCoreKit/Search/`, as are the facet panel's narrowing and staged selection, the Query Inspector's model, `SearchSortOrder`, `DocumentHeaderDisplay` and, since S17b, a saved search's watermark (`SavedSearchFreshness`), the scope signature (`SearchScopeSignature`, with `QueryQuoting`) and a recorded search's values and count (`RecordedSearch`); the method appendix is in `FRUSCoreKit/Export/` (the app's half is `Export/QueryMethodAppendix+App.swift`), the provenance sources and statement in `FRUSCoreKit/Provenance/`, and the Research page's aggregation in `FRUSCoreKit/Research/`. Since FRUS Explorer Light's S27a search by meaning's engine is in `FRUSCoreKit/Search/` too: the searcher (`SemanticQuerySearcher`, over a host's `SemanticQueryEncoding` and shards), the Meaning engine (`SemanticSearchBackend`), Search Within These Results' held list and composer (`SearchLayering.swift`, with `ExecutedSearchRoute` and `UserTagCountScope`), the timing lines (`SearchTimingLog`) and the words the Meaning views draw (`SemanticSearchCopy.swift`); the app's halves are `SemanticSearchBackend+App.swift`, `SearchLayering+App.swift` and `Semantic/SemanticQuerySearcher+App.swift`, whose `SemanticOnDeviceEncoder` holds the llama encoder and its 180-second idle rule |
| `TEI/` | The reader's web view and its configuration, `HTMLTemplate` (which forwards to the kit's `ReaderPage`), the `frusexplorer://` scheme handler, the AST cache and the rendering config; the XML parser, AST types, AST-to-render conversion, HTML serializer, the reader's page (`ReaderPage`, `ReaderAppearance`, `TextSizePreference`), its footnote landing (`FootnoteLanding`), its three annotation scripts (`ReaderAnnotationScripts.swift`), and where a link to a whole volume or a printed page goes (`WholeVolumeLink`, `PageLink`) are in `FRUSCoreKit/TEI/` |
| `Browser/` | Volume/subseries/corpus navigation with breadcrumb trail; `VolumeStructure` is in `FRUSCoreKit/Browser/`, and Browse's semantic clusters' axis (`ClustersAxis`) in `FRUSCoreKit/Semantic/` with the semantic map's rules |
| `DocumentView/` | Document display, the shared Research rail + floating selection bar, cross-reference links; `DocumentDisplayTitle`, the selection verbs (`SelectionVerb`), the re-anchor's search (`HighlightReanchor`) and, since S21a, the update review's `ExcerptReview` and `HighlightReview`'s status rule (`HighlightReviewStatus.swift`, which the app's `HighlightReview.swift` extends) are in `FRUSCoreKit/DocumentView/` |
| `CrossReference/` | Graph visualization and its view model; the store (`CrossReferenceStore`), its models, the resolved-edge index, `DocumentNodeKey`, the graph's display half (`CrossReferenceGraphDisplay`), `BrokenRefsIndex` and `RelatedCitationCandidate` are in `FRUSCoreKit/CrossReference/`, and the bundle loaders (`BrokenRefsIndexStore`, `ResolvedEdgeIndexStore`, `CitedPageMapStore`) and the store's initialiser that passes them (`CrossReferenceStore+App.swift`) stay here |
| `Collections/` | Collection editor, the content resolver over SwiftData and `AppState` (the data source of FRUSCoreKit's assembly), the PDF exporter, the format list and the RTF decoder (`CollectionExporter+App.swift`), the outline's rules over `CollectionEntry` (`CollectionOutline+App.swift`), and the SwiftData halves of the `.fruscollection` format (`NativeCollectionFormat+App.swift`) and the smart snapshot (`SmartCollectionSnapshot+App.swift`); the content assembly (`CollectionContentAssembly`) and its data source, the five apparatus blocks (`CollectionGeneratedBlocks`), the `.fruscollection` file, writer and importer over values, the smart snapshot and its search, the export's payloads, options, presets and naming, the HTML, Word, BibTeX and RIS exporters, the outline's value core, `CollectionEditorNaming`, `CollectionGeneratedBlockType` and the Add Documents sheet's citation line resolver are in `FRUSCoreKit/Collections/`, and the quotation check (`ExcerptVerifier`) in `FRUSCoreKit/Export/` |
| `Citation/` | Citation Lookup's view, the Zotero export's library lookup (`ZoteroJSONExporter+App.swift`) and the citation-style preference; the formatter, models, parser, canonical URL, page-span resolver, matching engine, block splitter, page-range store, the lookup form's fields, `CitableVolumeCatalogue`, the BibTeX, RIS and Zotero exporters and the TEI's publication year are in `FRUSCoreKit/Citation/` |
| `Summarization/` | Apple Intelligence integration, prompt management UI |
| `SourceExplorer/` | NARA catalog integration and the views; the bundled archival indexes' stores, and the overloads that pass them (`ArchivalResolver+App.swift`, `PresidentialLibraryOutcome+App.swift`, `SourceExplorerProvenance+App.swift`, `SourceExplorerResolution+App.swift`, `NARALookupAnalyzer+App.swift`); the Keychain as the NARA client's key provider (`NARACatalogClient+App.swift`) and the names the views read the kit's panel rules by (`SourceExplorerView+Panels.swift`); the readers and resolvers, with `ArchivalResolver`, the classifier and `SourceExplorerResolution`, the sequence both views run, the NARA Catalog client, the lookup analyzer, `LookupStrategy` and `SourceExplorerPanels`, are in `FRUSCoreKit/SourceExplorer/`, and the Zotero client in `FRUSCoreKit/Zotero/` |
| `TripPacket/` | Archives Visits: the plans' editor, list, Mac manager and plan picker, the packet's sheet with its PDF drawing, the plan's rows mapped to the kit's records and the rows its rules answer applied through the context (`ArchiveVisitDerivation+App.swift`), and the forms that pass the app's bundled indexes (`TripPacket+App.swift`); the packet's builder, data source, model, exporter and rules, the overlay, the counts, the derivation (`ArchiveVisitDerivation.swift`) and the plan's write rules (`ArchiveVisitPlanWrites.swift`) are in `FRUSCoreKit/TripPacket/` |
| `Downloads/` | `DownloadManager`, download queue UI; the corrections check (`VolumeUpdateChecker`, with the git blob SHA-1) is in `FRUSCoreKit/Downloads/` |
| `Analytics/` | The Analytics family, all Swift Charts: corpus term frequency, Person, Cross-Reference, and Archival (era × archival-unit rankings + the user's own archival profile); Cross-Reference Analytics' `CrossReferenceStats` and `PageRank` are in `FRUSCoreKit/Analytics/`, and so are Corpus Analytics' service with its series, units, axes, occurrence rule, dispersion, scrub and search hand-off, the volume folding (`AnalyticsSourceColoring`), and the method block (`FRUSCoreKit/Analytics/Export/`: `AnalyticsProvenance`, which renders for an `AnalyticsProvenance.Host`, the app's names passing its own from `Export/AnalyticsProvenance+App.swift`, `AnalyticsChartTables`, `ChartInspectorData` and `SeriesAnalyticsExport`); since FRUS Explorer Light's S24b, Person Analytics' maths (`PersonAnalyticsMath.swift`) and the co-mention network's choice of nodes and edges (`PersonCoMentionNetwork.swift`), whose layout, labels and viewport stay in `PersonCoMentionGraphView.swift`, and About the Series' data (`FRUSCoreKit/Analytics/Series/`: production, the publication-lag target, geography, provenance and administration profiles, with the two aggregates' loaders by URL, and the charts' year range, `SeriesAxisRange.swift`) with its tables (`Export/ChartInspectorAdapters.swift`); the series' stores, dashboards and `PoliticalParty`'s colour (`SeriesAnalytics/PoliticalParty+Color.swift`) stay in `SeriesAnalytics/`, and Chronology's rules are the kit's `Chronology/ChronologyGrouping.swift`, `ChronologyViewModel` keeping its state, `reload()` and the names; since FRUS Explorer Light's S24c, Archival Analytics' derivations (`FRUSCoreKit/Analytics/Archival/`: the axes, the counts, the Collections ranking, the network's graph and layout, the flows and the reader's library profile) with their export statements (`Export/ArchivalAnalyticsExport.swift`), and the graphs' label rules (`GraphNodeLabels.swift`), which the co-mention, volume, cross-reference and archival canvases place their labels by; the app keeps `make` over its stores (`ArchivalCollectionsData+App.swift`), the network's caption measure and the `layout(_:in:)` that passes it (`ArchivalNetworkBuilder+App.swift`), the custodians' tints (`ArchivalRepositoryCategory+Color.swift`) and the label plate's drawing (`PersonCoMentionGraphView.swift`) |
| `Theme/` | `FRUSTheme` (colors, typography constants) |
| `Resources/` | Bundled JSON: manifest, taxonomy, subject tags, TEI config |

`FRUSCoreKit/` sits beside `FRUSExplorer/`, not inside it, with subfolders that mirror the app's (`TEI/`, `Citation/`, `CrossReference/`, `Browser/`, `Collections/`, `DocumentView/`, `Export/`, `Models/`, `Search/`, `Chronology/`, `RelatedDocuments/`, `Analytics/`, `Provenance/`, `Research/`, `SourceExplorer/`, `ProjectContext/`, `Downloads/`, `Settings/`, `TripPacket/`, `Semantic/`) and a `Linux/` of stand-ins that Apple platforms compile out. Both app targets compile it, and so does an SPM target of its own: read `FRUSCoreKit` under **SPM package targets** below before editing it.

- `SemanticVectorsKit` — the semantic-vector artifact contract: binary layouts, the
  document-id run-length encoding that keys every row, mmap readers for the bundled
  corpus tier and the per-volume shards, and the retrieval kernel. Compiled into the app
  targets via `project.yml` (the WordCloudKit/FTS5Store pattern) **and** an SPM library
  target, so `SemanticVectorsGenerator` writes through the declarations the device reads
  through. Two rules to know before touching it. **The kernel's tie-breaks are the measurement**:
  changing one silently invalidates the recall the artifact states. And identity NEVER comes from
  a shard's position in local XML but always from the bundled index's segments, because a
  re-published volume changes the XML and not the artifact. `.claude/rules/semantic-vectors.md`
  has the whole entry: the kernel's timings and why there is no ANN index, the app's loaders in
  `FRUSExplorer/Semantic/`, the shards' fetch (eager with a download, lazy for a library already
  on disk), the storage section both hubs mount and what it may claim, and the download switch,
  which is device-local and deliberately not on `SyncedPreferences`. Claude Code loads it when a
  session reads or edits a file under `SemanticVectorsKit/`, `FRUSExplorer/Semantic/` or
  `FRUSCoreKit/Semantic/`; read it before changing any of those.

**SPM package targets** (`Package.swift`, package name `FRUSExplorerTools`, macOS 15+). This is a build-tool package, not a library distribution: it declares **no `products:` block at all**, so nothing here is linkable from outside — the app reaches the shared code by compiling the same source directories through `project.yml`. It currently declares **40 library targets, 32 executables and 39 test targets** (111, `swift package describe`, counted 2026-11-06 when VolumeAnnotationsIndexGenerator was added; 39, 31 and 38 from 2026-10-04, when FRUSCoreKit and FRUSCoreKitTests were added; 38, 31 and 37 from 2026-10-01; the line read 37, 30 and 36 until then); every generator indexed in `.claude/rules/generators.md`, and documented in `Planning/Generators-Runbook.md`, lives here. Do not read the list below as an inventory — read `Package.swift`.

The **shared** (non-per-tool) library targets are the ones worth knowing by name:
- `FTS5Store` — the reusable SQLite FTS5 actor. `LinuxLogger.swift` stands in for `os.Logger` on Linux and compiles to nothing on Apple platforms, so keep FTS5Store's logging to `debug`, `info`, `notice`, `warning` and `error` with plain `privacy:` interpolation.
- `SourceNoteKit` — the FRUS source-note parser.
- `TEIHeaderKit` — the `<teiHeader>` grammar `manifest.json` was built from (#777).
- `SemanticVectorsKit` — the semantic-vector artifact contract (see above).
- `GeneratorKit` — the generators' shared plumbing: `VolumeCorpusEnumerator`, a stderr logger, the reproducible `yyyy-MM-dd` stamp, an RFC-4180 `CSVWriter`.
- `CrossRefKit` — the cross-reference grammar; **SPM-only**, a mirror of `FRUSURLScheme.resolveCrossRefTarget` (FRUSCoreKit) rather than shared source, whose hard-coded fixtures never call the app: it has drifted on the three branches the app has changed since: footnote anchors (`.footnote`, #988), `mailto:` targets and whole-volume targets (`.volume`, #1603).
- `FRUSCoreKit` — the code FRUS Explorer Light, the web edition, compiles on Linux from a pinned commit, and both app targets compile into their own module: the TEI parser, AST, render nodes, AST-to-render converter and HTML serializer, the reader's page and links, the citation code, the indexing pipeline and the search service, and the rules over values of nearly every feature since (collections, Source Explorer, Related Documents, the cross-reference graph, the analytics, the semantic map, the word cloud, Archives Visits, the research export and its import). It depends on SourceNoteKit, FTS5Store, TEIHeaderKit, SemanticVectorsKit and WordCloudKit. **`Planning/FRUSCoreKit-Runbook.md` has what it holds by area**: which of the app's names forward to it, what each web-edition phase moved or made public, the seams a host passes, and the test support files, one headed paragraph per area, moved there from this entry word for word on 2026-11-26. `grep -n '<TypeName>'` finds a paragraph; read an area's before changing it. **A move into the kit, or a declaration made public for a host, is recorded there and not here.** This entry keeps the rules that bind every change:
  - **Foundation only**: FoundationXML, FoundationNetworking, CryptoKit (swift-crypto's `Crypto` on Linux), OSLog, SQLite3 (the web edition's `CSQLite` on Linux), FTS5Store, SourceNoteKit, TEIHeaderKit, CoreGraphics, SemanticVectorsKit and WordCloudKit are imported behind `canImport`, and the stand-ins under `Linux/` compile to nothing on Apple platforms.
  - **The kit never reads `Bundle.main` or `UserDefaults`.** A host passes what it read: the bundled data files as `IndexingResources`, an `IndexingStampStore`, an index by URL (`init(contentsOf:)`), the app's state as a dependencies value. The stores and loaders that read the bundle stay in the app, as do the overloads that pass them (`…Store.swift`, `…+App.swift`).
  - **A declaration the kit needs that lives in an Apple-only file moves INTO the kit, never the reverse**, and the app keeps the old name as a forwarder or typealias. The kit's rules run over values, and the app maps its SwiftData models to them in app files.
  - **`public` alone does not mark what the web edition uses**: the kit's other `public` declarations were already `public` in the app. Access changes nothing for the app, which compiles the kit into its own module.
  - **Pins by SHA-256, each re-taken with its reason**: `SearchStatementTextTests` (the text and binds of every statement the app's calls run on a search's user half; the app passes no `SearchUserSource`), `CollectionRenderingTests` (the HTML, Word, BibTeX and RIS a set of collections renders to), `CollectionResolutionTests` (a fixture collection's resolved items), and the reader's page and scripts (*Coding Standards*, below).
  - **The research export**: a field or type added to it goes into the kit's envelope with a version bump there, and into `makeEnvelope`. A format version bump owes `ResearchImportPlan.Fields` a case for each field it adds to a type an earlier version carried, and `ModelType` the version of each new type; `ResearchDataFixtures` keeps a file of each version, which the kit's suite decodes.
  - **The app never turns on `setStopsBetweenBatchesWhenCancelled(_:)`**, so the background indexing task iOS expires runs on as before.
  - **Its suites live in `FRUSExplorerTests/FRUSCoreKit/` and are compiled twice**, into the app's test target by Xcode and against the kit alone by `FRUSCoreKitTests`, so anything there that needs the app (its module, its bundle or its views' source) goes inside `#if !SWIFT_PACKAGE`. The `…TestSupport.swift` files there give the package's suites what the test host gives Xcode's; the runbook says what each gives.
  - **Both folders are Foundation-only: after editing either, run `swift build --target FRUSCoreKit` and `swift test --filter FRUSCoreKitTests`.** The app builds even when a kit file names an app type, since it compiles both into one module; only the package and `FRUSCoreKitBoundaryTests` catch it.

All of these except `CrossRefKit` and `GeneratorKit` are ALSO compiled directly into both app targets by `project.yml`, so the generators write through the declarations the app reads through.
- `WordCloudKit` — the word-cloud tokenizer stack (`WordCloudTokenizer`,
  `WordCloudMultiLensTokenizer`, `WordCloudLens`, `WordCloudTuning`, `TermCount`,
  `WordCloudLexiconSet`, `WordCloudStopwordSet`), with `Keyness` and the two artifacts' readers by
  URL. Compiled directly into the app targets via `project.yml` (like `FTS5Store`/`SourceNoteKit`)
  **and** an SPM library target, so `CloudVectorsGenerator` tokenises the corpus through the app's
  own code; the web edition compiles it on Linux. The rules that bind every change:
  - Lexicon/stopword payloads are **injected**, never read from `Bundle.main`.
  - The tokenizers read a tagger through `WordCloudTagger`. NaturalLanguage and `os` are imported
    only behind `canImport(NaturalLanguage)`, and so is a WordCloudKitTests suite that tags with it.
  - `WordCloudMultiLensTokenizer` counts N lenses from one pass. `WordCloudKitTests` pins it against
    N single-lens runs, and `WordCloudPrintedFormParityTests` the printed-form tally against a
    `.printed` tokenizer's: those parity suites are what makes the merge safe — do not weaken them.
  - A stamp of NaturalLanguage's tokenizer at version 1 is written without its key, so the bundled
    files stand byte for byte and the generator writes the bytes it wrote.

  `.claude/rules/word-cloud.md` has the whole entry (the tagger protocol, the tokenizer's identity
  and the refusal of a scope counted by another, what is unavailable where NaturalLanguage is
  missing, what FRUSCoreKit took in S29b) and, after it, how to see a launch with no lemmatiser
  (#1608). Claude Code loads it when a session reads or edits a file under `WordCloudKit/`, its
  tests, `CloudVectorsGenerator*/` or either `Analytics/WordCloud/` folder.
- Test targets: **39 of them**, one per tool plus one per shared kit — `FRUSCoreKitTests` compiled from `FRUSExplorerTests/FRUSCoreKit/` — except `TEIHeaderKit`, whose grammar is exercised from `ManifestGeneratorTests` (`TEIHeaderParserTests`, `ManifestStatusPolicyTests`) rather than a suite of its own. The shape is uniform — each tool is a `<Name>GeneratorCore` library (all logic, testable), a thin `<Name>Generator` executable (entry point only) and a `<Name>GeneratorTests` suite that imports the Core. `swift test` runs the lot; there is no curated subset to know by heart.

## Coding Standards

**Six of these have a mechanical gate, and three of the six are narrow spot-checks rather than tree-wide rules. Check everything else by hand — do not assume a test will catch you.** (The heading used to read "enforced by `CodingStandardsAuditTests`", which was true of half the list and let several stale doc comments ship unnoticed.)

Enforced by `CodingStandardsAuditTests` — these fail the test suite:

- **License header**: Apache 2.0 header required on every source file *and* every test file of a built target, within the file's first 20 lines, the "Licensed under" line and the license URL both. Every built target since 2026-10-01: the app, both test targets (`FRUSExplorerUITests` was outside the scan until then), the widgets, `Package.swift`, and every directory a package target names as its `path:` — 1,174 Swift files in 110 directories when measured, none missing it. **Not the whole tree**: Swift under `tools/` and `Planning/` belongs to no target and is not scanned, and 14 such files carry no header (three in `tools/map-film/`, eleven harness files under `Planning/early-era-people/`).
- **OpenAPI spec** (`FRUS-API.openapi.yaml`): must remain valid OpenAPI 3.1.0, declare no deprecated `nullable: true`, and define the `/citation-lookup` endpoint + `CitationMatch` schema. Update whenever the API surface changes.
- **Version history**: required on an **allowlist** of key session-output files (not all files).
- **Debug logging** (spot-check, not tree-wide): `#if DEBUG` blocks with a `print("[TypeName] ...")` prefix. Three tests pin exactly three files — `CitationParser`, `CitationMatchingEngine`, `PageRangeStore` — each asserting both `#if DEBUG` and that type's own log prefix (`[CitationMatcher]` for `CitationMatchingEngine`, note). Everywhere else is by hand.
- **Test-container hermeticity** (tree-wide, both test targets): every `ModelConfiguration(` in `FRUSExplorerTests` and `FRUSExplorerUITests` must pass `cloudKitDatabase: .none`. The parameter defaults to `.automatic`, which adopts the **test host app's** iCloud entitlement, so an in-memory test store built without it gets a real `NSCloudKitMirroringDelegate` whose setup runs asynchronously and outlives the test that created it. Measured on `v2` @ `9078fe61` (#1325), nine such calls crashed the host five times with `NSInternalInconsistencyException: 'No eligible connection available'` and the unit target ended `** TEST EXECUTE FAILED **` — while the log's own last line said the run had passed. The scan walks each call's balanced parentheses, so a call split across lines is read whole; it does **not** skip comments or string literals, and `CodingStandardsAuditTests.swift` is excluded BY NAME because it holds the search string itself.
- **Localization** (spot-check, and a weak one): `keyViewsUseLocalization` opens exactly three views — `CitationLookupView`, `CrossReferenceGraphView`, `AboutView` — and asserts only that each file mentions `localized:` *somewhere*. It cannot see a bare `Text("…")` sitting next to one, and it says nothing about any other view in the tree.

**`Docs/EditableContent/` has a gate of its own, outside `CodingStandardsAuditTests` and the six above.** The owner's editing surface is one markdown file per app area (split from the single `Docs/EditableContent.md` on 2026-09-28; its `README.md` lists them, `History/` holds dated snapshots the tests skip, and a change is logged as one bullet at the end of `Amendment-Log.md`). A block's text is always what the app ships; the owner's unlanded edits sit after a block as ✎ boxes and wording issues as ⚑ callouts, neither of which is written back. `EditableContentKeyTests` fails when a block names a key its source file lacks and, since #1424, when a block's `lines:` range no longer holds that key's quoted literal. So a change that moves lines in a Swift file re-points every ranged block citing that file — start the range on the key's line and keep its length; the failure names each key's real line, and no re-point script is committed — and a RETIRED block carries no range, with its banner kept to four lines, since the marker must sit in the five lines above the annotation. Blocks with no `lines:` field are not checked. Gating the ranges at all is #1424's open owner decision (the issue allowed them to stay advisory); the suite's doc comment says which test to delete if the owner so decides.

**`FRUSCoreKit/` has a gate of its own as well.** `FRUSCoreKitBoundaryTests` fails when a kit file imports anything but Foundation (an attribute or an access level before `import` included) outside the `canImport` that selects FoundationXML, FoundationNetworking, CryptoKit, `Crypto`, SourceNoteKit, OSLog, SQLite3 (`CSQLite` in its `#else`), FTS5Store, TEIHeaderKit, CoreGraphics, SemanticVectorsKit or WordCloudKit; reads `Bundle.main` (a `Bundle = .main` or `Bundle? = .main` default and a `bundle: .main` argument included), `UserDefaults` or the Keychain; or names, outside comments and string literals, a type, function, constant or variable declared at the top level of a file under `FRUSExplorer/`. It also fails on code under `FRUSCoreKit/Linux/` that sits outside a `#if !canImport(…)`, and on a suite under `FRUSExplorerTests/FRUSCoreKit/` that, outside Xcode's branches, imports the app (a module the kit may use is allowed there, behind the `canImport` that selects it) or names a top-level declaration of the app's or of the test target's other files — Xcode builds and passes such a suite, and only `swift test` would fail. Both name checks read a name only where it can mean that declaration: they skip a member after a `.`, an argument label or parameter (a name followed by `:` inside parentheses), and any name the kit or the suites declare for themselves, at any depth. So a change to the app alone does not fail them by adding a top-level declaration whose name the kit uses for something else; if one does, the name is one the kit takes from Foundation or the standard library (`URL`, `max`), which the app's declaration now meets in one module, and the app's declaration is the one to rename. It reads source, so a member the app adds to a kit or Foundation type is out of its reach, and so is a kit use of an app name the kit also declares somewhere; `swift build --target FRUSCoreKit` is not. The scans whose rule a kit file can break — the copy scans, the Search Tips key scan, the localized-Markdown census, the `Used by` check, the unused `private var` check and the space-joined `plainText` check among them — read `FRUSCoreKit/` with `FRUSExplorer/` through `AppSourceTree`; the scans for views, scenes, windows and models read `FRUSExplorer/` alone, and `AppSourceTreeTests` (#1604) fails on a test file that walks the app's folder alone and is not on its list, each entry with its reason.

**The other shared kits have the same gate, since FRUS Explorer Light's #1911.** `SharedKitsBoundaryTests`, in the same file and with its scanner, holds FTS5Store, SourceNoteKit, CrossRefKit, GeneratorKit, TEIHeaderKit, SemanticVectorsKit, WordCloudKit and eight generators' cores (ManifestGeneratorCore, CloudVectorsGeneratorCore, and SourceExplorerExportGeneratorCore with the five it builds on), and their suites' folders, to the same three rules: each kit's imports only behind the guards its row in `SharedKitsBoundaryTests.kits` names, or anywhere with the reason the row gives (a generator core's package dependencies, ManifestGeneratorCore's TEIHeaderKit among them, since no app target compiles a file of a core's that imports one); no read of the bundle, the settings or the Keychain; and no name declared at the top level of a file under `FRUSExplorer/`, nor, in a suite, under `FRUSExplorerTests/`. A suite's lines that only Xcode compiles are exempt, as for FRUSCoreKit's. A kit added to the shared code in the "Web edition" section below needs its row there, which a test of the suite's checks against that section's list.

**A test that pins specific language is an advisory reminder, not a firm constraint (the owner's decision of 2026-10-14, plan of record decision 9).** `ReaderPageTests`' head pins, `CollectionTests.publishedExampleMatchesTheGuide` (the `Docs/Agentic-Analysis-Guide.md` §15.1 block), `EditableContentKeyTests`' ranges and `planOfRecordMatchesTheVisualMarketingPlan` each fail when an edit touches text they read. That failure says "this moved", not "do not move it": when there is a good reason to change the text, change it, bring the test to the new text in the same change, and write the reason where the test is. The gates on behaviour (contrast, hermeticity, the boundary scans) are not covered by this rule.

**The reader's page has a gate too, since #1575 and #1578.** Change the page in the kit (`FRUSCoreKit/TEI/ReaderPage.swift`), never in `HTMLTemplate` or `FRUSTheme.cssVariables`, which forward to it. Four pins by SHA-256 and length fail on any changed byte, a comment inside the CSS included: `ReaderPageTests` (the page's head, eight pins over both appearances and four text sizes), `ReaderAnnotationScriptTests` (the three annotation scripts, which a web host serves as the app injects them), and `CollectionRenderingPinTests` (the collection export's pages, whose stylesheet is the reader's, so a change to it moves its three HTML pins too). Re-take a pin from the failure message and say why in the comment above it. The same suites hold the page to 4.5:1 contrast, its links to an underline on screen and none on paper, the links of a list item of links alone to boxes 24 px square, and the reader's link parse to a table of hrefs (`ReaderLinkTests`). `.claude/rules/reader-page.md` has the whole paragraph: what each suite reads, how the print rule and the boxes were measured in WebKit, the export's own colour list, and what a new reader host owes. Claude Code loads it when a session reads or edits one of those files; read it before changing the page, the serializer's links or a pin.

**After a change to shared code, three runs, and the first two are not Xcode's.** `swift build --target FRUSCoreKit` is the only build that sees a kit file calling a member an app extension adds, or naming a declaration of WordCloudKit, SemanticVectorsKit or TEIHeaderKit: Xcode compiles the kit into the app module, and `FRUSCoreKitBoundaryTests` reads names declared under `FRUSExplorer/` alone. `swift test` is the second (measured 2026-10-07 at `f384d2d5`: exit 0, 38 `Test run with` lines, one per test target, 2,557 tests in all, about two minutes with the package built and about four from an empty build folder); it is also owed after regenerating a JSON file under `FRUSExplorer/Resources/`, which package suites read from the repository. A `--filter` that matches nothing runs zero tests and exits 0, so read the counts back. Then the unit target and the Mac build as for any change: every kit file is Mac-compiled.

**A view nothing constructs has a gate too, since #1484.** `UnconstructedViewAuditTests` (in `ToolbarAccessibilityAuditTests.swift`) fails when a type under `FRUSExplorer/` whose header names `View` is named by no code besides its own declaration and its extensions — comments and string literals blanked, every `#if` branch kept, so a view only the Mac constructs counts as constructed. It was written after two whole screens nothing presented, `PromptsListView` and `GlobalContextView`, were found by reading. Measured 2026-10-01: 480 files, 394 such types, 2 unnamed — `FilterChip` (`App/SearchSheet.swift`) and `CrossProjectNoteIndicator` (`DocumentView/DocumentView.swift`), both listed in its `knownUnnamed`, which is an exact exception list and not permission. **A pass says nothing is unnamed, not that nothing is dead**: it cannot see a view constructed only by code that is itself never called (`SubseriesListView` was, by `BrowserView.splitLayout`), so before deleting a file by name, still enumerate what it declares and who names each symbol.

Conventions with **no** automated check — reviewer's responsibility:

- **Swift 6 strict concurrency**: zero warnings under `SWIFT_STRICT_CONCURRENCY=complete`. This is a build setting, not part of the audit suite. **Verify with a CLEAN build — an incremental one reports nothing, because it does not recompile the files that would warn.** Measured 2026-08-02 on a clean build of both schemes: **zero source warnings**. Re-measured 2026-09-17 on **Xcode 27.0 (Swift 6.4)**, which surfaced ten new app-target warnings — seven files naming `ModelContext` without `import SwiftData` (member-import visibility is now enforced), an un-awaited call into the `DownloadManager` actor, and a `[weak appState]` flagged `#ImplicitStrongCapture` — all fixed, so zero again. **The test targets are at zero too, since 2026-09-18** (they had 53 unit-test and 1,438 UI-test warnings), so verify with a clean `build-for-testing`, not a plain build, which never compiles them. They drifted once: five unit-test warnings came back (#1405) and were fixed, and **a clean `build-for-testing` of the `FRUSExplorer` scheme on 2026-09-26 (Xcode 27.0, iOS Simulator, both test targets compiled) printed zero source warnings** — the only warning lines were the two residues below, the `GeneratedSummary` one as 2 diagnostics. Two rules keep them there. **A UI suite is `@MainActor` and overrides the ASYNC `setUp()`/`tearDown()`**, because the XCUI APIs are main-actor and XCTestCase's synchronous `setUpWithError`/`tearDownWithError` are nonisolated (see the head note in `UIObstructionTests`). **Never write `try? #require(x)`**: under Swift 6.4 it binds `#require`'s non-optional overload and a nil PASSES SILENTLY, measured in a scratch package, so use `try #require` in a `throws` test. Two known non-source residues remain and are not ours to fix: the SwiftData `@Model` macro synthesises a plain `Sendable` for `GeneratedSummary`, which already declares `@unchecked Sendable` (it must — removing it fails `SummarizationServiceTests`), giving 2 "redundant conformance" diagnostics per clean build on Xcode 27.0 — 4 `warning:` lines in the log, since xcodebuild echoes each under its caret, in both the iOS `build-for-testing` and the `FRUSExplorerMac` build of 2026-09-26 (#661 counted ~75 iOS / ~25 macOS lines on 2026-08-02, before Xcode 27); and `appintentsmetadataprocessor` notes there is no AppIntents dependency. Note the `FRUSExplorer` scheme builds **both** app modules, so a `#if os(macOS)` file's warnings surface in an "iOS" build.
- **Localization everywhere else**: all user-facing strings use `String(localized:)` — no raw string literals in views. The three-file spot-check above is not tree-wide coverage.
- **Doc comments**: every `public`/`internal` type, function, and property requires a doc comment. Nothing verifies that they are *accurate*, either — verify doc claims about runtime behaviour by running the app, not by reading neighbouring comments or commit messages.

## Web edition (FRUS Explorer Light)

joshbotts/FRUS-Explorer-Web-App compiles this repository's shared kits on Linux from a pinned commit. Sessions here follow four rules and do nothing else for it. Web sessions watch this repository, repair Linux breaks, and write every change only the web edition needs, as pull requests here for the owner to merge. The arrangement: https://github.com/joshbotts/FRUS-Explorer-Web-App/blob/main/docs/COORDINATION.md

Shared code: FTS5Store, SourceNoteKit, CrossRefKit, GeneratorKit, TEIHeaderKit, SemanticVectorsKit, WordCloudKit, ManifestGeneratorCore, CloudVectorsGeneratorCore, SourceExplorerExportGeneratorCore, LotClaimantsIndexGeneratorCore, CentralFilesIndexGeneratorCore, VolumeSourcesIndexGeneratorCore, CollectionAuthorityGeneratorCore, SourceProvenanceIndexGeneratorCore and FRUSCoreKit/, with their test folders (FRUSCoreKit's is FRUSExplorerTests/FRUSCoreKit/; see its entry under SPM package targets). Code inside a kit test's `#if !SWIFT_PACKAGE` branch is the app's own and exempt from rules 1 and 2.

1. In shared code, never import SwiftUI, UIKit, AppKit, WebKit, SwiftData, CoreSpotlight, TipKit or NaturalLanguage, except WordCloudKit's tagging code, which imports NaturalLanguage and `os` only inside `#if canImport(NaturalLanguage)`, as a WordCloudKitTests suite that tags does. Keep the existing `#if canImport` imports inside their guards; FRUSCoreKit/ allows only Foundation and the guarded modules its entry names. Do not read Bundle.main, UserDefaults or the Keychain: pass them in.
2. A kit file never uses an app-only type: pass the value in, or move the declaration into the kit. A member that reads app state goes in an extension in an app file.
3. Leave the `#if canImport` guards in place, though they look redundant here. Change kit behaviour in the kit, never in an app forwarder to it.
4. After changing shared code, run `swift test` as well as the usual unit target: Xcode never runs the kits' own suites.

Not asked of sessions here: labelling, notifying or checking the web edition's CI; Linux builds or its tools; holding back index-version, export, kit API (`public` included) or refactoring changes; shaping code for it beyond these rules; any feature, API or `public` access only it needs; porting work after a web-authored move. App work goes ahead; the web side follows.

## CloudKit schema-deploy gate (Wave R-7)

Adding or removing a `@Model` in `frusModelTypes` — **or a stored property on one** — changes the
CloudKit schema and needs a Production deploy before the build ships. #488 is what happens when it
does not: build 35 added four identifiers, Production was never promoted, and export failed for
every user.

`FRUSExplorerTests/CloudKitSchemaInventoryTests` fails the suite the moment the mirrored set
changes, and its failure message carries the whole checklist plus the literal to paste. Follow it;
do not hand-edit `CloudKitSchemaInventory.installedIdentifiers` to make the red go away. In short:

1. Paste the printed list over `installedIdentifiers`.
2. Add the new identifiers to `identifiersAwaitingDeploy` (the app then reports it at launch and
   in Settings ▸ Data & Recovery ▸ iCloud Schema). The list also serves as an **interlock** for
   any migration that deletes the rows it replaces in the same call — CloudKit would keep only
   the deletions while the new type awaits deploy. (`ResearchTrailMigration` was the type case;
   it and the session models were retired in R-2b, PR #981 — with NO Production deploy, because
   Production is append-only and a removal is not a deploy.)
3. Owner step: exercise the new type/field once on a Development build with iCloud signed in, then
   CloudKit Dashboard → Schema → **Deploy Schema Changes to Production**.
4. Clear `identifiersAwaitingDeploy`, re-run the suite, paste the count + digest it prints, and
   update `deployedThroughBuild` / `deployedOn`.

Only step 3 is outside the repo, and only step 3 cannot be verified by a test. Since #1531 it can
be verified by a script: `./Scripts/check_cloudkit_schema.py` exports Production's schema and fails
when it lacks an identifier the build can write, and every archive is gated on its last read (see
the build-bump list at the top of this file). #1531 is what the attestation alone cost: the
inventory recorded `CD_GeneratedSummary.CD_sourceContentHash` as deployed on 2026-09-03, Production
did not hold it, and sync stopped on every device that summarised an indexed document from build
45 until the owner deployed it on 2026-09-28.

## Planning & Specification

- `Planning/FRUS-Explorer-Specification.md` — the ORIGINAL design spec, 1,222 lines and **unmodified since Session 01** (`63cc5c9b`). Consult it for original intent and for §18/§22's numbered decisions, which other docs still cite; it is not a record of what shipped. What shipped lives in `Planning/DEVELOPMENT-PLAN.md`, and what is planned lives in the **latest** plan of record — the one `Planning/Plan-Of-Record-*.md` whose header is not marked `Status: SUPERSEDED`. There is deliberately only ever one live: `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan` finds the one not marked SUPERSEDED and fails if there is not exactly one, so do not name a dated file here again.
- `Planning/DEVELOPMENT-PLAN.md` — the session log: append an entry at its end after each work session. It holds the entries from 2026-11-01; a finished month's are in `Planning/Completed/DEVELOPMENT-PLAN-<yyyy-mm>.md` (those before October 2026 in `DEVELOPMENT-PLAN-to-2026-09.md`), and a code comment that cites an entry finds it in the file that holds its date. The file is megabytes long: never read it whole. `grep -n '^## Session'` lists its entries, and the end of the file shows the form an entry takes.
- `Planning/` holds live plans, runbooks, and open designs only; completed or closed plans (including the per-task session files, e.g. `02-Manifest-Generator.md`) are archived in `Planning/Completed/` — see its README for the index.

## Bundle IDs & Entitlements

| Setting | Value |
|---------|-------|
| Bundle ID | `bottsywattsy.FRUS-Explorer` |
| CloudKit container | `iCloud.bottsywattsy.FRUS-Explorer` |
| iOS scheme | `FRUSExplorer` |
| macOS scheme | `FRUSExplorerMac` |
| macOS configs | `AppStore`, `DirectDistribution` |
