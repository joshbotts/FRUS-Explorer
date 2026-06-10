# FRUS Explorer — Development Plan

**Version**: 1.7  
**Date**: 2026-06-09

Each task below corresponds to a single development session. Tasks are ordered so that each session's outputs are available as inputs for subsequent sessions. All sessions share the same Xcode workspace.

---

## Session Sequence

| # | Task | Key Output | Depends On |
|---|---|---|---|
| 01 | Project Setup & Build Configuration | Xcode project, SPM manifest, entitlements, two Mac configs | — |
| 02 | Manifest Generator Tool | `manifest.json`, `ManifestGenerator` executable | 01 |
| 03 | SQLite FTS5 Swift Wrapper (`FTS5Store`) | Reusable documented wrapper + tests | 01 |
| 04 | SwiftData Models & CloudKit Sync | All SwiftData model types + CloudKit configuration | 01 |
| 05 | Volume Download & Storage Manager | Download pipeline, queue, storage reporting | 02, 04 |
| 06 | TEI Parser — Core Elements (Layer 1 + 2) | Swift AST, rendering model, core element coverage | 01 |
| 07 | TEI Parser — Full Element Coverage | Complete element coverage, edge case fixtures | 06 |
| 08 | Subject Tag Bundle Integration | Taxonomy + appearance data loading, `SubjectTag` model | 04 |
| 09 | Search Index Pipeline | FTS5 indexing of volumes, summaries, notes, tags | 03, 05, 07, 08 |
| 10 | Onboarding View | Full onboarding flow, project creation, download initiation | 02, 05, 09 |
| 11 | Browser View | Corpus → subseries → volume → compilation → chapter hierarchy | 05, 06, 08 |
| 12 | Document View — Core | TEI rendering, toolbar, citation, tags below document | 06, 07, 08, 04 |
| 13 | Citation Formatter | `CitationFormatter` protocol, history.state.gov style, tests | 06, 12 |
| 14 | Research Note Editor | Note creation, tag selector, summary promotion, cross-project visibility | 04, 12 |
| 15 | Project & Global Context | AppState, project switching, activity tagging, global view | 04, 14 |
| 16 | Search View | Full composable search UI, all filter types, results list | 09, 08, 15 |
| 17 | Cross-Reference Graph — Data | Edge extraction during indexing, edge table queries | 09 |
| 18 | Cross-Reference Graph — UI | Canvas renderer, standard + fallback layouts, interaction | 17, 12 |
| 19 | AI Summarization — Core | `SummarizationProvider` protocol, Apple Intelligence implementation, chunking | 04, 06 |
| 20 | AI Summarization — UI & Prompts | Prompt management UI, schema templates, Document view integration | 19, 12, 15 |
| 21 | Background Summarizer | Concurrent background summarization, scope configuration, Settings integration | 19, 20 |
| 22 | Collection Editor & Export | Collection management UI, PDF + HTML export, share sheet | 04, 12, 14 |
| 23 | NARA Source Explorer | Source note parser, provenance switching, NARA API integration | 12 |
| 24 | Settings Screen | All settings panels, storage management, reindex, prompt management | 05, 09, 21, 23 |
| 25 | Global Context View | Aggregated reading history, notes browser, collections browser | 15, 14, 22 |
| 26 | About Screen & App Polish | About screen, attribution, links, disclaimers | All prior |
| 27 | Accessibility Audit & Fixes | VoiceOver, Dynamic Type, Reduce Motion, tap targets | All prior |
| 28 | OpenAPI Document Review & Finalization | Complete `FRUS-API.openapi.yaml` | All prior |
| 29 | Direct Distribution Build & Notarization | Sparkle integration, Developer ID signing, notarization workflow | All prior |
| 30 | Citation Lookup | Citation parser, page range store, matching engine, Citation Lookup view | 07, 09, 12, 16 |
| 31 | Final Integration Testing | End-to-end tests, performance testing, corpus-scale validation | All prior |
| 32 | Breadcrumbs, App Reset, App Icon & Subseries Fix | `BrowserBreadcrumbBar`; correct reset flow; app icon; subseries regex fix | 11, 24 |
| 33 | Auto-index After Download | `DownloadManager.onVolumeDownloaded` callback; automatic post-download indexing | 09, 05 |
| 34 | Front Matter Browser Support | Structural-section parse fallback; "Read" button in `CompilationView` | 07, 11 |
| 35 | macOS Compatibility | Collection/Export macOS fixes; iOS modifier guards; blank settings sub-view fix; subject tag assets | 22, 24, 08 |
| 36 | Structured Date Indexing | `.date` AST node; `extractStructuredDate`; `DateCertainty`; re-index migration | 07, 09 |
| 37 | Cross-Reference Context Population | `cross_references.context` populated; edge labels in graph popover | 17, 18 |
| 38 | Editorial Note Distinction | `is_editorial_note` flag; `DocumentTypeFilter`; italic rendering in browser | 09, 16 |
| 39 | Person Mention Indexing — Data | `person_mentions` table; `PersonMentionStore`; `SearchParameters.personRef` | 09 |
| 40 | Person Mention Indexing — UI | Person filter in Search; mention count in `PersonDetailSheet`; `pendingSearch` navigation | 39, 16, 12 |
| 41 | Persons & Terms Glossaries Persisted | `persons`/`terms` SQLite tables; SQLite-first `DocumentViewModel`; autocomplete picker | 39 |
| 42 | Footnote Number Indexing (`@n`) | `printedNumber` in AST and render model; `displayLabel` for rendering | 07, 13 |
| 43 | Shared Navigation State & iOS Tab Shell | `AppTab`; `activeTab`; `MainTabView` shell; `ContentView` routing | 01, 11 |
| 44 | Full Navigation Wiring — All Platforms | iOS tabs wired; sheets removed from iOS; Done buttons guarded; `handleCrossRefTap` cross-platform | 43, 15, 16, 24 |
| 45 | Tab Bar Polish & Two-Platform Audit | Badges; `lastActivityTabVisit`; `unindexedVolumeCount`; build audit | 44, 27 |
| 46 | macOS Settings Scene & Toolbar | `Settings` scene; `MacSettingsView`; ⌘F / ⌘⇧F shortcuts; Collections button | 44 |
| 47 | Documentation Update | Planning docs for sessions 32–46; spec and README updated | All prior |
| 48 | Database & Infrastructure Bug Fixes | FTS5 `frus_documents` rebuild (schema v3); `UIBackgroundModes`; BGTaskScheduler cap | 38, 45 |
| 49 | Onboarding Redesign & Download Manager | Three-choice onboarding; default project with corpus dates; subseries/subject picker in Settings | 10, 24 |
| 50 | Browser & Navigation Polish | Downloaded-volumes filter; multi-line breadcrumbs; macOS About menu item | 11, 32, 46 |
| 51 | iOS Indexing Performance & Visualization | Memory-aware batch throttle; `IndexingProgressUpdate` stream; progress UI | 09, 33, 45 |
| 52 | UI Obstruction Audit & Fixes | Safe-area and composed-view obstruction mitigations across both platforms | All prior |
| 53 | Pre-Index Feasibility Assessment | Architecture document for hosted Quick-Start index; no code changes | 09 |
| 54–76 | [Various features and fixes] | See individual session files and git log for Sessions 54–76 | — |
| 77 | TEI Fidelity — Choice and Small Caps | `<choice>` suppresses `<sic>`; `<hi rend="smallcaps">` uses `lowercaseSmallCaps()` | 07 |
| 78 | TEI Fidelity — Inline Notes and Attachments | `<note rend="inline">` transparent; `<frus:attachment>` full pipeline; `IndexingPipeline` updated | 77 |
| 79 | TEI Fidelity — Title Page and Anonymous Block | `<titlePage>` → centred `.titlePageBlock`; `<ab>` → `.paragraph` | 78 |
| 80 | TEI Fidelity — Documentation Update | Version history and plan docs updated; no code changes | 79 |
| 81 | Collection Export — Rich Document Rendering | `DocumentRenderService`; `CollectionExportDocument` carries `FRUSDocumentRenderModel?`; PDF + HTML emit structured output | 07 |
| 82 | DOCX Export — Infrastructure | `DocxCollectionExporter`, ZipFoundation, Open XML helpers, cover page + plain-text bodies | 81 |
| 83 | DOCX Export — Rich Content + Italic Fix | `<w:rPr>` run formatting, Word footnotes, TOC; italic-in-collection-notes fix | 82 |
| 84 | Small UI Fixes | Remove macOS research-strip collapse; fix iOS storage index size | — |
| 85 | Handoff + Spotlight | `NSUserActivity` cross-device continuity; CoreSpotlight indexing | 09 |
| 86 | Citation Export (BibTeX / RIS) | `BibtexExporter`, `RISExporter`; export buttons in citation sheets | 13 |
| 87 | Person Index View | `PersonIndexView` grouped alphabetical list tapping into `personRef` search | 39 |
| 88 | Document Timeline View | `TimelineView` with Swift Charts `BarMark`; year grouping from `date_iso` | 36 |
| 89 | Cloud Sync — Collections Investigation | SwiftData/CloudKit `Collection` model fix; iPad Collections tab sync | 04 |
| 90 | Settings Parity — Assessment + Implementation | macOS ↔ iOS Settings feature comparison and gap closure | 46 |
| 91–92 | iOS Visual Identity | Shared `FRUSTheme`; apply macOS design patterns to iOS views | 44 |
| 93 | Dynamic Island / Live Activity | ActivityKit feasibility; slim progress banner fallback | 51 |
| 94–95 | Source Explorer — macOS | Port iOS NARA/lot-file/archive browser to macOS split-view idioms | 23 |
| 96–97 | Saved Searches + Smart Collections | `SavedSearch` model; smart Collection binding; dynamic export resolution | 16, 22 |
| 98–99 | Corpus Frequency Analytics | `CorpusAnalyticsService`; Swift Charts frequency views by year/subseries | 36, 09 |
| 100–101 | Research Session Log | `ResearchSession` + `SessionEvent` models; Activity tab timeline | 04 |
| 102–106 | Inline Highlighting + Passage-Anchored Notes | `DocumentHighlight` model; macOS + iOS text selection layers; CloudKit sync | 81 |
| 107–110 | iPadOS Split View + Stage Manager | `horizontalSizeClass` layout paths; multi-window scenes for iPad | 44 |
| 112 | Indexing Stage Accuracy | `IndexingStage` renamed to two honest phases; batch-N-of-M counter in FTS5 write loop | 51 |
| 113 | Live Discovery Feed | `VolumeMetadataDiscovered` event; person/date/xref/doctype counts in all progress views | 112 |
| 114 | Post-Index Summary Card | Auto-dismissing summary card with "Search this volume" action | 113 |
| 115 | Interrupted Indexing State | `IndexingStateTracker`; UserDefaults sentinel; amber partial-index badge; resume action; ReindexView "Needs Attention" | 112 |
| 116 | FRUS Context Card + Queue Banner | Era/series context card during indexing; multi-volume queue banner with ETA and pending list | 113, 115 | ✅ |
| 117 | Consolidate Downloads | Merge `DownloadManagerSettingsView` + `VolumeManagementView` → `DownloadsSettingsView`; remove Download Manager row | 49, 51, 70 | ✅ |
| 118 | Consolidate Storage & Index | Absorb Reindex All into `StorageManagementView`; remove standalone Reindex pane; rename Summarization Prompts row | 51, 67, 90 | ✅ |
| 119–127 | Bug fixes, polish, tooltips, search improvements, analytics | macOS search triple-result bug fixed; tag-save pipeline for iOS+macOS; iOS Add-to-Collection sheet; search tooltips; analytics polish; breadcrumb overlap fix | various | ✅ |
| 128 | Collection Export Improvements | Fix `_text_` italic markup in all 3 exporters; ToC label style picker (citation vs. header+dateline); per-document body/note content selection | 22, 81, 83 | ✅ |
| 140 | WebKit Migration — HTML Serializer | `FRUSRenderNodeHTMLSerializer`; all node types; `data-skip` attributes; `colspan`/`rowspan` tables; footnote `popover` markup; round-trip tests | 81, 128 |
| 141 | WebKit Migration — WKWebView Wrapper & Theming | `FRUSDocumentWebView`; `WKWebViewConfiguration` factory; HTML template; CSS bundle; `FRUSTheme` → CSS variable bridge; dark mode + Dynamic Type | 140 |
| 142 | WebKit Migration — Interactive Elements & Document View | `FRUSURLSchemeHandler`; footnote popover verification; replace `FRUSDocumentRenderer` in `DocumentView` + `MacDocumentView`; feature flag | 141 |
| 143 | WebKit Migration — JS Flat-Text Offset Engine | `frus-offset-engine.js`; Swift–JS offset equivalence test harness; `FRUSOffsetEngineTests` | 142 |
| 144 | WebKit Migration — CSS Custom Highlight API | `frus-highlights.js`; `CSS.highlights.set()` rendering; stale highlight amber overlay; stored highlight injection on page load | 143 |
| 145 | WebKit Migration — Highlight Selection & Creation | `frus-selection.js`; `selectionChanged` message handler; reverse offset mapping; `DocumentHighlightTextView` disabled | 144 |
| 146 | WebKit Migration — Collection Export Unification | Refactor `HTMLCollectionExporter` to use shared serializer; `frus-print.css`; footnote print layout | 140, 128 |
| 147 | WebKit Migration — Cleanup, Accessibility & Testing | Delete `FRUSDocumentRenderer` (1,117 lines) + `DocumentHighlightTextView` (646 lines); accessibility audit; VoiceOver testing; performance profiling | 142–146 |
| 148 | CloudKit Sync Silent Failures | Zone verification at launch; account status check; schema push; change token diagnostics; richer status bar error messaging | None |
| 149 | persName / gloss Detail Sheets Empty | Await persons/terms from SQLite before building render model; nil-guard tap callbacks; `.personNotFound` sheet case | None |
| 150 | Source Explorer — NARA API Resolution | CSV analysis of corpus citations; `NARACatalogLookupTable`; constrained API queries with naId parent filter; multiple candidate UI; specific error messages | None |
| 151 | Volume Front Matter — Phases 1–4 | Parser recognises `prefatoryNote`/`sources`/`persons`/`terms` divs; VolumeView splits "Front Matter" / "Contents" sections; CompilationView routes to `FrontMatterPersonsView` and `VolumeSourcesView`; `isFrontMatter` propagates through AST → `document_cache.is_front_matter`; `SearchParameters.includeFrontMatter` toggle wired through SearchService, SearchViewModel, and SearchFilterView | 07, 09, 16, 34, 41 |
| 152 | Volume Front Matter — macOS Corpus Browser | `CorpusVolumeDetailSheet.structureView` now splits sections into "Front Matter" / "Contents" headers (mirrors VolumeView); `CorpusSectionDocumentListView` routes persons → `FrontMatterPersonsView`, sources → `VolumeSourcesView`, prose → "Read" button; `<abbr>` glossary popovers via `abbrLookup` in `ASTToRenderNodeConverter`; "Front Matter" badge in search results (iOS + macOS); build 17 | 151 |

