# Cross-Platform UI Adversarial Review — state of play

Companion to the review package in this directory. **The review is the input, not the record.**
Several of its findings have not survived contact with the current build, and this file is where
that is written down — otherwise the next session re-scopes from the review text and redoes work
that was already done, or "fixes" something that was never broken.

Last updated after PR #907. Shipped: Wave 1 (CW-1…CW-5), Wave 2 (CW-6…CW-8a), and Wave 3 so far (CW-11a, CW-10a/b, plus #901's by-catch).

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
| **F-2** (HIGH, iPad) | "Every tab root is a phone list stretched to full width… no tab offers a second pane at regular width" | **Cap claim true, second-pane claim now false.** All five roots are genuinely uncapped and **there is no width-cap helper anywhere in the app** — zero hits for `readableContentGuide`, `maxContentWidth`, or any equivalent; Wave 1's "70ch measure" is a CSS rule in `HTMLTemplate.documentCSS` scoped to `.frus-document` and cannot reach a SwiftUI `List`. But Search shipped a regular-width facet inspector in #891 — this review's own F-12. **The naive remedy is wrong**: no `List` in the app is capped with `.frame(maxWidth:)`, and framing a NavigationStack-root list turns `.insetGrouped` into a floating card and costs `.plain` its edge-to-edge separators and swipe extents. Needs a design decision, not a wiring change. |
| **F-3** (HIGH, iPad) | "five rows above ~900 pt of empty column" | **Holds structurally, two details wrong.** `TabSection` has never existed in the app target on any branch (`git log --all -S` → zero commits) and `.sidebarAdaptable` is live and ungated. But Collections is already the fourth sidebar row, and the void is ~510 pt — "~900 pt" exceeds the entire column in the figure the finding cites. Implementation gate: `TabSection` lives in a `@TabContentBuilder`, so the extraction must conform to **`TabContent`, not `View`** — no such type exists in the repo yet. |
| **F-5** (LOW, iPad) | dock stretches edge to edge; welcome copy, scope picker and buttons all affected | **Premise exact — unusually, both line citations are still accurate — but only one of the three symptoms was real.** Measured on the iPad simulator: the scope picker filled **1294 of 1294 pt**, while the welcome body was already capped at 340 pt and the primary button is 128 pt and centred. Fixed in #902. |
| **F-17** (HIGH, iPad) | "conveys exactly one level"; iPad gets less context than iPhone across five levels | **Suppression real and unfixed; damage overstated.** iPhone has no breadcrumb at the document level either (Session 121) and none at the corpus root, so the delta is three levels, not five — and of those, the volume screen's own title already names its series and period. The level that genuinely loses its ancestor is the **compilation**. Fixed there in #902. |
| **M-2** (HIGH, macOS) | per-document tools are singletons that "cross-wire" between document windows | **Singletons confirmed; the cross-wiring is largely FIXED.** Both doc comments the finding quotes as evidence are records of *shipped repairs* — one literally says "used to". Source Explorer renders a `noteSnapshot`, so a background `loadDocument` cannot reach an open explorer; the graph binds its global live, but every writer is a deliberate user open. So the live defect is **scene COUNT** (you cannot compare A's graph against B's), not silent cross-wiring, and the second reader adds that the **cold Window-menu path** is still exposed. Two corrections to scope: the **word cloud does not belong** in this finding (it is an app-level analysis window with its own scope picker, not a per-document tool), and the finding *under*-states its case — `SourceExplorerRequest` and `GraphWindowRequest` already exist and already ship value-based **on iPad** (#317). Cost: `openWindow.fronting(id:)` is id-only with ~20 call sites and a build-failing test, and a `WindowGroup(for:)` loses its automatic macOS Window-menu entry. |
| **M-3** (MEDIUM, macOS) | one Search window; result sets cannot be compared | **Singleton confirmed and unfixed, but "S" effort is refuted** — six shared-state couplings sit between here and a second window, plus an unpriced Window-menu regression and two test gates. And it needs an **owner decision first**: value-based windows reuse by request *equality*, but a Search window opens empty and is typed into, so what keys it is the actual design question. |
| **F-11 / F-13** (iPad) | five analytics sheets; the Search→Analytics hand-off teleports across tabs | **Mechanism exactly right, inventory wrong twice.** There are **six** analytics sheets plus the word cloud, not five, and **Archival Analytics is not presented by `BrowserView` at all** (#833 routes it through a hand-off). F-13 reproduces line for line, and the second reader found it is **three routes, not one**. |
| **F-25** (HIGH, iPad) | the semantic map is a sheet; the reader is buried inside it | **HOLDS, and is worse than the review or the first reader said — measured on a booted iPad Pro 13-inch.** The sheet reports **compact** width, so the 13-inch iPad ran the map's *phone* layout, and with the header at its default expanded state the Metal canvas was **~582×201pt — about 8% of the screen, for 314,483 documents**. The pushed document's Research rail then opened as a **third stacked sheet** over the map, because SwiftUI auto-presents `.inspector` as a sheet at compact width. Two review clauses are wrong: only **one** of the six sheets declares `.presentationSizing(.page)`, and the pushed document **does** offer Open in New Window. Fixed in #904. |
| **X-8** | Committed screenshots are stale | **Confirmed and load-bearing** — it is what made P-1 look real. Treat any screenshot-based finding as unverified until re-driven. |

**Standing rule from this program:** verify a finding against the current build before implementing
it. **Fourteen of the items above** would have produced wrong or wasted work if taken at face value — and
F-2 is the sharpest case yet, because there the finding is *true* and the obvious remedy is what
breaks.

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
| CW-10a | [#902](https://github.com/joshbotts/FRUS-Explorer/pull/902) | Onboarding dock cap (F-5); compilation parent line (F-17) |
| CW-10b | [#903](https://github.com/joshbotts/FRUS-Explorer/pull/903) | Dead search-scope chip removed (M-10); Mac toolbar centre names its location (M-8) |
| CW-9a | [#904](https://github.com/joshbotts/FRUS-Explorer/pull/904) | The semantic map gets an iPad window (F-25) — the first analytics window scene on iOS |
| CW-9b | [#905](https://github.com/joshbotts/FRUS-Explorer/pull/905) | Corpus Analytics + Chronology windows; F-13's tab teleport removed |
| CW-9c | [#906](https://github.com/joshbotts/FRUS-Explorer/pull/906) | Archival Analytics window — the last surface whose request type already existed |
| CW-9d | [#907](https://github.com/joshbotts/FRUS-Explorer/pull/907) | Person Analytics window, keyed by Trends/Network (owner decision: #906 option 2) |

---

## 3. Next: Wave 3

Wave 2 is complete. What remains, in the review's own order:

**CW-9 — the window model** (X-7). Verified in full (§1); **F-25 shipped in #904**, which is the
"analytics `WindowGroup`s on iPad, Semantic first" half of the item and proves the pattern on the
sharpest surface. What remains:

- **F-11 is four surfaces of six done.** The map (#904), Corpus Analytics and Chronology (#905),
  and Archival Analytics (#906) all had request types already, so each window cost a synthesised
  `Codable & Hashable` and a gate. **Person Analytics and Cross-Reference Analytics are what
  remain, and they are a decision rather than a port**: measured, they are the only two analytics
  surfaces that take *no parameters at all* — no init arguments, no deep-link hand-off, nothing a
  caller can pre-set. So a window value for either carries no information, and the choice is:

  1. **An empty marker request** — every value equal, so `openWindow(value:)` always focuses one
     window. Correct semantics for a parameterless surface, and the smallest change.
  2. **A mode-carrying request** — `PersonAnalyticsMode` is `.trends` / `.network`, so a reader
     could put the rankings dashboard and the co-mention graph side by side. That is a real
     comparative use on an iPad, but it is a **new feature**, it changes the views' initialisers
     and their state seeding, and nobody asked for it.

  **Owner decision 2026-08-15: option 2, for Person Analytics.** Shipped in #907 —
  `PersonAnalyticsRequest` carries the mode, so Trends and Network open as two windows, and the
  Browse menu becomes a submenu of the two halves where windows are available (without it the
  mode-carrying request would be theoretical: the menu could only ever have opened Trends).
  **Cross-Reference Analytics was not covered by that decision and remains a sheet** — it has no
  mode enum of its own, so option 2 has nothing to key on there and only option 1 applies.
- **M-2, rescoped by measurement.** The word cloud is **out** (app-level, not per-document). The
  real work is Source Explorer + graph, whose request types already exist from #317's iPad port —
  so the cost is not the values but `fronting(id:)`, which is id-only across ~20 sites and guarded
  by a build-failing test, plus the lost macOS Window-menu entry.
- **M-3 needs an owner decision before code**: what keys a Search window that opens empty and is
  typed into? Value-based windows reuse by request equality, and an empty request is the same
  empty request.
- **A consequence of #904, now measured twice.** The map window is a real scene, so iPadOS restores
  it and the app can relaunch showing the map with no tab bar. Scenario 10 handles both entry
  states rather than assuming a cold start — and in #907 the same behaviour showed its second face:
  the scenario **leaked its window into the next test**, which launched inside the restored map,
  found no Browse tab, and failed. It passed in isolation, which is the signature of leaked state
  rather than a defect in either test. Scenario 10 now closes the window before it returns. **Any
  future test that opens a window owes the same courtesy** — sheets never needed it, scenes do.

**CW-10 — chrome and width.** Verified in full (§1); **F-5 and F-17 shipped in #902**. What remains,
with the constraint that makes each one bigger than it looks:

- **F-2 (the width cap) needs an owner decision, not an implementation.** The finding is true — no
  root is capped and no helper exists — but the obvious fix is measurably wrong: framing a
  NavigationStack-root `List` turns `.insetGrouped` into a floating card and costs `.plain` its
  edge-to-edge separators and swipe-action extents, and no `List` in this app is capped that way
  today. The real options are (a) cap the *row content* rather than the list, (b) adopt a
  two-pane shape at regular width per `CollectionEditorView.iPadCollectionLayout`, or (c) decide
  full-width lists are correct on iPad, as Apple's own Settings and Mail are. That is a design
  call.
- **F-3 (`TabSection`s) needs a tab-identity model first.** `TabSection` sits in a
  `@TabContentBuilder`, so the extraction must conform to **`TabContent`**, and no such type
  exists in the repo — this is new ground rather than an adoption.
- **Mac W-8/W-9.** M-10 and M-8 shipped in #903 (§5). **M-4** (the Search window's ten
  hover-explained icon toggles and its five-buttons-that-want-to-be-a-picker) and **M-9**
  (Read-mode paging is hover-only edge chevrons) are what remain, and both genuinely want a Mac in
  front of someone.

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

## 3a. Owner decisions taken 2026-08-15

Recorded here because each one closes a question a later session would otherwise re-open, and two
of them overrule the recommendation I gave.

| Question | Decision | What it means |
|---|---|---|
| **F-2** — iPad width discipline, given that capping a root `List` breaks its native style | **Two-pane at regular width** | Browse and Research gain a list + detail layout following `CollectionEditorView.iPadCollectionLayout` (`:734`, reached via `if sizeClass == .regular` at `:518`). Must honour the #238 rule: a plain `HStack` of two panes, **never** a nested `NavigationSplitView`. This is the largest of the four options and was chosen over my recommendation of capping row content — so the row-content cap is NOT a fallback to drift into; if the two-pane shape proves wrong, that is a new decision. |
| **F-3** — what populates the iPad tab sidebar | **Saved searches + projects** | `SavedSearch` (`Models/SavedSearch.swift`) and `Project` (`Models/Project.swift`). Collections is deliberately excluded: it is already the fourth sidebar row, and listing it inside the sidebar would duplicate a tab. Recent volumes are excluded too. The extraction must conform to **`TabContent`**, not `View`. |
| **P-8's real defect** — Archival Analytics' mode picker truncating to `Col… Net… Flo… You…` | **Menu at compact width** | Matches the other dashboards' compact behaviour. Accepts the stated cost: one extra tap, and the loss of the at-a-glance sense that four views exist. |
| **What comes next** | **CW-9, the window model** | Ahead of implementing F-2, the Mac chrome items (M-4/M-9), and F-3. |

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

## 5. Two Mac findings that needed no Mac — shipped in #903

Both were checked against the current build during CW-10 and neither needed the macOS UI to fix or
to test, contrary to this file's earlier framing that CW-10's Mac half was uniformly the owner's.
Only **M-4** (Search-window chrome) and **M-9** (Read-mode paging) genuinely need a Mac in front of
someone.

**M-10 — the search-scope chip wired to nothing. CONFIRMED, and more cleanly than stated.**
`MacSearchViewModel.scopeCollections` (:124) is a bare stored property carrying the comment
`// deferred to future session`, and it has **exactly one reader in the whole codebase: the chip's
own binding** at `SearchSheet.swift:727`. Every sibling scope has a `didSet` projecting into
`parameters` and `filterVM`. Toggling Collections therefore changes nothing, and the only
disclosure is `.help` hover text — on the one platform where a user need never hover. The repo's
no-silent-no-ops standard gives three outcomes: it works, it is disabled with a visible reason, or
it does not ship. Removing the chip and the dead property is the smallest honest one, and it also
relieves the row density M-4 complains about.

**M-8 — the raw ID in the title bar. WRONG AS WRITTEN, and the correction improves the fix.** The
finding says the document's title "is relegated to `.help` hover". It is not:
`MacDocumentView.swift:1237` already sets `.navigationTitle` to the header, under a comment that
says so. The real defect is narrower — the toolbar's centre repeats identity the window title
already gives in human form, and its tooltip repeats it a third time. So the remedy is not "show
the title", it is **make the centre say what the title does not**: which volume, and where in it.
`ChronologyViewModel.distilledVolumeLabel` is the existing short form, already rendered by
Chronology and Cross-Reference Analytics — and now by the compilation parent line (#902).

## 6. Verification constraints

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
