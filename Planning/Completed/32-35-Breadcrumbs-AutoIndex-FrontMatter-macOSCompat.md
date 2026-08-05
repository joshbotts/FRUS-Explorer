# Sessions 32–35 — Breadcrumbs, Auto-index, Front Matter, and macOS Compatibility

**Version**: 1.0
**Date**: 2026-05-16
**Reconstructed from**: git commit history (no pre-session planning documents exist for Sessions 32–35)

These four sessions addressed production-readiness issues and missing features discovered during and after the Session 31 integration testing pass. Sessions 32–34 added distinct features; Session 35 was a multi-commit macOS compatibility sprint that brought both targets to a clean build.

---

## Session 32 — Breadcrumbs, App Reset, App Icon & Subseries Fix

### Goal

Deliver the breadcrumb navigation bar, a correct app reset flow, the initial app icon, and a fix for subseries parsing failures that caused some volumes to be bucketed under the wrong subseries heading.

### Key Outputs

- **`BrowserBreadcrumbBar`** — horizontally scrollable breadcrumb trail injected via `.safeAreaInset(edge: .top)` in `BrowserView.levelView`; tapping a crumb pops to that level; tapping the root "FRUS" crumb clears the entire navigation path
- **App icon** — rasterised from `frus_explorer_icon_v5.svg` into a full `Assets.xcassets` set (iOS 1024 pt universal + macOS 16–1024 pt); wired into both targets in `project.pbxproj`
- **Reset App** — now correctly deletes `Project` records in addition to `ResearchNote`, `UserTag`, `GeneratedSummary`, `ReadingHistoryEntry`, `Collection`, `CollectionEntry`, and `SummarizationPrompt`
- **Post-reset navigation** — `showSettingsSheet` / `pendingOnboardingAfterReset` added to `AppState`; `ResetView` dismisses the Settings sheet first; `BrowserView.onDismiss` sets `hasCompletedOnboarding = false` only after the sheet fully animates out, preventing a SwiftUI race with `ContentView`'s route switch
- **Subseries parsing** — `frusSubseries(from:)` free function replaces the broken `v\d+` regex with `^[\d-]+` so suffixes like `"app"`, `"p1"`, and country names are stripped correctly (e.g. `frus1877app.xml → "1877"`, `frus1863p1.xml → "1863"`); extracted as an internal free function so `ManifestStoreTests` can reach it via `@testable import`

### Files Changed

| File | Change |
|---|---|
| `FRUSExplorer/Browser/BrowserBreadcrumbBar.swift` | New file |
| `FRUSExplorer/Browser/BrowserView.swift` | Inject breadcrumb bar via `safeAreaInset`; add `showProjectContext`/`onDismiss` reset flow |
| `FRUSExplorer/App/AppState.swift` | Add `showSettingsSheet`, `pendingOnboardingAfterReset` |
| `FRUSExplorer/Settings/SettingsView.swift` | `ResetView.performReset` two-phase dismissal; delete `Project` records |
| `FRUSExplorer/Models/ManifestStore.swift` | Extract `frusSubseries(from:)` as package-internal free function |
| `FRUSExplorer/Resources/Assets.xcassets/` | App icon assets for all sizes |
| `FRUSExplorerTests/ManifestStoreTests.swift` | Parameterised tests for all `frusSubseries` cases |

### Tests

- `ManifestStoreTests.SubseriesParsingTests` — parameterised over edge cases (standard volumes, appendix suffixes, part suffixes, country-name suffixes)

---

## Session 33 — Auto-index Volumes Immediately After Download

### Goal

Eliminate the requirement for users to manually trigger reindex after downloading a volume. Index each volume automatically as soon as its download completes, with graceful degradation if indexing fails.

### Key Outputs

- **`DownloadManager.onVolumeDownloaded`** — new optional `@Sendable (String) async -> Void` callback, defaulting to `nil`. Fired from `downloadDidSucceed` via an unstructured `Task` so indexing runs concurrently without blocking the actor or delaying queue processing.
- **`FRUSExplorerApp.bootDownloadManager`** — wires `onVolumeDownloaded` to `IndexingPipeline.indexVolume(_:)`. The pipeline reference is captured once on the `MainActor` before `DownloadManager` is created, so the closure has no main-actor dependency at call time. Errors are suppressed with `try?` — a failed index attempt remains recoverable via Settings → Reindex.

`DownloadManager` retains no direct reference to `IndexingPipeline`; the closure is the only coupling point between the two actors.

### Files Changed

| File | Change |
|---|---|
| `FRUSExplorer/Downloads/DownloadManager.swift` | Add `onVolumeDownloaded` callback parameter; fire after successful download |
| `FRUSExplorer/App/FRUSExplorerApp.swift` | Capture `indexPipeline` and pass as `onVolumeDownloaded` to `DownloadManager` |

---

## Session 34 — Front Matter Browser Support

### Goal

Make preface, introduction, and errata sections readable in the Browser even though they are not structured as numbered `<div type="document">` children. These "front matter" sections previously appeared as chapter entries in `CompilationView` but dead-ended with "No documents in this section."

### Key Outputs

