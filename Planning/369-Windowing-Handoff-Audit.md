# #369 Windowing / Hand-off Audit

*Consolidated from five parallel code audits (search, analytics/chronology/word-cloud, browse/document/volume/graph, macOS window-focus + provenance, iPad multi-window consumer inventory). Prepared for owner review before implementing #338.*

---

## 1. Summary

Cross-view hand-offs in FRUS Explorer work by writing a payload into a **process-global single-slot `pendingX` field on the one shared `AppState`** (`AppState.swift:218`, injected into every scene) and letting each scene observe it. On single-window iPhone and on macOS this is sound: iPhone has exactly one observer per channel, and every macOS tool target is a **singleton `Window` scene** (`FRUSExplorerApp.swift:613/641/668/727/772/781` etc.) that the producer opens and fronts directly with `openWindow(id:) + bringMacWindowToFront`. The macOS document-open path is even fully correct — it uses a **scene-addressed** request, `routedBrowse = RoutedBrowse(host: DocumentHostID, entry:)`, guarded by `routed.host == hostID` (`AppState.swift:743-756`, `MainWindowView.swift:182-190`, `MacDocumentView.swift:1243-1250`), which is the model the rest of the system lacks.

The systemic gap is **iPad multi-window (Stage Manager)**: the same single-slot `pendingX` fields carry a payload but **no destination**, and each open window binds its own observer to the same slot. Two failure shapes result. (a) **Nondeterministic winner** — consumers that re-read `appState` and clear-first (`pendingBrowseDocument`, `pendingBrowseVolume`, `pendingSearch`, `pendingTab`) let the first serially-invoked closure win and no-op the rest, so exactly one *arbitrary, un-targeted* window adopts — possibly a background window, and decoupled from which window won the separate `pendingTab` race. (b) **Fan-out to all windows** — consumers that do *not* re-read (`.sheet(item: $appState.pendingWordCloud)`, and the captured-param `pendingAnalytics`/`pendingChronology` closures) present in **every** open window at once. Two macOS-only defects sit adjacent to this: two `History → Search` producers omit `bringMacWindowToFront`, and the Source Explorer "Source Note" segment reads process-global state **live** instead of snapshotting it into local `@State` on consume (as `pendingNARALookup`/`pendingNoteComposer` correctly do), so a second document window can mutate an open note out from under the user.

---

## 2. Findings table

Refocus = "does the intended window come forward?" · Query fires = "does the handed-off query/nav actually execute (vs. only populate)?" · iPad fan-out = multi-window behavior.

### Cluster 1 — Search hand-offs

| Hand-off | Platforms | Refocus | Query fires | iPad fan-out | Severity |
|---|---|---|---|---|---|
| All producers → Search (`pendingSearch`+`pendingTab`) | iPad | GAP — no scene targeting; per-scene consume-once | GAP — tab-winner ≠ query-winner (decoupled channels) | nondeterministic winner | **high** |
| Word Cloud "Search for this term" → Search | iOS+iPad | GAP — iOS omits `pendingTab=.search` | partial — runs invisibly, user not brought to it | nondeterministic winner | **medium** |
| macOS People/Analytics/WordCloud/PersonAnalytics/Chronology/History/"Search this volume" → Search window | macOS | OK — singleton `frus.search` + front | OK — `parametersVersion`→`searchTrigger`→`performSearch` | none | ok |
| iPhone (single window) → Search tab | iPhone | OK | OK — `canRun` gate + `Task{vm.search()}` | none | ok |
| Inventory correction: CrossRef-Analytics & tag-chips are **not** Search hand-offs | iOS+macOS | n/a — CrossRef-Analytics→Browse; chips = in-place filter | n/a | none | ok |

### Cluster 2 — Analytics / Chronology / Word Cloud

