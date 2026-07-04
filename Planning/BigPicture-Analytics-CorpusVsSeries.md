# Big Picture: Analytics Architecture — Corpus Analytics vs. Series Analytics

**Date:** 2026-07-03 (roadmap statuses updated 2026-07-04)
**Status:** Blueprint. A subset is now scheduled — see
[`Analytics-Session-Plan.md`](Analytics-Session-Plan.md) (2026-07-04), which formalizes the
enabling prep + the whole Series feature + four Corpus content sessions. The remaining
priorities (8, 10, 11, 12) are **postponed** — marked in the roadmap table below.
**Supersedes:** `BigPicture-CorpusAnalytics-Roadmap.md` (2026-07-02) — this revision splits that
roadmap's 12 recommendations across two distinct features.

## The split

App analytics divides cleanly into two features with different questions, data, and homes:

- **Corpus Analytics — *what the series contains.*** Document-content analysis: term
  frequency, people mentioned, places, topics, citations between documents. Stays where it
  lives today (the Browse → "Analysis Tools" menu on iOS; the `frus.analytics` /
  `frus.wordcloud` windows on macOS).
- **Series Analytics — *how the volumes were produced.*** Metadata analysis of the series
  as a publishing artifact: production output, timeliness/lag, editorial organization, and
  how the underlying archival sourcing changed over time. Becomes an **interactive part of
  the Research Guide** (`ResearchGuideView` / `IndexingEducationView`; macOS
  `frus.researchGuide` Help window, iOS Settings sheet).

The line between them: if a chart answers "what did US foreign policy *say/do*," it is
corpus. If it answers "how did the *Office of the Historian build and publish* this
series," it is series.

### Sources reviewed

1. **Office of the Historian, *Toward "Thorough, Accurate, and Reliable"*, Appendix A:
   Historical FRUS Timeliness and Production Charts** —
   <https://history.state.gov/historicaldocuments/frus-history/appendix-a>
   The series' own production history: publication lag between the year covered and the
   year published (the post-1914 "release deficit"), and volume output per year. Companion
   [Annual FRUS Production and Timeliness Data](https://history.state.gov/historicaldocuments/frus-history/research/production-and-timeliness-data).
   → **feeds Series Analytics.**

2. **Hensler, "'It's Late': How FRUS Volume Organization Teaches History (and Makes a
   Massive Backlog)," *DttP: Documents to the People* 54, no. 1 (2026)** —
   <https://journals.ala.org/index.php/dttp/article/view/8675/12036>
   Volume organization as data: ~5.89 volumes per administration year, the 25-year
   backlog, the 20th-century Europe emphasis, and inconsistent regional naming.
   → **primarily Series Analytics** (organization/production); its content-coverage angle
   also informs a Corpus geographic view.

3. **Özsoy, Salamanca, Connelly, Hicks, Pérez-Cruz, "KG-FRUS: A Novel Graph-based Dataset
   of 127 Years of US Diplomatic Relations" (arXiv:2311.01606)** —
   <https://arxiv.org/abs/2311.01606>
   Knowledge graph over the same TEI XML this app parses; PageRank, Node2Vec, and
   time-windowed entity-relation dynamics. → **feeds Corpus Analytics** (entities/citations).

---

## Re-homing the 12 recommendations

Two items from the prior roadmap turn out to be *two* features wearing one name once the
split is applied — flagged **(split)** below.

