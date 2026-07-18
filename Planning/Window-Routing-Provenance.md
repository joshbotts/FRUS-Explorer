# Window Routing: Provenance Redesign (macOS)

**Status:** Investigation complete · **owner decisions D1–D5 RESOLVED 2026-07-18 (all as recommended — see §8)** · implementing per §10
**Supersedes:** the #392 `activeDocumentHost` mechanism (merged 2026-07-18, confirmed flaky at runtime)
**Scope:** macOS only. iOS/iPadOS keep their existing `pendingBrowseDocument` paths untouched (D5).

## 1. The spec (owner, 2026-07-18)

> Originating windows own both direct and indirect downstream document opens unless the user
> overrides through contextual menu options to open a document in a new window. A search from the
> initial window (A) opens documents in A; document navigation from a cross-reference graph or
> corpus browser triggered within A opens in A; documents selected from a search window spawned
> from a subsequent new window (B) open in B. "Open in New Window" from A or B opens new window C.

Distilled to one rule — **provenance routing**:

- Every surface that can trigger a document open has a **provenance host** — the document-hosting
  window it descends from. A document host (each main window, each standalone document window) is
  its own provenance. A tool window's provenance is the host that spawned it, **transitively**
  (Archival Neighbors spawned from A's search window belongs to A; People → Search → document is a
  three-hop chain that still lands in A).
- Document opens land in the provenance host — never in "whichever host was most recently active."
- The explicit contextual **Open in New Window** is the only override: it mints a standalone
  document window, which then owns its own downstream opens.

## 2. The as-built mechanism (#392)

Four steps, with the origin information discarded at step 1:

1. **Producer** (any tool window) writes `appState.pendingBrowseDocument = entry` — origin-less
   (`AppState.swift:641`; ~13 macOS producer surfaces, inventory §5).
2. **Every open host** observes it and races to call `routeBrowseToActiveHost()`
   (`MainWindowView.swift:115-118`, `MacDocumentView.swift:1194-1197`). Clear-first makes the
   translation exactly-once.
3. The translation stamps `RoutedBrowse(host: activeDocumentHost, entry:)` — where
   `activeDocumentHost` is "the document-hosting window most recently made key," sampled from
   `controlActiveState` observers on each host (`AppState.swift:662-666`).
4. The **matching host** consumes: appends to its `navigationPath`, clears (`MainWindowView.swift:129-133`,
   `MacDocumentView.swift:1211-1216`).

## 3. Why it misroutes — failure catalog

The observed "flakiness" is three defect classes stacked; the first is not even a race.

| # | Failure | Mechanism |
|---|---------|-----------|
| FM-A | **Recency ≠ provenance** (the core defect, deterministic) | Launch Search from A → glance at document window B for any reason → click a result → routes to **B**. Working exactly as built; wrong per spec. |
| FM-B | Click-vs-focus delivery race | AppKit makes windows key synchronously on mouseDown; the host's `controlActiveState` write lands a SwiftUI cycle later. Fast click sequences translate against a stale host. |
| FM-C | Tool→tool focus never updates the pointer | search→graph→search leaves `activeDocumentHost` at whatever host was key before the excursion. |
| FM-D | ⌘N fan-out | All main windows identify as `.main` (self-documented, `DocumentWindowID.swift:52-55`); consumption is whichever observer runs first — and both observers act on the *captured* onChange value, so double-append is possible. |
| FM-E | Route to a dead `.main` | `MacDocumentWindowView.onDisappear` resets to `.main` without checking a main window exists. Click → routed to nobody → **silent dead click**, value stranded until overwritten. |
| FM-F | Host closed mid-flight | A route minted for `.window(X)` while X is closing is never consumed. `onDisappear` is additionally an unreliable close signal in this codebase (retained popped views, project memory). |
| FM-G | Invisible navigation | The `.main` consumer never fronts itself (the standalone consumer does, review fix F2) — a route into a buried/miniaturized main window looks like a no-op; users click again and stack duplicates. |
| FM-H | The API itself | `controlActiveState` is deprecated on macOS 15 for `appearsActive`, which *cannot express* key-vs-active — Apple considers the distinction an implementation detail. The design is built on a signal Apple is retiring. |
| FM-I | Mint-then-click-fast | "Open in New Window" then immediately clicking more results interleaves destinations — the new window isn't the active host until its content mounts. |
| FM-J | Originless launches | History menu, Handoff/Spotlight (`navigateToDocument`), scene shortcuts (⌘F/⌘⇧B/⌘⌥R) run no host code; they inherit all the staleness above. |

