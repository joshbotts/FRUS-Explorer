# F-2 — two-pane Browse and Research at regular width: the design

Owner decision 2026-08-15 (STATUS.md §3a): Browse and Research gain a plain two-pane content
layout at regular width, following `CollectionEditorView.iPadCollectionLayout`, honouring #238's
rule that a tab's content hosts a `NavigationStack` and never a `NavigationSplitView`.

This document is the mapping that has to exist before that is built. It was produced by two
independent readers per surface, the second prompted to break the first's plan; **every plan in
the first pass was materially wrong in at least one load-bearing way**, which is the argument for
writing this down rather than starting from the review's one-line recommendation.

**Status: §2's shape is REFUTED (§6a). §7 is the replacement, and it is unbuilt.** Read §6a and §7
before touching this — §2–§5 are kept because their surgery list, gate and test analysis all still
apply, but their *shape* does not.

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

## 6. The probe has been run — and its conclusion was too strong (see §6a)

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

---

## 6a. The probe was necessary and NOT sufficient — §2's shape is refuted

**§6 concluded the shape was viable. Building it showed that conclusion was too strong, and the
fault was in the probe's design rather than in its numbers.**

The probe measured the composition **at rest** — two panes, nothing pushed. It never opened a
level. Built out and driven on the same 1032×1376 iPad, the layout is correct at rest and **fails
on push**:

| state | evidence |
|---|---|
| at rest | detail placeholder present; list-pane row at `(16, 138, 308, 52)` — two panes, correct |
| after opening a subseries | cells at `(20, 175, **992**, 93.5)`, `navBars=1` — **full container width** |

The nested `NavigationStack`'s pushed destination expands to the whole content area instead of
staying inside the detail pane, so the list pane is replaced exactly as the single-column layout
would replace it. **The two-pane exists only until the reader uses it.**

Candidate cause — the detail stack lacking a bound of its own — was **tested and refuted**: an
explicit `.frame(maxWidth: .infinity, maxHeight: .infinity)` plus `.clipped()` left the pushed
cells at 992pt. So the cause is not a missing constraint on that view; a `NavigationStack` inside
an `HStack` appears not to constrain its pushed destination at all.

**The lesson is about the probe, not the layout.** A composition probe has to exercise the
composition's *purpose*. This one asked "does a nested stack sit correctly beside a list?" when
the question that decides the design is "does a nested stack **push** correctly beside a list?"
The safe-area numbers in §6 remain true and remain beside the point. §7.5 encodes the correction.

The work, the corrected scenario and the diagnostic that produced these numbers sit on
`claude/f2-two-pane`, unmerged.

---

## 7. The new design: the detail pane renders the path, it does not push it

§2's shape is refuted for pushes (§6a). This replaces it.

### 7.1 The idea, in one sentence

**At two-pane width there is no second navigation container. The detail pane renders
`levelView(for: vm.navigationPath.last)` directly, and navigation is array mutation — which is
what it already was.**

### 7.2 Why this fits Browse specifically

§1's enabling fact is worth restating, because it is what makes this design ordinary rather than
clever: **Browse contains no `NavigationLink`s at all.** Every row from the corpus root to the
document level is a `Button` that mutates `vm.navigationPath`. The `NavigationStack` has never
been how Browse *navigates* — only how it *presents*. Selection was already an array operation;
this design stops wrapping that array in a container whose job is to cover the screen.

That also explains why §2's shape failed in the way it did. A `NavigationStack` exists to present
one thing at a time over its container. Asking two of them to cooperate inside an `HStack` asks
each to be smaller than its purpose, and iPadOS declined.

### 7.3 What the detail pane must supply

Removing the stack removes three things it was providing. Each has an answer, and the third is the
one that decides whether this design is cheap or expensive.

**1. Back.** Trivial: `vm.navigationPath.removeLast()`, shown when `navigationPath.count > 1`. It
is more honest than the stack's Back, which in a two-pane would have offered to pop to a corpus
root that is *already on screen in the list pane*.

