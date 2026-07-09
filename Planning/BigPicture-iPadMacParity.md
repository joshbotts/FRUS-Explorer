// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

# iPad / Mac Interface Parity and Stage Manager

**Status:** Partially implemented — see Implementation Status below  
**Priority:** Medium (medium-term backlog)  
**Estimated effort:** 4–8 sessions (depending on scope chosen)

---

## Implementation Status (updated 2026-06-11, Session 159)

The phase plan below was written before several phases were quietly delivered by
other sessions. Actual state:

| Phase | Plan estimate | **Actual state** |
|---|---|---|
| 1 — iPad sidebar root | 1–2 sessions | **Done (Session 159)** — realized via `.tabViewStyle(.sidebarAdaptable)` on the existing `MainTabView` `TabView`, *not* a custom `iPadRootView` (see below) |
| 2 — Inspector panel | 1 session | **Done (Session 110)** — `DocumentView` uses `.inspector(isPresented:)` on iPad |
| 3 — Tools in detail pane | 1 session | **Satisfied under `.sidebarAdaptable` (Session 159)** — Person Index is a `BrowserView` destination; Analytics, Source Explorer, and Cross-Reference Graph work as sheets on iPad (the "Source Explorer no visible action" bug is already fixed). The detail-pane-vs-sheet premise was tied to the superseded `iPadRootView`; no refactor needed |
| 4 — iOS settings indexing controls | 0.5 session | **Done** — `StorageManagementView` has "Index Remaining" + "Delete Index & Rebuild" mirroring macOS |
| 5 — Stage Manager multi-window | 1–2 sessions | **Mostly done** — Session 108 added `UIApplicationSupportsMultipleScenes`, `WindowGroup(for: DocumentWindowID.self)`, Source Explorer window. Session 159: fixed the "Open in New Window" gate (`supportsMultipleWindows`); added the Cross-Reference Graph iOS window + wired both tool buttons to open windows (sheet fallback); fixed `DocumentWindowID` dedup; search results open documents in windows alongside the list. **iPad has no system window-tabbing API** (macOS/Safari only) so iPad uses separate Stage Manager windows. **macOS native window tabbing done** (Session 159 Phase 2): `MacDocumentWindowView` + a macOS document `WindowGroup(for: DocumentWindowID.self)` + "Open in New Window" in `ResearchStripView` → the system provides native tabs / "Merge All Windows" |

**Why `.sidebarAdaptable` instead of a custom `iPadRootView` (Session 159):**
`BrowserView` (`splitLayout`) and `ResearchView` already use their own
`NavigationSplitView` on iPad. Wrapping the five sections in an *outer*
`NavigationSplitView` (the original Phase 1 design) would nest split-in-split,
the SwiftUI anti-pattern. The deployment target is iOS 26 and `MainTabView`
already uses the iOS 18 value-based `Tab(...)` API, so adding
`.tabViewStyle(.sidebarAdaptable)` makes iPad render the tabs as a native
adaptive sidebar (persistent in landscape, top bar in portrait) while iPhone
keeps its bottom tab bar — and each section keeps its own internal navigation
as the sidebar's detail content. One reversible modifier, no new files, no
nested split. The `iPadRootView`/`NavigationSplitView` design in Phase 1 below
is therefore superseded and kept only for historical context. A future
enhancement could add `TabSection` grouping for sidebar section headers.