| # | Recommendation | Home | Notes |
|---|---|---|---|
| 1 | Corpus-baseline normalization toggle (% of docs/year) | **Corpus** | Modifies `AnalyticsView` in place |
| 2 | Person trajectory + multi-person comparison charts | **Corpus** | Who is mentioned = content |
| 3 | Most-mentioned persons by era (replaces `topTermsByYear` stub) | **Corpus** | Entity content |
| 4 | Series Production & Timeliness Dashboard | **Series** | The anchor of the new feature |
| 5 | Geographic Attention **(split)** | **Corpus** + **Series** | Document-content regional attention → Corpus; volume-organization / naming emphasis (Hensler's core) → Series |
| 6 | Cross-reference statistics (most-cited docs, citation heat matrix) | **Corpus** | How documents cite each other |
| 7 | Administration profiles **(split)** | **Corpus** + **Series** | "By Administration" term-frequency axis → Corpus; production profile (volumes/admin-year, 5.89 baseline) → Series |
| 8 | Person co-mention network + relationship dynamics | **Corpus** | Entity content |
| 9 | Tag co-occurrence & topic trends | **Corpus** | Content topics |
| 10 | `place_mentions` indexing + country attention *(schema bump)* | **Corpus** | Content; the one schema change |
| 11 | Document similarity / "More like this" | **Corpus** (DocumentView) | A per-document affordance, not a chart |
| 12 | VIAF/Wikidata person enrichment | **Corpus** (person pages) | External fetch |
| — | **Archival Sourcing Over Time** (NEW, this revision) | **Series** | Source Explorer synthesis; the user-requested dashboard expansion |

---

## Series Analytics (the new feature)

Everything here is *metadata about the series as a publication*, derivable today from
`manifest.json` plus the Source Explorer data — no new content indexing.

### S1. Series Production & Timeliness Dashboard *(roadmap #4 — the anchor)*
Reproduces and extends Appendix A:
- **Publication lag over time** — per volume, `publicationDate.year − dateRange.latest.year`
  plotted against coverage year. The post-1914 release deficit and the modern ~25-year
  backlog become visible in one curve.
- **Volumes published per year** — output bars by publication year, colorable by subseries;
  shows the Vietnam-era surge and the 1991-statute output.
- **Coverage-span vs. publication-era Gantt** — one bar per volume (coverage span on the
  x-axis, colored by lag bucket).
- **Production pipeline snapshot** — counts by `status` (published / partially published /
  planned), the live analogue of Appendix A's backlog framing.
- Data: `manifest.json` only. **Works with zero index / offline / mid-onboarding** — which
  matters because the Research Guide is shown while the first index is still building.

### S2. Administration Production Profiles *(roadmap #7, production half)*
Per-administration cards: volume count, **volumes per administration year against Hensler's
~5.89 corpus baseline** (reference line), document count, coverage span, editors /
general editor. Subseries year-spans (`"1969-76"`, `"1977-80"`, …) map implicitly to
administrations; a small bundled `subseries → administration` lookup makes the labels
explicit. Data: `manifest.json`.

### S3. Volume Organization & Geographic Emphasis *(roadmap #5, Series half — Hensler's core)*
Hensler's headline as an interactive view: **share of volumes per region per
administration** (stacked area / ridgeline) using taxonomy `places` tags rather than
title-string parsing — the app can normalize where raw titles could not. Surfaces the
20th-century Europe emphasis and the postwar pivot to Asia/Middle East. A companion
**naming-consistency panel** can flag the inconsistent-Europe-titling problem Hensler
documents. Data: manifest volume tags + `volume-tag-taxonomy.json`.

### S4. Archival Sourcing Over Time (NEW — the requested Source Explorer expansion)
**Feasibility: yes, from existing data — confirmed.** Source Explorer holds the substrate;
it just presents it at document/collection grain, never as a series-level time series.

- **Record-group / repository mix by coverage era** — stacked area of where the series
  draws its documents (State central files / RG-59, presidential libraries, foreign
  archives, personal papers) across coverage decades. Reveals structural shifts — e.g. the
  rise of presidential-library sourcing in the postwar volumes.
  *Derivation:* `majorCollections` (2,929 bundled records in `volume-sources-index.json`,
  each with `recordGroup` / `repository` / `resolved` NAID **and `volumeIds`**) →
  join `volumeIds` to `manifest.json` `dateRange` / `subseries` → bucket by era.
  **Works offline from bundled JSON.**
- **Top archival collections by administration** — which `majorCollections` dominate each
  era's citations (ranked bars, tap-through to the existing Source Explorer
  `CollectionDetailView`).
- **Editorial-practice change** — composition of `citation_era`
  (`structured` / `footnote` / `named_series` / `foreign` / `unrecognized`) by publication
  era. **Caveat, must be labeled in-UI:** `citation_era` is *citation-grammar*, not
  diplomatic era — a proxy for how source-note conventions standardized over the series'
  life, not for the historical period. Frame it as "how citations were written," not "when."
- **Per-volume repository distribution** — finer grain from the `volume_sources` SQLite
  table for indexed volumes.
  **Coverage caveat, must be surfaced (no silent truncation):** bundled `volume_sources`
  currently covers **258 of 552 volumes** (`Planning/Source-Explorer-Audit-2026-07-03.md`).
  The collection-grain views (bullet 1–2, via `majorCollections.volumeIds`) cover far more
  and work offline; the per-volume distribution degrades gracefully to "indexed volumes
  only" with an explicit coverage note.

