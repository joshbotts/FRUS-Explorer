# Navigation & State-Management Audit — iOS + macOS

**Status (2026-08-14): substantially discharged — 10 of the 12 filed issues closed; #751 and #752 remain open, each with an owner status ledger.** PR #768 (#751 — reading journeys stay in their origin tab; `DocumentJump` `.push`/`.replace` so page-turns replace) and PRs #769 + #803 (#752 — per-window `ContinuationHost`, the word-cloud hand-off consumed with `orAnyWindow`, the missing `\.sceneID` injections) landed the remedies; #746–#750 and #753–#757 closed 2026-08-08/09.

The four #752 tail entries carry their own **RESOLVED / CLOSED** blocks in place (M-25, L-40, L-43 — and L-48, which **does not reproduce** and was closed with a documentation correction rather than code). Everything else stands as filed.

**Still live, and this document is still the evidence of record for it:** M-16's Research / History / Project-leads restructure, deferred pending a **second owner decision** because the Research stack's path is a typed projection of `selectedItem` (the #238/#272 `.sidebarAdaptable` workaround) — `Planning/iOS-Reading-Journey-Design.md` §6, tracked as **O-3** in `Planning/Resolve-Open-Issues-Plan-2026-08.md`; and **M-17b**, the 56 pt edge-tap zone vs. back-swipe overlap, which needs a device measurement, not a code change. Both sit on **#751**. **#752** stays open on the one structural gap it names — nothing calls `requestSceneSessionActivation`, pinned by `FRUSExplorerTests/WindowTargetingTests.swift:219` (`noSceneActivationYet`).

**Date:** 2026-08-07. **Method:** seven parallel code auditors over disjoint dimensions
(iOS navigation/back, macOS windows/focus, hand-off machinery, document-open inventory,
persistence/restoration, staleness/invalidation, presentation state), every high/medium finding
then re-derived by an independent adversarial verifier, and the four most consequential claims
spot-checked a third time by hand against raw source. **Read-only** — no build, no app launch.
**Result: 49 findings — 12 high, 22 medium, 15 low. 24 verified adversarially (all confirmed,
none refuted); the four hand spot-checks also confirmed.** Evidence is `file:line` into the
`v2` tree at commit `091db70f`.

The two questions the owner asked are answered first; findings follow, grouped by severity, each
with symptom → mechanism → evidence → verification status. Surface maps are appended.

---

## Q1 — How does focus move among macOS windows? Do hand-offs carry focus?

**The designed answer is yes — there is deliberate, well-built focus-carrying machinery — but it
is applied at roughly two-thirds of the sites that need it.**

What exists and works:

- A hand-off routed into a main window **deminiaturizes and fronts it**
  (`MainWindowView.swift:183-189` — the FM-G rule: "a routed delivery is never invisible",
  including the docked-window case `makeKeyAndOrderFront` alone cannot handle).
- `bringMacWindowToFront(id:)` (`MainWindowView.swift:445-465`) exists precisely because
  `openWindow(id:)` **creates** a closed singleton but does not reliably **re-raise** one that is
  open behind another window. Cross-window hand-offs that use the pair
  (`openWindow` + `bringMacWindowToFront`) surface their target correctly — ~20 sites do.
- Active-host document routing (`routedBrowse`, per-instance identity) consumes on the addressed
  window only and fronts it — no cross-window race, no invisible delivery.

Where it breaks:

- **Eleven `openWindow(id:)` sites lack the fronting companion** — mechanically enumerated, then
  confirmed by the focus auditor as 7-of-9 *toolbar launchers* plus context-menu and menu-item
  sites (findings H-13, M-12, M-13, L-34, L-37). The worst case is the one the helper's own doc
  comment names: the launcher fires parameters into a window that stays buried; the user sees
  nothing happen. The same inconsistency in one pair: `ResearchView:683` opens the cross-ref
  graph unpaired while `ResearchRailView:726` opens the same window paired.
- **Project Home is the largest focus/dead-drop defect on macOS** (H-0): with no document host
  open, lead/document/note clicks write a hand-off nobody consumes — nothing happens — and the
  payload then fires as a surprise navigation into the *next* main window opened, minutes or days
  later.
- Keyboard focus after fronting is unset in the Search window (L-35): ⌘S raises it, typing may
  not land in the query field.

## Q2 — Does Back from a document return the user to the view they opened it from?

**The first Back: yes, from every origin that pushes onto its own stack — iOS search results,
chronology, citation lookup, and the graph sheet all round-trip correctly, and macOS opens
documents as separate windows, which preserves origin by construction. Everything else: no.**

The load-bearing fact (verified twice, independently): **on iOS, every document-to-document jump
— cross-ref tap, printed-page ref, `frusexplorer://` link, and the edge-tap page-turn that is the
app's core reading gesture — deliberately routes through the Browse tab**
(`DocumentView.swift:968-971, 1531-1539`, the design rationale in its own doc comment). The
consequences, per origin:

| Origin of the document | First Back | After one page-turn / cross-ref |
|---|---|---|
| Search results (iOS) | ✔ returns to results, state intact | ✘ user is now in Browse; Back unwinds a stale Browse stack; the same document is open in two tabs at different pages |
| Chronology / Citation Lookup / Graph (sheets) | ✔ in-sheet push | ✘✘ navigation happens **invisibly behind the still-open sheet** — the tap looks dead (H-10/M-15) |
| Research, History, Project leads, Related Documents, Archival Neighbors | ✘ hand-off to Browse appends onto whatever Browse held; Back unwinds that | same |
| People ▸ Find all mentions | ✘ by design a tab hand-off to Search — acceptable — but it lands **beneath a stale pushed document** if the Search tab had one open (H-4), and it silently destroys the user's current query (M-29) |
| Browse itself | ✔ | ✔ appends one level per jump; Back unwinds one at a time (N page-turns = N Backs, M-17) |
| macOS (any origin) | ✔ separate `DocumentWindowID` window; close = return | ✔ prev/next stays in-window |

So the honest summary for the owner: **the architecture protects the first hop and loses the
journey.** The Browse-tab-as-universal-reader decision is defensible for predictability; what it
costs is exactly what the question suspected — after any in-document navigation, Back no longer
returns to where you came from, and on sheet-hosted documents it navigates a stack you cannot
even see.

---


## High-severity findings

### H-0. Project Home document/lead/note clicks dead-drop when no document window is open, then fire as a surprise navigation later
*macOS · verified · macOS window management and focus*

**Symptom.** With the main window closed (⌘W — the app keeps running with Project Home and tool windows open), clicking a lead, recent document, or note in the Project Home window does nothing at all. The click is not lost, though: minutes or days later, when the user next opens a main window (Dock click / ⌘N), that fresh window immediately navigates itself to the long-ago-clicked document.

**Mechanism.** ProjectHomeView.openDocument calls appState.openBrowseDocument on BOTH platforms (only the openTab call is #if os(iOS)-guarded). On macOS that writes pendingBrowseDocument = Handoff(target: .macLegacyBrowse, …) (AppState.swift:1933-1935). The only macOS consumers of that channel are the document hosts' onAppear drains and .onChange observers (MainWindowView.swift:154-173, MacDocumentView.swift:1261-1277) — with zero hosts mounted, nothing observes the write, so the click is inert; the next host to mount drains it via routeLegacyPendingBrowse and navigates. Every other macOS producer routes through AppState.openDocument, which MINTS a standalone window when no host is live (AppState.swift:847-851) precisely so 'a document open must never silently do nothing'; Project Home is the one producer that bypasses it. AppState's own doc comment (AppState.swift:725-731) claims the only remaining macOS writer of this channel is unregisterHost's demotion — ProjectHomeView contradicts it.

**Evidence.**
- `FRUSExplorer/ProjectContext/ProjectHomeView.swift:870` — performNavigation { #if os(iOS) openTab #endif; appState.openBrowseDocument(entry, from: sceneID) } — the openBrowseDocument call is NOT platform-guarded; callers at lines 510 (leads), 772 (recent visits), 782 (notes)
- `FRUSExplorer/App/AppState.swift:1933` — openBrowseDocument macOS arm: pendingBrowseDocument = Handoff(target: .macLegacyBrowse, payload: entry) — no mint fallback, unlike openDocument(_:from:mintWindow:)
- `FRUSExplorer/App/MainWindowView.swift:160` — onAppear drain comment acknowledges the class: 'Drain a legacy navigation written while NO host was mounted … routes here instead of stranding' — i.e. it strands until a host mounts
- `FRUSExplorer/App/AppState.swift:727` — Stale doc claim: 'On macOS every producer now routes directly through openDocument … the only remaining macOS writer is unregisterHost's demotion' — false while ProjectHomeView writes it
- `FRUSExplorer/App/FRUSExplorerApp.swift:2061` — Contrast: the equally scene-less Spotlight/Handoff path correctly uses openDocument(.global) with an openWindow(value:) mint tail

**Verifier.** ProjectHomeView.openDocument (ProjectHomeView.swift:864-878): only the openTab call is #if os(iOS)-guarded; openBrowseDocument runs on macOS too, and performNavigation (907-914) executes the handoff synchronously with no window mint or dismissal on macOS. Callers confirmed at ~510 (leadRow), ~772 (recent visits), ~782 (recent notes). AppState.openBrowseDocument's macOS arm writes Handoff(target: .macLegacyBrowse) with no mint fallback (AppState.swift:1934-1935), unlike openDocument(_:from:mintWindow:) which mints a standalone window when no host is live (AppState.swift:847-851). Exhaustive grep for consumers: routeLegacyPendingBrowse is drained ONLY by MainWindowView (154-173) and MacDocumentView (1261-1277) onAppear/onChange — and BrowserView is iOS-only (file-level #if os(iOS), BrowserView.swift:12/714), so with zero document hosts mounted the write sits unobserved until the next host's onAppear drain delivers it as a delayed navigation (MainWindowView.swift:156-162 comment admits the class). Project Home is its own value-based WindowGroup (FRUSExplorerApp.swift:891-898), so the scenario (main window ⌘W'd, Project Home open) is reachable. The stale doc comment is real (AppState.swift:726-728). One trivial line adjustment: the FRUSExplorerApp contrast evidence sits at 2062-2064 (line 2061 is the #if os(macOS)); same block, claim unaffected.

*Related known:* Provenance PR 2 ('macOS window routing: provenance redesign') migrated every other macOS producer off this channel; #369 was the audit wave that verified refocus/hand-off firing but predates the #377 Phase 1 Project Home window.

### H-1. Person correction renumbers every rollup id under live 'Mentions' search chips and analytics selections
*both · verified · state invalidation & staleness*

**Symptom.** Fix one duplicate person in the People browser (merge/separate), then run the search whose 'Mentions: Kissinger' chip was already set, or keep using an open Person Analytics comparison: the chip/chart still shows the old name but the results/trajectories now belong to a DIFFERENT person, with no error and no visual change to the chip.

**Mechanism.** Rollup ids are positional — consolidatePersonRollup writes rollup_id = clusterIndex + 1 — so any reconsolidation renumbers essentially every cluster after the first membership change. Every correction reconsolidates live (PersonClusterOverrideStore.saveAndReconsolidate), but only PersonIndexView observes appState.personCorrectionsGeneration; SearchViewModel.personRollupId, MacSearchViewModel.parameters.personRollupId, and PersonAnalyticsView.selectedPeople keep their captured ids and their old display labels (personLabel), while the SQL filter (EXISTS ... m.rollup_id = ?) now resolves those ids to different clusters. The same window exists without corrections: currentPersonRollupVersion was bumped 8→9, and in the boot-reindex branch the consolidation runs only after a multi-minute indexAllVolumes, i.e. mid-session while chips can already be set.

**Evidence.**
- `FRUSExplorer/Search/IndexingPipeline.swift:857` — rollup_id = Int64(clusterIndex + 1) — ids are positional, not stable identifiers
- `FRUSExplorer/Models/PersonClusterOverrideStore.swift:98` — saveAndReconsolidate reconsolidates live on every merge/split/undo; touches no view state
- `FRUSExplorer/Browser/PersonIndexView.swift:155` — onChange(personCorrectionsGeneration) — the ONLY observer of the corrections signal (grep-verified: AppState:472, PersonIndexView:36/155/939, PersonCorrectionsView:374)
- `FRUSExplorer/Search/SearchViewModel.swift:162` — personRollupId held in the live filter; passed unchanged into every subsequent search (line 824); chip label falls back to stored personLabel (999-1003)
- `FRUSExplorer/Search/IndexingPipeline.swift:3188` — search SQL filters person_rollup_member by the held rollup_id — after renumbering this is a different person
- `FRUSExplorer/Analytics/PersonAnalyticsView.swift:336` — selectedPeople holds rollupId+canonicalName; view reloads only on readOnlyStoresGeneration (681), which corrections never bump
- `FRUSExplorer/App/FRUSExplorerApp.swift:1596` — boot-reindex branch consolidates AFTER indexAllVolumes completes — the v9 renumber can land minutes into an active session

**Verifier.** Every evidence line is real and no compensating code exists. IndexingPipeline.swift:858 assigns rollup_id = Int64(clusterIndex + 1) after DELETE FROM person_rollup (840-857), and PersonClusterer.swift:226-228 orders clusters 'by first appearance for determinism' — so a merge/split removes or moves a component and shifts the index of every cluster after it. PersonClusterOverrideStore.swift:95-99 reconsolidates live on every correction and touches no view state. Grep confirms personCorrectionsGeneration exists at exactly the finder's five sites (AppState.swift:472; PersonIndexView.swift:36/155/939; PersonCorrectionsView.swift:374) — only PersonIndexView observes it. SearchViewModel holds personRollupId (162) and stored personLabel (165), passes both unchanged into every search (824-825); IndexingPipeline.swift:3188-3196 filters by the held m.rollup_id; MacSearchViewModel holds parameters.personRollupId (App/MacSearchViewModel.swift:460/480/494). PersonAnalyticsView.selectedPeople (337) reloads only on readOnlyStoresGeneration (681), which is bumped solely in AppState.refreshReadOnlyStores (AppState.swift:661) — called after reindex, never by saveAndReconsolidate. currentPersonRollupVersion = 9 (IndexingPipeline.swift:752, v8 per the line-171 comment) and FRUSExplorerApp.swift:1587-1601 runs consolidatePersonRollupIfNeeded only after the multi-minute indexAllVolumes, confirming the mid-session window. One trivial symptom nit: the macOS chip label is numeric ('person #N', MacSearchViewModel.swift:480-482), so 'still shows the old name' applies to the iOS chip (stored personLabel) and the analytics comparison (stored canonicalName), not the Mac chip — severity unchanged.

### H-2. Erase Everything leaves 5 of 19 synced record types behind (saved searches, working corpora, custom scopes, person corrections, project leads)
*both · verified · state invalidation & staleness*

**Symptom.** User runs the double-confirmed 'Erase Everything', whose footer promises 'the app returns to onboarding as if newly installed' and whose warning says data 'goes from your other devices too'. After re-onboarding, the Saved Searches sheet still lists every old search (the user's own query text), Settings still lists their custom volume scopes, working corpora (captured result sets with source queries) still exist and sync, person-cluster corrections still apply, and orphaned ProjectLeadEntry rows reference the deleted projects.

**Mechanism.** performReset deletes 14 model types by hand (DocumentTagAssignment ... Project) but frusModelTypes enrolls 19 (+2 retiring). SavedSearch, PersonClusterOverride, CustomVolumeScope, ProjectLeadEntry, and WorkingCorpus are absent from the delete list, so they survive locally and in CloudKit. This is the exact fault class Wave R-2a fixed for SearchHistoryEntry ('a reset left every recorded search — the user's own query text, mirrored to iCloud — behind', comment at SettingsView.swift:1396-1400): the list was extended for the trail types but not for the four types added since (CustomVolumeScope #258, ProjectLeadEntry #377, WorkingCorpus M-1) nor for SavedSearch/PersonClusterOverride, which appear never to have been in it. ProjectLeadEntry additionally becomes an orphan because Project.self IS deleted.

**Evidence.**
- `FRUSExplorer/Settings/SettingsView.swift:1389` — performReset's complete delete list (1389-1407): no SavedSearch, PersonClusterOverride, CustomVolumeScope, ProjectLeadEntry, or WorkingCorpus
- `FRUSExplorer/Models/ModelContainer+FRUS.swift:80` — frusModelTypes enrolls all five missing types (SavedSearch:94, PersonClusterOverride:104, CustomVolumeScope:108, ProjectLeadEntry:111, WorkingCorpus:116) — all CloudKit-synced
- `FRUSExplorer/Settings/SettingsView.swift:1328` — footer promises 'as if newly installed'; warning at 1299 promises deletion from other devices
- `FRUSExplorer/Settings/SettingsView.swift:1407` — Project.self deleted while ProjectLeadEntry survives → dangling projectId references

**Verifier.** The delete list is exactly SettingsView.swift:1389-1407 (14 types, verified verbatim), and a repo-wide grep shows those are the ONLY delete(model:) calls in the app — SavedSearch, PersonClusterOverride, CustomVolumeScope, ProjectLeadEntry, and WorkingCorpus are deleted nowhere. The other reset half, ResetService.resetLocalData (Settings/ResetService.swift:55-93), touches only volume XML files, the FTS index, and analytics caches — no SwiftData. ProjectLeadEntry holds a plain projectId UUID (Models/ProjectLeadEntry.swift:36) with no @Relationship, so deleting Project.self (1407) cannot cascade — the orphan claim holds. UI copy verified: footer 'as if newly installed' (~1327-1329), warning 'goes from your other devices too' (~1298-1300), and the file's own R-2a comment (1293-1297) names this exact fault class. Two count corrections that don't change the verdict: frusModelTypes (ModelContainer+FRUS.swift:81-119) enrolls 20 types = 18 active + 2 retiring, not '19 (+2)'; and a sixth active type, SyncedPreferences, also survives performReset (defensible as deliberate for synced settings, but unstated by the screen). The five named user-data types surviving a double-confirmed erase — including in CloudKit — is fully confirmed.

*Related known:* Same fault class as the Wave R-5/R-2a fix documented in the file's own comments (an erase under-reaching its promise); that wave fixed the trail types only.

### H-3. Cross-ref tap in a Search-opened document exits to Browse; Back cannot return to the source document
*iOS · verified · iOS tab & stack navigation, and BACK behavior*

**Symptom.** Reading a document opened from search results, the user taps an in-text cross-reference ("see Document 123"). The app switches to the Browse tab and shows the target. Tapping Back then lands on whatever the Browse stack previously held — an unrelated volume from earlier browsing, or the corpus root where the Back button vanishes — never the document they were reading. To resume, they must know to tap the Search tab.

**Mechanism.** Search results push documents onto the Search tab's own stack (SearchView.swift:1544-1546), but every cross-reference tap inside DocumentView routes through `appState.openTab(.browse)` + `appState.openBrowseDocument(...)` (DocumentView.swift:968-971; page refs via :986-997; frusexplorer://doc links via :744-754). Only BrowserView consumes pendingBrowseDocument, appending `.document(entry)` to the BROWSE stack (BrowserView.swift:625-636). The source document stays stranded atop the Search stack; Back unwinds the Browse hierarchy. The comment at DocumentView.swift:1523-1530 records this as deliberate ("keeps behaviour predictable"), but it makes Back's destination arbitrary for every non-Browse origin.

**Evidence.**
- `FRUSExplorer/DocumentView/DocumentView.swift:968` — #if os(iOS) openTab(.browse) + openBrowseDocument for every resolved cross-ref
- `FRUSExplorer/Search/SearchView.swift:1544` — openResult appends to the Search tab's own stack — the origin that gets abandoned
- `FRUSExplorer/Browser/BrowserView.swift:632` — consumer appends .document onto whatever the Browse path already held
- `FRUSExplorer/DocumentView/DocumentView.swift:1523` — doc comment: DocumentView presented from Search/CitationLookup/Graph/Browse; ALL doc-to-doc jumps route through the Browse tab by design

**Verifier.** All four evidence points verified verbatim. navigateToCrossRef routes every resolved cross-ref through appState.openTab(.browse) + openBrowseDocument (DocumentView.swift:968-971); page refs funnel into the same function (986-997), and frusexplorer://doc links reach it via handleCrossRefTap (744-754). Search results push onto the Search tab's own stack (SearchView.swift:1544-1546), and the only iOS consumer of pendingBrowseDocument is BrowserView, which appends .document onto the Browse path (BrowserView.swift:625-636). Hunted for compensating code: grep across SearchView/SearchViewModel shows navigationPath is only declared (SearchViewModel.swift:437) and appended (SearchView.swift:1545) — nothing ever pops it, restores focus to the Search tab, or unwinds Browse back to the origin. The design comment at DocumentView.swift:1523-1530 confirms this is deliberate, exactly as quoted. Severity high is honest: the user's reading position survives only as an abandoned entry on a tab they must know to revisit, and Back in Browse unwinds unrelated history.

*Related known:* #338 made these handoffs scene-addressed (same window), but the tab-level origin loss is untouched

### H-4. Search hand-offs land beneath a stale pushed document in the Search tab
*iOS · verified · iOS tab & stack navigation, and BACK behavior*

**Symptom.** The user earlier opened a document from search results and left it open. Later, from the People browser (or a person sheet, Person Analytics, History's search rows, Corpus Analytics, an indexing banner) they tap "Find all mentions" / "Open in Search". The app switches to the Search tab — and shows the OLD document, not the new results. The new search ran invisibly underneath; only tapping Back reveals it. It looks like the button opened the wrong document.

**Mechanism.** `consumePendingSearch` (SearchView.swift:629-643) calls `vm.applyParameters` + `runSearch()` but never pops `vm.navigationPath`; `applyParameters` (SearchViewModel.swift:1086-1123) touches every filter field and not the path (the path's only writes are the declaration at SearchViewModel.swift:437 and the append at SearchView.swift:1545). The NavigationStack therefore keeps displaying the pushed entry while the root's result list is replaced beneath it. Producers all pair `openSearch` with `openTab(.search)`: PersonIndexView.swift:191-198, DocumentView.swift:562-573, HistoryView.swift:475-481, AnalyticsView.swift:1108/1125, WordCloudView.swift:1553-1568, ChronologyView.swift:1167-1179, MainTabView.swift:281-295.

**Evidence.**
- `FRUSExplorer/Search/SearchView.swift:629` — consumePendingSearch applies parameters and runs the search; no navigationPath reset
- `FRUSExplorer/Search/SearchViewModel.swift:1086` — applyParameters resets every filter field but not navigationPath
- `FRUSExplorer/Browser/PersonIndexView.swift:191` — Find-all-mentions producer: openSearch + openTab(.search)
- `FRUSExplorer/History/HistoryView.swift:480` — History search-row rerun: same pair

**Verifier.** consumePendingSearch (SearchView.swift:629-643) calls vm.applyParameters + runSearch and never touches vm.navigationPath; applyParameters (SearchViewModel.swift:1086-1123) resets every filter field and nothing else. The path's only writes in the entire Search layer are the declaration (SearchViewModel.swift:437) and the append (SearchView.swift:1545) — no pop exists. The handoff is consumed by .onChange(of: appState.pendingSearch) at SearchView.swift:527-528 on the NavigationStack ROOT, which stays mounted (and its onChange live) while a document is pushed over it, so the search executes invisibly beneath the stale document. Checked the last plausible compensator: tab switching. MainTabView's pendingTab observers (MainTabView.swift:181-189) only set selectedTab — no pop-to-root on select or reselect. Producers verified pairing openSearch + openTab(.search): PersonIndexView.swift:191-198, HistoryView.swift:479-481, DocumentView.swift:562-573. The finder's 'likely' was conservative — the only runtime assumption is standard SwiftUI stack-root behavior; statically this is fully traced.

*Related known:* people-eval finding F fixed the missing tab switch (DocumentView.swift:569-573) but not the covered-results case; runtime check: open a search result, leave it pushed, run Find-all-mentions from People — expect the stale document on arrival

### H-5. iOS Cross-Reference Analytics: tapping a document or volume opens it invisibly beneath the sheet
*iOS · verified · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** In the Browse tab's Cross-Reference Analytics sheet, tapping a most-referenced document, a PageRank landmark, or a heat-matrix volume appears to do nothing. The sheet stays up; only after manually closing it does the user discover the document(s) silently stacked on the Browse stack — one per tap they retried.

**Mechanism.** CrossReferenceAnalyticsView.openDocument (iOS branch) calls appState.openBrowseDocument + openTab(.browse) with no dismissal — the file contains zero references to dismiss. The consumer is BrowserView, which is the very view PRESENTING this sheet (Browse tab, 'Analysis Tools' menu), so the navigationPath append happens beneath the still-presented sheet. openVolume has the same defect. Contrast: ChronologyView deliberately pushes documents INLINE inside its sheet stack for exactly this reason, and ProjectHomeView defers hand-offs behind an explicit sheet dismissal (#431).

**Evidence.**
- `FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift:1205` — iOS branch: openBrowseDocument + openTab(.browse); no dismiss anywhere in the file (grep verified)
- `FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift:1221` — openVolume: same pattern for volume taps
- `FRUSExplorer/Browser/BrowserView.swift:197` — the sheet is presented BY BrowserView — the same view whose stack consumes the hand-off
- `FRUSExplorer/Browser/BrowserView.swift:625` — consumePendingBrowseDocument appends to vm.navigationPath beneath the presented sheet
- `FRUSExplorer/Chronology/ChronologyView.swift:113` — sibling sheet solved this by pushing inline — proves the pattern was known

**Verifier.** Mechanism verified end to end. CrossReferenceAnalyticsView.swift contains zero references to dismiss (grep verified; sibling ChronologyView declares @Environment(\.dismiss) at :36 and calls it at :199/:1098/:1179). The iOS branch of openDocument (:1210-1213) does openBrowseDocument + openTab(.browse); openVolume (:1221-1225) is identical; real tap targets call both (Buttons at :740-741, :939, :961, :1071-1072). BrowserView presents this very sheet (:197-208) and injects its OWN sceneID into it (:203), so the handoff is addressed to and consumed by the BrowserView sitting beneath the sheet — consumePendingBrowseDocument (BrowserView.swift:625-636, append at :632) writes only vm.navigationPath and never touches showCrossRefAnalytics. openTab(.browse) is a no-op (already on Browse) and dismisses nothing. The ChronologyView contrast is exact: :113-116 pushes DocumentBrowserEntry inline via navigationDestination inside the sheet's own stack. 'Likely' is the right confidence (the visual claim that a push beneath a presented sheet shows nothing needs the named runtime check, but no code path dismisses or presents in-sheet). One severity nuance the finding's symptom already concedes: after manually closing the sheet the user DOES land on the last-tapped document, so nothing is lost — 'high' rests on the no-feedback dead-tap plus one stacked duplicate per retry polluting the back stack, which is within the rubric's 'lands somewhere wrong'.

*Related known:* Runtime check to settle: on iPhone, open Browse → Analysis Tools → Cross-Reference Analytics, tap a most-referenced document; confirm the sheet remains and the Browse stack gains the document only after manual dismissal. ProjectHomeView.swift:899-914 (#431) is the handled counterpart.

### H-6. iOS relaunch restores which tab you were on but nothing inside it — reading position, browse depth, and search are all lost
*iOS · verified · state persistence & restoration — what survives a tab switch, a window close, and an app relaunch, on both platforms*

**Symptom.** A researcher deep in a document (Browse ▸ subseries ▸ volume ▸ document) switches to another app; iOS terminates FRUS Explorer in the background (routine under memory pressure). Reopening restores the Browse tab as selected — implying continuity — but shows the corpus root: the document, the path to it, and any in-progress search text/results/filters are gone, with no 'continue reading' re-seed offered.

**Mechanism.** The app's entire scene-restoration surface is four @SceneStorage keys, and only frus.selectedTab covers the main UI. Every navigation holder is process-lifetime state: Browse position lives in BrowserViewModel.navigationPath inside @State viewModel (created fresh by bootstrapViewModel), Search keywords/results live in SearchViewModel inside @State vm, Research's selectedItem is @State. Nothing encodes these into SceneStorage or re-seeds them from the SwiftData reading history at launch; the .userActivity on DocumentView is Handoff-eligible only, not a restoration activity. The tab wrapper comments confirm tab-switch survival was engineered (stable @State identity) — relaunch survival simply has no mechanism.

**Evidence.**
- `FRUSExplorer/App/MainTabView.swift:90` — @SceneStorage("frus.selectedTab") — the only piece of main-UI state that survives relaunch
- `FRUSExplorer/Browser/BrowserView.swift:102` — @State private var viewModel: BrowserViewModel? — Browse path dies with the process; bootstrapViewModel() at :651-664 creates it empty with no re-seed
- `FRUSExplorer/Search/SearchView.swift:276` — _vm = State(initialValue: SearchViewModel(...)) — keywords, results, filters, and navigationPath (SearchViewModel.swift:437) all session-only
- `FRUSExplorer/Research/ResearchView.swift:170` — @State private var selectedItem: ResearchSidebarItem? — Research tab position session-only
- `FRUSExplorer/DocumentView/DocumentView.swift:426` — activity.isEligibleForHandoff = true — Handoff only; no restoration-activity path exists

**Verifier.** The restoration surface is exactly as claimed, with one immaterial imprecision. Full @SceneStorage inventory: 4 declarations / 3 distinct keys — MainTabView.swift:90 (frus.selectedTab), SearchSheet.swift:118 (search.facets.shown, macOS window), SearchSheet.swift:122 + SearchView.swift:249 (search.inspector.expanded). Quibble: search.inspector.expanded at SearchView.swift:249 IS in the iOS main UI, so 'only frus.selectedTab covers the main UI' is slightly overstated — but it is a disclosure toggle, not navigation, so the substantive claim (no navigation, search, or reading state survives) holds. All holders verified process-lifetime: BrowserView.swift:102 @State viewModel with bootstrapViewModel (:651-664) creating it empty and no re-seed; SearchView.swift:272-278 State(initialValue: SearchViewModel(...)) with navigationPath a plain session var in SearchViewModel; ResearchView iOS selectedItem a plain optional @State. DocumentView.swift:423-427 sets only isEligibleForHandoff = true; the app's only onContinueUserActivity handlers (FRUSExplorerApp.swift:1177, :1181) serve incoming Handoff/Spotlight continuations, not scene restoration, and no stateRestorationActivity/resume-reading mechanism exists anywhere (greps empty). BrowserTabView's doc comment (MainTabView.swift:311-316) confirms tab-switch survival was deliberately engineered while relaunch survival has no mechanism, and the aux document windows' value-based restoration (FRUSExplorerApp.swift:496-498, #317) confirms the cited inconsistency that the main window is the surface that forgets. 'Certain' is earned; note for the caller that this is a missing-capability finding (nothing malfunctions — the mechanism was never built), which the rubric still scores high because a background termination silently discards the researcher's position.

*Related known:* #323 shows the iPad aux document windows DO restore their document across relaunch — making the main window the only surface that forgets, which sharpens the inconsistency

### H-7. Standalone iPad document window ships its reading actions to the launching window, which is never brought forward
*iOS · verified · Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms*

**Symptom.** In a Stage Manager standalone document window, tapping a cross-reference, using the edge-tap page-turn gesture, or 'Find All Mentions' appears to do nothing: the current window keeps showing the same document while the target document/search opens in the launching main window, which may be in another stage or behind — nothing activates it.

**Mechanism.** The document WindowGroup republishes the LAUNCHING window's scene as its \.sceneID via .auxWindowOrigin (FRUSExplorerApp.swift:527-529 comment says exactly this: 'this document window's rail producers (cross-ref, edge-tap, word cloud) route back to it'). DocumentView's cross-ref handler and navigateToAdjacentDocument write openTab(.browse)+openBrowseDocument targeted at that origin scene (DocumentView.swift:969-971, 1531-1537); the origin window's BrowserView consumes and appends to ITS navigation path (BrowserView.swift:625-636). No code anywhere calls UIScene activation (grep for requestSceneSessionActivation: zero hits), so the consuming window is not fronted. The standalone window has no BrowserView of its own, so locally nothing changes.

**Evidence.**
- `FRUSExplorer/App/FRUSExplorerApp.swift:527` — '#338 aux-window origin: republish the launching window's scene so this document window's rail producers (cross-ref, edge-tap, word cloud) route back to it' — routing away from the user's window is the design
- `FRUSExplorer/DocumentView/DocumentView.swift:1533` — navigateToAdjacentDocument (edge-tap page-turn): openTab(.browse, from: sceneID) + openBrowseDocument(adjacent, from: sceneID) — sceneID is the ORIGIN window inside the standalone window
- `FRUSExplorer/App/AppState.swift:2021` — AuxWindowOriginModifier publishes resolveOriginScene(originRaw) as \.sceneID for all descendants of the aux window
- `FRUSExplorer/Browser/BrowserView.swift:630` — consumption appends to the ORIGIN window's browse path; nothing activates that scene

**Verifier.** The comment at FRUSExplorerApp.swift:527-529 is verbatim as quoted, and AuxWindowOriginModifier republishes the launching window's scene as \.sceneID for all descendants (AppState.swift:2015-2028, the environment write at 2021). DocumentView reads that environment (DocumentView.swift:231), so its cross-ref handler (968-971), edge-tap page-turn (navigateToAdjacentDocument, 1531-1539), and Find All Mentions (562-573, openSearch + openTab(.search, from: sceneID)) all address the ORIGIN window. The standalone window's content is a bare NavigationStack{DocumentView} (FRUSExplorerApp.swift:505-511) — no BrowserView or MainTabView, so no local consumer exists and nothing changes in the user's window. The consumer is the origin window's BrowserView/MainTabView (BrowserView.swift:625-636), and a repo-wide grep for requestSceneSessionActivation returns zero hits, so nothing fronts that scene. Even when the origin window has closed, resolveOriginScene falls back to .anyWindow — still some OTHER window. The one residual runtime nuance: if the origin window happens to share the same Stage Manager stage, the user would see it change rather than 'nothing'; the finding's 'may be in another stage or behind' already states this accurately.

*Related known:* #338 aux-window origin design (fan-out fix); the routing is deliberate — the missing half is scene activation, and for page-turn the routing target itself is arguably wrong (the standalone window should page itself)

### H-8. iOS 'Visualize in Corpus Analytics' / 'View in Chronology' hand-off is silently dropped when the Browse tab was never opened
*iOS · verified · Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms*

**Symptom.** User taps 'Visualize in Corpus Analytics' from Search (or Analyze/Chronology inside a word cloud); the app switches to the Browse tab but no chart/chronology sheet appears and the query context is lost. Repeating the action works, because Browse now exists.

**Mechanism.** pendingAnalytics/pendingChronology are consumed ONLY by BrowserView's .onChange observers (BrowserView.swift:224-235); BrowserView.onAppear drains pendingBrowseDocument and pendingBrowseVolume but NOT analytics/chronology (BrowserView.swift:236-246 — the comment there documents that 'Browse may be freshly instantiated' and fixes exactly this class of bug for the two browse channels only). Producers write the slot then openTab(.browse) (SearchView.swift:1370-1383, WordCloudView.swift:1424-1443); if the Browse tab content is created by that very tab switch, .onChange never fires for the pre-set value, there is no drain, and the hand-off parks until a LATER hand-off overwrites it. SearchView shows the correct pattern the sheet consumers lack: its .task drains pendingSearch precisely for 'the Search tab is being created for the first time' (SearchView.swift:509-512).

**Evidence.**
- `FRUSExplorer/Browser/BrowserView.swift:224` — onChange(of: appState.pendingAnalytics) — the only iOS consumer; no onAppear/.task drain exists for this slot
- `FRUSExplorer/Browser/BrowserView.swift:244` — onAppear drain covers only consumePendingBrowseDocument()/consumePendingBrowseVolume(); comment concedes 'Browse may be freshly instantiated'
- `FRUSExplorer/Search/SearchView.swift:1383` — producer: openAnalytics then openTab(.browse) — the tab switch that instantiates Browse is the same action that needs the drain
- `FRUSExplorer/Search/SearchView.swift:512` — SearchView's own .task drain ('the Search tab is being created for the first time') — the asymmetry that leaves analytics/chronology exposed

**Verifier.** Every evidence quote is real. BrowserView.swift:224-235 holds the ONLY iOS consumers of pendingAnalytics/pendingChronology (codebase-wide grep: AnalyticsView.swift:1023/1057 and ChronologyView.swift:129/156 consume only the .macAnalytics/.macChronology fixed targets, which can never match an iOS scene token), and they are .onChange-only. The onAppear drain at BrowserView.swift:236-246 covers only consumePendingBrowseDocument/Volume; BrowserTabView (MainTabView.swift:328-350) is a bare wrapper with no drain. Producers confirmed writing the slot before the tab switch: SearchView.swift:1370-1384 (openAnalytics, then openTab(.browse) at :1383) and WordCloudView.swift:1424-1442 (openAnalytics + openTab + dismiss). The 'onChange never fires for pre-set state on a freshly created tab' premise is the app's own documented, measured behavior (MainTabView.swift:184-187 drains pendingTab in onAppear for exactly this reason; SearchView.swift:509-512 drains pendingSearch in .task for 'the Search tab is being created for the first time'). No compensating drain exists anywhere. The one residual assumption — that the TabView instantiates Browse lazily — is what keeps this 'likely' rather than 'certain', matching the finding's self-rating; the named runtime check (fresh launch on Search tab, Visualize) would settle it. Severity high is honest: the tab switch fires (pendingTab has an onAppear drain) but the content does not, so the user lands on the Browse root with nothing presented.

*Related known:* #369 BUG-11 fixed the sheet presenting on a backgrounded tab by adding the openTab; the cold-tab drop is the remaining half. Runtime check: fresh launch with last tab = Search, run a search, tap Visualize — sheet should appear but won't.

### H-9. Word Cloud button in a restored or orphaned standalone document window does nothing, forever — .anyWindow has no pendingWordCloud consumer
*iOS · verified · Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms*

**Symptom.** After an app relaunch restores a standalone iPad document window (or after the launching window is closed), tapping the Research rail's Word Cloud tile does nothing — no sheet, no error — on every attempt. When the launching window IS alive, the cloud presents in that other window instead of the one tapped.

**Mechanism.** In the standalone window, \.sceneID is resolveOriginScene(originRaw): a restored window captures originRaw == nil (pendingAuxWindowOriginRaw is transient, AppState.swift:757-760), and a closed launcher fails the liveSceneIDs check — both yield .anyWindow (AppState.swift:1843-1847). openWordCloud then targets .anyWindow (AppState.swift:1883 — sceneID is non-nil so not even the 'unreached' debug print fires). The only iOS consumer is MainTabView's sheet(item:) binding, which matches handoff.target == its own token with NO .anyWindow acceptance (MainTabView.swift:209-210) — unlike pendingSearch/pendingTab/pendingBrowse*, which use orAnyWindow. The hand-off parks in the slot until some other word-cloud action overwrites it. This contradicts AppState.swift:1770-1773's claim that .anyWindow 'never black-holes'.

**Evidence.**
- `FRUSExplorer/App/MainTabView.swift:210` — guard handoff.target == SceneID(sceneIDToken) — exact match only; no orAnyWindow path for the word-cloud sheet
- `FRUSExplorer/App/AppState.swift:1846` — resolveOriginScene: closed/unknown origin → .anyWindow — a target no word-cloud consumer accepts
- `FRUSExplorer/DocumentView/DocumentView.swift:1115` — rail Word Cloud producer: openWordCloud(.document(...), from: sceneID) — comment above assumes MainTabView 'an ANCESTOR of this view', false in the standalone window
- `FRUSExplorer/App/AppState.swift:1770` — doc comment: .anyWindow is 'first-wins, not a broadcast … never black-holes' — untrue for pendingWordCloud

**Verifier.** Fully traced with no compensating code. MainTabView.swift:207-213: the sheet(item:) binding guards handoff.target == SceneID(sceneIDToken) — exact match, no orAnyWindow variant (unlike pendingBrowseDocument/Volume at BrowserView.swift:631/643 and pendingSearch at SearchView.swift:633, which pass orAnyWindow: true). Grep confirms this is the ONLY iOS consumer of pendingWordCloud. The standalone document window is WindowGroup(for: DocumentWindowID.self) (FRUSExplorerApp.swift:500-530), explicitly restorable across scene lifecycle (:496-498), with .auxWindowOrigin at :529; AuxWindowOriginModifier (AppState.swift:2015-2028) captures the transient pendingAuxWindowOriginRaw once (nil on a restored window per AppState.swift:755-760) and publishes \.sceneID = resolveOriginScene(originRaw) LIVE on every body — so a launcher closing later also degrades to .anyWindow (AppState.swift:1843-1847). The rail producer (DocumentView.swift:1107-1117) then calls openWordCloud(from: .anyWindow); AppState.swift:1883 stamps target .anyWindow (non-nil, so the :1877-1881 debug print never fires). Result: no consumer ever matches; the handoff parks until overwritten. The cited contradiction is real — AppState.swift:1770-1772 ('never black-holes') and :1839-1842 ('in *some* live window (never nowhere)'). The live-launcher half (cloud presents in the launcher window, not the tapped one) is also confirmed and is arguably by design per FRUSExplorerApp.swift:527-529, but the restored/orphaned case is an unhandled dead end. Note: openWordCloud's own comment (AppState.swift:1872-1876) documents a graceful no-op for the NIL-sceneID standalone-window case — but the aux-origin work later made that window publish .anyWindow instead of nil, which silently routed it around even that acknowledged diagnostic. Severity high is defensible: a permanently dead control among rail siblings that all work, plus wrong-window presentation when the launcher lives.

*Related known:* #338 step 2/step 4 — the wildcard-acceptance discipline was applied to browse/search/tab consumers but never to the word-cloud sheet

### H-10. Cross-ref links and edge-tap page-turns inside sheet-hosted documents navigate invisibly beneath the sheet
*iOS · finder-likely · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** Reading a document inside the Chronology sheet, the Citation Lookup sheet, or the in-document cross-reference-graph sheet, tapping a <ref> link (or edge-tapping prev/next) appears to do nothing — the sheet stays up showing the same document, while the target is pushed onto the Browse tab underneath. Users discover a pile of mystery documents on their Browse stack later.

**Mechanism.** DocumentView.handleCrossRefTap → navigateToCrossRef and navigateToAdjacentDocument both route EVERY document-to-document jump through openTab(.browse) + openBrowseDocument, regardless of host. When DocumentView is hosted inside a presented sheet (ChronologyView's navigationDestination, CitationLookupView's stack, or the .crossReferenceGraph sheet whose graph pushes documents inline), the Browse-tab append happens beneath the sheet and nothing dismisses it — no dismissal exists on this path.

**Evidence.**
- `FRUSExplorer/DocumentView/DocumentView.swift:968` — navigateToCrossRef: openTab(.browse) + openBrowseDocument — no sheet dismissal
- `FRUSExplorer/DocumentView/DocumentView.swift:1531` — navigateToAdjacentDocument: identical routing for edge-tap page-turns; doc comment asserts it 'keeps behaviour predictable'
- `FRUSExplorer/Chronology/ChronologyView.swift:114` — DocumentView pushed INSIDE the chronology sheet's stack — its ref taps then go beneath the sheet
- `FRUSExplorer/Citation/CitationLookupView.swift:138` — iOS lookup sheet pushes DocumentView in its own stack — same exposure
- `FRUSExplorer/DocumentView/DocumentView.swift:603` — graph sheet: CrossReferenceGraphView pushes documents inline (CrossReferenceGraphView.swift:336); refs inside those go beneath two layers

*Related known:* Runtime check: open Chronology on iPhone, open a row's document, tap any cross-reference — verify the sheet persists unchanged. Same shape as finding 1; #431's deferred-dismiss machinery (ProjectHomeView.swift:907-914) exists but is not used here.

### H-11. Analytics/Chronology hand-off silently dropped when the Browse tab has never been shown (onChange-only consumption)
*iOS · finder-likely · Modal/sheet/inspector/popover presentation state (iOS + macOS)*

**Symptom.** Tap "Visualize in Corpus Analytics" from Search, or "Analyze"/"View in Chronology" from a word cloud, when the Browse tab in that window has not yet been displayed (cold launch on another tab, or a fresh iPad window): the app switches to the Browse tab and nothing appears. The chart/timeline the user asked for never opens; the hand-off is lost (a later hand-off overwrites the parked one).

**Mechanism.** BrowserView consumes pendingAnalytics/pendingChronology only in .onChange (BrowserView.swift:224-235). .onChange never fires for a value set before the view attaches, and BrowserView's .onAppear drain (236-246) covers only pendingBrowseDocument/pendingBrowseVolume — its own comment (238-243) states the channels "can be set BEFORE BrowserView exists ... and Browse may be freshly instantiated", which is exactly the producers' sequence: openAnalytics/openChronology then openTab(.browse) (SearchView.swift:1371-1385; WordCloudView.swift:1424-1447, 1584-1600). Every sibling channel drains both ways (pendingSearch: SearchView.swift:495-513 + 527-529; pendingTab: MainTabView.swift:181-194); analytics and chronology are the only two iOS hand-offs with no appear-time drain.

**Evidence.**
- `FRUSExplorer/Browser/BrowserView.swift:224` — .onChange(of: appState.pendingAnalytics) → consumeHandoff — the ONLY iOS consumption path; chronology twin at 230-235
- `FRUSExplorer/Browser/BrowserView.swift:236` — .onAppear drains consumePendingBrowseDocument/Volume only; the 238-243 comment concedes values are set before BrowserView exists
- `FRUSExplorer/Search/SearchView.swift:1371` — producer: appState.openAnalytics(...) then openTab(.browse) — the sequence that instantiates Browse after the set
- `FRUSExplorer/Search/SearchView.swift:495` — contrast: pendingSearch is drained in .task exactly for this race ("the Search tab is being created for the first time")

*Related known:* Same bug class the repo already fixed for pendingBrowseDocument/pendingBrowseVolume ("cumulative-review fix") and for pendingSearch (Session 162); the fix was never extended to the two analytics channels.


## Medium-severity findings

### M-12. 7 of 9 main-window toolbar launchers never re-front an already-open buried tool window
*macOS · verified · macOS window management and focus*

**Symptom.** With a tool window open but behind the main window, clicking the main window's titlebar Search or Browse button — or Analytics ▸ Corpus Analytics / Chronology / Word Cloud, or My Research ▸ Research / Collections — appears to do nothing: the buried window stays buried. The same actions from the menu bar work (they front the window). The Analytics dropdown is internally inconsistent: Person Analytics and Cross-Reference Analytics front their windows, the other three items do not. Worst case is Word Cloud: the buried cloud window is silently retargeted to corpus scope (its onChange consumes the hand-off), so a volume/collection cloud the user had set up is clobbered without the window ever surfacing.

**Mechanism.** These seven sites call bare openWindow(id:) with no bringMacWindowToFront. The codebase's own helper documentation records the measured gap: openWindow(id:) reliably creates a closed singleton (which fronts itself) but 'does not always re-raise a window that is already open behind another one' (MainWindowView.swift:445-450). Consumers never front themselves (e.g. WordCloudWindowContent just consumes pendingWordCloud via onChange, WordCloudView.swift:1721-1726), so fronting is entirely the producer's responsibility — and these producers omit it while their two menu siblings (lines 306-307, 314-315) and all menu-bar equivalents (FRUSExplorerApp.swift:2807-2835, 2894-2906) include it.

**Evidence.**
- `FRUSExplorer/App/MainWindowView.swift:266` — Search button: bindTool + openWindow(id: "frus.search") only; same pattern at 282 (corpusBrowser), 299 (analytics), 323 (chronology), 331 (wordcloud), 354 (research), 360 (collections)
- `FRUSExplorer/App/MainWindowView.swift:307` — Inconsistent siblings in the same Analytics menu: personAnalytics (306-307) and crossRefAnalytics (314-315) DO call bringMacWindowToFront
- `FRUSExplorer/App/MainWindowView.swift:447` — bringMacWindowToFront doc comment records the measured openWindow(id:) re-raise gap ('Corpus Analytics → Search … stays buried behind the window the user is looking at')
- `FRUSExplorer/Analytics/WordCloud/WordCloudView.swift:1721` — WordCloudWindowContent .onChange retargets an already-open window's scope on any hand-off — combined with no fronting, the toolbar item silently clobbers a buried cloud's scope to corpus
- `FRUSExplorer/App/FRUSExplorerApp.swift:2809` — Menu-bar Analytics commands all pair openWindow with bringMacWindowToFront (2809-2834), as do Research-menu items (2896-2904) — the toolbar is the systematic outlier

**Verifier.** Read the whole trailingTools toolbar (MainWindowView.swift:258-399): exactly 9 launcher items, and exactly the 7 claimed sites call bare openWindow(id:) with no bringMacWindowToFront — Search (264-266), Browse (280-282), Corpus Analytics (297-299), Chronology (321-323), Word Cloud (328-331), Research (352-354), Collections (360) — while their two Analytics-menu siblings Person Analytics (304-307) and Cross-Reference Analytics (312-315) do front, an in-menu inconsistency. The helper's doc comment (MainWindowView.swift:443-457) records the codebase's own measurement of the openWindow(id:) re-raise gap, quoting the exact 'does not always re-raise a window that is already open behind another one' text and the buried-Search example. Menu-bar equivalents all pair openWindow with bringMacWindowToFront: AnalyticsMenuContent (FRUSExplorerApp.swift:2807-2835, all five items) and ResearchMenuContent (2894-2905). The Word Cloud worst case is real: the toolbar button seeds appState.openWordCloud(.corpus, from: nil) at line 329 BEFORE opening, and WordCloudWindowContent's .onChange (WordCloudView.swift:1721-1726) consumes the hand-off and retargets an already-open window's scope — so a buried cloud configured on a volume/collection scope is clobbered to corpus without surfacing. I hunted for compensating consumer-side fronting via a codebase-wide grep of bringMacWindowToFront/makeKeyAndOrderFront/orderFront: every call is producer-side; no tool window fronts itself on hand-off. Confidence likely is correct — the residual assumption is the documented-in-repo 'not always re-raises' runtime behavior, corroborated by the #369 BUG-9 fix history (HistoryWindowView.swift:138).

*Related known:* #369 BUG-9 added bringMacWindowToFront to 'the eight sibling producers' (HistoryWindowView.swift:138 cites it); the main-window toolbar was not covered by that sweep.

### M-13. Graph context menus retarget a buried Cross-Reference Graph window without fronting it — its content changes silently
*macOS · verified · macOS window management and focus*

**Symptom.** Right-clicking a document → 'Show Cross-Reference Graph' in the Corpus Browser, or 'Show Cross-References' in the Research window, does nothing visible when the graph window is already open behind other windows. Worse: the buried graph window HAS silently switched to the newly chosen document, so when the user later brings it forward expecting the graph they left there, it shows a different document's graph with no explanation.

**Mechanism.** Both sites set appState.currentGraphEntry and call bare openWindow(id: "frus.crossReferenceGraph") with no bringMacWindowToFront. CrossReferenceGraphWindowView binds currentGraphEntry LIVE (body's if-let + .id retarget), so an open window re-renders for the new entry immediately whether or not it is visible. Sibling producers of the same window do front it (ResearchRailView.swift:726-727; MacCorpusBrowserWindow.swift:398-399), so the omission is site-specific, not a design choice.

**Evidence.**
- `FRUSExplorer/App/MacCorpusBrowserWindow.swift:1375` — documentButton context menu: currentGraphEntry = doc; bindTool(.graph,…); openWindow(id: "frus.crossReferenceGraph") — no bringMacWindowToFront (contrast line 398-399 in the same file)
- `FRUSExplorer/Research/ResearchView.swift:683` — #if os(macOS) context item 'Show Cross-References': same bare openWindow — while the wordCloudButton in the same file fronts (649-650)
- `FRUSExplorer/CrossReference/CrossReferenceGraphWindowView.swift:110` — Targeted mode reads appState.currentGraphEntry live with .id(entry.id…) — an open-but-buried window retargets immediately
- `FRUSExplorer/DocumentView/ResearchRailView.swift:727` — The rail's Graph tile, a sibling producer, pairs openWindow with bringMacWindowToFront

**Verifier.** Both bare sites verified: MacCorpusBrowserWindow.swift:1371-1380 (documentButton context menu sets appState.currentGraphEntry, bindTool(.graph,…), then bare openWindow(id: "frus.crossReferenceGraph") at 1375) and ResearchView.swift:672-691 ('Show Cross-References' sets currentGraphEntry at 680, bare openWindow at 683). The live-retarget mechanism is confirmed: CrossReferenceGraphWindowView.body (CrossReferenceGraphWindowView.swift:108-125) reads appState.currentGraphEntry directly in an if-let with .id("\(entry.id)-…") at 120, and currentGraphEntry is plain shared observable state that this window never consumes or clears — so any producer's write re-renders an open-but-buried window immediately (unlike pendingVolumeGraph, which IS consume-and-clear at 132-136). The site-specific-omission claim holds: sibling producers of the same window front it — the same file's volume-graph button (MacCorpusBrowserWindow.swift:396-399) and the rail's openGraph (ResearchRailView.swift:723-728) both pair openWindow with bringMacWindowToFront, and the same ResearchView's wordCloudButton fronts at 649-650. No compensating self-fronting exists anywhere (codebase-wide fronting-call grep is all producer-side). Severity medium and confidence likely (the one assumption is the same in-repo-documented openWindow re-raise gap as the toolbar finding) are both honest.

*Related known:* #369 BUG-9 (refocus sweep) fixed sibling producers; these two context-menu sites were missed. Same silent-retarget class as #369 BUG-8's Source Explorer live-binding flicker, which was fixed with sourceNoteFocusID.

### M-14. Mid-session volume add/remove never rebuilds the person rollup — People browser shows ghosts or misses new people until relaunch
*both · verified · state invalidation & staleness*

**Symptom.** Remove a volume via the Volumes & Storage hub: the People browser still lists people whose only mentions were in that volume, with their old mention counts; opening one shows the removed volume among its members while 'Find all mentions' returns fewer or zero results. Conversely, download and index a new volume mid-session: its people never appear in the People browser (and rollup-based person analytics/search miss its mentions) until the app is relaunched.

**Mechanism.** consolidatePersonRollupIfNeeded is called from exactly four places: the three launch branches (FRUSExplorerApp.swift:1596/1615/1628) and user corrections (PersonClusterOverrideStore:98). No volume add/remove/reindex path calls it: removeVolumes in both storage hubs calls pipeline.removeVolume + refreshReadOnlyStores only — reopening connections does not rebuild data — and auxDeleteVolume deletes persons/person_mentions rows but does NOT touch person_rollup or person_rollup_member (neither table is in its list at 5866-5884, nor in removeAllVolumesFromIndex at 1560-1566). The materialized person_rollup therefore keeps the removed volume's members and stale mention_count/volume_count until the next launch, when the count-based drift check (members != persons, IndexingPipeline:800-802) finally fires.

**Evidence.**
- `FRUSExplorer/Search/IndexingPipeline.swift:5866` — auxDeleteVolume's table list omits person_rollup and person_rollup_member — dangling member rows and stale materialized counts survive
- `FRUSExplorer/Settings/VolumesStorageHubView.swift:1228` — removeVolumes: removeVolume + refreshReadOnlyStores + loadReport — no consolidation (macOS twin MacVolumesStorageHub.swift:1182 identical)
- `FRUSExplorer/Search/IndexingPipeline.swift:795` — consolidatePersonRollupIfNeeded — grep-verified callers are only the 3 boot branches + corrections; nothing on index/remove paths
- `FRUSExplorer/Search/IndexingPipeline.swift:800` — drift check members != persons catches it only at the NEXT launch's gated call
- `FRUSExplorer/App/FRUSExplorerApp.swift:1645` — post-download reconcile loop indexes volumes with no follow-up consolidation

**Verifier.** Fully traced; I could not refute it. Grep confirms consolidatePersonRollupIfNeeded has exactly three callers — the three launch branches at FRUSExplorerApp.swift:1596/1615/1628 — plus PersonClusterOverrideStore.swift:98 calling consolidatePersonRollup directly for user corrections (the finding's only trivial imprecision: :98 calls the non-gated variant, which changes nothing). No add/remove path consolidates: IndexingPipeline.removeVolume (:1531-1537) only nils cachedClusterInputs and calls auxDeleteVolume, whose table list (:5866-5884) omits person_rollup and person_rollup_member (so member rows for the removed volume and stale mention_count survive while person_mentions/persons rows are deleted — exactly the ghost-with-broken-mentions symptom); removeAllVolumesFromIndex (:1560-1566) omits both tables too; indexVolume (:1294-1354) ends at Spotlight submission with no consolidation; both hubs' removeVolumes (VolumesStorageHubView.swift:1228-1245, MacVolumesStorageHub.swift:1182-1199) do removeVolume + refreshReadOnlyStores + loadReport only — and refreshReadOnlyStores reopens connections, it rebuilds nothing; the launch reconcile loop (:1645-1661) indexes with no follow-up. The drift check members != persons (:800-802) fires only at the next gated call, i.e. next launch or a user correction. 'Certain' is justified — every path enumerated in shipped code.

*Related known:* #275 is about stale read-only CONNECTIONS (fixed); this is stale materialized DATA the reopened connections faithfully re-read.

### M-15. Cross-refs inside Chronology / Citation-Lookup / Graph-sheet documents navigate invisibly behind the sheet
*iOS · verified · iOS tab & stack navigation, and BACK behavior*

**Symptom.** The user opens a document inside the Chronology sheet (or Citation Lookup, or the Cross-Reference Graph sheet) and taps a cross-reference. Nothing visible happens — the tap looks dead. When they eventually tap Done, they discover the app has moved them to the cross-ref target in the Browse tab, with their chronology/lookup context gone.

**Mechanism.** These three sheets push DocumentView on their own internal stacks (ChronologyView.swift:87/114/1152; CitationLookupView.swift:104/138-140; CrossReferenceGraphView.swift:238-241/336). A cross-ref inside those documents still routes via openTab(.browse)+openBrowseDocument (DocumentView.swift:968-971); BrowserView consumes it and appends beneath the still-presented sheet — nothing dismisses these sheets on a pendingBrowseDocument write (ChronologyView's only dismiss triggers are Done/:1098, word-cloud/:199, search-in-range/:1179). The codebase knows this failure mode and guards it elsewhere: SourceExplorerView dismisses itself before its related-doc callback (SourceExplorerView.swift:82-83, 1971-1972) and Project Home's sheet dismisses on hand-off precisely because "otherwise the navigation happens invisibly behind the modal" (ResearchView.swift:190-193). These three hosts miss the same guard.

**Evidence.**
- `FRUSExplorer/Chronology/ChronologyView.swift:1152` — iOS pushes the document inline inside the sheet's stack
- `FRUSExplorer/DocumentView/DocumentView.swift:969` — cross-ref inside that document targets the Browse tab, not the sheet's stack
- `FRUSExplorer/Research/ResearchView.swift:192` — the repo's own comment naming invisible-behind-the-modal as the reason Project Home dismisses first
- `FRUSExplorer/SourceExplorer/SourceExplorerView.swift:1971` — contrast: Source Explorer dismisses itself before invoking the navigation callback

**Verifier.** Fully traced with no compensating dismissal anywhere. ChronologyView is a .sheet from BrowserView (BrowserView.swift:209-210) and on iOS pushes DocumentView on its own stack (navigationDestination ~113-115; row push navigationPath.append at 1152; only dismiss = Done at 1098). CitationLookupView: same shape (~138-140), presented as .sheet from SearchView:472-474. CrossReferenceGraphView: iOS navigationDestination at 238-241 and inline push at 336, presented as a detented sheet from DocumentView (~605-615). DocumentView.navigateToCrossRef (950-971) unconditionally routes openTab(.browse) + openBrowseDocument for EVERY document cross-ref — DocumentView(entry:) takes no host callback, so the sheet-hosted instance cannot be overridden. The handoff's only iOS consumer is BrowserView (onChange :152 → consumePendingBrowseDocument :625-636), which just appends to vm.navigationPath — nothing sets showChronology/showCitationLookup/the graph flag false on a pendingBrowseDocument write. The contrast guards are real: ResearchView.swift:190-192 ('otherwise the navigation happens invisibly behind the modal') and SourceExplorerView.swift:82-83 + 1970-1972 (dismiss() before the callback). The finder's 'likely' rested only on standard sheet-over-stack behavior, which the repo's own ResearchView comment asserts as the observed failure mode — I'd treat the mechanism as confirmed; the suggested one-tap runtime check remains the final validation.

*Related known:* runtime check: open Chronology, push a document, tap any cross-ref — expect no visible change until Done

### M-16. Research, History, Project-leads, Related-Documents and Archival-Neighbors opens: Back unwinds the old Browse stack, never the origin surface
*iOS · verified · iOS tab & stack navigation, and BACK behavior*

**Symptom.** Tapping a document in the Research tab, History, Project Home's leads list, a Related Documents sheet, or Archival Neighbors jumps to the Browse tab. After reading, Back does not return to the list the user came from — it steps down whatever Browse hierarchy existed before (possibly a different volume browsed earlier in the session, or straight to the corpus root). Working through a leads/history list means a manual tab switch (and for leads, re-opening the Project Home sheet) after every single document.

**Mechanism.** All five producers use the same pair: `openBrowseDocument` + `openTab(.browse)` — ResearchView.swift:705-710 (doc comment says "navigates to Browse (iOS)"), HistoryView.swift:457-467, ProjectHomeView.swift:864-877 (its sheet is dismissed via performNavigation/onNavigateAway), RelatedDocumentsView.swift:401-413 (sheet dismisses via onNavigate), ArchivalNeighborsSheet.swift:485-500. The consumer appends to the existing Browse path (BrowserView.swift:632), so the pushed document's Back target is whatever the user last browsed, unrelated to the origin. The origin tab's own stack survives (BrowserTabView-style identity wrappers, MainTabView.swift:313-317), so the origin is recoverable — but only by a tab tap the UI never hints at.

**Evidence.**
- `FRUSExplorer/Research/ResearchView.swift:708` — Research doc open → openBrowseDocument + openTab(.browse)
- `FRUSExplorer/ProjectContext/ProjectHomeView.swift:874` — leads open the Browse tab; the Project Home sheet is dismissed, so each lead costs a full re-entry
- `FRUSExplorer/History/HistoryView.swift:466` — History document rows: same routing
- `FRUSExplorer/Browser/BrowserView.swift:632` — append onto the pre-existing Browse path — Back target is arbitrary relative to origin

**Verifier.** All five producers verified verbatim on their iOS branches: ResearchView.swift:705-710, HistoryView.swift:457-468 (doc comment even names it 'the shape ResearchView.openDocument uses'), ProjectHomeView.swift:864-877 with performNavigation (907-913) invoking onNavigateAway — confirming the sheet dismisses so each lead costs a full Research-tab → Project Home re-entry, RelatedDocumentsView.swift:398-413 (onNavigate?() dismisses the sheet), ArchivalNeighborsSheet.swift:485-500. The consumer (BrowserView.swift:625-632) appends .document(entry) onto the EXISTING vm.navigationPath with no pop/reset, so Back steps down whatever the user last browsed. MainTabView's BrowserTabView wrapper (~311-317) confirms the Browse stack deliberately survives tab switches, making the stale-stack Back target the norm, and also confirms the origin tab's own stack survives for manual recovery. One framing caveat: this is a documented, consistently applied routing convention across all five producers (each macOS branch routes to a provenance host instead), so it reads as a deliberate design whose Back-target cost was accepted or unexamined, not an accidental regression — 'medium/confusing' is the honest severity, and the mechanism is certain as claimed.

*Related known:* #404 (fixed) covered the rail auto-open, not this routing; the pattern predates #338, which only pinned it to one window

### M-17. Edge-tap page-turns stack one Browse entry per page and leave the Search context; leading zone overlaps the back-swipe region
*iOS · verified · iOS tab & stack navigation, and BACK behavior*

**Symptom.** Reading in Read mode, each edge-tap "page-turn" is a new push: after paging through 20 documents, leaving the volume takes 20 Back taps (the breadcrumb is hidden at document level, and entirely on regular iPad). If the document was opened from search results, the very first page-turn silently switches to the Browse tab, abandoning the results. Separately, the previous-document tap zone is a 56pt strip on the leading edge — the same region where the back-swipe begins — so an imprecise swipe-back can open the previous document instead of going back.

**Mechanism.** `navigateToAdjacentDocument` reuses the cross-ref pathway: openTab(.browse) + openBrowseDocument (DocumentView.swift:1531-1539), and the consumer appends (BrowserView.swift:632) — never replaces the top entry — so every page-turn deepens the Browse path. Zone width is FRUSTheme.documentEdgeTapZoneWidth = 56 (FRUSTheme.swift:377); zones are active whenever Read mode is on, edgeTapNavigationEnabled (default on), and no sheet is up (DocumentView.swift:1433).

**Evidence.**
- `FRUSExplorer/DocumentView/DocumentView.swift:1531` — page-turn routes through the Browse-tab handoff, appending a stack level per turn
- `FRUSExplorer/Theme/FRUSTheme.swift:377` — 56pt leading zone overlapping the system back-swipe start region
- `FRUSExplorer/Browser/BrowserView.swift:604` — breadcrumb suppressed at .document level (and on regular iPad), so no level-jump escape from a deep page-turn stack

**Verifier.** All evidence verified. navigateToAdjacentDocument (DocumentView.swift:1531-1539) calls appState.openTab(.browse, from: sceneID) + openBrowseDocument on every edge-tap; AppState.openBrowseDocument (AppState.swift:1933-1949) is a plain hand-off setter with no dedup, and the consumer appends — vm.navigationPath.append(.document(entry)) at BrowserView.swift:632 — never replaces. I searched BrowserViewModel for compensating pop/replace logic: the only path-prefix mutation (BrowserViewModel.swift:275-279) is the tag-filter pop, unrelated. The tab switch is real: MainTabView.swift:181-183 consumes pendingTab and sets selectedTab, so a document opened from Search results (which push onto the Search tab's own stack via navigationDestination, SearchView.swift:481-490) does switch the window to Browse on the first page-turn. Breadcrumb suppression confirmed at BrowserView.swift:602-605 (EmptyView on regular-width iPad at any level, and at .document level on any width), so no level-jump escape exists. Zone width 56pt confirmed (FRUSTheme.swift:377) with gating at DocumentView.swift:1433. Two honest nuances the finding largely already carries: (1) 'abandoning the results' slightly overstates — the Search tab retains its stack including the originally opened document, so results are one tab-tap away, not lost; (2) the zones use .onTapGesture (DocumentView.swift:1489), so a recognized pan should not fire them — whether an imprecise short back-swipe registers as a tap is the runtime question the finding itself flags. Severity medium is fair.

*Related known:* the tap-vs-pan disambiguation (swipe still winning over the tap zone) is the one part needing a runtime check; UIObstructionTests' swipe-defeats-tap ordering memory suggests pans do win

### M-18. Collections tab has no route to open a document for reading
*iOS · verified · iOS tab & stack navigation, and BACK behavior*

**Symptom.** Inside a collection, tapping an entry opens its settings inspector (composition, notes, highlights) — there is no way to open the document itself. A researcher reviewing a collection must remember each document's volume and re-find it via Browse or Search; the owner's "back from a collection's document" scenario cannot even occur.

**Mechanism.** The entire Collections module contains no `DocumentView`, `appState.openDocument`, `openBrowseDocument`, `openTab`, or `pendingBrowse*` reference (module-wide grep); the only NavigationLink is the Collection Settings drill-in (CollectionEditorView.swift:681). Entry rows open the per-entry inspector (CollectionEntryRows.swift:643, a11y hint "Opens this document's settings" :741); the compact drill-in is `entryInspectorContent` (CollectionEditorView.swift:588-598). Compare macOS, where document opens route via AppState.openDocument from other list surfaces.

**Evidence.**
- `FRUSExplorer/Collections/CollectionEditorView.swift:588` — iPhone entry tap → inspector push (documentOnly settings), not the document
- `FRUSExplorer/Collections/CollectionEntryRows.swift:741` — row a11y hint: 'Opens this document's settings' — the only tap affordance
- `FRUSExplorer/Collections/CollectionListView.swift:150` — the tab's only navigationDestinations: create/edit collection

**Verifier.** The absence claim survived three independent sweeps. (1) Module-wide grep across all 25 files in FRUSExplorer/Collections/ for DocumentView|openDocument|openBrowseDocument|openTab|pendingBrowse|NavigationLink returns exactly one hit: the Collection Settings NavigationLink at CollectionEditorView.swift:681. (2) The per-entry inspector (CollectionEntryInspector.swift) uses appState only for summarization/indexing/download/manifest/crossReferenceStore lookups — no open-document affordance, no openWindow, and its buttons are Done/note-include/excerpt-insert/headnote-edit. (3) No alternate route exists: the collection preview WebView deliberately excludes the frusexplorer:// interactive-link handler (CollectionPreviewView.swift:51-55 and 588-594 — 'carries no frusexplorer:// interactive links'), and the module's only openURL uses are Zotero/export (CollectionExportSheet.swift). Cited lines are accurate: iPhone entry rows' sole tap action is onInspect (CollectionEntryRows.swift:716, doc comment at 643) with a11y hint 'Opens this document's settings' (740-742); the compact drill-in pushes documentOnly settings (CollectionEditorView.swift:588-598); CollectionListView's only navigationDestinations are create/edit (150-155). One sharpening: the gap is module-wide, not iOS-only — MacCollectionManagerView also has no document-open route — though other macOS list surfaces do route via AppState.openDocument (e.g. ResearchView.swift:698), so the comparison stands. Severity medium and confidence likely are honest.

*Related known:* absence claim — grep-verified across the module; a runtime pass over the entry inspector would make it certain

### M-19. Collection items cannot be opened in the app's own reader on either platform
*both · verified · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** In a collection — the one list built entirely of documents the user deliberately curated — there is no way to read a document in the app. On macOS the only open affordance launches history.state.gov in the web browser; on iOS tapping a row opens the configure inspector and no open-document affordance exists at all. Every other document list in the app (search, history, chronology, research, graph, related, neighbors) opens the in-app reader.

**Mechanism.** MacEntryRow's action controls are Configure, an external history.state.gov URL, and Delete. iOS EntryRow's whole-row tap and pill both call onInspect only. No file in Collections/ references openDocument/openBrowseDocument/DocumentWindowID (grep verified; only the add-documents picker sheets reference DocumentBrowserEntry).

**Evidence.**
- `FRUSExplorer/Collections/MacCollectionManagerView.swift:1598` — the only per-entry open: external history.state.gov URL via openURL
- `FRUSExplorer/Collections/CollectionEntryRows.swift:716` — iOS row tap → onInspect() — inspector only, no reader open
- `FRUSExplorer/Collections/CollectionEntryRows.swift:702` — the ConfigurePill is the sole other affordance on the row

**Verifier.** All citations verified and the compensating-affordance hunt came up empty. MacCollectionManagerView.swift:1590-1623: MacEntryRow's action controls are exactly ConfigurePill (1593), the external history.state.gov openURL button (1598-1610), and Delete (1613) — no in-app open. CollectionEntryRows.swift:702-709 (ConfigurePill or a chevron) and 715-716 (.contentShape + .onTapGesture { onInspect() }) confirm the iOS row's only actions open the inspector. Adversarial checks: the entry context menu is Move Up/Move Down only (EntryMoveControls, CollectionEntryRows.swift:350-381); CollectionEntryInspector's buttons are Done/New Note/Insert excerpt/Cancel/Save/Edit/Generate — no open-in-reader; and a grep of the entire Collections/ module for openDocument, openBrowseDocument, DocumentWindowID, and pendingBrowseDocument returns zero hits, so no producer exists anywhere in the module. One nuance the finder missed, not enough to change the verdict: CollectionPreviewView (an editor pane, 'the HTML export, live') DOES render document body text in-app in a WKWebView, so the sentence 'no way to read a document in the app' is slightly overbroad — but it is a whole-collection export preview with no interactive reader affordances (its own doc comment notes it carries no frusexplorer:// links, no highlight/selection JS, and bodies can be capped or citation-only), so the substantive claim — no route from a curated entry to the app's reader — stands. Severity medium honest.

### M-20. Every warm launch routes through the first-run Onboarding screen until the async boot finishes
*both · verified · state persistence & restoration — what survives a tab switch, a window close, and an app relaunch, on both platforms*

**Symptom.** A long-onboarded user with hundreds of downloaded volumes launches the app and briefly sees the first-run Welcome/onboarding screen before it snaps to the main UI. The flash lengthens with boot cost (store open, duplicate-record cleanup, trail migration on large stores) — and reads as 'my data is gone' for however long it lasts.

**Mechanism.** ContentView routes to OnboardingView unless hasCompletedOnboarding AND (hasVolumes OR downloads active). hasVolumes calls OnboardingViewModel.hasDownloadedVolumes(in: appState.downloadManager?.volumesDirectory), which returns false for a nil directory — and downloadManager is nil until bootDownloadManager assigns it at FRUSExplorerApp.swift:1791, at the END of the async boot (CloudKit check, sentinel read, FTS5Store open, IndexingPipeline init, DuplicateRecordCleanup, ResearchTrailMigration). Boot starts in .task, i.e. after the first frame, so at least the first frames render OnboardingView. No cover exists: CloudSurfaceArbiter.resolve returns .none on an ordinary warm start (isCoreReady is also false that early), so ContentViewWithSplash overlays nothing. The routing comment ('downloadQueue prevents a mid-download flicker') shows the flicker class was known — this nil-manager variant of it was not closed.

**Evidence.**
- `FRUSExplorer/App/ContentView.swift:51` — hasVolumes = OnboardingViewModel.hasDownloadedVolumes(in: appState.downloadManager?.volumesDirectory) — nil manager at launch
- `FRUSExplorer/Onboarding/OnboardingViewModel.swift:227` — guard let dir = directory else { return false } — boot-in-progress is indistinguishable from no-volumes
- `FRUSExplorer/App/FRUSExplorerApp.swift:1791` — appState.downloadManager = dm — assigned only after store opens + cleanup/migration passes (boot begins at :1398 from .task)
- `FRUSExplorer/Analytics/WordCloud/CloudSurfaceArbiter.swift:94` — ordinary warm start → .none: no splash covers the onboarding flash

**Verifier.** The full mechanism chain is real; the only unverified element is perceived duration, which the finding honestly scopes with its 'likely' confidence and a named runtime check. Verified: ContentView.swift:51 computes hasVolumes from appState.downloadManager?.volumesDirectory and line 54's AND gate routes to OnboardingView (line 61) whenever it is false; OnboardingViewModel.swift:227 'guard let dir = directory else { return false }' makes a nil manager indistinguishable from no-volumes. Grep confirms the sole assignment of appState.downloadManager is FRUSExplorerApp.swift:1791, at the END of bootDownloadManager, which is started via .task on the primary WindowGroup's ContentViewWithSplash (lines 1136-1139, plus 1149) — i.e. after the first frame. The inline pre-assignment work is confirmed blocking: await stateTracker.interruptedVolumeIds() (1486), FTS5Store open (1491), IndexingPipeline init (1493), DuplicateRecordCleanup.run on the main context (1504), ResearchTrailMigration.run (1524), SettingsSyncCoordinator start (1528-1530), and the DownloadManager construction itself (1719-1790). One precision note: the truly long reindex/rebuild paths (indexAllVolumes etc., 1586+) run inside spawned Tasks and do NOT extend the flash — the finding correctly names only cleanup/migration/store-open as the lengtheners. The no-cover claim is verified: CloudSurfaceArbiter.resolve returns .none for an ordinary warm start (CloudSurfaceArbiter.swift:94, rule 5), and the isCoreReady guard at line 90 forces .none that early regardless, so ContentViewWithSplash overlays nothing (ContentView.swift:115-118). The alternate legs of the gate cannot save it: downloadQueue is populated only by DownloadManager's onStateChanged (1722-1724), so hasActiveDownloads is false throughout boot; OnboardingView renders its Welcome step immediately (@State step = .welcome, OnboardingView.swift:70, welcomeDock at 187). On macOS there is no launch screen, so the window's first content is literally the Welcome screen; on iOS it appears the moment the launch screen drops. Severity medium honest — no work is lost, but the flash scales with store size.

*Related known:* Runtime check to settle: add a timestamped print in ContentView.body logging the branch taken, or screen-record a cold launch on the owner's device — the OnboardingView branch renders for the full boot duration

### M-21. macOS relaunch restores the window arrangement but resets every window's content
*macOS · verified · state persistence & restoration — what survives a tab switch, a window close, and an app relaunch, on both platforms*

**Symptom.** A user quits with a workspace — main window on a document, a Search window with a query, the Corpus Browser on a subseries, the graph window on a document's graph, plus Archival Neighbors / Related Documents lists. Relaunch reopens all those windows in place (macOS default restoration), but the main window shows 'Select a document to begin', Search is blank, the Corpus Browser has no selection, the graph window drops to its volume picker, and Source Explorer resets to Collections. Only the value-based aux windows (Archival Neighbors, Related Documents, standalone document windows' ROOT document) restore content — the satellites come back while the center of the workspace forgets.

**Mechanism.** All singleton-window and main-window content lives in @State or in-memory AppState fields: MainWindowView's navigationPath is @State (empty path → DocumentPlaceholderView); MacSearchWindowView's searchVM is @State; CorpusBrowserWindowView's selectedSubseries/detailPath are @State; CrossReferenceGraphWindowView reads AppState.currentGraphEntry (in-memory, nil after relaunch → picker); SourceExplorerWindowView's mode/noteSnapshot are @State reading currentSourceNote* globals that died with the process. MacDocumentWindowView restores its root from the encoded DocumentWindowID value but its pushed navigationPath is @State. The code itself confirms restored-at-launch windows are a real scenario (PeopleWindowView's boot guard exists precisely for 'a window restored at launch').

**Evidence.**
- `FRUSExplorer/App/MainWindowView.swift:77` — @State private var navigationPath: [DocumentBrowserEntry] = [] — open document lost; placeholder at :131/:406-421
- `FRUSExplorer/App/SearchSheet.swift:108` — @State private var searchVM = MacSearchViewModel() — query/results reset per window lifetime
- `FRUSExplorer/App/MacCorpusBrowserWindow.swift:66` — @State detailPath: [CorpusNavValue] + :60 selectedSubseries — browse position resets
- `FRUSExplorer/CrossReference/CrossReferenceGraphWindowView.swift:110` — reads appState.currentGraphEntry — in-memory, nil after relaunch → picker mode
- `FRUSExplorer/App/MacDocumentView.swift:1182` — standalone doc window: root restores from DocumentWindowID value, pushed stack (@State) lost
- `FRUSExplorer/App/FRUSExplorerApp.swift:728` — PeopleWindowView boot-guard comment: 'a window restored at launch' — confirms macOS restoration reopens these windows in practice

**Verifier.** Every evidence line is real. MainWindowView.swift:77 declares `@State private var navigationPath: [DocumentBrowserEntry] = []` with the NavigationStack rooted on DocumentPlaceholderView at :130-131; SearchSheet.swift:108 declares `@State private var searchVM = MacSearchViewModel()` (the only @SceneStorage there is showFacetPanel/inspectorExpanded at :118/:122 — booleans, not the query); MacCorpusBrowserWindow.swift:60/:66 hold selectedSubseries/detailPath as @State; CrossReferenceGraphWindowView.swift:110-122 falls to pickerContent when in-memory appState.currentGraphEntry (AppState.swift:898, plain var, no persistence) is nil; MacDocumentView.swift:1182 gives the standalone window a @State navigationPath while only rootEntry (:1190) comes from the encoded DocumentWindowID; SupportingViews.swift:1815/:1827 confirm SourceExplorerWindowView's mode defaults to .collections and noteSnapshot is rebuilt from currentSourceNote* globals (AppState.swift:918-928, in-memory) that are nil after relaunch. Compensating-code hunt came up empty: grep for SceneStorage finds nothing covering any of this content, and grep for restorationBehavior/NSQuitAlwaysKeepsWindows finds no opt-out — while FRUSExplorerApp.swift:726-729's PeopleWindowView comment ('a window restored at launch never renders the definitive… empty state as a lie') confirms restored-at-launch windows are a scenario the codebase itself designs for. The one assumption (macOS default window restoration reopens these scenes) is why 'likely' rather than 'certain' is the honest confidence; medium severity is fair — arrangement survives, content resets.

*Related known:* macOS Project Home window has no toolbar (accepted) — unrelated; the honest-boot-guard pattern (PeopleWindowView, MacSearchWindowView :158-172) covers the boot race but not content restoration

### M-22. Restored iPad Cross-Reference Graph window shows the definitive 'No Document Selected' while the store is still booting
*iOS · verified · state persistence & restoration — what survives a tab switch, a window close, and an app relaunch, on both platforms*

**Symptom.** An iPad user relaunches with a Cross-Reference Graph window in their Stage Manager set. The window comes back saying 'No Document Selected — Open a document, then tap Cross-References in the toolbar' — a definitive instruction implying the window lost its target — then abruptly flips to the correct graph once the index boots. On a slow boot the lie stands for seconds.

**Mechanism.** The scene body's guard is `if let request, let store = appState.crossReferenceStore` with a single else branch. On restoration the request IS present but crossReferenceStore is nil until bootSearchInfrastructureOnce completes, so the nil-store boot race renders the same empty state as a genuinely empty window. The sibling value scenes distinguish these states: ArchivalNeighborsContent and RelatedDocumentsContent gate on pipelineReady and show 'Preparing your index…' (a fix made specifically because 'windows restored at relaunch no longer race app boot', ArchivalNeighborsSheet version history 1.1). The scene-header table (FRUSExplorerApp.swift:73) claims GraphWindowRequest 'restores correctly' — the value restores, but the boot-race presentation was not ported with it. Recovery does happen (Observable store assignment re-evaluates the scene body).

**Evidence.**
- `FRUSExplorer/App/FRUSExplorerApp.swift:597` — if let request, let store = appState.crossReferenceStore — one combined guard
- `FRUSExplorer/App/FRUSExplorerApp.swift:617` — else branch: definitive 'No Document Selected / Open a document, then tap Cross-References' shown during the nil-store boot race
- `FRUSExplorer/SourceExplorer/ArchivalNeighborsSheet.swift:306` — the sibling pattern: !pipelineReady → 'Preparing your index…' placeholder, added by the Phase-5 review for exactly this restored-window race
- `FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift:121` — pipelineReady gate copied into the #308 scene — the graph scene is the only guarded-value scene without it

**Verifier.** FRUSExplorerApp.swift:595-598 is exactly as claimed: the iOS GraphWindowRequest scene guards `if let request, let store = appState.crossReferenceStore` in one combined condition, and the single else branch at :616-626 renders ContentUnavailableView 'No Document Selected / Open a document, then tap Cross-References in the toolbar' — so request-present-but-store-nil (the restored-window boot race; crossReferenceStore is assigned at FRUSExplorerApp.swift:1541, deep in bootDownloadManager) is indistinguishable from a genuinely empty window. The sibling pattern is real: ArchivalNeighborsSheet.swift:300/:306-312 and RelatedDocumentsView.swift:121/:128-131 both gate on pipelineReady and show 'Preparing your index…', with comments naming the restored-window race explicitly. Recovery via @Observable re-evaluation is correctly credited (the body reads appState.crossReferenceStore). The scene-table row at :73 does claim 'restores correctly' for the VALUE, matching the finding's framing. The sibling DocumentWindowID row at :71 documents its own boot race as user-visible (#323), supporting the claim the race window is observable. 'Likely' is honest — the mechanism is fully traced, only the visible duration needs runtime.

*Related known:* #323 — the same boot race on the sibling DocumentWindowID scene is documented as real and user-visible, which is the evidence the race window is long enough to see

### M-23. iOS Search tab claims 'Search Unavailable' during every boot — the definitive-empty-state lie macOS already fixed
*iOS · verified · state persistence & restoration — what survives a tab switch, a window close, and an app relaunch, on both platforms*

**Symptom.** A user whose restored tab is Search (or who taps Search right after launch) sees 'Search Unavailable — The search index is not available.' over a fully built index of 316,839 documents, until the async boot finishes. The message reads as permanent breakage, not a wait; it is also indistinguishable from a genuine store-open failure.

**Mechanism.** SearchTabView renders the ContentUnavailableView whenever appState.searchService is nil, and searchService is assigned late in bootDownloadManager (after CloudKit check, sentinel read, FTS5Store open, pipeline init, cleanup/migration passes) which itself starts post-first-frame. The macOS Search window had this exact defect and fixed it with an explicit boot guard rendering 'Preparing your index…' plus a comment naming the principle ('never renders the definitive empty state as a lie', citing PeopleWindowView and CitationLookupView); the iOS tab was never given the same treatment.

**Evidence.**
- `FRUSExplorer/App/MainTabView.swift:379` — searchService nil → ContentUnavailableView 'Search Unavailable / The search index is not available.' — no boot/failure distinction
- `FRUSExplorer/App/FRUSExplorerApp.swift:1543` — appState.searchService = SearchService(...) — assigned deep into the async boot sequence beginning at :1398
- `FRUSExplorer/App/SearchSheet.swift:166` — the macOS fix this tab lacks: searchService == nil → ProgressView 'Preparing your index…', with the rationale comment at :158-165

**Verifier.** MainTabView.swift:374-388 confirmed: SearchTabView renders ContentUnavailableView 'Search Unavailable / The search index is not available.' whenever appState.searchService is nil, with no boot/failure distinction. searchService is assigned at FRUSExplorerApp.swift:1543, after the CloudKit diagnostics block (:1434-1481), sentinel read (:1485-1487), FTS5Store + pipeline creation (:1491-1499), DuplicateRecordCleanup/OrphanedTagRepair/ResearchTrailMigration/settingsSync (:1504-1530), and indexed-ID seeding (:1540) — all inside bootDownloadManager, started from bootSearchInfrastructureOnce (:1398) via a post-first-render .task. The macOS contrast is exact: SearchSheet.swift:158-172 carries the boot guard with the rationale comment naming PeopleWindowView and CitationLookupView ('never renders the definitive empty state as a lie'); the iOS tab has no equivalent. The @SceneStorage tab restore (MainTabView.swift:90) means a user who quit on Search sees the message immediately at launch, and @Observable re-evaluation makes it flip once boot completes — transient, so medium/'likely' is honest.

*Related known:* Same class as #410 (Source Explorer 'No Document Selected' on first doc, fixed) — boot-state presented as definitive absence

### M-24. Opening a .fruscollection on iPhone/iPad lands on the Collections tab but never selects the imported collection
*iOS · verified · Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms*

**Symptom.** User opens a shared .fruscollection from Files/AirDrop; the app switches to the Collections tab but the imported collection is not opened or highlighted — the user must find it by name. On macOS the same import opens the Collections window with the collection selected.

**Mechanism.** surfaceOpenedCollection writes pendingCollectionSelection only in its macOS branch; the iOS branch calls only openTab(.collections, from: .anyWindow) (FRUSExplorerApp.swift:1358-1366). The iOS consumer built for exactly this (#369 BUG-12: CollectionListView.consumePendingCollectionSelection, drained by .task and .onChange at lines 160-162, which pushes the imported collection's editor) can therefore never fire from an import — grep confirms FRUSExplorerApp.swift:1362 is the sole writer in the codebase and it is inside the #else (macOS) branch.

**Evidence.**
- `FRUSExplorer/App/FRUSExplorerApp.swift:1360` — #if os(iOS): only openTab(.collections, from: .anyWindow); pendingCollectionSelection = id is written at line 1362 in the #else (macOS) branch
- `FRUSExplorer/Collections/CollectionListView.swift:90` — iOS consumer exists and documents the intent ('pushes the imported collection's editor so the user lands on it after an open-with import') but has no iOS producer
- `FRUSExplorer/Collections/CollectionListView.swift:161` — .task + .onChange drains wired and dead

**Verifier.** Every citation checks out. FRUSExplorerApp.swift:1358-1366: the iOS branch of surfaceOpenedCollection calls only appState.openTab(.collections, from: .anyWindow) (line 1360); appState.pendingCollectionSelection = id is written at line 1362 inside the #else (macOS) branch, followed by openWindow + bringMacWindowToFront. A grep across the whole app confirms line 1362 is the only non-nil writer in the codebase (the other two writes, CollectionListView.swift:92 and MacCollectionManagerView.swift:323, are the consumers' nil-clears). The iOS consumer exists exactly as claimed — CollectionListView.swift:86-97 consumePendingCollectionSelection (#if os(iOS)), drained by .task at 160 and .onChange at 161-163, doc-commented as the #369 BUG-12 fix 'pushes the imported collection's editor so the user lands on it after an open-with import' — and can never fire from an import because no iOS code path sets the slot. The macOS twin (MacCollectionManagerView.swift:304 onChange + 319-323 apply) confirms the platform asymmetry in the symptom. No compensating selection mechanism exists on iOS: the import flow (FRUSExplorerApp.swift:1330-1342) ends at surfaceOpenedCollection. Severity medium is honest — the collection IS imported, just not surfaced.

*Related known:* #369 BUG-12 added the iOS consumer; the producer side was never wired on iOS

### M-25. .anyWindow first-wins delivery can hand Spotlight/deep-link/import content to a background window instead of the one the OS just activated

> **RESOLVED 2026-08-10 (#752 F-2).** The continuation modifiers now sit inside `ContinuationHost`, a per-window modifier that publishes a scene identity above the tab view, so each handler addresses the window it fired in and both channels carry the same target. The remedy this entry proposed — *prefer the activated scene* — is unreachable: `MainTabView` documents that iPadOS reports every visible window `.active`, and nothing exposes the activated scene to the app. Two corrections to the entry itself: there is **no custom URL scheme** (the three entry points are Handoff, Spotlight and the `.fruscollection` open-with; `frusexplorer://` links are intercepted inside the web view), and the import path acquired a *second* untargeted channel after this was written — #755's `pendingCollectionSelection` — which is now scene-addressed on iOS too.

*iOS · verified · Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms*

**Symptom.** With two or more iPad windows open, tapping a Spotlight/Handoff result (or opening a .fruscollection) brings one window forward, but the document/tab-switch can land in a different, background window — the fronted window shows no change.

**Mechanism.** Continuations write openBrowseDocument/openTab targeted .anyWindow (FRUSExplorerApp.swift:2066-2070, 1360). Consumption is 'first live scene to observe wins' (AppState.swift:1824-1830) across every open MainTabView/BrowserView observer, with no preference for the scene the system activated to deliver the user activity, and no code to activate the consuming scene afterwards. Additionally the winner for the document channel must have a bootstrapped BrowserView (BrowserView.swift:629 vm-gate), which can steer consumption toward a background window whose Browse tab was visited over a fronted window whose wasn't.

**Evidence.**
- `FRUSExplorer/App/FRUSExplorerApp.swift:2068` — navigateToDocument: openBrowseDocument(entry, from: .anyWindow) + openTab(.browse, from: .anyWindow) for Spotlight/Handoff
- `FRUSExplorer/App/AppState.swift:1827` — orAnyWindow consumption — first observer to run wins; no frontmost/activated-scene preference
- `FRUSExplorer/App/MainTabView.swift:181` — every open window observes pendingTab and races to consume

**Verifier.** Mechanism fully verified in code; only the identity of the actual winner needs runtime, which the finding itself declares (confidence: hypothesis). FRUSExplorerApp.swift:2066-2069: navigateToDocument's iOS branch targets .anyWindow for both openBrowseDocument and openTab, exactly as quoted. AppState.swift:1824-1830: consumeHandoff(orAnyWindow:) hands the payload to the first observer whose guard passes and clears the slot — no frontmost/activated-scene preference exists. MainTabView.swift:181-183 (plus the onAppear drain at 188-189): every open window's MainTabView consumes pendingTab via consumePendingTab (AppState.swift:1563-1565, orAnyWindow: true). BrowserView.swift:626-631: the vm-before-consume gate is real ('a not-yet-bootstrapped window leaves the hand-off pending'), so a background window with a mounted Browse tab can win over a fronted window without one. Adversarial hunt for compensating code came up empty on three fronts: (1) scenePhase gating was DELIBERATELY removed — MainTabView.swift:74-78 documents that iPadOS reports every visible window .active, so it cannot select the fronted window; (2) grep finds no requestSceneSessionActivation/UISceneActivationRequest anywhere, confirming nothing fronts the consuming scene afterwards; (3) the BUG-7 'tab and content land in the SAME window' guarantee (AppState.swift:1983-1986) only holds for concrete scene IDs — with both channels targeted .anyWindow, MainTabView and BrowserView consume independently, so the tab switch and the document can even split across two windows, which is slightly worse than the finding states. Severity medium honest.

*Related known:* #338 step 4 review accepted first-wins over a broadcast; runtime check: two iPad windows, both having visited Browse, tap a Spotlight result and observe which window navigates

### M-26. Recalling a saved search silently drops the person filter, user-tag filter, project scope and front-matter setting it was saved with
*both · finder-certain · state invalidation & staleness*

**Symptom.** User sets up a search — 'détente', Mentions: Kissinger chip, two of their tags, front matter excluded — and saves it as 'Kissinger détente'. Recalling it later runs plain 'détente' over everything: the person chip and tag chips are simply absent, front matter is back in, and nothing says the recalled search is broader than the one they named. Only an active VOLUME scope gets a 'not saved' notice on the save sheet.

**Mechanism.** SavedSearch.init persists 12 scalar fields and drops 8 of SearchParameters' 20: userTagIds, volumeIds, documentIds, excludeDocumentIds, projectId, personRollupId, personLabel, includeFrontMatter (init at 103-131 never reads them; the searchParameters round-trip at 136-176 returns defaults). The save sheets disclose only the volume-scope drop (#258 Q4(a)). On recall, SearchViewModel.applyParameters faithfully applies the defaults — personRollupId = nil, selectedUserTagIds = [], includeFrontMatter = true — so the recalled search is silently broader. Asymmetry adds confusion: the legacy single-volume personRef DOES round-trip while the modern cross-corpus rollup filter does not.

**Evidence.**
- `FRUSExplorer/Models/SavedSearch.swift:103` — init(name:parameters:) reads neither userTagIds, volumeIds, documentIds, excludeDocumentIds, projectId, personRollupId, personLabel, nor includeFrontMatter
- `FRUSExplorer/Models/SavedSearch.swift:162` — searchParameters round-trip returns those 8 fields as defaults (nil/[]/true)
- `FRUSExplorer/App/SearchSheet.swift:579` — save sheet discloses ONLY the volume-scope drop (iOS twin SearchView.swift:1413-1425)
- `FRUSExplorer/Search/SearchView.swift:463` — recall path: SavedSearchesView onSelect → vm.applyParameters(saved.searchParameters) → runSearch, no warning
- `FRUSExplorer/Search/SearchViewModel.swift:1093` — applyParameters sets personRollupId/personLabel from the (always-nil) stored values and clears the tag selection

*Related known:* The 8-of-20 drop was recorded in the Q&CA wave notes (memory: project_qca_decisions_b_e) but M-2 fixed history reproducibility, not SavedSearch; the shipped save/recall behavior is as described.

### M-27. Open Person Analytics dashboard never refreshes after a person correction — keeps pre-merge identities and stale ids
*both · finder-certain · state invalidation & staleness*

**Symptom.** User notices 'H. Kissinger' and 'Henry A. Kissinger' as two rows in the Person Analytics ranking, goes to the People browser and merges them, and returns to the still-open analytics window: the ranking still shows both rows, the comparison chips still name the old identities, and any subsequent refetch (grain toggle, adding a person) plots renumbered clusters under the old names. Only closing and reopening the dashboard shows the corrected identity.

**Mechanism.** PersonAnalyticsView reloads on appState.readOnlyStoresGeneration (the #275 reindex signal) but corrections never bump that generation — saveAndReconsolidate rebuilds the rollup tables without touching AppState, and the corrections' own signal (personCorrectionsGeneration) is observed solely by PersonIndexView. The focus sheet is keyed on "\(focus.rollupId)-\(readOnlyStoresGeneration)" so it too survives a correction unrefreshed with a now-renumbered id.

**Evidence.**
- `FRUSExplorer/Analytics/PersonAnalyticsView.swift:681` — reload trigger is onChange(readOnlyStoresGeneration) only
- `FRUSExplorer/Models/PersonClusterOverrideStore.swift:95` — saveAndReconsolidate: save → snapshot → consolidate; never calls refreshReadOnlyStores nor bumps any generation
- `FRUSExplorer/Browser/PersonIndexView.swift:939` — corrections bump personCorrectionsGeneration, whose only observer is PersonIndexView:155 (plus PersonCorrectionsView:374 as a producer)
- `FRUSExplorer/Analytics/PersonAnalyticsView.swift:1101` — focus sheet .id uses rollupId + readOnlyStoresGeneration — unchanged across a correction, so it keeps a renumbered id

*Related known:* Distinct from #275 (fixed): the connection is fresh; the refresh SIGNAL for this data-change class simply doesn't reach this view.

### M-28. iOS Back after a cross-reference jump lands in the stale Browse stack, not the source document; macOS returns to source
*iOS · finder-certain · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** Open a document from Search results, tap a cross-reference: the app jumps to the Browse tab and shows the target. Tapping Back does NOT return to the document the link was in — it pops to whatever the Browse stack previously held (a volume list from an earlier session, or the Browse root). The source document is stranded on the Search tab. On macOS the identical tap pushes onto the same window's stack, so Back returns to the source.

**Mechanism.** iOS handleCrossRefTap appends the target to the BROWSE tab's BrowserViewModel.navigationPath via the openBrowseDocument hand-off, while the source document lives on a different stack (SearchViewModel.navigationPath). The Browse stack's prior content becomes the Back destination. macOS MacDocumentView.navigateToCrossRef appends to the SAME window's navigationPath binding, preserving the round trip.

**Evidence.**
- `FRUSExplorer/DocumentView/DocumentView.swift:968` — iOS: target appended to Browse tab's stack, not the host stack
- `FRUSExplorer/Browser/BrowserView.swift:632` — vm.navigationPath.append(.document(entry)) — appended after existing Browse levels
- `FRUSExplorer/App/MacDocumentView.swift:1086` — macOS: navigationPath.append(dest) — same-window push, Back returns to source
- `FRUSExplorer/Search/SearchView.swift:1545` — search-opened documents live on SearchViewModel.navigationPath — a different stack from Browse

### M-29. "Find all mentions" and other search hand-offs silently destroy the Search tab's current query — and land on an unrelated pushed document
*iOS · finder-likely · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** With a search open and a result document pushed on the Search tab, using People ▸ Find all mentions (or an analytics/indexing-banner search hand-off) switches to the Search tab — which still shows the pushed DOCUMENT, so nothing appears to happen. Back then reveals results for the new person query; the user's original query, filters, and results are gone with no undo.

**Mechanism.** consumePendingSearch applies parameters and re-runs, but neither it nor SearchViewModel.applyParameters pops vm.navigationPath — the pushed document stays on top while results and every filter field are overwritten beneath it. Producers (PersonIndexView, MainTabView's indexing banner/summary card, AnalyticsView) pair openSearch with openTab(.search) only.

**Evidence.**
- `FRUSExplorer/Search/SearchView.swift:629` — consumePendingSearch: applyParameters + runSearch; navigationPath untouched
- `FRUSExplorer/Search/SearchViewModel.swift:1086` — applyParameters overwrites keywords/filters/scope; never touches navigationPath (declared :437)
- `FRUSExplorer/Browser/PersonIndexView.swift:191` — find-mentions producer: openSearch + openTab(.search)
- `FRUSExplorer/App/MainTabView.swift:281` — indexing banner person-search producer — same channel, same clobber

*Related known:* macOS shares the replace-the-singleton-search-window behavior by design, but the window shows the replacement immediately; only iOS can hide it under a pushed document. Runtime check: push a search result, then trigger find-mentions from People.

### M-30. iPad standalone document window: cross-ref taps and page-turns navigate a DIFFERENT window instead of in place
*iOS · finder-likely · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** On a Stage Manager iPad, open a document 'in New Window', then tap a cross-reference (or edge-tap next): the standalone window does not navigate. The target is delivered to the LAUNCHING main window's Browse tab — which may be behind the standalone window or in another workspace, so the tap can look like a no-op. The macOS standalone document window navigates in place.

**Mechanism.** The iOS DocumentWindowID scene applies .auxWindowOriginModifier, republishing the ORIGIN window's scene as this window's \.sceneID. DocumentView's navigateToCrossRef/navigateToAdjacentDocument address openTab/openBrowseDocument to that sceneID, so the origin MainTabView switches tab and the origin BrowserView appends the entry. The standalone window itself hosts no BrowserView and never consumes the hand-off. macOS MacDocumentWindowView instead appends to its own stack.

**Evidence.**
- `FRUSExplorer/App/FRUSExplorerApp.swift:529` — .auxWindowOrigin(appState) on the iOS DocumentWindowID scene — comment says rail producers 'route back to it' (the launcher)
- `FRUSExplorer/DocumentView/DocumentView.swift:969` — openTab(.browse, from: sceneID) — sceneID here is the ORIGIN window's identity
- `FRUSExplorer/App/AppState.swift:1843` — resolveOriginScene: live origin wins; .anyWindow only when the launcher closed
- `FRUSExplorer/App/MacDocumentView.swift:1086` — macOS equivalent pushes onto the standalone window's own stack

*Related known:* #338 aux-window origin work made this deliberate for rail producers; the divergence from macOS in-place navigation for in-document links is the unexamined consequence. Runtime check: two-window Stage Manager, cross-ref tap in the standalone document window.

### M-31. Word Cloud tapped in a standalone iPad document window opens in another window — or nowhere at all if the launcher closed
*iOS · finder-likely · Modal/sheet/inspector/popover presentation state (iOS + macOS)*

**Symptom.** iPad Stage Manager: open a document in its own window, open the Research rail, tap the Word Cloud tile. The cloud sheet presents in the ORIGINATING main window — which iPadOS does not raise, so if that window is offscreen the tap appears to do nothing. If the originating window has since been closed, the tap does nothing permanently: no window ever shows the cloud, and the hand-off stays parked until some later word-cloud action overwrites it.

**Mechanism.** The aux document window republishes the launcher's scene as its \.sceneID, resolving to .anyWindow when the launcher is gone (AuxWindowOriginModifier, AppState.swift:2016-2035; resolveOriginScene 1843-1847). The rail tile calls appState.openWordCloud(scope, from: sceneID) (DocumentView.swift:1115-1117), producing Handoff(target: originScene-or-.anyWindow). The only iOS presenter is MainTabView's guarded sheet binding, which matches ONLY its exact scene token — `handoff.target == SceneID(sceneIDToken)` with no orAnyWindow acceptance (MainTabView.swift:207-214) — unlike pendingBrowseDocument/pendingSearch/pendingTab, which all accept .anyWindow (AppState.swift:1824-1830, 1947, 1978, 1988). So the live-origin case presents in a background window the user isn't looking at, and the closed-origin case matches no presenter at all. The nil-sceneID sentinel path is documented as a deliberate no-op (AppState.swift:1872-1883), but the .anyWindow path is not covered by that rationale and isn't even logged.

**Evidence.**
- `FRUSExplorer/App/MainTabView.swift:209` — guard handoff.target == SceneID(sceneIDToken) — no .anyWindow acceptance for pendingWordCloud
- `FRUSExplorer/App/AppState.swift:1843` — resolveOriginScene returns .anyWindow when the launching window closed — a target no word-cloud presenter matches
- `FRUSExplorer/App/FRUSExplorerApp.swift:527` — aux document window comment: rail producers (incl. word cloud) route back to the launching window — the design that yields the wrong-window presentation
- `FRUSExplorer/DocumentView/DocumentView.swift:1115` — rail Word Cloud tile → appState.openWordCloud(..., from: sceneID) with the aux window's republished origin scene

*Related known:* #338 aux-window origin design (MEMORY: aux producers fall back to .anyWindow); the browse/search/tab consumers were given orAnyWindow acceptance in step 4-5, pendingWordCloud/pendingAnalytics/pendingChronology were not.

### M-32. Compact-width iPad: the Research panel presents as a sheet and rail tools (Word Cloud, Cite, Summarize) collide with it
*iOS · finder-hypothesis · Modal/sheet/inspector/popover presentation state (iOS + macOS)*

**Symptom.** iPad in 1/3 Split View or a narrow Stage Manager window (compact width) with the Research panel open: tapping the rail's Word Cloud tile does nothing while the panel is up, then the cloud can "ghost-present" after the panel closes; Cite and Summarize taps may likewise fail silently while the panel is up.

**Mechanism.** On iPad the rail is the `.inspector` (guard is `!isPhone`, keyed on userInterfaceIdiom — DocumentView.swift:317, 699-704), and the code's own comment (697-698) states that on compact width SwiftUI "would otherwise auto-present the inspector AS a sheet" — the guard only prevents this on iPhone, so on compact-width iPad the inspector IS presented as a sheet. The word-cloud tile posts to the MainTabView-hosted ancestor sheet, and openRailTool's own comment (1109-1113) documents that SwiftUI won't present an ancestor sheet over a descendant one (dead no-op + later ghost-present); its mitigation dismisses only the iPhone `.researchRail` activeSheet — "On iPad the rail is the .inspector column (not a sheet), so nothing to dismiss" (1114), which is false in compact width, so nothing dismisses the inspector-sheet. Cite/Summarize set activeSheet (1106, 1125), a sibling presentation from the same host as the up inspector-sheet. Sources/Graph/Related escape via openWindow on multi-window iPads (787-845).

**Evidence.**
- `FRUSExplorer/DocumentView/DocumentView.swift:697` — comment: on compact width SwiftUI auto-presents the inspector AS a sheet; the !isPhone guard only excludes iPhone
- `FRUSExplorer/DocumentView/DocumentView.swift:1109` — documented mechanism: ancestor pendingWordCloud sheet won't present over a descendant presentation — dead tap + ghost-present
- `FRUSExplorer/DocumentView/DocumentView.swift:1117` — mitigation dismisses only activeSheet == .researchRail — the compact-iPad inspector-sheet is never dismissed
- `FRUSExplorer/DocumentView/DocumentView.swift:1106` — Cite sets activeSheet — a sibling .sheet from the same host while the inspector-sheet is up

*Related known:* The iPhone half of this exact collision was diagnosed and fixed (the researchRail set-then-dismiss, cf. #404 rail work); the compact-iPad half follows the same documented mechanism but needs a runtime check to confirm: narrow an iPad window to compact width, open the Research panel (confirm it appears as a sheet), tap Word Cloud/Cite, and observe whether anything presents and whether the word cloud ghost-presents after closing the panel.

### M-33. iPad multi-window: opening a word cloud in one window closes a word cloud already open in another
*iOS · finder-likely · Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms*

**Symptom.** With word-cloud sheets involved in two iPad windows: window A has a cloud open; the user opens any word cloud in window B; window A's cloud sheet dismisses itself.

**Mechanism.** MainTabView presents the cloud via sheet(item:) whose getter reads the LIVE shared slot each render and whose setter clears the slot on dismiss (MainTabView.swift:207-214) — presentation does not consume the hand-off, so appState.pendingWordCloud stays populated (target A) for the whole time A's sheet is up. Window B's producer overwrites the single slot with a new Handoff (target B) (AppState.swift:1883); window A's getter now returns nil (target mismatch) and SwiftUI dismisses A's sheet. Every other Handoff slot consumes-and-clears on adoption; this is the one consumer that holds the shared slot hostage for its presentation lifetime.

**Evidence.**
- `FRUSExplorer/App/MainTabView.swift:207` — sheet(item:) bound to the live shared slot; get target-checks, set clears on dismiss — no consume-on-present
- `FRUSExplorer/App/AppState.swift:1883` — producers overwrite the single slot unconditionally

*Related known:* #338 step 2 closed the fan-out (both windows presenting); the shared-slot lifetime coupling between windows remained


## Low-severity findings

### L-34. History ▸ Complete History… and the About menu item don't raise their window when it is open but buried
*macOS · finder-likely · macOS window management and focus*

**Symptom.** With the History window (or About window) already open behind other windows, choosing Research ▸ History ▸ Complete History… (or FRUS Explorer ▸ About FRUS Explorer) appears to do nothing — the window stays buried.

**Mechanism.** Both menu items call bare openWindow(id:) with no bringMacWindowToFront, the same measured re-raise gap as finding 2. The inconsistency is one line away in the History menu itself: runSearch fronts the Search window and cites '#369 BUG-9: match the eight sibling producers' — the Complete History item in the same menu body was not given the same treatment.

**Evidence.**
- `FRUSExplorer/App/HistoryWindowView.swift:114` — 'Complete History…' button: openWindow(id: "frus.history") only
- `FRUSExplorer/App/HistoryWindowView.swift:138` — Sibling runSearch in the same menu: openWindow + bringMacWindowToFront with the #369 BUG-9 citation
- `FRUSExplorer/App/FRUSExplorerApp.swift:1216` — CommandGroup(replacing: .appInfo): openWindow(id: "about") only

*Related known:* #369 BUG-9 refocus sweep — these two sites fell outside 'the eight sibling producers'.

### L-35. Search window sets no keyboard focus: after ⌘S re-fronts it, typing may not land in the query field
*macOS · finder-hypothesis · macOS window management and focus*

**Symptom.** The user presses ⌘S (Find ▸ Search…) and starts typing a query; if the Search window was already open, keystrokes go to whatever control was last focused inside it (the results list, a filter control) rather than the query field — arrow keys move the result selection instead of editing text. On first open, whether the field is focused depends on AppKit's initial-first-responder pick rather than any code.

**Mechanism.** MacSearchWindowView contains no @FocusState, .focused, or .defaultFocus anywhere (verified by grep over SearchSheet.swift), and re-fronting via openWindow/bringMacWindowToFront never resets first responder. The codebase knows this class of problem and has two deliberate solutions elsewhere: CitationLookupView needs .defaultFocus PLUS a .task fallback to land focus at all (its own comment says defaultFocus alone 'never landed'), and the find-in-document bar re-focuses on every ⌘F via a focusToken bump. The Search window — the app's most-summoned text-entry window — has neither.

**Evidence.**
- `FRUSExplorer/App/SearchSheet.swift:102` — MacSearchWindowView declaration — the file's only focus machinery is none: grep for @FocusState/focused(/defaultFocus in SearchSheet.swift returns nothing
- `FRUSExplorer/Citation/CitationLookupView.swift:142` — .defaultFocus($focusedField, .paste) + the 144-158 task workaround — the sibling find window needed BOTH to land focus, showing default behavior is not trustworthy
- `FRUSExplorer/App/MacDocumentView.swift:1450` — DocumentFindBar re-focuses its field on every ⌘F via controller.focusToken — the established in-repo pattern for refocus-on-reinvoke that the Search window lacks

*Related known:* Runtime check to settle it: open Search, click a result row, click the main window, press ⌘S, type — observe whether keystrokes reach the query field. If AppKit restores the row selection as first responder they will not.

### L-36. Research window context item labeled 'Open in Main Window' actually routes to the provenance host — which may be a document window or a freshly minted window
*macOS · finder-certain · macOS window management and focus*

**Symptom.** In the Research window, right-clicking a note/tag/highlight's document offers 'Open in Main Window'. If the user launched Research from a standalone document window — or all main windows are closed — the document opens in that document window or a brand-new standalone window, not the main window the label promised.

**Mechanism.** The menu label is fixed, but the action routes through AppState.openDocument(entry, from: .tool(.research)) which resolves to the Research window's provenance host (the window it was launched from), then the most-recently-key host, then mints a standalone DocumentWindowID window. All three targets can be something other than a main window. The routing itself is the designed provenance behavior; only the label predates it.

**Evidence.**
- `FRUSExplorer/Research/ResearchView.swift:666` — Label 'Open in Main Window' (research.action.openDocument) on the context item
- `FRUSExplorer/Research/ResearchView.swift:706` — macOS arm: appState.openDocument(browsEntry, from: .tool(.research), using: openWindow) — provenance host, not the main window
- `FRUSExplorer/App/AppState.swift:844` — Resolution chain: provenance(of: tool) ?? fallbackHost() → routedBrowse, else mintWindow — none of which is necessarily a main window

*Related known:* Provenance PR 2 changed the destination semantics; the label was not updated.

### L-37. ⌘⇧B (Corpus Browser) is a bare scene shortcut: it may not raise an open-but-buried browser window
*macOS · finder-hypothesis · macOS window management and focus*

**Symptom.** Pressing ⌘⇧B when the Corpus Browser window is already open behind other windows may leave it buried — the only keyboard route to Browse appears dead — while clicking the titlebar Browse button or reopening it from the Window menu works.

**Mechanism.** The shortcut is declared as .keyboardShortcut on the Window scene itself, which 'runs no code' (AppState's bindTool comment relies on exactly this) — so it cannot call bringMacWindowToFront, and whether SwiftUI's scene-shortcut open re-raises an already-open window is the same unverified platform behavior that motivated the helper everywhere else. The provenance half of the bareness (leaving the existing tool binding in place) is documented as deliberate; the fronting half is not addressed anywhere.

**Evidence.**
- `FRUSExplorer/App/FRUSExplorerApp.swift:718` — .keyboardShortcut("b", modifiers: [.command, .shift]) declared on the frus.corpusBrowser Window scene — no code path, so no bringMacWindowToFront possible
- `FRUSExplorer/App/AppState.swift:816` — 'Bare scene keyboard shortcuts run no code, so they never reach this' — confirms the shortcut executes no app code
- `FRUSExplorer/App/MainWindowView.swift:445` — The documented openWindow(id:) re-raise gap the scene shortcut has no way to compensate for

*Related known:* Runtime check: open Corpus Browser, front the main window over it, press ⌘⇧B — observe whether the browser fronts. Same class as finding 2 if it reproduces.

### L-38. Research-trail scope signatures embed renumber-unstable rollup ids, breaking the 'same scope' comparison they exist for
*both · finder-certain · state invalidation & staleness*

**Symptom.** The research trail / method appendix records a search's scope as a signature ('person=rollup:1234') explicitly so 'anyone who needs to check that two rows really did run under the same scope' can compare them. After any rollup reconsolidation (including the one-time v9 renumber every user gets on next launch), two rows filtered to the SAME person carry different signatures, and rows filtered to DIFFERENT people can carry identical ones — the printed comparison key silently stops meaning what the appendix says it means.

**Mechanism.** SearchScopeSignature.signature emits the raw rollup id (personComponent → "rollup:\(rollup)"), and SearchHistoryWriter persists it into the immutable SearchHistoryEntry.scopeSignature. Volume/tag/doc lists are content-hashed (digest of sorted ids — stable across sessions), but the person component uses the one identifier in the app that is positional and regenerated (rollup_id = clusterIndex+1). The prose decoder is deliberately lossy ('filtered to one person') so nothing mis-NAMES a person, but the raw signature printed beside it is the documented comparison artifact. In-session dedup is unaffected (anchored on queryText).

**Evidence.**
- `FRUSExplorer/Search/SearchScopeSignature.swift:103` — personComponent emits the raw renumber-unstable rollup id, unlike the hashed volume/tag components (110-114)
- `FRUSExplorer/Search/SearchScopeSignature.swift:124` — doc: the signature is printed 'for anyone who needs to check that two rows really did run under the same scope' — the property the renumber breaks
- `FRUSExplorer/Search/SearchHistoryWriter.swift:156` — signature persisted into the immutable trail row
- `FRUSExplorer/Search/IndexingPipeline.swift:752` — currentPersonRollupVersion = 9 — every user's ids renumber on next launch, invalidating all previously recorded rollup:N components at once

### L-39. Citation-Lookup and Graph sheets omit the \.sceneID injection their siblings get — cross-refs from documents inside them route to .anyWindow
*iOS · finder-hypothesis · iOS tab & stack navigation, and BACK behavior*

**Symptom.** On an iPad with two app windows, tapping a cross-reference inside a document opened from the Citation Lookup sheet (or the Cross-Reference Graph sheet) can open the target document in the OTHER window's Browse tab — the user's window shows nothing happening.

**Mechanism.** The codebase's own rule is that "a sheet doesn't reliably inherit \.sceneID", so presentation sites inject it explicitly (ArchivalNeighborsSheet at SearchView.swift:475-479, Chronology at BrowserView.swift:209-214, RelatedDocuments at DocumentView.swift:655-659, WordCloud at MainTabView.swift:207-221). Two sheets skip it: `CitationLookupView()` (SearchView.swift:472-474) and the `.crossReferenceGraph` case (DocumentView.swift:603-616). A DocumentView pushed inside them reads a nil `\.sceneID`, so `navigateToCrossRef` posts openTab/openBrowseDocument with target `.anyWindow` (AppState.swift:1947, 1988) — consumed first-wins by ANY live window's observers (AppState.swift:1824-1830). Single-window iPhone degrades gracefully; iPad multi-window can mis-route.

**Evidence.**
- `FRUSExplorer/Search/SearchView.swift:472` — CitationLookupView sheet presented without .environment(\.sceneID, sceneID) — its Archival-Neighbors sibling three lines later gets it
- `FRUSExplorer/DocumentView/DocumentView.swift:603` — .crossReferenceGraph sheet case lacks the injection the .relatedDocuments case (:657) has
- `FRUSExplorer/App/AppState.swift:1947` — nil sceneID → .anyWindow, consumed first-wins by whichever window observes first

*Related known:* #338 fan-out program; runtime check: two iPad windows, open Citation Lookup in one, push a match, tap a cross-ref, observe which window navigates

### L-40. iPad Source Explorer window's related-document taps land in an arbitrary window

> **RESOLVED 2026-08-10 (#752 F-2).** `SourceExplorerWindowContent` is a View, so the tap reads the scene `.auxWindowOrigin` publishes and pairs an `openTab`. It was the only unpaired `openBrowseDocument` producer of eleven; a repo-wide invariant test now enforces the pairing and the same-target rule.

*iOS · finder-certain · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** On a multi-window iPad, tapping a related document inside the Source Explorer window opens it in whichever window's Browse tab consumes it first — not necessarily the window the Source Explorer was launched from, and possibly one in another workspace.

**Mechanism.** The onRelatedDocumentTapped closure in the SourceExplorerRequest scene addresses .anyWindow explicitly (first-wins) even though the window knows its origin via .auxWindowOrigin — the closure is not a View and cannot read \.sceneID, as its own comment acknowledges. It also never calls openTab, so the receiving window's Browse tab is not brought forward.

**Evidence.**
- `FRUSExplorer/App/FRUSExplorerApp.swift:558` — appState.openBrowseDocument(entry, from: .anyWindow) with the acknowledging comment at 553-557; no openTab pairing
- `FRUSExplorer/App/AppState.swift:1773` — .anyWindow contract: first live BrowserView to observe consumes

### L-41. iPhone Related Documents / Archival Neighbors sheets discard the ranked list on every open
*iOS · finder-certain · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** On iPhone (and iPads without Stage Manager), opening one result from the Related Documents or Archival Neighbors sheet dismisses the whole ranked list. Stepping through a work list means re-opening the sheet after every document, re-running the query, and re-scrolling from the top — Back from the opened document lands in the Browse stack, not the list.

**Mechanism.** Both sheets pass onNavigate: { dismiss() }; the row tap does openBrowseDocument + openTab(.browse) then dismisses. The window presentations deliberately keep the list alive (onNavigate: nil) — the sheet fallback has no state preservation, and the content view re-fetches on next presentation.

**Evidence.**
- `FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift:435` — sheet: onNavigate: { dismiss() }; window (:482) passes nil and survives
- `FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift:409` — iOS open: openBrowseDocument + openTab(.browse) before the dismiss
- `FRUSExplorer/SourceExplorer/ArchivalNeighborsSheet.swift:590` — Archival Neighbors sheet: same onNavigate dismiss

*Related known:* The window-vs-sheet asymmetry is documented in RelatedDocumentsWindowView's doc comment ('a work list the researcher steps through'); the sheet fallback simply lacks any equivalent.

### L-42. Latent: SearchView's macOS branch mounts MacDocumentView with the known-broken constant navigation binding
*macOS · finder-certain · Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)*

**Symptom.** Not user-visible today. If SearchView is ever mounted on macOS (it currently is not — MainTabView is its sole instantiation site, iOS-only), its result pushes would render a MacDocumentView whose cross-reference taps and prev/next silently do nothing.

**Mechanism.** SearchView's navigationDestination macOS branch passes navigationPath: .constant([]) — the exact constant-binding defect the Citation Lookup window (#239) and Chronology (D1) were rebuilt to eliminate; MacDocumentView's navigation appends into a constant are dropped. Dead today, armed for any future reuse of the shared SearchView on macOS.

**Evidence.**
- `FRUSExplorer/Search/SearchView.swift:488` — MacDocumentView(entry:, navigationPath: .constant([]), ...) in the #else branch
- `FRUSExplorer/App/MainTabView.swift:375` — sole instantiation of SearchView — iOS-only file, so the branch is unreachable today
- `FRUSExplorer/Citation/CitationLookupView.swift:133` — comment documenting why the identical pattern was removed there: 'silently broke prev/next and cross-reference navigation'

### L-43. Research Guide sheet fans out to every open iPad window (shared AppState bool bound in each window's Settings tab)

> **RESOLVED 2026-08-10 (#752 F-2) — by deletion, not by the prescribed remedy.** The entry asked for a scene-addressed hand-off. That is the wrong shape: producer and consumer are one view tree in one window (`AboutView` is a `NavigationLink` destination of the `SettingsView` that presented the sheet), so the flag never needed to cross a window boundary. It is now `@State` on `AboutView`. Note also that this was not "the one real multi-presenter-over-one-binding case" — it was the one spelled `isPresented: $appState.`; `ProjectPickerMenu`'s nudge and `StoreSchemaMismatchAlert` reach shared state through hand-rolled `Binding`s and are documented as accepted.

*iOS · finder-likely · Modal/sheet/inspector/popover presentation state (iOS + macOS)*

**Symptom.** iPad with two windows whose Settings tabs have both been shown: opening "Research Guide" from About presents the guide sheet in BOTH windows at once; dismissing it in one window also dismisses it in the other.

**Mechanism.** SettingsView anchors `.sheet(isPresented: $appState.showResearchGuide)` (SettingsView.swift:151) on a SHARED @Observable AppState bool (AppState.swift:980), so every live SettingsView instance is a presenter over one binding — the fan-out class the #338 Handoff work eliminated for the pendingX channels, but this pre-existing bool was never converted. Producer: AboutView.swift:280.

**Evidence.**
- `FRUSExplorer/Settings/SettingsView.swift:151` — .sheet(isPresented: $appState.showResearchGuide) — one shared binding, one presenter per live window's Settings tab
- `FRUSExplorer/App/AppState.swift:980` — var showResearchGuide: Bool — shared app-wide state, not a scene-addressed Handoff
- `FRUSExplorer/Settings/AboutView.swift:280` — producer sets the shared bool

*Related known:* #338 pendingX fan-out fix (scene-addressed Handoff); this is the one remaining sheet bound directly to a shared AppState presentation flag (verified by grep: the only `isPresented: $appState.` site in the repo).

### L-44. Cross-reference Graph sheet can present with empty content when the store is nil
*iOS · finder-hypothesis · Modal/sheet/inspector/popover presentation state (iOS + macOS)*

**Symptom.** On iPhone (or a non-multi-window iPad), tapping the rail's Graph tile — or "View Connections" in the volume-not-downloaded alert — while the cross-reference store isn't available presents a sheet that is completely blank (the sheet slides up with nothing in it).

**Mechanism.** The consolidated sheet's `.crossReferenceGraph` case renders `if let store = appState.crossReferenceStore { ... }` with no else branch (DocumentView.swift:603-616), and neither entry point guards the store before setting activeSheet: openCrossReferenceGraph sets it unconditionally on the no-multi-window path (DocumentView.swift:787-799), and the cross-ref download alert's "View Connections" button does the same (DocumentView.swift:533-537). crossReferenceStore is nil during search-infrastructure boot and briefly while the read-only stores are recreated after an in-session reindex.

**Evidence.**
- `FRUSExplorer/DocumentView/DocumentView.swift:603` — case .crossReferenceGraph: if let store — no else; a nil store yields an empty presented sheet
- `FRUSExplorer/DocumentView/DocumentView.swift:795` — openCrossReferenceGraph sets activeSheet = .crossReferenceGraph without checking appState.crossReferenceStore
- `FRUSExplorer/DocumentView/DocumentView.swift:536` — alert button also sets activeSheet = .crossReferenceGraph unguarded

*Related known:* #275 (read-only stores stale/recreated after reindex — fixed) narrows but does not eliminate the nil window; runtime check: trigger the Graph tile immediately after starting a reindex (store recreation) or during first boot and observe whether an empty sheet presents.

### L-45. macOS Search window half-restores: facet panel and inspector expansion survive relaunch, the search they describe does not
*macOS · finder-likely · state persistence & restoration — what survives a tab switch, a window close, and an app relaunch, on both platforms*

**Symptom.** A user who quit with the facet inspector open beside results relaunches: the Search window reopens with the facet column already extended — describing a search that no longer exists (empty query, no results) — until they run a new search.

**Mechanism.** The two UI booleans are deliberately per-window @SceneStorage ('search.facets.shown', 'search.inspector.expanded') so they restore with the window, but their companions — the query, results, and FacetPanelController content — are @State (searchVM, facetController) and reset. The persisted half is a description of the discarded half, so the restored combination is incoherent: an open facet inspector with nothing to facet.

**Evidence.**
- `FRUSExplorer/App/SearchSheet.swift:118` — @SceneStorage("search.facets.shown") — survives relaunch
- `FRUSExplorer/App/SearchSheet.swift:108` — @State searchVM = MacSearchViewModel() + :114 @State facetController — the content the flag describes resets
- `FRUSExplorer/App/SearchSheet.swift:323` — .inspector(isPresented: $showFacetPanel) — restored true presents the column unconditionally

### L-46. 'hasShownThisSession' indexing-education flag actually persists forever — the sheet auto-opens once per install, not once per session
*iOS · finder-certain · state persistence & restoration — what survives a tab switch, a window close, and an app relaunch, on both platforms*

**Symptom.** The 'while indexing' education sheet auto-opens the first time a user ever runs a multi-volume indexing batch — and never again, in any later session, even months later when they download a new tranche of volumes. The banner's info affordance still opens it manually, but the designed auto-introduction is one-shot-per-install.

**Mechanism.** The flag was moved from @State to @AppStorage("frus.hasShownIndexingEducation") to stop re-triggering on view recreation within a session (version history 1.1), but @AppStorage persists across launches and the grep shows nothing ever resets the key — no session-start reset, no reset action. The property name (hasShownThisSession) and the onAppear comment ('the first time this banner appears in the current app session') both state per-session intent; the storage scope silently widened it to per-install. Correct scoping would be a reset at app launch or an AppState session-lifetime flag.

**Evidence.**
- `FRUSExplorer/App/IndexingQueueBannerView.swift:81` — @AppStorage("frus.hasShownIndexingEducation") private var hasShownThisSession = false — persists across launches; sole reference to the key in the codebase
- `FRUSExplorer/App/IndexingQueueBannerView.swift:112` — comment: 'the first time this banner appears in the current app session' — per-session intent, per-install behavior
- `FRUSExplorer/App/IndexingQueueBannerView.swift:45` — version history 1.1: the move to @AppStorage targeted view-recreation re-triggering, not cross-launch suppression

### L-47. Second-project nudge 'Open Project Home' may read the signal after the alert binding already cleared it
*both · finder-hypothesis · Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms*

**Symptom.** After creating a second project, tapping 'Open Project Home' in the one-time nudge alert could dismiss the alert without opening Project Home (silent no-op), depending on SwiftUI's binding-vs-action ordering.

**Mechanism.** The alert's isPresented binding setter clears appState.pendingSecondProjectNudge on dismissal (ProjectPickerMenu.swift:326-331), and the 'Open Project Home' action reads the same slot afterwards (line 295: let id = appState.pendingSecondProjectNudge; if let id ...). If SwiftUI writes isPresented=false before running the button action — behavior that has varied across OS releases — id is nil and openProjectHome never runs, with no fallback.

**Evidence.**
- `FRUSExplorer/ProjectContext/ProjectPickerMenu.swift:295` — action reads pendingSecondProjectNudge, which the nudgePresented setter (line 329) nils on dismissal
- `FRUSExplorer/ProjectContext/ProjectPickerMenu.swift:329` — set: { presented in if !presented { appState.pendingSecondProjectNudge = nil } }

*Related known:* #377 Phase 5; runtime check: create a 2nd project on-device and tap 'Open Project Home' — verify Project Home actually opens

### L-48. pendingAuxWindowOriginRaw leaks when openWindow(value:) refocuses an existing aux window, letting a later system-created aux window adopt a stale origin

> **CLOSED 2026-08-10 (#752 F-2) — DOES NOT REPRODUCE.** The premise is that a later aux window could adopt the stale origin. It cannot: `openAuxWindow` is the only writer, it writes **unconditionally immediately before every open**, and it is the only iOS path that mints any of the five `.auxWindowOrigin`-bearing scenes — so every open overwrites the slot with its own launcher before the new root reads it. A parked value can only ever be re-read by the window that parked it, and one that outlives its window degrades through `resolveOriginScene` to `.anyWindow`, a live window rather than nowhere. What *is* true is #338-accepted and now documented on both `pendingAuxWindowOriginRaw` and `AuxWindowOriginModifier`: an aux window refocused from a **different** main window keeps its first origin.

*iOS · finder-likely · Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms*

**Symptom.** A rarely-hit misroute: after re-invoking an already-open aux window (same request refocuses it), a subsequently system-created aux window (e.g. via the app switcher) can route its document taps to whichever window performed that earlier re-invoke, rather than to .anyWindow.

**Mechanism.** openAuxWindow writes pendingAuxWindowOriginRaw before every openWindow(value:) (AppState.swift:1852-1856), but the only drain is the aux root's one-shot onAppear (AuxWindowOriginModifier, AppState.swift:2019-2027, didCapture guard). When openWindow refocuses an existing equal-value window, no onAppear runs, so the slot stays populated indefinitely; the next aux window whose creation did NOT go through openAuxWindow captures the stale value as its origin.

**Evidence.**
- `FRUSExplorer/App/AppState.swift:1854` — slot written before every openWindow(value:), including refocus-only invocations
- `FRUSExplorer/App/AppState.swift:2023` — onAppear-only, once-only drain (didCapture) — refocus path never clears the slot

*Related known:* #338 review accepted keep-first-origin on refocus; the undrained slot side effect was not part of that acceptance


---

## Filed issues (2026-08-07 — all 49 findings, grouped)

| Issue | Scope | Findings |
|---|---|---|
| [#746](https://github.com/joshbotts/FRUS-Explorer/issues/746) | Erase Everything leaves 5 synced record types behind | H-2 |
| [#747](https://github.com/joshbotts/FRUS-Explorer/issues/747) | Person rollup lifecycle vs live UI | H-1, M-14, M-27, L-38 |
| [#748](https://github.com/joshbotts/FRUS-Explorer/issues/748) | macOS Project Home dead-drop / surprise navigation | H-0 |
| [#749](https://github.com/joshbotts/FRUS-Explorer/issues/749) | macOS window-fronting sweep (11 unpaired sites + focus nits) | M-12, M-13, L-34–L-37 |
| [#750](https://github.com/joshbotts/FRUS-Explorer/issues/750) | iOS hand-off visibility rule | H-4, H-5, H-8, H-10, H-11, M-15, M-29, M-32 |
| [#751](https://github.com/joshbotts/FRUS-Explorer/issues/751) | Design: Browse-tab-as-universal-reader loses the origin | H-3, M-16, M-17, M-28 |
| [#752](https://github.com/joshbotts/FRUS-Explorer/issues/752) | iPad multi-window targeting family | H-7, H-9, M-25, M-30, M-31, M-33, L-39, L-40, L-43, L-48 |
| [#753](https://github.com/joshbotts/FRUS-Explorer/issues/753) | Boot-in-progress shown as definitive empty states | M-20, M-22, M-23 |
| [#754](https://github.com/joshbotts/FRUS-Explorer/issues/754) | Restoration depth (program decision) | H-6, M-21, L-45 |
| [#755](https://github.com/joshbotts/FRUS-Explorer/issues/755) | Collections reader gap + import selection | M-18, M-19, M-24 |
| [#756](https://github.com/joshbotts/FRUS-Explorer/issues/756) | SavedSearch silently drops filters | M-26 |
| [#757](https://github.com/joshbotts/FRUS-Explorer/issues/757) | Low-severity polish batch | L-41, L-42, L-44, L-46, L-47 |

---

## Recommended remediation order

1. **The Erase Everything gap (H-2)** — a stated privacy promise the code does not keep, and the
   second occurrence of a fault class Wave R-2a already fixed once. Mechanical fix (5 delete
   calls) + a `frusModelTypes`-driven inventory test so the list can never fall behind again.
2. **Rollup-id renumbering under live UI (H-1, M-27, L-38)** — one signal exists
   (`personCorrectionsGeneration`) with one observer; the fix is observers (or id-stability) at
   the other holders: search chips, analytics selections, trail scope signatures.
3. **Project Home dead-drop (H-0)** — macOS arm should mint a document window when no host
   exists (the pattern `routeLegacyPendingBrowse` already implements one screen away).
4. **The hand-off visibility family (H-4, H-5, H-8, H-10/11, M-15)** — one shared rule ("a
   hand-off must dismiss the presenting sheet, pop to root or push visibly, and front its
   target") applied at each consumer; the Chronology sheet already implements the dismissal
   half correctly and can serve as the template.
5. **`openWindow(id:)` pairing sweep (M-12, M-13, L-34, L-37)** — mechanical: add
   `bringMacWindowToFront` at the 11 unpaired sites, or wrap both in one helper so the pair
   cannot be split again.
6. **Back-from-page-turn (M-17, M-28 + the Q2 table)** — the one *design* question in the list,
   not a bug fix: in-stack prev/next on iOS (as macOS already does in-window) would keep reading
   journeys inside their origin context. Deserves its own decision rather than a patch.
7. iOS restoration honesty (H-6, M-20, M-23) and the iPad `.anyWindow` family (H-7, H-9, M-25,
   M-30, M-31, M-33) as two further passes.

## What was NOT audited

Runtime-only behaviors (actual focus order under the window server, restoration timing races,
Stage Manager geometry) — several findings carry named runtime checks for the owner's next
device session. VoiceOver/keyboard-only navigation. The macOS Collections/Settings scenes'
internals beyond their launchers.


---

## Appendix — surface maps and dimension answers


### macOS window management and focus

## macOS window/focus surfaces audited
**Scenes** (FRUSExplorerApp.swift:651-1051): main WindowGroup (multi-instance, ⌘N) · 17 singleton `Window(id:)` (frus.search 681, citationLookup 701, corpusBrowser 711 [⌘⇧B scene shortcut 718], people 730, crossReferenceGraph 740, sourceExplorer 757, analytics 810, personAnalytics 827, crossRefAnalytics 845, wordcloud 858, chronology 868, research 878, newProject 924, collections 934, history 984, about 1017) · Settings 994 · 6 value-based WindowGroups (DocumentWindowID 660, CrossVolumeProvenance 787, ProjectHome 894, NoteComposer 955, ResearchGuide 1040, + shared ArchivalNeighbors/RelatedDocuments 1080-1131).
**Focus movers**: `bringMacWindowToFront` (MainWindowView.swift:458-466 — activate + makeKeyAndOrderFront by identifier match; the only general fronting mechanism); routed-delivery fronting (MainWindowView.swift:182-190; MacDocumentView.swift:1287-1294); `openWindow(value:)` self-fronting on equal value (identity = volumeId/documentId, DocumentWindowID.swift:79-86).
**Routing**: AppState provenance model (AppState.swift:738-874): registerHost/hostBecameKey (controlActiveState advisory stamps) → bindTool → openDocument (provenance → recency fallback → mint) → routedBrowse consumed+fronted by target host; legacy channel pendingBrowseDocument(.macLegacyBrowse) drained only by mounted hosts (MainWindowView.swift:154-173, MacDocumentView.swift:1261-1277).
**Menu targeting**: focusedSceneValue keys documentCommands / collectionManagerCommands / collectionDetailCommands (FRUSExplorerApp.swift:2497-2519; publishers MacDocumentView.swift:241, MacCollectionManagerView.swift:312/815); all consumers disable (never silently no-op) when unfocused.
**Initial focus**: defaultFocus only in CitationLookupView.swift:142 (+task workaround); find bar @FocusState + focusToken (MacDocumentView.swift:1400,1448-1450); Search window: none.

**Dimension answers.**

HOW FOCUS (KEY WINDOW) MOVES — definitive answer, fully traced:

1) openWindow(id:) on a singleton Window that is CLOSED: the window is created and comes forward/key on its own. On one that is ALREADY OPEN but buried: it does NOT reliably come forward — this is a measured platform gap the codebase itself documents (MainWindowView.swift:443-457: "openWindow(id:) reliably *creates* a closed singleton window… but it does not always re-raise a window that is already open behind another one", observed in the Corpus Analytics → Search hand-off). The app compensates with the helper `bringMacWindowToFront(id:)` (MainWindowView.swift:458-466), which calls NSApplication.shared.activate() then makeKeyAndOrderFront(nil) on the NSWindow whose identifier equals or prefixes the scene id. This helper is the app's ONLY general fronting mechanism. Roughly 28 macOS producers pair openWindow(id:) with it (e.g. FRUSExplorerApp.swift:2656-2663, 2807-2835, 2894-2906; MacDocumentView.swift:262-263, 645-646; ResearchRailView.swift:689-727; ChronologyView.swift:194-195, 1175-1176; AnalyticsView.swift:1143-1144; PersonIndexView.swift:195-196; HistoryView.swift:477-478; ProjectHomeView.swift:883-884; FRUSSettingsView.swift:503-506). Eleven sites do NOT: MainWindowView.swift:266, 282, 299, 323, 331, 354, 360 (7 of the main window's 9 toolbar launchers), MacCorpusBrowserWindow.swift:1375, ResearchView.swift:683, HistoryWindowView.swift:114, FRUSExplorerApp.swift:1216 (About). At those sites an already-open buried window may stay buried — see findings 2-4.

2) openWindow(value:) on a value-based WindowGroup: SwiftUI focuses the existing window when the value compares equal (identity is (volumeId, documentId) for DocumentWindowID — DocumentWindowID.swift:79-86) and creates/fronts a new one otherwise. The codebase relies on this self-fronting (FRUSExplorerApp.swift:1072-1074; SupportingViews.swift:351-353; AboutView.swift:276-278 notes that openWindow(id:) against a value-based scene "silently does nothing"). Caveat handled in code: openWindow(value:) does NOT deminiaturize a docked window (MacDocumentView.swift:1291-1292).

3) Content hand-offs routed to a document host DO move focus deliberately. A tool-window document click resolves through AppState.openDocument (AppState.swift:839-852): provenance binding → liveness check → most-recently-key fallback → mint. The receiving host consumes `routedBrowse` and fronts itself: MainWindowView.swift:182-190 (re-read guard, append, deminiaturize if miniaturized, hostWindow.makeKeyAndOrderFront — "FM-G: a routed delivery is never invisible"); MacDocumentWindowView at MacDocumentView.swift:1287-1294 (append, deminiaturize, then openWindow(value: windowID) to re-front). So yes — when a hand-off routes a document to the main window or a document window, that window comes forward and becomes key; the user's focus does NOT stay in the tool window. When NO host is live, openDocument mints a fresh standalone DocumentWindowID window, which fronts by construction. The ONE exception is Project Home's document/lead/note clicks, which bypass openDocument (finding 1). Tool-parameter hand-offs (pendingSearch/pendingAnalytics/pendingWordCloud/pendingNARALookup/pendingVolumeGraph/pendingBrowseVolume) are consumed passively by the target window (.task + .onChange, e.g. SearchSheet.swift:374-399, WordCloudView.swift:1710-1726, CrossReferenceGraphWindowView.swift:132-136); consumers never front themselves — fronting is entirely the producer's job, which is why a producer that forgets bringMacWindowToFront yields a silent retarget of a buried window.

4) Active-host tracking: `controlActiveState == .key` bumps an ADVISORY per-host recency stamp (MainWindowView.swift:176-178, MacDocumentView.swift:1280-1282 → AppState.hostBecameKey:785-788). It is consulted ONLY by fallbackHost() (AppState.swift:829-833: max stamp among live hosts) for originless opens and dead provenance; provenance routing never samples focus. When NO host is registered at all, fallbackHost() returns nil and openDocument mints a window — "a document open must never silently do nothing" (AppState.swift:829-830). The "active host cannot show the content" case does not arise structurally: only document hosts register (MainWindowView.swift:154-164, MacDocumentView.swift:1261-1268), every host can display any document, and non-document content (volume graphs, NARA lookups, word clouds) is always addressed to fixed singleton tool windows, never to hosts. Residual caveat: whether controlActiveState actually fires .key at runtime is marked unverified in code (relatedKnown); if it never fired, stamps would degrade to registration order — most-recently-OPENED rather than most-recently-key — a graceful degradation by design (AppState.swift:740-745). Note also that if every stamp update came only from registration, fallback picks the most recently opened host.

5) Explicit AppKit focus calls: the complete inventory is bringMacWindowToFront (MainWindowView.swift:458-466), the MainWindowView routed-delivery fronting (186-189), and an unrelated NSOpenPanel (CollectionRichTextEditor.swift:383). Nothing else calls NSApp.activate/makeKey/orderFront.

6) FocusedValues / menu-command targeting: three keys — documentCommands (published by MacDocumentView.swift:239-241, exists in the main window's stack AND standalone document windows), collectionManagerCommands + collectionDetailCommands (MacCollectionManagerView.swift:311-315, 813-815); keys declared at FRUSExplorerApp.swift:2497-2519. All consuming menu items are DISABLED (grayed) when no publishing window is key — Document menu (2560-2612), Find in Document/Next/Previous (2634-2651), Collection menu (2695-2777), File ▸ Open Document in New Window (2529-2538). So NO command silently no-ops via a wrong-key-window focused value; the visible cost is that ⌘F/⌘G/⌥⌘↑/⌥⌘↓/⌘⇧N/⌘⇧H/⌘⇧R beep when a tool window (Search, Collections list, an analytics window) is key — the designed gating (comment at 2295-2301). Always-enabled commands (Analytics/Research menus, Find ▸ Search ⌘S, Citation Lookup ⌘⇧F) open their windows directly and all pair with bringMacWindowToFront. Menu-bar analytics/research commands deliberately CLEAR tool provenance (bindTool(_, to: nil), FRUSExplorerApp.swift:2808-2831, 2895) so later document opens follow the recency fallback.

7) Keyboard focus after a sheet dismisses: nothing in the codebase restores or assigns focus after any sheet dismisses — there is no focus-related onDismiss anywhere (grep); post-dismiss first responder is whatever AppKit restores. defaultFocus exists in exactly ONE place app-wide: CitationLookupView.swift:142, backed by a .task workaround (144-158) because defaultFocus alone failed to land in the Form-hosted field. The macOS Search window sets no initial focus at all (no @FocusState/defaultFocus in MacSearchWindowView — SearchSheet.swift), so where typing goes after ⌘S is left to AppKit (finding 5). The find-in-document bar self-focuses on appear and on each ⌘F via focusToken (MacDocumentView.swift:1400, 1448-1450) but restores nothing on hide (1437-1439, 1452).

8) Closing a document window: deliberate ROUTING cleanup but NO deliberate focus assignment. NSWindow.willClose (HostWindowAccessor, DocumentWindowID.swift:181-246) triggers unregisterHost (AppState.swift:795-808), which re-targets an in-flight routedBrowse at the surviving fallback host or demotes it to pendingBrowseDocument(.macLegacyBrowse) for the next host to drain on appear. Which window becomes key after the close is left entirely to AppKit's default z-order promotion; the advisory stamps then follow whatever becomes key, keeping later fallback routing aligned with the user's actual focus.


### state invalidation & staleness

## Staleness surfaces audited

**Boot-once SQLite stores (the #275 family)** — crossReferenceStore / personMentionStore / pageRangeStore / citationMatchingEngine, all recreated by `AppState.refreshReadOnlyStores()` (AppState.swift:640); called from 3 boot branches + every mutation in both storage hubs; reload observers on `readOnlyStoresGeneration` in 5 views + 1 scene id. **Coverage: complete for connections; the person-rollup TABLES are the gap** (never rebuilt mid-session).

**Person rollup (renumber-unstable ids, v8→v9 just bumped)** — ids are positional (`clusterIndex+1`). Reconsolidation triggers: launch (3 branches, FRUSExplorerApp:1596/1615/1628) + live user corrections (PersonClusterOverrideStore:98). Holders: live search chips (SearchViewModel:162 / MacSearchViewModel:617), Person Analytics selections (PersonAnalyticsView:336), facet chips, doc-view person popover, People detail sheet (self-dismissing). Persisted holders: none raw; `scopeSignature` embeds `rollup:N` as a string.

**Volume delete/add mid-session** — central cleanup via `DownloadManager.onVolumeDeleted` (index rows, Spotlight, AST cache); read-only stores reopened; but NO rollup reconsolidation on any add/remove path, and `auxDeleteVolume`/`removeAllVolumesFromIndex` never touch `person_rollup(_member)`.

**SavedSearch round-trip** — 12 scalar fields persisted; 8 SearchParameters fields silently dropped; one (volume scope) disclosed on both save sheets.

**Erase Everything** — 14 of 19 synced model types deleted (SettingsView:1389-1407 vs frusModelTypes:80-118).

**Project switch** — both search surfaces reset scope on `activeProjectId` change. **WorkingCorpus** — stable doc keys, coverage recomputed live; clean.

**Dimension answers.**

Assigned questions, answered with traced evidence:

(1) REINDEX / #275 coverage: The fix covers every boot-once read-only holder that exists today. AppState.refreshReadOnlyStores (App/AppState.swift:640-665) recreates crossReferenceStore, personMentionStore, pageRangeStore AND rebuilds citationMatchingEngine (which captures the page-range store by value, AppState.swift:646-660). Callers: all three boot branches (App/FRUSExplorerApp.swift:1601, 1618, 1635) and every mutation path in BOTH storage hubs (Settings/VolumesStorageHubView.swift:970,1069,1132,1142,1161,1184,1215,1243; Settings/MacVolumesStorageHub.swift:925,1023,1085,1095,1114,1137,1168,1197). Generation observers that reload open views: CrossReferenceAnalyticsView:237, PersonAnalyticsView:681+1101, VolumeConnectionGraphView:388, RelatedDocumentsView:201, CrossReferenceGraphWindowView:120, and the iOS graph scene id (FRUSExplorerApp.swift:615). SearchService/IndexingPipeline share the single writer FTS5Store built at boot (FRUSExplorerApp.swift:1491-1498), so they see rebuild writes directly. DocumentASTCache is purged per-volume by DownloadManager.onVolumeDeleted (FRUSExplorerApp.swift:1770-1788). Residue: person_rollup/person_rollup_member are absent from both auxDeleteVolume (IndexingPipeline.swift:5866-5884) and removeAllVolumesFromIndex (IndexingPipeline.swift:1560-1566) — see finding on mid-session rollup staleness.

(2) PERSON ROLLUP RE-CONSOLIDATION (v8→v9): rollup ids are positional (rollup_id = clusterIndex + 1, IndexingPipeline.swift:857-858), so ANY reconsolidation renumbers them wholesale. Every holder of a rollupId, checked: LIVE holders — SearchViewModel.personRollupId (Search/SearchViewModel.swift:162, passed into SQL at 824 → IndexingPipeline.swift:3188-3198), MacSearchViewModel (App/MacSearchViewModel.swift:617), facet chips write into live parameters (Search/FacetPanelView.swift:75), PersonAnalyticsView.selectedPeople (Analytics/PersonAnalyticsView.swift:336), DocumentViewModel.selectedPersonRollupId (DocumentView/DocumentViewModel.swift:695-697, resolved per-tap), PersonIndexView detail sheet (dismisses itself after each correction, PersonIndexView.swift:941). PERSISTED holders — none holds a raw rollupId: SavedSearch drops it entirely (Models/SavedSearch.swift:103-131), WorkingCorpus stores volumeId/documentId keys (Models/WorkingCorpus.swift:82), CustomVolumeScope resolves the person to volume ids at pick time (Settings/CustomScopesView.swift:346-357), SearchHistoryEntry embeds it only inside the scopeSignature STRING ("rollup:N", Search/SearchScopeSignature.swift:103) — see low finding. So the launch-time v9 renumber breaks nothing persisted; the exposure is mid-session renumbering (user corrections via PersonClusterOverrideStore.saveAndReconsolidate, Models/PersonClusterOverrideStore.swift:95-99; and the boot-reindex branch, whose consolidation lands minutes into an active session, FRUSExplorerApp.swift:1586-1605) against the live holders — findings 1 and 3.

(3) VOLUME DELETE while shown: index rows + Spotlight + AST cache are cleaned centrally via DownloadManager.onVolumeDeleted regardless of UI path (FRUSExplorerApp.swift:1770-1788). An open document keeps its in-memory render; navigating to a gone volume hits DocumentView's explicit error/undownloaded states (DocumentView/DocumentView.swift:478-487) — the aux-window spinner dead-end is known #323. Already-listed search results for the deleted volume stay on screen until the next submit (nothing observes indexedVolumeIds), and the person rollup keeps the removed volume's members until next launch (finding 4).

(4) SAVEDSEARCH round-trip: persists keywords/phrase/prefix/booleanMode/excludedTerms/scopeFlags/dateRange/subjectTagIds(inert, known)/documentTypeFilter/personRef only (Models/SavedSearch.swift:103-131). Silently DROPPED: userTagIds, volumeIds, documentIds, excludeDocumentIds, projectId, personRollupId, personLabel, includeFrontMatter. Only the volume-scope drop is disclosed on the save sheets (App/SearchSheet.swift:576-585; Search/SearchView.swift:1413-1425). No stale volume ids or rollup ids can be persisted — because nothing of the scope is persisted at all (finding 2).

(5) PROJECT SWITCH / ERASE: both search surfaces reset project scope on active-project change (Search/SearchView.swift:534; App/SearchSheet.swift:408 with resetSelection:true). Erase Everything, however, deletes only 14 of the 19 synced model types (Settings/SettingsView.swift:1389-1407 vs frusModelTypes, Models/ModelContainer+FRUS.swift:80-118): SavedSearch, PersonClusterOverride, CustomVolumeScope, ProjectLeadEntry, WorkingCorpus all survive — finding 2 (ordered as finding #2 below).

(6) WORKINGCORPUS keys: stable "volumeId/documentId" strings by design; WorkingCorpusResolver recomputes coverage per call against the live indexedVolumeIds set (Models/WorkingCorpusResolver.swift:74-80), so reindex is a no-op and a volume delete honestly shrinks "N of M indexed on this device". No staleness found.


### iOS tab & stack navigation, and BACK behavior

## iOS navigation surface map

**Shell:** ContentView → MainTabView (`.sidebarAdaptable`; per-window `@SceneStorage` tab, MainTabView.swift:90) — 5 tabs, each hosting its own NavigationStack:
- **Browse** = BrowserTabView → BrowserView, path `[BrowserLevel]` in BrowserViewModel (corpus→subseries→volume→compilation→document→people); destination BrowserView.swift:486; breadcrumb (suppressed on regular iPad + at .document)
- **Search** = SearchView, path `[DocumentBrowserEntry]` (SearchViewModel:437); destination SearchView.swift:481; sheets: filters, facets, saved searches, Citation Lookup (own stack, pushes docs inline), Archival Neighbors
- **Research** = ResearchView, one-deep path projecting `selectedItem` (:275); pushes category lists + HistoryView; Project Home is a sheet
- **Collections** = CollectionListView → pushed CollectionEditorView (no document-open route)
- **Settings** = SettingsView (own stack)

**Sheets that host documents inline (own stacks):** Chronology (BrowserView-presented), Citation Lookup, Cross-Reference Graph — each pushes DocumentView internally.

**Cross-tab handoff plumbing:** `AppState.openTab` (pendingTab) + `openBrowseDocument` (pendingBrowseDocument → BrowserView APPENDS `.document`) + `openSearch` (pendingSearch → SearchView applies params + runs, never touches its path). All consume-once, scene-addressed (`consumeHandoff`, AppState.swift:1812-1830).

**Document-open routes by producer:**
| Origin | Route | Back returns to origin? |
|---|---|---|
| Search results / timeline / concordance | in-stack push (SearchView:1544) | YES |
| Chronology rows | in-sheet push (:1152) | YES |
| Citation Lookup / CrossRef Graph rows | in-sheet push | YES |
| Cross-ref / page-ref / edge-tap inside ANY document | Browse-tab handoff (DocumentView:968-971, 1531-1539) | only if doc was Browse-hosted |
| Research docs (:708), History docs (:466), Project leads (:876), Related Documents (:409), Archival Neighbors (:496) | Browse-tab handoff | NO — unwinds prior Browse stack |
| People find-mentions (:191), person sheet (:563), History search rows, Analytics/WordCloud/Chronology→Search | Search-tab handoff | NO — tab switch |

**Dimension answers.**

OWNER QUESTION — "when a user opens a document and navigates back, do they return to the exact view they came from?" Per origin (iOS):

1. **Search results — YES.** A result tap pushes onto the Search tab's own stack (SearchView.swift:1544-1546 `vm.navigationPath.append(entry)`, destination declared at :481-490 inside the stack). Back (button or swipe) returns to the results list with query, page, and scroll state intact. This is the one origin that does NOT route through pendingBrowseDocument. Caveat: anything you do inside that document that opens another document (cross-ref, page-turn, related-docs row) exits the Search tab — see findings 1/5.

2. **People browser "Find all mentions" — NO (tab handoff, not a push).** PersonIndexView.swift:191-198 calls `openSearch(...)` + `openTab(.search)`. You land in the Search tab; Back there unwinds the Search stack, never the People list. The People screen survives on the Browse tab (manual tab tap returns to it). Hazard: if the Search tab still has a document pushed from an earlier search, the new mention search runs invisibly beneath it and you land on that stale document (finding 2).

3. **A collection — N/A: there is no document-open route from the iOS Collections tab at all.** The Collections module contains no `DocumentView`, `openBrowseDocument`, `openTab`, or `pendingBrowse*` reference (verified by module-wide grep); the only NavigationLink is the Collection Settings drill-in (CollectionEditorView.swift:681). Entry rows open the per-entry inspector (CollectionEntryRows.swift:643), not the document. So "back from a collection's document" cannot arise — the gap itself is finding 6.

4. **Chronology — YES.** Rows push inline onto the Chronology sheet's own stack (ChronologyView.swift:1152 `navigationPath.append(entry)`, destination :114). Back returns to the chronology list, range intact. Caveat: a cross-ref tapped inside that pushed document navigates the Browse stack BEHIND the still-open sheet — the tap looks dead (finding 3).

5. **Related Documents — NO.** RelatedDocumentsView.swift:409-412: row tap → `openBrowseDocument` + `openTab(.browse)`, then the sheet dismisses. The target is APPENDED to whatever the Browse stack already held (BrowserView.swift:632). If the source document was itself in the Browse stack, Back does return to it (it sits directly beneath). If the source document was in the Search stack or a sheet, Back unwinds the old Browse hierarchy — origin lost.

6. **Cross-reference link tapped INSIDE a document — depends on where the document lives.** Every cross-ref tap routes `openTab(.browse)` + `openBrowseDocument` (DocumentView.swift:968-971; page refs :986-997; frusexplorer://doc links :744-754). Browse-hosted document: appended one level → Back returns to the source document, one tap at a time — CORRECT. Search-hosted document: tab switches to Browse; Back unwinds the stale Browse stack, not to the source doc (finding 1). Sheet-hosted document (Chronology / Citation Lookup / Cross-Ref Graph): navigation happens invisibly behind the sheet (finding 3). The doc comment at DocumentView.swift:1523-1530 records this as a deliberate "route everything through Browse" decision.

7. **Project leads — NO.** ProjectHomeView.swift:864-877 routes to the Browse tab; the Project Home sheet is dismissed first (ResearchView.swift:190-193, precisely to avoid invisible navigation). Back unwinds the pre-existing Browse stack. To triage the next lead the user must re-open Research tab → Project Home sheet — one full round trip per lead.

8. **History — NO.** Document rows: HistoryView.swift:457-467 → Browse tab handoff (same as 7). Search rows: :475-481 → Search tab (finding 2 hazard applies).

SUB-AUDITS:
- **Tab stack preservation: YES.** Each tab keeps its stack across tab switches. Browse path lives in `BrowserViewModel.navigationPath` behind the `BrowserTabView` identity wrapper (MainTabView.swift:313-317, 334); Search in `SearchViewModel.navigationPath` (@State vm, SearchView.swift:276); Research is a one-deep projection of `selectedItem` (ResearchView.swift:275-278); Collections/Settings use internal NavigationStacks. All are in-memory only — lost on scene death (normal iOS behavior).
- **Document-to-document depth: pushes, and Back unwinds one at a time.** Each cross-ref/handoff APPENDS one `.document` level (BrowserView.swift:632); no replace, no collapse. Edge-tap page-turns also append (DocumentView.swift:1531-1539), so page-turning through N documents costs N Back presses to leave (finding 5).
- **pendingTab consumption: sound.** Consume-once, scene-addressed with `.anyWindow` wildcard (AppState.swift:1824-1830, 1987-1989), drained on change AND on appear (MainTabView.swift:181-194), so cold-launch handoffs aren't dropped; BrowserView likewise drains pendingBrowseDocument/Volume on appear after bootstrap (BrowserView.swift:236-246, 625-649). No dropped-payload path found.
- **iPhone vs iPad divergence:** routing is identical (shared MainTabView). Divergences: the Browse breadcrumb is suppressed entirely on regular-width iPad (BrowserView.swift:602), removing the level-jump affordance iPhone has; iPad adds "Open in New Window" and aux windows whose hand-backs resolve via `.auxWindowOrigin`/`resolveOriginScene` to `.anyWindow` when the launcher is gone (AppState.swift:1843-1856); and two sheets fail to inject `\.sceneID`, which on iPad multi-window can land a cross-ref in a different window (finding 7).
- **Swipe-back vs button-back: equivalent.** No `navigationBarBackButtonHidden`, no pop-gesture overrides anywhere (grep; only `interactiveDismissDisabled` on a storage sheet, VolumesStorageHubView.swift:1771). Both mutate the same path bindings. One interaction risk: the 56pt leading edge-tap zone (FRUSTheme.swift:377, active in Read mode, DocumentView.swift:1433) occupies the region where the back-swipe starts; a swipe registering as a tap opens the PREVIOUS document (via the Browse-tab handoff) instead of going back — needs a runtime check (finding 5).
- **navigationDestination placement: all correct.** Every iOS destination is attached to stack-root content, none inside a lazy container: BrowserView.swift:486, SearchView.swift:481, ChronologyView.swift:114, ResearchView.swift:240, CitationLookupView.swift:138, CrossReferenceGraphView.swift:239, CollectionListView.swift:150-155. The historical outside-the-container trap (toolbar/sheets declared on `BrowserView()` from the tab wrapper being silently dropped) is documented as fixed at MainTabView.swift:330-346.


### Document-open entry points: mechanism, back-behavior, and origin survival (both platforms)

| Entry point | Platform | Mechanism | Back / close returns to | Origin survives? |
|---|---|---|---|---|
| Search result | iOS | push onto `SearchViewModel.navigationPath` (Search-tab stack) — SearchView.swift:1544-1546, dest :481-486 | search results list | Yes (stack pop) |
| Search result | macOS | `openDocument(.tool(.search))` → routedBrowse → provenance host push; mints `DocumentWindowID` window if no host — SearchSheet.swift:1709-1718 | Search window untouched; host Back pops prior doc | Yes |
| People find-mentions | both | NOT a doc open: `openSearch` (pendingSearch) + Search tab / `frus.search` window — PersonIndexView.swift:190-199, 686-699 | iOS: person detail sheet DISMISSED (:699); Browse stack keeps People list | Partial (sheet lost; replaces current search — F4) |
| Collection item | both | **No in-app open.** macOS: external history.state.gov link (MacCollectionManagerView.swift:1598-1611); iOS: row tap → inspector only (CollectionEntryRows.swift:712-716) | n/a | n/a (F5) |
| Chronology row | iOS | inline push in Chronology sheet's own stack — ChronologyView.swift:1152, dest :114-116 | chronology list (in sheet) | Yes |
| Chronology row | macOS | `openDocument(.tool(.chronology))` → host — ChronologyView.swift:1150 | Chronology window stays open | Yes |
| Related Documents row | iOS sheet | `openBrowseDocument`+`openTab(.browse)` then sheet dismisses — RelatedDocumentsView.swift:401-413, 435 | Browse stack (prior content); ranked list GONE | No (F8) |
| Related Documents row | iPad window / macOS | routes to origin scene's Browse (auxWindowOrigin) / `.tool(.relatedDocuments)` → host; window stays (`onNavigate: nil`, :482) | list window persists | Yes |
| Archival Neighbors row | iOS sheet / window / macOS | same shape — ArchivalNeighborsSheet.swift:494-497, 590, 610 | sheet: dismissed; window: persists | sheet No / window Yes |
| Cross-ref graph node | iOS | push inside graph's own stack — CrossReferenceGraphView.swift:332-339 | graph canvas | Yes |
| Cross-ref graph node | macOS | `openDocument(.tool(.graph))` → host — :334 | graph window stays | Yes |
| `<ref>` tap in document | iOS | `openTab(.browse)`+`openBrowseDocument` → Browse-stack append — DocumentView.swift:914-976 | prior Browse stack item, NOT source doc (unless source was Browse) — F1/F2/F3 | Source doc survives in its host but Back ≠ source |
| `<ref>` tap in document | macOS | same-window `navigationPath.append` — MacDocumentView.swift:1070-1086 | source document | Yes |
| Edge-tap prev/next | iOS | same Browse-tab handoff — DocumentView.swift:1531-1539 | as `<ref>` above | as above |
| Citation lookup result | iOS | push onto lookup sheet's own stack — CitationLookupView.swift:386-389, dest :137-141 | parsed matches (in sheet) | Yes |
| Citation lookup result | macOS | ALWAYS mints standalone `DocumentWindowID` window (owner D2) — CitationLookupView.swift:376-385 | lookup window persists | Yes |
| Project leads/visits/notes row | both | ProjectHomeView.swift:864-877: iOS `openTab(.browse)`+`openBrowseDocument` (modal dismissed first, one-tick defer #431, :899-914); macOS `openBrowseDocument` → `.macLegacyBrowse` → fallback host | Browse stack / host stack; Project Home sheet closed on iOS | Partial |
| History row (shared view) | both | macOS `.tool(.history)` → host; iOS `openBrowseDocument`+`openTab(.browse)` — HistoryView.swift:457-469 | macOS: History pane stays; iOS: prior Browse stack | macOS Yes / iOS partial |
| History menu (macOS) | macOS | `.global` → most-recently-key host, else mint — HistoryWindowView.swift:120-129 | menu (stateless) | Yes |
| CrossRef Analytics doc/volume row | macOS | `.tool(.crossRefAnalytics)` → host — CrossReferenceAnalyticsView.swift:1209 | analytics window stays | Yes |
| CrossRef Analytics doc/volume row | iOS | `openBrowseDocument`+`openTab` beneath its OWN presenting sheet, no dismiss — :1205-1229 | sheet still up; push invisible — F1 | Appears broken |
| Spotlight / Handoff | macOS | `.global` → fallback host or minted window — FRUSExplorerApp.swift:2055-2064 | n/a | Yes |
| Spotlight / Handoff | iOS | `.anyWindow` + Browse tab; first live BrowserView consumes — FRUSExplorerApp.swift:2066-2070, BrowserView.swift:236-245 | prior Browse stack beneath | Partial |
| onOpenURL | both | `.fruscollection` import only — FRUSExplorerApp.swift:1188-1190; no document URL route | n/a | n/a |
| Working Corpus row | both | no doc open; corpus = search scope (banner in SearchView.swift:1022 / SearchSheet.swift:1280) | n/a | n/a |
| iPad standalone doc window `<ref>` | iPadOS | `\.sceneID` = LAUNCHING window (auxWindowOrigin, FRUSExplorerApp.swift:500-531) → target opens in the ORIGIN window's Browse tab, not in place — F6 | standalone window unchanged | Diverges from macOS |
| Corpus Browser (macOS) doc row | macOS | `.tool(.corpusBrowser)` → host — MacCorpusBrowserWindow.swift:939-943, 1280-1287 | browser window stays | Yes |

**Dimension answers.**

The dimension's (a)/(b)/(c) inventory is in surfaceMap. Cross-cutting summary: macOS uses ONE routing spine — AppState.openDocument(entry, from:.tool(...)/.global) → routedBrowse → provenance-host NavigationStack push, minting a DocumentWindowID window when no host is live (AppState.swift:839-874); tool windows always survive the open, so every macOS round trip preserves origin. iOS uses TWO patterns: in-place push onto the origin's own NavigationStack (Search results SearchView.swift:1544-1546; Chronology rows ChronologyView.swift:1152; Citation Lookup CitationLookupView.swift:388; graph nodes CrossReferenceGraphView.swift:336) — these round-trip cleanly — and the cross-tab handoff openBrowseDocument+openTab(.browse) (AppState.swift:1933-1949) consumed by BrowserView (BrowserView.swift:625-636), which appends to the Browse tab's existing stack: Back then pops to whatever Browse previously held, not the origin surface. Special answers: People find-mentions opens SEARCH (pre-seeded pendingSearch), not a document, on both platforms (PersonIndexView.swift:190-199); collection items open NO in-app document on either platform (external history.state.gov link on macOS only, MacCollectionManagerView.swift:1598-1611); Working Corpus rows never open documents — a corpus is a search scope, applied in Search (WorkingCorporaView rows are rename/delete only); onOpenURL handles only .fruscollection imports (FRUSExplorerApp.swift:1188-1190) — there is no document URL scheme; Spotlight/Handoff route .global on macOS (fallback host or minted window) and .anyWindow+Browse tab on iOS (FRUSExplorerApp.swift:2055-2071), with BrowserView's onAppear drain covering cold launch (BrowserView.swift:236-245).


### Modal/sheet/inspector/popover presentation state (iOS + macOS)

## Presentation surfaces audited (~150 sheet/fullScreenCover, 10 popover, 4 inspector, 29 alert, 17 confirmationDialog sites)

**iOS shell**
- `MainTabView` — per-scene word-cloud sheet via guarded `Handoff` binding (MainTabView.swift:207-221); pendingTab drained onChange+onAppear
- `BrowserView` — 4 boolean analytics/chronology sheets (168-217); pendingAnalytics/pendingChronology onChange-only (224-235), onAppear drains browse channels only (236-246)
- `SearchView` — 8 sheets incl. vm.showFilterPanel; pendingSearch drained onChange + .task
- `DocumentView` — consolidated `.sheet(item: $activeSheet)` (17 cases, 550-667) + 2 alerts + confirmationDialog + iPad `.inspector` (699-704) / iPhone `.researchRail` sheet split on userInterfaceIdiom (317)
- iOS aux WindowGroups (Document/SourceExplorer/Graph/ArchivalNeighbors/RelatedDocuments) — `\.sceneID` republished via `auxWindowOrigin` (FRUSExplorerApp.swift:500-635; AppState.swift:2016-2035)

**Shared browser stack** — CompilationView + MacCorpusBrowserWindow host the hoisted sheet anchors for section-emitting VolumeSourcesView / FrontMatterPersonsView (the documented per-child cure; verified compliant). VolumeSubjectsChips/PersonIndexDetailSheet anchor correctly.

**macOS** — MacDocumentView (3 item sheets + 4 alerts on the root, excerpt sheet on the web-view container); SearchSheet (inspector + 3 sheets + popover); MacCollectionManagerView (inspector + sheets + popover); rail is a manual overlay, never `.inspector`.

**Settings (both platforms)** — SettingsView/FRUSSettingsView tag/project/prompt editor sheets (platform-split duplicates, benign); NotesSettingsView; CustomScopesView facet sheets; storage hubs' dialogs. One shared-AppState-bool sheet: showResearchGuide.

**Verified-clean patterns**: platform-split duplicate anchors; per-row @State presenters; alert `presenting:` usage; size-class-complementary sheet/push gating in CollectionEditorView.

**Dimension answers.**

Audit results per assigned area:

(1) Group/Section per-child presentation: the documented cure is followed everywhere it was previously applied — VolumeSourcesView takes @Binding targets and anchors nothing itself (FRUSExplorer/Browser/VolumeSourcesView.swift:117-135), FrontMatterPersonsView likewise (FRUSExplorer/Browser/FrontMatterPersonsView.swift:55-57, 134-136 "NO .sheet here"), and both parents anchor exactly once on their List (FRUSExplorer/Browser/CompilationView.swift:200-247; FRUSExplorer/App/MacCorpusBrowserWindow.swift:1235-1257). Both section-emitting views guard their `.task` against per-child re-fire with a didLoad flag (VolumeSourcesView.swift:111-116; FrontMatterPersonsView.swift:48-51). I found NO new instances of the per-child anchoring bug; VolumeSubjectsChips anchors its sheet on a single VStack row (Browser/VolumeSubjectsView.swift:53-85), and CollectionEntryRows' sheet/dialog use per-row @State (Collections/CollectionEntryRows.swift:183-202), which is a single presenter each.

(2) Multiple presenters over one binding: apparent duplicates (SearchFilterView:159/211, PromptEditorView:121/167, CustomScopesView:392/449, CollectionPickerSheet:195/254, AboutView:165/486, CollectionExportSheet:298/395, NotesSettingsView:100/276) are all platform-split bodies or separate structs — only one anchor is live per platform. The one real multi-presenter-over-one-binding case found is `.sheet(isPresented: $appState.showResearchGuide)` in every iOS window's Settings tab (finding 4). SearchViewModel/DocumentViewModel are per-view @State, so their sheet bindings never span windows.

(3) Sheet-over-sheet/sheet+alert: nested sheets are attached inside the presented content (allowed); the PersonMergePicker→confirmation-alert chain sets state before dismissing and is the shipped #243 flow. The unhandled collision class is on compact-width iPad where the research `.inspector` auto-presents AS a sheet (finding 3).

(4) iPad inspector vs iPhone sheet: the split is keyed on userInterfaceIdiom, not size class (DocumentView.swift:313-317), so Stage Manager resize cannot flip a live rail between hosts — good. The residual gap is compact-width iPad (finding 3). CollectionEditorView's entry inspector is a model of doing this right: one `inspectedEntryId` drives a sheet when regular and a navigationDestination when compact via complementary gating (CollectionEditorView.swift:588-591, 755-757), so a mid-flow resize migrates the surface instead of stranding it.

(5) Dismissal cleanup: generally solid — PersonIndexView resets autoOpenMergePicker onDismiss (PersonIndexView.swift:158), MacDocumentView clears pendingExcerptCapture onDismiss (MacDocumentView.swift:424), DocumentView clears vm.selectedPerson and panelVisible on sheet close (DocumentView.swift:716-724). The word-cloud handoff slot is the exception: an unmatched Handoff parks forever because only dismissal clears it (finding 2).

(6) onChange vs onAppear consumption races: every iOS pendingX consumer drains BOTH on change and on appear — pendingTab (MainTabView.swift:181-194), pendingBrowseDocument/Volume (BrowserView.swift:152-164, 236-246), pendingSearch (SearchView.swift:495-513, 527-529), pendingCollectionSelection (CollectionListView.swift:91, 161), pendingChronology on macOS (ChronologyView.swift:128-131, 156) — EXCEPT pendingAnalytics and pendingChronology on iOS, which BrowserView consumes only in onChange (finding 1).

(7) Alerts on optional-item bindings: all audited alerts either pass `presenting:` (DocumentView.swift:515-546, MacDocumentView.swift:293-319, SupportingViews.swift:1433-1434) or degrade to a static message; none can present with load-bearing nil content. The one presentable-empty-content case found is a sheet, not an alert: DocumentView's `.crossReferenceGraph` sheet body is `if let store` with no else (finding 5).


### state persistence & restoration — what survives a tab switch, a window close, and an app relaunch, on both platforms

## Persistence & restoration surface map

**Persisted state (survives relaunch)**
| Store | Keys | Holder |
|---|---|---|
| @SceneStorage (4 total) | frus.selectedTab · search.facets.shown · search.inspector.expanded (×2 views) | MainTabView:90, SearchSheet:118/122, SearchView:249 |
| @AppStorage panel state | researchPanel.visible (4 views) + 4 rail accordions + analytics expansions + collections.mac.showPreview | MainWindowView:81, MacDocumentView:129/1186, DocumentView:284, ResearchRailView:108-112 |
| @AppStorage settings | SettingsKeys.* / WordCloudSettings.* / SearchDefaults.* / related.weights | Settings*, SearchView, RelatedDocumentsView |
| UserDefaults direct | tab seed (Keys.activeTab), hasCompletedOnboarding, one-shot flags | AppState:218/1570-1584, IndexingQueueBannerView:81 |
| Window values (OS-encoded) | DocumentWindowID · SourceExplorerRequest · GraphWindowRequest · ArchivalNeighborsRequest · RelatedDocumentsRequest · CrossVolumeProvenanceRequest | FRUSExplorerApp:500-649, 787, 1081, 1112 |

**Session-only state (@State / @Observable — dies with the process, never re-seeded)**
- iOS: BrowserViewModel.navigationPath (BrowserView:102), SearchViewModel (SearchView:233), ResearchView.selectedItem (:168-171), all sheet flags
- macOS: MainWindowView path (:77), MacDocumentWindowView path (:1182), MacSearchViewModel (SearchSheet:108), CorpusBrowser selection/detailPath (:60-66), graph picker stage (:73), Chronology/CitationLookup paths
- AppState pendingX hand-off slots + currentSourceNote*/currentGraphEntry — in-memory only (correct)

**Launch routing**: ContentView (ContentView:50-63) gates on downloadManager-derived hasVolumes; downloadManager assigned at end of async boot (FRUSExplorerApp:1791); splash arbiter returns .none on warm starts (CloudSurfaceArbiter:88-95). Boot guards: macOS Search/People/ArchivalNeighbors/RelatedDocuments honest ("Preparing your index…"); iOS Search tab + iOS graph scene dishonest (definitive empty states).

**Dimension answers.**

INVENTORIES (grep-verified across FRUSExplorer/):

@SceneStorage — exactly 4 declarations in the whole app:
1. "frus.selectedTab" (App/MainTabView.swift:90, AppTab: String enum AppState.swift:167) — per-window tab selection, seeded from UserDefaults Keys.activeTab via AppState.seedActiveTab (AppState.swift:1570) and written back on every change (MainTabView.swift:173-175 → persistTabSeed AppState.swift:1579). Read+written, coherent.
2. "search.facets.shown" (App/SearchSheet.swift:118, macOS Search window) — facet inspector visibility, drives .inspector at SearchSheet.swift:323.
3/4. "search.inspector.expanded" — declared twice: App/SearchSheet.swift:122 (macOS window) and Search/SearchView.swift:249 (iOS tab). Same key, same meaning, never co-resident in one scene (SearchView is only instantiated from MainTabView.swift:375 on iOS; grep found no macOS instantiation) — deliberate cross-platform reuse, not a collision.
No @SceneStorage key is written-but-never-read or read-but-never-written. One DOC LIE: AppState.swift:1734 claims MainTabView mints its scene id via @SceneStorage("frus.sceneID"); the shipped code is @State (MainTabView.swift:99) with an explicit comment that SceneStorage was avoided (#338 review). Doc-only drift, no user impact, but it will misdirect the next restoration audit.

@AppStorage — ~115 references; four families: (a) real settings (SettingsKeys.*, WordCloudSettings.Keys.*, SearchDefaults.*, SearchCollocationDefaults.*); (b) panel/section state that intentionally persists — "frus.document.researchPanel.visible" shared by 4 views (MainWindowView.swift:81, MacDocumentView.swift:129+1186, DocumentView.swift:284, same meaning everywhere), rail accordion keys (ResearchRailView.swift:108-112), analytics section-expansion keys (PersonAnalyticsView.swift:365-366, CrossReferenceAnalyticsView.swift:157-160), "collections.mac.showPreview" (MacCollectionManagerView.swift:640); (c) one-shot flags — "frus.hasShownSecondProjectNudge" (ProjectEditorView.swift:48, ProjectPickerMenu.swift:277), "frus.hasShownIndexingEducation" (IndexingQueueBannerView.swift:81 — see finding: named/documented as per-session, persists forever); (d) "frus.related.weights" (RelatedDocumentsView.swift:85, DocumentView.swift:286, ResearchRailView.swift:113). Cross-device sync (SettingsSyncCoordinator.swift:161-228) mirrors ONLY word-cloud tuning, research logging, citation style, and defaultDocumentMode — panel-visibility keys are NOT synced, so no cross-device rail cross-talk.

NAVIGATION-PATH HOLDERS — every one is @State (or a per-session @Observable held in @State); NONE is persisted and NOTHING re-seeds any of them after process death:
- iOS Browse: BrowserViewModel.navigationPath [BrowserLevel] (BrowserViewModel.swift:96) in @State viewModel (BrowserView.swift:102); survives tab switches by design (BrowserTabView wrapper, MainTabView.swift:313-334) — relaunch loses it.
- iOS Search: SearchViewModel.navigationPath (SearchViewModel.swift:437) in @State vm (SearchView.swift:233,276); keywords/results in the same vm. Survives tab switch, not relaunch.
- iOS Research: @State selectedItem projected into the stack path (ResearchView.swift:168-171, 275).
- macOS main window: @State [DocumentBrowserEntry] (MainWindowView.swift:77); standalone doc windows: @State (MacDocumentView.swift:1182); graph window picker stage @State (CrossReferenceGraphWindowView.swift:73); Corpus Browser selection/detailPath @State (MacCorpusBrowserWindow.swift:60-66); CitationLookupView NavigationPath @State (CitationLookupView.swift:82); ChronologyView @State (ChronologyView.swift:45); MacSearchViewModel/@State searchVM (SearchSheet.swift:108).
The only cross-launch document mechanisms are Handoff/Spotlight NSUserActivity continuations (FRUSExplorerApp.swift:1177-1186, 2044-2071) — isEligibleForHandoff only (DocumentView.swift:423-427), not wired as restoration activities.

FIVE iOS VALUE-BASED AUX SCENES — boot-race guard status (the header's claims at FRUSExplorerApp.swift:71-75 checked against code):
- DocumentWindowID: no guard — #323 (known, not re-reported).
- SourceExplorerRequest (540-585): renders the parsed note from the value alone; appState.indexingPipeline is passed optionally and the related-documents section is simply gated on it (SourceExplorerView.swift:79,162) and appears when the Observable lands — graceful, header claim holds.
- GraphWindowRequest (595-626): guard EXISTS (crossReferenceStore nil → else branch) but the else branch is the definitive "No Document Selected" empty state — a lie during the boot race (see finding 4). Header's "restores correctly" is only mostly true.
- ArchivalNeighborsRequest: real guard — pipelineReady + "Preparing your index…" placeholder + .task(id:) re-fire (ArchivalNeighborsSheet.swift:296-311, 351-371). Header claim verified.
- RelatedDocumentsRequest: same guard pattern verified (RelatedDocumentsView.swift:121-130, 157).

TAB / SEARCH / BROWSE / SHEETS:
- Selected tab persists across relaunch (SceneStorage) and seeds new iPad windows (UserDefaults). Verified.
- Search text/results/filters: survive tab switch on iOS (tab content stays mounted — the BrowserTabView comment documents this as the mechanism, MainTabView.swift:313-316); lost on relaunch on both platforms; macOS also loses them on window close. Saved Searches / SearchHistoryEntry exist but nothing auto-restores the last query.
- Browse position: survives tab switch; lost on relaunch on both platforms; never re-seeded.
- Sheets: all presentation flags are @State → every sheet is gone after relaunch. iPad document rail persists via "frus.document.researchPanel.visible" and its accordion keys — coherent because the rail only exists inside a document view. defaultDocumentMode == .rememberLast works by leaving that same key untouched on open (DocumentView.swift:395-402, MacDocumentView.swift:210-218); on iPhone every open writes it false by design (#404), harmless because the key is not synced cross-device.

HALF-SURVIVALS found: (1) tab identity survives, tab content doesn't (finding 1); (2) macOS window arrangement survives, every window's content resets (finding 3); (3) macOS Search window's facet/inspector booleans survive while the query they describe doesn't (finding 6); (4) standalone macOS document windows keep their root document but lose the pushed stack (finding 3); (5) "hasShownThisSession" persists forever (finding 7).


### Hand-off machinery — AppState pendingX slots, Handoff/SceneID targeting, value-based window requests, both platforms

## Hand-off surface map (writers → consumers, drain semantics)

**Scene-addressed Handoff<T> slots (consumeHandoff, clear-on-consume; AppState.swift:1792-1830)**
| Slot | iOS consumer | macOS consumer | on-appear drain? |
|---|---|---|---|
| pendingSearch | SearchView (scene, orAnyWindow; .task+.onChange, runs query) SearchView.swift:495-533,629-643 | SearchSheet (.macSearch; .task+.onChange) SearchSheet.swift:374-399 | YES both |
| pendingAnalytics | BrowserView (scene only) BrowserView.swift:224-229 | AnalyticsView (.macAnalytics) AnalyticsView.swift:1011-1059 | macOS yes, **iOS NO** |
| pendingChronology | BrowserView (scene only) BrowserView.swift:230-235 | ChronologyView (.macChronology) ChronologyView.swift:128-159 | macOS yes, **iOS NO** |
| pendingWordCloud | MainTabView sheet(item:) exact-scene only, cleared on dismiss MainTabView.swift:207-221 | WordCloudWindowContent (.macWordCloud) WordCloudView.swift:1710-1726 | macOS yes, **iOS: no `.anyWindow` acceptance; slot held while sheet open** |
| pendingBrowseDocument | BrowserView (scene, orAnyWindow, vm-gated adopt-then-clear) BrowserView.swift:152-154,625-636 | every host via routeLegacyPendingBrowse (.macLegacyBrowse) MainWindowView.swift:154-173, AppState.swift:871-874 | YES both |
| pendingBrowseVolume | BrowserView (scene, orAnyWindow) BrowserView.swift:639-649 | CorpusBrowserWindowView (.macCorpusBrowser) MacCorpusBrowserWindow.swift:186-206 | YES both |
| pendingTab (iOS) | every MainTabView (scene, orAnyWindow; onChange+onAppear) MainTabView.swift:181-193 | — | YES |

**Plain slots (clear-on-consume, singleton targets)**: pendingNARALookup → SourceExplorerWindowView .task+.onChange (SupportingViews.swift:1878-1936); pendingCollectionSelection → MacCollectionManagerView:303-325 + CollectionListView:87-96/160-162 (iOS consumer has NO iOS producer); pendingSettingsPaneRaw → FRUSSettingsView:133-145; pendingVolumeGraph → CrossReferenceGraphWindowView:132-150; researchGuideInitialPageId → ResearchGuideView:42-47; pendingSecondProjectNudge → SecondProjectNudgeModifier (app-wide alert) ProjectPickerMenu.swift:282-331; pendingDownloadScope → FRUSExplorerApp:1803 (**no writers — dead**).

**Live-bound (not consume-once)**: currentGraphEntry (graph window binds live, CrossReferenceGraphWindowView.swift:110); currentSourceNote* sextet + sourceNoteFocusID snapshot discipline (SupportingViews.swift:1824-1923, #369 BUG-8 fixed).

**macOS routing**: routedBrowse + liveDocumentHosts + toolProvenance (AppState.swift:746-874); consumer fronts + deminiaturizes (MainWindowView.swift:182-189; MacDocumentView.swift:1287-1291); orphan demotion path verified.

**iPad scene identity**: MainTabView mints per-window token, publishes \.sceneID, registers/unregisters live scenes (MainTabView.swift:99,168,188-201); aux windows republish origin via .auxWindowOrigin (FRUSExplorerApp.swift:529,583,633; RelatedDocumentsView.swift:473; ArchivalNeighborsSheet.swift:667; CrossVolumeProvenance window has none → producers go .anyWindow); origin resolution AppState.swift:1843-1847; NO scene-activation API anywhere (focus never crosses windows on iOS).

**Dimension answers.**

OWNER QUESTION — does a hand-off carry focus?

macOS: YES, consistently. Since the "provenance PR 2" relay retirement, every macOS producer traced opens its target window directly and fronts it alongside the slot write (e.g. MacDocumentView.swift:255-263 openSearch + openWindow + bringMacWindowToFront; same pattern at MacDocumentView.swift:644-646 for NARA, HistoryView.swift:475-478, MacCorpusBrowserWindow.swift:838-841, WordCloudView.swift:1431-1436, SavedSearchesView.swift:188-196, FRUSExplorerApp.swift:1362-1364). The routed document consumer even repairs minimized windows: MainWindowView.swift:182-189 deminiaturizes then makeKeyAndOrderFront. Every macOS singleton consumer drains on `.task` (value set before the window existed) AND `.onChange`: SearchSheet.swift:374-399, AnalyticsView.swift:1011-1059, ChronologyView.swift:128-159, WordCloudView.swift:1710-1726, SupportingViews.swift:1878-1903, MacCollectionManagerView.swift:303-305, FRUSSettingsView.swift:133-136, CrossReferenceGraphWindowView.swift:132-136. Consumers also run the content (MacSearchViewModel.applyParameters bumps parametersVersion so the query executes, MacSearchViewModel.swift:656-674; Analytics/Chronology apply-and-reload). Orphan rescue works: unregisterHost re-targets an in-flight routedBrowse or demotes it to pendingBrowseDocument(.macLegacyBrowse), which every host drains on appear (AppState.swift:795-808, MainWindowView.swift:154-173).

iOS: hand-offs carry TAB focus inside the consuming window (every content write is paired with openTab, e.g. MainTabView.swift:281-282, SearchView.swift:1383, DocumentView.swift:569-572), but NEVER window focus — there is no UIScene activation request anywhere in the app (grep for requestSceneSessionActivation: zero hits). So any hand-off consumed by a window other than the one the user is touching (all aux-window producers, all `.anyWindow` deliveries) lands in a window that is not brought forward — findings 1, 3, 6. Within a single window, focus carry is good EXCEPT the pendingAnalytics/pendingChronology pair, which can silently drop its payload when the Browse tab is cold (finding 2).

Per-slot exactly-once audit: every Handoff<T> slot (pendingSearch/Analytics/Chronology/WordCloud/BrowseDocument/BrowseVolume/Tab) is consumed through consumeHandoff (clear-on-consume, target-checked; AppState.swift:1812-1830) — the #338 fan-out is genuinely closed for these; I found no remaining multi-window content fan-out. The non-Handoff slots (pendingNARALookup, pendingCollectionSelection, pendingSettingsPaneRaw, pendingVolumeGraph, researchGuideInitialPageId) all clear on consume and are macOS-singleton-addressed by design. Two exceptions to consume-once: (a) iOS pendingWordCloud is held live by the sheet for its whole presentation and cleared only on dismiss (finding 5); (b) pendingSecondProjectNudge is an app-wide alert signal — with two iPad windows the alert presents in BOTH (acknowledged in the comment at MainTabView.swift:222-229) and its "Open Project Home" action reads the slot after the dismissal binding may have cleared it (finding 7).

Unmounted-consumer behavior: pendingSearch, pendingTab, pendingBrowseDocument/Volume, and all macOS windows have on-appear drains, so a parked value delivers on the next visit. pendingAnalytics/pendingChronology on iOS have NO drain — a value written while Browse is uninstantiated parks forever until the next hand-off overwrites it (finding 2). A pendingWordCloud targeted `.anyWindow` parks forever — no consumer accepts the wildcard (finding 3).

Writer races: all writes are main-actor; producers deliberately overwrite unconsumed values ("a pending scope is always fresher"). No same-slot double-write from a single user action was found; the only silent drops are the parked cases above.

pendingAuxWindowOriginRaw: set by openAuxWindow immediately before openWindow(value:), drained once by the aux root's onAppear (AppState.swift:1852-1856, 2015-2028). When openWindow refocuses an existing equal-value window, the slot is never drained and leaks (finding 8). A restored aux window correctly reads nil → `.anyWindow`.

#338 fan-out: closed for content. Residual: the second-project nudge alert fan-out (accepted in-code), and `.anyWindow` first-wins may pick a background window (finding 6).

Dead slot: pendingDownloadScope has a consumer (FRUSExplorerApp.swift:1803-1804) but ZERO writers anywhere in FRUSExplorer/ — the AppState doc comment (AppState.swift:239-245) describing onboarding/Settings writers is stale; onboarding evidently starts downloads by another path. No user-visible symptom, but the comment will mislead the next contributor.