---

## Dependency Graph (simplified)

```
01 ──┬── 02 ──── 05 ──┬── 10
     │               │
     ├── 03 ──────────┤
     │               │
     ├── 04 ──────────┼── 08 ──── 09 ──┬── 16 ──┐
     │               │               │          │
     └── 06 ──── 07 ─┤               ├── 17 ── 18
                     │               │
                     └── 11          └── 21

12 ──┬── 13
     ├── 14 ── 15 ── 16
     ├── 18
     ├── 20 ── 21
     ├── 22
     └── 23

07 ──┐
09 ──┼── 30 (Citation Lookup) ── 31 (Final Testing)
12 ──┤
16 ──┘

31 → 32 (Breadcrumbs/Reset/Icon) → 33 (Auto-index) → 34 (Front Matter)
     └→ 35 (macOS Compat)

35 → 36 (Structured Dates) → 37 (XRef Context) → 38 (Editorial Notes)
       ┌──────────────────────────────────────────────────────┘
       └→ 39 (Person Mentions Data) → 40 (Person UI) → 41 (Glossaries)
                                                       ↑
                                                      42 (Footnote @n) [independent]

41 → 43 (Nav State Shell) → 44 (Full Wiring) → 45 (Polish) ──┐
                                                               ├── 47 (Docs)
                                                     46 (macOS) ─┘

47 → 48 (DB/Infra Bugs) → 49 (Onboarding) → 50 (Browser Polish)
                       └→ 51 (Indexing Perf) → 52 (UI Obstruction Audit)
                                               ↑
                                        53 (Pre-Index Feasibility) [parallel, no code]
```

