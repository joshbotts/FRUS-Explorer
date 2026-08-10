# Archival Analytics — Adversarial Review Against the Researcher-Value Bar

**Date:** 2026-08-10 · **Version:** 1.0 · **Status:** review for owner — no code rides this
document. Companion to `Archival-Analytics-Feasibility.md` (the plan of record, v1.9), which this
review deliberately re-litigates from one specific angle.

**The bar this review applies, as the owner set it:** corpus-wide aggregates are interesting, but
the feature has to deliver most of its value by helping researchers understand **what archival
sources to consult beyond FRUS to answer their own targeted research questions** — alongside the
two descriptive goals: how source notes and external citations illuminate **relationships among
archival collections and central-file segments** (decimal and subject-numeric), and **what records
FRUS's editors used** to document the official history.

**Inputs:** the tree at `abf92f0` (branch lineage of build 40); the bundled artifacts as of
2026-08-10 (`collection-usage-index.json` 2026-08-08, `provenance-flow-index.json` 2026-08-08,
`external-citation-index.json` 2026-08-10, `collection-authority.json` 2026-08-06); the
plan-of-record documents (`Archival-Analytics-Feasibility.md`, `Archival-Analytics-Design-Handoff.md`,
`Research-Trip-Packet-Scope.md`, `DEVELOPMENT-PLAN.md` #784/F-2 sessions); the open tracker
(24 open issues, checked 2026-08-10); a full navigation census of the archival surfaces (every
entry point and action verified in code, cited by file:line below); and fresh measurements over
the bundled artifacts (Python over the shipped JSON, run 2026-08-10 on this branch; band
attribution by `dateRange`-midpoint thresholds ≤1947/≤1960/≤1968/≤1976, which reproduces the
app's own per-band volume counts of 261/120/64/66/41 exactly).

---

## 1. Verdict up front

Judged as **description** — what records the editors used, era by era, and how the archival units
travel together — the feature is strong, unusually honest, and already renders the wave's central
finding (the record's migration from State's filing rooms to the White House). Judged against the
owner's stated bar — **turning a researcher's own question into archival guidance** — the shipped
feature under-delivers, and the shortfall is not in the data. Measured below, the bundled
artifacts already answer targeted questions well (a Vietnam-scoped ranking differs from the
corpus band ranking in 7 of its top 12 rows; a Suez-scoped class list is almost disjoint from the
band's). What is missing is entirely presentational and navigational, and most of it was in the
approved design:

1. **No scoping.** Collections mode ranks only five fixed corpus-wide era bands. The approved
   design's own filter row (`AnalyticsScopeBar` + year chip + `AdministrationPresetMenu`) was not
   built, and — unusually for this repo — the deviation is recorded nowhere. Archival Analytics
   is now the **only** analytics surface in the app with no volume/subseries scope; even its
   sibling SA-3 dashboard gained one under #267.
2. **Every mode is a dead end.** No mode can open a collection's detail record — the one place
   the NARA catalog link, aliases, citing volumes, Related Collections, and Divided-at-NARA
   live. The only action anywhere is Archival Neighbors, which reads the user's local index and
   returns an honest-empty list for exactly the user most in need of guidance (few volumes
   indexed). The design's "Open Collection" dock action was dropped, also unrecorded.
3. **The feature is an island.** Nothing deep-links in (structurally: the view takes no
   parameters); no research surface (document, search, volume, person, project) leads to it; the
   Research Guide documents every other analytics surface's "Find it from…" but never names this
   one; the SA-3 cross-link shipped macOS-only (#798 tracks the iOS half).

The rest of the review substantiates these, adds seven more findings (grain inconsistency in the
class lens, unused denominators, unlabeled classes, the external-citation decimal gap, flow
time-blindness, actionability ceilings, data warts), grades the feature against the two
descriptive goals, answers the owner's "does this framing make sense" question, and prices the
recommendations — most of which are small, because the artifacts were built better than the
surfaces that consume them.

---

## 2. What the review confirms is working

Credit first, because the foundations are genuinely good and the recommendations below depend on
them:

- **The honesty culture holds under adversarial reading.** Every caveat this review checked is
  real, measured, and read off the artifact rather than hard-coded: the 95.3% footnote share, the
  per-band umbrella disclosure, the Documents/Volumes population split, the era-span statement on
  the unprinted layer that corrects #784's own headline claim. The `heaviestPairs` corpus-wide
  external view correctly excludes same-unit pairs (checked because the raw artifact's three
  heaviest pairs *are* self-loops — `NSC Files → NSC Files` at 2,029).
- **The central historical finding renders.** Ranked by documents, umbrella hidden: `Lot 54–D270`
  through 1947 → `Whitman File` 1948–60 → Johnson `National Security File` 1961–68 → Nixon
  `NSC Files` 1969–76 → Carter `National Security Affairs` 1977–92. Goal 2 (what the editors
  used) is served at corpus grain.
- **Unit honesty (collection ≠ class) is enforced visually and in routing** — squares vs
  circles, class actions never open a collection detail.
- **The refusals are correct.** The class-flow surface (1.7 refs/pair), the per-citation local
  browse (would contradict the diagram it sits under), the faked SA-3 volume scope — each was
  refused for a measured reason, and this review found no case where a refusal should be
  reversed as-is.
- **The one healthy archival loop** — document → Research rail *Sources* → Source Explorer →
  `CollectionDetailView` → Related Collections → Archival Neighbors → documents — works, is
  self-contained, and is the model the analytics surfaces should be wired into.
- **`collection-usage-index.json` was built to a higher standard than its consumer.** It carries
  per-volume grain and per-volume note-count denominators that the shipped mode never reads —
  which is the reason most of §6's recommendations are cheap.

---

## 3. Findings

Ordered by how much they cost the stated bar. F-1 through F-3 are the substance; the rest are
real but smaller.

### F-1 · The targeted-research gap: the data is per-volume, the UI is corpus-only

`collection-usage-index.json` stores every count per **(unit, volume)**. The shipped Collections
mode collapses that to five fixed era bands (`ArchivalAnalyticsView.swift:296-364` — the filter
row offers era band, unit lens, weight, umbrella; nothing else). The approved design's filter row
specified `AnalyticsScopeBar`/`AnalyticsYearRangeBar` chips plus `AdministrationPresetMenu`
(`Archival-Analytics-Design-Handoff.md` §2; feasibility §7.3 restates it). None shipped, and
§7.10/§7.11's decision log — which records four design premises the data refuted — does not
record this one. Grep confirms: `AnalyticsScopeBar|AdministrationPresetMenu` matches six files in
`Analytics/`, none archival.

**Measured, the scope is where the researcher value is.** Two probes, method as in the header:

- *Vietnam, 1961–1968.* The 11 Vietnam-titled volumes in the band, top collections by documents:
  Johnson `National Security File` (753), `Central Files 1967–69` (241), Kennedy
  `National Security Files` (159), `Taylor Papers` (102), `A/IM Files: Lot 93 D 82` (79),
  Johnson `Recordings and Transcripts` (79), `Tom Johnson's Notes of Meetings` (73),
  `Meeting Notes File` (46), `Hilsman Papers` (43), `Vietnam Working Group Files: Lot 67 D 54`
  (41). That list *is* a research itinerary. The whole-band top-12 shares only **5 of 12 rows**
  with it — the corpus band buries the Taylor Papers' Vietnam weight under the band's Kennedy
  Office Files, and the Vietnam Working Group lot does not appear at all.
- *Suez-era Near East, 1948–1960.* The 14 Near East/Arab-titled volumes' top classes: `501.BB`,
  `867N.01`, `868.00`, `684A.86`, `674.84A`, `974.7301`, `780.5`, `501.BC`, `891.00`, `890D.01`
  — the actual decimal files a researcher requests at College Park for this topic. The band's
  top classes (`740.5`, `795.00`, `740.00119`, `893.00`, `751G.00`…) share **two rows** with it.
  The band list answers "what did the fifties cite"; the scoped list answers "what should *I*
  pull".

The feature's stated purpose ("what records each era's editors actually worked in") survives the
corpus grain; the owner's bar does not. A researcher's question is almost never "the 1948–1960
band" — it is a topic × period, which in this app means a set of volumes, and the artifact
already counts by volume. **This is the highest-value gap in the feature and it is a view-layer
change.** (§6 R-1.)

### F-2 · Every analytics mode dead-ends short of the actionable record

The navigation census (verified in code, complete):

- **Collections mode:** the ranking is `BarMark`s with accessibility labels only
  (`ArchivalAnalyticsView.swift:424-453`) — no tap, no context menu, no route. The table
  inspector and CSV export both carry the **capped 12 rows** (`rankingInspector` maps
  `ranking.rows`; `ranking()` is called only with the default `rowCap`), so the full era list —
  e.g. the 1,000+ units the caption itself counts via `unitsReached` — is not obtainable
  anywhere in or out of the app. There is no "Show all". The no-silent-truncation rule is
  satisfied in letter (the caption states the count) but not in spirit (the reader cannot get
  the rest).
- **Network:** node actions are Explore This Collection (recentre) and Show Archival Neighbors
  (`ArchivalNetworkView.swift:483-511`). The approved design's dock listed **"Explore
  connections / Open Collection / Show shared volumes"** (`Archival-Analytics-Design-Handoff.md`
  §3); "Open Collection" and "Show shared volumes" were both dropped, unrecorded in §7.11's
  R-1…R-4.
- **Flows:** the flow card offers Show Archival Neighbors only (`ArchivalFlowsView.swift:551-563`).
- **Your Library:** the most-cited-collections rows open Archival Neighbors
  (`ArchivalAnalyticsView.swift:830-860`).

So no mode can reach `CollectionDetailView` — the surface holding the **NARA catalog link**
(`CollectionDetailView.swift:215-235`), aliases, the citing-volume list, Related Collections,
Cited Over Time, and Divided at NARA. The one action every mode does offer, Archival Neighbors,
reads the **local index**: for the reader with three volumes indexed who has just found a
compelling collection in a corpus-wide chart, it returns an honest-empty list, and there is then
no route at all to what the app knows about that collection. The class routing note
(`ArchivalAnalyticsView.swift:1077-1080`) justifies the class case; nothing justifies the
collection case.

Adjacent regressions and dead ends from the same census, listed because §6 R-2 should sweep them
together: `CollectionDetailView`'s "Cited Across the Series" rows are inert
(`CollectionDetailView.swift:533-547`) while the legacy surface they superseded makes the same
list navigable and its doc comment records that those rows "used to be dead ends"
(`VolumeSourcesView.swift:810-878`); Search's "Archival provenance" facet is descriptive-only —
not narrowable, no navigation from any bucket (`FacetPanelView.swift:62`, `:877-886`); the
reading view's source note is inert HTML (`FRUSRenderNodeHTMLSerializer.swift:632-658`; the rail's
Sources tile is the sole door, which is acceptable, but worth stating); non-class sub-series rows
on the detail view are inert (`CollectionDetailView.swift:590-614`).

### F-3 · The island problem: nothing leads in, and the view cannot receive a subject

`ArchivalAnalyticsView` declares no initializer — every mode/selection is `@State`
(`ArchivalAnalyticsView.swift:33-86`) — so a deep link is structurally impossible today, not
merely unwired. Both instantiation sites call it bare. Entry points are five: iOS Browse-tab
Analysis Tools menu (a sheet over Browse — it cannot sit beside a document), the macOS Analytics
menu/toolbar/Window list, and the SA-3 dashboard's cross-link, which is `#if os(macOS)`
(`SourceProvenanceDashboard.swift:479-499`; #798 tracks iOS). Network and Flows both open on
"choose a collection" pickers, so the reader must already know a collection's name to begin
(`ArchivalNetworkView.swift:623-631`). The Research Guide's walkthrough gives a "Find it from…"
line to every other analytics surface and never mentions this one (grep over `Onboarding/`:
zero matches for "Archival Analytics").

Consequence for the bar: the researcher's natural starting points — a document's source note, a
search result set, a volume, a person, a project — none of them can hand their context to the
one surface built to aggregate it. The healthy Source Explorer loop (§2) and the analytics
island do not touch.

### F-4 · The class lens ranks two grains in one chart, and disagrees with the Network

Owner decision **D-3** admitted the subject-numeric lens **folded to category + number**, "so
#765 calls it rather than re-deriving it." The Network's umbrella expansion calls it
(`ArchivalNetworkData.swift:324-330`). The Collections-mode class ranking does not — it tallies
raw `usage.classKeys` (`ArchivalCollectionsData.swift:248-303`), producing three defects at once:

- **Grain mixing within one chart.** Decimal rows are classes (`770G.00` — all of Congo);
  subject-numeric rows are leaves (`POL 23-9 THE CONGO`). Bars of different grain are not
  comparable, and the caveat block does not say this (it says only that two filing systems are
  present).
- **The 1961–1968 ranking splits its own heaviest unit.** Raw: `POL 27 VIET S` 463 top row.
  Folded: `POL 27` 1,090 — 2.3× the shown value, scattered across `POL 27 ARAB-ISR` (233),
  `POL 27-14 VIET` (138), `POL 27 CYP` (143), `POL 27 YEMEN` (92)… Subject-numeric material is
  **61.6%** of the band's class-keyed documents; the raw ranking under-states its rank.
- **The 1969–1976 ranking is the thin-leaf regime D-3 measured.** All 12 raw rows are
  subject-numeric leaves led by `UN 6 CHICOM` at 108; folded, `POL 7` (150), `UN 6` (114),
  `POL 27` (107), `POL 15-1` (101) lead. Subject-numeric is 99.9% of the band's class mass.

The counterargument deserves stating: the **leaf is the actionable unit** — `POL 27 VIET S` is
what a researcher writes on a pull slip, and folding it to `POL 27` discards the country. So the
right fix is not automatically "fold"; it is **one deliberate grain, disclosed, consistent across
the two surfaces** — e.g. rank folded groups and expand each row's constituent leaves on demand
(which also serves F-2's navigation). What ships today is two surfaces silently disagreeing with
each other and with the decision log. (§6 R-4.)

### F-5 · The denominators the artifact was built to carry are never read

`collection-usage-index.json` ships `volumeNoteCounts` — per CLAUDE.md, "the per-volume
source-note totals **every share needs as a denominator**." No code outside the decoder reads
them. Consequences, measured:

| band | notes in band | land in any named collection | the 12 shown rows cover |
|---|---|---|---|
| Through 1947 | 150,764 | 3.9% | 3.0% |
| 1948–1960 | 59,973 | 42.2% | 9.4% |
| 1961–1968 | 22,737 | 83.8% | 43.1% |
| 1969–1976 | 18,381 | 84.7% | 71.3% |
| 1977–1992 | 12,609 | 70.5% | 46.7% |

The default view (the mode opens on 1948–1960, named collections, documents) shows twelve bars
describing **9.4%** of the band's sourced documents, and nothing on screen says so. The caveat
block explains the era asymmetry qualitatively; the number is sitting in the bundle. A one-line
"the rows below account for N% of this band's 59,973 source notes; most of the remainder is the
central files, cited by file number" would convert the mode's weakest property into the era
finding it actually is — and the same denominators would let every bar carry a share. (§6 R-5.)

### F-6 · The pre-1946 record is shown in a notation nobody can read

The class lens is the *whole* named record before 1948 (F-5: 3.9% named-collection coverage
against 93–98% class-key coverage measured in feasibility §4-I), and it renders as bare numbers:
`793.94`, `740.00119`, `501.BB`. The D-2 label table was refuted in its planned source
(feasibility §7.8 Finding 3), refiled — and the refile produced **no tracker issue**: #764 is
closed, and no open issue carries it. The app's entire label inventory for the pre-1946 archival
record is the two examples in the info popover (`FRUSTheme.swift:252`). Meanwhile §7.8 measured
that a compositional table (country codes + class-8 suffixes, ~200 rows) covers **87.7%** of
classed documents — better coverage than 1,000 flat rows. For goal 1 as the owner phrased it
(relationships among *central file segments*), unlabeled classes are the binding constraint: a
co-citation or flow between `763.72` and `861.00` cannot illuminate anything for a reader who
does not already know both numbers. (§6 R-3; needs the owner-supplied schedule first.)

### F-7 · External citations: the harvested layer is post-war only, and the per-document/
### per-collection surfaces are unbuilt

The user's framing names external citations as co-equal evidence. What ships (the Flows
"To unprinted material" layer) is honest and correctly scoped, but:

- **The pre-war half does not exist yet.** At the shipped scope (lots + libraries), the
  through-1947 band contributes **89 of 19,011** joined references (measured from the artifact's
  per-target volume rows). The signal that reaches 1910–1945 is the decimal-file channel
  (4,877 pre-war footnotes name a decimal file, per §7.9a), deferred with a recorded gate: 56%
  of decimal hits are the citing document's own class, and the grammar must stay anchor-first.
  DEVELOPMENT-PLAN records it "left explicitly undone"; no tracker issue carries it. Until it
  lands, the feature cannot support the owner's framing for the first half of the citable
  corpus. (§6 R-6.)
- **The document-grain surface is unbuilt** — `externalCitations(volumeId:documentId:)` and
  `externalCitationStats` exist, are tested, and have zero UI callers (grep; DEVELOPMENT-PLAN
  says the same). The reader of a document cannot see "this document's footnotes name unprinted
  material in X" — which is the single most targeted "beyond FRUS" pointer the app could make,
  delivered at the exact moment of need. (§6 R-7.)
- **`CollectionDetailView` does not show inbound external citations.** The bundled index carries
  per-target totals and per-volume breakdowns (`ExternalCitationIndex.referenceCount`,
  `volumeCounts` — also uncalled outside Flows). "Editors pointed at unprinted material in this
  collection N times across M volumes" is the strongest possible evidence that *the archive
  holds more than FRUS printed* — the owner's bar in one sentence — and it belongs on the
  collection record next to In Your Library. (§6 R-7.)

### F-8 · Flows cannot answer an era question, and cross-system hand-offs are invisible at class
### grain

Both recorded (R-3 in §7.11; the caveat says "you cannot narrow this mode to a period"), so this
is a priority statement rather than a discovery: the pair table carries no volume or era
dimension, so a Cold-War researcher and a Progressive-Era researcher get the same diagram. The
schema-2 regeneration (pairs keyed by coverage band) is the one artifact change in this review's
recommendations. Second, the artifact stores two parallel axes (collection→collection,
class→class); a **mixed** edge — an NSC-file document whose footnote cites into `611.51` — is
representable only when the class side happens to be an era-specific Central Files *collection*
record, i.e. at the coarsest grain. Whether collection→class flows are thick enough to render is
unmeasured; given the class axis's 1.7 refs/pair, measure before building. (§6 R-9.)

### F-9 · Actionability ceiling: the rows the researcher meets mostly cannot link out

Of the top-12 documents-weight rows per band, the count carrying a NARA NAID in the authority:
**1/12, 5/12, 3/12, 0/12, 2/12** (bands 0–4). Overall, 647 of the 1,828 usage-reached
collections carry one. The 1969–1976 band's **zero** is the sharpest case: its heaviest rows are
presidential-materials collections (`NSC Files`, Kissinger files) — and the app *has* a
presidential-library catalog index (3,837 collections, 14,656 series with NAIDs, #681) that the
authority join does not yet reach. Even with F-2's navigation fixed, most top rows land on a
detail view whose NARA-catalog section is absent. This bounds how far "consult beyond FRUS" can
go without the N-4 curation lane; the review flags it so R-2 is not oversold. Related open
issues: #808/#733 (CIA Job numbers key nothing), #353 (~1,850 unrecognized notes), #372 (lot-map
consolidation).

### F-10 · Data warts (small, worth filing)

- **35 authority names concatenate their lot key and subtitle without a separator** —
  `INR/GGI Files: Lot 00 D 221Office of the Geographer and Global Issues Program files` — an
  `AuthorityBuilder` name-assembly seam, visible verbatim in Related Collections rows, pickers,
  and rankings.
- The lifecycle card's top-18 includes repository-grain records ranked as collections
  (`Manuscript Division` [LC], 86 volumes) — the umbrella problem beyond Central Files; the
  Central Files umbrella itself tops this card (157 volumes) *unaffected by the umbrella chip*,
  which governs only the ranking card. Defensible (the caption never promises otherwise), but
  worth an explicit decision.
- `CollectionDetailView`'s Cited Over Time card is the one chart in the archival family with no
  table inspector and no export (`CollectionDetailView.swift:416-458`), against the D3 rule the
  rest of the family follows.

---

## 4. Assessment against the two descriptive goals

**Goal: relationships among archival collections and central-file segments.** *Partially met.*
Collection↔collection is genuinely served three ways (co-citation detail rows, Network, Flows),
with honest grain disclosures. Collection↔class is served only inside the Network's umbrella
expansion (document-weighted, capped at 6 squares). Class↔class is served at co-citation grain
by nothing (the Collections class ranking is per-band totals, not relationships) and at flow
grain by a measured refusal — correctly. The binding constraints are F-6 (unlabeled classes make
any class relationship unreadable) and F-4 (the one class surface that does rank disagrees with
the other). The relationships story is also **footnote-annotation practice**, as every surface
says — the review confirms the disclosures and finds them sufficient.

**Goal: what records the editors used.** *Met at corpus grain, with two honest asterisks the
surfaces already carry (41.3% of authority records reached by document notes; the
Documents/Volumes population split) and one they do not (F-5's share-of-band denominators).* The
era narrative is the feature's best work. What is missing at this goal is only reach: the
per-volume grain (F-1) would let the same question be asked of any subseries, which is how a
historiographer actually asks it.

**The owner's bar: what to consult beyond FRUS for a targeted question.** *Not yet met, and the
review's central claim is that the distance is short.* The chain the bar requires is
scope → rank → open → act: scope to my question (F-1, missing), rank honestly (works), open the
unit (F-2, missing), act on it — catalog link, digitized scans, trip planning (F-9 bounds it;
the Research Trip Packet, already scoped in `Research-Trip-Packet-Scope.md`, is the terminal
act and is NARA's own recommended workflow quoted back). Every link in that chain except the
packet is a small change.

---

## 5. Does the framing make sense? — yes, with two refinements

**Refinement 1: the bar is a workflow property, not a fifth mode.** "Help me decide what to
consult" is delivered by scoping + navigation + linking-out across the surfaces that exist (and
by the trip packet at the end), not by another corpus chart. The review therefore recommends no
new visualization at all.

**Refinement 2: FRUS usage is evidence of editorial selection, not a census of the archive —
in both directions.** The shipped caveats state the overcount direction well (heavy citation ≠
archive importance). The undercount direction deserves equal weight in any "what to consult"
framing: a unit the editors barely drew on may still be essential for the researcher's question
(post files, foreign-ministry archives, private papers FRUS rarely cites). Two shipped signals
already point outward and should be framed that way: the external-citation layer is literally
the editors saying *there is more here than we printed*, and the 2,595 front-matter-only
collections — consulted, never (resolvably) drawn on — are a "consulted but not printed" lens
hiding inside a disclosure. The trip packet's honesty rules (never promise availability, "start
where the editors worked, then widen") are the right frame; analytics copy that feeds it should
inherit the sentence.

---

## 6. Recommendations, priced

Ordered by (value against the bar ÷ cost). Effort tags follow the feasibility doc's convention.
Items marked ⊘ have no tracker issue today.

- **R-1 (S–M) ⊘ — Scope the Collections mode.** Volume-set scoping via the existing
  `AnalyticsScopeBar` custom-scope machinery + `AdministrationPresetMenu`, exactly as the
  approved design specified; the artifact is already per-volume. This single change converts the
  mode from a survey into an instrument ("the archival profile of *these* volumes"), measured in
  F-1. The era-band control becomes what the design intended: a display selector within the
  scope. Rider: when scoped, state the scope's note-count denominator (R-5's machinery).
- **R-2 (S) ⊘ — Close the dead ends.** (a) Ranking rows and lifecycle bars open
  `CollectionDetailView` (tap targets over the bars, or rows in the inspector — the Person
  surfaces already solve chart-row navigation); class rows open class-keyed Archival Neighbors
  *plus* the class's usage across volumes. (b) Network dock and Flows card gain "Open
  Collection" (restoring the approved design). (c) An uncapped "all units in this band/scope"
  table behind the ranking (the current cap-12 export is the one silent-in-practice truncation
  in the family). (d) Re-enable navigation on "Cited Across the Series" rows (the legacy surface
  it superseded had it). (e) `CollectionDetailView` gains a "View in Archival Analytics"
  hand-off (Network focused, Flows focused) via an initializer — which also unlocks every other
  deep link. All view-layer.
- **R-3 (M, owner-gated) ⊘ — The class-label table.** Re-file D-2 as an issue so it stops being
  prose-only; build the compositional seed (country codes + class-8 suffixes + validated
  subject-numeric rows + glosses, per-row source-edition stamps) the moment the owner supplies
  the 1910–49 schedule. 87.7% coverage for ~200 rows is the best legibility-per-byte available
  anywhere in this feature, and it multiplies R-1/R-2's value for every pre-1963 question.
- **R-4 (S) ⊘ — One class grain, everywhere, disclosed.** Decide leaf vs folded for the
  Collections class ranking (recommendation: folded rows, leaf expansion on tap — D-3's grain
  for ranking, the pull-slip grain on demand); make Network and Collections agree; add the
  grain sentence to the caveat block. Include the fold parity in the existing derivation tests.
- **R-5 (S) ⊘ — Use the denominators.** Per-band/per-scope "the rows below account for N% of
  M source notes" line + share annotations, from `volumeNoteCounts`. This is the cheapest
  finding-shaped change in the review (F-5's table is the finding).
- **R-6 (M–L) ⊘ — The external-citation decimal channel.** Re-run the own-class gate (56%),
  harvest decimal-file footnote citations with the own-class exclusion (or a same-class flag),
  anchor-first, never through `decimalClassLocation`, `SAMPLE_OUTPUT` reviewed before trusting
  — all constraints already recorded. This is the only route to the owner's framing for
  1910–1945, and it should be sequenced *after* R-3 so its output is readable on arrival.
- **R-7 (S–M) ⊘ — Surface the external citations the app already stores.** (a) A Sources-tile
  section: "this document's footnotes name unprinted material in: …" from
  `externalCitations(volumeId:documentId:)` (reading order, `Ibid.`-inheritance marked). (b) A
  `CollectionDetailView` section: "editors point at unprinted material here N times across M
  volumes" from the bundled per-target rows, beside In Your Library. Both are wired to data that
  exists and is tested; both deliver the bar's sentence at the researcher's moment of need.
- **R-8 (per its own plan) — Build the Research Trip Packet (T-0…T-3)** as the terminal "beyond
  FRUS" deliverable, and give analytics/detail surfaces an "add to trip packet" affordance once
  it exists. Already scoped against NARA's own guidance; nothing in this review changes that
  scope, and several findings (F-9) are exactly what its advance-inquiry flow is designed to
  absorb.
- **R-9 (M, measure first) ⊘ — Flow index schema 2.** Key pairs by coverage band (not volume —
  keep the artifact small), which un-blocks the era question F-8 documents; measure
  collection→class density in the same regeneration and decide whether the mixed axis earns a
  surface.
- **R-10 (M) ⊘ — A topic door.** The subject → volumes join exists
  (`VolumeSubjectProfiles.volumeIds(forSubjectRefs:)`); composed with R-1's volume scoping it is
  "archival profile of the volumes about X" with zero new artifacts. Same pattern gives Search a
  real archival aggregate over a result set's volumes (today's provenance facet is
  descriptive-only). This is the entry point that matches how researchers actually arrive.
- **R-11 (S) — Discoverability.** Close #798 (iOS SA-3 cross-link); add the Research Guide
  "Find it from…" line and a guide mention; consider a reverse `ResearchGuideLinkButton` from
  the analytics surface.
- **R-12 (file it) ⊘ — The F-10 warts:** the 35 concatenated authority names (generator-side
  name assembly); the Cited-Over-Time inspector/export; an explicit decision on
  repository-grain records in the lifecycle card.

**Sequencing:** R-2 + R-5 + R-4 + R-11 are one small session and de-risk nothing (view-layer).
R-1 (+R-10 riding it) is the value session. R-3 unlocks R-6; both are generator sessions. R-7 is
independent and small. R-8 is its own scoped program. R-9 only if flows earn continued
investment after R-1/R-2 land — the mode's honest ceiling (annotation practice, post-1945,
time-blind) is the lowest of the four.

---

## 7. Other feasible insights the feature could target (the owner's question 4)

Beyond the recommendation list, candidates this review checked for derivability against data in
the repo, with the honest limit stated:

1. **"Consulted but not printed" lens (S, careful copy).** The 2,595 front-matter-only
   collections, presented as their own view rather than a disclosure: the editors' working
   bibliography beyond what yielded printed documents. Limit: the set conflates true
   consulted-only records with document-note join failures (#353's ~1,850 unrecognized notes),
   so the copy must say "never *resolvably* drawn on" until the parser-recovery session lands.
2. **Editorial-practice-over-publication-time (S–M, local).** `citation_era` composition by
   *publication* year rather than coverage year — how the editors' own citation practice
   changed (named in the original S4 blueprint, still unbuilt). Runs on `document_sources` with
   the Your Library disclosure pattern.
3. **Digitization coverage overlay (S, after N-7 settles).** Feasibility §4-G, still right:
   join scoped rankings against `digitized-ranges-index`/`roll-scans-index` so a scoped class
   list says which files can be read tonight versus at College Park — the single most
   trip-decision-relevant fact the app holds. Rider: the same join inverted ("cited, not
   digitized, no NAID") is the "you will need an on-site visit" flag, and feeds R-8's packet.
4. **Presidential-library series resolution (N-4 lane, M).** Join the authority's
   presidential-library records against `presidential-library-catalog.json` (14,656 series
   NAIDs) so the 1969–1976 band's zero-NAID top rows (F-9) become catalog links. This is a
   curation/join problem, not a UI one, and it lifts the actionability ceiling for the modern
   subseries where the White House-custody story lives.
5. **Person → archives (M, local-index).** For a person page: the collections whose documents
   mention or are authored by them, from a `persons` × `document_sources` join over indexed
   volumes, with the standing coverage disclosure. Biographical entry is the second-commonest
   research shape after topical; today person surfaces carry no archival reference at all.
   Corpus-wide would need a new artifact — do not build that until the local version proves the
   question is asked.
6. **Volume↔volume provenance similarity (S, one view).** "Other volumes drawing on the same
   collections," cosine over the usage index's per-volume vectors. Distinct from the refuted
   similarity axes (creator-org #405, lot sibling-inheritance) because it uses document-grain
   usage, not catalog metadata. Limit: within a subseries it will mostly rediscover the
   subseries; its value is cross-subseries surprises, so present it on the collection detail
   ("volumes that source like this one") only if a measured sample shows non-obvious pairs.
7. **Not worth building, checked and named to save future sessions:** a class↔class co-citation
   network (the volume-grain signal is dominated by the era's filing system itself — every
   1950s volume co-cites dozens of classes, so edges say "same era" rather than "related
   subject"); corpus-wide person→archive artifacts (5); any surface promising archival
   *holdings* rather than FRUS usage (the app's data cannot support it, and the trip packet's
   honesty rules exist precisely because NARA's own answer is "write and ask").

---

## Version history

- 1.0 (2026-08-10) — Initial review: verdict, confirmation of working surfaces, findings
  F-1…F-10 with fresh measurements over the shipped artifacts (scoped-vs-band divergence,
  per-band denominators, class-grain fold discrepancy, external-citation era distribution,
  NAID actionability ceiling, navigation census), assessment against the two descriptive goals
  and the targeted-research bar, the two framing refinements, recommendations R-1…R-12 priced
  and sequenced, and seven further candidate insights with derivations and limits.
