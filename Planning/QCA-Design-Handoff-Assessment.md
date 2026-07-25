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

## Premise verification — clean

Every engineering anchor in the handoff was checked against the tree on 2026-07-25.
**Zero false premises** (the analytics handoff had three; this one was written against
the session plan, the design brief, and the integration assessment, and it shows).

| Handoff claim | Verdict |
|---|---|
| `MacSearchWindowView` in `App/SearchSheet.swift`, control rows + `sortBar`, timeline toggle in the sort bar | ✓ (`SearchSheet.swift:102,161,659`; toggle per v1.8 note) |
| `search.empty.detail` "Try different keywords…" is the zero-state copy to replace | ✓ (`SearchView.swift:629`; macOS empty state lives in `SearchSheet` — same replacement there) |
| iOS `timelineButton` + over-cap "Visualize in Corpus Analytics" in `SearchView` | ✓ (`SearchView.swift:399,41`) |
| macOS **Complete History** window exists, already project-filtered | ✓ (`frus.history` scene, `FRUSExplorerApp.swift:100,902` — the surface-5 home is exactly as assumed) |
| `makeMatchExpressions` (:196, discarded today) · `searchCount` (:153) · `PorterStemmer` (`SearchService.swift:113`) · `makeContextSnippet` (:362) | ✓ all land on-key |
| `SearchSQLFilters.documentIds` (`IndexingPipeline.swift:6567`) · `person_rollup` (:3938) · reach-count precedent (`SearchFilterView.swift:1173`) | ✓ |
| Component vocabulary: `AnalyticsCollapsibleSection` (controls never in the header-Button), `FeatureInfoButton`, chip grammar, North Star Settings grammar | ✓ all current idioms |
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
| Integration decision **B** (M-2 attribution home) | Untouched — engineering call at M-2 start (design works either way) |
| Integration decisions **C** (Q-V) / **D** (saved analytics queries) | Untouched — `6a–10a` unsettled; both remain plan-tail items |
| Q-1-1 / Q-3-1 / Q-3-2 | Not design questions; unchanged — but see flag 1 |

## Flags (all minor; none blocks; fold into the named session)

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
- **M-2 Query log** — 5a: Sessions · Queries lens on the existing log (macOS
  `frus.history` window retitled per project, iOS `SessionLogView`); star anatomy;
  absence-assertion rows with **both scope claims as separate lines**; re-run ↻ with
  inline diff chip ("re-ran just now: 46 — logged 44 · index grew 540 → 552");
  appendix export via `ResearchDataExporter` with the #454 project header. The
  "sessions aren't project-tagged" dependency is stated in the handoff itself and
  remains M-2 work (integration decision B).

## Where the artifacts live

The bundle stays in iCloud (`…/2026-06-30 FRUS Explorer Build 26 screenshots/
design_handoff_qca/`); consult `README.md` + the `1a`–`5a` anchors of the canvas at
each session's start. Shell access to that folder worked on 2026-07-25; if TCC
regresses, have the owner `cp -R` the bundle to `/private/tmp/claude-501/` (the
2026-07-24 workaround).
