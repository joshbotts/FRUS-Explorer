# Design Requirements — Query & Corpus Analysis UI

**For:** Claude Design · **Date:** 2026-07-25 · **Commissioned by:**
`Planning/Consolidated-Development-Plan-2026-08.md` (Workstream Q) · **Feature
source:** `Planning/Query-And-Corpus-Analysis-Session-Plan.md` (read it first — every
surface below has a session there with full data-model detail; this brief covers only
what design needs).

**The product move these surfaces serve:** the app is very good at *finding a document*
and has almost nothing for *characterizing a set*. Two enabling ideas — make the query
legible, and make the result set a first-class object. The audience is working
historians who publish method appendices; honesty affordances (denominators, bounds,
indexed-scope caveats) are content, not chrome.

---

## What is settled and OUT OF SCOPE for this pass

Do not revisit these; they are recent, deliberate, and in some cases just shipped:

1. **Settings** — fully settled by the 2026-07-24 North Star handoff
   (`design_handoff_settings_northstar/`, options 1c/2a…11a). New surfaces below that
   need a Settings home (working corpus) must *slot into* that tree (Research group,
   beside Volume Scopes) using its shared components (NavRow, editor grammar) — not
   introduce new settings idioms.
2. **The analytics dashboards** — Corpus / Person / Cross-Reference just completed a
   full design program (9 quick wins + compare terms + research-grade export, PRs
   #466–#479). Their idioms are the *vocabulary to reuse*, not surfaces to rework:
   `AnalyticsCollapsibleSection` (controls live in a `controls:` strip, never in the
   header — the header is itself a Button), `FeatureInfoButton` popovers,
   per-section Export menus, provenance-stamped CSV/figure export, 44 pt targets.
3. **The document research rail** — the old macOS "research strip" no longer exists;
   the rail (`ResearchRailView`) replaced it across all platforms, with a titlebar
   collapse on macOS. GitHub issues predating this (e.g. #368's document-view bullet)
   are mooted; do not design against screenshots showing the strip.

**Platform frame to design within:** iOS `MainTabView` (Search tab; iPhone compact
width is real — prior lesson: iPad *sheets* are compact-width too, ~540 pt, so
multi-chip rows use `ViewThatFits`, never size-class checks); macOS dedicated Search
window (`SearchSheet` — a **separate implementation** from iOS SearchView, so every
surface needs an explicit macOS placement, not "same as iOS"); Dynamic Type; VoiceOver
labels on all counts.

---

## Surfaces requiring design

Priority order = implementation order. 1–3 are schedule-critical (needed by Q-2/R-1/R-3
sessions); 4–5 follow; 6–9 are optional/opportunistic.

### 1. Query Inspector (session Q-2) — the flagship

**Job:** "Show me what my query actually did — and when it returns nothing, tell me
*which part* killed it."

**Content (all already computable):**
- the rendered FTS5 MATCH expression (e.g. `("military guarantee" NEAR Europe, 30) AND year:1948`);
- per-operand hit counts within the current filter scope;
- each term's Porter stem with corpus document-frequency ("*containment* → **contain** —
  12,431 documents"), flagging stem collisions;
- zero-result decomposition: when a conjunction returns nothing, name the empty conjunct;
- live operand counts while the query is being built (debounced; precedent:
  `SubjectCategoryFacetPicker`'s reach counts).

**Placement to solve:** iOS = a disclosure below the search field; macOS = popover or
inspector pane off the search field. Settled decisions to honor: the raw expression is
**always visible**, not behind a "technical detail" toggle (Q-2-2); scoped-exact vs
corpus-estimate counts are both shown and **labeled as which is which** (Q-2-1 — the
difference between them is itself information).

**States:** empty query · building (live counts) · results (expression + counts) ·
zero-result (decomposition featured, not an afterthought) · count-pending (debounce).

**Design questions:** How does the inspector coexist with the existing filter chips and
saved-search UI without becoming a second filter panel? What does the stem line look
like when a query has six terms? Is the zero-result decomposition inline in the empty
state (replacing today's "Try different keywords" copy) or inside the inspector?

### 2. Result-set facet panel (session R-1) — the anchor

**Job:** "My 412 hits: 60% in three volumes, spiking in 1948, Hickerson in 31 —
click any of those to narrow."

**Facets (computed in SQL over the match):** year/decade · volume/subseries · person
(rollup-resolved) · document type · archival provenance (with its honest coverage
caveat). Each row = label + count + click-to-narrow (applies through the existing
filter model, so facets and the filter sheet can never disagree).

**Placement to solve:** macOS = inspector column beside results; iOS = sheet or an
extension of the existing filter surface; there is precedent in the results/timeline
toggle (`SearchView` mode switch). Bounds are **surfaced, not silent** (top-N per facet
with a "showing top 12 of 47" affordance).

**Settled:** facets describe the **whole match**, with a visible note when checklist
mode hides rows (R-1-2). Year facet may render eagerly (it feeds the existing timeline);
the rest compute lazily when the panel opens (R-1-1) — design the loading state that
implies.

**Design questions:** one panel with five sections vs a segmented facet picker? How
does an applied facet read back in the chip row? What does the person facet do with 200
names (search-within-facet?)?

### 3. KWIC concordance (session R-3)

**Job:** "Read 400 hits in ten minutes — one aligned column of every occurrence."

A third results mode beside list and timeline: term-aligned rows (left context · **term**
· right context), monospaced-ish alignment on the hit, sortable by left context / right
context / date / volume; **one row per occurrence** (a document hitting nine times shows
nine rows — that's the point); row-tap opens the document at that occurrence; export
(CSV/Markdown) rides the existing export affordances.

**Design questions:** How does the mode switch scale from two modes to three (list ·
timeline · concordance) on iPhone? Alignment strategy at compact width — center-pinned
term with truncated contexts, or horizontally scrollable gutters? How is the sort
control presented (the existing analytics `controls:`-strip idiom is available)?

### 4. Working corpus — promotion flow + presence (session M-1)

**Job:** "These 267 documents are now *my OSP corpus* — run everything else inside it."

**Pieces:**
- a **promote** affordance on a result set / saved search / collection ("Save as
  working corpus…") — naming sheet with an honest scope line ("267 documents · resolved
  against 552 indexed volumes · 2026-07-25"). **Project-aware:** the sheet pre-attaches
  the active project (removable chip — attachment is a tag, never ownership), and
  promoting **from the project History scope** is a first-class variant (freezing
  today's engaged set as a citable snapshot);
- **presence everywhere scopes appear**: the scope menus in Search, Analytics, Word
  Cloud, and facets already list "My Volume Scopes" — working corpora join as a sibling
  section at document grain. Design the row (name · document count · staleness hint).
  **The project section of the scope menus must read as one designed family of three**:
  *History* (dynamic — what you've engaged) · *Focus* (discovery — where your subjects
  point) · *working corpora* (curated — what you've frozen). Each answers a different
  question; today's pickers grew separately and it shows;
- a **manager** in Settings → Research beside Volume Scopes, adopting the North Star
  list grammar (row → editor; counts on rows; "New …" ends the list) — the editor shows
  the definition (query + scope + snapshot date) and a re-resolve action, per the
  settled sync model (M-1-1: the *definition* syncs, devices re-resolve locally, and a
  differing local resolution is **visible, not silent** — design that state).

**Design questions:** What does "this corpus resolves to 241 documents here, 267 at
creation" look like on the row and in the editor? Where does promote live on iPhone
(toolbar? the facet panel's footer?)? How does the three-scope family read in a compact
menu without a paragraph of explanation?

### 5. Query log & method appendix (session M-2)

**Job:** "Every query I ran, with its real hit count and scope — including the zeros —
exportable as the appendix a published piece needs."

Auto-logged per project (query · rendered expression · scope · indexed-volume
denominator · timestamp · hit count); manual **mark-as-significant**; absence assertions
(a pinned zero) as first-class entries; export defaults to the marked subset. Homes with
the existing project surfaces (`SessionLogView`, `SavedSearchesView`) — not a new
top-level screen. The provenance-preamble idiom from the D3 export work is the visual
kin for the exported appendix.

**Engineering context that shapes the design:** the app *already* auto-captures every
search (`searchSubmit` session events carry query + result count) — this surface is an
**enrichment of that existing log**, not a new logger, so the design should treat the
session log and the query log as one narrative with two lenses, not two lists. Project
attribution is being added as part of this work (sessions are not yet project-tagged).
The exported appendix header carries the project's name + research question, exactly as
collection exports already do. An absence assertion records its full scope **including
the project scope** — "0 in project history" and "0 corpus-wide" are different claims,
and the design must keep them visually distinct.

**Design questions:** How does mark-as-significant read in a dense log list? How is an
absence assertion visually distinct from an ordinary zero-hit log row? Re-run affordance
(a logged query is one tap from running again — with the diff against the logged count
shown when it lands)?

### 6–9. Optional / opportunistic (design if cheap, else defer)

6. **Keyness mode toggle** (session S-1(Q)): a raw-frequency ↔ keyness switch on the
   existing word cloud + a one-line measure disclosure ("log-likelihood vs corpus
   baseline; terms under N occurrences floored"). Smallest possible surface; the cloud
   itself does not change.
7. **Vocabulary explorer** (session D-1): browse/filter the corpus term dictionary
   (stem · doc frequency · occurrences · surface forms when cached); click-to-add to
   query. Could be a sheet off the Query Inspector's stem line. Low confidence — a
   direction sketch suffices.
8. **Manuscript-repository guidance card** (#354d): when a source note names LoC/NDU/
   CMH/NHC etc., Source Explorer today issues a NARA query guaranteed to miss; design
   the small static card that instead names the actual repository and its finding-aid
   path. One card, a few states.
9. **NARA Lookup candidate picker** (#235): selection → analyzed context → ranked
   candidate resolutions (each with the evidence that produced it), manual lookup as
   fallback. Direction sketch only; engineering scope is still being set.
10. **Project Home cards for the Q&CA layer** (rides sessions R-1/M-1/M-2/M-3; see
    `QCA-Projects-Integration-Assessment.md`): a corpus-profile card (top years /
    volumes / people of the engaged set, with its indexed-vs-engaged denominator), a
    query-log receipt card ("23 logged · 6 significant · 2 absence assertions"), a
    verify-quotations entry point, and — later — a "Vocabulary leads" section beside
    the existing #308-axis leads, each lead carrying its matched distinctive terms.
    Ask: one composable card language for all of these, consistent with the existing
    Project Home summary cards, rather than four bespoke tiles.

---

## Cross-cutting requirements (bind every surface)

- **Denominators and bounds are UI content.** Every count states its scope ("in your
  412 results" / "corpus-wide, 552 indexed volumes"); every cap is visible when hit;
  "0 results" always reads as "0 in what you have indexed."
- **Counts agree or say why.** A scoped count and an unscoped estimate may differ; if
  both appear, both are labeled (Q-2-1). Nothing silently mixes document counts with
  occurrence counts — the distinction is itself a designed element (R-2 exposes it).
- **One interaction grammar with what shipped:** collapsible sections with a
  `controls:` strip; info via `FeatureInfoButton`; export via the per-section Export
  menu; chips for applied filters. New grammars need a reason.
- **Compact width is first-class** (iPhone, iPad sheets at ~540 pt): `ViewThatFits`
  patterns, no size-class assumptions.
- **Project scope is named wherever it filters.** Any count rendered under a project
  scope (History / Focus / a working corpus) says so — the recall-vs-discovery
  distinction is content, and "0 in project history · 47 corpus-wide" is the designed
  form of a zero under scope.
- **Accessibility:** Dynamic Type throughout; ≥44 pt targets; VoiceOver labels that
  speak the full fact (count + scope), matching the analytics precedent.
- **Copy tone:** the app's existing methods-honesty register (see the D3 export
  preambles and the analytics info popovers) — plain, specific, no hedging boilerplate.

## Deliverable format

Match the Settings North Star handoff package, which worked well: a `README.md` with a
settled-decisions table and per-surface notes with file anchors; an interactive
`*.dc.html` with anchor-linkable option ids (two options per contested surface —
priority surfaces 1–3 each warrant an A/B; 4–5 can go straight to a single
recommendation); retina screenshots per settled mock, iOS + macOS both, iPhone compact
included for surfaces 1–3. Flag any place where a requirement above conflicts with a
better design idea rather than silently complying — send-backs on false premises have
been caught and fixed before, and are welcome.
