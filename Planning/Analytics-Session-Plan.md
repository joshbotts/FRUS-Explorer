# Analytics — Session Plan

**Date:** 2026-07-04
**Source blueprint:** [`BigPicture-Analytics-CorpusVsSeries.md`](BigPicture-Analytics-CorpusVsSeries.md) (2026-07-03) — the corpus-vs-series split and the 12-item prioritized roadmap.
**Scope of this plan (owner-selected 2026-07-04):** two enabling prep sessions, the full **Series Analytics** feature (SA-1…SA-3), and four **Corpus Analytics** content sessions (CA-4, CA-5, CA-6, CA-8). **Postponed** (not in this plan): Corpus session 7 (geographic/topic content + "By Administration" axis), and the deferred tail — session 9 (`place_mentions` + country attention, the schema change) and session 10 (document similarity + person-authority enrichment). See the big-picture doc's roadmap table for the postponement markers.

This follows the house scope conventions: each session is 1–2 PRs, with goal, deliverables (file-anchored), data dependency, prerequisites, effort, decision points, and the blueprint's guardrails. Line/symbol anchors are from the 2026-07-03 blueprint and **must be re-verified at each session's start** — analytics-adjacent code has shipped since.

## Cross-cutting guardrails (every session)

- **Two chart chassis, deliberately.** Corpus sessions extend `AnalyticsView`'s existing axis-picker / year-range / chart-vs-table / Search-handoff frame (after Prep-B extracts it). Series sessions use a **new dashboard chassis inside the Research Guide**, tuned for narrative reading — never a `frus.analytics`-style content window (that would blur the split).
- **Offline / onboarding safety.** Series dashboards must render in the zero-index onboarding context the guide already serves. Only SA-3's per-volume grain may gate behind "requires indexed volumes."
- **Honest coverage — no silent truncation** (house style): surface the `volume_sources` **258/552-volume** coverage and the **`citation_era` = citation-grammar-not-diplomatic-era** caveat in-UI wherever they apply.
- **All on-device** from bundled JSON + the local SQLite index (every session in this plan; no external fetch — the one network-dependent item, C8, is postponed).
- **Standing gates** (as ever): `String(localized:)`, doc comments, Apache headers, `Version history` bumps, `CodingStandardsAuditTests`, dual-manager/dual-platform parity, docs rider per feature-session rule.

---

## Prep-A — Research Guide dashboard-page kind *(prerequisite for all Series sessions; Effort S)*

**Goal.** Let a Research Guide page render a live SwiftUI dashboard view, not only prose — the additive content-model extension the Series feature needs.

