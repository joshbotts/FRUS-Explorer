---
name: Session 75+ Development To-Dos
description: Work items from end of Session 74 (2026-05-19) plus longer-horizon feature backlog. Pick up from another machine.
type: todo
originSessionId: session-74
---

# Development To-Do List (Sessions 75+)

Captured after a two-day mac-focused sprint (Sessions 73–74). Branch `claude/crazy-elion-bc7005` contains all Session 73–74 work and has an open PR against `v2`.

Items are grouped into **Immediate fixes** (bugs and polish from the sprint), **Near-term features** (one session each, low risk), **Medium-term features** (two to three sessions, moderate complexity), and **Large investments** (architectural work, multiple sessions).

**Collaboration strategy note:** This app targets collaboration through shared export artefacts — researchers exchange collections (PDF, HTML, and DOCX) as reading packets rather than sharing live data. DOCX export is therefore the primary collaboration feature to prioritise. CloudKit sharing is explicitly out of scope.

---

## IMMEDIATE FIXES (bugs and polish from Sessions 73–74)

---

## 1. Collection Export — Rich Document Rendering (HIGH PRIORITY)

**Problem:** Exported PDFs and HTMLs render document body text as a flat block of text. The actual FRUS document structure includes:
- A **header** (document number, classification, originating office)
- A **dateline** (place and date)
- **Body text** (formatted, possibly multi-section)
- **Footnotes** (numbered, referenced inline)

**Expected behavior:** Exported documents should render these structural elements as they appear in `DocumentView` — headers, datelines, body, and footnotes — but paginated appropriately for the export format.

**Where to start:**
- `FRUSExplorer/Document/DocumentView.swift` — the iOS rendering view; understand the data model it uses
- `FRUSExplorer/App/MacDocumentView.swift` — macOS equivalent
- `FRUSExplorer/Collections/PDFCollectionExporter.swift` — currently dumps `doc.bodyText` as a flat string
- `FRUSExplorer/Collections/HTMLCollectionExporter.swift` — same issue; body split on `"\n\n"` only
- `FRUSExplorer/Collections/CollectionExporter.swift` — `CollectionExportDocument` carries `bodyText: String`; this struct may need a richer representation (header, dateline, body sections, footnotes as separate fields) to support structured rendering
- `FRUSExplorer/Search/IndexingPipeline.swift` — `fetchDocumentBodyText` retrieves flat text; may need a companion method that returns structured document data
- `FRUSExplorer/Models/` — look for `FRUSDocumentMetadata` or equivalent parsed document model

---

## 2. Collection Export — Italic Formatting for Series Title (LOW EFFORT)

**Problem:** The export renders `_Foreign Relations of the United States_` with literal underscores in exported PDFs and HTML instead of italic text.

**Where to start:**
- `FRUSExplorer/Collections/HTMLCollectionExporter.swift` — the collection note and document body text run through `escaped()` which preserves underscores literally; need to either pre-process Markdown-style emphasis or ensure the source string doesn't use underscores as markup
- `FRUSExplorer/Collections/PDFCollectionExporter.swift` — same issue in plain-text rendering; `NSAttributedString` with italic attribute needed for the phrase
- Root cause: the collection note field is plain text; if the user types `_Foreign Relations..._` expecting Markdown italic, the export doesn't honor it. Decide: (a) process lightweight Markdown in export text, or (b) document that italic markup is not supported in export notes

---

## NEAR-TERM FEATURES (one session each, low risk, purely additive)

---

## 3. Source Explorer — macOS Implementation (LARGE)

**Problem:** `SourceExplorerWindowView` on macOS is an unimplemented stub. iOS has a full implementation.

**Expected behavior:** Same functionality as iOS (NARA Catalog API, lot files, presidential library records, foreign archives), but using macOS-appropriate interface elements (split views, table/list views, NSSavePanel for exports, toolbar buttons rather than sheets).

**Where to start:**
- `FRUSExplorer/SourceExplorer/` — iOS implementation; use as the functional reference
- `FRUSExplorer/App/FRUSExplorerApp.swift` — `SourceExplorerWindowView` wired to `Window("Source Explorer", id: "frus.sourceExplorer")`
- Look for `SourceExplorerWindowView.swift` — currently a stub; this is the file to build out
- NARA API key is stored in keychain; `NARAAPIKeyStore` provides access
- Note: Source Explorer requires a NARA API key configured in Settings → Advanced → NARA API

