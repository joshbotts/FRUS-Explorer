# FRUS Explorer — Development Plan

**Version**: 1.7  
**Date**: 2026-06-15

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

### Session 2026-06-10 (2) — Research Feature Fixes
Findings from the research-features review (highlighting, tags, notes, collections, export, summarization, cross-reference graph, source explorer on both platforms):
- **iOS "Add Note to Highlight" restored** — `pendingHighlightLink` was set after highlight creation and the `.noteEditorForHighlight` sheet case existed, but nothing ever presented it (lost in the Session 2026-06-07 toolbar consolidation). A transient toolbar button now appears after a highlight is created, mirroring the macOS research strip; one-shot, cleared on document change.
- **Summarization failures surface to the user** — `DocumentViewModel.summarizationError` is set in the `generateSummary` catch (previously print-only). iOS shows an alert (visible even in Read mode); the macOS `SummaryBlockView` shows the error inline. New `SummarizationErrorSurfacingTests` regression test with a failing provider.
- **Apple Intelligence availability gating** — `SummaryBlockView` (macOS) hides Change prompt/Regenerate/Summarize and shows an explanation when `SystemLanguageModel` is unavailable (Intel Macs, AI disabled); existing iCloud-synced summaries still display. The iOS summary accordion's empty state (which pointed at the removed "More" menu) is now an availability-gated "Summarize this Document" button, a progress row while generating, or the unavailability explanation.
- **Selection edit menu (iOS)** — new `_FRUSEditMenuWebView` subclass adds "Highlight" and "Look Up in NARA Catalog" to the text-selection edit menu via `buildMenu(with:)` (context menu system only — the iPad keyboard menu bar is untouched). Highlight is gated to selections with valid in-document offsets. The conditional NARA toolbar item (which popped in/out of the overflow menu with selection changes) is removed; the duplicate `.sheet(isPresented: $showHighlightColorPicker)` on the toolbar button is consolidated onto the main content chain so the colour picker presents reliably from both entry points.
- 709/709 app tests; both platforms build clean.

### Session 2026-06-10 (3) — Settings Cleanup
From the settings review (every stored preference traced to its consumers):
- **Search Defaults wired (was dead on both platforms):** new `SearchDefaults` enum (SearchModels) holds the `frus.search.*` keys and typed accessors. `SearchViewModel` seeds its scope/type-filter properties from it and `clearFilters()` resets to the configured defaults; `MacSearchViewModel` gains an initialiser that applies the defaults to both the scope toggles and `parameters` (property observers don't fire during init). Both settings panes now reference the shared key constants. Regression test: `SearchDefaultsWiringTests`.
- **Download concurrency wired (was a key mismatch):** boot read `"downloadConcurrencyLimit"` while the iOS picker wrote `"frus.concurrentDownloadLimit"` — the setting never took effect. Boot now reads `SettingsKeys.concurrentDownloadLimit`; `DownloadManager.setConcurrencyLimit(_:)` (clamped 1…8) applies changes live, kicking `processQueue()`; the iOS picker applies immediately (note text updated from "takes effect on next launch"); macOS gains the missing control in the Add Volumes pane.
- **Removed dead "Show Document Numbers" toggle** (both platforms) — `frus.display.showDocumentNumbers` had no consumer.
- **Removed dead macOS "Enable AI summarization" toggle** — `frus.summarization.enabled` had no consumer. The pane's unavailability notice now keys on `AppleIntelligenceProvider.isAvailable` (the old check `summarizationService == nil` was always false) and explains that prompts still sync to other devices.
- **Storage limit removed, reporting retained:** the advisory-only GB limit (enforced only for settings-initiated batch downloads) is gone from both platforms — pickers, projected-usage gates, and "Download Anyway" dialogs. Storage *reporting* stays: aggregate + per-volume breakdowns on both platforms, with the corpus-size guidance (~3.4 GB XML + ~9–10 GB index) kept as caption text, and the macOS Manage Storage sheet now has a persistent "Manage Storage…" button (its only previous trigger was the removed advisory card).
- 710/710 app tests; both platforms build clean.

### Session 153 — iOS ↔ macOS Feature Parity
Five gaps closed between the iOS and macOS builds (`153-iOS-macOS-Feature-Parity.md`):
- **Persisted citation styles (Task 3):** Chicago and Turabian formatting, previously inline `@State`-only logic in the macOS citation popover, are now `ChicagoCitationFormatter`/`TurabianCitationFormatter` conformers in `Citation/CitationFormatter.swift` alongside `HistoryAtStateCitationFormatter`. New `CitationStyle.current` (backed by `SettingsKeys.citationStyle = "frus.citation.style"`, default `.historyAtState`) drives `DocumentViewModel.formattedCitation`/`plainTextFormattedCitation`/`shareableCitationMessage` and the iOS `CitationSheetView` on both platforms; a "Citations" picker is in Settings → Display on both platforms. The macOS popover keeps its per-presentation segmented-control override, now seeded from `CitationStyle.current` and using the shared formatters. Both Chicago/Turabian formatters preserve the no-document-number handling from the Session 2026-06-09 editorial-note fix (no leaked `xml:id`s). `CitationFormatterTests` extended with Chicago/Turabian fixtures.
- **Project delete/merge on iOS (Task 1):** new `ProjectAdminService` (`ProjectContext/ProjectAdminService.swift`, `internal` — `Project`/`AppState` are internal types) extracts the delete/merge SwiftData mutations from macOS `SettingsProjectsPane` (delete orphans referencing `ResearchNote`/`Collection`/`GeneratedSummary`/`ReadingHistoryEntry` rows rather than deleting them; merge reassigns those references and redirects `AppState.activeProjectId`). iOS gains a "Projects" group in Settings (`ProjectsSettingsView`, mirroring `UserTagsView`'s list/swipe/context-menu pattern); macOS `SettingsProjectsPane` switched to the shared service with no behaviour change. New `ProjectAdminServiceTests` (7 tests).
- **Local-only reset on iOS (Task 2):** new shared `Settings/ResetService.swift` extracts the macOS local-reset path (delete downloaded volume XML + clear the FTS5 index via `IndexingPipeline.removeAllVolumesFromIndex()` + return to onboarding), deliberately leaving the SwiftData store, `UserDefaults`, the iCloud-Keychain-synced NARA API key, and the CloudKit zone untouched. iOS `ResetView` gains a three-tier ordering — **Sync** → **Local** (new, via `ResetService`) → **Full** — with confirmation copy stating iCloud data survives and re-syncs. macOS `SettingsResetPane` and iOS's full-reset path both now call the shared helper for the volume+index step.
- **NARA API usage counter on iOS (Task 4):** iOS `NARAKeyView` gains a "Usage (Last 30 Days)" section sourced from `NARAAPIKeyStore.shared.callCountLast30Days`, mirroring macOS `SettingsNARAPane`.
- **Volume connection graph on iOS (Task 5):** `VolumeConnectionGraphView` (already cross-platform — one conditional `.onHover`) is now reachable from `VolumeView`'s toolbar via a `point.3.connected.trianglepath.dotted` button (matching the macOS corpus browser affordance), disabled with an accessibility hint when the volume isn't indexed. Presented in a `NavigationStack` + Done button sheet with `.presentationDetents([.medium, .large])`, mirroring `DocumentSheet.crossReferenceGraph`'s sizing.
- Fixed a latent macOS build break in `ProjectsSettingsView` introduced by Task 1 (`.navigationBarTitleDisplayMode` needs an `#if os(iOS)` guard — `SettingsView.swift` is type-checked for both targets).
- 729/729 `FRUSExplorerTests`; both iOS and macOS targets build clean. (`UIObstructionTests` has 3 pre-existing failures from a `simctl`-not-found environment issue, unrelated to this session.)

### Session 154 — Configuration & Maintenance Needs
Six independent gaps closed from the 2026-06-10 settings review (`154-Configuration-And-Maintenance.md`), in the suggested order:
- **Cellular download policy (Task 1, iOS):** new `SettingsKeys.allowCellularDownloads` (`"frus.downloads.allowCellular"`, default `true`). `BackgroundDownloadEngine.startDownload(volumeId:from:allowsCellular:)` and `DownloadManager.performTestDownload` now set `URLRequest.allowsCellularAccess` per-request from the stored preference, read once per `processQueue()` pass. Toggle added to iOS `DownloadsSettingsView` "Settings" section.
- **Reading preferences (Task 4, both platforms):** new "Reading" group under Display settings. `SettingsKeys.edgeTapNavigationEnabled` (default on) gates `DocumentView.documentEdgeNavigationOverlay`'s page-turn tap zones. `SettingsKeys.defaultDocumentMode` (new `DefaultDocumentMode` enum: `.read` / `.research` / `.rememberLast`, default `.rememberLast`) is applied to `panelVisible` once per document open in both iOS `DocumentView` and macOS `MacDocumentView`; `.rememberLast` preserves the existing `frus.document.researchPanel.visible` cross-document persistence, while `.read`/`.research` force a fixed mode (the in-document segmented control still overrides live for that document).
- **Live Activity opt-out (Task 6, iOS):** new `SettingsKeys.liveActivityEnabled` (default on), toggle near the indexing/storage rows. `AppState.syncIndexingLiveActivity` checks the preference before requesting/updating an indexing Live Activity and ends any already-running activity if the user disables it mid-index.
- **Index & Spotlight maintenance (Task 5, both platforms):** new `IndexingPipeline.checkIndexIntegrity()` runs `PRAGMA quick_check` plus an FTS5 `integrity-check` (rank=1) against `frus_documents` and `user_content`, returning a list of problem strings (empty list = "No problems found"). New `IndexingPipeline.rebuildSpotlightIndex()` clears the Spotlight index via `CSSearchableIndex.deleteAllSearchableItems()` and re-submits `document_cache` rows in batches of 500 without re-parsing volume XML, sharing a new `makeSearchableItem` helper with `submitSpotlightItems(for:)`. Both actions are buttons in the Storage settings pane on iOS and macOS. New `IndexIntegrityTests` (clean fixture + a deliberately-corrupted-table fixture).
- **Upstream volume update detection (Task 3, both platforms):** `ManifestStore.fetchLiveManifest()` now decodes each GitHub listing entry's git blob `sha`; `ManifestDiffResult.liveInfoByVolumeId: [String: LiveVolumeInfo]` (sha + size) is exposed for `known` volumes. New `Downloads/VolumeUpdateChecker.swift` plus `DownloadManager.gitBlobSHA1(for:)` (computes `sha1("blob <len>\0" + bytes)`, matching GitHub's format) and `blobSHA(for:)`/`localVolumeInfo(for:)`, cached per-volume in `UserDefaults` and invalidated on delete/re-download. `VolumeUpdateChecker.hasUpdate(local:live:)` compares blob SHAs (falling back to byte size if no local SHA is cached yet), and `updatableVolumes(known:liveInfoByVolumeId:downloadManager:)` scans downloaded volumes for upstream corrections. `DownloadManager.enqueueDownload(volumeId:downloadUrl:force:)` gained `force` to re-queue and overwrite an already-downloaded volume. Both Downloads settings surfaces gain an "Updates Available" section with per-volume "Update" and "Update All" actions; the existing UPSERT re-index path preserves user notes/summaries/tags. New `VolumeUpdateCheckerTests` (8 tests: SHA computation checked against `git hash-object`, comparison logic, orchestration).
- **Research data export (Task 2, both platforms):** new `Export/ResearchDataExporter.swift` builds a versioned (`formatVersion`) `ResearchDataEnvelope` of Codable DTOs — research notes (with `linkedHighlightIds`), tags, tag assignments, highlights, collections (with ordered entries), user-created prompts, projects, and optionally `GeneratedSummary` — serialized as pretty-printed, key-sorted JSON with ISO-8601 dates. A second `markdownExports(notes:tags:appState:)` renders one Markdown file per note with YAML front matter (canonical `history.state.gov` URL, citation when the source volume is indexed, tags, timestamps) for Obsidian-style tools. iOS gains Settings → Data → "Export Research Data…" (`ResearchDataExportView`, `ShareLink`-based for both the JSON file and the per-note Markdown files); macOS gains a Data pane in Advanced settings (`SettingsDataPane`: `NSSavePanel` for JSON, `NSOpenPanel` folder picker for Markdown). Import is out of scope — `formatVersion` exists for a future importer. New `ResearchDataExporterTests` (6 tests: envelope contents/filtering, highlight linkage, JSON round-trip idempotency, schema-key snapshot, Markdown front matter).
- 751/751 `FRUSExplorerTests`; both iOS and macOS targets build clean. (`UIObstructionTests` has 3 pre-existing failures from a `simctl`-not-found environment issue, unrelated to this session.)

### Session 155 — Zotero Export (Options A + B)
Implements `Planning/BigPicture-ZoteroExport.md` Options A and B for both platforms (`155-Zotero-Export.md`):
- **Option A — "Send to Zotero (BibTeX)…"** (both platforms): shares/saves a `.bib` file from the existing `BibtexExporter`. iOS `CitationSheetView` and macOS `CitationPopoverView` Export menus gain "Copy BibTeX"/"Copy RIS" plus this share action, alongside the existing "Save as .bib…".
- **Option B — "Send to Zotero (JSON)…"**, wired to the **Document View** (both platforms): new `Citation/ZoteroJSONExporter.swift` builds a `bookSection` item per document in Zotero's JSON exchange format (`{"version": 5, "items": [...]}`), with `creators` from `volume.editors`, `extra` carrying "Editorial note"/"Document date:" lines, and `tags`/`notes` resolved from `UserTag`/`DocumentTagAssignment`/`ResearchNote` via `ZoteroJSONExporter.fetchTagsAndNotes`. `DocumentViewModel` gains `bibtexCitation`, `risCitation`, and `zoteroItem(tags:notes:)`. iOS shares the generated `.json` file via `ShareLink`; macOS saves it via `NSSavePanel` and opens Zotero (or reveals it in Finder) via the new `sendToZoteroJSON`/`sendToZoteroBibtex`/`sendToZotero` helpers in `CitationPopoverView`.
- **Option B at the Collection level**: per the research finding that Zotero's `items` array natively supports multiple items (i.e. already "a collection of items"), `ExportFormat.zoteroJSON` + new `Collections/ZoteroCollectionExporter.swift` write one multi-item Zotero JSON file per FRUS Explorer collection. `CollectionExportDocument.zoteroItem` is populated by both `CollectionEditorView.resolveDocuments()` and `.resolveSmartDocuments()`; `options.includeNotes == false` strips child notes from every item. `isEditorialNote: false` is a deliberate simplification at this scope (collection entries don't carry that flag).
- New `ZoteroJSONExporterTests` (9 tests): `makeItem` field mapping (title/document-number formatting, editorial-note and dateline `extra`, tags/notes, omission of empty collections), `exportData` round trip and schema-key check, `fetchTagsAndNotes` against an in-memory `ModelContainer`.
- 760/760 `FRUSExplorerTests`; both iOS and macOS targets build clean. (`UIObstructionTests` has 3 pre-existing failures from a `simctl`-not-found environment issue, unrelated to this session.)

