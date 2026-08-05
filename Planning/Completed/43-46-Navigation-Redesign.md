# Sessions 43–46 — Navigation Redesign

**Version**: 1.0
**Date**: 2026-05-16
**Planning document**: `43-46-Navigation-Redesign-Plan.md` (external, v2.0, provided before sessions began)

This block implements the full cross-platform navigation redesign:
- **iOS/iPadOS (iPhone)**: five-tab `TabView` replacing the single `NavigationStack`-with-sheets pattern
- **macOS**: `Settings` scene replacing the sheet, keyboard shortcuts for Search and Citation Lookup, Collections toolbar button

Sessions 43–45 are platform-agnostic where possible. Session 46 covers macOS-specific changes. All four sessions must be completed in order; 45 and 46 may be worked concurrently after 44.

---

## Session Sequence

| # | Task | Key Output | Depends On |
|---|---|---|---|
| 43 | Shared navigation state and iOS tab shell | `AppTab` enum; navigation properties on `AppState`; `MainTabView` shell; `ContentView` routing | 01, 11 |
| 44 | Full wiring on all platforms | iOS tabs wired; sheets removed from iOS `BrowserView`; Done buttons guarded; reset flow simplified; `onCrossRefTap` cross-platform | 43, 15, 16, 24 |
| 45 | Tab bar polish and two-platform audit | Tab icons; badge counts; `lastActivityTabVisit`; `unindexedVolumeCount`; full build audit | 44, 27 |
| 46 | macOS Settings scene, toolbar, shortcuts | `Settings` scene; `MacSettingsView` (`TabView`); ⌘F / ⌘⇧F commands; Collections toolbar button | 44 |

---

## Session 43 — Shared Navigation State and iOS Tab Shell

### Goal

Introduce all navigation-related properties to `AppState`, create `MainTabView` as the iOS root shell (five tabs with placeholder content), and confirm `ContentView` routing on both platforms. No visible UI change on macOS.

### Key Changes

**`AppState`**:
- `AppTab` enum (iOS-guarded): `.browse`, `.search`, `.activity`, `.collections`, `.settings`; `rawValue` persisted to `UserDefaults("frus.activeTab")`
- `activeTab: AppTab` (iOS-guarded); `pendingBrowseDocument: DocumentBrowserEntry?`; `showSearch: Bool`; `showCitationLookup: Bool`
- `showSettingsSheet` and `pendingOnboardingAfterReset` retained unchanged (removed in Sessions 44 and 46 respectively)

**`ContentView`** — routes iOS to `MainTabView`, macOS to `BrowserView` unchanged.

**`MainTabView`** (new, iOS-only) — five-tab `TabView(selection: $appState.activeTab)` using the iOS 18+ `Tab(_, systemImage:, value:)` API; Browse wraps `BrowserView` via `BrowserTabView`; remaining four tabs show `ContentUnavailableView` stubs pending Session 44.

**`BrowserView`** — `showSearch` and `showCitationLookup` promoted from local `@State` to `appState` properties; toolbar buttons updated.

### Tests

`AppTabTests` (iOS-guarded, 3 cases) and `NavigationStateTests` (3 cases) added to `AppStateTests.swift`.

---

## Session 44 — Full Wiring on All Platforms

### Goal

Wire all five iOS tabs with real content. Remove Search, Settings, and Citation Lookup sheets from iOS `BrowserView`. Remove Done dismiss buttons from iOS paths of `SearchView`, `ProjectContextView`, `GlobalContextView`, and `SettingsView`. Simplify the reset flow on iOS (direct assignment). Wire `onCrossRefTap` in `DocumentView` for both platforms.

### Key Changes

**`MainTabView`** — four placeholder tabs replaced with `SearchTabView`, `ActivityTabView`, `CollectionListView`, `SettingsView`. `SearchTabView` adds a Citation Lookup toolbar button and local sheet. `ActivityTabView` wraps `ProjectContextView`.

**`AppState`** — `showSettingsSheet` and `pendingOnboardingAfterReset` guarded to `#if os(macOS)`.

**`BrowserView`** — iOS `stackLayout` retains only the `ProjectPickerMenu` toolbar button; Search/CitationLookup/Settings sheets guarded to macOS; `ProjectPickerMenu` closure switches to `.activity` tab on iOS; `pendingBrowseDocument` `.onChange` observer added to both platforms.

