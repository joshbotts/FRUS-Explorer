# M-4 — the macOS Search window chrome: design brief

**For a designer.** This describes what exists, what constrains it, and what must not be lost. It
deliberately proposes no design.

Everything below was verified against the code on 2026-08-15 by two independent readers, the second
tasked with breaking the first's citations. Where the original review finding is wrong, that is
stated — this program has repeatedly found review claims that did not survive contact with the
source, and a brief that inherited them would design for a window that does not exist.

---

## 1. What the surface is

The macOS Search window (`frus.search`, `SearchSheet.swift`, ~2,200 lines). It is the app's
primary research surface: a query field, a results list, and a **sort bar** of controls that change
how the results are read.

It opens at **820 pt wide** (`.defaultSize(width: 820, height: 680)`), and can be resized down to a
**640 pt floor**. The review says "opens at minWidth 640" — that is wrong, and the distinction
matters: 820 is the width to design for, 640 is the width that must not break.

## 2. What the review got right, and what it got wrong

| M-4 claim | Verdict |
|---|---|
| "no `.toolbar` at all — verified, zero occurrences" | **Holds.** One occurrence of the string in the file, and it is the comment asserting the absence. |
| the sort bar packs many controls | **Holds, but undercounts** — 11 interactive controls, not 8. |
| "most are icon-only" | **Half true.** Four of the eight sort-bar controls are icon-only (timeline, concordance, collocates, save-corpus); Facets and Checklist carry labels. |
| "meaning delivered exclusively via `.help` hover text" | **True for sighted users, false for VoiceOver.** Every icon-only button carries a state-dependent `.accessibilityLabel`. The gap is *sighted discovery only* — which is the same shape as findings P-2 and F-9 elsewhere in this review. |
| three of four "readings" toggles are mutually exclusive and hand-cleared | **Holds**, and the hand-clearing is the entire enforcement mechanism — three independent `@State` Bools, each responsible for clearing the other two. There is no type, no picker, no invariant. |
| "the sort bar is dense at minimum window width" | **Holds** — the code says so itself, and names its compression strategy. |

## 3. The controls, and how meaning is conveyed today

**Sort bar (8):** Facets *(labelled)*, Checklist *(labelled)*, timeline *(icon)*, concordance
*(icon)*, collocates *(icon)*, save-corpus *(icon)*, a page-size menu, and three hand-rolled sort
chips. Plus "Visualize in Corpus Analytics" and the Advanced button nearby.

Icon-only controls are `.system(size: 12)`, `.buttonStyle(.plain)`, and differ from their
neighbours only by SF Symbol.

**The exclusive group** — timeline / concordance / collocates — is signalled visually **only** by
the absence of `Divider`s between them and by accent tint on the active one. There is no shared
container, frame, or selection track. Save-corpus sits immediately after and is deliberately *not*
in the group: it is an action with a durable effect, and a `Divider` separates it.

## 4. The thing most worth fixing, stated plainly

**One SF Symbol convention carries two contradictory meanings inside this window.**

- `bookmark` vs `bookmark.fill` are **two different controls** — save this search, and open the
  saved-search list.
- `chart.bar` vs `chart.bar.fill` are **one control in two states** — timeline off, timeline on.
  Same for Advanced.

A reader who learns either rule will misread the other.

## 5. The house already has the answer to the exclusive group

The review frames the segmented picker as an iOS pattern the Mac would have to import. **It is
already inside this same window.** The Advanced popover (480×560, shared iOS/macOS code — not
iOS-only) contains a real segmented `Picker` for document type, with an accessibility label.

Two consequences for the designer: the picker is house-consistent rather than borrowed, and
**document type currently exists twice in one window**.

## 6. Hard constraints

1. **640 pt must not break.** Design for 820; verify at 640.
2. **VoiceOver must not regress.** The icon-only buttons announce state today. Hover text is *not*
   announced on macOS, so anything conveyed only by `.help` is invisible to a screen-reader user —
   but the labels are what carry them now, and they must survive.
3. **Type does not scale here.** The chrome is a fixed 8–14 pt scale.
4. **No keyboard route to any of these controls**, and no menu-bar equivalent. Adding one would be
   an improvement, not a regression — but their absence is why hover-only meaning is costly.
5. **Three source-scanning tests pin this surface** and will fail on a partial migration:
   - one pins the hand-clearing, and its branch already anticipates a picker — but adopting
     `selection: readingSelection` then *requires* the whole-triple assignment and the absence of
     the old toggle. **A half-migration fails the branch it just entered.**
   - one pins the sort bar's **order** (save-corpus must follow collocates), because the capture
     action once sat physically between two mutually exclusive readings.
   - one pins the concordance **glyph**, because macOS once showed for the inactive state the
     symbol iOS uses for the active one.

## 7. What must not be lost

This app has a recorded history of redesigns dropping a working affordance. Specifically preserve:

- every control's **current function** — the count above is the checklist;
- the **distinction** between the exclusive readings group and save-corpus, which is an action;
- **VoiceOver state announcements** on every control that has them;
- the ability to reach every control at **640 pt**.

## 8. Not in scope

The window's *results list* and query field. This brief is the chrome only.

---

*Grounding: `FRUSExplorer/App/SearchSheet.swift`, `FRUSExplorer/Search/SearchFilterView.swift`,
`FRUSExplorerTests/CollocationWiringAuditTests.swift`, `FRUSExplorerTests/ResultReadingTests.swift`.
A defect found during this inventory — a live "Include front matter" toggle that changed nothing —
was fixed separately rather than left for the redesign to inherit.*
