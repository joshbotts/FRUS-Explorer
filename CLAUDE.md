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

**Bumping the build number or version** — do NOT run `xcodegen generate`. Edit both files directly:
- Build number: change `CURRENT_PROJECT_VERSION` in `project.yml`, then replace all occurrences in `project.pbxproj` (`replace_all: true`)
- Version string: change `MARKETING_VERSION` the same way

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

**Run the UI obstruction suite on an iPad destination** (scenario 4 covers the iPadOS
`.sidebarAdaptable` floating-top-tab-bar overlay, #238; it self-skips on an iPhone
destination — any installed iPad simulator works; check `xcrun simctl list devices available`):
```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -only-testing FRUSExplorerUITests/UIObstructionTests
```

**SPM command-line tools (run from repo root):**
```bash
swift run ManifestGenerator   # Regenerate manifest.json from GitHub FRUS TEI headers. Env: OUTPUT_PATH override; GITHUB_TOKEN. VOLUMES_DIR=<local corpus> switches to OFFLINE local overlay mode (no GitHub): loads the existing manifest at OUTPUT_PATH as the base and re-derives ONLY publicationDate (publicationStmt/date[@type="publication-date"] TEXT = print year) and dateRange (content-date @notBefore/@notAfter, else creation/date) from each VOLUMES_DIR/<filename> header, preserving all other fields
swift run TaxonomyGenerator   # Regenerate volume-tag-taxonomy.json
CATALOG_API_KEY=<key> swift run CentralFilesIndexGenerator   # Harvest NARA Catalog → central-files-index.json (Phase 1: 1906–1910 Numerical File; Phase 2: diplomatic series)
CATALOG_API_KEY=<key> SURVEY_SERIES=603720 swift run CentralFilesIndexGenerator   # Survey a series' structure. Diplomatic: 603720/593313/594363/597272. Consular (Phase 3): 302031 Despatches / 604019 Instructions / 1076611 Notes-to / 1076629 Notes-from
CATALOG_API_KEY=<key> CITATIONS_CSV=/path/to/citations.csv swift run CentralFilesIndexGenerator   # Phase 3: pre-resolve distinct lot files (variantControlNumber_is) into the bundled index
CATALOG_API_KEY=<key> ENRICH_LOTS=1 swift run CentralFilesIndexGenerator   # #315A: enrich the already-harvested index's lot files with HMS/MLR entry numbers from the Catalog (reads + rewrites OUTPUT_PATH in place; cached to CACHE_DIR)
PRUNE_FLAGGED_LOTS=1 swift run CentralFilesIndexGenerator   # #321 OFFLINE remediation (NO API key): drop lot files flagged ancestryLacksRecordGroup from the already-harvested index and rewrite it in place — run after ANY re-harvest, since the durable resolver policy rejects these only on fresh queries
swift run VolumeSourcesIndexGenerator   # Harvest every volume's front-matter Sources section → volume-sources-index.json (per-volume prose + resolved archival-collection outline + cross-volume authority). Offline pass: lot files resolve against central-files-index.json. Env: VOLUMES_DIR, CENTRAL_FILES_INDEX, OUTPUT, GENERATED_DATE
CATALOG_API_KEY=<key> swift run VolumeSourcesIndexGenerator   # Adds the NARA Catalog resolution pass: lot files the bundle missed (variantControlNumber_is) + record-group headers → NAIDs. Cached to CACHE_DIR (default .cache/volume-sources), so re-runs are free
swift run -c release CollectionAuthorityGenerator   # Regenerate collection-authority.json (Source Explorer Phase 4): parses all TEI volumes' front-matter Sources + document source notes with the shared SourceNoteKit grammar, clusters them into a two-level cross-volume collection authority (identity/aliases/volume-lists/NAIDs only — no document counts), NAIDs resolved 100% offline (central-files-index + volume-sources-index + .cache/volume-sources; never the live API). Also writes collection-authority-report.txt (stats, coverage, unmerged ambiguous clusters). Env: VOLUMES_DIR, CENTRAL_FILES_INDEX, VOLUME_SOURCES_INDEX, CACHE_DIR, OUTPUT, REPORT, GENERATED_DATE
swift run -c release SourceProvenanceIndexGenerator   # Regenerate source-provenance-index.json (Series analytics SA-3a, prerequisite for the SA-3 "Archival Sourcing Over Time" dashboard): parses every volume's per-document source notes (every TEI type="source" element) with the shared SourceNoteParser grammar, maps each parse to a stable ProvenanceCategory (centralDecimalFile / centralForeignPolicyFile / lotFile / presidentialLibrary / naraCollection / intelligence / namedFileSeries / foreignArchive / previouslyPublished / unrecognized), and aggregates the counts by coverage decade (manifest dateRange midpoint). Entirely offline; small (~4.5KB) bundled aggregate. Env: VOLUMES_DIR, MANIFEST (default Resources/manifest.json), OUTPUT (default Resources/source-provenance-index.json), GENERATED_DATE
swift run -c release AdministrationProfilesIndexGenerator   # Regenerate administration-profiles-index.json (Series analytics SA-2a, prerequisite for the SA-2 "Administration Production Profiles" dashboard): reads the authoritative frus:doc-dateTime-min/-max bounds on each FRUS document <div> (the same editorial dates IndexingPipeline.extractDateRange prefers), classifies each document as point-dated (min day == max day) / range-dated (multi-day, chiefly editorial notes) / undated, and attributes it — BY DOCUMENT DATE keyed to who was in office (coverage, not production) — to presidential administration(s): half-open [start,end) for point dates (a succession-day doc goes to the successor), any-overlap for ranges (tracked separately so the dashboard can include/exclude them). Aggregates per-(administration,volume) + per-administration (pointDocCount / rangeDocCount / volumeCount / volumeCountPointOnly / coverage span / volume breakdown) + per-volume totals (the proportion denominators). Nixon and Ford are DISTINCT; the two Cleveland/Trump terms are separate. Entirely offline & deterministic; ~167KB bundled aggregate. Env: VOLUMES_DIR (default /Users/jbotts/Development/frus/volumes), ADMINISTRATIONS (default Resources/administrations.json), OUTPUT (default Resources/administration-profiles-index.json), GENERATED_DATE
swift run -c release CrossRefValidationGenerator   # Validate every <ref target> across the local corpus (Wave-6 Session 6, issue #240). Pass A byte-scans each volume's xml:id inventory (pages included — <pb> carries xml:id="pg_N", so anchor validation is one set-membership test, no separate page index); Pass B byte-scans for <ref target> capturing UTF-8 byte offset + 1-based line + nearest enclosing <div type="document"> (both passes skip comments/CDATA/PI, so a stray <ref — or a phantom xml:id — inside a comment is neither harvested nor inventoried); Pass C classifies each with the shared CrossRefKit grammar (a parity-tested mirror of the app's resolveCrossRefTarget) and resolves it against the inventories (literal xml:id membership, with footnote dNfnM→dN and page pageN→pg_N fallbacks that match app navigation). Emits three artifacts to OUTPUT_DIR: broken-refs-report.csv (the OH-submittable spreadsheet — one row per broken ref, precise location, sorted by source volume then line), broken-refs-report.json (machine copy: aggregate metadata + full records), and broken-refs-index.json (the CANDIDATE bundled exclusion index for Session 7; composite (sv,sd,t)-keyed and DEDUPLICATED to one record per distinct key — totalBroken stays the occurrence count — full-detail while <1.5MB else compact rv/ra-dropped). Broken reasons: unknownPage / unknownAnchor / unknownVolume / malformedTarget / emptyTarget. Non-broken outcomes (external, wholeVolumeRef, resolved, volumeNotInSnapshot) plus non-shippable refs (resolve in-corpus but target a volume outside the app manifest) are tallied, not reported. Entirely offline & deterministic (filename-sorted scan + explicit record sorts + sorted JSON keys). SPM-ONLY generator (adds CrossRefKit + GeneratorKit + CrossRefValidationGenerator* targets to Package.swift). To REFRESH the app's bundled exclusion index (Session 7 / #240B), re-run then copy the one index file into Resources — `cp Planning/cross-ref-validation/broken-refs-index.json FRUSExplorer/Resources/broken-refs-index.json` (do NOT point OUTPUT_DIR at Resources — that would also dump the 271KB CSV+report into the bundle). A same-name refresh needs NO xcodegen (the file is already enrolled in project.pbxproj; xcodegen + scheme restore only if the resource is new/renamed). The app's `applyBrokenRefsIndexIfNeeded` re-runs whenever the bundled index's `generated` stamp changes. Env: VOLUMES_DIR (default /Users/jbotts/Development/frus/volumes), MANIFEST (default FRUSExplorer/Resources/manifest.json — defines the shippable series set), OUTPUT_DIR (default Planning/cross-ref-validation), GENERATED_DATE
swift run -c release VolumeSubjectProfilesGenerator   # Regenerate volume-subject-profiles-index.json (Wave-6 Session 9, the volume-level Subjects feature): reads the Office of the Historian public-domain frus-subjects document–subject mappings (/Users/jbotts/Development/frus-subjects/data/document_subjects.json) and aggregates a per-volume "top subjects" profile. Score = (docs in volume tagged with subject / distinct tagged docs in volume) × ln(corpus tagged docs / subject corpus doc-frequency); a genericity floor drops subjects tagging >GENERICITY_THRESHOLD of all tagged corpus docs (7 at the 0.10 default — War, Peace, Treaties…, etc.); a per-volume MIN_DOC_COUNT floor kills singletons; TOP_N per volume; the shared subject vocabulary is int-indexed to keep the artifact compact. Document-level tags are NOT re-introduced — noise washes out only at the volume grain. An ERA-SANITY pass (#308 F2, EraSanity.swift's owner-reviewed earliest-plausible-year table — named events/organizations only, never perennial concepts) drops anachronistic subject↔volume entries whose subject postdates the volume's entire coverage span (manifest dateRange end year); table names absent from the drop are warned, never silently disabled. Entirely offline & deterministic (JSONEncoder .sortedKeys, compact — no pretty-printing — + explicit sorts); provenance pins the source drop's generated date AND md5 (upstream re-mints ~95 synthetic refs per export). ~224KB bundled aggregate (lazily loaded, not at app init). Env: DOCUMENT_SUBJECTS, MANIFEST (default FRUSExplorer/Resources/manifest.json — supplies the coverage-end years; the runner throws if absent), OUTPUT (default FRUSExplorer/Resources/volume-subject-profiles-index.json), GENERATED_DATE, GENERICITY_THRESHOLD (0.10), MIN_DOC_COUNT (2), TOP_N (15)
```

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
        ↓
  SwiftData + CloudKit          SQLite FTS5
  (user data: notes, tags,      (search index, cross-refs,
   collections, highlights,      persons, glossaries, dates)
   prompts, projects)
        ↓
