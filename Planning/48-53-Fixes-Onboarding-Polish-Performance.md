# Sessions 48–53 — Bug Fixes, Onboarding Redesign, Browser Polish, Indexing Performance

**Version**: 1.0
**Date**: 2026-05-17

This block addresses production bugs identified in live-device testing (Session 47 console
log), a complete onboarding redesign, browser and navigation polish, iOS indexing memory
management, and a feasibility assessment for a bundled corpus-level pre-index.

---

## Session Sequence

| # | Task | Key Output | Depends On |
|---|---|---|---|
| 48 | Database & Infrastructure Bug Fixes | FTS5 `is_editorial_note` rebuild; `UIBackgroundModes`; BGTaskScheduler cap | 38, 45 |
| 49 | Onboarding Redesign & Download Manager | Three-choice onboarding; default project; subseries/subject picker in Settings | 10, 24, 49* |
| 50 | Browser & Navigation Polish | Downloaded-volumes filter; multi-line breadcrumbs; macOS About menu item | 11, 32, 46 |
| 51 | iOS Indexing Performance & Visualization | Memory-aware throttle; progress visualization | 09, 33, 45 |
| 52 | UI Obstruction Audit & Fixes | Safe-area and composed-view obstruction mitigations | All prior |
| 53 | Pre-Index Feasibility Assessment | Architecture document; recommended approach | 09 |

---

## Session 48 — Database & Infrastructure Bug Fixes

### Goal

Fix three live-device regressions identified in the post-Session 47 console log:

1. **FTS5 `is_editorial_note` column absent** — `frus_documents` FTS5 virtual table was
   never updated; `INSERT` fails with "no such column" for every indexed volume, silently
   preventing all editorial-note distinction data from being stored.
2. **`UIBackgroundModes: remote-notification` missing** — CloudKit push notifications
   produce a console warning and may fail to deliver on devices with strict background limits.
3. **BGTaskScheduler Code=3** — CloudKit schedules more background export tasks than the
   system limit allows; repeated `updateTaskRequest failed` errors in the log.

### Key Changes

**FTS5 Table Rebuild (`IndexingPipeline`)**:

SQLite `ALTER TABLE ADD COLUMN` is silently ignored on FTS5 virtual tables. The only
correct mitigation is a version-gated rebuild:

```
Schema version 3 (added by Session 48):
  1. Check PRAGMA user_version
  2. If < 3:
     a. BEGIN TRANSACTION
     b. INSERT OR IGNORE into a temp table: SELECT * FROM frus_documents (all existing rows)
        — note: this captures what FTS5 _does_ expose; is_editorial_note will be 0 for all
     c. DROP TABLE IF EXISTS frus_documents
     d. CREATE VIRTUAL TABLE frus_documents USING fts5(..., is_editorial_note UNINDEXED)
     e. Re-insert rows from temp table with is_editorial_note = 0
     f. DROP temp table
     g. PRAGMA user_version = 3
     h. COMMIT
  3. Set UserDefaults "frus.ftsIndexVersion = 3" migration flag to trigger background
     re-index of all downloaded volumes (so is_editorial_note is correctly populated)
```

The re-index flag follows the Session 36 pattern: `UserDefaults` key
`frus.ftsSchemaVersion`; compared on `IndexingPipeline.init`; if stale, enqueues all
downloaded volumes for background re-index.

Because all simulator and Mac container databases currently have 4 KB empty files (FTS5
bug prevented all prior indexing), the rebuild will always run on first upgrade install.

**`Info.plist` — `UIBackgroundModes`**:

Add `remote-notification` to the `UIBackgroundModes` array in `project.yml`
(`INFOPLIST_KEY_UIBackgroundModes`). This is required for CloudKit to deliver silent
push notifications that trigger incremental sync.

**BGTaskScheduler cap**:

Wrap the CloudKit `NSPersistentCloudKitContainer` background task scheduling call in a
guard that checks the number of pending requests before adding another. Use
`BGTaskScheduler.shared.getPendingTaskRequests` (async API) to count pending export
tasks; skip `updateTaskRequest` if count ≥ system cap (empirically 1 per identifier).
Add a `#if DEBUG` log prefix `[CloudKit]` for all scheduling events.

### Tests

`FTS5RebuildTests` (3 cases) in `IndexingPipelineTests`:
- `ftsSchemaUpgradeAddsEditorialNoteColumn` — open DB at version 2, run migration,
  verify column present and INSERT succeeds
