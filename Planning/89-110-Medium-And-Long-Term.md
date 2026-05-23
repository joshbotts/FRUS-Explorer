---
name: Sessions 89–110+ — Medium and Long-Term Investments
description: Medium and long-term development roadmap covering cloud sync repair,
  platform parity, large new features (Source Explorer macOS, Saved Searches, Analytics,
  Research Session Log), and multi-session investments (Inline Highlighting, iPadOS
  Split View / Stage Manager). Most items require investigation before final
  implementation can be fully specified.
type: implementation
originSessionId: session-80
---

# Sessions 89–110+: Medium and Long-Term Investments

These sessions address items from the Development Backlog
(`Planning/75-Development-Backlog.md`) that require more investigation, carry more
architectural risk, or simply represent larger scopes than the quick-win track in
Sessions 81–88. Final implementation details for most items should be confirmed at
the start of the relevant session after reviewing current code state.

Sessions marked **BLOCKED on Session 81** cannot begin until the rich rendering
infrastructure introduced in Session 81 is complete and stable in production.

---

## Work Item Summary

| Session(s) | Backlog Ref | Title | Effort | Risk | Blocked On |
|------------|-------------|-------|--------|------|------------|
| 89 | #9 | Cloud Sync — Collections Not Syncing to iPad | Low–Med | Low | None |
| 90 | #10 | macOS ↔ iOS Settings Parity | Low–Med | Low | None |
| 91–92 | #11 | iOS Visual Identity — Apply macOS Style | Medium | Low–Med | None |
| 93 | #14 | Dynamic Island / Live Activity Investigation | Low | Low | None |
| 94–95 | #3 (LARGE) | Source Explorer macOS | Large | Medium | None |
| 96–97 | #16 | Saved Searches + Smart Collections | Medium | Low–Med | None |
| 98–99 | #17 | Corpus Frequency Analytics | Medium | Low | None |
| 100–101 | #18 | Research Session Log | Medium | Low | None |
| 102–106 | #19 (LONG) | Inline Highlighting + Passage-Anchored Notes | Very Large | High | **Session 81** |
| 107–110 | #20 (LARGE) | iPadOS Split View + Stage Manager | Large | Medium | None |

---

## Session Breakdown

---

### Session 89 — Cloud Sync Investigation: Collections Not Syncing to iPad

**Scope:** Backlog #9. Diagnose and fix the CloudKit sync bug that causes the
Collections tab to be empty on iPad while the Activity tab and Research Notes sync
correctly.  
**Effort:** Low–Medium (one session: investigate + fix + device test).  
**Risk:** Low. A targeted model annotation change; no architectural impact.

#### Investigation Approach

Start by comparing the `Collection` SwiftData `@Model` with `ResearchNote` (which
syncs reliably). Common CloudKit sync failure causes for SwiftData models include:

1. **Ordered relationships** — CloudKit cannot sync `[SomeModel]` properties backed
   by an ordered array. Must use an unordered relationship + a separate `sortOrder:
   Int` column on the child entity.
2. **Missing `@Attribute(.unique)` on a required unique field** — CloudKit record
   identity depends on stable unique identifiers.
3. **Non-optional relationships** — CloudKit requires all relationships to be
   optional to handle partial record delivery.
4. **Model not registered in the CloudKit-backed `ModelContainer` schema** —
   verify `Collection` (and `CollectionEntry`) are passed to
   `FRUSExplorerApp.makeFRUSContainer()` in the schema array.
5. **`@Relationship` cascade/nullify rules incompatible with CloudKit** — some
   delete rules are not supported.

#### Files to Investigate

| File | What to Check |
|------|---------------|
| `FRUSExplorer/Models/Collection.swift` | `@Relationship` annotations; ordered vs unordered arrays; optional vs non-optional |
| `FRUSExplorer/Models/CollectionEntry.swift` | Same; plus whether `sortOrder` or `position` is an ordered-array index |
| `FRUSExplorer/App/FRUSExplorerApp.swift` | `makeFRUSContainer()` — confirm `Collection` and `CollectionEntry` are in the schema |

#### Expected Fix

Almost certainly a relationship annotation change: replace an ordered `[CollectionEntry]`
with an unordered `Set<CollectionEntry>` plus a `sortOrder: Int` field on
`CollectionEntry`, and ensure all relationships are optional. No UI changes required
if the sort order column is added transparently.

---

### Session 90 — macOS Settings ↔ iOS Settings Parity