---

## Task File Index

Present these files to Claude Code in order. The leading number matches the session number(s) inside each file.

| File | Sessions |
|---|---|
| `01-Project-Setup.md` | 01 |
| `02-Manifest-Generator.md` | 02 |
| `03-FTS5-Wrapper.md` | 03 |
| `04-08-Models-Parser-Tags.md` | 04, 05, 06, 07, 08 |
| `09-16-Search-Views.md` | 09, 10, 11, 12, 13, 14, 15, 16 |
| `17-24-Graph-AI-Export-Settings.md` | 17, 18, 19, 20, 21, 22, 23, 24 |
| `25-29-Polish-Audit-Distribution.md` | 25, 26, 27, 28, 29 |
| `30-Citation-Lookup.md` | 30 |
| `31-Final-Integration-Testing.md` | 31 |
| `32-35-Breadcrumbs-AutoIndex-FrontMatter-macOSCompat.md` | 32, 33, 34, 35 |
| `36-42-Extended-Indexing.md` | 36, 37, 38, 39, 40, 41, 42 |
| `43-46-Navigation-Redesign.md` | 43, 44, 45, 46 |
| `48-53-Fixes-Onboarding-Polish-Performance.md` | 48, 49, 50, 51, 52, 53 |
| `77-80-TEI-Fidelity-Improvements.md` | 77, 78, 79, 80 |
| `81-88-Exports-Quick-Wins.md` | 81, 82, 83, 84, 85, 86, 87, 88 |
| `89-110-Medium-And-Long-Term.md` | 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110 |
| `112-116-Indexing-UX.md` | 112, 113, 114, 115, 116 |
| `117-118-Settings-Consolidation.md` | 117, 118 |