- **`FRUSDocumentParser.TEIParserDelegate`** — structural-section fallback in `didEndElement` captures any `<div xml:id="{targetId}">` as a quasi-document when called from `parseDocument(documentId:)`. Parsing aborts immediately after the matching div closes, keeping the targeted parse fast.
- **`CompilationView.canReadSectionDirectly`** — computed property that returns `true` when the section is a front-matter type (preface, intro, introduction, errata), has no `allDocumentIds`, has no subsections, and has a non-auto-generated `sectionId`. When true, `readSectionDirectlySection` renders a "Read [Title]" button that creates a synthetic `DocumentBrowserEntry` and pushes `.document` onto the navigation path. The check runs before the `isIndexed` gate so front matter is accessible regardless of FTS index state.

### Files Changed

| File | Change |
|---|---|
| `FRUSExplorer/TEI/FRUSDocumentParser.swift` | Structural-section fallback in `didEndElement`; early-abort after matching div closes |
| `FRUSExplorer/Browser/CompilationView.swift` | `canReadSectionDirectly`; `readSectionDirectlySection`; "Read" button navigation |

---

## Session 35 — macOS Compatibility (Four-Part Sprint)

### Goal

Bring the macOS (`FRUSExplorerMac`) target to a clean build. Four commits addressed distinct compatibility layers.

### Session 35 — `CollectionListView` and `CollectionEditorView`

- **`CollectionListView`**: replaced iOS-only `.insetGrouped` list style with a conditional `.listStyle(.insetGrouped)` on iOS / `.listStyle(.inset)` on macOS fallback
- **`CollectionEditorView`**: guarded `.navigationBarTitleDisplayMode(.inline)` across all three `NavigationStack` bodies; guarded `EditButton()` with `#if os(iOS)` (on macOS, drag handles and Delete key handle editing without explicit edit mode)
- **`ExportSheetView`**: replaced the dead-end `Text(url.lastPathComponent)` macOS stub with `MacExportCompleteView`, which offers "Reveal in Finder" (`NSWorkspace.activateFileViewerSelecting`) and "Save To…" (`NSSavePanel`) so exported files are actually reachable on macOS

### Session 35b — Remaining iOS-only SwiftUI Modifier Guards

Guarded iOS-only modifiers that caused compile errors on macOS:
- `CitationLookupView`: `.navigationBarTitleDisplayMode(.inline)`, `.textInputAutocapitalization(.never)` / `.characters`, two `.keyboardType(.numberPad)` calls
- `BackgroundSummarizationSettingsView`: `.textInputAutocapitalization(.never)`, two `.keyboardType(.numbersAndPunctuation)` calls
- `PromptsListView`: `.navigationBarTitleDisplayMode(.inline)`
- `SourceExplorerView`: `.navigationBarTitleDisplayMode(.inline)`

### Session 35c — Fix Blank Settings Sub-Views on macOS

The `SettingsView` `NavigationStack` lacked stable dimensions on macOS, causing `NavigationLink` destinations (which inherit their container's size) to render at intrinsic content size — blank for views like `ResetView` and `ReindexView` that have minimal content.

Two-part fix:
1. `SettingsView` `NavigationStack`: add `.frame(minWidth: 500, minHeight: 440)` on macOS
2. All eight `Form`-based sub-views (`VolumeManagementView`, `StorageManagementView`, `SideloadView`, `ReindexView`, `UserTagsView`, `SummarizationPromptsSettingsView`, `NARAKeyView`, `ResetView`): add `#if os(macOS) .frame(maxWidth: .infinity, maxHeight: .infinity) #endif`

### Session 35d — Subject Tag Bundle Assets and macOS Reset Fix

- **Bundle assets**: committed `taxonomy.json` (683 curated subjects, 59 KB) and `subject-appearances.json` (86,539 document-level assignments, 8.7 MB; covers 405 of 683 subjects; subjects appearing in more than 150 volumes omitted as too broad for document-level discovery). Generated by `frus-subject-taxonomy/scripts/export_app_bundle.py --max-volumes 150`.
- **macOS onboarding reset**: added `onChange(of: appState.showSettingsSheet)` fallback in `BrowserView` that ensures `handleSettingsSheetDismiss()` fires even when SwiftUI skips the `onDismiss` closure on programmatic sheet dismissal (a known macOS SwiftUI limitation with `.sheet(isPresented:onDismiss:)`).

### Files Changed (Session 35, all parts)

| File | Change |
|---|---|
| `FRUSExplorer/Collections/CollectionListView.swift` | `.inset` list style on macOS |
| `FRUSExplorer/Collections/CollectionEditorView.swift` | iOS modifier guards; `EditButton` guard; `MacExportCompleteView` |
| `FRUSExplorer/Citation/CitationLookupView.swift` | iOS modifier guards |
| `FRUSExplorer/SourceExplorer/SourceExplorerView.swift` | iOS modifier guard |
| `FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift` | iOS modifier guards |
| `FRUSExplorer/Summarization/PromptsListView.swift` | iOS modifier guard |
| `FRUSExplorer/Settings/SettingsView.swift` | Frame constraints on `NavigationStack` and all eight sub-views |
| `FRUSExplorer/Browser/BrowserView.swift` | `onChange` macOS fallback for settings sheet dismiss |
| `FRUSExplorer/Models/Tags/SubjectTagStore.swift` | Doc comments with asset provenance and filter rationale |
| `FRUSExplorer/Resources/taxonomy.json` | 683-subject curated taxonomy |
| `FRUSExplorer/Resources/subject-appearances.json` | 86,539 document-level subject assignments |
