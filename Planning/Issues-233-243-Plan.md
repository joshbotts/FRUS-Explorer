# Issues 233–243 Development Plan

**Planned:** 2026-07-08, from a 15-agent codebase investigation + adversarial completeness critique.
**Workflow:** each implementation session runs as an **Opus 4.8 Ultracode** multi-agent session on its own branch off `v2`, immediately followed by a **Fable Ultracode adversarial review + fix pass** on the same branch before self-merge. Wave ends with a consolidated docs pass + build bump (build 31 → 32), per the 207–219 precedent (`Planning/Issues-207-219-Remediation-Plan.md`, commit dabc386).

## Owner decisions (2026-07-08)

| Decision | Choice |
|---|---|
| #234 scope this wave | **M0 only** — POCOM ingestion + career enrichment. M1/M2 (early-era coverage via matching/NER + adversarial review) deferred to their own program (see Backlog — it exceeds any interactive Max 20x workflow). |
| #240 staging | **Two sessions** — offline generator + OH report first (Session 6), app-side consumption second (Session 7), scoped by Session 6's measurements. Bundled resolved-edge list (ideas-2) deferred. |
| Feature ride-alongs | **Administration scope presets** (Session 3) and **Document→Chronology pivot** (Session 5). Batch citation triage and person↔subject affinity chips → Backlog. |
| #241 deliverable | **Report + prototype** — Planning/ investigation doc plus a small proving PR (ArchivalNeighbors scene ported to iPad, `.defaultSize` on the 3 iOS scenes, stale Stage-Manager comments refreshed). |
| #238 platform + fix depth (corrected 2026-07-08: the overlay is **iOS/iPadOS**, most apparent when the `.sidebarAdaptable` sidebar is toggled into the floating top tab bar — not macOS) | **Fix A + Fix B, staged** — unpin the iPad breadcrumb (A) AND flatten iPad Browse to NavigationStack (B), as separate commits with B independently revertible; owner accepts losing the in-tab subseries sidebar (the TabView's adaptive sidebar remains the rail). Research/Settings share the nested-split composition → verify during reproduction, file as follow-up, don't fix in-session. |