### Session 156 — UIObstructionTests Fixes
**Correction:** Sessions 153–155 each carried a note attributing 3 `UIObstructionTests` failures to "a `simctl`-not-found environment issue, unrelated to this session." That was wrong on two counts — the suite ran fine once `DEVELOPER_DIR` was set, and all three failures had real causes (one a genuine routing regression, one a flaky test assertion, one a real dead-button bug). All three are now fixed and the suite passes.

- **`testBreadcrumbBarNotObstructingFirstRow`:** `ContentView`'s onboarding/main-UI routing check (`hasCompletedOnboarding && (hasVolumes || hasActiveDownloads)`) had no allowance for UI tests, which launch with `-hasCompletedOnboarding 1` but no downloaded volumes — the app silently stayed on `OnboardingView` and every `MainTabView`/`MainWindowView` element lookup failed. `ContentView` now also accepts `ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1"` as a third routing condition.
- **`testTabBarNotObstructingLastBrowserRow`:** the corpus list's last row does become `isHittable` once scrolled to true rest, but the iOS 18 floating tab bar's deceleration/rubber-band animation continues for several swipes after `swipeUp()` returns — two fixed swipes left the row in a transient, non-final position. The test now swipes with a 0.5 s settle delay in a bounded retry loop (≤15 attempts) until the last row is hittable, asserting on that outcome instead of a fixed-count scroll. No production change needed.
- **`testKeyboardDoesNotCoverProjectNameField` → `testKeyboardDoesNotCoverCitationLookupField`:** the test exercised "Activity tab → New Project", a flow that no longer exists on iOS (Activity was renamed to Research in Session 130, and project creation is macOS-only). While building a replacement around Citation Lookup, found that **"Find by citation" was a real dead button**: `SearchTabView`'s `.toolbar`/`.sheet` were applied to `SearchView`, but `SearchView` (since its Session 2026-06-08 toolbar restructure) owns its own `NavigationStack` and toolbar — a `.toolbar` modifier applied outside that stack never reaches the nav bar, so the button was rendered nowhere (not even in the overflow menu). Moved "Find by citation" + its `CitationLookupView` sheet into `SearchView`'s own "More search actions" menu (`SearchView.swift` 1.11); removed the dead toolbar/state/sheet from `SearchTabView` (`MainTabView.swift` 1.1). The rewritten test opens Search → "More search actions" → "Find by citation" and verifies the paste-citation field stays hittable above the keyboard.
- 760/760 `FRUSExplorerTests`; `UIObstructionTests` 3/3 pass; both iOS and macOS targets build clean.

### Session 157 — Collection Zotero Export: Editorial-Note Flag
Fixes a fidelity gap from Session 155 (flagged in the 2026-06-11 commit review): `CollectionEditorView.resolveDocuments()` and `.resolveSmartDocuments()` built Zotero items with `isEditorialNote: false` hardcoded, so editorial notes exported via a collection lost the "Editorial note" `extra` line that the document-level export (`DocumentViewModel.zoteroItem`) includes.

- New `ZoteroJSONExporter.editorialNoteFlags(volumeIds:pipeline:)` resolves the flag from `document_cache.is_editorial_note` via `IndexingPipeline.documents(forVolume:)`, returning a `"<volumeId>/<documentId>" → true` map (unindexed volumes contribute no entries, degrading to `false` — the same knowledge boundary as the document-level path, whose `DocumentBrowserEntry` also comes from the index).
- Both collection resolve paths call it once per export and pass `flags[key] ?? false` into `makeItem` (`CollectionEditorView` 1.7).
- New test in `RealCorpusEncodingTests` (`collectionZoteroExportFlagsEditorialNotes`): indexes the real-encoding fixture, asserts d1 (`subtype="editorial-note"`) is flagged and d2 isn't, asserts an unindexed volume yields no entries, and verifies end to end that the resulting items carry "Editorial note" in `extra` for d1 only.

### Session 158 — Commit-Review Follow-Up Fixes
Remaining minor findings from the 2026-06-11 review of the 2026-06-10 commits, all robustness/hygiene (no behaviour changes for well-formed data):
- **Project merge reassigns `SearchHistoryEntry.projectId`** (`ProjectAdminService` 1.1): previously left dangling at the deleted source project's id — a pre-existing macOS gap faithfully carried into the Session 153 extraction. Delete still orphans by design ("kept but unlinked"). `mergeReassignsScalarProjectIds` extended to cover it, including a target-owned entry that must not change.
- **Live-manifest `sha` decode is tolerant** (`ManifestStore`): `GitHubLiveEntry.sha` is now optional, so one anomalous GitHub listing entry degrades to "no update detection for that volume" instead of failing the entire live-manifest decode (and with it newly-available detection and download URLs).
- **`rebuildSpotlightIndex` no longer holds an open SQLite statement across `await`**: each 500-row batch is read via keyset pagination on `rowid` with its own statement, fully stepped and finalized before the `CSSearchableIndex` submission suspends — the actor is reentrant, so a concurrent Delete Index & Rebuild could previously have mutated the database mid-iteration.
- **Markdown export YAML is quoting-safe** (`ResearchDataExporter.yamlQuoted`): tag names and citations are emitted as double-quoted YAML scalars with backslash/quote escaping — user-authored tag names can contain `:`/`"`/`]`, which break unquoted flow-sequence entries. Test expectation updated to the quoted form.
- **Tag-id dictionaries use `uniquingKeysWith:`** (`ZoteroJSONExporter.fetchTagsAndNotes`, `ResearchDataExporter.markdownExports`): `uniqueKeysWithValues:` would crash if CloudKit sync transiently surfaced duplicate `UserTag` ids.
- **macOS "Send to Zotero" save failures surface an `NSAlert`** instead of silently returning — the user explicitly chose a destination, so a silent failure looked like the export worked.
- **Stale comments removed**: two "Phase 1: storage limit" comments orphaned by the Session 2026-06-10 storage-limit removal (`FRUSSettingsView`, `SettingsView`).
- **`IndexingSummaryCardTests` deflaked**: the four async tests slept a fixed 50 ms between `indexVolume` and asserting main-actor state from the progress stream; one failed under full-suite load (2026-06-11) and passed in isolation. Replaced with `waitForCompletedMetadata(in:)`, a bounded 5 s / 20 ms poll on the observable state; on timeout each test's own assertion still reports the failure.

### Session 159 — iPad Sidebar (BigPicture-iPadMacParity Phase 1)
Gives iPad a macOS-like sidebar instead of the iPhone-style bottom tab bar, the one genuinely-unbuilt gap in `BigPicture-iPadMacParity.md` (Phases 2 & 4 were already shipped in Sessions 110 / earlier; Phase 5 is partially shipped from Session 108).
- **`MainTabView` 1.8**: added `.tabViewStyle(.sidebarAdaptable)` to the existing `TabView(selection: $appState.activeTab)`. iPad (regular width) renders the five tabs as a native adaptive sidebar — persistent in landscape, a top bar with a sidebar-expand toggle in portrait — while iPhone (compact width) automatically keeps the bottom tab bar. Each tab keeps its own internal navigation (e.g. `BrowserView`'s / `ResearchView`'s `NavigationSplitView`), which becomes the sidebar's detail content, so **no nested split view is introduced**.
- **Approach note**: the original Phase 1 design (a custom `iPadRootView` wrapping the sections in an outer `NavigationSplitView`) was superseded because it would nest split-in-split with `BrowserView`/`ResearchView`. iOS 26 deployment target + the iOS 18 value-based `Tab(...)` API already in use make `.sidebarAdaptable` the idiomatic one-modifier realization. `BigPicture-iPadMacParity.md` updated with an Implementation Status section recording actual phase state and this decision.
- **Verification**: 761/761 `FRUSExplorerTests` (iPhone 17 sim — bottom tab bar unaffected, `UIObstructionTests` green); iPad Pro 11" sim screenshot confirms the sidebar control and that Browse renders `BrowserView`'s subseries+detail split cleanly with no nesting breakage; macOS target builds clean (`MainTabView` is iOS-only). No new files, no new user-facing strings.

**Phase 5 fix (same session) — "Open in New Window" gate.** `DocumentView` 3.5: the toolbar's "Open in New Window" button was gated on `sizeClass == .regular`, which is true on *every* iPad — so it appeared for all iPad users but `openWindow(value:)` silently no-ops unless Stage Manager is active. Re-gated on `@Environment(\.supportsMultipleWindows)`, which is `true` only when a second window can actually open (Stage Manager on iPad; never iPhone or non-Stage-Manager iPad). The other `sizeClass == .regular` sites (`DocumentView` notes-inspector placement, `BrowserView` split-vs-stack, `CollectionEditorView` iPad layout) are genuine layout gates and correctly stay size-class based.

**Phase 3 assessment (no change needed).** Phase 3 ("tools in the detail pane, not modal sheets") was premised on the superseded custom-`iPadRootView` design. Under `.sidebarAdaptable` the corpus/document tools already work well on iPad: Person Index is a `BrowserView` navigation destination; Analytics, Source Explorer, and the Cross-Reference Graph present as working sheets (the "Source Explorer no visible action" bug the doc cited was already fixed — it is always a sheet now). Converting these contextual, document-scoped tools to detail-pane pushes would be churn without clear benefit, so Phase 3 is treated as satisfied.

- **Remaining backlog**: optional Stage-Manager *enhancements* only — making the Cross-Reference Graph and Source Explorer open as dedicated iPad windows under Stage Manager (they currently work as sheets; this needs new iOS `WindowGroup` scenes + a design decision). `TabSection` grouping for sidebar section headers is a possible future polish.

### Session 159 (cont.) — Multi-window: tool windows + search-alongside (iPad Phase 1)
Lets iPad Stage Manager users view reference tools and documents *alongside* each other instead of as sheets / pushed screens. Investigation finding: **iPadOS has no third-party window-tabbing API** (macOS/Safari only), so iPad uses separate Stage Manager windows; macOS-native tabbing is a separate follow-up (Phase 2).
- **`DocumentWindowID` dedup fix** (`App/DocumentWindowID.swift`): custom `Equatable`/`Hashable` keyed on `(volumeId, documentId)` only — `header` is a display placeholder. `WindowGroup(for:)` reuses a window when the value is equal, so without this the *same* document opened with a different header (search result vs. cross-reference tap) spawned a duplicate window instead of focusing the open one. 5 unit tests in `AppStateTests.swift` (`DocumentWindowIDTests`).
- **Cross-Reference Graph window (iOS)**: new single-instance `WindowGroup(id: "frus.crossReferenceGraph.ios")` showing `CrossReferenceGraphView` for `appState.currentGraphEntry` (`.id(entry.id)` retargets on reopen), mirroring the existing `frus.sourceExplorer.ios` scene. `DocumentView`'s Cross-References button opens it when `supportsMultipleWindows`, else the existing sheet.
- **Source Explorer window (iOS)**: the `frus.sourceExplorer.ios` scene already existed but was unused — `DocumentView`'s Source Explorer button now opens it (priming `currentSourceNote`/`currentSourceNoteYear`) when `supportsMultipleWindows`, else the sheet.
- **Search opens documents alongside** (`SearchView` 1.12): with `supportsMultipleWindows`, tapping a result opens the document in its own window via `openWindow(value: DocumentWindowID(...))` so the results list stays visible (open several documents from one list in turn); per-document identity focuses an already-open document vs. opening a new window. iPhone / non-Stage-Manager keeps the push behaviour. A row context-menu "Open in Place" pushes inline as the explicit alternative.
- **Verification**: 766/766 `FRUSExplorerTests` (iPhone 17 sim; +5 `DocumentWindowID` tests); iPad + macOS builds clean; iPad launches cleanly with the new scene registered. **Caveat**: full Stage-Manager runtime behaviour (windows opening side-by-side, focus-existing dedup, results-list-stays) is not scriptable via `simctl` and needs manual on-device verification; the dedup logic, builds, launch, and non-Stage-Manager fallbacks are verified automatically.
- **Phase 2 (next)**: macOS native window tabbing — give macOS document `WindowGroup(for: DocumentWindowID.self)` scenes + an "Open in New Window" affordance so the system provides native tabs/merge, additive to `MainWindowView`.