**Scope:** Backlog #10. Assess feature parity between `FRUSSettingsView.swift`
(macOS, reported 11 panes) and `SettingsView.swift` (iOS) and implement missing
controls on the lagging platform.  
**Effort:** Low–Medium (one session for assessment + implementation if gaps are small;
two sessions if significant new controls are needed).  
**Risk:** Low. Additive UI controls; no model changes.

#### Assessment Approach

Produce a gap table at the start of the session listing every pane/control in the
macOS Settings and its iOS equivalent (or lack thereof). Common gaps in cross-platform
apps include:

- Keyboard shortcut configuration (macOS-only by nature)
- Appearance / theme controls present on one platform but not the other
- Advanced indexing controls or cache management tools
- Export defaults (default format, paper size) present on macOS but missing on iOS

Prioritise gaps that affect research workflow over cosmetic preferences. Implement
the highest-priority missing controls first; defer macOS-only controls (keyboard
shortcuts, menu bar integration) that have no iOS equivalent.

#### Files to Investigate

| File | Role |
|------|------|
| `FRUSExplorer/UI/macOS/FRUSSettingsView.swift` | macOS settings — source of truth for pane inventory |
| `FRUSExplorer/UI/iOS/SettingsView.swift` | iOS settings — identify gaps against macOS |

---

### Sessions 91–92 — iOS Visual Identity: Apply macOS Style

**Scope:** Backlog #11. Define a shared design system and apply macOS visual
conventions to iOS key views.  
**Effort:** Medium. Two sessions: Session 91 for investigation and design system
definition; Session 92 for implementation.  
**Risk:** Low–Medium. Touching many iOS views; risk of unintended layout regression.
Use snapshot tests before and after to catch regressions.

#### Session 91 — Investigation + Design System

1. Audit macOS visual identity patterns in:
   - `MainWindowView.swift` — layout structure, sidebar / content split
   - `MacDocumentView.swift` — document reading typography, spacing
   - `ResearchStripView.swift` — secondary panel visual language
   - `StatusBarView.swift` — status/progress bar style
2. Identify shared design tokens: typography scale (body, heading, caption), color
   palette (primary text, secondary text, accent, background), spacing constants,
   corner radii.
3. Design a `FRUSTheme` environment object (or `ViewModifier`) that encodes these
   tokens. Decide between:
   - **Environment object approach**: `@EnvironmentObject var theme: FRUSTheme`
     injected at the root, accessed in all views.
   - **ViewModifier approach**: `.frusTheme()` modifier applied at the root, providing
     token values via `@Environment` custom keys.
4. Propose typography and color changes for the three primary iOS views:
   `MainTabView`, `DocumentView`, `BrowserView`.

#### Session 92 — Implementation

Apply `FRUSTheme` tokens to iOS key views:

- `FRUSExplorer/UI/iOS/MainTabView.swift`
- `FRUSExplorer/UI/iOS/DocumentView.swift`
- `FRUSExplorer/UI/iOS/BrowseTabView.swift` (or `BrowserView.swift`)

Update font calls, color references, and spacing constants to use theme tokens rather
than hard-coded values. Verify on iPhone and iPad (both light and dark mode) before
closing.

#### Files to Investigate / Modify

| File | Role |
|------|------|
| `FRUSExplorer/UI/macOS/MainWindowView.swift` | Reference for macOS visual language |
| `FRUSExplorer/UI/macOS/MacDocumentView.swift` | Reference for document reading style |
| `FRUSExplorer/Theme/FRUSTheme.swift` (new) | Shared design token environment object / modifier |
| `FRUSExplorer/UI/iOS/MainTabView.swift` | Apply theme tokens |
| `FRUSExplorer/UI/iOS/DocumentView.swift` | Apply theme tokens |
| `FRUSExplorer/UI/iOS/BrowseTabView.swift` | Apply theme tokens |

---

### Session 93 — Dynamic Island / Live Activity Investigation

**Scope:** Backlog #14. Investigate ActivityKit feasibility for indexing/summarization
progress display in Dynamic Island; implement a simpler fallback if ActivityKit is
deferred.  
**Effort:** Low (one session: investigation + fallback implementation).  
**Risk:** Low. ActivityKit is purely additive; fallback is a straightforward banner view.

#### Investigation

ActivityKit requires a separate Widget Extension target, WidgetKit entitlements, and
an `ActivityAttributes` struct shared between the app and extension via a framework or
Swift package. Assess whether adding this complexity is justified given the expected
frequency and duration of indexing operations.