**Correction (Session 1 / #238):** the claim above that `.sidebarAdaptable`
introduces "no nested split" was wrong. A tab that *itself* hosts a
`NavigationSplitView` (`BrowserView.splitLayout`, `ResearchView`) still nests a
split view under the adaptable TabView — and in the collapsed *floating top
tab-bar* representation (which Session 159 never exercised — it verified only
the leading-sidebar representation) the nested detail column mis-computes its
top safe area and overlays content that cannot be scrolled into view. The fix:
`BrowserView` now uses a `NavigationStack` (its `stackLayout`) on iPad too, so
the subseries list becomes the stack root and the TabView's adaptive sidebar is
the only rail. **Guard rule going forward: a tab under `.sidebarAdaptable`
hosts a `NavigationStack`, not a `NavigationSplitView`.** `ResearchView` and
`SettingsView` still nest splits and are tracked as a follow-up issue (verify
reproduction, then flatten the same way).

---

## Problem Statement

The current platform split is:
- **iPhone / iPad:** `MainTabView` — five-tab navigation (Browse, Search, Activity, Collections, Settings)
- **macOS:** `MainWindowView` — sidebar navigation with five dedicated window scenes (Search, Browser, CrossReference, SourceExplorer, Collections) and a Research Strip

An iPad in landscape with a keyboard and Magic Trackpad has the same ergonomic profile as a Mac laptop — researchers expect a layout closer to macOS, not the phone-style tab bar. Specific gaps identified in testing:

(Table as originally assessed; ✅/❌ in the "iPad (current)" column reflect the
pre-Session-159 state. See Implementation Status above for what has since shipped —
e.g. Sidebar navigation and Settings: Index Remaining are now ✅ on iPad.)

| Feature | macOS | iPhone | iPad (current) |
|---|---|---|---|
| Sidebar navigation | ✅ | ❌ (tab bar) | ✅ (`.sidebarAdaptable`, Session 159) |
| Always-visible Research Strip | ✅ | ❌ | ❌ |
| Multi-window (Stage Manager) | ✅ | ❌ | Partial (broken Source Explorer) |
| Inspector/research panel | ✅ | ❌ | `.inspector` ✅ (Session 110) |
| Settings: Index Remaining | ✅ | ✅ | ✅ (`StorageManagementView`) |
| Keyboard shortcuts | ✅ | N/A | Partial |
| Hover states / tooltips | ✅ | N/A | ✅ (pointer) |

---

## Design Principles

1. **iPhone stays on `MainTabView`.** Phone users benefit from familiar tab navigation; the tab bar is not a deficit on a 6" screen.
2. **iPad gets a sidebar.** *(Superseded — Session 159.)* Originally specified as a custom `iPadRootView` using `NavigationSplitView`; realized instead via `.tabViewStyle(.sidebarAdaptable)` on the shared `MainTabView`, which avoids nesting split-in-split with `BrowserView`/`ResearchView`. See Implementation Status.
3. **Maximize shared code.** `BrowserView`, `DocumentView`, `SearchView`, `CrossReferenceGraphView`, and all sheet/inspector content are shared across iPhone, iPad, and macOS unchanged.
4. **No separate iPad target.** Conditional compilation (`#if os(iOS) && targetEnvironment(macCatalyst)` / `@available`) handles differences within the shared iOS target.
5. **Stage Manager is opt-in-bonus.** The primary goal is a good non-Stage-Manager iPad experience. Stage Manager multi-window is a follow-on enhancement.

---

## Proposed Architecture

### New `iPadRootView` (iPad-only, iPadOS 17+)

```
iPadRootView
├── NavigationSplitView
│   ├── Sidebar (NavigationStack)
│   │   ├── Browse (section header)
│   │   │   ├── BrowserView (volume list)
│   │   │   └── Collections
│   │   ├── Tools (section header)
│   │   │   ├── Search
│   │   │   ├── Person Index
│   │   │   ├── Corpus Analytics
│   │   │   └── Source Explorer
│   │   └── Settings (section header)
│   │       └── SettingsView
│   └── Detail (NavigationStack)
│       └── [selected document or view]
└── Inspector (isPresented when document open)
    └── Research Panel (notes, tags, highlights)
```

Routing in `ContentView.swift`:
```swift
if appState.hasCompletedOnboarding && (hasVolumes || hasActiveDownloads) {
    #if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .pad {
        iPadRootView()
    } else {
        MainTabView()
    }
    #else
    MainWindowView()
    #endif
} else {
    OnboardingView()
}
```

---

## Implementation Plan

### Phase 1 — iPad Root View Scaffold (1–2 sessions)

**Goal:** iPad shows `NavigationSplitView` with the existing `BrowserView` as the primary content. Tab bar is gone. Sidebar shows volume navigation.

Tasks:
- Create `FRUSExplorer/App/iPadRootView.swift` (iOS-only, `UIDevice.current.userInterfaceIdiom == .pad` gated in `ContentView`)
- `NavigationSplitView(sidebar:detail:)` layout
- Sidebar: `List` with `NavigationLink` rows for Browse, Search, Activity, Collections, Settings
- Detail: `NavigationStack` driven by `AppState.navigationPath` (same path already used by `MainWindowView`)
- Indexing banner: `.safeAreaInset(edge: .bottom)` identical to current `MainTabView` position
- Persist selected sidebar item in `AppState` so it survives app restarts

**Acceptance criteria:**
- iPad launches to sidebar view instead of tab bar
- Browse opens `BrowserView` in the detail pane
- Document navigation works (tapping a document pushes `DocumentView` onto the detail stack)
- Indexing banner appears above the home indicator

---

### Phase 2 — Inspector Panel (1 session)

**Goal:** iPad document view gains the `.inspector` panel (research notes + tags) that macOS already has.

Tasks:
- In `DocumentView.swift`, enable `.inspector(isPresented: $showNotesPanel)` for iPad (`UIDevice.current.userInterfaceIdiom == .pad`) using the same `ResearchPanelView` already used on macOS
- Move the "Notes panel" toggle from `.topBarLeading` (current iPad toolbar placement) to `.primaryAction` placement (right side, mirroring macOS)
- The existing `.inspector` modifier already works on iPadOS 17+ with the same API as macOS

**Acceptance criteria:**
- "Notes" toolbar button on iPad opens the research panel as a side inspector (not a full-screen sheet)
- Panel shows notes, tags, and highlights for the current document
- Adding a note from the panel works

---

### Phase 3 — Search, Analytics, and Corpus Tools in Detail Pane (1 session)

**Goal:** Search, Corpus Analytics, Person Index, and Source Explorer open in the detail pane on iPad (not as modal sheets), matching the macOS window approach.

Tasks:
- Sidebar rows for Search, Corpus Analytics, Source Explorer each push a `NavigationLink` destination into the detail pane
- `SearchView` already works in a `NavigationStack` detail pane (it's a self-contained view)
- `AnalyticsView` similarly self-contained
- `SourceExplorerView` — on iPad, open in the detail pane (not a sheet); this fixes the "no visible action" Source Explorer bug at the same time
- `CrossReferenceGraphView` — on iPad, open as a `.sheet` with `.presentationDetents([.medium, .large])` (already done in a prior session) OR push into the detail pane

**Acceptance criteria:**
- Tapping "Search" in the iPad sidebar opens `SearchView` in the detail pane
- Tapping "Source Explorer" in the sidebar opens `SourceExplorerView` in the detail pane
- Search and analytics handoffs from other views use `AppState.pendingSearch` / `AppState.pendingAnalytics` to navigate the sidebar + detail, not `openWindow(id:)`

---

### Phase 4 — iOS Settings Indexing Controls Parity (0.5 sessions)

**Goal:** iOS Settings → Storage & Index has the same indexing controls as macOS.

Gap items to add to `StorageManagementView`:
- **"Index Remaining" button** — calls `DownloadManager.indexRemainingVolumes()` to queue all downloaded-but-unindexed volumes; mirrors macOS `indexRemaining()` action
- **"Rebuild Index" button** — wipes and rebuilds the FTS5 index; mirrors macOS "Rebuild Index" in `SettingsStoragePane`
- **Inline progress card** — while indexing is in progress, shows the same `IndexingProgressCard` that macOS displays; on iOS this sits in the Storage settings section

**Acceptance criteria:**
- iOS Settings shows "Index Remaining" and "Rebuild Index" buttons
- Tapping "Index Remaining" queues all unindexed downloaded volumes and starts indexing
- Progress card appears while indexing is in progress

---

### Phase 5 — Stage Manager Multi-Window (1–2 sessions)

**Goal:** iPad Stage Manager users can open document windows side-by-side (mirrors macOS document windows).

Current state: `UIApplicationSupportsMultipleScenes = YES` is set in Info.plist; Stage Manager window creation is gated on `sizeClass == .regular` (incorrectly — see Source Explorer bug fix in this session).

Correct Stage Manager detection:
```swift
// Check for multiple-scene support — reliable Stage Manager proxy on iPad
let supportsMultipleScenes = UIApplication.shared.supportsMultipleScenes
```

Or use SwiftUI's `@Environment(\.supportsMultipleWindows)` (iPadOS 16+):
```swift
@Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
```

Tasks:
- Replace all `sizeClass == .regular` guards around `openWindow(id:)` calls with `supportsMultipleWindows` checks
- "Open in New Window" button in `DocumentView` toolbar: show only when `supportsMultipleWindows && UIDevice.current.userInterfaceIdiom == .pad`
- `WindowGroup` scene for `DocumentWindowID` already registered in `FRUSExplorerApp.swift` — confirm it works on iPad Stage Manager
- `WindowGroup` for Source Explorer: restore the Stage Manager path (currently broken; always-sheet fix in Phase 1 was the safe interim)
- Cross-reference graph in Stage Manager: add `WindowGroup` for `CrossReferenceWindowID` so the graph can open as a dedicated window

**Acceptance criteria:**
- On iPad with Stage Manager active, "Open in New Window" button appears and opens a standalone document window
- Source Explorer opens as a window in Stage Manager; falls back to sheet without Stage Manager
- Cross-reference graph opens as a resizable window in Stage Manager

---

## What NOT to Do

- **Do not create a separate iPadOS target** — doubles build/signing/distribution complexity for minimal gain. Conditional compilation inside the shared iOS target handles everything needed.
- **Do not port the entire macOS window-scene architecture to iPad** — macOS has 5 dedicated window scenes; iPad Stage Manager support is a bonus, not the foundation.
- **Do not use `UIUserInterfaceIdiom.mac` (Catalyst)** — the project is NOT a Catalyst app; it's a native multiplatform app with separate iOS and macOS targets.

---

## Dependency on Prior Work

Phase 1 (iPad sidebar) should land before Phase 5 (Stage Manager), because the sidebar navigation model determines where "open in new window" fits conceptually. Phase 4 (Settings parity) is independent of phases 1–3 and can be done any time.

---

## Testing Criteria

- [ ] iPad in portrait: sidebar collapses to overlay mode (`navigationSplitViewStyle(.balanced)` or `.automatic`)
- [ ] iPad in landscape: sidebar is persistent (visible alongside detail)
- [ ] iPhone: still uses `MainTabView` (no regression)
- [ ] macOS: still uses `MainWindowView` (no regression)
- [ ] Document navigation works end-to-end on iPad sidebar layout
- [ ] Indexing banner appears on iPad in both portrait and landscape
- [ ] Settings → Storage & Index on iPad/iPhone shows "Index Remaining" and "Rebuild Index"
- [ ] Stage Manager (Phase 5 only): document windows open side-by-side
- [ ] Source Explorer opens as sidebar content (no Stage Manager) / window (Stage Manager)
- [ ] Keyboard shortcuts work on iPad with Magic Keyboard (`.keyboardShortcut` modifiers already on macOS views apply on iPad too)

---

## Open Questions

1. Should the iPad sidebar show the Research Strip (always-visible summary of current document metadata, notes count, highlights count) between the sidebar list and the bottom? This is a macOS-only concept currently.
2. Should iPad use `.automatic` (`NavigationSplitViewStyle`) or `.balanced` / `.prominentDetail`? `.automatic` adapts to available space which is usually best.
3. On iPhone 17 Max / Plus (large phones in landscape), should the `iPadRootView` path be taken instead of `MainTabView`? Probably not — `UIDevice.current.userInterfaceIdiom` correctly returns `.phone` on all iPhones.