| Hand-off | Platforms | Refocus | Query fires | iPad fan-out | Severity |
|---|---|---|---|---|---|
| Search → Corpus Analytics (iOS "Visualize") | iOS+iPad | GAP — no `pendingTab=.browse`; sheet on backgrounded Browse tab | OK once mounted (`AnalyticsView:436 runSearch`) | nondeterministic winner¹ | **medium** |
| Search → Corpus Analytics (macOS) | macOS | OK — singleton + front + provenance | OK | none | ok |
| Analytics → Search (reverse; #369 reconfirm) | iOS+iPad+macOS | OK both | **OK — fires both directions** | nondeterministic winner (iPad, via `pendingSearch`) | ok |
| Word Cloud word-tap → Corpus Analytics | iOS+iPad+macOS | OK — iOS sets `pendingTab=.browse`; macOS front | OK | nondeterministic winner¹ | low |
| Word Cloud (date-range) → Chronology | iOS+iPad+macOS | OK — iOS `pendingTab=.browse`; macOS front | OK | nondeterministic winner¹ | low |
| Chronology → Word Cloud | iOS+iPad+macOS | OK | OK | **all windows** (via `pendingWordCloud`) | **medium** |
| `pendingWordCloud` consumer (all ~17 producers) | iPad | GAP — `.sheet(item:)` in every window | OK | **all windows** | **high** |
| `pendingWordCloud` consumer (macOS) | macOS | OK — singleton `frus.wordcloud` | OK | none | ok |
| People → Person Analytics | iOS+iPad+macOS | OK | n/a — `PersonAnalyticsView()` parameterless dashboard | none | ok |

### Cluster 3 — Browse / Document / Volume / Graph

| Hand-off | Platforms | Refocus | Query fires | iPad fan-out | Severity |
|---|---|---|---|---|---|
| Cross-ref/Related/Archival/Research/CrossRef-Analytics → Browse (`pendingBrowseDocument`) | iOS+iPad | GAP — no window fronting; `pendingTab` per-scene only | winning BrowserView loads doc — maybe wrong window | nondeterministic winner | **high** |
| Volume Sources/Subjects/CrossRef-Analytics → Browse (`pendingBrowseVolume`) | iOS+iPad | GAP — same as above | winning BrowserView pushes `.volume` — maybe wrong window | nondeterministic winner | **high** |
| Tool windows → document host (`routedBrowse`, PR #392/#398/#399) | macOS | OK — provenance→fallback→mint, deminiaturize+front | OK | none — **host-addressed (the model)** | ok |
| Adjacent-doc edge-tap (legacy unguarded write) | macOS | recency-based `.global` fallback (usually the key window) | OK on fallback host | none | low |
| Volume tap → Corpus Browser window (`pendingBrowseVolume`, macOS) | macOS | OK — singleton `frus.corpusBrowser` + front | OK | none | ok |
| Corpus-Browser per-volume graph → Cross-Ref Graph (`pendingVolumeGraph`) | macOS | OK — singleton `frus.crossReferenceGraph` + front | OK | none | ok |
| Rail/Research/Corpus-Browser → Cross-Ref Graph ego-graph (`currentGraphEntry`/`GraphWindowRequest`) | iOS+macOS | OK — macOS singleton; iPad value-based `openWindow(value:)` | OK | none | ok |

### Cluster 4 — macOS window-focus + provenance

| Hand-off | Platforms | Refocus | Query fires | iPad fan-out | Severity |
|---|---|---|---|---|---|
| Source Explorer "Source Note" segment (`currentSourceNote*` sextet) | macOS | OK — open+front | **PARTIAL (#410-class)** — reads process-global **live**, no `.task` re-consume; cross-window mutation leaks | none | **medium** |
| History "Re-run search" → Search window | macOS | GAP (minor) — the only 2 producers missing `bringMacWindowToFront` | OK | none | low |
| Selected text → Source Explorer NARA Lookup (`pendingNARALookup`) | macOS | OK | OK — `.task`+`.onChange`, snapshots to local `@State` (**reference pattern**) | none | ok |
| Add/edit note → Note Composer (`pendingNoteComposer`) | macOS | OK | OK — local `@State` snapshot + `handoffId` identity (**reference pattern**) | none | ok |
| Tool-window doc opens → provenance host (`routedBrowse`) | macOS | OK — deminiaturize+front | OK | none — **robust mechanism** | ok |
| Cross-view tool hand-offs → Search/Analytics/WordCloud/Chronology | macOS | OK — every producer opens+fronts+stamps provenance (relays retired) | OK | none — singleton scenes | ok |

### Cluster 5 — iPad multi-window consumer inventory (re-examines clusters 1–3 fields from the multi-window angle)

| Hand-off | Platforms | Refocus | Query fires | iPad fan-out | Severity |
|---|---|---|---|---|---|
| any surface → Word Cloud (`.sheet(item: $pendingWordCloud)`) — *= C2 row* | iOS/iPad | GAP | OK, redundant per window | **all windows** | **high** |
| cross-ref/adjacent/Related/Archival/Research → Browse doc (`pendingBrowseDocument`) — *= C3 row* | iOS/iPad | GAP | loads once, un-targeted window; decoupled from tab winner | nondeterministic winner | **high** |
| Search over-cap "Visualize" → Corpus Analytics (`pendingAnalytics`) | iOS/iPad | GAP — captured-param closure, per-window `showAnalytics=true` | GAP — redundant execution across windows | **all windows**¹ | **high** |
| Word Cloud "View in Chronology" (`pendingChronology`) | iOS/iPad | GAP — captured-param closure | GAP — redundant execution | **all windows**¹ | **medium** |
| Find-all-mentions/person/date/indexing → Search (`pendingSearch`) — *= C1 row* | iOS/iPad | GAP — nondeterministic among live-Search windows; may miss if none on Search | runs at most once, un-targeted | nondeterministic winner | medium |
| Cross-Volume-Provenance/Volume-Subjects → Browse volume (`pendingBrowseVolume`) — *= C3 row* | iOS/iPad | GAP | applies once, un-targeted | nondeterministic winner | medium |
| every hand-off sets `pendingTab` → switch tab | iOS/iPad | PARTIAL (#316) — consume-once + `@SceneStorage` selectedTab; winner still arbitrary | GAP — `pendingTab` decoupled from content-field winner | nondeterministic winner | **medium (root)** |
| open-with `.fruscollection` → select collection (`pendingCollectionSelection`) | macOS ok / **iOS unfired** | macOS OK (singleton); iOS has **no consumer** | iOS: silently no-ops | none | low |
| Corpus-Browser graph → Cross-Ref Graph (`pendingVolumeGraph`) | macOS | OK | OK | none | ok |
| macOS producers → singleton Search/Analytics/Chronology/WordCloud | macOS | OK — open+front | OK | none | ok |
| macOS doc nav → host window (`routedBrowse`) | macOS | OK — **MODEL primitive** | OK | none | ok |
| Legacy origin-less `pendingBrowseDocument` → mint macOS doc window | macOS | OK-ish — value-based `openWindow(value:)` dedupes | OK | nondeterministic but harmless (one deduped window) | ok |

¹ **Auditor discrepancy — see §3.** The analytics/chronology cluster rated `pendingAnalytics`/`pendingChronology` "nondeterministic winner"; the iPad-inventory cluster's line-level read of the closure bodies rates them "all windows / high." The line-level read is the tie-breaker.

---

## 3. Confirmed bugs (prioritized)

### The #338 iPad multi-window fan-out / nondeterminism cluster

**BUG-1 (HIGH) — `pendingWordCloud` fans out to *all* iPad windows.** *The clearest #338 fan-out.*
`MainTabView.swift:182` attaches `.sheet(item: $appState.pendingWordCloud) { scope in WordCloudView(scope: scope) }` to the TabView in **every** MainTabView scene. `pendingWordCloud` is a single shared slot (`AppState.swift:633`) and `WordCloudScope` is `Identifiable` (`WordCloudModels.swift:301`), so a non-nil value presents the sheet in every open window simultaneously; dismissing one sets the binding nil and dismisses all mid-view. ~17 producers feed it (`DocumentView.swift:1058`, `ResearchRailView.swift:673`, `ChronologyView.swift:187`, `CollectionListView.swift:244`, `SavedSearchesView.swift:186`, …). *Scenario:* two Stage-Manager windows open → any "Word Cloud" button opens the cloud in both; closing it in one blanks it in the other.

**BUG-2 (HIGH) — `pendingAnalytics` fans out (captured-param closure).** *Auditor severity conflict — resolve as HIGH.*
`BrowserView.swift:165-170`: `{ _, params in guard let params else { return }; analyticsParameters = params; appState.pendingAnalytics = nil; showAnalytics = true }`. The closure acts on the **captured `params`** and does **not** re-read `appState`, so the nil-first clear cannot make it exactly-once — every live Browse tab sets its own `@State showAnalytics = true`. Producers: `SearchView.swift:737`, `WordCloudView.swift:829`. Latent second gap: `BrowserView.onAppear` (`:177-187`) drains only `consumePendingBrowseDocument/Volume`, **not** `pendingAnalytics`/`pendingChronology`, so a cold Browse mount (seed tab ≠ Browse) loses the hand-off entirely. *Discrepancy to flag:* cluster 2 rated this "nondeterministic winner / medium" reasoning the clear-first coalesces; cluster 5's read of the actual closure body (captured param, no re-read) shows the clear cannot prevent per-scene presentation. Treat as HIGH pending a quick empirical confirm on two windows.

**BUG-3 (MEDIUM) — `pendingChronology` fans out (captured-param closure).** Identical structure to BUG-2: `BrowserView.swift:171-176`, producer `WordCloudView.swift:983`; same `onAppear` non-drain.

**BUG-4 (HIGH) — `pendingBrowseDocument` picks a nondeterministic, un-targeted window.**
`BrowserView.swift:123` `.onChange` → `consumePendingBrowseDocument` (`:441-448`) re-reads `appState.pendingBrowseDocument`, **clears it before** `vm.navigationPath.append(.document)`. On N windows all N closures fire serially on the main actor; the first reads+nils, the rest re-read nil and no-op → exactly one adopter, but **which** window is undefined (SwiftUI does not order sibling-scene `onChange`) and is not tied to the acting window. Producers: `DocumentView.swift:941/1457`, `RelatedDocumentsView.swift:381`, `ArchivalNeighborsSheet.swift:491`, `ResearchView.swift:589`, `CrossReferenceAnalyticsView.swift:812`. Also decoupled from the `pendingTab` winner (BUG-7). Note the codebase's own comments disagree: `MainTabView.swift:77` says "adopt in every open window" while `AppState.swift:1291-1294` says "exactly one consumer ever adopts." *Scenario:* tap a cross-ref in the foreground window; a background Stage-Manager window loads the document and the user sees nothing happen.

**BUG-5 (HIGH) — `pendingBrowseVolume` picks a nondeterministic window.** Identical clear-first-after-guard idiom: `BrowserView.swift:133/451-459`. Producers `VolumeSourcesView.swift:731`, `VolumeSubjectsView.swift:228`, `CrossReferenceAnalyticsView.swift:823`.

**BUG-6 (HIGH) — `pendingSearch` nondeterministic + cross-field decoupled.**
`SearchView.swift:256/280-292` clears-first then `Task{vm.search()}`; `MainTabView.swift:168` consumes `pendingTab` independently. The two consume-once channels are drained by **different observers in different views**, so the window that wins `pendingTab` (switches to Search) **need not** be the window that wins `pendingSearch` (runs the query). *Scenario:* one window ends on the Search tab showing an empty field while a background window silently ran the query. #369 named this the People→Search concern — see the reconfirm below.

**BUG-7 (MEDIUM, ROOT) — `pendingTab` nondeterministic + decoupled from its content field.**
#316/#337 already made `pendingTab` consume-once (`AppState.consumePendingTab`, `AppState.swift:1296`) and moved selection to `@SceneStorage "frus.selectedTab"` (`MainTabView.swift:90`), killing the old all-mirror bug. Remaining: the winner is arbitrary, un-targeted, and — per BUG-6 — a **separate channel** from the content field. The `MainTabView.swift:165` comment ("so the hand-off's tab comes forward wherever the user is") overstates the code. This decoupling is the core architectural gap #338 must close with a single request+target primitive.

### #369-named query-fire reconfirms (both **fire** — populate-and-execute, per evidence)

- **People → Search DOES fire without keywords.** macOS: `MacSearchViewModel.applyParameters` (`:529-538`) bumps `parametersVersion`→`searchTrigger`, and `performSearch` runs on the standalone person filter (`personRef`/`personRollupId` guard, `MacSearchViewModel.swift:573-574`). iOS: `consumePendingSearch` `canRun` is true when `personRef`/`personRollupId` is present (`SearchView.swift:284-291`) → `Task{vm.search()}` (`:290`). The query executes; the only iPad defect is the *targeting* (BUG-6), not a dead click.
- **Analytics ↔ Search fires in BOTH directions.** Forward (Search→Analytics): `AnalyticsView.swift:436 runSearch()`. Reverse (Analytics→Search): iOS `SearchView.swift:290 Task{vm.search()}`; macOS `parametersVersion`→`searchTrigger`→`SearchSheet.task(id:searchTrigger)`→`performSearch`. Scoped by-volume/by-subseries drill-in carries `committedTerm+volumeIds` through the same path (`AnalyticsView.swift:471`) and fires. #369 reconfirm result: the handed-off query is included **and** executed, not merely field-filled.
- **Not query hand-offs (no concern):** People→Person Analytics is a parameterless corpus dashboard (`PersonAnalyticsView()`, `FRUSExplorerApp.swift:743`); CrossRef-Analytics document/volume taps go to **Browse**, not Search (`CrossReferenceAnalyticsView.swift:812-825`); SearchView tag chips are an in-place `selectedUserTagIds` filter, not a cross-view hand-off.

### macOS-only defects (independent of the iPad primitive)

**BUG-8 (MEDIUM) — Source Explorer "Source Note" segment cross-window content leak (#410-class). *Confirmed.***
The `currentSourceNote*` sextet is written **unconditionally** by every window's `loadDocument()` (`MacDocumentView.swift:927-972`: clears to nil at `:927`, sets to that window's note at `:961-967`) and by `openSources` (`ResearchRailView.swift:684-701`). The open Source Explorer window renders it **live**: `SupportingViews.swift:1867-1894` does `if let note = appState.currentSourceNote { MacSourceExplorerView(...) }` with no `.task` snapshot — the only `.task` there is `consumePendingNARALookup()` (`:1849`), which does not touch the note segment. The `openSources` §6.1 guard (`ResearchRailView.swift:685-697`) re-primes from the acting window's `entry` at open time, so the *initial* open is correct. **Leak:** after Source Explorer is open on doc X, any *other* document window running `loadDocument()` mutates the globals, and the reactive binding flickers to "No Document Selected" (`SupportingViews.swift:1885-1893`) then re-renders to the other window's note. Contrast `pendingNARALookup` (`SupportingViews.swift:1846-1863`) and `pendingNoteComposer` (`ResearchNoteEditorView.swift:437-447`), which snapshot into local `@State` on consume. The Source Note segment is the one tool surface reading process-global state live.

**BUG-9 (LOW) — History "Re-run search" omits `bringMacWindowToFront`.** `HistoryWindowView.swift:207-211` (window row) and `:297-303` (menu item) are the only two macOS `pendingSearch` producers that call `openWindow(id:"frus.search")` **without** the following `bringMacWindowToFront` — cf. eight sibling producers that pair them (`MacDocumentView.swift:255-256`, `AnalyticsView.swift:491-492`, `WordCloudView.swift:966-967`, `ChronologyView.swift:1171-1172`, `MacCorpusBrowserWindow.swift:833-835`, `PersonAnalyticsView.swift:1095-1096`). A Search window buried behind unrelated windows gets no explicit `NSApplication.activate()+makeKeyAndOrderFront`. Query still fires. Inconsistency, not a dead click.

### Shared-platform (iPhone + iPad) missing-`pendingTab` drops

**BUG-10 (MEDIUM) — Word Cloud "Search for this term" strands the user on the wrong tab.** `WordCloudView.swift:956-968` sets `appState.pendingSearch` then `dismiss()` only — it never sets `appState.pendingTab = .search` on iOS, unlike every sibling (`AnalyticsView.swift:494`, `PersonAnalyticsView.swift:1100`, `ChronologyView.swift:1175`, `DocumentView.swift:558`, and its own `:844`/`:998` for the Analyze/Chronology paths). `MainTabView.swift:168` observes `pendingTab`, not `pendingSearch`, so nothing switches to Search. The query *does* run (keywords → `canRun`), but invisibly on the background Search tab or on the user's next manual visit; the user is dropped back on the prior tab. Affects iPhone too, then inherits BUG-6 on iPad.

**BUG-11 (MEDIUM) — Search → Corpus Analytics never fronts the Browse tab (iOS).** `SearchView.openSearchInAnalytics` (`SearchView.swift:727-745`) sets `pendingAnalytics` but never sets `pendingTab`; the analytics sheet is owned by `BrowserView` (Browse tab, sheet at `BrowserView.swift:139`, `onChange` at `:165`). Tapping from the Search tab presents the sheet on the backgrounded Browse tab — the user on Search sees nothing come forward. Contrast `WordCloudView.swift:844` which sets `pendingTab=.browse` for the same target. Plus the latent `onAppear` non-drain (BUG-2) loses it entirely if Browse never mounted.

**BUG-12 (LOW) — `pendingCollectionSelection` has no iOS consumer.** `FRUSExplorerApp.swift:1140-1142` sets `pendingCollectionSelection + pendingTab=.collections` on an open-with import. macOS consumes it in the singleton `frus.collections` window (`MacCollectionManagerView.swift:300-322`), but `CollectionListView` (iOS Collections tab) has **no** reader (grep: only `pendingWordCloud` there). On iOS the tab switches but the collection is never selected.

---

## 4. #338 design proposal — one shared hand-off-targeting primitive

**Goal.** Replace every process-global single-slot `pendingX` channel with a request that carries *both a payload and a target scene id*, plus a consume-once helper so **only the intended scene** applies it. This generalizes the two things that already work — macOS `routedBrowse` (scene-addressed doc open) and #316/#337's consume-once `pendingTab` — into one mechanism that also covers iPad.

### The type

```swift
/// A cross-scene hand-off addressed to exactly one scene (or, deliberately, all).
struct Handoff<Payload: Equatable & Sendable>: Equatable, Sendable {
    let id: UUID                 // dedupe + re-read guard + .sheet(item:) identity
    var target: HandoffTarget
    var payload: Payload
}

enum HandoffTarget: Equatable, Sendable {
    case scene(SceneID)          // one window / host, resolved at SET time
    case broadcast               // deliberately every window (rare)
}
```

`routedBrowse` is already `Handoff<DocumentEntry>` with `target == DocumentHostID` in all but name (`AppState.swift:752`) — lift it into this generic and it becomes the reference adopter with **zero behavior change**.

### Scene identity source

- **macOS:** reuse the existing per-instance `DocumentHostID` (`.main(UUID)` minted `@State` at `MainWindowView.swift:71`; `.window(windowID)` at `MacDocumentView.swift:1129`) and the singleton `Window` ids. Producers already resolve a tool→originating host via `provenance(of:) → fallbackHost() → mintWindow` (`AppState.swift:728-756`). No new identity needed.
- **iPad:** define the missing per-scene identity — the same key-window / active-scene problem the #337 review hit. Mint `@SceneStorage("frus.sceneID") var sceneID = UUID().uuidString` per `MainTabView` instance (the exact analogue of the macOS per-instance host UUID), and register it into an `AppState` scene registry on `.onAppear` / unregister on `.onDisappear`, stamping a most-recently-active timestamp on `scenePhase == .active`. The producer stamps `target: .scene(registry.activeSceneID)` — mirroring the macOS `fallbackHost()` "most-recently-key host" rule (`AppState.swift:735-737`). Resolving "the active scene" to a concrete `SceneID` **at set-time** keeps the consumer a plain equality check (no live "who is active" query inside the consumer, which is where nondeterminism enters today).

### The consume-once helper

```swift
extension AppState {
    /// Returns the payload iff this scene is the addressed target, clearing the slot once.
    func consumeHandoff<P>(_ keyPath: ReferenceWritableKeyPath<AppState, Handoff<P>?>,
                           for sceneID: SceneID) -> P? {
        guard let h = self[keyPath: keyPath], h.target == .scene(sceneID) else { return nil }
        self[keyPath: keyPath] = nil
        return h.payload
    }
}
```

Each scene's `.onChange`/`.task` calls `consumeHandoff(\.pendingSearchHandoff, for: mySceneID)`. The `target == .scene(sceneID)` guard means only the addressed scene applies; the clear is idempotent. This is exactly the macOS `routed.host == hostID` guard (`MainWindowView.swift:182`, `MacDocumentView.swift:1243`) generalized to every field.

### Two structural fixes the primitive enables

1. **Kill cross-field decoupling (BUG-6/BUG-7).** Fold `pendingTab` into each content payload — e.g. `SearchHandoff { tab: .search; params: SearchParameters }` — so the scene that switches the tab is *definitionally* the scene that loads the content. One request, one target, one adopter.
2. **Kill the fan-out consumers (BUG-1/2/3).** For the `.sheet(item:)` word-cloud path, make the item a computed binding that yields non-nil only when `handoff.target == .scene(mySceneID)` (or move it to the consume-once observer + local `@State` snapshot, mirroring `pendingNARALookup`/`pendingNoteComposer`). For the captured-param `BrowserView` closures (`:165`/`:171`), switch from acting on the captured `params` to `consumeHandoff(...)` re-read-and-guard — this both scene-targets *and* removes the captured-param fan-out in one change.

### What #316/#337 already solved, and how this generalizes it

#316/#337 made `pendingTab` **consume-once** (one adopter, not all-mirror — `AppState.consumePendingTab`, `AppState.swift:1296`) and moved tab selection to per-scene `@SceneStorage` (`MainTabView.swift:90`). This proposal keeps consume-once but **adds a target address**, so "the one adopter" is the *intended* scene rather than an arbitrary race winner, and **bundles the tab with its content** so the two can no longer split across windows.

### Migration order across the `pendingX` consumers

1. **Land the primitive.** Introduce `Handoff`/`HandoffTarget`/`consumeHandoff` + the iPad `SceneID` registry; refactor macOS `routedBrowse` to sit on it (no behavior change) as the reference adopter.
2. **`pendingWordCloud`** — deterministic all-windows bug, simplest to demo/verify (BUG-1). Convert the `.sheet(item:)` to scene-guarded.
3. **`pendingAnalytics` + `pendingChronology`** — captured-param fan-out (BUG-2/3); switch the `BrowserView` closures to `consumeHandoff`; also fix the `onAppear` non-drain.
4. **`pendingBrowseDocument` + `pendingBrowseVolume`** — nondeterministic winners (BUG-4/5); reuse the exact macOS `routed.host == hostID` shape on iOS.
5. **`pendingSearch` + fold `pendingTab`** — combined `SearchHandoff` (BUG-6/7). This is the decoupling fix and should land as one payload.
6. **Sweep remainders** — add the missing iOS `pendingCollectionSelection` consumer (BUG-12); audit any field not yet migrated.

---

## 5. Recommended sequencing

### Quick wins — land now, no refactor, independent of #338

These are one-to-few-line fixes that remove real user-visible breakage immediately:

- **BUG-10** — add iOS `appState.pendingTab = .search` in `WordCloudView.swift:956-968`. Fixes the wrong-tab drop on *both* iPhone and iPad.
- **BUG-11** — add `appState.pendingTab = .browse` in `SearchView.openSearchInAnalytics` (`SearchView.swift:727`).
- **BUG-9** — append `bringMacWindowToFront(id:"frus.search")` after `openWindow` at `HistoryWindowView.swift:208` and `:298`.
- **BUG-8** — convert the Source Explorer "Source Note" segment to the `.task { consume() } + .onChange` + local-`@State` snapshot pattern (mirror `pendingNARALookup` at `SupportingViews.swift:1846-1863`). macOS-only, self-contained.
- **BUG-12** — add an iOS `pendingCollectionSelection` consumer in `CollectionListView`.

Caveat: BUG-10/BUG-11 fully fix iPhone but on iPad still ride the nondeterministic `pendingTab` channel — necessary but not sufficient there; the full fix needs the primitive.

### The shared-primitive refactor (#338 proper)

Everything in §4, migration steps 1–6. Do the primitive + `routedBrowse` refactor first (safe, no behavior change), then the fan-out fields (BUG-1/2/3 — highest severity, simplest shapes, easy two-window verification), then the nondeterministic-winner fields (BUG-4/5), then the combined `SearchHandoff` that also closes the decoupling (BUG-6/7).

### Platform scoping of the findings

- **macOS-only** (fix independently, not part of the iPad primitive): BUG-8 (Source Note leak, medium), BUG-9 (History front, low), and the legacy adjacent-doc recency route (`DocumentView.swift:1453`, low — correct in the common single-key-window case).
- **iPad-only** (the #338 cluster): BUG-1 (high), BUG-2 (high), BUG-3 (medium), BUG-4 (high), BUG-5 (high), BUG-6 (high), BUG-7 (medium, root). The macOS twins of every one of these are already safe because the targets are singleton `Window` scenes.
- **Shared iPhone + iPad** (not multi-window-specific): BUG-10, BUG-11 (medium — visible even single-window), BUG-12 (low, iOS).

### Open item for the owner

The **§2 footnote-1 discrepancy** on `pendingAnalytics`/`pendingChronology` (BUG-2/BUG-3): the two auditors split between "nondeterministic winner (medium)" and "fans out to all windows (high)." The line-level read of `BrowserView.swift:165-170`/`:171-176` (captured `params`, no `appState` re-read) supports **fan-out/high**. A 5-minute empirical check on two Stage-Manager windows would settle it before the refactor sets their target severity.