Decision criteria:
- If indexing a large volume takes >30 seconds and users leave the app during indexing
  → ActivityKit is worthwhile.
- If indexing is fast or users typically stay in the app → implement the fallback.

#### Fallback Implementation (if ActivityKit is deferred)

Add a progress banner view pinned above the tab bar on iOS, mirroring the macOS
`StatusBarView` pattern. `AppState` already exposes `indexingProgress: Double`. Wire
it to a `ProgressBannerView` shown when `indexingProgress > 0 && < 1`:

```swift
struct ProgressBannerView: View {
    let progress: Double
    var body: some View {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(.accentColor)
            .padding(.horizontal)
            .background(.bar)
    }
}
```

Inject at the bottom of `MainTabView` using a `ZStack` overlay, hidden when progress
is 0 or 1.

#### Files to Investigate / Modify

| File | Role |
|------|------|
| `FRUSExplorer/App/AppState.swift` | Confirm `indexingProgress` exposure |
| `FRUSExplorer/UI/iOS/MainTabView.swift` | Add `ProgressBannerView` overlay |
| `FRUSExplorer/UI/iOS/ProgressBannerView.swift` (new) | Banner view implementation |

---

### Sessions 94–95 — Source Explorer macOS

**Scope:** Backlog #3 (LARGE). Build out the macOS Source Explorer from a stub to a
fully functional multi-archive browser, porting iOS logic to macOS idioms.  
**Effort:** Large (two sessions; may require a third for polish).  
**Risk:** Medium. Significant new UI surface; depends on NARA API reliability.

#### Session 94 — NARA API + Lot File Browsing + Search

The iOS implementation in `FRUSExplorer/SourceExplorer/` is the reference. The macOS
`SourceExplorerWindowView` (or equivalent) is reported as a stub.

1. Review iOS `SourceExplorer/` architecture: identify view models, API services,
   and data models that can be shared or directly reused on macOS.
2. Build `MacSourceExplorerView` with a macOS-idiomatic split view:
   - Leading sidebar: archive list (NARA, Presidential Libraries, Foreign Archives)
   - Content area: lot file browser / search results table (`List` or `Table`)
   - Detail panel: selected record metadata
3. Port NARA API integration from iOS to macOS (likely shared logic in a
   `SourceExplorerService` already used on iOS).
4. Wire search: `NSSearachField`-backed query → API search → results in the content
   table.

#### Session 95 — Presidential Library Records + Foreign Archives + Export

1. Presidential library records browser: port iOS equivalent; adapt for macOS table
   views and toolbar buttons.
2. Foreign archives section: port iOS equivalent.
3. Export functionality: `NSSavePanel` for exporting record citations or metadata
   as CSV/JSON. Use existing `BibtexExporter` / `RISExporter` from Session 86 for
   citation export where applicable.
4. Toolbar: standard macOS toolbar with Search, Refresh, Export, and Share items.

#### Files to Investigate / Modify

| File | Role |
|------|------|
| `FRUSExplorer/SourceExplorer/` (directory) | iOS reference implementation |
| `FRUSExplorer/UI/macOS/MacSourceExplorerView.swift` (new or existing stub) | macOS implementation target |

---

### Sessions 96–97 — Saved Searches + Smart Collections

**Scope:** Backlog #16. Persistent saved searches that can also back "smart
collections" — dynamically resolved at export time.  
**Effort:** Medium (two sessions).  
**Risk:** Low–Medium. New SwiftData model; UI additions to SearchView and
CollectionEditorView; dynamic collection resolution touches the export pipeline.

#### Session 96 — Saved Search Model + Save Button + SavedSearchesView

**New SwiftData model:**

```swift
@Model final class SavedSearch {
    var id: UUID
    var name: String
    var queryText: String
    var scopeFlags: Int          // Bitmask for corpus / volume scope
    var dateRangeStart: Date?
    var dateRangeEnd: Date?
    var subseriesFilter: String?
    var documentTypeFilter: String?
    var sortOrder: String        // e.g. "relevance", "date_asc", "date_desc"
    var createdAt: Date
}
```

Add `SavedSearch` to the `ModelContainer` schema in `FRUSExplorerApp.makeFRUSContainer()`.

**SearchView "Save Search" button:** Toolbar button that presents a sheet for naming
the search; saves current `SearchParameters` as a `SavedSearch` record.