### Session 159 (cont.) — macOS native window tabbing (Phase 2)
Gives macOS real document-window scenes so the system provides native window tabbing — the chosen approach for "tabbed documents" on Mac (iPad has no such API).
- **`MacDocumentWindowView`** (`App/MacDocumentView.swift`, macOS-only): a standalone document window hosting the full research workspace — `ResearchStripView` + `NavigationStack { MacDocumentView }` + `StatusBarView`, with its own `navigationPath`, `HighlightCoordinator`, and NARA-lookup sheet (so each window/tab is self-sufficient and independent). Mirrors `MainWindowView`'s composition, rooted at the window's document. Window/tab title is the document heading.
- **macOS document scene** (`App/FRUSExplorerApp.swift`): added `WindowGroup(for: DocumentWindowID.self)` to the macOS scene block, hosting `MacDocumentWindowView`. macOS automatically gathers windows from one `WindowGroup` into native tabs ("Merge All Windows" / the window tab bar). Additive — `mainWindowScene` stays the default.
- **"Open in New Window"** added to `ResearchStripView` (appears in the main window and in document windows) via `openWindow(value: DocumentWindowID(...))`. Per-document identity (the Phase 1 dedup fix) means reopening the same document focuses its existing window/tab.
- Design defaults chosen (the open questions): each macOS document window carries its **own ResearchStrip** (full workspace, not a lean viewer); macOS **search-opens-in-window** is delivered as the follow-up below.
- **Verification**: macOS + iPad builds clean; 766/766 `FRUSExplorerTests` (no testable logic added in Phase 2 — the `DocumentWindowID` dedup tests already cover the identity macOS tabbing relies on). **Caveat**: native tab behaviour (the tab bar, "Merge All Windows", drag-to-merge) is a system feature exercised by launching the Mac app and using "Open in New Window" — confirmed to build/register but the runtime tab UI needs a manual check.

### Session 159 (cont.) — macOS search: open result in a new window/tab
Completes the deferred macOS search-opens-in-window work. Investigation finding: the "new tab" vs "new window" distinction is **not a SwiftUI capability** — it requires AppKit `NSWindow.tabbingMode`/`addTabbedWindow` and can't be verified in this environment. Chosen approach (user decision): the **system-respecting** model rather than fragile per-action AppKit tab control.
- `MacSearchWindowView` 1.10 (`App/SearchSheet.swift`): the result-row context menu's "Open in new window" — previously a no-op stub marked "deferred" — now opens the document in its own `DocumentWindowID` window via `openWindow`. Default click still opens in the **main window** (`navigateToResult` → `pendingBrowseDocument`), so "existing window" remains the default.
- Because document windows share one `WindowGroup`, macOS shows the opened document as a **tab or a separate window per the user's "Prefer tabs when opening documents" setting** (System Settings ▸ Desktop & Dock) — no AppKit tab-mode code. Per-document identity focuses an already-open document instead of duplicating it.
- **Verification**: macOS build clean; no new testable logic. The tab-vs-window outcome depends on the user's system setting and needs a manual check on a Mac.

### Session 159 — Complex-query search bug: grouped boolean queries returned zero results
Reported: `(aqaba OR tiran) and (navigation OR passage OR transit)` returned **no results** in FRUS Explorer but 382 on history.state.gov. Investigation (with direct SQLite FTS5 probing) found two issues:
- **Critical bug** — `FTS5InlineQueryParser.assemble()` joined adjacent operands by **bare juxtaposition** (implicit AND) and deliberately *dropped* the `AND` keyword. FTS5 permits implicit-AND only between bare phrases (`"a" "b"`), **not between parenthesised groups**: `(a OR b) (c OR d)` is a hard `fts5: syntax error`. So *every* grouped boolean query — including the correct uppercase form `(aqaba OR tiran) AND (...)` shown in the parser's own doc comment — rendered to invalid FTS5, the query failed, and the UI surfaced it as zero results. The parser's unit tests only string-matched the output and never executed it, so it shipped. **Fix:** operands are now joined with an explicit `AND` keyword (kept as `X NOT Y` juxtaposition for negated right-hand operands, since `AND NOT` is itself an FTS5 error). `FTS5InlineQueryParser` 3.0.
- **Behaviour (user decision)** — operators were recognised only in UPPERCASE, so the user's lowercase `and` became a literal required term. Operators are now **case-insensitive** (`and`/`Or`/`NOT` all work), matching history.state.gov; to search the literal word, quote it (`"and"`). `SearchService.positiveTerms` updated to skip operators case-insensitively for snippet highlighting.
- **New safety net** — `FTS5InlineQueryParserTests` now *executes* rendered expressions against a real in-memory `porter unicode61` FTS5 table (throws on syntax error), covering the user's exact query, uppercase/lowercase grouped AND, narrowing, OR/NOT/wildcards, and nested groups — so invalid output can no longer pass as a green test.
- **Verification**: 47/47 `FTS5InlineQueryParserTests` (swift test, incl. the execution tests); full app `FRUSExplorerTests` green; iPad + macOS build clean.