- `ftsRebuildPreservesExistingRows` — seed rows before migration, verify they survive
- `migrationFlagTriggersReindex` — verify `frus.ftsSchemaVersion` updated and reindex
  enqueued for all downloaded volumes

---

## Session 49 — Onboarding Redesign & Download Manager Enhancement

### Goal

Replace the current multi-step onboarding (subseries picker → subject picker → project
creation) with a streamlined three-choice flow. Move the subseries and subject pickers
to the Settings → Download Manager so power users can still access them. Create a
suggested "Onboarding" project pre-filled with corpus-wide date bounds.

### Background

The current onboarding asks users to make curatorial decisions (which subseries? which
subjects?) before they understand the app. New flow: pick a download scope, name a
project, start. Depth is preserved in Settings.

### Key Changes

**`OnboardingView`** — redesigned into a three-step sheet:

Step 1 — **Welcome** (static): app name, tagline, one-sentence description.

Step 2 — **Download Scope** (new `DownloadScopePickerView`):
```
○  Entire Corpus     552 volumes · 3.3 GB
   Download everything and search the full series.

○  A Subseries       [Subseries picker — segmented or list]
   Choose a decade or era.

○  A Single Volume   [Volume search field]
   Find and download one volume to explore.
```
`DownloadScopePickerView` replaces the old `SubseriesPickerView` inside onboarding.
The subseries and subject-filter pickers currently in onboarding are removed from
the onboarding flow entirely and relocated to Settings (see below).

Step 3 — **Create Project** (`ProjectCreationView`):
Pre-filled suggestion:
- **Name**: "Onboarding"
- **Reason**: "Explore app"
- **Date from**: `1861-01-01` (derived at runtime as `minCorpusYear` from manifest)
- **Date to**: `1992-12-31` (derived as `maxCorpusYear` from manifest)

`minCorpusYear` / `maxCorpusYear` are computed once in `ManifestStore` by scanning
`subseries` fields for leading 4-digit year tokens. Returns `1861` / `1992` given the
current 552-volume corpus. Pre-fill is editable; user may clear and enter any values.

**`ManifestStore`**:
- `var corpusDateRange: ClosedRange<Date>` — computed from subseries year scan; cached
  after first call; returns `1861-01-01...1992-12-31` for the current corpus.

**Settings → Download Manager** (`DownloadManagerSettingsView`, new):
- Moved from onboarding: subseries filter and subject-tag filter for bulk downloads
- "Download selected subseries" / "Download by subject tag" actions
- Integrates with existing `DownloadManager` queue
- Exposed as a new row in `VolumesSettingsPane` (macOS) and `SettingsView` (iOS)

**`AppState`** — `showOnboarding` logic unchanged; `pendingDownloadScope: DownloadScope?`
enum (`.corpus`, `.subseries(String)`, `.volume(String)`) passed from onboarding to
`DownloadManager`.

### Tests

`OnboardingFlowTests` (4 cases):
- `corpusDateRangeDerivedFromManifest` — `ManifestStore.corpusDateRange` returns
  expected bounds given a fixture manifest
- `downloadScopeCorpusEnqueuesAllVolumes` — `.corpus` scope enqueues all 552 volumes
- `downloadScopeSubseriesFiltersCorrectly` — `.subseries("1969-76")` enqueues only
  volumes matching that subseries prefix
- `defaultProjectPreFillUsesCorpusDates` — `ProjectCreationView` model has correct
  default name/reason/dates

---

## Session 50 — Browser & Navigation Polish

### Goal

Three independent polish items: (1) a downloaded-volumes filter toggle in BrowserView,
(2) multi-line breadcrumb display, (3) moving the macOS About view from the Settings
Advanced pane to the standard macOS application menu.

### Key Changes

**Downloaded-Volumes Filter (`BrowserView`)**:

A `filterDownloadedOnly: Bool` toggle in the BrowserView toolbar (iOS: toolbar item;
macOS: toolbar control). When `true`:
- At the corpus level: only subseries that contain ≥1 downloaded volume are shown
- At the subseries level: only volumes with `DownloadState.downloaded` are shown
- Badge or label "Showing downloaded only" when filter is active

`filterDownloadedOnly` stored in `AppState` (persisted to `UserDefaults("frus.filterDownloadedOnly")`).

**Multi-line Breadcrumbs (`BrowserBreadcrumbBar`)**:

