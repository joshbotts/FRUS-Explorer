# Q&CA × Projects — Integration Assessment

**Date:** 2026-07-25 · **Companion to:** `Consolidated-Development-Plan-2026-08.md`
(Workstream Q) and `Query-And-Corpus-Analysis-Session-Plan.md` · **Question:** where
should the Q&CA milestones integrate with the #377 project features that shipped
through Phase 5 (PRs #436–#462)?

**Method:** every claim below was verified against the working tree on 2026-07-25;
anchors are current. The recommendations sort into **riders** (absorbed into an
already-planned Q&CA session at small marginal cost), **new slices** (worth scheduling,
not free), **defers**, and **rejects**.

---

## The verified shapes (what each side actually is)

**Projects after #377.** A `Project` is an *activity lens, not a content container*
(`Models/Project.swift:14–24`): content stays global; activity records carry the tag
(`Collection.projectIds` at `Collection.swift:112`, `ResearchNote.projectIds`,
`ReadingHistoryEntry.projectId`). The project record itself carries `name`,
`researchQuestion`, default date range, `leadAxisWeights` (raw string,
`Project.swift:85`), and `defaultUserTagIds` (tag focus, `:95`). Around it:

- **Engaged set** — `ProjectEngagedDocuments` unions collection docs + anchored notes +
  visits into `"volumeId/documentId"` keys, *"the same identity the FTS5 `documentIds`
  filter matches on"* (`ProjectEngagedDocuments.swift:44–48`).
- **Three search scopes** — `ProjectSearchScope.off/.history/.focus`
  (`ProjectEngagedDocuments.swift:23–36`): history = recall over the engaged set;
  focus = discovery over subject-characteristic volumes, with an "only new" exclusion.
- **Leads** — per-seed related-document rankings (the #308 six-axis engine) summed
  across the project's seed (`ProjectLeadsAggregator.swift:28–60`), weighted per
  project, with dismiss/backfill semantics.
- **Session log** — `ResearchSession`/`SessionEvent` already auto-captures
  `searchSubmit(query:resultCount:)` (`ResearchSession.swift:25,47–48`) — but sessions
  are **not project-tagged** (no `projectId` anywhere in `ResearchSession.swift`), and
  the payload lacks the rendered expression, scope, and denominator.
- **Project-in-exports** — #454/#455 put `name` + `researchQuestion` into export
  headers; **Project Home** is the surfacing hub.

**Q&CA's project-relevant sessions.** M-1 working corpus explicitly plans to ride
`SearchSQLFilters.documentIds` — the plan's own text notes that plumbing was *"built
for Project History scope"*. M-2 plans a *"per-project query log"* homed *"with the
existing project surfaces (SessionLogView, SavedSearchesView)"*. R-1 facets compute
over whatever the current match is — including a History- or Focus-scoped match, for
free. S-1(Q)/D-1 build keyness and query-by-example machinery over arbitrary document
sets.

**The load-bearing convergence:** the engaged set, the History scope, and M-1's working
corpus all speak the same key grammar through the same SQL filter. Integration is
therefore a **model/UX question, not a plumbing project** — the pipes are already one
pipe.

---

## Opportunities

### I-1 · Working corpus ⇄ project (rider on M-1) — **adopt**

M-1 should ship project-aware from day one:

- **Attachment, not ownership.** `WorkingCorpus.projectIds: [UUID]` following the
  `Collection.projectIds` convention — the corpus stays global, the active project
  filters which corpora surface first (`Collection.swift:790–791` is the exact
  pattern). This deliberately does *not* revive dropped Phase 6: no auto-applied
  per-project default scope. Phase 6 died because volume-grain defaults were redundant
  with Focus + existing pickers; a *curated document-grain set the user explicitly
  built and explicitly applies* is a different object. Keep it explicit.
- **The three-scope story becomes coherent.** The scope menus' project section reads:
  **History** (dynamic — what you've engaged) · **Focus** (discovery — where your
  subjects point) · **your working corpora** (curated — what you've frozen). Each
  answers a different question; the design brief should present them as one family
  (brief updated, see *Impacts*).
- **Promotion defaults.** "Save as working corpus…" pre-attaches the active project;
  Project Home lists the project's corpora with their honest resolution line.
- **One new decision point (M-1-2):** should *promote from History scope* exist —
  freezing today's engaged set as a citable snapshot ("the 267 documents I had engaged
  on 2026-07-25")? Lean yes: it is the method-layer move (M-2's appendix can then cite
  a stable corpus, not a moving one), and it is nearly free once promotion exists.

*Cost:* one field + filtered queries + Home card; well under half a session. *Risk:*
CloudKit — `projectIds` on a definition-synced record follows M-1-1's chosen model (b)
cleanly.

### I-2 · Query log is the session log, enriched (rider on M-2, scope correction) — **adopt**

M-2 as written risks the #372 mistake — two parallel capture paths for the same event.
`searchSubmit` already fires on every search with `(query, resultCount)`. The
integration-correct M-2 is:

1. **Enrich the existing capture**: rendered FTS5 expression, scope descriptor
   (including `ProjectSearchScope` + working corpus if active), indexed-volume
   denominator, and **project attribution** — the piece that verifiably does not exist
   today (`ResearchSession` carries no `projectId`). Whether attribution lands on the
   event or on a new query-log model that references the session is M-2's call; the
   activity-tagging convention (`ReadingHistoryEntry.projectId`) is the precedent
   either way.
2. **The appendix header reuses #454/#455**: project `name` + `researchQuestion` head
   the exported method appendix exactly as they head collection exports. The D3
   provenance-preamble idiom is the visual kin.
3. **Project Home gets the receipt card**: "23 queries logged · 6 marked significant ·
   2 absence assertions" → the appendix view.

*Cost:* absorbed into M-2 (this narrows M-2, it doesn't grow it — the logger is
already running). *Correction to the Q&CA plan:* M-2's "new SwiftData model;
CloudKit-synced" stands, but it should be defined as an enrichment **around**
`ResearchSession`, never a second submit-hook in `SearchViewModel`.

### I-3 · Project-vocabulary leads (new slice, after Q-M3 S-1) — **adopt as Q-M5 sibling**

The highest-ceiling integration. D-1's query-by-example takes one seed document →
distinctive vocabulary → proposed query. Generalize the seed to the **project's engaged
set**: keyness of engaged docs vs corpus baseline (S-1 machinery, `fts5vocab`
denominators) → the project's distinctive vocabulary → run it as a query → documents
matching the project's *language* that the project has never touched. That is a lead
source no similarity axis can produce — the #308 engine relates document-to-document
metadata (provenance, cross-refs, people, dates); this relates to what the project is
*about*, as evidenced by its own accumulated text.

- **Present as a separate "Vocabulary leads" section**, not blended into
  `aggregateScore` — different provenance, different failure modes, and blending would
  make `leadAxisWeights` dishonest (it weights #308 axes; keyness is not one).
- Each vocabulary lead carries its evidence: the matched distinctive terms ("*matched:
  mobilization base, offshore procurement, counterpart funds*") — same
  explain-yourself discipline as `contributingSeedKeys`.
- **Sequencing:** needs S-1(Q) keyness + Q-3 `fts5vocab`. Slot alongside D-1 (they
  share the query-by-example core; build once, two entry points). Effort M.
- **Decision point:** minimum engaged-set size before the keyness is meaningful (a
  3-document project's "distinctive vocabulary" is noise) — floor it and say so in-UI,
  per the indexed-scope-honesty rule.

### I-4 · Facets profile the project (near-free rider on R-1) — **adopt**

Two entry points, one computation:

- **Free:** History-scoped search + R-1 facet panel already yields "the shape of what
  I've engaged" — zero extra work once R-1 lands, because History is just a filter and
  facets aggregate the current match.
- **Cheap:** a Project Home "corpus profile" card — top years / volumes / people of
  the engaged set — is the same facet aggregation invoked with
  `documentIds = engagedKeys`, rendered as a compact card that deep-links into the
  faceted search. One extra call site.

*Watch:* the engaged set can reference unindexed volumes (visits survive deletion);
facet SQL sees only indexed docs — the card states its denominator ("profile of 241
indexed of 267 engaged"), consistent with scope-honesty.

### I-5 · Inspector speaks project scope (tiny rider on Q-2) — **adopt**

When `ProjectSearchScope` ≠ `.off`, per-operand counts are within that scope; the
inspector labels it ("in your project history — 267 documents"). The zero-result
decomposition gains the most valuable variant: **dual-count the empty conjunct**
("*guarantee*: 0 in project history · 47 corpus-wide") — distinguishing "my project
hasn't touched this" from "the corpus lacks it", which is precisely the
recall-vs-discovery distinction the two scopes encode. Absence assertions (M-2) must
serialize the project scope for the same reason — a pinned zero means nothing without
it.

### I-6 · Excerpt verification from Project Home (rider on M-3) — **adopt**

M-3 already plans batch verification over a collection before export. Add the
project-grain entry point: "Verify quotations" on Project Home runs the pass over the
active project's collections + note quotations (activity-record filtered — the same
`projectIds` filter Collections' manager already applies). Report, never block
(M-3-1). Cost: one entry point over the same service.

### I-7 · Saved analytics queries ⇄ project — **defer to M-2**

D1 Phase 3's `SavedAnalyticsQuery` persists as JSON under plain `UserDefaults` keys
(`AnalyticsView.swift:97,103,237`) — device-local, unsynced, deliberately modest. Do
**not** project-tag it now: that would create a second project-query store one session
before M-2 defines the real one. When M-2 lands, revisit: either analytics saves
migrate into the query-log model (gaining sync + project attribution + appendix
presence), or they stay device-local scratch and the log records analytics *runs* like
searches. Decision belongs to M-2's session, with the store's migration cost measured
then.

### I-8 · Coding schemes are project objects (rider on D-2, when/if it runs) — **adopt in principle**

D-2's user-defined label scheme should live on the project (the scheme *is* the
research question operationalized); the label distribution becomes a Project Home
card; machine-vs-human fields stay distinct (D-2-1) so per-project inter-rater
reporting is possible. No change to D-2's experimental status or its position at the
plan's lowest-confidence tail.

### I-9 · Auto-corpus from Focus volumes — **reject**

"Freeze the Focus scope's volumes into a working corpus" recreates Phase 6's
redundancy with staleness added: Focus is *deliberately* dynamic (subjects → volumes
re-resolve as indexing grows), and a frozen volume-grain copy answers no question the
live scope doesn't. If a researcher wants a citable snapshot, I-1's promote-from-
History (document grain, things actually engaged) is the honest object. Rejecting this
keeps the three-scope story clean.

---

## What not to do (the boundaries that keep both systems honest)

1. **No ownership.** Working corpora, logs, and schemes are global content with
   project *tags*, per the architecture's own contract (`Project.swift:14–24`).
   Nothing in Q&CA should be reachable only through a project.
2. **No auto-applied project scope.** Phase 6 was dropped deliberately (2026-07-23).
   Every project scope remains an explicit user choice per surface.
3. **No second capture path** for searches (I-2) and no second saved-query store
   (I-7). Both classes of duplication have burned this codebase before (#372).
4. **No blending of keyness into `aggregateScore`** (I-3) — axis weights stay
   truthful about what they weight.

---

## Impacts on the two companion documents

**Consolidated plan (Workstream Q):** no slot changes. I-1/I-2/I-4/I-5/I-6 are riders
inside already-scheduled sessions (M-1, M-2, R-1, Q-2, M-3) — their session entries in
the Q&CA plan gain these as deliverable bullets/decision points at execution time.
I-3 adds one appetite-driven session beside D-1 in the 17+ tail ("Q-V — project
vocabulary leads"). The S-1-before-M-1 edge gains a second justification (Project Home
cards want S-3's list components too).

**Design brief:** updated in the same PR —
- the working-corpus surface (§4) now includes the promote-defaults-to-project flow,
  the three-scope family presentation (History/Focus/corpora as one designed section),
  and the resolution-honesty row states;
- the query-log surface (§5) now names the session-log relationship (enrichment, not a
  new logger), project attribution, and the #454-style appendix header;
- a new optional item: **Project Home cards** (corpus profile facets · query-log
  receipt · verify-quotations entry · vocabulary-leads section) as one composable card
  language;
- cross-cutting: any count shown under a project scope names the scope.

**Owner decision points surfaced by this assessment (none block Q-M1):**

| # | Decision | When it's needed |
|---|---|---|
| A | I-1 promote-from-History snapshot: in M-1's first cut, or follow-up? | M-1 session start |
| B | I-2 attribution home: enrich `SessionEvent` payload vs new model referencing sessions | M-2 session start |
| C | I-3 vocabulary leads: greenlight as Q-V beside D-1? (only item with real new cost) | after S-1(Q) ships |
| D | I-7 analytics saved queries: migrate into the log vs stay device-local scratch | M-2 session |