---

## 4. Handoff / Continuity

**Goal:** Start reading a document on Mac, continue on iPhone or iPad without finding it again.

**Effort:** Low (half a session). Zero regression risk — purely additive Apple API.

**Where to start:**
- Set `view.userActivity` on `MacDocumentView` and `DocumentView` (iOS) with a `NSUserActivity` encoding `volumeId` and `documentId` when a document is opened
- Handle `onContinueUserActivity` in `ContentView` (both platforms) to navigate to the specified document
- `FRUSExplorer/App/FRUSExplorerApp.swift` — define the activity type constant and register it in `Info.plist`
- No SwiftData changes; no network calls; no model changes

---

## 5. Person / Entity Index View

**Goal:** Browse all persons mentioned across a volume or the full corpus; tap a person to see all documents that mention them.

**Effort:** Low (one session). `PersonMentionStore` already holds the data.

**Where to start:**
- `FRUSExplorer/Search/PersonMentionStore.swift` — existing data source; understand the query API
- New `PersonIndexView`: grouped list of person names with document counts; tapping a name runs a pre-filtered search
- Natural home: a new tab or section in the Corpus Browser window (macOS) and the Browse tab (iOS)
- No model changes; no new stores; read-only queries only

---

## 6. Zotero / RIS / BibTeX Citation Export

**Goal:** Let researchers export citations directly to their reference manager (Zotero, Endnote, Mendeley).

**Effort:** Low (one session). Citation data is already computed; BibTeX and RIS are simple text formats.

**Where to start:**
- `FRUSExplorer/Citation/HistoryAtStateCitationFormatter.swift` — existing structured citation data
- Add `BibtexExporter` and `RISExporter` as simple string-interpolation functions
- Add export buttons to the citation popover (macOS and iOS) producing a `.bib` / `.ris` file via the system share sheet
- No new dependencies; no model changes; no regression surface

---

## 7. Document Timeline View

**Goal:** Visualise a search result set or a collection's documents in chronological order.

**Effort:** Low (one session). Date extraction already runs during indexing.

**Where to start:**
- Dates are stored in the FTS5 index and `document_cache` — `DocumentBrowserEntry` should carry them
- New `TimelineView` accepting `[SearchResult]` or `[DocumentBrowserEntry]`, sorted by extracted date, rendered with Swift Charts or a custom scrollable list with year/month markers
- Surfaced as a view-mode toggle in Search results and in the Collection detail pane
- No model changes; no writes; purely read-only presentation

---

## 8. Spotlight Integration

**Goal:** Downloaded documents findable from macOS Spotlight and iOS Search.

**Effort:** Low (one session). Entirely additive `CoreSpotlight` API.

**Where to start:**
- After `IndexingPipeline` finishes indexing a volume, submit `CSSearchableItem` records (title, contentDescription, `userInfo` with `volumeId` + `documentId`) via `CSSearchableIndex.default().indexSearchableItems()`
- When a volume is removed, call `CSSearchableIndex.default().deleteSearchableItems(withIdentifiers:)` with its document IDs
- Handle `onContinueUserActivity(NSUserActivityTypes.coreSpotlightSearch)` in `ContentView` to navigate to the tapped result
- `FRUSExplorer/Search/IndexingPipeline.swift` — add a `submitSpotlightItems()` call at the end of `indexVolume()`

---

## MEDIUM-TERM FEATURES (two to three sessions, moderate complexity)

---

## 9. Cloud Sync — Collections Tab Not Showing Synced Items on iPad (INVESTIGATE)

**Problem:** iPad shows items created on Mac in the Activity tab but NOT in the Collections tab. Projects and notes appear to sync; collections do not.

**Expected behavior:** Collections created on Mac should appear in the Collections tab on iPad after CloudKit sync.