**Adjacent bugs, same disease (process-global state where per-window state is needed):**

- **Sources-tile identity leak:** `MacDocumentView.loadDocument` rewrites the process-global
  `currentSourceNote*` sextet on every load in *any* window; the rail's `openSources()` re-primes
  only when nil — so with two document windows, the older window's Sources tile opens the *newer*
  window's source note (`MacDocumentView.swift:915-960`, `ResearchRailView.swift:673`).
- **Find-all-mentions dead with main closed:** producers set `pendingSearch`, but the only observer
  that *opens* the Search window is on `MainWindowView` (`MainWindowView.swift:141-145`) — from a
  standalone document window with main closed, the click does nothing. Same relay pattern affects
  `pendingAnalytics` / `pendingWordCloud` / `pendingChronology`.
- **Chronology's broken embed:** its rows push `MacDocumentView(entry:, navigationPath: .constant([]))`
  inline (`ChronologyView.swift:106-112`) — cross-ref taps and prev/next inside that document are dead.

## 4. The redesign

Origin is **captured once, synchronously, at spawn** — by the window that already knows its own
identity. Nothing is sampled at click time.

### 4.1 Identity + host registry

```swift
enum DocumentHostID: Hashable {
    case main(UUID)                 // per-MainWindowView instance (@State-minted token)
    case window(DocumentWindowID)   // standalone document window (unchanged)
}
```

`AppState` gains a **live-host registry**: hosts register on appear
(`liveHosts[id] = lastKeyStamp`), refresh their stamp when they become key (the existing
`controlActiveState` observers survive **demoted to advisory** — they feed only the fallback, so
their flakiness degrades gracefully instead of corrupting every route), and deregister on close.
Each host captures its `NSWindow` via a tiny `HostWindowAccessor` (NSViewRepresentable), giving us
(a) a **reliable close signal** (`willCloseNotification` → deregister; `onDisappear` kept as
belt-and-braces) and (b) **fronting** — `makeKeyAndOrderFront` on consume, fixing FM-G for main
windows.

### 4.2 Provenance registry

```swift
enum ToolSurface: Hashable {
    case search, corpusBrowser, graph, sourceExplorer, analytics, personAnalytics,
         crossRefAnalytics, wordCloud, chronology, research, people, citationLookup, history
    case archivalNeighbors(ArchivalNeighborsRequest)     // value-based → per-instance key
    case relatedDocuments(RelatedDocumentsRequest)
    case crossVolumeProvenance(CrossVolumeProvenanceRequest)
}
var toolProvenance: [ToolSurface: DocumentHostID]
```

- **Bind at launch:** every `openWindow` call site for a tool stamps
  `appState.bindTool(.search, to: origin)`. Host-mounted launchers (rail tiles, titlebar buttons,
  PersonDetailSheet) read their origin from a new **`@Environment(\.documentHostID)`** set at each
  host root — the rail never needs to know which window it's mounted in.
- **Transitive:** a tool spawning another tool binds the child to *its own* provenance
  (`toolProvenance[.search]`), not to itself.
- **Singletons re-bind on every explicit launch** (last-spawner-wins); merely focusing the window
  does not re-bind. Value-based windows are keyed per-instance by their request value. Provenance is
  session-scoped (never persisted/restored — a restored window resolves through the fallback).

### 4.3 The routing call

Producers replace `pendingBrowseDocument = entry` with:

```swift
appState.openDocument(entry, from: .search)          // tool surfaces
appState.openDocument(entry, from: .global)          // History menu, Handoff/Spotlight
```

