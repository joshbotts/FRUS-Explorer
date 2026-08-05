# Sessions 56–62: HIG Compliance — Assessment & Implementation Plan

## Source

Apple Human Interface Guidelines audit conducted in Session 55 planning phase.
All 30 findings (F-001 – F-030) are grouped into seven implementation sessions
by theme, file overlap, and risk level.

---

## Finding Registry

| ID | Platform | Severity | Area | Session |
|---|---|---|---|---|
| F-001 | iOS | High | Settings tab badge — non-actionable count | 56 |
| F-002 | iOS | High | Custom search field instead of `.searchable` | 62 |
| F-003 | iOS | High | DocumentView toolbar overloaded (6–7 items) | 56 |
| F-004 | iOS | Medium | UserTagsView tap-to-rename undiscoverable | 57 |
| F-005 | iOS | Medium | Unlabeled ProgressView in DocumentView bootstrap | 56 |
| F-006 | iOS | Medium | Missing `.presentationDetents` on many iOS sheets | 59 |
| F-007 | iOS | Low | Fixed-size icons not capped for Dynamic Type | 58 |
| F-008 | iOS | High | BrowserBreadcrumbBar touch targets < 44 pt | 56 |
| F-009 | iOS | Medium | Onboarding requires project name to proceed | 57 |
| F-010 | iOS | High | Volume delete has no confirmation | 57 |
| F-011 | iOS | Low | SettingsView root uses `.inline` title mode | 56 |
| F-012 | iOS | Low | Hardcoded `Color.white` in tag chip foreground | 58 |
| F-013 | macOS | High | Search/Collections presented as full modal sheets | 60 |
| F-014 | macOS | Medium | About presented as sheet, not Window scene | 61 |
| F-015 | macOS | Low | Integrations + Advanced tabs could be merged | 61 |
| F-016 | macOS | Low | Inconsistent layout pattern across settings panes | 61 |
| F-017 | macOS | Low | Toolbar items ungrouped on macOS | 60 |
| F-018 | macOS | High | Graph nodes not keyboard-focusable | 61 |
| F-019 | macOS | Low | About Done button (already addressed in Session 55) | N/A |
| F-020 | Both | Low | Empty states missing calls to action | 58 |
| F-021 | Both | Medium | Reading history shows raw IDs not display titles | 58 |
| F-022 | Both | Medium | Accessibility labels use non-localized interpolation | 58 |
| F-023 | Both | Low | Hardcoded colors for confidence indicators | 58 |
| F-024 | Both | Medium | Multiple `.sheet` modifiers on DocumentView | 59 |
| F-025 | Both | Low | Layout shift during inline loading in VolumeView | 58 |
| F-026 | Both | Medium | `accessibilityHint` used for long descriptive text | 58 |
| F-027 | Both | Low | Two `.borderedProminent` buttons in CompilationView | 56 |
| F-028 | Both | Low | Redundant `.accessibilityAddTraits(.isButton)` | 58 |
| F-029 | Both | Low | `.lineLimit(1)` truncates at accessibility text sizes | 58 |
| F-030 | iOS | Medium | Settings occupies a dedicated tab (low-frequency nav) | 57 |

---

## Session 56 — iOS Toolbar, Interaction Patterns & Title Hierarchy

**Scope:** Purely iOS-side interactive refinements that touch display and tap mechanics.
None of these changes touch model, data, or navigation architecture.

### Findings addressed
| ID | Fix |
|---|---|
| F-003 | Collapse 6–7 DocumentView toolbar icons into ≤ 3 direct buttons + one overflow `Menu` |
| F-008 | Expand BrowserBreadcrumbBar tap targets to 44 pt minimum |
| F-005 | Label the bootstrap `ProgressView()` in DocumentView |
| F-011 | Change SettingsView root from `.inline` to `.large` title display mode |
| F-027 | Demote "Index Now" button in CompilationView from `.borderedProminent` to `.bordered` |
| F-001 | Remove (or boolean-cap) the unindexed-volume badge on the Settings tab |