TEI Rendering Pipeline: XML → FRUSDocumentParser → FRUSASTNode
                             → ASTToRenderNode → FRUSDocumentRenderer → SwiftUI
```

### Key Data Flows

- **Download → Index**: `DownloadManager` queues volume files; on completion `IndexingPipeline` parses TEI XML and populates FTS5 tables (documents, persons, cross-references, dates).
- **Search**: `SearchService` queries FTS5 with BM25 ranking and English stemming; results flow to `SearchView`.
- **Document rendering**: TEI XML is parsed into an AST (`FRUSASTNode`), converted to render nodes, and displayed via `FRUSDocumentRenderer`. Highlights are overlaid post-render.
- **Summarization**: `SummarizationService` and `BackgroundSummarizationService` call Apple's `FoundationModels` framework (on-device); summaries stored in SwiftData and indexed in FTS5.
- **User data sync**: SwiftData models sync automatically via CloudKit (`iCloud.bottsywattsy.FRUS-Explorer`).

### Platform Layout Split

- **iOS/iPadOS**: `MainTabView` with 5 tabs — Browse, Search, Activity, Collections, Settings. iPad adds `.inspector(isPresented:)` panels and Stage Manager multi-window scenes.
- **macOS**: `MainWindowView` with sidebar navigation plus dedicated window scenes for Search, Browser, CrossReference, SourceExplorer, and Collections.

The `#if os(iOS)` / `#if os(macOS)` conditional compilation pattern is used extensively throughout views.