`openDocument` resolves: `toolProvenance[tool]` → **liveness check** against the registry → if dead
or unbound, the fallback chain (§8-D3) → writes `routedBrowse` (struct unchanged). The liveness
check at *delivery* is the structural fix for FM-E/F — even a missed deregistration can't strand a
click. Consumers guard on live state (`guard appState.routedBrowse == routed`), append, front
themselves, clear. With per-instance identities exactly one host can match (kills FM-D).

### 4.4 Relay elimination (direct-open conversion)

The `pendingSearch`/`pendingAnalytics`/`pendingWordCloud`/`pendingChronology` producers convert to
**direct `openWindow` + payload + provenance stamp** at the producer — the pattern the C1 rail work
already established ("rail tiles call openWindow directly"). The MainWindowView-only opening relays
are deleted on macOS (iOS keeps its own observers). This structurally fixes find-all-mentions-dead-
with-main-closed and makes tool→tool provenance exact at every hop.

### 4.5 What survives untouched

In-window navigation (cross-ref taps, prev/next) stays local to the host's `navigationPath`.
The explicit **Open in New Window** paths (`SearchSheet.swift:1127-1133` context menu,
File ▸ Open Document in New Window) stay exactly as they are — they're the spec's sanctioned
override; the minted window self-registers as a provenance root on appear.

## 5. Migration inventory

**Producers → `openDocument(entry, from:)`** (all currently `pendingBrowseDocument = entry`):
SearchSheet `navigateToResult` (:1109) · MacCorpusBrowserWindow ×3 (:917, :1258, :1344) ·
CrossReferenceGraphView ×3 (:321, :767, :1032) · RelatedDocumentsView (:367) ·
ArchivalNeighborsSheet (:464) · CrossReferenceAnalyticsView (:799) · Source Explorer
`onRelatedDocumentTapped` (SupportingViews:1875) · ResearchView (:567) · HistoryWindowView window
(:196) + menu (:285, → `.global`) · FRUSExplorerApp `navigateToDocument` (:1670, → `.global`).

**Launchers → add `bindTool` stamp:** MainWindowView trailingTools (Search/Browse/Analytics ▾/My
Research ▾) · rail tiles `openGraph`/`openSources`/`openRelated`/`openWordCloud` · corpus-browser
People/graph spawns · Search's Citation-Lookup/Archival-Neighbors spawns · ResearchView graph spawn ·
Source Explorer's CollectionDetail → Archival Neighbors · WordCloud's Search/Analytics/Chronology
hand-offs · Chronology's word-cloud spawn.

**Deletions:** `activeDocumentHost` + `routeBrowseToActiveHost()` + both every-host translation
observers + both DEBUG prints + the `.onDisappear` reset-to-`.main` + the macOS relay observers.
`pendingBrowseDocument` remains iOS-only (plus nothing on macOS).

## 6. Adjacent bugs folded in

1. **Sources-tile leak:** `openSources()` re-primes whenever the global's `(volumeId, documentId)`
   differs from the rail's own entry — not only when nil.
2. **Find-all-mentions relay** — fixed by §4.4.
3. **Chronology embed** — per owner decision D1 (§8).
4. Doc drift: the FRUSExplorerApp scene table undercounts (claims 21 scenes/3 WindowGroups; actual
   22/4, `relatedDocumentsScene` omitted) — fix in the same PR. Stale comment `SearchSheet.swift:904-905`.

## 7. Test plan

The routing core becomes pure `AppState` logic — unit-testable without UI (the #392 tests only
covered value equality). New `WindowRoutingTests`:

- register two mains + one standalone; bind `.search` → A; produce; assert routed host A.
- transitive: bind `.search` → A, spawn `.archivalNeighbors` from search, produce → A.
- singleton re-bind: bind `.search` → A, re-bind → B, produce → B.
- liveness: bind → A, deregister A, produce → fallback (per D3), never stranded.
- `.global` with no live hosts → per D3.
- double-consume impossibility with per-instance main identities.
- consumer live-state guard (simulated stale capture).

Runtime verification stays the owner's visual pass (checklist in the PR, mirroring the A/B/C
walkthrough); the two DEBUG prints are deleted with the observers they instrumented.

