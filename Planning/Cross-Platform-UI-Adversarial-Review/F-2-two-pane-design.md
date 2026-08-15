# F-2 — two-pane Browse and Research at regular width: the design

Owner decision 2026-08-15 (STATUS.md §3a): Browse and Research gain a plain two-pane content
layout at regular width, following `CollectionEditorView.iPadCollectionLayout`, honouring #238's
rule that a tab's content hosts a `NavigationStack` and never a `NavigationSplitView`.

This document is the mapping that has to exist before that is built. It was produced by two
independent readers per surface, the second prompted to break the first's plan; **every plan in
the first pass was materially wrong in at least one load-bearing way**, which is the argument for
writing this down rather than starting from the review's one-line recommendation.

**Status: designed, not built.** §5 says why that was the right stopping point.

---

## 1. The enabling fact, and the disabling one

**Browse has zero `NavigationLink`s.** `grep -rn "NavigationLink" FRUSExplorer/Browser/` returns
nothing. Every row is a `Button` that mutates `vm.navigationPath` — the corpus root's three
targets are `CorpusView.swift:36-37` (resume reading), `:42-43` (People) and `:79-80` (subseries),
and every deeper level is the same shape (`SubseriesView.swift:59-60`, `VolumeView.swift:304`,
`CompilationView.swift:283-284`).

This matters more than anything else in the design. A `NavigationLink(value:)` outside an
enclosing `NavigationStack` is **inert**; a `Button` that appends to an `@Observable` array is not.
So Browse's list pane needs no navigation container of its own, and `vm.navigationPath` can drive
the detail pane verbatim.

**Research is the opposite.** Its iOS sidebar rows *are* `NavigationLink(value:)`
(`ResearchView.swift:280-284`), so a list pane outside a stack makes them dead. Converting them to
Buttons re-arms the #312 dead-row defect unless the `.frame(maxWidth: .infinity)` +
`.contentShape(Rectangle())` idiom travels with them.

---

## 2. The shape: one outer stack, one nested detail stack

The first reader proposed two sibling `NavigationStack`s in an `HStack`, citing
`iPadCollectionLayout` as the house pattern. **That is not what the house pattern is.**
`iPadCollectionLayout` (`CollectionEditorView.swift:734-767`) contains *no navigation container at
all* — its `.navigationTitle`, `.navigationBarTitleDisplayMode(.inline)` and `.toolbar` are applied
to the HStack's **parent** (`:515-547`). Single outer stack. That shape ships today, in a tab,
under `.sidebarAdaptable`, at regular width. Two sibling stacks each spanning the tab's top edge
have never run in this repo.

Browse cannot be a pure `iPadCollectionLayout`, because its detail levels each set their own
`navigationTitle` and several set a `.toolbar` (`SubseriesView.swift:82-95`,
`VolumeView.swift:98-120`, `CompilationView.swift:177-190`), and the detail needs a Back. So the
detail pane needs a container and the list pane does not — exactly one container touching the
tab's top edge, which is the geometry #238 broke on. This is also `MacCorpusBrowserWindow`'s
shipped shape (`App/MacCorpusBrowserWindow.swift:143-156`).

## 3. The surgery, in order

