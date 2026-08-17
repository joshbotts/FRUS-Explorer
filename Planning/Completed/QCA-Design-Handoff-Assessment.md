# Q&CA Design Handoff — Assessment & Session Binding

**Date:** 2026-07-25 · **Bundle:** `design_handoff_qca/` (iCloud screenshots folder:
`README.md` + `QCA Design Review.dc.html`/`support.js` + 10 retina screens) · **Status
per bundle:** designs **1a · 2a · 3a · 4a · 5a settled**, all recommendations accepted
2026-07-25; canvas items `6a–10a` are unsettled sketches — **do not implement**.
**Purpose of this doc:** premise verification + the binding of each settled design onto
its Q&CA session, so slots 4/8/10/13/14 of
`Consolidated-Development-Plan-2026-08.md` start from here, not from a fresh read.

**The design hand-back the plan gated on (cross-lane edge 1) is CLEARED — received
before Q-1 even started.**

---

## Premise verification — **three corrections, 2026-07-29**

Every engineering anchor in the handoff was checked against the tree on 2026-07-25.
~~**Zero false premises**~~ **[2026-07-29: this claim was itself the first false
premise.]** Re-verified against the tree after R-2a/R-3/R-4/#548/O/S-1 shipped: **three
premises were wrong when written**, and two more anchor rows misdescribe the code. The
handoff is still unusually clean for its size — but "zero" was never true, and this
document is what every Q&CA session is told to start from, so its drift is the most
expensive in the set. Corrected rows are marked ⚠ below.

| Handoff claim | Verdict |
|---|---|
| `MacSearchWindowView` in `App/SearchSheet.swift`, control rows + `sortBar`, timeline toggle in the sort bar | ✓ (`SearchSheet.swift:102,161,659`; toggle per v1.8 note) |
| `search.empty.detail` "Try different keywords…" is the zero-state copy to replace | ⚠ **iOS only.** The string is at `Search/SearchView.swift:665`. **macOS has no zero-result empty state at all** — `App/SearchSheet.swift:171-200` branches checklist-all-reviewed → `showTimeline` → pending → `else { resultsList }`, so a zero-result search renders an empty `List`; the only zero-result copy is the sort-bar literal `Text("No results")` (`:820`). Surface 1's macOS zero state is a **new view in a new branch**, and the branch must sit *before* `} else if showTimeline {` (`:174`), which has no emptiness condition. `MacSearchViewModel` also has no `hasSearched` flag. |
| iOS `timelineButton` + over-cap "Visualize in Corpus Analytics" in `SearchView` | ⚠ anchors drifted — `timelineButton` is `Search/SearchView.swift:426` (used `:200`, `:534`); the over-cap string is `:784`. |
| macOS **Complete History** window exists, already project-filtered | ⚠ **superseded by Wave R-3 the day after this was written.** `HistoryWindowView` is now a four-line wrapper (`App/HistoryWindowView.swift:41-47`) around the cross-platform `HistoryView`, which iOS pushes from the Research tab (`:25-26`). Scene anchor is `App/FRUSExplorerApp.swift:919`. "Exactly as assumed" is retracted: the home is now **one shared view**, and the handoff's iOS half (`SessionLogView`) is a different, Settings-only stack — see flag 14. |
| `makeMatchExpressions` (:196, discarded today) · `searchCount` (:153) · `PorterStemmer` (`SearchService.swift:113`) · `makeContextSnippet` (:362) | ⚠ line numbers exact, **two descriptions wrong**. (a) `makeMatchExpressions` is *not* discarded — both `search()` (`:102`) and `searchCount()` (`:154`) consume it; what is discarded is the *rendered string*. It returns a **tuple** `(corpus:userContent:)` (`:198`) and `(nil, nil)` for a person-only query (`:213-221`) — a whole search mode with no expression to display. Under shipped defaults the two strings are **byte-identical**; they diverge only when exactly one of Notes/Summaries is off. (b) `PorterStemmer` at `:113` is the **snippet-highlight** path — query- and index-side stemming is SQLite's `porter unicode61` (`FTS5Store/FTS5InlineQueryParser.swift:472`). That is the two-stemmer hazard the consolidated plan names; it belongs here too. |
| `SearchSQLFilters.documentIds` (`IndexingPipeline.swift:6567`) · `person_rollup` (:3938) · reach-count precedent (`SearchFilterView.swift:1173`) | ⚠ first two ✓. The reach-count row is ✓ as a **display** precedent and ✗ as the **debounce** precedent the handoff uses it for (README:54, :133): `SearchFilterView.swift` contains no debounce at all, and its reach values are precomputed taxonomy counts (`:1146`, `:1155`); `:1173` is a bare closing brace. Real debounce precedents: `Settings/PersonCorrectionsView.swift:165-172` (closest shape), `ProjectContext/ProjectHomeView.swift:590-596`, `Collections/CollectionPreviewView.swift:256,393`. |
| Component vocabulary: `AnalyticsCollapsibleSection` (controls never in the header-Button), `FeatureInfoButton`, chip grammar, North Star Settings grammar | ⚠ two sub-claims fail. (a) The handoff's named Settings components ("NavRow/StatusRow") **do not exist** — the types are `SettingsNavRow` (`Settings/SettingsComponents.swift:425`) and `SettingsStatusRow` (`:320`). (b) The token table's chip grammar matches `ScopeChip` exactly, but `ScopeChip` is `private` and inside `#if os(macOS)` (`App/SearchSheet.swift:1448`), so "reuse" means **extraction**; and the clearable `NARROWED BY` chip is really `FilterChip` (`:1475`), a *different* grammar (radius 4, padding 6×2, accent 0.08). Also: `MacSearchWindowView` has **no `.toolbar` at all**, so README:70's "toggled from a titlebar inspector button" has no existing host. |
| Settings manager mock renders inside the North Star tree (Research group beside Volume Scopes) | ✓ — **assumes S-1 has landed**, which reaffirms the plan edge (M-1 after S-1) |