**`SavedSearchesView`:** List of saved searches with rename/delete support. Tapping
a saved search runs it immediately (populates `SearchParameters` and executes).

#### Session 97 — Smart Collection Binding + Dynamic Resolution

**`Collection.savedSearchId: UUID?`:** Optional reference to a `SavedSearch`. When
non-nil, the collection is "smart" — its document list is resolved at export time
by executing the saved search against the current index.

**Dynamic collection resolution:**

In the export pipeline (called before building `[CollectionExportDocument]`):

```swift
if let searchId = collection.savedSearchId,
   let search = savedSearchStore.find(searchId) {
    let results = await searchEngine.search(SearchParameters(from: search))
    documents = results.map { CollectionExportDocument(from: $0) }
}
```

**`CollectionEditorView`:** Show a "Smart Collection" indicator (lightning bolt icon)
when `collection.savedSearchId != nil`. Add a "Link to Saved Search" control.

#### Files to Modify

| Session | File | Change |
|---------|------|--------|
| 96 | `FRUSExplorer/Models/SavedSearch.swift` (new) | `SavedSearch` SwiftData model |
| 96 | `FRUSExplorer/App/FRUSExplorerApp.swift` | Add `SavedSearch` to container schema |
| 96 | `FRUSExplorer/UI/SearchView.swift` (shared or per-platform) | "Save Search" toolbar button + sheet |
| 96 | `FRUSExplorer/UI/SavedSearchesView.swift` (new) | List + manage saved searches |
| 97 | `FRUSExplorer/Models/Collection.swift` | Add `savedSearchId: UUID?` |
| 97 | `FRUSExplorer/Collections/CollectionExporter.swift` | Dynamic resolution before export |
| 97 | `FRUSExplorer/UI/iOS/CollectionEditorView.swift` | Smart collection indicator + link control |

---

### Sessions 98–99 — Corpus Frequency Analytics

**Scope:** Backlog #17. Analytics service computing term frequency by year and
subseries, surfaced in Swift Charts visualisations.  
**Effort:** Medium (two sessions).  
**Risk:** Low. Read-only queries; new view only; no model writes.

#### Session 98 — CorpusAnalyticsService + Background Task Design

**`CorpusAnalyticsService` actor:**

```swift
actor CorpusAnalyticsService {
    func termFrequencyByYear(term: String) async -> [YearFrequency]
    func termFrequencyBySubseries(term: String) async -> [SubseriesFrequency]
    func topTermsByYear(year: Int, limit: Int) async -> [TermCount]
}
```

Queries run against the FTS5 index. Design background task scheduling so that
expensive queries (full-corpus term scans) do not block the main actor. Use
Swift's structured concurrency (`Task.detached` with low priority or a custom
`BackgroundTaskScheduler`).

Determine appropriate caching strategy: results for frequently queried terms can
be cached in-memory with a size-bounded `NSCache`; cache invalidation on index
update.

#### Session 99 — AnalyticsView with Swift Charts

**`AnalyticsView`:**

- Bar chart: term frequency by year (`BarMark` with x = Year, y = Count)
- Line chart overlay: trend line (`LineMark` with same axes)
- View-mode toggle between chart and data table
- Term search field driving the chart data

```swift
Chart {
    ForEach(frequencyData) { point in
        BarMark(x: .value("Year", point.year),
                y: .value("Frequency", point.count))
    }
    ForEach(frequencyData) { point in
        LineMark(x: .value("Year", point.year),
                 y: .value("Frequency", point.count))
        .interpolationMethod(.catmullRom)
    }
}
```

**Surface:** View-mode toggle in Corpus Browser toolbar (macOS) and a dedicated
"Analytics" tab or menu item in the Browse tab (iOS).

#### Files to Modify

| Session | File | Change |
|---------|------|--------|
| 98 | `FRUSExplorer/Analytics/CorpusAnalyticsService.swift` (new) | Actor with frequency query methods + caching |
| 99 | `FRUSExplorer/UI/AnalyticsView.swift` (new) | Swift Charts bar + line chart with term search |
| 99 | `FRUSExplorer/UI/macOS/MacCorpusBrowserView.swift` | Add Analytics toggle to toolbar |
| 99 | `FRUSExplorer/UI/iOS/BrowseTabView.swift` | Add Analytics entry point |

---

### Sessions 100–101 — Research Session Log