### Files
- `DocumentView/DocumentView.swift` — toolbar consolidation + bootstrap spinner label
- `Browser/BrowserBreadcrumbBar.swift` — touch target fix
- `Browser/CompilationView.swift` — button style demotion
- `App/MainTabView.swift` — badge change
- `Settings/SettingsView.swift` — root title mode (iOS only)

### Toolbar design (F-003)

**Current:** `ToolbarItemGroup(.primaryAction)` contains Add Note, Tag Document, a Citation
`Menu`, Source Explorer (conditional), Cross-References, and Summarize (conditional) —
up to 7 items.

**Target:** Exactly 3 direct buttons + 1 overflow Menu button:
1. Add Note (keep — most frequent)
2. Tag Document (keep — frequent, fast single-tap)
3. "···" More `Menu` containing: Citation, Source Explorer (conditional), Cross-References,
   Summarize (conditional)

The existing `Menu { Button("Copy Chicago…"); Button("Copy Footnote…"); … }` for citation
can be embedded directly inside the More menu as a sub-menu.

### Touch targets (F-008)

`BrowserBreadcrumbBar.crumbButton` currently renders buttons with `.font(.caption)` and
`.buttonStyle(.plain)` which produces a ~13 pt tap area. Fix:

```swift
.padding(.vertical, 14)          // expands hit area to ≥ 44 pt
.contentShape(Rectangle())       // ensures the padding zone is tappable
```

### Tests
- Smoke-build both iOS and macOS; no new unit tests needed (all UI layout changes).
- VoiceOver smoke: confirm "More" menu items are reachable.

---

## Session 57 — Behavioral Guards & Onboarding Friction

**Scope:** Confirmations for destructive actions, onboarding skip path, settings badge,
tag editing discoverability, and Settings tab navigation approach.

### Findings addressed
| ID | Fix |
|---|---|
| F-010 | Add `.confirmationDialog` or swipe `.destructive` role before volume delete |
| F-009 | Make project name optional in onboarding; add a visible Skip path |
| F-004 | Add a swipe action "Edit" (alongside existing Delete) in UserTagsView |
| F-030 | Evaluate Settings tab — convert entry point to toolbar gear icon in Browse |

### Files
- `Settings/SettingsView.swift` — volume delete guard (`VolumeManagementView.downloadedVolumesSection`)
- `Onboarding/OnboardingProjectSetupView.swift` — Skip button, validation relaxation
- `Settings/SettingsView.swift` — UserTagsView swipe action

### Volume delete (F-010)

Replace the inline red `Button("Delete")` per volume row with a swipe action so the
destructive visual treatment is system-provided:

```swift
.swipeActions(edge: .trailing) {
    Button(role: .destructive) {
        deleteVolume(volume)
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

No additional `confirmationDialog` is needed once `.destructive` role is used — the red
tint communicates the action. If deletion is irreversible, add an optional confirmation
dialog on top.

### Onboarding skip (F-009)

`OnboardingProjectSetupView.canProceedFromProjectSetup` gates the primary "Get Started"
button on a non-empty project name. Add a secondary "Skip for now" button (`.bordered`
style) that:
1. Creates a default project named `String(localized: "onboarding.defaultProject", defaultValue: "My Project")`
2. Calls the same proceed action

The research question, date range, and subject tag defaults remain optional (they already
are, but the UX should make this clearer with "Optional" labels in field headers).

### Tag editing discoverability (F-004)

`UserTagsView` uses `.onTapGesture` on rows for editing. Replace with a `.swipeActions`
"Edit" button (leading edge) and keep delete on trailing edge. This matches system patterns
in Reminders, Notes, and Contacts.

### Settings tab (F-030)

Assessment: FRUS Explorer's power users do access Settings frequently (download manager,
re-index). Removing the tab would reduce discoverability. **Decision: retain the Settings
tab but fix the badge (done via F-001 in Session 56).** Document this decision in the
planning doc for future reference.

### Tests
- Verify onboarding flow proceeds with empty project name (skip path).
- Verify volume swipe-to-delete shows red confirmation then removes volume record.

---

## Session 58 — Accessibility & Dynamic Type Compliance

**Scope:** Mechanical accessibility fixes across both platforms. Most changes are 1–5 line
modifications; grouped together to avoid fragmenting small changes across many sessions.

### Findings addressed
| ID | Fix |
|---|---|
| F-022 | Wrap bare interpolation accessibility labels in `String(localized:)` |
| F-026 | Replace `accessibilityHint` long descriptive text with combined `accessibilityLabel` |
| F-028 | Remove redundant `.accessibilityAddTraits(.isButton)` from `Button` elements |
| F-007 | Add `.dynamicTypeSize(...<.accessibility3)` to hero/icon fixed-size elements |
| F-021 | Display `header` field (document title) in ReadingHistoryListView instead of raw ID |
| F-012 | Replace `Color.white` tag chip foreground with `.colorScheme(.dark)` environment |
| F-029 | Remove or raise `.lineLimit(1)` on list rows in VolumeManagementView |
| F-023 | Audit confidence indicator colors against WCAG AA; replace failing swatches |
| F-025 | Add `minHeight` to VolumeView loading section to prevent layout shift |
| F-020 | Add `actions:` CTA to `ContentUnavailableView` in activity list empty states |

### Files (partial list — many small edits)
- `Browser/CorpusView.swift`, `Browser/SubseriesView.swift` — F-022
- `Onboarding/DownloadScopePickerView.swift` — F-026
- `ProjectContext/ProjectContextView.swift`, `GlobalContextView.swift` — F-028, F-020
- `Onboarding/OnboardingIntroView.swift`, `Settings/AboutView.swift` — F-007
- `ProjectContext/ProjectContextView.swift` (ReadingHistoryListView) — F-021
- `Onboarding/OnboardingProjectSetupView.swift` — F-012
- `Settings/SettingsView.swift` (VolumeManagementView) — F-029
- `Citation/CitationLookupView.swift`, `Browser/CompilationView.swift` — F-023
- `Browser/VolumeView.swift` — F-025
- `ProjectContext/ProjectContextView.swift` — F-020

### Reading history display (F-021)

`ReadingHistoryEntry` stores `documentId` and `volumeId`. The model must also store a
`displayTitle: String` captured at read time from `DocumentBrowserEntry.header`. Check if
the SwiftData model already has this field or if a migration is needed:

```swift
// ReadingHistoryEntry — check existing fields
var displayTitle: String?   // add if absent; backfill with volumeId fallback
```

If the field exists but is nil for old records, display `volumeId + " · " + documentId` as
the fallback.

### Dynamic Type cap (F-007)

For the onboarding icon and About icon:
```swift
Image(systemName: "doc.text.magnifyingglass")
    .font(.system(size: 48))
    .dynamicTypeSize(...<.accessibility3)   // prevents > ~96 pt at extreme sizes
```

### Tests
- VoiceOver audit on `DownloadScopePickerView`: confirm label reads combined title+detail.
- Confirm accessibility text size XL does not truncate volume row titles.

---

## Session 59 — iOS Sheet Detents & DocumentView Sheet Architecture

**Scope:** Two related structural changes to how sheets are presented that both reduce
surprise/jank: adding proper detent declarations on iOS sheets, and consolidating
DocumentView's seven independent sheet triggers into a single enum-driven sheet.

### Findings addressed
| ID | Fix |
|---|---|
| F-006 | Add `.presentationDetents` to iOS sheets that fit smaller content |
| F-024 | Replace 7 separate `.sheet` modifiers on DocumentView with enum state |

### Files
- `DocumentView/DocumentView.swift` — enum-based sheet consolidation
- `DocumentView/DocumentView.swift` (PersonDetailSheet, GlossDetailSheet, CitationSheetView) — detents
- `ProjectContext/ProjectContextView.swift` (ProjectEditorView, GlobalContextView) — detents
- `Settings/SettingsView.swift` (MergeTagSheet) — detents
- `Collections/CollectionListView.swift` (CollectionEditorView) — detents

### DocumentView enum sheet (F-024)

Replace the current approach:
```swift
// 7 separate @State booleans / optionals → 7 separate .sheet() modifiers
@State private var showGraph = false
// vm.showCitationSheet, vm.showNoteEditor, vm.showSummarizeSheet, etc.
```

With a single enum:
```swift
enum DocumentSheet: Identifiable {
    case personDetail(PersonEntry)
    case glossDetail(GlossEntry)
    case citation(String)
    case noteEditor
    case crossReferenceGraph
    case summarizePromptPicker
    case sourceExplorer(String)

