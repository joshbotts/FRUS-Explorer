# Handoff: Browse Axes (FRUS Explorer issue #1051)

## Overview
Design for extending FRUS Explorer's Browse tab (iOS/iPadOS) and Corpus Browser window (macOS) with up to seven additional browse axes — volume titles, publication year, administrations, editors, custom volume scopes, working corpora, semantic clusters — plus scope creation/editing UI. All axes are data-ready in the repo's bundled artifacts; this is pure interaction design. Basis: `uploads/BrowseAxesDesignRequirements.md` (the "#1051 requirements doc") and a survey of the shipped code.

**Target codebase: `joshbotts/FRUS-Explorer`, branch `v2` (SwiftUI, iOS/iPadOS 26 + macOS 26).** See `github.md` for the source association. Implement in the repo's existing patterns — this is an extension of shipped screens, not a greenfield app.

## About the Design Files
`Browse Axes Proposals.dc.html` is a **design reference created in HTML** — an annotated canvas of static mockups, not production code. The task is to **recreate these designs in the FRUS-Explorer SwiftUI codebase** using its established components and rulings (named per screen below). The `screenshots/` folder renders each cluster; the HTML canvas is the authoritative, zoomable copy with full annotation text.

Canvas ids (`1a`–`3c`) label each cluster; screenshots are named accordingly. Newest decisions are at the top of the canvas (turn 3 = scope editing, turn 2 = root variant, turn 1 = the main proposal set).

## Fidelity
**High-fidelity** for layout, hierarchy, copy, and component choice: recreate structure and wording exactly, using native SwiftUI controls (`List` `.insetGrouped` on iOS, `.inset`/sidebar on macOS) rather than copying CSS. All **counts/figures are illustrative** — real values come from the bundled artifacts at runtime. Colors/typography are stock iOS system styles (see Design Tokens); do not invent custom chrome.

## Decisions already made (owner-settled — do not re-open)
- **Q-1**: Editor index lists **compilers only**; general editors stay on the volume page. Alias table (~38 rows) normalizes spellings in the grouping layer only.
- **Q-2**: Administration membership = **volumeCount** (any dated document).
- **Q-8**: **Tag axis CUT** — Topics (shipped) is the subject-style axis. Canvas cluster 1k is kept struck-through for the record; do not build it.
- **Scopes**: Browse **may create and edit** custom volume scopes (owner call 2026-08-22, supersedes "Browse applies, never creates" for scopes). Working corpora (A-6) remain capture-only — list and open, never create.
- **Q-4**: Clusters axis designed now, **implemented only after** the build-42 semantic-map verdict.

## Decisions still open (present options, don't assume)
- **Q-9**: root direction — 1b flat doors / **1c hub (recommended)** / 1d search-first / 2a search-first with Subseries tile.
- **Q-7**: **1e one "All Volumes" catalogue (recommended)** vs 1f separate Title/Year doors.
- **Q-3**: scope application idiom — live reference (WordCloud pattern) vs membership copy (Search pattern). Pick one deliberately.
- **Q-6**: document counts via a `volumeTotals` accessor (recommended) vs populating manifest `documentCount`.
- **Q-5**: tag chips on subseries-less paths — push the subseries level with the filter applied (recommended) vs suppress chips.

## Screens / Views

### 1a — Baseline (already shipped; reference only)
Recreations of today's `CorpusView` (iOS) and `CorpusBrowserWindowView` (macOS) for comparison. Match the shipped code, not the screenshot.

### 1b / 1c / 1d / 2a — iOS corpus root directions (Q-9; build ONE)
All keep: `ResumeReadingRow` first; **People as the first cross-volume row (test-pinned)**; Topics second; rows are `Button`s mutating `navigationPath` (never `NavigationLink`); root doors call `vm.select(_:)` (path **assignment**, never append); subseries section below.
- **1b Flat doors**: one unnamed section with 9 rows: People, Topics, All Volumes, Publication Year, Administrations, Editors, Semantic Clusters (amber "gated Q-4" capsule), then "Your sets" section (My Scopes, Working Corpora). Cost: subseries pushed ~570pt down.
- **1c Indices hub (recommended)**: root adds ONE row — "Browse by…" (`square.grid.2x2`), caption "Volumes, years, administrations, editors, clusters, your sets". It assigns `[.indices]`; the hub level lists axes in three sections — Volumes (All Volumes w/ "Search all 552 titles" + count 552; Publication Year "1861–2025, grouped by decade"; Administrations "Documents covering each presidency" + 32; Editors "Named on 471 of 552 volumes" + 171), Documents (Semantic Clusters "179 automatic clusters" + gated chip), Your sets (My Scopes, Working Corpora + counts). Hub doors **append**, so the breadcrumb reads FRUS › Browse by › Administrations.
- **1d Search-first**: root `.searchable` ("Search 552 volumes by title or number") + a "Browse by" 2-column tile grid (Administrations, Editors, Publication Year, Clusters; All Volumes full-width) + "Your sets" rows + subseries. Tiles: white cards, radius 12, icon 21pt + 14pt medium label.
- **2a Variant of 1d**: Subseries becomes a **double-width tile on the grid's top row** (title 16pt semibold + caption "552 volumes by era, 1861–1988"); grid then 2×2; Your sets keeps its own row section. Note: bends the "subseries stay primary" constraint — flagged, needs the owner's sign-off in session.