**Where to start:**
- `FRUSExplorer/Models/Collection.swift` — check SwiftData `@Model` definition; verify CloudKit sync annotations
- `FRUSExplorer/Models/CollectionEntry.swift` — check relationship definitions and any `@Relationship` cascade/nullify rules that could prevent sync
- Compare `Collection` model's CloudKit schema with `ResearchNote` model (which syncs correctly) to find the difference
- Check `ModelContainer` configuration in `FRUSExplorer/App/FRUSExplorerApp.swift` — `makeFRUSContainer()` — to confirm `Collection` is included in the CloudKit-backed schema
- This may be a missing `@Attribute(.unique)` or a relationship that CloudKit can't replicate; SwiftData + CloudKit has known limitations with ordered relationships

---

## 10. macOS Settings — iOS Gap Assessment (INVESTIGATION → IMPLEMENTATION)

**Problem:** Not yet assessed whether the macOS Settings panes expose features or controls not available in the iOS Settings tab, and vice versa.

**Expected behavior:** Settings functionality should be at parity between platforms where applicable.

**Where to start:**
- `FRUSExplorer/Settings/FRUSSettingsView.swift` — full macOS Settings window (11 panes)
- `FRUSExplorer/Settings/SettingsView.swift` — iOS Settings tab
- Produce a side-by-side comparison and implement any missing controls on the lagging platform
- Refer to the iOS vs macOS gap analysis in `session_74_gap_analysis` context (or re-run from the codebase)

---

## 11. iOS Visual Identity — Apply macOS UI Style (INVESTIGATION → DESIGN)

**Problem:** The macOS UI has a more developed visual identity. Assess how much of it can be carried to iOS.

**Expected behavior:** iOS UI should share visual language with macOS where the platform allows (typography scale, color palette, card/section styling, iconography).

**Where to start:**
- Review macOS `MainWindowView`, `MacDocumentView`, `ResearchStripView`, `StatusBarView` for design patterns
- Review iOS `MainTabView`, `DocumentView`, `BrowserView` for current state
- `FRUSExplorer/Resources/Assets.xcassets/` — current color and image assets
- Consider: shared `FRUSTheme` environment object or `ViewModifier` to enforce consistent styling cross-platform
- iPadOS is the higher-priority iOS target for visual parity (larger screen, closer to macOS usage patterns)

---

## 12. macOS Research Strip — Remove Collapse Behaviour (LOW EFFORT)

**Problem:** The research strip on `MacDocumentView` can be collapsed to a "+" re-expand button. There is no use case for hiding it — it saves no meaningful vertical space and adds a tap to restore.

**Expected behavior:** The research strip is always visible; remove the collapse/expand toggle entirely.

**Where to start:**
- `FRUSExplorer/App/MacDocumentView.swift` — find `ResearchStripView` and the `@State private var researchStripCollapsed` (or equivalent) toggle
- Remove the chevron collapse button, the "+" re-expand button, and the associated `@State` variable
- The strip height and layout should be locked; `ResearchStripView` itself can remain unchanged if the toggle is purely in the parent

---

## 13. iOS Settings — Storage Index Size Not Reporting (BUG)

**Problem:** The storage summary in iOS Settings does not correctly report the size of the search index. Either the size reads as zero/nil, or the row is showing incorrect data.

**Expected behavior:** Each row in the storage list shows the on-disk size of that component (volumes directory, SQLite index). If the index size cannot be read, the row should either show "—" or be omitted.

**Where to start:**
- `FRUSExplorer/Settings/SettingsView.swift` — `StorageManagementView` or equivalent; find where index size is computed
- The SQLite database is at `{Application Support}/FRUSExplorer/frus.db`; its size should be readable via `FileManager.attributesOfItem(atPath:)[.size]`
- `FRUSExplorer/App/FRUSExplorerApp.swift` `makeDatabaseURL()` — the canonical DB path
- If the path resolves differently on iOS (sandboxed app support directory vs macOS), the size lookup may be targeting the wrong URL

---

## 14. iOS — Progress Indicators in Dynamic Island / Live Activity (INVESTIGATION)

**Problem:** On iOS, indexing and background summarization progress have no persistent visibility. Users must navigate to Settings to see what the app is doing.

**Expected behavior:** Investigate whether ActivityKit Live Activities (powering the Dynamic Island on supported hardware and the lock screen on all devices) are a feasible way to surface indexing and summarization progress.

