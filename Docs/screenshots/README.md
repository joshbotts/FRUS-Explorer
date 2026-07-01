# User-Manual Screenshots

Screenshots embedded in the user manuals (`../iOS-User-Manual.md`, `../macOS-User-Manual.md`).
Manuals still carry `` `[SCREENSHOT: …]` `` placeholders wherever an image has not been captured yet.

## Capture conventions

- **iOS / iPadOS** — captured from the iPhone 17 and iPad Pro 11″ simulators running the app against
  the full 552-volume corpus, via `xcrun simctl io <device> screenshot` (clean device-screen PNGs).
  Set an Apple-style status bar first:
  `xcrun simctl status_bar <device> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi`
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
`chronology`, `collections`, and `research` (the Research window; not yet wired into the manual — no
placeholder). Also `toolbar` (§3.1), `research-strip` (§3.2, the annotation strip with a document
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
pass — most need a state that the running, already-indexed app can't show without extra setup.

**macOS Chronology hover magnifier** (§14 placeholder) is still open. The magnifier is a transient
SwiftUI `onContinuousHover` overlay (year bucket → month-by-month breakdown) driven by live pointer
tracking: it is visible interactively, but every disk-capture path tried (`screencapture -l`/`-R` and
the MCP `zoom` re-capture) fires the hover's `.ended` and dismisses the card before the frame is
written, and `CGWindowListCreateImage` is unavailable on macOS 15+. Capturing it cleanly needs a
ScreenCaptureKit-based grab (or an in-process move-then-capture helper). To reach the year-bucketed
chart, set a date range longer than 8 years that stays under the 5,000-document load cap (e.g.
1869–1878) and hover a year bar.

**iOS / iPadOS states needing special setup:**

- **Onboarding** — welcome / scope picker / "Ready" screens (needs a fresh install, no
  `-hasCompletedOnboarding` launch arg).
- **Indexing banners & Live Activity** — single- and multi-volume indexing banners, the
  indexing-complete card, the Dynamic Island and Lock Screen Live Activity (need an active download
  on a device; the simulator corpus is already indexed).
- **Stage Manager multi-window** (iPad) — two document windows side by side.
- **App Store listing** — the product page.
- **Feature flows not in the core pass** — embedded browser sheet, Research tab, Collections editor
  with documents, Citation Lookup, AI summary panel (Apple Intelligence, device-only),
  cross-reference graph, Source Explorer.
