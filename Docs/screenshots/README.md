# User-Manual Screenshots

Screenshots embedded in the user manuals (`../iOS-User-Manual.md`, `../macOS-User-Manual.md`).
Manuals still carry `` `[SCREENSHOT: …]` `` placeholders wherever an image has not been captured yet.

## Capture conventions

- **iOS / iPadOS** — captured from the iPhone 17 and iPad Pro 11″ simulators running the app against
  the full 552-volume corpus, via `xcrun simctl io <device> screenshot` (clean device-screen PNGs).
  Set an Apple-style status bar first:
  `xcrun simctl status_bar <device> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi`
  - **Series Analytics (offline) exception** — the four Series Analytics dashboards (Production &
    Timeliness, Geographic Emphasis, Archival Sourcing, Administration Profiles) render from bundled
    offline aggregates, with **no downloaded volumes and no index**. Capture them on a device with an
    empty corpus (or mid-onboarding), so the shots show the offline empty-index state these dashboards
    are designed for. Reachable via the FRUS Research Guide → **About the Series** category
    (`IndexingEducationView`).
- **macOS** — capture each window with the macOS screenshot tools (`⇧⌘4` then space). Most committed
  shots were taken with the main window in full-screen so its backdrop hid every other app, then
  `screencapture -R` cropped each floating window. The People sheets (`people-list`, `people-detail`)
  were instead captured with `screencapture -o -l <windowID>` on the Corpus Browser window, which
  grabs just that window (with its presented sheet) shadow-free regardless of what overlaps it — the
  window id comes from `CGWindowListCopyWindowInfo`.
- Keep filenames lowercase-kebab and grouped under `ios/`, `ipad/`, `macos/`.

## Captured

**iPhone (`ios/`)** — `browse-corpus`, `people-list`, `people-detail`, `search-results`,
`document-view`, `analytics`, `chronology`, `settings`.

**iPad (`ipad/`)** — `browse` (portrait split view), `sidebar-landscape` (landscape adaptive
sidebar), `document` (landscape reading view), `search-results`.

**macOS (`macos/`)** — `browser` (Corpus Browser with the People button), `people-list` (the People
sheet's alphabetical list) and `people-detail` (the "Kissinger, Henry A." reconciled-identity detail
sheet) — both wired into §4.4 — `search`, `document` (full-window reading view), `analytics`,
`chronology`, `collections` (**STALE — slated for re-capture**; see Remaining), and `research` (the
Research window; not yet wired into the manual — no placeholder). Also `toolbar` (§3.1, **STALE —
slated for re-capture**; predates build 27, missing the Person Analytics + Cross-Reference Analytics
buttons; see Remaining), `research-strip` (§3.2, the annotation strip with a document
open), `saved-searches` (§5.5, the Search window's saved-search list), `source-explorer` (§12, an
RG-59 source resolved to a NARA Catalog entry), and `analytics-table` (§13.2, Corpus Analytics in
Table mode).

> **macOS People browser (behaviour difference, investigated and resolved).** An earlier capture
> attempt showed the macOS People browser with "Kissinger" split four ways and some `*`-prefixed
> names, while iOS showed one unified identity. Root cause: a **stale rollup observed mid-rebuild** —
> the Mac's `person_rollup` was from an older (pre-authority) build, and the version-7 reconsolidation
> triggered on launch had not finished when the window was opened. Once it completed, the macOS
> browser showed the correct single "Kissinger, Henry A." (13,174 mentions, 100 volumes) and a clean
> list, **identical to iOS** — the state captured here. Both platforms use the same read path
> (`PersonIndexView → allPersonsSortedByName → SELECT … FROM person_rollup`); there is no
> macOS-specific bug. The `*`/`†*` strings live only in the raw `persons` table and are folded away by
> consolidation. Minor UX note: right after a rollup-version bump the browser keeps showing the
> previous (stale) rollup until the background reconsolidation finishes — including across sheet
> reopens, since the loaded list is cached — with no "rebuilding…" indicator; a fresh relaunch once
> consolidation has completed reads the clean rollup.

## Remaining

These placeholders still need images. They were out of scope for the first "core feature screens"
pass — most need a state that the running, already-indexed app can't show without extra setup. (The
four Series Analytics dashboards are the exception: they render **offline with no index**, so the
simplest capture is a fresh/empty install navigated to the Research Guide → About the Series
category — see the *Series Analytics* entry below and *New since build 26*.)