---

## Notes for All Sessions

- Read `FRUS-Explorer-Specification.md` before beginning any session
- All code must compile under Swift 6 strict concurrency checking
- All user-facing strings must use `String(localized:)`
- All new types and functions require documentation comments
- `#if DEBUG` telemetry logging required for all significant operations
- Update `FRUS-API.openapi.yaml` if the session touches GitHub API or local volume data
- Run all existing tests before committing session output
- Each session produces its own unit tests

---

## Implementation Notes for All Sessions

### `lastModified` must be updated explicitly at the call site
`@Model` transforms stored properties into computed properties backed by persistent storage. `didSet`/`willSet` observers are syntactically accepted but do not fire reliably in practice. Any code that writes to a SwiftData model must set `instance.lastModified = .now` explicitly at the mutation site — never rely on an observer to do it automatically. This applies to every model type that carries `lastModified` (Session 04 models and any new models added in later sessions).

---

## Cross-Session Dependency Additions

The following items were added to earlier sessions by later feature requirements. Confirm they are implemented in the named session before beginning the dependent session.

### Session 07 — TEI Parser Full Coverage
**Added by Session 30 (Citation Lookup)**:
- `<pb>` element must be surfaced in the AST as `pageBreak(pageNumber: PageNumber)`
- `PageNumber` enum: `.arabic(Int)`, `.roman(Int)`, `.prefixed(String)`, `.unparseable(String)`
- Normalization rules for `@n` attribute values documented in Session 31 task file