**Scope:** Backlog #18. Automatic logging of research events (document opens, note
saves, searches, exports) into a structured session timeline, surfaced in the Activity
tab.  
**Effort:** Medium (two sessions).  
**Risk:** Low. New SwiftData models; hook points are fire-and-forget; no impact on
existing feature performance paths.

#### Session 100 — Models + Event Hook Points

**New SwiftData models:**

```swift
@Model final class ResearchSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var events: [SessionEvent]   // Ordered; see Session 89 CloudKit note
}

@Model final class SessionEvent {
    var id: UUID
    var session: ResearchSession?
    var timestamp: Date
    var eventType: String        // "documentOpen", "noteSave", "searchSubmit", "export"
    var payload: Data?           // JSON-encoded event-specific data
    var sortOrder: Int
}
```

Add both models to `makeFRUSContainer()` schema.

**`AppState.logEvent(_:)`:** A low-overhead method (async, fire-and-forget) that
creates a `SessionEvent` and appends it to the current `ResearchSession`. Creates a
new `ResearchSession` if none is active (i.e., no session started in the last N
minutes of inactivity).

**Hook points** (all fire-and-forget; must not block UI):
- `AppState.logEvent(.documentOpen(volumeId:, documentId:, title:))`
  → called from `MacDocumentView.onAppear` and `DocumentView.onAppear`
- `AppState.logEvent(.noteSave(noteId:, title:))`
  → called from `ResearchNoteStore.save()`
- `AppState.logEvent(.searchSubmit(query:, resultCount:))`
  → called from `SearchEngine.search()` on completion
- `AppState.logEvent(.export(format:, documentCount:))`
  → called from each exporter on completion

#### Session 101 — Timeline Log UI + Settings Toggle

**Activity tab timeline:** In the Activity tab, add a "Session Log" section or
sub-tab showing `ResearchSession` records in reverse-chronological order. Expanding
a session reveals its `SessionEvent` list with timestamps and event descriptions.

**Settings toggle:** In `SettingsView` (both platforms), add a "Log Research Sessions"
toggle backed by `@AppStorage("researchSessionLoggingEnabled")`. When disabled,
`AppState.logEvent` returns immediately without writing. No data deletion on
disable — preserve existing log.

#### Files to Modify

| Session | File | Change |
|---------|------|--------|
| 100 | `FRUSExplorer/Models/ResearchSession.swift` (new) | `ResearchSession` + `SessionEvent` models |
| 100 | `FRUSExplorer/App/AppState.swift` | Add `logEvent(_:)` method + session management |
| 100 | `FRUSExplorer/App/FRUSExplorerApp.swift` | Add models to container schema |
| 100 | `FRUSExplorer/UI/macOS/MacDocumentView.swift` | Log `documentOpen` on appear |
| 100 | `FRUSExplorer/UI/iOS/DocumentView.swift` | Log `documentOpen` on appear |
| 100 | `FRUSExplorer/Search/SearchEngine.swift` | Log `searchSubmit` on completion |
| 100 | `FRUSExplorer/Collections/CollectionExporter.swift` | Log `export` on completion |
| 101 | `FRUSExplorer/UI/ActivityView.swift` (or tab) | Session log section / sub-tab |
| 101 | `FRUSExplorer/UI/iOS/SettingsView.swift` + macOS equivalent | Logging toggle |

---

### Sessions 102–106 — Inline Highlighting + Passage-Anchored Notes

**Scope:** Backlog #19 (LONG-TERM).  
**Effort:** Very large (five sessions minimum).

> **BLOCKED: DO NOT START until Session 81 (Rich Document Rendering in Exports) is
> complete, stable, and merged to main.** The offset model (startOffset, endOffset)
> must be defined against the render model's character stream, not raw XML byte
> positions. The render model must be stable before offset values are persisted.

#### Session 102 — Architecture Design + DocumentHighlight Model

Before writing any code, produce a design document covering:

- Offset model: how character offsets are defined relative to the render model
  (e.g. flattened inline text nodes, depth-first traversal order). Must be
  deterministic across sessions.
- `renderingVersion: String` field on `DocumentHighlight` — a hash or version
  identifier of the render model used when the highlight was created. Stale
  highlights (version mismatch) are shown with a warning indicator rather than
  silently dropped.
- Conflict resolution strategy for CloudKit sync of overlapping highlights from
  multiple devices.

**`DocumentHighlight` SwiftData model:**