Current: `ScrollView(.horizontal)` with `HStack` — breadcrumbs overflow off-screen.
New: `FlowLayout` (custom `Layout`-conforming type) that wraps onto additional lines
rather than scrolling horizontally. No truncation. Height is dynamic.

`BrowserBreadcrumbBar` structural change:
- Remove `ScrollView(.horizontal)` wrapper
- Replace with `BreadcrumbFlowLayout` (new `Layout` conformer; no external dependencies)
- Separator `"›"` between crumbs unchanged
- Root "FRUS" crumb unchanged
- Tap behavior unchanged

**macOS About Menu Item**:

Standard macOS behavior places "About [App]" as the first item in the application
menu. Currently the About view lives inside `MacSettingsView` → `AdvancedSettingsPane`.

Changes:
- `FRUSExplorerApp.body` (macOS): add `CommandGroup(replacing: .appInfo) { ... }` that
  presents `AboutView` as a sheet or uses `NSApplication.shared.orderFrontStandardAboutPanel`
  with a custom `NSDictionary` of credits. Preferred: sheet via `appState.showAbout`.
- `AppState` (macOS-guarded): `showAbout: Bool`
- `BrowserView` (macOS): `.sheet(isPresented: $appState.showAbout) { AboutView() }`
- `MacSettingsView` → `AdvancedSettingsPane`: remove the "About FRUS Explorer"
  `NavigationLink` row; retain only "Reset App"

The iOS About view (in `SettingsView`) is unchanged.

### Tests

`BrowserFilterTests` (3 cases) in `BrowserViewTests`:
- `filterToggleHidesNonDownloadedVolumes`
- `filterTogglePersistedToUserDefaults`
- `filterOffShowsAllVolumes`

`BreadcrumbLayoutTests` (2 cases):
- `longPathWrapsToMultipleLines` — measure layout with a 6-crumb path
- `singleCrumbFitsOnOneLine`

`MacAboutMenuTests` (1 case, macOS-guarded):
- `aboutCommandGroupPresentsAboutView`

---

## Session 51 — iOS Indexing Performance & Visualization

### Goal

Prevent iOS from terminating the app due to excessive memory consumption during bulk
indexing (observed when downloading and indexing many volumes in sequence). Add a
progress visualization so users understand what is happening during indexing.

### iOS Memory Throttle

The iOS memory limit for foreground apps is approximately 1.2–1.8 GB (device-dependent).
The current `IndexingPipeline` processes all documents in one SQLite transaction per
volume, which can require holding the full parsed TEI AST in memory simultaneously for
large volumes.

Changes to `IndexingPipeline`:

**Batch commit strategy** — replace single-transaction-per-volume with chunked
transactions of `batchSize` documents (default: 50 on iOS, unlimited on macOS):
```swift
#if os(iOS)
static let batchSize = 50
#else
static let batchSize = Int.max
#endif
```
After each batch commit, call `Task.yield()` to release memory before the next batch.

**Memory pressure monitoring** — register for `ProcessInfo.thermalState` and
`UIApplication.didReceiveMemoryWarningNotification`. On memory warning: reduce
`batchSize` to 20 and insert a 500ms sleep between batches. Return to default after
warning clears.

**Serial queue on iOS** — existing `IndexingPipeline` is an actor (serial by definition).
Concurrent indexing is already prevented. No change needed here.

**`Task.yield()` between volumes** — `FRUSExplorerApp.bootDownloadManager` wraps
the `onVolumeDownloaded` callback to insert `await Task.yield()` before calling
`indexVolume`, giving the system a chance to reclaim memory between sequential
auto-indexes.

### Indexing Progress Visualization

**Decision point**: Choose one of the following options before implementing. Options
presented to the user but answer deferred — to be confirmed at session start.

| Option | Description |
|--------|-------------|
| A | Per-row progress bar in volume list (inline in Manage Volumes) |
| B | Persistent thin banner above tab bar; taps to expand queue sheet |
| C | Live cards in Activity tab with docs/sec rate; persists as history |
| D | Inline capsule in BrowserView volume rows (minimal new surface) |

**Implementation regardless of option**:

`IndexingPipeline` must publish indexing state. New `IndexingProgressUpdate` value type:
```swift
struct IndexingProgressUpdate: Sendable {
    let volumeId: String
    let stage: IndexingStage         // parsing, dates, persons, fts5, complete
    let completedDocuments: Int
    let totalDocuments: Int          // 0 if unknown
    let docsPerSecond: Double        // rolling 5-second average
}

enum IndexingStage: String, Sendable {
    case parsing, extractingDates, indexingPersons, buildingFTS5, complete
}
```