### Session 09 — Search Index Pipeline
**Added by Session 30 (Citation Lookup)**:
- `page_ranges` SQLite table built during indexing pass alongside cross-reference edge table
- Schema and index definitions documented in Session 31 task file
- Population logic: extract `<pb>` nodes from AST, record document containment and section grouping
- `FRUS-API.openapi.yaml` updated with `GET /volumes/{volumeId}/page-ranges`

**Added by Sessions 36–39 (Extended Indexing)**:
- `document_dates` populated from `<date>` attribute extraction rather than plain-text heuristic
- `person_mentions` table added alongside existing tables; `removeVolume` must delete from it
- `is_editorial_note` column added to `document_cache` and the FTS5 virtual table
- `persons` and `terms` tables added; `removeVolume` must delete from both

### Session 07 — TEI Parser Full Coverage
**Added by Sessions 36 and 42 (Extended Indexing)**:
- `<date>` element mapped to `.date(when:from:to:notBefore:notAfter:children:)` AST node
- `<note @n>` attribute captured as `printedNumber: String?` on `.footnote` case (breaking change; all switch sites must add `printedNumber: nil` default)

### Session 12 — Document View Core
**Added by Session 40 (Person Mention UI)**:
- `PersonDetailSheet` must accept a `PersonMentionStore` dependency for mention count display
- "Find all mentions" button writes `appState.pendingSearch`; `BrowserView` must observe this property

