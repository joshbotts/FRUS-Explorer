# Cross-Platform UI Adversarial Review — state of play

Companion to the review package in this directory. **The review is the input, not the record.**
Several of its findings have not survived contact with the current build, and this file is where
that is written down — otherwise the next session re-scopes from the review text and redoes work
that was already done, or "fixes" something that was never broken.

Last updated after PR #901. Shipped: Wave 1 (CW-1…CW-5), Wave 2 (CW-6…CW-8a), and Wave 3 so far (CW-11a, plus #901's by-catch).

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
| **P-2** (iPhone) | "tooltips are `.help(...)` — which iOS never renders — so … the matrix is opacity-only" | **Half wrong, and the correction sharpens it.** `.help` sets the accessibility hint on iOS, and the cell separately carries its own `.accessibilityLabel` naming both volumes and the count. A VoiceOver reader has had these numbers all along; a **sighted touch** reader had none. Fixed in #898 by routing the existing `crossRefMatrixTable` to the existing `ChartDataInspectorView`. |
| **P-4** (iPhone) | a legend of six identical "Foreign Relations of the…" entries; the chart is "untappable" | **Both false.** `distilledVolumeLabel` fixed the legend on 2026-06-18 — all 552 labels distinct over the shipped manifest. The chart resolves taps by *nearest bucket*, so bar width is irrelevant. Only the "1 volumes" inflection survived; fixed in #898. |
| **P-7** (iPhone) | "the 1-hop `ReferenceListPanel` list … the canvas should be the secondary door" | **Key claim false for the cross-reference graph** — the list panel is already a peer of the canvas, not buried inside it. |
| **P-8** (iPhone) | Cross-Reference Analytics is "the worst-crowding view" | **Its own evidence is stale.** That code comment was falsified by #209 thirty minutes after it was committed; the surface is now the *least* crowded in the family, one glyph in an empty bar. The surface that genuinely truncates (`Col… Net… Flo… You…`) is Archival Analytics' mode picker, which P-8 does not name. |
| **X-8** | Committed screenshots are stale | **Confirmed and load-bearing** — it is what made P-1 look real. Treat any screenshot-based finding as unverified until re-driven. |

**Standing rule from this program:** verify a finding against the current build before implementing
it. Six of the items above would have produced wrong or wasted work if taken at face value.

### 1a. The screenshot ledger rule (X-8, CW-11)

X-8 asks for a rule: *chrome retired ⇒ shot stale*. This program has now supplied the evidence for
it three times over, each independently measured:

| finding | what the evidence showed | what was actually true |
|---|---|---|
| **P-1** | a Build-26 screenshot of Corpus Analytics clipping its controls | the chrome had been rebuilt — steppers became chips, a legend and a landscape hint were added — and nothing in the finding was on screen to clip |
| **P-4** | a figure showing a legend of six identical "Foreign Relations of the…" entries | `distilledVolumeLabel` fixed it on 2026-06-18, two months before the review shipped; over the shipped manifest all 552 labels are distinct |
| **F-24 / iPad shots** | four iPad captures predating #238 | the tab bar and navigation chrome they show no longer exist |

**The rule, stated so it can be followed:**

1. A screenshot is evidence about a **build**, not about the app. Every committed capture carries
   the build number it was taken from, in `Docs/screenshots/README.md`.
2. When a change **retires or reshapes chrome**, the shots showing that chrome are stale from that
   commit — not from whenever someone next notices. The commit that changes the chrome adds the row.
3. A finding whose only evidence is a screenshot is **unverified** until re-driven on the current
   build. This costs minutes; three of this program's findings would have cost a session each.

The re-captures themselves stay with the owner, by the standing convention that the owner takes
screenshots. What is automatable is the *ledger* — knowing which shots a change invalidated — and
that is a discipline in the commit, not a script.

---

## 2. Shipped

