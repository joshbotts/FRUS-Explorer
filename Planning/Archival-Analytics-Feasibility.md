# Archival Analytics — Feasibility Assessment

**Date:** 2026-08-08 · **Version:** 1.0 · **Status:** feasibility assessment for owner review —
no code changes ride this document.

**The question asked:** is a new archival analytics feature feasible — one that helps users see
*interrelationships between archival collections*, *how FRUS historians have used archives over
time*, and other insights reachable through data the app already has?

**Inputs:** the tree on this branch (build 39 lineage); the bundled Resources artifacts as of
2026-08-08; `Planning/BigPicture-Analytics-CorpusVsSeries.md` (the corpus/series split and the
SA roadmap); `Planning/Feature-Priorities-Review-2026-08.md` (§5a "Complete the archive
bridge"); `collection-authority-report.txt` (2026-08-06 regeneration); the
`Planning/source-explorer-export/` committed aggregates (264,464 document source notes); open
issues #267, #262, #645, #663; and fresh measurements over the bundled artifacts (scripts noted
inline, run 2026-08-08 on this branch).

---

## 1. Verdict up front

**Feasible — and unusually cheap for what it delivers.** The hard part of this feature was
built over the last two months without being asked for by name: a cross-volume collection
authority (4,423 records with volume lists), a parity-pinned source-note parse of all 264,464
document source notes, five offline NARA indexes, a shipped decade-grain sourcing dashboard
(SA-3), and a reusable force-directed graph view (CA-8). What the request adds is genuinely
new **presentation**, plus **one small new bundled aggregate** for the document-weighted views.

Three findings shape the recommendation:

1. **"How historians used archives over time" already ships at category grain.** The SA-3
   "Archival Sourcing Over Time" dashboard (`SourceProvenanceDashboard`, inside the Research
   Guide) charts the decade × 10-category provenance mix. The request's added value is the
   **collection grain** — *which* collections, not just *what kind* — and open issue **#267**
   (source-provenance index v2, per-volume counts) is the already-recorded first step in
   exactly this direction.
2. **Collection interrelationships are computable today from bundled data, with no new
   artifact.** `collection-authority.json` carries `volumeIds` on every record. Measured:
   4,423 collections over 356 volumes, median 30 collections per volume; 40,538 collection
   pairs share ≥2 volumes and 4,550 share ≥5 — a real, thresholdable co-citation graph. The
   pairwise computation over all 11,804 (collection, volume) memberships is trivial
   (sub-second in interpreted Python; faster in Swift off-main).
3. **Document-weighted rankings need one new generator artifact** — per-(collection, volume)
   document counts — because `collection-authority.json` deliberately carries no document
   counts (a recorded design decision). The generator infrastructure to build it exists
   end-to-end (`SourceExplorerExportGenerator` already computes every input), and the same
   session can close #267. Estimated artifact size: ~300–500 KB.

The honest limits (§5) are era asymmetry — collection-grain analytics are structurally a
1946–1988 story, because pre-1946 sourcing *is* the Central Decimal File — and the
volume-grain meaning of "co-cited" (§5.2). Both are disclosable in-UI in the house style, and
the era asymmetry is itself the historical finding the feature would surface.

---

## 2. What already ships (the feature is an extension, not a greenfield)

Checked against the tree 2026-08-08:

| Surface | What it does today | Grain |
|---|---|---|
| `SourceProvenanceDashboard` (SA-3b, Research Guide "About the Series") | Decade × provenance-category mix, composition, density; category filter; renders offline, zero-index | decade × 10 categories |
| `SeriesProductionDashboard`, `SeriesGeographyDashboard`, `AdministrationProfilesDashboard` | The other three "About the Series" dashboards | series/volume |
| `CollectionBrowserView` + `CollectionDetailView` (Source Explorer Phase 4/5) | Browse the 4,423-record authority grouped by repository; per-collection detail: overview/aliases, NARA link, "In Your Library" local counts, citing-volume list, sub-series | one collection at a time |
| `ArchivalNeighborsSheet` / macOS neighbors window | "Documents from the same lot / decimal class," scoped volume/subseries/corpus | document |
| `PersonCoMentionGraphView` (CA-8) | Canvas force-directed **ego graph** with thresholds — a directly reusable pattern | person network |
| `LotClaimantsIndex` (#675) | Divided-lot claimants surfaced on lot resolution | one lot at a time |
| Digitised-scan links (N-7 lineage: `digitized-ranges-index.json`, `roll-scans-index.json`) | Page-image links for decimal-cited documents | document |

Two structural facts worth stating because they define the gap:

- **No surface anywhere relates one collection to another.** `CollectionDetailView`'s five
  sections are all about *one* record; the two graph views in the app are cross-references and
  person co-mentions. "Which collections travel together" is currently unanswerable in-app.
- **Source Explorer contains zero charts** (`grep -l "import Charts"` over
  `FRUSExplorer/SourceExplorer/` → 0 files). All archival presentation is list-grain.

---

## 3. Data inventory (measured 2026-08-08)

| Artifact | Size | What it contributes to this feature |
|---|---|---|
| `collection-authority.json` (schema 1, 2026-08-06) | 1.9 MB | **The backbone.** 4,423 collection records: canonical name, repository, record group, lot key, NAID (938 resolved), aliases (5,444 forms), **`volumeIds`** (11,804 memberships, from front matter *and* document notes), 7,656 sub-series children |
| `manifest.json` | 782 KB | `dateRange` / `subseries` / `publicationDate` per volume — the time axis for every era attribution (same join SA-3a uses) |
| `source-provenance-index.json` (SA-3a) | 4.5 KB | Decade × category counts — the shipped coarse grain |
| `volume-sources-index.json` (schema 2) | 952 KB | 2,929 `majorCollections` with volume lists; per-volume front-matter prose; RG/lot resolutions |
| `lot-claimants-index.json` (#675) | 125 KB | 118 lots claimed by >1 NARA series (up to 13 claimants) — the "NARA divided it" interrelationship |
| `presidential-library-catalog.json` (#681) | 3.3 MB | 11 libraries, 3,837 collections, 14,656 series with NAIDs |
| `central-files-index.json` | 3.5 MB | Decimal/lot/series NAID resolutions; numerical-file rolls |
| `curated-library-resolutions.json` + `curated-lot-resolutions.json` | 134 KB | Hand-curated finding-aid links |
| `digitized-ranges-index.json` + `roll-scans-index.json` | 472 KB | Which cited decimal ranges/rolls have page images |
| `administration-profiles-index.json` (SA-2a) | 171 KB | Administration attribution per volume — an alternative era axis |
| **Local index** (per user, indexed volumes only): `document_sources` | — | Per-document `repository` / `record_group` / `lot_file_norm` / `decimal_class` / `citation_era` / `classification`, already indexed for equality lookups |
| **Local index**: `volume_sources`, `cross_references` | — | Per-volume collection outline; the resolved citation graph |
| `Planning/source-explorer-export/` (committed aggregates of the 264k-record export) | — | Generation-time proof of what a new aggregate can hold: strategy × outcome × decade over the full corpus |

Interrelationship measurements (Python over `collection-authority.json`, 2026-08-08):

- Collections with ≥2 citing volumes: **1,577**; with ≥5: **418**; maximum spread: **157
  volumes** (a Central Files umbrella record).
- Volume → collection inverted index: **356 volumes** carry ≥1 clustered collection; median
  **30** collections per volume, max **358**.
- Co-citation pairs: **261,847** distinct; **40,538** share ≥2 volumes; **4,550** share ≥5.
- The strongest pairs are historically meaningful, not noise: *Presidential Correspondence Lot
  66 D 204 ↔ Central Files* (68 shared volumes), *S/S–NSC Files Lot 63 D 351 ↔ S/S–NSC
  (Miscellaneous) Files Lot 66 D 95* (67), *Whitman File ↔ Central Files* (61) — the
  Eisenhower/Kennedy-era State–NSC paper circuit, visible from the artifact alone.

Authority join quality (from `collection-authority-report.txt`, 2026-08-06): front-matter
items land in an authority record at 81.3% overall (lot-keyed 100%); document notes land at
83.5% (1961–68), 82.6% (1969–76), 67.2% (1977–88), 36.8% (1946–60, where decimal citations
still dominate), **2.7% (pre-1946)** — see §5.1.

---

## 4. Candidate insights, each with derivation and cost

Ordered by (value ÷ cost). A/B/C/D are the recommended core; E–H are riders and stretch.

### A. "Related Collections" on `CollectionDetailView` — *no new data, smallest step*

A sixth section on the existing detail view: the top-N collections by shared-volume count
(overlap coefficient or Jaccard to damp the umbrella records), each row tappable to its own
`CollectionDetailView`, with the shared count disclosed ("cited alongside in 12 volumes").
Derivation: intersect `volumeIds` against the loaded authority — the store is already
warm-grouped off-main for the browser. **Effort S.** This alone answers "interrelationships"
at the grain a researcher meets it: *I'm looking at Lot 63 D 351 — what else was this
material's neighborhood?*

### B. Collection co-citation ego graph — *no new data*

Reuse the CA-8 Canvas pattern (`PersonCoMentionGraphView` is an ego graph with thresholds —
the right shape here too; a global 4,423-node hairball is explicitly not proposed). Focus
collection at centre; edges = shared volumes above a threshold slider; node tap re-centres;
"open collection" passthrough. Repository-coloured nodes give the State ↔ NSC ↔ presidential
library structure at a glance. **Effort M** (the view model, layout, and accessibility
patterns are all established by CA-8). Home: launched from `CollectionDetailView` and the
macOS Source Explorer window.

### C. Collection-over-time views — *no new data for the volume-weighted version*

- **Per-collection timeline** on the detail view: its citing volumes laid on the coverage
  axis (`volumeIds × manifest.dateRange`) — a collection's *lifecycle in FRUS sourcing*
  (when it enters the record, when it fades). Effort S.
- **Era × repository / era × top-collections** series charts: for each coverage era, the
  top collections by citing-volume count. Honest at volume weight today; document weight
  needs D. Effort S–M.

### D. `collection-usage-index.json` — *the one new artifact; closes #267 in the same session*

Per-(authority collection id, volume id) **document counts**, plus per-volume provenance
category counts (#267's exact ask), rolled up by coverage decade. Everything needed is
already computed by `SourceExplorerExportGenerator` (parity-pinned parser + 4-step
`AuthorityLookup` mirror); this is an aggregation pass over the same scan, emitted as a
bundled artifact instead of the gitignored 182 MB export. Int-indexed collection ids against
the authority's `id` field keep it compact — estimated **~300–500 KB** (11,804 membership
pairs + counts + a 501-volume × ≤10-category table).

This is deliberately a **separate artifact**, not new fields on `collection-authority.json`
— same reasoning as `lot-claimants-index.json`: the authority is identity, this is usage,
and the recorded "no document counts in the authority" decision stands.

Unlocks: document-weighted "top collections per era/administration" (the difference between
"cited in 30 volumes" and "supplied 4,100 documents"); true volume scoping on the shipped
SA-3 dashboard (#267); edge weights for B that reflect documents rather than volume
membership. **Effort: one generator session + tolerant decode**, the app-side consumers
being A–C's views.

### E. "In Your Library" archival profile — *local index, no new data*

For indexed volumes, `document_sources` supports per-user distributions the bundled
aggregates can't: repository / record-group / `citation_era` composition of *your* library,
with the standing 258-of-552 coverage disclosure. Extends the existing
`localCollectionStats` grain from one collection to the whole library. Effort S–M. This is
also where **editorial-practice change** (`citation_era` composition by publication era —
named in the original S4 blueprint but not shipped) can live without a new artifact.

### F. Divided-lot / NARA-structure panel — *bundled, UI only*

`lot-claimants-index.json` already ships 118 multi-claimed lots (64 D 563 rides 245
documents across 12 series). A small "how NARA reorganised FRUS's citations" insight —
table + link-outs — inside the same feature. Effort S.

### G. Digitisation coverage over time — *bundled, secondary*

Join D (or the volume-weighted proxy) against `digitized-ranges-index` / `roll-scans-index`:
"what share of the cited archival base has page images, by era." Worth designing only after
the N-7 consumer ships; the indexes are new and their in-app consumption is still settling.
Effort S once N-7 is stable.

### H. Stretch — archival hand-off matrix (cross-references × provenance)

The one *document-grain* interrelationship that genuinely exists: document A (from
collection X) cross-references document B (from collection Y). Joining `cross_references` ×
`document_sources` locally yields a directed collection-to-collection flow matrix ("NSC files
cite into Central Files; presidential library material cites into lot files"). Feasible
today **for indexed volumes only**; corpus-wide it wants #262 (bundled resolved-edge
manifest), which has its own open size/shape design. Park behind #262 — do not let it gate
A–D.

---

## 5. Honest limits (in-UI disclosures, house style)

1. **Era asymmetry is structural, not a parser gap.** Pre-1946 document notes land in
   distinct authority collections at 2.7% — because the sourcing *was* the Central Decimal
   File, cited by file number, not by named collection. Collection-grain analytics are a
   1946–1988 story (83–84% landing in the '60s–'70s), thinning again post-1988 as volumes
   still in declassification trail off. Every era view needs the same disclosure pattern
   SA-3 already uses for its pre-1900 floor — and the asymmetry itself is the finding: the
   feature would *show* the central-file-to-decentralised-sourcing transition, which is the
   documented arc of FRUS historiography.
2. **"Co-cited" is volume-grain.** Two collections sharing a volume co-fed one editorial
   compilation; that is not document-level affinity. There is no document-grain
   co-citation: a document has one source note (the copy consulted). The affordance must say
   "cited together in N volumes," never imply more. (H is the exception, and it is a
   different relation — reference flow, not shared provenance.)
3. **Umbrella hubs.** "Central Files"-type records (157 volumes) and the biggest lots will
   dominate any naive network. B needs either a hub cap, an exclude-toggle mirroring SA-3's
   category filter, or overlap-coefficient weighting — pick at design time, disclose in the
   caveat line.
4. **The authority deliberately under-merges.** 460 same-segment/different-repository
   clusters are left unmerged (e.g. "Ball Papers" at Johnson vs. Kennedy Library). Related-
   collection lists inherit that: two records that are arguably one collection appear as
   two. Correct behaviour — merging on ambiguity would be worse — but a reviewer should know.
5. **356 of 552 volumes** appear in authority volume lists (501 parsed; the gap is volumes
   whose notes never name a clusterable collection). Coverage lines on every aggregate view,
   per the no-silent-truncation rule.
6. **Refuted routes stay refuted** (Feature-Priorities-Review §1): no creator-org similarity
   (#405, 2.8% reach), no lot sibling-inheritance (52.4% precision), no namedFileSeries
   title-matching (0/4,986). Nothing in A–H depends on any of them.

---

## 6. Recommended shape and sequencing

**Home:** split by audience, matching the corpus/series split already governing analytics.
Exploratory, collection-grain surfaces (A, B, C-timeline, E, F) live in **Source Explorer**,
where the collection objects and their navigation already exist. The series-level narrative
(era × collection rankings, digitisation coverage) extends the **Research Guide's "About the
Series"** dashboards — either as SA-3 v2 drill-down or a fifth `EducationDashboard` case (the
enum + exhaustive switch is the designed extension point). Deep-link both directions with the
existing `ResearchGuideLinkButton` / Source Explorer routing.

| Phase | Content | New data? | Effort |
|---|---|---|---|
| 1 | A (Related Collections section) + C-timeline on `CollectionDetailView`; F rider | No | 1 session |
| 2 | D: `collection-usage-index.json` generator + #267 fold-in + SA-3 tolerant decode | **Yes** (one artifact, ~0.5 MB) | 1 generator session |
| 3 | B (ego graph) + era × collection dashboard views consuming D; E rider | No | 1–2 sessions |
| — | G after N-7 settles; H parked behind #262 | — | — |

Phase 1 ships user-visible value with zero artifact risk and validates the interrelationship
UX before the graph work. Phase 2 is the only data work and pays twice (this feature + #267).
Phase 3 is presentation over data that will already exist.

**Fit against current priorities:** this is §5a territory — "the most on-brand cluster" —
and does not collide with the P1 sync wave or the P2 discovery lane (different code, different
data). Natural slot: after the N lane finishes, or interleaved as the small sessions they are.
Nothing here touches SwiftData models, so the CloudKit R-7 deploy gate is untouched; all of it
is offline-first bundled-JSON + local-SQLite work, consistent with the app's posture. New
chart surfaces should adopt the shared `AXChartDescriptor` work (#268) when it lands.

**Total estimated cost to the full recommended feature: 3–4 sessions**, one of which is a
generator session with no UI. No new network dependency, no schema bump to the FTS5 index
(E reads existing tables), one new ~0.5 MB bundled resource (needs the standard
`xcodegen generate` + scheme-restore enrolment once).

---

## Version history

- 1.0 (2026-08-08) — initial assessment: verdict, shipped-surface inventory, artifact
  measurements (co-citation counts over `collection-authority.json`), candidate insights A–H
  with derivations, honest-limits list, and the three-phase recommendation with #267 fold-in.