This turns Source Explorer's rich but document-scoped provenance data into a series-level
narrative — "how the archival foundation of FRUS changed as the series matured" — which is
squarely a *series-production* story and belongs beside S1–S3.

### Home & exposure — inside the Research Guide
The Research Guide is the purpose-built home:
- **Existing anchor:** Guide page 2, *"163 Years in Progress — How the Corpus Evolved,"*
  already narrates the series' production history in prose. Series Analytics is its
  quantitative counterpart.
- **Recommended structure:** add a new `EducationCategory` — **"About the Series"** —
  holding the S1–S4 dashboards as live pages, sitting alongside the existing narrative in
  the macOS two-column HelpBook layout (which already supports adding a category) and the
  iOS paged sheet.
- **Content-model note:** `IndexingEducationView`'s content model (`EducationPage` /
  `EducationSection`) renders *prose* today. Embedding interactive charts needs one small
  extension — either (a) a new section kind that hosts a SwiftUI chart view inline, or
  (b) a page whose body is a live dashboard view instead of static sections. Recommend (b)
  as lower-risk: keep the narrative sections prose; make the "About the Series" pages
  render dashboard views. The content pane is already SwiftUI, so this is additive.
- **Deep-linking:** reuse the existing `ResearchGuideLinkButton` /
  `AppState.researchGuideInitialPageId` mechanism so a "See how sourcing changed" button in
  Source Explorer, or a "Why is my volume not published yet?" prompt in Browse, can open the
  guide pre-scrolled to the relevant dashboard.
- **Offline behavior:** S1–S3 and S4's collection-grain views run from bundled JSON and
  work during onboarding before anything is indexed; S4's per-volume distribution shows a
  "requires indexed volumes" state. Keep the guide usable in the zero-index onboarding
  context it already serves.

**Not** exposed as a `frus.analytics`-style content window — that would blur the split the
user is drawing. Series Analytics is guide-resident; Corpus Analytics is window/menu-resident.

---

## Corpus Analytics (stays put, gains the content items)

Home unchanged: iOS Browse → "Analysis Tools" menu (Chronology / Corpus Analytics / Word
Cloud); macOS `frus.analytics` and `frus.wordcloud` windows + per-scope Word Cloud buttons.
All items below are document-content analysis over the local FTS5 index and entity tables.