### 1e — All Volumes catalogue (Q-7, recommended)
Pushed level, inline title "All Volumes", breadcrumb bar. `.searchable` "Title or volume number" (matches title + volumeId, A-1). Segmented control: **Title / Published / Era / Length**. Coverage caption: "552 volumes. Counts are FRUS document divs from the bundled index; Search over the same volume can return more rows." Sorted-by-Published shows decade section headers (2020S…), rows = `VolumeRowLabel` (full title, wraps) + caption row: year · "N docs" (via the R-2 accessor) · Downloaded glyph. Parse years with `firstYear(in:)` (CitationFormatter), never string sort. Label the axis "publication year" — the print year, not declassification.

### 1f — Separate Title / Year doors (Q-7 alternative)
Titles level: filed A–Z by the **distinctive segment after "Volume N,"** (409 titles start "Foreign Relations of the United States"); row = distinctive segment 16pt + boilerplate caption 12pt; right-edge letter index rail. Year level: decade sections, rows "YYYY — N volumes" drilling to that year's R-1 list.

### 1g — Administrations (A-3)
Index: coverage caption ("…A volume spanning two administrations appears under both — memberships sum to ~879 across 552 volumes."). Rows in roster order: number (13pt bold gray, 34pt column) · name 17pt · caption "term · party" · trailing right-aligned "N vols / N docs". Zero-volume administrations (Clinton onward) render at 45% opacity with reason "No published volumes cover this administration yet" — disabled, never hidden. Drill (e.g. Truman): caption "44 volumes with documents **covering** the Truman administration (Apr 1945 – Jan 1953), largest share first. Membership rule: any dated document (Q-2)." Rows = R-1 list in the index's order (doc count desc — never re-sorted) + trailing accessory "N docs / N.N%". Dual-membership rows carry an amber inline note "also under Eisenhower". Wording is always "covering", never "published under".

### 1h — Editors (A-4, compilers only)
Topic-Index template: `.searchable`, letter sections, per-row trailing "N volumes". Header caption: "Volume editors as named on each title page. 471 of 552 volumes name editors — 81 pre-1920 volumes carry none, so this index cannot reach them. General editors are credited on the volume page, not indexed here." Alias-merged rows show a tertiary caption ("4 spellings merged"); the Phillips pair stays split (auto-merge over-merges). Manifest strings are never rewritten — normalization lives in the grouping layer.

### 1i — Scopes, Working Corpora, and the R-3 document drill
- **My Scopes**: rows name + "N volumes · edited date"; unavailable scope renders dimmed with "Scope unavailable on this device". An empty resolution NEVER falls through to the whole corpus. Optional filter mode: pinned banner "Browsing within: Cold War Berlin ✕" above the subseries list (mechanically `filterDownloadedOnly`; persisted in UserDefaults, never on the @Model).
- **Working Corpora**: rows name + "N documents · captured from Search/Semantic Map · date"; truncation disclosed on the row ("saved 7,500 of 9,212 matches" in amber). Footer: capture happens in Search results and the map lasso — no create here.
- **Corpus document drill (R-3)**: amber coverage banner "1,873 of 2,340 documents indexed on this device…". Indexed rows: header 16pt + caption "place, date · volume title". Unindexed rows degrade to gray id "frus1969-76v41 · d97" + caption + a bordered blue **Download** (or **Index**) capsule button — the list never blocks. Three-tier date fallback per `CollectionEntryRows`. Never snapshot metadata into synced models.