```swift
@Model final class DocumentHighlight {
    var id: UUID
    var volumeId: String
    var documentId: String
    var startOffset: Int
    var endOffset: Int
    var colorTag: String         // "yellow", "green", "blue", "pink"
    var noteId: UUID?            // Optional link to a ResearchNote
    var createdAt: Date
    var renderingVersion: String
}
```

#### Session 103 — macOS Text Selection Layer

Implement text selection and highlight creation on macOS. The primary challenge is
that `FRUSDocumentRenderer` uses SwiftUI `Text` views, which do not expose selection
events. Options to investigate:

1. Wrap the document body in an `NSTextView` (`UIViewRepresentable`/`NSViewRepresentable`)
   — requires converting the render model to `NSAttributedString` (already done in
   Session 81 for PDF export).
2. Custom `Canvas`-based rendering with gesture recognisers for selection.
3. SwiftUI `TextEditor` (limited; likely insufficient).

Option 1 is recommended as it reuses the `renderNodeToNSAttributedString` work from
Session 81.

#### Session 104 — iOS Text Selection Layer

Port Session 103 text selection to iOS using `UITextView` (`UIViewRepresentable`).
The `renderNodeToNSAttributedString` attributed string from Session 81 is the shared
foundation. Implement tap-and-hold selection with the system magnifier; map selected
range back to `(startOffset, endOffset)` in the render model's character stream.

#### Session 105 — Highlight Persistence + CloudKit Sync + Conflict Resolution

1. Persist `DocumentHighlight` records via SwiftData on highlight creation and deletion.
2. Register `DocumentHighlight` in `makeFRUSContainer()` schema for CloudKit sync.
3. Implement `renderingVersion` check: on document open, compare stored highlights'
   `renderingVersion` against the current render model version. Surface stale-offset
   warning UI for mismatched highlights.
4. Conflict resolution: use `createdAt` timestamp for last-write-wins; surface a
   conflict indicator when two devices have created non-overlapping highlights on the
   same passage.

#### Session 106 — ResearchNote Anchoring to Highlights + UI Integration

1. Allow a `ResearchNote` to be anchored to a `DocumentHighlight` (via
   `DocumentHighlight.noteId`). Creating a note from a selected passage auto-links
   the note to the highlight.
2. In `FRUSDocumentRenderer`, show highlight color overlays under highlighted text
   spans. On macOS, use `NSTextView` background color attributes. On iOS, use
   `UITextView` background color attributes.
3. Show a note indicator icon (speech bubble) adjacent to highlighted passages that
   have a linked note. Tapping the indicator opens the linked note in `ResearchNoteEditorView`.

#### Files to Investigate / Modify (across Sessions 102–106)

| File | Role |
|------|------|
| `FRUSExplorer/Models/DocumentHighlight.swift` (new) | `DocumentHighlight` SwiftData model |
| `FRUSExplorer/App/FRUSExplorerApp.swift` | Add model to container schema |
| `FRUSExplorer/UI/macOS/MacDocumentView.swift` | macOS text selection layer + highlight overlay |
| `FRUSExplorer/UI/iOS/DocumentView.swift` | iOS text selection layer + highlight overlay |
| `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` | Highlight overlay rendering on both platforms |
| `FRUSExplorer/Models/ResearchNote.swift` | (May need no change if `noteId` on highlight is sufficient) |

---

### Sessions 107–110 — iPadOS Split View + Stage Manager

**Scope:** Backlog #20 (LARGE). First-class iPadOS support: `NavigationSplitView`
for regular-width layouts, additional `WindowGroup` scenes for Stage Manager.  
**Effort:** Large (four sessions).  
**Risk:** Medium. Significant layout changes to views that currently assume compact
or macOS idioms; regression risk on iPhone.

#### Session 107 — `horizontalSizeClass .regular` Layout Paths

Key views to update for iPad regular-width (`horizontalSizeClass == .regular`):

- **`BrowseTabView` / `BrowserView`:** Introduce a `NavigationSplitView` with a
  sidebar (volume list) and content (document list) when `horizontalSizeClass == .regular`.
  The current `NavigationStack` remains for compact width (iPhone).
- **`DocumentView`:** Wider layout with optional side panel for research notes when
  in regular width.
- **`CollectionEditorView`:** Two-column layout on iPad — collection documents on
  the left, editor controls on the right.

#### Session 108 — Stage Manager: Additional WindowGroup Scenes

