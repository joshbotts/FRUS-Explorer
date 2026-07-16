# #241 — Window-Based UI on iPad: Investigation

**Session:** R (deferred from the 233–243 wave; carried forward per the 2026-07-11 issue comment)
**Date:** 2026-07-15
**Status:** Investigation complete; the ArchivalNeighbors prototype landed the same day (§5.1's
recipe, executed — the scene is shared via `archivalNeighborsScene`, the 4 call sites are gated, the
3 iOS scenes have `.defaultSize`, and the §2 census replaced the stale in-file table). Follow-ups
filed: #316 (`activeTab` mirroring), #317 (pending-state scenes restore empty). Verified: both
schemes build, iPad launch smoke check passes. **Not yet verified — the review's job (§7):** the
window-open interaction end-to-end, which needs indexed data to reach a neighbors action.
**Method note:** Every scene count, availability claim, and state-flow claim in this document was
derived from the code or the installed SDK at `v2` tip `e2d970b` — not from planning docs or commit
messages. Where a prior document disagrees with the code, the code-derived number is given and the
stale source is named. (Process rule adopted 2026-07-15 after three confidently-recorded claims in
this repo failed execution; see `MainTabView` version history 1.11 for one of them.)

---

## 1. The question, answered

> *"Investigate feasibility and implications of making iPad app window-based by default. Where are
> platform-inherent gaps between current Mac implementation and potential iPad
> functionality/interface?"*

**Verdict: do not make the iPad app window-based by default.** That is the XL path, and it is
blocked by three structural facts (§4), the largest of which — the forked reading surface — is not a
windowing problem at all and would have to be solved first for unrelated reasons. **The right shape
is the incremental path**: keep `MainTabView` as the iPad root, and port individual macOS auxiliary
windows to iPad as **value-based `WindowGroup` scenes** where a window genuinely beats a sheet
(comparison workflows, reference panels users park beside reading). The app already has
`UIApplicationSupportsMultipleScenes = YES` (`project.yml:100`) and three working iPad aux scenes;
this path extends a pattern that exists rather than importing an architecture that doesn't.

The two decisions that follow from this verdict:

1. **Prototype** (2026-07-16): convert **ArchivalNeighbors** — the best candidate by construction
   (§5.2) — as the template PR. `CrossVolumeProvenance` is the natural second (identical pattern)
   but is a **stretch goal, not a commitment**: the Session R block (`Issues-233-243-Plan.md:252`)
   names only ArchivalNeighbors; the week plan's "2 scene conversions" phrasing overstated it.
2. **File, don't fix** the two latent bugs found during this investigation (§6). Both predate #241
   and are reachable today; neither is a windowing-port prerequisite.

---

## 2. Scene inventory (code-derived)

Source of truth: `FRUSExplorer/App/FRUSExplorerApp.swift`, scene body lines ~408–821, read at
`e2d970b`. The doc-comment table at lines 56–72 of that file is **incomplete** (missing WordCloud,
Chronology, Research, NoteComposer, ResearchGuide, Settings) and the 233–243 plan's "~17 macOS
scenes" **undercounts**; the tables below are the authoritative census and the prototype PR should
refresh the in-file table to match (Session R block item 4).

### 2.1 Shared

| Scene | Kind | Notes |
|---|---|---|
| Main window (`:826`) | `WindowGroup` | Onboarding → `MainTabView` (iOS) / `MainWindowView` (macOS). macOS-only `.defaultSize(1200×800)` at `:887` |

### 2.2 iOS auxiliary scenes (3) — `#if os(iOS)` region `:410–524`

| Scene | Kind | State source | `.defaultSize` |
|---|---|---|---|
| Document windows (`:417`) | `WindowGroup(for: DocumentWindowID.self)` | Value-based (Codable payload) | **none** |
| Source Explorer `frus.sourceExplorer.ios` (`:449`) | `WindowGroup(id:)` | **Pending-state**: `appState.currentSourceNote` + 5 sibling fields (`AppState.swift:665–675`) | **none** |
| Cross-Reference Graph `frus.crossReferenceGraph.ios` (`:492`) | `WindowGroup(id:)` | **Pending-state**: `appState.currentGraphEntry` | **none** |