**2. Transitions.** A direct render has no push animation. `.transition(.move(edge: .trailing))`
on the detail content is the cheap approximation; doing nothing is also defensible for a pane that
changes in place. **Not a blocker, and not worth solving first.**

**3. Titles and toolbars — the load-bearing one.** `SubseriesView` (`:82`, `:89`), `VolumeView`
(`:98`, `:116`) and `CompilationView` (`:177`, `:184`) each set a `navigationTitle` **and** a
`.toolbar`. With no inner container these resolve against the **outer** stack, which means:

- the outer bar's title becomes the current level's title, and
- the outer bar's toolbar becomes the three persistent Browse items **plus** whatever the level
  contributes.

The first is desirable — it is how a split view names where you are. The second needs measuring:
`analyticsToolbarItems` is already a menu plus two buttons, and `VolumeView` adds its own. **The
open question is whether the combined bar overflows at 1032pt**, and the answer is a screenshot,
not an argument.

If it does overflow, the fallback is to give the detail pane a lightweight header of its own
(title + Back as ordinary views, not bar items) and pass `showsNavigationChrome: false` down to
the levels — the same shape as the `showsWorkingOnSubtitle` flag already threaded through them,
so the mechanism is established rather than new.

### 7.4 What carries over from §3 unchanged

Items 1 (`select(_:)` replacing the path), 2 (measured-width gate), 3 (plain `if/else`, never
`AnyView`) and 4 (suppress one pane's `workingOnSubtitle`) are all still required and are all
already written on `claude/f2-two-pane`. Item 5's warning also still holds: **do not splice the
path.** The detail renders `path.last`; `pushInBrowseStack`'s `removeLast()` arithmetic and
`activateTagFilter`'s pop keep working precisely because the array stays whole.

`navigationDestination` stays on the single-column path and is simply unused at two-pane width.

### 7.5 The probe for THIS design, and the lesson it encodes

**The probe must push.** §6's probe measured the composition at rest, pronounced the shape viable,
and was wrong — not in its numbers but in its question. A composition probe has to exercise the
composition's purpose.

So the probe is: at two-pane width, open a subseries, then a volume, then a compilation, and after
**each** step assert that cells exist on both sides of the divider. That is three pushes deep,
which is where a container that quietly takes over will reveal itself. `testBrowseIsTwoPaneOnWideiPad`
on the WIP branch already does the first step and has the divider arithmetic; extending it is the
work of minutes.

Its companion assertion is the one that would have caught §6a immediately: **`app.cells` must
never be wider than the detail pane.** A cell at 992pt in a 1032pt window is the defect, stated
directly.

### 7.6 The cheaper alternative that deserves one probe first

**Re-test `NavigationSplitView` on iPadOS 26 before building any of this.**

#238's revert is the reason the split is forbidden, and #238 is a finding about an *older OS*. The
nested-stack composition it warned against turned out to sit correctly at rest on 26.3 (§6), which
is at least a hint that the platform has moved. `BrowserView.splitLayout` still exists,
unreferenced, and restoring the `sizeClass == .regular` branch is a one-line experiment.

If a nested `NavigationSplitView` now behaves under `.sidebarAdaptable` — measured with the §7.5
probe, pushes included — it is a better answer than §7.1 on every axis: it is the platform's own
two-pane, it supplies Back and titles and transitions for free, and it deletes rather than adds
code. **It should be tried first**, and it costs one probe run.

The order for the next session is therefore: §7.6's split probe, then §7.1 only if the split still
misbehaves.

---

The detail pane's constant 138.0 across both representations is consistent with the *content* bar
being at 138 in both while `firstMatch` picks up the sidebar's own bar at 86 in the second — i.e.
finding (2) is the likeliest explanation of the 52.0, not a real gap. **Confirming that is the
next session's first ten minutes**, because if it *is* a real 52pt gap at the top of the detail
pane, it is a cosmetic defect the design should fix rather than inherit.