`IndexingPipeline` gains `var progressStream: AsyncStream<IndexingProgressUpdate>` backed
by an `AsyncStream.Continuation` stored as an actor property. Emitted at each stage
transition and after each batch commit.

`AppState` subscribes to `progressStream` on init and stores
`currentIndexingProgress: IndexingProgressUpdate?` (iOS-guarded; nil when idle).

The chosen visualization option reads from `appState.currentIndexingProgress`.

### Tests

`IndexingThrottleTests` (3 cases):
- `batchSizeIsReducedUnderMemoryPressure`
- `batchSizeiOS50MacUnlimited`
- `taskYieldCalledBetweenBatches` (verifies the yield hook in bootDownloadManager)

`IndexingProgressStreamTests` (3 cases):
- `progressStreamEmitsOnStageTransition`
- `progressStreamEmitsCompleteOnFinish`
- `progressStreamDocsPerSecIsRollingAverage`

---

## Session 52 — UI Obstruction Audit & Fixes

### Goal

Systematically identify and fix cases where composed SwiftUI views obstruct each other:
tab bars covering content, safe-area insets not applied, overlapping toolbars,
breadcrumb bar covering list rows, floating banners blocking interactive elements.

### Audit Scope

Every view with a persistent on-screen element (tab bar, navigation bar, breadcrumb
bar, indexing banner from Session 51, search bar) must be verified against:

| Check | Pass criterion |
|-------|---------------|
| Content inset respects tab bar height | Last list row scrolls fully above tab bar |
| Content inset respects breadcrumb bar | First list row not hidden behind breadcrumb |
| Toolbar items not clipped | All items fully visible at Dynamic Type XXL |
| Sheets scroll to avoid keyboard | Text fields not covered when keyboard appears |
| macOS toolbar not duplicated | No double toolbars from nested NavigationStack |
| Safe-area bottom on notched devices | Scroll views stop above home indicator |

Known issues going in (from prior inspection):
- `BrowserView.levelView` injects `BrowserBreadcrumbBar` via `.safeAreaInset(edge: .top)`;
  if the breadcrumb bar is now multi-line (Session 50), the inset height must be dynamic
  not fixed — verify `.safeAreaInset` respects the view's natural height.
- `MainTabView` + `BrowserTabView` double-nesting: confirm no doubled navigation bar
  on iOS.
- `ActivityTabView` wrapping `ProjectContextView`: the inner view's toolbar must not
  conflict with the tab bar's own safe area.

### Key Changes

Where obstructions are found, fixes applied in priority order:
1. `.safeAreaInset` with dynamic height measurement
2. `.ignoresSafeArea` removed from any view that should not span the safe area
3. `.contentMargins` / `.scrollContentBackground` corrections
4. Explicit `.padding(.bottom)` as last resort

All changes guarded to the platform where the obstruction exists.

### Tests

`UIObstructionTests` (UI test suite, `FRUSExplorerUITests`):
- `tabBarNotObstructingLastBrowserRow` — scroll to bottom, verify last cell accessible
- `breadcrumbBarNotObstructingFirstRow` — verify first row below breadcrumb is tappable
- `keyboardDoesNotCoverProjectNameField` — tap project name field, verify visible

---

## Session 53 — Pre-Index Feasibility Assessment

### Goal

Produce an architecture document assessing whether a pre-built SQLite index for the
full FRUS corpus can be bundled with the app or offered as a separate download, and
what the recommended approach is.

### Scope of Assessment

**Size estimate**:
- Full corpus XML: 3.3 GB (552 volumes, 694 files)
- FTS5 inverted index for English prose: typically 30–60% of input plain-text size
- Markup overhead in TEI XML: estimated 40–50% of total bytes → ~1.7 GB plain text
- Estimated `frus_documents` FTS5 index: **500 MB – 1 GB**
- `document_cache` table (stored body_text + metadata): estimated **800 MB – 1.5 GB**
- All auxiliary tables (`person_mentions`, `cross_references`, `persons`, `terms`,
  `page_ranges`): estimated **100 – 300 MB**
- **Total `frus.db` for full corpus: estimated 1.4 – 2.8 GB compressed**