    var id: String { /* stable string per case */ }
}

@State private var activeSheet: DocumentSheet? = nil
```

Drive all seven former sheet triggers through `activeSheet`, and present via:
```swift
.sheet(item: $activeSheet) { sheet in
    switch sheet {
    case .personDetail(let p): PersonDetailSheet(...)
    // ...
    }
}
```

Move the boolean/optional properties in `DocumentViewModel` that currently drive sheets
(`showCitationSheet`, `showNoteEditor`, `showSummarizeSheet`, `showSourceExplorer`) to
computed setters on `DocumentView` that write to `activeSheet`.

### Detents to add (F-006)

| Sheet | iOS detents |
|---|---|
| PersonDetailSheet | `.medium, .large` |
| GlossDetailSheet | `.medium` (content is small) |
| CitationSheetView | `.medium, .large` |
| MergeTagSheet | `.medium, .large` |
| SummarizationPromptPickerSheet | already has detents ✓ |
| CollectionEditorView | `.large` (content-heavy, skip medium) |
| ProjectEditorView | `.medium, .large` |
| GlobalContextView | `.large` (activity dashboard, full screen appropriate) |

---

## Session 60 — macOS Search & Tool Panel Architecture

**Scope:** The most architecturally significant session. On macOS, Search and Collections
are currently full modal sheets that block the reading surface. Replace with the SwiftUI
`.inspector` pattern (macOS 14+) so the main document remains accessible.

### Findings addressed
| ID | Fix |
|---|---|
| F-013 | Search/Collections/CitationLookup presented as panels, not full-screen sheets |
| F-017 | macOS toolbar item grouping |

### The Inspector Pattern

SwiftUI 5 (macOS 14+) provides `.inspector(isPresented:) { content }` which renders as a
trailing panel attached to the window — non-modal, resizable, does not block content.

**Target architecture on macOS:**

```
BrowserView (NavigationSplitView)
├── Sidebar: subseries list
├── Detail: volume / document content
└── .inspector(isPresented: $showSearch) {
        SearchView(...)             // trailing side panel
    }
    .inspector(isPresented: $showCollections) {
        CollectionListView(...)     // same panel slot (only one open at a time)
    }
```

**Note:** `.inspector` replaces the sheet only on macOS. On iOS the sheet presentation
is retained (`.inspector` on iOS falls back to a sheet, which is the correct behavior).

**CitationLookupView:** Can remain a sheet on macOS (it is a targeted lookup utility, not
a persistent tool) or migrate to inspector. Decision: keep as sheet with the current
`minWidth: 560` added in Session 55.

**About:** Addressed separately in Session 61.

### Toolbar grouping (F-017)

Replace the current flat `ToolbarItem(placement: .primaryAction)` × 4 in BrowserView with
`ToolbarItemGroup` separating navigation-context items from utility items:

```swift
// Group 1: project/context (leftish)
ToolbarItem(placement: .navigation) { ProjectPickerMenu { … } }

// Group 2: search tools (primary action area)
ToolbarItemGroup(placement: .primaryAction) {
    Button("Search", …)           // magnifyingglass
    Button("Citation Lookup", …)  // doc.text.below.ecg
}