**Deliverables.**
- Extend `IndexingEducationView`'s content model (`EducationPage` / `EducationSection`) so a page's body can be a **live dashboard view** instead of static prose sections (the blueprint's recommended option **b** — lower-risk than a new inline-chart section kind; the content pane is already SwiftUI, so this is purely additive).
- No new dashboards yet — one throwaway/placeholder dashboard page proves the pipe end-to-end on both the macOS `frus.researchGuide` HelpBook two-column layout and the iOS paged sheet.
- Confirm the existing `ResearchGuideLinkButton` / `AppState.researchGuideInitialPageId` deep-link mechanism reaches a dashboard page (SA sessions will deep-link into these).

**Decision point (P-A-1).** Dashboard-page hosting: (a) a new `EducationPage` body variant that swaps prose for a dashboard view (recommended — narrative pages stay prose, "About the Series" pages render dashboards), vs (b) a new inline section kind hosting a chart between prose sections. Lean (a); (b) is heavier and mixes reading modes.

**Prereq:** none. **Data:** none.

## Prep-B — Extract the shared Corpus analytics frame *(prerequisite for CA sessions; Effort S)*

**Goal.** Pull the reusable scaffold out of the ~1,680-line `AnalyticsView` **before** cloning it, so the Corpus content sessions extend a frame instead of duplicating a giant view.

**Deliverables.**
- Extract the axis-picker / year-range / chart-vs-table toggle / Search-handoff frame from `AnalyticsView` into a shared, reusable container (a `AnalyticsChartFrame`-style host + a protocol/enum for the "what am I charting" axis). Behavior-preserving refactor — **no user-facing change**; the existing Corpus Analytics view renders identically.
- A byte/behaviour regression check that the current analytics screens are unchanged.

**Decision point (P-B-1).** Frame boundary: how much of `AnalyticsView` becomes shared (just the chrome, vs the chrome + the year-bucketing/normalization compute). Lean: extract chrome + the shared compute helpers CA-4/CA-5 will both need (per-year document totals), stop short of the query-specific rendering.

**Prereq:** none. **Data:** none. *(Can slot immediately before CA-4 rather than up front.)*

---

## Series Analytics — the self-contained, zero-index milestone

Ships first: small, high-narrative-value, offline, onboarding-safe. SA-1…SA-3 constitute the whole Series feature and land as a Research-Guide-integrated milestone. All derive from `manifest.json` + Source Explorer's bundled data — **no new content indexing**.

### SA-1 — Series Production & Timeliness Dashboard *(blueprint S1 / roadmap #1; the anchor; Effort S)*

**Goal.** Reproduce and extend Appendix A: make the series' own production history visible.

**Deliverables.**
- **Publication lag over time** — per volume, `publicationDate.year − dateRange.latest.year` vs. coverage year (the post-1914 release deficit and the modern ~25-year backlog as one curve).
- **Volumes published per year** — output bars by publication year, colorable by subseries (Vietnam-era surge, 1991-statute output).
- **Coverage-span vs. publication-era Gantt** — one bar per volume, coverage span on x, colored by lag bucket.
- **Production pipeline snapshot** — counts by `status` (published / partially published / planned).
- Stand up the new **"About the Series" `EducationCategory`** holding these as live dashboard pages (uses Prep-A).
- **Data:** `manifest.json` only; renders with **zero index / offline / mid-onboarding**.

**Prereq:** Prep-A. **Decision point (SA-1-1):** chart library reuse — reuse Swift Charts as the analytics views already do vs. a bespoke dashboard renderer; lean Swift Charts for consistency.

### SA-2 — Administration Profiles + Volume Organization & Geographic Emphasis *(blueprint S2 + S3 / roadmap #3 + #6; Effort M)*

**Goal.** The "how the series is organized" half of the Hensler analysis, interactive.

**Deliverables.**
- **Administration production profiles** — per-administration cards: volume count, **volumes per administration-year against Hensler's ~5.89 corpus baseline** (reference line), document count, coverage span, editors/general editor. Needs a small **bundled `subseries → administration` lookup** to label year-spans (`"1969-76"`, `"1977-80"`, …) explicitly.
- **Volume organization & geographic emphasis** — share of volumes per region per administration (stacked area / ridgeline) from taxonomy `places` tags (normalized, where raw title strings could not be), surfacing the 20th-century Europe emphasis and the postwar Asia/Middle-East pivot.
- **Naming-consistency panel** — flags the inconsistent-Europe-titling problem Hensler documents.
- **Data:** `manifest.json` + `volume-tag-taxonomy.json`.

**Prereq:** Prep-A, SA-1 (shared Series chassis + the "About the Series" category). **Decision point (SA-2-1):** the `subseries → administration` lookup — bundle a static JSON vs. derive from year-span heuristics; lean bundled static (explicit, auditable). **Guardrail:** taxonomy-tag-based regional shares, not title parsing.

### SA-3 — Archival Sourcing Over Time *(blueprint S4 / roadmap #5; the requested Source Explorer expansion; Effort M)*

**Goal.** Turn Source Explorer's document-scoped provenance into a **series-level** narrative: "how the archival foundation of FRUS changed as the series matured." Feasibility already confirmed from existing bundled data.

**Deliverables.**
- **Record-group / repository mix by coverage era** — stacked area of where the series draws documents (RG-59 central files / presidential libraries / foreign archives / personal papers) across coverage decades. *Derivation:* `majorCollections` in `volume-sources-index.json` (each with `recordGroup`/`repository`/resolved NAID **and `volumeIds`**) → join `volumeIds` to `manifest.json` `dateRange`/`subseries` → bucket by era. **Offline from bundled JSON.**
- **Top archival collections by administration** — ranked bars, tap-through to the existing Source Explorer `CollectionDetailView`.
- **Editorial-practice change** — composition of `citation_era` (`structured`/`footnote`/`named_series`/`foreign`/`unrecognized`) by publication era.
- **Per-volume repository distribution** — finer grain from the `volume_sources` SQLite table (indexed volumes only).

**Mandatory in-UI caveats (blueprint, non-negotiable):**
- `citation_era` is **citation-grammar, not diplomatic era** — a proxy for how source-note conventions standardized, not for the historical period. Label as "how citations were written," not "when."
- Per-volume grain covers **258/552 volumes** — surface the coverage explicitly; the collection-grain views (bullets 1–2, via `majorCollections.volumeIds`) cover far more and run offline; the per-volume view degrades gracefully to "indexed volumes only."

**Prereq:** Prep-A, SA-1. **Decision point (SA-3-1):** deep-link a "See how sourcing changed" button from Source Explorer into this dashboard (reuse `ResearchGuideLinkButton`) — yes/lean-yes.

**Series milestone docs rider:** a Research Guide / manuals note that the "About the Series" category exists and what each dashboard shows.

---

## Corpus Analytics — the selected content items

Home unchanged: iOS Browse → "Analysis Tools" menu; macOS `frus.analytics` / `frus.wordcloud` windows. All document-content analysis over the local FTS5 index + entity tables. Reuse `WordCloudScope` semantics (document/volume/subseries/corpus/collection/tag/date-range) so new analytics inherit scoped workflows for free.

### CA-4 — Corpus-baseline normalization *(blueprint C1 / roadmap #2; Effort S)*

**Goal.** The cheapest correctness upgrade: stop conflating "term got popular" with "corpus got bigger."

**Deliverables.** A **"% of documents that year" toggle** in `AnalyticsView`, using per-year document totals from `document_dates`. Raw-count and normalized modes side by side.

**Prereq:** Prep-B. **Data:** existing index. **Decision point (CA-4-1):** default mode — raw vs. normalized; lean raw-default with a persistent per-user toggle. *(Small; a good early win — can precede or interleave with the Series milestone.)*

### CA-5 — Person analytics, part 1 *(blueprint C2, first half / roadmap #4; Effort M)*

**Goal.** Real person-content analytics, replacing the `topTermsByYear` stub honestly.

**Deliverables.**
- **Mention-trajectory charts with multi-person comparison** — the multi-series UI the single-term view lacks.
- **Most-mentioned-persons-by-era** — computed over `person_mentions × document_dates` (cheap and precise), the honest replacement for the stub.

**Prereq:** Prep-B, CA-4 (shared frame + per-year totals). **Data:** existing index (`person_mentions`, `document_dates`, `person_rollup`). **Decision point (CA-5-1):** person identity for comparison — pick by `person_rollup` cluster (recommended, post-People-eval consolidation) vs. raw ref.

### CA-6 — Cross-reference statistics *(blueprint C3 / roadmap #7; Effort M)*

**Goal.** Treat `cross_references` as a statistical object, not just the graph.

**Deliverables.** Most-referenced documents (in-degree), degree distributions, volume-to-volume citation **heat matrix**; **optional offline PageRank** for "landmark documents."

**Prereq:** Prep-B. **Data:** existing index (`cross_references`). **Decision point (CA-6-1):** ship PageRank now vs. defer — lean include (offline, bounded, high narrative payoff), behind a clearly-labeled "influence" framing.

### CA-8 — Person co-mention network + relationship dynamics *(blueprint C2, rest / roadmap #9; Effort M–L)*

**Goal.** The relational half of person analytics.

**Deliverables.**
- **Co-mention network** — reusing the force-directed `Canvas` from `CrossReferenceGraphView` (respect the Session-161 visual-encoding contract).
- **Two-person relationship-dynamics time series** — explainable, time-bucketed co-mention counts (KG-FRUS's dynamic-embedding idea, done transparently rather than with opaque embeddings).

**Prereq:** Prep-B, CA-5 (person-selection UX validated). **Data:** existing index. **Decision point (CA-8-1):** network scale/perf cap — top-N persons by mention count with a documented cap (no silent truncation), mirroring the graph's existing degree limits.

---

## Sequencing

Series first (self-contained, unblocks the guide), a small Corpus quick win early, then the Corpus content depth:

| Order | Session | Feature | Prereq | Effort |
|---|---|---|---|---|
| 1 | Prep-A (Research Guide dashboard page) | enabling | — | S |
| 2 | SA-1 (Production & Timeliness) | Series | Prep-A | S |
| 3 | Prep-B (extract Corpus frame) | enabling | — | S |
| 4 | CA-4 (baseline normalization) | Corpus | Prep-B | S |
| 5 | SA-2 (admin profiles + geo emphasis) | Series | SA-1 | M |
| 6 | SA-3 (archival sourcing over time) | Series | SA-1 | M |
| 7 | CA-5 (person trajectory + by-era) | Corpus | Prep-B, CA-4 | M |
| 8 | CA-6 (cross-reference statistics) | Corpus | Prep-B | M |
| 9 | CA-8 (person network + dynamics) | Corpus | CA-5 | M–L |

*(Prep-B/CA-4 can interleave earlier if a quick Corpus win is wanted before the Series milestone finishes; the Series milestone — Prep-A + SA-1…SA-3 — is independently shippable.)*

**Postponed (tracked in the big-picture doc, not scheduled here):** Corpus geographic/topic content + "By Administration" axis (blueprint C4/C5, roadmap #8); `place_mentions` + country attention (C6, #10 — the one schema change, gated on the CA-5/CA-8 entity UX proving out); document similarity (C7, #11) and person-authority enrichment (C8, #12, the one external-fetch item).

**Status:** planned 2026-07-04; no implementation started.