**Distribution constraints**:
- iOS OTA app download limit: 200 MB (prompts user before downloading over cellular)
- App Store binary size limit: 4 GB (but user-facing: anything > 200 MB is friction)
- A bundled 1.4–2.8 GB database file inside the app bundle is **not feasible** for App
  Store distribution
- Direct distribution (DMG) has no enforced size limit but would make the initial
  download prohibitively large

**Recommended approach — Hosted Quick-Start Index**:

Offer a server-hosted `frus-index.db` artifact, generated by a CI pipeline using the
same `IndexingPipeline` Swift code compiled as a macOS command-line tool. Available
at a known URL (e.g., `https://frus-explorer.example.com/frus-index-vN.db.gz`).

Onboarding step 2 gains a fourth option:

```
○  Quick Start (Recommended)
   Download the search index only (≈ 600 MB). Search the full corpus
   immediately. Download individual volumes to read documents.
```

This approach:
- Keeps the app bundle small
- Lets users search before downloading any XML
- Degrades gracefully: if index download fails, local indexing still works
- Requires a server-side build pipeline and hosting (separate from app releases)
- The index is read-only from the app's perspective; user data lives in SwiftData

**Schema consideration**: the hosted index must be regenerated whenever
`IndexingPipeline` schema changes (tracked by `user_version` PRAGMA). The app must
check `user_version` after download and refuse to use an incompatible index.

**Partial index shards**: rejected as too complex for the initial implementation.
Full-corpus single file is simpler and feasible at estimated size.

### Output

`Planning/PreIndex-Feasibility.md` — architecture document covering:
- Size estimates with methodology
- Distribution option comparison table
- Recommended Quick-Start index architecture
- Build pipeline sketch (`IndexingPipelineCLI` target)
- Versioning and compatibility strategy
- App Store Review considerations

No code changes in this session — assessment only.

---

## Files Changed Summary

| File | S48 | S49 | S50 | S51 | S52 | S53 |
|------|-----|-----|-----|-----|-----|-----|
| `App/AppState.swift` | — | `corpusDateRange` access; `pendingDownloadScope` | `filterDownloadedOnly`; macOS `showAbout` | `currentIndexingProgress` (iOS) | — | — |
| `App/FRUSExplorerApp.swift` | — | — | macOS About `CommandGroup` | `Task.yield` between indexes | — | — |
| `App/MainTabView.swift` | — | — | — | Indexing viz (option TBD) | Audit | — |
| `Browser/BrowserView.swift` | — | — | Filter toggle; filter persistence | — | Obstruction fixes | — |
| `Browser/BrowserBreadcrumbBar.swift` | — | — | `BreadcrumbFlowLayout`; multi-line | — | Dynamic inset verification | — |
| `Downloads/DownloadManager.swift` | — | `DownloadScope` enum; scope-based queue | — | `Task.yield` hook | — | — |
| `Onboarding/OnboardingView.swift` | — | Three-step redesign | — | — | — | — |
| `Onboarding/DownloadScopePickerView.swift` | — | New | — | — | — | — |
| `Settings/SettingsView.swift` | — | `DownloadManagerSettingsView` row | macOS About row removed | — | — | — |
| `Settings/DownloadManagerSettingsView.swift` | — | New | — | — | — | — |
| `Settings/MacSettingsView.swift` | — | Download Manager row in Volumes pane | About row removed from Advanced | — | — | — |
| `Models/ManifestStore.swift` | — | `corpusDateRange` computed property | — | — | — | — |
| `Indexing/IndexingPipeline.swift` | FTS5 rebuild; schema v3; reindex flag | — | — | Batch commits; memory throttle; progress stream | — | — |
| `App/Info.plist` / `project.yml` | `UIBackgroundModes: remote-notification` | — | — | — | — | — |
| `FRUSExplorerTests/IndexingPipelineTests.swift` | FTS5 rebuild tests | Onboarding flow tests | Browser filter tests | Throttle + stream tests | UI obstruction tests | — |
| `Planning/PreIndex-Feasibility.md` | — | — | — | — | — | New |

---

## Manifest Data Notes (from pre-session run)

- `manifest.json` regenerated 2026-05-17: **552 volumes, 0 errors**
- `dateRange` field in manifest schema is always `{}` (GitHub XML headers do not carry
  a parseable date range; field retained for future use)
- Corpus year bounds derivable from `subseries` leading year: **1861–1992**
- `documentCount` field is `0` for all volumes (not populated by `ManifestGenerator`
  without parsing full XML; tracked as future enhancement)