### Session 09 — Search Index Pipeline
**Added by Session 48 (DB Bug Fix)**:
- `frus_documents` FTS5 virtual table schema version promoted to 3 with `is_editorial_note UNINDEXED` column
- `PRAGMA user_version` gating strategy documented in `48-53-Fixes-Onboarding-Polish-Performance.md`
- `UserDefaults("frus.ftsSchemaVersion")` migration flag triggers background re-index on first post-upgrade launch

### Session 10 — Onboarding View
**Replaced by Session 49 (Onboarding Redesign)**:
- Three-step onboarding (`DownloadScopePickerView`) replaces old subseries/subject picker flow
- `ManifestStore.corpusDateRange` must be implemented before Session 49 (`minYear=1861`, `maxYear=1992`)
- `DownloadScope` enum (`.corpus`, `.subseries(String)`, `.volume(String)`) added to `DownloadManager`

### Session 09 — Search Index Pipeline
**Added by Session 151 (Volume Front Matter)**:
- `is_front_matter INTEGER NOT NULL DEFAULT 0` column added to `document_cache` (idempotent `ALTER TABLE` migration)
- `frontMatterDocumentKeys(limitToVolumeIds:) -> Set<String>` query added to `IndexingPipeline`
- `DocumentCacheRow.isFrontMatter` field populated from `FRUSDocumentAST.isFrontMatter` during `parseAndExtract`
- `TEIParserDelegate.frontMatterDivTypes` set controls which promoted quasi-documents receive `isFrontMatter = true`
- Volumes indexed before this change have `is_front_matter = 0`; re-index is required for the toggle to take effect

### Session 07 — TEI Parser Full Coverage
**Added by Session 151 (Volume Front Matter)**:
- `VolumeStructureParserDelegate.structuralTypes` extended with `"prefatoryNote"`, `"sources"`, `"persons"`, `"terms"`
- `TEIParserDelegate.structuralDivTypes` extended with `"prefatoryNote"`, `"terms"` (sources/persons handled via specialised tables)
- `FRUSDocumentAST.isFrontMatter: Bool` field added (default `false`); set to `true` for promoted front-matter prose divs
- `humanTitle(for:)` extended with display labels for the four new types

### Session 16 — Search View
**Added by Session 151 (Volume Front Matter)**:
- `SearchParameters.includeFrontMatter: Bool` (default `true`) controls whether front-matter quasi-documents appear in results
- `SearchFilterView` exposes an "Include front matter" toggle in the Search Scope section
- `SearchViewModel.includeFrontMatter` wired into `searchParameters`, `hasActiveFilters`, `clearFilters()`, `applyParameters(_:)`

### Session 34 — Front Matter Browser Support
**Extended by Session 151 (Volume Front Matter)**:
- `CompilationView.canReadSectionDirectly` extended to include `"prefatoryNote"` and `"terms"`
- `CompilationView` routes `"persons"` → `FrontMatterPersonsView` and `"sources"` → `VolumeSourcesView`
- `VolumeView.volumeStructureSection` split into "Front Matter" and "Contents" `Section`s
- `PersonIndexDetailSheet` visibility widened from `private` → `internal` for use in `FrontMatterPersonsView`
- New files: `FrontMatterPersonsView.swift`, `VolumeSourcesView.swift`