**macOS Chronology hover magnifier** (§14 placeholder) is still open. The magnifier is a transient
SwiftUI `onContinuousHover` overlay (year bucket → month-by-month breakdown) driven by live pointer
tracking: it is visible interactively, but every disk-capture path tried (`screencapture -l`/`-R` and
the MCP `zoom` re-capture) fires the hover's `.ended` and dismisses the card before the frame is
written, and `CGWindowListCreateImage` is unavailable on macOS 15+. Capturing it cleanly needs a
ScreenCaptureKit-based grab (or an in-process move-then-capture helper). To reach the year-bucketed
chart, set a date range longer than 8 years that stays under the 5,000-document load cap (e.g.
1869–1878) and hover a year bar.

**iOS / iPadOS states needing special setup:**

- **Series Analytics (About the Series) dashboards** — the four offline dashboards (Production &
  Timeliness, Geographic Emphasis, Archival Sourcing, Administration Profiles). Unlike everything
  else here, these render **with no index**, so the simplest capture is a fresh/empty install (or
  mid-onboarding) navigated to the Research Guide → About the Series category. Each dashboard carries
  an editable start/end year range and a per-chart "View as table" pop-up (see *New since build 26*).
- **Onboarding** — welcome / scope picker / "Ready" screens (needs a fresh install, no
  `-hasCompletedOnboarding` launch arg).
- **Indexing banners & Live Activity** — single- and multi-volume indexing banners, the
  indexing-complete card, the Dynamic Island and Lock Screen Live Activity (need an active download
  on a device; the simulator corpus is already indexed).
- **Stage Manager multi-window** (iPad) — two document windows side by side.
- **App Store listing** — the product page.
- **Feature flows not in the core pass** — embedded browser sheet, Research tab, Collections editor
  with documents, Citation Lookup, AI summary panel (Apple Intelligence, device-only),
  cross-reference graph, Source Explorer, **Person Analytics** (Trends + Network modes; iOS Browse →
  Analysis Tools → Person Analytics; macOS `frus.personAnalytics` window), **Cross-Reference
  Analytics** (iOS Analysis Tools → Cross-Reference Analytics; macOS `frus.crossRefAnalytics`
  window), the **consolidated macOS Collections ribbon** (Add ▾ · Sort by Date ▾ · View ▾ ·
  Export…), and the two-mode **Sort-by-Date menu** (Across the Whole Collection / Within Each
  Section) on both the macOS ribbon and the iOS/iPad Collections toolbar.

## New since build 26

