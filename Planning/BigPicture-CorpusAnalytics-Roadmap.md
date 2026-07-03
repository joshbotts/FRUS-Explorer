# Big Picture: Corpus Analytics Roadmap — Recommendations from Published FRUS Research

**Date:** 2026-07-02
**Status:** Recommendations (no code changes yet)

## Purpose

Three open-source publications apply quantitative/computational methods to the FRUS
corpus. Each demonstrates analytics that FRUS Explorer could offer natively — in most
cases against data the app *already parses and indexes* but does not yet surface as
analytics. This document maps each publication's methods to concrete feature
recommendations, grounded in the app's existing data substrate, and ends with a
prioritized roadmap.

### Sources reviewed

1. **Office of the Historian, *Toward "Thorough, Accurate, and Reliable": A History of
   the Foreign Relations Series*, Appendix A: Historical FRUS Timeliness and Production
   Charts** — <https://history.state.gov/historicaldocuments/frus-history/appendix-a>
   Charts the series' own production history: the publication lag between the year
   covered and the year published (the post-1914 "release deficit"), and volume output
   per year across the series' life. Companion data: the Office's
   [Annual FRUS Production and Timeliness Data](https://history.state.gov/historicaldocuments/frus-history/research/production-and-timeliness-data).

2. **Hensler, "'It's Late': How FRUS Volume Organization Teaches History (and Makes a
   Massive Backlog)," *DttP: Documents to the People* 54, no. 1 (2026)** —
   <https://journals.ala.org/index.php/dttp/article/view/8675/12036>
   Analyzes FRUS volume organization (administration → region/topic) as data: volumes
   per administration year (~5.89 average), the twenty-five-year backlog, the heavy
   20th-century emphasis on Europe, and how inconsistent regional naming (Europe titled
   variously by country/continent/subregion, vs. highly consistent naming for Africa and
   East Asia volumes) damages searchability.

3. **Özsoy, Salamanca, Connelly, Hicks, Pérez-Cruz, "KG-FRUS: A Novel Graph-based
   Dataset of 127 Years of US Diplomatic Relations" (arXiv:2311.01606)** —
   <https://arxiv.org/abs/2311.01606>
   Builds a knowledge graph from the same TEI XML this app parses: 300,000+ documents
   plus person and country entities, enriched with Wikidata relations. Demonstrates
   (a) query-language answers to research questions, (b) whole-graph algorithms —
   PageRank for entity importance, Node2Vec for entity similarity — and (c) *dynamic*
   time-windowed entity embeddings that show how relations between actors tighten or
   drift around world events.

## Where the app stands today

Current analytics surface (see `FRUSExplorer/Analytics/`):
- **Corpus Analytics** — single-term document-frequency charts by decade/year/month/day/
  subseries/volume (`CorpusAnalyticsService` over FTS5 `matchedDocumentKeys` +
  `document_dates`), with Search handoff.
- **Word Cloud** — top-terms frequency clouds with NER/POS/concept/sentiment lenses over
  document/volume/subseries/corpus/collection/tag/date-range scopes.
- **Cross-Reference graphs** — document and volume ego-graph *topology* views (Canvas),
  not statistical charts.
- Swift Charts also appears in `ChronologyView` (density bar) and
  `DocumentTimelineView` (results by year).

Already indexed but **not surfaced as analytics**: `person_mentions`, `persons` +
`person_rollup` (canonical persons, roles, eras, VIAF ids), `terms` (glossary),
`cross_references` (as a statistical object), `document_sources` / `volume_sources`
(repositories, record groups, lot files), `document_dates.date_precision`/`date_certainty`,
manifest `publicationDate` + `dateRange` + volume subject tags, and the
places/topics hierarchy in `volume-tag-taxonomy.json`.

---

## Recommendations from Source 1 — Appendix A (production & timeliness analytics)

Appendix A treats the series itself as the object of analysis. Everything it charts can
be recomputed live from `manifest.json` alone — no indexing required, works before any
volume is downloaded.

### 1.1 Series Production & Timeliness Dashboard
A new "About the Series" analytics screen reproducing (and extending) Appendix A:
- **Publication lag over time** — per volume, `publicationDate.year − dateRange.latest.year`;
  plot lag vs. coverage year as a line/scatter. The post-1914 release-deficit curve and
  the modern ~25-year backlog Hensler describes become immediately visible.
