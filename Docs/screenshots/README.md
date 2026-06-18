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

**macOS People browser.** Deliberately not captured: on the test Mac the person rollup was in a
degraded state (e.g. "Kissinger" split into four entries, and several names carrying a spurious
leading `*`), whereas the same database on the iOS simulators shows the correct unified identities.
This looks like the macOS reconsolidation not completing cleanly (the status bar showed CloudKit
"Zone Missing / Sync Error"); it should be re-checked before screenshotting the macOS People window.
The iOS People screenshots represent the feature accurately in the meantime.

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
