# macOS ⇄ iOS parity audit — 2026-07-25

**Scope:** every divergence between the two platforms' settings experiences and the surfaces they
point at, taken at `v2` HEAD (`21bdc37`, after S-5b and the Research Sessions pane).

**Method:** five parallel audits (tree shape, per-pane controls, copy, behaviour, reachability),
each finding then handed to an independent fact-checker instructed to refute it. 71 candidates,
**67 confirmed, 4 dismissed**; several confirmations carried corrections, which are folded in below.
Every line has been checked against source — but nothing here has been checked against a *running*
app, so the "what the user sees" claims are read from code, not observed.

**What the tree looks like now:** identical on both platforms except `.sync`, which is a pane on
macOS and an inline section at the top of the iOS root. That part of the North Star landed.

---

## A. Safety — destructive actions that differ

The two that matter most, because a slip is unrecoverable.

| # | Gap | Where |
|---|-----|-------|
| A1 | **macOS Free Up Space deletes without asking.** The "Remove N volumes" button calls `performRemoval()` directly; the sheet declares no confirmation state at all. iOS routes the same button through a `confirmationDialog` ("Remove these volumes? … Every one of these volumes can be downloaded again."). | `MacVolumesStorageHub.swift:1711` vs `VolumesStorageHubView.swift:1625` |
| A2 | **iOS deletes a Volume Scope on a full swipe, instantly.** `CustomScopesView` uses a bare `.onDelete`, which enables full-swipe by default — one uninterrupted gesture destroys a hand-curated volume set. macOS gives the same row a trash button behind a "Delete Scope?" dialog. | `CustomScopesView.swift:83` vs `FRUSSettingsView.swift:521` |

Worth noting what is *not* a gap: Tags and Projects have no row-level delete on macOS at all, and
both platforms share the same confirmed editor path for those. Only scopes are genuinely asymmetric.

---

## B. A capability one platform simply lacks

| # | Gap | Where |
|---|-----|-------|
| B1 | **macOS cannot cancel a download.** iOS renders an Active Downloads section with a per-transfer Cancel calling `cancelDownload(volumeId:)`. The macOS hub has no equivalent section. This is a UI omission, not a missing capability — `DownloadManager` and `BackgroundDownloadEngine` carry no platform fences. | `VolumesStorageHubView.swift:245`; absent from `MacVolumesStorageHub.swift` |
| B2 | **No History surface on iOS.** `HistoryWindowView` + `HistoryMenuContent` are inside `#if os(macOS)`, reached by the `frus.history` scene and the Research ▸ History menu. iOS has no view over `ReadingHistoryEntry`/`SearchHistoryEntry` — only Project Home's per-project recents, and only when a project is active. | `HistoryWindowView.swift:9`, `FRUSExplorerApp.swift:902` |
| B3 | **Search history is *written* only on macOS.** `SearchHistoryEntry` has exactly one producer, `MacSearchViewModel.recordSearchHistory`, called from the macOS-fenced `SearchSheet`. So even the Mac History window shows nothing you searched on the iPhone. A one-way gap, not a symmetric one. | `MacSearchViewModel.swift:749` |
| B4 | **macOS has no settings search.** iOS filters panes through `SettingsPane.matches(_:)`; that method has exactly **one caller in the whole app**, and `keywords` has none outside it and the tests. Fourteen keyword lists are green in the suite and unreachable from macOS. Traceable to the design handoff, which specified `.searchable` for iOS and never mentioned macOS. | `SettingsView.swift:98`; `FRUSSettingsView.swift:87` |
| B5 | **"Precompute word clouds in background" is inert on macOS.** The shared pane renders the toggle and a footer promising the work happens; both halves of the machinery — the enqueue (`AppState.swift:1140`) and the drain (`FRUSExplorerApp.swift:339`) — are inside `#if os(iOS)`. | `WordCloudSettingsView.swift:155` |
| B6 | **Sync Log "Copy to Clipboard" is iOS-only.** | `SyncDiagnosticsView.swift:52` |
| B7 | **`pendingSettingsPaneRaw` has no iOS consumer.** Nothing outside Settings can send an iOS user to a named pane; macOS uses it from menus. | `AppState.swift:903` |

---

## C. Copy that is wrong — not merely different

These matter for **S-6**: a docs pass would otherwise describe them as if correct.

