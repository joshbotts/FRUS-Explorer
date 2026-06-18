# User-Manual Screenshots

Screenshots embedded in the user manuals (`../iOS-User-Manual.md`, `../macOS-User-Manual.md`,
`../iOS-Supplement.md`). Manuals still carry `` `[SCREENSHOT: …]` `` placeholders wherever an image
has not been captured yet.

## Capture conventions

- **iOS / iPadOS** — captured from the iPhone 17 and iPad Pro 11″ simulators running the app against
  the full 552-volume corpus, via `xcrun simctl io <device> screenshot` (clean device-screen PNGs).
  Set an Apple-style status bar first:
  `xcrun simctl status_bar <device> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi`
- **macOS** — capture each window with the macOS screenshot tools (`⇧⌘4` then space, or
  `screencapture -o -w`). See the note under *Remaining* about capturing on a clean desktop.
- Keep filenames lowercase-kebab and grouped under `ios/`, `ipad/`, `macos/`.

## Captured

**iPhone (`ios/`)** — `browse-corpus`, `people-list`, `people-detail`, `search-results`,
`document-view`, `analytics`, `chronology`, `settings`.

**iPad (`ipad/`)** — `browse` (portrait split view), `sidebar-landscape` (landscape adaptive
sidebar), `document` (landscape reading view), `search-results`.

## Remaining

These placeholders still need images. They were out of scope for the first "core feature screens"
pass — most need a state that the running, already-indexed app can't show without extra setup.

**macOS — all window screenshots (`macos/`).** Not captured in the automation session: the
controlling terminal overlapped the app's right-hand panes in every full-screen grab, so the region
captures were unusable. Capture these by hand from a clean desktop (quit other windows first):
Corpus Browser (`⇧⌘B`) with the **People** toolbar button, the **People** browser sheet and a
reconciled person's detail, the Search window (`⌘F`) with results, a document in the main window
(Read / Research toggle), Analytics, Chronology, Source Explorer, Collections, and Settings →
Index Health.

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