Zero `.defaultSize` in the entire iOS region — all 19 code occurrences are inside
`#if os(macOS)`: 18 on auxiliary scenes plus the main window's macOS-only `.defaultSize(1200×800)`.
*(Count corrected by the 2026-07-15 review; the original said "19 auxiliary".)* `.defaultSize` **is** honored on iPadOS 26 for new windows in
Stage Manager; adding sensible defaults to the 3 iOS scenes is a Session R block item and rides in
the prototype PR.

### 2.3 macOS auxiliary scenes (21) — `#if os(macOS)` region `:525–821`

| # | Scene | Kind | Line |
|---|---|---|---|
| 1 | Document windows | `WindowGroup(for: DocumentWindowID.self)` | `:534` |
| 2 | Search | `Window` | `:551` |
| 3 | Citation Lookup | `Window` | `:569` |
| 4 | Corpus Browser | `Window` | `:579` |
| 5 | People | `Window` | `:597` |
| 6 | Cross-Reference Graph | `Window` | `:606` |
| 7 | Source Explorer | `Window` | `:617` |
| 8 | Archival Neighbors | `WindowGroup(for: ArchivalNeighborsRequest.self)` | `:638` |
| 9 | Cross-Volume Provenance | `WindowGroup(for: CrossVolumeProvenanceRequest.self)` | `:669` |
| 10 | Corpus Analytics | `Window` | `:691` |
| 11 | Person Analytics | `Window` | `:703` |
| 12 | Cross-Reference Analytics | `Window` | `:716` |
| 13 | Word Cloud | `Window` | `:724` |
| 14 | Chronology | `Window` | `:733` |
| 15 | Research | `Window` | `:742` |
| 16 | Collections | `Window` | `:752` |
| 17 | Note Composer | `Window` | `:770` |
| 18 | History | `Window` | `:785` |
| 19 | Settings | `Settings` | `:794` |
| 20 | About | `Window` | `:801` |
| 21 | Research Guide | `Window` | `:815` |

**Census: 17 singleton `Window` scenes + 3 `WindowGroup`s + `Settings` = 21 macOS aux scenes vs 3
on iOS.** The gap #241 asks about is therefore 18 scenes wide at most — but §5.3 argues most should
never port.

---

## 3. Platform capability gaps (SDK-verified)

Checked directly against the **iPhoneOS 26.5 SDK** swiftinterface
(`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface`), not against documentation or recall:

| Capability | iOS status | Consequence |
|---|---|---|
| `SwiftUI.Window` (singleton scene) | **`@available(iOS, unavailable)`** (macOS 13 + visionOS 26 only) | None of the 17 macOS singleton `Window` scenes can port as-is. Every iPad port becomes a `WindowGroup` — value-based where a Codable request exists, `id:`-based otherwise — with single-instance semantics hand-rolled if needed. This is the single most consequential platform fact for #241. |
| `navigationSubtitle` | **`@available(iOS 26.0, macCatalyst 14.0, macOS 11.0, *)`** | At our iOS 26 deployment target, `ArchivalNeighborsWindowView` (which uses `.navigationSubtitle` at `ArchivalNeighborsSheet.swift:~637`) compiles on iOS **unchanged**. The prototype does not need a chrome rewrite. |
| `Settings` scene | macOS-only | iPad settings stay in the Settings tab (already the case). |
| `.defaultSize` | Honored on iPadOS 26 (Stage Manager) | Add to the 3 iOS scenes in the prototype PR. |
| Menu bar / `.commands` on iPad | iPadOS 26 shows the system menu bar; `.commands` participates | Out of scope for Session R (backlog item from the wave plan). Do not rabbit-hole here — this table's method (swiftinterface check) settles such questions in minutes when they actually matter. |

