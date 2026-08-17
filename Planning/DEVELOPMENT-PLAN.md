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

## Session 2026-08-06/07 — the N wave: archival resolution (build 40)

Fifteen PRs, #710–#728. Every figure below was measured against the corpus with shipped code, not
estimated; every parser change was mutation-tested.

**#681 presidential libraries** — #709/#710 wired the bundled library catalogue into Source
Explorer, answering **43.8% of 30,417 documents** offline and suppressing the live query where it
answers. #711 carried the unverified caveat into Copy and Export (26,667 documents had been
exporting caveat-free) and re-landed a fix #710 lost. #720 fixed the macOS escape hatch that
opened only on a *successful* manual search.

**#353 parser recoveries** — eight PRs (#712–#719) moving **~3,010 documents** and taking corpus
`unrecognized` from **2.8% → 2.2%**. Status comment on the issue lists what is left; the largest
remaining item is the 36,063 named-subfile decimal classes.

**#354 archival routing — CLOSED.** #721 Paris Peace Conference (1,547), #722 the numerical-file
format gate (334, a *wrong-answer* fix), #723 manuscript repositories (564), #724 named file
series (1,763). Two of its five items were closed unbuilt after measurement showed they return
nothing. **4,208 documents** total.

**#668 front-matter Sources — CLOSED.** #725 read the paragraph-encoded list (14 volumes, +526
collections), #726 fixed a book list being filed as archival collections and attached each
description to its collection, #728 fixed a `ForEach` identity collision and gave front-matter
rows the library route. Index version 33 → 36 across the wave. Residue split to **#727**.

### Lessons worth carrying

- **The issue's own comments reversed its body twice** (#675, #354). Read them before scoping.
- **A count going up is not evidence a rule is right.** #719's first measurement reported 89
  documents; a test found `Lot 52–242` truncating to `52`, and 29 of the 89 were wrong.
- **Two of #354's proposed record-group mappings were contradicted by the volumes themselves.**
  262 documents were left unrouted rather than sent to record groups that do not hold them.
- **Mutation testing found what review did not** — twice: a source audit that could not detect a
  logic change (#721), and a library match that would have silently lost 57 collections (#728).
- **The simulator app host wedges per-device.** A control run of the *unmutated* suite is the only
  way to tell a wedge from a surviving mutant; switching devices clears it.

### Owed

- `SourceExplorerExportGenerator` re-run + new `eval-baseline.txt` (#353's own closing step).
- `macManualSearchSurvivesSuppression` is a presence check, not a behaviour check — lift the
  condition out of the `ViewBuilder` into a testable predicate.
- Screenshots for the four new Source Explorer surfaces (see #106).

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

### Session 2026-07-03 — Collections Authoring Phase 6 (generated apparatus) + PDF/DOCX footnote gating
Four commits on claude/authoring-phase6-apparatus: (1) **footnote gating** (owner decision
2026-07-03): PDF/DOCX now honor `includeFootnotes` (footnote bodies/section suppressed,
inline markers kept — HTML's exact semantics; per-entry override cascade respected;
untouched collections byte-identical, DOCX proven byte-for-byte). (2) **apparatus core** —
`CollectionEntryKind.generated` + `generatedBlockType` (typed vocabulary: bibliography/
chronology/archivalSources/personsIndex/thematicIndex w/ default front/back positions);
`CollectionExportItem.generated(CollectionGeneratedBlock)` pre-resolved rows → ONE switch
arm per exporter; real DOCX hyperlinks (external relationships, xmlns:r only when used);
Apparatus submenu in both editors; unknown block types = inert entry (re-exported intact);
rows never serialized — blocks re-resolve on recipient data. (3) **five blocks** via
`CollectionGeneratedBlockDataSource` seam (hermetic tests): bibliography (dedupe, series
order), chronology (precision-honest labels, Undated group), sources & archives
(document_sources aggregate + bundled NAID links), persons index (People-browser rollup
path reused; ≥2-doc threshold when ≥4 docs), thematic index (note-tags ∪ assignments).
(4) **review fixes** — 7/7 valid: smart collections now include apparatus blocks
(front/back per defaultPosition; capped previews feed full membership); DOCX markdown-
italic run fix; fullCitation dedup; person_mentions row-value IN (index-usable, was a
full-table scan per preview refresh); PDF overtall-row pagination; deterministic persons
ordering. Full suite 1036/1036. **THE SIX-PHASE AUTHORING PROGRAM IS IMPLEMENTATION-COMPLETE.**
Remaining wrap-up: the scope's closing consolidated docs pass + build bump (TestFlight notes
must mention the one-time reindex from the version-12 bump if build 28 hasn't shipped).

### Session 2026-07-03 (later) — Build-prep batch: loop fix (verified), 3 features, 3 audits, quick wins
Branch claude/build-prep-fixes, 8 commits:
- **Archival Neighbors loop, third time final**: real cause = presentation modifiers on
  Group/Section content INSIDE List apply per row (first fix just moved the duplication);
  presentation hoisted to the parents' List containers (CompilationView + macOS corpus
  section view); FrontMatterPersonsView hoisted identically. **Runtime-verified** in a
  dedicated simulator: neighbors ×4, cross-volume, person detail — all present once and
  stay dismissed; disclosure state survives.
- **Rich text**: visible formatting toolbar (B/I/U/color/Link) on every editor — macOS
  button bar w/ selection state + NSColorPanel follow-focus, iOS inputAccessoryView;
  LINKS shipped end-to-end (.link → RTF HYPERLINK → HTML <a>/DOCX w:hyperlink/PDF visible
  URL); LISTS declined with documented reason (NSTextList markers are layout-generated —
  plain projection + span model would silently lose list semantics).
- **Long titles**: all corpus-browser surfaces wrap complete titles (618-char frus1865p4
  calibration); nav bars keep system truncation but every long title now appears in full
  in content (VolumeView metadata header, CompilationView title section, macOS detail headers).
- **AI attribution**: "AI-generated summary · Apple Intelligence (on-device)" caption on
  every exported summary/headnote ×3 formats + preview via shared CollectionAIAttribution
  (GeneratedSummary stores no model id — documented seam if one is ever recorded).
- **Three audits committed** (Planning/Source-Explorer-Audit / People-Browser-Eval /
  UI-Audit -2026-07-03.md): Source Explorer = extractSourceNote misses nested source notes
  → <1% coverage 1955-91 (~77k docs), fix ceiling 24%→86% lot resolution, 5-phase draft
  scope enclosed; People = 67 conflated rollups + one-line iOS Find-All-Mentions bug +
  671 junk rollups + 6,486 orphaned split-set mentions; UI = 8 macOS sheet types → windows
  (14 sites), TextFormattingCommands missing, Dynamic Type unsupported (344 fixed fonts).
- **Audit quick wins shipped**: Find All Mentions fixed + rollup-scoped (iOS tab switch;
  rollupId passed on both platforms); personRollupVersion→8 (authority cannot-link at
  union time, Mrs./Jr.-Sr. normalize fixes, majority-by-mentions authority pick, index-
  artifact purge); currentDateIndexVersion→13 (split-set `volumeId#fragment` person refs
  normalized — rides the unshipped build's existing first-launch reindex);
  TextFormattingCommands(); .contentShape tap targets on browser rows.
**Next sequences for owner review:** Source Explorer program (draft scope in the audit),
macOS sheet→window conversions + accessibility mitigations (UI audit), consolidated docs
pass + build bump (TestFlight notes: authoring suite + one-time reindex).

### Session 2026-07-03 (later) — Source Explorer program: scope + Phase 1 (extraction fix)
Scope formalized: Planning/Source-Explorer-Provenance-Scope.md (PR #156) — 5 phases,
decision points S1–S6, verification = the audit's reproducible queries. **Phase 1 shipped**
(claude/sourceexplorer-phase1-extraction, 3 commits): frus-sources locator chain ported
into extractSourceNote (head/note/p/seg → head/note w/ Source: prefix → top-level inline,
with the review-hardened dual-encoding priority: head remarks defer to top-level citations —
full-corpus replay over all 694 volumes showed exactly 25 docs change, all improvements);
[Source: …] wrapper normalization keeps the Source: prefix so parseNarrative fires;
S1 classification split → document_sources.classification (conservative marking-vocabulary
gate); extractHeader now excludes footnote descendants of <head> — source-note text had
been leaking into EVERY 1955+ document's displayed title (bonus corpus-wide title cleanup);
display-side extractor unified with the pipeline's. currentDateIndexVersion 13→15 (impl+fix).
**Measured on real TEI (era table in PR #157):** 1955+ coverage <1% → 87–98% raw (100% of
eligible; residue = editorial notes, genuinely sourceless); structured rows 0 → 378 across
7 sample volumes; the audit's known lots now resolve (66 D 204 → 74 neighbors, 77 D 163 → 31).
Lasting RealTEICoverageTests gated on FRUS_TEI_MIRROR. 1075/1075. Next: Phase 2 (parser v2 +
citations.csv eval harness) on owner go.

### Session 2026-07-03 (later) — Source Explorer Phase 2 (parser v2 + eval harness)
Four commits on claude/sourceexplorer-phase2-parser: (1) **SourceNoteKit + harness** —
SourceNoteParser relocated to a shared SPM target compiled directly into both app targets
(FTS5Store pattern; one source of truth); SourceNoteEvalGenerator runs the parser over all
267,663 real source notes in citations.csv (dependency-free RFC-4180 streaming reader;
deterministic diffable report; DUMP env for positional regression diffs); baseline committed
(24.3% unrecognized overall). (2) **grammar v2** — decimal word-infix refs, lowercase/comma +
lot-leading + en-dash lot styles, prefix-less library notes, named file series (new
ParsedSourceNote.namedFileSeries + citation_era='named_series', all consumers audited),
`document_sources.lot_file_norm` canonical key (uppercase, dash/space-free — Phase 3 reads it,
volume_sources will write the same form); currentDateIndexVersion 15→16. **Results: overall
unrecognized 24.3% → 2.8%; 1906–39: 19.3→1.1%, 1940–51: 39.3→1.5%, 1952–54: 42.6→7.4%,
1961–63: 15.2→3.1% — every target beaten; ZERO recognized→unrecognized regressions
(positional diff over the full corpus); 226 deliberate reclassifications in 3 audited classes.**
(3+4) review found 5 (1 med: colon-tail junk in 1,024 lot_file_norm keys → 0 after fix;
namedFileSeries ordering; FRC RG misattribution on Nixon materials; OpenAPI enum; dotted-
decimal file ids) — all fixed with corpus probes. eval-baseline.txt + eval-report.txt
committed in SourceNoteKit/ as the permanent regression corpus reports. 1083/1083 app +
272/272 SPM. Next: Phase 3 (volume_sources keying + inheritance + normalized matcher —
cashing the 86% ceiling).

### Session 2026-07-03 (later) — Source Explorer Phase 3 (keying, inheritance, normalized matcher)
Four commits on claude/sourceexplorer-phase3-keying: (1) **front-matter keying** — shared
lot grammar in SourceNoteKit (`firstLotReference`: designator-agnostic D/F/W/M, en/em-dash,
run-together, "Lot Files" infix; doc-side tryLooseLotFile delegates to it — one grammar both
sides, +7 doc-side notes recognized); outline inheritance (ancestor-frame walk fills
record_group/repository on children); volume_sources gains lot_file_norm + decimal_class
(verbatim-form class leaves; RG/FRC excluded); series junk-tail gate; currentDateIndexVersion
→18 (Phase 2 fix had taken 17). (2) **matcher** — single indexed lot_file_norm lookup
(4-variant IN retired); relatedByCollection → comma-boundary prefix w/ guards; NEW
relatedByDecimalClass (4 boundary shapes + CFPF prefix; **S3 resolved lean** — DecimalFileSegment
port declined w/ documented rationale) and presidential-library volume-level path;
VolumeSourceNeighborsTarget gains repository/decimalClass through both parents; bibliography
rows render in a "Published Sources" section w/o affordances. (3) **measurement** (13 real
volumes, 1,713 items, app's own calls): keyed 14.5%→47%; within-sample lot resolution 62%;
corpus-wide predictor 84–85% ≥ the 80% target (ceiling 86%); class path found DEAD end-to-end
and fixed in-session (0→228 keyed); F-lots 0→32 keyed/17 resolving; bucket re-run B2/B3≈0
(cross-volume + genuinely-uncited dominate). (4) **review fixes 7/7** — medium: bibliography
exclusion keyed on `listofworks`, which a 694-volume survey proved NONEXISTENT (real encoding
= "Published Sources" pseudo-headings; rebuilt + ~3,008 rows now correctly marked); class-gate
hardening; plural "Lots"; spaced letter-suffix parity; doc-comment accuracy. 1100/1100 app +
279/279 SPM. Remaining: Phase 4 (cross-volume authority; S4/S5) + Phase 5 (three-state UI,
classification chips, S6 window).

### Session 2026-07-04 — Source Explorer Phase 4 (cross-volume collection authority)
Three commits on claude/sourceexplorer-phase4-authority. **Owner decisions: S4 = two levels,
S5 = local counts only.** (1) **generator** — sibling CollectionAuthorityGenerator (Core/exe/
tests) parses all 694 TEI volumes with the SHARED SourceNoteKit grammar (key-producing rules
centralized in SourceNoteKit/CollectionKeying.swift — generator and app agree by construction,
proven by byte-identical artifact across the refactor); two-level conservative clustering
(lot-norm always merges; textual merges same-repo only; unattributed never joins attributed;
generic/locator segments never key; central-files → DoS override); bundled
collection-authority.json = 4,464 records / 7,739 children / 5,473 aliases / 939 NAIDs,
1.92MB ≤ budget, byte-deterministic; 477 ambiguous clusters deliberately unmerged (committed
report). Coverage: lot-keyed 100%, overall 81.2% of Phase-3-keyed items. (2) **app** —
CollectionAuthorityIndex store; CollectionDetailView (aliases, NAID link, corpus volume list,
S5 local stats via IndexingPipeline.localCollectionStats, neighbors incl. per-child
decimal_class); VolumeSourcesView rows upgrade to "Collection · cited in N volumes";
Source Explorer gains Archival Collection sections + browse-by-collection
(CollectionBrowserView; macOS Collections segment in the window); alias-fallback in the
matcher (direct-first, display-time only, basis names the alias). Docs rider both manuals +
TestFlight + education view. (3) **review fixes 6/6** — HIGH: secondary-copy citations minted
phantom "Department of State" records for presidential-library collections (library-name gate;
phantom buckets verified gone in regenerated artifact); name-initial truncation merges;
S5-count/neighbors-agreement doc fix; unattributed-bucket ambiguity guard; symmetric
central-files override; extractor-parity tests. 1120/1120 app + 317/317 SPM.
**Remaining: SE Phase 5** (three-state UI, classification chips, S6 = neighbors window on
macOS — owner call) → then the consolidated docs pass + build bump (reindex v18).

### Session 2026-07-04 (later) — Source Explorer Phase 5 (UI truth, S6 window) — PROGRAM COMPLETE
Four commits on claude/sourceexplorer-phase5-ui. **S6 owner-resolved: Archival Neighbors is
a WINDOW on macOS.** (1) **UI truth** — three-state neighbor affordance: ONE batched count
query per key family at volume load (neighborCountKey = single path-selection truth shared
with the per-tap query, so badge ≡ sheet by construction); keyed-0 rows render subdued w/
honest "no documents in your indexed volumes" help text; alias fallback EXCLUDED from counts
(13 non-indexed LIKEs — documented may-exceed-badge caveat). Classification chips (S1 column)
on Source Explorer both platforms, reading views (opt-in serializer annotation — exports
byte-identical), and search rows (free — sourceNote already loaded). (2) **S6** —
ArchivalNeighborsRequest (Codable/Hashable, 4 query shapes, alias fallback flattened +
reconstructed) via WindowGroup(for:); window-per-distinct-request, restoration enabled;
shared ArchivalNeighborsContent core (iOS sheets unchanged); every macOS presenter converted
(SearchSheet, CompilationView, VolumeSourcesView via openWindow-as-action, CorpusSectionDocumentView,
graph node menu); row taps hand off via pendingBrowseDocument, window stays open; UI-audit
doc line marked converted. (3) **program docs pass** — both manuals §12 rewritten coherently,
TestFlight paragraphs replaced, guide/education verified, README updated, scope Status closed
with S1–S6 resolutions. (4) **review fixes 3/3** (fix agent died mid-commit; staged work
verified + committed by orchestrator): restored-window boot race → "Preparing your index…"
gate; Group-gotcha double query; stale count badges refresh on indexing completion.
1133/1133. **The Source Explorer Provenance program is complete: <1% modern coverage → 87–98%;
unrecognized 24.3% → 2.8%; front-matter resolution 25% → ~85% predicted (86% ceiling);
corpus-wide collection authority; truthful UI.** Remaining before testers: consolidated docs
pass + build bump (reindex v18).

### Session 2026-07-04 (later) — macOS UI audit pass (window conversions + a11y quick wins)
Branch claude/macos-ui-audit, 5 commits (workflow ran the first 4 stages; a11y stage was
interrupted by a credit limit mid-A8 and finished + verified manually on Opus 4.8).
**Windows (owner rule: prefer windows over modal sheets):** B2 Cross-Volume Provenance →
value window + navigable rows (new AppState.pendingBrowseVolume hand-off); B3 NARA Lookup →
third segment of the Source Explorer window; B4 Citation Lookup → own frus.citationLookup
window (⌘⇧F moved to the scene); B5 People index → frus.people window (single window-level
detail sheet, no more stacked sheets); B6 volume graph → frus.crossReferenceGraph via
pendingVolumeGraph; B7 macOS WhileIndexing auto-modal removed (banner button opens the
Research Guide window); B8 entry inspector → .inspector column on the Collections window.
Every new scene copies the Phase-5 boot-race guard ("Preparing your index…"); Cross-Volume
window is manifest-backed so needs none. **Borderlines:** C1 note composition → utility
window (frus.noteComposer) so the document stays readable; C4 advanced search filters →
live-apply popover; gaps 16/19 window sizing. **Keyboard:** Collection + Document CommandMenus
via focusedSceneValue (New/Export/Add Documents/headings/preview; prev/next doc ⌥⌘↑↓, add
note ⌘⇧N, highlight ⌘⇧H, research panel ⌘⇧R — all collision-checked); List(selection:)
keyboard-navigable rows. **A11y quick wins:** A3 highlight-picker labels + no-color glyph;
A4 VoiceOver Move Up/Down on outline rows; A5 .isSelected traits; A6 stateful toggle labels;
A8 sentiment cloud +/− marks (screen + PNG/PDF export); A10 graph control labels. **Self-review
(the workflow's adversarial stage was cut by the credit limit):** verified the two
highest-risk categories — no orphaned macOS sheet presentations of converted views (all
correctly #if os(iOS)-gated or intentional), and boot-race guards present in all four new
window scenes. 1146/1146; both platforms build. **Deferred:** A1/A2 Dynamic Type (own pass);
consolidated docs pass now covers the windows/shortcuts story for the manuals + TestFlight.
Reindex version unchanged (18 — no parse-output changes).

### Session 2026-07-04 (later) — Dynamic Type accessibility pass (UI audit A1/A2)
Branch claude/dynamic-type-a11y, 4 commits. Careful, scoped pass (NOT find-replace) —
the app had exactly ONE scaled-font site before this. **Foundation:** documented
size→text-style convention + `@ScaledMetric` pattern in FRUSTheme (scalable captionFont/
captionSmallFont tokens; `cappedGlyphSize` helper), worklist at
Planning/Dynamic-Type-Worklist.md classifying all 346 `.system(size:)` sites. **Converted
40 sites** (iOS-primary: OnboardingView, OnboardingIntroView, IndexingBannerView,
IndexingQueueBannerView, IndexingContextCard, IndexingSummaryCard, DocumentView, SearchView,
ResearchView — text→text-styles, hero glyphs→@ScaledMetric with a working 1.6× cap).
**A2 (the flagged item):** RichTextEditor iOS gets `adjustsFontForContentSizeCategory` +
`displayScaledForDynamicType` (UIFontMetrics remap of stored concrete RTF fonts, display-only)
+ `baseNormalizedForStorage` (collapse to canonical 13pt base on serialize — chosen over
inverting the non-linear metrics curve; RTF bytes byte-identical at every content size,
proven: no exporter/plain-projection consumer reads point size); highlight-picker detent
[.height(180)]→[.height(180),.medium] + ScrollView so it grows not clips. **Deferred (worklist-
backed): 284** — 262 macOS-chrome (FRUSSettingsView 145/SupportingViews 72/SearchSheet 45,
lower value + higher layout risk) + 22 permanent LEAVE-FIXED (graph-canvas labels scale with
zoom not type; word cloud has bespoke sizing). Review APPROVED (verified no canvas/word-cloud/
chrome wrongly scaled — all deferred files byte-untouched); 3 low findings fixed (missed 4th
sibling badge; inert `.dynamicTypeSize(...accessibility3)` caps on `.system(size:)` glyphs →
`cappedGlyphSize`; multi-detent sheet opening clipped → ScrollView). 1146/1146; both platforms
build; no index-version bump. **Worth a manual/simulator AX5 spot-check before release**
(large type is a visual property). **Remaining before testers: the consolidated docs pass +
build bump** (reindex v18).

### Session 2026-07-03 — Analytics architecture split: corpus vs. series (planning only)
Revised the analytics roadmap into a two-feature architecture per design direction.
**Corpus Analytics** (what the series contains — term/person/place/topic/citation content)
stays in its current home (Browse "Analysis Tools" menu on iOS; frus.analytics /
frus.wordcloud windows on macOS). **Series Analytics** (how the volumes were produced —
production, timeliness, editorial organization, archival sourcing over time) becomes an
interactive part of the Research Guide (ResearchGuideView/IndexingEducationView; macOS
frus.researchGuide Help window, iOS Settings sheet), most naturally as a new "About the
Series" EducationCategory beside the existing "163 Years in Progress" narrative page.
Series feature anchored by the Production & Timeliness Dashboard, expanded with a new
**Archival Sourcing Over Time** dashboard synthesizing Source Explorer data
(majorCollections.volumeIds × manifest coverage dates → record-group/repository mix by era;
citation_era as editorial-practice proxy) — confirmed feasible from existing bundled JSON
+ volume_sources, with coverage caveats (volume_sources 258/552 volumes; citation_era is
citation-grammar not diplomatic era). Re-homed all 12 prior recommendations; two
("Geographic Attention," "Administration profiles") split across both features. New doc
`Planning/BigPicture-Analytics-CorpusVsSeries.md` supersedes and removes
`BigPicture-CorpusAnalytics-Roadmap.md`. No code changes.

### Session 2026-07-04 (later) — Collections Manager UX rework (M1/M2/M3)
Owner-driven discoverability rework of the Collections manager. Grounded eval →
Planning/Collections-Manager-UX-Scope.md (F1–F7; decisions D1–D5). **M1 (PR #164, merged):**
CollectionRibbonView (faithful ResearchStripView clone, CONTENT/ARRANGE/VIEW + pinned Export;
ResearchStripButton promoted private→internal + reused) as the macOS detail-pane 2nd row;
"Documents"→"Contents"; iPad native-toolbar promotion + iPhone labeled nav menu; Collection
command-menu lockstep. **M2 (PR #165, merged):** rows→pure reporting with status chips;
inspector absorbs body-depth + highlight-style note checkboxes (macOS-menu/iOS-list divergence
erased); notes empty=all on ALL export paths incl. native .fruscollection (review caught the
native-export closure missing it — TWO note-resolution sites); iPad per-entry inspector
sheet→.inspector column; docs rider for the export-default change. **M3 (PR #167):** shared
CollectionEntry.titleOverride (ToC label + export heading via one centralized exportHeading;
Zotero/BibTeX excluded; inspector TextField w/ real derived-citation placeholder; portable
plain-text — travels in .fruscollection, extends usesV2Features, no format/floor/index bump).
Reviews independently ran builds+tests each phase. All green (124/124 M3). Manager rework
COMPLETE. **Remaining before testers: consolidated docs pass + build bump** (reindex v18;
release notes cover authoring suite + Source Explorer + macOS windows + Dynamic Type +
manager rework + the M2 notes-default change).

### Session 2026-07-07/08 — Tester-feedback wave: issues 207–219 (build 31)
Eleven GitHub issues from tester feedback on build 30, each on its own branch off v2,
self-merged, and closed, with a multi-agent adversarial refute-pass (find → independently
verify) per issue. Plan: Planning/Issues-207-219-Remediation-Plan.md.
- **#213** Collection Manager defaults to all-project scope (banner + Scope-to-project /
  Show All; macOS gains the override for the first time) — PR #220.
- **#215** Source Explorer pre-1906 links: dateline year extractor widened 19xx→1[89]xx and
  hardened to prefer a strict `Month D, YYYY` parse over a stray token; restores 18xx
  reel/country-series resolution (both platforms) — PR #221.
- **#218** Checklist Mode exposed as a self-labeling control (iOS search actions bar; macOS
  icon+text Label), enabled on results, VoiceOver-announced — PR #222.
- **#212** macOS live user-tag filter chips (188-D iOS parity): My Tags section, live refresh,
  applied to results + Tagged chip — PR #223.
- **#214** macOS corpus browser browses downloaded early volumes without indexing (structure
  loads regardless of index; non-blocking Index/Re-index banner replaces the content wall) — PR #224.
- **#216** Citation Lookup round-trips the app's own citations (title-fragment forwarded;
  full-subset title override; volume-number-first ordering) — PR #225.
- **#219** iOS analytics views drop the nav-title to free toolbar space; screen name kept for
  VoiceOver via accessibilityElement(children:.contain)+label — PR #226.
- **#207** Person Analytics collapsible chart sections with per-chart controls (Options fold
  removed) — PR #227.
- **#209** Cross-Reference Analytics collapsible sections + not-downloaded landmark labels +
  a non-document target denylist (pg_/fn/in#/ch#/app*/URL anchors no longer rank as
  landmarks) — PR #228.
- **#208** Corpus Analytics subseries grouping switched to the Corpus Browser's leading-year
  algorithm (the ~158 marker-less volumes bucket consistently; areaToken guard dropped per
  review) — PR #229.
- **#217** Archival Neighbors **scope selector** (This volume / This subseries / All indexed
  volumes) with per-trigger defaults; the document and volume-source paths reconciled
  (document path widened to the offline collection-authority alias fallback; anchor excluded
  uniformly, also fixing a presidential-library self-inclusion bug); scope rides in the
  Codable request for macOS window restore; the two inline Source-Explorer surfaces routed
  onto the shared widened query for parity. Post-filter scope architecture (applyScope +
  scopedFetchCeiling). Review caught relatedByDecimal's hardcoded `LIMIT 1000` starving
  scoped decimal queries → candidate cap max(1000, limit) + regression test — PR #230.
- **Wave 5 (this branch):** consolidated docs pass + **build 30 → 31** (project.yml +
  project.pbxproj, no xcodegen; MARKETING_VERSION 0.2 unchanged). A doc-coverage audit
  workflow confirmed all 11 issues' manual updates landed in their per-issue PRs; filled the
  one gap (macOS §13 subseries-parity note), refreshed three stale README lines (Person
  Options-fold, macOS live tag chips, Archival Neighbors scope), and rewrote both TestFlight
  "What's New" files for build 31 (≤4000 chars each). No re-index (build 30 already shipped
  index v21; none of the 11 changed parse output). In-app help unchanged (all fixes/
  refinements, no new research concepts). Both schemes build clean; targeted test suites green.

### Session 2026-07-08/10 — Issues 233–243 wave: wave 6 (build 32)
Wave 6 per the committed plan (Planning/Issues-233-243-Plan.md, PR #244; revised 2026-07-09
for the colleague data repos, PR #250). Each session ran an implement pass (Opus) plus an
adversarial review pass (Fable) on its own branch off v2, self-merged.
- **Session 1 (#237/#238/#242)** the two user-tag pickers consolidated into UserTagPickerSheet
  (New Tag field moved to the top; sheet-created tags pin to the top with a "New" badge until
  the sheet closes; "Tags - Doc N" title); iOS Browse two-line nav titles at the
  volume/compilation levels; iPad Browse flattened to NavigationStack with the pinned
  breadcrumb suppressed + an iPad UI-obstruction regression test; BoundedTitleHeader and
  shared pieces extracted into SupportingViews — PR #245.
- **Session 2 (#233/#239)** word cloud "Hide in this word cloud" context-menu action
  (non-persistent, per-generation; "Show N hidden words" restores) beside the persistent
  global/per-lens lists; macOS Citation Lookup platform fit (grouped form, Return submits,
  results open the document in its own window with working prev/next so the match list stays
  visible) — PR #247. Follow-up: document-number citations resolve via a deterministic lookup
  instead of keyword search — PR #248.
- **Session 3 (#236)** Scope control (Whole series / By Subseries, decade-nested submenus) on
  every "About the Series" dashboard; SA-3 provenance Categories filter (re-bases the mix;
  the last visible category can't be hidden); SA-2b year-range bar (administration
  term-overlap); Reset clears scope + year range together; Corpus + Cross-Reference Analytics
  gain an Administration year-range preset menu; SeriesChartCard extracted — PR #249.
- **Session 4 (#243)** manual person merge: "Merge with another person…" in the detail sheet
  or the row context menu; confirmation names both people and warns on distinct OOH
  identities; "Corrections" toolbar manager lists every merge/separation with per-item undo;
  corrections sync via CloudKit; backend fingerprint-staleness fix — PR #252.
- **Session 6 (#240A)** offline cross-reference validation generator:
  CrossRefValidationGenerator (SPM-only; the shared CrossRefKit grammar parity-tested against
  the app's resolver) byte-scans the local corpus → broken-refs-report.csv/.json (the
  OH-submittable report) + the candidate bundled exclusion index — PR #254.
- **Session 7 (#240B)** app half: known-unresolvable cross-references render muted grey with
  a dotted underline + dagger instead of as working links; tapping opens an "Unresolved
  Reference" sheet (reason + apparent destination); Cross-Reference Analytics captions
  "N unresolvable references are excluded from this analysis" when any fall in scope; Broken
  Cross-References Report export (CSV/JSON — iOS Settings > Export Research Data, macOS
  Settings > Data pane); **currentDateIndexVersion 21→22** — the one-time background re-index
  also repairs the v21 defect that indexed some cross-volume page references against the
  wrong document in graphs/analytics — PR #255.
- **Session 9** volume subject profiles: VolumeSubjectProfilesGenerator aggregates the OOH
  frus-subjects document–subject data into a per-volume "Top subjects" profile (~224KB
  bundled); volume detail on both platforms shows category-grouped top subjects even
  pre-download; tapping a subject lists the other volumes covering it corpus-wide (incl.
  undownloaded) with navigation; the dead document-level subject-tag machinery retired
  (~81 ms main-thread launch win; bundle ~8.5 MB smaller) — PR #251.
- **Plan close (PR #257):** with Fable review-pass usage near its allowance the owner closed
  the wave after Sessions 1–7 + 9. Session 8 (#234-M0 POCOM + colleague-data person
  enrichment) and Session R (#241 iPad windowing investigation) deferred to a future wave;
  their plan sections stay intact so the next wave opens straight from them.
- **Closing Session (this branch):** consolidated docs pass (both manuals, TestFlight
  "What's New", README, in-app Research Guide/education views — scope pickers + presets,
  unresolvable-reference explanation + report export, volume subject profiles; POCOM/
  Wikidata-VIAF explicitly excluded as not shipped) + **build 31 → 32** (project.yml +
  project.pbxproj, no xcodegen; MARKETING_VERSION 0.2 unchanged).

### Session 2026-07-14/15 — Clear-the-decks P0 batch + Session R part 1 (dev-week plan)
Executed per the 2026-07-14 week plan (prioritization board + Week Execution Plan artifacts;
Opus implementation single-threaded, Fable plan review Wed noon).
- **Clear-the-decks (11 P0 items)** — PR #310: #271 downloadUrl consolidation; #277 distinct
  Cross-Reference Analytics glyph; #278 editorial-note "not indexed" mislabel fixed via
  header-independent `indexedDocumentKeys` membership; #309 iOS collection-settings ordering
  mirrors macOS (iPhone drill-in + iPad gear sheet); #305 iOS search date sort
  (`SearchSortOrder` promoted to shared SearchModels); #300 Duplicate Collection (deep copy
  incl. per-entry headnote drafts); dead `mark.hl-orange` CSS removed; zero-mention People
  caption; #272 ResearchView flattened to NavigationStack on iOS (#238 class); #273 corpus-
  browser cluster extracted to `MacCorpusBrowserWindow.swift` (4,044→2,691 lines); #246
  warnings cleared (iOS ~125→74, macOS ~41→25; residue = SwiftData macro + AppIntents only).
  Nine issues closed on the tracker with PR-referencing comments.
- **Post-merge audit + follow-up** — PR #314: a 13-agent adversarial audit of the merge found
  the #238 compliance ledger naming a SettingsView follow-up that never existed (corrected in
  MainTabView 1.11 + the BigPicture-iPadMacParity duplicate), #272's scenario-5 test gating
  the wrong column (drill-in restored with the sound `navigationBars` oracle — ordering, not
  Cell-tap-inertness, was the defeater), and a claimed iPad auto-push regression that **does
  not reproduce** (A/B-measured; `NavigationStack(path:)` fed a computed Binding discards the
  initial path element). #311 (dead 5s guard let both iPad scenarios XCTSkip green) and #313
  (CLAUDE.md over-claimed CodingStandardsAuditTests enforcement) fixed and auto-closed by the
  PR; #312 (detail-column seeded-data fixture) filed and open.
- **Fable plan review (Wed 7/15 noon, Rev 2/Rev 3)** — four read-only lenses re-planned the
  remaining week: dropped the redundant #278/#272 review; exposed Zotero's "macOS entry" as
  phantom scope (merged 2026-06-27; `BigPicture-ZoteroExport.md` Phase-2 status is stale —
  fix scheduled with Friday's session); slotted new **#315** (Source Explorer NARA
  enrichment) as harvest half (Fri, owner-run live NARA re-query — HMS/MLR numbers were
  dropped at decode time, no offline recovery) + dual-platform UI half (Sat); owner fold-ins:
  #258 design slice (sketch Sat eve + pre-cliff Fable design review Sun) and #306 as
  Sat-slack. Next-week queue: #258 implementation (lead), #308 rec-doc (opener), #235.
- **Session R part 1 (#241)** — `Planning/241-iPad-Windowing-Investigation.md`. Verdict: NOT
  window-based-by-default (XL; blocked by the forked reading surface, the two pending-state
  iOS scenes, and process-global window state); incremental value-based `WindowGroup` ports
  instead. Code-derived census: **21 macOS aux scenes vs 3 iOS** (supersedes "~17" and the
  stale `FRUSExplorerApp.swift:56-72` table). SDK-verified: `SwiftUI.Window` is
  `@available(iOS, unavailable)` → every port becomes a WindowGroup; `navigationSubtitle` is
  iOS 26+ → ArchivalNeighbors chrome compiles as-is. Latent bugs found, deferred to issues:
  `activeTab` mirrors across iPad main windows (process-global; zero `@SceneStorage`;
  user-reachable today) and both pending-state scenes restore empty. **Part 2 (2026-07-16):**
  ArchivalNeighbors conversion prototype PR + `.defaultSize` on the 3 iOS scenes + follow-up
  issue filing, then the full Fable review (doc first — 3pm hard gate).

### Session 2026-07-15 (eve/night) — #241 prototype · #315 shipped same-day · #258 design · People riders
Two days ahead of the Rev-3 schedule by close.
- **#241 part 2 + review** — PR #318 (ArchivalNeighbors as the first value-based iPad
  window port + `.defaultSize` on the iOS scenes); Fable 3-lens review UPHELD-WITH-CAVEATS →
  remediation PR #325 (reading-surface-fork argument repaired — the real XL gate is state
  routing + dual-root retention; §5.3 retiered; the VolumeSourcesView neighbors trigger
  gated). Filed #323 (DocumentWindowID restore spinner) and #324 (test-mode boot race).
  HIGH process find: a contract-test commit had broken the unit-test target at v2 masked by
  an incremental build — "run the FULL executed suite" made policy.
- **#315 filed 09:17, closed same night** — #319+#320 (HMS/MLR enrichment harvest — owner-run
  keyed re-query; 946/979 lots with naturally-sorted entry numbers; 979/979 able to name a
  file series via the free ancestors data; 16 flagged `ancestryLacksRecordGroup`) + #326
  (dual-platform provenance UI + the #321 app-side guard: flagged = unresolved). **#321
  filed:** the null-RG fallback measured 0/16 precision — every flagged record a
  presidential-library staff file. #322 filed (propagate enrichment to volume-sources).
  Merge-check discipline instituted after #319 stranded 2 of 3 commits.
- **#258 design** — PR #327, authored by an Opus agent from a requirements-only brief to
  preserve author≠reviewer for the pre-cliff Fable review. Review verdict: shape survives;
  **the load-bearing invariant discovered: empty-resolution inversion** (an empty scope set
  reads as "no filter" corpus-wide) → the `IndexedResolution` enum contract.
- **People riders** — PR #328: #307 macOS graph scroll-wheel zoom (window-scoped event
  catcher) + node context menus; #264 person subject-affinity chips via the new
  `volumeMentionCounts(forRollupId:)` GROUP-BY primitive × volume subject profiles.
  Roles swapped (Fable implemented → Opus reviewed): clean + one a11y string fixed.

### Session 2026-07-16 — #258 implementation · C-batch · #308 architecture + Phase 1 + Phase 2 begun
- **#258 Custom Volume Scopes, all five phases** — PRs #329–#333: Phase 1 minimal vertical
  (flat all-defaulted `CustomVolumeScope` @Model, `CustomScopeResolver.indexedResolution`
  never returning a bare empty set, Settings CRUD both platforms); Phase 2 Search adoption
  (seed-the-picker snapshot semantics + warn-and-refuse); Phase 3 Analytics scope bars
  (disabled zero-indexed rows); Phase 4 Series manifest grain + the rich editor facets;
  Phase 5 word-cloud `.customScope` with signature round-trip + direct window open (#334
  folded). Owner release gate noted: **CloudKit Production schema deploy before build 33.**
- **C-batch** — C1 PR #336 (#334 direct openWindow + fronting; #324 test-mode bootstrap;
  #312 gap 3 re-measured and FALSIFIED — cell/button taps both fail to push on Browse,
  finding recorded, red test not shipped). C2 PR #337 (#316: `activeTab` removed — per-window
  `@SceneStorage` + consume-once `pendingTab`, seed persisted via `persistTabSeed`; #317:
  Source Explorer + Graph scenes converted to value-based restorable requests; first design
  REJECTED in review — scenePhase ≠ focus on iPadOS — and redesigned; the rename broke the
  test target, repaired in-branch: full-suite rule now enforced). C3 PR #339 (durable #321
  resolver policy) + owner keyed regen (350c192) + PR #340 (offline PRUNE_FLAGGED_LOTS
  remediation mode; 16 flagged lots pruned from the bundle). Issues #316/#317/#321/#322/#258
  closed; #338 filed (pendingX content fan-out).
- **#308 architecture + Phase 1** — PR #341 (the reviewed design: grain/data-availability
  invariant — volume-grain ships now, document-grain behind the `DocumentSubjectStore` seam
  gated on #261; generators-vs-scorers similarity model per review F1). PR #342 (ScopeFacets
  category/sub-category catalogs + Search "By Subject · Detected Topics" + Analytics/Series
  facets, "detected topics — experimental" framing per F2/F3/F4/F5). PR #343 (era-sanity:
  owner-reviewed earliest-plausible-year table — named events only, Terrorism deliberately
  excluded; 14 anachronistic entries removed; regen + tests). PR #344 (word-cloud
  `.subjectCategory` scope, F6). PR #345 (Phase 2a model: shared `DocumentKey`, six-axis
  SimilarityGenerator/Scorer split, pure ranker + engine, restorable
  `RelatedDocumentsRequest`, inert subject scorer; review fixes: candidate-pool floor
  decoupled from display limit, honest overflow count). PR #346 (Phase 2b: bounded
  `relatedByCitation` ego query reusing the parity-tested document-target predicate;
  review added the same-volume NULL-target + bidirectional/self-loop fixtures).
- Model note: main-loop switched to Fable mid-wave; review roles swap accordingly
  (Fable implements → Opus reviews).

### Session 2026-07-17 — find-related UI · cumulative review + remediation · #335 · build-33 close
- **#308 Phase 2 UI** — PR #347 (RelatedDocumentsContent/Sheet/WindowView on the
  ArchivalNeighbors pattern: per-axis weight sliders re-ranking on release, why-related
  chips, pipeline-ready + duplicate-fire guards; value-based `relatedDocumentsScene`;
  iOS toolbar + macOS strip entry points. A unit test caught a REAL runtime crash pre-ship:
  Codable+RawRepresentable rawValue via `JSONEncoder(self)` infinitely recurses — manual
  field-wise encoding; review then proved the conformance re-routes Equatable/Hashable/
  Codable through rawValue, docs corrected). PR #348 ("Subjects (this volume)" disclosure —
  the F7 cheap win, visibility-gated). **#308 Phase 2 complete; the subject axis and
  document-grain disclosure light up automatically on the #261 data drop.**
- **Cumulative review of #314–#348** (owner-requested, ultracode workflow: 9 dimensions +
  full-suite ground truth, 33 agents; every finding adversarially verified): 1413/1413 tests,
  21 confirmed findings (0 high / 6 medium), 2 refuted. **Remediation PR #349** fixed the
  five mediums (both #275 store-generation reload gaps incl. the iPad graph scene; the
  silent facet refusal for no-scope users; Analytics facet indexed-gating; the subject-cloud
  cache missing a profiles fingerprint) + the cheap lows (BrowserView on-appear drains with
  adopt-then-clear; `consumePendingTab()` making the #316 contract testable — the vacuous
  test replaced; the #321 guard re-covered by a synthetic fixture after #340 emptied the
  bundled one; CLAUDE.md generator-doc drift; assorted). Deferred to owner decisions:
  #356 (cross-ref multiplicity damping — measured heavy-tailed to 121×), #357 (weights in
  window identity).
- **#335** — PR #350: `SourceExplorerExportGenerator` (SPM trio; parity-mirrored
  AuthorityLookup; 18 tests) + the corpus-wide run (**264,464 records / 552 volumes**) +
  the adversarial audit (6 lenses, 40 agents, 34/34 findings verified,
  `Planning/335-Source-Explorer-Audit.md`). Headlines: lot 60 D 627 (455 records)
  confidently WRONG (Operation Mongoose file unit; empty `variantControlNumbers` — the
  fileUnit class quarantine is #351); series-level lot accuracy ~93%; 71.6% of the corpus
  resolves only to the constant RG-59 record-group link (claims must say record-group
  grain); top-50 missed lots = 78% of the lot gap (#352, owner-keyed); parser session
  scoped (#353); routing session (#354); curated library NAIDs (#355). Baseline
  recommendation: re-run post-fixes and supersede citations2.csv for Source Explorer
  purposes.
- **Closing session (this branch):** follow-up issues filed (#351–#358, incl. the Zotero
  iOS URL-share fallback; `BigPicture-ZoteroExport.md` Phase-2 status corrected);
  consolidated docs pass (both manuals, TestFlight Build-33 notes, README, in-app guides —
  Related Documents, Custom Volume Scopes, detected-topic facets, provenance enrichment,
  People additions, iPad windows, Zotero); **build 32 → 33** (project.yml + project.pbxproj
  direct edit, no xcodegen). Owner release gates: CloudKit Production schema deploy
  (CustomVolumeScope), two-device LWW sync check, Zotero live E2E verify, upload.

### Session 2026-07-19 — #406 orphaned user tags (data-loss investigation + fix)
- **Symptom (from the owner's research-data export):** 1 `UserTag` survived but 94
  `DocumentTagAssignment`s referenced 13 distinct tag ids — 12 gone, 92 of 94 assignments
  orphaned; notes/collections/projects/highlights intact (loss selective to `UserTag`). Tags
  were in active use through 2026-07-17, so the loss window is 07-17…19.
- **Investigation (ultracode workflow: 4 finders + 3 adversarial verifiers + synthesis).**
  Root **trigger is under-determined** — the export equally fits (A) a Settings tag-delete with
  no cascade, or (B) `DuplicateRecordCleanup` colliding with a CloudKit re-import; the
  "tombstone also removes the keeper" mechanism is not demonstrable, and neither explains the
  timing without an unobserved event. RULED OUT: the #390 flicker fix (read-only, verified),
  both full-resets (notes survived), merge (its assignment-repoint fix `638a400` shipped in
  build 33), the id-default-collapse theory (survivor keeps a real distinct id; only 92/94
  orphaned). The **confirmed defect** is trigger-independent: tag→doc/note links are plain
  `UUID`s with no referential integrity or orphan cleanup anywhere.
- **Fix (PR on `claude/orphaned-user-tags-mka3qb`).** New `UserTagAdmin.deleteCascading`
  (strip note ids + delete assignments) wired to both raw Settings delete sites; new
  `OrphanedTagRepair` reconstructs a `"Recovered Tag …"` placeholder `UserTag` per orphaned id
  (id-preserving, so all 92 associations re-attach — names unrecoverable, no pre-loss backup),
  run **after CloudKit imports settle** (8 s debounce off the sync-event observer; immediately
  for local-only stores) so it never mints duplicates against a partial mid-import store;
  `DuplicateRecordCleanup` gains a placeholder-aware keeper (a real/renamed tag beats a
  placeholder sharing its id) + always-on removal logging; both full-reset paths now also delete
  `DocumentTagAssignment` + `DocumentHighlight` (same missing-cascade class).
  New `OrphanedTagRepairTests`. **NOT built/tested in-session** (no Xcode toolchain on the CI
  host) — owner must `xcodegen generate` (+ restore schemes), build iOS+macOS, run the suite.
  Diagnostics to confirm the trigger: console `[DuplicateRecordCleanup] Removed N …` on a
  build-33 launch; CloudKit Dashboard `CD_UserTag` (deleted vs. present-not-syncing).

### Session 2026-07-24 — Query & corpus-analysis transferability assessment + session plan
- **Input.** Two externally-produced FRUS research reports ("Drawing the Line" — allied
  military security 1945–51; "Nothing Will Be Said Here" — off-shore procurement 1950–72),
  generated by an agent working directly against a tokenized FRUS corpus in a local SQL
  database. Owner question: are the methods transferable to the app, or do they exceed
  Apple 26/27 frameworks and device compute?
- **Assessment.** Transferable, and **nothing is compute-bound**. The reports' entire
  evidentiary apparatus is SQLite FTS5 work — same engine, same `porter unicode61`
  stemmer the app already uses. Already present: phrase/boolean/prefix/grouped queries
  (`FTS5InlineQueryParser`), per-year distributions (`CorpusAnalyticsService`), corpus-wide
  counts (`searchCount`), document-set scoping (`SearchSQLFilters.documentIds`), full
  unstemmed text for verbatim checks (`document_cache.body_text`), canonical
  history.state.gov URLs, and PDF/HTML/DOCX assembly. Missing: **`NEAR`** (never exposed —
  `FTS5Query.swift:26`, and `sanitizeTerm` strips its punctuation), `fts5vocab` (unused
  anywhere), quote verification, and any way to characterize a *result set*. The only real
  platform ceiling is cross-document synthesis: `AppleIntelligenceProvider` budgets 3,072
  tokens, so per-document classification is feasible and 190-passage argument-building is
  not. Notably the reports' two fabricated NSC 68 quotations were caught by a deterministic
  substring check, not by a model — the highest-value method needs no LLM at all.
- **Diagnosis driving the plan.** The app optimizes for *finding a document* (term→distribution,
  document→neighbours) and has nothing for *characterizing a set*. Two enabling moves: make
  the query legible, make the result set a first-class object.
- **Output.** `Planning/Query-And-Corpus-Analysis-Session-Plan.md` — 13 sessions in 5
  milestones, written for **local Mac + Xcode execution** (per-session build/test commands,
  xcodegen-and-restore-schemes flags, corpus-size gates, and on-device verification steps
  that reproduce published numbers from the two reports as regression oracles).
  Milestone 1 (NEAR · query inspector · `fts5vocab` + stem transparency + exact-word filter)
  needs **no index migration, no SwiftData model, no CloudKit surface** and is shippable
  alone; it also fixes a live correctness hazard (silent stemming — `containment` → `contain`).
  Minimum useful subset: Q-1, Q-2, R-1. Decision points flagged for owner resolution, the
  significant one being M-1-1 (CloudKit shape for document-grain working corpora — lean
  sync-the-definition, not the key list).
- **No app code changed this session** (assessment + planning only).

### Session 2026-07-26 — Wave R-1: close the research-logging gate
- **The bug.** `AppState.logEvent` was gated on `researchSessionLoggingEnabled`;
  `DocumentViewModel.recordReadingHistory` and `MacSearchViewModel.recordSearchHistory` were
  gated by nothing at all. So the switch labelled "Log Research Sessions" stopped the recorder
  only `SessionLogView` reads and left running the ones feeding the History window, Project
  Home recents, Project Leads' engaged documents, the search checklist and the storage hub's
  last-opened dates. Turning it off did not stop the app remembering what you read.
- **Fix.** One reader: `AppState.researchLoggingPreferenceKey` +
  `AppState.isResearchLoggingEnabled(in:)` (absent means on). All three writers route through
  it; `SettingsSyncCoordinator` and the `ResearchSessionsView` `@AppStorage` binding take the
  key from `AppState` instead of re-declaring the literal. The orphaned `@AppStorage` in
  `SettingsView` (unread since S-1) was removed. `UserDefaults` key unchanged — it is
  user-data-bearing and mirrored via `SyncedPreferences.researchLoggingEnabled`.
- **Behaviour change, stated in the copy.** With the switch off, History and Project Home
  recents now drain. Both recording footers were rewritten under **new** localization keys
  (no String Catalog, so key reuse is a silent collision) to say the switch governs the whole
  trail and to warn about the drain; the Manage footer no longer calls reading history
  "separate". Owner decision R-0 Q3 keeps the label "Log Research Sessions", so the footer
  carries the whole explanatory burden.
- **Copy correction.** The pre-R-1 macOS footer said "searches are recorded on iPhone and iPad
  but not here". True of the *session log* alone: macOS is the sole producer of
  `SearchHistoryEntry` and does record search text. Corrected on both platforms.
- **Tests.** New `FRUSExplorerTests/ResearchLoggingGateTests` (10 tests): behavioural coverage
  of the two writers reachable from the iOS bundle (document open, iOS search submit) with
  on/off/absent controls; a source-shape guard for the macOS search writer (the type is
  `#if os(macOS)`, the test bundle is iOS-only); plus two standing guards — every producer of
  a history entry is a known gated writer, and the key literal appears in exactly one file.
  Both negative controls verified by temporarily neutering each gate.
- **Verified.** iOS `build-for-testing` + full `FRUSExplorerTests` (1694 tests, 232 suites) pass;
  macOS `FRUSExplorerMac` builds with no new warnings. Not verified: on-device/simulator visual
  review of the rewritten footers, and end-to-end drain of History/Recents.

### Session 2026-07-26 — Wave R-7: the schema-deploy release gate
- **Why.** `Planning/188-189-Tester-Feedback-Build28-Plan.md:158` specified "a startup log line
  if the installed model set is newer than a known-deployed marker, so a future undeployed-schema
  regression is caught before shipping." It was never built. #488 **is** that regression: build 35
  added `CD_ProjectLeadEntry`, `CD_Project.CD_leadAxisWeights`, `CD_Project.CD_defaultUserTagIds`
  and `CD_Collection.CD_includeProjectProvenance`; Production was never promoted; CloudKit export
  failed for every user; the owner had to diagnose it from the CloudKit Console because the app
  could not describe its own failure.
- **The inventory.** `FRUSExplorer/Models/CloudKitSchemaInventory.swift` — 206 checked-in CloudKit
  identifiers (**18 record types + 188 fields**) in the Console's own `CD_Type` /
  `CD_Type.CD_field` vocabulary. Property-grained on purpose: three of #488's four identifiers
  were fields on existing types, so a record-type-only inventory would have caught one quarter.
  `ModelContainer.frusModelTypes` went `private` → internal so the test can build a `Schema` from
  it; **membership unchanged** (that is R-2's).
- **The ratchet.** `CloudKitSchemaInventoryTests` (9 tests) rebuilds the inventory from the live
  `Schema` and fails on any change, printing the added/removed identifiers, the replacement
  literal, and a five-step deploy checklist. Pasting the literal then trips a second test: the
  deployed baseline (`installed − awaiting`) is pinned by count **and** SHA-256 digest, so the
  change must be answered either by listing the identifiers in `identifiersAwaitingDeploy`
  (not deployed) or by restating the baseline (a claim that it was). No test can verify the
  deploy itself — nothing in-process sees the Production schema — but it cannot be skipped in
  silence, which was the gap. All three rungs were proved red then green with a temporary
  `CustomVolumeScope.r7ProofField`, then reverted.
- **Marker.** Two `static let`s beside the inventory, seeded at **build 36 / 2026-07-26** per the
  owner's note on #488 ("Resolved by deploying the missing CloudKit schema"). Source, not
  `UserDefaults` or a bundled resource: the fact is a property of the release, must be identical
  on every install of a build, and must be reviewable in the diff that adds a model.
- **Startup signal.** `makeFRUSContainer()` logs on the CloudKit-enabled path only. Cost is one
  `isEmpty` on an array literal — no `Schema` walk, no hashing.
- **Surfaces.** Settings ▸ Data & Recovery ▸ Diagnostics gains an **iCloud Schema** row beside
  Sync Log, shown in both states, with no alert/badge/red — an undeployed schema is a
  release-process failure a researcher cannot act on, but #488's user-visible symptom was silence,
  so it is stated rather than hidden. Its screen explains the state in plain language, lists
  outstanding identifiers and offers **Copy Report**. The sync-log **export header** carries the
  same state: #488 was reported by pasting that dump, which could not name its own cause. Row
  hidden when the container is local-only.
- **Also fixed.** The version-history block said "16 record types" for a list of 18 (drift across
  #258 and #377 Phase 3). Any `N record types` phrase in `ModelContainer+FRUS.swift` is now pinned
  to the derived count.
- **Verified.** Full `FRUSExplorerTests` 1708/1708 pass; iOS + macOS build with no new warnings;
  iPhone 17 Pro simulator walk-through of both states (row, detail screen, sync-log header) and
  the startup console line. **Not verified:** the macOS render of the row and its sheet (the Mac
  app shares the owner's real CloudKit container on this machine, so it was not launched), and
  the real CloudKit deploy path.

### Session 2026-07-26 — Wave R-2a: one trail, one store

Executes R-0's Q1(a) — the wave's riskiest change, and the one that had to be split.

- **The split, and why.** `ResearchSession.self` / `SessionEvent.self` cannot leave
  `frusModelTypes` in the same release that migrates them: without them the app cannot **read** the
  rows it has to migrate on a device that has not launched since, or on a device whose second
  device is still on an older build and still writing them. So this is **R-2a** — migrate, stop
  writing, derive for display, keep the types enrolled. Removing them is **R-2b**, a later release,
  specified in `Planning/Wave-R-Research-Trail-2026-08.md`.
- **`ExportHistoryEntry`** (contract D1) — the trail's third typed table. The four
  `logEvent(.export(…))` sites in `CollectionExportSheet` go through `ExportHistoryRecorder`, one
  gated writer, so R-1's gate is written once and `noUngatedHistoryWriterExists` has one file to
  name rather than a view with four copies of it. Exports survive because nothing else records
  that a collection left the app, and the Zotero Web-API push has a real external side effect.
- **`.noteSave` dropped** (contract D2) — `ResearchNote` timestamps itself.
- **`ResearchTrailMigration`.** Migrates `.searchSubmit` (de-duplicated) and `.export`; drops
  `.documentOpen` (every one already has a `ReadingHistoryEntry`) and `.noteSave`; then empties the
  legacy tables. **No `UserDefaults` marker** — it is self-limiting (one `fetchCount` and out),
  which is what lets it pick up events a device on an older build syncs in *later*; a one-shot flag
  would have made those permanently unreadable. Idempotent because each migrated row takes **the
  source event's own `id`**. Runs from the CloudKit import-settled debounce (local-only: at boot),
  the `OrphanedTagRepair` placement, for the same "never against a partial store" reason.
- **The ±2 s search pairing.** Pre-R-4 `.searchSubmit` events have no counterpart and must be
  migrated; post-R-4 ones do and must not. Nothing on the record distinguishes them, so they pair
  on content. Two seconds because the two writers fired in the same main-actor continuation with
  nothing awaited between them (`SearchViewModel.search()`'s last statement, then
  `SearchView.runSearch()`'s next line) — the real gap is sub-millisecond. A pre-existing entry
  absorbs **one** event; a row this pass inserted absorbs any number of near-identical followers,
  which is what `lastRecordedHistoryQuery` did live. That distinction was found by a failing test,
  not by reading.
- **Sessions derived.** `ResearchTrailSessions` groups the three tables on the 30-minute idle rule
  from timestamps alone, which **removes** the inherited defect rather than reproducing it: the
  stored form stamped `endedAt` only when a later event arrived in the same process, so a session
  ended by quitting the app read "Ongoing" forever. `SessionLogView` reads a bounded
  `SessionLogSnapshot` (1 000 activities, Show More, honest "showing N of M") instead of a `@Query`
  over CloudKit-mirrored tables nothing prunes.
- **The delete had to grow, and that was forced.** "Delete Recorded Sessions…" summarises *derived*
  sessions, so a delete reaching only the legacy tables would have announced twelve sessions and
  removed none of them. It now calls `HistoryTrailAdmin.deleteAll` — the whole trail plus the
  legacy tables — with new copy keys. **Erase Everything** was extended the same way: it reached
  `ReadingHistoryEntry` alone and left every recorded search behind.
- **Not enrolled in `DuplicateRecordCleanup`, deliberately.** Its keeper rule breaks ties on
  `createdAt` then `id.uuidString` — vacuous for a same-`id` group — so two devices can pick
  different keepers and delete each other's copy. That hazard is pre-existing for the four enrolled
  types and is not R-2's to fix, but it is a reason not to aim it at a table D5 says nothing may
  silently delete. Migration duplicates are instead made rare (deterministic ids + import-settled
  timing) and benign (an identical, individually deletable row).
- **R-7's gate fired**, as designed: 7 added identifiers (`CD_ExportHistoryEntry` + 6 fields),
  pasted into the inventory and listed in `identifiersAwaitingDeploy`. **The Production deploy is
  outstanding** and is the one step no test can check.
- **Verified.** Full `FRUSExplorerTests` **1762/1762** pass; iOS and macOS build with no new source
  warnings; iPhone 17 Pro simulator walk-through — Research Sessions pane empty *and* populated,
  the derived Session Log showing one session grouping a document open (12:06) and a search (12:07)
  as "Ongoing · 2 events". **Not verified:** the macOS render of the pane and log sheet, the
  migration against real legacy data (no `SessionEvent` rows existed on the test device), and the
  multi-device race, none of which a simulator can reach.

### Session 2026-07-26 — Wave R-2a review fixes (PR #517)

Three adversarial reviews attacked the migration independently; most findings arrived with a
failing test rather than an argument. Two were blockers.

- **The dedupe design was wrong in kind, not in size.** `pairingTolerance` (2s) was sized from the
  gap between the two *writers* — sub-millisecond, same main-actor continuation — but it was also
  load-bearing for collapsing repeated *events*, whose gap is a human tap. `SearchViewModel.search()`
  fired `.searchSubmit` on every execution; `recordSearchHistory` wrote one row per **distinct**
  query; and iOS re-ran `search()` for the same keywords from `clearVolumeScope()` and the
  result-row tag chip. One query plus two filter toggles = 3 events, 1 recorded search, **3 migrated
  rows**, on every shipped iOS build. The window is **removed**, not retuned: existing entries and
  legacy events merge into one time-ordered stream, which is cut into runs of consecutive identical
  queries; a run holding a real entry writes nothing, a run without one writes exactly one row.
  That is what `lastRecordedHistoryQuery` did, so `A A B A` is three searches. It also dissolves the
  finding that a pre-existing row was the only row forbidden from absorbing its own followers.
- **R-7's marker became an interlock.** The pass writes `ExportHistoryEntry` and deletes the
  `SessionEvent` rows it replaces in one call. While that type sits in `identifiersAwaitingDeploy`,
  CloudKit takes the deletions and rejects the replacements (#488) — a second device or a reinstall
  would simply lose the export history. `run` now checks the marker for any record type it writes,
  defers, and logs why. **The migration is therefore dormant in this build and starts by itself at
  the first launch after the owner clears the marker** (CloudKit checklist step 4).
- **Determinism.** Every fetch feeding a decision is sorted; the merged stream orders by
  (timestamp, kind, id). `theResultDoesNotDependOnInsertionOrder` pins it.
- **Same-`id` duplicates.** The residual is only benign if it is visible and deletable, and it was
  neither — `ForEach` had two elements under one `Identifiable` id, and the deletes used
  `fetchLimit = 1`. Rows now carry a distinct `HistoryRowID`; the deletes remove every copy;
  `HistoryTrailAdmin.deleteExport` and a **Collections Exported** History section close the third
  type, which had no per-entry delete and was never even loaded.
- **The migration runs unconditionally at boot** as well as from the import-settled debounce — a
  device signed out of iCloud never got that event, and nothing reads `SessionEvent` any more.
- **The delete confirmation quotes the exact activity count.** It quoted a session count off a
  1,000-activity scan against an unbounded delete: measured, "1000 sessions" destroyed 1,200. New
  key `settings.sessions.delete.message.trail.v2`; the Settings row says "at least N sessions" when
  its scan was truncated.
- **`nil` timestamps.** `SessionLogSnapshot.totalActivities` counts only *datable* rows, so
  `hasMore` can reach `false` and an all-undated store draws its empty state;
  `ResearchSessionsSummary.isEmpty` asks whether there is anything **to delete**, so undated rows no
  longer grey out the only delete control. A `SessionEvent` with a `nil` `timestamp` falls back to
  `createdAt` instead of being destroyed. The legacy sweep is refused when the event fetch returned
  fewer rows than the `fetchCount` before it.
- **Tests changed, and why.** `pairingBoundaryHolds` **deleted** (it pinned the window from both
  sides). `aLaterRepeatOfTheSameQueryIsNotSwallowed` and `eachEntryPairsWithOneEventOnly`
  **rewritten** — both encoded the "one entry absorbs one event" assumption that produced the three
  rows. `nilTimestampIsSkipped` **rewritten**: it asserted `totalActivities == 2` for a page that
  could only ever draw one row, which is the desynchronisation itself.
- **Verified.** Full `FRUSExplorerTests` **1777/1777** pass on a booted iPhone 17 Pro simulator;
  iOS and macOS build with no new warnings. **Not verified:** the migration against real legacy
  data, the multi-device race, and the on-device render of the new History exports section.

### Session 2026-07-26 — Wave R-6: make a CloudKit failure diagnosable

Issue #488 reported `CKErrorDomain partialFailure (2)` and nothing else; the cause was
reconstructed from the CloudKit Console and a `git diff`. R-7 built the gate that stops the
regression recurring — this makes the *next* one describable. **It fixes no sync.**

- **The defect, verified in source.** `cloudKitDiagnostic` read
  `error.userInfo[CKPartialErrorsByItemIDKey]` at exactly one level and, on a miss, fell through to
  domain + code. A `grep` for `NSUnderlyingErrorKey`, `NSMultipleUnderlyingErrorsKey`,
  `CKErrorRetryAfterKey` and the server's error text returned **zero readers anywhere in the app**,
  so every channel that could name the rejected record type was discarded.
- **The walk.** New `FRUSExplorer/Diagnostics/CloudKitErrorInspector.swift`: breadth-first over
  `NSUnderlyingErrorKey` + `NSMultipleUnderlyingErrorsKey`, bounded three ways — depth 6, 64
  errors, and an `ObjectIdentifier` visited-set so a self-referential chain terminates on the
  second visit instead of hanging. The per-item dictionary is found wherever it sits and its
  **depth is recorded**; `NSPersistentCloudKitContainer` re-vends #488's failure at depth 1.
- **`hadPartialDictionary` is the point.** `false` = looked, found none. Field absent on a stored
  row = the row predates the walk. Those were one silence before. A walk stopped by a bound sets
  `chainTruncated` rather than claiming an absence.
- **Schema identifiers only, by a hand-written grammar.** Split the text into maximal
  `[A-Za-z0-9_]` runs; emit a run only if it starts with `CD_` (with something after) or *is*
  `_pcs_data`. No regex, so a reviewer can read exactly what escapes and there is no pattern to
  "simplify" into `.*`. A UUID cannot match (no underscore, so `CD_` never begins inside one) and
  the maximal-run rule makes `someCD_thing` one failing run rather than two.
- **The redaction gate.** #188-C.1 forbids free text from an `NSError` reaching the log and has no
  mechanical enforcement except this: `CloudKitErrorInspectorTests` feeds a description carrying a
  UUID record name, a zone owner id, an e-mail and a field value, and asserts zero tokens plus no
  surviving fragment anywhere in the result. **Proved red under mutation** (grammar widened to emit
  every run — it leaked the UUID, the e-mail and "Kissinger") before being trusted.
- **New `SyncDiagnosticsEntry` fields are all optional.** `loaded()` swallows a decode failure with
  `try?`, so a non-optional addition would silently wipe the history the owner pastes into issues;
  `legacyRowDecodes` pins a pre-R-6 JSON file.
- **Surfaces.** `SyncDiagnosticsLog.line(for:stamp:)` split out of `formattedText()` and testable
  without the actor: renders `partial=N@depth D`, the `no per-item errors in chain` /
  `chain truncated` / say-nothing distinction, `schema: CD_…`, `retry-after=Ns`. Data & Recovery's
  Sync Log row reads "2 errors today, 1 with no detail"; `SyncLogSummary.Event` makes the second
  count structurally unable to exceed the first. The two `checkCloudKitHealth()` catch blocks run
  through the inspector too.
- **Also fixed, found while doing it.** The CloudKit code-name table was applied to *every* domain
  (an `NSCocoaErrorDomain` code 4 was reported as `networkFailure`); the equal-count histogram sort
  was unstable, so one failure rendered differently on each run; `cloudKitDiagnostic`'s doc comment
  had drifted above the wrong declaration and still claimed it logged via `print`.
- **Verified.** 44 new tests in `CloudKitErrorInspectorTests` / `CloudKitDiagnosticTests` /
  `SyncDiagnosticsEntryTests` / extended `SyncLogSummaryTests`; full `FRUSExplorerTests`
  **1815/1815** pass on a booted iPhone 17 simulator; iOS and macOS build with no new warnings.
  **Not verified:** anything against a real CloudKit rejection — every shape is reconstructed —
  and the on-device render of the new Sync Log row wording on either platform.

### Session 2026-07-27 — Lexical similarity neighbors: feasibility & value assessment

Assessment only — no code changes. New `Planning/Lexical-Similarity-Neighbors-Assessment.md`
answers whether a bundled document-level lexical-similarity neighbor index (a
`CloudVectorsGenerator` sibling) can power a new Related Documents / Project Leads axis.

- **Verdict: feasible and valuable, but only precision-first.** Full-corpus top-10 k-NN is
  ~40–45 MB of JSON (calibrated at ~11.7 B per compact int entry from
  `cloud-vectors-volumes.json`) — rejected outright. A thresholded strong-pairs index
  (~100–150k pairs, k ≤ 5, ~2–3.5 MB) fits the `central-files-index.json` size precedent and
  concentrates on cross-volume topical cousins no existing axis can produce.
- **Why it matters:** the #308 candidate universe is the union of the two generators only
  (archival provenance + explicit cross-references); doc-grain topical relatedness has been a
  hole since `sharedSubjects` shipped inert. A lexical index is generator-shaped (bounded keyed
  lookup), and `ProjectLeadsService.effectiveWeights` already back-fills a future axis's
  default weight. Phase A is CloudKit-neutral (no `ProjectLeadEntry` change).
- **Reuse map:** enumerator, `TEIBodyTextExtractor`, one-pass multi-lens tokenizer
  (`topics` noun lens as the vector basis), determinism idioms, `BundledCloudVectors` loader
  pattern; measured 18m53s O-1 full-corpus pass bounds the I/O cost. The one new algorithm —
  all-pairs similarity over ~314k sparse TF-IDF vectors — is rated the main schedule risk
  (medium), with df-ceiling pruning + prefix filtering as the standard escalations.
- **Proposed workstream:** L-1 generator + subseries-slice calibration; L-2 full run +
  spot-check panel + acceptance bar (≤3.5 MB, ≥15% coverage, else a finding); L-3 axis +
  loader + both surfaces; L-4 optional off-index "volumes you haven't downloaded" leads tier
  (separate section per the I-3 no-blending rule, volume-grain rollup + Download affordance).
  Six owner decisions queued in the assessment §10.
- **Not verified** (corpus absent from this container): score distributions, coverage at any
  threshold, APSS wall-clock, non-`"dN"` xml:id share — all measurable in L-1.

### Session 2026-08-03 — Vector embeddings & semantic similarity: recommendations

Assessment only — no code changes. New `Planning/Vector-Embeddings-Semantic-Design.md` answers the
owner's ask: bundled semantic indexing for a related-documents/leads proximity axis plus a
browse/discovery view over semantic space, with generation offloaded to an owner-side M1 Mac Studio.

- **Core move: precompute on the Studio, ship vectors not models.** Deletes the OS-27 design's
  workstream-C headline risk (on-device embedding of 316,839 documents) and replaces it with a
  distribution problem the repo already solves (17 bundled artifacts; GitHub volume downloads with
  blob-SHA verification).
- **Three-tier artifact stack by access pattern:** bundled 2-D map coords + cluster labels +
  volume/subseries centroids (~3–4 MB); bundled 256-bit binary vectors for corpus-wide zero-download
  candidate generation (10.1 MB — the one real app-size decision); per-volume int8-256 shards
  (~149 KB/volume, ~82 MB full corpus) fetched by DownloadManager from an app-owned GitHub repo,
  mmapped flat, deleted with the volume. No `@Model`, no CloudKit deploy, vectors never in SQLite
  BLOBs. Retrieval is exact brute force — no ANN at 317k vectors.
- **Pipeline:** pinned Python embed/UMAP stage writing a raw vector store treated as a harvest
  cache (the NARA raw-store precedent), then a deterministic SPM `SemanticVectorsGenerator` packer
  with full provenance pins (model SHA, dims, chunking, pooling, quantization) and the
  configuration-mismatch refusal promoted to a family rule. Primary model candidate
  EmbeddingGemma-300M (Matryoshka), Apache-2.0 fallbacks benchmarked in a V-0 spike;
  `NLContextualEmbedding` rejected for the corpus side (unpinnable revisions).
- **Feasibility:** axis — smallest lift, must enter the ranker self-normalised (raw cosine) to
  dodge #643, chips computed at render time from the pair's own texts; leads — OS-27 §5.5 centroid
  design survives verbatim, plus an off-index "which volume next" tier; discovery map — feasible,
  precomputed layout + live int8 axis projections for the "slices", but the renderer must be Metal
  with LOD (317k points; Canvas degrades far below that); free-text semantic search deferred to
  V-5 (only feature needing an on-device query encoder).
- **Gates before building (V-0 spike):** cross-reference weak-positive MRR per era, the lexical
  assessment's 100-row era-stratified blind panel with pre-1900 as its own kill bucket, and a
  quantization-ladder recall measurement. Sequencing: #645 seven-site fix + missing archival route
  arms land first, then re-measure the 46,234-document zero-candidate market this axis exists for.

### Session 2026-08-03 — Feature & priorities review: what to target after the current slate

Assessment only — no code changes. New `Planning/Feature-Priorities-Review-2026-08.md` reviews
shipped capabilities and every open plan, then recommends the next priorities once the current
slate (N lane, R-2b, Q discovery tail, held owner decisions) ships or is refuted.

- **P1 — Sync & data-integrity wave**, anchored on the owner's #665 (background CloudKit
  integration + workspace notification), folding in the recorded summary-sync defects
  (last-push-wins `summary_text`, missing `!isHeadnoteDraft` boot filter — with #626 if un-held),
  a generalized referential-integrity sweep for the #406 defect class, the missing multi-device
  verification protocol, and R-2b's deploy.
- **P2 — one Discovery lane** merging the three semantic/similarity designs behind one gate
  sequence: #645 remainder + route arms + zero-candidate remeasure, the shared "why related"
  design question, `CSUserQuery` + Spotlight `textContent` pulled forward (available since
  iOS 18), then the V-0 spike deciding vector vs. lexical-floor; #308 doc-level subjects enter
  the same blind-panel gate via #261.
- **P3 — corpus-completeness programs**: the People program (#234/#259/#260, eval-first), the
  #262 resolved-edge manifest (size/shape design first), #265/#263 as quick wins.
- **P4 — reach**: one explicit hosting-channel decision (four features have died against its
  absence), then a 1.0-readiness wave (#106, metadata, accessibility closeout, localization
  posture).
- **P5 — scheduled perf/debt**: the measured two-phase fetch session (~10.5 s → ~0.6 s), one
  batched index-migration event (collect index-shape wants behind a single version bump —
  for tidiness, not cost: the reindex is ~10 minutes, owner-measured 2026-08-04), dead-code decisions, the unticked export-verification checklist, #270 as trailing
  hygiene. Non-targets reaffirmed: cross-platform port (post-1.0; spike only), CloudKit sharing,
  ANN infra, and every measured refutation.

### Session 2026-08-04 — Research Trip Packet: scope against NARA's pre-visit guidance

Assessment only — no code changes. New `Planning/Research-Trip-Packet-Scope.md` scopes the
§5a.2 trip-packet idea against NARA's own guidance, anchored on the research-visit FAQ ("How
can I make my visit more successful?"), whose verbatim text is deposited at
`Planning/reference/nara-research-visit-faqs-2026-08-04.md` so the traceability oracle has a
primary source in-repo.

- **The FAQ reads like a requirements memo for this app.** Its effective-inquiry spec asks for
  records identified by record group, entry number, series title, and NAID links — the four
  fields of the bundled lot and volume-sources indexes; it names State Department "Lot File"
  numbers as identifiers that "do not always carry over" (making #375's unresolved lots NARA's
  *predicted* case, with a prescribed remedy: name them in the advance inquiry); and it puts
  State and post-1960 records on the extra-lead-time list, so nearly every packet carries the
  write-early flag on NARA's own criteria.
- **Traceability table A1–A14**: each advisory (appointments, the 4-week/one-address/10-business-
  day inquiry mechanics, the six-element inquiry spec, extra-notice criteria, the
  no-ad-hoc-resolution warning, mandatory use of online/microfilm substitutes, Catalog/Explorer/
  History Hub entry points, pull times, registration, restrictions, the RDT2 foreign-affairs
  specialist, presidential-library write-ahead, citation practice, room rules) mapped to the
  packet section that satisfies it.
- **Shape**: per-repository PDF chapters — checklist with A4-escalated countdown, per-agency-
  cluster inquiry drafts (structure resolved from the FAQ's one-address/one-agency rules),
  pull worksheet (blank Box column — never fabricated), mandatory-substitutes, restriction
  triage, citation crib, visit-day card. Sessions T-0 (data audit + ~16-row repository table) →
  T-1 (aggregation/flag engine on `archivalSourceRows`) → T-2 (exporter, ships before N-7) →
  T-3 (N-7 riders: accessRestriction, digitised series, numberingNote, series date-checks) —
  the standing reason N-7's bundle should carry those rider fields from its first cut.
- Five honesty rules (no box fabrication, unresolved-as-predicted, dated volatile facts,
  range-grain scans, availability never promised); five owner decisions queued, one already
  resolved from source.

### Session 2026-08-05 — Planning-folder cleanup: archive completed plans under Completed/

Housekeeping — no code behaviour changes. 57 completed/closed planning documents moved to
`Planning/Completed/` (with an index README stating the criterion and mapping the clusters),
leaving 22 live documents plus the four artifact directories at the root.

- **Moved**: all delivered numbered session plans (01…406), the completed workstream plans
  (Onboarding, Analytics, Research Rail, Projects #377, Docs pass, the Collections trilogy,
  Corpus Browser rework, Source Explorer provenance, Window-Routing-Provenance, the QCA design
  brief), closed issue-wave plans (207–219, 233–243, 188–189), point-in-time audits/evals
  (UI, People Browser, Source Explorer 07-03, Settings parity), delivered BigPicture programs
  (WordCloud, VolumeFrontMatter, iPadMacParity, ZoteroExport), the superseded 75 backlog, and
  the shipped PDF/DOCX-highlight one-off.
- **Kept live**: the consolidated plan, this log, the spec, open designs/assessments (vector,
  OS-27, lexical, cross-platform, PreIndex, #308, Analytics-CorpusVsSeries postponed items,
  Pre1910 pair), live runbooks (NARA RG catalog, lot resolution), the QCA assessments binding
  the Q tail, Wave R (R-2b), the Eight-Issue plan (held decisions), Dynamic-Type worklist, the
  priorities review, and the trip-packet scope.
- Classification was verified against shipped code where status lines were stale
  (Collections-Authoring says "no implementation started"; `titleOverride`/prose exporters say
  shipped). Twelve code doc-comment paths updated to the new locations (verified: no stale
  `Planning/<moved-file>` references remain in Swift sources); `CLAUDE.md` and
  `Docs/screenshots/README.md` pointers updated. Generator OUTPUT_DIR defaults
  (`cross-ref-validation/`, `nara-record-group-catalog/`, `source-explorer-export/`) untouched.

### Session 2026-08-07 — #586: sort, page, and filter facets (and stop cutting years at 50)

The issue asked for facet sorting and pagination. Assessing it turned up a defect underneath:
`FacetRequest.limitPerSection` was 50 for every section, and the years aggregate is ordered
`k DESC`, so the cut kept the **50 most recent years** and dropped the rest. Measured on the
owner's index, the histogram began at **1953** — 88,720 of 314,676 dated rows, 28% — and hid both
World Wars behind a caption reading "Showing the top 50 of 203". The count was honest; "top" was
the wrong word for a cut that kept the latest, not the largest.

**One premise in the issue was wrong and is worth recording**: it says "facets are displayed by
count". True of volumes / people / document type / provenance; **not** of years, which has always
been reverse-chronological. What years lacked was the *choice*.

**Architecture: display cut moved out of SQL.** Two measurements decided this.

1. Cache-controlled on the whole 316,839-document corpus, the people aggregate cost **0.798 s /
   0.811 s at `LIMIT 50`** and **0.894 s / 0.802 s at `LIMIT 20000`** returning **16,385 rows**.
   The `GROUP BY` computes every group either way. So sections are fetched whole
   (`FacetRequest.fetchCeiling = 20_000`, above the 18,078-row rollup table) and `FacetPaging`
   sorts/pages/filters in Swift — instant, and no re-query per page turn. SQL `OFFSET` paging
   would have re-paid 0.8 s on **every** page.
2. `ORDER BY canonical_name` uses BINARY collation, which exiles all **22** non-ASCII initials
   past `Z` (`Ágústsson, Einar`) and misplaces **1,041** names carrying an internal diacritic.
   `localizedStandardCompare` fixes both, and also orders `…v05` before `…v10`.

**Alphabetical people ≈ last name, honestly labelled.** **17,062 of 18,078** canonical names
(94.4%) are stored `Last, First`, so plain alphabetical *is* surname order for almost all of them.
The 1,016 without a comma are initials-first transliterations (`A. Ya. Vyshinski`) and titled or
single names (`Abbas Hilmi Pasha`); there is no surname to extract from the latter, so the control
says "A–Z" rather than promising a last name it cannot always find.

**Shipped**: `FacetSort`, `FacetPageSize`, `FacetDisplayState`, `FacetPage`, `FacetPaging` in
`ResultSetFacets.swift`; per-section display state on `FacetPanelController`; sort menu, Show menu,
page turner, and a filter field (volumes/people only, above 100 rows) in `FacetPanelView` — which
is **shared by both platforms** (`SearchView.swift`, `SearchSheet.swift`), so unlike the rest of
search this needed no separate macOS port.

**Verification**: 24 tests in `FacetSortingAndPagingTests`, **15/15 mutations caught**. The years
guard drives the real `IndexingPipeline.resultSetFacets` over a 60-distinct-year fixture, not a
constant — restoring `fetchCeiling = 50` fails it. The four neighbouring facet suites and the
coding-standards audit stay green; both platforms build clean.

**Not verified**: the SwiftUI wiring itself (menus rendering, the filter field binding) has no
automated coverage — the PR carries a visual-review checklist for it.

### Session 2026-08-07 — #736: POCOM career data, authority schema v2, and the #260 crosswalk

Carved out of #234 after a readiness check found its prerequisites satisfied but its scope
mismatched, and merged with #260 because both regenerate the same bundled artifact.

**#234 stays open, deliberately.** Its complaint is that the people browser reaches only volumes
whose editors published a person list — measured, **268 of 552 volumes (48.6%) have none**,
including every volume from the 1860s and 1880s. POCOM carries **no FRUS anchor of any kind**; the
only join runs backwards (app people-id → registry record → `departmenthistory` slug → POCOM), so
it can only enrich people already known from front matter. Closing #234 on this would mark the
pre-1930 gap solved while not one of those 268 volumes gained a person.

**Four premises in the plan/issue were false, and three of them fail silently.**

1. `persons-complete.xml` has **zero** `source-url` elements; anchors ride on
   `<idno type="frus-ref">`. A parser written from the description returned 0 pairs from 30,776
   well-formed entries and exited 0.
2. The identifier idno types are `Wikidata` and `VIAF`, **capitalized**, each shipped twice beside
   a `-URL` sibling. The lower-case match found 0 of 7,500 and 0 of 6,442 — the first full run
   wrote an index with `with a Wikidata QID: 0` and reported success.
3. `merge_audit_report.csv` uses bare `\r` line endings; splitting on `\n` makes the whole file one
   row and the mandated audit guard silently inert. Caught only because the runner treats a guard
   resolving zero ids as fatal.
4. That same CSV keys on `FRUS-NNNNN` xml:ids — **the identifier the plan's own rules forbid
   relying on**. The guard is applicable only by resolving them inside the same file version and
   pinning the result in provenance; it cannot be recomputed after the planned re-mint.

Also corrected: the plan called POCOM "chief-of-mission assignments", which would have dropped
`positions-principals` — 1,293 appointments across 951 people, i.e. every Secretary and Under
Secretary, the people most represented in FRUS.

**Measured outcomes** (owner's 552-volume index, shipped artifacts):

| | before | after |
|---|---|---|
| crosswalk pairs / volumes | 49,345 / 229 | **56,110 / 285** |
| coverage of live person rows | 78.5% | **89.3%** |
| VIAF ids | 142 | **3,198** |
| Wikidata QIDs | 0 | **3,825** |
| authority index size | 1.3 MB | **2.42 MB** (budget 2.5) |
| POCOM careers | — | **1,240** of 1,242 reachable slugs, 2,621 assignments, 420 KB |

Rollup impact of the expansion, measured before shipping: of 7,282 newly-covered records, **6,454
(88.6%) land in a cluster already carrying that id** (no change), 786 in a cluster with none, and
**90 (1.2%) in a cluster with a different id** — pulled out, a de-conflation in v8's direction.
`currentPersonRollupVersion` 8 → 9. The 259 anchors where the two sources disagree are **printed in
full** by the runner; the registry keeps its answer in every case.

**Verification**: 31 new tests (18 POCOM generator, 13 overlay/builder additions, 13 app-side);
**14/14 mutations caught**. One mutation initially survived — case-sensitive identifier matching —
because every fixture used the lower-case spelling the real file does not have; the fixtures now
carry the real capitalization, which is the bug that actually shipped a zero-QID index. A second
pair survived until the fixtures grew a repeated role title, which **394 of 1,240 real careers
(32%) have**. 905 SPM tests green, both platforms build clean.

**Not verified**: the Career section's on-screen rendering. The models and parsers are covered; the
SwiftUI layout is not, and the PR carries a visual-review checklist.

### Session 2026-08-07 — #234's early-era program lifted out of the archive, and its reframe corrected

The M1/M2/M3 NER program was defined inside `Issues-233-243-Plan.md`, which the 2026-08-05 cleanup
filed under `Completed/` as a "closed issue-wave plan". The wave closed; the program did not. The
only live pointer was one sentence in the priorities review, bundling it with #259 and #260 — both
since resolved — so it had been invisible for two months. Now `Planning/People-Early-Era-Program.md`.

**Two corrections, both measured.**

1. **The `persons-new.xml` reframe does not hold.** The archived plan claims it turns M1 from "NER
   from scratch" into "adopt + review the colleague's extraction — much smaller program". Its
   anchors are `volume/persons#ref`, so by construction they only land in volumes that already have
   a persons page: they reach **2 of the 268 no-list volumes** and 2 of the 129 pre-1930 ones. It
   enriches the covered corpus and cannot extend into the uncovered one. M1 is not smaller.

2. **The gap is bigger, and the problem is different.** 268 of 552 volumes have no person list —
   but they hold **199,246 documents, 62.9% of the corpus**, because the unserved volumes are the
   large early annual volumes. And those volumes are *not* unmarked text: they carry **253,919
   editor-marked `<persName>` elements** (141,064 `from`, 95,837 `to`, 17,018 untyped; 13,914
   distinct strings, 3,253 appearing 5+ times) with **zero** links to any identity. A covered
   volume links its mentions with `corresp="#p_W1"` back to an editor list of
   `<persName xml:id=…>` items; the uncovered ones have the names and no list to point at.

   So the core problem is **reconciliation, not detection** — and with 93.3% of the names in
   `from`/`to` correspondence headers, POCOM becomes genuinely load-bearing: sender/recipient +
   document date + who held which post when is a three-way constraint, not open-domain entity
   linking. A new **M1a** gate goes in front of everything: measure what share of person mentions
   are marked up at all (unmeasured, and it decides whether M2 is needed), build the ground-truth
   eval set, and measure POCOM's constraint strength — before any extraction is built.

**Method note.** The first pass at this counted `@ref` and reported "0 linked" across both covered
and uncovered volumes, which would have been a finding about nothing. The linking attribute is
`corresp`; a covered volume carries it on ~75% of its `persName` elements. Caught by comparing
against a volume known to be covered instead of trusting the first number — the same discipline the
size-against-the-denominator rule exists for.

### Session 2026-08-07 — M1a run: the gate measurements for #234's early-era program

`Planning/early-era-people/` — reproducible survey (`m1a_survey.py`, seed 234, read-only),
`M1a-Findings.md`, `m1a-survey.json`, and 300 staged eval candidates.

**The headline reverses last session's framing.** `People-Early-Era-Program.md` argued the early-era
problem looked like *reconciliation, not detection*, explicitly flagging markup coverage as
unmeasured and as the thing that would size the program. Measured over a stratified 12-volume
sample: **34.0% pooled markup share** (10,682 marked / 20,739 unmarked), falling to **12–31% in the
1946– volumes**. The editors mark the correspondence apparatus (`from`/`to`) and leave body prose
alone, so **M2 (detection) is required**. Spot-checked the unmarked hits — telegram signature lines,
title parentheticals, running prose — they are genuine mentions, not noise. Stated as a lower bound
on markup, since a bare surname regex also matches TOC and index repetitions.

**POCOM constrains the `from`/`to` layer strongly:** 12,384 names in the sample, **83.2%
surname-known**, **63.9% resolving to exactly one officeholder serving that year**. Recorded as an
upper bound on precision — the match is surname-only, and the 1946– volumes already show the ceiling
falling as correspondence widens beyond US chiefs of mission.

**The eval set is staged, not done.** 300 stratified rows with an empty identity column; keying is
owner work, and nothing downstream is measurable until it happens.

**Two defects fell out of validating the survey**, both from cross-checking the TEI-derived volume
split against the app's own database — they disagreed on three volumes and every disagreement was a
bug. [#740](https://github.com/joshbotts/FRUS-Explorer/issues/740): `frus1873p1v1`/`p1v2` carry
57-entry editor lists the parser never reads (`xml:id="correspondents"` with no `subtype`, versus
the parser's `subtype=="index"` + `xml:id ∈ {persons,persname,listofpersons}` rule).
[#741](https://github.com/joshbotts/FRUS-Explorer/issues/741): `frus1941-43` contributes 77
back-of-book subject-index headings to the People browser as people.

Those three volumes also reconcile the two volume counts now in circulation: **268** is where the
app shows no people, **267** is where the TEI has no editor list, and the difference is exactly the
defect volumes.

### Session 2026-08-07 — #740 / #741: two persons-list encodings the parser mishandled

Both surfaced by the M1a cross-check (TEI-derived volume census vs the app's own database), and
**both root causes differ from what the issues originally said** — the issues were written from the
symptom, and the code disagreed.

**#740.** Filed against `FRUSDocumentParser.structuralKind`. The actual gate is
`PersonsParserDelegate.isPersonsSection`, which accepted `xml:id ∈ {persons, persname,
listofpersons}`. `frus1873p1v1`/`p1v2` use `<div type="section" xml:id="correspondents">` with no
`subtype`. Added `correspondents` to the accepted set — measured, those are the only two volumes in
552 that use it, so this is 114 entries, not an encoding family.

**#741.** Filed as "there is no editor person list in that volume at all, and the rows should not
exist." Wrong: `frus1941-43` *does* carry `<div subtype="index" type="section" xml:id="persons">`
headed **"Index of Persons"**, holding 749 entries that are mostly real people (Acheson, Alexander,
Amery). The defect is **nesting**: a back-of-book index entry is a tree —

```xml
<item>Arnold, Henry H., Lieutenant General…:
  <list><item>Meetings:
    <list><item>Casablanca Conference: Combined Chiefs of Staff, 536…</item>
```

— and every nested `<item>` was emitted as its own person, which is where "Casablanca Conference",
"Meetings" and "Correspondence with" came from. Two rules now: only the **outermost** item is a
person, and text accumulation **stops at the first nested list**, so the role is the text before the
sub-entries rather than every page reference beneath them.

Both change parse output, so `currentDateIndexVersion` 36 → 37 in the same commit.

**Recorded honestly:** the fix does not make `frus1941-43` contribute its full 749. Index-style
entries ending in a page run (`Finletter, Thomas K., … , 104`) are still rejected by the
pre-existing `PersonListHeuristics.isLikelyPersonName`. That is a separate question — whether a
back-of-book *Index of Persons* should populate the People browser at all — and was not in scope
here. The test says so rather than expecting a number the code does not produce.

**Verification:** 7 new tests driving the real `parsePersons` through temporary volume files;
**3 of 4 mutations caught**, the fourth an equivalent mutant (defensive depth reset, unreachable on
XML `XMLParser` accepts) now annotated as such in the source. 25 tests green across the parser,
pipeline and standards suites; both platforms build clean.

### Session 2026-08-07 — Can M2 ride the vector-embeddings pipeline? Yes — plan + priced

New doc `Planning/M2-Semantic-Pipeline-Ride-Along.md`. The two programs share their expensive
part — a full pass over the corpus body text — so the answer is yes, with a seam: shared
extraction, tooling discipline, hardware window, and one load-bearing model reuse
(mention-context embeddings as the reconciliation signal for identity clustering); **never**
shared gates or verdicts (V-0's pre-1900 cosine kill stays embedding-only; M2 still waits on its
own M2a prose ground truth; the M1a 300 rows are still un-keyed).

**Measured before estimating:** the corpus body text is **~330 M BPE tokens** (1.374 B chars /
229.2 M words over 314,483 document divs — tag-stripped `<div type="document">` character data,
all 552 volumes); ~380 M after chunk overlap; the M2 scope (268 no-list volumes) is ~176 M
(51.3%). This corrects two design-doc guesses: ~475 k chunks (not 600 k–1 M), and §3.3's
"1–6 hour [U]" wall-clock band, which implies ≥49 TFLOPS effective for the 300 M primary — not
reachable on either machine. Correction note added to the design doc in place.

**Generation price, both machines** (assumptions stated in the doc; V-0 on both machines converts
them to measurements for pennies): EmbeddingGemma-300M full-corpus embed **~8–13 h on the M1 Max
Studio**, **~8–26 h on the M5 MacBook Air** — the Air's spread is software, not silicon (whether
the ML stack drives M5's per-core Neural Accelerators for encoder models is [U]; fanless
throttling on top). NER pass over the M2 scope ~1–9 h by detector; mention-context pass ~4–7 h.
Electricity for the whole program: **under $1 on either machine** (~$0.30–0.75 Studio,
~$0.10–0.30 Air). The only real dollar line is the deferred adversarial-review tier (~$45–90 as a
Haiku-class API batch over the uncertain band). The genuinely scarce resource is neither machine:
it is the two owner keying sittings (M1a's 300 rows, M2a's exhaustive sample) that gate both
programs.

Recommended execution: V-0 spike on both machines, then embed on the Studio + NER on the Air in
one night, context pass the next evening — a weekend of machine time end to end.

### Session 2026-08-07 — LM Studio execution route for the semantic harvest (owner-run)

The owner will run the model passes themselves through LM Studio; the ride-along plan gains §5
(execution route) and the repo gains `tools/semantic-harvest/` — a runbook plus a committed,
**stdlib-only** `harvest_embeddings.py` (no pip/venv; runs on the macOS-bundled python3, which is
what makes the Studio a 15-minute setup). Resumable per volume, provenance-pinned (GGUF SHA-256
via MODEL_FILE, LM Studio model id, chunk/prefix/batch params, machine, script SHA), per-volume
timing log, live ETA, and SHA256SUMS for the Studio → Air transfer the owner named as a
requirement — the runbook's Phase 4 verifies checksums on the Air before anything reads vectors.

Three design consequences recorded in the plan: (1) the **pin moves** from a Python lockfile + HF
revision to the GGUF file's SHA — and a quantized GGUF is a different model for pinning purposes,
so the V-0 gates run through the same runtime as the full pass; (2) **pooling leaves the
harvest** — the store keeps chunk vectors + spans, and pooling/L2/truncation/quantization all move
to the deterministic packer, so a pooling-rule change costs a re-pack (minutes) instead of a
re-run (overnight); (3) GLiNER/spaCy don't run in LM Studio, so the LM-Studio-native NER route is
structured-output chat NER, sample-first, with the NLTagger control in-repo.

**Verified before handover**: the harvester ran end-to-end against a mock `/v1/embeddings` server
— frus1861 → 312 docs / 586 chunks, chunk spans tile each document exactly, resume skips the
completed volume, dimension-change mid-run aborts, checksums and run-manifest written. Confirmed
externally: LM Studio serves `/v1/embeddings`, embedding models must be explicitly loaded, and
EmbeddingGemma-300M has an official lmstudio-community GGUF.

Division of labour is explicit in both docs: owner = setup, V-0 spike on both machines, model
sign-off, full harvest, verified transfer; Claude = store validation, weak-positive MRR gates,
blind-panel staging, quantization ladder, deterministic pooling/packing, artifact tests.

### Session 2026-08-07 — Navigation & state-management audit, both platforms

`Planning/Navigation-State-Audit-2026-08.md`. Seven parallel code auditors over disjoint
dimensions, adversarial verification of every high/medium finding (24 verified, none refuted),
plus four hand spot-checks of the most consequential claims. **49 findings: 12 high, 22 medium,
15 low.**

The owner's two questions, answered: **macOS focus** — deliberate focus-carrying machinery exists
(deminiaturize+front on routed deliveries; `bringMacWindowToFront` because `openWindow(id:)` won't
re-raise a buried singleton) but 11 of ~31 `openWindow(id:)` sites lack the fronting companion,
including 7 of 9 main-window toolbar launchers; Project Home clicks dead-drop entirely with no
document host open, then fire as a surprise navigation later. **Back from a document** — the first
Back works from every origin that pushes onto its own stack; but on iOS every document-to-document
jump (cross-ref, page ref, deep link, edge-tap page-turn) deliberately routes through the Browse
tab, so after one page-turn the origin is lost, and inside sheet-hosted documents the navigation
happens invisibly behind the sheet. The architecture protects the first hop and loses the journey.

Headline finds beyond the questions: **Erase Everything leaves 5 of 19 synced record types
behind** (saved searches, working corpora, custom scopes, person corrections, project leads — the
same fault class Wave R-2a fixed once, recurring beneath its own warning comment); **person
corrections renumber every positional rollup id** while only PersonIndexView observes the
corrections signal, so live search chips and analytics selections silently mis-target; warm
launches route through the Onboarding screen until async boot finishes; iOS restores the selected
tab but nothing inside it; the iPad `.anyWindow` family (orphaned aux windows, cross-window
deliveries); saved searches silently dropping the person/tag/scope filters.

Remediation order proposed in the doc: reset gap → rollup observers → Project Home mint →
hand-off visibility rule → openWindow pairing sweep → the page-turn design question.

### Session 2026-08-08 — #746: Erase Everything accounts for every enrolled @Model

The audit's highest-severity finding: a double-confirmed erase promising "as if newly installed"
left **five CloudKit-synced user-data types** alive locally *and in the user's iCloud account* —
`SavedSearch`, `PersonClusterOverride`, `CustomVolumeScope`, `ProjectLeadEntry`, `WorkingCorpus`.
Second occurrence of the fault class Wave R-2a fixed for `SearchHistoryEntry`, recurring directly
beneath its own warning comment.

**The fix is the structure, not the five deletes.** A hand-written list in `performReset` cannot be
kept in agreement with `frusModelTypes` by reviewers reading a different file — it drifted twice.
So the list moved to `ResetInventory` (`Settings/ResetService.swift`) as two declarations —
`erased` (ordered) and `deliberatelyRetained` (with reasons) — and `ResetInventoryTests` asserts
their union **equals** `frusModelTypes` exactly. Enrol a new `@Model` without deciding its reset
fate and the suite fails naming the type.

**Delete order is now asserted, not just commented.** The sequence is non-transactional, so
dependents must precede what they reference: `DocumentTagAssignment` before `UserTag` (or #406's
`OrphanedTagRepair` resurrects deleted tags as "Recovered Tag"), `CollectionEntry` before
`Collection` and `SessionEvent` before `ResearchSession` (`.nullify`, not cascade), and the three
additions holding a raw-UUID project reference before `Project`, which is now asserted last.

**`SyncedPreferences` is retained — a decision, recorded.** The verifier flagged it as surviving
but "defensible". Traced: `ResetService.resetLocalData` clears volumes, index and caches but not
the `@AppStorage` keys these values mirror, so deleting only the synced record would let the local
copies immediately re-publish it. Retaining is right; leaving it *unstated* was the fault. It is
now the sole entry in `deliberatelyRetained`, a test pins that it is the only one, and the erase
screen says "Your app preferences are kept."

Copy updated in the same commit (new key `settings.erase.warning.inventory` — no String Catalog
ships, so an in-place rewrite would be a silent collision, the same reason R-5 minted the last
key) plus both user manuals.

**Verification:** 10 tests, **6/6 mutations caught** — including the vacuity case (re-inlining the
deletes in `performReset`), which a source-reading wiring guard catches in the style of
`CodingStandardsAuditTests`. 34 green across the reset, CloudKit-schema-inventory and
coding-standards suites; both platforms build clean. No `@Model` or stored property changed, so
the R-7 CloudKit deploy gate is untouched.

**Method note.** The first run of the vacuity mutation reported SURVIVED. It hadn't: a 2-minute
timeout killed the mutation loop before it rewrote `$SP/m6.py`, so the run executed a **stale
script from the #586 session** and mutated an unrelated file. Re-run under a uniquely-named
script, the guard caught it. Generic scratch filenames reused across sessions make a mutation
result a measurement of the wrong thing — name them per-issue.

---

## Session 2026-08-08 — #747: a person filter that survives a rollup rebuild

Fourth item off the 2026-08 navigation and state audit (`Planning/Navigation-State-Audit-2026-08.md`),
covering findings **H-1**, **M-14**, **M-27** and **L-38** — all four are the same root cause seen
from four surfaces.

**The root cause.** `IndexingPipeline.consolidatePersonRollup` does `DELETE FROM person_rollup` and
then writes one row per cluster at `rollup_id = clusterIndex + 1`. Clusters are ordered by canonical
name, so **merging two identities shifts every id after the merge point**. `rollup_id` is therefore
a slot number, not an identity — and the filter chip, the analytics series, the search parameters
and the research-trail signature were all holding it across rebuilds. The user-visible failure is
quiet and wrong in the worst way: after a merge, a chip still labelled "Rusk" filters to whoever now
occupies slot 12.

**The fix is a durable key.** `person_rollup_member`'s primary key is `(volume_id, ref)`, both taken
from the TEI, so it does not move when the table is renumbered. `PersonRollupAnchor` wraps that pair;
`SearchParameters` carries it; `PersonRollupRefresh.rebind` is the single rule that captures one,
re-resolves it, or drops the filter when it no longer resolves.

**Capture happens on apply, not on produce.** Six sites set a `personRollupId`, and none of them can
supply an anchor: `PersonIndexEntry.entry.ref` is **empty** for rollup-sourced entries — only the
store knows the member rows. So the anchor is captured lazily, in one place, on the first rebind.

**Both search surfaces, deliberately.** iOS `SearchView`/`SearchViewModel` and the separate macOS
`SearchSheet`/`MacSearchViewModel` each observe `personRollupGeneration` and each re-resolve. Fixing
one would have reproduced this repo's documented recurring failure (`Dual Settings Views`,
`macOS Search is Separate`), so a wiring test now reads both files.

**M-14 — corpus change never reconsolidated.** `refreshReadOnlyStores()` reopens *connections*; it
does not recompute derived data. Volume add/remove left the rollup standing, so the People browser
listed people whose only mentions were in a removed volume, with their old counts, until the next
launch's drift check noticed. New `AppState.refreshAfterCorpusChange(context:)` runs the same
`consolidatePersonRollupIfNeeded` drift check the launch path uses — cheap when nothing moved,
which is why it is now called at **every** `refreshReadOnlyStores()` site in both storage hubs
rather than at the ones someone judged relevant. `consolidatePersonRollupIfNeeded` now returns
whether it rebuilt, so the generation is published only when ids actually moved.

**M-27 — analytics watched the wrong signal.** `PersonAnalyticsView` reloaded on
`readOnlyStoresGeneration`, which a correction never moves (the rebuild reopens nothing). Every
charted series stayed attributed to ids that had since become other people.

**L-38 — the trail signature meant two things.** `SearchScopeSignature` keyed the person component
on the slot, so two genuinely different scopes recorded either side of a merge could sign
*identically* — a false match that silently reuses one result set for another — while one unchanged
scope re-signed after a rebuild looked new. It now digests the anchor, with the slot kept only as a
labelled fallback for a filter that has not captured one yet.

**A drop is announced, not silent.** When an anchor no longer resolves the filter is cleared rather
than left pointing at a stranger, and both platforms surface an alert. A `nil` store (mid-reindex)
is a no-op, not a drop: "I cannot look this up" is not "this person is gone".

**Verification:** 22 tests in two suites (the rule, exercised with injected lookups; plus
source-reading wiring guards for both search surfaces, analytics, both hubs and both correction
sites). Both platforms build clean. No `@Model` or stored property changed — `SearchParameters` is a
struct and `SavedSearch` flattens it into columns — so the R-7 CloudKit deploy gate is untouched.

**Found while working.** `SavedSearch` persists neither `personRollupId` nor `personLabel`, so a
saved search has never been able to carry a person filter at all. That is #756's territory, left
alone here and now recorded in the test file so the next reader does not mistake it for a
regression from this change.

---

## Session 2026-08-08 — #748: Project Home's macOS clicks stopped dead-dropping

Fifth item off the 2026-08 navigation and state audit, finding **H-0**.

**The defect.** `ProjectHomeView.openDocument` guarded only its `openTab` call with `#if os(iOS)`;
the `appState.openBrowseDocument(...)` beside it therefore compiled and ran on **macOS** too. That
call writes `pendingBrowseDocument`, whose only macOS consumers are the document hosts' `onAppear`
drains. Project Home is its own window, so ⌘W can close the main window while the app keeps running
— and with zero hosts mounted, nothing observed the write.

The click did nothing, and **the value was not discarded**: it sat in `AppState` until the next host
mounted, so the fresh window the user opened minutes or days later immediately navigated itself to a
long-forgotten document. Neither half looks like a bug on its own, which is why it survived.

**The fix.** The macOS arm now calls `appState.openDocument(entry, from: .global, using: openWindow)`
— the provenance router, which **mints a standalone window when no host is live**, precisely so "a
document open must never silently do nothing". `.global` rather than `.tool(…)` because Project Home
has no `ToolWindowID`: it is a dashboard, not a document-derived tool, so there is no launching host
to bind to. The iOS arm is unchanged.

**Project Home really was the only offender — but my first measurement said otherwise.** Checking
whether the five sibling producers shared the bug, I scanned backwards from each call site for the
nearest `#if` and got `#if os(macOS)` every time, i.e. "all six are macOS writers". The opposite of
the truth: their calls sit in that directive's `#else`. Reading the call sites showed all five
already route through `openDocument(…using: openWindow)`. **A nearest-preceding-directive scan cannot
answer a conditional-compilation question**, and it fails in the direction that manufactures work.

**That error is why the test does real scope tracking.** `MacDocumentOpenRoutingTests` walks
`#if`/`#elseif`/`#else`/`#endif` maintaining a frame stack, and asserts that **no macOS-compiled
producer calls `openBrowseDocument` at all**. Three of its six tests exist only to prove the analyser
itself before the invariant leans on it — including the `#else` case that my hand-scan got wrong, and
a `DEBUG`-inside-`os(iOS)` nesting case.

**Why a source-reading test.** `AppStateTests` already proves the *model* mints when no host is live,
and that was true throughout the bug — the defect was that one producer never called the minting API.
No behavioural test can see a call that isn't made.

**A doc comment asserted this invariant and was false for two releases.**
`AppState.pendingBrowseDocument` claimed "on macOS every producer now routes directly through
`openDocument`" while `ProjectHomeView` contradicted it. The comment now records that history and
points at the test; the invariant is enforced by the suite, not by prose.

**Verification:** 6 tests; **6/6 mutations caught** after re-running M1 in a form that compiles.
Note on M1: reverting the platform guard to reproduce the original bug **no longer compiles**, because
`@Environment(\.openWindow)` is itself inside `#if os(macOS)` — a real compiler-enforced improvement,
but it proves nothing about the guard, so it was re-run as M1b (reintroduce an unguarded legacy write
alongside the fix), which the guard caught. Both platforms build clean; macOS manual updated. iOS
behaviour is unchanged, so the iOS manual is deliberately untouched.

---

## Session 2026-08-08 — #749: opening a macOS window now always raises it

Sixth item off the 2026-08 navigation and state audit, covering **M-12, M-13, L-34, L-35, L-36, L-37**.

**Measured first.** 56 `openWindow(id:)` sites across the app: **11 bare, 45 already paired** with
`bringMacWindowToFront`, matching the audit exactly. All 56 are macOS-only (0 iOS-reachable), which
is what makes both a macOS-only helper and a blanket invariant safe. The 45 paired sites were
near-uniform — 44 adjacent same-id pairs, one with a two-line gap — so a mechanical rewrite was
viable rather than risky.

**The fix is the shape the issue proposed.** `OpenWindowAction.fronting(id:)` does both calls, and
all 56 sites use it. Pairing by hand is a *rule*, and rules get forgotten — 7 of the 9 main-window
toolbar launchers had, while every menu-bar equivalent of the same action paired correctly, and two
Analytics-menu items fronted while the three beside them did not. One call makes the defect
unrepresentable rather than merely discouraged.

**The consequence was worse than a dead button.** Several tool windows retarget content from shared
state the moment a producer writes it, visible or not: the Word Cloud toolbar item seeds `.corpus`
scope and the window's `onChange` consumes it, so a buried cloud lost the volume/collection scope the
researcher had set up; `CrossReferenceGraphWindowView` binds `currentGraphEntry` live, so a buried
graph became a different document's graph and only revealed it when next brought forward.

**L-37 — the one scene-level shortcut in the app.** ⌘⇧B was declared on the Corpus Browser `Window`
scene, which runs no code, so it could not front a buried browser *and* appeared on no menu item. It
is now a Research-menu command carrying ⌘⇧B. Every other shortcut in the app already lived on a
command; this was the sole exception.

**L-35 — the Search window had no focus machinery at all.** It now focuses the query field on open
(with the `.task` fallback `CitationLookupView` needed, because in its own words `.defaultFocus`
"never landed") and re-focuses on a `searchQueryFocusToken` bump. The token is deliberately bumped by
only two producers — ⌘S and the toolbar Search button — because parameter hand-offs (Corpus Analytics
→ Search, a saved search, a facet drill-in) arrive pre-filled and stealing focus there would be its
own bug. A test pins that exact producer set.

**L-36 — a label that predated its behaviour.** "Open in Main Window" routes through the provenance
chain, which can land in a document window or mint a new one. Now "Open Document", under a **new**
localization key: no String Catalog ships, so `defaultValue` IS the shipped string and rewriting it
in place would silently retarget anything keyed to the old text.

**Verification:** 12 tests; **9/9 mutations caught** — but only after a rerun, see below. Both
platforms build clean; macOS manual updated (iOS is unaffected).

**A guard that passed for the wrong reason.** The first sweep's M9 — break the invariant test's match
needle — **SURVIVED**: the whole "no bare calls" assertion went green while every launcher was free to
skip the raise again. The matcher was inlined in the assertion, so nothing proved it could match
anything. It is now an extracted `bareOpenWindowSites(in:)` exercised against literal fixtures (a bare
call, a fronting call, and prose about the old API), plus a floor assertion that ≥50 converted sites
exist. Re-run, the same mutation is caught. **An invariant test that scans source must prove its
matcher on a fixture, or it is only asserting that it found nothing.**

**Found while working, and fixed:** the macOS manual documented **⌘F** as "Open Search window" in four
places. ⌘F is Find in Document; Search has been ⌘S since #363 #5. Corrected in the same pass, since
three of the four were in tables this change already had to touch.

---

## Session 2026-08-08 — #750: iOS hand-offs that the user could not see

Seventh item off the 2026-08 navigation and state audit. Seven findings (**H-4, H-5, H-8, H-10,
H-11, M-15, M-29**), three defects, and — the part that mattered — **three different right answers**.

**1. Buried under a stale document (H-4, M-29).** `consumePendingSearch` replaced the query, every
filter and the results, but never popped `vm.navigationPath`. A document pushed from an *earlier*
search stayed on top while the new search ran beneath it, so "Find all mentions" looked like it had
opened the wrong document. Verified before fixing: the entire Search layer has one declaration and
one append of that path and no pop anywhere. Now pops **before** applying parameters — after would
render the stale document for a frame; after `runSearch()` would race the results in.

**2. Buried under the sheet that sent it — and NOT a single rule (H-5 vs H-10/M-15).** The audit
grouped these, but they need opposite fixes:

- **Cross-Reference Analytics (H-5)** is presented *by* BrowserView and hands off *to* BrowserView,
  so it appended beneath itself; each retry stacked another copy. It had no `@Environment(\.dismiss)`
  at all. It now dismisses first — correct because the user is *leaving* an analysis tool.
- **The three reader sheets (H-10, M-15)** — Chronology, Citation Lookup, the cross-reference graph
  — must NOT dismiss. The audit's own complaint is that the user's chronology or lookup context ends
  up "gone". `DocumentView` gained an optional `onNavigateToDocument`; each sheet passes its own
  stack, so a cross-ref or page-turn moves *within* the sheet and the reader keeps their place.

  A test also pins that BrowserView and SearchView must **not** pass it: they host the stack the
  hand-off already targets, so supplying a router there would navigate twice.

**3. Dropped before the tab existed (H-8, H-11).** `pendingAnalytics` / `pendingChronology` were the
only two iOS channels with no appear-time drain — and the only two whose producers create the Browse
tab as part of the same action (`openAnalytics(...)` then `openTab(.browse)`). On a cold launch or a
fresh iPad window, `.onChange` never fires for a value set before the view attached, so the sheet
never opened and the hand-off sat parked until a later one overwrote it; repeating "worked", which is
what made it look intermittent. Both consumers are now extracted and called from `.onAppear` too,
with the observers delegating so the two paths cannot drift.

**Verification:** 8 tests; **9/9 mutations caught**, including two ordering mutants (pop-after-apply,
dismiss-after-handoff) and the vacuity mutant that broke the suite's own `codeLines` helper — the
guard #749 taught me to include. Both platforms build clean; iOS manual updated (macOS is unaffected).

**A compile error worth recording.** Adding the parameter failed with *"extra argument
'onNavigateToDocument' in call"* while the property was plainly declared on `DocumentView`. Two
theories were wrong (`@Bindable` shadowing in `body`; a competing `DocumentView` type). The cause:
`DocumentView` declares an **explicit** `init(entry:)`, so there was never a memberwise initializer
to extend. Swift reports this at the call site, not at the declaration — when a new parameter is
"not there", check for a hand-written init before theorising about scope.

---

## Session 2026-08-08 — #751: reading journeys stay in their tab (Search), page-turns stop stacking

The audit's one genuine **design** question, so it began as an assessment
(`Planning/iOS-Reading-Journey-Design.md`) with options and a recommendation, not a patch. Owner
chose **Option B, staged** — journeys stay in their origin tab, tab-hosted origins first.

**Delivered.** `SearchView` passes a host router, so a cross-reference or page-turn inside a
search-opened document stays on the Search tab and **Back returns to the document the link was in** —
matching macOS, which never had this problem. That is H-3 and M-28.

**M-17a, in the same pass.** New `DocumentJump` (`.push` / `.replace`) threads the reader's intent:
a cross-reference descends (Back returns to it), a page-turn **replaces** the reading position. Every
router host acts on it. Paging through twenty documents no longer costs twenty Back taps — which
mattered most in the Browse tab, where there is no breadcrumb escape at document level and none at
all on regular-width iPad.

**`BrowserView` now also passes a router**, which #750's guard forbade. That guard's stated reason —
"a cross-ref would push onto the browse stack twice over" — was **wrong**: `DocumentView` returns
after calling the router, so there is no second navigation. It was really encoding #750's decision to
keep the change opt-in. The guard now records the new rule and says why the old reasoning failed.

**A correction to my own design document, made while implementing it.** The assessment said Search,
Research and History "each already owns a stack for its pushed reader" — about one line apiece — and
the owner decided against that estimate. Verified afterwards: **true only for Search.** `HistoryView`
has no stack at all (it renders *inside* the Research tab's stack), and that stack's path is a
projection of `selectedItem` typed to `ResearchSidebarItem`, shaped that way for the iPadOS 26
`.sidebarAdaptable` workaround (#238 Fix B / #272). The codebase had already reached this conclusion
once: Project Home was made a **sheet** specifically "to keep it decoupled from the typed
`researchNavigationPath`".

So Research/History is a navigation restructure with a documented regression history, not a one-line
adoption. Corrected in the design doc in place, reported rather than silently re-scoped, and deferred
for a second decision. **Estimate before verifying the shape of the code you are estimating, and the
decision it feeds is built on sand.**

**Not done:** M-17b (the 56 pt edge-tap zone said to overlap the back-swipe region). The zones use
`.onTapGesture`, so a recognised pan should not fire them; nobody has measured it on device; and the
width has a documented rationale (sit outside the reading column so in-column links still receive
taps). Narrowing it blind would trade a measured benefit for an unmeasured one.

**Verification:** 10 tests in the extended suite; **8/8 mutations caught**, including both jump-kind
inversions (page-turn descends / cross-ref replaces) and the vacuity mutant. Both platforms build
clean; iOS manual updated. macOS is unaffected — it already behaves the way this makes iOS behave.

---

## Session 2026-08-08 — #752: an action in an iPad window now happens in that window

Eighth item off the 2026-08 navigation and state audit. Eight findings; **six fixed, two deferred
with reasons.**

**The root of the family.** The standalone document window republishes the *launching* window's
scene as its own `\.sceneID` (`.auxWindowOrigin`), so rail producers have somewhere to present.
Document navigation inherited that too — and **nothing in the app calls
`requestSceneSessionActivation`** (verified: zero hits repo-wide), so the consuming window is never
brought forward. On a Stage Manager iPad the tap looked like nothing happened while another stage
silently changed. When the launcher had closed, or the app had restored the window (which captures
no origin at all), the target degraded to `.anyWindow`.

**H-7 / M-30 — the standalone window now reads on its own.** New
`StandaloneDocumentWindowContent` owns a path and uses #751's router, so cross-references and
page-turns navigate in place, exactly as `MacDocumentWindowView` already did. This takes document
navigation *out of* the aux-origin mechanism rather than trying to make cross-window delivery work.

**H-9 / M-31 / M-33 — the word-cloud channel.** It was the one channel of five demanding an exact
scene match, so a restored or orphaned standalone window targeted `.anyWindow` and **no presenter
matched**: the tile did nothing, permanently, while its rail siblings worked — contradicting
`AppState`'s own promise that `.anyWindow` "never black-holes". It now accepts the wildcard, and
**consumes** into window-local state instead of holding the shared slot for its presentation
lifetime, which is what let window B's producer dismiss window A's open sheet.

**L-39 — two sheets got the `\.sceneID` injection their four siblings had.**

**Deferred, and why.** **M-25** (Spotlight/deep-link content can land in a background window) needs
the app to *activate* the consuming scene — a capability it has never had. Adding scene activation
is a design change with its own failure modes, not a patch. A test now flags if
`requestSceneSessionActivation` ever appears, because it would invalidate the reasoning behind these
fixes. **L-40** (Source Explorer related-document taps) has the same shape: the closure is not a View
and cannot read `\.sceneID`, as its own comment admits.

**Verification:** 9 tests; **9/9 mutations caught — but only after a second round.**

**Three of my own guards were weak, and mutation testing is the only reason I know.**

1. `#expect(body.contains("onNavigateToDocument: navigate"))` passed with **one of the two**
   `DocumentView`s stripped of its router — the root and the pushed destination both need one, and
   `contains` cannot tell. Now counts occurrences.
2. The Citation Lookup assertion extracted a 600-character window and looked for `\.sceneID`
   anywhere inside it. That window **spilled into the ArchivalNeighbors sheet three lines below,
   which injects it too** — so the test passed with Citation Lookup's own injection deleted. It was
   measuring a different sheet's correctness. Now checks line adjacency.
3. The "nothing activates scenes" test asserts *absence*, so breaking its needle made it pass
   vacuously — the same defect #749's M9 exposed, recurring in a new file. Now has a positive control
   sharing one `needle` constant so control and scan cannot drift.

**A character-window extraction is a proximity heuristic, not a scope.** In a file where sibling
call sites do the same correct thing a few lines apart, it will happily prove the neighbour's point.
Anchor on the construct, or assert adjacency.

---

## Session 2026-08-08 — #753: boot-in-progress stops being rendered as a definitive state

Ninth item off the 2026-08 navigation and state audit — M-20, M-22, M-23. Three findings, one lie:
the async boot runs *after* the first frame, and every surface reading a service it creates had a
nil branch that made a **definitive** statement.

- The Search tab: *"Search Unavailable — the search index is not available"*, over a fully built
  index of 316,839 documents (M-23).
- A restored Cross-Reference Graph window: *"No Document Selected"* — with a perfectly good restored
  request in hand — plus an instruction to go open one (M-22).
- `ContentView`: the **first-run Welcome screen**, to a researcher with hundreds of downloaded
  volumes, because `hasDownloadedVolumes(in: nil)` is `false` and `downloadManager` is assigned at
  the very END of boot (M-20).

None is a wait; all three read as loss or breakage. **The flash lengthens with store size**, so it
aims itself squarely at the users with the most to lose.

**One vocabulary, as the issue asked.** New `BootPlaceholderView` — extracted, not copied three times
— and `AppState.isBootComplete`, *derived* from `downloadManager != nil` rather than stored, so it
cannot be forgotten at a set site and then lie in the opposite direction by claiming ready when
nothing is. macOS Search already carried this fix and named the principle: a surface "never renders
the definitive empty state as a lie".

**The honest failure states survive.** At each site a test asserts the real error branch still exists
*after* the boot branch. Deleting "Search Unavailable" or "No Document Selected" would be a way to
make "never lie during boot" pass while making the app strictly worse — a store that genuinely fails
to open still has to say so.

**Re-onboarding still happens when true.** `ContentView` reaches `OnboardingView` from exactly two
places — the genuinely new user (decided on the first frame, since that branch needs nothing from
boot) and the onboarded user whose library is empty *after* boot completed. A test pins the count, so
the fix cannot quietly become "never show onboarding again".

**A test of mine encoded a false assumption.** The sweep initially asserted all three sites consult
`isBootComplete`. That is wrong: the graph scene waits on `crossReferenceStore` specifically, and
keying it to the download manager would be *less* accurate, not more consistent. Fixed the test, not
the code — what the three genuinely share is the placeholder. **One vocabulary is not one variable.**

**Verification:** 8 tests; mutation sweep across the three sites, the derived signal, the placeholder,
and the suite's own prose filter. Both platforms build clean; iOS manual updated.

**A live mutant reached a commit — again, hours after writing the rule against it.** The docs pass
ran `git add -A` while a **one-mutant re-run** was in flight, and captured M1c: `OnboardingView()`
where `BootPlaceholderView()` belongs, i.e. it re-introduced M-20, the defect this PR fixes. Caught
by the post-sweep tree check and restored in the next commit. The #747 rule said "no commits while a
sweep runs"; it failed here because **a single-mutant re-run did not feel like a sweep**. The trigger
is *a background process is editing tracked files*, not *a sweep is running*. Memory updated.

Related habit corrected: `git status --porcelain; echo clean` prints "clean" unconditionally and
reads like a verification. It is not one.

**Method note.** M1 came back `PATTERN-MISS` — my mutant string did not match the real source, so it
measured nothing and would have been reported as a pass had the harness not distinguished the two
outcomes. Re-run against the actual text. **A mutation harness must report "pattern not found" as its
own verdict; scoring it as CAUGHT or SURVIVED silently fabricates a result.**

---

## Session 2026-08-08 — #754: a relaunch gives the document back

Tenth item off the 2026-08 navigation and state audit. Labelled `enhancement` and framed as a
program decision, so it began as an assessment (`Planning/Restoration-Depth-Design.md`) with three
mechanisms costed, not a patch. **Owner decisions: resume reading, offered; and for L-45, stop
persisting entirely** (the stronger of the two options put to them).

**Measured first.** The app's whole restoration surface was **three** `@SceneStorage` keys — the
selected tab and two inspector toggles. No `stateRestorationActivity` anywhere; the two
`.userActivity` sites set only `isEligibleForHandoff`, a different feature. So H-6 is a **missing
capability, not a malfunction** — which is why it belonged in an assessment rather than a bug fix.

**Resume reading beats path-encoding on three counts**, and that is why it was recommended. It reads
`ReadingHistoryEntry`, which the app already writes and syncs, so it needs **no new persistence**; it
survives a **reinstall** and works on a **second device**, which no `@SceneStorage` scheme can; and a
volume removed since the last read is a **row to filter**, not a restored path that dead-ends at
launch — the worst possible moment for a failure.

**Offered, never forced.** Nothing auto-opens, and a test asserts there is no `.onAppear` navigation
in the row. Auto-reopening would make the first frame depend on history the user may have moved on
from, with no way to decline.

**L-45 — the one incoherence.** `search.facets.shown` survived a relaunch while the query and results
it describes did not, so the Search window could reopen with the facet inspector extended over
nothing. **Restoring only the half that is cheap to restore is worse than restoring neither**,
because the surviving half asserts the other one exists. All three Search UI flags are now `@State`,
leaving exactly one persisted key in the app — and a test guards that `frus.selectedTab` *stays*,
since "persist nothing" would be over-correcting: a tab selection describes no content.

**Verification:** 10 tests — three of them driving a real `ModelContainer` (newest-wins,
removed-volume-skipped, nothing-to-offer), so the selection rule is behavioural rather than another
source read. **8/8 mutations caught** after one round of guard repairs. Both platforms build clean;
both manuals updated.

**Two of my guards were weak, and one repeats a pattern that has now recurred three times.**

- M3: nothing asserted that **dismissing the offer sticks**. A dismiss control the next render undoes
  is not a dismiss control.
- M4: deleting the entire `ResumeReadingRow` call from the Browse root **survived**, because the
  assertion was `contains` on the raw source and the doc comment two lines above the call names
  `ResumeReadingRow`. **The prose satisfied the code assertion.**

That is the third occurrence this session — #752's M8 (a character window spilling into a neighbouring
sheet), #753's label check, and now this. **In these source-reading suites, `contains` on raw source
is suspect by default:** filter to code lines or anchor on the construct. All four suites now carry
the same `codeLines` helper.

**Found in passing:** the macOS placeholder told users to "Use Search (⌘F)". Search has been **⌘S**
since #363 #5 — the same stale claim #749 corrected in the manual, still wrong in the app itself.
Fixed.

**Deferred, with reasons in the design doc:** navigation-path encoding (B) and macOS window-content
restoration (C). Note they are coupled to #756: search restoration needs `SearchParameters` to become
`Codable`, which it is not today.

---

## Session 2026-08-08 — #755: a collection can finally open a document

Eleventh item off the 2026-08 navigation and state audit — **M-18, M-19, M-24**.

**The gap.** Collections was the **only** document list in the app with no route into the reader: a
module-wide grep found no `openDocument`, `openBrowseDocument`, `DocumentView` or `pendingBrowse*`
anywhere in `FRUSExplorer/Collections/`, while search, history, chronology, research, the graph,
related documents and archival neighbours all open it. A researcher reviewing documents **they had
deliberately curated** had to remember each one's volume and re-find it through Browse or Search. On
macOS the single per-row "open" launched **history.state.gov in a web browser** — the published text,
without the notes, highlights and cross-references the app exists to provide.

**Fixed by routing like everything else:** the scene-addressed hand-off on iOS, the provenance chain
(with its window-minting tail) on macOS.

Two deliberate constraints, both tested and both mutation-checked:

- **The row tap is unchanged.** It has opened the configure inspector since Composer v2 §D and
  researchers rely on it; the reader route is an *addition* (long-press on iOS, a button on the macOS
  row), not a re-binding.
- **The history.state.gov link stays.** The published text is a legitimately different destination.
  Removing it would be a way to satisfy "Collections can open a document" while taking something
  away.

The open action is also a VoiceOver action, because a context menu alone is not reachable — an
inaccessible sole route would be worse than the gap it replaces.

**M-24 — a consumer with no producer.** `CollectionListView.consumePendingCollectionSelection` has
existed since #369 BUG-12, wired to `.task` and `.onChange` and documented as pushing "the imported
collection's editor so the user lands on it after an open-with import". The only writer of that slot
in the whole codebase was the **macOS** branch, so on iOS it could never fire: the collection
imported correctly, then the user had to find it by name. One line — set before the tab switch, for
the same reason macOS sets it before `openWindow`.

**Verification:** 9 tests; **10/10 mutations caught** after one round of guard repairs. Both platforms
build clean; both manuals updated.

**Two weak guards, two distinct failure modes — and a pattern now four sessions old.**

- **M6:** `contains("accessibilityAction(named:")` passed with the open action deleted, satisfied by
  the row's **move-up/move-down** actions. Now matched on the specific localization key, plus a check
  that the action actually calls `onOpenDocument`.
- **M4:** the test asserted the `history.state.gov` URL still appeared — proving a **URL constant
  exists**, not that anything can click it. (The mutant was also weak: it stripped only the button's
  label.) Now asserts `openURL(url)` survives, and the mutant guts the whole action.

Four sessions running, a source-reading assertion has been satisfied by something other than the
thing it named: #752 a neighbouring sheet, #753 a label in prose, #754 a doc comment, #755 a sibling
accessibility action. **`contains` proves a string exists somewhere, which is almost never the
claim.** Each fix needed a specific key, line adjacency, or a code-line filter.

---

## Session 2026-08-08 — #756: a saved search now recalls the search that was saved

Twelfth item off the 2026-08 navigation and state audit — **M-26**.

**The defect.** `SavedSearch` persisted 12 of `SearchParameters`' 20 fields. The other eight —
`userTagIds`, `volumeIds`, `documentIds`, `excludeDocumentIds`, `projectId`, `personRollupId`,
`personLabel`, `includeFrontMatter` — were dropped on save and returned as **defaults** on recall. A
search saved as "Kissinger détente" came back as plain `détente` over everything: **broader than the
one the user named**, silently. The asymmetry sharpened it — the legacy single-volume `personRef`
round-tripped fine while the modern rollup filter did not, and the facet panel *writes*
`personRollupId` and clears `personRef`, so a facet-narrowed person filter could not survive a save
at all.

**One archived value, not eight more columns.** Eight columns fix today's list and leave the same
trap for field nineteen — `personAnchor`, added in #747, was already a ninth casualty. Archiving
`SearchParameters` itself makes the drop class **unrepresentable**: a new field is persisted by
construction. It is also **one** CloudKit identifier instead of eight, and every identifier is a
Production deploy.

Making `SearchParameters` `Codable` needed only two enum conformances — and both are **raw-value
backed on purpose**. A synthesised enum encoding is positional, so inserting a case into
`DocumentTypeFilter` or `BooleanMode` would silently re-interpret **every saved search a user has**:
the same defect class as #747's renumbered rollup ids.

**This is also the enabling work #754 deferred.** Search restoration was blocked on
`SearchParameters` being `Codable`; it now is.

**Compatibility in both directions.** Existing records have `parametersData == nil` and still recall
from the scalar columns; a corrupt blob falls back rather than returning a blank search. The scalar
columns are **still written**, so a device on an older build reads the record partially rather than
not at all.

**A disclosure that became a lie.** Both save sheets carried the #258 Q4(a) notice, "The volume scope
is not saved with the search — re-apply it after running the saved search." True when written; false
now, and actively telling users to redo work the app had already done. Retired on both platforms —
part of the fix, not a tidy. (#258 called the real fix "the named fast-follow"; this is it, arriving
as one archived value rather than the one additive field it imagined.)

**R-7 gate: fired correctly and handled.** Exactly one added identifier,
`CD_SavedSearch.CD_parametersData`, now listed in `installedIdentifiers` and
`identifiersAwaitingDeploy` with its seeding note. **Owner step outstanding:** save any search once
on a Development build with iCloud signed in, then deploy the schema to Production and clear the
awaiting list.

**Verification:** 9 tests, all behavioural (round-trip, legacy fallback, corrupt-blob fallback,
older-build readability, a real SwiftData persist). **7/7 mutations caught** after one repair.

**The most instructive test failure of the session.** M5/M6 — removing `String` from the two enums —
**survived**, and the test looked right: it asserted the encoded JSON *contained* the case name. But
a synthesised enum encodes as `{"editorialNotesOnly":{}}`, which contains the name too. **The
assertion held under both behaviours.** The property that matters is not "the name appears" but "the
name is the contract rather than the position" — so it now decodes from a *bare* JSON string, which
only a raw-value enum can do.

This is adjacent to the four `contains` failures of the last four sessions but distinct: those
matched the **wrong occurrence**; this matched the **right** one and still proved nothing.
**Assert the property, not the presence of a string that the property happens to produce.**

---

## Session 2026-08-08 — #757: the five findings that close the navigation audit

Thirteenth and final item off the 2026-08 navigation and state audit — **L-41, L-42, L-44, L-46,
L-47**. Five independent small fixes.

**L-41 was in direct tension with #750, and the obvious fix was the wrong one.** The audit wants the
ranked list to survive an open; #750's H-5 fix was to *dismiss* a sheet before handing off. Deleting
the `dismiss()` here would have reinstated H-5 exactly — the document landing invisibly beneath a
still-presented sheet. The answer that satisfies both is the one #750/#751 established for reader
sheets: **push the document inside the sheet.** Related Documents and Archival Neighbors now own a
stack and a reader, with #751's push/replace semantics. A test names that trap so the next reader
does not "simplify" it back.

**L-42** — the dead-but-armed `.constant([])`. Rather than delete the branch, it now passes the real
`$vm.navigationPath`, which exists on both platforms: the trap cannot spring if `SearchView` is ever
reused on macOS.

**L-44** — the graph sheet's `if let store` had no `else`, so a nil store presented a blank sheet
(reachable during boot and after an in-session reindex). It now shows #753's `BootPlaceholderView` —
reusing that vocabulary rather than inventing a second one.

**L-46** — `hasShownThisSession` was `@AppStorage` with nothing resetting it, so a once-per-session
introduction was once-per-**install**. Moved to `AppState`, which genuinely is the session.

**L-47** — the alert action read a slot its own `isPresented` setter nils. Captured via `.onChange`.
A first attempt captured it inside the binding's *getter*, and was backed out: a getter that mutates
state is a re-render hazard and is called at times SwiftUI does not promise.

**Verification:** 8 tests, **10/10 mutations caught** — after two rounds and one harness fix.

**Four guards were weak, and the shape is sharper than the previous sessions'.** Every string I
matched was the *right* string; it just was not load-bearing.

- **M1/M2:** deleting the `return` after `onOpenInSheet(entry)` left the callback, the `@State`
  path and the `navigationDestination` all present — so all three assertions passed while the row
  opened in the sheet **and then also** handed off to Browse and dismissed. Now asserts the early
  return, with a fall-through variant in the sweep.
- **M5:** `} else {` → `} else if false {` keeps `BootPlaceholderView` in the file, so `contains`
  passed while the branch became unreachable. Now asserts the `else` is unconditional.
- **M6:** I checked for `@AppStorage` + the key; a raw `UserDefaults.standard.bool(forKey:)`
  reinstates the defect and is not `@AppStorage`. Now checks **any** persistence API against that
  key, and that the **guard** reads the session flag.

The five previous sessions' failures were `contains` matching the **wrong occurrence**. These matched
the right one and still proved nothing: **the fix existed in the file but was not in the control
path.** Assert the mechanism, not its vocabulary.

**A harness bug worse than a weak guard.** M5 survived a second time for a different reason: the
mutation string `"                } else {"` (16 spaces) is a **substring of any more-deeply-indented
`} else {`**, and Python's `str.replace` took the first match — line 584, nowhere near the graph
sheet. The graph's `else` was never mutated, so the test passed correctly and the sweep reported
SURVIVED. Unlike a `PATTERN-MISS`, which announces itself, **a mutant that silently hits the wrong
line is indistinguishable from a weak guard.** Re-anchored on the unique `#757 (audit L-44)` comment:
caught. **A mutation string must be UNIQUE in the file, not merely correct at the intended site.**

---

## Session 2026-08-08 — R-7 closeout: #756's schema promoted to Production

Owner deployed `CD_SavedSearch.CD_parametersData` to the Production CloudKit schema — the **seventh**
promotion, and the only step of the R-7 checklist that cannot be done from the repo.

Repo side, following the checklist the failing test prints:

1. `identifiersAwaitingDeploy` cleared, with the promotion recorded in place (date, build, and *why*
   it was one field rather than eight).
2. `deployedThroughBuild` 37 → **40**, `deployedOn` → **2026-08-08**.
3. Baseline restated from the test's own output: **234** identifiers, digest `a91e9487…`.

The digest matters more than the count here: the count alone would miss a rename, or an add and a
removal in the same change. Restating it **is** the assertion "I deployed this to Production" — which
is why the test cannot mend itself and the marker cannot drift quietly.

**Effect:** saved searches now carry their complete filter set **across devices**, not only locally.
Until this promotion, #756's fidelity was real on the device that saved and absent everywhere else —
deliberately, since the record kept writing the legacy scalar columns so an un-updated device read it
partially rather than not at all. That fallback stays: it costs nothing and it is what makes a
half-updated set of devices degrade gracefully.

`ResearchTrailMigration`'s interlock — which refuses to run while a record type it writes is listed
as awaiting — is unblocked again, as it was before #756 listed anything.

---

## Session 2026-08-08 — #762: what a collection travelled with

Archival analytics Phase 1, and the first code off the design handoff merged in #778. Three
sections join `CollectionDetailView` after "In Your Library", exactly where mock `1a` puts them:
**Related Collections**, **Cited Over Time**, **Divided at NARA**. No new bundled data — all three
derive from `collection-authority.json`, `lot-claimants-index.json`, and the manifest.

**The ranking metric needed a floor before it ranked anything.** The plan recorded the overlap
coefficient (shared ÷ the *smaller* citing-volume list) as decided, to damp umbrella records.
Implementing it and measuring first showed the metric alone is degenerate: it hits exactly 1.000
for *any* record whose volume list is a subset of the focus record's, **2,846 of the 4,423 shipped
records cite a single volume**, and so **77.8% of all co-citing pairs tie at 1.000**. Ranked on the
score alone, **80.3%** of the top-5 slots for broadly-cited collections went to one-volume records
sharing one volume, a third of those records getting a top-5 that was entirely that. Requiring
**two shared volumes** removes the class outright — a one-volume record cannot share two — and
costs 19 of the 1,577 multi-volume records their list. The tie-breaks then do the real work
(shared count, then the partner's own breadth *ascending*, preferring the specific over another
umbrella), because with coefficients saturating this widely they decide most orderings. For
contrast: on raw shared count the Central Files umbrella tops **461 of 1,557** lists.

The decision itself was not re-litigated — it was implemented, and the measurement that makes it
workable is now in §7.6 of the plan, because #765's Network mode uses the same metric for edge
weights and would otherwise rediscover all of this.

**The mock asked for a number that does not exist.** Divided at NARA's rows read "NAID 4682721 ·
claims 118 of its documents" in the design. There is no such number and there cannot be: a FRUS
citation names a *lot*, never a series, which is precisely the fact NARA's division destroyed —
every claimant claims the whole lot. The rows carry what NARA does state (NAID, record group,
coverage span, and *every* HMS/MLR entry number, where the existing `.candidates` mapping keeps
only the first), plus a line noting the NARA Catalog link above points at one of them. Verified:
all 113 authority records that reach a divided lot have a NAID that is one of the claimants, so
without that line the screen states one answer twice and contradicts itself.

**A generated sentence is a claim, and three shapes made it lie.** "Cited Over Time" writes its own
caption — *enters the record with … peaks across … fades after …* — and each clause had to be
guarded against the chart drawn immediately above it. Two of the three failures were found by the
adversarial review, not by me and not by the mutation sweep:

1. **A maximum that recurs after a dip.** The peak run was found by scanning forward from the first
   maximum, so `Department of the Treasury` — two 1955–1957 volumes, two 1977–1980 volumes, nothing
   between — read "peaks across the 1955–1957 volumes, and fades after the 1977–1980 volumes" with
   the last bar exactly as tall as the first. Both clauses false. **9 of the 600 charting records**
   have that shape. A maximum that comes back is not a peak; the run is now `nil` unless every era
   at the maximum forms one unbroken block.
2. **"Runs through" across a gap.** `Lot 66 D 199` is cited once in the 1951–1954 volumes and once
   in 1964–1968, with three empty eras between; "runs through" asserts a continuity the chart
   denies. **44 records.** They now get a sentence that says they return.
3. **One volume per era**, which has no trend to describe, and a collection still at its height in
   the last era, which has nothing to fade from.

**Mutation testing, two rounds, 30 mutants.** Round 1: 20 mutants, 16 caught. Of the four
survivors, one was an expected non-guard (the early return for a sub-floor focus record is a fast
path — no candidate could clear the floor anyway) and three were real: the caption's two-volume
condition was carried entirely by a *different* condition on the same line (both fire on a flat
1-1-1 shape; only a 1-0-1 shape separates them); two "the list is capped" assertions matched the
constant anywhere in the section, and the Show-all button's own condition mentions it, so removing
the cap from the rendered rows left both green; and a section-gate assertion used `contains`, which
`if true || <gate> {` satisfies while mounting unconditionally.

Round 2 re-ran those against the fixes and added the new guards: 7 of 10 caught. Two more real
gaps — the "enters at its peak" wording had no test, and **deleting the breadth tie-break outright
survived where flipping its direction had been caught**, because the four fixture records happened
to be *named* in the order the tie-breaks produce, so falling through to the name comparison gave
the expected answer anyway. Renamed to sort in exactly the reverse. **A tie-break fixture must be
named against its own expectation, or the last tie-break silently stands in for all the others.**

The third round-2 survivor stays: after the peak-run fix, the two-volume condition provably cannot
change the outcome for buckets from `citedOverTime`, whose ends are non-empty by construction. It
is kept so the function is correct for a direct caller, documented as such, and pinned by a test
that hands it the bucket list `citedOverTime` will not produce — an equivalent mutant recorded
rather than removed or pretended away.

**The review also caught four doc comments asserting numbers I had not checked hard enough**: the
80.3% figure describes a score-only ranking, so attributing that improvement to the floor rather
than to the tie-break was wrong; "Central Files would otherwise top *every* list" is one in three,
not all; a decade axis does *not* merge 1958–60 with 1961–63 (their midpoints fall either side of
1960) though it does put five subseries into one 1960s bar; and 1740 is `frus1872p2v5`'s decade,
not its midpoint, which is 1746. All four are measured now. A wrong number in a doc comment is a
defect in a repo that reasons from its own doc comments.

**Also in scope, from the mock:** the citing-volume list is capped at five with "Show all N
volumes" — the widest record cites 157.

---

## Session 2026-08-08 — #763: how many documents, not just which volumes

Archival analytics Phase 2. `collection-usage-index.json` is the one new bundled artifact the
feature needs: per-(authority collection, volume), per-(central-file class, volume), and
per-(provenance category, volume) **document** counts, plus each volume's source-note total so a
share has a denominator. One pass over the shippable corpus through the surfaces
`SourceExplorerExportGenerator` already pins to the app — `DocumentNoteExtractor`,
`SourceNoteParser`, `ProvenanceCategory.from`, `AuthorityLookup`'s four-step mirror, and
`ExportClassification.derivedKeys` for the gated class — so the aggregate and the per-record export
agree by construction rather than by review.

**Built: 628 KB.** 264,464 notes over 552 volumes (501 carry any), **1,828 of the authority's 4,423
records reached (41.3%)**, 10,435 class keys, 28.3% of notes in a collection and 71.9% carrying a
class.

**Three design decisions the build settled, each against what the plan assumed.**

*No era rollups.* §4-D asked for decade rollups. They would have cost ~157 KB and created a second
era axis capable of disagreeing with `CollectionRelations.coverageEras` — the one #762 shipped a
week's work ago. Every era view is a rollup of these per-volume counts against `manifest.json`,
which the app already computes. One axis, one answer.

*One-letter wire names.* The first build came out at 784 KB, and measuring where the bytes were
showed 307 KB — **38% of the file** — was the strings `"key"`, `"volumes"`, `"counts"` repeated
across 12,273 rows. `k`/`v`/`n` via `CodingKeys` took it to 628 KB with the Swift properties still
spelled out. Nothing was truncated to get there: 3,944 classes hold a single document corpus-wide
and are all still in the file.

*Never build it from an existing export.* The 182 MB `source-explorer-export.json` was sitting on
disk and would have made the aggregation a five-minute script. Joined against the current authority
it carries **28 dead collection ids over 2,040 documents** — including the largest
presidential-library collection — because #696 folded `president's ` to `presidential ` after the
export was written. An artifact test now refuses a usage index whose ids miss the shipped authority,
so the next person cannot take the shortcut either.

**D-3 resolved: the subject-numeric lens ships, folded.** The gate the plan set was to measure
1963–73 subject-numeric class coverage before letting #765 offer the lens. Measured on the artifact
just built (not on the stale export, which predates the post-#687 class fixes): **1,362
subject-numeric leaf keys carrying 6,876 documents across 113 volumes**. At leaf grain it is
unrankable — 691 leaves, half of them, hold exactly one document, and only 8 pass a hundred. Folded
to **category + number** it becomes 326 groups, 13 past a hundred (`POL 27` 1,197, `POL 7` 490,
`DEF 12-5` 218) — a list a reader can work with. The fold ships as
`CollectionKeying.subjectNumericGroup` so #765 calls it instead of re-deriving a rule from prose.

Worth stating because it will surprise: **the class vocabulary holds two different archives**. The
corpus cites the 1910–1949 decimal file and the 1963–1973 subject-numeric file through one grammar,
so 9,073 decimal numbers and 1,362 subject-numeric designators share one column. Anything that
labels or groups classes has to branch — `CollectionKeying.isSubjectNumericClass` is that branch.

**#267 was folded in, and folding it in was wrong.** Its premise — "the SA-3 dashboard's scope
control filters what the decade-aggregated index allows" — describes a control that does not exist.
SA-3 is the one "About the Series" dashboard *without* a `SeriesScopeBar`, deliberately: the
Session-3 plan says "the bundled index is decade×category — do not fake volume scope". So #267 is
not making an approximation exact, it is unlocking a capability that was withheld. And its data
belongs in `source-provenance-index.json` v2, whose store SA-3 already reads and whose generator
already accumulates the volume dimension before discarding it — not in this artifact, which would
make SA-3 load a second file for its own scope control. #267 lands as its own change; the plan's
§7.7 records why.

**What the Documents ↔ Volumes toggle will do.** `lot:54D270` supplies 1,063 documents from 5
volumes; `lot:63D351` supplies 625 from 81. The two rankings are different questions and both are
right. More sharply: **2,595 authority records have no attributed documents at all** — named in a
volume's front matter, never resolved from a document source note — so more than half the authority
disappears when the toggle flips. The reader returns zero rather than nothing for those, so #765's
surface can say which question it answered instead of implying the collection is unused.

---

## Session 2026-08-08 — #267: the scope control SA-3 was withheld

Closes #267, re-scoped. Its filed premise — "the SA-3 dashboard's scope control filters what the
decade-aggregated bundled index allows" — describes a control that does not exist. `SourceProvenance
Dashboard` never instantiates `SeriesScopeBar`; it is the one "About the Series" dashboard without
one, and that was deliberate. The Session-3 plan says it in as many words: *"category filter only
(the bundled index is decade×category — do not fake volume scope)"*. So nothing was inexact. A
capability was refused, on the grounds that an approximated scope is worse than none, and the issue
was really a note to come back with the data that would make it exact.

**The data was already being computed and thrown away.** `SourceProvenanceIndexRunner` accumulates
`volumeIds: Set<String>` per decade purely to report `volumeCount`, then discards the identities.
Schema 2 emits them as `byVolume` — volume id, decade, note total, per-category counts. Because
every volume belongs to **exactly one** coverage decade, a subset of volumes re-totals its decades
*exactly*: no note is split, none is double-counted, and `volumeCount` is the number of volumes in
scope rather than a proportion of the whole-series figure. That is the property that turns the
Session-3 refusal into a shipping control.

**Regenerating was additive, and the old test proved it.** `totalSourceNotes` 268,757,
`volumesCovered` 522, 16 decades — every headline figure came back identical; only `schemaVersion`
moved. The existing artifact test failed on exactly that one assertion and nothing else, which is
the cleanest possible evidence that the new table is another view of the same scan rather than a
different count. 4.4 KB → 134 KB.

**The unscoped dashboard is byte-identical.** `byDecade` stays authoritative and the app does *not*
re-sum `byVolume` when no scope is active. The two are pinned against each other by an artifact
test — decade for decade, category for category — so "scope everything" and "no scope" cannot
diverge without a test failing.

**The refusal survives as the fallback.** `byVolume` is optional, and `SourceProvenanceData` reports
`supportsVolumeScope`. Against a schema-1 artifact the dashboard shows **no scope bar at all** and
the figures stay whole-series — it does not silently filter a decade table by volume id, which is
precisely the approximation Session 3 declined. The behaviour is pinned by a test that constructs a
schema-1 index and passes a scope.

**The manual was ahead of the code.** Both user manuals already said "Controls shared by all four
dashboards: a **Scope** control…", which has been wrong for Archival Sourcing since Session 3. It is
true now; the bullets gained a sentence saying the narrowing is exact rather than estimated, and why.

**Two note counts that will look like a bug and are not.** This generator counts every
`type="source"` element (`SourceNoteExtractor`): 268,757 notes over 522 volumes. #763's usage index
counts notes **paired with a document id** (`DocumentNoteExtractor`): 264,464 over 501. The 4,293-note,
21-volume gap is source notes with no resolvable enclosing document. Two different questions, both
correctly answered; recorded here so nobody "fixes" one to match the other.

---

## Session 2026-08-08 — #764: the flow matrix, and two premises that did not survive

Archival analytics Phase 2b. `provenance-flow-index.json` (254 KB) records where FRUS's editors
sent the reader when they cross-referenced one document from another, aggregated to
(source unit → target unit) pairs on two axes. Two passes over the corpus reusing the validator's
`RefHarvester` + `CrossRefGrammar` for the references and the export generator's parse/authority/
class surfaces for each document's unit — so an edge here is an edge in the cross-ref report, and a
unit here is a unit in `collection-usage-index.json`.

**The funnel is the story.** 2,713,592 references in the corpus → 181,807 sit inside a document div
→ **77,792 resolve to a real document**. The rest are page citations and back-of-book index
entries, which have no archival provenance at either end. Of the survivors, **74,146 (95.3%) are
footnotes**.

**Premise 1 refuted: this is not archival relationship, it is editorial practice.** A cell says
*the editors, annotating material from this collection, sent the reader to material from that one*
— 3,646 of 77,792 references are in document text. That is a real and unmapped thing and worth
showing, but it is not what "reference flow between archives" implies. The artifact carries
`footnoteEdges` so the disclosure is a measured field rather than a sentence that goes stale, and a
test fails if the share ever drops below 90%.

**Premise 2 refuted: §4-I's class-flow half has no signal.** The issue calls the class↔class matrix
"genuinely novel; no equivalent exists anywhere". Measured:

| axis | between units | pairs | refs/pair | top cell | top-100 pairs |
|---|---|---|---|---|---|
| collections | 20,837 | 4,356 | 4.78 | 449 | 42.5% |
| classes | 4,663 | 2,730 | 1.71 | **31** | 18.6% |

The class axis's largest cell is `740.00119 → 740.0011-EW` — one wartime file cited two ways — and
the distribution has no head. The cause is structural, not a parser gap: **the `dN`
cross-reference idiom postdates 1945**. Pre-1940 coverage contributes 33 references corpus-wide;
298 of 552 volumes contribute none; and the decades that do cross-reference heavily cite lot files
and libraries, not decimal classes. The reason no equivalent exists anywhere is that there is
almost nothing to map. Shipped as a measurement so #765 can confirm the thinness rather than
rediscover it, with a test that fails if it stops being thin.

The collection axis is the opposite — legible and historically meaningful: Nixon NSC Files →
Central Files 1970-73 (449), Kennedy NSF → Central Files (365), the Whitman File and Central Files
in both directions (287 / 276), Nixon White House Tapes → NSC Files (261).

**Premise 3 refuted: D-2's label source does not exist.** §4-I says class labels are "partially
available from the authority's class-keyed sub-series children (front-matter names)". All **2,550
of 2,550** such children have `name` equal to `decimalClass` character for character, because
`AuthorityBuilder` sets `childName = ref.subDecimalClass ?? …` — the name *is* the key by
construction. What does exist: FRUS's own front-matter gloss lists (819 rows, 454 cited classes,
15.4% of classed documents) whose era coverage is the **inverse** of D-2's stated priority — 415
rows from the 1950s and 394 from the 1960s against **10 from the 1910s**, because editors only
began writing Sources essays in the mid-1950s. The 1910–49 schedule D-2 names first is precisely
where the corpus is silent. The missing pieces are semantic, not extractive: the country-number
table, the class-8 suffix table, and the rule distinguishing `738.11` (relations with Haiti) from
`768.11` (a Yugoslav subdivision) — identical shapes, opposite readings. Refiled rather than
guessed at; a generator that composed labels without the schedule would emit confident wrong ones.

**Two small mechanisms worth noting.** The join needs a *narrower* inventory than the validator's:
`AnchorInventory` collects every xml:id, and 49,799 index-entry anchors (`inN`) resolve as
documents under the grammar, so `DocumentIdInventory` restricts to document divs or the matrix
mints phantom nodes. And `RefHarvester` gained note-depth tracking — six lines, additive, defaulted
— so the footnote share is measured rather than asserted.

Same-unit flows are stored, not dropped. They are 56% of the joined collection references; the
design excludes them from display, and an artifact that had already dropped them could not disclose
what the exclusion removed.

---

## Session 2026-08-08 — footnote citations: assessed, and a live count contained

The owner asked whether the archival analytics could extend past cross-references between
*printed* documents to editorial footnotes citing archival documents FRUS did **not** print. The
assessment is §7.9 of the plan. The answer is yes, narrower than it sounds — and looking for it
surfaced something already shipping.

**The material is real and reaches the era nothing else does.** 502,601 editorial footnotes,
~66,500 carrying a well-formed archival citation. Against the `#dN` cross-reference idiom's **7 /
0 / 0** references for the 1910s / 1920s / 1930s, footnote citations give **640 / 523 / 1,183** —
verbatim, `(file No. 711.684/11)` and `(811.114 Guatemala/90)`. §7.8 had just established that the
flow matrix is empty before 1945; this is the only thing that fills it.

**But it is ~37% novel, not ~80%.** The 80% figure is document grain. At *volume* grain — what the
analytics actually consume — it is 36.2% for lots and 37.8% for classes.

**And it is only safe for two of the three units.** Lots and library+collection: 0 false positives
in 80 read samples. Subject-numeric: **87.2% out-of-vocabulary** at the strictest gate — `A10` is a
newspaper page, `CF 341` a Conference-File folder, `NSDD 104` a directive. The parser says why in
its own comment: a bare `PRC nn` candidate "is already unreachable from citation scans, which are
sentence-bounded". **The exclusion list is calibrated to the bound.** Remove the bound to read
footnote prose and the reasoning behind it is void, so footnote text needs an anchor-first grammar
of its own and must never route through `decimalClassLocation`.

**What this session actually fixed.** Editorial-note body citations were already being written into
`document_sources` with `citation_era = "footnote"` — and every provenance query over that table
counts rows without filtering the era. `localCollectionStats` is one of them, so **"N documents in
M of your indexed volumes cite this collection"** — the In Your Library line #762 sits directly
above — was blending two different claims: documents *drawn from* an archive, and documents whose
editor merely *mentioned* one. Bounded at ~2,026 rows across 8,700 editorial-note documents, and
the same code kept only `citations.first`, discarding ~1,182 of the 3,208 citations it found.

**Contained by removal, not by filtering.** The obvious fix — add a `citation_era` predicate to the
provenance queries — has twelve call sites and therefore twelve chances to miss one. Instead the
write is gone, and a one-shot `DELETE ... WHERE citation_era = 'footnote'` in the schema pass
repairs an already-built index on its next open. No reindex, no query to review, nothing to miss.
The capability is wanted; the storage was wrong — `document_sources` has a primary key of
(volume_id, document_id), one row per document, and cannot hold the several archives a footnote may
cite.

**Both tests were verified against the pre-fix code**, not just against the fix: restoring the old
write and removing the cleanup makes each fail with `documentCount → 2` — the exact inflation a
user would have seen. The first version of the write-path test passed in both directions, because
its fixture cited a bare lot number and `extractCitations` matches only "National Archives, RG N…"
and "<Name> Library, <collection>…". **A fixture that does not trigger the code under test proves
nothing about it** — the same lesson as the tie-break naming, in a different costume.

---

## Session 2026-08-09 — #765 stage 1: Archival Analytics, the Collections and Your Library modes

**Shipped:** `ArchivalAnalyticsView` in the Analytics family on both platforms — a sixth Analysis
Tools row on iOS, a `Window(id: "frus.archivalAnalytics")` opened through `openWindow.fronting`
from the macOS Analytics menu. Two of the design's four modes: **Collections** (era × archival
unit rankings, plus collection lifecycles, corpus-wide from #762's authority and #763's usage
index) and **Your Library** (rider E, from the user's own `document_sources`). **Not shipped:**
Network and Flows, the two custom-drawn `Canvas` surfaces, which follow in their own change.
`ArchivalAnalyticsMode` carries no case for them — a four-segment picker with two dead segments
would be worse than a two-segment one that grows.

**The mode renders the finding.** Documents weight, umbrella hidden, top collection per band:
`Lot 54–D270` (1,063) through 1947 · Eisenhower's `Whitman File` (1,643) in 1948–1960 · Johnson's
`National Security File` (3,917) in 1961–1968 · Nixon's `NSC Files` (**7,052**, against
`Central Files 1970–73`'s 2,086) in 1969–1976 · Carter's `National Security Affairs` (3,489) in
1977–1992. The documentary base of American foreign relations leaves the State Department's filing
rooms for the White House, and nobody had to write that sentence into the code for the chart to
say it. A test asserts it against the shipped artifacts, so a re-clustering that broke it would
fail the suite rather than quietly re-tell the story.

**Five era bands, not the mock's four, and stored as era *indices*.** `ArchivalEraBand` holds a
`ClosedRange<Int>` into `CollectionRelations.coverageEras` and reads its own years back off them,
so it is a *view of* the one era axis rather than a second set of boundaries — the hazard CLAUDE.md
names for #763. Three of the mock's four boundaries are exact unions of existing eras and `1946` is
not (the axis runs `1941–1947` as one war-years bucket). More decisive: the mock's four omit
everything before 1946 — **261 of 552 volumes**, the band where named collections are nearly absent
(131 reached, largest 1,063 documents) and classes dominate (`793.94` alone 4,956). That asymmetry
is what the Units chip is *for*, so the band exists and the caveat points at it. A test asserts the
five ranges tile indices 0…18 exactly once.

**Charts merge bars that share a label — silently.** A Swift Charts categorical axis keys on the
label string. 279 shipped authority names are carried by more than one record (`White House Central
Files` by nine), and two of the five bands collide inside their visible top twelve: `NSC
Institutional Files` in 1969–1976, `National Security Council` in 1977–1992, where a Ford Library
record and a NARA record would have been drawn as **one bar carrying the sum of both**. Repeated
names gain their repository; a suite sweeps all 40 band × lens × weight × filter combinations for
uniqueness. This was found by measuring the shipped data before writing the view, not by seeing a
wrong chart.

**The umbrella disclosure had to be per band.** `Central Files` supplies 12,060 documents to
1948–1960, 5,480 to 1961–1968, 47 to 1969–1976, and **none at all** before 1948 or after 1976. The
design's fixed "the Central Files umbrella record (157 volumes) is hidden" line would be wrong in
three bands of five, so the chart states what it actually withheld in the era on screen, or says
nothing. The era-specific `Central Files 1970–73` / `1967–69` / `1964–66` records are never hidden:
they are the era's real central-file bar, and suppressing them would remove the State Department
from the very charts that show it losing ground.

**A separate custodian enum, named for what it tests.** `ArchivalRepositoryCategory` classifies an
*authority record* (repository keyword, lot key, name); SA-3's ten-way `SourceProvenanceCategory`
classifies a *parsed source note*. Folding them would make one surface report a distinction it
cannot draw. `Nixon` needs an explicit case beside the `" Library"` suffix — it carries `NSC Files`,
the second-largest collection in the series, and a suffix-only rule would paint the biggest bar of
1969–1976 the wrong colour. The blue bucket is called **Department of State**, not "central files":
392 records reach it and the tail includes post files, so the narrower label would be a claim the
data does not support.

**Documents and Volumes count different populations.** Documents come from the usage index, which
resolves a note to a collection only when the citation names one; Volumes come from the authority,
where a volume counts if its front matter *or* any document note names the collection — so a
front-matter-only record (2,595 of 4,423) ranks under Volumes and vanishes under Documents.
Measured: the top twelve differ in **4 of 5 bands**. The caveat block and the info popover both
say so, and a test would fail if the two weights ever stopped disagreeing.

**Your Library needed two new pipeline queries, and there was nothing to reuse.** No whole-index
aggregate over `document_sources` existed — the only `GROUP BY` on that table runs over a
materialised search match set and needs a query. `archivalLibraryGroups()` groups by
`(volume_id, citation_era, repository)`; `archivalLibraryCollectionGroups()` by the two keys the
authority resolves on. Two traps closed: `citation_era` is **not** the provenance axis — NARA
collections, presidential libraries, and CIA records all write `structured`, and the repository is
what splits them, so `SourceProvenanceCategory.from(citationEra:repository:)` is a faithful inverse
of `baseDocumentSourceRow` rather than a guess; and the collection query excludes the two
central-file forms on purpose, since their `series_name` holds a file identifier such as
`611.51/1-1558`. Those notes are reported as their own figure in the footer rather than lost. The
#351 cross-domain guard is carried over: a presidential-library citation never resolves onto a
State lot cluster.

**Verification.** 39 tests in 7 suites; four assert the claims the UI copy makes against the
shipped artifacts rather than a fixture. The query tests drive the **real indexer** over TEI
fixtures, because the columns they group on are written by the source-note parser and a test that
inserted its own rows would pass while the parser wrote something else. A 22-mutant sweep covers
the category rule, the band axis, the umbrella filter, the sort, the disambiguation, the lifecycle
endpoints, both weights, the category mapper, the band ordering, the #351 guard, the leading-segment
split, and both SQL statements.

---

## Session 2026-08-09 — #765 stage 2: Archival Analytics gains Network and Flows

**Shipped:** the two custom-drawn `Canvas` surfaces, completing the design's four-mode picker.
**Network** is the co-citation neighbourhood of one collection in four custodian sectors;
**Flows** is where the editors sent the reader when they cross-referenced one document from
another, over #764's aggregate. Both modes were measured against the shipped artifacts *before*
any drawing code was written, and that measurement overturned four of the design's premises.

**The Network's edge measure does not survive its own data.** The approved design weights edges
by the overlap coefficient and offers a threshold slider defaulting to 0.25. Measured: the median
focus has **35 partners at ≥ 0.25**, `Central Files` has **1,000**, and it is still **810 at
≥ 0.75**. The coefficient saturates at exactly 1.000 for any partner whose volume list is a subset
of the focus's, and 2,846 of 4,423 records cite one or two volumes — so the Whitman File's top
eight neighbours are two-to-seven-volume lot files scoring the maximum with between zero and ten
documents in common, and a *higher* threshold keeps them. Replaced with Jaccard over citing
volumes and joint documents supplied. Both surface the real neighbourhoods (for `NSC Files`:
Central Files 1970–73, the White House Tapes and Special Files, Kissinger's papers) and both thin
properly under a slider. #762's Related Collections list keeps the coefficient — a five-row list
with three tie-breaks is a different job from a graph with a strength axis.

**Three things Flows cannot honestly offer**, each verified rather than assumed: the **year-range
chip** (the artifact's only volume-shaped fields are two scalars, and the generator aggregates
into a `Pair(from:to:)` carrying two unit ids — a time filter needs a schema-2 regeneration); a
**class focus** (#764's own reader says not to build it, and the class-label rider was separately
refuted in the plan of record — 2,550 of 2,550 class children carry a name equal to the class
key); and **"browse these citations in your library"** (no query joins `cross_references` to
`document_sources`, and `reference_type` defaults body-text refs to `"footnote"`, so a local list
could not reproduce the split the surface is framed around). Each absence is stated in the
caveats rather than left as a gap.

**The review was the session's real work.** A four-lens adversarial review with a verify pass —
42 agents — raised 38 candidates and confirmed 25. The derivation suite was 31 for 31 green
throughout, and **the Network mode rendered nothing at all**: `layout` was gated on a `@State
canvasSize` whose only writer sat inside the branch that state gated, so the geometry never
entered the hierarchy, the size stayed zero, and every device drew a spinner forever. Three
agents found it independently. No test I had written could have: they all exercised the
derivation, which was correct.

The other confirmed defects, all fixed, in the order they would have hurt a reader:

- **Class squares ignored the threshold slider** — 23 of the 40 most-cited foci drew squares
  below their own threshold at the default setting.
- **Class strength was normalised against a collection-only maximum.** On `Conference Files, Lot
  60 D 627` four classes exceeded the strongest collection, the largest by 76%; all four clamped
  to 1.0 and drew at identical size and radius on top of the focus disc. One radial axis needs
  one maximum.
- **The subject-numeric fold took one `min()` per leaf**, so a group could claim more
  jointly-supplied documents than the focus contributed at all. It clips once per volume now.
- **Node captions were cut at 16 characters**, eating the ` · Repository` suffix disambiguation
  appends — so six distinct `White House Central Files` records drew as one identical string. The
  disambiguation pass was defeated at the last step.
- **The dashed hull was a bounding box** in a radial layout, enclosing collection circles that
  were not classes — a dashed outline labelled "Central Files" around a presidential library,
  which is the exact unit confusion the shapes exist to prevent. Classes now take their own
  sub-arc and the layout supplies the hull.
- **The cap was global and the wedge step rank-based**, packing a busy sector 2.6° apart. The cap
  is now per custodian, which also fixes a reading problem: a neighbourhood that is nine-tenths
  lot files keeps its one presidential library.
- The dock's own sentence put class squares over a collection-only denominator; the #498
  status-bar preference was missing on the focus pickers (BrowserView's comment names this
  surface); a detached child outlives its parent's cancellation, so a superseded scan could pin
  the wrong graph; the Flows copy said "destinations" and computed an outgoing share while
  showing incoming; the two Flows columns overlapped below ~220pt.

**Lesson, and it is the same one in new clothes.** A green derivation suite says nothing about
whether the view draws. The `canvasSize` deadlock is the "unreachable pane" class (#363, #338)
with a data dependency instead of a missing modifier, and the only thing that caught it was
reading the code as a renderer would execute it. Both new wiring tests exist because of it.

**Verification.** 37 tests in 3 suites; six assert against the shipped artifacts. A 27-mutant
sweep covers both derivations and the two view invariants.

---

## Session 2026-08-09 — #262: inbound citations stop depending on what you downloaded

**The defect.** `cross_references` holds only the edges harvested from volumes the reader has
**indexed**. So the inbound half of every citation graph was a function of the library: a reader
with ten volumes was shown the citations from those ten and told nothing about the rest. The
graph's `hasUndownloadedSources` flag could not help — its own comment said it "is normally
false", because an edge from a volume you do not have was never in the table to be flagged. The
banner it drove hedged accordingly: "Some volumes that **may** reference this document have not
been downloaded."

**The artifact is 281 KB, not the "big artifact" the issue expected.** #262 sized it from the
validator's ~2.70M resolved references. Two filters remove three orders of magnitude, and both
are properties of the question rather than compression:

1. **Document-to-document only.** Of 2,713,592 references, 181,807 sit inside a document div (so
   they have a source document at all) and 77,792 resolve to a document div in a shippable
   volume. The rest are page anchors, index entries, and targets outside the manifest.
2. **Cross-volume only.** 69,164 of those 77,792 are same-volume — and if you can see a document
   you have its volume, so the local table already holds every one. Shipping them again would
   duplicate `cross_references` and be merged as duplicate arrows.

What remains is exactly the set that is *structurally* unreachable locally: **8,628 edges into
5,740 documents from 184 volumes.**

**Design decisions worth their comments.** Grouped by target, because the question is always
"what cites this document". Endpoints are two-level `(volume, document)` indices so a document id
is stored once per volume rather than once per edge. The footnote share is a **per-target scalar,
not a per-edge flag**: 95.3% of these references are an editor's annotation, so the scalar says
the honest thing at half the size — and the merge documents that a synthesised edge's
`referenceType` is therefore an approximation, with `footnoteSourceCount` as the number to trust.
The artifact carries **no titles or dates**: those live in the volume's TEI, and a surface built
on this may say how many documents cite one and which volumes they are in, never what they are.

**The merge is additive and local always wins.** `completingInboundEdges` adds only pairs the
local table lacks; a local edge keeps its context text and its real reference type. With no
index, the function is the identity — which is exactly what shipped before.

**The banner can finally say what it knows.** It now reads "N documents in M volumes you have not
downloaded also cite this one", naming a real count instead of a hedge, and
`undownloadedCitingVolumeIds` carries the list so a future affordance can offer the downloads.

**Two process notes, both cheap and both caught something.**
- The generator's fixtures used `volume:anchor` for a cross-volume reference; the grammar wants
  `volume#anchor`. Four tests failed loudly — but one, the phantom-target rejection, had
  *passed* on the broken syntax for the wrong reason (it threw "no edges" because nothing
  resolved at all, not because the index-entry anchor was rejected). Fixing the syntax is what
  made it a real test.
- The new app test file ran **zero tests** until `xcodegen generate` enrolled it. `TEST SUCCEEDED`
  with "Executed 0 tests" is the quietest possible green.

**Verification.** 7 generator tests, 10 app tests across 2 suites. Four assert against the shipped
artifact, including that its funnel matches the number #764 reports from the same harvester — two
artifacts disagreeing about the corpus would mean one of them reads it differently.

---

## Session 2026-08-09 — #787: the archival cards join the D3 provenance-stamped export

**The gap.** #765 gave every archival chart card the "View as table" inspector and stopped there.
`ChartDataInspectorView`'s only export affordance is Copy CSV, and `ChartInspectorData.csv` is the
bare table — so an archival table that left the app carried **no method statement at all**: no
scope, no era band, no weight, no caveats. Corpus, Person, Cross-Reference and the Word Cloud all
carry one; the newest analytics surface was the only one that did not, and it is the one whose
numbers most need their method attached.

**All five cards export now**, through `SeriesChartCard`'s `controls` slot — which has existed
since #236 and had **no call site anywhere in the tree** until this change. `libraryCollectionsCard`
became a real `SeriesChartCard`: #765 shipped it as a bare `VStack`, so it was the one card with
neither a table nor an export, and it is the one whose rows a reader is most likely to want.

**Every archival provenance sets `appliesDocumentDating: false`.** Nothing on this surface reads a
document's date — the era comes from the *volume's* coverage span and the counts are of source
notes. The word cloud set that precedent, and a test sweeps all five builders, because printing
"each document is placed at its TEI `<date>`…" above a table that never looked at one is a methods
statement about work the export did not do.

**The caveats carry the two things that are honest but counter-intuitive**, and they are
per-export rather than boilerplate:
- the ranking states **what the umbrella filter withheld, as a number**, and only in bands where
  it withheld anything — it supplies 12,060 documents to 1948–1960 and none at all before 1948;
- the weight caveat spells out that Documents and Volumes count **different populations**, so
  switching changes membership as well as order;
- the Flows export **leads** with the footnote share, computed from the data rather than written
  down, and discloses the same-unit exclusion only when there is one.

**Network and Flows export CSV only.** `AnalyticsFigureExporter` has never rendered a `Canvas` in
this app — its own comment says the PDF path "is only proven against plain `Text`" — so a figure
button there would ship an unproven render path as a finished feature. The two `Canvas` modes hand
an `ArchivalExportRequest` up to the shell rather than inheriting its share-sheet plumbing.

**Verification.** 11 tests in 2 suites. One is end-to-end over `provenancedCSV` and asserts a
negative that matters: the string `TEI` must **not** appear in an archival CSV. The wiring suite
counts five mounted controls and checks the share sheet is anchored outside the mode switch — a
`.sheet` on a `Group` mounts once per child.

---

## Session 2026-08-09 — #790: the four About-the-Series dashboards join the D3 export

**The gap, and why it survived so long.** The D3 program (#474–#479) ran Corpus → Person and
Cross-Reference → figures → heat matrix → word cloud. The Series dashboards were never in scope,
and #474's own body is the giveaway: it "reuses the **tested** `ChartInspectorData` CSV writer
**from the Series dashboards**". They supplied the writer the whole export program was built on
and never received the export. Meanwhile all eleven of their charts pass a `ChartInspectorData`,
so "View as table → Copy CSV" has always been reachable, emitting the bare table with no method.

**Investigating first changed the shape of the work.** A four-agent read of the dashboards found
that cloning the archival provenance onto them would have printed **two false sentences on every
file**, and that both faults were in the shared type rather than in the new code:

1. `appliesDocumentDating` gated **two independent things** — the dating caveat *and* the
   year-range line. Three of these four dashboards never read a document's date (Production
   places *volumes* by print year, Geography counts *volumes* by subject tag, Provenance buckets
   by the *volume's* coverage decade), yet all three have a year control that filters rows. `true`
   prints a false rule; `false` drops the line a reader most needs.
2. `corpusCaveat` unconditionally said counts "cover only the N volume(s) indexed on this device".
   These four read bundled aggregates and render **before anything is downloaded** — that is their
   whole purpose. The default does not merely over-caveat, it understates every figure.

So `AnalyticsProvenance` gained `datingRule` and `corpusStatement` overrides, and the year-range
line now follows `yearRange != nil || appliesDocumentDating`. All three changes are strictly
additive — the four shipped surfaces produce byte-identical preambles, and tests pin that.

**Four builders, not one.** Each states its own dating rule and its own corpus. Administration is
the one that genuinely *is* document-dated (`frus:doc-dateTime-min/-max`, no fallback), and it
carries the two corrections its own controls otherwise imply wrongly: the year range **selects
which presidents appear** rather than re-counting documents, and any-overlap attribution means the
counts are **not mutually exclusive**. Provenance discloses that hiding a category **re-bases every
share**.

**One live defect found, filed rather than fixed (#791).** The volumes-per-administration-year
chart counts range-dated-only volumes whatever the editorial-notes toggle says, while that
toggle's subtitle promises it affects "every count and proportion". The artifact already ships
`volumeCountPointOnly` for exactly this and **nothing in the app reads it**; measured, 14 of 26
populated administrations differ. Fixing it moves numbers on a shipped chart, which is a separate
decision — so this session made the *export* honest instead: that figure's statement says it is
unaffected by the setting rather than inheriting the toggle's claim.

**One shared helper, four small diffs.** `SeriesExportBox` (an `@Observable` holding the share item
and the error) plus a `seriesExportPresentation` modifier, so each dashboard added one property,
one modifier, and a `provenance:` argument per chart. The figure is built from **the card's own
content closure**, so an exported plate cannot drift from the chart on screen.

**Verification.** 14 tests in 3 suites: the override behaviour and its non-regression, the four
statements, and a wiring suite asserting all eleven charts pass a provenance, each dashboard mounts
the presentation exactly once, and every figure is built from the card's content. Full suite 3,136
in 409 suites.

**A note on test fixtures, again.** Two assertions failed at first because they matched the phrase
"indexed on this device" — which the *new, correct* copy also contains, in order to deny it. The
assertion now matches the default caveat's own signature. Matching a phrase two sentences share
tests nothing about which one was emitted.

---

## Session 2026-08-09 — #791: the editorial-notes toggle reaches the volume count

**The defect.** `AdministrationProfilesDashboard`'s toggle says including editorial notes "adds
them to every count and proportion". True of the documents chart and the detail card's shares;
false of *Volumes per administration-year*, whose numerator counted a volume toward an
administration whenever any of its documents landed there — range-dated ones included, whatever
the toggle said.

Measured: **14 of 26 populated administrations** affected (Ford 46→42, L. Johnson 77→74, Lincoln
21→19, Kennedy 31→29), series total 879 → 856. With the toggle **off** — the default, the state
the caveats call "the firmer point-dated data" — that chart read high for more than half its bars.

**The field was already there.** `administration-profiles-index.json` has shipped
`volumeCountPointOnly` since SA-2a and nothing in the app read it. The unscoped branch now picks
between the two scalars; the scoped branch applies the same rule to the per-volume rows it
re-sums.

**Two checks before touching anything**, both from the shipped artifact:
- **No administration is range-only** (0 of 26), so nothing gains a zero bar or drops out.
- **Every administration's per-volume rows reproduce both of its scalars exactly** (0 of 32
  disagree), so the two branches — which read different fields — cannot diverge on this data. A
  test pins that they agree when the scope is everything.

**#790's caveat went with the defect.** The `affectedByEditorialNotes` parameter existed only so
the volumes-per-year figure could disclaim a claim it could not honour. Both charts respond now,
so the parameter is gone and the surviving sentence gained the consequence that had been silently
wrong: excluding notes also withholds a volume whose only tie to an administration is such a note.

**Process note, and it is one already on file.** I ran the pre-fix verification by editing the
working copy and then `git checkout --` to restore — with the fix **uncommitted**. That reverted
to HEAD and discarded it; the next full-suite run failed with the three pre-fix failures, which is
how I caught it. The rule is written down — *commit before mutation testing, because
`git checkout --` reverts to HEAD* — and it applies to a one-off pre-fix check just as much as to
a sweep.

**Verification.** Three new tests, each verified against the pre-fix code: they fail with exactly
the wrong numbers (4 where 3 is right; a volumes-per-year ratio identical across both toggle
states). Full suite 3,139 in 409 suites; both schemes build clean.

---

## Session 2026-08-09 — Plain-language pass across the app's user-facing prose

**The ask.** Review the app's user-facing text and make it plainer, then produce a fresh
`Docs/EditableContent.md` for the owner to edit.

**What was actually wrong.** Not the content — the packing. Measured over all **3,948**
`String(localized:)` defaults, **126 strings run past 200 characters**, topping out at 1,153
(`archival.caveats.body`). The pattern in every one of them was the same: a load-bearing
limitation riding in a subordinate clause after an em-dash, three facts fused into one 40-word
sentence, and vocabulary that belongs in a code comment — *volume-grain*, *re-based*, *the usage
index*, *an under-merge*, *bundled aggregate*, *document chrome*, *higher-signal*.

**The rule.** Plainer must not mean vaguer. Every number, every stated limitation, and every
refusal to claim more than the data supports had to survive — in practice by being promoted out of
a trailing clause into a sentence of its own, which is where most of the added length went and why
several rewrites are barely shorter than what they replace.

**122 of 126 strings changed.** Four were already plain and were left alone, which is a useful
signal that the pass was not rewriting for its own sake.

**Mechanical guards, because Swift checks none of this.** The applying script refuses a revision
whose format-specifier list or Swift-interpolation list differs from the original **at any call
site**, applies multi-site keys to every site (aligning interpolation identifiers per site — the
iOS/macOS pair of `source.explorer.nara.outsideCustody` spells the same value `\(repository)` and
`\(library)`), and preserves each literal's style, rewrapping `"""` blocks with Swift's `\`
continuations. A round-trip re-extract of all 3,948 keys afterwards matched the intended text
**exactly, 0 mismatches**.

**Five rewrites were rejected on review and repaired**, each because the plainer wording claimed
*more* than the original: "most heavily used" for a ranking that measures how many volumes cite a
collection; "covers the whole series" for what was only an independence claim; "exact phrase" for
a stemmed index that has a separate exact-word mode; "the collections cited alongside it" for a
graph that also draws class nodes; and "arrangement" for the app's own named Composition setting.
That is the failure mode of this kind of pass and it is worth naming: the rewrite reads better and
asserts something the data does not support.

**Four tests were pinning the old prose by quoting a fragment of it**, and would have gone on
passing — for the wrong reason — the moment the wording moved. They now match **the real emitter**:
`AnalyticsProvenance` with its overrides stripped (so "does not inherit the default" means exactly
that, whatever the default says), `SeriesAnalyticsExport.adminYearsCaveat` / `.adminOverlapCaveat`,
and `ArchivalAnalyticsExport.weightCaveat`. Two caveats were lifted out of a builder body and
`weightCaveat` moved from `private` to internal to make it possible. This is the same lesson as
#790's fixture note, one step further on: matching a phrase is a guard with a shelf life.

**`Docs/EditableContent.md` regenerated — 214 blocks to 373.** Every `lines:` field recomputed;
**16 blocks named a source file that no longer held the key** and were corrected; one genuinely
stale body fixed (`wordcloud.info.shows.detail.v2`, which still described the surface before
"Size words by" shipped); typographic quotes synced so blocks round-trip byte-for-byte. Four new
sections cover surfaces the file had never carried at all — **§9 Archival Analytics** (all four
modes), **§10 Export method statements** (archival + the four About-the-Series dashboards),
**§11 Source Explorer panels**, **§12 Word Cloud keyness** — plus a **Display & Reading**
subsection in §6 and smaller additions in §5 and §7. §7.11 was moved back inside §7, where it had
never been. Verified afterwards: 373 SOURCE/END pairs, no key documented twice, and every
documented body matches the source (339 exactly, 15 rendering `\(…)` as `%lld`/`%@` placeholders
per the file's own convention).

**Docs pass.** The two user manuals paraphrase five of the revised strings rather than quoting
them, and every fact in those passages is unchanged, so they needed no edit. The dated
`EditableContent.md` archives are snapshots and were deliberately left alone.

**Verification.** Both schemes build clean; **3,139 tests in 409 suites** pass, plus the UI suite.

---

## Session 2026-08-09 — Manual review, and 25 screenshots per document

**The ask.** Review both user manuals, and cut each to 25 screenshots or fewer.

**The arithmetic.** The manuals carried **77 + 7** and **72 + 13** — placeholders the owner still
has to capture, plus images already captured — so 84 and 85 against a budget of 25. Two in three
had to go, and the question for each stopped being "is this nice" and became "can a reader follow
the prose without it".

**Three independent lenses ranked all 149 placeholders** — a newcomer learning the app, an
experienced researcher using the manual as reference, and the owner who re-captures every image
each time the UI moves. Consensus was strong: **18 drew a unanimous *essential***, **101 a
unanimous *droppable***. What survived is what a picture does and prose cannot: a **visual
encoding** (the citation graph's position/size/arrows, bar colour meaning custodian, the
grey-and-dagger treatment of a dead cross-reference), a **layout the reader must recognise on
screen** (the Research rail, the iPad Composer's two columns, the annotated main window), or a
**surface unlike anything else in the app** (Source Explorer). What went is what the prose already
enumerates: settings panes, menus whose items are quoted verbatim beside them, forms whose fields
are bulleted below them, stock OS surfaces, near-duplicates.

**Two placeholders were retired by images that already existed.** Eleven captured screenshots sat
in `Docs/screenshots/` referenced by neither manual. Most are stale — `macos/collections.png`
predates the composer redesign, `ios/settings.png` the Settings reorganisation, the iPad captures
are rotated — but `macos/series-production.png` and `macos/person-analytics-network.png` are
current and matched two surviving placeholders exactly. Final: **iOS 18 + 7, macOS 10 + 15**.

**The review found 70 code-checked defects**, each verified by an adversarial second pass whose
default was that the reviewer had misread something. One was rejected. A sample:

- **⌘[ / ⌘] do not exist.** The Mac manual claimed browser-style Back/Forward in three places and
  in its shortcut table. There is no `keyboardShortcut("[")` anywhere, and a path-based
  `NavigationStack` has no forward history at all. The shortcut section was rebuilt against the
  app's 20 real declarations — the "In a Document" table had **all three rows wrong**, including
  ⌘⌥N for Add Note, which is **New Collection**.
- **iOS search does not run as you type** — `.onSubmit(of: .search)` is the only keystroke path.
- **The unindexed-volumes badge is on Settings**, not Browse.
- **The onboarding "Ready" step has no project form**; the app silently creates *My Research*.
- **There is no top-level History menu** — folded into Research (#363 #4).
- **"Reset iCloud Sync", "Link Search", "Use as Draft", "View Others"** name controls that do not
  exist; **"General Summary" / "Structured Summary"** are not the shipped prompt names.
- **The Network graph has no 32-node cap** — six per custodian quadrant, a different rule.
- **The Mac Settings sidebar has fifteen panes, not thirteen**, as its own table already said.

**Then the repair pass had to be repaired.** The reviewers' fixes replaced sentence *fragments*
with whole sentences, so **21 lines** carried half the old sentence as well as all of the new one.
A 40-character repeated-substring scan found every one; each was rewritten by hand. **A mechanical
fix pass needs a mechanical damage check — "an agent proposed it" is not that check.**

**A second adversarial pass over the repaired files found 41 more**, about half pre-existing: a
**five-row tab table with four prose paragraphs wedged inside it**, rendering its last four rows
as literal pipe text; two dead TOC anchors; ten section cross-references pointing at the wrong
section (`My Volume Scopes` cited as 5.8 when it is 5.11, and 16.1 when it is 16.2); and surfaces
described twice in contradictory terms — a **Graph button in the toolbar** §3.1 says was removed,
a **research strip** §3.2 says was retired.

**Verification is structural, not a re-read.** Both files pass: zero duplicated 40-char fragments
(one legitimate repetition excepted and checked by hand), zero dead TOC anchors, 30 markdown
tables well-formed with consistent column counts, every referenced image present on disk, exactly
25 screenshots each.

**Process note.** These commits initially landed on local `v2` — I had checked it out to pull and
never branched. Caught before any push; `v2` was reset to `origin/v2` and the work moved to
`manual-review-screenshot-cut`. The rule is on file; **`git pull` on `v2` is exactly the moment it
gets forgotten.**

## Session 2026-08-09 — Open-issue verification sweep + resolve-open-issues plan

All 37 open issues read (bodies and comments) and verified against the tree at `9b62f33` — every
"landed?" claim checked in code, none taken from PR prose. **Five closed as completed** with
evidence comments: #765 (all four Archival Analytics modes + D3 export), #764 (flow index + Flows
surface; class-flow surface declined by its own measurement, label-table rider refuted in the plan
of record), #754 (L-45 fix + resume-reading shipped per the recorded decision; B/C deferred until
lived-with), #597 (tip phases #630/#633/#634 + the "Show Tips Again" recall), #663 (both scan
routes + the shared row; the three catalog-field riders carried into the new plan as F-7).

**Three retitled to match their own audit comments:** #795 widened to both missing Archival
Analytics doors (the `MainWindowView:297` toolbar menu lacks the entry, and the SA-3 cross-link
rider never landed — absorbed from #765; the manual promised the toolbar entry at sweep time, and
the same-day #796 review rewrote it to document the gap instead, so the fix now restores that
sentence too); #405 narrowed to the creator-display
feature (similarity axis measured-negative, 2.8% reachability); #358 narrowed to the two real
Zotero dead ends (the local-app premise was wrong). **Status ledgers posted** on #751/#752 pinning
shipped-vs-remaining per finding (verified: Research/History/leads still route through Browse;
M-25/L-40/L-43/L-48 still in the tree; the word-cloud consumer now takes `orAnyWindow`), and on
#651 (the consolidated plan was already corrected — only the runbook edits remain).

**New plan of record: `Planning/Resolve-Open-Issues-Plan-2026-08.md`** — prioritizes the 32
surviving issues into five tiers (quick wins → diagnosis bugs → de-risked features →
infrastructure → owner-gated decisions), carries per-item evidence pointers and effort, defers to
the live N-lane/People/Subjects/reading-journey docs rather than re-planning them, and records the
one new unfiled work item (#663's catalog fields). Docs only — no code, no build bump.

---

## Session 2026-08-09 — Tier 0 quick wins (QW-1…QW-5)

The first engineering row of `Resolve-Open-Issues-Plan-2026-08.md`: five small items, all
evidence-complete in their issues, none needing a decision.

**Every item was verified against the tree before an edit was made, and four of the five plan lines
were wrong.** That is the point of the house rule, and it earned its keep here:

- **QW-2's fix does not compile as written.** The plan (and #657) prescribe
  `.badge(cond ? "·" : nil)`. `Tab` conforms to `TabContent`, not `View`, and **`TabContent.badge`
  has no optional-String overload** — only `badge(_ label: Text?)` admits nil. `View.badge` *does*
  have `LocalizedStringKey?` and `S?` overloads, which is where the issue generalised from. The
  shipped spelling is `Text(verbatim: "·") : nil`. An implementer pasting the plan line hits a
  build error whose obvious "fix" is reverting to `""`.
- **QW-3 is 22 refs in twelve volumes, not 18 in eight** — and the plan's own predicate breaks five
  real links. "An `http(s)` target whose link text is not itself a URL" de-links the five
  `frus1917-72PubDip` supplement PDFs, whose text is prose ("a high resolution color PDF"). The
  shipped predicate has **two** clauses, and measurement shows each is load-bearing: bare-host
  target alone kills the thirty genuine `bookstore.gpo.gov` / `un.org` links; non-URL text alone
  kills the supplement PDFs. Measured over all 552 shippable volumes: **619 http(s) refs, 22
  de-linked, 597 kept.** The plan's verification document was also wrong — `frus1867p1/d303`
  carries `would.be` and `only be`, not the three phrases named; "Shall" is d599.
- **QW-1's SA-3 target is `SourceProvenanceDashboard`, not `EducationDashboardView`** (a four-arm
  dispatcher), and the item is not XS: that dashboard renders on both platforms and, on iOS, inside
  the mid-onboarding `WhileIndexingSheet`. The macOS arm shipped; the iOS arm is filed, because a
  sheet-over-a-sheet during the first index is a design question, not a mechanical edit.
- **QW-1's test cannot be "extended in place."** `ArchivalAnalyticsEntryPointTests.macOSEntryPoint`
  asserts the fronting call against `FRUSExplorerApp.swift` — where the menu-bar item has always
  lived. That is precisely why it stayed green through the whole of #795. Pinning the toolbar
  needed a **second** test reading `MainWindowView.swift`.
- **QW-4's snippet fails the suite.** `bringMacWindowToFront` paired with a bare `openWindow(id:)`
  is the pre-#749 idiom, and `MacWindowFrontingTests` greps for exactly that. The shipped code uses
  `openWindow.fronting(id:)` like its siblings.

**Two doors, one shape.** #795 and #652 are the same bug twice: a window that exists, a menu-bar
item that opens it, and no row in the toolbar menu a mouse-driven reader actually uses. Both are now
in their toolbar menus, and `MacWindowFrontingTests`' roster went from seven launchers to nine so
the next omission is loud. #652 also makes History the **first host-bound `.history` producer** —
`provenance(of: .history)` has always resolved nil, so a document re-opened from History fell
through to the recency chain instead of landing in the window it was launched from.

**QW-2 is a suspect removed, not a fix, and the PR says so.** #657 is unreproduced and its own
report will not choose between a watchdog hang and a data abort at address 0. `""` is still a badge
— it materialises a label in the tab-item layout, which is the stack the crash log names — so
removing it is cheap and defensible. Conviction still needs B-1's device backtrace in Read mode.
The issue stays open.

**QW-5 found the fifteen-lot list existed nowhere in prose.** #651 asks the run-book to record
which lots the 2026-07-29 regeneration re-resolved. The only source is the artifact diff at commit
`2496472f`; the run-book now carries the table and the command that reproduces it. It also states
the outcome as *of that date* — #694 has since pruned the map from 758 lots to 7, so writing "758"
as a description of the bundle would have replaced one stale claim with another.

**Verification.** Seven mutations, one per new guard, each verified to turn its suite red:
the predicate's scheme gate, each of its two clauses separately, both toolbar rows, the SA-3
cross-link, and the badge reverted to `""`. All seven CAUGHT. Both schemes build clean; **3,146
tests in 411 suites** pass, plus the UI suite.

---

## Session 2026-08-09 — #777 stage 0: Free Up Space could delete a file nothing can restore

**Diagnosing B-2 turned up a worse bug than the one reported, and it is independent of the fix.**

#777 says a side-loaded volume reaches search but not Browse. Tracing that produced the mechanism
in one sentence: **side-loading records a volume's existence only as a file on disk plus rows in
SQLite, while every navigation surface derives its universe from `manifest.json`** — so the volume
is searchable (index-keyed) and structurally unrepresentable in Browse (manifest-keyed). Confirmed
in code: `SideloadValidator` takes the id from the *filename*, copies the XML, and calls
`indexVolume`; `ManifestStore` has no mutation API at all (`bundledEntries` is `private(set)` and
only ever filled from the read-only bundle).

**The worse bug, on the way past.** Free Up Space builds its candidates from a directory scan, so
a side-loaded volume *is* offered — and it sorts never-opened volumes **first**, so a freshly
side-loaded volume is by definition the top suggestion. All four removal confirmations end
"…and the volume can be downloaded again." For a side-loaded volume that is false twice over: the
app has no download URL for it, and its copy is written with `isExcludedFromBackupKey`, so it is in
no iCloud Backup and no Time Machine either. **Irreversible data loss behind a reassuring
sentence** — and the reassurance is what makes the button feel safe.

**The guard is a filter, not a warning.** `StorageRemovalPlan.make` gains
`redownloadableVolumeIds` and excludes anything absent from it, exactly as it already excludes
volumes carrying notes. Passing an empty set therefore offers *nothing*, which is the safe
direction for a caller whose catalogue has not loaded: guessing "recoverable" deletes files;
guessing "not" shows an empty sheet. The per-volume Remove confirmation branches to say plainly
that the app cannot fetch this one again.

**A third find in the same area.** macOS's Citation popover substitutes "Citation unavailable —
volume metadata not loaded." when there is no manifest entry, and its **Copy citation** button was
not disabled — only the sibling *Copy as…* menu was — so clicking it put that apology on the
clipboard. Now disabled in the same state.

**Verification.** Four new tests, including one that pins the *premise*: with the guard removed a
side-loaded volume leads the candidate list, so if the ordering ever changes the rationale gets
re-checked rather than silently invalidated. Mutation: removing the filter turns the suite red
(CAUGHT). Both schemes build; 3,150 tests in 411 suites pass.

**What this deliberately does not do.** It does not make the volume browsable — that is the
reported bug and it needs the navigation model to represent a volume with no manifest entry. It
does not touch the ~50 other manifest-keyed surfaces (citations, search scoping, custom scopes,
bulk summarization), each of which degrades for a side-loaded volume. Both are scoped in the
follow-up issue; neither is a reason to hold a data-loss fix.

---

## Session 2026-08-09 — #777 browse half: a side-loaded volume gets a catalogue entry

The reported bug. A side-loaded volume reached search but not Browse, because side-loading records
existence only as a file plus SQLite rows while every navigation surface enumerates
`manifest.json` — and `ManifestStore` has no mutation API.

**The shape chosen, and the one thing that made it safe.** Three options were costed. The one that
fixes Browse *and* the other ~50 manifest-keyed surfaces is to **synthesise a real entry**, because
they all funnel through `entry(forVolumeId:)`. Its hazard is equally concentrated: `downloadUrl` is
**computed from the filename**, so an unguarded synthesised entry hands every repair path a
plausible GitHub URL that 404s — or one day resolves to a *different* volume published under that
name — and `HistoryAtStateCitationFormatter` would cite an unpublished pre-release as published.

So `downloadUrl` became **optional**, and that optionality is the mechanism rather than a nicety:
it forced all fifteen consumers to confront the missing URL at compile time. Ten of them collapsed
into one new `enqueueDownload(_ entry:)` overload that declines what it cannot fetch, so the rule
lives in one place instead of fifteen.

**`TEIHeaderKit`.** The app now reads a side-loaded volume's own `<teiHeader>` with *the parser that
built `manifest.json`* — a second parser would drift, and the drift would surface as a side-loaded
volume whose metadata disagreed with the same volume downloaded. The extraction was blocked because
`ManifestGeneratorCore` and the app each declare `VolumeManifestEntry`/`VolumeStatus`/`DateRange`.
Resolved by a decomposition rather than a move: **the kit owns the grammar, each consumer owns its
model.** `ParsedTEIHeader` carries no manifest types — and lost nothing, because the parser never
set `status` (the TEI header does not carry one).

**A sidecar, not a `@Model`.** A stored property on a mirrored model trips the R-7 CloudKit gate,
and this data has no business syncing: it is reconstructible from the XML beside it, and a device
without the file has no use for it. `<volumeId>.frusmeta.json` lives next to the volume, so deleting
one deletes both, with no orphan row to reconcile. Boot reconciliation parses only files that are
both unknown *and* unparsed — which is what repairs volumes side-loaded before this shipped.

**Citation honesty shipped with it, not after it.** `canonicalDocumentURL` returns `nil` for a
side-loaded volume, which covers BibTeX, RIS, Zotero and the share message from one choke point, and
a `citationProvenanceNote` says why. This was the non-negotiable: the previous session recorded that
stages 1–2 without stage 3 would be *a regression dressed as a fix*, and shipping them together is
that judgement honoured rather than restated.

**A fixture that tested the opposite of its name.** The new browse-universe test used
`frus1969-76v42` — **a real catalogue volume**. `refreshLocalEntries` correctly declined to mint an
entry, `entry(forVolumeId:)` returned the catalogue's, and the assertions failed on a provenance
mismatch. Caught because the test asserted `provenance == .sideloaded` rather than merely
"resolves". The id is now `frus1969-76v99`, with a comment saying why it must stay absent from the
manifest. Same lesson as the tie-break fixtures, in a new costume.

**Verification.** 12 new tests. Five mutations: four CAUGHT immediately; **M1 — reverting the browse
enumeration to the catalogue — SURVIVED**, which is to say nothing tested the central claim of the
whole change. The browse-universe test exists because of that survivor, and M1 is CAUGHT now. Both
schemes build; **3,162 tests in 412 suites** pass.

**Left for the follow-up:** the manuals still describe side-loading as it was; there is no on-screen
label distinguishing a side-loaded volume in Browse (it currently sits in its era with a title and
nothing marking it); and the storage hero's "553 of 552" denominator is untouched.

---

## Session 2026-08-10 — F-1 (#784): where the editors pointed *outside* the printed record

**Shipped as one PR** rather than the two the plan of record budgeted: `SourceNoteKit`'s
`FootnoteCitationScanner`, `DocumentFootnoteExtractor`, the app's `external_citations` table and
document-ordered harvest (`currentDateIndexVersion` → 38), `ExternalCitationIndexGenerator` →
`external-citation-index.json` (159 KB), and the Flows mode's second layer with its own copy,
caveats and export methods statement. No `@Model` change, so the R-7 CloudKit gate is untouched.

**The measurement, from the shipped generator.** 470,827 body footnotes across 552 volumes →
**19,800 references** (8,661 lot, 11,139 library, 1,780 inherited via `Ibid.`) → **19,011 joined**
to the collection authority (96.0%), into 995 units and 3,067 pairs across **284 volumes**. Zero
false positives in 178 read samples.

### The issue's payoff line is false at the issue's own scope

#784 argues footnote citations are "the only archival-flow signal that reaches 1910–1945", citing
640 / 523 / 1,183 references for the 1910s / 1920s / 1930s. At the scope the same issue mandates —
lot files and library collections, decimal classes deferred, subject-numeric never — those decades
yield **0 / 0 / 2**.

Both figures are right; they count different things, and the issue's own verbatim examples say which:
`(file No. 711.684/11)` and `(811.114 Guatemala/90)` are **decimal file numbers**. Over the 159
volumes covering 1910–1945, footnotes name a decimal file 4,877 times, a lot 67 times, and a library
120 times — and most of that last figure is the head-nested *"Photostatic copy obtained from the
Franklin D. Roosevelt Library"* provenance the harvest excludes by design. Lot files and
presidential libraries are a post-1945 filing practice.

So the feature ships without the argument that justified it, and the surface says the span the data
has (`ExternalCitationIndex.eraSpan`, read off the manifest) instead of the one predicted. Recorded
in `Archival-Analytics-Feasibility.md` §7.9a. **This is the fifth plan line this program has found
to be a claim rather than a fact**, and the pattern is now stable enough to plan around: verify the
justification, not only the mechanism.

### `Ibid.` is worth a tenth of what the issue budgets, and its real job is refusal

Non-negotiable 3 sizes the stateful pass at "12,482 notes inherit their repository". Measured over
13,432 `(Ibid., …)` occurrences: 4,209 decimal, 1,471 subject-numeric (both out of scope), 5,863
page/volume references to **publications**, 769 lot (which the anchor grammar reads with no state at
all), 6 library. The machinery earns its place on **bare** `Ibid.` — and mostly by refusing:

- `Ibid., National Security File, Country File, Vietnam` means *the same library, a different
  collection*. The first corpus run inherited the previous unit and filed it under *Recordings and
  Transcripts*.
- `ibid., Central Files, 684A.86/8–956` means *a decimal file* — a unit this grammar does not read.
  The first run filed it under a Conference-Files lot.

Both were found by **reading the generator's sample file**, which is why the generator writes one.
Neither would have failed a test, because no test existed for a case nobody had thought of.

### The exclusion the issue did not name

A footnote nested in the document's `<head>` is the printed document's *own* provenance —
`frus1937v01/d29` fn 1 is, in full, *"Photostatic copy obtained from the Franklin D. Roosevelt
Library, Hyde Park, N. Y."* 533 such notes carry an anchor. Harvesting them would report the editors
pointing outside the printed record when they were describing the printed record itself. The
extractor now returns what it refused, with the reason, so the coverage block can *measure* the
guard — the first run reported "44,356 excluded notes carried an anchor" and the number was
meaningless until split: 268,752 of the exclusions are source notes, which carry archival anchors
because that is what a source note is.

### Verification

- 32 SPM tests + 14 app tests + 5 Flows tests, and a **generator↔app parity test over two dense real
  volumes** (`frus1955-57v19`, `frus1958-60v03` — chosen for citation density, not convenience; the
  first draft used a volume yielding four citations, and the sanity floor caught it).
- **Ten mutations. Three SURVIVED**, and each exposed a fixture that could not reach the code:
  - **M3** — the `Ibid.` publication veto. The existing test used `Ibid., p. 68.`, which a *clause*
    check catches one step earlier, so the note-level state clearing was unpinned.
  - **M8** — the pipeline's per-document `beginDocument()`. Every app fixture had one document, so
    removing the reset changed no result. The scanner's own reset test proves the scanner, not the
    pass that drives it.
  - **M10** — the focus picker's self-edge filter. The fixture had no self-only collection.
  All three now CAUGHT.
- Both schemes build clean; the full suite is green.

### Left explicitly undone

- **The decimal channel.** Unblocking the pre-war reach needs it, and its gate is #784's own
  measurement that 56% of decimal hits are the citing document's own class. That was not re-run.
- **A document-grain surface.** `IndexingPipeline.externalCitations(volumeId:documentId:)` and
  `externalCitationStats` exist and are tested, but nothing in Source Explorer or the research rail
  reads them yet — the table currently feeds only the corpus-wide artifact.
- **Screenshots** for the new Flows layer in either manual.

---

## Session 2026-08-10 — F-2 (#752 tail): an action reaches the window it belongs to

The low-severity remainder of the 2026-08 navigation audit, after PR #769 closed the high-severity
half. Four findings, last re-verified at a commit five PRs back. **Every one of them was re-verified
before a line was written, and two did not survive it.**

### What the verification changed

| finding | audit said | measured |
|---|---|---|
| **M-25** | prefer the activated scene, or front the consuming one | *Prefer the activated scene* is unreachable — `MainTabView` already documents that iPadOS reports **every visible window** `.active`, and nothing exposes the activated scene. Fixed a third way. |
| **L-40** | one unpaired producer | **Holds, exactly.** Line numbers unchanged since the audit; still the only unpaired `openBrowseDocument` of eleven. |
| **L-43** | convert the shared bool to a scene-addressed hand-off | **Wrong shape.** Producer and consumer are one view tree in one window — `AboutView` is a `NavigationLink` destination of the `SettingsView` that presented the sheet. The answer is to *delete* the flag. |
| **L-48** | a refocus leaves a stale origin a later window can adopt | **Does not reproduce.** `openAuxWindow` writes the slot unconditionally immediately before every open and is the only path that mints an aux scene, so a parked value can only be re-read by the window that parked it. **Closed with a documentation correction, no code.** |

Two more corrections to the audit's own text: there is **no custom URL scheme** in this app (the
three continuation entry points are Handoff, Spotlight and the `.fruscollection` open-with;
`frusexplorer://` links are intercepted inside the web view), and the import path grew a *second*
untargeted channel after the audit was written — #755's `pendingCollectionSelection` — so M-25's
import half had got worse, not better, since it was filed.

### The M-25 fix, and the hypothesis it does not depend on

`ContinuationHost` publishes a per-window scene identity **above** the tab view, so each handler can
address the window it fired in; `MainTabView` adopts the published value and keeps its own mint as a
fallback. Both channels then carry the same target, which is what makes `openTab`'s own
"lands in the SAME window (BUG-7)" doc comment true — with two `.anyWindow` wildcards it was false,
because `MainTabView` exists in every window while `BrowserView` must have bootstrapped, so a window
that had never visited Browse could take the tab switch while another took the document.

**The part that matters for review:** UIKit delivers a user activity to one `UIScene` and SwiftUI
bridges that per scene — but that is *not verified on this device*, and if SwiftUI instead fanned the
modifier out, addressing each handler to its own scene would open the document in **every** window
rather than one. `AppState.claimContinuation` bounds it: the first window to fire acts, the rest
return. The change is therefore an improvement under both readings and needed no device gate.

### Verification

- 13 new tests in `SceneAddressingTests`, plus three rewritten in `CollectionsReaderRouteTests` that
  pinned the old untargeted slot.
- **Ten mutations. The first eight were CAUGHT immediately — which was the warning sign**, because
  each directly contradicted a literal assertion. Two harder ones then **SURVIVED**, and both were
  the worst regression the change could cause: deleting `ContinuationHost`'s
  `.environment(\.sceneID, …)` (the handlers still receive a scene, `MainTabView` falls back to its
  own mint, and every continuation is addressed to a token no consumer holds — a black hole where
  `.anyWindow` at least always landed somewhere), and making the token a shared constant (every
  window publishes the same identity, so addressing means nothing). Both CAUGHT now.
- The full suite is green; both schemes build clean with no new warnings.

### Left undone

- Nothing calls `requestSceneSessionActivation`, and `WindowTargetingTests.noSceneActivationYet`
  still pins that. This narrows targets from a lottery to the right window; it does **not** bring an
  off-stage window forward. That remains the one structural gap in the family.
- The Source Explorer window still `dismiss()`es before handing the document off — "leave here and
  go read it" is a design choice, not a bug, and giving that window an in-place reader is an owner
  call rather than something to smuggle in on L-40.

---

## Session 2026-08-10 — F-3 (#775): choosing more than one year

### Two plan premises, both false

**"The reachability half (#586) can ship first and independently."** #586 closed on 2026-08-07 and
its work is in the tree: `FacetRequest.fetchCeiling` is 20,000 and `FacetPaging` does the display
cut. Nothing to ship. F-3 is the multi-select half alone.

**"Tap a second row to add it."** This is what the issue implies and it cannot work. A facet section
is computed **against the active filters**, and a narrow re-runs the search, which invalidates every
section — so tapping 1951 leaves a Years section containing only 1951. There is no second row left
to tap. Multi-select one tap at a time is structurally unreachable, and every design that did not
notice would have shipped a control that appeared to work once.

The answer is a **staged** selection: rows cycle neutral → included → excluded, nothing runs, and
one **Apply** commits the whole selection as a single search. That also fixes the iOS sheet for
free — it stays open while choosing and dismisses on Apply.

### A shipped defect, found while mapping and repaired here

The Years facet buckets on `substr(date_iso, 1, 4)` — the **start year**. A tap applied a
`dateRange`, which is **interval overlap**. Measured on the owner's index: the 1948 row reads
**7,392** documents and the filter it applied returned **7,892**, because 7,562 dated rows span a
year boundary. A facet row that does not deliver its own count is a wrong answer wearing a number.

`yearKeys` uses the facet's own rule, so the row now delivers exactly what it promises. `dateRange`
is untouched and still ANDs alongside — "documents touching this period" is a different question the
filter sheet is entitled to ask, and the Years chip says which rule it uses.

### Negation never reaches SQL, on purpose

Include-minus-exclude resolves in Swift over the section's own buckets, so #775's equivalence holds
**by construction**: `include{1950…1953} − {1950,1952}` and `include{1951,1953}` are literally the
same `["1951","1953"]` value, not two paths that have to agree. The obvious `NOT IN` spelling is a
trap — `substr(NULL,1,4) NOT IN ('1950')` is NULL, SQLite drops the row, and excluding one year
would silently delete every undated document while the panel went on reporting them present.

### Per-domain, and what was refused

- **Years** — multi-select and exclude. The only domain the model could not express at all.
- **Volumes** — multi-select, no exclude. `volumeIds` was already a set end to end; the panel was
  the only thing collapsing it. Exclude adds nothing: the facet lists only volumes in the match, so
  "exclude these three" *is* "include the other thirty-seven".
- **People — neither.** `personRollupId` is one rollup and `PersonRollupAnchor` is singular (the
  #747 renumber defence); a set of N needs N anchors and per-member rebinding, none of which exist.
  And OR multi-select is the *less* useful operation — the historian's question is co-occurrence,
  which Person Analytics already answers.
- **Document type, Provenance** — permanently not. `.all` already means "exclude neither"; the
  other has no filter field by design.

### Verification

- 24 new tests. The acceptance criterion is one of them, run end to end through the real query.
- **Ten mutations, two SURVIVED**: the staged-selection reset in `invalidate` (a selection would
  survive into a search it does not describe, showing checkmarks against rows that may not exist)
  and the macOS `advancedFilterSignature` — **M-1 recurring**, where a field missing from the
  fingerprint is applied, shown as applied, and silently ignored by the search. Both CAUGHT now. One
  COMPILE-FAIL is the `yearKeys` Optionality, which is protection of a different kind.
- 3,210 tests in 419 suites green; both schemes build clean.

### Left undone

- People, above — an owner override would make it a further stage, not a patch.
- The two date rules are disclosed in the chip's help text but not yet in the manuals' Search
  chapter.

---

## Session 2026-08-10 — F-4 (#645 remainder): the pool tells you when it cut you off

**Issue:** #645 · **PR:** (this session) · **Plan:** `Resolve-Open-Issues-Plan-2026-08.md` § F-4

The 2026-08-02 audit listed five items. **Two of them were already done** and the audit did not
know it: PR #654 had stratified the collection-authority alias fallback (item 1), and item 4's
allowlist conversion had been *started* — the doc comment already read "an allowlist by location,
not a count" — but never finished, so the assertion underneath was still `inside == 2`. That
half-finished state is why the audit's prediction came true on contact: the count went red on
item 2's fix, a change that repairs a defect.

### The measurement came first, because #645 let it decide the shape

The issue offered an explicit out: *"If it is rare, this is a doc-comment correction rather than a
code change, and that is a fine outcome."* Measured read-only against the live index:

| axis | containers over the 120-row pool | documents in one |
|---|---|---|
| lot files | 23 of 1,248 | 6,678 (2.5% of source-noted documents) |
| central-file classes | **260** | **105,681 (40.0%)** |

Largest single container: `Lot 54 D 270`, 1,063 documents across 5 volumes. The class axis is an
order of magnitude more affected than the lot axis **and nobody had counted it** — every previous
discussion of pool depth in this issue used lot examples. Not rare, so not a doc-comment
correction. Written to `Planning/Archival-Pool-Depth-Measurement.md` (item 5), which is where the
figure should have been all along instead of PR prose.

### What shipped

- **The scoped re-cut stratifies** (item 2). `applyScope` took the survivors with
  `prefix(limit)`. That is the cut that actually binds whenever a scope is active, because the
  100,000-row fetch ceiling means the query-side stratification rarely fires — so a scoped reader
  was getting the alphabetical head of the alphabetically-first volumes. `applyScope` now takes an
  `ordering:` and the anchored entry point asks for `.stratified`; the default stays
  `.alphabetical` so no finding-aid caller changes behaviour.
- **A truncated total no longer reads as a complete one** (item 3). `GeneratedPool` carries the
  generator's own `availableTotal`. `nil` means *did not count* — neither "none" nor "no
  truncation" — which is the distinction that keeps a caveat off every cross-reference result
  while still refusing to infer a total from what a generator happened to return. The engine takes
  `max`, not sum, because the axes overlap. `RelatedDocumentsView` renders `related.poolCut` only
  when the pool was genuinely cut.
- **A real allowlist** (item 4). `intendedStratifiedRequests` names each site with the reason it
  belongs and derives the count from itself, so adding a site means justifying it rather than
  editing a number. A bare count had blocked this issue's fix twice; the comment says so.

### The sweep found two survivors, and they were the same mistake

13 mutations. The two that survived were **not** exotic — they were the two most likely
regressions, and both were "covered" by an assertion that read source for a string literal:

- Deleting the `isTruncated` guard from the engine's fold. The assertion read
  `poolCutFrom = max(poolCutFrom ?? 0, total)`; that literal does not contain the guard.
- Flipping `applyScope`'s **default** to `.stratified`. The allowlist cannot catch this *by
  construction* — it counts `.stratified` requests, and a default is not a request.

Both fixes were the same move: make the thing callable and call it. The fold became
`RelatedDocumentsEngine.absorbing(_:into:)`; `applyScope` went from `private` to internal. Seven
tests replaced four string scans. The standing lesson (*tests must drive the real emitter*) has now
been paid for twice in one session, in the same file, on the same kind of assertion — when a rule
lives behind a source scan here, assume it is untested until proven otherwise.

### Verified against the code, not the plan

Three of the audit's five items were re-checked before implementing and two were already closed.
That is now the fourth consecutive session where a plan line was stale — the habit of reading the
code before the plan is earning its keep. One doc comment was also caught mid-session giving
guidance the shipped surface contradicts (`poolCutFrom` told a caller to say "at least" rather than
"of"); CLAUDE.md's warning that doc-comment *accuracy* has no mechanical gate is not theoretical.

### Left undone

- The 120 floor itself. The measurement says the cut binds often; it says nothing about what
  raising the floor would cost in per-anchor query and scoring time, and that needs its own
  measurement before anyone touches it. Recorded in the measurement doc under "what this does not
  license".
- #353's decimal-class slice (N-1) is the change that would make this pool *bigger* for the axis
  that binds hardest. Still scheduled in the N lane, still the largest reachable data win.

---

## Session 2026-08-10 — F-5 (#733): a CIA Job number is a front-matter key

**Issue:** #733 · **Plan:** `Resolve-Open-Issues-Plan-2026-08.md` § F-5

Sized "S — keying gap only". It was neither, and the audit that established that is most of the
session's value.

### Three stated facts were wrong, and each changed the design

1. **"19 rows."** Measured now with the app's own grammar: **664 rows across 122 volumes** name a
   Job — 619 outline items, 45 prose. 564 carry only an inherited `repository`, 98 carry nothing:
   **662 of 664 have no container key**. The issue's own hedge ("the real population is likely
   larger") understated by more than an order of magnitude.
2. **"SourceNoteParser already owns the Job grammar — reuse it."** Not reachable: `jobRegex` was
   `private`, with no standalone entry point (only `tryCIACollection`, gated on the note naming
   the Agency), and `SourceNoteKit` was not a dependency of `VolumeSourcesIndexGeneratorCore` —
   directly or transitively. Reuse meant new public API plus a Package.swift edit.
3. **"Never a second regex."** There already was one, for **lots**. The generator declared
   `\bLot\s+([\w\s\-]+?D\s*\d+)\b` — D-designator only, the pattern the app replaced at index
   version 18. Measured against the app's own table it cannot see **249 rows across 75 volumes**
   (225 F-designator embassy/consulate posts), and it minted malformed keys (`lot:FILE03D256`,
   `lot:6D379`). The bundled index has been missing those collections all along.

### The design decision the measurement settled

The obvious gate is "extract a Job only where the text names the CIA". Measured, that drops **82
unmistakably CIA rows** — `DCI (McCone) Files: Job 80-B01285A`, `DDO/DDP Files: Job 64–00352R`,
`NIC Files, Job 79–R01012A` — because only 20 of the 664 name the Agency in their own text; the
rest inherit it. So the gate is the **grammar itself**, which produced zero non-job captures over
all 33,764 rows, plus a two-leading-digits guard that makes the property structural rather than
lucky and costs none of the 664.

Job numbers get **their own column and key space**. The document side stores them in `lot_file`,
which is fed to the bundled lot resolver — a job number there is looked up as a lot. The norm is
load-bearing, not tidiness: `79R01012A`, `79-R01012A`, `79–R01012A`, `79R–01012A` are one
collection cited 214 times. 395 job norms vs 1,734 lot norms, **0 collisions**.

`accumulateAuthority` also had to widen: it folds a node only when it is a heading or carries an RG
or a lot, and 618 of the 620 job rows are none of those — the key would have reached nothing.

### Result

majorCollections **2,929 → 3,410**: +252 job, +302 lot, 59 re-keyed from malformed forms. Every
removed key was traced. Index version 38 → 39.

### Left undone, deliberately

- **I-3 (GeneratorKit migration) was NOT folded in**, against the plan's suggestion. The pairing
  existed so the regenerated artifact could be byte-verified, and #733 legitimately changes that
  artifact — landing a mechanical refactor alongside makes every byte difference ambiguous between
  the two. It is cheaper now, not dearer: the target gained its SourceNoteKit dependency here.
- **`Lot 2015D608` regressed by one collection in one volume.** The *shared* grammar requires
  `\d{2,3}` before the designator letter, so a 4-digit lot prefix matches nothing — the app misses
  it too. The old generator regex caught it by accident. Filed rather than papered over.
- **The 45 prose-kind Job rows are still unkeyed**, and that is consistent: prose rows carry no
  keys at all (2,524 of 2,524). They are a #668-adjacent encoding gap — paragraph-encoded
  collections in sections that also contain `<item>` rows, so the promotion pass skips them — not
  #733's keying gap.

---

## Session 2026-08-10 — F-6 (#405): NARA names the office that made the records

**Issue:** #405 · **Plan:** `Resolve-Open-Issues-Plan-2026-08.md` § F-6

The plan's numbers held up — rare enough this month to be worth saying. 622 series carry a creator,
reached independently: 8,234 NAIDs are named by the bundled indexes, 2,121 of them are series in
the 4.5 GB harvest, and 622 of those carry `creators`. 364 distinct headings, 52 KB.

### Two plan lines needed correcting in flight

- **"with a #650-style cohort statement"** — there is no cohort to state. #650's chip is
  `"%@ · 1 of %lld"` and its rule is that the count is taken *before* any scope and *includes* the
  anchor, so the same pair never reads two sizes on two screens. A creator is an attribute of one
  series, not a set the reader is standing inside. Borrowing the phrasing would have implied a
  measurement nobody made, so the creator is a plain `LabeledContent` row like every other
  identifier in that panel.
- **"rendered … both Source Explorer views"** — the row already existed. `curatedLotSection`'s
  `.candidates` branch has shipped a "NARA Creator" row since #669, driven by a `creatorName` that
  `LotClaimantsIndex.candidatesOutcome` hard-coded to `nil`. Feeding it cost one expression and no
  new localized string.

### The display rule took three attempts, and the test caught the first

NARA appends the creating body's lifespan to its heading. Stripping it is obviously right; *how*
is not.

1. "A trailing parenthetical containing a year" — eats NARA's **identity** form, turning
   `President (1945-1953 : Truman)` into a bare `President`. Caught by a test written before the
   artifact was regenerated.
2. "Digits, slashes and dashes only" — safe, and left **106 of 369** headings with their tail
   attached, because NARA hedges: `(1958 - ca. 1961)`, `(1969 - 1974 ?)`.
3. **"Contains a year AND not NARA's ` : ` disambiguator"** — measured to strip 369 of 369.

The ` : ` guard protects nothing in today's corpus: the presidential form appears *mid*-heading,
where an end-anchored pattern cannot reach it. It stays because the next harvest may put one at
the end, and the failure would be silent.

### Three guards keep a true fact off the wrong record

Series level only (a file unit borrows its series title from its parent and would borrow the
creator the same way); not an untrustworthy NAID (#351's list); and never the record group, whose
creator reads "Department of State" for three-quarters of the corpus. The divided-lot row names a
creator **only when every claimant agrees** — a lot NARA split across 13 series may have several
creators, and naming one would be false for the rest.

### Left undone

- **The similarity axis stays refused**, and the generator's doc comment argues it at length so the
  artifact's existence is not later mistaken for evidence that the axis became viable. 2.8% corpus
  reachability, structural: only the lot route reaches a series NAID.
- **Predecessor creators are stored and unrendered** (117 series). The harvest pass is the
  expensive part, and re-running it later to answer a question this scan could already answer costs
  the same again — the principle the presidential-library harvester states for its deeper levels.
- **No export path exists for the bundled lot record**, so the new row has nothing to travel into.
  Only live catalog results are exportable (`naraExportText`). Worth knowing before someone reads
  the #680 caveat and assumes this row is missing from a copy.

---

## Session 2026-08-10 — F-7 (#663): what NARA can tell you before you travel

**Issue:** #663 (closed; this is the carried remainder) · **Plan:** § F-7

The plan named three catalog fields. Measured against the 622 series the app can actually name,
one of them barely exists and the two most useful are not on the list.

| field | coverage of 622 | signal |
|---|---|---|
| `accessRestriction` | 100% | **414 restricted**; 338 cite FOIA (b)(1) National Security |
| inclusive dates | 100% | real year pairs |
| `physicalOccurrences.extent` | 100% | "1 linear foot, 3 linear inches" + holding facility |
| `useRestriction` | 100% | 205 copyright-restricted |
| `findingAids` | 19.6% | Folder List ×108 |
| **`numberingNote`** | **1 (0.2%)** | **dropped** |

`numberingNote` is projected on 385 records corpus-wide and reaches **one** the app can name.

### Access and use are two rows, and the cross-tab is the argument

(access-restricted, use-restricted) = (yes,yes) 175 · (yes,no) 239 · (no,yes) 43 · (no,no) 165.
All four cells populated: 43 series may be **read** but not freely **published**, 239 the other
way round. Folding them misleads in both directions. A status can also arrive with no categories
(5 of the 43), so the render path has an empty-list branch with a test on it.

### Where it landed, and why not where the plan said

The plan said `NARACatalogResult` — the **live API** path, which needs a key and a network. The
bundled lot panel is what a reader actually hits, and F-6 measured it at 618/618 covered. So the
facts ride the bundled artifact, on the same NAID key F-6 established.

### The artifact was renamed rather than duplicated

Same records, same harvest pass, same key — one artifact is right, and `series-creator-index.json`
would have been an actively misleading name for a file carrying access restrictions. Renaming a
just-merged resource is cheap; renaming it later is not. Schema 1 → 2, 52 KB → 105 KB.

### The sweep found a determinism bug my own comment had already flagged

I wrote "deterministic because the rows are iterated in a sorted order" and then iterated a raw
Dictionary. Every vocabulary would have renumbered between runs with no input change — a diff on
each regeneration, hiding any real one. Fixed, and then the *fix* survived its mutation, because
the artifact test reads the committed file, which a generator mutation cannot move. `buildRows` is
extracted and driven directly; 6/6 caught.

### Left undone

- **The live `NARACatalogResult` path still shows none of this.** Its decoder reads
  `coverageStartDate`, while the harvest uses `inclusiveStartDate` — worth confirming the live API
  actually sends the former before anyone extends that path, since a mismatch would mean
  `dateRange` is silently nil there today. Not investigated; flagged.

---

## Session 2026-08-10 — F-8 (#358): every iOS route to Zotero now goes somewhere

**Issue:** #358 · **Plan:** § F-8

### The plan named the wrong mechanism

F-8 says "offer the web-library/file hand-off". The Zotero design doc's own **verified Fallback B**
is different: share the document's `history.state.gov` URL, which Zotero's iOS share extension
ingests through its web translators. That is the only route into Zotero on iOS without an API key,
and the document share menu did not offer it — it offered BibTeX and RIS files, neither of which
Zotero on iOS can read.

The upstream finding (recorded in `BigPicture-ZoteroExport.md`, verified against `zotero/zotero-ios`):
no `CFBundleDocumentTypes` for `.ris`/`.bib`, no File → Import, and a share extension that accepts
`public.url` and runs web translators with **no citation-file parser**. A shared RIS makes Zotero
appear in the sheet and then does nothing — the exact reported symptom.

### Three changes

1. The document menu offers the working route on iOS, lossy on purpose and labelled as such.
2. The collection row's caption stops over-promising. It read "Falls back to an RIS file with no
   account" on **both** platforms; it is now platform-aware and names the Mac.
3. A failed send recovers. Both failure paths — missing credentials and a thrown send — offer the
   file route, which does not depend on whatever broke the API call.

### The owner yes/no turned out to be moot

The plan offered an alternative: "if the owner rules the RIS-to-a-Mac path sufficient, close the
issue." No decision was needed — the RIS path is *retained* and simply labelled honestly, so the
dead end closes either way. Nothing was closed on the strength of a decision nobody took.

### The sweep caught a loose assertion of mine

Renaming the localized key `document.share.zoteroWeb` → `…zoteroWebRemoved` passed, because my test
checked for the bare substring and the longer key contains it. Pinned to the quoted key. Worth
remembering generally: a source-scan assertion on an identifier prefix is satisfied by any longer
identifier that starts the same way.

### Left undone

- **Live E2E against a real Zotero library is still owner-only** and remains on the build-33
  checklist — the share-extension hand-off in particular cannot be verified in a simulator without
  the Zotero app installed and signed in.
- **The collection sheet has no multi-document web route**, by design: the share-extension path
  takes one URL at a time. If that ever changes upstream, the sheet is where it would go.

---

## Session 2026-08-10 — F-9 (#306): drag the chart to narrow the years

**Issue:** #306 (body empty; the plan line was the whole spec) · **Plan:** § F-9

`chartXSelection(range:)` on the date chart, committed on **release** rather than continuously:
Swift Charts updates the selection through the whole drag, and writing the year range on each frame
would re-filter and re-render the series under the user's finger.

### "Honor the existing chip + reset" was already true

Both read `yearRangeIsCustom`, which is derived from the two year bounds. A drag that writes the
same state the steppers write surfaces the chip and Reset with no second code path. The plan line
implied work; the work was to *not* introduce a parallel path.

### Two rules that needed care, one that did not exist

- **A decade selection covers ten years.** The By Decade axis plots decade *starts*, so a drag from
  1950 to 1960 means 1950–1969. Committing the raw upper bound drops nine years the user visibly
  selected, and the chart redraws narrower than the gesture that produced it.
- **Bounds clamp to the corpus.** A drag can end past the plotted data; an out-of-corpus bound
  yields an empty chart whose only escape is Reset.
- **A descending drag is impossible.** The first draft ordered the bounds defensively and
  documented Swift Charts as reporting them "as drawn". That is false: `chartXSelection(range:)`
  yields a `ClosedRange`, and `1962...1947` **traps at construction** — which is how the claim was
  caught, because the test written to prove it crashed on its own literal. Dead code and a wrong
  comment, both removed; the test now pins the invariant the type guarantees so the next reader
  knows why there is no min/max.

### The rule was extracted before the sweep, not after

Three sessions running, every mutation survivor was a rule no test could call. `ChartScrubRange`
was written as a pure function from the start. The sweep still found one gap — the *wiring*
(`decadeStride` forwarded from the chart) has no runtime seam, so a literal `false` there passed
every behavioural test while making each By Decade drag select a single year. Pinned by a source
assertion that says plainly it is a wiring pin, not behaviour.

### Left undone

- **The scrubber is on the single-term date chart only.** The multi-term comparison chart (D1) and
  the categorical Subseries/Volume axes have no year x-axis to drag; the latter two ignore the year
  range entirely (`isDateBased`).
- **No haptic or live range readout during the drag.** The selection is invisible until release —
  acceptable because the commit is immediate and reversible, but a live overlay would be the
  obvious refinement if it reads as unresponsive on device.

---

## Session 2026-08-10 — F-10 (#263): paste a chapter's footnotes and triage them

**Issue:** #263 · **Plan:** § F-10

### "Engine unchanged" was true and misleading

`CitationMatchingEngine` and `CitationParser` needed nothing — and `CitationParser.parse` takes
**one** citation. Nothing in the app turned a chapter's footnotes into the list to hand it. That
splitter *is* the feature, and the plan costed it at zero.

### Why the splitter is marker-first, not newline-first

Real blocks break the naive rule in both directions. A citation copied from a two-column PDF or a
narrow measure arrives wrapped across three lines — splitting per line yields three unparseable
fragments instead of one good citation. And a running notes paragraph puts several footnotes on one
line. So: a numbered marker starts a citation, marker-less lines continue it, and a block with no
markers at all is one citation per line.

The marker is bounded to three digits. Unbounded, `1969. Memorandum…` reads as footnote 1969 and
**silently eats the year** — a mutation confirmed nothing else catches it.

### Four outcomes, not three

The plan says resolved/ambiguous/missing. `.failed` is separate: "we looked and found nothing" and
"we could not look" send a researcher to different next steps — a different volume versus fixing the
citation text. Ambiguous carries its count, because 3 possibilities and 12 are different problems
when triaging a chapter.

### Sequential lookup, on purpose

The engine is an actor over the same index the rest of the app reads, and a chapter is tens of rows.
Fanning out would contend for the index to save a second on a list the reader is about to read line
by line — and rows arriving in paste order is what makes partial progress legible. A row that throws
becomes `.failed` rather than aborting the batch.

### Left undone

- **No export of the triage table.** A researcher who triages 40 footnotes may well want the result
  as a file; nothing here produces one. Deliberately out of scope, and worth its own issue if it is
  wanted.
- **The table does not disambiguate in place.** An ambiguous row states its count; choosing among
  the candidates still means a single lookup. That is the obvious next increment.
- **Sequential lookup is untested for a very large paste.** Tens of rows is the design point; a
  thousand-line paste would run visibly long with no cancel.

---

## Session 2026-08-10 — F-11 (#265): look up an abbreviation across every volume

**Issue:** #265 · **Plan:** § F-11

### "A search-scoped UI over it" was two things short

The `terms` table and its `term` index exist, as the plan says. There was **no query API** — only
an insert. And the framing assumes a glossary has one answer per abbreviation.

### The corpus disagrees, and that is the feature

Measured on the owner's index: **66,095 glossary rows over 312 volumes, 10,632 distinct terms,
5,685 defined in more than one volume.** The editors did not standardise their glossaries:

| term | volumes | distinct definitions |
|---|---|---|
| `EUR` | 231 | **30** |
| `S/S` | 225 | 25 |
| `NSC` | 276 | 10 |

A corpus-wide glossary showing one line per abbreviation would be picking one volume's wording and
hiding twenty-nine. So a result carries its variants, most widely used first, each with the count
of volumes behind it — and only contested terms get a disclosure, because for the ~47% defined one
way it would be a control with nothing behind it.

### Ranking, and two things the SQL had to get right

Exact, then prefix, then contains; breadth within a rank. Someone typing "NSC" wants NSC, not "NSC
Action No." above it, even though the latter may be defined in more volumes. Breadth is the
tie-break because a glossary carries no frequency data of its own.

- **LIKE wildcards are escaped.** `100%` must search for a percent sign. Unescaped it matches
  everything — the worse failure, because it looks like an answer.
- **The per-term volume count is the widest variant's, not the sum.** Summing reports 220 volumes
  for a term defined in 231, and would exceed the corpus for a heavily-contested abbreviation.

### Left undone

- **No path from a definition to the volumes using it.** Each variant knows a sample volume id but
  the row does not link anywhere. That is the obvious next increment and the one a reader will ask
  for first.
- **No in-document affordance.** Selecting an abbreviation while reading does not offer this
  lookup; it is reachable from Search's overflow only.
- **Terms are indexed only for downloaded volumes**, so the corpus-wide claim is bounded by what
  the reader has. The empty state says the index needs a volume, but the counts shown are not
  labelled as "of your downloaded volumes" — worth wording if it confuses.

---

## Session 2026-08-10 — Tier 3 begins: I-3 volume-sources onto GeneratorKit

**Issue:** #270 · **Plan:** § I-3

The debt F-5 deliberately took on. That session declined to fold this in because the pairing's
point was **byte-verifying** the regenerated artifact, and #733 legitimately changed the artifact's
contents — a refactor landing alongside would have made every byte difference ambiguous between the
two.

Alone, the check is clean and it passes: same `GENERATED_DATE`, `cmp` reports the artifact
**byte-identical**. That is the whole claim of a mechanical migration, demonstrated rather than
asserted — and it is the thing the plan asked for that F-5 structurally could not provide.

What moved: the inline `contentsOfDirectory`/filter/sort becomes `VolumeCorpusEnumerator.volumeFiles`
(the sort keeps the artifact stable, so it is the part worth sharing), `today()` →
`generatorDateStamp()`, `log()` → `generatorLog()`, and `RunError.noVolumes` retires in favour of
`GeneratorError.noVolumes` which the enumerator already throws. `RunError.emptyRecordGroups` stays:
it is this generator's own refusal to write an empty record-group map.

### Tier 3 status

- **I-3** — 1 of 5 generators done. **Manifest, Taxonomy, CentralFilesIndex, SourceProvenanceIndex
  remain**, each its own PR with the same byte-verification.
- **I-1 (#268, shared `AXChartDescriptor`)** — not started. Highest payoff of the three: zero
  `AXChartDescriptor` exists while the chart population has grown to five analytics families. Its
  own gate is **owner VoiceOver validation on device**, which I cannot perform.
- **I-2 (#312, seeded-fixture obstruction test)** — not started.

---

## Session 2026-08-10 — I-1 (#268): the charts get an Audio Graph descriptor

**Issue:** #268 · **Plan:** § I-1 · **NOT CLOSED — owner device pass outstanding**

Premise re-verified before starting: **zero** occurrences of `AXChartDescriptor` or
`accessibilityChartDescriptor` in the tree, against five analytics chart families. Every chart was
one opaque element to VoiceOver.

### The tempting shortcut is the dangerous one

`ChartInspectorData` already has the shape a descriptor needs — but its cells are **already-formatted,
already-localised strings**. Reading an axis range back out means parsing `1,204` and `38%` in
whatever locale rendered them, and a lenient parse yields a *wrong* range rather than an error. On
an audio graph that failure is **inaudible**: the tones describe a shape the chart does not have.

So the builder takes numbers, and the bridge refuses **wholesale** — one unparseable cell yields no
descriptor, not a descriptor missing a third of its points, because a graph missing points still
sounds complete.

Three behaviours worth naming: an empty series yields nil (a descriptor over `0...0` is one flat
tone, which reads as data rather than absence); a constant series is widened by one (a zero-width
range makes VoiceOver's own arithmetic divide by zero); a categorical axis keeps its labels rather
than having an index forced onto it.

### Adopted at one site

`SeriesChartCard` is the shared card taking `inspector:`, so every Series chart gains a descriptor
there rather than one dashboard at a time.

### What remains — and why this is not closed

- **The owner's VoiceOver device pass**, which is #268's own gate. Nothing here is validated
  against a real screen reader; it is unit tests and a clean build only.
- **Four of the five families are not adopted**: corpus, person, cross-reference, archival. They do
  not route through `SeriesChartCard`, and several plot data with no inspector table, so each needs
  its points supplied directly to the builder.

---

## Session 2026-08-10 — the Archival Analytics design handoff, assessed and enrolled

**Issues:** #825–#835, #798 · **New:** #837, #838 · **No code — planning and tracker only**

A design handoff arrived after the #825–#835 enrolment: eleven artboards rendering the enrolled
issues as screens. It is now in the repo at
`Planning/Archival-Analytics-Revision-Design-Handoff/` (byte-identical to the delivered zip, with
a `PROVENANCE.md` saying what governs), because the issue bodies reference artboards and those
lived only in a zip outside the repo.

### The finding that mattered

The handoff is faithful to every issue's core scope. But its own opening paragraph records **"a
later owner pass"** whose five additions appear in **no issue body and in no row of §9's
enrolment table** — the two documents the handoff names as its plan of record. Sector zones, a
third ranking weight, a Cross-Reference Graph layer, the lifecycles card's removal, and a global
relabel pass. An implementer working from the tracker would have missed all five.

Verification, not reading, is what produced that: `gh issue view` on all twelve bodies against the
README, then code probes with an adversarial re-check on each. The re-check earned its keep twice
— it caught that §9's own table also disagreed with the handoff (strengthening the finding), and
it refuted a claim that a source-scan test would break on a new initializer (the pin is on the
*call site*, not the type).

### Two scope changes came out of the measurement

**#829(c), the "Unprinted pointers" weight, is not an enum case.** The join is exact (995/995
target ids present in the authority) but `ranking()` drops zeros, so the weight *replaces* the row
set — 1,014 collections out, 181 in. The class lens has no external vocabulary at all; the
availability fallback is documents-shaped; three shipped strings assert a two-weight world and one
is pinned verbatim by a test over `allCases`; the export's base caveat is a drawn-from methods
statement stamped above a pointed-at table.

**#837's node layer is contract-touching.** `CrossReferenceEdge` cannot represent a
document → archival-unit edge, node ids are `"volumeId/documentId"` parsed by splitting on `/` in
three places, loading is whole-ego-graph, and the Session 161 vocabulary has already spent
*dashed* and *orange* on other meanings. The issue splits into a phase A that touches no canvas
code (the shipped Archival Neighbors context-menu pattern reaches the same destination) and a
phase B gated on four visual decisions.

### Owner decisions recorded

All eight are in `Archival-Analytics-Adversarial-Review.md` §10, with the enrolment map. The two
gates outside the repo are unchanged and remain the critical path: #828's 1910–49 filing schedule,
and #830's repository facts — now an explicit gate on that issue, because the packet mocks turn
those facts into printed sentences a researcher acts on.

---

## Session 2026-08-10 — wave 1a: the lifecycle card goes, Cited Over Time becomes a real chart

**Issues:** #832 (b) and (c) · **PR:** the first implementation session of the archival revamp

(a), the authority-name concatenation, is deliberately **not** in this PR: it is a generator fix
whose re-clustering may ripple through three bundled artifacts that key on authority ids
(`collection-usage-index`, `external-citation-index`, `provenance-flow-index`), not the one the
issue names. That needs measuring on its own.

### The removal's real hazard was not the deletion

The lifecycle card was self-contained across three files with one mount point. What made it
dangerous is that the loop building its spans **also** fills `collectionVolumes` — the sole writer
of the named-collection lens's Volumes weight — and `records`, which supplies every ranking row's
label. Deleting the loop with the card compiles, throws nothing, and leaves the ranking quietly
empty under a weight whose alternative needs a bundled artifact that may be absent. Only the span
bookkeeping came out, and a new test asserts the per-band volume counts with the usage index
withheld, so that failure mode is now caught rather than merely avoided. `repeatedNames` survives
with one caller for the same class of reason: it is what stops Swift Charts silently *merging* two
bars that share a label.

This reverts #820 in full — its 1860 axis floor had no consumer outside the removed chart.

### (b) needed three things the issue named as one

Cited Over Time had no inspector, no export, and no Audio Graph descriptor. It could not simply
adopt `SeriesChartCard`: the chart sits in a `List` section whose header already names it, so the
card would draw a second heading beneath the first. So the pieces were composed instead, which
surfaced two costs the issue did not carry — the descriptor modifier was `private`, and now has a
`View.axChartDescriptor` entry point (also the route for the four chart families #268 has not
reached); and **no** existing `AnalyticsProvenance` factory fit, the nearest being the one (c)
deletes.

### Mutation sweep: 5 mutants, 5 killed — and two pattern-misses worth recording

M1 (drop the `collectionVolumes` increment), M2 (counting unit Volumes→Documents), M3 (drop the
base caveat), M4 (drop the descriptor), M5 (sheet moved inside the Section) all KILLED.

Two runs first reported SURVIVED and were wrong, both times because the *harness* missed rather
than the test: `-only-testing FRUSExplorerTests/ArchivalAnalyticsTests` names a **file**, while the
suite type is `ArchivalCollectionsDataTests`, so zero tests ran; and one `perl -0pi` regex silently
matched nothing, which `git status` showed as a clean tree. Both are the standing PATTERN-MISS
verdict, not evidence about the tests. Check that the mutation applied and that the intended tests
actually ran before believing a survivor.

### Docs

Both manuals lose the removed card and gain the pointer; the macOS figure-export sentence was
carrying a **second, already-false** clause (it promised figure export for Your Library, which has
always been CSV-only). `EditableContent.md` loses three blocks and gains the new export caveat, and
**38 stale `lines:` pointers** into the two shrunk files were recomputed against the source rather
than hand-edited — 0 keys unresolved, which is also a check that no block references a string that
no longer exists.

---

## Session 2026-08-10 — wave 1b (#826): one class grain, and the denominators that shipped unread

**Issue:** #826 · **Filed en route:** #841 · **PR:** the second implementation session of the revamp

### The fold's real hazard is the volumes weight

Folding subject-numeric leaves to category+number is what makes the class lens
rankable — at leaf grain half the keys carry one document. But the per-(key, volume)
tally that was correct at leaf grain **double-counts the moment leaves merge**: a volume
citing `POL 27 VIET S` and `POL 27 ARAB-ISR` is one citing volume of `POL 27`. The error
is not marginal, it is absurd — summing the pairs reports `POL 1` as cited by 101 volumes
in a band containing 64 volumes in total. The class pass therefore accumulates a **set**
of volume ids per folded key, and a test drives the exact two-leaf case.

The leaf is the pull-slip unit, so every folded row keeps its leaves under the chart.

### The denominators reproduce exactly, so they are pinned rather than trusted

`volumeNoteCounts` has been in the artifact since #763, described in its own generator
notes as the denominator every share needs, and nothing read it. Measured independently
here and by the pre-flight, #826's table reproduces to the digit: 150,764 / 59,973 /
22,737 / 18,381 / 12,609 notes, and top-12 coverage of 3.0% / **9.4%** / 43.1% / 71.3% /
46.7%. That 9.4% — the view the mode *opens* on — is now a test against the shipped
artifacts, travelling through manifest coverage, band attribution, the usage index and
the umbrella chip, which moves it to 29.2% when the umbrella is shown.

One wrinkle worth recording: **#826's own two percentage columns use different
populations.** "Lands in any named collection" includes the umbrella; "the 12 shown rows
cover" excludes it. With the umbrella hidden the 1948–1960 figure is 22.1%, not 42.2%.
The on-screen sentence picks one convention.

### The pre-flight earned its keep, twice over

It confirmed the two non-obvious decisions (the `?? key` fallback — 10 shipped keys are
unfoldable and would VANISH without it — and the distinct-volume set), and then found
**five defects in this session's own code**, four invisible from the screen. The worst was
a **tautological test**: `#expect(folded != key || key == folded)` is `A || !A`. The test
guarding the one property this issue exists to establish asserted nothing at all, and it
passed, and it would have passed forever. Replaced with a fixed-point sweep that a
mutation now kills.

Also: leaf counts rendered in documents under both weights (a bar of 36 expanding to
hundreds), leaves sorted by documents while displaying volumes, an unguarded export
caveat committing to CSV the units error the screen refuses, and a sub-1% share rendering
as "0%" above three visible bars.

### Filed rather than fixed

**#841** — two live definitions of a subject-numeric family. The artifact fold is greedy
over the hyphen (`POL 27-14 VIET` → `POL 27-14`); the live-index query's
`classLeafPatterns` includes a `POL 27-%` pattern and swallows it. The Network already
hands folded labels to that query, so the mismatch ships today; #826 only makes it
reachable from a second surface. Worth 220 documents in one band.

The handoff's own worked example for that family is wrong in two positions — recorded on
#838, whose job is the "never hard-code from the mocks" rule.

### Mutation sweep: 7 mutants, 7 killed

Volume-set → per-pair count; stop folding; drop the note accumulation; let the volumes
weight state a share; leaves report documents under both weights; unfold (against the
replaced parity test specifically); drop the shared fold from the Network.

---

## Session 2026-08-10 — Semantic Phase 2: the spike comes back as numbers

The owner carried the Studio's five raw spike stores to the Air; this session executed the
runbook's Phase 2 — validate, gate, ladder, panel — and wrote the V-0 verdict.
`tools/semantic-harvest/spike_gates.py` (new, committed, deterministic, numpy on the Air)
produced `Planning/semantic-spike/`: `V0-Spike-Verdict.md`, `spike-gates.json`,
`blind-panel.csv` + its key.

### What the numbers said

- **Gemma leads everywhere it can be measured.** Weak-positive MRR@10 0.087 / hit@10 0.226 /
  median cited-doc rank 62 of 2,197, ahead of arctic (0.076/0.211/81) at full precision, at
  the shipping int8 config, and in both eras with edges. Full-corpus run extrapolates to
  ~6.1 h — under the ride-along's 8–13 h band.
- **The gate's ceiling is the labels, not the models.** Hits are same-thread telegrams at
  rank 1–5; misses are page-anchor noise ("for portions not printed, see p. 155" resolving
  to whatever document spans p. 155). Identical noise for every model ⇒ valid comparatively,
  meaningless absolutely.
- **frus1861 has zero cross-ref edges**, so pre-1900 — the era the feature exists for — has
  no weak-positive evidence at all. The 34 pre-1900 rows of the blind panel are the only
  gate that era gets. The design doc assumed `cross_references` was era-stratified; pre-1945
  it is not.
- **int8 is free, the Hamming→rerank pipeline is sound, the Matryoshka cut is the entire
  cost**: 768→256 loses 23% of gemma's exact top-10 (512 recovers to 12% at double the
  Tier-2 bytes; 128 is refuted). The design's "≥95% recall [U]" survives against the 256-d
  truth, not against full-dim.
- **The no-Q4 rule got its measurement** from the accidental store pair: Q4_K_M vs Q8_0
  nomic agree on 82% of rank-1 neighbors — one in five top results silently differ.

### Decisions taken, and the two that wait

Store validation passed everywhere (gzip-mtime explains the differing text-layer checksums;
decompressed layers are byte-identical across all five stores). The pooling rule is pinned
in the output JSON. The Aug-3 index build supplied the edges — owner flagged the app copy
as stale; acceptable for a comparative gate, disclosed in the verdict. What waits is the
owner: key the 100-row panel blind (the key file unblinds — open it after), and read the
Gemma licence, which binds only V-5 weight-bundling. Then Phase 3 is one overnight
`caffeinate` run with `MODEL_FILE` set — the one provenance gap the spike left.

---

## Session 2026-08-11 — wave 1c (#825 a, c, d): the dead ends close

**Issue:** #825 (a, c, d — b/e/f follow separately) · **PR:** the third implementation session

### What the pre-flight measured that changes the design

The "Show all N units" table is **not** a 40-row list. Measured over the shipped artifacts, the
largest cell is **5,881 rows** (Through 1947 · file numbers, either weight); the widest collections
cell is 1,491. It is also the thinnest evidence in the corpus — 3,667 of those 5,881 rows are cited
by exactly one volume. A `List` handles it lazily, but the number is why the sheet is a list rather
than an inspector table, and why it states its own count in the header.

### Three seams worth naming

**The hit test cannot live in the chart body.** That body is also what the figure exporter
rasterises, so `.chartOverlay` inside it would bake a dead hit-test region into a PNG. It lives on
a separate wrapper, pinned by a test to exactly one call site.

**The uncapped list must draw `label`, not `name`.** `disambiguate` appends the repository to names
carried by more than one authority record. Drawn as `name`, one band prints `White House Central
Files` **six times** — six identical rows, each opening a different collection. The chart never had
this problem because it has always drawn `label`; the new list quietly did not.

**A dismiss and a present in one state change drops the present.** Opening a collection from the
all-units sheet sets `showsAllUnits = false` and then the detail target; done in the same update the
detail never appears. The hand-off hops to the next update.

### The uncapped export needed its own sentence

The capped CSV's denominator caveat blames the shortfall partly on "a unit below the row cap". In
the uncapped table there are no rows below a cap, so the same sentence is a false claim about a
population that does not exist there. `rowCapApplied` branches it.

### A dead end that predates the surface

#825(d)'s "Cited Across the Series" rows were **never** navigable — `git show d7c53185` has the same
inert `ForEach` from the section's first commit — while the sibling list in `VolumeSourcesView`,
showing the same volumes for the same collection, has been navigable since the UI audit that
recorded "the rows used to be dead ends". The issue calls it an adjacent regression; it is a
restoration relative to a sibling, and the correction is on the issue.

### Mutation sweep: 3 mutants, 3 killed

Keep the cap in the all-units sheet; make the citing rows inert again; leak the interactive chart
into the figure export.

---

## Session 2026-08-11 — wave 1d (#825 b, e) + four gaps the pre-flight found in wave 1c

**Issue:** #825 (b, e — (f) sector zones still to come) · **PR:** the fourth implementation session

### (b) and (e)

**Open Collection** joins the Network dock and the Flows card. Both surfaces already *resolved* an
`AuthorityCollectionRecord` to offer Archival Neighbors and simply never offered the record. The
distinction matters most for a reader with few volumes indexed: Neighbors reads the **local** index
and answers honestly-empty, so without this the dock had no route at all to what the app knows
corpus-wide.

**The surface is addressable.** `ArchivalAnalyticsView(mode:focusCollectionId:)`, every parameter
defaulted so the two bare call sites (one pinned by a source scan) keep compiling. Scope parameters
are deliberately **not** in the signature yet: #827 adds volume scoping, and a parameter no caller
can act on is an empty promise. The Network seeds its focus **once**, guarded, because that view
re-appears every time the mode picker returns to it and re-seeding would discard the reader's own
choice.

### The pre-flight's four findings against wave 1c — one was a crash

1. **`CollectionDetailView` declares a NON-optional `@Environment(AppState.self)`, which traps on
   DECLARATION.** The analytics surface holds AppState *optionally* by design — its whole defensive
   pattern is to degrade to an empty state — so presenting the detail unguarded crashed exactly the
   configuration the optional exists for. Now withheld, and a row will not even set a target it
   cannot present.
2. **The chart tap had no hint and no accessible equivalent.** A `chartOverlay` tap is not an
   accessibility element. Two other charts in this app pair the same overlay with a hint; this one
   now does, and names the uncapped list as the route that works without tapping.
3. **A folded class row opens a document set drawn from a WIDER family than its bar** — the SQL
   prefix match sweeps sub-numbers the artifact fold assigns elsewhere (#841). Measured by the
   pre-flight: 38 of 102 drawn class rows, `POL 15` sweeping 73 keys. Until #841 is settled the
   screen says so.
4. **On iOS the analytics surface is itself a sheet**, so #825(d)'s hand-off to the Browse tab
   landed *underneath* it and nothing appeared to happen. `CollectionDetailView` gained an
   `onNavigateAway` hook, because only the host knows it is presented.

Also confirmed by the pre-flight and worth recording: **0 of 1,828 usage collection ids are absent
from the shipped authority**, so no drawn collection row currently lacks a record — the nil path is
correctness insurance rather than a live case — and the umbrella is a normal record that opens.

### Mutation sweep: 2 mutants, 2 killed

Drop Open Collection from the Flows card; re-seed the Network focus on every appearance.

---

## Session 2026-08-11 — wave 1e (#838): plain labels, one method statement, and a copy rule with teeth

**Issue:** #838 · **PR:** the fifth implementation session — wave 1 complete

### The relabel

`Units → Show`, `Weight → Count by`, `Coverage era → Era`. The rule that makes this more than a
rename: the plain word goes on the **control**, and the term of art it replaces moves into the
popover text, so a reader who knows "weight" still finds that word where the method is explained.

It also surfaced a latent **localized-key collision**: `archival.filter.era` was used both as the
chip's caption and as a chart axis name in Your Library, with two different default values. One key
carrying two defaults means translating either silently rewrites the other. The axis now has its
own key.

### The ⓘ consolidation, and what deliberately stayed

The standing method statement moved into **About These Figures**. The **conditional** disclosures
did not: what the Central Files filter withheld *in this era*, and whether an artifact failed to
load, describe the chart on screen right now and change with the controls. A caveat that changes
with the controls has to be where the controls are, and a reader who never opens a popover must
still be told the largest bar is missing.

### The copy rules are a test, not a convention

The handoff's four conventions — ●/○ marks, issue numbers, artboard ids, British spellings — each
appear in copy the handoff itself calls final, and three of the four read as ordinary prose to a
reviewer who has not seen the mocks. So "remember not to" is not a control. `ArchivalCopyRulesTests`
scans the shipped `defaultValue:` literals (not the doc comments, which are exactly where that
vocabulary *should* live) and fails on the commit that introduces a violation.

**It immediately found five in pre-existing copy**: `coloured` in the ranking caption, `recognise`
/ `recognises` three times in Your Library, and `centre` in the Network's ring legend. None came
from this handoff; they had simply never been checked.

### Mutation sweep: 3 mutants, 3 killed

A ● in a shipped string; an issue number in a caption; the method statement altered rather than
moved.

---

## Session 2026-08-11 — #841: one definition of a subject-numeric family

**Issue:** #841 · owner's decision: **option (a)** — the fold is the definition, the query follows it.

Two definitions were live at once. `CollectionKeying.subjectNumericGroup` is greedy over the
hyphenated number, so `POL 27-14 VIET` belongs to `POL 27-14`; `classLeafPatterns` carried a
`key + "-%"` branch, so the SQL family for `POL 27` swallowed it. A row labelled 1,090 documents
opened a document set drawn from a strictly wider population — **38 of the 102 class rows the
ranking draws**, `POL 15` sweeping 73 keys, `POL 27-14` alone worth 220 documents in one band.

The hyphen branch is now **decimal-only**. A decimal key is not folded, so no second definition
exists to disagree with, and the corpus writes `611.51-A` subdivisions a reader asking for `611.51`
means to include.

### The residue is bounded, not excused

The fold's regex needs two-to-six category letters, so the ten single-letter `E …` keys cannot be
parsed and each becomes its own group. Two are prefixes of others, and the space branch — the one
that finds `POL 27 VIET S` under `POL 27` — still crosses them: `E 1` reaches `E 1 JAPAN-US` and
`E 1 US`. **Exactly those two**, pinned as an exact set, so a new leak from a change to either
definition fails a test rather than going unnoticed. Down from 38 rows to 2 keys.

### A stale caveat is worse than none

Wave 1d added a screen sentence warning that a grouped row's documents include its sub-numbers.
That is now false, so it is gone — and the test that demanded it now demands its **absence**, with
the reason. A caveat that outlives its defect tells a reader the number in front of them is wrong
when it is right.

### Mutation sweep: 2 mutants, 2 killed

Restore the hyphen branch for subject-numeric keys (the original defect); drop it for decimal keys
too (the over-correction). Pinning both directions matters here because the fix is a narrowing, and
narrowing too far is as wrong as not narrowing at all.

---

## Session 2026-08-11 — wave 2a (#827): the Collections mode gets a scope

**Issue:** #827 · the "value session" of the review's sequencing

### The seam was already there

`ArchivalCollectionsData.make(authority:usage:coverage:)` is a pure function of its three inputs,
and the **coverage map is the volume set**. So scoping is a filter on one input rather than a new
code path — which is exactly what makes the ranking, the per-band denominator, the caption's volume
count, the units-reached figure and the CSV all narrow *together*. None of them can be scoped
separately, so none can be left describing the wider population.

### The decision that matters: scope over the series, not the library

Every other analytics surface passes `appState.indexedVolumeIds` to `AnalyticsScopeBar`, because
those surfaces read the local index and can only describe what is downloaded. This mode's
derivation is the bundled corpus-wide authority and usage index — it is honest about all 552 volumes
with **none** of them downloaded. Passing the library here would silently answer a different
question for every reader: "the collections of the 1969–76 subseries" would mean whichever eleven
of its volumes they happen to hold.

So the surface passes a manifest-derived `scopableVolumeIds`, and the export says so in as many
words: *the same scope gives the same figures on any device*. This is the handoff's "do not
intersect with the local index" rule, which appears in no issue body.

### The issue's own component assumption did not survive contact

#827 names `AdministrationPresetMenu` as the administration control. That component binds a **year
range**, and its doc comment restricts it to coverage-year surfaces — it cannot produce a volume
set, and wiring it here would have put a second date axis beside the era bands for them to disagree
over. The bundled administration profiles carry their own **per-volume** breakdown, so an
administration is taken as a volume set directly. Same feature, right primitive.

### Mutation sweep: 3 mutants, 3 killed

Scope the library instead of the series; ignore the scope when building coverage; drop the scope
from the export.

## Session 2026-08-11 — #833: the topic door (subject- and search-scoped archival profiles)

Two doors into Archival Analytics' volume scope, from the questions a reader is already asking:
the search facet panel's archival-provenance section (scope = the volumes the matches sit in) and
the subject sheet reached from a volume's **Top subjects** chips (scope = every volume whose
profile carries that subject). Both travel as an `ArchivalScopeRequest` on the scene-addressed
`pendingArchivalScope` hand-off — macOS to the singleton window, iOS to the producing scene.

### The surface had no presenter outside one tab

Before this, the only iOS presenter of `ArchivalAnalyticsView` was a private `@State` bool inside
`BrowserView`. The search door could therefore switch to the Browse tab and *nothing would open* —
a door with nothing behind it, and no data-layer test could see it, because the whole defect is in
which view owns the presentation. `MainTabView` is now the single iOS presenter (the shape the word
cloud has used since #752), Browse's own menu row produces `ArchivalScopeRequest.unscoped` through
the same hand-off, and the view gained `init(initialScope:)` because the shell must consume the
hand-off in order to decide whether to present at all.

Two presenters remain in play on iOS — the shell and an already-mounted sheet — and the
arrangement is deterministic because the shell **declines** while a sheet is up: a scope arriving
then stays in the slot for the mounted view to adopt and re-scope in place. The mounted view always
wins, whichever `onChange` the runtime runs first.

### #827 shipped a scope that changed nothing, and this session's fix for it shipped a wedge

The scope bar changed the chip and left the chart alone: `.task` was unkeyed, `loadCollections`
early-returns while `collectionsData != nil`, and `setScope` did not clear it. Keying the task on
the scope fixed that and introduced a worse failure, which the pre-flight review caught before the
PR: picking a scope **that is already active** — the checked "Whole corpus" row, the same
administration twice, the same door twice for one query — drops the derivation while leaving the
signature byte-identical, so nothing restarts the load. The chart sits on its spinner for the life
of the view, and the scope chip lives inside the `if let data` branch, so the only control that
could undo it has vanished with the data. The signature now carries a `scopeGeneration` counter and
every invalidation path goes through one `invalidateCollections()`.

The same review found a second one: `Task.detached` does not inherit cancellation and `Task.value`
does not throw, so a superseded load still resumes past its `await` and used to assign
unconditionally. The macOS window reproduces the overlap on **every** scoped open — it mounts
unscoped, starts a corpus-wide build, then consumes the hand-off — so corpus-wide figures could
land last under the scope's own name. `loadCollections` now admits its result only if the signature
it started with is still current.

### Three more from the review, each a real dead end

- The search door was gated on `facets.volumes`, which is computed only when the reader expands the
  **Volumes** section. So the door rendered only for someone who had opened a different section
  first — and Provenance, the dead-end section the door exists to open a way out of, was the one
  hiding it. Disclosing Provenance now also asks for the volume breakdown (loading a section does
  not expand it).
- A scope arriving from a door landed on the default 1948–1960 band whatever era its volumes cover,
  so a 1970s subject opened on an **empty chart under its own name** — which reads as "FRUS cites
  no archives for this topic", not "wrong decade". Arriving scopes now move the band to wherever
  their volumes are; a scope the reader picks from the bar does not, because a control that moves
  itself while in use is worse than a wrong default.
- Two doc comments were silently re-attributed by insertion: `ArchivalScopeRequest` landed inside
  `Handoff`'s, and the new `archivalSheet` helper inside the word-cloud consumer's.

### The subject door scopes to N volumes while the list above it shows N−1

`otherVolumeIds` excludes the volume being viewed, which is right for "where else can I read about
this" and wrong for the profile — dropping one volume from every profile opened from a volume page
would be an under-count no figure on the destination could reveal. The door reads
`volumesBySubjectRef` and its own count says which set it means. It is withheld below two volumes:
a one-volume "profile of volumes on this subject" is that volume's own profile under a topic's name.

### A second review, of the fixes themselves

The six repairs above were then reviewed the same way, from three lenses with two independent
refutation angles per finding. **All 21 findings against the fixes were refuted** — the repairs
hold. The completeness critic, asked what all three lenses had missed, found five things that
were not, of which four were real and are fixed here:

- The `init` doc comment still said "scope parameters are deliberately **not** here yet",
  two paragraphs above the scope parameter, and still claimed both call sites pass none.
- The door was hidden by the very section it belongs to: it sat inside the `else` of
  `if buckets.isEmpty`, so a provenance breakdown with **no rows** — no matched document carrying
  a resolvable source note — showed "Nothing to break down here." and offered no way on. That is
  precisely when the volumes' archival profile is worth most. The door's only condition is now the
  section it belongs to, and the test pins the condition rather than the position (the first
  version passed with a row-count guard bolted back on).
- Both hosts labelled the scope from a **live text-field buffer** — macOS documents `queryText`
  as exactly that — so a reader who typed a new term without committing it got the OLD result
  set's volumes under the NEW term's name. `FacetPanelController` now records the query its
  breakdown was computed against, and both doors take the label from there.
- Disclosing Provenance runs a second aggregation in the background for the volume breakdown the
  door is made of. On a broad match that is the same size as the one the reader is already waiting
  for, and the control used to materialise silently seconds later; the wait is now stated.
- The macOS subject door was the only launcher of the archival window not clearing the tool's
  provenance. Now it does, like its four siblings.

**And one defect that is not ours to fix here.** On macOS the facet panel is a long-lived
inspector, so `expanded` survives a search; `onDiscloseSection` fires only from the header toggle;
and `invalidate` clears the data. An already-open section therefore renders *completely empty* —
no rows, no caveat, no door — after any re-search, until it is collapsed and re-opened. Verified
present on `origin/v2`, affecting every section, so it is filed separately rather than widened
into this branch.

### The all-units sheet could be emptied out from under the reader

`ArchivalAllUnitsSheet` read the live derivation and owns its only Done button. Once a scope change
drops that derivation, a hand-off arriving from another window blanked the sheet — on macOS leaving
a window-modal sheet with no dismiss control. It now takes a snapshot of the whole input (data,
band, lens, weight, umbrella, label) at the moment it opens, which also makes its "same as the
chart" claim true of the chart it was opened from rather than whatever the chart became.

### Mutation sweep: 20 mutants, 20 killed

Seven over the doors (scope the displayed list; drop the one-volume guard; soften the load-bearing
footer; remove the shell's second-sheet guard; hand off in the same state change as the dismissal;
revert Browse's row to private state; never pass the payload), seven over the first round of review
fixes (the generation leaves the signature; the scope bar nils without moving the key; drop the
stale-load guard; stop asking for the volume facet; two band-move paths; re-orphan the doc
comment), and six over the second (flip the band tie-break; answer band zero for empty coverage;
stop observing the hand-off slot; revert the all-units sheet to the live derivation; re-couple the
door to the section's rows; label the scope from an empty string).

The band decision moved out of the view and into `ArchivalEraBand.bandHoldingMost(of:)` for the
sake of that sweep: the first test asserted only that the function was *called by name*, so the
plurality, the tie-break and the empty case could all have been wrong and the suite would not have
noticed. It is now tested against real coverage spans, including that every band is reachable.

## Session 2026-08-11 — #835: the collection-grain card on Archival Sourcing

§8's answer to the owner's relocation question was **relocate no, layer yes**: the *narrative*
("which collections carried each era") is series-analytics subject matter, while the query-driven
instrument stays in Analytics. This lands the narrative card, the derivation it needed, and the
cross-links #835's 8.3d asked for.

### Verifying the issue first overturned six of its premises

- **"Authority/usage decode lazily" — already true**, but on whichever thread touches them first,
  which is the actual problem. **"The page's current load is the 134 KB provenance index"** is
  misleading in the other direction: `SourceProvenanceStore` is an eagerly-constructed stored
  property on `AppState`, so this page's marginal load today is *zero* and #835 gives it its first
  appearance-time cost. That strengthens the lazy/off-main requirement rather than weakening it.
  (`SourceProvenanceStore`'s own "~4.5 KB" note, stale by 30× since #267, is corrected here.)
- **`ArchivalAnalyticsView` is the counter-example, not the model** — it read both `.shared` stores
  on the main actor *before* its detached block. Both touches now happen inside it.
- **"Honouring the year range" had no API that could.** `ranking(band:)` takes exactly one band
  and every per-band table is `private let`.
- **Merging the bands in the view would have been a silent data-loss bug.** `disambiguate` runs per
  ranking, and 279 shipped authority names are carried by more than one record: rows unique inside
  their own band collide once merged, and Swift Charts draws two bars sharing a label as one. The
  merge therefore happens inside the type, before disambiguation.
- **Cross-band summation is exact under BOTH weights** — two of the verification lenses claimed
  Volumes could not be summed. `make` writes `bandByVolume[volumeId]` exactly once, so the bands
  *partition* the corpus and a unit's citing volumes in two bands are disjoint. The double-count
  warning they were reading belongs to folding class *leaves within one band*, which is a different
  situation that looks identical. Pinned by test rather than left as a comment.
- **`CollectionDetailSheet` is not "self-contained"** — it wraps a view declaring a non-optional
  `@Environment(AppState.self)`, which traps on *declaration*. The dashboard holds AppState
  optionally by design, so every row is behind `if let appState`, the shape #844 fixed.

### What the card owes its reader, and pays

It is on a page whose charts count a **different population**: the provenance aggregate covers 522
volumes and floors at decade 1900, the archival authority covers 552 with no floor (68 volumes sit
in pre-1900 coverage decades). Its four custodian colours answer "who holds the records", not the
ten categories' "what kind of citation is this". Its eras are coarser than the charts' decades. All
three are stated on the card. The umbrella is withheld with its size named — there is no chip here
to reveal it — and the share sentence is suppressed under the volumes weight, where a share of a
note total would be a ratio of two different things.

The year range selects the era bands it **overlaps**. Containment would have dropped the first band
— 261 of 552 volumes — for any range starting after 1861.

### #798 resolved to option (a), on a measured cost

Owner decision 5 said build (a) and *report* the cost rather than force it. Measured: three files,
about six lines, and `IndexingEducationView` already owned the value. The route the issue assumed
does **not** work — `openArchivalScope` is consumed by `MainTabView`'s presenter, and on iOS this
page is itself a sheet inside that shell, so the shell would be asked to present a second sheet
while presenting. The door presents locally instead, and `ArchivalAnalyticsView` gained
`onNavigateAway` so a Browse hand-off from a collection record closes the guide too rather than
leaving it over the surface that just navigated.

"Archival Analytics" appeared **nowhere** in the 1,200-line walkthrough — not a missing sentence, a
missing section. It now has one, mirrored into `Docs/EditableContent.md`, and the tool carries a
return link to the Archival Sourcing page.

### The review found the card telling two untruths, and a guard that could not fire

- **The population sentence was false.** It said the ranking "reads the archival authority, which
  spans all 552 catalogued volumes and has no 1900 floor". Measured against the shipped artifacts:
  the authority names **356** volumes and **none** with a pre-1900 coverage midpoint. The 552-and-
  no-floor property belongs to the *usage* index, which is where the document counts come from —
  so a row genuinely can rest on a volume the charts above leave out, but not for the reason given.
  The sentence now names both artifacts and both numbers.
- **The umbrella footnote asserted a magnitude it does not have.** "One undifferentiated record
  carrying N here, which would flatten every other bar" is true for the default whole-range view
  (17,587 against 7,056) and for 1948–1960 (12,060 against 1,643). For 1969–1976 it is 47 against
  7,052 — a bar 0.7% of the tallest, described as scale-breaking. Withholding is still right in
  every band; the copy now *compares* the two figures instead of asserting dominance, and the card
  has no umbrella chip so this is the reader's only information.
- **The stale-result guard could not fire.** `guard requested == scopeSignature` is live in the
  instrument because its scope is `@State`, whose storage is shared across view-struct instances.
  On the card the scope is a plain `let`, so a superseded run re-read its own captured value and
  always matched itself — the guard was inert and a stale derivation could land last. `.task(id:)`
  cancels the previous run, so `Task.isCancelled` is the signal that is actually about the current
  view.

Also folded: the iOS escape now carries the page's scope (`initialScope:` existed for exactly this
and was unused, so the link discarded the narrowing the card above it describes); the collection
sheet gained the `onNavigateAway` hook whose absence reintroduced the #844 dead-end; the reverse
guide link is withheld when the guide is what presented the surface, or the guide becomes reachable
from inside itself one sheet deeper each time; `isOnboarding` is actually passed, so the priority
softening it exists for happens; a year range selecting no band reports a range problem instead of
blaming the scope; the row's accessibility label carries the disambiguated form, since VoiceOver
reading the bare name would announce several "White House Central Files" identically; and both
manuals' standing "every chart offers View as table" claim is qualified, because the card is a list.

**The band rule moved onto `ArchivalEraBand`.** It was briefly a static on the card, where the
parity test could not call it: a `View` is `@MainActor`-isolated in Swift 6, and the test crashed on
the actor check. It is a fact about the axis, so it lives beside `bandHoldingMost(of:)` — and is now
tested directly rather than restated inline in the test, which is what the critic caught.

### Mutation sweep: 16 mutants, 16 killed

Six over the derivation (stop deduplicating bands; overwrite instead of summing; keep the
denominators single-band; drop the umbrella disclosure; default an unparseable year instead of
skipping; treat an empty scope as the whole corpus), six over the card and links (show the door
mid-onboarding; stop forwarding the context through the iOS renderer; pin the card to one band;
open rows with no authority record; show the umbrella; key the load on the year range), and four
over the review fixes (containment instead of overlap; drop the scope from the escape; revert the
population claim; drop the recursion guard).

## Session 2026-08-11 — #828 PR 1: the decimal-class label artifact

The 1910–49 State Department classification schedule, parsed from the manuals the owner supplied,
into `decimal-class-labels.json`. The renderer pass — every surface reading one label source — is
PR 2. The manuals stay local (`SCHEDULE_DIR`), as decided; the artifact is the reproducible product.

### Compositional, and era-scoped

`761.62` is *class 7, political relations, between country 61 and country 62*, so the table stores
class glosses, country numbers and subject suffixes separately and composes at render time — the
shape #764 measured at 87.7% of classed documents against 79.4% for a thousand flat rows.

The classification was **renumbered in 1950** (class 7 is Political Relations of States before,
Internal Political and National Defense Affairs after; Iran moves 91 → 88, Turkey 67 → 82), so a
key resolves only against the schedule governing its own era. `891.00` is Iran in the 1910–49 table
and resolves to nothing in the 1950s one — the failure that era-scoping exists to prevent.

### Four things the source settled that guesswork would have got wrong

- **The relations reading belongs to class 7 alone.** Class 8 is *Internal Affairs of States* —
  one country and a subject — and its keys are shaped identically. Treating every country-arranged
  class as relations made `893.51` read "China and France" when it means China's internal affairs.
- **The 1910–49 schedule has no class 9.** Its summary runs 000–800 and "900" appears nowhere; the
  class arrives with the 1950 renumbering. A floor of ten was rejecting a complete parse.
- **Country codes are alphanumeric** — 270 of 353 carry a letter, because colonies were numbered
  off the parent (France 51, Algeria 51r).
- **65 is legitimately both Italy and Rhodes Island**, Italy having held the Dodecanese for the
  period. Shared codes resolve to the shortest name, ties alphabetical — deterministic, and it
  prefers the sovereign state over the territory filed under it.

### Three parsing strategies, two measured and rejected

- **Drop every partial row** (a row not filling all three era columns): honest but expensive —
  176 of 353 codes, 80.0% of documents.
- **Place codes by x position**: the column centres calibrate cleanly (125 / 224 / 293 from 140
  rows each), but `PDFPage.characterBounds(at:)` does not agree with `PDFPage.string`'s ordering on
  these files, so the positions cannot be trusted to belong to the tokens they are read for.
- **Read NARA's own annotations** — the rule that ships. 135 `Discontinued` rows left-align, 106
  `Beginning`/`Established` rows right-align, and an unannotated partial row is dropped and counted.

Three bugs found by rendering the top corpus keys as a reader would see them, not by tests: a
wrapped name after a code row was swallowed as note continuation (this hid the Soviet Union); a
sort read the code's length instead of the name's (so 51 was "Corsica", not "France"); and the
page headers reprint on every page, severing names from codes across breaks.

### A short, sourced corrections list

A few pages interleave columns beyond recovery — `Germany`'s name sits twenty lines above its
`62 62 62`. Five entries are supplied by curation, **each established by the source document rather
than by outside knowledge**, each carrying the quotation that establishes it. Germany's is derived
from the table's own entries under the convention NARA's hints sheet states: `West Germany 62a`,
`East Germany 62b`, so the parent is 62. The list is deliberately short and is not a place to make
a coverage number look better.

### Measured, and honest about the remainder

**67.3% of decimal class keys and 78.8% of the documents behind them.** 124 codes remain
unresolved. Where the table does not know a country it says nothing — the key renders as it does
today — because a wrong gloss on an archival citation is worse than a bare number: the reader
cannot tell it is wrong.

The 1950–59 and 1960–63 schedules are **omitted**, not shipped thin: their scans letter-space every
word and yield 4 and 8 class headings against ten. A half-named class table mislabels rather than
labels, so the generator drops an incomplete schedule and says which eras it covers.

## Session 2026-08-11 — #828 PR 2: the renderer pass

The label table reaches the screen. One injection point does the whole job: class rows are built in
exactly one place, `ArchivalCollectionsData.ranking`, so attaching the gloss there labels the
chart, the uncapped list, the CSV exports and the Archival Sourcing card at once. Attaching it in a
view instead would have left every export shipping bare numbers.

### The gloss sits beside the key, never instead of it

`793.94` still reads `793.94`, with *China and Japan* under it. The number is what a pull slip
needs; the prose is what makes the ranking legible. The chart's y-axis keeps the bare key because
that axis value is also the disambiguation key, and Swift Charts silently merges two bars sharing a
label — so the gloss goes to VoiceOver there, and under the key everywhere a second line fits.

### When the table is allowed to speak

The rule is asymmetric, and the asymmetry is the whole correctness argument.

- **Upper bound is checked.** The classification was renumbered in 1950, so a span reaching past
  1949 also covers the era where the same digits mean something else. The 1948–1960 era band is
  exactly that case and gets no labels at all.
- **Lower bound is not.** The central decimal file begins in 1910, so the first band's 1861–1909
  years contain no decimal keys to mislabel. Requiring containment at both ends silenced that band
  entirely — and that band is the one #828 exists for, since before 1948 the class lens *is* the
  named archival record.

The first version got this wrong in the safe direction and shipped nothing at all; it was caught by
rendering real keys rather than by a test.

### Measured on the shipped artifact

Over the first era band: `793.94` → China and Japan; `893.51` → China — financial conditions (NOT
"China and France": class 8 is Internal Affairs, and its suffix only looks like a country code);
`812.00` → Mexico — political affairs; `795.00` → Korea and The World, the inverted index form
un-inverted. `763.72` reads as Austria and Serbia, which is what an Austro-Serbian file from a
1910s volume should say.

### Mutation sweep: 4 mutants, 4 killed

Read class 8's suffix as a second country; stop enforcing the renumbering boundary; stop
un-inverting `World, The`; stop attaching the gloss to the rows.

## Session 2026-08-11 — #828 follow-up: four wrong glosses retired

Investigating the remaining manuals turned up something more urgent than the manuals: **the shipped
1910–49 table was confidently wrong about four country codes**, and two of them were large.

| code | shipped gloss | truth | documents |
|---|---|---|---|
| `01` | Arctic | not a 1910–49 code at all | **4,513** |
| `52` | `Africa."` | Spain | **1,761** |
| `11h` | Alaska | not a 1910–49 code | — |
| `90c` | `Azerbaijan Azores` | two rows' names merged | 8 |

`501.BB` alone — 1,628 documents — was glossed "Arctic". It is a **Class 5 United Nations key** and
names no country whatever. This is the precise failure the table's whole design is meant to make
impossible, and it was shipping.

### Two causes, both now closed

- **`Discontinued ⇒ left-align` was never sound.** `Arctic 01 Discontinued 1955. See 03.` does not
  say that 01 is a 1910–49 code; the annotation is written from the perspective of a column the
  text never names. The rule is deleted. `Beginning`/`Established` is kept, because it is
  directional in the other sense — a code that begins mid-period cannot be in the earliest column,
  so right-alignment removes possibilities rather than inventing one.
- **Note prose was reaching the name slot.** A country name is a noun phrase; names carrying a
  quote mark, ending in a full stop or comma, or running past six words are rejected.

Spain joins the curated corrections under the same rule as Germany — established by the document's
own dependants (`Adrar 52c`, `Annobon 52e`, `Alhucemas 52f`) under the parent-plus-letter
convention NARA's hints sheet states, never from outside knowledge.

### The coverage number went down and the table got better

67.3% of keys / 78.8% of documents → **63.3% / 77.1%**. The old figure counted 6,274 documents
carrying a wrong label as covered. Net *correct* coverage rose; the headline fell because it had
been flattered.

### What the analysis found for the rest, and what it costs

Measured before any of it was built:

- **The later schedules are worth less than they look.** 73.9% of decimal-class documents sit in
  the first era band, 24.4% in 1948–1960, 1.7% after. And the era bands do not align with the
  schedule boundaries — band 1 spans 1948–1960, which is three schedules — so **no band-level rule
  can label it however many schedules are parsed**. Attributing per *key* instead (all contributing
  volumes agreeing on one schedule) would unlock 6.2% for 1951–1959 and 0.3% for 1960–1963.
- **The biggest single win is in the era already covered**: the 1910–49 manual holds 646 nested
  `.NNN` continuation lines under its class-8 headings that the parser never sees, because the
  pattern demands an `8**.` prefix while the tree is written as bare `.421 Academic`. Measured lift
  **+18,750 documents**, class-8 suffix naming 55.8% → 83.7%. No new extractor needed.
- **The cultural-relations supplement should not be parsed.** 13 keys, 155 documents, and **zero**
  corpus keys use its parenthesised grammar — `SourceNoteParser` drops it upstream, so no
  downstream change could render it. Its one real subject, `.427††`, is already in the parent
  manual.
- Three traps recorded for whoever builds the later schedules: class 3 is **not** country-arranged
  (including it would mislabel 4,151 documents, the UN General Assembly among them as "South and
  Central America"); the later relations classes are 2/4/5/6, not 6 alone; and every pattern must
  be bounded to the body pages, since the back index yields 1,445 confident nonsense matches that
  clear the floors by orders of magnitude.

## Session 2026-08-11 — #828 follow-up: the class-8 subdivision tree

`812.6363` used to read "Mexico". It is the Mexican oil file — class 8, country 12, subject
`.6363 Petroleum` — and the manual states it, three levels down a branch whose class is printed
once at the top. The shipped table had the 61 stems and none of the tree.

### Why one pass could not do it, and why the second one is line-anchored

The stem pass demands a literal `8**.` on every entry, which is how the manual writes the top of a
subdivision and nothing else; beneath it the class and the country are dropped and the suffix is
printed alone (`.421 Academic.`, `.4211 Popular.`). Carrying the class forward from the last stem
is the whole of the fix, and an earlier attempt at this got it wrong in a way worth recording: it
split the text at every suffix occurrence, so each mid-entry pointer ("For apprenticeship, see
8**.605") became a fragment whose remainder was the next entry's prose, and first-writer-wins locked
it in — `8**.42` came back as "Division of Trade Agreements".

The measurement that settles it: over the class-8 body, **not one of its 755 subdivision lines is a
cross-reference, and not one cross-reference begins a line.** Anchoring at the line start removes
the failure mode rather than guarding against it. Only four lines in the body carry anything before
a suffix-shaped token; three are exactly that prose (`For armament control, United States, see
711.00111 Armament control.`) and the fourth is `]8**.77 Railway.`, an OCR bracket — which is why
one leading mark is tolerated and a leading word is not.

### Class 8 only, and that is a property of the other classes

Classes 6 and 7 are country-arranged too and neither writes a general bare suffix. Class 7's bare
children belong to the *whole numbers* heading them — `.01 Right of residence` sits under `701
Diplomatic representation`, meaning `701.01`; filed as a class-7 subject it would gloss `761.01` as
the Soviet Union's right of residence, which the manual does not say. Its genuinely general
subdivisions all carry the second-country marker (`.††11 War. Peace. Friendship.`) and are compound
keys the one-suffix lookup cannot express. Class 6's are `††`-marked throughout. Running the pass
anywhere else would invent readings, so it runs on class 8 and on the 1910–49 manual alone (blind
against the two later scans it yields 507 and 311 further suffixes — numbers that mean nothing
until someone has read what they say).

### Three parse rules, each found by reading the output rather than by a test

- **An entry the manual did not finish is not a label.** Every finished entry ends in a full stop.
  One that does not either wrapped — and a wrapped phrase resumes in LOWER CASE, where a
  sub-descriptor of the entry above starts a new capitalised sentence — or ran into the facing
  column. Joining on that test recovered five truncated entries and refused the one case where the
  next line was a second column. What is still unterminated is dropped, which is what stops
  `.541 Industrial property. ** Country in which protection`, `.542 Patents is sought. For
  treaties, conventions,`, `.543 Trade-marks. Trade names. arrangements, ect., add country number
  ††,` and `.796104 Inspection. ** Country of regulation,` from shipping. The same rule costs four
  entries the manual states perfectly well but forgot to punctuate (`.512 Taxation`, `.4511 Dress`,
  `.61345 Soya beans`, `.2222F Foreign Nationals`); their keys render bare.
- **Where bleed survives punctuation, it is cut.** `.544 Copyrights. using smaller number of
  country for **.` ends in a full stop and is still two columns. A sentence resuming in lower case
  is the second column starting, and so is a `**`/`††` followed by a capital — while `country **`
  mid-phrase, which the manual writes constantly, is followed by a lower-case word and is left
  alone.
- **A gloss must begin with a letter.** The scan splits some numbers across a space; without the
  rule, suffix `42` takes the gloss "31 Engineering" from `.42 31 Engineering` and overwrites
  Education with a fragment.

A country-scoped stem suspends inheritance: `800.88 Foreign carrying trade` has eight route termini
under it (`.8810 North America.`) that are subdivisions of country 00, The World. Inherited by the
class they would gloss `862.8810` as Germany's North America.

### The subject keeps the manual's capitalisation

Lower-casing it was right for 61 common nouns and wrong for a tree full of proper ones — it turned
`.00N` into "Haiti — nazi. nazi activities" and `.142` into "United States — red cross". Any rule
that lower-cases a first word breaks the proper-noun-initial entries, so the glosses now read as the
manual prints them. This changes the appearance of every subject label already shipping and is the
one item on the visual-review list.

### Measured, with the app's own gloss code over the real corpus

Over the Through-1947 era band — 261 volumes, 5,881 class keys, 135,432 documents:

| | keys naming their subject | documents |
|---|---|---|
| before | 878 (14.9%) | 49,551 (36.6%) |
| after | 2,069 (35.2%) | 69,851 (51.6%) |

**1,191 keys and 20,300 documents gained a named subject.** The measure is *names the subject*, not
*has a gloss*: an unresolved suffix already fell back to the country alone, so "keys glossed" is
identical before and after (69.9%) and cannot see this change at all.

Reading the largest of them is what the artifact is held to, and they are recognisable files:
`812.6363 Mexico — Petroleum` (419), `882.5048 Liberia — Slavery. Compulsory labor. Peonage` (139),
`891.51A Iran — Financial adviser` (142), `817.812 Nicaragua — Canals` (124), `837.61351 Cuba —
Cane` (217), `893.0146 China — Territory occupied by foreign military forces` (127), `867.4016
Turkey — Race problems` (89), `862.4016 Germany — Race problems` (86).

### Known and deliberate: a gloss is not unique

99 of the 693 suffixes share wording with another — `.711` and `.731` are both "Laws and
regulations", of postal and of cable service; `.2225` and `.3225` are both "Discharge", from the
army and from the navy. Qualifying them by their parent was measured and dropped: it does not
separate the largest family (the military/naval pairs differ two levels up, so the qualifier would
have to be the whole chain) and the key itself is always displayed beside the gloss.

The subject floor rose 60 → 650. Sixty is met by the stem pass alone, so a nested pass that
silently stopped matching would leave a table that still passes, still ships, and still labels
`812.6363` "Mexico".

## Session 2026-08-11 — #828 follow-up: a class label follows its own key's volumes

The label rule asked whether a schedule could speak for the **era band**. That is the wrong
question. The band is how the chart groups; the evidence a label rests on is the coverage of the
volumes citing the key.

### Why it is a prerequisite and not a refinement

Band 1 runs 1948–1960 and spans three classification schedules, so no schedule can ever govern it —
**however many are parsed**. With the band's span, shipping the 1951–59 and 1960–63 schedules would
label nothing at all: band 1's 1960 falls outside 1951–59, band 2's 1968 outside 1960–63. Every key
in the eras those schedules exist for would still render bare. Item 3 of the #828 follow-ups is
unreachable without this one.

### Measured on the shipped artifact, which carries 1910–49 alone

- **Band 0: unchanged, key for key.** The one band-0 volume whose coverage runs past 1949
  (`frus1945-50Intel`, 1945–1950) contributes no class keys at all, so nothing is withdrawn.
- **Band 1: +310 keys, +966 documents** — `862.00 Germany — Political affairs` (67 documents, cited
  only by volumes covering 1948–1949), `893.001 China — Chief executive. Sovereign` (56),
  `818.00 Costa Rica — Political affairs` (55).
- Bands 2–4: nothing, until their schedules are parsed. That is the guard, not a gap.
- **A merged-band selection goes from labelling nothing to 67,213 documents.** The union of two
  bands' years is covered by no schedule, so `ranking(bands:)` silenced every key in a multi-band
  scope including the ones whose volumes never leave the 1910–49 file. No class-lens surface merges
  bands today — #835's card is on the collections lens — so this is latent rather than visible, and
  it is stated as latent.

966 documents is a small number and the PR says so. The change is worth making for the two reasons
above: it asks the right question, and it is the only route to the later schedules.

### The span is a union, and it can only take a label away

A key cited by volumes running 1930–1940 and 1955–1960 yields 1930…1960, which no schedule governs,
so it stays bare — the same conservatism the band rule had, applied to the population it is about.
A key with no recorded span gets no gloss rather than falling back to the band's, because a
fallback would quietly restore the old rule for exactly the rows whose evidence is missing.

### The drift guard got stronger, not weaker

`rankingCarriesTheGloss` was a source scan for three literal substrings, two of which this change
invalidated. It now drives the real derivation over the bundled usage index and manifest — asserting
the row carries both the key and `Mexico — Petroleum` — and then enumerates every app source file
touching `DecimalClassLabelStore`, requiring the list to be exactly `ArchivalCollectionsData.swift`.
That is the claim "one label source" was always making, and the scan could not check it.

### The mutation sweep found a trap the next PR would have armed

Narrowing the union's *upper* bound was killed; ignoring its **lower** bound survived, because
`governs(_:)` only ever read the upper one. That asymmetry was deliberate and correct while the
span was a band's — the decimal file begins in 1910 and the first band opens in 1861, so requiring
containment at both ends silenced the whole first band. Under per-key attribution the span is
evidence, and dropping half of it is a latent mislabel: a key cited by volumes covering 1945–1955
has its upper bound inside 1951–59, so the moment that schedule ships it would be read against a
table governing half its documents.

`governs(_:floor:)` now tests containment at both ends on a span **clamped at the earliest year any
schedule covers**, which says what the asymmetry was reaching for instead of dropping the bound and
hoping. A span ending before that floor still resolves to nothing, or the clamp would lift it into
the first schedule. Every corpus figure above is unchanged; a decoded two-schedule table pins the
straddling case, because the defect arrives with data rather than with code and nothing else in the
suite would see it.

---

## Session 2026-08-11 — #234 R-1: a runbook for the NER harvest, and the harness under it

The corpus is the one the #234 comments describe: the **268 volumes with no editor person list**
(267 by the TEI rule), **199,246 documents — 62.9% of the corpus**, carrying **253,919
`<persName>` elements and zero identity links**. `tools/semantic-harvest/NER-RUNBOOK.md` is the
runbook; `harvest_ner.py` is the harness it drives, verified by `SELFTEST=1 python3 harvest_ner.py`
(23 checks, no corpus and no LM Studio needed — the discipline `harvest_embeddings.py` was handed
over under).

### The pass splits into a free layer and a priced one

The **marked layer** — the 253,919 editor-delimited names, placed in the R-0 text layer's
coordinate space — needs no model, no server, and no LM Studio window. It is M1b's input and it
falls out of a disk read. The **detected layer** is the LLM candidate pass, and it is sampled.

That split is what makes R-1 startable now. The ride-along's stage table had R-1 depending on both
R-0 and M2a; measured against the harness, the free half depends on neither.

### Why no full sweep is scheduled, with the arithmetic in the runbook

705 M chars ≈ 176 M tokens, ~230–260 k chunks, a ~191-token system prompt re-sent per chunk ⇒
~240 M tokens through the model ⇒ **~5–8 days continuous** at the ride-along's 350–600 tok/s
convention. That is the adversarial-review tier's cost, not the overnight band, and it would be
spent before any ground truth exists to say whether the output is worth having. NLTagger over the
same scope is ~1–2 h. So the harness **refuses** an unsampled full-scope LLM run unless
`FULL_SWEEP=1` is set deliberately, and the runbook's pilot is M1a's twelve volumes × 40 documents
— well under an hour, and the same documents for every model compared.

### Three properties the harness has because the repo has been burned before

- **R-0 parity is asserted, not assumed.** `harvest_ner.py` imports `harvest_embeddings.py` rather
  than copying its extractor, and every volume checks its own `(doc_id, ordinal, text)` list against
  `extract_documents`. A disagreement aborts instead of writing offsets that mean something slightly
  different from the embeddings' text. `harvest_embeddings.py` is not edited — its SHA is pinned in
  the provenance of a store that already exists.
- **Detector output is grounded by exact substring search.** A name the model normalises, expands,
  or invents is counted `unlocated` and stored nowhere; offsets asked of a model would be fiction.
  The self-test pins this with a fixture name that appears nowhere in the text.
- **gzip is written with `mtime=0`**, so re-running over the same input is byte-identical — the V-0
  spike found gzip mtime to be the only difference between five otherwise-identical text layers.

### What the runbook refuses to route around

M2a — the exhaustive prose ground truth — is un-keyed, and so are M1a's 300 rows. Every number the
harvest prints is descriptive (how much was found, how grounded it was); none is evaluative. The
runbook says so in §0 and again in §5, along with the two things that are simply not built: the
NLTagger control (needs a Swift harness, and without it a pilot cannot show a model beat the free
option) and R-2, which waits on the embeddings store that Phase 3 has not yet produced.

### Revised the same day: embeddings Phase 3 is done, and the model band is the lever

Two corrections from the owner, both of which change the runbook rather than the harness's shape.

**Phase 3 has run**, so the R-0 text layer exists for all 552 volumes. The sequencing warning above
is void — there is no window to share — and the harness gains `TEXT_DIR`, which checks every
volume's extracted text against that stored layer character for character. The parity assert
against `extract_documents` catches a divergence in the *code*; this catches one in the *corpus*,
which is the failure that would actually happen: R-2 embeds a context window around each mention
against chunk vectors computed from the stored text, so a TEI copy that moved since Phase 3 would
give offsets addressing a document those vectors never saw, and nothing downstream could tell. A
mismatch aborts naming the first differing ordinal; a missing file aborts too, because the value of
the check is that it ran. Three self-test cases cover it (26 checks now, all passing).

**Smaller models on the M5 Air change the tier but not the order of work.** The token count is a
property of the corpus, not the hardware: ~240 M, of which 94% is prefill. Prefill cost is roughly
linear in parameters, so scaled from the ride-along's 8B anchor, the full sweep runs ~4.6–7.9 days
at 7–8 B, **25–42 h at 1.5–2 B, and 8–15 h at 0.5–0.6 B** on the Studio, with the Air at 1.0–2.0×
depending on whether llama.cpp drives the M5's neural accelerators — unmeasured, and the reason the
runbook labels every cell derived. Prefill-dominance is the Air's best case, since its real deficit
is memory bandwidth and this workload barely decodes; its fanless throttle is the argument for
several resumable evening runs rather than one long one.

So a ≤2 B sweep is schedulable where the 8B one never was. The runbook's §4.2 says what that costs:
quality is the entire reason to prefer an LLM over `NLTagger`, quality is what degrades as the model
shrinks, and the price gap narrows from 60–100× to roughly 5–20× — **a small model that merely ties
NLTagger has no reason to exist**, and nothing can say which it is, because the control is still
unbuilt. The recommendation therefore sharpens rather than relaxes: build the Swift control harness
before spending an Air-night on a small-model sweep.

---

## Session 2026-08-11 — #234 R-1: the control detector, and the M2a loop that makes it mean something

N-0 and N-1 are run (owner). This session builds the two things the runbook named as unbuilt and
gating: the **free control detector** and the **M2a ground-truth loop**, plus the scorer that joins
them.

### The control: `EarlyEraNERControl` (SPM-only, Core + executable + Tests)

Apple's `NLTagger` over the same no-list scope, writing the same `detected/` layer, so
`score_detections.py` scores it beside an LLM store with no adapter. It exists to make one
comparison possible: §4.2 of the runbook prices NLTagger at ~1–2 h against ~5–8 days for an
8B-class model and 8–42 h for a 0.5–2 B one, so the cheaper the hosted model gets, the more the
question stops being *is it good* and becomes *does it beat the free option* — and until now
nothing could answer it.

- **It reads the R-0 text layer, not the TEI**, so its offsets are the marked layer's by
  construction rather than by agreement, and it needs no XML parser.
- **The offset unit is the Unicode code point.** Every other producer here is Python. Swift offers
  three plausible answers and all three agree on ASCII, which is exactly what would make the bug
  invisible — so the arithmetic is a separately tested function pinned against a decomposed accent
  (grapheme offsets land one short) and an astral character (UTF-16 lands one long).
- The tagger walk is deliberately `WordCloudKit`'s own, so "the control" means the recogniser the
  app already ships. `NLTagger`'s output is a property of the OS build, so every head and the run
  manifest record it.

### M2a: annotation by editing text, not by typing offsets

`stage_m2a.py` writes each sampled document as its exact R-0 text with the editors' `<persName>`
mentions already wrapped in `⟦…⟧`; the owner wraps the rest; `COLLECT=1` strips the brackets and
**requires the result to equal the R-0 text character for character**. Offsets are therefore derived,
never typed, and land in the same coordinate space as the detectors and the chunk vectors.

`score_detections.py` reports strict and relaxed (maximum-cardinality, not greedy) P/R/F1 per band,
plus **the editors' own markup scored as a detector** — the number that says what detection is for.

### The review found what a compiler could not

Four adversarial reviewers ran over code that cannot be compiled in this environment. The Swift
reads clean (one construct pre-emptively rewritten), but the behavioural findings were real and are
fixed: the scorer never verified the **ground truth itself** against the R-0 text (a stale gold file
scores a perfect detector as a total strict failure, with no error anywhere); a resumed control run
overwrote its manifest with partial totals; `DOCS` was not the number of documents staged; and a
mutation pass over the self-test found **16 of 23 mutants surviving** — including swapping
precision's and recall's denominators, and staging every document with none of its seeds.

The one worth naming on its own: **a `y` on an untouched file** collected the editors' seed as
ground truth and printed "measured markup share: 100.0% — this is the real measurement". The staged
bytes are now hashed into the manifest and an unchanged file is refused; `none` is how you say
"read it, nothing to add". Both suites now run 26 and 27 checks, no corpus and no server needed.

## Session 2026-08-12 — #863 follow-up 1: the suite goes green

`swift test` was red on `v2` from the moment #863 merged: 1,033 tests, one failure.

`writesRowShape` expected the detected row to end `,"ci":0}`. `NERStoreIO.writeDetected` omits
`ci` deliberately and argues the case in its own comment — a windowed LLM pass has a chunk index to
name, this detector does not chunk, and "writing a constant 0 would fabricate a field a reader could
believe." The writer is right; the test was written from the wrong side of the contract.

The two producers genuinely differ here, and that is the whole content of the fix. `harvest_ner.py`
closes its detected row with `"ci": chunk_index` (line 548); the control closes at `n`. So the
expectation is corrected **and** the absence is asserted in its own right, because a `hasPrefix`
match cannot distinguish a missing field from a reordered one — which is precisely how a test
expecting `,"ci":0}` shipped green-looking and went in red.

Mutation-checked: making the writer emit `,"ci":0` fails the test with two issues (the prefix and
the new assertion). Full SPM suite back to 1,033 passing.

Nothing else is touched. The nine silent-success findings from the same review are a separate pass —
they share a theme and want one set of tests, and this one had to be able to land on its own.

## Session 2026-08-12 — #863 follow-up 2: a run that fails must not report success

Nine findings from the #863 review, and they are one theme. Each sits beside a comment already
arguing for the guard that is missing twenty lines away.

### The Swift control

- **`TEXT_DIR` is validated up front, like `STORE`.** The comment above the `STORE` guard explains
  exactly why it exists — "the run would finish clean and report 100% of its detections as novel" —
  and `TEXT_DIR` had no such check while being the likelier typo: the path ends in `text/`, so
  dropping that component leaves a directory that exists. Every volume then threw, was filed as
  missing, and the run wrote a manifest of zeroes and exited 0. The `totalOverlap == 0` warning
  could not fire either, being guarded on `totalMentions > 0`.
- **Resume compares scope, not file existence.** A head written by an `ONLY_DOCUMENTS` pass is
  indistinguishable from a full one at that grain, so the runbook's own fast path poisoned the
  store for the sweep that follows it: the full run skipped those volumes and the manifest folded
  three documents into what it called a complete pass. The rule is asymmetric and that is the whole
  of it — a full pass covers any sample, a sampled pass covers only the documents it names.
- **The manifest labels its two scopes.** `totals` is re-derived store-wide (deliberately, so a
  resumed run does not shrink a complete manifest) while `volumes_requested` describes the command
  just typed. Re-running one volume of a finished 268-volume store left `volumes_requested: 1`
  beside totals for all 268. `volumes_in_store` now states the other denominator, and
  `volumes_reused` / `volumes_rescanned` say what this invocation actually did.
- **Spans are trimmed of whitespace before the offsets are taken.** `WordCloudTokenizer` trims the
  same ranges but only to normalise a string for counting — it produces no offsets, so its trim
  could not protect this one. The error is invisible by construction: an untrimmed span still
  slices back to its own surface, so neither `spanMismatch` nor the scorer's span check fires, and
  it would surface only as a zeroed strict-precision column read as a weakness in the recogniser.

### The Python loop

- **A volume the detector produced nothing for is refused by name.** Returning an empty set read as
  "it scanned zero of these documents" and dropped them from both sides of the ratio, so a detector
  that died on a volume scored identically to one that swept the sample.
- **The baseline reports its refusals.** They were discarded at the call site (`, _`, then a literal
  `[]`), and the editor-markup row is the number the whole detector-versus-free-layer question is
  decided against.
- **`volume_text` shares the layer reader's both-present refusal.** It had its own resolver that
  silently preferred the `.gz` — in the one directory the Swift control also reads, and which
  prefers the plain file. That is the exact disagreement `layer_path`'s comment describes.
- **A span mismatch no longer aborts mid-staging.** It is counted, and fatal *after* progress.csv,
  the instructions and the manifest exist — so the failure is loud and the directory is coherent
  rather than a half-written one that re-stages over its own orphans.
- **`_raises` narrows to `SystemExit`.** Catching `BaseException` meant a guard test passed when the
  code raised `NameError`. This was not hypothetical: writing the new both-present check, a wrong
  module name raised `NameError` inside `_raises` — under the old version it would have printed
  `ok`.

Four checks added to the M2a round trip (30, was 27) and eight Swift tests. Both suites green: SPM
1,041 tests in 119 suites; selftest 30/30.

Docs: `CLAUDE.md` said the round trip was 17 checks and the runbook said 27 in one place and 17 in
another — all three now say 30, while the two "26 checks" lines are left alone because they describe
`selftest_harvest_ner.py`, a different suite, and it does have 26. The §8 store contract had a
clause duplicated verbatim; one copy removed.

## Session 2026-08-12 — Phase-3 harvest assessed: the store is valid, and the gates now run at corpus scale

The full-corpus embedding harvest (2026-08-10, gemma, 552 volumes / 314,483 docs / 605,643
chunks) validated end to end and assessed for proceeding. Full verdict:
`Planning/semantic-spike/Phase3-Store-Assessment.md`; machine copy `corpus-gates.json`
beside it; analysis scripts `tools/semantic-harvest/corpus-gates/` (numpy, seeded, pinned
to `spike_gates.py`'s procedures).

- **Store: sound.** 2,208/2,208 checksums; every count reconciles to the digit at every
  grain; one continuous run; contract matches what Phase 2 gated (prefix trailing space
  included); the V-0 provenance gap (GGUF SHA) closed. Script drift vs the repo copy is
  the two #811 fail-fast guards only — the run used the pre-#811 `~/semantic-harvest`
  copy, and both guarded failures demonstrably did not occur.
- **Every planning-number discrepancy reconciled exactly**: 1.374B vs 1.333B chars is the
  truncate-at-next-div rule (40.9M chars of index bleed, reproduced to the digit both
  ways); 605,643 vs ~475k chunks is per-document chunking (66.3% of docs are
  single-chunk; realized mean chunk ~584 tokens, not 800); wall clock −2.3% vs the
  extrapolation.
- **Gate A at corpus scale**: 70,469 queries / 118,099 pairs against all 314,482
  candidates — int8-256 median rank 36 (top 0.011% of the pool; the spike could only say
  top 3.05% of 2,197), hit@10 0.365. First cross-volume evidence: 15,006 queries,
  hit@10 0.187. Weakest band is 1900–1945 (0.216), not pre-1900 — but pre-1900 has 572
  queries total, so the un-keyed blind panel is still the only real pre-1900 gate.
- **The deferred same-volume question**: the spike's 100% same-volume top-1 relaxes to
  78% at corpus scale — but 97% of top-10 slots are same-era. The space is
  era-stratified; a cross-era discovery surface must be an explicit projection, not a
  nearest-neighbor hope.
- **The §10.4 dims decision is fully priced**: corpus-scale recall@10 0.749 (int8-256)
  vs 0.864 (int8-512); the Hamming funnel's tax is a parameter — widening RERANK_POOL
  200→800 recovers 512's funnel recall 0.816→0.851 at ~0.4M MACs/query. P≥800 should
  ship regardless of dims.
- **New V-3 requirement found by reading the top pairs**: 27 of the 30 highest-cosine
  neighbor pairs are cross-volume *edition twins* (Iran/IranEd2, e15p2/Ed2 — same docId,
  cosine 1.0). Neighbor surfaces must suppress edition pairs, a cheap volume-pair rule.
- **The packer's id contract, measured**: store ids are a strict subset of
  `document_cache` (join on `(volume_id, d)`); the 2,356 vector-less app rows are all
  structural (`ch*`/front-matter/`comp*`) and must render typed-unavailable; 949
  letter-suffixed idExceptions (0.302%, as designed); 0 collisions, 0 tiling violations.

Next: V-1's `SemanticVectorsGenerator` packer (the only unbuilt Claude-side piece before
V-2), the Tier-0 UMAP stage (gates V-4 only), and the two standing owner acts — key the
blind panel (gates V-3), read the Gemma licence (gates V-5).

**Owner decision, same day — the blind panel is retired as a gate.** The axis ships
**experimental, opt-in at weight 0.0, and unscoped**; app-tester feedback replaces the
100-row panel as the quality instrument, on the reasoning that a cohort of researchers
working their own questions judges the feature better than one annotator. Recorded in
`Phase3-Store-Assessment.md` §0a, with the superseded notes written into
`V0-Spike-Verdict.md` §5 and the design doc's §8. The trade in one line: the opt-in
default is what makes shipping-before-measuring survivable, and **pre-1900 quality is now
a declared unknown rather than a measured pass** — Gate A reaches only 572 pre-1900
queries, so nothing automatic speaks for the era the feature most exists for. V-3
therefore owes an experimental label in the UI and a tester-feedback path that names the
19th-century question; the panel artifacts stay staged and un-keyed as the cheap fallback.

## Session 2026-08-12 — V-1: the packer, and the keying rule that was wrong

`SemanticVectorsGenerator` (SPM: `SemanticVectorsGeneratorCore` + executable + 36 tests) turns the
validated raw store into shippable tiers. Stage 1 is the owner-run neural harvest — non-reproducible
and pinned by provenance; this is the deterministic half, and a repack is byte-identical across all
three artifact kinds and all 552 shards.

Artifacts: `semantic-vectors-index.json` (73KB, bundled) + `semantic-vectors-binary.bin` (10.23MB,
bundled — 314,483 sign-bit rows then 659 volume/subseries centroids) + 552 gitignored
`Planning/semantic-vectors/shards/<volume>.vec` (79MB, ~148KB/volume, the download tier) +
a committed `shards-manifest.json` carrying per-shard SHA-256 and the provenance pin.

- **The design's implicit keying is refuted, and the refutation is the session's main finding.**
  §4.1 proposed `d{ordinal+1}` plus a ~949-row exception table for the letter-suffixed ids. Measured:
  that mis-keys **15,097 documents (4.8%)**. The 949 is real but it is a count of odd *ids*, not of
  wrong *keys* — one suffixed id (`frus1865p1`'s `d373a`) shifts every document behind it, so a
  single exception mis-keys a whole tail. A running-counter variant fails outright in 23 of 552
  volumes. **A wrong key here never fails**: every vector resolves, every score is plausible, and the
  neighbours shown belong to other documents. Identity is therefore stored, run-length encoded —
  1,605 segments for all 314,483 ids (~14KB) — and the generator round-trips every volume before
  writing and throws on a mismatch.
- **Parity with the measured pipeline is measured, not asserted.** Against the numpy matrices every
  published recall number came from: sign bits bit-identical for all 314,483 documents; **11** of
  80,507,648 int8 components differ by exactly ±1; scales differ ~3e-7 relative. The number that
  matters: **shipping-config top-10 neighbour lists identical on 6,000 of 6,000 slots** over 600 gate
  queries, rank-1 600/600.
- **The first explanation of that residual was wrong, and the review caught it.** This entry
  originally blamed a chunk-normalisation width difference (float32 vs Double). There is none — the
  reference `pool_docs.py` normalises chunks in float64, exactly as the Swift does, and
  `spike_gates.py` does not normalise chunks at all, so pooling contributes nothing. The cause is
  `truncate`'s norm: numpy sums **pairwise**, a Swift loop sums sequentially, and over 256 squares
  the two disagree by ~1e-7, re-rounding the occasional component. Accumulating that norm in Double
  took the divergence from 54 components to 11, which is the artifact now committed. Worth recording
  because the wrong explanation pointed at the one stage that was already identical.
- **Two pinned steps are easy to get plausibly wrong**, so both have named tests: rounding is
  half-to-even (numpy `rint`; Swift's bare `rounded()` is half-away-from-zero), and sign packing is
  MSB-first with zero packing as a SET bit (`np.packbits(m >= 0)`). Either backwards yields plausible
  Hamming distances that are not the measured ones.
- **RERANK_POOL ships at 800**, not the design's 200, per the assessment's sweep — and the measured
  value travels *in* the artifact so a device need not read a planning doc to know what its recall
  number describes.
- Every artifact carries one provenance digest (model + GGUF SHA + dims + chunking + prefix +
  pooling + quantization, separator-joined so the prompt's trailing space cannot go invisible). The
  family rule: no consumer mixes two generations.
- Two departures from §4.3's shard sketch, both toward fewer sources of truth: Float32 scales rather
  than Float16 (the design's own size table budgeted 4 bytes), and no id rows in shards (the bundled
  index already has them; a second copy is a second place for identity to be wrong).
- The generator throws rather than writing on an unpinned model, a missing volume, an id encoding
  that does not round-trip, or a vector/centroid that cancels to zero.

New bundle resources, so this took the one-time `xcodegen generate` + scheme restore; the pbxproj
diff is exactly the 12 new resource references. **The +10.23MB is the design §10.1 app-size decision
being taken** on its recommendation — reversible to a first-launch download without touching the
generator.

Still open: Tier 0's map layer (2-D coordinates + cluster labels) waits on the UMAP/HDBSCAN stage and
its pinned non-stdlib Python environment — it gates V-4 only, and the centroids it would have shipped
beside are already in the binary. Next is V-2, the device substrate: loaders, the shard fetch and
registry in DownloadManager/IndexingPipeline, the mmap scan kernels, and oldest-device latency.

### Review pass on the packer (same session)

A four-lens adversarial review (arithmetic vs `spike_gates.py`, binary layout re-parsed independently
in Python, identity checked against all 314,483 store ids, runner failure modes) raised 10 findings,
9 confirmed by execution. All are fixed here; the artifacts were regenerated and re-verified.

- **`measuredRecallAt10` was a single constant while `DIMS` is a documented lever.** A 512-dim
  artifact would have shipped 256's 0.7449 — understating its own measured quality by 0.106 while
  citing the document that contradicts it. The whole point of carrying the number in the artifact is
  that a consumer need not read that document, so the wrong number is the one that gets believed.
  Now keyed by width (`[256: 0.7449, 512: 0.8510]`), and a width with no corpus-scale measurement is
  refused rather than given a borrowed number. The artifact test pins the value for the artifact's
  own width instead of a `> 0.7` floor, which 256's number cleared at every width.
- **`DIMS` was unvalidated and reached preconditions.** Verified: `DIMS=7` and `DIMS=1024` exited 133
  by SIGTRAP, and in a release build preconditions keep their teeth but lose their messages, so the
  operator got no diagnostic at all; `DIMS=abc` silently packed at 256 as though unset. Now validated
  before anything is read, with an error naming the variable and the accepted widths.
- **An interrupted run could leave two generations of shards side by side.** Shards are written per
  volume, the manifest once at the end, and the directory is gitignored — so nothing in the
  repository would ever show it. A successful run now prunes every `.vec` it did not publish.
- **Nothing verified a shard's bytes.** The artifact test checked that each `sha256` field was 64 hex
  characters and never opened a file. It now hashes every shard present (skipping cleanly when they
  are absent, as on a fresh clone) and checks size, magic, and the provenance digest.
- **A zero chunk row was reported as a degenerate document**, sending the reader to inspect a
  document when the fault is a row in the store. Its own error case now names the chunk.
- **`numericPart` now refuses a multi-digit leading zero.** `decode` re-mints interior ids from a
  value, so `d006, d007` would have decoded as `d006, d7` — the round-trip guard would have aborted a
  552-volume pack rather than corrupt anything, but refusing the parse makes such ids literal
  segments and makes "exact by construction" actually true. No such id exists in the corpus today
  (0 of 314,483); this is about the next one.
- Three doc figures corrected against measurement: the index is 73 KB not ~90 KB, and the id segments
  are 7.5 KB of literals / 48 KB encoded, not "~14 KB".

One finding was refuted on verification (a claim that `decode` traps on malformed segment shapes —
the behaviour reproduces but is the documented refusal path, not a defect).

## Session 2026-08-12 — V-2: the device substrate, and two kernel defects the reference caught

The device half of the semantic program: the code that reads the V-1 artifacts, keyed and scored the
way the corpus gates measured. No UI and no similarity axis — that is V-3.

**`SemanticVectorsKit`** now holds the artifact contract and is compiled into the app *and* the
packer, on the WordCloudKit precedent: two copies of a binary layout are how a byte's meaning drifts.
It carries the shapes and layouts (moved out of `SemanticVectorsGeneratorCore`), the document-id
encoding, mmap readers for both tiers, and the retrieval kernel. The generator keeps only what a
packer needs.

**The kernel is verified against the measurement, not merely unit-tested.** Driving the shipping code
over the real shipped artifacts reproduces the numpy reference the corpus gates ran on for **600 of
600 queries, in exact order** — so the recall number the artifact states describes what the device
does. That check found two defects a unit test would not have:

- It returned the right candidate **set** in row order while its own doc comment promised "nearest
  first". Invisible behind a rerank; wrong for a caller with no shard, which is every volume today.
- Its eligibility filter ran during collection, *after* the cutoff had been computed over rows that
  were then discarded — a 50-candidate request returned 28.

Both are now a proper counting sort (histogram → prefix-sum offsets → placement), with the tie-break
falling out of the traversal and a property test pinning it against a naive sort.

**Performance is measured, and the two dominant costs were not the arithmetic.** Materialising a
`[Int8]` per candidate: 5.59 → 4.78 ms. Resolving each candidate through `document(at:)`, which builds
an id `String` the caller then hashes: 4.78 → **2.44 ms**. `volumeSlot(containing:)` exists for that —
at 800 candidates a query, the string and its hash cost about what the entire 314,483-document scan
costs (1.43 ms). Every performance sentence in the doc comments is one of these measurements; an
earlier draft cited a number from a scratch harness that the shipping path never achieved, and that
was corrected rather than shipped.

**Two design deviations, both argued in code:**

- **No SQLite registry table for shards.** The app already answers "is this volume downloaded" from
  the filesystem, nothing here reconciles a table against disk, and a registry would need maintaining
  in three hand-kept lists (`auxDeleteVolume`'s eleven tables, `removeAllVolumesFromIndex`'s parallel
  list, and `PRAGMA user_version`, which `FTS5Connection` owns). Presence is a `stat`; provenance is
  the shard's own header; neither can lie.
- **Shards live in their own directory**, not beside the volume XML. Three places sweep the Volumes
  directory by extension and all three look for `.xml`, so a `.vec` there would outlive its volume.

Teardown is wired at both paths the scouts found: `onVolumeDeleted` (which the Settings hubs fire
twice, hence idempotence) and `ResetService.resetLocalData`, which deletes XML directly and therefore
never fires that callback at all.

**Tier 2 still has no host.** The design names an app-owned GitHub repo; creating and publishing it
is the owner's call, so this ships the seam rather than a fetch: `adoptShard(from:for:)` validates
header, provenance digest and row count before keeping a file, which is what a network fetch will
call. Tier 1 is bundled and works with zero downloads today.

Owed next: the oldest-device latency measurement (desktop numbers only so far), the Tier-2 host
decision, and V-3's axis — which lands into a ranker where `isSelfNormalising` does not yet exist and
where generators run regardless of weight, both of which V-3 must handle rather than discover.

## Session 2026-08-12 — V-2b + V-3: the axis, and the two shared changes it needed

**Tier 2 got a host** (owner decision, beta): 552 shards / 82 MB published at
`github.com/joshbotts/frus-semantic-vectors` — derived data only, with the shard format, the
provenance pin and the measured recall in its README. The app fetches from raw.githubusercontent but
deliberately **not** through `DownloadManager`: that engine hardcodes `<volumesDirectory>/<id>.xml`,
routes by `taskDescription == volumeId` so a second per-volume transfer has no representable key, and
exposes a single delegate slot a second attacher would displace. A shard is 148 KB; background
sessions are for transfers that must survive suspension.

The shard manifest moved into the bundle (66 KB) so a download is checked against its recorded length
and SHA-256 before the store re-validates header, provenance and row count. That is more than the app
does for volume XML, and deliberately: a corrupt volume is visibly wrong, a corrupt vector is a
plausible wrong answer. Fetch policy is split — eager beside a volume's own download (148 KB against
~6 MB), lazy for everything already on disk, so an existing full library does not silently pull 82 MB
at launch for a feature nobody has opened.

**V-3 — `SimilarityAxis.semanticSimilarity`** ships as a generator at weight 0 with "experimental" in
its display name. A generator rather than a scorer because a scorer cannot widen the candidate
universe, and the 46,234 documents with an empty Related list are the entire point.

Two changes to shared code, both of which the ranker applies on behalf of every axis:

- **`isSelfNormalising`** — the #643 escape, which existed only as a proposal in two planning docs.
  Step 2 of the ranker divides each generator axis by its own max, which is right for a count and
  destructive for a cosine: a document's *only* semantic neighbour would read 1.0 however unlike it
  is. Self-normalising axes are clamped to [0,1] instead — a negative similarity is not evidence.
- **`skipsGenerationAtZeroWeight`** — generators otherwise run regardless of weight, on purpose (one
  axis's candidates are scorable by another). The semantic axis is the exception because its
  generation can trigger a **network fetch**, and spending a user's bandwidth on an axis they left at
  0 is not defensible. Both properties are false for all six existing axes, and a test asserts that.

The generator applies the display fence *inside* the scan as a precomputed per-row eligibility array
built from indexed volumes' row ranges — filtering afterwards is what V-2 measured returning 28
candidates for a request of 50. It scores only candidates whose shard is present and **drops the
rest rather than falling back to Hamming**: raw binary recalls 0.53 against the funnel's 0.745 and the
two are different scales, so a list mixing them would be sorted by a number meaning different things
in different rows. Missing volumes are queued so the next query is better.

Still owed: the "why related" chip currently states the cosine as a percentage, which is the only
thing this axis knows — the design's shared-distinctive-terms chip is separate work. And the
tester-feedback path the retired blind panel was traded for still needs to exist: shipping an
experiment nobody can report on is not evidence-gathering.

## Session 2026-08-12 — V-3 follow-ups: the chip, and the feedback path the panel was traded for

Two things the axis shipped without, plus a defect the scouting found in what did ship.

**THE SEMANTIC EVIDENCE LABEL WAS NEVER RENDERED.** V-3 added
`SemanticSimilarityGenerator.evidenceLabel`, tested it, and carried it to
`RelatedDocumentRow.axisEvidenceLabel` — but `whyRelatedChips` had no `.semanticSimilarity` arm, so
it fell through `default:` to a bare percentage and the label's only consumer was its own unit test.
A test on the producing function passed the whole time. This is the "tests must drive the real
emitter" failure in its purest form, and the fix is source-scanned rather than unit-tested for that
reason.

**The "why related" chip** (`SemanticSharedTerms`) now computes shared *distinctive* terms at render
time for the displayed rows only — the design's §6.1 shape. Ranking is by corpus rarity from
`BundledKeynessBaseline`, because two FRUS documents share "government" the way two sentences share
"the". Three details are load-bearing:
- **A term the baseline does not price is skipped, not treated as maximally rare.** The artifact
  keeps a 20,000-term head, so "unpriced" also means "tokenisation debris" — which would otherwise
  win every chip precisely because it is meaningless.
- **The display form comes from the anchor's own text.** `WordCloudTokenizer` emits lowercased
  lemmas; printing them would render the ship *Kearsarge* as `kearsarge`. A guard also rejects a
  surface form far longer than its lemma, so "ration" inside "corporations" is not shown.
- The pass runs **after** ranking and is guarded on the same reload key as the load, so a late
  result cannot write terms for a previous anchor onto the current rows. Rows display the percentage
  until it lands, and permanently where no distinctive vocabulary is shared.

Observation recorded rather than fixed: the rarest shared terms are often personal names, which
overlaps the `sharedPersons` axis. Filtering them would need a second entity pass per document, and
which a historian prefers is what the feedback path is for.

**The tester feedback path** (`SemanticFeedbackLog` + Settings ▸ Data & Recovery ▸ Semantic Match
Feedback) is the other half of the decision to retire the blind panel. **Every field exists to answer
the question the panel would have answered**: the anchor's `CoverageEra` — the app's own banding, not
a second one — plus the cosine, whether the pair are volume-mates, and the artifact generation. A log
without the era would record enthusiasm and prove nothing, and the Settings screen shows the era
split on screen rather than burying it in the export, because zero pre-1900 verdicts after a beta
means the panel was retired and nothing replaced it.

It is deliberately **not** a `@Model`: that changes the CloudKit schema and needs a Production deploy
before shipping (#488), and a tester's notes about the app are not their research. It follows
`SyncDiagnosticsLog` — an actor over a bounded JSON file in Application Support, local by
construction, exportable through `ShareLink`. A second verdict on the same pair replaces the first,
so one indecisive row cannot outweigh ten rows of agreement.

The row control is a context menu (the row is already a Button, and a button inside a button is a
hit-testing argument nobody wins) and appears only on rows the semantic axis actually scored — a
verdict on a row it did not produce would be evidence about a different axis.

## Session 2026-08-12 — V-4a: the renderer is fine, the layout is the problem

The spike the design asks for before any of the discovery map's interaction design gets built.
Verdict and numbers: `Planning/semantic-map/V4a-Rendering-Spike.md`; the picture it produced is
`v4a-pca-layout-2560.png` beside it.

**Rendering is not the bottleneck the design budgeted for.** One draw call over all 314,483
documents costs **3.3 ms** at 2560×1440 on the M1 Max — five times inside a 60 fps frame. §6.3
budgets level-of-detail machinery as a prerequisite ("a session, not an afternoon"); it is an
optimisation for weaker GPUs. **The cost is fill rate, not vertex count**: 8-pixel points cost 50%
more than 2-pixel ones, and zooming in — same vertices, fewer covered pixels — drops the frame to
0.6 ms.

**And the spike found something it was not looking for: PCA-2D is unusable as a layout.** The two
leading components carry 10.0% of the variance and the corpus renders as one featureless cloud. That
is not a rendering defect, it is what 10% looks like — and it means **V-4's blocking dependency is
the Tier-0 layout artifact, not the renderer**, which inverts the order the design assumed. Until
UMAP/HDBSCAN runs there is nothing worth rendering, and every remaining §6.3 feature is downstream of
it.

Two engineering notes worth keeping. The shaders compile at **runtime** rather than from a `.metal`
file, because a build-time shader needs the Metal toolchain component and a multi-gigabyte developer
download is a strange prerequisite for finding out whether a draw call is fast; if the map ships,
that becomes a deliberate decision. And the spike **deliberately bundles no placeholder layout** — it
reads a developer-supplied coordinate file and falls back to a synthetic cloud that says so on
screen, because a file in `Resources` that looks like the measured artifact and is not is exactly the
failure this program keeps designing against.

Next: the Tier-0 layout stage (pinned Python, PCA-50 → UMAP-2D with a fixed seed, clusters and
c-TF-IDF labels, packed by `SemanticVectorsGenerator`), then re-measure this spike against the real
clumped layout before deciding whether a density layer is needed.

## Session 2026-08-12 — V-4 layout stage: the map has a shape

The Tier-0 layout the V-4a spike identified as V-4's critical path. Tool:
`tools/semantic-map/build_layout.py`; environment pinned in `tools/semantic-map/requirements.txt`
(+ a resolved lock beside it); picture: `Planning/semantic-map/v4-umap-layout-2560.png`.

**Measured**: PCA-50 (58.4% of the variance in the components UMAP consumes) → UMAP-2D in **6.6 min**
→ HDBSCAN in 8.2 min, giving **179 clusters and 28.0% unclustered**. `layout.bin` is **1.89 MB** for
314,483 documents at 6 B each — the design's §4.1 estimate to two decimal places.

**The picture is the point.** PCA-2D was a featureless blob (10.0% of the variance); UMAP gives
continents, filaments, islands and voids — something a reader can navigate. That contrast is why the
layout stage, not the renderer, was V-4's blocker.

**The fill-rate caveat is closed, and the prediction was half wrong.** I expected UMAP's clumping to
be strictly worse for the renderer. Measured, the two layouts *cross over*: the densest cell holds
452 documents against PCA's 38, but overall occupancy *falls* from 50.8% to 31.4%, so at 2 px UMAP is
**cheaper** (1.90 ms vs 3.28) and at 8 px it is 47% **dearer** (5.91 vs 4.03). Cost tracks covered
pixels, and clumping trades a smaller lit area against heavier overdraw inside it. Worst measured
case is 5.9 ms — still nearly 3× inside a 60 fps frame — so level-of-detail stays an optimisation,
and the practical lever is point size: a map that scales sprites with zoom does LOD's job for a
fraction of LOD's complexity.

Environment notes worth keeping. The machines have **Python 3.9 only**, which is what pins
scikit-learn below 1.7 and numpy below 2.1 — a future machine with 3.12 would resolve differently.
The standalone `hdbscan` package is deliberately absent: scikit-learn has shipped
`sklearn.cluster.HDBSCAN` since 1.3, so the clustering needs no extra dependency. `random_state` is
pinned despite costing UMAP its parallelism, because a layout that rearranges itself between runs
cannot be diffed or regression-tested and would move every document on screen after a rebuild that
changed nothing. Clustering runs on the **2-D embedding**, not the 50-D space, so the clusters a
reader sees are the ones the map draws.

The stage emits cluster **ids only**. Labels are Swift's job (c-TF-IDF through the WordCloudKit
tokenizer, per design §4.1) — labelling in Python would mint a second vocabulary that silently
disagrees with every word-cloud surface, which is the cross-source-join failure this repo keeps
re-learning.

Two defects fixed on the first run: `np.asarray` on a memmap whose dtype already matches returns a
READ-ONLY view, so the in-place renormalise threw; and PCA was being fitted a second time purely to
log its explained variance — a full pass over 314,483 × 256 for a number already in the estimator.

Next: pack Tier-0 into the bundled artifact (`SemanticVectorsGenerator` reads `layout.bin`, emits
coordinates + cluster ids, generates the labels), then the surface itself.

## Session 2026-08-12 — V-4 Tier 0 packed, and 168 of 179 labels were wrong

The map artifact: `semantic-map.bin` (1.89 MB — 314,483 placements, 179 clusters, 28.0%
unclustered) and `semantic-map-index.json` (25 KB — labels, cluster centres, per-cluster era
histograms). A **separate** artifact from the vector tiers because the access patterns differ, and a
**separate, skippable pass** in the packer because the map's layout comes from a 15-minute Python
stage and a packer that refused to emit vectors without one would hold the shipping feature hostage
to an experimental one.

**The finding that matters is a defect I had already eyeballed and approved.** The first c-TF-IDF
used `log(1 + N/df)`, with a comment asserting the `+1` made a universal term score zero. It floors
it at `log(2) ≈ 0.69` instead — enough for a word occupying 98% of a cluster's tokens to beat one
appearing nowhere else. I read the output, saw `chinese, china, japanese, nanking` against the China
cluster and `israel, arab, israeli` against the Middle East one, and called them historically
coherent. **They were the wrong labels.** A fixture where `government` beat `kearsarge` caught it, and
correcting the formula to plain `log(N/df)` changed **168 of 179 labels**:

| cluster | before | after |
|---|---|---|
| 8 (38,652 docs) | chinese, china, japanese, nanking | nanking, shanghai, hankow, chinese |
| 108 (8,094) | british, united, war, american | maize, cottonseed, oversea, lansing |
| 20 (15,520) | israel, arab, israeli, say | israel, israeli, arab, baath |

Generic words gave way to distinctive ones in every case. **Plausibility is what made it invisible,
and plausibility is all an eye can check** — the same lesson as the V-3 evidence label that was
computed, tested and never rendered.

Two smaller decisions, both recorded in code. Labels are Swift's, not Python's, because the design
wants them through the WordCloudKit tokenizer and a second tokenizer would mint a second vocabulary —
the failure `BundledKeynessBaseline` exists to prevent. And date chrome (`apr` named a cluster) is
filtered **in the labeller**, not in the shared stopword payload: `BundledKeynessBaseline` pins that
payload's SHA-256 — verified, the digests match — so editing it would make every keyness read report
a configuration mismatch until a ~50-minute `CloudVectorsGenerator` run, and would silently re-price
the entire corpus reference. Disproportionate for one cosmetic term in one label of 179.

Labels are **sampled** — c-TF-IDF over up to 300 stride-sampled documents per cluster, 53,087 read of
226,276 clustered — and the artifact says so, because a label built from part of a cluster should
disclose that rather than let a reader assume it saw everything. The stride runs over members in row
order (which is volume order) so a sample spans a cluster instead of concentrating in whichever
volumes sort first.

## Session 2026-08-12 — V-4: the map reads its own artifact

The surface stops being a spike. `BundledSemanticMap` loads the shipped Tier-0 artifact —
`SemanticMapVectors` mmaps `semantic-map.bin` the way the corpus tier is mapped — and the view draws
from it. **The developer-file path and the synthetic-cloud fallback are gone**: they existed because
the layout did not, and a device with no map now says so rather than drawing something invented.

The loader **refuses a map whose provenance digest disagrees with the loaded vectors**, and this is
the one refusal in the family that is not pedantry: coordinates are computed *from* vectors, so a map
of one generation drawn against another places every document where different vectors put it — wrong
in a way no reader could ever detect.

**Three colour lenses**, all computable from data the app already carries: `cluster` (the map's own
bytes), `era` (the manifest's dates, banded by the app's own `CoverageEra` so an era-coloured map, an
era-split chart and an era-banded feedback log all mean the same thing by "before 1900"), and
`availability` (which volumes are indexed — the reader's own library against the whole corpus).

Two implementation notes that are really one idea. A point carries a palette **index**, not a colour,
so switching lens rewrites one byte per document — 314 KB against the 5 MB a colour-per-point buffer
would cost — and never touches a coordinate; `setColourIndices` exists for exactly that. And every
lens except `cluster` is a property of a *volume*, and the map's rows are contiguous per volume, so a
lens is a few hundred range fills rather than 314,483 lookups.

The palettes differ by lens on purpose: `era` is ordered and gets a sequential ramp, `availability` is
a two-state contrast, `cluster` is categorical. Drawing an ordered variable with categorical hues is
the commonest way a map lies about its data. Cluster colours **cycle** through 16 slots for 179
clusters — adjacency is what the colour conveys, and the label at a region's centre is what names it;
a map that tried to give 179 regions distinguishable hues would distinguish none of them.

Verified by rendering the **shipped bytes** through the headless Metal tool rather than trusting the
build: 314,483 placements, 179 clusters, 28.0% unclustered, all cross-checked against the index.
App suite 3,433 green, SPM 1,119 green, both platforms build.

Still to come: cluster labels drawn on the map, tap-to-open, lasso into a `WorkingCorpus`, and the
design's semantic-axis slices.

## Session 2026-08-13 — the map drew nothing, and three of my explanations for it were wrong

The owner opened the screen and reported **no visible map**. Every artifact check was green; the
screen was blank.

**What is established.** The renderer was created inside the representable's `makeUIView`, which then
performed two `@State` writes during a view update: `renderer = made`, and then `unavailable = …`
from an eager load that ran before `BundledSemanticMap.prepare()` had and so found no map. Two
writes, and the owner's console carried exactly two "Modifying state during view update" lines.
Nothing was ever uploaded.

**What is not established, and this session's main lesson.** The first version of this entry — and of
the doc comment — went further and said the `.task` closure "had captured the view struct from before
the renderer was assigned, so its `if let renderer` saw `nil`", and that the body swapping the
surface out "destroyed the renderer". An adversarial review of my own diff refuted both. A `@State`
property reads through a SwiftUI-owned location, which is exactly why ordinary `.task` and
button-action bodies see current values; there is no snapshot to go stale. And the renderer was held
by that same `@State` while `MTKView.delegate` is `weak`, so the swap tore down the view and nothing
else. Worse, the two stories contradict each other: if the write stuck, the renderer survived the
swap; if it did not, the renderer died when `makeMap` returned and the stale-capture story is
superfluous. SwiftUI documents a state write during a view update as undefined behaviour, and the
honest account is that the code invoked it and the map never appeared. **The fix removes the
undefined behaviour rather than reasoning about which write survived it** — which is also why the
always-mounted surface is justified on its real merit (a transient unavailable state no longer tears
down the drawable) rather than on a rescue that never happened.

**The fix is an ownership change.** `SemanticMapModel` (`@MainActor @Observable`) owns the renderer
and builds it from the `.task`; the representable creates no state and only *attaches* what exists,
which is usually nothing yet — `updateUIView` is the path that actually connects it. Extracting a
plain class is what made the load testable. (The closure parameters instead of an `AppState` are
ergonomics; `AppState()` is default-constructible and the suite builds one in dozens of places. The
first draft of this entry claimed otherwise.)

**The first test I wrote for it was a tautology.** It asserted `model.placedCount == documentCount`
under the message "every placement must reach the vertex buffer" — but `placedCount` is assigned from
the array the model has just built, one statement after `setPoints` and with no dependency on it.
Stub `setPoints` to an empty body and all three new tests stayed green over a blank screen: exactly
the defect they were written for. `SemanticMapRenderer` now exposes `uploadedPointCount` (read
*through* `pointBuffer`, so it also catches a `makeBuffer` returning nil) and `uploadCount`, and the
tests assert those. Idempotence needed the counter specifically — a full re-upload of the same corpus
leaves every other number identical, so "does not re-upload" was previously unfalsifiable.

**Four more defects the review found in code I had just written**, all confirmed against source:

- The map was drawn **stretched on every device**. `frameAll` was called with a hardcoded `aspect: 1`
  and `mtkView(_:drawableSizeWillChange:)` was empty, while the shader normalises by `scale` in both
  axes. Aspect and viewport now come from the drawable; `scale` is derived from a `halfExtent` plus
  that aspect, so a resize cannot disturb the camera and a zoom cannot distort the map. Pan converts
  through the real viewport instead of a constant 300 points.
- The lens picker and point-size slider **were not reachable on iPhone**: a grouped `Form` capped at
  `maxHeight: 130` spent the budget on section insets and rendered an empty card. Now a plain stack.
- A lens chosen *during* the load was dropped and overwritten, because `apply` refuses until the index
  exists. The `.task` re-applies after the await.
- Doc comments that said the blending was additive ("what makes density legible") when the factors are
  ordinary source-over, and that the vertex buffer is 4 bytes per document when `MapPoint` strides at
  8. Both corrected; a real density layer is still owed.

**The format diagnostic has a mechanism after all, and it is worth carrying elsewhere.** I had
written that the nine `String(format:)` complaints paired a format string from one line with an
argument type from another and that I could not reproduce them. Both wrong. The line was

```swift
String(format: "%.0f fps equivalent", ms > 0 ? 1000 / ms : 0)   // ms is a Double
```

Under a `CVarArg...` parameter the ternary's branches are erased to the existential **independently**,
so the bare literal `0` takes its default type `Int`. Verified by running it: a `CVarArg...` probe
prints `Int` when `ms == 0` and `Double` otherwise. It fired only while `frameMilliseconds` was still
zero — the frames before `StatsSink` publishes its first 30-sample window — which is why there were
about nine and then no more. `LocalizedStringKey` was never involved. The general rule:
**`cond ? someDouble : 0` under `CVarArg` is an `Int` half the time.**

**Verified on device, not from the build.** iPhone 17 simulator: the map draws 314,483 documents at
0.14 ms mean / 0.24 ms worst, and the app console carries zero format diagnostics and zero
state-during-update warnings. The previous entry ended "verified by rendering the shipped bytes
through the headless Metal tool rather than trusting the build" — that was true, the bytes were fine,
and the screen was blank anyway.

## Session 2026-08-13 — the map was still blank on macOS: it was the SwiftUI sheet

PR #874 fixed the map on iOS. The owner reported it **still blank on macOS**, with the stats overlay
confidently reading "314483 documents · 4.09 ms mean · 245 fps equivalent". This entry records a
failure to diagnose, because three confident explanations for this one screen have now been wrong and
the pattern is worth more than another story.

**Two things I read wrong in that screenshot.** The stats do not prove the surface was drawing:
`StatsSink` publishes one window per 30 samples and the model then *keeps* that value, so a frozen
overlay is indistinguishable from a live one. And I reached for a mechanism before measuring.

**The one solid lemma.** `clearColor` is not a property an `MTKView` paints — it is the `.clear` load
action inside `currentRenderPassDescriptor` — so a layer nobody presented to has **no contents at
all** and composites transparent. White meant "nothing reached the screen"; dark would have meant
"attached but idle". The surface had no way to say which, which is why one screenshot could not
settle it, and fixing *that* is the most useful thing this session produced.

**Nineteen candidate mechanisms were reviewed adversarially and every one was refuted.** Two of the
refutations were themselves measurements: the bare `MTKView()` initializer does NOT skip MetalKit's
setup (MTKView's own Objective-C method list carries `initWithFrame:` on macOS 26.6.1), and the
"4.09 ms implies a large drawable" inference is unfounded.

**My own probe was wrong, and I over-claimed on it.** A simplified AppKit probe showed `updateNSView`
firing once and the view never drawing, and I reported that as the measured cause. It was an artifact
of the probe: the ticking state sat on the *presenting* view, so the sheet's content never
re-evaluated. A **faithful** reproduction — same shader, the real 314,483 placements, the same
model/representable/sheet structure — shows the opposite and is the one to trust:

```
>>> updateNSView view=-37073 window=SheetPresentationWindow frame=(0,0,520,333) delegate=nil
>>> ATTACHED to view=-37073 window=SheetPresentationWindow
[draw #600] view=-37073 window=SheetPresentationWindow vis=true drawable=(1040,666) inTree=true
```

The view is attached, sized, visible, in the layer tree, and presenting 600 frames at a clean 60 fps.
So neither "it never gets a delegate" nor "the sheet realizes it twice" is what happens.

**And the faithful reproduction's own conclusion is also unfounded.** It reported "SwiftUI's sheet
never composites the layer" and cited a screenshot; there is no screenshot among its artifacts and no
pixel readback anywhere in its code. It could not see the screen. Its logs establish that the view
*draws*; they establish nothing about what *appears*. Its bisect also contains a counter-example in
which the sheet case rendered. Treat "the sheet is at fault" as an untested hypothesis.

**What shipped, and why each part is defensible without the diagnosis.**

- `draw(in:)` encodes an **empty pass** when there is nothing to draw, so an attached-but-idle surface
  clears to dark instead of staying contentless. This converts the next observation into a
  measurement: dark = attached and presenting, white = neither.
- `Stats` gained a running `presentedFrames`, because the averages alone could not distinguish a live
  surface from a dead one — the precise ambiguity that misled me.
- `SemanticMapModel` builds its renderer in `init`, so a renderer can no longer arrive after the last
  `update*View`. A real hole, mutation-tested (with `makeMap` returning an unattached view the new
  test fails three times with `view.delegate → nil`) — but NOT known to be the macOS cause.
- Frames from a window-less view are ignored, so the statistics describe the surface on screen.
- **macOS opens the map in its own `Window` scene instead of the sheet.** The cheapest way to test the
  one hypothesis still standing: if it draws there, the sheet was the problem; if it is still white in
  an ordinary window, the hypothesis is dead and the `[SemanticMapRenderer]` probe lines say what is.

**CONFIRMED THE SAME DAY.** The owner opened the rebuilt app and the map appeared. Moving the screen
out of the sheet and into its own `Window` scene, with nothing else changed, is what fixed it — so
the last hypothesis standing was right, and the rule to carry is blunt: **do not put an `MTKView` in
a SwiftUI sheet on macOS.** It draws, it presents, and none of it reaches the screen.

Two process notes, since the failure was in the diagnosing rather than the code. The empty-pass
change is what would have made this a one-round bug: until white and dark meant different things, no
screenshot could distinguish "never attached" from "attached and idle", and three confident
explanations survived that ambiguity. And of nineteen candidate mechanisms reviewed adversarially,
the one that was right survived only as the last one standing — it was settled by looking, not by
argument, which is the whole reason the surface had to be made observable first.

## Session 2026-08-13 — the map names its regions

With the macOS blank fixed, the map was still a coloured cloud with nothing to read. The Tier-0
artifact has carried the names since it was packed — 179 clusters, each with four c-TF-IDF terms and
a centre — and nothing drew them. Now the largest regions are named in place: *nanking shanghai*
(38,652 documents), *israel israeli* (15,520), *vietnam viet* (13,587), *shah iran*, *rok korea*.
Seeing them land on the right clusters is incidental confirmation that the c-TF-IDF fix two sessions
ago was the right one.

**Rank by size, not by proximity.** 179 regions, room for about 22 names. Picking the nearest would
re-pick a different set every frame; picking the largest keeps a region's name attached to it while
the reader pans, and a small region simply loses to a big one it collides with. Ties break on id so
two equal regions cannot swap between runs.

**One projection rule, and it is now a type.** The label layer has to land text on the pixels a point
lands on, so `SemanticMapCamera` owns `(grid - centre) / scale` and the renderer's `scale` *is* that
function. A second copy of that arithmetic would be a second thing that drifts — this file has
already shipped a distortion bug from exactly that. `aspect` is deliberately NOT stored on the camera:
the renderer takes it from the drawable and the label layer from the SwiftUI geometry, the same
rectangle in pixels and in points, so the ratio agrees by construction and there is nothing to sync.

**The camera is mirrored onto the model rather than read from the renderer**, because the renderer is
display-link-driven and must not publish per frame. Gestures now go through `SemanticMapModel.pan`
and `.zoom`, which move the camera and republish it; that is what makes the labels follow the map.

**Looking at it caught what the tests did not.** The first build clipped names at the viewport edges
— `srael israeli` on the left, a truncated `seward dayton` on the right — because the visibility
margin let a region's *centre* sit near the edge while its *text* ran off. Labels are now clamped
inside an inset, and the clamp runs BEFORE the spacing test so two names pulled to the same edge
still cannot collide. That ordering is itself tested, since it is the failure the fix could
introduce.

**And the fix broke a test in an instructive way.** The cap test spread its clusters to the grid
edges, so after clamping three of them landed on the same x, collided, and were dropped — the
assertion "the largest five" saw `[0, 1, 5, 6, 7]`. The temptation is to relax the expectation to a
count; that would have stayed green while testing nothing. The fixture moved inboard instead, with a
comment saying why, because the test's job is to prove the *cap* picks the largest N and it cannot do
that while the *clamp* is what is limiting it.

Layout is a pure function of (clusters, camera, size) — projection, y-flip, aspect, pan, zoom,
crowding, culling, the cap and the clamp all tested without a GPU, which is the thing this surface
has repeatedly needed and not had. Map suite 17 green; verified on the iPhone 17 simulator.

Still to come: tap-to-open, lasso into a `WorkingCorpus`, and the design's semantic-axis slices.

## Session 2026-08-12 — #234 R-1: the detector pilot, measured

Three arms over the twelve M1a volumes on the Air (Apple M5, 32 GB). `prompt_tokens` came out
identical at 548,177 for both LLMs, so the two saw the same 824 chunks and the comparison is one.

| | docs | mentions | novel | unlocated | truncated | wall clock | scope extrapolation |
|---|---|---|---|---|---|---|---|
| `NLTagger` control | 9,935 | 71,358 | 95% | n/a | — | 0.4 min | **~8 min** |
| Qwen3 1.7 B | 480 | 2,031 | 85% | **7.3%** | 244 (30%) | 421 min | **~120 days** |
| Qwen3 14 B | 480 | 2,264 | 82% | **0.8%** | 231 (28%) | 1,754 min | **~501 days** |

### The timings measure a misconfiguration, not a model

§4.1 designs this workload to be 94% prompt processing. It ran at **52.8% generation** — 613,375
completion tokens against 548,177 prompt, **~735 per chunk** where the answer is ~25 tokens of JSON
(the models returned about two strings per chunk). That is Qwen3's reasoning trace, on by default.
The run became **decode**-bound, the one axis the Air is worst on, inverting §4.2's own argument for
using it. At 733 tokens in 127.68 s the 14 B decoded at ~5.7 tok/s against a ceiling near 10 for a
15 GB model on 153 GB/s; the 1.7 B got 24 of a possible ~85, the rest being the fanless throttle
over 7- and 29-hour runs.

The 28–30% truncation rate is the tell, and §4.5 pointed the wrong way at it — "`MAX_TOKENS` is
clipping a dense passage" is right for a non-reasoning model and actively misleading here, where
raising the ceiling makes the run slower and changes no answer. Both §4.2's table and §4.5's row are
now annotated.

Two corrections fell out: the chunk count is **1.72 per document**, so the scope is ~339,000 chunks
rather than §4.1's 230–260 k; and the control ran **8–15× faster than its own ~1–2 h estimate**.
§4.2's "at 0.5–2 B the gap narrows to roughly 5–20×" does not survive — measured, it is ~21,000×.

### The quality finding is clean, and is why two arms were run

On byte-identical input, Qwen3 1.7 B failed to copy **112 of 1,538** returned strings verbatim
(7.3%) against the 14 B's **13 of 1,634** (0.8%). A string not occurring verbatim is located nowhere
and contributes no mention, so that is one mention in fourteen deleted silently. With the 1.7 B
alone, 7.3% could have been the model or the prompt; the 14 B on the same chunks says it is the
model. **Shortlist sign-off: 1.7 B out on verbatim-copy discipline, 14 B stands with its cost
unmeasured.** `unparsable` was 0 for both.

Two traps recorded for whoever reads the table next. `novel` is not quality — the control finds 7.2
mentions per document against the 14 B's 4.7, and whether its extra half are people or ships is
exactly what M2a decides. And the control's `unlocated` is **n/a, not 0.0%**: that counter is
written only by the LLM path, so a summariser defaulting it to zero shows the control as flawless at
something it never does.

### The re-run, and the provenance gap it carries

`detect_chunk` sends a fixed body with no hook for `chat_template_kwargs`, so thinking is disabled
LM Studio-side and the manifest cannot record it — it records `system_prompt`, `response_format`,
`temperature` and `max_tokens` only. The *effect* is recorded (`completion_tokens` per chunk,
`truncated` per volume), so a store still says which mode produced it; §4.8 says to name the store
for it. §4.8 also carries a one-chunk probe through the harness's own `detect_chunk`, so the check
uses the real prompt: ~25 completion tokens means thinking is off, ~700 means it is not, and that
costs ten seconds against a 30-hour mistake.

## Session 2026-08-13 — tap a point, open the document

The map could be read but not used. Now a tap selects the nearest document, names it, and opens it.

**The gate is the point of the feature, not a detail.** The map draws all 552 volumes; a reader has
downloaded some. The obvious implementation offers "Open" on every document and fails on most — and
on iOS it fails *silently*: `DocumentView` sits on "Opening document…" forever with no error when the
volume is absent, because there is no not-downloaded affordance in the iOS reader at all. So the
selection carries whether the document is readable and the card says "This volume is not on this
device" instead.

**And the first version asked the wrong question.** It checked `indexedVolumeIds` — the *search
index* — where opening needs the XML on disk (`downloadManager.isVolumeDownloaded`). A volume
downloaded but not yet indexed reads perfectly well and would have been refused. The colour lens
keeps `indexedVolumeIds`, because that one really is about the index; they are two different
questions and are now two different functions.

**Picking is a linear scan and that is the right answer.** 1.9 MB of mapped placements read straight
through with a one-axis early rejection, once per tap rather than per frame. A spatial index would be
faster asymptotically, slower here, and a second structure to keep in step with the artifact. The
cost is measured, not assumed. The tolerance converts through the camera, because a 22-point
fingertip is a different number of grid units at every zoom, and `unproject` is pinned against
`project` by a round-trip test — a tap resolved through a slightly different rule selects the
document *next to* the reader's finger, wrongness that reads as imprecision rather than a bug.

**Two integration defects, both found by driving the app rather than by the suite.**

1. The Open button did nothing. The card was an `.overlay` *on* the surface, so it sat inside the
   view carrying the `SpatialTapGesture` and the gesture swallowed the button. It is now a sibling in
   a `ZStack`. This would have hit the macOS `Button` identically.
2. It *still* did nothing — and the app log settled what three screenshots could not:
   `WebPageProxy::loadDataWithNavigation` and a completed page load, i.e. `DocumentView` was built and
   rendered its TEI, then the push failed to stick. A value-based `NavigationLink` needs its
   `navigationDestination(for:)` registered before the link activates, and it was declared on a view
   that is itself a pushed destination of the Settings stack. Bound to state
   (`navigationDestination(item:)`) instead.

**A test assertion that was green and wrong.** It required `documentID.hasPrefix("d")` and passed only
because the sampled rows happened to be `dN`. `frus1958-60v05mSupp` keys its 628 documents `eta_d1…`,
and the corpus also carries `d373a`, `appA`, `s05sub04` — the same assumption that mis-keyed 15,097
documents when the design tried deriving ids from ordinals. The test now samples that volume by name
and asserts identity **round-trips** through `row(documentID:volumeID:)` rather than asserting a shape.

**Verified end to end on the simulator, including the path that opens.** A volume was downloaded
specifically so the affirmative case could be exercised rather than reasoned about: the `Downloaded`
lens showed one green region beside *nato edc*; zooming in resolved *abm icbm*, *nuclear soviet*,
*nsc atomic*, *shevardnadze soviet*; tapping a green point selected `frus1989-92v31 · d173`; and Open
produced **"Letter From Soviet Foreign Minister Shevardnadze and Soviet Defense Minister Yazov to
Secretary of State Baker and Secretary of Defense Cheney", Moscow, December 6, 1990** — a Shevardnadze
letter, from the region the labeller named *shevardnadze*. The map's semantics check out under a
tap.

Still to come: lasso into a `WorkingCorpus`, and the design's semantic-axis slices.


## Session 2026-08-13 — draw a region, keep the documents

The map could be read and tapped. Now a freeform lasso captures what it encloses into a
`WorkingCorpus` — the app's existing document-grain, synced, citable set.

**The model already fitted, and that decided the design.** `WorkingCorpus.documentKeys` is a value
array of `"volumeId/documentId"`, so a lasso is **one insert**, not five thousand — no membership
`@Model`, no relationship, and therefore **no CloudKit schema-deploy gate**. Provenance goes in the
existing `sourceDescription`, the route the search capture already takes. Nothing was added to the
model.

**The 7,500 ceiling is the record's, not a search's.** `WorkingCorpus` sizes itself against macOS's
`searchHardLimit` because until now the only capture path was a result set — "at most 7,500 keys …
around 190 KB as a value array, well inside a CloudKit record". A lasso has no natural bound: it can
enclose the corpus. So the capture caps there, and the scan **deliberately runs past the cap** to
count everything inside, because `totalMatchCountAtCapture` is the thing a truncated capture is a
fraction *of*. A denominator that stopped counting when the numerator filled would be worse than none.

**A lasso is the first capture path that can enclose documents this device cannot search.** Every
corpus before it came from a search result set, so its members were indexed by construction; the map
draws all 552 volumes. Applying such a corpus silently narrows to the indexed keys, and one with none
is refused outright. The card therefore states coverage **at capture**, computed through
`WorkingCorpusResolver` rather than counted locally — so the number shown is produced by the same code
that later decides what the corpus actually searches.

**Even-odd containment, not winding**: a hand-drawn path that crosses itself leaves the overlap
outside, matching what the stroke looks like. The crossing test is half-open in y so a vertex at the
ray's height is counted once — the classic source of speckled holes along a horizontal edge, and one
of the geometry tests walks a row straight through one. The lasso is converted to grid space once
rather than projecting 314,483 documents into view space, for the same reason the tap radius is.

**Three controls on this screen have now been drawn correctly and done nothing**, each for a different
reason, and none visible to the suite: the Open button swallowed by the surface's tap gesture; the
Open button again, built but never pushed (a `NavigationLink` registration race, found in the system
log); and now the Lasso toggle, rendered *underneath the iCloud status banner* at the bottom of the
screen, so the drag kept panning. It moved to the toolbar — a mode switch has to be reachable
whatever transient chrome the app is showing.

**Verified end to end.** Lassoing the China cluster reported **40,599 documents**, region *nanking
shanghai*, "Saving the first 7500 of 40599", and "0 of 7500 documents indexed on this device" — then
saved, and the corpus appears in Working Corpora rendered by the existing view with no changes:
provenance "Semantic map selection · Captured Aug 13, 2026 · against 2 indexed volumes".

Still to come: the design's semantic-axis slices.

## Session 2026-08-13 — the axis you can state

The last of the design's V-4 features: *"a semantic axis = normalised difference of two centroid
vectors, where the user picks the poles … project visible documents onto it and drive the x-axis with
it while y stays date. This is honest in a way the UMAP plane is not."* That last clause is the
point — the map's plane preserves neighbourhoods, not distances, so "these two regions are far apart"
means nothing on it. An axis has a definition a reader can say out loud.

**The data decided which poles exist, and it is two of the design's four.** Verified against the
shipped bytes rather than the doc comments: the binary carries 552 volume centroids then 107
subseries centroids, int8 with a Float32 scale, L2-normalised before quantization — so those poles
are exact. A **cluster pole is not offerable at all**, because the Tier-0 map records a cluster centre
only as 2-D *layout* coordinates and nowhere in embedding space; term-set poles need an on-device
encoder the design defers and calls optional. Offering a pole the artifact cannot support would be
worse than offering fewer.

**Projection runs on sign bits, because that is the only corpus-wide per-document tier there is.**
One bit per dimension, so a document reads as ±1 and the coordinate is `Σ sign·direction / √dims` — a
real cosine against the sign pattern. int8 exists only in downloaded shards, and using it would make
the axis mean one thing for some rows and another for the rest.

**Poles are picked by tapping a document, not from a list.** 552 volumes and 107 subseries do not fit
in a menu anyone would read, and the reader is already pointing at what they mean.

**The coupling that would have been a silent wrong answer:** picking and lasso read the *artifact's*
placements. A slice draws different coordinates for the same rows, so a tap would have selected
whatever sat under the finger *on the map* while the reader was looking at a slice. Both now scan the
displayed positions, and cluster identity is looked up by ROW — which survives re-layout, because a
row still means the same document. Five existing tests moved onto the same accessor the model uploads
through, so the tests and the renderer no longer hold two copies of one decode.

**Three defects found by looking at it, two predicted and one not.** The lens was silently discarded
(`setPoints` rewrites every colour byte, so the slice came out in slot 0 — the dim "between regions"
grey); region labels stayed at their map positions, naming regions that are no longer there; and —
unpredicted — the x-spread was a narrow smear, because a sign-bit cosine against a
difference-of-centroids axis concentrates near zero when most of the corpus is unrelated to both
poles. The first two are fixed, the third is scaled to the observed range **and disclosed**, since
the order along the axis is the content and the absolute magnitude of a sign-bit cosine is not
interpretable on its own.

**The map now carries a caveat at all**, which it never has. On the plane it states the UMAP
limitation; on a slice it names the poles, the precision, the scaling, and that up–down is the
*volume's* coverage midpoint rather than the document's date. A projection onto a stated axis looks
like a measurement, and the plane behind it is not one.

Verified on the iPhone 17 simulator: an axis from `frus1936v04` (China, 1936) toward `frus1949v06`
(Iran, 1949) re-lays the corpus into year bands with the regions still coloured, and returns to the
map when the poles are cleared.

## Session 2026-08-13 — the map gets an address

The semantic map has been a `#if DEBUG` row in Settings ▸ Data & Recovery since V-4a, where it
belonged when it was a *measurement* — can one draw call hold 314,483 points — and where it stayed
through labels, tap-to-open, lasso capture and axis slices, long after it had stopped being one. It
is now **Semantic Analytics**, a sibling of Corpus, Person, Cross-Reference and Archival Analytics,
reached the same way each of those is.

- **macOS**: `Window("Semantic Analytics", id: "frus.semanticAnalytics")`, out of `#if DEBUG`, with
  an Analytics-menu item using the same `bindTool` + `openWindow.fronting(id:)` shape as its
  siblings. `fronting`, not a bare `openWindow(id:)` — `MacWindowFrontingTests` fails the suite if
  one reappears (#749: a bare open leaves an already-open window buried).
- **iOS**: a row in the Analysis Tools menu in `BrowserView`, presented as a `.sheet` like Person and
  Cross-Reference Analytics.
- `ToolWindowID.semanticAnalytics` joins the four existing analytics tools so window provenance
  routes the same way — **and the map's macOS Open Document goes through
  `appState.openDocument(_:from: .tool(.semanticAnalytics), using:)` to make that true.** The first
  version of this entry claimed the routing while the open button minted a standalone window
  directly "matching Citation Lookup", which is the one case `ToolWindowID`'s own doc comment says
  is deliberately excluded from the enum: both launchers wrote a binding nothing read. Routing also
  puts the document where the reader launched the map from, and with no live host `openDocument`
  mints the standalone window anyway, so nothing is lost.

**The iOS sheet was the one thing not to assume.** An `MTKView` in a SwiftUI sheet on *macOS* draws,
presents, and never reaches the screen — that cost two sessions. UIKit presents a sheet as a view
controller, so it *ought* to be fine, which is precisely the reasoning that failed last time.
Verified: the map renders in the iOS sheet at 0.05 ms mean over 314,483 documents. The hazard is
AppKit's, now established by observation on both platforms rather than inferred from one.

**An unplanned improvement, and a correction to it.** The sheet has no tab bar and no iCloud status
banner over it, so the lens picker and point-size slider are fully visible — the reachability problem
that forced the lasso toggle into the toolbar was an artifact of the Settings-tab presentation, not
of the controls. But that observation covered only the bottom controls row: the *toolbar* needs a
navigation container, and a bare sheet supplies none, so the first version of `SemanticAnalyticsView`
took the lasso toggle and the document push away on iOS while appearing to improve reachability. The
view wraps itself in a `NavigationStack` for exactly that reason, as its siblings do.

**The new view says what the surface measures**, which the map never did. Every other analytics
window measures something the corpus states: who is named, what cites what, where a document came
from. This one measures a model's reading of the language, ships **experimental** by the owner
decision that traded a blind quality panel for tester judgement, and carries pre-1900 quality as a
declared unknown. A reader meeting it for the first time learns that in the window rather than from
a release note. The header is dismissible and remembers that it was dismissed.

Semantic Match Feedback stays in Data & Recovery: it is an export-and-diagnostics surface for the
Related Documents axis, not a view of the corpus, and moving it would put a data-management screen
inside an analytics window.

**Two renderer changes the promotion forced, both of them properties of a window a reader keeps
open rather than of a diagnostics row they visit once.**

*The map now draws on demand.* It was configured `isPaused = false` / `enableSetNeedsDisplay = false`
— a free-running display link re-issuing the same 314,483-point draw call sixty times a second, for
as long as the surface existed, to produce an identical frame. That is a fair trade for a spike being
measured and not one for a window left open beside a document. The view is now paused with
set-needs-display on, and every renderer mutator marks the surface dirty: `pointSize`, `camera` and
`aspect` through `didSet`, `setPoints`/`setColourIndices`/`setPalette` explicitly. **The dirty mark
goes to a weak LIST of views, not to one reference**, because SwiftUI realizes this representable
more than once and a single slot could hold the discarded instance — which is the shape of two
earlier blank-surface defects, and would here mean a map that never redraws at all rather than one
that redraws needlessly. Measured on the simulator: opening the map costs **2 frames**, a pan takes
it to 11, and a lens switch to 12. Before this it would have been in the thousands.

That change also broke the statistics overlay's one useful property, which is worth recording because
the fix is not obvious: `StatsSink` published only when a window of 30 samples closed, so a map that
had plainly drawn read `0 frames presented · 0.00 ms mean` — the exact false reading the frame counter
was added to prevent. It now publishes every frame and keeps the timings from the last closed window.

*An axis slice had no way back.* `clearSlice` was written in #880 alongside the slice and **never
called by anything** — grep found one hit, its own declaration. Picking two poles re-laid the corpus,
hid the region labels (the label layer returns none while a slice is active), and left closing the
window as the only exit; re-picking a pole only re-sliced. The previous session's entry states as
verified that the surface "returns to the map when the poles are cleared", which was true of the
method and of nothing a reader could reach. There is now an **Axis card**: it names the poles, offers
*Back to the map*, and — the state nothing else showed — says when the reader is one pole in, having
pressed "Axis: from here" with no indication anywhere on screen that anything happened. That is the
fifth control on this surface found drawing correctly and doing nothing, which is why the review
lens for it is now standing.

The three cards also stacked wrongly: `selectionCard` and `lassoCard` are both bottom-leading
siblings of one `ZStack`, so a lasso result drew *exactly on top of* a selection card, hiding Open
Document and the pole buttons behind a card that looked like the only thing there. They are a `VStack`
now.

*The renderer is main-actor-isolated.* Marking an `MTKView` dirty is a main-actor call — `MTKView` is
`NS_SWIFT_UI_ACTOR` — and the class was nonisolated, so a **clean** macOS build emitted *main
actor-isolated property 'needsDisplay' can not be mutated from a nonisolated context* against this
repo's zero-source-warnings rule. Incremental builds do not recompile the file and reported nothing,
which is the second time that has hidden a warning here. The fix is isolation rather than a hop:
every caller — the `@MainActor` model, the representable — already was on the main actor, and the
class is not `Sendable`, so a renderer built anywhere else could never legally reach the model that
owns it. A comment claiming the opposite ("a renderer is a perfectly reasonable thing to build off
the main actor") is gone; the locked pipeline cache it justified is now a plain dictionary, because
the isolation *is* the synchronisation.

*The frame counter could tick backwards.* `StatsSink` hops each window to the main actor with its own
unstructured `Task`, and independent tasks have no ordering guarantee, so the number that exists to
prove the surface is alive could go down. The model drops a window older than the one it holds.

*The pipeline is compiled once per process.* `SemanticMapModel` builds its renderer in `init`, and a
`@State` initial-value expression is evaluated on **every** initialisation of the view struct, not
only the first; SwiftUI discards the duplicates after the shader has already been compiled. A static
device-keyed cache behind an `NSLock` makes a discarded construction a dictionary lookup. The
ordering fix that put the renderer in `init` — no view may exist before the renderer does — is
unchanged; only its cost is.

## Session 2026-08-13 — the same scope, a different projection

The owner's question: *can the semantic map use the same scope pickers as other analytics features, to
give users a chance to compare semantic slices with other ways to segment the corpus?* Yes, and it is
the cheapest interesting thing this surface can do — the map is the only place in the app where an
editorial, a subject and a political segmentation can be laid against a layout that knows about none
of them.

**It is literally the same control.** `AnalyticsScopeBar(presentation: .chip)` plus the administration
menu, the pair Archival Analytics uses, so the doors are the ones a reader has already opened
elsewhere: by subseries, by volume, my volume scopes, by detected topic, by president. The population
is the **series** — `SemanticVectorIndex.volumes`, the 552 the artifact places — not the reader's
library, for the reason Archival gives: this derivation is bundled and honest with nothing
downloaded. `availability` stays a lens rather than becoming a scope.

**A scope narrows the map without shrinking it**, and that is the whole design. Everywhere else a
scope excludes data from a sum; here the excluded data is the reference frame — *where does the Nixon
administration sit in the corpus's language?* is unanswerable with only the Nixon administration on
screen. Out-of-scope documents stay, desaturated to their own luminance at 22% alpha. Fading alone
was tried and rejected in the same pass: a low-alpha red still reads as red, and a reader comparing a
subseries against the corpus would see two shades of one hue and take both for data.

The mechanism is the `flags` byte `MapPoint` has carried unused since V-4a. A palette slot would have
cost every lens a colour and, worse, would have made an out-of-scope point stop meaning what the lens
says — the reader scopes to a subseries *in order to* see its eras.

**Four things follow the scope, and all four read one array.** The GPU flags, tap picking, lasso
capture, and the count under the chip come from a single `ScopeMask`, because a mask computed twice is
a mask that can disagree with itself. Two of the four are corrections rather than additions: an
out-of-scope point is drawn as ground, so a tap that opened one would contradict the chip, and a lasso
that captured ghosts would build a working corpus out of documents the reader had excluded. The
lasso's TOTAL is gated too, not just the kept rows — an ungated total would make the truncation note
describe a cap that never applied.

**Region labels re-rank rather than merely filtering.** Dropping regions with nothing in scope is the
obvious half; the half that matters is replacing each surviving region's `documentCount` with its
in-scope count, because the label layer ranks by size and keeps a dozen. Rank by the series and a
narrow scope hands its labels to the corpus's biggest regions — which under that scope may hold three
documents each — while the region it actually fills goes unnamed. Measured on the simulator: scoping
to the detected topic *Nuclear Nonproliferation* re-labels the map to `shevardnadze soviet`,
`brazilian goulart`, `salmon constantinople`.

**The grain is stated on screen, and it has to be.** Every scope this control offers is a set of whole
VOLUMES. Scoping to *Nuclear Nonproliferation* lights all 7,702 documents in the 26 volumes carrying
that tag, not the documents about nonproliferation. On a bar chart that distinction hides inside the
bar; on a map the reader watches those documents land in a region called `salmon constantinople` and
the obvious reading is that the model placed them badly. So the summary line says "every document in
26 of 552 volumes" rather than a bare count.

`setPoints` rewrites every byte of the vertex buffer, so the scope is re-asserted after each
re-layout — the same trap that once dropped the lens on a slice and painted the corpus in slot 0.

Verified on the iPhone 17 simulator: Theodore Roosevelt (18,349 documents in 22 of 552 volumes) and
the Nuclear Nonproliferation topic (7,702 in 26). The three new tests are mutation-tested — an
unfiltered label list, a picking scan that ignores the mask, and a mask that admits everything each
turn one red.

**Not done, and deliberately:** a scoped *slice*. The axis projection is computed over every document
and the ghosts are laid out with the rest, which is defensible — the slice's x is a property of the
document, not of the scope — but it has not been thought about properly and no surface claims
otherwise.

## Session 2026-08-14 — where the documents came from, on the map

The design has named this lens since §6.3 and called it the prize: *"A map coloured by provenance
category alone — watch the central files give way to presidential libraries across the space — is a
historian-grade artifact no other FRUS tool has."* It is now built, and it looks like the sentence.

**It is a per-VOLUME reading on a per-DOCUMENT map, and that is stated on screen.** Each volume takes
the archival category most of its source notes name, from the bundled aggregate's schema-2
`byVolume` table, so every point in a volume takes one colour and a volume that drew half its
documents from a presidential library shows only its larger half. A caption under the map says so.
The per-document alternative exists only for downloaded volumes — the FTS5 source notes — and a lens
that meant one thing for an indexed volume and another for the rest is exactly what `yearForVolume`
refused for the slice's y-axis.

**Absence keeps its own slot.** Slot 0 is "No source notes" — **30 of the 552** volumes the map
places are outside the aggregate (522 covered), and **21 of those 30 have a pre-1900 leading year**,
the remaining nine between 1903 and 1919 (eight of them 1903–1906, one 1919): source notes are a later editorial practice, and
the grey region the map shows over the nineteenth-century clusters is that fact. Without a reserved
slot they would have fallen into the first category, `centralDecimalFile`, which is also the largest,
and been absorbed without a trace. The mutation that makes them fall there is one of the two this
session's tests are pinned against.

**An evidence floor, added after the review.** The first version took the arg-max with no floor at
all, so a volume resting on ONE parsed note painted every one of its documents — `frus1898` carries
1,194 documents on the map and one note. Fifteen volumes are in that state (10,339 documents, 3.3% of
the plane) and all fifteen resolve to `unrecognized`. The visible consequence was a boundary a reader
could see and could not explain: `frus1898` took the "Other / Unclassified" colour while its
neighbour `frus1899` (810 documents, no notes) took the absence colour — two adjacent volumes of
identical editorial character separated by whether one note happened to parse, and the new legend had
just given those two greys two different names. The floor is **ten notes**: 24 volumes sit at ten or
fewer and 29 at twenty or fewer, so the curve is flat there and the exact cut is not load-bearing.
Below it a volume joins the absence slot, which is renamed "Too few source notes" to cover both
states honestly.

**`unrecognized` is now the dimmest of the ten**, not the brightest. It was hue 0, saturation 0,
brightness 0.95 — white, the loudest thing on the plane — for the category whose own doc comment says
it is "a citation form the parser could not classify". It wins 55 volumes, 9% of the map, so the
first draft put the map's loudest claim on its weakest evidence.

**Two properties of the real distribution are worth stating, because the picture does not show
them.** Measured over the 522 covered volumes: the winner is `centralDecimalFile` for 311,
`presidentialLibrary` for 100, and **`unrecognized` for 55** — so a tenth of the coloured map is a
confident hue meaning *the parser could not classify these notes*, which is why the legend keeps that
category's own honest name ("Other / Unclassified") rather than inventing one. And **23 of the 522
have a winner holding under 40% of their notes**, so a bare plurality does paint a whole volume; the
caption says the volume shows "only its larger half", and for those 23 the larger half is a minority.

**Ties break on `allCases` order, not on dictionary iteration.** A Swift dictionary has no stable
iteration order, so a volume that drew equally from two files would have recoloured itself between
launches.

**The lens is withheld, not drawn empty, when the artifact predates schema 2** — the
`supportsVolumeScope` posture. An older aggregate carries only `byDecade`, and painting all 552
volumes "no source notes" would say something false about the corpus rather than about the build.

**The legend finally exists.** `SemanticMapLens.legend` has been declared since the V-4 lens work
and drawn by NOTHING for every session since — survivable while the lenses were regions (named on the map itself), a
two-state download flag and an ordered era ramp; not survivable for ten archival vocabularies, where
an unlabelled colour is decoration. Its swatches come from the same `SemanticMapColouring.palette`
the GPU gets.

**The first version of that test asserted the wrong thing**, and the review caught it: it required
`legend.count <= paletteSize`, which is satisfied by naming ONE of sixteen colours — precisely what
`cluster` does. Coverage is now checked against the slots the colouring actually produces over the
shipped artifact, and a lens that cannot name them all must declare it (`namesEveryColour`) and
carry a caption saying why. `cluster` is the only one, because its colour means adjacency and its
regions are named on the map itself.

**Four lenses do not fit a segmented control**, so the picker is a menu. "Provenance" is the longest
name and the first that cannot be shortened without lying about what it shows, and the design lists
more lenses to come.

Verified on the iPhone 17 simulator: the corpus is overwhelmingly the blue of the Central Decimal
File, with lot files and presidential libraries massed on the left of the plane and a grey
"no source notes" region near `borough lincoln` — which is the nineteenth century, and is the
picture the design predicted.

**Not built, and the reason:** subseries and administration lenses. Both are the same per-volume
shape and would take an afternoon, but there are 107 subseries and 32 administrations against 16
palette slots, so both would have to cycle hues — and a cycled categorical colour with no legend is
the decoration this session just finished removing. They need a different treatment (an explicit
highlight-one-and-dim-the-rest, which is what the scope control already does) rather than a lens.

## Session 2026-08-12 — #234 R-1: the no-think re-run, and the measure that needed no ground truth

The fix landed cleanly: `truncated` 231 → **0**, completion **733 → 64 tokens per chunk**, wall clock
**127.68 → 19.27 s/chunk**, scope **501 → ~76 days**. At ~8 returned names per chunk, 64 tokens is
roughly correct JSON — **there is no waste left in the generation half**, so no prompt change
recovers more.

### One reading corrected, in this session's own analysis

The re-run's `unlocated` went 0.8% → 3.6% and was first read here as a quality regression. It is not.
`returned` went **1,634 → 6,667** and *located* **1,621 → 6,423**: it lost 238 strings to gain 4,802.
A rate whose denominator quadrupled is not comparable to the rate before it. Recorded in §4.7 as a
warning rather than quietly fixed, because the misreading was one sentence away from being a
shortlist decision.

### The measure that needs no M2a

Every arm already records `overlapping_marked` and `marked_in_scanned_docs`, and the editors' markup
is a real if partial ground truth sitting on disk. The Python harvester and the Swift control
compute the ratio **identically** (one count per detection overlapping any mark) — checked in the
source, because a cross-source metric assembled from two implementations is exactly the join this
repo keeps getting wrong.

| arm | mentions | landing on markup | editor spans | ratio | mentions/doc |
|---|---|---|---|---|---|
| `NLTagger` control | 71,358 | 3,760 | 13,055 | **28.8%** | 7.2 |
| Qwen3 14 B, thinking | 2,264 | 404 | 680 | 59.4% | 4.7 |
| Qwen3 14 B, no-think | 9,533 | 682 | 680 | **100.3%** | 19.9 |

**It is not recall** — two detections on one span count twice, which is how a row exceeds 100%. But
double counting only pushes a figure up, so each is an **upper bound**, and the control's is the
load-bearing one: **`NLTagger` misses at least 71% of the mentions the editors themselves marked.**
Equally: the metric rewards over-detection, the no-think arm returns 19.9 mentions per document
against the editors' ~1.4, and its precision is unknown. That is what §6 is for.

### The cost, decomposed, and a call this session got wrong

Two runs over the same chunks with the same prompts solve to **decode ~6.2 tok/s, prefill ~75 tok/s**
(8.9 s/chunk), decode still 54% of the clock, and a **~35-day prefill-only floor** for the scope.
§4.2 assumed 350–600 tok/s prefill for an 8 B; the table was wrong about the dominant term.

Before the re-run this session argued the fix would flip the machine advantage to the Air, since
prefill is compute-bound and the M5 is newer. The measured 75 tok/s says compute is the bottleneck
and the Air is bad at it — the ride-along's own table has the M1 Max at ~10.4/21 TFLOPS against the
Air's 2.5–8 sustained. The correction is recorded in §4.8 rather than deleted.

Sequencing now: **(1)** the Studio pilot, one variable, plausibly 2–4×; **(2)** concurrency, which
§4.2 already calls the largest remaining lever and the harness still does not exploit; **(3)** M2a,
which is the critical path — two arms disagree by 2.8× on mentions per document and nothing
available says which is right.

## Session 2026-08-14 — #829c: the ranking gets a third body of evidence

The Collections ranking's Count by control gains **Unprinted pointers**, ranking each collection by
the editorial footnotes pointing at material there that FRUS did not print. With (a) and (b) shipped
in #886, all three of #829's parts are now built.

**A weight SWAP, never a sum**, and the derivation is where that is enforced rather than the copy:
`ArchivalCollectionsData` gains its own `collectionPointers` table, banded by the **citing** volume's
coverage — the same rule the other two use, which is what keeps the bands a partition and lets a
multi-band ranking add them. Nothing adds a pointer total to a usage count; that addition is the
defect #783 removed.

**The evidence for "swap" is visible, and a test asserts it.** Measured on the shipped artifacts for
1948–1960: under Documents the Whitman File leads at 1,643; under pointers it is third at 472, behind
S/S–NSC (Miscellaneous) Files: Lot 66 D 95 at 859. `pointerWeightReplacesTheRowSet` requires the two
row sets to differ in both directions — a pointer-only collection must exist, or the pointer table is
being filled from the usage index.

**Four places assumed two weights and each was a different kind of wrong:**

- The **picker** dimmed as a whole when Documents was unavailable, which was right when the two
  weights failed together. They no longer do — pointers are unavailable on the class lens while
  Documents is fine — so the gate is now per option, via `supports(_:for:)`.
- The **class lens** has no pointer vocabulary at all: #784's harvest reads lot files and
  presidential libraries and never a decimal class. `ranking()`'s switch handles the combination
  explicitly (empty), the UI disables it, and the caveat block says why. Verified on the simulator:
  switching to classes under pointers falls back to Volumes rather than drawing an empty chart.
- The **ranking caption** said volumes "draw on" N collections regardless of weight, which is false
  above a pointed-at chart. It branches on `ArchivalWeight.measuresPrintedMaterial`.
- The **export's base caveat** describes parsing source notes to find where documents were drawn
  from — work a pointers export did not do. It is SWAPPED for `pointerBaseCaveat`, following
  `flows(...)`'s precedent in the same file, rather than appended to. Two contradictory methods
  statements in one CSV is worse than one wrong one, because a reader trusts the first.

**`shownShare` was already right and now says why.** It is gated to `.documents`; the denominator is
the band's source-note count, and a footnote-pointer count is not a share of it. The gate happened to
be correct for the new weight too, so the doc comment now records that it must stay that way — the
"percentage" it would otherwise print divides two unrelated populations.

Three shipped strings asserting a two-weight world were rewritten with new keys, the label-uniqueness
sweep goes 40 → 60 combinations, and the export suite's `weightCaveat` loop over `allCases` now
covers three.

Every figure on screen was predicted from the raw artifact before it was looked at: 859 / 508 / 472,
and 474 collections in the band. 3,478 unit tests (+4); clean macOS build.

## Session 2026-08-14 — the UI adversarial review becomes the plan of record for UI work

The owner commissioned three per-platform adversarial UI reviews (2026-08-13) plus Semantic
Analytics addenda (2026-08-14) and a consolidated handover; the package is now committed at
`Planning/Cross-Platform-UI-Adversarial-Review/` and is **the next priority**: 69 findings
(Critical ×2, High ×19, Medium ×30, Low ×18) consolidated into twelve work items CW-1…CW-12 in
three waves, with reuse opportunities O-1…O-6.

**Assessed against the decision record before adoption.** Five load-bearing claims were spot-checked
against `v2` and all held (undated slice volumes plot at `Float(0)` — dead centre; `MagnifyGesture`
is the map's only zoom input; the selection card headline is raw ids; the iOS sheet has no
`presentationSizing`; `eraCounts` has no reader). Nothing in the 69 findings resurrects a rejected
decision — the review keeps free-text poles deferred and works around the recorded rejections. Three
gates recorded at adoption: the **figure half** of the export ask (X-6) waits on a texture-readback
proof, per §13.9's own hand-rendered-surfaces doctrine; MR-13's slice scale must keep the
volume-midpoint y-axis (#880's decision), adding ticks and a gutter rather than per-document dates;
and F-29's tappable labels must use the sibling-in-ZStack treatment, since `.allowsHitTesting(false)`
is what keeps overlays from swallowing the surface's gestures.

**Overlaps folded into existing plans rather than duplicated:** M-21/F-29/O-3 = the backlog's
`eraCounts` consumer; O-2/O-4 = anchor-document mode + the semantic scorer gap; O-6 = subseries
poles (poles, NOT the rejected subseries lens); CW-11 = #106; CW-12 = the Dynamic Type worklist;
CW-9 overlaps #824; the VoiceOver items join #268/I-1; F-25 rides the R-7 iPad-windows program.

## Session 2026-08-14 — Wave 1 finishes: the compact map, the summary dedup, Print restored

The rest of the UI review's Wave 1, on top of #889.

**CW-5 — one card at a time on the phone (P-13), and the chrome folds (P-14).** At compact width
the axis/selection/lasso stack gives way to pills naming what has content plus the newest card
alone — the reader's explicit pill choice wins while it still has content. The point-size slider
folds behind a "Display options" disclosure at compact only. Verified on the simulator: with an
axis and a selection live, the map keeps most of the sheet, and tapping the Axis pill swaps the
card in place.

**F-15 — the reader stops showing the same summary twice.** On iPad with the rail open (the
default), the strip above the document and the rail's Summary accordion rendered the identical
text simultaneously, filling the first screenful twice. The strip now yields while the rail is
visible; iPhone (transient sheet) and Read mode keep it.

**M-14 — Print is back on ⌘P, and the reserved shortcuts go home.** `File ▸ Print` routes through
the same focused-scene value as the Document menu and runs the key window's web view's own
`printOperation` (the zero-frame print-view gotcha is handled and documented). Project Home moves
⌘P → ⌘⇧P; Search moves ⌘S → ⌥⌘F, the global-search convention, beside ⌘F find-in-document and
⌘⇧F Citation Lookup.

**M-11 — Sync Error is a button.** The status bar's failure state opens a popover with the message
in selectable text and a link into `SyncDiagnosticsView` — the diagnostics surface the label never
connected to.

**P-9 was already fixed** before the review shipped: the year-range chip's popover has typed,
clamped year fields (`yearEntryField`). The review read the pre-chip chrome. No work; recorded so
nobody scopes it again.

Remaining from Wave 1 after this session, deliberately: P-1 (the Corpus Analytics compact
clipping — needs its own layout investigation), F-12 (the facet inspector at regular width), and
the find-in-document/commands lift that CW-6 owns.

## Session 2026-08-14 — Wave 1's residue: P-1 does not reproduce, and the facet inspector

Two items were left from the previous session. One of them turned out not to exist.

**P-1 does not reproduce, and its evidence is stale.** The review's finding is that Corpus
Analytics clips its controls at compact width, and the evidence is a screenshot of **Build 26**.
The app is at build 40, and that chrome was rebuilt in between: the steppers the screenshot shows
are now chips, a legend was added, and a landscape hint sits under the chart. Driven on the
simulator at compact width, nothing in the finding's description is on screen to clip. X-8 of the
review says the committed shots are stale; this is the first Wave-1 item where that mattered
enough to change the answer. **Nothing was "fixed" here, because nothing was broken** — recorded
so the finding is not re-scoped from the screenshot a third time.

What IS wrong at that width is smaller and was found by looking rather than by reading: the
filter chip row scrolls horizontally and the last chip ("By Year") is cut by the trailing edge
with no cue that the row continues. It now carries a trailing fade, **measured rather than
assumed** — `.onGeometryChange` on both the content and the viewport, and the mask is applied only
when the content actually exceeds the visible width, so a row that fits is not dimmed at its edge
for no reason.

**F-12 — iPad gets the facet panel as a trailing inspector.** Faceting is an iterative loop: tap a
year, watch the list narrow, tap a person, back out one. A sheet forces open → tap → dismiss for
each step and hides the very results it is narrowing. `FacetPanelView` was already written to be
shared ("only the container differs") and the macOS window has shipped it in an inspector since
R-1c, so iPad now gets the same container while iPhone keeps the sheet with its detents.
`facetPanel(dismissesOnApply:)` is the one seam: **true** in the sheet, which must close to reveal
the results behind it, **false** in the inspector, where staying open beside them is the entire
point.

The `isPhone` guard is load-bearing in a way worth stating: both modifiers read the same
`showFacetSheet`, so without it an iPhone would present the sheet AND the inspector (which SwiftUI
renders as a sheet at compact width) from one tap. Gating on idiom rather than size class means
exactly one of the two bindings can ever be true on a given device.

Verified on iPad Pro 13-inch: 120 matches for "blockade", panel opens beside the results, Years →
1861 → Apply narrows to 10, the "Narrowed by 1861" chip appears, **and the panel is still open**.

**Found while verifying, not fixed here: Skip in onboarding is a dead end.** `ContentView` routes
to onboarding unless the flag is set AND at least one volume is on disk or queued — deliberately,
so a user who deleted everything is re-onboarded rather than dropped into an empty app. But the
wizard offers **Skip** on the download step, and Skip enqueues nothing. Tapping Skip then Finish
therefore writes `hasCompletedOnboarding = true`, creates the default project, and returns the
reader to the Welcome page, with no way past it. Measured on the simulator: the flag and
`activeProjectId` are both written, so the button fires and the routing sends them back. This is a
first-run trap on every platform, not an iPad bug — it is filed rather than patched here, because
the fix is a product decision (let Skip through to an empty-state app, or stop offering it) and
does not belong in a UI-review PR.

## Session 2026-08-14 — CW-6a: the keyboard iPad, and a finding that was already false

Wave 2 opens with the review's only CRITICAL finding, F-6: the entire `.commands` block sits
inside `#if os(macOS)`, so a Magic Keyboard researcher on iPad gets nothing — no menu bar
contribution, nothing in the ⌘-hold HUD. That much reproduces exactly. **Its proposed remedy does
not**, and neither does the finding stacked on top of it.

**The lift is not a gate removal, and could not have been.** Un-gating the existing block does not
compile on iOS: it reads `@Environment(\.openSettings)`, which is `@available(iOS, unavailable)`;
it calls `openWindow.fronting(id:)`, an extension declared inside `MainWindowView`'s own
`#if os(macOS)`; and it embeds `HistoryMenuContent`, a macOS-only type. Past compiling, the
Analytics, Research and Collection menus front `Window` scenes iOS does not have. So iOS gets a
second, smaller `.commands` block. What IS shared is the half that was already shareable:
`DocumentMenuContent` moved out of the fence unchanged, and the whole `DocumentCommandActions` /
`FocusedValues` value layer was already outside every `#if` — a 2026-07-04 comment says it was
left ungated so the iOS simulator's unit tests would exercise the equality contract, which turns
out to have done half of this work two waves early.

**The publisher is where iOS genuinely differs, and the difference was measured rather than
reasoned about.** On macOS every reader owns a window, so "the key window's document" is
unambiguous. iOS puts every reader in ONE scene: the Browse and Search tabs can each hold a live
`DocumentView`, and seven more sites present one in a sheet over the first. If they all published,
the winner would not reliably be the one on screen — a ⌥⌘↓ that turned the page of a hidden tab's
document is worse than no shortcut. So `DocumentView` publishes only while on screen
(`ownsKeyboardCommands`), and the claim/release was then **driven on an iPad simulator with the
transitions logged**: opening a document in the Search tab claims; switching to Browse releases;
returning re-claims. Exactly one claimant at every point, and a returning tab does re-claim —
which is the half that would have left the menu permanently dead if `onAppear` had not fired again.

Five of the eleven published closures are deliberately inert on iOS, and each omission is a
property of the platform: no `printDocument` (iOS has no print path here at all), no
`findNext`/`findPrevious` (`UIFindInteraction` owns those inside its own bar, and a second owner of
a system key is the defect #363 #2 removed on macOS), and `openInNewWindow` gated on
`supportsMultipleWindows` like every other door to it. `isResearchPanelVisible` reads
`railToggleActive`, not the raw `panelVisible` — on iPhone the rail is a sheet and the stored key
merely shadows it, so the menu toggle would have shown the wrong checkmark on every iPhone.

**F-7 is false as written, and was false before the review shipped.** It claims
`isFindInteractionEnabled` "appears once in the codebase, in MacDocumentView.swift:1299" and that
the iOS web view "never enables UIFindInteraction". The live assignment is
`FRUSDocumentWebView.swift:588`, on the iOS path, added by #363 #5 on 2026-07-22 — three weeks
before the review was written. The line the finding cites is a doc comment that says the opposite
of what it was cited for: "macOS `WKWebView` has no native find bar (unlike iOS, where
`isFindInteractionEnabled` provides one)". So a hardware ⌘F and the selection edit menu have raised
the find bar on iPad for a month.

The real residue is narrower and still worth fixing: nothing ever called
`presentFindNavigator`, so a reader with no keyboard and no selection had no way in.
`DocumentFindPresenter` is that way in — deliberately not the iOS half of
`DocumentFindController`, because that type exists to hand-build a find UI macOS lacks, whereas
iOS ships the whole thing and needed only an opener. Verified on iPad: the new toolbar button
raises the system find bar, and typing *Havana* highlights the match and reports "1 of 1".

Also delivered, without new code: **F-10's keyboard half**. ⌥⌘↑/⌥⌘↓ now turn the page, routed
through `navigateToAdjacentDocument`, so the keyboard replaces the top of the stack exactly as the
edge tap does rather than appending the way macOS does (audit M-17a). It is deliberately NOT gated
on `edgeTapNavigationEnabled`: that setting exists because a touch zone at the margin misfires, and
⌥⌘↑ cannot be pressed by accident — gating it would take page-turning away from the keyboard user
who switched the zones off precisely because they have a keyboard.

Deferred to CW-6b with reasons rather than silently: F-9 (the `.help` sites), where the finding is
also partly wrong — `.help` sets the accessibility hint on iOS, the rail tiles do render captions,
Share already uses the repo's own `controlHelp` fan-out, and a TipKit tip in the iPad reader is the
one thing this codebase has already been burned by (a watchdog kill, `DocumentView` 1084-1094).
F-10's visible chevron and F-8's drag-and-drop pass follow.

## Session 2026-08-14 — Onboarding's Skip was a dead end, and the routing rule had no seam

Found while setting up the CW-6a verification, and worse than the thing being verified: **the
first-run wizard offered a Skip the reader could never come back from.**

`ContentView` left onboarding only when `hasCompletedOnboarding` was set AND a volume was on disk
or queued. That AND is deliberate and still right for the case it was written for — someone who
deleted every volume should be re-onboarded rather than dropped into an empty app. But Skip
enqueues nothing, so Skip → Finish wrote the flag, created the default project, and returned the
reader to the Welcome page permanently. Measured on an iPad simulator before touching anything:
both `hasCompletedOnboarding` and `activeProjectId` are written, so the button worked and the
routing sent them back.

**Decision: let Skip through**, rather than removing it. A great deal of this app needs no
downloads — the bundled manifest the Browse tab lists and downloads from, the word-cloud vectors,
the semantic map's 314,483 placements, every archival-analytics index. Declining 3.3 GB on first
run is a reasonable choice and should not cost the reader the app. Removing Skip would also have
left the same trap reachable another way (below).

**The flag is keyed on the outcome, not on the button.** `hasFinishedOnboardingWithoutVolumes` is
set whenever onboarding completes with nothing on disk and nothing queued. Skip is the usual road
there, but a scope that enqueues nothing — offline, or one resolving to no volumes — traps a
reader who tapped Continue in exactly the same way, and a fix that keyed on the Skip button would
have left that standing.

**The routing rule moved into `AppRootRouter`, a pure function, and that is most of the change.**
The trap shipped past a green suite because every existing test covers `OnboardingCompletion`'s
side effects — all of which *succeed* on the trapped path. What was untested was the decision made
afterwards, and a decision inside a view body has no seam a test can reach. Six tests now pin every
branch, including the deleted-everything case the AND still protects.

**Two #753 tests broke, and converting them was the right repair rather than a chore.**
`BootStateHonestyTests` pinned the M-20 ordering by SCANNING `ContentView.swift` for literals —
its own header says why: "absence of a lie has no runtime signature without a UI harness driving a
half-booted app." The extraction deletes the strings it matched, so two assertions went red while
the behaviour was unchanged. They now drive `AppRootRouter` directly, which is what that header
wanted: the old versions passed on the *presence of a line of text* and would have kept passing if
the branches were reordered into the wrong answer.

An adversarial review over the diff (four lenses, every finding then challenged) raised the same
test breakage from three independent directions and recommended the same repair. Its other
findings did not survive: the Search tab's empty-corpus copy branches on `indexedVolumeIds` and was
already reachable; the manual offers three routes to add volumes; and the flag surviving volume
deletion is the state the fix deliberately ships, with both supported reset paths clearing it.

Also fixed, because Finish now leads somewhere: the Ready step promised "Volumes download and index
automatically — search unlocks in minutes" on a path where nothing downloads and search never
unlocks. An empty finish gets copy that is true instead.

## Session 2026-08-14 — CW-6b: the pointer iPad, and a stranding bug found by review

The rest of CW-6. Two findings and one defect that the CW-6a review turned up on its way past.

**F-9 — the explanations reached a Mac pointer and nobody else.** The finding says `.help` "which
iPadOS does not render", and that is half right in a way that changes the fix: the iOS 26 SDK
documents `View.help(_:)` as setting **the accessibility hint** as well as the macOS tooltip, so
VoiceOver has always spoken these sentences on iPad. The gap is a *sighted* reader. Two more of
its clauses are simply wrong — the tiles are not "cryptic glyph tiles" (`tileLabel` draws a
caption under every glyph), and Share is not a `railTile` on iOS at all (it is a `Menu` that
already carries `controlHelp`). So the true finding is **non-adoption**: this repo built
`controlHelp` in Session 162 for exactly this problem and reached 30 sites against ~79 iOS-compiled
raw `.help` calls, five rail tiles among the misses.

Both halves are now fixed. The tiles route through `controlHelp`, which adds the VoiceOver hint
and the Large Content Viewer entry they lacked; and the rail header gains a `FeatureInfoButton`
whose six rows are the same sentences, so a sighted iPad reader can read them at last. **Not a
TipKit tip** — `DocumentView`'s own note records that a tip presented in the iPad reader drove a
view-graph update loop, 90s of CPU in 101s and a `scene-update` watchdog kill at 10s. A popover the
reader opens cannot present during that reflow.

It cost no new copy, because the six captions and sentences moved into `RailTileCopy` first. They
had been written inline at every call site, and the macOS and iOS tile blocks each carried a full
set — so each string existed twice before the popover wanted it a third time. Now once.

**F-10 — the page-turn zones show their chevrons on iPad.** The review says "macOS has chevrons",
and macOS does not, quite: `edgeNavChevron` renders at `.opacity(0)` until the pointer enters, so a
Mac user not currently pointing at that edge sees nothing either. Copying it would have shipped the
finding rather than a fix, since a touch iPad never hovers. The iPad chevron rests visible but
quiet at 0.35 and brightens under a pointer. iPhone keeps the invisible zone: the tip teaches it,
and Wave 1's 70ch measure — which put ~150–250 pt of clear margin either side of the iPad column —
does not bind at phone width.

**The stranding bug.** `SemanticMapSpikeView` was the one of nine iOS `DocumentView` hosts passing
no `onNavigateToDocument`, so a page turn inside the map's sheet fell back to
`appState.openTab(.browse)` and threw the reader out to the Browse tab — losing the map, the lens
and any lasso behind it. That is the #750 defect the handler exists to prevent. Found by the
adversarial review of CW-6a, in code this program shipped three sessions earlier.

Verified on iPad: the info popover lists all six tools; the chevrons render in the margins clear of
the reading column and turn the page (No. 186 → No. 181) with the reader staying put. 3,491 tests
pass; both schemes clean-build with no warnings.

## Session 2026-08-14 — CW-7a: the map gets an exit, and a way in

Wave 2's third item. All four CW-7 strands were verified against the build first; all four
reproduce, and — unlike CW-6 — the review's descriptions are largely accurate. What the
verification changed was the *shape* of the fix, twice.

**The map can be exported, and the export is CSV only.** Manual §13.9 promises every analytics
chart a figure or its data; the map had neither and is not among §13.9's named exceptions. The
data half is now a 30-line adoption of machinery the app already owns — `SeriesExportBox`,
`AnalyticsSectionExportControl`, `ChartInspectorData`, `AnalyticsProvenance` — which the map was
simply never wired into.

**The figure half is refused in writing rather than deferred**, because it is not an adoption.
`AnalyticsFigureExporter` drives `ImageRenderer` over a SwiftUI view; the map is a Metal
point-sprite pass inside an `MTKView`, and `ImageRenderer` captures the SwiftUI layer tree, not a
`CAMetalLayer` drawable — it would render a blank plate. The two real routes are an offscreen
Metal pass into a private texture, or a drawable readback the view cannot do (`framebufferOnly`
defaults to true and nothing in the repo clears it, and it would capture the viewport at screen
resolution rather than a publication plate). `AnalyticsSectionExportControl` supports a CSV-only
surface by construction: omit `exportFigure` and the PNG/PDF items do not exist. Verified on the
iPad — the menu offers one item.

**What the table contains was the real design question.** "The data behind the map" read literally
is 314,483 coordinate rows, which nobody can check against anything. The regions table is the grain
a reader can audit: 179 rows, every one a label they can see, ranked by the map's own comparator so
the top of the file is the set of names on screen. It gives `eraCounts` its first reader — the
artifact has shipped a per-region era histogram "so a cluster tooltip can say *when* as well as
*what*", and nothing in the app had ever read it.

**One caveat was a trap.** `AnalyticsProvenance`'s default corpus sentence says counts "cover only
the N volume(s) indexed on this device". True for every other analytics surface; false here, where
the artifact is bundled and draws all 314,483 documents with nothing downloaded. Shipping the
default would have put a false methods statement in a file written to outlive the screen. The
export supplies its own, and a test pins it.

Verified by prediction: the expected row count, top row and era histogram were computed from
`semantic-map-index.json` before the app was opened, and the exported file matches — 179 rows, top
row `nanking shanghai hankow chinese` at 38,652, and the era columns summing to 226,276, which is
both the Documents column's total and the artifact's own clustered count.

**F-30 needed correcting before it could be fixed.** The finding reads the
`.accessibilityElement(children: .contain)` at the body root as the map's accessibility provision.
It is not: that is the shared #219 idiom every sibling analytics view uses to supply a screen name
where iOS drops the navigation title, and `.contain` exists to *keep* children navigable. The
cards, the slice scale and the drawn region labels are all announced already. What a VoiceOver
reader cannot do is **create** a selection — selection and lasso each have exactly one producer, a
spatial gesture on an `MTKView`, which is not an accessibility element and never can be.

So the fix is a route in, not a caption: `.accessibilityRepresentation` over a region list, the
app's own idiom for a drawn surface (`CrossReferenceGraphView`, `WordCloudView`), where each row
selects that region and lands on the existing selection card. It lists every region rather than
the ~22 the canvas fits, and its header states what it cannot cover — 88,207 of 314,483 documents
sit between regions. Placement is load-bearing: above `unavailableOverlay`, because
`.accessibilityRepresentation` replaces its subtree and attaching it lower would have swallowed
the "Map unavailable" message, leaving a VoiceOver reader with an empty list and no explanation.
Filed iPad-only; fixed ungated, since the same view is the Mac window.

Deferred with reasons: Handoff (F-28's second half) and a *visible* region tap. The tap needs
care the CSV did not — `select(at:)` hit-tests within a radius converted through the camera scale,
so a region's centroid can fall outside a zoomed view and the affordance would read as dead; the
accessibility route sidesteps it by framing first, but a touch affordance cannot.

## Session 2026-08-14 — CW-7b: the regions become tappable, and eraCounts finds its reader

CW-7's third strand, F-29 / M-21: region names drew with `.allowsHitTesting(false)` while the
bundled artifact carried a per-region era histogram — shipped, in the artifact's own words, "so a
cluster tooltip can say *when* as well as *what*" — that nothing in the app had ever read.

**The tap is resolved inside `select(at:)`, not by making labels hit-testable, and that is the
whole design.** `labelOverlay` is an `.overlay` of the Metal surface and the tap/drag/magnify
gestures are applied *after* it, so they wrap it: turning those `Text`s into `Button`s reproduces
the failure this file already documents twice, where the control highlights and nothing happens.
Resolving the tap inside the existing gesture introduces no new hit-testable view at all, so
`.allowsHitTesting(false)` stays exactly as it was.

Two arithmetic rules carry the card, and both fail silently if broken — which is why they were
extracted to `SemanticMapRegionRows` and pinned rather than left inside a `private var`:

- **Identity comes from `clusters`, not `labelledClusters`.** The latter substitutes the in-scope
  count into `documentCount` while leaving `eraCounts` whole-corpus, so a card built from it would
  print era rows that do not sum to its own headline — on the surface whose stated job is being
  honest about what it can say. The in-scope figure is read separately from `scope.regionCounts`
  and shown beside the total.
- **Only the eras present are drawn, and an unrecognised key is kept.** Iterating
  `CoverageEra.allCases` would print a permanently empty "1991–present" on every card in the
  shipped artifact, and a zero row is a claim about the corpus rather than a missing value. The
  generator emits `"unknown"` for a volume with no parseable coverage year, and `"3"` becomes
  reachable the moment a post-1991 volume enters the manifest; both are pooled into one row rather
  than dropped, so the rows still account for the headline.

The hit test measures against the **laid-out label position**, not the projected centroid:
`SemanticMapLabelLayout` nudges a name into an inset so it stays readable near an edge, which can
move it well off its region's centre. The reader aims at the word they can see.

Verified on iPad against the artifact: tapping `nanking shanghai hankow` gives 38,652 documents
with 2,275 / 27,049 / 9,328 across the three eras present and no fourth row — the same numbers
`semantic-map-index.json` carries, and they sum to the headline.

Remaining in CW-7: Handoff (F-28's second half). It is not a view change — the macOS window is a
valueless singleton with no initializer that can be handed a state, so it needs either a new
scene-level request type plus the `SceneID`/`Handoff` plumbing the other aux windows use, or a
conversion to a value-based `WindowGroup`. Its own PR.

## Session 2026-08-14 — CW-7c: the map can leave the device

CW-7's last strand, F-28's second half: documents have published an `NSUserActivity` since the app
shipped and no analytics surface ever has, so an analysis built on the iPad could not continue on
the Mac. The map now publishes one, and both platforms continue it.

**The payload is scope and lens, and the omission is the interesting part.** Most of the map's
state is not portable — the camera is a live projection, the lasso path is view points at the
sender's surface size, `SemanticAxis` carries a 256-float direction that is rebuilt from two volume
centroids anyway. What survives a trip between devices is what the reader *chose*.

**The slice poles are deliberately not carried, and the reason is a trap the verification found
rather than a preference.** `setScope` tolerates arriving before the artifact has loaded — it
stores `requestedScope` and `prepare()` re-applies it — but `setPole` does not: it records the pole
and then hard-returns when `centroid(forVolume:)` finds no index, leaving `poles` populated and
`slice` nil. The axis card renders on `poles.negative != nil`, so a continuation that set poles
before the map loaded would leave a half-drawn axis card naming a pole with no slice, permanently
and with no retry — the same "renders and does nothing" class this surface has already shipped. A
continued map opens unsliced; carrying poles needs a `requestedPoles` deferral inside the model
first, and that is a model change rather than a Handoff one.

**The registration is the part that would have made the whole feature silently dead**, and nothing
in the repo pinned it. Handoff routes an activity only if its type is declared in the target's
`Info.plist` under `NSUserActivityTypes` — publishing and continuing can both be perfectly wired
and nothing happens. The plists are generated by XcodeGen from `project.yml`, so a hand-edit is
reverted by the next `xcodegen generate`. `activityTypesAreRegistered` reads the built app's own
plist and was mutation-tested by deleting the declaration from `project.yml` and regenerating: it
fails, which is what makes it worth having.

Two source-scanning tests failed on correct changes and were repaired rather than relaxed:
`HandoffVisibilityTests`'s `.onAppear` scan had a 1,400-character budget that a fifth consumer
pushed an existing one past — the budget is a scan limit, not a claim about how long the drain may
be, so it was raised and the new consumer added to the required list; and
`SemanticAnalyticsEntryPointTests` matched the sheet's `SemanticAnalyticsView(appState: appState)`
call verbatim, which now takes a `continued:` argument.

**Verified by me: everything except the handoff.** The payload round-trips, an absent scope reads
as the whole series rather than an empty one, a payload with no lens is refused, an unknown lens
survives for an older build to ignore, and both plists carry the type. The hop between devices
needs two signed-in devices and is the owner's.

CW-7 is now complete apart from §13.8's screenshots, which are the owner's by standing convention.

## Session 2026-08-14 — CW-8a: the matrix's numbers, and a count that said "1 volumes"

Wave 2's last item, verified first as usual — and the verification is most of the story. Of the
five findings CW-8 carries, **two are substantially false**, one is an architectural opinion whose
named exhibits are both healthy, and two are real.

**P-2 is real, and the fix was already written.** The 15×15 volume heat matrix encodes a cell's
count as fill opacity and nothing else — the export's own doc comment has said so since it was
written ("these counts are otherwise unreadable"). At ~707 pt of content on a ~393 pt screen it is
also wider than the phone, nested in a second scroll view. The only route to a number was to write
a CSV and leave the app.

The finding's own phrasing repeats this review's recurring error — "tooltips are `.help(...)` —
which iOS never renders" — and it is half wrong in the way already recorded in STATUS.md: `.help`
sets the accessibility hint on iOS, and more to the point the cell already carries an explicit
`.accessibilityLabel` naming both volumes and the count. **A VoiceOver reader has had these numbers
all along; a sighted touch reader had none.** That is a narrower and more useful statement of the
defect.

The fix is an adoption, not a build. `ChartDataInspectorView` already renders a `ChartInspectorData`
as a plain list at compact width and a `Table` at regular; `AnalyticsChartTables.crossRefMatrixTable`
already builds exactly the right ranked edge list, zero pairs dropped; `ArchivalAnalyticsView` already
shows the button-plus-sheet pattern. None had ever been pointed at this matrix. The table was also
extracted out of `exportMatrixCSV`, so the screen and the CSV are now one value and cannot diverge.

**P-4 is mostly false.** Its headline — a legend whose six entries all read "Foreign Relations of
the…" — was fixed on 2026-06-18 by `distilledVolumeLabel`, two months before the review shipped;
emulated over the shipped manifest, all 552 labels are distinct. Its "untappable" clause is also
false: a `.chartOverlay` resolves a tap by nearest bucket, so the 1 pt bar width is irrelevant to
the hit test. The review's figure was captured from a pre-June build — the third finding in this
program whose evidence is a stale screenshot, which is X-8 doing exactly what X-8 says.

What survives is the pluralization: `aggregateLine` read **"1 volumes · 1 subseries"**, and on a
day-grouped chronology a single-volume day is the common case, not an edge one. Fixed with the
app's own `count == 1 ? "" : "s"` form rather than a stringsdict, because six other sites are
written that way. Extracted to `ChronologyAggregateText` so the inflection is testable at all.

Deferred, with reasons: **P-3** (the concordance's columns) is real but needs a designed compact
form rather than a wiring change; **P-7**'s key claim is false for the cross-reference graph, whose
list panel is already a peer of the canvas rather than buried in it; **P-8** is an architectural
opinion whose two named exhibits are both healthy — Cross-Reference Analytics is the *least*
crowded surface in the family, its "worst-crowding view" comment falsified by #209 thirty minutes
after it was written — while the surface that genuinely truncates, Archival Analytics' mode picker,
is not the one it names. That last one deserves its own change and the owner's call on whether
folding four visible segments into a menu is the trade they want.

## Session 2026-08-14 — CW-11a: the guide gets a door, Settings gets a search, and X-8 gets its rule

Wave 3's documentation item, minus the screenshots. Three of its four parts are adoptions of
machinery the app already owns; the fourth is the rule the whole program has been supplying
evidence for.

**F-14 — the Research Guide had no door on the tab named after it.** The app's educational core,
and the host of the four Series Analytics dashboards, was reachable on iPad only through
Settings ▸ About ▸ FRUS Research Guide: a sheet presented from a pushed pane inside a different
tab. The archival review had already indicted that path ("five levels deep in a reference modal")
when it blocked relocating analytics there. It now sits at the top of the Research tab, one tap,
using the same `ResearchGuideView` — a door, not a move, so a reader who learned it lives in
Settings still finds it there. Verified on iPad.

**M-16 — the Mac Settings sidebar never called the matcher it shares with iOS.**
`SettingsPane.matches(_:)` has existed since S-1 and iOS filters thirteen panes with it; the macOS
sidebar rendered the same shared model with no filter at all. One `.searchable` on the sidebar
column and the same `if !visible.isEmpty` guard iOS uses. The selection is deliberately not cleared
when a query hides the selected pane — the detail keeps showing what the reader was reading, and
clearing the field brings its row back; blanking the detail on a keystroke would be worse.

**X-8's ledger rule is now written down** (`STATUS.md` §1a), and this program supplied its evidence
three times over: P-1's Build-26 screenshot, P-4's legend figure captured before a 2026-06-18 fix,
and the four iPad shots predating #238. The rule is three sentences — a screenshot is evidence
about a *build*; the commit that retires chrome is the commit that marks its shots stale; a finding
whose only evidence is a screenshot is unverified until re-driven. The re-captures stay the
owner's; what is written here is the discipline that says which ones are owed.

`STATUS.md` also gains the four findings this wave corrected — P-2's `.help` clause, P-4's legend
and tap claims, P-7's list-panel claim, and P-8's stale "worst-crowding" comment — bringing the
corrected-by-measurement table to eleven entries.

---

## Release 2026-08-17 — TestFlight build 42 (v0.2), both platforms

Tagged **`build-42`** at `724d87c1`. The tag is annotated and carries the summary, the re-index
requirement and the CloudKit position, because this session lost real time reconstructing what
build 40 had contained — `git show build-42` should stop that happening again.

**The headline is Semantic Analytics, and it is wholly new to a tester.** Build 40's tree has no
`FRUSExplorer/Semantic/` directory and no semantic resources at all; its shipped notes never mention
the map. So the tester notes introduce the map, its regions, its slices, reveal-from-a-document and
the ten nearest documents from scratch rather than narrating changes to them. Also in the range: the
iPad two-pane Browse and Research, six macOS analytics windows that raise rather than duplicate, the
Search window's titlebar and filter tokens, Settings' search field, Unprinted pointers in Archival
Analytics, and a plain-language pass over about thirty explanatory passages.

**A full re-index is required on first launch** — `currentDateIndexVersion` 36 → 40 and
`currentPersonRollupVersion` 8 → 9, and that constant's own doc comment says a date bump triggers a
full clean reindex. The first draft of the notes claimed no re-index was needed; comparing
`IndexingPipeline` between the two commits is what corrected it, and "let the re-index finish —
roughly how long?" is now the first thing asked of testers.

**No CloudKit deploy.** `identifiersAwaitingDeploy` is empty and Production is deployed through
build 40.

**Two baseline facts worth keeping**, because both were unrecoverable from the repo alone and had to
come from the owner: build 41 was never released, and **build 38 was iOS-only** — which is why the
two platforms carried different "since" baselines before this release, and why the repo's Mac notes
said "Since Build 37" while the shipped iOS notes said "Since Build 38". Build 40 went to both, so
both files now say **Since Build 40**.

Tester notes live in `Docs/TestFlight-Instructions-ios.md` and `-mac.md` and are what gets pasted
into App Store Connect's *What to Test*, one per platform. `Docs/EditableContent.md` gained §13 for
the map and the Semantic Vectors settings section; its header records the roughly twenty short
strings from the same plain-language pass that it does not yet carry.

**Branches were cleaned to `v2` at this point.** The abandoned first attempt at F-2 — two WIP
commits that never opened a PR — is preserved as **`archive/f2-two-pane-wip`** under the convention
`archive/377-project-home-switcher-pr458` established. F-2 shipped later and differently via
#911–#921, so it is superseded rather than lost.