- **Volumes published per year** — bar chart of output by publication year, colorable by
  subseries; shows the Vietnam-era surge, 1990s statute-driven output, etc.
- **Coverage span vs. publication era** — Gantt-style bars (one per volume: dateRange
  span, positioned on a coverage-year axis, colored by lag bucket).
- Data: `manifest.json` (`publicationDate`, `dateRange`, `subseries`, `status`).
  Effort: small — one service struct + one Swift Charts view; no schema changes.

### 1.2 Coverage-density metrics
- **Documents per covered year** (`documentCount ÷ coverage span`, refined to actual
  per-year counts from `document_dates` for indexed volumes) — exposes thin vs. dense
  years and complements the existing per-term charts with a *baseline*: the term charts
  currently show raw counts, which conflate "term got popular" with "corpus got bigger."
- **Normalization option for existing Corpus Analytics** — add a "% of documents that
  year" toggle to `AnalyticsView` using this baseline. This is arguably the single
  cheapest correctness upgrade to the existing feature.

## Recommendations from Source 2 — Hensler (organization, geography, backlog)

Hensler's method is metadata analysis of the volume catalog: administration × region ×
topic. The app's `volume-tag-taxonomy.json` (places/topics/people categories with
hierarchy) is precisely the normalization layer Hensler found missing in raw volume
titles — the app can do this analysis *better* than title-string matching.

### 2.1 Geographic Attention Explorer
- Chart **share of volumes (and, for indexed volumes, share of documents) per region per
  administration/era**, using taxonomy `places` tags rather than volume-title parsing.
  A stacked-area or ridgeline chart makes the 20th-century Europe emphasis — and the
  postwar pivot toward Asia/Middle East — directly visible, the article's headline
  finding as an interactive view.
- Drill-in: tap a region × era cell → Browse filtered to those volumes (the browse and
  tag plumbing already exists).
- Data: manifest volume tags + taxonomy; `document_dates` for per-document weighting.
  Effort: medium-small; no new indexing.