1. **`CorpusView`'s three row actions change from `append` to assign** — `vm.navigationPath =
   [.subseries(group)]` rather than `.append`. Without it, tapping a second subseries in a
   persistent list pane stacks it on top of an open document. The dead `SubseriesListView`
   (`BrowserView.swift:847-864`) already does the assign form: it was written for the reverted
   split and is the evidence this is the correct semantics.

   **This is provably a no-op on iPhone**: nothing anywhere appends `.corpus`, the breadcrumb only
   truncates (`prefix(index+1)`, `:672`), `levelView`'s `case .corpus` (`:615`) is unreachable, and
   `CorpusView`'s only live call site is the stack root where the path is empty.

2. **The gate must read measured container width, not size class.** In the `.sidebarAdaptable`
   *sidebar* representation the tab sidebar already consumes a column without changing the size
   class, so a 380pt list pane leaves an 11-inch iPad in portrait roughly **194pt of detail**. A
   `sizeClass == .regular` gate — the obvious one, and the one the first plan used — produces that.

3. **The branch must be a plain `if/else` in a ViewBuilder, never `AnyView`.** `levelView` uses
   `Group` rather than `AnyView` deliberately (`:581`): `DocumentView`'s `@State var vm` must
   survive re-renders of `BrowserView.body`, which fire on every `navigationPath` change. Wrapping
   either layout in `AnyView` restarts document loading on every navigation.

4. **`.workingOnSubtitle()` must be suppressed in one pane.** It is applied to both `CorpusView`
   (`:116`) and every level (`:627`). Today only one is on screen; in a two-pane the research
   question renders twice.

5. **The path binding is copied verbatim** (`:532`). Reusing the identical binding is what keeps
   back-navigation, breadcrumb truncation (`:670-676`), `activateTagFilter`'s pop
   (`BrowserViewModel.swift:276-288`) and `pushInBrowseStack`'s page-turn `.replace` (`:697-703`)
   working with no further edits. **Any scheme that splices the path** (root = `path.first`,
   pushed = `dropFirst`) breaks `pushInBrowseStack`'s `removeLast()` arithmetic.

## 4. The test problem, which is the reason this is not a small change

**Several existing UI tests do not fail in a two-pane — they pass while measuring the wrong pane.**
That is worse than breaking.

- `app.swipeUp()` / `swipeDown()` target the app element's **horizontal centre**, so they scroll
  whichever pane straddles the window midline — and that is a *different pane* in the sidebar
  representation than in the floating-top-bar one. This affects `UIObstructionTests` scenario 1 and
  `CompilationDocumentsTests.scrollDownUntil`.
- `app.navigationBars.firstMatch` and `app.cells.firstMatch` resolve the list pane's bar rather
  than the detail's. `assertBrowseDetailPushesUnobstructed`'s hittability assertion (`:639-646`)
  silently becomes an assertion about the list pane.
- Two oracles assert the corpus navigation bar **disappears** on a drill-in — which is precisely
  what a two-pane must stop doing, so they are correct today and wrong afterwards.

So the work includes re-establishing the safety net pane-aware, not making it green.

## 5. Why this is designed and not built

The composition — a nested detail `NavigationStack` inside a `.sidebarAdaptable` tab — **has never
run in this repo on iPadOS 26**, and the last attempt at a two-pane Browse was reverted for a
safe-area defect in exactly that area (#238). Against that, the change rewrites the navigation
shell of the app's most central view and requires reworking test oracles that would otherwise pass
while measuring the wrong pane.

That is a session's focused work with a live revert risk, not a tail-end increment. Building half
of it — or building it with the safety net still pointing at the wrong pane — would be worse than
not starting, because the tests would go green and say nothing.

**The first task of that session is not code.** It is to stand up the nested-stack composition in
a throwaway branch and confirm on a booted iPad that the detail pane's top safe area resolves
correctly in *both* `.sidebarAdaptable` representations. If it does not, §2's shape is wrong and
the whole design changes — and that is a twenty-minute answer, not a day's.

---

## 6. The probe has been run. The shape is viable.

Run 2026-08-15 on a freshly erased iPad Pro 13-inch (iOS 26.3, window 1032×1376), against a
minimal instrument: one outer `NavigationStack` carrying the chrome, an `HStack` of
`CorpusView` + a nested detail `NavigationStack`, with a 1pt marker at the detail pane's top. The
instrument was removed afterwards rather than left behind a flag — this file already has to
explain two *previous* unreferenced layouts (`splitLayout`, `SubseriesListView`) kept "for easy
revert", and a third would be the same debt again.

| representation | navigation bar bottom | detail pane top | clearance |
|---|---|---|---|
| floating top tab bar | 138.0 | 138.0 | **0.0** |
| sidebar | 86.0 | 138.0 | **52.0** |

**The answer: the nested stack does not reproduce #238's defect.** In both representations the
detail pane's content begins at y=138 — flush with the bar in the floating case, below it in the
sidebar case, and *never above it*. #238's split put content where it could not be scrolled to;
this composition does not. **§2's single-outer-stack shape stands, and the design is buildable as
written.**

Two by-products, both of which the test work in §4 needs:

1. **`app.tabBars` resolves nothing in either representation.** The `.sidebarAdaptable` chrome is
   not an `XCUIElement` of type `tabBar`, so a pane-aware oracle cannot measure against it the
   obvious way. Any assertion about "clears the floating tab bar" has to be written against
   something else.
2. **`app.navigationBars.firstMatch` resolves a *different bar* in each representation** — 138.0
   in one, 86.0 in the other, for the same layout. That is §4's predicted hazard appearing in
   practice, in the very first measurement taken, and it is why §4 says the existing oracles pass
   while measuring the wrong thing rather than failing.

### 6a. The probe was necessary and NOT sufficient — corrected 2026-08-15

**§6 concluded the shape was viable. Building it showed that conclusion was too strong, and the
fault was in the probe's design rather than in its numbers.**

The probe measured the composition **at rest** — two panes, nothing pushed. It never opened a
level. Built out and driven, the layout is correct at rest (the detail placeholder renders beside
a 340pt list pane; the corpus People row measures 308pt wide at x=16) and then **fails on push**:

| state | evidence |
|---|---|
| at rest | `placeholderPresent=true`, list-pane row at `(16, 138, 308, 52)` — two panes, correct |
| after opening a subseries | cells at `(20, 175, **992**, 93.5)`, `navBars=1` — **full container width** |

The nested `NavigationStack`'s pushed destination expands to the whole content area instead of
staying inside the detail pane, so the list pane is replaced exactly as the single-column layout
would replace it. The two-pane exists only until the reader uses it.

**The lesson for the next attempt is about the probe, not the layout.** A composition probe has to
exercise the composition's *purpose*. This one asked "does a nested stack sit correctly beside a
list?" when the question that decides the design is "does a nested stack **push** correctly beside
a list?" The safe-area numbers in §6 remain true and remain insufficient.

Two candidate causes, in the order worth testing:

1. ~~**The detail stack has no width constraint of its own.**~~ **Tried, and it is not this.**
   Adding `.frame(maxWidth: .infinity, maxHeight: .infinity)` and `.clipped()` to the detail stack
   left the pushed cells at 992pt. The code carries a do-not-re-try comment at the site.
2. **A `NavigationStack` inside an `HStack` does not constrain its pushed destination** — now the
   leading explanation, and if it holds, **§2's shape is wrong** and the detail pane needs a
   different container. That is precisely the outcome §5 predicted would change the whole design.

So the shape is **refuted for pushes, pending one more test**: does the same `HStack` +
nested-stack composition mis-push in a *minimal* view outside this app's chrome? If it does, the
answer is a SwiftUI constraint and the design needs a detail pane that renders
`vm.navigationPath.last` directly — no nested stack, with Back supplied by the pane itself. That
is a different design from §2, not an adjustment to it, and it should be written before it is
built.

The work sits on `claude/f2-two-pane`, unmerged, with the diagnostic that produced these numbers
(`testDiagnoseBrowseContainerWidth`) kept on the branch so the next attempt does not rebuild it.

The detail pane's constant 138.0 across both representations is consistent with the *content* bar
being at 138 in both while `firstMatch` picks up the sidebar's own bar at 86 in the second — i.e.
finding (2) is the likeliest explanation of the 52.0, not a real gap. **Confirming that is the
next session's first ten minutes**, because if it *is* a real 52pt gap at the top of the detail
pane, it is a cosmetic defect the design should fix rather than inherit.