**Composition constraint carried from #238** (owner comment on #241): a tab under
`.sidebarAdaptable` hosts a `NavigationStack`, never a `NavigationSplitView` (`MainTabView`
version-history 1.9–1.11 is the authoritative ledger — note 1.11's correction; the copy in
`BigPicture-iPadMacParity.md` was retired 2026-07-15). This rule barely constrains Session R's
actual work: **aux `WindowGroup` scenes are siblings of the TabView, not nested inside it**, so
window content composes navigation freely (each iOS aux scene already wraps content in its own
`NavigationStack`). The rule matters only if a port tries to reuse a macOS window view that
internally builds a `NavigationSplitView` *and* that view is ever re-hosted inside the tab tree —
which no Session R work does.

---

## 4. Why "window-based by default" is blocked (the XL path)

Three structural facts, in decreasing order of cost:

### 4.1 The reading surface is forked — but the fork is NOT the gate
*(Corrected by the 2026-07-15 Fable review, which measured the fork instead of accepting this
section's original "this is the blocker" claim. The verdict stands; this argument's weighting did
not.)*

The macOS window world is anchored by `MainWindowView` + `MacDocumentView`; iPad reads through
`MainTabView` + `DocumentView` — parallel implementations, the same fork pattern as Settings and
Search. **However, measured:** the fork is ~3.9k lines of *platform chrome* (`DocumentView` 2,819 +
`MacDocumentView` 1,123 + `MainWindowView` 408; exactly 6 duplicated interaction handlers) over a
**fully shared ~6.7k-line engine** (`DocumentViewModel`, the TEI parser/AST/converter,
`FRUSDocumentWebView` — both views render through the same pipeline). And the decisive fact: **the
iPad already hosts the iOS `DocumentView` inside a window scene today** (the `DocumentWindowID`
`WindowGroup`), so window-hosted reading on iPad needs zero reading-surface work. The fork blocks
**Mac-parity window UX** — it does not block window-based-by-default. Do NOT schedule
DocumentView/MacDocumentView unification as a windowing prerequisite; it is not one.