| Wave | PR | Contents |
|---|---|---|
| Wave 1 | [#889](https://github.com/joshbotts/FRUS-Explorer/pull/889) | Reader measure (70ch), header dedup, slice scale, map zoom |
| Wave 1 | [#890](https://github.com/joshbotts/FRUS-Explorer/pull/890) | Compact map cards, summary dedup, Print restored to ⌘P, Sync Error button |
| Wave 1 | [#891](https://github.com/joshbotts/FRUS-Explorer/pull/891) | P-1 disproved; chip-row overflow fade; F-12 facet inspector on iPad |
| CW-6a | [#892](https://github.com/joshbotts/FRUS-Explorer/pull/892) | iOS `.commands` (Document + Find), `DocumentFindPresenter` + toolbar Find, ⌥⌘↑/↓ page turn |
| (found in passing) | [#893](https://github.com/joshbotts/FRUS-Explorer/pull/893) | Onboarding Skip dead end; `AppRootRouter` extracted and tested |
| CW-6b | [#894](https://github.com/joshbotts/FRUS-Explorer/pull/894) | Rail `controlHelp` + tools info popover, iPad page-turn chevrons, semantic-map stranding fix |
| CW-7a | [#895](https://github.com/joshbotts/FRUS-Explorer/pull/895) | Map regions CSV + provenance; VoiceOver region list; figure refused in writing |
| CW-7b | [#896](https://github.com/joshbotts/FRUS-Explorer/pull/896) | Region tap + region card; `eraCounts` gets its first reader |
| CW-7c | [#897](https://github.com/joshbotts/FRUS-Explorer/pull/897) | Map Handoff (scope + lens), both platforms; activity-type registration test |
| CW-8a | [#898](https://github.com/joshbotts/FRUS-Explorer/pull/898) | Heat-matrix table route; chronology inflection |
| CW-11a | [#899](https://github.com/joshbotts/FRUS-Explorer/pull/899) | Research Guide door; Mac Settings search; the X-8 ledger rule |
| by-catch | [#901](https://github.com/joshbotts/FRUS-Explorer/pull/901) | Three missing sheet exits; Chronology range bar at accessibility sizes |

---

## 3. Next: Wave 3

Wave 2 is complete. What remains, in the review's own order:

**CW-9 — the window model** (X-7). De-singleton the Mac tools, multi-Search, and analytics
`WindowGroup`s on iPad with Semantic first. The largest remaining item and mostly macOS, which
these sessions cannot drive; it wants the owner's hand on verification.

**CW-10 — chrome and width.** Mac Search re-chrome; iPad width discipline, `TabSection`s and the
breadcrumb; Read-mode paging. The iPad half is drivable here.

**CW-11 — the rest of the documentation sweep.** The ledger rule is now written (§1a) and the
guide doors are shipped. What remains is the **re-captures themselves**, which are the owner's by
standing convention, plus the manual caption corrections that depend on them.

**Carried over, each with its reason:**

- **P-3** (concordance columns at compact width) — real; needs a designed compact form rather than
  a wiring change.
- **P-8's actual defect** — Archival Analytics' mode picker truncates to `Col… Net… Flo… You…` and
  is the only analytics dashboard with no size-class awareness at all. Folding four visible
  segments into a menu costs a tap and the at-a-glance sense that four views exist: **the owner's
  call**, not one to infer.
- **Semantic map slice poles in Handoff** — needs a `requestedPoles` deferral inside
  `SemanticMapModel` first; see `AppActivityTypes.semanticMap` for why carrying them without it
  ships a permanently half-drawn axis card.
- ~~Two by-catch items found while driving~~ — **shipped in #901**, and the count was wrong: it was
  *three* missing Done buttons, not two. See §5.

## 4. By-catch: what driving the app found that the review did not (#901)

> **Naming correction.** PR #901 called itself "CW-12". The review's own master worklist already
> uses CW-12 for *"Programs and gates: macOS text scaling, window-fronting audit, iPad probes"*,
> which is unrelated and unstarted. Nothing in #901 belongs to that item. By-catch is filed by PR
> number here rather than given a CW number it would have to share.

Neither of these is in the review package. Both were found by using the app, which is the argument
for driving it rather than reading it.

**Three analytics sheets had no exit, not two.** `PersonAnalyticsView`, `CrossReferenceAnalyticsView`
*and* `SemanticAnalyticsView` shipped with no Done button, against four siblings that have had one
since they shipped. The semantic map was the sharpest case and for a reason particular to it: the
interactive swipe-down needs a drag the sheet can claim, and the map puts a
`DragGesture(minimumDistance: 1)` on its canvas for panning — so a drag begun anywhere on the
canvas, which is most of the sheet, pans the map instead of dismissing it.

The regression test reads `BrowserView`'s own `.sheet` presentations rather than naming the views,
so the seventh sheet added without an exit fails on the commit that adds it. All three fixes were
mutation-tested.

**The Chronology range bar overflowed at accessibility text sizes, and now there is a test for it.**
`UIObstructionTests` scenario 8 is the suite's first Dynamic Type check. Two things about it are
worth carrying forward:

1. **It is iPhone-only, and that is measured.** Running the pre-fix layout on an iPad Pro 13-inch
   *passes* — the row fits at accessibility-large on a 1032pt canvas, so the assertions hold whether
   or not the bug is present. A green iPad run would have looked like verification and meant
   nothing. The skip says so.
2. **The defect, quantified by the mutation run**: on an iPhone 17 at accessibility-large the Show
   button lands at **x = 409.7 in a 402pt window** — past the trailing edge entirely, squeezed to
   32pt wide and 174pt tall. The From field ran off the leading edge at the same time, which is why
   the test checks both ends.

**A tooling note that cost most of this session** — sharpened after #901, because the first version
of this paragraph understated it. Three simulators share the name "iPhone 17" and three share
"iPad Pro 13-inch (M5)", and they are **one per installed runtime** (iOS 26.3 / 26.4 / 26.5) rather
than stray clones. So a name-based `-destination` is nondeterministic in **both identity and iOS
version**: successive runs land on different UDIDs, and a run that lands on a wedged one fails with
`Busy ("Application failed preflight checks")`, which reads exactly like a test failure. One
mutation result was misread that way before the destination was pinned.

**Pin `-destination "id=<UDID>"` for any A/B or any result you will report**, and list the UDIDs with
their runtimes beside them:

```bash
xcrun simctl list devices available | awk '/^-- iOS/{rt=$0} /iPhone 17 \(/{print rt" | "$0}'
```

Cure a wedged device with `simctl erase <UDID>` — a shutdown/boot pair does **not** clear it, which
was verified here by running a pre-existing scenario as a control and watching it fail identically.

## 5. Verification constraints

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
