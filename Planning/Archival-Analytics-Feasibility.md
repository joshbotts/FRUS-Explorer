# Archival Analytics — Feasibility Assessment

**Date:** 2026-08-08 · **Version:** 1.3 · **Status:** plan of record with design integrated
(§7); no code changes ride this document. Design contract: `Archival-Analytics-Design-Handoff.md`
(in this folder — the verbatim handoff README; annotated HTML mock + PNGs stay with the owner's
zip).

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
4. **(Added 1.1, on owner question.) The pre-1946 era is reachable at that era's own grain —
   the decimal class.** v1.0 conceded the era because only 2.7% of pre-1946 notes land in
   *named* authority collections; but that is the wrong unit for the period. Measured over
   the committed export sample (n=1,323, every 200th record): **93–98% of 1910s–1940s
   documents carry a decimal-class archival-neighbor key** (`derived.archivalNeighborKey`),
   which the app already treats as first-class (`document_sources.decimal_class`, indexed;
   class-keyed Archival Neighbors). And the corpus-wide cross-reference harvest
   (`CrossRefValidationGenerator`: 2,713,736 refs scanned, 652 broken) supports an
   **aggregated class↔class reference-flow matrix** computed at generation time — no #262
   dependency for the aggregate. See §4-I and the revised §5.1.

The honest limits (§5) are grain-dependent era coverage — *named-collection* analytics are a
1946–1988 story, extended to ~1910 by the class grain, with the structural floor at pre-1906
where documents carry no source notes at all — and the volume-grain meaning of "co-cited"
(§5.2). Both are disclosable in-UI in the house style, and the era asymmetry is itself the
historical finding the feature would surface.

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

### H. Archival hand-off matrix (cross-references × provenance) — *upgraded in 1.1*

The one *document-grain* interrelationship that genuinely exists: document A (from
collection X) cross-references document B (from collection Y). Joining `cross_references` ×
`document_sources` locally yields a directed collection-to-collection flow matrix ("NSC files
cite into Central Files; presidential library material cites into lot files"). Feasible
today **for indexed volumes only**.

**1.1 correction:** v1.0 parked the corpus-wide version behind #262, which was too
conservative. #262 is about shipping the **per-edge** list (the big artifact with the open
size/shape design). The *aggregated* flow matrix needs no per-edge shipping: at generation
time, `CrossRefValidationGenerator`'s Pass B already captures every ref with its enclosing
source document (2,713,736 refs scanned across 694 volumes, 652 broken), and the export scan
already knows every document's provenance unit. One join, emitted as a
provenance-unit × provenance-unit matrix, is a small bundled aggregate. Per-edge browsing
("show me the citations behind this cell") still degrades to indexed volumes until #262
ships — disclose, don't block.

### I. Early-era extension: class-grain interrelationships, 1910–1949 — *added in 1.1*

*(Prompted by owner question: why not leverage central-file archival neighbors +
document cross-references to extend interrelationships to the earlier era?)* The answer:
yes — the era is reachable, provided the analytic unit switches to what the era's archive
actually was. Pre-1946 FRUS cites the Central Decimal File by file number; the **class**
segment of that number (763.72, 812.00, 861.00) is the subject-file unit researchers pull
at NARA, and the app already extracts and indexes it.

**Measured key coverage** (committed export sample, n=1,323, every 200th record;
`derived.archivalNeighborKey` presence — script run 2026-08-08):

| Decade | Sampled docs | With neighbor key | Share |
|---|---|---|---|
| 1900s | 10 | 0 | 0% (numerical file — see below) |
| 1910s | 147 | 141 | 96% |
| 1920s | 99 | 97 | 98% |
| 1930s | 197 | 194 | 98% |
| 1940s | 368 | 342 | 93% |
| 1950s | 210 | 163 | 78% |
| 1960s | 143 | 78 | 55% (lot/CFPF transition) |