### Directory Map (`FRUSExplorer/`)

| Directory | Purpose |
|-----------|---------|
| `App/` | `@main` entry point, `AppState`, `ContentView`, routing |
| `Models/` | SwiftData model types, manifest structs, tag/person/highlight models |
| `Search/` | `SearchService`, `IndexingPipeline` (the largest file), `SearchView` |
| `TEI/` | XML parser, AST types, AST-to-render conversion, renderer |
| `Browser/` | Volume/subseries/corpus navigation with breadcrumb trail |
| `DocumentView/` | Document display, research notes panel, cross-reference links |
| `CrossReference/` | Graph visualization, `CrossReferenceStore` |
| `Collections/` | Collection editor, PDF/HTML/DOCX exporters |
| `Citation/` | Citation formatter, lookup engine, parser, BibTeX/RIS export |
| `Summarization/` | Apple Intelligence integration, prompt management UI |
| `SourceExplorer/` | NARA catalog integration |
| `Downloads/` | `DownloadManager`, download queue UI |
| `Analytics/` | Term frequency analysis with Swift Charts |
| `Theme/` | `FRUSTheme` (colors, typography constants) |
| `Resources/` | Bundled JSON: manifest, taxonomy, subject tags, TEI config |

**SPM package targets** (separate from the app, in `Package.swift`):
- `ManifestGenerator`, `TaxonomyGenerator`, `FTS5Store` (reusable SQLite FTS5 actor)
- Test targets: `ManifestGeneratorTests`, `TaxonomyGeneratorTests`, `FTS5StoreTests`