Stage Manager on iPadOS M-chip devices supports multiple concurrent windows. Implement
additional `WindowGroup` / `DocumentGroup` scenes mirroring the macOS architecture:

- A document window scene (`WindowGroup(for: DocumentWindowID.self)`)
- A source explorer window scene

These scenes are inactive on iPhone and on iPad models without Stage Manager support
(`UISupportsMultipleScenes` key in Info.plist; conditional on device capability).

#### Sessions 109–110 — Polish, Testing, and Regression Fixes

1. Full regression pass on iPhone (compact width) to ensure all `horizontalSizeClass`
   branches are correct.
2. iPad Pro layout testing (11-inch and 13-inch, both orientations).
3. Stage Manager multi-window testing: open two document windows simultaneously;
   verify no shared-state conflicts in `AppState` or `NavigationModel`.
4. Fix any layout regressions surfaced during 107–108.

#### Files to Investigate / Modify

| Session | File | Change |
|---------|------|--------|
| 107 | `FRUSExplorer/UI/iOS/BrowseTabView.swift` | Add `.regular` `NavigationSplitView` path |
| 107 | `FRUSExplorer/UI/iOS/DocumentView.swift` | Wider layout with side panel on `.regular` |
| 107 | `FRUSExplorer/UI/iOS/CollectionEditorView.swift` | Two-column layout on `.regular` |
| 108 | `FRUSExplorer/App/FRUSExplorerApp.swift` | Additional `WindowGroup` scenes for Stage Manager |
| 108 | `FRUSExplorer-iOS/Info.plist` | `UISupportsMultipleScenes: true` |
| 109–110 | All modified iOS views | Regression fixes from testing |

---

## Dependency Chain

```
Sessions 77–80 (TEI Fidelity)
        │
        ▼
Session 81 (Rich Rendering in Exports)  ◄── PREREQUISITE FOR HIGHLIGHTED SESSIONS BELOW
        │
        ├──► Sessions 82–83 (DOCX Export)          [BLOCKED on Session 81]
        │
        └──► Sessions 102–106 (Inline Highlighting) [BLOCKED on Session 81; LONG-TERM]
                     │
                     └──► Session 106 (Note Anchoring) [BLOCKED on 102–105]

[Independent tracks — no dependency on Session 81]

Session 89  (Cloud Sync Fix)
Session 90  (Settings Parity)
Sessions 91–92 (iOS Visual Identity)
Session 93  (Dynamic Island / Live Activity)
Sessions 94–95 (Source Explorer macOS)
Sessions 96–97 (Saved Searches + Smart Collections)
Sessions 98–99 (Corpus Frequency Analytics)
Sessions 100–101 (Research Session Log)
Sessions 107–110 (iPadOS Split View + Stage Manager)
```

### Items Explicitly Blocked on Session 81

The following sessions **cannot begin** until Session 81 (Rich Document Rendering in
Exports) is complete and its `FRUSDocumentRenderModel` / `DocumentRenderService`
infrastructure is stable in main:

| Session | Title | Why Blocked |
|---------|-------|-------------|
| 82 | DOCX Export Part 1 | Infrastructure needed before rich DOCX layers are added in 83 |
| 83 | DOCX Export Part 2: Rich Content | Directly consumes render model for `<w:rPr>` mapping |
| 102 | Highlighting Architecture | Offset model must be defined against stable render model |
| 103 | macOS Text Selection | Reuses `renderNodeToNSAttributedString` from Session 81 |
| 104 | iOS Text Selection | Same dependency as Session 103 |
| 105 | Highlight Persistence + CloudKit | Offset values are meaningless without stable render model |
| 106 | Note Anchoring + UI Integration | Depends on Highlight persistence from 105 |

---

## Notes on Scheduling

- **Session 89** (Cloud Sync) should be scheduled as soon as possible — a sync bug
  actively degrades the iPad experience and may affect user trust in data persistence.
- **Sessions 91–92** (iOS Visual Identity) are best scheduled after **Session 90**
  (Settings Parity) so that any new iOS settings controls also receive the new
  visual treatment.
- **Sessions 102–106** (Inline Highlighting) are the largest risk block in the
  roadmap. Begin the Session 102 architecture document only after Session 81 has been
  in production for at least one full development cycle (confirm no render model
  regressions before freezing the offset model).
- **Sessions 107–110** (iPadOS) are independent but benefit from the design system
  work in Sessions 91–92. Consider scheduling them in sequence.