Corpus scale: `centralDecimalFile` is the largest strategy in the export — 193,675 of
264,464 document notes — with ~160k of them pre-1950. Against the 2.7% named-collection
landing rate for pre-1946, the class key is the difference between "no early-era data" and
"the era's richest per-document key."

Three views, all riding infrastructure that exists:

- **Class co-occurrence** — which subject files feed the same volumes (the early-era
  analogue of A/B). Same intersect-and-threshold machinery, keyed on
  `document_sources.decimal_class` locally and the export's class field at generation time.
- **Class↔class reference flows** — the H join restricted to decimal classes: documents
  filed under 763.72 (the World War) citing documents filed under 861.00 (Russia, internal
  affairs) maps the file system's internal wiring as the editors traversed it. Genuinely
  novel; no equivalent exists anywhere.
- **Class over time** — a class's document volume across coverage years, segmented by the
  decimal file's own chronological blocks (1910–29 / 1930–39 / 1940–44 / 1945–49…), which
  the Archival Neighbors query already encodes (`ArchivalNeighborsDocKey.documentYear`
  drives the same segmenting). Classes even resolve toward NARA series/rolls via
  `central-files-index.json` and `digitized-ranges-index.json`, so class rows can link out
  the same way collections do.

**Design riders:** (a) *Labels.* Class numbers need human names ("763.72 — European War").
Partially available from the authority's class-keyed sub-series children (front-matter
names); the gap wants a small bundled class-schedule label table from NARA's public-domain
decimal classification guides — a data-curation rider, not a parser change. (b) *Unit
honesty.* A class is a subject file, not a provenance collection; the UI must not present
class nodes and collection nodes as the same kind of thing. The natural seam is a mode/lens
switch on the same views, mirroring how Archival Neighbors already distinguishes
class-keyed from lot-keyed queries.

**The two remaining era gaps, stated precisely:**

- **1906–1910 (Numerical File):** the case number is already parsed
  (`"File No. 774–44"` → case 774, resolving to specific microfilm rolls), but
  `supportsArchivalNeighbors` is deliberately `false` today — case numbers are not decimal
  classes and the neighbor query would find nothing in `decimal_class`. Case-grain
  neighbors + analytics are a small, real extension (the case *is* a subject unit), but it
  needs its own small eval before trusting, per house discipline.
- **Pre-1906:** the structural floor. Documents carry **no source notes**;
  `CentralFilesClassifier` already infers the country-arranged series from datelines
  (confidence-tagged, display-only), but that is inference, not citation — and country-series
  interrelationships would largely reproduce the volumes' own country-chapter organization.
  Keep pre-1906 out of the analytics substrate; the classifier's Source Explorer surface
  remains the right exposure.

---

## 5. Honest limits (in-UI disclosures, house style)

1. **Era asymmetry is real but grain-dependent** *(revised in 1.1)*. *Named-collection*
   analytics are a 1946–1988 story: pre-1946 document notes land in distinct authority
   collections at 2.7%, because the sourcing *was* the Central Decimal File, cited by file
   number, not by named collection. At the **class grain** (§4-I) the same era is richly
   keyed — 93–98% of sampled 1910s–1940s documents carry a class key — so the feature
   extends to ~1910 by switching units, not by forcing collections where none were cited.
   The structural floor is **pre-1906**: no source notes exist, and the dateline classifier
   is inference, not citation. Every era view needs the same disclosure pattern SA-3
   already uses for its pre-1900 floor, plus the unit-switch disclosure (§4-I rider b) —
   and the asymmetry itself is the finding: the feature would *show* the
   central-file-to-decentralised-sourcing transition, which is the documented arc of FRUS
   historiography.
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

**Home:** *(superseded by the approved design — see §7.2; original recommendation kept below for
the record)* split by audience, matching the corpus/series split already governing analytics.
Exploratory, collection-grain surfaces (A, B, C-timeline, E, F) live in **Source Explorer**,
where the collection objects and their navigation already exist. The series-level narrative
(era × collection rankings, digitisation coverage) extends the **Research Guide's "About the
Series"** dashboards — either as SA-3 v2 drill-down or a fifth `EducationDashboard` case (the
enum + exhaustive switch is the designed extension point). Deep-link both directions with the
existing `ResearchGuideLinkButton` / Source Explorer routing.

