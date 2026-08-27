# User-Manual Screenshots

Screenshots embedded in the user manuals (`../iOS-User-Manual.md`, `../macOS-User-Manual.md`).
Manuals still carry `` `[SCREENSHOT: …]` `` placeholders wherever an image has not been captured yet.

> **Owner decision, 2026-08-23 (issue #1081): every committed capture is treated as stale.** The
> 31 files on disk date from the build 26–42 era and the UI has moved under all of them. Nothing
> on disk is presumed current: every slot a manual or the repo README references gets a fresh
> capture, every placeholder gets a first capture, and the unreferenced files get deleted rather
> than refreshed. **Issue #1081 is the shared tick-list; this file is the how.** The **Capture
> conventions** section below still applies in full. Everything between here and it — the tiered
> shot list and the historical "Captured" / "Remaining" / "New since build NN" sections — is kept
> for its staging notes only; its 🔄/keep triage is superseded, and its `§N.N` pointers refer to
> the pre-rewrite manual layout.
>
> The August 2026 rewrite (first-time graduate-student audience; the iOS manual is iPad-first and
> embeds the `ipad/` captures) also wired in `macos/person-analytics-trends` and `macos/research`,
> which were previously captured but unused.

## Staging notes (superseded triage — see #1081 for the tick-list)

Keyed to the **post-rewrite** section numbers. Legend as elsewhere: 🆕 new shot · 🔄 re-capture
(existing file shows retired UI). Two rules keep the wiring cheap:

- **🔄 items keep their existing filename** — the manuals reference the path, so a same-name
  re-capture updates them with zero edits.
- **🆕 items use the filenames below** (or note what you used instead, and the manual references
  get adjusted to match when the shots are wired in).

### Staging notes — holes in the shipped manuals (placeholders and stale-flagged embeds)

| Shot | For | What it must show |
|------|-----|-------------------|
| 🆕 `ipad/research-rail.png` | iOS §4.2 placeholder | Document open on iPad (landscape) with the Research rail as the trailing inspector: RESEARCH header, the 3×2 tile grid (Cite · Word Cloud · Sources · Graph · Related · Share), and the Summary/Notes/Tags/Collections accordions beside the text |
| 🆕 `ipad/stage-manager.png` | iOS §4.5 placeholder | Stage Manager: a document window beside a Related Documents (or Archival Neighbors) window, main window behind |
| 🔄 `macos/toolbar.png` | macOS §4.1 | The current trailing five: Search, Browse, **Analytics ▾**, **My Research ▾**, Research-rail toggle, with the centered `volumeId/documentId` title. (The older note below about separate Person/Cross-Reference Analytics *buttons* predates the menu consolidation — they now live inside Analytics ▾) |
| 🔄 `macos/research-strip.png` | macOS §4.2 | The Research rail beside a document — tile grid + accordions (filename kept for continuity) |
| 🔄 `macos/document.png` | macOS §4.3 | The reading view under the current toolbar (rail closed is fine) |

### Staging notes — iPad upgrades for the four iPhone stand-ins

The iOS manual is iPad-first; these four slots currently embed `ios/` captures with an
"(iPhone capture)" caption. Same content, iPad framing; the references get swapped once the
files land.

| Shot | For | Replaces |
|------|-----|----------|
| 🆕 `ipad/people-list.png` | iOS §6.5 | `ios/people-list.png` |
| 🆕 `ipad/people-detail.png` | iOS §6.5 | `ios/people-detail.png` |
| 🆕 `ipad/analytics.png` | iOS §15.1 | `ios/analytics.png` — ideally with **% of documents** on and the inline toolbar **Export** menu visible (the iPad placement is itself documented) |
| 🆕 `ipad/chronology.png` | iOS §15.7 | `ios/chronology.png` |

### Staging notes — new slots the manuals will embed as they land

No image exists on that platform today; each gets wired in on arrival.

- 🆕 `ipad/collections-editor.png` — iOS §12.1: the two-column manager (Contents outline + live
  preview), ideally with a section heading and a prose or excerpt row visible. The
  teaching-reader centerpiece — the highest-value Tier-3 shot.
- 🔄 `macos/collections.png` — macOS §12.1: the current Collections window (toolbar collection
  picker, outline + preview, ⚙ Collection / inspector controls). The committed file shows the
  retired UI, which is why the rewrite doesn't embed it; a fresh capture gets wired in.
- 🆕 `ipad/source-explorer.png` — iOS §14 (macOS already has one).
- 🆕 `ipad/cross-reference-graph.png` — iOS §8.6.
- 🆕 `ipad/related-documents.png` — iOS §8.5: scope control + Adjust weights + why-related chips.
- 🆕 `ipad/crossref-analytics.png` and `macos/crossref-analytics.png` — §15.4 on each (no capture
  of the analytics window exists on either platform).
- 🆕 `ipad/archival-analytics.png` and `macos/archival-analytics.png` — §15.5, Collections mode:
  an era ranking with the Central Files umbrella chip visible.
- 🆕 `ipad/semantic-map.png` and `macos/semantic-map.png` — §15.6, Regions coloring with labels
  and the caveat line beneath the map.
- 🆕 `ipad/word-cloud.png` and `macos/word-cloud.png` — §15.2, ideally in **Distinctive** mode
  with the eligibility line under the control visible.
- 🆕 `ipad/series-production.png` — iOS §16.1, offline per the Series-Analytics empty-corpus
  convention below (macOS already embedded).
- 🆕 `ipad/onboarding-volumes.png` — iOS §2.3, the Add Volumes step over the word-cloud backdrop
  (needs a fresh install, per the historical notes below).

### Housekeeping from the rewrite

- `ios/browse-corpus.png`, `ios/search-results.png`, `ios/settings.png` and `ipad/browse.png` are
  embedded by nothing and are **slated for deletion**, not refresh (#1081 §7).
  `ios/document-view.png` is no longer in either manual but is still the repo `README.md`'s third
  hero image — #1081 §6 leaves it as an open choice: re-shoot it for the README, or swap that slot
  for a current shot (the semantic map or the Browse root) and delete the file.
- The four `ios/` files still embedded are exactly the Tier-2 stand-ins above.
- Known-hard items are unchanged and stay out of the tiers: the macOS Chronology **hover
  magnifier** (capture problem documented below) and the **Live Activity / Dynamic Island**
  (needs a physical iPhone with an active download).

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
Research window; not yet wired into the manual — no placeholder). Also `toolbar` (§3.1, **STALE**; predates the toolbar consolidation), `research-strip` (§3.2, the annotation strip with a document
open), `saved-searches` (§5.5, the Search window's saved-search list), `source-explorer` (§12, an
RG-59 source resolved to a NARA Catalog entry), `cross-reference-graph` (a document's reference
graph; embedded at macOS manual §8.5 and as a repo-README hero), and `analytics-table` (§13.2,
Corpus Analytics in Table mode).

> **macOS People browser (behavior difference, investigated and resolved).** An earlier capture
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
- **Feature flows not in the core pass** — embedded browser sheet, Research tab, Collections
  editor with documents, Citation Lookup, AI summary panel (Apple Intelligence, device-only),
  and, on **iOS/iPadOS only**, the cross-reference graph, Source Explorer, Person Analytics and
  Cross-Reference Analytics. On macOS all four of those are already committed
  (`cross-reference-graph`, `source-explorer`, `person-analytics-trends`,
  `person-analytics-network`), as is `collections-ribbon` — all stale per #1081, but present.

## New since build 35 — the Settings North Star

Build 36 rebuilt Settings end to end: seventeen destinations became thirteen rows in four groups
(Library · Research · Reading & Search · System), driven by one shared model on both platforms.
**Every existing settings shot is obsolete**, and most of these surfaces have never been captured.
Legend as above: 🆕 new shot · 🔄 re-capture (existing shot is stale).

The design handoff's reference framings — `design_handoff_settings_northstar/screenshots/`,
`00-ia-settled-1c.png` through `10-about-polish.png` — are one per pane and are what these should
look like.

**iPhone (`ios/`)**

- 🔄 `settings` — **STALE, three IA generations out of date.** The committed image shows Volumes
  (Downloads · Storage & Index · Sideload), Research (User Tags · Projects · Summarization ·
  a Log Research Sessions toggle), Integrations, Data, and a Reset row. Not one of those group
  names or rows still exists. Re-capture the root: the iCloud Sync section, the **Search Settings**
  field, and the four groups.
- 🆕 `settings-volumes-storage` — the merged Library destination: storage bar with the XML/index
  split, Downloaded Volumes, Keeping Current, Storage & Index.
- 🆕 `settings-free-up-space` — the Free Up Space sheet with candidates selected and the
  **confirmation dialog** showing. This is a fixed-safety surface; the dialog is the point.
- 🆕 `settings-connections` — the two service cards (NARA Catalog · Zotero) showing connected and
  not-connected state side by side.
- 🆕 `settings-data-recovery` — Contents counts, the export rows, and the three-rung recovery
  ladder with its consequence lines.
- 🆕 `settings-research-sessions` — the Log Research Sessions switch, the Session Log row with real
  counts, and Delete Recorded Sessions…
- 🆕 `settings-notes` — the pane iOS never had: recent notes plus the All Notes door.
- ⚙️ `settings-search-results` — the Search Settings field with a query typed ("privacy" or
  "stop words") showing the tree filtered. Optional, but it is the feature reviewers miss.

**Mac (`macos/`)**

- 🆕 `settings-sidebar` — the window with the grouped sidebar and a pane open beside it. There has
  never been a committed macOS settings shot.
- 🆕 `settings-word-cloud` — the pane carrying the new bench: the **Sample** row, the
  "Keeps N of M terms" line, and the single Hidden Words editor with its scope picker.
- 🆕 `settings-session-log` — the Session Log sheet with real sessions expanded to their events.

**Not to capture**

The macOS Settings window has no search field (iOS only), and macOS has no live sync status inside
Settings (it is in the main window's status bar). Both are real gaps, recorded in
`Planning/Completed/Settings-Parity-Audit-2026-07-25.md`, not things to shoot.

## New since build 26 (build-27 tier — partly captured)

The build-27 feature set adds the analytics surfaces and Collections polish below. **Several of
these have since been captured** — `macos/person-analytics-trends`, `macos/person-analytics-network`,
`macos/series-production`, `macos/collections-ribbon` are committed, and `macos/collections` has been
re-captured — so treat the tick-list in issue **#1081** as authoritative over this list
(#1081 supersedes #106). Legend: 🆕 new
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
  colored by party, per-administration volume list with document proportions, editorial-notes
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
  caption strip — all three must stay visible. The matrix shades with the **system accent color**,
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
- 🔄 `toolbar` — **RE-CAPTURE**: the committed shot predates the toolbar consolidation. The
  current trailing set is Search, Browse, **Analytics ▾**, **My Research ▾**, and the
  Research-rail toggle, with the centered `volumeId/documentId` title (macOS manual §4.1).
  Person Analytics and Cross-Reference Analytics are items *inside* Analytics ▾, not buttons.
- ⚙️ `analytics` (re-capture optional) — existing term-frequency chart showing the new "% of
  documents" normalization toggle enabled.