// Group 3: view options (supplementary)
ToolbarItem(placement: .secondaryAction) {
    Toggle(isOn: $filterDownloadedOnly) { … }
}
```

On iOS, toolbar placement is platform-specific; use `#if os(macOS)` guard as needed.

### Tests
- Verify Search inspector panel opens/closes without blocking document reading on macOS.
- Verify iOS Search still presents as a sheet.
- Verify inspector state persists when navigating to a document and back.

---

## Session 61 — macOS App Architecture: About Window, Settings Consolidation, Keyboard Navigation

**Scope:** macOS-only fixes to app-level architecture (About as a proper Window), Settings
cleanup, and keyboard navigation for the graph view.

### Findings addressed
| ID | Fix |
|---|---|
| F-014 | Present About as a `Window` scene, not a modal sheet |
| F-015 | Merge Integrations and Advanced into a single "Advanced" pane |
| F-016 | Consistent `NavigationSplitView` layout across all settings panes |
| F-018 | CrossReferenceGraphView node keyboard accessibility |

### About as Window (F-014)

In `FRUSExplorerApp.swift`:

```swift
// Add alongside existing WindowGroup and Settings scenes
#if os(macOS)
Window(String(localized: "about.window.title", defaultValue: "About FRUS Explorer"),
       id: "about") {
    AboutView()
        .frame(width: 480, height: 460)       // fixed size — About doesn't need to resize
}
.windowResizability(.contentSize)              // fixed to content; no resize handle
#endif
```

In `CommandGroup(replacing: .appInfo)`:
```swift
Button("About FRUS Explorer") {
    openWindow(id: "about")      // requires @Environment(\.openWindow) in App body
}
```