**`SearchView`, `ProjectContextView`, `GlobalContextView`, `SettingsView`** — `@Environment(\.dismiss)` and Done `ToolbarItem` guarded to `#if !os(iOS)`.

**`ProjectContextView`** — `GlobalContextView` presented as `NavigationLink` on iOS, sheet on macOS; `showGlobalContext` and its sheet guarded to `#if !os(iOS)`.

**`ResetView.performReset`** — iOS path: `appState.hasCompletedOnboarding = false` directly. macOS path: retains `pendingOnboardingAfterReset` / `showSettingsSheet` two-phase dismissal until Session 46.

**`DocumentView.handleCrossRefTap`** — cross-platform: sets `activeTab = .browse` on iOS then `appState.pendingBrowseDocument`; sets `pendingBrowseDocument` only on macOS; falls back to cross-reference graph if target volume is not downloaded.

### Tests

`MainTabViewTests.swift` (new): `MainTabViewTests` (6 cases, iOS-guarded where needed) + `ResetFlowTests` (2 platform-guarded cases).

---

## Session 45 — Tab Bar Polish and Two-Platform Audit

### Goal

Final iOS tab-bar polish: badge counts, persistence, accessibility. Full two-platform build audit verifying all conditions from the Sessions 43–44 audit table.

### Key Changes

**`AppState`** (iOS-guarded additions):
- `lastActivityTabVisit: Date` — persisted to `UserDefaults("frus.lastActivityTabVisit")`; defaults to `.distantPast`; stamped `.now` in `activeTab.didSet` when `.activity` is selected
- `unindexedVolumeCount: Int` — computed; counts volumes that are downloaded but not present in the search index; uses `try?` to return 0 conservatively on SQLite error

**`MainTabView`** — `@Query private var allNotes: [ResearchNote]`; `newNoteCount` computed as `allNotes.filter { created > lastActivityTabVisit }.count`; `.badge(newNoteCount)` on Activity tab; `.badge(appState.unindexedVolumeCount)` on Settings tab.

**Build audit** — all conditions from Sessions 43–44 verified against both `FRUSExplorer` and `FRUSExplorerMac` targets; both build clean with zero warnings.

### Final Tab Icon Specification

| Tab | `systemImage` |
|---|---|
| Browse | `"books.vertical"` |
| Search | `"magnifyingglass"` |
| Activity | `"person.crop.rectangle.stack"` |
| Collections | `"tray.2"` |
| Settings | `"gear"` |

### Tests

`TabBarAccessibilityTests` (3 cases) added to `AccessibilityTests.swift`. `MainTabViewTests` extended with `activeTabPersistenceRoundTrip` and `lastActivityTabVisitUpdatesOnActivityTabSelect`.

---

## Session 46 — macOS Settings Scene, Toolbar, and Shortcuts

### Goal

Convert macOS Settings from a toolbar-button sheet to a native `Settings` scene with a `TabView` interior. Add ⌘F and ⌘⇧F keyboard shortcuts. Add a Collections toolbar button. Simplify the macOS reset flow to match iOS.

### Key Changes

**`FRUSExplorerApp`** — `body` restructured into `private var mainWindowScene: some Scene` (the `WindowGroup` + macOS `.commands` and `.defaultSize` modifiers) plus a top-level `#if os(macOS) Settings { MacSettingsView() } #endif` sibling (required by `SceneBuilder` — a `Settings` scene cannot be nested inside a modifier-applying `#if` block).

`CommandGroup(after: .textEditing)` adds ⌘F (Search) and ⌘⇧F (Citation Lookup) menu items that write `appState.showSearch` / `appState.showCitationLookup`.

**`SettingsView.swift`** (macOS additions, guarded by `#if os(macOS)`):
- `MacSettingsView` — `TabView` with four tabs (Volumes, Research, Integrations, Advanced) at `560×480` fixed frame; presented by the system `Settings` scene (⌘, and App menu > Settings)
- `VolumesSettingsPane` — `NavigationStack + Form` with four `NavigationLink` rows (Volume Management, Storage, Sideload, Reindex)
- `ResearchSettingsPane` — User Tags, Summarization Prompts
- `AdvancedSettingsPane` — Reset App, About FRUS Explorer