## 8. Owner decisions — RESOLVED 2026-07-18 (all as recommended)

| # | Question | Resolution (owner) |
|---|----------|----------------|
| **D1** | **Chronology rows** — currently read inline via a broken `.constant([])` embed. Route to provenance host like every other tool (killing the embed), or keep inline reading and fix the binding (making Chronology a quasi-host)? | **Route to provenance host.** Consistent with the spec's "corpus browser" example; deletes a broken code path; the rail inside chronology-pushed docs stops having ambiguous provenance. |
| **D2** | **Citation Lookup** always mints a standalone window per result (deliberate, #239) — technically violates "Open in New Window is the *only* override." Bless as a named exception, or convert to routed-with-context-menu-override? | **Bless the exception.** It's a "locate this exact citation" tool; a dedicated window per match is arguably the right UX and predates the spec. Document it in the scene comment. |
| **D3** | **Fallback chain** when provenance is dead/unbound (origin closed; `.global` opens; restored windows): ? | **Most-recently-key *live* host → any live main → mint a standalone document window for the entry.** Never drop a click silently. |
| **D4** | **Main-window identity is session-scoped** (@State UUID; window restoration re-mints, so a restored tool window's binding falls back per D3 on first use). Acceptable, or should identity survive relaunch (requires value-based main WindowGroup — invasive)? | **Session-scoped.** Restoration re-mints everything anyway; D3 covers the first post-restore click. |
| **D5** | **iPadOS multi-window parity** (Stage Manager has analogous surfaces) — in scope now? | **macOS only now.** Port the provenance model to iPadOS as a follow-up once macOS proves out. |

## 9. Verification checklist (owner's visual pass, post-implementation)

1. Main window A → ⌘F search → click results → each opens in A; **glance at another document
   window mid-stream** → next result still opens in A (the FM-A killer).
2. A → rail Graph tile → "View Document" in the graph → opens in A. Same from corpus browser.
3. File ▸ New Window (⌘N) → B → search from B → results open in B (not A — per-instance identity).
4. Search context menu → Open in New Window → C; C's rail → Related → row click → opens in **C**.
5. Close A with its search window still open → click a result → falls back per D3, never a dead click.
6. Two document windows on different documents → Sources tile in the *older* one → opens *its own*
   source note (leak fix).
7. Standalone document window, main closed → person detail → Find all mentions → Search window
   actually opens (relay fix).
8. History menu with only tool windows open → document opens per D3 (no silent drop).

## 10. Phasing

Two PRs, both fully green independently:

- **PR 1 — mechanism:** `DocumentHostID.main(UUID)` + registry + environment key +
  `openDocument(from:)`/`bindTool` + `HostWindowAccessor` + consumers hardened (live-state guard,
  fronting, drain) + `WindowRoutingTests`. The old translation path stays functional for
  not-yet-migrated producers (compat shim: unmigrated `pendingBrowseDocument` writes translate
  through the fallback chain instead of `activeDocumentHost`).
- **PR 2 — migration + deletion:** all producers/launchers converted (§5), relays deleted, the
  legacy shim + its host observers deleted, adjacent bugs (§6), scene-table doc fix, memory +
  manuals updated. Also (PR-1 review): widen `DocumentWindowID`'s non-identity payload
  (documentNumber/dateline/sourceNote/isEditorialNote as optionals, the `GraphWindowRequest`
  pattern) so D3-minted windows don't render a thinner document than routed opens.

**PR-1 review folds (2026-07-18):** the Coordinator's one-shot willClose token became stored
`nonisolated(unsafe)` state removed in-handler (3 strict-concurrency warnings + an
observer→block→box retain cycle); both hosts drain `pendingBrowseDocument` on appear (a
zero-host click now lands when the next host mounts, per the iOS BrowserView discipline);
`unregisterHost` re-resolves an in-flight route addressed to the closing host (fallback, else
demote to pending — FM-F's consumption gap); consumers deminiaturize before fronting
(`makeKeyAndOrderFront`/`openWindow(value:)` don't restore docked windows); registry-side
`#if DEBUG` prints replace the deleted #392 instrumentation for the owner's visual pass.