**Where to start:**
- `FRUSExplorer/App/AppState.swift` — `indexingProgress` and `backgroundSummarizationProgress` are the live data sources
- ActivityKit requires a Widget Extension target; assess build complexity
- Fallback if ActivityKit is too heavy: a persistent banner within the app UI (e.g. a slim progress bar pinned above the tab bar, similar to macOS `StatusBarView`) that appears only when a background task is active
- The macOS `StatusBarView` design is the reference; a compact iOS equivalent anchored above the tab bar would achieve similar UX without requiring an extension target

---

---

## LARGE INVESTMENTS (architectural work, multiple sessions)

---

## 15. DOCX Collection Export (COLLABORATION PRIORITY)

**Goal:** Export collections as Word documents so researchers can exchange reading packets with colleagues who work in Word-based manuscript environments. This is the primary collaboration feature — researchers share collections as artefacts rather than live data.

**Effort:** Medium (two sessions). No native Swift DOCX library; requires generating Open XML directly.

**Risk:** Medium. Open XML is verbose and formatting details (italic, bold, paragraph styles, page layout, footnotes) require correct XML or Word silently ignores them. Allow extra time for debugging edge cases. No regression risk to existing features.

**Where to start:**
- DOCX is a ZIP archive of XML files (Open XML format). Structure: `[Content_Types].xml`, `_rels/.rels`, `word/document.xml`, `word/styles.xml`, `word/relationships`
- `FRUSExplorer/Collections/CollectionExporter.swift` — add `docx` to `ExportFormat` enum; create `DocxCollectionExporter: CollectionExporter`
- Adapt the structure from `PDFCollectionExporter`: cover page (title + note + ToC), per-document sections (citation heading, URL, body paragraphs, footnotes, research note)
- Use `Foundation.Data` + ZIP creation; `ZipFoundation` or a hand-rolled minimal ZIP writer (DEFLATE + local file headers) to assemble the archive
- `FRUSExplorer/Collections/MacCollectionManagerView.swift` and `CollectionEditorView.swift` — add DOCX option to the export format picker
- Rich document rendering (To-Do #1) should be completed first so exported body text is structured; otherwise DOCX will have the same flat-text problem as current PDF/HTML

---

## 16. Saved Searches + Smart Collections

**Goal:** Let researchers save complex search configurations and optionally bind a collection to one so it auto-populates from a live query rather than a manually curated list.

**Effort:** Two to three sessions. New SwiftData model needed; export path requires care.

**Risk:** Low-medium. The export path needs to handle a smart collection being evaluated at export time — it must produce a stable, ordered result and not vary mid-export. Async design required.

**Where to start:**
- New `SavedSearch` SwiftData model: `queryText`, `scopeFlags` (documents/notes/summaries), `dateRange`, `subseriesFilter`, `documentTypeFilter`, `sortOrder`
- `FRUSExplorer/Search/SearchView.swift` — add a "Save Search" button that creates a `SavedSearch` from the current filter state
- New `SavedSearchesView` accessible from the Search tab / Search toolbar
- `FRUSExplorer/Models/Collection.swift` — add optional `savedSearchId: UUID?`; when non-nil, the collection is dynamic
- `FRUSExplorer/Collections/CollectionEditorView.swift` — distinguish static from dynamic collections; dynamic collections show a "Live Results" indicator instead of a manually ordered list
- `FRUSExplorer/Collections/CollectionExporter.swift` — `resolveDocuments()` evaluates the saved search at export time and freezes the result for the export run

---

## 17. Corpus Frequency Analytics

**Goal:** Show how often a term, person, or subject appears across the corpus over time and by subseries — a digital humanities capability history.state.gov doesn't offer.

**Effort:** Two sessions. SQL aggregation queries; Swift Charts visualisation.

**Risk:** Low for existing features. Performance risk: naive `GROUP BY` queries over a large corpus can be slow; queries must run on a background task with caching.

**Where to start:**
- The FTS5 index and `document_cache` table hold term frequency and document dates; joining them enables `GROUP BY year` aggregations
- New `CorpusAnalyticsService` actor: methods like `termFrequencyByYear(query:)` → `[(year: Int, count: Int)]` and `termFrequencyBySubseries(query:)` → `[(subseries: String, count: Int)]`
- Visualisation: `AnalyticsView` using Swift Charts (`BarChart`, `LineMark`) — surface as a new tab in the Corpus Browser or as a view-mode toggle in Search
- Date extraction quality matters — documents without reliable dates are excluded from time-series charts with a disclosure note

---

## 18. Research Session Log

**Goal:** Auto-generate a log of each research session (documents opened, notes created, searches run, collections modified) for reproducibility and research trail documentation.

**Effort:** Two sessions. Model is simple; instrumentation touches many views.

**Risk:** Low if logging is purely additive and never on a critical path. The main risk is poorly placed event hooks causing subtle bugs; instrument carefully with `try?`-wrapped async calls that never block UI.

**Where to start:**
- New SwiftData models: `ResearchSession` (startTime, endTime, projectId) and `SessionEvent` (timestamp, eventType enum, metadata dictionary)
- `FRUSExplorer/App/AppState.swift` — add `func logEvent(_ event: SessionEvent)` as the single call-site; all views call this rather than touching SwiftData directly
- Hook points: `MacDocumentView`/`DocumentView` `onAppear` (document opened), `ResearchNoteEditorView` save (note created/edited), `SearchView` search submission (search run), `CollectionEditorView` export (collection exported)
- Presentation: a timeline-style log in the Activity tab, grouped by session date
- Privacy consideration: add a toggle in Settings to disable session logging

---

## 19. Inline Highlighting + Passage-Anchored Notes (LONG-TERM)

**Goal:** Let researchers highlight a passage of text in a document and anchor a note to it — the most fundamental capability of physical archival research.

**Effort:** Large (three or more sessions). Architecturally significant; depends on rendering pipeline stability.

**Risk:** High. **Do not start until To-Do #1 (rich document rendering) is complete and stable.** Character offset highlights become invalid if the underlying rendering pipeline changes. This is the highest-value feature on the list but must be built on a stable foundation.

**Architectural considerations:**
- SwiftUI `Text` does not support text selection or overlaid highlights natively; realistic paths are wrapping `NSTextView` (macOS) / `UITextView` (iOS) in a `UIViewRepresentable`, or implementing a custom rendering layer that composites highlight rectangles over the text layout
- New SwiftData model: `DocumentHighlight` with `volumeId`, `documentId`, `startOffset`, `endOffset`, `colorTag`, `noteId?`
- Offsets must survive app updates; define a `renderingVersion` stamp per document and invalidate highlights when it changes
- CloudKit sync of highlights requires careful conflict resolution (two researchers highlighting the same passage offline)

---

## 20. iPadOS Split View + Stage Manager

**Goal:** Make the iPad a credible research workstation — two documents side by side, or the Collections/Corpus Browser floating alongside the document view.

**Effort:** Large (three or more sessions). Requires restructuring scene management for iPadOS.

**Risk:** Medium-high. The iPad currently uses `MainTabView` (tab-based, single-window). Meaningful Split View support requires conditional `NavigationSplitView` layouts driven by `horizontalSizeClass`. Stage Manager multi-window support requires a separate scene management approach mirroring the macOS architecture. Start with `horizontalSizeClass` adaptations (lower risk) and treat Stage Manager as a separate follow-on.

**Where to start:**
- `FRUSExplorer/App/ContentView.swift` — check for `horizontalSizeClass` branching; add `.regular` size-class paths for key views
- `FRUSExplorer/Collections/CollectionEditorView.swift` — iPad `.regular` path should use `NavigationSplitView` like `MacCollectionManagerView`
- `FRUSExplorer/Corpus/BrowserView.swift` — iPad `.regular` path should use a two-column layout
- Stage Manager: define additional `WindowGroup` scenes in `FRUSExplorerApp.swift` for iPad, mirroring the macOS `Window` scenes for Collections and Corpus Browser

---

## Context for Next Session

- All Session 73–74 changes are on branch `claude/crazy-elion-bc7005` with an open PR
- The branch is rebased on `v2`; no merge conflicts at time of writing
- The worktree is at `/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/crazy-elion-bc7005`
- Session 74 version numbering: files updated to reflect sessions 73 (large mac collections rewrite) and 74 (polish, entitlements, dSYM fix, doc updates)
- The iOS vs macOS gap analysis from Session 74 is in the conversation transcript and summarised in the beta testing guide