## Settled-decision crosswalk

Every open decision the session plan or the integration assessment left is now either
settled by the accepted design or explicitly untouched:

| Decision | State after handoff |
|---|---|
| Q-2-1 scoped vs corpus counts | **Settled as designed** — both on every pill ("41 in scope · 96 corpus ~"), `~` marks estimates, footer states the contract |
| Q-2-2 raw expression visibility | **Settled: always visible** — the MATCH row "never disappears"; chevron collapses rows 2–4 only |
| R-1-1 facet timing | **Settled: years eager** (feeds timeline), others lazy with skeletons; panel never blocks |
| R-1-2 facets vs checklist mode | **Settled: whole-match** + amber banner naming both numbers |
| R-3-1 occurrence grain | **Settled: one row per occurrence**, repeat marker "· 2nd", count line carries both totals |
| M-1-1 sync model | **Settled: definition syncs, devices re-resolve; divergence is loud** (amber in menu row, banner in editor) |
| M-2-1 log discipline | **Settled: auto-log + star-as-significant; appendix defaults to starred** |
| Integration decision **A** (promote-from-History in M-1 first cut) | **Settled: yes** — the promote sheet's History variant is first-class in 4a |
| Integration decision **B** (M-2 attribution home) | **[2026-07-29] CLOSED** — owner call. Both of B's branches named types R-2a removed; Wave R answered it in writing (`Wave-R-Research-Trail-2026-08.md:241-244`, "enrich `SearchHistoryEntry`") and `SearchHistoryEntry.projectId` ships stamped by both producers. The residual store-shape question is **Decision E** below — a new decision, not B re-homed. |
| Integration decisions **C** (Q-V) / **D** (saved analytics queries) | Untouched — `6a–10a` unsettled; both remain plan-tail items |
| Q-1-1 / Q-3-1 / Q-3-2 | Not design questions; unchanged — but see flag 1 |

## Flags

Flags 1–5 are the original minor ones (none blocks). **Flags 6–14 were added
2026-07-29** on re-verification against the post-R-2a/R-3/R-4/#548/O/S-1 tree; several are
not minor.