### Session 32 — Breadcrumbs
**Superseded by Session 50 (Browser Polish)**:
- `BrowserBreadcrumbBar` `ScrollView(.horizontal)` wrapper replaced with `BreadcrumbFlowLayout`
- Multi-line display; no truncation; height is dynamic (`.safeAreaInset` inset must track actual height)

### Session 2026-06-09 — Data Infrastructure Overhaul (Phases 1–3)

**Phase 1 — correctness/stability fixes:**
- `FTS5Store.delete(documentId:)` → `delete(documentId:volumeId:)`: FRUS document IDs ("d1") repeat per volume, so the unscoped delete removed rows from *every* volume on each summary/note/tag update and per-document volume removal. `IndexingPipeline.removeVolume` switched to a volume-scoped delete. Regression tests in `FTS5StoreTests` + `RemoveVolumeTests`.
- `PRAGMA busy_timeout = 5000` on all five SQLite connections (FTS5Connection, IndexingPipeline auxDb, CrossReferenceStore, PersonMentionStore, PageRangeStore) — concurrent writers previously got instant `SQLITE_BUSY` that `try?` callers swallowed.
- `DownloadManager.onVolumeDeleted` callback wired in `FRUSExplorerApp` → `IndexingPipeline.removeVolume` + AST-cache eviction. The `.frusVolumeDeleted` notification had no observer, so the iOS Downloads settings delete path orphaned index data.

**Phase 2 — external-content FTS5 redesign (schema generation 4):**
- `frus_documents` is now an external-content FTS5 table over `document_cache` using the built-in `porter unicode61` tokenizer; application-layer Porter stemming removed from index and query paths (`stemForIndex` deleted; `FTS5Query`/`FTS5InlineQueryParser` render quoted, unstemmed terms).
- New `user_content` FTS5 table (summary_text, note_text) over the same `document_cache` rows — note/summary edits re-tokenize only user text; corpus index rows are immutable outside indexing.
- Index maintenance via generated SQL triggers (`FTS5Schema.externalContentTriggerSQL`); `document_cache` is the single write path. Re-index UPSERTs preserve rowids and user fields (`INSERT OR REPLACE` previously wiped summaries/notes/tags on every re-index).
- Migration: `PRAGMA user_version` 3→4 drops the legacy table; `rebuildSearchIndexFromCache()` rebuilds both FTS5 tables from `document_cache` via the FTS5 `rebuild` command — no XML re-parse — and restores rows lost to the unscoped-delete bug. `currentFTSSchemaVersion = 4`; date-index version stays 6.
- DB shrinks by roughly the stemmed text copy (~⅓); search result display fields come back unstemmed directly.

