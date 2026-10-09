# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

**Run all tests (iOS Simulator):**
```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

**Run a single test suite:**
```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -only-testing FRUSExplorerTests/CitationParserTests
```

**UI suites: which devices, and where the detail is.** One destination gives one idiom's tests, and
a suite that self-skips on the wrong device reports green. Each suite's full entry is in
`Planning/UI-Test-Destinations-Runbook.md`: why it needs those devices, the counts and skips to
expect, what it measured on the unfixed code, and the exact commands. **Read a suite's entry before
you run it, change it or read its result as a guard** (`grep -n '<SuiteName>'` finds it). The table
is the index, not the entry.

| Suite (name the TYPE in `-only-testing`) | Run it on | Expect |
|---|---|---|
| `UIObstructionTests` | an iPhone and any iPad | scenario 4 (#238) self-skips on an iPhone |
| `BrowseNestedSectionTests` | iPad Pro 13-inch (M5) and iPhone 17; `testLevelStateSurvivesTheTwoPaneGate` on iPad mini (A17 Pro) | 11 tests: 3 skipped on the iPad, 4 on the iPhone |
| `TopicIndexArrivalTests` | iPad Pro 13-inch (M5), two-pane, and iPhone 17 | 3 passed on each; it never skips, so one device alone is not the guard |
| `CollectionEditorTitleTests` | iPhone 17, iPad Pro 13-inch (M5), iPad Air 11-inch (M4) `OS=26.5` | 8 tests: 0, 3 and 3 skipped; only the Air folds ＋ Add into the overflow |
| `CollectionProseRowRestTests` (in `CollectionEditorTitleTests.swift`) | iPad Air 11-inch (M4) and iPhone Air, both `OS=26.5` | 5 tests, 0 skipped on each |
| `SelectionEditMenuTests` (in `ResearchReadingStaysInTabTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5) | 4 tests, 0 skipped on each |
| `ResearchReadingDepthTests` | iPad mini (A17 Pro) | skips on an iPad whose portrait is already two-pane |
| `AnalyticsKeyboardTests`, `KeyboardDismissBarReachTests`, `ToolbarOverflowAccessibilityTests` | iPad mini (A17 Pro) | green on iPhone 17 and iPad Pro 13-inch too, but only the mini catches a restored analytics window (#1279) |
| `SearchActionsBarFitTests` | iPhone 17 and iPhone SE (3rd generation), iOS 27 | iPhone-only; self-skips at iPad width |
| `AuxWindowCloseTests` | iPad Pro 13-inch (M5), `OS=27.0`, in Windowed Apps | iPad-only; which cases guard depends on the multitasking mode |
| `VolumeRemovalTests` | an iPad on iOS 27 and one on iOS 26, full screen | 5 tests, 0 skipped; an iPhone skips the 2 popover-anchor tests |
| `ResearchSidebarSelectionTests` | iPad Pro 13-inch or iPad Air 13-inch | 2 tests, 0 skipped; an iPhone run is a skip |
| `BrowseRootSelectionTests` (in `TwoPaneDocumentTests.swift`) | the same 13-inch iPads | 4 tests, 0 skipped; an iPhone run is a skip |
| `CrossReferenceMatrixScrollTests` (in `AnalyticsRotationTests.swift`) | iPad Pro 11-inch (M5) and iPhone 17 | 5 tests: 1 skipped on the iPad, 2 on the iPhone |
| `CrossReferenceRankingChartTests` (same file) | any iPhone or iPad | 1 test, 1 passed; never skips |
| `BrowseWithinScopeTests` | iPad Pro 11-inch (M5) and iPhone 17 Pro, both `OS=26.4` | 3 passed on each; neither is a control |
| `SummarizationPromptCopyTests` | any iPhone or iPad | 1 test, 1 passed; never skips; its test must stay the pane's first action |
| `AnalyticsCompareFromTableTests` | any iPhone or iPad | 1 test, 1 passed; never skips; needs no index |
| `TabShellBannerClearanceTests` | iPhone 17 and iPad Pro 11-inch (M5) | 6 tests: 1 skipped on the iPhone, 0 on the iPad, which the suite turns to landscape |
| `WordCloudLensTests`, `NaturalLanguageReadinessWarmUpTests` (unit target) | iPad Pro 13-inch (M5), `OS=27.0` | a guard only on iOS 27.0; a control elsewhere |

Four rules hold for every UI run, and the runbook gives the measurement behind each:

- **Name the test type, not its file.** An `-only-testing` name that matches nothing runs zero tests
  and reports green, so read the test count back.
- **A device name does not name an OS.** This Mac has one of each device per installed runtime
  (iOS 26.3, 26.4, 26.5, 27.0): pin `OS=` or a UDID. A simulator also carries state between runs
  (the tab-sidebar representation, the scene's saved state), so when a failure follows one
  simulator, suspect that before the OS.
- **On iOS 27 pass `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 300`**, so a
  stall ends the run. A suite that measures a screen at rest sets `FRUS_UI_TEST_DISABLE_ANIMATIONS=1`.
- **A suite that opens a presentation closes it in `tearDown`** with
  `UITestPresentation.dismissAnyPresentation(in:)`. Terminating the app is not enough: the next
  launch restores what the last one had open.

**Command-line tools: what exists, and where the detail is.** Every generator is a package target
run from the repo root (`swift run -c release <Name>`); a few corpus tools are stdlib-only Python
under `tools/`. Each one's entry in `Planning/Generators-Runbook.md` gives its inputs and
environment variables, the figures it last measured, when it refuses to write, and what must be
regenerated after it. **Read a tool's entry before you run it, edit it or quote a figure from its
artifact** (`grep -n '<ToolName>'` finds it; the entries are long because each rule in them was a
measured failure).

| Tool | Writes | Reads, beyond the corpus at `VOLUMES_DIR` |
|---|---|---|
| `ManifestGenerator` | `manifest.json` | GitHub TEI headers, or `VOLUMES_DIR=` for the offline overlay |
| `TaxonomyGenerator` | `volume-tag-taxonomy.json` | history.state.gov |
| `CentralFilesIndexGenerator` (four keyed modes, four offline ones) | `central-files-index.json` | NARA Catalog (`CATALOG_API_KEY`) or the record-group harvest |
| `VolumeSourcesIndexGenerator` | `volume-sources-index.json` | `central-files-index.json`; optionally the Catalog |
| `CollectionAuthorityGenerator` | `collection-authority.json` and its report | the two indexes above |
| `CollectionUsageIndexGenerator` | `collection-usage-index.json` | the authority, the manifest |
| `ProvenanceFlowIndexGenerator` | `provenance-flow-index.json` | the authority, the manifest |
| `ResolvedEdgeIndexGenerator` | `resolved-edge-index.json` | the manifest |
| `ExternalCitationIndexGenerator` | `external-citation-index.json` | the authority, `decimal-class-labels.json` |
| `SourceProvenanceIndexGenerator` | `source-provenance-index.json` | the manifest |
| `AdministrationProfilesIndexGenerator` | `administration-profiles-index.json` | `administrations.json` |
| `CrossRefValidationGenerator` | `Planning/cross-ref-validation/`; copy `broken-refs-index.json` into Resources | the manifest |
| `CorpusStructureSweepGenerator` | `Planning/corpus-structure-sweep/` | `CORPUS_COMMIT` (required) |
| `tools/oh-report/build_oh_report.py` | `Planning/OH-Report-<date>/` | `CORPUS_COMMIT` (required), the cross-ref CSV |
| `SourceExplorerExportGenerator` | `Planning/source-explorer-export/` | the bundled indexes |
| `LotClaimantsIndexGenerator` | `lot-claimants-index.json` | the record-group harvest |
| `AccessionSeriesIndexGenerator` | `accession-series-index.json` | the record-group harvest |
| `SeriesFactsIndexGenerator` | `series-facts-index.json` | the record-group harvest |
| `DigitizedRangeIndexGenerator` | `digitized-ranges-index.json`, `roll-scans-index.json` | the record-group harvest only |
| `PresidentialLibraryCatalogGenerator` | `presidential-library-catalog.json` | NARA Catalog (`CATALOG_API_KEY`), or its cache with `PROJECT_ONLY=1` |
| `RecordGroupCatalogGenerator` | `Planning/nara-record-group-catalog/` | NARA's public S3 export; start with `PROBE=1` |
| `DecimalClassLabelGenerator` | `decimal-class-labels.json` | the Department's manuals in `SCHEDULE_DIR` |
| `SubjectNumericLabelGenerator` | `subject-numeric-labels.json` | the handbooks in `SCHEDULE_DIR`, the usage index |
| `PersonAuthorityIndexGenerator` | `person-authority-index.json` | the people registry, `persons-complete.xml`, the merge audit |
| `POCOMIndexGenerator` | `pocom-index.json` | the POCOM register; run it after `PersonAuthorityIndexGenerator` |
| `DocumentSubjectIndexGenerator` | `document-subject-index.json` | the corrected subject export only, no TEI |
| `VolumeSubjectProfilesGenerator` | `volume-subject-profiles-index.json` | the same export, the manifest |
| `SemanticVectorsGenerator` | `semantic-vectors-*`, the shards and their manifest, `semantic-map*` | the chunk-vector store, `tools/semantic-map/build_layout.py`'s layout |
| `CloudVectorsGenerator` | `cloud-vectors-core.json`, `cloud-vectors-volumes.json`, `keyness-baseline.json` | the lexicon and stopword payloads |
| `EarlyEraNERControl`, `tools/semantic-harvest/*.py` | the #234 detector stores and scores | the R-0 text layer |

Rules that span entries:

- **A refreshed JSON under `FRUSExplorer/Resources/` owes `swift test` and the unit target**, since
  package suites read it from the repository. A new or renamed bundled resource also needs
  `xcodegen generate` and the scheme restore; a same-name refresh does not.
- **Rebuilding `collection-authority.json` changes record ids**, so regenerate usage, flow and
  external citations after it. The central-files chain is `SUPPLEMENT_FROM_HARVEST` →
  `PRUNE_FLAGGED_LOTS` → `CollectionAuthorityGenerator` → `CollectionUsageIndexGenerator` →
  `LotClaimantsIndexGenerator` → `SeriesFactsIndexGenerator`.
- **A change to the country or class keys of `decimal-class-labels.json`** moves
  `external-citation-index.json`'s vocabulary digest: regenerate it in the same commit.
- **Files that come out of one run are committed together**: `CloudVectorsGenerator`'s three, and
  `SemanticVectorsGenerator`'s index, binary and shard manifest. Run the second with `EXPECT_DIGEST`
  set to the shipped family's digest.
- **A keyed NARA harvest spends a metered quota**: confirm the invocation first. A
  `CloudVectorsGenerator` run takes 50 to 60 minutes.

**Before ANY archive — TestFlight, App Store, or the notarized DMG — cache the query encoder's
debug symbols once:**
```bash
./Scripts/fetch-llama-dsyms.sh
```
`Vendor/llama.xcframework` (the on-device query encoder's llama.cpp runtime) is committed WITHOUT
its dSYMs — 76–153 MB per slice, past GitHub's 100 MB limit — so every TestFlight upload used to
warn that the archive "did not include a dSYM for llama.framework", and a crash inside the encoder
could not be symbolicated. The dSYMs live as a release asset on `frus-semantic-vectors`
(`llama-xcframework-dSYMs-<commit7>.zip`, on `encoder-1`); the fetch script downloads them into
the gitignored `.cache/llama-dSYMs/`, verifies every slice's UUIDs against the committed
binary, and is a no-op once the cache verifies. An archive-only build phase on both app targets
("Embed llama dSYM", `Scripts/embed-llama-dsyms.sh`) then copies the embedded slice's dSYM into
the archive after re-checking the UUIDs — and **FAILS the archive** when the cache is missing or
stale, because shipping unsymbolicated is the state it exists to end. It never runs on a plain
build or test. **Test a change to that phase with `-derivedDataPath` on a real path, never under
`/tmp`**: xcodebuild spells a `/tmp` build directory as `/tmp/…` in the script sandbox's rules while
the kernel checks the resolved `/private/tmp/…`, so no deny rule matches and the phase runs
unsandboxed — measured, the `rm -rf` that failed the build-48 archive passes a `/tmp` archive and
fails one under `~/Library`. After `Scripts/build-llama-xcframework.sh` rebuilds the framework, upload the zip
it writes to that release AND commit the new xcframework together, then re-run the fetch;
`notarize.sh` runs the fetch itself before archiving.

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

- **Download → Index**: `DownloadManager` queues volume files; on completion `IndexingPipeline` parses TEI XML and populates FTS5 tables (documents, persons, cross-references, dates). **`frus:doc-dateTime-min`/`-max` is an INSTANT, not a day**: the corpus's own build writes it through `adjust-dateTime-to-timezone` at `-PT5H`, which preserves the moment and rewrites the local fields, so its first ten characters are the day *at −05:00*. Reading them as the calendar day put 11,847 documents on the wrong one across 480 volumes (#1326, index v54) — a Washington telegram printed 22 October 1962 was stored as the 21st, because the stylesheet uses EST all year round. `IndexingPipeline.sameInstantDay` takes the day from the document's own `<date>` wherever the two name the same instant, and leaves the attribute alone where they do not. `AdministrationProfilesIndexGeneratorCore.DocumentDateExtractor` mirrors that rule; the two are pinned by their own fixtures, not shared code. (The reason given until October 2026, that the app target is not linkable from the SPM package, no longer holds: `IndexingPipeline` is a package target, `FRUSCoreKit`, since #1573. The mirror is still a mirror.) **A volume's `volume_structures` row is also the record that its last store pass finished (#1566)**: `storeIndexData` removes it before it writes anything and writes it last, so it stays the last write of any store path. A volume with documents and no such row was cut short (`volumesWithUnfinishedStore()`); the launch reconcile finishes one the interrupted-indexing sentinel does not name, which is what a power loss leaves, and leaves one it does name to the reader's amber badge.
- **Search**: `SearchService` queries FTS5 with BM25 ranking and English stemming; results flow to `SearchView`.
- **Document rendering**: TEI XML is parsed into an AST (`FRUSASTNode`), converted to render nodes, and displayed via `FRUSDocumentRenderer`. Highlights are overlaid post-render.
- **Figure images (#1516)**: when a volume's download finishes, `DownloadManager` fetches the images its `<figure>`s name — the `<graphic url>` outside the title page — from `https://static.history.state.gov/frus/<volume>/<url>.png` into `{Volumes}/<volume>.figures/`, removes them with the volume, and counts them in Volumes & Storage. **The rule is "a `<graphic>` in a `<figure>`", never "every `<graphic>`"**: a page's scan is a `<graphic>` too, in `<facsimile><surface>`, and the 553 manifest volumes hold 1,143,043 of those against 992 in figures. `.png` is added to every name (`OpenPitMine.jpg` is served only as `OpenPitMine.jpg.png`), and a file the host does not have answers **403**, not 404. Measured 2026-10-01 by HEAD request at corpus `8e5da08c1`: 553 images, 140,994,857 bytes, in 96 volumes, and 13 more names refused; a second pass read each one's first 24 bytes, and all 553 open with the PNG signature (the widest is 19,043 pixels). **A volume already on the device — downloaded before build 49, or left short by a failed or interrupted run — is brought up to its images by `DownloadManager.fetchMissingFigureImages(among:)`, which the app starts at launch and each time the device comes back online**, for catalogue volumes only; a volume whose run ended with nothing left to fetch is recorded in `{Volumes}/.figure-images-complete.json` against its XML's size and modification date, so the library is scanned once and not at every launch, and the pass stops after three volumes in a row whose transfers all fail. Until the pass reaches a volume, the reader and a PDF, Word or HTML export fetch the one image they need (`FigureImageStore`), only while online; BibTeX, RIS and the Zotero send fetch none. **In a unit test's host the app's store is left unconfigured and the pass is not started** (`FigureImageStore.isUnitTestHost`): the tests run inside the app, whose boot would otherwise point every default at the simulator's own volumes and at the network. The reader draws an image through `frusexplorer://figure/…` (`FRUSURLSchemeHandler`); PDF, Word and HTML exports embed it. **A figure's head, captions and placeholder, and the space between two inline elements (`.elementSpace`), are drawn under `data-skip` and are not flat text**, so `renderingVersion`, `body_hash`, `body_text` and every stored highlight stayed where they were and the change took no index version. `renderingVersion` cannot see drawn text that leaks out of `data-skip`; only `FigureReaderTests`' Swift/JS parity, in a real web view, does.
- **Summarization**: `SummarizationService` and `BackgroundSummarizationService` call Apple's `FoundationModels` framework (on-device); summaries stored in SwiftData and indexed in FTS5.
- **User data sync**: SwiftData models sync automatically via CloudKit (`iCloud.bottsywattsy.FRUS-Explorer`).

### Platform Layout Split

- **iOS/iPadOS**: `MainTabView` with 5 tabs — Browse, Search, Research, Collections, Settings. iPad adds `.inspector(isPresented:)` panels (including the document Research rail) and Stage Manager multi-window scenes.
- **macOS**: `MainWindowView` with sidebar navigation plus dedicated window scenes for Search, Browser, CrossReference, SourceExplorer, and Collections.

The `#if os(iOS)` / `#if os(macOS)` conditional compilation pattern is used extensively throughout views.

### Directory Map (`FRUSExplorer/`)

| Directory | Purpose |
|-----------|---------|
| `App/` | `@main` entry point, `AppState`, `ContentView`, routing |
| `Models/` | SwiftData model types and tag/person/highlight models; the manifest structs, `CountCopy` and `PersonMentionStore` are in `FRUSCoreKit/Models/`, and the highlight colours (`HighlightColor`) in `FRUSCoreKit/TEI/` |
| `Search/` | `SearchView`, its view models and the search UI; `IndexingPipeline+App.swift` (the pipeline's Spotlight donation, its bundled data files and the initialiser the app calls) and `SearchService+Collocation.swift`; `SearchService` and `IndexingPipeline` (the largest file) are in `FRUSCoreKit/Search/` |
| `TEI/` | The reader's web view and its configuration, `HTMLTemplate` (which forwards to the kit's `ReaderPage`), the `frusexplorer://` scheme handler, the AST cache and the rendering config; the XML parser, AST types, AST-to-render conversion, HTML serializer and the reader's page (`ReaderPage`, `ReaderAppearance`, `TextSizePreference`) are in `FRUSCoreKit/TEI/` |
| `Browser/` | Volume/subseries/corpus navigation with breadcrumb trail; `VolumeStructure` is in `FRUSCoreKit/Browser/` |
| `DocumentView/` | Document display, the shared Research rail + floating selection bar, cross-reference links |
| `CrossReference/` | Graph visualization, `CrossReferenceStore`; `BrokenRefsIndex` is in `FRUSCoreKit/CrossReference/` and its bundle loader, `BrokenRefsIndexStore`, stays here |
| `Collections/` | Collection editor, PDF/HTML/DOCX exporters; the Add Documents sheet's citation line resolver is in `FRUSCoreKit/Collections/` |
| `Citation/` | Citation Lookup's view, BibTeX/RIS/Zotero export and the citation-style preference; the formatter, models, parser, canonical URL, page-span resolver, matching engine, block splitter, page-range store, the lookup form's fields and `CitableVolumeCatalogue` are in `FRUSCoreKit/Citation/` |
| `Summarization/` | Apple Intelligence integration, prompt management UI |
| `SourceExplorer/` | NARA catalog integration |
| `Downloads/` | `DownloadManager`, download queue UI |
| `Analytics/` | The Analytics family, all Swift Charts: corpus term frequency, Person, Cross-Reference, and Archival (era × archival-unit rankings + the user's own archival profile) |
| `Theme/` | `FRUSTheme` (colors, typography constants) |
| `Resources/` | Bundled JSON: manifest, taxonomy, subject tags, TEI config |

`FRUSCoreKit/` sits beside `FRUSExplorer/`, not inside it, with subfolders that mirror the app's (`TEI/`, `Citation/`, `CrossReference/`, `Browser/`, `Collections/`, `Models/`, `Search/`, `Chronology/`, `RelatedDocuments/`, `Analytics/`) and a `Linux/` of stand-ins that Apple platforms compile out. Both app targets compile it, and so does an SPM target of its own: read `FRUSCoreKit` under **SPM package targets** below before editing it.

- `SemanticVectorsKit` — the semantic-vector artifact contract: binary layouts, the
  document-id run-length encoding that keys every row, mmap readers for the bundled
  corpus tier and the per-volume shards, and the retrieval kernel. Compiled into the app
  targets via `project.yml` (the WordCloudKit/FTS5Store pattern) **and** an SPM library
  target, so `SemanticVectorsGenerator` writes through the declarations the device reads
  through. **The kernel's tie-breaks are the measurement**: driving it over the shipped
  artifacts reproduces the corpus gates' reference neighbour lists in exact order for
  600/600 queries, so changing one silently invalidates the recall the artifact states.
  Two device-side rules worth knowing before touching it — a full corpus Hamming scan is
  1.43 ms and the whole funnel 2.44 ms (so no ANN index, measured rather than assumed) — but **both were measured at the 256 width**, and the bundle has shipped at 512 since #933: `Planning/semantic-vectors/Dimension-Ladder-Spike.md` drove this same kernel over both artifact sets and got a Hamming scan of 0.96–1.11 ms at 256 against **1.53–1.68 ms** at 512, and a whole funnel of ~1.03 ms against **~1.64 ms**, so the CONCLUSION survives the width change and neither quoted number does,
  and identity NEVER comes from a shard's position in local XML but always from the
  bundled index's segments, because a re-published volume changes the XML and not the
  artifact. App-side, `BundledSemanticVectors` (prepare()-shape loader, maps the 19.52 MB
  binary) and `SemanticShardStore` (filesystem-truthed, no SQLite registry — the app
  already reads downloaded-ness from disk, and a table would drift) are in
  `FRUSExplorer/Semantic/`. **Tier 2 now has a host**: `SemanticShardFetcher` fetches through
  `adoptShard(from:for:)`, which validates before it keeps, and `AppState.fetchSemanticShardIfNeeded`
  drives it on a deliberate split — **eagerly** when a volume downloads (~294 KB beside ~6 MB is
  invisible, and it makes the volume semantic-ready exactly when it becomes search-ready) and
  **lazily** for volumes already on disk, so an existing library does not silently pull 162 MB at
  launch for a feature the reader has not opened. **#900 added the storage UI**: one
  `SemanticStorageSection` mounted by *both* hubs (they are hand-maintained twins, so a section
  written twice is two places to drift), reporting disk usage against the published total, the
  problems the app has actually noticed, and a Remove control. **Two of its four figures are
  structurally partial** — a fetch failure lives only in memory for the session, and a refusal is
  recorded only for volumes something has already asked about — so the screen may say what it has
  noticed and may never say there is nothing wrong; `SemanticStorageReport` owns that distinction
  and its wording. **No progress is reported, deliberately**: the transfer is a one-shot
  `URLSession.download(from:)` with no callback, a shard is ~294 KB on average (988 KB at the largest), fetched in a fraction of a second, and the app
  shows no byte progress for the ~6 MB volume download beside it. **#926 added the controls**: a
  device-local `SettingsKeys.autoDownloadSemanticShards` (default ON, so its introduction changes
  nothing for anyone who never touches it) gating both automatic paths, and a manual **Download
  Missing Vectors** that ignores the switch — pressing a button is the consent it withholds. The
  preference is deliberately NOT on `SyncedPreferences`: a download policy is about one device's
  storage and network, and a stored property on a mirrored `@Model` would need a CloudKit
  Production deploy (the #488 gate) to ship. The manual run reports a **count** ("12 of 340"),
  which is observable where per-file bytes are not, and the missing count is computed over
  **downloaded volumes only** — `published − onDisk` would tell a 12-volume library it was missing
  544.

**SPM package targets** (`Package.swift`, package name `FRUSExplorerTools`, macOS 15+). This is a build-tool package, not a library distribution: it declares **no `products:` block at all**, so nothing here is linkable from outside — the app reaches the shared code by compiling the same source directories through `project.yml`. It currently declares **39 library targets, 31 executables and 38 test targets** (108, `swift package describe`, counted 2026-10-04 when FRUSCoreKit and FRUSCoreKitTests were added; 38, 31 and 37 from 2026-10-01; the line read 37, 30 and 36 until then); every generator indexed under *Build & Test Commands* above, and documented in `Planning/Generators-Runbook.md`, lives here. Do not read the list below as an inventory — read `Package.swift`.

The **shared** (non-per-tool) library targets are the ones worth knowing by name:
- `FTS5Store` — the reusable SQLite FTS5 actor. `LinuxLogger.swift` stands in for `os.Logger` on Linux and compiles to nothing on Apple platforms, so keep FTS5Store's logging to `debug`, `info`, `notice`, `warning` and `error` with plain `privacy:` interpolation.
- `SourceNoteKit` — the FRUS source-note parser.
- `TEIHeaderKit` — the `<teiHeader>` grammar `manifest.json` was built from (#777).
- `SemanticVectorsKit` — the semantic-vector artifact contract (see above).
- `GeneratorKit` — the generators' shared plumbing: `VolumeCorpusEnumerator`, a stderr logger, the reproducible `yyyy-MM-dd` stamp, an RFC-4180 `CSVWriter`.
- `CrossRefKit` — the cross-reference grammar; **SPM-only**, a mirror of `FRUSURLScheme.resolveCrossRefTarget` (FRUSCoreKit) rather than shared source, whose hard-coded fixtures never call the app: it has drifted on the three branches the app has changed since: footnote anchors (`.footnote`, #988), `mailto:` targets and whole-volume targets (`.volume`, #1603).
- `FRUSCoreKit` — the TEI parser, AST, render nodes, AST-to-render converter and HTML serializer, the reader's lookups and serializer settings (`ReaderRendering.swift`), the citation formatter, models, parser, canonical URL and page-span resolver, and (part 2) the indexing pipeline and the search service with the Foundation-only types they use, and Citation Lookup's matching engine, block splitter and page-range store with the lookup form's fields, the Add Documents citation line resolver and `CountCopy`: the code FRUS Explorer Light, the web edition, compiles on Linux from a pinned commit. It depends on SourceNoteKit and FTS5Store. **Foundation only**: FoundationXML, CryptoKit (swift-crypto's `Crypto` on Linux), OSLog, SQLite3 (the web edition's `CSQLite` on Linux), FTS5Store and SourceNoteKit are imported behind `canImport`, and the stand-ins under `Linux/` (`LinuxFoundationShims.swift`, `LinuxOSLogShims.swift`) compile to nothing on Apple platforms. The pipeline is given what the app reads: `IndexingResources` (the bundled data files, as providers), an `IndexingStampStore` (whose requirements are `UserDefaults`' own methods) and an optional `IndexedDocumentDonor`; the app's half — `IndexingResources.bundled`, `extension UserDefaults: IndexingStampStore`, the Spotlight donor and rebuild, `updateSummary(_:)` and the initialiser every app call site uses — is in `FRUSExplorer/Search/IndexingPipeline+App.swift`, and `runPostIndexPasses` runs the passes after indexing: the app's launch calls it, and the web edition's indexer is to. The matching engine reads the volumes it answers for from a `CitableVolumeCatalogue`; the app's is `ManifestStore`, conformed beside it, and a host outside the app passes a `FixedVolumeCatalogue`. A declaration the kit needs that lives in an Apple-only file moves INTO the kit, never the reverse, and the app keeps the old name as a forwarder or typealias (`FRUSURLSchemeHandler.resolveCrossRefTarget` → `FRUSURLScheme`, `DocumentHighlight.Color` → `HighlightColor`, `IndexingPipeline.normalizeSourceNoteWrapper` → `StoredSourceNote`, `NARACatalogClient.isDecimalFileNumber` → `DecimalFileSegment`); the kit never reads `Bundle.main` or `UserDefaults` (`BrokenRefsIndexStore`, `ManifestStore`, `CitationStyle.current` and the loaders `DocumentSubjectStore`, `DecimalClassLabelStore`, `VolumeSubjectProfilesStore` and `PersonAuthorityIndexStore` stay in the app). #1569 made public what the web edition calls — the reader's lookups and serializer settings, `CrossRefDestination` and `FRUSURLScheme.resolveCrossRefTarget`, `FRUSCanonicalURL`, the citation text rules and `CitableDocumentNumber` — and part 2 added, public, what a host outside the app needs to build and run the indexer and search: the seams in `Search/IndexingSeams.swift` (`IndexingResources` with `.none`, `indexResourceNames`, `LoadError` and `loading(fromDirectory:)`; `IndexingStampStore` and `InMemoryIndexingStampStore`; `IndexedDocumentDonor` and `DonatedDocument`; `runPostIndexPasses`), `IndexingPipeline`'s `resources` and the initialiser that takes them, `IndexingStateTracker.init(store:)` and `DateRange`'s initialiser, and `CitableVolumeCatalogue` and `FixedVolumeCatalogue` for the matching engine. For the web edition's search and reader (its S8a) they added the read-only, immutable opens `FTS5Store(readingDatabaseAt:schema:)`, `FTS5Store.immutableURI(for:)` and `IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:)` with `isReadOnly`, which skip the schema set-up and the WAL switch; `FigureImages.linked(url:)` and `FRUSRenderNodeHTMLSerializer.reader(figureURL:)`, a host's own figure addresses; `FRUSURLScheme.figureHost`, `figureURL(for:)` and `isSafeComponent(_:)`; and `ReaderPage` (`build`, `cssVariables`, `documentCSS`, `figureCSS`) with `ReaderAppearance`, the page and theme the app's `HTMLTemplate` and `FRUSTheme.cssVariables` now forward to, with `TextSizePreference` moved into the kit. For its reader's links and cards (S9b) they added `FRUSURLScheme.readerLink(from:)` and `ReaderLink`, the parse of the reader's links that `FRUSURLSchemeHandler.dispatch(url:)` now forwards to, and the immutable opens `PageRangeStore(readingDatabaseAt:)` and `PersonMentionStore(readingDatabaseAt:)` with `isImmutable`. The kit's other `public` declarations were already `public` in the app before the move, so `public` alone does not mark what the web edition uses. Access changes nothing for the app, which compiles the kit into its own module. Its suites live in `FRUSExplorerTests/FRUSCoreKit/` and are compiled twice, into the app's test target by Xcode and against the kit alone by `FRUSCoreKitTests`, so anything there that needs the app (its module, its bundle or its views' source) goes inside `#if !SWIFT_PACKAGE`; `IndexingTestSupport.swift` gives the package's test pipelines the app's data files from the repository and one shared stamp store, as the test host does in Xcode, and `CitationTestSupport.swift` gives its test engines the bundled manifest from the repository and a fixed catalogue where Xcode's get a `ManifestStore`. **Both folders are Foundation-only: after editing either, run `swift build --target FRUSCoreKit` and `swift test --filter FRUSCoreKitTests`.** The app builds even when a kit file names an app type, since it compiles both into one module; only the package and `FRUSCoreKitBoundaryTests` catch it.

All of these except `CrossRefKit` and `GeneratorKit` are ALSO compiled directly into both app targets by `project.yml`, so the generators write through the declarations the app reads through.
- `WordCloudKit` — the word-cloud tokenizer stack (`WordCloudTokenizer`,
  `WordCloudMultiLensTokenizer`, `WordCloudLens`, `WordCloudTuning`, `TermCount`,
  `WordCloudLexiconSet`, `WordCloudStopwordSet`). Compiled directly into the app
  targets via `project.yml` (like `FTS5Store`/`SourceNoteKit`) **and** an SPM library
  target, so `CloudVectorsGenerator` tokenises the corpus through the app's own code.
  Lexicon/stopword payloads are **injected**, never read from `Bundle.main` — the app
  supplies them from its bundle (`WordCloudStopwords`/`WordCloudLexicons`), the
  generator from file URLs. `WordCloudMultiLensTokenizer` counts N lenses from one
  `NLTagger` pass; `WordCloudKitTests` pins it against N single-lens runs, and that
  parity suite is what makes the merge safe — do not weaken it.
- Test targets: **38 of them**, one per tool plus one per shared kit — `FRUSCoreKitTests` compiled from `FRUSExplorerTests/FRUSCoreKit/` — except `TEIHeaderKit`, whose grammar is exercised from `ManifestGeneratorTests` (`TEIHeaderParserTests`, `ManifestStatusPolicyTests`) rather than a suite of its own. The shape is uniform — each tool is a `<Name>GeneratorCore` library (all logic, testable), a thin `<Name>Generator` executable (entry point only) and a `<Name>GeneratorTests` suite that imports the Core. `swift test` runs the lot; there is no curated subset to know by heart.

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

**`FRUSCoreKit/` has a gate of its own as well.** `FRUSCoreKitBoundaryTests` fails when a kit file imports anything but Foundation outside the `canImport` that selects FoundationXML, CryptoKit, `Crypto`, SourceNoteKit, OSLog, SQLite3 (`CSQLite` in its `#else`) or FTS5Store; reads `Bundle.main` (a `Bundle = .main` default included) or `UserDefaults`; or names, outside comments and string literals, a type, function, constant or variable declared at the top level of a file under `FRUSExplorer/`. It also fails on code under `FRUSCoreKit/Linux/` that sits outside a `#if !canImport(…)`, and on a suite under `FRUSExplorerTests/FRUSCoreKit/` that, outside Xcode's branches, imports the app (a module the kit may use is allowed there, behind the `canImport` that selects it) or names a top-level declaration of the app's or of the test target's other files — Xcode builds and passes such a suite, and only `swift test` would fail. Both name checks read a name only where it can mean that declaration: they skip a member after a `.`, an argument label or parameter (a name followed by `:` inside parentheses), and any name the kit or the suites declare for themselves, at any depth. So a change to the app alone does not fail them by adding a top-level declaration whose name the kit uses for something else; if one does, the name is one the kit takes from Foundation or the standard library (`URL`, `max`), which the app's declaration now meets in one module, and the app's declaration is the one to rename. It reads source, so a member the app adds to a kit or Foundation type is out of its reach, and so is a kit use of an app name the kit also declares somewhere; `swift build --target FRUSCoreKit` is not. The scans whose rule a kit file can break — the copy scans, the Search Tips key scan, the localized-Markdown census, the `Used by` check, the unused `private var` check and the space-joined `plainText` check among them — read `FRUSCoreKit/` with `FRUSExplorer/` through `AppSourceTree`; the scans for views, scenes, windows and models read `FRUSExplorer/` alone.

**The reader's page has a gate too, since #1575 and #1578.** `ReaderPageTests` (`FRUSExplorerTests/FRUSCoreKit/`, run by Xcode and by `swift test`) pins the page's head by SHA-256 and length for both appearances and all four text sizes, so any byte changed in `FRUSCoreKit/TEI/ReaderPage.swift`'s stylesheet, palette or template fails eight pins, a comment inside the CSS included: re-take them from the failure message and say why in the comment above them. It also fails when a text colour is under 4.5:1 against the page, an editorial note's tint or (since #1602) the wash behind a footnote a cross-reference arrived at; when the colour of text inside a highlight is under 4.5:1 over any of the five tints; when a `color:` is anything but one of the six text variables; and when `a.pers-name` or `a.cross-ref` loses its underline on screen or keeps it on paper: since 2026-10-08 the stylesheet's one `@media print` block prints the two links plain, and the suite reads a rule inside `@media print` as paper's alone and every other rule, those inside other `@media` blocks included, as the screen's. The print rule was checked in WebKit itself, by printing a page through `WKWebView.printOperation(with:)`, the call the Mac's File ▸ Print makes, and measuring the result: with the rule the longest run of link-coloured pixels under a person's name fell from 1,263 to 41 (letter strokes), and the name kept its colour. The stylesheet is also the collection HTML export's (`CollectionItemHTMLRenderer.embeddedCSS`) and the Mac's printed page's (File ▸ Print prints the reader's own web view). The export's own layer draws its text in literal colours, which `CollectionExportContrastTests` (the same file, Xcode's alone) measures, each against the background it is listed with: a rule added there that draws text is added to that list. Change the page in the kit, never in `HTMLTemplate` or `FRUSTheme.cssVariables`, which forward to it. `ReaderLinkTests` holds the reader's link parse (`FRUSURLScheme.readerLink(from:)`) to a table of the hrefs the serializer writes and, in Xcode alone, the app handler's call for each to the call it made before it read links with the kit: an intended change to what a tap does edits that expectation too, and a new reader host needs a row.

**After a change to shared code, three runs, and the first two are not Xcode's.** `swift build --target FRUSCoreKit` is the only build that sees a kit file calling a member an app extension adds, or naming a declaration of WordCloudKit, SemanticVectorsKit or TEIHeaderKit: Xcode compiles the kit into the app module, and `FRUSCoreKitBoundaryTests` reads names declared under `FRUSExplorer/` alone. `swift test` is the second (measured 2026-10-07 at `f384d2d5`: exit 0, 38 `Test run with` lines, one per test target, 2,557 tests in all, about two minutes with the package built and about four from an empty build folder); it is also owed after regenerating a JSON file under `FRUSExplorer/Resources/`, which package suites read from the repository. A `--filter` that matches nothing runs zero tests and exits 0, so read the counts back. Then the unit target and the Mac build as for any change: every kit file is Mac-compiled. `VolumeMetadataDiscoveredTests.metadataArrivesBeforeFirstBatch` compares two tasks' clock times and failed 1 full package run in 5 at that commit while passing 6 of 6 alone: run it again alone before reading it as yours.

**A view nothing constructs has a gate too, since #1484.** `UnconstructedViewAuditTests` (in `ToolbarAccessibilityAuditTests.swift`) fails when a type under `FRUSExplorer/` whose header names `View` is named by no code besides its own declaration and its extensions — comments and string literals blanked, every `#if` branch kept, so a view only the Mac constructs counts as constructed. It was written after two whole screens nothing presented, `PromptsListView` and `GlobalContextView`, were found by reading. Measured 2026-10-01: 480 files, 394 such types, 2 unnamed — `FilterChip` (`App/SearchSheet.swift`) and `CrossProjectNoteIndicator` (`DocumentView/DocumentView.swift`), both listed in its `knownUnnamed`, which is an exact exception list and not permission. **A pass says nothing is unnamed, not that nothing is dead**: it cannot see a view constructed only by code that is itself never called (`SubseriesListView` was, by `BrowserView.splitLayout`), so before deleting a file by name, still enumerate what it declares and who names each symbol.

Conventions with **no** automated check — reviewer's responsibility:

- **Swift 6 strict concurrency**: zero warnings under `SWIFT_STRICT_CONCURRENCY=complete`. This is a build setting, not part of the audit suite. **Verify with a CLEAN build — an incremental one reports nothing, because it does not recompile the files that would warn.** Measured 2026-08-02 on a clean build of both schemes: **zero source warnings**. Re-measured 2026-09-17 on **Xcode 27.0 (Swift 6.4)**, which surfaced ten new app-target warnings — seven files naming `ModelContext` without `import SwiftData` (member-import visibility is now enforced), an un-awaited call into the `DownloadManager` actor, and a `[weak appState]` flagged `#ImplicitStrongCapture` — all fixed, so zero again. **The test targets are at zero too, since 2026-09-18** (they had 53 unit-test and 1,438 UI-test warnings), so verify with a clean `build-for-testing`, not a plain build, which never compiles them. They drifted once: five unit-test warnings came back (#1405) and were fixed, and **a clean `build-for-testing` of the `FRUSExplorer` scheme on 2026-09-26 (Xcode 27.0, iOS Simulator, both test targets compiled) printed zero source warnings** — the only warning lines were the two residues below, the `GeneratedSummary` one as 2 diagnostics. Two rules keep them there. **A UI suite is `@MainActor` and overrides the ASYNC `setUp()`/`tearDown()`**, because the XCUI APIs are main-actor and XCTestCase's synchronous `setUpWithError`/`tearDownWithError` are nonisolated (see the head note in `UIObstructionTests`). **Never write `try? #require(x)`**: under Swift 6.4 it binds `#require`'s non-optional overload and a nil PASSES SILENTLY, measured in a scratch package, so use `try #require` in a `throws` test. Two known non-source residues remain and are not ours to fix: the SwiftData `@Model` macro synthesises a plain `Sendable` for `GeneratedSummary`, which already declares `@unchecked Sendable` (it must — removing it fails `SummarizationServiceTests`), giving 2 "redundant conformance" diagnostics per clean build on Xcode 27.0 — 4 `warning:` lines in the log, since xcodebuild echoes each under its caret, in both the iOS `build-for-testing` and the `FRUSExplorerMac` build of 2026-09-26 (#661 counted ~75 iOS / ~25 macOS lines on 2026-08-02, before Xcode 27); and `appintentsmetadataprocessor` notes there is no AppIntents dependency. Note the `FRUSExplorer` scheme builds **both** app modules, so a `#if os(macOS)` file's warnings surface in an "iOS" build.
- **Localization everywhere else**: all user-facing strings use `String(localized:)` — no raw string literals in views. The three-file spot-check above is not tree-wide coverage.
- **Doc comments**: every `public`/`internal` type, function, and property requires a doc comment. Nothing verifies that they are *accurate*, either — verify doc claims about runtime behaviour by running the app, not by reading neighbouring comments or commit messages.

## Web edition (FRUS Explorer Light)

joshbotts/FRUS-Explorer-Web-App compiles this repository's shared kits on Linux from a pinned commit. Sessions here follow four rules and do nothing else for it. Web sessions watch this repository, repair Linux breaks, and write every change only the web edition needs, as pull requests here for the owner to merge. The arrangement: https://github.com/joshbotts/FRUS-Explorer-Web-App/blob/main/docs/COORDINATION.md

Shared code: FTS5Store, SourceNoteKit, CrossRefKit, GeneratorKit, TEIHeaderKit, SemanticVectorsKit, ManifestGeneratorCore and FRUSCoreKit/, with their test folders (FRUSCoreKit's is FRUSExplorerTests/FRUSCoreKit/; see its entry under SPM package targets). Code inside a kit test's `#if !SWIFT_PACKAGE` branch is the app's own and exempt from rules 1 and 2.

1. In shared code, never import SwiftUI, UIKit, AppKit, WebKit, SwiftData, CoreSpotlight, TipKit or NaturalLanguage. Keep the existing `#if canImport` imports inside their guards; FRUSCoreKit/ allows only Foundation and the guarded modules its entry names. Do not read Bundle.main, UserDefaults or the Keychain: pass them in.
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
- `Planning/DEVELOPMENT-PLAN.md` — session-by-session task log; update after each work session.
- `Planning/` holds live plans, runbooks, and open designs only; completed or closed plans (including the per-task session files, e.g. `02-Manifest-Generator.md`) are archived in `Planning/Completed/` — see its README for the index.

## Bundle IDs & Entitlements

| Setting | Value |
|---------|-------|
| Bundle ID | `bottsywattsy.FRUS-Explorer` |
| CloudKit container | `iCloud.bottsywattsy.FRUS-Explorer` |
| iOS scheme | `FRUSExplorer` |
| macOS scheme | `FRUSExplorerMac` |
| macOS configs | `AppStore`, `DirectDistribution` |