1. **Stem surface forms vs Q-3-1 (the one real wrinkle).** The 1a stem line renders
   "…12,431 docs corpus-wide ~ **(also guaranteed, guarantees)**". That parenthetical
   requires the stem→surface-forms map that Q-3-1 **deliberately deferred to D-1**
   (`fts5vocab` stores stems only). Resolution: **Q-2 ships the stem line count-only**
   (everything up to the paren — free via `fts5vocab`), and the "(also …)" clause
   lights up when D-1's cached map lands. The design needs no rework; the paren is
   additive. Record in Q-2's PR that the omission is deliberate.
2. **Cross-session controls need consistent gating.** 1a's zero state includes **"Pin
   as absence assertion"** with the handoff's own rule: *hidden until M-2 ships*. 2a's
   facet footer includes **"Save as working corpus…"** with no such note — apply the
   same rule: **hidden until M-1 ships** (not disabled — hidden; a dead button in a
   shipped build invites tester bug reports).
3. **One iOS toolbar reconciliation at R-3.** Surface 2 turns the actions-bar **chart
   icon** into a menu (Timeline · This result set); surface 3 turns the **timeline
   icon** into a three-mode menu. Fine sequentially (R-1 then R-3), but the R-3 session
   should land the final combined arrangement: one view-mode menu (List · Timeline ·
   Concordance) + the facet entry, whatever icon count that implies — don't ship two
   adjacent menus both containing "Timeline".
4. **Concordance export rides D3 machinery as-is.** `AnalyticsExportDelivery` +
   `filenameStem(title:prefix:)` already accept the `FRUS-Concordance` family prefix
   (built for the word cloud in D3 Phase 4a); the `#`-preamble comes from
   `AnalyticsProvenance` with `appliesDocumentDating: false`… **no** — a concordance IS
   date-scoped; use the standard provenance with the search scope + sort recorded in
   `extraCaveats`. Either way: no new export plumbing.
5. **Mock rendering artifacts are not spec.** 1a's HTML shows two clipped overlaps
   (the wrapped MATCH expression under the micro-tag; the footer over the stem line).
   Obvious layout bugs in the mock, not intent — SwiftUI wrapping supersedes.

### Added 2026-07-29

6. **The handoff's load-bearing self-contradiction — this *is* Decision E's mutability
   axis.** README:137 calls query-log rows "**immutable records**"; README:121 has the
   star "**tap toggles**"; README:123 adds a "Pin as absence assertion" promote link.
   Two in-place mutations of a row the same document calls immutable.
   **Resolution (owner-accepted 2026-07-29):** the contradiction is a category error.
   *The record of an execution is immutable; the researcher's annotation of it is not.*
   Both halves survive. Two supporting facts: the stated immutability is **already false
   in code** — `ProjectContext/ProjectAdminService.swift:97-100` rewrites `projectId` on
   live rows — and rows are individually deleted (`Models/HistoryPaneSnapshot.swift:580`).
   Note also that "every mutable model carries `lastModified`" is **not** the house rule:
   of 19 `@Model` types only 8 have one; `SavedSearch`, `DocumentHighlight` and
   `ProjectLeadEntry` are mutable without.
7. **Absence-assertion cardinality is settled at export, open in the store.** README:127
   "appear once per recorded scope claim" + the mock's two appendix rows for one query =
   a **1:N fan-out at export**, one list row bearing two claims. Only the store shape was
   open; see Decision E.
8. **The mock's expression prefix is a string the app cannot emit.** 05a's log row shows
   `{header dateline source_note body_text}: NEAR(…)` — those are the four corpus FTS5
   columns (`FTS5Store/FTS5Types.swift:22-25`), but the corpus expression renders with
   `columns: nil` → **empty prefix** (`Search/SearchService.swift:201,236-241`). The same
   mock's appendix table shows no prefix. Display what went to SQLite; a synthesized
   prefix makes the "Rendered expression" column non-reproducible.
