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

**SPM command-line tools (run from repo root):**
```bash
swift run ManifestGenerator   # Regenerate manifest.json from GitHub FRUS TEI headers
swift run TaxonomyGenerator   # Regenerate volume-tag-taxonomy.json
CATALOG_API_KEY=<key> swift run CentralFilesIndexGenerator   # Harvest NARA Catalog → central-files-index.json (Phase 1: 1906–1910 Numerical File; Phase 2: diplomatic series)
CATALOG_API_KEY=<key> SURVEY_SERIES=603720 swift run CentralFilesIndexGenerator   # Phase 2 survey: report a diplomatic series' structure (603720/593313/594363/597272)
CATALOG_API_KEY=<key> CITATIONS_CSV=/path/to/citations.csv swift run CentralFilesIndexGenerator   # Phase 3: pre-resolve distinct lot files (variantControlNumber_is) into the bundled index
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

## Coding Standards (enforced by `CodingStandardsAuditTests`)

- **Swift 6 strict concurrency**: zero warnings under `SWIFT_STRICT_CONCURRENCY=complete`.
- **Localization**: all user-facing strings use `String(localized:)` — no raw string literals in views.
- **Doc comments**: every `public`/`internal` type, function, and property requires a doc comment.
- **License header**: Apache 2.0 header required on every source file.
- **OpenAPI spec** (`FRUS-API.openapi.yaml`): update whenever the API surface changes; must remain valid OpenAPI 3.1.0.
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
