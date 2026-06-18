# User-Manual Screenshots

Screenshots embedded in the user manuals (`../iOS-User-Manual.md`, `../macOS-User-Manual.md`,
`../iOS-Supplement.md`). Manuals still carry `` `[SCREENSHOT: …]` `` placeholders wherever an image
has not been captured yet.

## Capture conventions

- **iOS / iPadOS** — captured from the iPhone 17 and iPad Pro 11″ simulators running the app against
  the full 552-volume corpus, via `xcrun simctl io <device> screenshot` (clean device-screen PNGs).
  Set an Apple-style status bar first:
  `xcrun simctl status_bar <device> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi`
- **macOS** — capture each window with the macOS screenshot tools (`⇧⌘4` then space). The
  committed shots were taken with the main window in full-screen so its backdrop hid every other
  app, then `screencapture -R` cropped each floating window.
- Keep filenames lowercase-kebab and grouped under `ios/`, `ipad/`, `macos/`.

## Captured

**iPhone (`ios/`)** — `browse-corpus`, `people-list`, `people-detail`, `search-results`,
`document-view`, `analytics`, `chronology`, `settings`.

**iPad (`ipad/`)** — `browse` (portrait split view), `sidebar-landscape` (landscape adaptive
sidebar), `document` (landscape reading view), `search-results`.

**macOS (`macos/`)** — `browser` (Corpus Browser with the People button), `search`, `document`
(full-window reading view), `analytics`, `chronology`, `collections`, and `research` (the Research
window; not yet wired into the manual — no placeholder).

## Remaining

These placeholders still need images. They were out of scope for the first "core feature screens"
pass — most need a state that the running, already-indexed app can't show without extra setup.

**macOS People browser** (manual §4.4 placeholders). Not yet captured, but the feature is verified
correct (see the note below). The shots just need a clean capture pass — the People sheet opens
centred, where the controlling terminal overlapped it during the automation session; capture from a
clean desktop or with the FRUS windows moved left.

> **Investigated (behaviour difference, now resolved).** An earlier capture attempt showed the macOS
> People browser with "Kissinger" split four ways and some `*`-prefixed names, while iOS showed one
> unified identity. Root cause: a **stale rollup observed mid-rebuild** — the Mac's `person_rollup`
> was from an older (pre-authority) build, and the version-7 reconsolidation triggered on launch had
> not finished when the window was opened. Once it completed, the macOS browser showed the correct
> single "Kissinger, Henry A." (13,174 mentions, 100 volumes) and a clean list, **identical to iOS**.
> Both platforms use the same read path (`PersonIndexView → allPersonsSortedByName → SELECT … FROM
> person_rollup`); there is no macOS-specific bug. The `*`/`†*` strings live only in the raw `persons`
> table and are folded away by consolidation. Minor UX note: right after a rollup-version bump the
> browser shows the previous rollup until the background reconsolidation finishes, with no
> "rebuilding…" indicator.

**Other macOS placeholders** still open (out of the core set): the toolbar close-up, Research strip,
saved-searches sidebar, Source Explorer, Analytics table mode, and the Chronology hover magnifier.

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