9. **"552" is per-device, and the handoff says so.** README:56 ends "(Volume count is
   live.)"; the 4a editor mock uses 540-at-creation against 512-on-this-Mac. The
   denominator is `AppState.indexedVolumeIds` (`App/AppState.swift:1011-1020`), not the
   manifest's 552. Two consequences: log line 3 is "…**at log time**", a stored snapshot
   **nothing can back-fill**; and the working-corpus payload needs a creation-time
   denominator, which neither README:113 nor M-1-1(b) lists.
10. **Q-1 is missing from the handoff's session list, and it is load-bearing.** README:15
    names Q-2/R-1/R-3/M-1/M-2 and never Q-1 — yet every surface-1 and surface-5 mock uses
    `NEAR("military guarantee" europe, 30)`. `NEAR` is **unimplemented and documented as
    such** (`FTS5Store/FTS5Query.swift:26`); the shipped parser renders that string as
    `"near" AND ("military guarantee" AND "europe," AND "30")`. So Q-1 is a prerequisite
    for the design's own copy, not only for pedagogy. The live interleave already honours
    it (Q-1 slot 2, Q-2 slot 4).
11. **iOS swipe collision.** The handoff puts "Significant" on the **trailing** swipe
    (README:121 + iPhone mock). That slot is already the destructive Delete, which exists
    because `SearchHistoryEntry` previously had no delete path at all — "a privacy gap
    rather than a polish item" (`History/HistoryView.swift:392-397`). The star's shortcut
    takes the **leading** edge, or the privacy control is displaced.
12. **Flag 2 is contradicted by its own mock.** Flag 2 settles "Pin as absence assertion"
    as hidden until M-2. `screenshots/01a-inspector-strip.png` renders it **live and
    enabled**, captioned "Pinning records this zero — query, scope, denominator, date —
    in the project query log (5a)" — which is also the tightest enumeration of Decision
    E's required fields anywhere in the bundle. Implementing Q-2 from the screenshot
    ships a dead button. **The prose is binding.**
13. **The pin occupies the star's gutter slot, so the default export subset is
    undefined.** In 05a the leading gutter is a red pin on the absence row and a star on
    the others — one slot, two mutually exclusive glyphs — while README:127 says the
    appendix "defaults to the significant subset" and the preamble counts significant
    queries and absence assertions as **separate** populations. Whether an unstarred
    absence assertion is in the default export is unsettled. Two booleans or one enum;
    folded into Decision E.
14. **`resultCount` is not currently a fact, and the appendix has a Hits column.** iOS
    caps at 1,000 (`Search/SearchViewModel.swift:402,590`). macOS reads
    `(try? await countTask) ?? fetched.count` then `max(total, fetched.count)`
    (`App/MacSearchViewModel.swift:709-711`) against a 7,500-row fetch (`:204`) — so
    whenever the concurrent `COUNT(*)` throws or is cancelled, which at 6–12 s per
    common-term query is the realistic path, the **logged number is 7,500**. Both row
    shapes sync into one log with nothing distinguishing them. `resultCountIsExact` is
    the cheapest honesty fix in the M-2 set.

## What each session now inherits (binding)

- **Q-2 Query Inspector** — 1a strip (macOS, between control rows and `sortBar` in
  `SearchSheet.swift`) + iOS disclosure card; five states (empty/building/results/
  zero/count-pending); zero-result decomposition **replaces** `search.empty.detail`
  on both platforms; dual-count pills with 300 ms debounce (reach-count precedent);
  stem line count-only (flag 1); "Pin as absence assertion" hidden (flag 2); the
  purple-operator mono treatment maps to `FRUSTheme` tokens per the handoff's token
  table (semantic colors, no hardcoded light hexes). *Effort note: Q-2 grows from M
  toward M+ — the strip, the iOS card, and the empty-state redesign are three
  surfaces, but all read-only over data the session already computes.*
- **R-1 Facets** — 2a panel: macOS trailing `.inspector` (~300 pt, Query + Facets
  tabs), iOS "This result set" sheet; five `AnalyticsCollapsibleSection`s with the
  specified per-facet anatomy (Years histogram eager; Volumes proportional fills +
  in-place top-N expansion; People rollup-resolved with search-within; Type;
  Provenance lazy + coverage caveat); `NARROWED BY` chip row; checklist banner;
  footer per flag 2.