### Session 2026-06-11 — Pre-1910 Central Files / NARA Catalog feasibility (planning only)
Assessed expanding Source Explorer to resolve pre-1910 documents to their digitized
archival copies in the NARA Catalog (the entire State Dept. Central Files 1789–1910 are
online). **Verdict: feasible, high confidence.** Pre-1906 TEI carries explicitly tagged
sender/recipient direction (`persName type="from"/"to"`), dateline office+place, ISO
dates, and country chapters — enough to classify documents into Central Files components
deterministically in most cases; the catalog exposes a uniform series → file-unit
(country/post) → item (roll, JPEGs + consolidated PDF) hierarchy enumerable via the v2
API's `ancestorNaId` parameter. Proposed: a `CentralFilesIndexGenerator` SPM harvest tool
emitting a bundled `central-files-index.json` (runtime then needs **no API key** — links
are static `/id/<naid>` URLs), a `CentralFilesClassifier`, and an upgraded
`centralFilesPanel` showing the inferred roll-level link with confidence, alternates, and
a date-interpolation verification hint. Phased: (1) Numerical File 1906–1910 ("File No."
→ case → M862 roll, near-deterministic), (2) country-arranged diplomatic series,
(3) consular + chronological-run series. No code changes this session.
- New: `Planning/BigPicture-Pre1910-CentralFiles.md` (full assessment, series NAID table, architecture, risks)
- New: `Planning/Pre1910-CentralFiles-Reference-Data.md` (template for 10 user-traced reference documents; doubles as the acceptance fixture — target ≥8/10 reproduced)
### Session 160 — macOS testing fixes: in-document links, front-matter one-tap, complete Prev/Next
Three issues reported from macOS testing.
- **In-document person/term links never fired (both platforms; surfaced on macOS).** Links are `<a href="frusexplorer://…">`. The shared web-view coordinator's `decidePolicyFor` returned `.cancel` for the `frusexplorer` scheme — which is required so the scheme handler's empty response can't replace the document, but cancelling also **prevents `WKURLSchemeHandler.webView(_:start:)` from running**, and that `start` method was the *only* place person/gloss/cross-ref taps were dispatched. So the callbacks never fired. **Fix:** dispatch moved into `FRUSURLSchemeHandler.dispatch(url:)`, now called from `_FRUSWebViewCoordinator.webView(_:decidePolicyFor:)` (on the main actor) before returning `.cancel`. `start` now only responds with an empty 200. Single dispatch, deterministic on both platforms. `FRUSURLSchemeHandler` 1.1.
- **Front-matter sections needed a second click (macOS corpus browser).** `CorpusVolumeDetailSheet.structureView` opened an intermediate `CorpusSectionDocumentListView` sheet whose prose-section branch only showed a "Read X" button (a second click). **Fix:** new `openSection(_:)` helper opens `canReadDirectly` sections straight into the main window on first tap (posts `pendingBrowseDocument` + dismisses), exactly like a numbered document; compilations / Persons / Sources still route to the sheet (list or structured view). `SupportingViews.swift`.
- **Prev/Next skipped some front matter.** Prev/Next was built from `documents(forVolume:)` (`document_cache`), which by design omits the structured/navigation sections kept out of search — **Persons, Sources, Table of Contents, Index** — so navigation jumped over exactly those. **Fix:** new `IndexingPipeline.readingSequence(forVolume:)` walks the persisted `VolumeStructure` (every section in source order), enriches body documents with cached metadata, and synthesises entries for the non-indexed sections so they open as quasi-documents by `xml:id` (the parser's `targetDocumentId` path already renders any div by id). Pure merge extracted to `mergeReadingSequence(structure:cached:volumeId:)`; both `MacDocumentView.loadDocument` and iOS `DocumentViewModel.loadAdjacentEntries` now use it, so navigation spans front-matter → body → back-matter on both platforms. Per user decision, Persons/Sources/TOC/Index **are** included.
- **Verification**: macOS app build clean; 770/770 `FRUSExplorerTests` (iPhone 17 sim; +4 new `ReadingSequenceTests` covering full-volume order, metadata preservation, auto-id skipping, and the no-loss safety net). **Caveat**: the link-tap fix compiles and is logically sound but a runtime click-through on a real document (and Prev/Next landing on a Persons/Sources section) is best confirmed in the next build — the WKWebView click path isn't covered by the unit suite.

### Session 161 — Cross-reference graph redesign: bug fixes, legibility, timeline layout, reference list, platform polish
Full critical review + redesign of the cross-reference graph (five commits). Diagnosis: position encoded nothing (force-directed layout, no spatial memory), direction was invisible (no arrowheads), labels were too thin ("Doc. 42", no dates), and several interaction bugs crippled macOS. Work landed in order:
- **Bug fixes** — (1) macOS hover cleared a click-pinned selection, making the info panel's Recenter/View Document buttons *unreachable by mouse* (hover state split into `hoveredNodeKey`/`hoveredEdgeKey`; hover previews, click pins); (2) pan/pinch gestures assigned raw gesture values so every new gesture snapped the viewport back (`steadyScale`/`steadyPanOffset` accumulation, both graph views; volume graph also gained Reset View + double-tap reset); (3) parallel references (same source→target pair, multiple footnotes) produced duplicate `DisplayNode`/`DisplayEdge` IDs — now aggregated into one weighted edge with merged contexts, nodes deduped, build output deterministic; (4) undownloaded nodes offered only a disabled button — now a **Download Volume** CTA in the info panel (spec §11 intent restored).
- **Tier 1 legibility** — arrowheads at the cited document's rim (curve-tangent oriented); edge thickness = aggregated reference count; node labels gain a date line (`document_dates` JOIN in `fetchMetadata`; new `CrossReferenceNodeMetadata.dateISO`/`.summary`, OpenAPI schema updated); node radius scales log₂ with corpus-wide connection count (new `connectionCounts` batch query); outbound recolored green→orange (colorblind-safe vs. blue; arrowheads carry direction redundantly); undownloaded encoding switched orange-ring → dashed ring + `icloud.slash`; compact always-visible legend (bottom-leading); node info panel previews the on-device `summary_text`.
- **Tier 2 timeline layout** — new `GraphLayoutMode` (.timeline/.network) with toolbar picker; **timeline is the default whenever the central doc + ≥2 neighbours have parseable dates**. `timelineLayout()`: x = document date between margins, greedy lane assignment for collision-free labels, central doc owns the centre lane, undated/cluster nodes park in a captioned trailing column; adaptive axis ticks (years/months/days by span); lenient ISO parsing (`yyyy`, `yyyy-MM`, `yyyy-MM-dd`); fully deterministic. Falls back to network (picker disabled) when chronology is unsupported.
- **Tier 3 navigation economics** — new `ReferenceListPanel` (sectioned: cites / cited by / further hops; full headers, dates, volumes, ×N badges, footnote-context snippets) synchronized two-way with canvas selection; macOS/iPad regular width = toolbar-toggled trailing panel, iPhone compact = Graph/List picker with **list as default**. Sparse graphs (1–3 direct refs) auto-widen to 2 hops with a toolbar note, without touching the degree picker; disabled once the user adjusts depth manually.
- **Tier 4 platform polish** — macOS scroll-wheel/trackpad zoom (`ScrollWheelZoomCatcher`, local NSEvent monitor, never intercepts clicks), Escape clears pinned selection, double-click re-centres; degree picker relabeled "Depth: 1 hop/2 hops/3 hops" (was "Neighbourhood 1°/2°/3°"); iPhone graph sheet opens at `.large`.
- **Verification**: 775/775 `FRUSExplorerTests` (iPhone 17 sim; +5 new tests: edge aggregation/unique IDs, build determinism, timeline chronological ordering + parking + ticks, partial-ISO parsing, undated fallback); macOS (AppStore config) and iOS builds clean. `ReferenceListPanel.swift` added via xcodegen (schemes restored per CLAUDE.md). **Caveats for next manual build**: hover/pin feel, scroll-zoom direction/speed (0.0035 factor), timeline lane spacing on dense graphs, and the Download Volume CTA flow are best confirmed interactively.

### Session 162 — Icon-only control discoverability: controlHelp modifier, toolbar sweep, TipKit tips
Goal: help users understand icon-only buttons on *all* platforms. Key fact driving the design: SwiftUI's `.help()` renders a visible tooltip **only on macOS** — on iOS it contributes nothing visual, so the app's ~120 help strings were Mac-only. Three layers landed:
- **`controlHelp(label:detail:systemImage:)`** (new `Theme/ControlHelp.swift`) — one modifier fans a single (label, detail) pair out to every per-platform surface: `accessibilityLabel` everywhere; `help` tooltip on macOS; `accessibilityHint` + **Large Content Viewer** entry (long-press HUD at accessibility Dynamic Type sizes — previously zero uses app-wide) on iOS/iPadOS. A custom `UIToolTipInteraction` bridge for iPad pointer hover was evaluated and deliberately skipped (would need to win pointer hit-testing without stealing touches — fragile); the doc comment records the reasoning.
- **Sweep** — adopted in the CrossReference views (info button, reset viewport, reference-list toggle, breadcrumb back, list-row open button) and across the highest-traffic iOS toolbars, replacing bare `accessibilityLabel` calls and adding explanatory detail strings: all 12 `DocumentView` toolbar items (add note, tag, highlight, note-to-highlight, view/copy/share citation, add to collection, cross-references, source explorer, open in new window, summarize, notes-panel toggle), `MainTabView`'s corpus-analytics button, and `SearchView`'s filter/timeline/overflow buttons.
- **TipKit** (new `App/DiscoveryTips.swift`; `Tips.configure` in both platform inits) — three curated first-contact tips, deliberately few: **Explore Cross-References** (document toolbar), **Browse References as a List** (graph toolbar toggle), **Timeline or Network** (graph layout picker). Each invalidates with `.actionPerformed` on first use and gives up after 3 impressions (`MaxDisplayCount`). TipKit works on macOS 14+ too, so tips appear on both platforms.
- **Verification**: 775/775 `FRUSExplorerTests` incl. `CodingStandardsAuditTests` over the two new files; macOS + iOS builds clean; both new files registered via xcodegen (schemes restored). **Caveat**: tip anchoring/frequency and the Large Content Viewer HUD are runtime behaviours — confirm on device at an accessibility text size.

### Session 162 (cont.) — "Index Health": merged index version + status + integrity into one Storage display
User request: merge the index-version/freshness story (previously invisible — the boot-time auto-reindex left no UI trace) and the manual integrity check into one compact "Index Health" display.
- **New shared `Settings/IndexHealthView.swift`** — one status row + the Check Integrity button + inline results:
  - *Updating index…* (spinner) when `AppState.currentIndexingProgress != nil` — covers boot-time version-triggered re-indexes, post-download indexing, and Settings batches alike;
  - *Index update pending* (orange `clock.arrow.circlepath`) when `needsDateReindex || needsFTSRebuildReindex` — shows "Built with format version X — version Y update runs automatically";
  - *Index up to date* (green `checkmark.seal`) with "Format version 7" otherwise.
  - The Check Integrity button (now `controlHelp`-labelled, with a "may take a moment" warning) keeps the Session 154 behaviour: SQLite `quick_check` + FTS5 `integrity-check`, green "No problems found" or red problem list with the Delete-Index-&-Rebuild suggestion. Disabled while anything is indexing.
- **Hosts** — iOS `StorageManagementView` gains an "Index Health" section (with explanatory footer) ahead of Diagnostics, which now holds only Rebuild Spotlight Index; macOS `FRUSSettingsView.diagnosticsSection` embeds the same view above its Spotlight button. Duplicated integrity state/`runIndexIntegrityCheck()` removed from both hosts (single source of truth in the shared view).
- **Verification**: full `FRUSExplorerTests` green; macOS + iOS builds clean; file registered via xcodegen (schemes restored). **Caveat**: the *update pending* state is hard to reach in normal use (boot auto-reindex clears it quickly) — simplest manual check is deleting the `frusExplorer.dateIndexVersion` UserDefaults key.

### Session 162 (cont.) — Graph interaction was dead on macOS: Canvas/Observation bug found by live computer-use debugging, plus overlap and density fixes
User's first manual run of the Session 161 graph: hovering/clicking nodes did nothing; the info panel and legend obscured nodes; dense 3-hop timelines were unreadable. Diagnosed by driving the running app directly (synthetic clicks + screenshots):
- **Root cause** — every interaction *was* registering in the view model (clicking "Network" in the toolbar suddenly revealed a node pinned two interactions earlier) but nothing re-rendered: the canvas read `displayNodes`/`nodePositions`/`resolvedNodeKey`/etc. **inside the `Canvas {}` rendering closure, which runs outside body evaluation — Observation never registers those reads as dependencies**, so hover/selection mutations invalidated nothing. The toolbar still worked because macOS toolbars live outside the content hierarchy. **Fix:** new `GraphRenderSnapshot` value captured in body (`makeRenderSnapshot()`) registers every dependency and hands the canvas stable value types; the rendering closure and all draw helpers now read only the snapshot. *Rule for future Canvas work: never read an `@Observable` model inside a `Canvas`/`TimelineView` closure — snapshot in body first.*
- **Resolution priority flipped** — pinned selection now wins over hover (`resolved = selected ?? hovered`), and clicks clear both hover keys. The old hover-wins order let a hover that never got its exit event (synthetic moves; pointer parked on a hit area) mask every later click.
- **Overlap fixes (user feedback)** — info panel moved top-leading → **bottom-trailing** (least node-dense corner in both layouts; top-left collided with the timeline's early-date lanes) and gained an `xmark.circle` dismiss; the legend left the canvas entirely and became a one-line **footer strip** below it (`ViewThatFits` long/short variants), so neither can obscure nodes again.
- **Dense-graph deconfliction** — (1) **focus dimming**: with a node/edge active, non-adjacent edges draw at 15% and non-adjacent nodes at 30% opacity, so a click isolates one document's neighbourhood out of the 3-hop spaghetti; (2) **label thinning**: above 40 nodes only central/cluster/focused nodes keep text labels.
- **Verification** — live, on the rebuilt app via computer use: click-to-pin instant, panel persists when pointer leaves, X dismisses and clears dimming, focus dimming isolates neighbourhoods in the 3-hop timeline, legend footer and bottom-trailing panel never overlap nodes; full `FRUSExplorerTests` green; both platform builds clean. **Caveat:** pointer-hover preview couldn't be exercised synthetically (tracking areas need real mouse moves) — confirm by hand; even a stuck hover is now harmless under pin-priority.
- **Deferred recommendations for very dense graphs** (discussed with user): cluster same-date pileups into expandable date-group nodes (the Jun 1967 column still stacks); a time-range brush to zoom the x-axis; defaulting 3-hop exploration to the reference list panel.

### Session 162 (cont.) — Details fold into the side panel; date clusters; time-range brush
All three previously deferred recommendations implemented (user request), each verified live via computer use on the rebuilt macOS app.
- **Details in the side panel, auto-open on click** — on regular widths the floating info card is gone: `ReferenceListPanel` gains a detail section at top (`GraphNodeDetailView`/`GraphEdgeDetailView` — header, dateline, volume, on-device summary, footnote context, Download Volume, Recenter / View Document / dismiss). **Clicking a node or edge pins it and auto-opens the panel** (`revealDetailPanelIfNeeded`); switching to 3 hops opens it too. iPhone compact keeps the floating bottom-trailing card (no side-panel real estate). `EdgeContextView` made internal; `DisplayNode.volumeId` helper added.
- **Date clusters** — new `DisplayNode.Kind.dateCluster`: in timeline mode, dated nodes whose x positions fall within a 52 pt window group; groups of 4+ collapse into a purple calendar node ("17 docs · Jun 1967" in the live test). Edges reroute to the cluster and re-aggregate (unique IDs; intra-cluster edges drop; cluster x = mean member date). Tap (iOS) or pin → Expand Date Group (macOS) expands in place. The VM now keeps `baseDisplayNodes/baseDisplayEdges` (unclustered truth) vs `displayNodes/displayEdges` (rendered); the reference list and VoiceOver list read base so they always show real documents, and selecting a folded document auto-expands its cluster.
- **Time-range brush** — `TimelineBrushView` strip between canvas and legend: full date extent with one density mark per dated document; drag to create a window, drag inside to move, edges to resize, ✕ to clear. While active the axis zooms to the window (`timelineLayout(domain:)`), out-of-domain dated nodes hide (never parked — and the **central document hides too** when excluded, rather than extrapolating off-plot), and clusters recompute on the zoomed scale so zooming in dissolves them (verified live: brushing Jun–Oct 1967 dissolved the 17-doc cluster into clean lanes with re-ticked Jun/Jul/Aug/Sep/Oct axis).
- **Regression caught by the full suite**: `rerunLayout`'s new base→display assignment emptied graphs for callers that seed `displayNodes` directly (the ReduceMotion accessibility tests) — fixed with a base-empty fallback. The brush test also exposed the central-extrapolation flaw above (its first version used the wrong fixture year, 1967 vs 1962 — both corrected).
- **Verification**: full `FRUSExplorerTests` green (777 tests; +2 new: date clustering, brush domain filtering); macOS + iOS builds clean; live checks — sidebar auto-open at 3 hops, cluster pin → Expand Date Group, brush drag/zoom/clear, detail header shows the descriptive cluster label rather than the raw `datecluster/…` key.

### Session 162 (cont.) — In-document link audit: assessed live, six defects found and repaired
Drove the running macOS app via computer use, clicking every link type in real documents (frus1964-68v19 d94/d13/d69/d100, chosen by grepping the volume XML for each ref-target flavour). Assessment → repair → live re-verification.

| Link type | Before | After |
|---|---|---|
| Person link (body) | ✅ opens sheet | ✅ |
| Person "In Indexed Documents" count | ❌ always "Not found" on macOS | ✅ "Mentioned in 1,408 indexed documents" (Nasser) |
| Person/term link **inside a footnote** | ❌ resolved nil → error alert | ✅ |
| Term/gloss definition | ❌ sheet always empty | parser fixed; populates on re-index (v8) |
| Heading `<gloss type="from">` | ❌ dead `href="#"` links | ✅ plain text |
| Footnote marker popover | ✅ | ✅ |
| Same-volume doc ref `#dNN` | ✅ | ✅ |
| Footnote-suffixed ref `#d100fn2` | ❌ "Document 'd100fn2' was not found" | ✅ opens d100 |
| Cross-volume ref `vol#dNN` | ❌ macOS navigated to raw target → not found | ✅ opens d65 in frus1964-68v18 |
| Printed-page ref `vol#pg_313` | ❌ macOS silent no-op; iOS would 404 | ✅ navigates; exact doc fixed by PageRangeStore repair |
| External `http(s)` ref | ❌ no-op / bogus nav | ✅ opens in browser via `openURL` |

Root causes and fixes:
- **`FRUSURLSchemeHandler.register(model:)` scanned only `model.bodyNodes`** — footnote bodies live in `model.footnotes`, so every person/term link inside a footnote resolved nil. Now scans both.
- **New `CrossRefDestination` + `resolveCrossRefTarget(_:volumeId:)`** (nonisolated static; the default-MainActor inference initially trapped the off-actor test — instructive crash via `dispatch_assert_queue` inside a `drop(while:)` closure): classifies raw `<ref>` targets into document (with `dNNfnM`→`dNN` normalisation), page (`pg_…`; roman numerals unresolved), external URL, or unresolved. Both platform `handleCrossRefTap`s now route through it; `PageRangeStore` resolves pages to containing documents (`AppState.pageRangeStore` added at boot); `openURL` handles externals.
- **`PageRangeStore.span` open-ended final span** — the last document of *every* section claimed pages to `Int.max`, so a section whose pagination ends early (front matter ending at p. 9) could win the dictionary-ordered race and resolve p. 313 of frus1955-57v17 to a page-9 document. Final spans now close at the section's highest recorded page; regression test added.
- **Terms parser discarded every definition in the corpus** — it split item text on ":" but FRUS uses `<term>POL</term>, definition`. Fixed (with no-`<term>` fallback retained); `currentDateIndexVersion` → **8** so the boot re-index repopulates `terms.definition` corpus-wide.
- **Heading metadata glosses** (`<gloss type="from">` with no target) no longer render as links.
- **macOS never called `loadPersonMentionCount`** (stale "future session" comment) — wired in `handlePersonTap`.
- **Verification**: full suite green (785 tests; +5 new: 4 resolver classifications, terms definitions, early-section page spans); both builds clean; live re-checks confirmed each repaired path. **Caveats**: term definitions appear after the v8 re-index completes (launch-triggered, Index Health shows progress); same-document `#pg_XIII`-style roman/front-matter page anchors remain unresolved by design; cross-document footnote-anchor scroll (landing on d100 *at* fn2) is a possible future enhancement.

### Session 2026-06-15 — Pre-1910 Central Files: reference data received + architecture revised
NARA higher rate limit granted (2026-06-12) and user delivered 9 hand-traced reference
documents (`Pre1910-CentralFiles-Reference-Data.md`, now filled in and committed). The
traces confirm feasibility but **revise the architecture** — captured in a new "Findings
from reference data" section in `BigPicture-Pre1910-CentralFiles.md`:
- **Hierarchy depth varies by series** (the biggest change): Diplomatic Instructions
  (593313) and Notes to Foreign Missions (597272) have **no file-unit level** — country
  is encoded in the roll/item title; Despatches (603720), Notes from (594363), and
  Consular Despatches (302031) keep the 3-level series→file-unit(country)→roll shape;
  Numerical File (654171) is 2-level by case number. Index schema gains a per-component
  `geoGranularity` flag + per-series `rollTitleGrammar`.
- Roll titles are heterogeneous and contain **typos including in dates** (1675 for 1875);
  date parsing must clamp implausible years.
- **Multi-country, non-chronological rolls** exist ("Uruguay and Paraguay") → `geoKeys`
  is an array, `chronological:false` suppresses the date-interpolation hint there.
- **Enclosures are dual-homed**: the printed text physically lives in its originating
  series (from the enclosure's own dateline); the covering doc's roll only references it.
- Country should be resolved from the **FRUS chapter head**, not name-parsing.
- FRUS file-number annotations can be imprecise/wrong, but the **integer case number
  still selects the right Numerical File roll** — Phase 1 keying is robust.
- No code yet. Next: build Phase 1 (`CentralFilesIndexGenerator` Numerical File survey +
  harvest, case→roll lookup) using the verified golden NAIDs as parser fixtures.

### Session 2026-06-15 (cont.) — Phase 1 built: CentralFilesIndexGenerator (Numerical File)
New SPM command-line tool (sibling of ManifestGenerator/TaxonomyGenerator), Core library
+ thin executable + 21 unit tests, all green; full package builds clean.
- **Targets** (`Package.swift`): `CentralFilesIndexGeneratorCore`, `CentralFilesIndexGenerator`,
  `CentralFilesIndexGeneratorTests`.
- **Core files** (`CentralFilesIndexGeneratorCore/`):
  - `CentralFilesIndexModels.swift` — `CentralFilesIndex` (bundled JSON, `schemaVersion`),
    `NumericalFileIndex`/`NumericalFileRoll`, and the lookup: `roll(forCaseNumber:)` and
    `roll(forFileNumber:)` (parses the leading integer case number, drops the `/NN`
    sub-document suffix — robust to FRUS's imprecise annotations, per Finding 6).
  - `RollTitleParser.swift` — `numericalFileCaseRange(from:)` parses `Numerical File: N-N`
    (hyphen/en-dash/whitespace/trailing-period tolerant); non-roll titles → nil (this is
    how series/file-unit/finding-aid records are filtered out).
  - `NARACatalogHarvestClient.swift` — actor; pages the v2 `records/search` API
    (`ancestorNaId` + `availableOnline=true`, cursor via `searchAfter`/`sort[0]`, shape
    `body.hits.hits[]._source.record` — matches NARA's own bulk scripts). **Caches every
    raw page to disk** (the required no-re-query design); `CatalogScalar` normalises
    number-or-string `naId`/cursor.
  - `NumericalFileIndexBuilder.swift` — pure build + self-survey (matched/unmatched
    counts, sample unmatched titles, coverage gaps, range overlaps).
  - `CentralFilesIndexWriter.swift` — deterministic pretty JSON (sorted keys, rolls
    sorted by caseStart).
  - `CentralFilesIndexGeneratorRunner.swift` — orchestration; prints the survey and
    **validates against golden checks from the reference data** (Doc 6 File No. 7187 →
    roll 19779414; Doc 7 File No. 697/43 → roll 19174810); non-zero exit on failure.
- **Run**: `CATALOG_API_KEY=<key> swift run CentralFilesIndexGenerator` (env: OUTPUT_PATH,
  CACHE_DIR, PAGE_SIZE, REFRESH). Writes `FRUSExplorer/Resources/central-files-index.json`.
- **Status**: harvest not yet run (no API key in the dev environment — user runs it).
  Tool is self-validating against the golden traces, so a bad parse/missing roll fails
  loudly. App-side consumption of the index is a later phase. **Open**: confirm the v2
  `limit` max page size from the first run's cached pages (try PAGE_SIZE=100).

### Session 2026-06-15 (cont.) — Phase 1 harvest run; parser hardened against real M862 titles
User ran the harvest (rate limit granted); 1,286 records over 52 pages, cached to disk.
The first run exposed that the clean `N-N` title is only ~55% of rolls, and a naive parse
produced bogus cross-case ranges (golden checks failed). Iterated the parser **against the
cached pages** (zero further API calls) until both golden checks pass:
- Real title forms now handled: single-case (`22346`), sub-document boundaries
  (`21701-21740/125`, `…/126-End of case`), roll-split `(R)`/`(S)` markers, en-dashes
  corrupted to **U+FFFD**/underscore, and stray-leading-dash space ranges (`-25101 25240`).
- **Sub-document hyphen disambiguation** (the key bug): in `18036/9-11Exhibit GG-End of
  Case` the first hyphen separates sub-documents, not cases — an end integer **below** the
  start case is a sub-document, so the roll is a single case (prevents bogus wide ranges
  like (11,18036) that were swallowing the golden cases). Cases run strictly ascending.
- Require a leading digit after `Numerical File:` → rejects annex/reference records
  (`Annex to 760928`, `Annexes to case 426`). Pure-space ranges only when the start token
  is a bare case (`15779 15820` ✓ vs `552/201 42006` → single case 552).
- Added `rolls(containingCaseNumber:)` (plural): a case is routinely split across 2–3
  rolls, so the app should surface all of them as page targets.
- **Result**: 1,261/1,286 parsed (98%); the 25 unmatched are all correctly non-case
  records (6 name/place rolls, ~14 annex/enclosure supplements, 5 individually-described
  documents). **Both golden checks pass.** 43 small coverage gaps + 417 overlaps are
  mostly legitimate case-splitting/boundary-sharing. One harmless outlier roll (case
  42273). Generated `FRUSExplorer/Resources/central-files-index.json` (272 KB) committed.
- **Page size**: harvested fine at the default 25. PAGE_SIZE=100 still untried (would cut
  enumeration ~4×) — non-blocking.
- **Next**: wire the index into the Source Explorer `centralFilesPanel` (1906–1910 "File
  No." → roll link(s) + Card Index M1889 fallback for gaps); then Phase 2.

### Session 2026-06-15 (cont.) — Phase 1 app integration: Numerical File roll resolution in Source Explorer
Wired the bundled index into both Source Explorer views so a 1906–1910 "File No." citation
resolves to its digitized roll(s) with no API key / no network.
- **New `FRUSExplorer/SourceExplorer/CentralFilesIndex.swift`** — app-side mirror of the
  generator's Codable models (the app can't import the SPM tool target; the JSON is the
  contract). `CentralFilesIndexStore.shared` lazy-loads/caches the bundled
  `central-files-index.json`; `rolls(forFileNumber:)` returns every roll holding the case
  (a case can span 2–3 rolls); static `cardIndexURL` (M1889) + `numericalFileSeriesURL`
  for the gap fallback.
- **iOS `SourceExplorerView`** — new `numericalFileSection(fileIdentifier:)` shown for
  `.centralFiles` notes when `documentYear ∈ 1906…1910`: lists each digitized roll with an
  "Open in NARA Catalog" link + a page-by-page hint; falls back to Card Index + series
  links when the case is in a coverage gap. Shown above the existing period-finding-aid
  section (kept as general context).
- **macOS `MacSourceExplorerView`** — same logic as `numericalFileBox(fileIdentifier:)`,
  `.buttonStyle(.link)`, placed above `centralFilesPeriodBox` in the NARA box.
- **`xcodegen generate`** run to register the new Swift file + bundle the JSON resource
  (schemes restored per CLAUDE.md).
- **Tests**: new `CentralFilesIndexTests` (6) — JSON-contract decode, golden File No.
  resolution, case-number parsing, split-case multi-roll, gap → empty, and a
  **bundled-index runtime test** proving the resource ships and both golden citations
  (7187 → 19779414; 697/43 → 19174810) resolve in-app. iOS + macOS build clean;
  SourceExplorerTests (37) and CodingStandardsAudit (15) green.
- **Remaining manual check**: a live UI walkthrough (open a real 1906–1910 doc with a
  "File No." note → Source Explorer → tap a roll link) — the data path is unit-verified;
  the SwiftUI rendering is not exercised by the suite.

### Session 2026-06-15 (cont.) — Phase 2 start: parsing core + survey (country-arranged diplomatic series)
Began Phase 2 (Despatches 603720, Diplomatic Instructions 593313, Notes from 594363, Notes
to 597272). Inspecting the cached catalog records revealed they carry `levelOfDescription`
and `ancestors` (parent NAIDs + structured dates) — so the 3-level series' roll→country
file-unit linkage is reconstructable, and the case-range "rolls" of Phase 1 are actually
`fileUnit` records (Phase 1 still correct). **Only the Numerical File is cached**, so —
applying the Phase 1 lesson (don't build parsers against 2 clean examples) — this turn
delivers the reusable, fully-tested parsing core plus a survey, deferring final per-series
parsers until real diplomatic titles are seen.
- **`HistoricalDateParser`** — parses the title date ranges (`Aug. 17, 1861 - Sept. 2,
  1863`, `Apr. 19, 1893-Mar. 28, 1896`, full/abbrev months incl. `Sept`, single date, bare
  year) to ISO; flags implausible years (the `1675`-for-`1875` catalog typo) without
  failing — a too-wide low bound never causes a missed lookup. 6 tests (real Doc 1–5 dates).
- **`GeoKeyNormalizer`** — canonical country keys; strips `Volume N:` and trailing date
  segments, splits combined rolls (`Uruguay and Paraguay` → 2 keys), seed alias table
  (`Argentine Republic`→argentina, Persia→iran, …). Runs on both index and classifier
  sides so they agree. 5 tests.
- **Harvest client** extended to decode `levelOfDescription` + parent file unit (ancestor
  distance 1) — Phase 1 decode/golden checks still green (41 generator tests pass).
- **`CentralFilesSurveyRunner`** + `SURVEY_SERIES=<naId>` env switch: enumerates a series
  and reports record levels, sample titles per level, item→parent linkage, and date
  parseability. Run e.g. `CATALOG_API_KEY=… SURVEY_SERIES=603720 swift run …`.
- **Next**: user runs the 4 surveys; finalize per-series geo/date parsers + file-unit
  country extraction against real titles; build the flattened `countrySeries` index with
  golden checks (Docs 1–5); then the app-side `CentralFilesClassifier` + Source Explorer
  integration for pre-1906 documents (which have no source note — needs header/dateline/
  chapter plumbed into the panel).

### Session 2026-06-15 (cont.) — Phase 2 harvest complete: country-arranged diplomatic series
Surveys run; the 4 series' real structures matched the findings (Despatches/Notes-from =
item rolls under country file units; Instructions/Notes-to = fileUnit rolls with country in
the title). Built the full Phase 2 harvest; **all 5 country golden checks pass** with tight
result sets, plus both Phase 1 checks. Index now ships 1,261 numerical + 2,963 country
rolls (1.5 MB, schemaVersion 2).
- **`CountrySeriesParser`** — per-series geo + date extraction: Despatches/Notes-from take
  country from the parent file-unit title (`…Ministers to {Country}, …` incl. `Diplomatic
  Officers, {Country}`; Notes-from demonyms `the {Demonym} Legation` / `Legation of
  {Country}` / `Central American Legations` / `Foreign Missions, {Country}`, `T## -` prefix
  stripped, Miscellaneous → no geo); Instructions/Notes-to parse `Volume {n}: {Country}:
  {dates}` / `{Country[ and …]}: {dates}` from their own title. Resolution level differs
  per series (item vs fileUnit).
- **`GeoKeyNormalizer`** — comprehensive alias table built from the full harvested
  vocabulary (all Notes-from demonyms + FRUS chapter spellings). **Canonical keys are the
  historical FRUS names** (Persia not Iran, Siam not Thailand) so the app's chapter-derived
  key matches.
- **`HistoricalDateParser`** — rewritten component-based; handles the pervasive catalog OCR
  errors: **`16xx`→`18xx` year correction (+200)** (1675→1875, 1656→1856, …) and
  **year-sharing** for day-range rolls (`Apr. 16-Aug. 23, 1881`). This collapsed e.g.
  Switzerland 1875-09-28 from 8 noisy matches to the 1 correct roll. `CountryRoll.matches`
  excludes dateless (garbled) rolls from date-filtered queries.
- Flattened `countrySeries` index model (`CountrySeriesIndex`/`CountryRoll`,
  `rolls(geoKey:dateISO:)`); builder with per-series survey diagnostics; runner enumerates
  all 4 series and validates the country golden checks. 51 generator tests pass; the app
  still decodes the upgraded bundled index (extra keys ignored).
- **Known residue (acceptable)**: ~73/2160 Despatches rolls have un-parseable dates
  (heavy OCR like `1S45`, `No Title`) — still country-discoverable; Instructions/Notes-to
  no-geo cases are the legit early country-less chronological volumes; Notes-from misc
  alphabetical rolls (`Rumania-Zanzibar`) carry no single country. A date query may return
  2 overlapping rolls (e.g. Japan) — fine as candidate links.
- **Next (app integration, the remaining Phase 2 work)**: add `countrySeries` to the
  app-side `CentralFilesIndex` model; build `CentralFilesClassifier` (dateline/heading +
  FRUS chapter → category + geoKey, per the Finding-5 rules); plumb document header/
  dateline/chapter into Source Explorer (pre-1906 docs have **no source note**, so the
  current `.centralFiles`-only trigger doesn't fire); render resolved roll links +
  confidence + the enclosure dual-home case (Finding 4).
### Session 162 (cont.) — Two iPhone Search defects: dead Analytics→Search handoff and an unreachable results-screen toolbar
User report: on iPhone, (1) Corpus Analytics' "open matching documents in Search" did nothing, and (2) the Search toolbar (Save/Saved/Find-by-citation overflow, filter, timeline) was unreachable from the results screen — making it impossible to save searches or reorder results. Investigated, fixed both, and live-confirmed on the iPhone 17 simulator.

| Defect | Root cause | Fix |
|---|---|---|
| Analytics → Search handoff inert on iOS | `AppState.pendingSearch` was set by Analytics / "Find all mentions" / indexing banners and `activeTab` switched to `.search`, but **nothing on iOS ever read `pendingSearch`** (only macOS' SearchSheet consumed it). | `SearchView` now consumes it in `.task` (handoff pending when the tab is first created) **and** `.onChange(of: appState.pendingSearch)` (handoff arriving while the tab is already alive). `consumePendingSearch()` applies the params, clears the slot so it fires once, and runs the search when a positive constraint is present. |
| Person-only handoff surfaced an error instead of results | `SearchViewModel.search()`'s `hasPositiveTerm` guard accepted only keywords/phrase/prefix, so a "Find all mentions" snapshot (carrying just `personRef`) was rejected as empty. | Guard now also accepts `personRef` — `SearchService` applies the person filter SQL-side, so it's a valid standalone constraint. |
| Search toolbar unreachable on iPhone results screen | Default `.searchable` placement + inline nav title lets the field expand **into** the nav bar on compact width, which suppresses the trailing `.primaryAction` items. | iOS now pins the field with `.navigationBarDrawer(displayMode: .always)` (own row beneath the bar) via a `searchFieldPlacement` helper; macOS keeps `.automatic` (inspector toolbar). |

- **Verification**: macOS build clean (confirms the `#if os(iOS)`/`.automatic` cross-platform split compiles); full suite green (**788 tests**, 0 failures); live on iPhone 17 sim — the Search nav bar now shows filter + timeline + overflow buttons with the field in its own drawer, and the overflow menu opens to **Save this search / Saved searches / Find by citation**. **Caveat / known gap**: `applyParameters(_:)` does not apply `volumeIds`, so the indexing-card "search this volume" handoff still pre-fills without auto-running on iOS — a separate, narrower item left for a future pass. Fix #1's end-to-end run on-device was code-verified only (the simulator had no downloaded corpus and the onboarding "Finish" button was unresponsive); the toolbar fix (#2) was fully reproduced live.

### Session 162 (cont.) — "Search this volume" handoff: iOS Search gains a real volume scope
Follow-up to the known gap noted above. The post-indexing summary card's "Search this volume" action (`IndexingSummaryCard.onSearchVolume`, on both iOS `MainTabView` and macOS `SupportingViews`) sets `AppState.pendingSearch = SearchParameters(volumeIds: [volumeId])`. macOS' `MacSearchViewModel` already applied and surfaced that scope (a clearable "Volume / subseries" `FilterChip`), but the iOS `SearchViewModel` **had no volume concept at all** — no storage property, `searchParameters` never forwarded `volumeIds`, and `applyParameters`/`clearFilters`/`hasActiveFilters` all ignored it. So the volume scope was dropped at three layers: even a keyword typed after the handoff searched the whole corpus, unscoped.

- **View-model data layer** (`SearchViewModel`): added `selectedVolumeIds: [String]`; `searchParameters` now forwards `volumeIds: selectedVolumeIds.isEmpty ? nil : selectedVolumeIds` (`SearchService` applies it SQL-side, already covered by `IndexingPipelineTests` "search filters by volumeIds"); `applyParameters` sets it from the snapshot; `clearFilters` resets it (so the filter sheet's existing "Clear" also clears the scope); `hasActiveFilters` reflects it (so the filter toolbar icon fills). Default `[]` ⇒ `volumeIds: nil`, identical to the previous implicit default — existing `searchParameters` comparisons stay green.
- **UI** (`SearchView`): a dismissible **volume-scope banner** pinned above the results via `.safeAreaInset(edge: .top)` (resolves to `EmptyView` ⇒ zero height when no scope is active). It shows the volume's manifest **title** (not the raw ID — friendlier than the macOS chip) and an ✕ that clears the scope and re-runs any active query. The initial empty-state prompt becomes scope-aware ("Enter keywords to search within this volume."). Matching macOS, a volume-only handoff does **not** auto-run (no executable FTS term — `consumePendingSearch`'s `canRun` stays keyword/phrase/prefix/person only); it applies + surfaces the scope and waits for the user's query.
- **Verification**: iOS + macOS builds clean; full suite green (**789 tests**; +1: `SearchViewTests.volumeScopeRoundTripsAndClears`, plus the existing `applyParameters` round-trip test extended to assert `volumeIds`). Producer (`IndexingSummaryCardTests`) and service-side filter (`IndexingPipelineTests`) were already tested; this closes the missing middle link. **Caveat**: the real post-indexing card needs an actually-indexed volume to appear, which the test simulator lacks, so the round-trip was verified by unit test rather than the on-device card; the banner itself is straightforward conditional SwiftUI fed by the now-tested `selectedVolumeIds`. A multi-volume picker inside `SearchFilterView` remains a possible future addition (the handoff only ever scopes to one volume; the banner is the clear affordance).

### 2026-06-15 — Search ↔ Corpus Analytics coupling: shared volume/subseries scope + By-Volume analytics
Goal: make Search and Corpus Analytics two views of the same result set. Researchers can now use Analytics to see how many documents match a query and **where** they sit across the corpus, then jump straight into Search at the same precision — because both contexts share equivalent volume/subseries filtering. Delivers the "multi-volume picker inside `SearchFilterView`" addition flagged at the end of Session 162. No `SearchParameters` schema change: a subseries is just a group of volume IDs, so everything reduces to the already-plumbed `volumeIds`.

- **Analytics service** (`CorpusAnalyticsService`): added `VolumeFrequency` and `termFrequencyByVolume(term:)` — a near-twin of `termFrequencyBySubseries` that buckets matched documents by full volume ID (matched-only, so volumes with zero hits are omitted automatically). New `volumeFrequencyCache` cleared in `invalidateCache()`.
- **Analytics view** (`AnalyticsView`): new **By Volume** axis (horizontal bar chart + table, titles resolved from the manifest). The categorical **By-Subseries** and **By-Volume** views are now **tappable** — chart bars (via a `chartOverlay` tap→Y-category lookup) and table rows (each a `Button` with a chevron) — and open Search scoped to exactly that subseries/volume via the new `openScopedDocumentsInSearch(volumeIds:)` (term carried, no date range; subseries expands through `CorpusAnalyticsService.subseries(fromVolumeId:)` so the scope matches the bar's own bucketing). A "Tap a bar…" hint advertises it; the whole-chart "View in Search" handoff is unchanged.
- **Search filtering** (`SearchViewModel`): added `selectedSubseriesIds` + `availableVolumes` (indexed-only, via `loadAvailableVolumes(allEntries:indexedIds:)`). `effectiveVolumeIds` unions the individually-selected volumes with every indexed volume in a selected subseries and feeds `searchParameters.volumeIds`. A shared `reconstructScope(from:available:)` round-trips a flat `volumeIds` scope (from a drill-in, `SavedSearch`, or handoff) back into the two pickers — a subseries counts as "wholly selected" only when all its indexed volumes are present.
- **Advanced filter sheet** (`SearchFilterView`): a "Limit to Volumes" section with **two combining, platform-appropriate pickers** — iOS pushes `NavigationLink` multi-select lists (subseries grouped); macOS uses inline `DisclosureGroup` checkboxes (the macOS sheet deliberately avoids `NavigationStack`). Shown only when `availableVolumes` is non-empty; a footer explains the union semantics.
- **Plumbing**: macOS `MacSearchViewModel.applyAdvancedFilters` writes `filterVM.effectiveVolumeIds` back into `parameters.volumeIds`, and `syncToFilterVM` now loads the picker options + reconstructs the selection (call site in `SearchSheet` passes the indexed manifest entries). iOS `SearchView.task` loads the picker options before applying any incoming parameters; the volume-scope banner and the initial-prompt copy now reflect the combined `effectiveVolumeIds`.
- **Verification**: new `CorpusAnalyticsServiceTests` (per-volume bucketing, zero-omission, sort order, blank-term) pass; `CodingStandardsAuditTests` + `SearchViewTests` green; iOS **and** macOS builds clean (project regenerated for the new test file; schemes restored). **Caveat**: the full end-to-end UI flow (pick a subseries → scoped results; tap an Analytics bar → scoped Search) needs ≥2 indexed volumes across ≥2 subseries, which the test simulator lacks — verified by unit test + green builds rather than on-device; a human pass on the live pickers/drill-in is still recommended. By-Volume **chart** Y-axis labels can be long for many-volume results (the **table** is the cleaner view at that granularity); switching the chart label to a compact volume ID is a trivial future tweak if desired.

### 2026-06-15 — Date precision/certainty in the index + a corpus-wide Chronology browser
Goal: deepen the app's use of FRUS document dates. A date audit found the index captures *ranges* faithfully (interval-overlap on `date_iso`/`date_iso_max`) but **loses precision and certainty** — every partial date is padded to a full `yyyy-MM-dd`, so a year-only "1969" is stored (and displayed/sorted) as "January 1, 1969", and the `DateCertainty` enum was computed-in-spirit but never persisted. There was also no way to browse the whole corpus by date. This session delivers both halves; footnote-date indexing and per-date person chips remain sketched follow-ons.

**Phase 1 — persist precision & certainty** (`FRUSASTNode`, `IndexingPipeline`):
- New `DatePrecision` enum (`day`/`month`/`year`); `DateCertainty` gains a `storageValue`/`init?(storageValue:)` for round-tripping through SQLite.
- `document_dates` gains `date_precision` + `date_certainty` columns (additive `ALTER TABLE` migrations). New `extractDateMetadata(from:dateTimeMin:dateTimeMax:)` returns the same normalized interval **plus** precision (from the component count of the *raw* winning `<date>` attribute, before `normalizeToFullDate` — the key fix) and certainty (`exact`=`@when`, `range`=`@from`/`@to` or differing doc-dateTime bounds, `approximate`=`@notBefore`/`@notAfter`, `textOnly`=heuristic). Wired through `DocumentDateRow` + the insert; `currentDateIndexVersion` 8→9 so the existing `needsDateReindex` path re-indexes on next launch.
- `dateMetadataByDocumentKey` exposes the new metadata (consuming it in the existing macOS date-sort / analytics by-day display is a noted follow-on).

**Phase 2 — Chronology browser** (`Chronology/` module):
- Query layer on `IndexingPipeline`: `documentsInDateRange` (ordered `document_dates ⋈ document_cache`, reusing the interval-overlap WHERE of `documentKeysInDateRange`) and `dateBucketCounts` (cheap `GROUP BY substr(date_iso,1,N)`).
- `ChronologyModels` (`ChronologyRow`, `ChronologyParameters`, `DateBucket`), `ChronologyViewModel` (groups rows into date sections, auto-coarsening day→month→year by span and **never rendering a row finer than its own stored precision**, so year-only docs form an honest year section instead of piling onto Jan 1), and `ChronologyView`: From/To pickers + Show, sectioned list with **dense-date collapse + "Show all N"**, section headers showing count badge + "N volumes · M subseries · K editorial notes" + inline density bar, rows showing summary-or-header snippet + volume chip + dateline + editorial/front-matter/`~`approximate badges, tap-to-open, and a "Search in this range" handoff (`pendingSearch` with a date filter).
- Integration mirrors Corpus Analytics: iOS calendar toolbar button + sheet in `BrowserTabView` with a `pendingChronology` `onChange` handoff (new `AppState.pendingChronology`); macOS `frus.chronology` `Window` scene + a sidebar tool button in `MainWindowView`.
- **Verification**: new `DateMetadataIndexingTests` (precision/certainty for exact/range/year/month/approximate) and `ChronologyQueryTests` (range ordering, interval overlap of a multi-day doc, month bucket counts, volume scoping) pass; full `IndexingPipelineTests` + `CodingStandardsAuditTests` green (no date-filter regression); iOS **and** macOS builds clean (project regenerated for the 4 new files; schemes restored). **Caveats**: the live UI flows (dense-date collapse against a real summit date) were verified by unit test + green builds, not on-device (the sim has no indexed corpus); the density chart, tappable-volume-chip-into-volume, per-date person chips, and a `footnote_dates` table were intentionally deferred to keep v1 tight.

### Session 2026-06-15 (cont.) — caught up with v2; Phase 2 app integration (iOS)
First merged `origin/v2` (Sessions 162–163: Search/Analytics coupling, Chronology browser,
date precision in the index). Only two conflicts — DEVELOPMENT-PLAN.md (kept both) and
project.pbxproj (regenerated via xcodegen). Builds clean; v2's new suites green alongside ours.

Then wired Phase 2 into the **iOS** Source Explorer so a pre-1906 document (no source note)
resolves to its diplomatic-series roll(s):
- App model: `CentralFilesIndex` gains `countrySeries` (+ `CountrySeriesIndex`, `CountryRoll`,
  `CentralFilesSeriesCategory`, `rolls(geoKey:dateISO:)`); decodes the schema-2 bundle.
- `GeoKeyNormalizer` mirrored into the app target (kept in sync with the generator) so a
  FRUS chapter name normalizes to the same key as the index.
- `CentralFilesClassifier`: dateline + heading + FRUS chapter → candidate series (Finding 5):
  U.S. mission abroad → Despatches (high); foreign legation in Washington → Notes from (high);
  Department of State outbound → **Instructions + Notes-to** (medium — ambiguous from the
  document alone); consular → none (Phase 3). Plus `datelineDateISO` and
  `chapterCountry(in:documentId:)` (top-level section title from the cached `VolumeStructure`).
- `SourceExplorerView.countrySeriesSection` — for `documentYear < 1906`, classifies and
  resolves each candidate to roll links (confidence chip + rationale); hides the empty
  raw-note section. `DocumentView` passes header/dateline/volumeId/documentId.
- Tests: `CentralFilesClassifierTests` (all 5 reference docs, dateline date, chapter
  resolution, **end-to-end against the real bundled index**). 29 app tests green; iOS+macOS
  build clean.
- **Remaining**: **macOS parity** (Mac Source Explorer is an AppState-driven window — needs
  `currentSourceNote{Header,Dateline,VolumeId,DocId}` primed + a `countrySeriesBox` in
  `MacSourceExplorerView`); iPad Stage-Manager `frus.sourceExplorer.ios` scene similarly
  needs the doc context; enclosure dual-home (Finding 4); live UI walkthrough.

### Session 2026-06-15 (cont.) — Phase 3 generator: pre-resolve lot files (later volumes)
Extend the bundled, key-less approach to State Department lot file citations in later
volumes so researchers get a NARA Catalog starting point without their own API key. Analyzed
a 1.1M-row citations export (`citations2.csv`, 196 MB): **1,743 distinct lot numbers**
(1,553 D-designator RG 59 + 190 F-designator RG 84) across 298 volumes; one-time harvest
~3.5–7k API calls. Built the generator side (app integration next):
- `LotFileCitationExtractor` — parse + normalize lot numbers (compact upper-case key,
  matching the app's runtime form); RG 59 (D) / RG 84 (F) by designator.
- `CitationCSVReader` — streaming byte-level CSV parser (only buffers `plain_text`) that
  survives the 196 MB RFC-4180 export (embedded commas/newlines/`""`). Validated offline
  against the real file (~5 s, 1,500–3,000 distinct lots).
- `NARACatalogHarvestClient.resolveLotFile(normalized:recordGroup:)` — `variantControlNumber_is`
  with compact/spaced/mixed spellings (the proven runtime method), **cached per lot** (hits
  and confirmed misses) so re-runs/partial failures never re-query.
- `LotFileEntry` + `lotFiles` in `CentralFilesIndex` (schemaVersion → 3) + `lotFile(normalized:)`.
- Runner Phase 3: when `CITATIONS_CSV` is set, extract distinct lots, resolve each, merge
  into the index (preserves prior `lotFiles` when the CSV isn't supplied); prints a survey
  (distinct / resolved / unresolved, by RG). `CentralFilesIndexWriter.read` added.
- 59→ now more generator tests green (extractor, CSV reader incl. tricky quoting + a guarded
  real-file check, lot variants, index lookup).
- **Next**: user runs `CATALOG_API_KEY=… CITATIONS_CSV=…/citations2.csv swift run CentralFilesIndexGenerator`
  (the resolved/unresolved survey is the validation gate; spot-check a few well-known lots).
  Then app integration: add `lotFiles` to the app-side `CentralFilesIndex`; in the Source
  Explorer `lotFilePanel`, resolve from the bundle **first** (key-less) and fall back to the
  live API only on a miss.

### Session 2026-06-16 — Lot-file quality (RG verification, match type) + Archival Neighbors
**Lot harvest quality.** First lot runs resolved 948→1578, but ~174+ were false positives
(Census RG 29, Morning Reports RG 407, Criminal Dockets RG 21) — NARA's RG query filter
doesn't constrain free-text results. Fixes: verify each result's *own* record group (from
its recordGroup ancestor) and reject non-59/84; align the phrase fallback to the app's
proven bare-quoted-lot form (this lifted resolution to ~1578 before the RG fix); retry
503/429 with backoff + 60 ms throttle; `RETRY_LOT_MISSES`; emit `unresolved-lots.txt`;
and track `matchType` (control vs phrase) for an app confidence cue. Re-harvest required
(cache stored only naId+title). Expect ~1,300–1,450 trustworthy lots after RG verification.
**Archival Neighbors** (Source Explorer, no harvest needed) — extends `relatedDocuments`:
- `DecimalFileSegment` (new): location (before `/`) + period segment from the suffix year
  (1940+ date form) or the doc's indexed year (pre-1940 sequential).
- `relatedByDecimal` segment-filters same-location candidates in Swift; `relatedByCollection`
  matches non-RG-59 collections on exact (record_group, series_name); lot matching gains
  self-exclusion; `documentYear` + volume/doc ids threaded from both views.
- UI relabeled "Archival Neighbors" with a basis caption (lot / collection / decimal
  location+segment); viewed document excluded from its own neighbors. iOS + macOS.
- 811 tests (+5 DecimalFileSegment); both platforms build clean.
**Remaining**: (1) user runs the clean lot re-harvest (`rm -rf .cache/central-files/lots`
then the CITATIONS_CSV run) → final index with RG-verified lots + matchType; (2) lot-file
*app* integration — add `lotFiles` to the app-side `CentralFilesIndex`, resolve the lot
panel from the bundle first (key-less) with a confidence chip, fall back to live API on miss;
commit the final index.

### Session 2026-06-16 — Phase 3 consular series (Consular Despatches)
Caught the branch up to v2 (PR #61 + subsequent refinements) then initiated consular
harvesting. Survey of Consular Despatches (NARA 302031) confirmed it mirrors diplomatic
Despatches: all 3,357 records are item rolls under a per-post file unit; roll titles
`Despatches: {dates}` (with `Volume N:` prefixes / `CHECK DATE` suffixes that
`HistoricalDateParser` already tolerates); file-unit titles
`Despatches [Ff]rom U.S. Consuls in {City}, {Region/Country}, {dates}` — the post **city**
is the first comma-delimited component.
- **Generator**: new `.consularDespatches` category (302031, item-level, geo = post city);
  `CountrySeriesParser.consularPostKeys` (first comma component; `Brusa (Brousa)` → both
  keys); the harvest loop (`allCases`) picks it up automatically; golden check added
  (Doc 8: consular Havana 1895-06-19 → roll 211373468).
- **App**: `.consularDespatches` added to `CentralFilesSeriesCategory`; `CentralFilesClassifier`
  now routes consular datelines **first** (geo = post city from the dateline via
  `consularPostKey`, independent of the FRUS chapter) → `.consularDespatches` instead of the
  old `return []`. Handles `Consulate…, {City}` and `Consulate … at {City}` forms.
- 64 generator tests + 11 classifier tests pass; iOS + macOS build clean. (Full unit-bundle
  run was confirmed separately after a simulator launch flake on the first attempt.)
- **Next**: user runs the full harvest (`CATALOG_API_KEY=… CITATIONS_CSV=… swift run
  CentralFilesIndexGenerator`; 302031 is cached from the survey, so it's a fast cached run)
  to regenerate the index with the consular series + validate the Havana golden check, then
  commit the index. Other consular series (Consular Instructions 604019, Notes to/from
  Consuls) and Domestic/Misc Letters remain as further Phase 3 work.

### Session 2026-07-02 — Open-with `.fruscollection` feedback (macOS) + duplicate protection
Fixed the silent open-with import: double-clicking / AirDropping a `.fruscollection`
(FRUSExplorerApp.importOpenedCollection) imported correctly but gave no feedback on macOS,
so users re-opened the file and minted silent CloudKit-synced duplicates (each apply()
creates a fresh Collection.id); failures were a DEBUG print only.
- **macOS surfacing**: new `AppState.pendingCollectionSelection` hand-off — set before
  `openWindow(id: "frus.collections")` + `bringMacWindowToFront` (the 21d2ddd pattern);
  `MacCollectionManagerView` consumes it (`.task` for a freshly created window,
  `.onChange` for an open one; consume-and-clear like `pendingSearch`) and selects the
  imported collection.
- **Errors**: open-with failures now present a "Couldn't Open Collection" alert on the
  main window (both platforms), with the DEBUG print retained for the raw error.
- **Duplicate protection**: session-scoped SHA-256 digest → Collection.id map in the App;
  re-opening a byte-identical file re-surfaces the collection it created (if it still
  exists) instead of importing again. Deliberately not persisted — the in-app Import
  button remains the intentional-copy path.
- Docs: both user manuals + both TestFlight instructions describe the new behavior.
### Session 2026-07-02 — VolumeView On-Page Download Completion Fix
Fixed the dead-end left by the Session 2026-06-28 "downloadable from every surface" work
(e971585): tapping **Download Volume** on the iOS VolumeView placeholder showed a static
"Download started." that never progressed — nothing in the view's body observed state that
changes when the transfer finishes (`vm.isDownloaded()` is a raw FileManager check on the
non-Observable `DownloadManager`, and the one-shot `.task` had already bailed on the
not-downloaded guard), so the structure never loaded even after a successful download.
- **VolumeView 2.3**: injected `@Environment(AppState.self)`; the placeholder now shows a
  live "Downloading…" row while the volume is in `appState.downloadQueue` (also covers
  downloads started from other surfaces), and `.onChange(of: appState.downloadQueue)`
  re-runs `loadVolumeStructure` on the present→absent transition — safe because
  `DownloadManager` moves the XML into place *before* firing `onStateChanged`. A failed
  download resets `downloadRequested` so the button is re-offered.
- Branch reorder: the structure/error/loading chain now falls back to the loading row
  (instead of a blank section) during the persisted-structure fast path and the brief
  post-download window, mirroring CompilationView's approach.
- Verified end-to-end in the iPhone 17 simulator: frus1961-63v06 (fast path) and the
  11.8 MB frus1961-63v07-09mSupp (spinner visible) both transitioned Download Required →
  Downloading… → loaded structure without leaving the screen. CodingStandardsAuditTests +
  BrowserViewTests pass (33/33).
### Session 2026-07-02 — Three-week review + reported-bug fixes (reindex bump, title whitespace, neighbors-sheet loop)
Multi-agent review of PRs #108–#136 (word-cloud/analytics, archival neighbors, corpus-browser
rework, volume-sources v2, Collections Phases 1a–4) plus root-cause fixes for the three
user-reported regressions:
- **Missing auto-reindex**: the Session 170 `volume_sources` rewrite (dd816df) drops the
  pre-170 table in its schema migration and only repopulates on a full XML re-parse — its
  commit message says "Requires a re-index" but `currentDateIndexVersion` was never bumped,
  so first launch never triggered one and the Sources outline sat empty until a manual
  reindex. Bumped to **12** with a version-history entry. (03f25f5's spurious-reindex fix
  is innocent — but before it, backgrounding accidentally re-indexed everything, which is
  why missed bumps used to self-heal invisibly.)
- **Corpus-browser title whitespace**: `VolumeStructureParserDelegate` only edge-trimmed
  joined `<head>` text, so hard-wrapped TEI titles carried interior newlines into
  `structureJSON`. Titles now collapse interior whitespace at parse time (regression test
  added); the version-12 re-parse propagates the fix.
- **Archival Neighbors open/close loop**: `VolumeSourcesView.body` is a `Group` emitting
  two Sections, and `Group` applies modifiers per child — `.sheet(item:)` was duplicated
  onto both sections over one shared binding, so the two presenters ping-ponged
  present/dismiss after close. Sheets now anchor once on the Archival Collections section;
  the duplicated `.task` (which re-ran `loadSources` and reset the outline's disclosure
  state) is guarded with `didLoad`. Same guard added to `FrontMatterPersonsView`.
- **Review fix**: `RelatedDocument` lists keyed by `documentId` alone collide across
  volumes (ids are volume-local) — added `compositeKey` and rekeyed ArchivalNeighborsSheet
  + both Source Explorer related-document lists.
- **Test health**: `WordCloudTokenizerTests.pluralFoldDisabled` was NL-asset-dependent
  (lemma availability for bare "treaties" varies); now uses a nonsense plural.
  `SettingsSyncCoordinatorTests` crashes the test host (SwiftData trap) on a **clean v2
  checkout** — pre-existing, spun off as a follow-up task with 3 other verified review
  findings (word-cloud cluster, legacy-prose export loss, iOS volume Download button,
  macOS .fruscollection import feedback).
- 959 unit tests pass (excluding the pre-existing crashing suite); iOS + macOS build clean.
- **Next**: collection-editor rework scoping (manager → authoring canvas; see session
  recommendations), plus the spun-off fix tasks. The next build's TestFlight notes must
  mention the one-time automatic re-index on first launch.

### Session 2026-07-02 (later) — Collections Authoring scope
Authored `Planning/Collections-Authoring-Scope.md` — the 6-phase program turning the
collection editor into an authoring tool for "rich historical products" (the owner's
2026-07-02 request). Synthesized from a 3-angle design panel (product-first /
architecture-first / effort-ROI-first + judge) over a verified current-state survey.
Backbone: §0 target artifact ("the FRUS Reader") → Phase 1 editor shell + unknown-kind
sync guard → Phase 2 single resolver + live preview → Phase 3 in-editor discovery
(search/browse/paste-citations/tag) → Phase 4 publication frame (front matter, level-based
nested sections, `.fruscollection` v2) → Phase 5 annotated document (headnotes, excerpts,
read-write inspector, footnote tri-state fix) → Phase 6 generated apparatus (bibliography,
chronology, sources & archives, persons, thematic index as placeable entries). Decision
points A1–A12 for the owner; Phases 1–3 carry zero schema/format risk. Key safety rails:
ship the `entryKind` `.unrecognized` fallback first (mixed-build CloudKit sync), never
re-purpose `sortOrder` (level-derived tree instead of parent pointers), one batched
`.fruscollection` bump with write-minimum + tolerant reader.

### Session 2026-07-02 (later) — Collections Authoring Phase 1 (implementation)
Executed Phase 1 of Planning/Collections-Authoring-Scope.md in two PRs:
- **PR #139 (merged): mechanics.** Mechanical split of CollectionEditorView.swift (2,836 →
  845 lines + 6 new per-type files, verbatim moves, one visibility change). Unknown-entry-kind
  sync guard (`CollectionEntryKind.unrecognized`): unknown kinds render inert, are skipped by
  resolve/native-export/native-import, never persisted, excluded from allCases — must age in
  the field before Phases 5–6 add new kinds. Shared `CollectionEntryData` (bulk header/date
  loader + canonical 3-tier date sort) used by both managers; iOS rows show real headers/
  volume titles/dates; iOS Sort by Date gains per-document precision. fileImporter narrowed
  to the `.fruscollection` UTI. New `unrecognizedKindGuard` test; 41/41.
- **PR 2: shell.** `CollectionEditorView.PresentationStyle` — pushed from the Collections tab
  (navigationDestination; back dismisses), sheet elsewhere (Done button). All-live autosave
  (A1 cheap): onChange → saveLive(); Save/Cancel and applyEditsForExport deleted; untouched
  new collection discarded on dismiss, kept-unnamed gets "Untitled Collection". iPhone:
  entry-list-primary Form — collapsible Details (name/note/smart link; expanded for new) +
  collapsed Composition disclosure. iPad: `.inspector` panel (toolbar-toggled) for metadata +
  composition, list gets full width. macOS manager: Composition popover → inline collapsed
  DisclosureGroup at the top of the scrolling entries List (inline per scope, but inside the
  scroll region so expansion can't overflow the fixed header — preserves the #126 constraint).
  Docs rider: iOS/macOS manuals §10 + both TestFlight instructions.

### Session 2026-07-02 (later) — Legacy-prose export data-loss fix
Closed the spun-off "legacy-prose export loss" finding: Phase 3b (9f1c648) persisted
`CollectionEntry.richText` as a JSON-encoded `AttributedString`; the RTF switch (05d31c7)
added no migration, so `ProseRichText.exportRTF` returned legacy blobs verbatim,
`CollectionProse.paragraphs(fromRTF:)` failed the RTF decode and returned `[]`, and all
three exporters (HTML/DOCX/PDF) silently omitted the prose block — even though the plain
text sat in `entry.text`. Fix, layered so no reader can drop prose again:
- **`ProseRichText.exportRTF`** now always emits valid RTF: stored RTF verbatim → legacy
  JSON converted (bold/italic `inlinePresentationIntent` → concrete font traits, so
  formatting survives) → plain `text` fallback. Conversion also migrates the entry in
  place (`migrateLegacyJSONIfNeeded`), so the first export heals the store.
- **`CollectionProse.paragraphs(fromRTF:)`** — the single decode path shared by all three
  exporters — falls back to decoding the legacy JSON encoding directly, covering raw
  legacy payloads that bypass `exportRTF` (pre-fix `.fruscollection` files, tests).
- **Editor**: `RichTextEditor` loads legacy blobs with formatting intact; the prose row
  migrates on appear. **Native format**: `makeFile` heals before emitting, so shared
  `.fruscollection` files honour the schema's "richText is RTF" promise.
- Unrecognizable blobs (neither format) are left untouched and export the plain `text`
  projection — never destroyed, never silently dropped.
- 4 new tests (legacy export+migration, garbage fallback, decoder fallback with paragraph/
  bold recovery, HTML/DOCX/PDF end-to-end); 30/30 CollectionTests + 15/15
  CodingStandardsAuditTests pass; exporter version histories bumped (HTML 1.7, DOCX 1.5,
  PDF 1.8, NativeCollectionSerializer 1.1, ProseRichText 1.1).

### Session 2026-07-02 (later) — SettingsSyncCoordinatorTests host-crash fix
All four `SettingsSyncCoordinatorTests` SIGTRAPped the test host ("Restarting after
unexpected exit…"; each case listed under Failing tests). Root cause was **container
lifetime, not CloudKit**: the test helper returned `container.mainContext` and dropped
the `ModelContainer` — `mainContext` does not retain its container, so the first
`context.fetch` in `SettingsSyncCoordinator.resolveCanonical` trapped inside SwiftData
(crash report: `EXC_BREAKPOINT` in SwiftData ← `resolveCanonical(create:)`, no fatal
message emitted). The CKAccountStatusNoAccount noise in the log was a red herring —
verified by re-running with `cloudKitDatabase: .none` alone, which still crashed.
- Fix: helper now returns the container; each test holds it for its whole body (the
  pattern every other suite already used).
- Hermeticity: test containers now pass `cloudKitDatabase: .none` explicitly — the
  default `.automatic` adopts the test host's iCloud entitlement and spins up real
  CloudKit sync machinery (CKNotificationListener registration was visible in the sim
  log). Same fix applied to `ModelContainer.makeTestContainer()`, whose doc comment
  already claimed "CloudKit sync is disabled" without actually disabling it.
- `collapsesDuplicates` UserDefaults cleanup moved into `defer` so a thrown fetch error
  can't leak the key.
- The fifth reported failure (`WordCloudTokenizerTests.pluralFoldDisabled`) was already
  fixed at the v2 tip by 182f297 (nonsense-plural probe); verified passing.
- Full unit-test bundle: 968 tests in 152 suites, all pass (iPhone 17 sim, iOS 26.5).

### Session 2026-07-02 (later) — Collections Authoring Phase 2 (resolver + live preview)
- **PR #148 (merged): CollectionContentResolver.** All resolution extracted from the export
  sheet (1,272 → 670 lines) into one @MainActor service: unified smart path (smart collections
  now honor notes/highlights/source-note/summary composition — previously silently dropped),
  AST-cache-backed render models (cache invalidation rides the existing volume delete/re-index
  path; one parse serves body text + render model), `.export`/`.preview` purpose gating
  (.preview never downloads volumes or triggers AI), per-item `resolveItem` API. Golden-file
  resolve test + smart-composition + preview-gating tests. 972/972.
- **PR 2b: shared renderer + live preview.** `CollectionItemHTMLRenderer` factored from
  HTMLCollectionExporter — one per-item HTML function serves export AND preview (byte-identity
  test proves no drift; export bytes verified identical to pre-2b). Exporter contract test
  (all 5 exporters × all item kinds; PDF leg asserts extracted text). `CollectionPreviewView`:
  WKWebView, ~1s debounced re-resolve on an entries+composition fingerprint, 20-doc initial
  cap ("Render All" lifts; smart searches pre-cap before any parsing), citation cards +
  native Download bar for missing volumes (poll keyed on the missing set; manifest-absent ids
  shown "not available"), summary-placeholder cards in preview, honest "HTML export" label
  (A2 cheap). iPhone Outline|Preview toggle; iPad + macOS side-by-side with eye toggle.
  Adversarial review pass fixed 9 findings pre-PR (smart-set pre-cap HIGH, LRU cap
  interaction, resolver cooperative cancellation, stale citation cards, phantom download
  state, export CSS purity, PDF contract leg). Docs rider: manuals §10.5 Live Preview,
  TestFlight files, IndexingEducationView. PR 2c (scroll-sync/incremental refresh) deferred
  as optional.

### Session 2026-07-02 (later) — Collections Authoring Phase 3 (in-editor discovery)
`CollectionAddDocumentsSheet` (new): four tabs over one shared multi-select set with a
persistent "Add N Documents" bar — Search (debounced FTS5, 100-cap), Browse (two-level
manifest → indexed-document list; download/index affordances for missing volumes),
Citations (paste footnotes or history.state.gov URLs; per-line resolved/ambiguous/
unresolved buckets via the closure-injected `CollectionCitationLineResolver`; hsg-URL
matcher added — none existed), Tags (note-carried tags ∪ `DocumentTagAssignment`,
replacing + deleting AddByTagSheet). Entry points: iOS "Add Documents…" section + header
menu; macOS toolbar ⇧⌘A. **A4 resolved cheap**: duplicates allowed; "Also in collection"
badge on both platforms' rows (composite-key duplicate set at pane level). **A5: deferred.**
Adversarial review → 8 valid findings fixed pre-PR, incl. citation false-"resolved"
downgrades (volume-only outranking; subseries-less guesses), macOS Return-key committing
the sheet mid-flow, and `CitationMatchingEngine.downloadedVolumeIds` upgraded from a
boot-time snapshot to live updates on indexing completion (fixes download-then-re-resolve
for CitationLookupView too). 9 new unit tests; docs rider (manuals, TestFlight files,
IndexingEducationView). Full suite 984/984. Phases 1–3 (the zero-schema-risk arc) complete.

### Session 2026-07-02 (later) — Corpus analytics research review (planning only)
Reviewed three open-source publications applying quantitative methods to the FRUS corpus
(FRUS series history Appendix A timeliness/production charts; Hensler, "It's Late," DttP
54:1 2026 on volume organization/geographic emphasis; KG-FRUS knowledge-graph dataset,
arXiv:2311.01606) against the app's current analytics surface and indexed-but-unsurfaced
data (person_mentions/person_rollup, cross_references-as-statistics, manifest
publication/coverage dates, tag taxonomy). Produced
`Planning/BigPicture-CorpusAnalytics-Roadmap.md`: 12 prioritized feature recommendations —
corpus-baseline normalization for existing term charts, person trajectory/comparison
charts (also resolves the `topTermsByYear` stub), series production & timeliness
dashboard, geographic attention explorer, cross-reference statistics, co-mention
networks, and a deferred `place_mentions` schema addition. No code changes.
### Session 2026-07-02 (later) — Collections Authoring Phase 4 (publication frame)
Four commits: (1) **model+format** — `CollectionEntry.level` (level-encoded nesting; global
sortOrder untouched), `CollectionOutline` single linearizer (clamp 1–3, orphan-jump repair,
sectionRange/canIndent/canOutdent, ancestor body-depth cascade — D5 falls out), Collection
front matter (subtitle/authorLine/introduction RTF+plain/includeColophon), `.fruscollection`
v2 (write-minimum: no-v2-features files emit byte-identical v1; minimumReaderVersion floor,
defaulted 1; tolerant reader). (2) **exporters** — `.heading(String, level:)`; title page +
introduction (leading prose item via the shared RTF path) + nested ToC + opt-in colophon in
HTML/PDF/DOCX + preview; title page/colophon metadata-driven (items stream unchanged);
byte-compat proven by frozen-literal tests; DOCX levels map to custom SectionHeading2/3
styles (NOT built-in Heading2/3 — those are used by citations/TEI headings). (3) **editor** —
depth-indented rows, collapse/expand (view state, "N hidden" badge), heading context menu
(rename/indent/outdent/delete-heading-vs-section), **move-section-as-a-unit** via a shared
pure move engine (unit-tested), front-matter UI on all three surfaces, docs rider.
(4) **review fixes** — 5/5 valid: HIGH = DOCX ToC field widened unconditionally (now emits
pre-Phase-4 `\o "1-2"` unless an authored level-3 exists); macOS normalize-before-reindex
no-op; three docs corrections. A6 resolved cap-3-UI-only; A7 resolved RichTextEditor as-is.
Full suite 1001/1001.

### Session 2026-07-03 — Collections Authoring Phase 5 (annotated document)
Four commits on claude/authoring-phase5-annotation: (1) **footnotes+headnotes** —
`includeFootnotes`/`includeSourceNote` Bool pair (nil = derive from legacy `footnoteStyle`;
dual-write preserved for old devices; "all footnotes AND source note" now expressible;
PDF/DOCX never consumed the tri-state — left ungated for byte-compat, flagged as follow-up);
headnotes (`includeHeadnote` + `headnoteSummaryId`): chosen AI summary as an abstract above
the full body ×3 formats + preview; prompt-aware inspector summary display. (2) **excerpts** —
`CollectionEntryKind.excerpt` (rides the Phase 1 kind guard): frozen verbatim quotation +
auto-citation source line (HTML figure/blockquote, PDF accent-bar flow, DOCX quote styles);
anchors (`excerptStart/End` unicode-scalar + `excerptRenderingVersion` + `excerptColorTag`)
stored at creation per A9 — precision slicing stays a rendering-only flip; three creation
paths (bulk "Add Highlighted Passages" sheet, document-view selection on both platforms via
`FRUSDocumentWebView.onSelectionChanged` offsets, per-highlight in the inspector); all
funnel through `CollectionExcerpts`; never serializes highlight UUIDs. (3) **inspector** —
read-write per-entry control surface: per-highlight selection (A8, empty = all),
notes/source-note/footnotes/highlights overrides, summary-prompt override, related-documents
toggle (A10: in-collection targets only, "See also:" line ×3 formats); heading entries carry
the same fields as section defaults via the generic `CollectionOutline.sectionOverrideValues`
cascade — resolved ONLY in the resolver; `selectedHighlightIds` deliberately omitted from
.fruscollection files (referenced highlights don't travel). A12 = notes stay trailing blocks.
(4) **review fixes** — 5/5 valid: multi-paragraph excerpt block-boundary fix (flat-text
block partitioning in FRUSRenderNode), macOS capture re-extraction (anchors always delimit
the frozen passage), iPhone overflow-menu anchor preservation, capped-preview A10 membership
from full model, timeline excerpt double-count. Full suite 1020/1020.
