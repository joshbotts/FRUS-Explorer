# FRUS Explorer macOS UI — Adversarial Review Against the Serious-Research-Instrument Bar

**Date:** 2026-08-13 · **Version:** 1.1 — §7 Semantic Analytics addendum added 2026-08-14 · **Status:** review for owner + fix worklist (Claude Code-consumable).
Companion to `../iPad-UI/iPad-UI-Adversarial-Review.md` (2026-08-13); two findings are shared defects and say so.
Figures: `Docs/screenshots/macos/*.png` — annotated versions in `Mac-UI-Adversarial-Review.html` (self-contained, this folder).

**The bar this review applies:** macOS is this app's flagship — the platform the iPad review's own bar
("the macOS-like layout researchers expect") points at. So the bar here is higher: a professional
research instrument that behaves like first-class Mac software — window discipline, typography, system
conventions, text scaling — under sustained, multi-window, multi-project use. Every claim cites
file:line at branch `v2` (tree `29ad7485`, read 2026-08-13).

**Inputs:** full read of the macOS shell and window roots (`MainWindowView`, `MacDocumentView` +
`MacDocumentWindowView` + find bar, `SearchSheet`/`MacSearchWindowView`, `MacCorpusBrowserWindow`,
`FRUSSettingsView`, `MacCollectionManagerView`, `MacSourceExplorerView`, `MacVolumesStorageHub`,
`HistoryWindowView`, `StatusBarView` in `SupportingViews`, the `FRUSExplorerApp` scene table and
`.commands` region); the committed macOS screenshots; `Docs/screenshots/README.md`;
`Planning/Dynamic-Type-Worklist.md`; the shared reader pipeline (`HTMLTemplate`, `FRUSTheme`).

---

## 1. Verdict up front

The Mac app is the serious platform, and mostly earns it: a complete menu-bar command system, honest
result counting, native inspectors, restorable value-based windows, a find bar, provenance-routed tool
windows. The failures are of a different species than the iPad's — not "phone app stretched" but
**professional-app debts under sustained use**:

1. **The window model taxes the researcher it serves.** Twenty-three scenes, and the app's own
   2026-08 navigation audit measured the cost: 11 of 56 window-open sites failed to front an
   existing window — including seven of the nine main-window toolbar launchers. Worse, the
   per-document tools (Source Explorer, cross-reference graph, word cloud) are app **singletons**:
   open two documents and they fight over one tool window — a fight the code twice patched
   (§6.1 leak, #369 BUG-8) without fixing the shape. (M-1…M-3)
2. **The workhorse windows are hand-rolled, fixed-point chrome.** The Search window has no toolbar
   at all — by its own comment, "verified, zero occurrences" — but a dense strip of ten icon-only
   9–13 pt controls whose only explanations are hover tooltips; 262 of the Dynamic-Type worklist's
   346 fixed-size sites are deferred macOS chrome the worklist itself rules "not exempt."
   (M-4…M-6)
3. **The reader still has no measure, and paper is unreachable.** The same no-max-width CSS the
   iPad review flagged renders ~150-character lines at the default 1200 pt window and ~300 at full
   screen on a 27″ display. And a documents app for historians — a paper discipline — **cannot
   print**: `CommandGroup(replacing: .printItem) { }` deletes Print, ⌘P is Project Home, ⌘S is
   Search. (M-7, M-14)

Alongside: a search-scope chip that is wired to nothing and admits it only in a tooltip, a Sync
Error state whose only detail is a hover, result rows that double-number and leak archival source
notes into titles (shared with iPad), and a user manual illustrated with retired chrome.

## 2. What the review confirms is working

Credit first — much of this app is what good Mac software looks like:

- **The menu-bar command system is exemplary.** Document / Find / Collection / Analytics / Research
  menus routed through focused-scene values so items enable exactly when their window is key;
  single-owner key equivalents enforced in comments (#363); a real ⌘F in-document find bar
  (`DocumentFindBar`, `MacDocumentView:1388`); `TextFormattingCommands` wired because the rich-text
  editor's ⌘B/I/U were dead without them (ui-audit #2).
- **Count honesty is best-in-class.** The Search sort bar distinguishes loaded vs. true uncapped
  totals, says "total unavailable" rather than faking it, drops both figures inside a capped
  working corpus because neither is the right denominator (`SearchSheet:1240-1285`, #607 parity),
  and the over-cap warning explains how to narrow.
- **Facets are a native trailing `.inspector`** on the Search window (`SearchSheet:361`) — exactly
  the container the iPad review asks that platform to adopt.
- **The value-based window scenes are the right architecture** — Archival Neighbors, Related
  Documents, Cross-Volume Provenance, Note Composer, Project Home all restore by construction
  (#317/#363), and `bringMacWindowToFront` + the 2026-08 navigation audit turned window-fronting
  from folklore into a checked rule (`MainWindowView:534-536`).
- **The reader's rail is thoughtfully engineered:** side-by-side ≥ ~900 pt, floating overlay with a
  close control below that so the document never reflows under a reading floor
  (`MacDocumentView:361-388`); toggling the rail drops the stranded selection bar (C1b F4).
- **The status bar reports background work properly** — indexed count, task + ETA, queue popover
  with a "learn while you wait" door (`SupportingViews:250-360,679+`).
- **Settings was modernized end-to-end** (S-pass): shared `SettingsPane` model with a coverage
  assertion so the two platforms' Settings cannot drift (`FRUSSettingsView:85-101`), native grouped
  Forms replacing hand-rolled card stacks.
- **The empty main window offers Resume** (#754, `DocumentPlaceholderView`) rather than a dead
  placeholder.

---

## 3. Findings

**16 findings: High ×5, Medium ×7, Low ×4.** Ordered within themes.

### A. The window model taxes the researcher

#### M-1 · HIGH — Twenty-three scenes, and the management tax is measured, not hypothetical

The scene inventory (`FRUSExplorerApp.swift:77-104`): 17 singleton `Window`s, 4 value-based
`WindowGroup`s, a `Settings` scene, plus the main window. Browse, Search, Research, Collections,
History, five analytics surfaces, Source Explorer, graph, word cloud, guide, About — each a
separate window. The app's own 2026-08 navigation audit found **11 of 56** open-window sites
unpaired with fronting — "including seven of the nine main-window toolbar launchers"
(`MainWindowView:534-536` doc) — meaning for months the primary toolbar's buttons could silently do
nothing while the target window sat buried. The helper + audit culture now exists (credit), but an
architecture that needs a 56-site audit to stay honest is charging the user (and the maintainer)
rent. The window model itself is defensible Mac design; the singleton choices inside it (M-2, M-3)
are where it breaks.

#### M-2 · HIGH — Per-document tools are app singletons; two documents fight over one window

`frus.sourceExplorer`, `frus.crossReferenceGraph`, and `frus.wordcloud` are singleton `Window`
scenes fed by process-global `AppState` fields (`currentSourceNote*`, `currentGraphEntry`). With
two document windows open — the exact workflow native tabbing (`WindowGroup(for:
DocumentWindowID.self)`, "native tabbing") invites — the tools cross-wire: the rail's own doc
comment records that "with two document windows open, the older window's tile used to open the
newer document's note" (`ResearchRailView.openSources`, §6.1 leak fix), and #369 BUG-8 added a
snapshot signal so the Source Explorer "can't be flickered by another window's `loadDocument`."
Both are patches on the wrong shape. The repo already owns the right shape — value-based
`WindowGroup`s that mint a window per distinct request (Archival Neighbors, Related Documents) —
and simply hasn't applied it to the three oldest tools. Compare a graph for document A against
document B today: impossible; the second open replaces the first. (§6 MR-2.)

#### M-3 · MEDIUM — One Search window: result sets cannot be compared side by side

`frus.search` is a singleton (`FRUSExplorerApp.swift:83`). A researcher comparing "Berlin crisis
1958–60" against "Berlin crisis 1961–63" — the comparative shape the app's own working-corpora
feature exists for — gets one window and sequential recall via Saved Searches. Every document can
be multi-windowed; the surface that *produces* document sets cannot. (§6 MR-6.)

### B. Hand-rolled chrome and the fixed-point debt

#### M-4 · HIGH — The Search window has no toolbar and a strip of ten hover-explained icon toggles

By its own comment: "`MacSearchWindowView` has no `.toolbar` at all — verified, zero occurrences"
(`SearchSheet:355-360`). Everything lives in hand-rolled rows: the sort bar packs Facets,
Checklist, timeline, concordance, collocates, save-corpus, page size, and three hand-rolled sort
chips (`SearchSheet:1040-1237`) — most icon-only at 10–12 pt, `buttonStyle(.plain)`, differing
from their neighbors only by SF Symbol, with meaning delivered exclusively via `.help` hover text.
Three of the four "readings" toggles are mutually exclusive and hand-cleared against each other —
the control that wants to be one segmented picker (the shape iOS 1.18 already adopted) is five
separate buttons here. The window also opens at `minWidth: 640` where the same comment admits the
sort bar is already "dense … at minimum window width" (`SearchSheet:1089-1090`). This is the app's
most-used window rendered in its least-native chrome. (§6 MR-3.)

#### M-5 · MEDIUM — 262 deferred fixed-point text sites, concentrated exactly here

`Planning/Dynamic-Type-Worklist.md` converted the iOS-visible surfaces and deferred the macOS bulk
— `FRUSSettingsView` (145), `SupportingViews` (72), `SearchSheet` (45), plus `MacDocumentView` (8),
`HistoryWindowView` (6), `MainWindowView` (5) — while ruling that macOS text scaling makes them
"**not exempt**." The consequence is that the windows a researcher lives in (Search, status bar,
Settings) ignore the system text-size setting entirely, at 9–13 pt: the status bar is 11 pt
(`SupportingViews:290`), the collection manager ships a 9 pt grid micro-label (worklist,
MacCollectionManagerView row). The debt is recorded; it has no owner or wave. (§6 MR-4.)

#### M-6 · MEDIUM — Result rows double-number and leak source notes into titles (shared defect)

`MacSearchResultRow` renders a `"\(volumeId) · Doc \(documentNumber)"` chip directly above
`result.header` (`SearchSheet:1962-2003`) — and modern volumes' indexed headers begin with their
own number, so rows read "**Doc 92**" over "**92.** Memorandum of Conversation" (Fig 1 ②). The
Research window shows the same headers running into archival source notes — "376. Letter From
Secretary of State Rogers to Secretary of Commerce Stans **Source: National Archives, RG 59,
Central Files 1970–73, ORG 1 COM–STATE. No classification marking.**" (Fig 3 ②) — the identical
header-extraction defect the iPad review filed (its F-21). One indexing fix serves both platforms;
each platform's row render also needs the prefix-suppression guard. (§6 MR-7.)

### C. The reader

#### M-7 · HIGH — No maximum measure: ~150 characters per line at the default window, ~300 maximized

The shared reader CSS caps nothing: `.frus-document { padding: 24px 48px 48px; }` under the
comment "No max-width: the WKWebView fills the window and the user can resize freely"
(`HTMLTemplate.documentCSS`). The main window's `defaultSize` is 1200×800
(`FRUSExplorerApp.swift:1264`), so the out-of-box reading line with the rail closed is ~1100 pt ≈
150 characters; maximized on a 27″ display it passes 300 (Fig 2 ①). "The user can resize freely"
delegates typography to the user on every single document open. The fix is the same one line the
iPad review prices as its R-1 — one CSS change serves both platforms. (§6 MR-1.)

#### M-8 · LOW — The toolbar's principal item is a raw internal ID

The reading window's title bar centers a monospaced `frus1946v06/d475` token (Fig 2 ②;
`MacDocumentView:1220-1226` for the standalone window). The document's *title* is relegated to
`.help` hover. Useful to the maintainer, developer-speak to the reader; the volume's short name +
document number is the same information in human form. (§6 MR-8 rider.)

#### M-9 · MEDIUM — Read-mode document paging is invisible

In Read mode, prev/next navigation is hover-only edge chevrons (`edgeNavChevron`,
`MacDocumentView:867-894`, shown only while `!panelVisible`) plus the ⌘⌥↑/↓ menu commands; the
visible bottom volume bar renders only in Research mode at ≥900 pt (`MacDocumentView:556-560`).
So the mode named "Read" — the one for reading through a volume — has no persistent visible way
to turn the page. (The manual's `document.png` shows a bottom Doc 474/475/476 bar in Read mode:
that is the retired strip-era chrome, see M-12.) (§6 MR-8.)

### D. Dead controls, quiet failures, stale documentation

#### M-10 · MEDIUM — A search-scope chip wired to nothing, disclosed only on hover

The "Collections" scope chip sits in the Search window's "Search in" row as a live, toggleable
control; its tooltip reads "Search collection names and notes **(deferred — not yet wired)**"
(`SearchSheet:727-731`). A user who toggles it gets identical results and no explanation unless
they happen to hover. The repo's own honesty bar — no silent no-ops — says this chip either works,
is disabled with an inline reason, or does not ship. (§6 MR-3 rider.)

#### M-11 · MEDIUM — "Sync Error" is a passive label whose only detail is a tooltip

The status bar's failure state renders `Label("Sync Error", systemImage:
"exclamationmark.icloud").help(message)` (`SupportingViews:573-580`) — orange text, hover-only
detail, no action. The app *has* a sync diagnostics surface (`SyncDiagnosticsView`) and an
error-inspector pipeline (#188-C); the one place a failure is announced connects to neither. An
error state should be clickable: show the message, link the diagnostics. (§6 MR-9.)

#### M-12 · MEDIUM — The manual is illustrated with retired chrome

`Docs/screenshots/README.md` itself marks `collections.png` and `toolbar.png` **STALE — slated for
re-capture**, yet both still illustrate the manual; and `document.png` (Fig 2) shows the retired
research-strip era — strip row, Read-mode bottom doc bar — which the C1 rail redesign replaced,
unflagged by the README's otherwise meticulous staleness ledger. Same finding class as the iPad
review's F-24, half-recorded here (credit for the ledger; the debt is that it ships). (§6 MR-10.)

#### M-13 · LOW — The Research sidebar truncates user labels into ambiguity

Fig 3 ①: "Commer… 9" and "Commer… 9" — two tags, identical truncations, identical counts — and
"rightsizi… 2" twice, "COM Au…" twice across sections. Tail truncation + trailing count in a
narrow sidebar column makes the user's own vocabulary indistinguishable. Middle truncation, a
`.help` with the full name, or count-under-name layout all fix it. (§6 MR-10 rider.)

### E. System conventions and input

#### M-14 · HIGH — Printing is deleted, and two reserved shortcuts are repurposed

`CommandGroup(replacing: .printItem) { }` removes Print entirely — "the app implements no document
printing, and ⌘P is used for Research ▸ Project Home" (`FRUSExplorerApp.swift:1285-1289`, `:3036`);
⌘S — Save, everywhere on the platform — is Search (`Find` menu, `:1328-1337`). This is a
document-reading app for a paper discipline: historians print documents, mark them up, file them,
and hand them to students; the reading view offers no Print and no Export-as-PDF (collection export
exists; single-document paper does not — the WKWebView is one `printOperation` away). Repurposing
⌘P/⌘S also violates the HIG's reserved-shortcut guidance and every muscle memory the target user
has. Restore Print to ⌘P (reader + web view), move Project Home, and give Search a non-reserved
equivalent. (§6 MR-5.)

#### M-15 · LOW — The Research Guide is deliberately hidden from the Window menu

The guide window is value-based partly *so that* it stays off the Window menu (#363 #7,
`FRUSExplorerApp.swift:1042-1057` region), leaving Help ▸ FRUS Research Guide as its one menu door.
The iPad review's F-14 is the same content buried on that platform; on the Mac the burial is
lighter but deliberate. A Window-menu presence (or a Research-menu item) costs nothing. (§6 MR-10
rider.)

### F. Settings

#### M-16 · LOW — Settings has no search field, and the parity gap is recorded but unowned

The macOS Settings window ships no search field while iOS Settings does
(`Docs/screenshots/README.md` "Not to capture": "The macOS Settings window has no search field
(iOS only) … Both are real gaps, recorded in `Planning/Completed/Settings-Parity-Audit-2026-07-25.md`,
not things to shoot"). Thirteen panes across four groups is exactly the size where type-to-find
starts paying. The shared `SettingsPane` model already carries `matches(query)` for iOS — the Mac
sidebar just never calls it. (§6 MR-11.)

---

## 4. Assessment against the contexts

**Sustained multi-window use.** The heart of the Mac review: the value-based scenes, provenance
stamps, and per-window commands are built for it; the three singleton per-document tools (M-2), the
singleton Search (M-3), and the audit-measured fronting tax (M-1) are where it still creaks.

**Typography & display scale.** The reader has no measure at any window size (M-7) and the chrome
ignores macOS text scaling at 9–13 pt fixed (M-5). On a 27″ display both compound: 300-character
lines beside 11 pt status text.

**System conventions / HIG.** Menus, focused-value enablement, tooltips, inspectors: strong.
Reserved shortcuts and printing: violated outright (M-14). Icon-only control strips with hover-only
meaning (M-4) sit below the platform bar the rest of the app sets.

**Honesty (the repo's own bar).** Result counting is exemplary; the dead Collections chip (M-10),
the tooltip-only Sync Error (M-11), and the stale manual figures (M-12) are the three places the
surface says less than the app knows.

---

## 5. Recommendations, priced

Effort tags follow the repo convention (S/M/L). ⊘ = no tracker issue found. Ordered by
value-for-cost.

- **MR-1 (S) ⊘ — Give the reader a measure.** Identical change to the iPad review's R-1
  (`max-width` ~70ch + centered margins in `HTMLTemplate.documentCSS`); one CSS edit fixes both
  platforms. Verify the hover edge chevrons and floating selection bar against the new column.
- **MR-2 (M) ⊘ — De-singleton the per-document tools.** Convert Source Explorer, cross-reference
  graph, and word cloud to value-based `WindowGroup`s keyed by their request (the Archival
  Neighbors / Related Documents pattern, #317). Deletes the process-global `currentSourceNote*` /
  `currentGraphEntry` fields and the two recorded cross-window fights with them.
- **MR-3 (S–M) ⊘ — Re-chrome the Search window.** A real `.toolbar`; one segmented control for
  List / Timeline / Concordance / Collocates (the iOS 1.18 shape); a native `Picker` for sort; text
  labels or `Label`s at system sizes for the icon strip. Rider: the Collections scope chip is
  disabled-with-reason or removed until wired (M-10).
- **MR-4 (M–L) ⊘ — Schedule the macOS text-scaling pass.** The worklist's deferred 262 sites,
  file by file (FRUSSettingsView → SupportingViews → SearchSheet), using the conventions the
  worklist already wrote. This is the standing accessibility debt of the platform.
- **MR-5 (S) ⊘ — Restore paper.** Print/Export-PDF for the reading view (`WKWebView` print
  operation; the Session-146 print CSS hook already exists in `HTMLTemplate`), Print on ⌘P,
  Project Home to another equivalent, Search off ⌘S (e.g. ⌥⌘F). One session, large goodwill.
- **MR-6 (S) ⊘ — Allow multiple Search windows.** `WindowGroup` (with New Search Window in the
  Find menu) or an explicit owner decision recording why one window is the design.
- **MR-7 (S) ⊘ — The shared header fix.** File the header-extraction issue (numbers + "Source:"
  leak) once for both platforms; add the row-level prefix-suppression guard here as on iPad.
- **MR-8 (S) ⊘ — Read-mode paging + humane title.** A persistent minimal prev/next affordance in
  Read mode (the volume bar, slimmed, or the chevrons made visible-at-rest); replace the raw
  `volumeId/docId` principal token with volume short-name · Doc N (id stays in `.help`).
- **MR-9 (S) ⊘ — Make Sync Error actionable.** Click → popover with the message + "Open Sync
  Diagnostics"; keep the tooltip.
- **MR-10 (S) ⊘ — Documentation staleness sweep.** Re-capture `collections`/`toolbar`/`document`;
  add `document.png` to the README's stale ledger rule ("chrome retired ⇒ shot is stale"); fix the
  Research-sidebar truncation (middle-truncate + `.help`) while in the neighborhood (M-13).
- **MR-11 (S) ⊘ — Settings search parity.** Wire the existing `SettingsPane.matches(query)` into
  the Mac sidebar; closes the recorded parity gap (M-16). Rider: Window-menu (or Research-menu)
  entry for the guide (M-15).

**Sequencing.** Wave 1 (polish session): MR-1, MR-5, MR-7, MR-9, MR-11 — all S, two of them shared
with the iPad wave-1. Wave 2 (the windows session): MR-2 + MR-6. Wave 3 (the chrome session):
MR-3, MR-8, MR-10. MR-4 is its own scheduled program.

---

## 6. Worklist table (for tracker enrolment)

| # | Carries | Findings | Effort | Wave |
|---|---|---|---|---|
| W-1 | Reader measure (shared with iPad W-1) | M-7 | S | 1 |
| W-2 | Print / Export PDF + shortcut de-conflict | M-14 | S | 1 |
| W-3 | Shared header-extraction fix + row prefix guards | M-6 | S | 1 |
| W-4 | Sync Error click-through | M-11 | S | 1 |
| W-5 | Settings search field + guide menu presence | M-16, M-15 | S | 1 |
| W-6 | Value-based Source Explorer / graph / word cloud windows | M-2 | M | 2 |
| W-7 | Multi-window Search (or recorded decision) | M-3 | S | 2 |
| W-8 | Search-window chrome: toolbar, segmented readings, native sort, dead chip | M-4, M-10 | S–M | 3 |
| W-9 | Read-mode paging affordance + principal-item title | M-9, M-8 | S | 3 |
| W-10 | Screenshot/manual staleness sweep + sidebar truncation | M-12, M-13 | S | 3 |
| W-11 | macOS text-scaling program (262 sites, 3 files first) | M-5 | M–L | scheduled |
| W-12 | Window-fronting audit stays a standing gate (re-run per release) | M-1 | S | recurring |

---

## 7. Addendum (2026-08-14) — Semantic Analytics

**What shipped.** Build 37 adds a fifth analytics window: the whole corpus as one Metal-rendered map of
its own language — 314,483 documents at precomputed coordinates, four colour lenses, region labels,
tap-to-open, lasso → working-corpus capture, volume-pole axis slices, and the family's shared scope
bar. Opened from the main-window Analytics ▾ menu (`MainWindowView.swift:342-349`) and the menu bar
(`FRUSExplorerApp.swift:3009-3011`) into a singleton `Window` at 900×700 (`FRUSExplorerApp.swift:761-768`).
Claims cite branch `v2`, tree `46cde737`, read 2026-08-14. **6 new findings: High ×1, Medium ×3, Low ×2**;
recommendations MR-12…MR-16; worklist W-13…W-17. Shared-defect cross-references: slice scale (iPad F-26,
iPhone P-15), raw-ID selection card (iPad F-27, iPhone P-16), export absence (iPad F-28, iPhone P-17).

**Inputs:** full read of `SemanticAnalyticsView`, `SemanticMapSpikeView` (+ `SemanticMapModel`,
`SemanticMapSurface`), `SemanticMapLens`/`SemanticMapColouring`, `SemanticMapPicking`,
`SemanticMapLabels`, `SemanticAxis`, `BundledSemanticMap`, the three launchers, `SemanticVectorsKit`
(artifacts, retrieval kernel), the Related Documents semantic pipeline (`SemanticSimilarityGenerator`,
`SemanticSharedTerms`, `SemanticFeedbackLog`/`View`), manuals §13.8/§13.9, and
`Planning/Vector-Embeddings-Semantic-Design.md` + `Planning/OS27-Semantic-Retrieval-Design.md`.

### 7.1 What the addendum confirms is working

This surface ships the app's most disciplined honesty posture yet:

- **The window-not-sheet decision is measured and documented.** An `MTKView` in a SwiftUI sheet on
  macOS presents frames that never reach the screen; the scene comment records the reproduction and
  the standing rule ("Anything Metal-backed added to this app needs a window on macOS"). The iOS
  entry keeps its sheet because UIKit was verified unaffected — the difference is stated, not assumed.
- **Caveats collapse instead of disappearing.** v1.1 fixed the one-way door: the experimental header
  collapses to its orange warning and the warning is the restore button (`SemanticAnalyticsView`
  version note); the layout caveat ("distances between far regions are not meaningful") is permanent;
  a slice swaps in its own caveat naming both axes and the 256-bit basis.
- **Denominators everywhere.** The scope line reads "N mapped documents — whole volumes, X of 552"
  (re-worded when "every document" was wrong by ~2,356 rows); the lasso card states at capture how
  much of the enclosure this Mac can search — resolved by the same `WorkingCorpusResolver` that will
  resolve the corpus later, so the number shown is the number applied; truncation says "Saving the
  first 7,500 of N."
- **The dead-control history is owned.** The file names six controls that shipped drawing-but-doing-
  nothing and each now carries its guard: fronting on both launchers, administrations with no mapped
  volumes disabled-with-reason, a scope requested mid-load remembered and disclosed ("not applied
  yet"), the lens re-asserted after every re-layout.
- **Lens discipline.** A sequential ramp for the ordered era lens; categorical hues for provenance
  with the weakest category (`Other / Unclassified`, 55 volumes) deliberately dimmest; a ten-note
  evidence floor with the plurality caption; a lens the artifact cannot support withheld rather than
  drawn empty.
- The spike-era stats overlay is **DEBUG-gated**, and Open Document routes through `bindTool`
  provenance like every other tool window — the M-1 audit culture followed on day one.

### 7.2 Findings

#### M-17 · HIGH — Zoom is pinch-only: a mouse cannot zoom the map, and the menus contribute nothing

`MagnifyGesture` is the map's only zoom input (`SemanticMapSpikeView.swift:712-717`) — a trackpad
pinch. There is no scroll-wheel or Smart-Zoom handling on the `MTKView`, no ⌘+/⌘−/⌘0, no zoom
control in the window, no double-click. Pan-by-drag works with any pointer; zoom — the interaction
that turns 314,483 points into readable neighbourhoods, precise taps (a 22-pt finger radius,
`SemanticMapPicking.swift`), and drawable lassos — requires a gesture a Magic Mouse or third-party
mouse cannot make. On the platform this review opened by crediting for "a complete menu-bar command
system," the new window receives exactly one menu contribution: the item that opens it. No View
commands, no keyboard equivalents — the app's only fully gesture-dependent window. (MR-12.)

#### M-18 · MEDIUM — The slice is an unlabelled chart, and undated volumes plot silently at mid-axis

A slice lays out x = projection onto the chosen axis, y = each volume's coverage-midpoint year
(`SemanticMapModel.setSlice`) — and draws **no scale of any kind**: no year ticks, no gridlines, no
pole names at the plane's edges, no indication of which end is early. The entire semantics ride in a
two-line `.caption2` sentence below the map, which names the poles but not the direction of time.
Worse, `SemanticMapSpikeView.swift:519` plots any volume without a parseable coverage year at
`Float(0)` — the exact vertical centre, indistinguishable from a genuine mid-range midpoint. On the
surface whose header exists to say what is and is not a measurement, the slice draws unknown dates
*as* dates. (MR-13; shared — iPad F-26, iPhone P-15.)

#### M-19 · MEDIUM — The selection card leads with raw IDs and exports them into the opened window (shared class)

The card's headline is `"\(selection.volumeID) · \(selection.documentID)"` — `frus1969v12 · d45`
(`SemanticMapSpikeView.swift:1135`) — with the region below and no volume title, document number, or
date. Open Document then mints `header: "frus1969v12 — d45"` (`:1217`), so the opened window's
title inherits the developer-speak M-8 already flagged. The volume's *title* is one manifest lookup
away — the scope bar on the same screen already does it (`manifestStore.entry(forVolumeId:)?.title`).
The artifact genuinely carries no per-document titles, so the honest ceiling is "volume title ·
Doc id" until the volume is local — but the current card does not reach the ceiling. (MR-14.)

#### M-20 · MEDIUM — The one analytics window that cannot be exported

Manual §13.9's doctrine: "Every analytics chart can leave the app as a figure (PNG or PDF) or as the
data behind it (CSV)." The semantic map offers neither — no figure, no CSV, for the map, a scoped
map, or a slice; §13.9 does not even list it among its named exceptions. The lasso → working corpus
is the only exit, and it feeds Search, not paper. For the audience M-14 describes — a discipline
that publishes figures — the surface most likely to produce one is the one that cannot. Rider:
manual §13.8 ships `[SCREENSHOT: …]` placeholders on both platforms and `Docs/screenshots/` holds no
semantic capture at all — the M-12 staleness ledger never gained a row for the app's newest window.
(MR-15.)

#### M-21 · LOW — Region names are inert, and the artifact's own era data has no reader

The label layer draws region names with `.allowsHitTesting(false)` (`SemanticMapSpikeView.swift:1040-1049`)
— a name cannot be tapped, zoomed to, or asked anything. Meanwhile the bundled artifact carries
per-region `eraCounts` — in its own words "so a cluster tooltip can say *when* as well as *what*
without a second pass over the corpus" (`SemanticVectorsKit/SemanticMapArtifacts.swift:59-61`) —
shipped in every build and read by nothing. The promised tooltip was never built. (MR-16; the same
field is opportunity O-3 below.)

#### M-22 · LOW — A 24th singleton scene, and a map VoiceOver cannot enter

The window joins M-1's inventory as a singleton — more defensible than the per-document tools M-2
indicts, since the map is corpus-level like Corpus Analytics. But the manual's own framing ("the
comparison this surface is for") describes scope-vs-scope and axis-vs-axis work that a single
instance cannot show side by side — M-3's class, on a new surface. And the map is a Metal canvas
with no accessible children: VoiceOver reaches the surrounding controls and a named rectangle; the
ready-made `labelledClusters` list (name, in-scope count, centre) would back a region rotor/list
almost verbatim. (MR-16 rider.)

### 7.3 Recommendations, priced

- **MR-12 (S) ⊘ — Mac zoom inputs.** Scroll-wheel zoom on the `MTKView`, ⌘+/⌘−/⌘0 (`frameAll`) as
  window commands, double-click zoom-in. The camera plumbing (`model.zoom(by:)`, republished camera)
  already exists; this is input wiring, not architecture.
- **MR-13 (S) ⊘ — Scale the slice.** Year ticks along the vertical edge (the per-row years are
  already computed), pole names at the plane's left/right edges, and undated volumes to a marked
  gutter — or excluded with a stated count — rather than centre-plotted.
- **MR-14 (S) ⊘ — Humane selection card.** Volume title + document id as the headline, raw ids to
  secondary text; pass the same humane header to `openDocument` so the opened window is named for a
  reader. One manifest lookup, shared with iPad/iPhone.
- **MR-15 (S–M) ⊘ — Export parity per §13.9.** Figure (PNG/PDF) of the current viewport — points,
  labels, key, and the caveat line baked into the caption strip — and CSV for a lasso or slice
  (volume, document, projection/grid position, region). Rider: capture §13.8's placeholder
  screenshots while in the neighbourhood (joins W-10).
- **MR-16 (S, decision) ⊘ — Record the singleton decision** (or adopt `WindowGroup`); make region
  names tappable (zoom-to-region + an era breakdown from `eraCounts`); VoiceOver region list from
  `labelledClusters`.

### 7.4 Foundations worth reusing — the semantic substrate × the visualization family

The owner asked where these foundations could improve other visualization-based features. Six flags,
each grounded in shipped code; the design doc's own ranking is `Vector-Embeddings-Semantic-Design.md` §7.

- **O-1 · Result sets and corpora on the map.** `SemanticMapColouring.ScopeMask` is one byte per row,
  but today it is only built from volume sets (`scopeMask(volumeIDs:)`). A mask built from document
  keys is the same array via `index.row(documentID:volumeID:)` — any working corpus or capped search
  result set becomes a highlighted geography. Search already owns the hand-off shape ("Visualize in
  Corpus Analytics"), and the lasso already walks the other direction (map → corpus → Search
  filters). One mask constructor and one door close the loop: *where does my result set sit in the
  corpus's language?*
- **O-2 · A two-way bridge with Related Documents.** The semantic similarity axis ships on this same
  substrate (weight 0, experimental), and `SemanticRetrievalKernel`'s corpus scan is measured at
  1.43 ms. The selection card could offer "Similar documents" with zero volumes downloaded (Tier-1
  sign bits); Related Documents rows could offer "Show on map" (row → camera). Evidence chips are
  already built: `SemanticSharedTerms` names the shared distinctive vocabulary at render time.
- **O-3 · Region-share-over-time in Corpus Analytics.** The bundled artifact already carries
  per-region `eraCounts` (M-21) that nothing draws. Region × era stacked areas is the design doc's
  own §7.3 ("cheap: Tier 0 already carries cluster ids"), and Swift Charts is already in the
  analytics family. This is the highest value-per-effort flag here: the data ships today.
- **O-4 · Pre-1900 rescue for Related Documents and the graph.** The generator's own measurement:
  46,234 documents have an empty Related list, 98.2% of them pre-1900 — exactly where citations and
  archival keys do not reach. Semantic neighbours as an explicitly-labelled experimental section
  (never mixed into citation rankings — the code's own no-mixed-scales rule) would light the
  corpus's darkest region, and `SemanticFeedbackView`'s verdict loop already weights 19th-century
  judgements highest.
- **O-5 · The renderer as a house substrate for large-N figures.** On-demand Metal point rendering
  (dirty-mark draws, palette + per-row flags, pure-function camera/label layout, measured picking)
  is what the canvases this family struggles with lack: the force-directed graphs could adopt its
  LOD posture, and the iPhone review's hairline chronology (its P-4) is a density scatter this
  renderer draws for free. A session, not an afternoon — but the machinery is now in-tree and tested.
- **O-6 · Subseries poles.** The bundle carries 659 exact int8 centroids — volumes *and* subseries
  (`SemanticAxis` doc) — and the UI offers only volume poles via tapped documents. A subseries pole
  picker ("Vietnam volumes → NSC institutional volumes") is data-ready today; cluster poles are
  impossible by construction and free-text poles are correctly deferred (design §6.4).

### 7.5 Worklist additions

| # | Carries | Findings | Effort | Wave |
|---|---|---|---|---|
| W-13 | Mac zoom inputs (wheel, ⌘+/⌘−/⌘0, double-click) | M-17 | S | 1 |
| W-14 | Slice scale + undated gutter (shared: iPad W-13, iPhone W-12) | M-18 | S | 1 |
| W-15 | Humane selection card + open header (shared) | M-19 | S | 1 |
| W-16 | Map/slice/lasso export + §13.8 screenshot capture | M-20 | S–M | 2 |
| W-17 | Singleton decision · region tap affordance · VoiceOver region list | M-22, M-21 | S | 3 |

**Sequencing.** W-13…W-15 are one polish session with the existing wave 1. W-16 rides the export
conventions §13.9 already fixed. O-1…O-3 are the recommended first opportunities: two are mask/chart
work over shipped data; none blocks a finding fix.