The honest gate this section originally failed to state is **dual-root retention**:
`supportsMultipleWindows` is runtime-variable (false on iPhone; plist-derived and mode-dependent on
iPad — see §5.1's caveat), and `openWindow` is a no-op where it is false, so `MainTabView` must be
retained as the root *regardless*. "Window-based by default" therefore collapses into the
incremental path plus a root swap that buys nothing — which, together with §4.2/§4.3, is why the
verdict holds even with 4.1's original overstatement removed.

### 4.2 Two aux scenes restore empty by design
`frus.sourceExplorer.ios` and `frus.crossReferenceGraph.ios` render from **process-global pending
state** (`appState.currentSourceNote` cluster, `appState.currentGraphEntry`) set moments before
`openWindow(id:)`. After a relaunch, SwiftUI restores the scene but the pending state is gone → the
window shows its `ContentUnavailableView` placeholder (`FRUSExplorerApp.swift:449–524`, both `else`
branches). A window-first iPad lives or dies on state restoration; converting these to value-based
`WindowGroup(for:)` requests means encapsulating ~6 parallel `AppState` fields into a Codable
request type **per scene**. Tractable, but each is its own change with its own regression surface —
which is why they are **filed as follow-ups, not pulled into the prototype** (§6.2).

### 4.3 Window-identity state is process-global
There is **zero `@SceneStorage` in the app** (grep: 0 hits) and `activeTab` is a process-global
`@Observable` property persisted to `UserDefaults` (`AppState.swift:1125–1134`), bound directly by
`TabView(selection: $appState.activeTab)` (`MainTabView.swift:74`). Consequence, reachable **today**
(§6.1): two main windows mirror each other's tab selection. A window-based-by-default iPad
multiplies every such process-global assumption (`pendingBrowseDocument`, `pendingWordCloud`,
`pendingAnalytics`, …) into a visible bug class. The incremental path meets these one at a time,
value-based scenes first, which sidesteps most of them by construction.

**Sizing:** full adoption = XL — gated on **state routing (§4.2/§4.3: 13 process-global
`pendingX`/`currentX` hand-off fields) + dual-root retention (§4.1)**, not on unifying the reading
surface; incremental = L spread across waves, each port S–M. Session R buys the template and the
census. *(The 2026-07-15 review's steelman: 2–3 sessions of #316+#317 work make multiple windows
CORRECT, but cannot make them the DEFAULT — the runtime-variable gate forces the tab root to stay.
L-vs-XL survives the steelman; the original "gated on unifying the reading surface" did not.)*

---

## 5. The incremental path

### 5.1 Conversion recipe (what the prototype instantiates)

For a macOS window view backed by a **Codable request type**:

1. Move the window view out of the `#if os(macOS)` region (`ArchivalNeighborsWindowView` lives at
   `ArchivalNeighborsSheet.swift:594–640`); it renders shared content
   (`ArchivalNeighborsContent`) under title/subtitle/min-frame chrome — all iOS-26-compatible (§3).
2. Declare the scene for both platforms: the `WindowGroup(for: ArchivalNeighborsRequest.self)` at
   `FRUSExplorerApp.swift:638` moves (or is mirrored) outside the macOS region; iPad wraps content
   in `NavigationStack` for nav-bar chrome, exactly as the `DocumentWindowID` iOS scene does at
   `:422`.
3. Gate call sites on `supportsMultipleWindows`, existing sheet as fallback. **FIVE iOS call-site
   files, not the four originally claimed** — the 2026-07-15 review caught `VolumeSourcesView`'s
   volume-source trigger, which the original grep missed because its sheet presentation is hoisted
   to `CompilationView`, so grepping for sheet *presentations* undercounts *triggers*. (Gated in
   the review-remediation pass.) Two caveats the review added: `supportsMultipleWindows` is
   **plist-derived, not strictly "Stage Manager"** — on an iPad in Full Screen Apps mode it may
   still be true, making the "parked window" a full-screen scene (reasoned, not yet run; probe
   filed) — and a gate must only be added where the target **scene exists on iOS**: gating the
   Cross-Volume Provenance trigger before porting its scene would make `openWindow` a silent no-op.
4. `.defaultSize` on the new scene + the 3 existing iOS scenes.
5. Refresh the stale scene table in `FRUSExplorerApp.swift:56–72` (§2 census).

No pending-state work: `ArchivalNeighborsRequest` is `Codable + Hashable + Sendable`
(`ArchivalNeighborsSheet.swift:75`) and **reconstructs its own fetch from the payload** — its doc
comment says outright that no `currentSourceNote`-style hand-off is needed. Restoration correctness
is free.

### 5.2 Why ArchivalNeighbors first
It is the only macOS aux window that is simultaneously (a) value-based already, (b) rendering
shared cross-platform content, (c) chrome-compatible with iOS 26 as-is, and (d) genuinely useful
parked beside a document (comparing archival context across sources). It is the **existence proof**
with the smallest possible diff — which is what Thursday's Fable review should be reviewing.

### 5.3 Candidate ranking for future waves (do NOT batch-port)

*(Retiered by the 2026-07-15 Fable review: the original "never" tier contradicted the app's own
recorded design rationales for two scenes, and this table is declared authoritative — a future wave
consuming a wrong "never" would permanently skip ports whose value the codebase itself documents.)*

| Tier | Scenes | Rationale |
|---|---|---|
| Ride-along next | Cross-Volume Provenance | Identical value-based pattern; sibling window view in the same macOS region; iOS sheet in `VolumeSourcesView`. Stretch goal for the prototype PR only if it lands with zero friction. |
| High value, needs request-type work | Source Explorer, Cross-Reference Graph (the two pending-state scenes); **Citation Lookup**; **Note Composer** | Real research value in parked windows. The first two need Codable request refactors (§6.2). Citation Lookup's own macOS scene comment states §1's port criterion verbatim — "parsed matches stay around while the researcher reads documents" (⌘⇧F sibling of Search). Note Composer's states the window exists because "the modal sheets this replaces covered the passage the user was writing about" — a problem iPad still has today (notes are `DocumentSheet.noteEditor` sheets over the document); `NoteComposerRequest` is `Hashable` but not `Codable`, hence request-type work. |
| Questionable | Word Cloud, Chronology, Analytics windows; Search | Sheets/tabs serve these fine on iPad; port only on demonstrated demand. Search moved down from "never": post-#316, a second main window on the Search tab supplies a parked search surface without a port, and `SearchView` already spawns per-document windows from results — contestable but defensible either way. |
| Never | Collections, Research, People, Corpus Browser, History, About, Research Guide, Settings | Tab-owned surfaces on iPad (porting would duplicate the tab UX), or trivial modals. |

The XL-path cost sub-argument this table used to carry ("window-based by default would drag all of
these along") is **weakened but not needed**: dragging Citation Lookup and Note Composer along
would be value, not dead cost — the XL path fails on §4's architectural gates independently.

### 5.4 Verification bar for the prototype
Cross-platform compile (both schemes) + one window-open smoke check on the iPad simulator.
Exhaustive Stage-Manager QA is explicitly **out** (simulator computer-use driving is slow;
`env_simulator_ui_verification`); the follow-up issue for deeper multi-window QA rides with the
census issue (§6.3).

---

## 6. Latent findings — file as issues, keep out of the PR

*(Both filed 2026-07-15: §6.1 → **#316**, §6.2 → **#317**.)*

### 6.1 `activeTab` mirroring across iPad main windows (bug, user-reachable today)
With `UIApplicationSupportsMultipleScenes = YES`, a second main window (App Exposé / Stage Manager)
shares `appState.activeTab` — switch tabs in one window and the other follows, because selection is
process-global and UserDefaults-persisted (`AppState.swift:1125–1134`, `MainTabView.swift:74`; zero
`@SceneStorage` anywhere). Fix direction: per-window `@SceneStorage`-backed selection that seeds
from (and writes through to) the persisted default. **Not fixed here** — it predates #241, needs
its own regression thinking (the `pendingX` hand-offs consult `activeTab`), and the fix touches the
tab root during the same week other work lands there.

### 6.2 Pending-state scenes restore empty (design gap)
§4.2. Two follow-ups, one per scene, each: introduce a Codable request type encapsulating the
hand-off fields (`currentSourceNote` cluster is ~6 fields), convert the scene to
`WindowGroup(for:)`, delete the `AppState` fields. Sequenced *after* the ArchivalNeighbors template
proves the pattern in review.

### 6.3 Stale scene documentation
The `FRUSExplorerApp.swift:56–72` table (fixed in the prototype PR) and the "~17 scenes" figure in
the wave plan (superseded by §2's census — this document is now the authority).

---

## 7. What Thursday's Fable review should attack

1. **The verdict itself** (§1/§4): is "incremental, not window-based-by-default" actually right, or
   does it under-weight where iPadOS is going? Attack the XL-path cost claims — especially whether
   the reading-surface fork is as load-bearing as claimed.
2. **The recipe** (§5.1): does the `supportsMultipleWindows` gate + sheet fallback degrade correctly
   on iPhone, on iPads without Stage Manager, and in Split View? Is mirroring the scene declaration
   outside `#if os(macOS)` the right move vs a parallel iOS scene?
3. **Restoration claim** (§5.1 step 5): "restoration correctness is free" for value-based scenes —
   verify against the prototype by killing and relaunching, not by reading the doc comment.
4. **The ranking** (§5.3): are the "never" tier calls defensible, or does any tab-owned surface have
   a legitimate parked-window use the census missed?
5. **Grading rule** (standing, this week): claims about runtime behavior count only if the reviewer
   ran them. This document's §2–§4 claims are code/SDK-derived and citable; §5's degradation claims
   become testable only once the prototype exists — grade them there.