## Coding Standards

**Only three of these have a mechanical gate. Check the rest by hand — do not assume a test will catch you.** (The heading used to read "enforced by `CodingStandardsAuditTests`", which was true of half the list and let several stale doc comments ship unnoticed.)

Enforced by `CodingStandardsAuditTests` — these fail the test suite:

- **License header**: Apache 2.0 header required on every source file *and* every test file.
- **OpenAPI spec** (`FRUS-API.openapi.yaml`): must remain valid OpenAPI 3.1.0, declare no deprecated `nullable: true`, and define the `/citation-lookup` endpoint + `CitationMatch` schema. Update whenever the API surface changes.
- **Version history**: required on an **allowlist** of key session-output files (not all files).

Conventions with **no** automated check — reviewer's responsibility:

- **Swift 6 strict concurrency**: zero warnings under `SWIFT_STRICT_CONCURRENCY=complete`. This is a build setting, not part of the audit suite. The app targets do currently build with zero *source* warnings; the residue is a SwiftData `@Model` macro-expansion `Sendable` warning plus AppIntents tool notices.
- **Localization**: all user-facing strings use `String(localized:)` — no raw string literals in views.
- **Doc comments**: every `public`/`internal` type, function, and property requires a doc comment. Nothing verifies that they are *accurate*, either — verify doc claims about runtime behaviour by running the app, not by reading neighbouring comments or commit messages.
- **Debug logging**: use `#if DEBUG` blocks with `print("[TypeName] ...")` prefix.

## Planning & Specification

- `Planning/FRUS-Explorer-Specification.md` — complete design spec (1800+ lines); consult before adding features.
- `Planning/DEVELOPMENT-PLAN.md` — session-by-session task log; update after each work session.
- `Planning/` contains per-task markdown files (e.g., `02-Manifest-Generator.md`) with detailed requirements.

## Bundle IDs & Entitlements

| Setting | Value |
|---------|-------|
| Bundle ID | `bottsywattsy.FRUS-Explorer` |
| CloudKit container | `iCloud.bottsywattsy.FRUS-Explorer` |
| iOS scheme | `FRUSExplorer` |
| macOS scheme | `FRUSExplorerMac` |
| macOS configs | `AppStore`, `DirectDistribution` |
