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
swift run -c release SourceExplorerExportGenerator   # Corpus-wide Source Explorer data export (#335): one record per document source note across the shippable corpus — canonical volumeId/documentId, the raw stored note (parity-pinned DocumentNoteExtractor, exactly what the app hands Source Explorer), the parsed value (shared SourceNoteParser), the strategy (ProvenanceCategory slug), derived keys (neighbor key / lotFileNorm / gated decimalClass / classification marking), and the OFFLINE resolution dictionary: bundled lot index (BundledLotResolver, #321 guard; misses distinguish notInBundle vs flaggedAncestryLacksRecordGroup), 1906–1910 Numerical File rolls (year-gated like the app), volume-sources index (lot-over-RG precedence), collection-authority 4-step lookup (AuthorityLookup, parity-mirrored), plus the recorded-never-executed live catalog route. Writes to OUTPUT_DIR: source-explorer-export.json (the full 264k-record ~182MB export — GITIGNORED, too large to commit), source-explorer-export-summary.json (committed aggregates: strategy × outcome × decade), source-explorer-export-sample.json (every 200th record, committed). Entirely offline & deterministic (filename-sorted scan, sortedKeys, per-volume streamed writes). Env: VOLUMES_DIR (default /Users/jbotts/Development/frus/volumes), MANIFEST (default FRUSExplorer/Resources/manifest.json — the shippable set), CENTRAL_FILES_INDEX / VOLUME_SOURCES_INDEX / COLLECTION_AUTHORITY (default the bundled Resources copies), OUTPUT_DIR (default Planning/source-explorer-export), GENERATED_DATE
swift run -c release VolumeSubjectProfilesGenerator   # Regenerate volume-subject-profiles-index.json (Wave-6 Session 9, the volume-level Subjects feature): reads the Office of the Historian public-domain frus-subjects document–subject mappings (/Users/jbotts/Development/frus-subjects/data/document_subjects.json) and aggregates a per-volume "top subjects" profile. Score = (docs in volume tagged with subject / distinct tagged docs in volume) × ln(corpus tagged docs / subject corpus doc-frequency); a genericity floor drops subjects tagging >GENERICITY_THRESHOLD of all tagged corpus docs (7 at the 0.10 default — War, Peace, Treaties…, etc.); a per-volume MIN_DOC_COUNT floor kills singletons; TOP_N per volume; the shared subject vocabulary is int-indexed to keep the artifact compact. Document-level tags are NOT re-introduced — noise washes out only at the volume grain. An ERA-SANITY pass (#308 F2, EraSanity.swift's owner-reviewed earliest-plausible-year table — named events/organizations only, never perennial concepts) drops anachronistic subject↔volume entries whose subject postdates the volume's entire coverage span (manifest dateRange end year); table names absent from the drop are warned, never silently disabled. Entirely offline & deterministic (JSONEncoder .sortedKeys, compact — no pretty-printing — + explicit sorts); provenance pins the source drop's generated date AND md5 (upstream re-mints ~95 synthetic refs per export). ~224KB bundled aggregate (lazily loaded, not at app init). Env: DOCUMENT_SUBJECTS, MANIFEST (default FRUSExplorer/Resources/manifest.json — supplies the coverage-end years; the runner throws if absent), OUTPUT (default FRUSExplorer/Resources/volume-subject-profiles-index.json), GENERATED_DATE, GENERICITY_THRESHOLD (0.10), MIN_DOC_COUNT (2), TOP_N (15)
PROBE=1 swift run -c release RecordGroupCatalogGenerator   # Offline NARA Catalog index for 22 foreign-affairs record groups (43, 59, 63, 76, 84, 169, 182, 208, 229, 239, 256, 268, 278, 286, 306, 353, 383, 420, 466, 469, 486, 490) — a CentralFilesIndexGenerator spin-off that keeps ALL available description data, with creator information and the complete UNFILTERED variantControlNumbers as its two priority payloads. NEEDS NO CATALOG_API_KEY: it streams NARA's public S3 bulk export (nara-national-archives-catalog, us-east-2, unauthenticated), not the v2 search API — so no 10,000/month quota, every level of description in one pass (adding file units for a chosen record group later is a filter change, not a second harvest), and each group's own recordGroup record carries NARA's `seriesCount`, which makes a truncated harvest SELF-DETECTING (verified: RG 486 = 11/11, RG 420 = 31/31). The cost is bandwidth — series are scattered through every shard, so a series-only harvest still streams the whole group; ~22 GB for all 22, of which RG 59 is 17.2 GB. ALWAYS START WITH `PROBE=1` (one shard per group, a few MB, censuses only, no index, written to OUTPUT_DIR/probe/ so it cannot clobber a real harvest): it confirms `creators` and `variantControlNumbers` are present under those names before anything large runs. The run-wide artifacts (manifest, censuses, sample, report) are rewritten from the CURRENT invocation's groups only — per-group index shards are not — so after any subset run FINISH with one offline `PROJECT_ONLY=1` pass over all groups to rebuild them (the tool emits a SUBSET RUN review note to say so). Every shard is checkpointed, so an interrupted or MAX_BYTES-stopped run resumes (and exits 0); `PROJECT_ONLY=1` rebuilds the index + censuses from the stored raw NDJSON with NO network, which is why a wrong field name costs seconds rather than a re-download — do NOT delete CACHE_DIR before the index is settled, notwithstanding the `.cache/` "regenerable scratch" convention. A depth escalation REFUSES to resume a shallower checkpoint (the shallow pass never read those levels) and names REFRESH=1. Env: RECORD_GROUPS, DEPTH (series|seriesAndFileUnits|all), DEPTH_OVERRIDES (`<rg>:<depth>` pairs — the per-group file-units-later path), OUTPUT_DIR (default Planning/nara-record-group-catalog), CACHE_DIR (default .cache/nara-rg-catalog), PROBE, PROJECT_ONLY, CREATOR_AUTHORITY (=1 resolves creators[].naId against NARA's authority records for administrative-history prose — note the join is NOT naId==naId; creator NAIDs are nested organizationNames[].naId inside a DIFFERENT parent authority record), REFRESH, MAX_BYTES, SAMPLE_EVERY, ALLOW_SHORT, BASE_URL, GENERATED_DATE. Artifacts: manifest.json + four census CSVs + creator-authority.json + series-sample.json are COMMITTED; series/rg_<N>.json (~165MB total) is gitignored. Non-zero exit when a priority field matched nothing, a checkpoint was refused, or a group is materially short of NARA's own count. API REFRESH (optional, needs the key): the bulk export is a SNAPSHOT (2026-04-09; republished ~2x/year). `CATALOG_API_KEY=<key> API_SURVEY=1` spends a handful of calls printing a paste-back block that settles the four unverified query-shape questions (envelope path — the repo's own two clients disagree; which `sort` element is the cursor — NARA's example is [score, naId] so sort[0] is a relevance score; whether `limit` is clamped; whether `q` is required); then `CATALOG_API_KEY=<key> API_REFRESH=1` re-pages the live API into CACHE_DIR/raw-api/, overlays it on the snapshot (API wins by naId) and writes census/refresh-changelog.csv classifying added/modified/unchanged/missingFromRefresh. There is NO incremental delta and there cannot be — no modified/updated/version field exists anywhere in the record payload (censused over 513 records) — so it re-pages, which is cheap (~40 calls at limit=1000 for all 22 groups' series layer vs a 10,000/month quota) and also catches WITHDRAWALS that a date filter structurally cannot. Guards: an EMPTY refresh is discarded rather than merged (it would otherwise flag every record withdrawn), a refresh failure leaves the snapshot index intact, each admitted level is paged separately (an unfiltered seriesAndFileUnits refresh would page items too), MAX_API_REQUESTS_PER_GROUP caps spend, and a non-advancing cursor throws. The API query shape is UNVERIFIED until the owner runs the survey. Full runbook: Planning/nara-record-group-catalog-runbook.md
GENERATED_DATE=<date> swift run -c release CloudVectorsGenerator   # Regenerate cloud-vectors-core.json + cloud-vectors-volumes.json (Workstream O, session O-1): the bundled word-cloud vectors behind the onboarding backdrop and launch splash, so the cloud renders with ZERO volumes downloaded. Byte-scans every manifest volume for `<div type="document">` body text (TEIBodyTextExtractor mimics IndexingPipeline's `body_text` — all character data inside the div, footnotes INCLUDED, matching FRUSASTNode.plainText), tokenises all four bundled lenses (concepts/topics/actions/sentiment; entity lenses excluded per the design hand-off) in ONE NLTagger pass via WordCloudKit's WordCloudMultiLensTokenizer, then rolls RAW counts up volume → subseries → corpus. Stores raw counts, not the hand-off's normalised 0–100 weights: the hand-off also asks for "sum raw counts then re-rank" for multi-volume scopes, and those two are incompatible — summing normalised weights is meaningless. The loader normalises (entries are sorted descending, so the first is the max). Aggregation happens BEFORE top-50 truncation, or a term ranked 51st in each of forty volumes would vanish from their subseries. Two files split by ACCESS PATTERN, each with its own self-contained int-indexed vocabulary: core (corpus + 107 subseries, loaded eagerly off-main) and volumes (the 552-volume tail, loaded lazily on first Volume-segment selection) — the splash cannot afford a ~1.5MB decode before its first frame. Thin lists are MARKED `belowSignalThreshold`, never dropped (decision O-4-2: a silent fallback would show a volume the era's vocabulary and let the user attribute it to the volume). THROWS on empty stopwords/lexicons where the app degrades to empty — a shipped artifact built without stopwords would bury every cloud under function words and nothing downstream would notice. Entirely offline & deterministic (filename-sorted scan, count-then-term tiebreak at every ranking step, first-appearance vocabulary interning, sortedKeys). Env: VOLUMES_DIR (default /Users/jbotts/Development/frus/volumes), MANIFEST, LEXICONS, STOPWORDS, OUTPUT_DIR (default FRUSExplorer/Resources), GENERATED_DATE
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

- **iOS/iPadOS**: `MainTabView` with 5 tabs — Browse, Search, Research, Collections, Settings. iPad adds `.inspector(isPresented:)` panels (including the document Research rail) and Stage Manager multi-window scenes.
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
| `DocumentView/` | Document display, the shared Research rail + floating selection bar, cross-reference links |
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
- Test targets: `ManifestGeneratorTests`, `TaxonomyGeneratorTests`, `FTS5StoreTests`,
  `WordCloudKitTests`

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
   in Settings ▸ Data & Recovery ▸ iCloud Schema). The list is also an **interlock**:
   `ResearchTrailMigration` refuses to run while a record type it writes is listed here, because it
   deletes the rows it replaces in the same call and CloudKit would keep only the deletions.
3. Owner step: exercise the new type/field once on a Development build with iCloud signed in, then
   CloudKit Dashboard → Schema → **Deploy Schema Changes to Production**.
4. Clear `identifiersAwaitingDeploy`, re-run the suite, paste the count + digest it prints, and
   update `deployedThroughBuild` / `deployedOn`.

Only step 3 is outside the repo, and only step 3 cannot be verified by a test.

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