- **R-3 Concordance** — 3a: three-segment mode control (macOS sort bar; iOS menu per
  flag 3); "71 results · 104 occurrences" count line; four-column row anatomy with
  fixed term column; row-tap opens **at the occurrence**; hover-popover for truncated
  contexts; CSV/Markdown export per flag 4; iPhone single-line clipped rows,
  no horizontal scroll.
- **M-1 Working corpus** — 4a: promote sheet (+ first-class History variant, decision
  A settled); the **scope-menu family retrofit** — every scope menu (Search filters,
  three analytics views, Word Cloud, facets) gains the PROJECT / WORKING CORPORA /
  MY VOLUME SCOPES sections with role glyphs, live-vs-frozen captions, and in-menu
  divergence amber — *this retrofit is the session's hidden bulk; budget it*;
  Settings → Research → Working Corpora manager + editor with the amber
  resolution-divergence banner and explicit re-resolve consequence line.
- **M-2 Query log** — 5a: Sessions · Queries lens on the existing log; star anatomy;
  absence-assertion rows; re-run ↻ with inline diff chip ("re-ran just now: 46 —
  logged 44 · index grew 540 → 552"); appendix export via `ResearchDataExporter` with
  the #454 project header.

  **[2026-07-29] Four corrections to this entry.**
  1. **The two named homes are two different view stacks.** `HistoryView` /
     `HistoryPaneSnapshot` (project-scoped, paged, per-row delete) hosts both the macOS
     Complete History window and the iOS Research-tab push. `SessionLogView` /
     `ResearchTrailSessions` is **Settings-only** (`Settings/ResearchSessionsView.swift:107,123`),
     snapshot-derived, with no stored rows to annotate, and
     `activities(in:limit:)` takes no scope at all (`:215`). "Segmented Sessions ·
     Queries with a project filter" means unifying two snapshot types **and**
     relocating a Settings-only surface, on both platforms. See flag 14.
  2. **"Both scope claims as separate lines" is the iPhone mock.** The settled macOS
     list draws them on one line, middot-separated. The assessment repeated the prose,
     not the mock.
  3. **Re-run is keywords-only today** — `SearchParameters(keywords: row.queryText)` at
     `History/HistoryView.swift:475,480` **and a third site no document names**, the
     macOS History menu at `App/HistoryWindowView.swift:133`. So the amber diff chip
     would silently attribute a dropped date range or volume scope to index growth.
  4. **The attribution dependency is half discharged, and the remaining half is a
     modelling question.** Searches carry `projectId`; `DerivedResearchSession`
     (`Models/ResearchTrailSessions.swift:87`) does not — it lives one level down on
     `ResearchTrailActivity` (`:63`). A session is a pure time window and can span
     projects, so "project-tagged sessions" is a decision, not a lookup. Also
     `HistoryScope` defaults to `.all` (contract D4, `Models/HistoryPaneSnapshot.swift:32`),
     and every row re-homed from a legacy `SessionEvent` was written `projectId: nil`
     (`Models/ResearchTrailMigration.swift:374-379`) — so a project-scoped log silently
     omits every pre-R-2a search.

## Where the artifacts live

The bundle stays in iCloud, and **[2026-07-29] it is now zipped**:
`…/2026-06-30 FRUS Explorer Build 26 screenshots/QCA Design Review handoff.zip`, which
extracts to `design_handoff_qca/` (README.md + `QCA Design Review.dc.html` + `support.js`
+ 11 screenshots, 5.4 MB). Unzipping to the session scratchpad reads fine and needs no
TCC workaround — the zip itself is shell-readable where the folder sometimes was not.
Consult `README.md` **and the screenshots** at each session's start: flags 8, 12 and 13
above all come from mock detail the prose omits or contradicts, so reading the prose
alone is not sufficient.

If direct access ever regresses, have the owner `cp -R` the bundle to
`/private/tmp/claude-501/` (the 2026-07-24 workaround).