Remove `appState.showAbout` property and the sheet presentation from `BrowserView`.
Remove the `NavigationStack` + Done button wrapper added to `AboutView` in Session 55
(no longer needed once it's a `Window`).

### Settings consolidation (F-015 + F-016)

Merge current 4 tabs (Volumes, Research, Integrations, Advanced) into 3 tabs:
- **Volumes** — unchanged NavigationSplitView
- **Research** — unchanged NavigationSplitView
- **Advanced** — new `NavigationSplitView` with two sidebar items:
  - "Integrations" → `NARAKeyView()`
  - "Reset App" → `ResetView()`

This eliminates the currently inconsistent single-content-pane Integrations and Advanced
tabs and makes all three panes uniformly `NavigationSplitView`.

### Graph keyboard accessibility (F-018)

`CrossReferenceGraphView` renders nodes as `Circle()` views with `.onTapGesture`. To add
keyboard focus:

```swift
// In the node hit-area view:
Button {
    vm.selectNode(node)
} label: {
    Circle().fill(.clear).frame(width: 48, height: 48)
}
.buttonStyle(.plain)
.accessibilityLabel(node.documentId)
.accessibilityAddTraits(.isButton)
.keyboardShortcut(.return, modifiers: [])  // not practical for arbitrary nodes
```

Better approach: the existing `accessibilityRepresentation` closure already provides a
`List`-based VoiceOver tree. Verify that this representation is fully keyboard-operable
by navigating the graph with keyboard+VoiceOver. If the representation's `Button` elements
are not getting focus, add `.focusable()` to the list rows.

### Tests
- Verify About window opens as a separate non-modal window on macOS.
- Verify ⌘, opens Settings window and About menu item opens About window simultaneously.
- Verify keyboard Tab stops in CrossReferenceGraphView land on the accessibility representation list.

---

## Session 62 — Search Refactor: `.searchable` Modifier

**Scope:** The largest architectural change in this HIG remediation set. The current
`SearchView` is a full custom VStack with a manually constructed search bar. Replace with
SwiftUI's `.searchable` modifier, which integrates with the navigation bar on iOS and the
toolbar on macOS, provides system cancel affordance, and supports `.searchScopes`.

### Findings addressed
| ID | Fix |
|---|---|
| F-002 | Replace custom `searchInputRow` with `.searchable` modifier |

### Current architecture

`SearchView` structure:
```
NavigationStack
└── VStack
    ├── searchInputRow  (HStack: icon + TextField + filter toggle + send button)
    ├── filterPanel     (expandable: date range, person, subject tags, user tags)
    └── resultsSection  (List of SearchResultRow)
```

The `searchInputRow` is a custom component with no system appearance.

### Target architecture

```
NavigationStack
└── List  (resultsSection, or ContentUnavailableView)
    .searchable(text: $vm.keywords, prompt: "Keywords…")
    .searchScopes($vm.scopeSelection) {
        Text("All").tag(SearchScope.all)
        Text("Documents").tag(SearchScope.documents)
        // etc.
    }
    .toolbar {
        ToolbarItem(placement: .primaryAction) {
            filterToggleButton    // opens filter sheet/popover
        }
        #if !os(iOS)
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
        #endif
    }
    .sheet(isPresented: $vm.showFilterPanel) {
        FilterSheetView(vm: vm)   // existing filter panel extracted to separate view
    }
```

**Key design decisions:**

1. **Filter panel** — the existing `filterPanel` subview (date range, person ref, subject tags,
   user tags, confidence) is too complex for a `.searchScopes` bar alone. Extract it to a
   `FilterSheetView` presented as a sheet on iOS (`.medium, .large` detents) or a popover
   on macOS. The filter toggle button in the toolbar shows a filled icon when filters are
   active (existing logic preserved).

2. **Scope bar** — if SearchViewModel supports distinct search scopes, expose them via
   `.searchScopes`. Otherwise, omit `.searchScopes` and rely solely on the filter sheet.

3. **Search-on-submit** — `.searchable` fires `onSubmit(of: .search)` which should trigger
   `vm.search()`. Alternatively, bind `.onChange(of: vm.keywords)` with debounce.

4. **Person search field** — the current `personSearchText` field is separate from the
   main keyword field. This becomes a field within the `FilterSheetView` only (not in the
   main search bar).

5. **Existing `SearchView` state** — `vm.keywords` maps directly to the `.searchable` text
   binding. All other `SearchViewModel` state (filters, results, navigation) is preserved.

### Migration path

1. Extract `filterPanel` into `SearchFilterView` as a standalone `Form`.
2. Remove `searchInputRow` from `SearchView`.
3. Apply `.searchable(text: $vm.keywords, prompt: ...)` to the `NavigationStack`.
4. Wire `onSubmit(of: .search) { vm.search() }`.
5. Add filter toggle toolbar button that presents `SearchFilterView` as sheet/popover.
6. Remove the `SearchView` initializer's `SearchView.vm` manual setup of the search text
   field (it already binds through `vm.keywords`).
7. Update `BrowserView.splitLayout` — the existing search toolbar button still works as-is
   (it presents the SearchView sheet/inspector, unchanged).

### Tests
- Existing search tests in `IndexingPipelineTests` and FTS5 tests are unaffected.
- Add UI-level snapshot test or XCUITest for the new search bar appearance.
- Verify that `vm.applyParameters(params)` still works (called from `pendingSearch` flow)
  by setting `vm.keywords` programmatically.

---

## Implementation Order Recommendation

| Priority | Session | Reason |
|---|---|---|
| 1 | **56** | High-severity iOS usability issues; small, safe changes |
| 2 | **57** | Destructive action guards are safety-critical; onboarding affects first launch |
| 3 | **58** | Accessibility compliance; largely mechanical, low-risk |
| 4 | **59** | Sheet architecture cleans up DocumentView; needed before Session 62 |
| 5 | **61** | macOS About Window and Settings cleanup; low-risk self-contained changes |
| 6 | **60** | macOS inspector architecture; largest macOS structural change |
| 7 | **62** | `.searchable` refactor; highest risk (core feature rewrite); tackle after all other sessions stabilise the codebase |