- **C1 — Corpus-baseline normalization** *(#1)*: add a "% of documents that year" toggle to
  `AnalyticsView`. Raw counts currently conflate "term got popular" with "corpus got
  bigger"; cheapest correctness upgrade. Uses per-year document totals from `document_dates`.
- **C2 — Person analytics** *(#2, #3, #8)*: mention-trajectory charts with multi-person
  comparison (the multi-series UI the single-term view lacks); most-mentioned-persons-by-era
  (the honest replacement for the `topTermsByYear` stub, computed over `person_mentions` ×
  `document_dates` where it's cheap and precise); person co-mention network + two-person
  relationship-dynamics time series (KG-FRUS's dynamic-embedding idea, done with explainable
  time-bucketed co-mention counts). Reuses the force-directed Canvas from
  `CrossReferenceGraphView`.
- **C3 — Cross-reference statistics** *(#6)*: `cross_references` as a statistical object —
  most-referenced documents (in-degree), degree distributions, volume-to-volume citation
  heat matrix; optional offline PageRank for "landmark documents."
- **C4 — Geographic/topic content** *(#5 Corpus half, #9)*: document-content regional
  attention over time (taxonomy `places` tags weighted by `document_dates`); topic-tag trend
  lines and tag co-occurrence matrix.
- **C5 — "By Administration" axis** *(#7 Corpus half)*: add administration as a sibling of
  the existing "By Subseries" analytics axis for any term.
- **C6 — Country attention** *(#10, schema change)*: add a `place_mentions` table mirroring
  `person_mentions` (index schema bump + re-index) for document-grain country time series and
  co-mention maps. Deferred until the entity-analytics UX (C2) is validated.
- **C7 — Document similarity** *(#11)*: "Related documents" panel in `DocumentView` from
  sparse person-mention + subject-tag profiles (cosine/Jaccard), optionally blended with
  `NLEmbedding`. A per-document affordance, not a chart.
- **C8 — Person authority enrichment** *(#12)*: VIAF/Wikidata enrichment of person pages via
  the existing `person_rollup.viaf_id` hook. Network-dependent; behind on-demand fetch.

---

## Revised prioritized roadmap

Sequenced so Series Analytics stands up first as a self-contained, zero-index feature (it is
small and unblocks the Research Guide integration), then the high-value corpus content items.

The **Scheduled** column maps each priority to its session in
[`Analytics-Session-Plan.md`](Analytics-Session-Plan.md); **Postponed** rows are not
scheduled there (tracked here only).

| Priority | Item | Feature | New data? | Effort | Scheduled |
|---|---|---|---|---|---|
| 1 | Series Production & Timeliness Dashboard (S1) | Series | No | S | **SA-1** |
| 2 | Corpus-baseline normalization toggle (C1) | Corpus | No | S | **CA-4** |
| 3 | Administration Production Profiles (S2) | Series | No (small lookup) | S–M | **SA-2** |
| 4 | Person trajectory + comparison; most-mentioned-by-era (C2, part) | Corpus | No | M | **CA-5** |
| 5 | Archival Sourcing Over Time (S4) | Series | No | M | **SA-3** |
| 6 | Volume Organization & Geographic Emphasis (S3) | Series | No | M | **SA-2** |
| 7 | Cross-reference statistics (C3) | Corpus | No | M | **CA-6** |
| 8 | Geographic/topic content + "By Administration" axis (C4, C5) | Corpus | No | M | **POSTPONED** |
| 9 | Person co-mention network + relationship dynamics (C2, rest) | Corpus | No | M–L | **CA-8** |
| 10 | `place_mentions` + country attention (C6) | Corpus | **Yes** (schema) | L | **POSTPONED** |
| 11 | Document similarity / "More like this" (C7) | Corpus | No | M | **POSTPONED** |
| 12 | VIAF/Wikidata person enrichment (C8) | Corpus | External fetch | L | **POSTPONED** |

Items 1–7 and 9 run on data already available (bundled JSON + current index) and are
scheduled across the enabling prep, the Series milestone (priorities 1, 3, 5, 6 = the whole
Series feature, one Research-Guide-integrated milestone), and the selected Corpus content
sessions.

### Postponed (not scheduled)

Four priorities are deliberately held back from the current plan:

- **Priority 8 — Geographic/topic content + "By Administration" axis (C4, C5).** Corpus
  regional-attention charts and an administration analytics axis. Deferred to keep the
  Corpus content sessions focused on the person/citation entity work (CA-5, CA-6, CA-8);
  the taxonomy-`places` derivation it needs overlaps with Series SA-2, so it is cheaper to
  revisit after that ships.
- **Priority 10 — `place_mentions` + country attention (C6).** The one **schema change**
  (a new index table + re-index). Stays deferred until the entity-analytics UX (CA-5 /
  CA-8) proves out, per the original blueprint gating.
- **Priority 11 — Document similarity / "More like this" (C7).** A per-document DocumentView
  affordance, not a chart — separable from the analytics chassis work and postponable
  without blocking anything.
- **Priority 12 — VIAF/Wikidata person enrichment (C8).** The **only external-fetch** item;
  postponed to keep the scheduled work fully on-device/offline-first.

When any of these is picked up, fold it into `Analytics-Session-Plan.md` as a new session
and flip its **Scheduled** cell above.

## Cross-cutting implementation notes

- **Two chart chasses, deliberately.** Corpus items extend `AnalyticsView`'s existing
  axis-picker / year-range / chart-vs-table / Search-handoff frame (extract a shared frame
  before cloning the 1,680-line view). Series items get a *new* dashboard chassis inside the
  Research Guide, tuned for narrative reading rather than query-driven exploration.
- **Research Guide content-model extension** (Series prerequisite): let an `EducationPage`
  render a live dashboard view, not only prose sections — additive, the pane is already
  SwiftUI. See S4 "content-model note."
- **Offline / onboarding safety**: Series dashboards must render in the zero-index
  onboarding context the guide already serves; gate only S4's per-volume grain behind
  "requires indexed volumes."
- **Honest coverage**: surface the `volume_sources` 258/552 coverage and the `citation_era`
  = citation-grammar caveat in-UI — no silent truncation, per house style.
- **All on-device**: every item except C8 computes from bundled JSON + the local SQLite
  index, consistent with the app's offline-first design.
- **Scopes**: Corpus items reuse `WordCloudScope` semantics (document/volume/subseries/
  corpus/collection/tag/date-range) so new analytics inherit collection- and tag-scoped
  workflows for free.