The build-27 feature set (testers' last build was 26) adds the analytics surfaces and Collections
polish below. None of these shots are captured yet — they all belong in Remaining. Legend: 🆕 new
shot · 🔄 re-capture (existing shot is stale) · ⚙️ optional re-capture to surface a new state.

**iPhone (`ios/`)**

- 🆕 `series-production` — Series Analytics: **Production & Timeliness** (publication-lag scatter with
  the evolving timeliness-target step line, volumes-per-print-year bars, cumulative-growth curve).
  Capture on an empty/offline install via Research Guide → About the Series.
- 🆕 `series-geography` — Series Analytics: **Geographic Emphasis** (regional-share-over-time stacked
  chart by the 6 State Dept regional bureaus, region totals, top countries). Offline.
- 🆕 `series-archival` — Series Analytics: **Archival Sourcing** (provenance-mix-over-decades chart,
  overall composition, note density by decade). Offline.
- 🆕 `series-administrations` — Series Analytics: **Administration Profiles** (docs-per-administration
  coloured by party, per-administration volume list with document proportions, editorial-notes
  toggle). Offline.
- 🆕 `person-analytics-trends` — **Person Analytics**, Trends mode (most-mentioned people by era +
  multi-person mention-trajectory comparison). Browse → Analysis Tools → Person Analytics.
- 🆕 `person-analytics-network` — **Person Analytics**, Network mode (co-mention ego-network graph:
  focus person + top co-mentioned partners).
- 🆕 `crossref-analytics` — **Cross-Reference Analytics** (most-referenced documents / in-degree,
  degree-distribution histogram, volume-to-volume heat matrix, PageRank influence landmarks).
  Analysis Tools → Cross-Reference Analytics.
- 🆕 `analytics-table-popup` — the per-chart **"View as table"** pop-up in iPhone **list** mode with
  the Copy-CSV control (shown from any analytics chart).
- 🆕 `analytics-export-menu` (§13.7) — Corpus Analytics' **Options (•••)** menu open on the **Export**
  heading, showing Chart data (CSV)…, Figure (PNG)…, and Figure (PDF)…. Capture on a **time** axis
  (Decade / Year / Month / Day) so the two figure items are enabled — on **By Subseries** / **By
  Volume** they appear dimmed.
- 🆕 `analytics-figure-png` (§13.7) — **the exported file itself, not a device capture**: run
  Figure (PNG)… on a By-Year chart and commit the resulting 1,200-pt white plate, so the caption
  strip (scope · year range · value mode · app version · date, plus the pointer to the CSV) is
  legible. Downscale for the manual if needed; do not crop the strip away.
- ⚙️ `analytics` (re-capture optional) — existing By-Year term-frequency chart showing the new
  **"% of documents"** normalization toggle enabled.

**iPad (`ipad/`)**

- 🆕 `series-production` — Series Analytics Production & Timeliness on iPad (shows the editable
  start/end year-range control and the wider dashboard layout). Offline. Represents the four Series
  dashboards on iPad; ideally also capture `series-geography`, `series-archival`,
  `series-administrations`.
- 🆕 `person-analytics-trends` — Person Analytics Trends mode on iPad.
- 🆕 `person-analytics-network` — Person Analytics Network ego-graph on iPad.
- 🆕 `crossref-analytics` — Cross-Reference Analytics on iPad (heat matrix + PageRank landmarks).
- 🆕 `analytics-table-popup` — the per-chart "View as table" pop-up rendered as a native **Table** on
  iPad, with Copy-CSV.
- 🆕 `analytics-export-menu` — the Corpus Analytics **Export** menu open in the iPad **toolbar** (the
  iPhone shot shows it nested in the Options ••• menu instead, so both placements are on record). No
  manual placeholder — §13.7's iOS shots are iPhone-worded.
- 🆕 `collection-sort-menu` — the Sort-by-Date two-mode menu ("Across the Whole Collection" vs "Within
  Each Section") in the iPad Collections toolbar.
- 🆕 `collection-note-collapsed` — the collapsed "Add a note" affordance in the iPad collection editor
  (before a note is added).

**macOS (`macos/`)**

- 🆕 `series-production` — Series Analytics Production & Timeliness dashboard (offline; Research Guide
  → About the Series). Also capture `series-geography`, `series-archival`, `series-administrations`
  for the other three.
- 🆕 `person-analytics-trends` — Person Analytics window (`frus.personAnalytics`), Trends mode.
- 🆕 `person-analytics-network` — Person Analytics window, Network co-mention ego-graph.
- 🆕 `crossref-analytics` — Cross-Reference Analytics window (`frus.crossRefAnalytics`): volume-to-
  volume citation heat matrix + PageRank influence landmarks (and/or degree-distribution histogram).
- 🆕 `analytics-table-popup` — the per-chart "View as table" pop-up as a native macOS **Table** with
  Copy-CSV.
- 🆕 `analytics-export-menu` (§13.7) — the **Export** menu open in the Corpus Analytics window
  toolbar: Chart data (CSV)… · Figure (PNG)… · Figure (PDF)…. Capture on a **time** axis so both
  figure items are enabled (**By Subseries** / **By Volume** dim them).
- 🆕 `analytics-figure-heatmap` (§13.7) — **the exported file itself, not a window capture**: from
  Cross-Reference Analytics, export the volume-to-volume heat matrix via Figure (PNG)…. The plate
  renders the whole grid at once with **each cell's count printed**, the shading legend, and the
  caption strip — all three must stay visible. The matrix shades with the **system accent colour**,
  so capture under the default accent for a reproducible figure.
- 🆕 `collections-ribbon` — the consolidated Collections manager ribbon: Add ▾ (Documents / Section
  Heading / Note Block / Passages / Apparatus) · Sort by Date ▾ · View ▾ (Composition / Front Matter
  / Preview) · Export….
- 🆕 `collection-sort-menu` — the Sort-by-Date ▾ menu opened, showing "Across the Whole Collection" vs
  "Within Each Section".
- 🔄 `collections` — **RE-CAPTURE**: the existing shot is stale (its subject — the always-visible
  collection note + old 10-button toolbar — has been replaced). The new shot must show the
  consolidated four-control ribbon and the collapsed "Add a note" affordance (collection note not yet
  added).
- 🔄 `toolbar` (§3.1) — **RE-CAPTURE**: the existing shot predates build 27 and does not show the two
  new right-side buttons (**Person Analytics** and **Cross-Reference Analytics**). The new shot must
  include them alongside the existing Search, Graph, Info, Research, Collections, Corpus, Analytics,
  and Chronology buttons.
- ⚙️ `analytics` (re-capture optional) — existing term-frequency chart showing the new "% of
  documents" normalization toggle enabled.