### 2.2 Administration Corpus Profiles
- A per-administration summary card set: volume count, volumes per administration year
  (Hensler's 5.89 baseline as corpus-wide reference line), document count, region/topic
  mix donut, top persons (from `person_rollup` filtered by era). Ideal as the header of
  a subseries browse page and as an Analytics chart mode ("By Administration" — a
  natural sibling of the existing "By Subseries" axis, and administrations are already
  how subseries are organized).

### 2.3 Tag co-occurrence & topic trends
- **Topic-tag trend lines** — the taxonomy's `topics` tags charted over coverage time
  (e.g., "arms control" volume/document share by decade); **tag co-occurrence matrix**
  (which topics travel with which regions). Data: volume subject tags (+ per-document
  `subject_tag_ids` already stored in `document_cache`). Effort: small-medium.

## Recommendations from Source 3 — KG-FRUS (entity & graph analytics)

KG-FRUS's pipeline (TEI → entities → graph → PageRank/Node2Vec/dynamic embeddings) maps
one-to-one onto tables the `IndexingPipeline` already populates. The app can deliver
scoped, on-device versions of each demonstrated analysis without any server or ML
dependency beyond what's bundled.

### 3.1 Person Analytics (highest value)
- **Person trajectory chart** — mentions per year for a person (`person_mentions` ×
  `document_dates`), reusing the existing `AnalyticsView` chart chassis with a person
  picker (autocomplete over `person_rollup.canonical_name`). Compare 2–5 persons as
  multi-series lines — this also introduces the multi-term comparison UI the current
  single-term Analytics lacks.
- **Most-mentioned persons by era/scope** — ranked bars per decade/administration/
  volume; effectively "topTermsByYear" (currently a stub returning `[]`) but over the
  entity table where it's cheap and precise instead of over FTS5 vocabulary where it
  isn't.
- **Co-mention network** — persons co-occurring in the same documents; edge weight =
  co-mention count. Render with the existing force-directed Canvas from
  `CrossReferenceGraphView` (extract the layout into a shared component). Degree/
  weighted-degree centrality is a one-pass SQL aggregate and a honest stand-in for
  PageRank at ego-graph scale; full PageRank over the corpus graph is a
  straightforward iterative loop in an actor if wanted later.
- **Relationship dynamics** (KG-FRUS's dynamic-embedding insight, simplified): chart
  co-mention strength between two chosen persons per year — "when did Kissinger and
  Dobrynin's documentary association peak?" No embeddings needed for v1; time-bucketed
  Jaccard/count on `person_mentions` suffices and is explainable to researchers.

### 3.2 Cross-reference statistics
- Treat `cross_references` as a statistical object, not only a node-link canvas:
  **most-referenced documents** (in-degree ranking, per scope), in/out-degree
  distributions, volume-to-volume citation heat matrix. PageRank over the document
  citation graph ("landmark documents") is feasible offline at index time and would be
  a genuinely novel research affordance no FRUS interface offers.

### 3.3 Country/place attention *(requires one indexing addition)*
- KG-FRUS's country entities are the one substrate we parse (`placeName` in the TEI
  parser) but don't persist. Add a `place_mentions` table in `IndexingPipeline`
  (mirroring `person_mentions`; bump the index schema version), plus a small
  gazetteer normalization pass (taxonomy `places` slugs as the target vocabulary).
  Unlocks: country attention time series at *document* granularity (sharper than 2.1's
  volume-tag granularity), country co-mention maps, and "places in this volume."
- Effort: medium (schema change + re-index); recommend sequencing after 3.1/3.2 prove
  the entity-analytics UX.

### 3.4 Document similarity ("More like this")
- KG-FRUS uses Node2Vec for entity similarity. An on-device analogue: represent each
  document by its person-mention + subject-tag profile (sparse vector already in
  SQLite) and rank by cosine/Jaccard; optionally blend `NLEmbedding` sentence vectors
  of headers. Surface as a "Related documents" panel in `DocumentView` and as a
  similarity edge type in the graph views. Effort: medium; no schema change for the
  sparse-profile version.

### 3.5 Authority enrichment (later)
- `person_rollup` already carries VIAF ids — the hook for KG-FRUS-style Wikidata
  enrichment (birth/death, positions held) to power richer person pages. Network-
  dependent and optional; keep behind the existing on-demand-fetch patterns.

---

## Prioritized roadmap

| Priority | Feature | Source | New data needed? | Effort |
|---|---|---|---|---|
| 1 | Corpus-baseline normalization toggle in existing Analytics (1.2) | App. A | No | S |
| 2 | Person trajectory + multi-person comparison charts (3.1) | KG-FRUS | No | M |
| 3 | Most-mentioned persons by era; replaces `topTermsByYear` stub (3.1) | KG-FRUS | No | S–M |
| 4 | Series Production & Timeliness Dashboard (1.1) | App. A | No | S |
| 5 | Geographic Attention Explorer (2.1) | Hensler | No | M |
| 6 | Cross-reference statistics: most-referenced docs, citation heat matrix (3.2) | KG-FRUS | No | M |
| 7 | Administration profiles + "By Administration" analytics axis (2.2) | Hensler | No | S–M |
| 8 | Person co-mention network + relationship-dynamics chart (3.1) | KG-FRUS | No | M–L |
| 9 | Tag co-occurrence & topic trends (2.3) | Hensler | No | M |
| 10 | `place_mentions` indexing + country attention analytics (3.3) | KG-FRUS | **Yes** (schema bump) | L |
| 11 | Document similarity / "More like this" (3.4) | KG-FRUS | No | M |
| 12 | VIAF/Wikidata person enrichment (3.5) | KG-FRUS | External fetch | L |

Sequencing logic: items 1–9 run entirely on data already indexed, so they can ship
incrementally without re-index churn; the one schema change (10) is deferred until the
entity-analytics UX is validated. Items 2–3 double as the fix for the known
`topTermsByYear` stub and the known "no multi-term comparison" gap in
`CorpusAnalyticsService`.

## Cross-cutting implementation notes

- **Chart chassis reuse**: `AnalyticsView`'s axis picker / year-range filter / chart-vs-
  table / Search-handoff pattern generalizes; extract a shared frame before adding the
  person and region chart modes rather than cloning the 1,680-line view.
- **All on-device**: every recommendation above is computable from bundled JSON + the
  local SQLite index, consistent with the app's offline-first design; only 3.5 needs
  network.
- **Performance**: entity aggregates (`person_mentions` joins) should live in the same
  actor + LRU-cache pattern as `CorpusAnalyticsService`; precompute corpus-wide
  rankings at index time like `WordCloudPrecomputeQueue` does for the corpus cloud.
- **Scopes**: reuse `WordCloudScope` semantics (document/volume/subseries/corpus/
  collection/tag/date-range) so every new analytic inherits collection- and tag-scoped
  research workflows for free.