| # | Gap | Where |
|---|-----|-------|
| C1 | **"Settings → NARA API" — that pane was deleted in S-4a** (folded into Connections). Four strings still say it. One is iOS-only; two are in `NARACatalogClient` and therefore **wrong on both platforms**. | `SourceExplorerView.swift:1100`, `NARACatalogClient.swift:51,60` |
| C2 | **iOS prints "State Dept. Central Files (RG RG-59)".** Shared key `source.explorer.centralFiles.typeValue`, two different `defaultValue`s — iOS interpolates "RG \(recordGroup)" where the value already contains "RG". macOS prints it correctly. | `SourceExplorerView.swift:444` vs `MacSourceExplorerView.swift:346` |
| C3 | **Zone-missing recovery names a control that exists on neither platform**, and a different wrong one on each: iOS says "tap Reset iCloud Sync below", macOS points at a "Danger Zone" group. The real path is System → Data & Recovery → Recovery → **Fix iCloud Sync**. | `SettingsView.swift:301`, `SupportingViews.swift:580` |
| C4 | **"Tags and scopes work the same way: tap a row to rename, merge or delete it."** False for scopes on both platforms (the scope editor has no merge and no delete), and doubly false on macOS, where scope rows are not clickable at all. | `FRUSSettingsView.swift:291`, `SettingsView.swift:741` |
| C5 | **macOS Research Sessions empty state** says "Open a document or run a search and it will appear here" — running a search never logs anything on macOS. Mine, from the pane I just shipped; the recording footer is correctly fenced but this one is not. | `ResearchSessionsView.swift:186` |
| C6 | **Shared Summarization footer** promises "Runs continue in the background if you allow it — set per run", a control macOS does not have. | `FRUSSettingsView.swift:836` |
| C7 | **`collections.empty.title` carries two mutually exclusive meanings** — "No Collection Selected" (macOS) and the genuinely-empty state (iOS) — under one key. | `MacCollectionManagerView.swift:225` |
| C8 | **Save Search sheet: label and placeholder are swapped** between platforms, under shared keys. | `SearchSheet.swift:372` |

Every one of C1–C8 is a same-key/two-text pair or a factual error. None is caught by any test, and
none would be caught by the compiler — no String Catalog ships, so each call site silently falls
through to its own `defaultValue`.

---

## D. The Mac explains itself less

A consistent, one-directional pattern: iOS puts guidance in visible text, macOS puts it in a
hover-only `.help()` tooltip or omits it.

- **D1** — Six Volumes & Storage actions are explained in visible text on iOS and hover tooltips on macOS, *with different sentences*. Two macOS buttons have no explanation at all. (`ControlHelp.swift:45` is the modifier: `.help(detail)` on macOS, `accessibilityHint` elsewhere.)
- **D2** — An index failure tells an iOS user what to click ("Try Index Remaining…"); it tells a Mac user to open **Console.app** and grep a subsystem. (`MacVolumesStorageHub.swift:559`)
- **D3** — A failed storage measurement is reported on iOS and silent on macOS. (`MacVolumesStorageHub.swift:819`)
- **D4** — Index Health and Check Integrity are explained on iOS, unexplained on macOS. (`MacVolumesStorageHub.swift:579`)
- **D5** — Advanced loses two explanatory footers on macOS.
- **D6** — …and one case in the other direction: the Free Up Space empty state names a concrete control on macOS and gestures vaguely on iOS, though iOS has the same control. (`VolumesStorageHubView.swift:1592`)

---

## E. Deliberate, and I'd leave them — with one exception

- **`.sync` as a macOS pane vs an iOS inline section.** Right idiom on each. **The exception:** the macOS pane shows *no live sync status at all* — iOS has seven states including three actionable failures (Local Only with the CloudKit diagnostic, Private Zone Missing, Account Issue). A Mac user gets the status-bar chip, which drops the relative timestamp and uses different labels, or a log summary one pane away. Passing `SyncSettingsSection { iCloudSyncStatusRow }` on macOS too would close it.
- **Projects → Related reaches Tags and Scopes differently.** macOS Settings contains zero `NavigationLink` — it is a sidebar architecture, so it re-selects the sidebar row; iOS pushes. A consequence of two correct architectures, not drift.
- **"Open Documents In" hidden on iPhone** (#404 — the rail is a user-triggered sheet there, so the setting has nothing to act on).
- **iOS keeps the indexing education sheet** macOS dropped — scoped to macOS on purpose by the 2026-07-04 UI audit (B7), documented in three places.
- **"OK" (macOS) vs "Done" (iOS)** on not-found alerts; the iOS DEBUG Diagnostics group.
- **Research-session search logging is iOS-only** — documented in the pane. Whether to close it is a live question: doing so starts collecting search text on a platform that currently does not.

---

## F. Developer-only

- `SettingsPlatform`'s doc comment — the stated rationale for the whole platform-split mechanism — describes a tree that has not existed for three sessions. (`SettingsPaneModel.swift:47`)
- Two dead `@AppStorage` properties on the iOS Settings root. (`SettingsView.swift:76`)
- The macOS standalone About window is constructed without `AppState` or the model container. (`FRUSExplorerApp.swift:924`)
- Four more shared-key/two-text pairs at accessibility and chart-label grain.
- Localization residue is concentrated in the older macOS-only windows (`SupportingViews.swift:1382`), not in any settings view — the settings surfaces are clean.
- A stale cross-platform pointer in `ResearchDataExportView`'s doc comment naming `SettingsDataPane`, deleted in S-4b.

---

## Suggested order

1. **A1, A2** — data loss, both one-evening fixes.
2. **C1–C8** — do these *before* S-6, or the docs pass will faithfully document errors.
3. **B1** — the Mac cannot stop a download it started; the capability is already there.
4. **B4** — one `matches(_:)` implementation already exists and is tested; only the macOS sidebar
   never calls it. Prototype first: `.searchable` on a `NavigationSplitView` sidebar is untried here,
   and there is a recorded caution about `.searchable` inside macOS sheets (different context, but
   worth a spike before promising a one-liner).
5. **E's exception** — the macOS Sync pane's missing status.
6. **B2/B3** — the History gap is the largest single "my Mac can do things my iPad cannot", and B3
   means it is under-populated even on the Mac. Its own session.
7. **D** — a copy pass, natural to fold into S-6.