### 1j — Semantic Clusters (A-8, gated on Q-4)
Caption: "179 clusters computed from document text. Labels are sampled terms, not subject headings. 88,207 documents (28.0%) belong to no cluster and cannot be reached from this list." Rows: 4-term label 16pt · "N documents" caption · right-aligned era mini-histogram (6 bars, volume-coverage-midpoint eras — the two peak bars accent blue #007AFF, rest #C7C7CC). Drill = R-3 pattern + the map card's behaviors; needs paging (cluster 8 = 38,652 docs). Never persist cluster ids in synced data or deep links.

### 3a — Scope editor
Pushed level (from My Scopes ＋ or an existing scope's Edit): nav "Edit Scope" + blue bold **Done**. Name section: single text-field row with clear button. "Volumes (N)" section: member rows with red `minus.circle.fill` delete controls + R-1 row content; last row = green `plus.circle.fill` "Add Volumes…" (blue label) which opens the 1e catalogue in **picker mode** (search/sort, tap to check). Footer: "Removing a volume never deletes it from this device. Changes sync via iCloud." Writes only the @Model's existing `name`/`volumeIds` — no schema change.

### 3b — Pan-axis "Add to Scope…" context menu
Long-press on ANY R-1 volume row (all axes inherit it — the menu lives once, in the shared list). Menu items in order: `Add to "«most recent scope»"` · `Add to Scope…` (submenu: all scopes, checkmark on rows the volume is already in; adding an existing member no-ops) · `New Scope from Volume…` · existing items (Download Volume, Word Cloud, Re-index when applicable). macOS: same items on `SubseriesVolumeListView` row context menus; the editor pushes in the detail column — **no new window** (#824).

### 3c — Whole-slice capture
Toolbar overflow on every R-1 list: "Save as Scope…" creates a scope from the list's current volume set, name prompt pre-filled from the axis (e.g. "Truman administration (44 volumes)").

### 1m — macOS Corpus Browser (R-4)
The one window absorbs all axes. Sidebar gains sections: **BROWSE** (All Volumes, Administrations, Editors, Clusters w/ Q-4 chip), **YOUR SETS** (My Scopes, Working Corpora), **SUBSERIES** (existing rows). Sidebar icons accent-tinted 15pt; selection = accent-filled rounded row. Requires retyping `List(selection:)` from `String?` to an axis/subseries enum — preserve the `.onChange` path-reset and `pendingVolumePush` deferral, and the `.macCorpusBrowser` hand-off. Axis selection shows its index in the detail column; rows push new `CorpusNavValue` cases (string-keyed) onto `detailPath` → R-1 volume list → existing `CorpusVolumeDetailView`. People/Topics keep their shipped windows; toolbar cross-links unchanged. **No new singleton Window scenes.** No deep-link/restoration promises (`CorpusNavValue` not Codable).

### 1n — iPad two-pane
List pane (340pt) is always `CorpusView` — root doors assign the path so the pane behaves as a list pane; hub doors append below the assigned root. Gate: ≥820pt (`BrowseTwoPaneMetrics`). Axis rows must be Buttons or they are inert in two-pane. Breadcrumb crumbs stay width-capped (220pt, tail-truncate); bar suppressed at document level.

### 1l — R-1 shared volume list (build FIRST, with 1e as proving axis)
One component, two mounts:
- iOS: new `BrowserLevel.volumeList(axis identity + ordered volumeIds)` — **hash on the axis identity, not the id array**; rows append `.volume` with the shipped Button pattern.
- macOS: promote `SubseriesVolumeListView` out of `private` (title parameter).
Contract: caller-supplied order, never re-sorts; coverage-caption slot above rows; optional trailing accessory slot (admin count/share, year, editor count). **One badge vocabulary on both platforms**: Downloaded (`arrow.down.circle.fill`, gray) · Indexed (`checkmark.circle.fill`, green) · Downloading (`arrow.down.circle`, blue) · Side-loaded (quaternary capsule) · Partial (orange text) · Planned (gray text).
R-2: all counts read `volumeTotals` (administration-profiles index) through one named accessor; resolve the three dead `documentCount > 0` labels. Bundled-artifact lists render pre-boot; SearchService-backed halves guard on `isBootComplete`.

## Interactions & Behavior
- Navigation: value-typed `BrowserLevel` array; root doors = `vm.select` (assign), deeper doors append. No `NavigationLink` anywhere in Browser/.
- Full-row tap targets: `.frame(maxWidth:.infinity,alignment:.leading)` **then** `.contentShape(Rectangle())` on `.plain`/`.borderless` button labels (the #312 measured idiom).
- Cross-surface arrivals: scene-addressed `Handoff<Request>`, drained from `.onChange` AND `.onAppear`.
- Disclosure sentences travel with their data (subjects "detected automatically… some are wrong"; cluster labels sampled terms; administrations "covering").
- Disabled states carry reasons (zero-doc administrations, unavailable scopes, boot-gated actions).
- Degraded rows gate only actions: Open needs the volume on-device; the affordance is Download/Index, never a dead end.

## State Management
- New `BrowserLevel` cases: `.indices` (if 1c), `.volumeList(axis, ids)`, `.administrations`, `.editors`, `.scopes`, `.scopeEditor(id)`, `.corpora`, `.corpusDocuments(id)`, `.clusters` (gated). Each needs the 4 exhaustive-switch touch points (hash/==, `levelView`, `breadcrumbLabel`, door).
- macOS: new string-keyed `CorpusNavValue` cases mirroring the above.
- Persisted device-local state (UserDefaults only): active browse scope filter; catalogue sort selection. Never new stored properties on synced @Models (CloudKit R-7 gate).
- Scope editing mutates existing `CustomVolumeScope.name`/`volumeIds`. Dependency: fix #862 (iOS scope visibility) first.

## Design Tokens (stock iOS system values used in the mocks)
- Backgrounds: systemGroupedBackground `#F2F2F7`; cards white, radius 12 (grouped inset), row padding 11×16.
- Text: label `#000` 17pt; secondaryLabel `#8A8A8E` 12pt captions; tertiary `#B0B0B5`; section headers 13pt uppercase `#6D6D72`.
- Accent `#007AFF`; destructive `#FF3B30`; success/indexed `#34C759`/`#28A745`; warning/amber `#FF9500` (banners at 12% tint, text `#7C4A03`/`#B45309`).
- Separators `rgba(60,60,67,0.18)`, inset to content leading edge.
- Typography: SF Pro (system). Large title 34pt bold; row title 17pt; volume titles 16pt wrapping (never clipped); captions 12pt; macOS rows 13/12pt with 10pt metadata.
- Hit targets ≥44pt.

## Assets
No bitmap assets. All icons are **SF Symbols** (use these, not custom art): `person.2`, `tag`, `square.grid.2x2`, `books.vertical`, `calendar`, `building.columns`, `person.text.rectangle`, `circle.hexagongrid` (clusters), `square.stack.3d.up` (scopes), `tray.full` (corpora), `arrow.down.circle` / `.fill`, `checkmark.circle.fill`, `minus.circle.fill`, `plus.circle.fill`, `magnifyingglass`, `chevron.right`. Tab bar (shipped): `books.vertical`, `magnifyingglass`, `note.text`, `tray.2`, `gear`.

## Files
- `Browse Axes Proposals.dc.html` — the full annotated canvas (open in a browser; pan/zoom).
- `screenshots/01…17` — one PNG per cluster, named `NN-<canvas id>-<name>.png`.
- `github.md` — source-repo association (repo, branch, screen→file map).
- Key repo files to modify/reference: `FRUSExplorer/Browser/BrowserViewModel.swift`, `BrowserView.swift`, `CorpusView.swift`, `SubseriesView.swift` (`VolumeRowLabel`), `SubjectIndexView.swift` (index-level template), `BrowserBreadcrumbBar.swift`, `BrowseTwoPaneMetrics.swift`, `VolumeView.swift`, `FRUSExplorer/App/MacCorpusBrowserWindow.swift` (`SubseriesVolumeListView`, `CorpusNavValue`), `AdministrationProfilesData.swift` (volumeTotals), `CitationFormatter.swift` (`firstYear(in:)`).

## Engineering constraints (from the requirements doc — the design promises around them)
- Every axis builds twice (iOS BrowserLevel; macOS CorpusNavValue) — implement R-1 platform-neutral, mount per platform (#777 twin drift).
- New files in `FRUSExplorer/Browser/` need `xcodegen generate` + scheme restore.
- Bundled-artifact reads only → no index-version bump, no CloudKit deploy.
- UI-test pins: People-first row; two-pane list-pane oracle; breadcrumb wrap behavior.
- Suggested order: R-1+R-2 with the catalogue → A-3 + A-4 → A-5 (after #862) + A-6 with R-3 → A-7 completions → A-8 behind Q-4. Shipping any axis owes the docs pass (Research Guide, manuals, in-app help).
