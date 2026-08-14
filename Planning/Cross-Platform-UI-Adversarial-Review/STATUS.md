# Cross-Platform UI Adversarial Review — state of play

Companion to the review package in this directory. **The review is the input, not the record.**
Several of its findings have not survived contact with the current build, and this file is where
that is written down — otherwise the next session re-scopes from the review text and redoes work
that was already done, or "fixes" something that was never broken.

Last updated after PR #893. Shipped through: Wave 1 (CW-1…CW-5) and CW-6a.

---

## 1. Findings corrected by measurement

Read this section before scoping anything. Every entry was checked against the code or the running
app, not against the review's prose.

| Finding | Review says | What is actually true |
|---|---|---|
| **F-7** (HIGH) | "`isFindInteractionEnabled` appears once… the iOS `FRUSDocumentWebView` never enables `UIFindInteraction`" | **False, and was false when the review shipped.** The live assignment is in `_FRUSDocumentWebViewiOS.makeUIView` (`FRUSDocumentWebView.swift:603` as of #893), added by #363 #5 on 2026-07-22 — three weeks before the review was written. The line the finding cites is a doc comment saying the *opposite* ("unlike iOS, where `isFindInteractionEnabled` provides one"). Only the missing *opener* was real; shipped in #892. |
| **F-6** (CRITICAL) | Reproduces, but "the `FocusedValue` routing is platform-neutral machinery; the gate is the only thing in the way" | Gate claim is right, remedy is **not**. Un-gating does not compile on iOS: `openSettings` is `@available(iOS, unavailable)`; `openWindow.fronting(id:)` is inside `MainWindowView`'s own `#if os(macOS)`; `HistoryMenuContent` is macOS-only. Also every publisher of `\.documentCommands` was macOS-only, so a lifted menu would have been permanently disabled. Shipped as a second iOS block in #892. |
| **P-1** (iPhone) | Corpus Analytics clips its controls at compact width | **Does not reproduce.** Evidence is a **Build 26** screenshot; the chrome was rebuilt (steppers → chips, legend added, landscape hint). Real residue was only the chip row's missing overflow cue — fixed in #891. |
| **P-9** (iPhone) | Year range needs tap-to-type | **Already fixed before the review shipped** (`yearEntryField`). No work; recorded so it is not scoped again. |
| **F-9** (MEDIUM) | "`.help` … which iPadOS does not render"; "six cryptic glyph tiles"; "every Research-rail tile" | **Partly wrong on three counts.** `.help` *does* set the accessibility hint on iOS (SDK doc), so VoiceOver already speaks these strings — the gap is sighted users only. The tiles **do** render captions (`tileLabel` draws `Text(label)`). Share is **not** a `railTile` on iOS and already uses `controlHelp`. The real finding is **non-adoption**: 30 `controlHelp` sites against ~79 iOS-compiled raw `.help` sites (of 169 in total — the rest are macOS-gated and therefore fine). |
| **F-10** (MEDIUM) | "macOS has chevrons"; the zones sit where a trackpad user selects text | macOS chevrons are `opacity(0)` until hover, so they are **not** a visible affordance either. The text-overlap clause is now false on iPad after Wave 1's 70ch measure. The zones already carry full VoiceOver labels/hints. Keyboard half shipped in #892. |
| **X-8** | Committed screenshots are stale | **Confirmed and load-bearing** — it is what made P-1 look real. Treat any screenshot-based finding as unverified until re-driven. |

**Standing rule from this program:** verify a finding against the current build before implementing
it. Four of the items above would have produced wrong or wasted work if taken at face value.

---

## 2. Shipped

| Wave | PR | Contents |
|---|---|---|
| Wave 1 | [#889](https://github.com/joshbotts/FRUS-Explorer/pull/889) | Reader measure (70ch), header dedup, slice scale, map zoom |
| Wave 1 | [#890](https://github.com/joshbotts/FRUS-Explorer/pull/890) | Compact map cards, summary dedup, Print restored to ⌘P, Sync Error button |
| Wave 1 | [#891](https://github.com/joshbotts/FRUS-Explorer/pull/891) | P-1 disproved; chip-row overflow fade; F-12 facet inspector on iPad |
| CW-6a | [#892](https://github.com/joshbotts/FRUS-Explorer/pull/892) | iOS `.commands` (Document + Find), `DocumentFindPresenter` + toolbar Find, ⌥⌘↑/↓ page turn |
| (found in passing) | [#893](https://github.com/joshbotts/FRUS-Explorer/pull/893) | Onboarding Skip dead end; `AppRootRouter` extracted and tested |

---

## 3. Next: CW-6b, then CW-7

**CW-6b — pointer/help and the visible page-turn affordance.** Scoped, not started.

- **F-9.** Do *not* add a TipKit tip in the iPad reader: the note on
  `.popoverTip(isPhone ? ResearchRailTip() : nil)` (`DocumentView.swift:1224` as of #893) records
  that `ResearchRailTip` there drove a view-graph update loop and a 10s `scene-update` watchdog
  kill — the `isPhone` gate is the whole fix and must stay.
  The cheap correct move instead is a `FeatureInfoButton` in the rail header built from the six strings
  already in `ResearchRailView` (no new copy, no new keys), plus converting `railTile`'s `.help`
  to the repo's own `controlHelp` fan-out. A wider `.help` → `controlHelp` sweep (~74 sites) is
  optional and should be audited per site, not regexed — `controlHelp` sets an
  `accessibilityLabel` and would overwrite better-chosen names.
- **F-10 visual.** `documentEdgeTapZone` already threads a `systemImage` used only by a `#if DEBUG`
  overlay; replace that with a real low-opacity chevron gated on `!isPhone`. Keep the existing
  56 pt `contentShape` as the only hit region, and keep the `.replace` verb — matching macOS's
  `append` would re-introduce audit M-17a.
- **Bug found during the CW-6a review, not yet fixed:** `SemanticMapSpikeView.swift:879` (as of #893) builds
  `DocumentView(entry:)` with **no** `onNavigateToDocument`, so a page turn there falls back to
  `appState.openTab(.browse)` and strands the reader out of the map's own sheet — the #750 class.

**CW-7 — semantic exits** (CSV/figure export, `userActivity`, region tap + eraCounts, VoiceOver
list). **CW-8** — compact reduced forms. Then wave 3 (CW-9…CW-11).

**F-8 (drag and drop)** is deferred out of CW-6 deliberately: the absence is confirmed (zero
`draggable`/`dropDestination` sites), but the first pass needs a second exported UTI declared in
both `project.yml` blocks and both Info.plists for `DocumentBrowserEntry`, and macOS has **no**
collection-list row to attach to (the sidebar was removed in Composer v2 §B). It deserves its own
change.

---

## 4. Verification constraints

Carry these into any session that claims something is verified.

- **No hardware keyboard on the simulator.** Menu-bar presence and every ⌘-shortcut from #892 are
  **unverified by me** and owed to the owner on a Magic Keyboard iPad — including whether iPadOS
  shows a duplicate Find entry now that both the app menu and `UIFindInteraction` bind ⌘F.
- **macOS UI is not drivable in these sessions** (computer-use access for the app was declined).
  Every PR lists its macOS checks explicitly; they remain the owner's.
- **`-showBuildSettings` returns the macOS product dir** when the scheme builds both modules.
  Install to a simulator from `Debug-iphonesimulator/`, and check the binary's architecture —
  installing the Mac build onto a simulator succeeds silently and then fails to launch.
- **Clean builds only** for warning claims; an incremental build does not recompile the files that
  would warn, and the `FRUSExplorer` scheme builds both platform modules.
