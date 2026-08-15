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