**`ResetView.performReset`** — simplified on both platforms to `appState.hasCompletedOnboarding = false` directly. `pendingOnboardingAfterReset` and `showSettingsSheet` removed from `AppState` entirely.

**`AppState`** (v2.3) — `showSettingsSheet` and `pendingOnboardingAfterReset` removed.

**`BrowserView`** — Settings sheet, `onChange` fallback, and gear toolbar button removed; `@State private var showCollections = false` (macOS-guarded) added; Collections `.sheet(isPresented: $showCollections)` and `tray.2` toolbar button replace the Settings gear.

### Architecture Note: SceneBuilder Constraint

The `Settings { }` scene is a `SceneBuilder` sibling of `WindowGroup`, not a modifier on it. Attempting to nest `Settings { }` inside a `#if os(macOS)` block that applies `.commands` / `.defaultSize` to the `WindowGroup` produces an `unexpected tokens in '#if' expression body` compile error. The fix is to compose scenes at the top level of `body`.

### Tests

`MainTabViewTests.resetFlowMacOS` updated to verify direct assignment (removed stale `pendingOnboardingAfterReset` reference). New `MacSettingsViewTests.swift` (macOS-guarded, 3 cases): smoke instantiation, Volumes pane row label count, direct-assignment reset behavior.

---

## AppState Version History After This Block

| Version | Session | Change |
|---|---|---|
| 2.0 | 43 | `AppTab` enum; `activeTab`; `pendingBrowseDocument`; `showSearch`; `showCitationLookup` promoted from `BrowserView` |
| 2.1 | 44 | `showSettingsSheet` and `pendingOnboardingAfterReset` guarded to macOS |
| 2.2 | 45 | `lastActivityTabVisit` and `unindexedVolumeCount` (iOS) |
| 2.3 | 46 | `showSettingsSheet` and `pendingOnboardingAfterReset` removed entirely |

---

## Complete Files Changed Summary

| File | S43 | S44 | S45 | S46 |
|---|---|---|---|---|
| `App/AppState.swift` | Add `AppTab`, `activeTab`, `pendingBrowseDocument`, `showSearch`, `showCitationLookup` | Guard `showSettingsSheet`/`pendingOnboardingAfterReset` to macOS | Add `lastActivityTabVisit`, `unindexedVolumeCount` (iOS) | Remove `showSettingsSheet`, `pendingOnboardingAfterReset` entirely |
| `App/ContentView.swift` | iOS → `MainTabView`; macOS → `BrowserView` | — | Audit | — |
| `App/FRUSExplorerApp.swift` | — | — | — | `mainWindowScene` property; `Settings` scene; ⌘F / ⌘⇧F commands |
| `App/MainTabView.swift` | New; Browse + 4× placeholder | All tabs wired | `@Query` badges; `lastActivityTabVisit` stamp in `activeTab.didSet` | — |
| `Browser/BrowserView.swift` | Promote `showSearch`/`showCitationLookup` | iOS: remove sheets/buttons; add `pendingBrowseDocument` observer | Audit | Remove Settings gear; add Collections button and sheet |
| `Search/SearchView.swift` | — | Guard `Done`/`dismiss` to non-iOS | Audit | — |
| `ProjectContext/ProjectContextView.swift` | — | iOS: remove `Done`; `GlobalContextView` as `NavigationLink` | Audit | — |
| `ProjectContext/GlobalContextView.swift` | — | Guard `Done` to non-iOS | Audit | — |
| `Settings/SettingsView.swift` | — | Guard `Done`/`dismiss` to non-iOS; iOS reset simplified | Audit | Add `MacSettingsView`; macOS reset simplified |
| `DocumentView/DocumentView.swift` | — | Wire `handleCrossRefTap` cross-platform | Audit | — |
| `AppStateTests.swift` | `AppTabTests`; `NavigationStateTests` | — | — | — |
| `MainTabViewTests.swift` | — | `MainTabViewTests` + `ResetFlowTests` | Badge + persistence tests | Update `resetFlowMacOS` |
| `MacSettingsViewTests.swift` | — | — | — | New; macOS-guarded |
| `AccessibilityTests.swift` | — | — | `TabBarAccessibilityTests` | — |