**Phase 3 — performance/capability:**
- `IndexingPipeline.searchDocuments`/`searchDocumentsCount`: single-statement combined corpus + user-content search (rowid merge, MIN(bm25)) with all filters (volume, date overlap, front matter, person, subject/user tags, document type) in SQL — exact pagination, no overscan, accurate counts. `SearchService` rewritten around it; key-set whitelists and display-repair pass deleted.
- `volume_structures` table: Browser structure JSON persisted during indexing (structure delegate joined `parseVolumeFull`'s composite); `BrowserViewModel`/macOS corpus browser read it instead of re-parsing XML.
- `DocumentASTCache` (LRU, 24 entries, memory-warning flush) + `parseDocumentWindow(documentId:volumeURL:trailingDocuments:)`: document opens warm the cache with the parse window (prefix tail + target + 1 trailing), making page-turns/re-opens instant.
- `indexVolume` runs a bounded FTS5 `merge` (quota 64) instead of full `optimize()` (which is O(total index) and would stall every download on a large corpus); `indexAllVolumes` keeps the single post-batch optimize.
- Boot-time SwiftData→index sync is now skip-if-unchanged (`updateCacheColumns` value guard: zero-row UPDATE fires no triggers).
- `BackgroundDownloadEngine`: volume downloads moved to a background `URLSession` — transfers survive suspension/termination, are re-adopted at launch (`resumeQueuedDownloads`), retried (≤2, linear backoff); `FRUSAppDelegate` handles background-session relaunch events; boot reconciliation indexes downloaded-but-unindexed volumes.

**Verification:** 699/703 app tests pass (4 pre-existing failures in CitationFormatterTests/SourceExplorerTests, unrelated — see chip); 127/127 SPM tests; iOS + macOS targets build clean.

### Session 2026-06-09 (follow-up) — Pre-existing Test Failures Fixed
- **SourceExplorerTests (3 stale tests):** commit 39b3ef6 intentionally consolidated the seven NARA decimal-file sub-period URLs onto the `…/rg-59-central-files/1910-1963` parent page (sub-period pages return HTTP 404, verified live 2026-06-04) but missed the tests. Tests updated to pin the consolidated URL (`hasSuffix` check) while asserting period-specific *labels* ("1945–1949", "1910–1929", "1960–January 1963") remain.
- **CitationFormatterTests (1 code regression):** commit f886282 added a `documentId` fallback to `HistoryAtStateCitationFormatter` so citations "always include a locator" — leaking TEI `xml:id`s ("edn-01") into formatted citations for editorial notes and unnumbered documents, contradicting the formatter's own documented history.state.gov style. Fallback removed: no printed document number → citation ends after the publication parenthetical. BibTeX/RIS note fields and page-turn UI labels intentionally keep the `documentId` (metadata/affordance, not citation text).
- Full FRUSExplorerTests bundle: 703/703 passing.

### Session 2026-06-10 — Corpus Browser: Real TEI Vocabulary Fix
**Root cause:** the published corpus encodes front/back matter as `<div type="section" subtype="…" xml:id="…">` and editorial notes as `<div type="document" subtype="editorial-note">`, but the structure parser, quasi-document promotion, editorial-note detection, and sources extraction all keyed on literal `type` values (`type="preface"`, `type="editorialNote"`, …) that exist only in the app's test fixtures. Verified against nine real volumes spanning 1861–1988 (zero unknown `type` values remain).
- `VolumeStructureParserDelegate.structuralKind(type:subtype:xmlId:)`: resolves effective section kinds from the real encoding; persons/terms glossaries disambiguated from `subtype="index"` by `xml:id` (the pattern PersonsParserDelegate/TermsParserDelegate already used); 1861-era `type="toc"` normalised to `"table-of-contents"`. Unknown wrapper divs now push *transparent frames* whose children bubble to the parent — previously every unmatched `</div>` popped the current frame, detaching the `<front>` wrapper from its sections in every real volume.
- Editorial notes detected via `subtype="editorial-note"` (legacy `type="editorialNote"` branch retained for fixtures): badges, italic rows, document-type search filter, and `is_editorial_note` now work on real data.
- Quasi-document promotion keys on effective kinds: preface/errata/press-release/volume-summary/about-frus-series/historical-document sections are indexed with `is_front_matter = 1`; persons/sources (structured views) and table-of-contents/index (navigation noise) excluded by design.
- `SourcesParserDelegate` triggers on `subtype`/`xml:id` "sources" → `volume_sources` populates on real volumes.
- Kind routing centralised on `VolumeSection` (`frontMatterKinds`, `proseReadableKinds`, `canReadDirectly`, `isPersonsList`, `isSourcesList`), replacing four "keep in sync" copies across `VolumeView`, `CompilationView`, and the macOS corpus browser. Both platforms gain a Back Matter group with `<back>` wrapper expansion; new kind labels (Table of Contents, Press Release, Volume Summary, About the Series, Index).
- `currentDateIndexVersion` 6 → 7: parse output changed, full XML re-parse repopulates editorial flags, front-matter quasi-documents, volume structures, and sources.
- New `RealCorpusEncodingTests` suite uses fixtures in the *real* encoding so vocabulary regressions can no longer pass CI. 708/708 app tests; SPM unaffected.
