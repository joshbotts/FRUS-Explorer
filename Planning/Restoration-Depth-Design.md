# What should survive a relaunch? (#754)

**Status:** owner decision required. Nothing is implemented.
**Source:** 2026-08 navigation & state audit, findings **H-6, M-21, L-45**.
**Written:** Session 2026-08-08, against `v2` @ `44c8f9ce`.

---

## 1. Measured, not assumed

The app's **entire** scene-restoration surface is four `@SceneStorage` declarations across three
distinct keys:

| Key | Where | What it holds |
|---|---|---|
| `frus.selectedTab` | `MainTabView` | which iOS tab was selected |
| `search.facets.shown` | macOS Search window | is the facet column extended |
| `search.inspector.expanded` | both Search surfaces | is the inspector card expanded |

That is all. There is **no** `stateRestorationActivity` anywhere; the two `.userActivity` sites set
only `isEligibleForHandoff`, which is a different feature. Every navigation holder is
process-lifetime `@State`: `BrowserViewModel.navigationPath`, `SearchViewModel` (query, filters,
results, its own path), `ResearchView.selectedItem`, `MainWindowView.navigationPath`,
`MacSearchWindowView.searchVM`, the Corpus Browser's `selectedSubseries`/`detailPath`.

**So this is a missing capability, not a malfunction.** Nothing is broken; the mechanism was never
built. That matters for how it should be scoped — and it is why the issue is labelled `enhancement`.

## 2. One thing here IS a plain bug (L-45)

`search.facets.shown` survives relaunch. The query, results and `FacetPanelController` it describes
do not. So the Search window can reopen with **the facet inspector extended over nothing** — the
persisted half is a description of the discarded half.

That is incoherent under *any* answer to the design question below, and it is cheap to fix. It
should not wait on the program decision.

## 3. What could survive — three mechanisms, very different costs

### A. Resume reading, from the trail that already exists

`ReadingHistoryEntry` is already a CloudKit-synced `@Model`, already queried most-recent-first in
four places. Offering "Continue reading: *<title>*" needs **no new persistence at all**.

- **Restores:** the document the researcher was in — the single most valuable thing lost.
- **Advantages over `@SceneStorage`:** survives reinstall, syncs across devices, and degrades
  honestly (a removed volume is a row you can filter, not a corrupt path).
- **Cost:** small. One query, one affordance.
- **Caveat:** it restores *the document*, not the path to it. Back from a resumed document goes to
  the Browse root, not through subseries → volume.

### B. Encode the navigation paths into `@SceneStorage`

- **Restores:** exact browse depth, search text and filters, per window.
- **Cost:** real. Every path element type needs a `Codable` representation, plus re-hydration that
  tolerates a volume removed since the snapshot. `BrowseDestination` and `SearchParameters` are the
  easy half; a restored path pointing at a deleted volume is the hard half, and getting it wrong
  produces a crash or a dead screen at launch — the worst possible moment.
- **Note:** `SearchParameters` is not `Codable` today (`SavedSearch` flattens it into columns), so
  search restoration needs that work first — the same gap #756 covers.

### C. macOS window-content restoration (M-21)

Same mechanism as B, multiplied across the main window, Search, Corpus Browser, the graph window and
Source Explorer. macOS already reopens the *windows*; only their content resets.

- **Cost:** the largest of the three, and the least differentiated per window.

## 4. Recommendation

**Do L-45 now** — it is a bug, not a preference.

**Then A (resume reading), offered rather than forced.** A researcher who was three levels into a
volume mostly wants *the document back*, not the ladder they climbed. Offering it as an affordance on
the Browse root — rather than auto-reopening — keeps the launch predictable, which is worth more than
the last 10% of fidelity. It reuses data the app already syncs, so it also works after a reinstall or
on a second device, which no `@SceneStorage` scheme can do.

**Defer B and C** until A has been lived with. If the resumed document turns out to be enough, B and
C are permanently unnecessary; if it is not, the gap will be specific and worth scoping properly. Do
not build path encoding speculatively — its failure mode is a bad launch, and launch is where this
app can least afford one.

## 5. If A is chosen — the shape

1. Query the most recent `ReadingHistoryEntry` whose volume is still indexed.
2. Surface it on the Browse root as a dismissible "Continue reading" row (iOS), and on the macOS main
   window's `DocumentPlaceholderView`, which today says only "Select a document to begin".
3. Tapping it opens the document through the existing routing — no new navigation path.
4. Nothing auto-opens. The launch a user sees is the one they expect.