**Resolved conflicts** (from the critique, decided by the planner):
- **#236 scope component:** new `SeriesScopeBar` sharing AnalyticsScopeBar's visual language — NOT a generalization of AnalyticsScopeBar. The data sources differ fundamentally (bundled manifest entries, zero-index onboarding-safe vs indexed FTS volume ids via CorpusAnalyticsService); forcing one component would couple the education dashboards to the corpus-analytics service.
- **#242 tag pickers:** **consolidate** `MacTagPickerSheet` + `TagPickerSheetView` into one internal `UserTagPickerSheet` *before* the feature change (extraction as its own commit inside the Session 1 PR). Justified by the wave's modularity mandate plus the adversarial review pass; keep the `tags.picker.*` localization key family.
- **BoundedTitleHeader ownership:** Session 1 owns the extraction — now as a pure modularity rider (the macOS #238 hypothesis is retired; the macOS overlay family was already fixed by 166f77e).
- **PersonIndexRow accessibility fixes:** assigned once, to Session 4 (#243), which runs first in the people family.
- **Docs policy:** consolidated model (build-31 precedent). Every session emits **delta notes only** (a short "docs-delta" list in its PR description); the Closing Session performs the single docs pass. Exception: doc-comment version histories and in-view FeatureInfoButton text update in-session as usual.

## Shared session preamble (paste into every implementation AND review session)

- **Worktree/branch:** branch per session off `v2`, e.g. `claude/issue-233-239-wave6`. Give Workflow agents absolute paths (worktree-path gotcha in memory).
- **Test baseline:** 5 known pre-existing failures on v2 tip — 4 `SettingsSyncCoordinatorTests` crashes + `WordCloudTokenizerTests.pluralFoldDisabled`. Do not chase these. Run suites with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, boot the iPhone 17 simulator first. Gate each session on: its own new/edited suites + `CodingStandardsAuditTests` + a clean build of **both** schemes (`FRUSExplorer`, `FRUSExplorerMac`).
- **Coding standards** (audit-enforced): `String(localized:)` for every user-facing string (no `.xcstrings` catalog exists — strings are inline `String(localized:defaultValue:)`), doc comments on every internal/public symbol, Apache header on new files, Swift 6 strict concurrency clean, `#if DEBUG` + `[TypeName]` print prefix for debug logging.
- **Extraction discipline:** modularity extractions land as **separate commits within the feature PR** so they can be cherry-picked if the feature reverts.
- **xcodegen hazard:** any `project.yml` change (Sessions 6, 8) → `xcodegen generate` then `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`. Build bumps never run xcodegen.
- **Index rule:** any parse-output change bumps `currentDateIndexVersion` in the same commit. Session 7 deliberately substitutes a retroactive UPDATE pass — the PR must document why the rule is satisfied.
- **Review pass:** Fable Ultracode adversarial review (find → independently verify → fix) on the session diff; reviews run builds + targeted tests. Verify claims against code — some finding line numbers may drift (e.g. one finding cited a stale `currentDateIndexVersion`; the current value is 21 at `IndexingPipeline.swift:551`).
- **Docs delta:** end the session by appending a docs-delta list (manual sections touched, checklist items for testers) to the PR description for the Closing Session.

## Sessions

Dependency order: **1 → everything** (SupportingViews extractions); **4 → 8**; **6 → 7 and 8**; #241 anytime; Closing last. Sessions 2, 3, 4, 5 are mutually independent after 1.

---

### Session 1 — Browse titles, iPad tab-bar overlay, tag picker (#237, #238, #242) — M
The wave's opener: it owns the biggest merge magnet (`App/SupportingViews.swift`), performs the shared extractions everything else rebases on, and carries the wave's one structural navigation fix.

**#238 (iPad chrome overlay — corrected report 2026-07-08)** — on iPad, toggling the `.sidebarAdaptable` sidebar into its floating top tab-bar representation overlays Browse content that cannot be scrolled into view. Diagnosis (two-agent re-investigation, high confidence): the Browse tab nests a `NavigationSplitView` inside the adaptable TabView (`BrowserView.swift:93/226` — a composition Apple's adaptable-tab guidance recommends against; Session 159 / 4d1b291 verified only the sidebar representation) and pins `BrowserBreadcrumbBar` as non-scrolling `.safeAreaInset(edge: .top)` chrome on the detail column (`BrowserView.swift:350–363`). In top-tab-bar mode the nested column's top safe area is miscomputed, so the opaque breadcrumb (wraps to ~100pt on deep paths — tallest at AX type sizes) and the List's first rows (SubseriesStatsView; VolumeMetadataView's full-title section — the very thing #237 protects) render underneath the floating tab bar; pinned chrome never scrolls. Same failure class the project fixed twice before (Session 121 document-level breadcrumb suppression, `BrowserView.swift:331–337`; macOS 166f77e). Title-display-mode differences (large at corpus root, inline below) plus toggle-order sensitivity explain the "sometimes".

1. **Step 0 — reproduce before fixing.** iPad Pro 13" (M4) simulator, `-hasCompletedOnboarding 1` + `FRUS_UI_TEST_MODE=1`; toggle sidebar → top tab bar; Browse → subseries → long-title volume (frus1969-76v37); repeat the toggle while already at depth (transition sensitivity), at the corpus root (large title), both orientations. Spot-check Research and Settings (same nested-split composition, no pinned inset) and Search (two stacked top `safeAreaInset`s, `SearchView.swift:162/180`). **Escape hatch:** if a plain NavigationStack detail is still overlaid, it's an iPadOS bug → land Fix A + `.defaultAdaptableTabBarPlacement(.sidebar)` as a documented stopgap, file a Feedback, and say so on the issue.
2. **Fix A (ships regardless):** stop pinning the breadcrumb on iPad — suppress `BrowserBreadcrumbBar` at regular width (Session 121 rationale: the tab sidebar + nav titles already convey location) or move it into scrollable content; pair with the #237 crumb cap so iPhone keeps a bounded pinned bar. Keep visual and accessibility geometry in sync: if suppressed, the crumbs must leave the accessibility tree entirely (overlaid-but-VoiceOver-focusable elements are their own bug).
3. **Fix B (owner-approved; separate commit, independently revertible):** route iPad Browse to the existing `stackLayout` — NavigationStack-per-tab is the supported shape under `.sidebarAdaptable`; the TabView's own adaptive sidebar remains the persistent rail. Re-verify `BrowserViewModel` path semantics and the `pendingBrowseDocument`/`pendingBrowseVolume` observers (`BrowserView.swift:103–123`) on iPad (split-detail vs stack routing differ subtly), and record the Session 159 revision in `Planning/BigPicture-iPadMacParity.md`. **Research/Settings flattening: follow-up issue** filed with Step-0 screenshots — not fixed here.
4. **Anti-fixes (do not):** no manual top-padding/GeometryReader safe-area compensation (breaks in the sidebar representation; see the fixedSize-title-overflow memory); no `.defaultAdaptableTabBarPlacement` paper-over once A+B land — both representations must be safe, and the app cannot even observe which one is active (verified: no binding, no TabViewCustomization).
5. **Regression net:** add an iPad scenario to `UIObstructionTests` — confirm the system "Toggle Sidebar" control's accessibility identifier via a scratch `debugDescription` dump, `XCTSkip` gracefully if absent, restore the representation in tearDown (it's system-persisted per install); navigate Browse → subseries and assert first-cell and first-pushed-row `isHittable`. Harden the existing `if browseTab.exists` guards that silently no-op on iPad. Document the iPad run command (`-destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -only-testing FRUSExplorerUITests/UIObstructionTests`) in CLAUDE.md next to the iPhone command. If the toggle proves unautomatable, land a tester-checklist item instead.
6. **Verification:** the Step-0 recipe in both representations and orientations, deep breadcrumb path, AX5 Dynamic Type, hardware-keyboard focus-scroll (focused row under the tab bar must scroll into view). Record the Search-tab check in the PR — fix in-session iff it reproduces (the guard rule "tabs host NavigationStack only; top chrome only via safeAreaInset inside the nav container" is the deliverable, not just the Browse patch).
7. **macOS rider (S — same file as the tag-picker work; the retired macOS hypothesis's still-useful pieces):** extract `BoundedTitleHeader` (SupportingViews.swift:3199) → own `internal` file with `@ScaledMetric` max-height + `.isHeader` + combined a11y element + `.help(title)`; wrap `CorpusVolumeDetailView.indexingView` in a ScrollView (strictly inside the `.indexing` case); convert `SubseriesVolumeListView` `.onTapGesture` rows to Buttons and migrate its hard-coded fonts to text styles. The DEBUG geometry guard and the optional corpus-browser file split move to Backlog.

**#237 (iOS nav-bar titles)** — full titles already head the content List since 57f6b33 (build 31); the nav bar itself still truncates:
1. New shared `TwoLineNavTitleView` (pattern: ArchivalNeighborsSheet.swift:572–582): subheadline semibold, `.lineLimit(2)`, `.minimumScaleFactor(0.8)`, `.accessibilityLabel(fullTitle)`, `.isHeader`.
2. Adopt as iOS-only `ToolbarItem(placement: .principal)` in `VolumeView` (keep `.navigationTitle` — back-button derivation) and `CompilationView` (same truncation, chapter titles equally long).
3. Drive-by: cap breadcrumb crumbs (`BrowserBreadcrumbBar.swift:238–241`) with `.lineLimit(1)` + maxWidth — a 618-char title currently becomes one giant crumb; keep the full string in the crumb's accessibility label.
4. Add `.isHeader` to the in-content full-title Texts (VolumeView:344, CompilationView:106) for the headings rotor.
5. Verify: frus1969-76v37 + frus1865p4, largest Dynamic Type, landscape, iOS 26 Liquid Glass scroll-edge behavior. Resolution note on the issue: nav bar = best-effort 2 lines; the in-content header remains the canonical full display (paragraph-length titles cannot fit any nav bar).

**#242 (new tags to top)** —
1. Extraction commit: consolidate `MacTagPickerSheet` (SupportingViews.swift:2356 — already has macBody/iOSBody) + `TagPickerSheetView` (DocumentView.swift:2652) → `DocumentView/UserTagPickerSheet.swift`; three call sites (SupportingViews:235, MacDocumentView:234, DocumentView:578); keep `tags.picker.*` keys; preserve the `newlyCreatedTags` cancel-rollback exactly.
2. Feature: pin session-created tags to the top (newest first) via a `displayTags` computed property composed from the synchronous `newlyCreatedTags` state (NOT by filtering the async `@Query`); "New" text badge (not color-only); move the New Tag entry section above "Your Tags"; rest stays alphabetical.
3. Consistency: `ResearchNoteEditorViewModel.createAndAddTag` → `insert(tag, at: 0)`. Settings tag managers unchanged (alphabetical is the point there).
4. A11y: post "Tag X created and selected" announcement + `@AccessibilityFocusState` move to the new toggle; explicit `.accessibilityLabel` on the tag-name field; fix the taxonomy `TagPickerRow` (SubseriesView.swift:496 — different picker, do not merge) missing `.isSelected` trait; fix MacTagPickerSheet's unlocalized `"— Doc \(docNum)"` title fragment.

**Review focus:** Fix B navigation-state regressions (path routing, pendingBrowse handoff observers, state restoration on iPad), breadcrumb suppression keeping the accessibility tree consistent, evidence that BOTH tab-bar representations were exercised, tag-picker consolidation regression on both platforms (sheet titles/detents), cancel-rollback orphan cleanup, principal-item clipping at AX sizes.

---

### Session 2 — Word cloud hide + Citation Lookup Mac fit (#233, #239) — S
Two disjoint, single-file changes sharing one implement+review cycle.

**#233** — non-persistent per-cloud hide, all in `WordCloudView.swift`:
1. `@State sessionHiddenWords: Set<String>` (per-view-instance = non-persistent by construction: iOS sheet dismissal, macOS window close / `.id(scope.signature)` retarget).
2. **Display-layer filter** (decided; not pipeline recompute — a corpus-cloud recompute is minutes per hide): `visibleTerms` filters the fetched 220 terms; layout places ≤180, so next-ranked words backfill instantly. Filter on bare lowercased terms BEFORE the sentiment ±mark mapping.
3. Swap `result.terms` → `visibleTerms` at: layout task, ranked list, header count, **all three exports (WYSIWYG — decided)**. Keep `result.terms` for empty-state / `belowSignalThreshold` / Options-menu disabled checks so users can't hide themselves into a dead end.
4. Extend `LayoutKey` with the hidden set (don't rely on count changes). Menu item first among the three hide actions (narrowest→broadest); one hide set per view instance across lens switches (decided).
5. "Show N hidden words" = union count of both stores; reset clears both (skip the pipeline reload when only session hides exist).
6. Extract the filter as a pure helper (`WordCloudResult.filtering(hidden:)`) + unit test (case-insensitivity, marked-term interaction). Delete the orphaned `WordCloudOverrides.hide(_:for:)` writer (keep reader + reset for legacy persisted hides).
7. A11y: fix the stale "Search for this term" VoiceOver hint on ranked rows (action is now Analyze); mirror the context menu as `.accessibilityAction(named:)` on ranked rows; post "'term' hidden" announcement.

**#239** — platform fit, all in `CitationLookupView.swift` (the window scene already exists):
1. `#if os(macOS) .formStyle(.grouped)` (the app's six other Mac forms set the convention); visual-check the segmented picker's List-row modifiers under grouped style.
2. Keyboard: `submitIfActionable()` helper; `.onSubmit` on all five fields (guarded — decided); `.keyboardShortcut(.defaultAction)` on Look Up (macOS-only if the iOS Done button conflicts); `.submitLabel(.search)` on iOS.
3. Focus: `@FocusState` + `.defaultFocus` on the paste field, switching with mode (defaultFocus silently no-ops if the field isn't in scope).
4. **macOS result taps open a real document window** via `openWindow(value: DocumentWindowID(...))` (SearchSheet:1116 convention — decided); delete the degraded in-window `MacDocumentView(navigationPath: .constant([]))` push; keep the `!documentId.isEmpty` guard; update the B4 doc comments + scene comment in the same commit (audit trail).
5. Polish: `.help()` tooltips; replace the hardcoded download URL with `ManifestModels.downloadUrl` (file follow-up chip for the other 3 duplicate sites).
6. A11y: group `CitationResultRow`'s info stack (`children: .combine`, buttons stay separate); result-count announcement after `performLookup`; nudge confidence-badge caption colors toward AA (keep hue language + icon coding).

**Review focus:** iOS sheet regression (shared view), lens-switch behavior of session hides, export WYSIWYG parity, defaultFocus mode switching.

---

### Session 3 — Series-analytics scope pickers + administration presets (#236 + ride-along) — M
1. **Extraction commit first:** `SeriesChartCard` (the `chartCard` helper is duplicated verbatim in all four dashboards) into `SeriesAnalytics/SeriesChartCard.swift`, with a controls slot and `.isHeader` on the title; move the thrice-defined `yearAxisFormat` next to `SeriesChartKind`.
2. **New `SeriesScopeBar`** (decided — not AnalyticsScopeBar) over **manifest entries**, subseries-level only (no By-Volume: degenerate single-volume series charts + a 552-item menu), `@State` non-persisted (educational dashboards must not silently reopen narrowed), dashboard-level placement (all charts share the scope). Zero-index onboarding context must keep working — verify inside the onboarding sheet.
3. SA-1 + SA-2: filter `entries` before data construction; caveat strings state the active scope.
4. SA-2b: `AdministrationProfilesData.init(... scopeVolumeIds:)` recompute from the per-volume breakdown; hide the coverage-span row under scope (cannot be re-derived) with a caveat disclosure; **add the missing year-range bar** (term-overlap filter — decided); assertion-style test summing `volumes[]` against `pointDocCount` on the real bundled index.
5. SA-3b: **category filter only** (the bundled index is decade×category — do not fake volume scope): hidden-categories menu + one-tap "Hide Other/Unclassified"; exact renormalized shares ("share of shown categories" caveat — historian-facing honesty); stable color domain. Generator v2 (per-volume provenance counts) → follow-up issue.
6. **Administration presets (ride-along):** a shared preset menu (from bundled `administrations.json`, reusing SA-2's date semantics — never re-derive) that expands to year ranges on `AnalyticsYearRangeBar` consumers: the four SA dashboards + corpus `AnalyticsView` + `CrossReferenceAnalyticsView`'s year filter. Word-cloud/Chronology presets → backlog note if the session runs long.
7. Empty-state guards under scope (subseries with no parseable years must hit existing empty paths, not blank axes); reset affordances clear scope + range together.
8. A11y: explicit label on the scope Menu + "reset" clarity; year TextField min-width (44pt clips at AX sizes); category-filter checked state via `accessibilityValue`; **scoped data must feed the ChartDataInspector tables** (the accessible fallback). AXChartDescriptor/audio graphs → follow-up (needs owner VoiceOver-on-device validation; unverifiable in this workflow).

**Review focus:** scoped-vs-unscoped count agreement, renormalization honesty, onboarding zero-index rendering, inspector parity.

---

### Session 4 — Manual person merge (#243) — M *(must precede Session 8)*
Investigation reframe: merge machinery was never removed — it's candidate-gated, and rollup-v8 guardrails (05d8b81) made candidates scarce. All backend reused; this is UI + small store API.
1. `PersonMergePickerSheet`: searchable list from `PersonMentionStore.allPersonsSortedByName()` excluding current rollup; **performance note (critique):** 18,641 rollups feed this list — debounce search and page/lazy-load; measure before shipping.
2. "Merge with another person…" button in `PersonIndexDetailSheet` (+ row context-menu shortcut); confirmation dialog naming both identities, with an **extra warning on differing authority ids** (decided: warn, not block — the historian may know better).
3. Reuse the exact existing path (representativeMember → `PersonClusterOverrideStore.merge` → save → `consolidatePersonRollup(forceReload:false)`); extract the duplicated correction tail into one `applyCorrection` helper (picker would be the third copy).
4. **Corrections manager (undo — do not defer):** list `fetchAll()` records with human-readable names (new `personName(volumeId:ref:)` store query); Delete → `PersonClusterOverrideStore.remove` (currently dead code) + re-consolidate. People-browser toolbar entry point (one shared code path, both platforms). Merge direction rendered textually, not "↔︎".
5. **Staleness fingerprint fix lands in the same PR:** `consolidatePersonRollupIfNeeded` compares override COUNT only — remove+add nets the same count and silently skips reconsolidation once undo exists. Replace with a deterministic snapshot fingerprint.
6. Confirmation copy explains transitive union (A→B, B→C merges all three); document the volume-removal anchor no-op behavior.
7. A11y (owned here for the people family): PersonIndexRow mention-count label + hidden chevron + combined row; per-person Merge/Separate labels; merge progress/completion announcements (re-consolidation takes seconds).
8. Tests: override round-trip incl. remove; arbitrary must-link union; fingerprint staleness. No index bump, no CloudKit schema change.
9. No candidate-generation loosening (decided — v8's under-merge bias was a deliberate audit outcome).

**Review focus:** fingerprint correctness across devices/sync, corrections-list name resolution for stale anchors, cross-authority warning flow.

---

### Session 5 — NARA lookup analyze-first MVP + chronology pivot (#235 + ride-along) — M
**Swift-only MVP slice** (decided): no JS `blockText` this wave (the `kSelectionJS`/`frus-selection.js` dual-file change is a careful follow-up PR).
1. `NARALookupContext` struct (selectedText, extendedText?, documentYear?, volume/document ids); widen `AppState.pendingNARALookup` String? → context (all macOS consumers; `NARACatalogLookupItem` subsumed).
2. In-document look-around: ±300 UTF-16 units via `flatTextExcerpt` (block-aware), shared free function consumed by both platforms (iOS DocumentView edit-menu path; macOS HighlightCoordinator `makeNARALookupContextAction` mirroring `makeExcerptCaptureAction`). Footnotes: whitespace-tolerant `vm.sourceNote` substring heuristic (covers the dominant select-a-lot-number-in-the-footnote case).
3. `SelectionResolutionAnalyzer`: parse selection / citation sentence / extended text with the app-bundled SourceNoteKit grammar (already compiled into both app targets — no packaging work); dedupe by case + normalized keys; attach offline resolutions (CollectionAuthorityStore / CentralFilesIndex / VolumeSourcesIndex); rank (exact-selection > extended; recognized > drop `.unrecognized`; offline-hit boost); cap 3. **Swift-6 concurrency audit up front (critique):** verify the isolation of the three index stores and the `Task.detached` warm pattern compile under complete checking at the new call sites before building the UI.
4. Extract the duplicated ParsedSourceNote-case→NARACatalogClient mapping (`SourceExplorerView.load()` + `LookupStrategy.execute`) into a shared `NARAQueryPlanner`.
5. UI: "Suggested Matches" section (classification chip, human key, offline resolution line with NAID/volume counts, one-tap Search); **auto-run live queries only for high-precision cases** (lotFile, presidentialLibrary — decided; protects rate limits); manual strategy picker demoted into a DisclosureGroup, **auto-expanded on zero candidates** so the degraded path is pixel-identical to today (decided).
6. A11y: combined candidate/result rows; "Analyzing selection…" labeled progress + completion announcements; "opens in your browser" hints; AA-nudge the orange API-key warning.
7. Tests: analyzer ranking/dedup (lot file ± context, decimal, presidential prose via extractCitations, garbage → empty).

**Ride-along — Document→Chronology pivot:** "Show this date in Chronology" toolbar/context action in DocumentView + MacDocumentView, seeding `ChronologyParameters` ±7/±30 days from `document_dates` via the existing `AppState.pendingChronology` handoff. (Slides to Session 7 if this session runs long.)

**Review focus:** grammar over-matching on arbitrary prose (false-positive parses), the String→struct hand-off ripple on macOS, rate-limit behavior, concurrency isolation.

---

### Session 6 — Cross-ref validation: offline half (#240A) — M/L *(prerequisite for 7 and 8)*
Generator-only; no app changes. Produces the measurements that scope Session 7.
1. **`CrossRefKit`** shared target (SourceNoteKit pattern; added to app targets via project.yml path entries): the ref-target grammar (mirror `FRUSDocumentParser.parseRefTarget` + `FRUSURLSchemeHandler.resolveCrossRefTarget` semantics — footnote-suffix collapse, page anchors arabic/roman, AnchorClass) + the validation-manifest Codable model. Keep a forwarding shim in FRUSDocumentParser (hot parse path untouched → no index-bump question); byte-parity unit tests against the existing functions.
2. **`GeneratorKit`** SPM library: `VolumeCorpusEnumerator` (VOLUMES_DIR env + enumeration + sorted deterministic iteration + progress printing) + shared manifest-entry decode. Build only the new generator on it; migrating the five existing runners → follow-up chips (each must byte-verify a deterministic bundled artifact).
3. **`CrossRefValidationGenerator`** (Core/exec/Tests trio): Pass A anchor inventory (ALL xml:id values + pb @n page numbers per volume — refs legitimately target footnotes/persons/pages); Pass B ref harvest with precise location (raw-text streaming scan for `<ref target>` capturing char offset + line number + enclosing div/note — XMLParser alone can't give offsets; nil-safe "front-matter" attribution for refs outside document divs); Pass C classification with failure reasons {unknownVolume, unknownAnchor, unknownPage, malformedTarget, emptyTarget}, distinguishing "volume not in local corpus snapshot" from "unknown to the series". External URLs classified, not fetched (offline — decided).
4. Outputs: `broken-refs-report.csv` + `.json` (repo artifacts, the **OH-submittable deliverable** — this session alone satisfies the issue's remediation-support core) and a measured proposal for the bundled index shape (full {d,t,r} detail if <~1.5MB, else compact exclusion keys with detail repo-only).
5. Wiring: Package.swift, project.yml (+ scheme restore), CLAUDE.md tool list entry. Fixture-volume tests (known-good, broken anchor, broken volume, page anchor, footnote-suffixed, external URL).

**Review focus:** grammar parity with the app (the entire feature's correctness rests on it), offset accuracy, snapshot-vs-series volume distinction (false positives would hide real references).

---

### Session 7 — Cross-ref validation: app half (#240B) — M *(after 6; scoped by its measurements)*
1. Bundled `broken-refs-index.json` (shape per Session 6 measurement) + `BrokenRefsIndex` lazy loader (VolumeSourcesIndex pattern); exclusion keyed by (sourceVolume, sourceDoc, target) — raw-target-only keys can collide with valid refs.
2. `ALTER TABLE cross_references ADD COLUMN is_broken` + insert-time marking + **retroactive idempotent UPDATE pass at pipeline open** (modeled on `resolvePageBasedCrossReferences`), gated by a stored marker; runs after each future volume index. This deliberately substitutes for a `currentDateIndexVersion` bump (rows themselves unchanged; a full reindex of 6.7GB libraries for a derived flag is disproportionate) — document the rationale against the standing rule in the PR.
3. `CrossReferenceStore`: broken-exclusion predicate alongside `documentTargetPredicate` in the 8+ graph/analytics queries; `excludedBrokenCount`; **disclosure footnote** in CrossReferenceAnalyticsView ("N unresolved references excluded" — decided: disclose, no toggle). Ego graphs stop rendering phantom "undownloaded volume" nodes for never-resolvable targets.
4. Reading view: `FRUSRenderNode.crossRefLink` gains `isBroken` (compiler-guided ripple: serializer, URL-scheme scanner, three exporters — exporters render broken refs as plain text); **tappable explained span** (dotted underline + muted color + aria-label, non-color-only) opening a short explanation sheet with the failure reason (decided — a research app should say *why* the printed reference can't be followed); fix the pre-existing silent `.unresolved` DEBUG-print branch (DocumentView.swift:825) with the same sheet.
5. In-app export: "Broken Cross-References Report" ShareLink (CSV/JSON re-serialized from the bundled index, or bundled report copy per size decision) near ResearchDataExportView.
6. Ride-along slot: the chronology pivot lands here if Session 5 dropped it.

**Review focus:** UPDATE-pass idempotency + cost at pipeline open, query-exclusion completeness (all 8+ sites), exporter output verification, explanation-sheet reachability on both platforms.

---

### Session 8 — People: POCOM M0 (#234-M0) — L-lean *(after 4 and 6)*
**Environment prerequisite (owner, before the session):** a local checkout of `HistoryAtState/pocom` (CC0 XML: `people/{a-z}/*.xml`, `missions-countries/*.xml`, code tables) — note its path for `POCOM_DIR`. Record the checkout SHA in the generated index's provenance string (upstream is "early beta — identifiers subject to change").
1. **`POCOMIndexGenerator`** (Core/exec/Tests on GeneratorKit): parse person records + chief-of-mission assignments + code tables → per-person career records {slug, name, birth/death, assignments: [{roleTitle, territory/org, appointed/started/ended}]} → `Resources/pocom-index.json`.
2. **Authority index schema v2:** `PersonAuthorityIndexBuilder` additionally captures the `departmenthistory/people/{slug}` source-urls it currently discards (the slug→canonical-numeric-id crosswalk falls out of the existing PEOPLE_DATA_DIR checkout — verified on record 100001); new optional terse field, `indexVersion` 2, regenerate the bundled index, mirror the field in the app-side tolerant decoder. Hand-mirror both twins this one time; PersonAuthorityKit shared-target extraction → follow-up chip.
3. App: pocom-index loader (loadBundled pattern) + **Career section** in `PersonIndexDetailSheet` for rollups whose authority entry carries a slug — list-based timeline (rows, not a visual timeline: free Dynamic Type/VoiceOver ordering), formatted dates.
4. Fix `FrontMatterPersonsView`'s misleading empty state ("Index this volume…" is wrong for the 409 no-list volumes — distinct no-editor-list message).
5. project.yml resource wiring (+ scheme restore); CLAUDE.md tool entry; generator tests on fixture records.
6. Zero rollup risk by construction (no derived entries this wave — no synthetic refs, no reindex, no clusterer changes).

**Review focus:** POCOM parse coverage across the 5+ record types, v2 tolerant-decode both directions, crosswalk correctness spot-checks against history.state.gov.

---

### Session R — iPad windowing investigation (#241) — S/M *(anytime; no dependencies)*
1. `Planning/241-iPad-Windowing-Investigation.md` (extends BigPicture-iPadMacParity for the iPadOS 26 era): scene inventory (3 iOS vs ~17 macOS scenes), platform-inherent gaps (no `bringMacWindowToFront` equivalent; no singleton Window scene; Settings scene + scene-attached shortcuts macOS-only; pending-state hand-off scenes restore to empty placeholders; process-global AppState means multiple iPad main windows mirror activeTab and race pendingX hand-offs), recommendation: **keep MainTabView root; incremental window ports; iPad menu bar as its own follow-up**; sizing answer: full MainWindowView adoption is XL (blocked by the forked reading surface), incremental path is L across small PRs.
2. Prototype PR (decided): port `WindowGroup(for: ArchivalNeighborsRequest.self)` outside `#if os(macOS)` (verify the content view actually compiles cross-platform first — its wrapper sits in a macOS region), gate open-sites on `supportsMultipleWindows` with the existing sheet fallback, add `.defaultSize` to the 3 iOS scenes, refresh stale "M-chip/Stage Manager" comments.
3. File follow-up issues: per-scene ports (Word Cloud, Citation Lookup, People, Chronology, Cross-Volume Provenance), iPad `.commands` menu bar, per-window state (@SceneStorage for activeTab — a latent bug today), value-based conversion of the two pending-state iOS scenes.
4. Incorporate Session 1's #238 finding into the report: NavigationSplitView nested inside the `.sidebarAdaptable` TabView is an unsupported composition on iPadOS 26 (the Browse flattening is prior art), and the "tabs host NavigationStack only" guard rule constrains how future iPad window/scene work composes navigation containers.

---

### Closing Session — consolidated docs pass + build 32
Per the build-31 precedent (dabc386): collect every session's docs-delta notes →
1. `Docs/iOS-User-Manual.md`, `Docs/macOS-User-Manual.md`, `Docs/EditableContent.md`, README.
2. In-app `ResearchGuideView` + `IndexingEducationView` (scope pickers, suggested NARA matches, broken-ref explanation, career timelines are new research concepts — unlike the 207–219 wave, this one has in-app-help-worthy additions).
3. Testing-checklist §33 delta (memory file), including the #238 tester item (iPad: toggle the sidebar into the top tab bar — the system "Toggle Sidebar" control — then Browse deep into a subseries/volume in both orientations and confirm breadcrumb-free/visible content and reachable first rows) and #237 before/after.
4. TestFlight "What's New" files; `Planning/DEVELOPMENT-PLAN.md` session entries.
5. **Build 31 → 32**: edit `project.yml` + `project.pbxproj` directly (`replace_all`), **never xcodegen**. Reindex note: no `currentDateIndexVersion` bump anywhere in this wave (Session 7's UPDATE pass substitutes); index stays v21.
6. Close issues with resolution notes; file the Backlog's follow-up issues.

---

## Feasibility vs Max 20x

Calibration: the 207–219 wave (11 mostly-S issues, per-issue implement + adversarial refute passes) fit in ~2 days of Max 20x usage. This wave as decided = **8 implementation sessions + Session R + 8 Fable review passes + the docs session** with a larger average session size — roughly **1.5–2× the 207–219 wave's consumption, call it 4–6 days of similar-intensity usage**. Spread across a week (or with review passes on off-peak days), it fits a Max 20x weekly budget that handled the previous wave comfortably; run Sessions 1–2 early and reassess consumption after their review passes.

**Ordered contingency cuts if limits bite mid-wave:**
1. Session 7 (#240 app half) → follow-up issue (Session 6 alone satisfies the OH-report core).
2. Session 8 (#234 M0) → next wave (self-contained; nothing else depends on it).
3. Session R prototype → report-only.
4. Drop the chronology-pivot ride-along; trim administration presets to the SA dashboards only.
5. Run Session 2 and Session R under a single combined review pass (Session 1 is no longer S-tier after the #238 correction, so it keeps its own review).

**Out of interactive scope regardless of budget:** #234 M1/M2 (surface-form matching + NER + adversarial review over ~409 volumes with committed accept/reject artifacts) is a multi-week offline program requiring a ground-truth eval set that doesn't exist. When resumed: build the eval set first, pilot on the 62 pre-1910 volumes with measured precision, and run the LLM-assisted review as scripted offline/API batch jobs rather than interactive sessions.

## Backlog (file as issues in the Closing Session)

| Item | Origin | Notes |
|---|---|---|
| #234 M1 (POCOM-anchored derived entries, pre-1910 pilot) + M2 (NER + adversarial review) + M3 (provenance UI) | #234 | Own program; see feasibility note. Synthetic-ref namespace, index-version bump batching, and rollup force-merge-only rules are documented in the investigation findings. |
| Bundled resolved-edge manifest → complete inbound citations across undownloaded volumes | ideas-2 | Revisit after Session 6 measures edge-list size; must reconcile with the is_broken design. |
| Batch citation lookup (footnote triage table) | ideas-3 | Natural Mac-window content for CitationLookupView; engine needs zero changes. |
| Person↔subject affinity chips | ideas-5 | S; rides any future people session. |
| Subject index browser + subject timeline | ideas-1 | Strongest standalone idea: 8.7MB curated subject-appearances data has no browsing surface. Own session. |
| Corpus-wide glossary/abbreviation lookup | ideas-6 | terms table already indexed by term string. |
| Saved-search freshness ("new results since last run") | ideas-7 | CloudKit model change; needs its own design pass. |
| SA-3 source-provenance index v2 (per-volume category counts → true volume scope) | #236 | Generator schema bump + regeneration + tolerant decode. |
| AXChartDescriptor/audio-graph builder (shared, from ChartInspectorRow) | a11y scan | Needs owner VoiceOver-on-device validation. |
| JS `blockText` selection context for footnotes | #235 | Careful dual-file kSelectionJS/frus-selection.js sync. |
| GeneratorKit migration of the 5 existing runners (byte-verify each artifact) | modularity | One chip per tool. |
| PersonAuthorityKit shared target (de-twin the hand-mirrored models) | #234-M0 | After schema v2 lands. |
| downloadUrl consolidation (3 remaining hardcoded sites) | #239 | SettingsView ×2, OnboardingViewModel. |
| iPad incremental windowing program (scene ports, menu bar, per-window state) | #241 | Filed from Session R's report. |
| Research + Settings tab flattening (NavigationSplitView nested in the sidebarAdaptable TabView — same #238 class) | #238 | Verify during Session 1 Step 0; file with reproduction screenshots. Research: ResearchView.swift:112. |
| macOS corpus-browser hardening leftovers (DEBUG content-visibility warn-print; lift the ~1,300-line corpus-browser cluster out of SupportingViews.swift) | #238 (retired macOS hypothesis) | Root cause on macOS was already fixed by 166f77e; these are optional guards/cleanup. |
| macOS UI-test target (route walk with pathological-title fixture) | macOS hardening | Only if macOS layout regressions keep recurring. |
| SourceExplorerView/MacSourceExplorerView unification | modularity | Accepted split for now; revisit if Source Explorer velocity picks up. |
| Word-cloud/Chronology administration presets; document reading view Dynamic Type mapping | Session 3 / a11y | Small follow-ups. |