| Phase | Content | New data? | Effort | Tracker |
|---|---|---|---|---|
| 1 | A (Related Collections section) + C-timeline on `CollectionDetailView`; F rider | No | 1 session | **#762 — shipped 2026-08-08** |
| 2 | D: `collection-usage-index.json` generator + #267 fold-in + SA-3 tolerant decode; **class × volume counts ride the same export scan (I)** | **Yes** (one artifact, ~0.5 MB) | 1 generator session | **#763** |
| 2b | H/I flow matrix: `CrossRefValidationGenerator` harvest × export provenance-unit join → bundled aggregate; class labels table rider | **Yes** (small aggregate + label table) | 1 generator session | **#764** |
| 3 | B (ego graph) + era × collection dashboard views consuming D; class lens (I) on the same views; E rider | No | 1–2 sessions | **#765** |
| — | G after N-7 settles; numerical-file case grain (I) behind its own eval; per-edge flow browsing behind #262 | — | — | recorded here only |

Phase 1 ships user-visible value with zero artifact risk and validates the interrelationship
UX before the graph work. Phase 2 is the main data work and pays twice (this feature + #267);
2b is separable and can trail — the class-grain *co-occurrence* views need only Phase 2, and
the flow matrix is additive. Phase 3 is presentation over data that will already exist.

**Fit against current priorities:** this is §5a territory — "the most on-brand cluster" —
and does not collide with the P1 sync wave or the P2 discovery lane (different code, different
data). Natural slot: after the N lane finishes, or interleaved as the small sessions they are.
Nothing here touches SwiftData models, so the CloudKit R-7 deploy gate is untouched; all of it
is offline-first bundled-JSON + local-SQLite work, consistent with the app's posture. New
chart surfaces should adopt the shared `AXChartDescriptor` work (#268) when it lands.

**Total estimated cost to the full recommended feature: 3–5 sessions**, one or two of which
are generator sessions with no UI. No new network dependency, no schema bump to the FTS5
index (E and the local class queries read existing tables and indexes), two new small
bundled resources (each needs the standard `xcodegen generate` + scheme-restore enrolment
once).

---

## 7. Design integration (2026-08-08 handoff)

The owner's design handoff (contract: `Archival-Analytics-Design-Handoff.md`; annotated mock +
five PNG captures in the source zip) is now the **design of record** for #762–#765. This section
records what it decides, where it supersedes §6, what it adds to each issue, and what was verified
against the tree before integration.

### 7.1 What is approved, and what is explicitly not to be built

- **Approved as-is:** mock `1a` (#762 detail sections), `1b` (Collections mode), `1i` (Your
  Library mode).
- **Approved revised directions:** `2a` (Network — repository sectors with umbrella expansion),
  `2b` (Flows — user-chosen focus, no top-N cap).
- **Explored, NOT to be built:** `1c`/`1e` (network alternatives), `1f`/`1g` (flow alternatives).
  `1f`'s heat matrix may return later as a "View as table"-style secondary representation only.
- Amber dashed notes in the mock are annotations, not UI. **Caveat/disclosure strings are
  copy-final** — they carry into `String(localized:)` verbatim.
- Fidelity rule: high-fidelity in **structure and copy**, native in implementation — system
  colors/fonts/materials, `List` inset-grouped, `Picker(.segmented)`, `.bordered` menu chips,
  `Canvas`, Swift Charts. The mock's hex values exist only to imitate what the system gives free.

### 7.2 Home: the design supersedes §6's split (owner decision D-1)

§6 recommended splitting by audience — exploratory surfaces in Source Explorer, the era ×
collection narrative as a Research Guide "About the Series" extension. **The approved design
consolidates all four modes into one new `ArchivalAnalyticsView` in the Analytics family**
(alongside Corpus / Person / Cross-Reference Analytics and Word Cloud), explicitly *not* the
Research Guide.

Consequences, recorded:

- The surface **mixes grains behind one mode picker**: Collections/Network/Flows are corpus-wide
  (bundled artifacts, independent of the user's library); Your Library is per-user (local index).
  This departs from the corpus/series governance rule; the design's answer is explicit per-mode
  disclosure ("The corpus-wide modes are independent of what you have downloaded" / "computed from
  … *your* N indexed volumes"), which every mode carries copy-final.
- The Research Guide and SA-3 are **untouched**. Rider (Phase 3, small): SA-3's dashboard gains a
  cross-link into Archival Analytics ("explore at collection grain"), mirroring the existing
  `ResearchGuideLinkButton` pattern in the other direction.
- Entry points: macOS `Window("Archival Analytics", id: "frus.archivalAnalytics")` + Analytics
  menu item (the `menu.analytics.*` block); iOS a sixth Analysis Tools item presenting the same
  view. The macOS opener MUST be `openWindow.fronting(id:)` — `MacWindowFrontingTests` fails the
  suite on any bare `openWindow(id:)` (#749).

### 7.3 What the design adds to each issue (deltas vs. the filed scope)

**#762 (Phase 1)** — as filed, plus the design fixes placement and shape:
- Three sections insert after "In Your Library", before "Cited Across the Series" (both section
  names verified in `CollectionDetailView.swift`).
- Related Collections: top-5 cap + "Show all", overlap-coefficient ranking (decided — not
  Jaccard; damps umbrellas by dividing by the *smaller* volume list), 56×4pt overlap meter,
  copy-final volume-grain footer.
- Cited Over Time: BarMark card with **subseries-era buckets** ('48–50 … '77–88), not SA-3's
  decades — same `manifest.dateRange` join, finer axis; the enters/peaks/fades caption is
  **generated from the data**, following the mock's sentence pattern.
- Divided at NARA: render only when `LotClaimantsIndex.claimants(forRawLot:)` returns >1 for
  `record.lotFileNorm` (both APIs verified present).

**#763 (Phase 2)** — scope unchanged (`collection-usage-index.json`, #267 fold-in, class × volume
counts). The design consumes it as: the Documents|Volumes weight toggle (1b), document-weighted
class edges (2a), and the class info-card counts. **New verification gate added (D-3):** measure
**subject-numeric (1963–73)** class coverage during the generator session — the substrate exists
(`decimal_class` carries decimal *and* subject-numeric leaves since index v19; the export's
`decimalClass` comes from the same shared `CollectionKeying`), but §4-I only measured the decimal
era. The Network umbrella menu's third option ships only if this measures usable.

**#764 (Phase 2b)** — scope unchanged (flow matrix + class-label table). The design consumes it as
Flows mode: focus chip + unit-aware search, Outgoing|Incoming, **every** destination rendered with
the smallest flows grouped into an expandable remainder block (the no-silent-truncation rule as
UI), ribbon widths ∝ reference count, within-file references excluded *and disclosed*. Unfocused
state = corpus-wide top flows; per-edge browsing degrades to indexed volumes until #262, disclosed
with copy-final text. Label-table curation rule (D-2): every label row carries its **source
edition**; class numbers are era-scoped (763.72 is the 1910–49 schedule; the same number is not
assumed stable across schedule revisions).

**#765 (Phase 3)** — the shell + four modes. Design refinements over the filed scope:
- **Network is NOT force-directed.** The filed issue said "reuse the CA-8 Canvas pattern"; the
  design keeps CA-8's *chrome* (canvas + transparent hit-area buttons, pinned focus, viewport
  capsules, Reduce Motion, legend, permanently-reserved info dock) but replaces physics with a
  **deterministic sector layout**: four 90° repository wedges (central files / lot files /
  presidential libraries / other), radial distance = overlap strength, dashed guide rings at
  ≥.75/.50/.25.
- **Umbrella expansion with unit honesty:** the Central Files node expands into its cited classes
  as **rounded squares** inside a dashed hull (⊖ collapses); a class must never render as a
  collection (§4-I rider b made visual). Menu: Collapsed / Decimal classes / Subject-numeric
  (1963–73, gated on D-3). Class actions route to class-keyed Archival Neighbors
  (`ArchivalNeighborsRequest.decimalClass` — verified present), never a collection detail.
- **Hub handling (§5.3) is thereby decided:** overlap-coefficient weighting + a "Hiding: Central
  Files umbrella" filter chip in Collections mode with the copy-final "its bar would dwarf the
  scale" disclosure — not a hard cap.
- Collections mode time controls compose as: filter-row year chip + administration preset scope
  the data; the card's era segmented control selects which era's ranking is displayed.
- Your Library mode is #765's E rider as designed (three cards; existing `document_sources`
  columns; queries off-main; no new artifact, no schema bump).

### 7.4 Verified against the tree (2026-08-08, this branch)

Every code anchor the handoff names exists as named: `AdministrationPresetMenu`,
`AnalyticsScopeBar`/`AnalyticsYearRangeBar` (`AnalyticsChartChrome.swift`), `SeriesChartCard`,
`ChartDataInspectorView`, `ScrollWheelZoomCatcher`, `PersonCoMentionGraphView`,
`ArchivalNeighborsRequest.decimalClass(String)`, `CollectionRecord.lotFileNorm`/`.volumeIds`,
`LotClaimantsIndex.claimants(forRawLot:)`, the off-main-warmed `CollectionAuthorityStore`, and the
`menu.analytics.*` command block. Standing constraints that intersect: new bundled artifacts each
need the one-time `xcodegen generate` + scheme restore; `FRUS-API.openapi.yaml` gains the new
queryable surfaces (audit-suite-enforced validity); nothing touches SwiftData models, so the R-7
CloudKit gate stays untouched; new charts adopt `AXChartDescriptor` (#268) when it lands; every
chart card joins the D3 provenance-stamped export.

### 7.6 Measured in Phase 1, and binding on Phase 3 (#762 → #765)

Two findings from building #762 that the later phases must start from rather than rediscover.

**The overlap coefficient is degenerate without a support floor.** §7.3 recorded the metric as
decided; implementing it showed the metric alone does not produce a usable list. Measured on the
2026-08-06 artifact: the coefficient is `shared ÷ min(|A|,|B|)`, so it reaches exactly 1.000 for
*any* record whose citing-volume list is a subset of the focus record's — and **2,846 of the 4,423
records cite a single volume**, so **77.8% of all co-citing pairs tie at 1.000**. Ranked on the
score alone, **80.3%** of the top-5 slots for records citing 20+ volumes go to one-volume records
sharing one volume, a third of those records getting a top-5 that is entirely that. Shipped
resolution, and the one #765's Network mode should adopt for its edge weights and threshold
slider: **require two shared volumes** (which removes the class outright — a one-volume record
cannot share two, at a cost of 19 of the 1,577 multi-volume records), then tie-break on shared
count, then on the partner's own breadth ascending. The tie-breaks are not cosmetic; with
coefficients saturating this widely they decide most orderings.

For contrast, the thing the coefficient is there to prevent is also measured: on raw shared count
the "Central Files" umbrella is the top answer for **461 of the 1,557** collections that have a
list — roughly one in three.

**Generated prose must be guarded clause by clause.** The "enters / peaks / fades" caption is
written from the data, and every clause is a claim about the chart beside it. Three shapes make a
naive generator lie, all present in the shipped corpus: a maximum that recurs after a dip (9 of
the 600 charting records — the caption named the earlier occurrence as *the* peak and then claimed
a fade, with the last bar drawn just as tall); a span with an empty era in the middle (44 records —
"runs through" asserts a continuity the chart denies); and one volume per era, where there is no
trend to describe at all. #764's flow copy and #765's dashboard captions inherit this: **a
generated sentence needs a test that it cannot contradict its own chart**, not only that it renders.

**Also settled here:** the coverage-era axis (`CollectionRelations.coverageEras`) is reusable by
#765 — the published subseries from 1955, the design's `1948–1950` / `1951–1954` groupings before
that, decades earlier, attributed by SA-3a's own `dateRange`-midpoint rule so the two surfaces
agree on which era a volume belongs to.

### 7.5 Decisions log

| # | Decision | Status |
|---|---|---|
| D-1 | One unified Archival Analytics surface supersedes §6's Source-Explorer/Research-Guide split; Research Guide untouched; SA-3 cross-link rider in Phase 3 | **Confirmed by owner 2026-08-08** — one surface; SA-3 cross-link rider stays |
| D-2 | Class-label table: era-scoped labels, per-row source-edition stamp; curate the 1910–49 decimal schedule first | **Confirmed by owner 2026-08-08** — 1910–49 schedule first, per-row edition stamps |
| D-3 | Subject-numeric umbrella option gated on a coverage measurement in the #763 session; ships Collapsed/Decimal-only if thin | **Confirmed by owner 2026-08-08** — measure in #763, gate the option |
| D-4 | Build in issue order #762 → #763 → #764 → #765, so the Documents weight toggle never ships disabled | Decided (follows the filed phase order) |

---

## Version history

- 1.4 (2026-08-08) — Phase 1 shipped (#762). Adds §7.6, the two findings from building it that
  bind the later phases: the overlap coefficient needs a two-shared-volume support floor and
  meaningful tie-breaks before it ranks anything usefully (measured — 77.8% of co-citing pairs
  tie at 1.000, and 2,846 of 4,423 records cite one volume), and a generated caption needs a test
  that it cannot contradict its own chart (three lying shapes found in the shipped corpus). Also
  records the coverage-era axis as reusable by #765, and marks Phase 1 shipped in the §6 table.
- 1.0 (2026-08-08) — initial assessment: verdict, shipped-surface inventory, artifact
  measurements (co-citation counts over `collection-authority.json`), candidate insights A–H
  with derivations, honest-limits list, and the three-phase recommendation with #267 fold-in.
- 1.1 (2026-08-08) — early-era extension, on owner question ("why not central-file archival
  neighbors + cross-references for the earlier era?"). Added §4-I (class-grain
  interrelationships 1910–1949, with measured neighbor-key coverage per decade from the
  export sample: 93–98% for the 1910s–1940s), upgraded §4-H (the aggregated flow matrix
  needs no #262 — `CrossRefValidationGenerator`'s 2.71M-ref harvest supplies the join at
  generation time; only per-edge browsing stays behind #262), revised §5.1 (era asymmetry is
  grain-dependent; the structural floor is pre-1906, where documents carry no source notes
  and `CentralFilesClassifier` is inference, not citation), and re-sequenced §6 (Phase 2
  carries class × volume counts; new Phase 2b for the flow matrix + class-label rider;
  numerical-file case grain parked behind its own eval).
- 1.3 (2026-08-08) — design integration: the owner's UI handoff recorded as design of record
  (§7; contract copied in-repo as `Archival-Analytics-Design-Handoff.md`). Supersedes §6's home
  recommendation (one Analytics-family surface, four modes — D-1); records the per-issue design
  deltas (deterministic sector network, umbrella expansion with unit honesty, no-cap flows,
  subseries-era timeline buckets, overlap-coefficient hub handling); verifies every named code
  anchor against the tree; adds the decisions log (§7.5) with the subject-numeric measurement
  gate (D-3) and the class-label curation rule (D-2).
- 1.2 (2026-08-08) — tracker enrolment: the four phases filed as issues #762 (Phase 1),
  #763 (Phase 2, folds in #267), #764 (Phase 2b), #765 (Phase 3); §6 table gains the
  Tracker column. Parked items (G, case grain, per-edge browsing) deliberately have no
  issues — they are recorded here and in the issues' scope-boundary notes.
