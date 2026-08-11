# Handoff: Archival Analytics Revision (#825–#835)

Implements the revision plan from `Planning/Archival-Analytics-Adversarial-Review.md` v1.2 (2026-08-11), tracked as issues **#825–#835** (plus **#798**) in `joshbotts/FRUS-Explorer`, branch `v2`.

## Overview

The adversarial review's verdict: as *description* the shipped Archival Analytics feature is strong; against the owner's bar — **helping researchers work out what archival sources to consult beyond FRUS for their own questions** — it under-delivers, and the distance is short. The chain the bar requires is **scope → rank honestly → open the unit → act beyond FRUS**. This design closes every link: volume/topic/search scoping, share-of-notes denominators and one class grain, navigation from every row to the collection record (and back via deep links), unprinted-material pointers at document and collection grain, both cross-links with the Research Guide, and the Research Trip Packet as the terminal act. No new visualization anywhere — the whole revision is scoping, navigation, denominators, labels, and linking out.

A later owner pass simplified all surfaces: **plain labels on screen; method statements and caveats moved into the ⓘ info popovers**; the Collections lifecycles chart removed; an external-citations count added to the Collections ranking; Network sectors made independent focus/inspect zones; and a document-level hand-off into the Cross-Reference Graph with unprinted citations drawn in.

## About the Design Files

`Archival Analytics Revision.dc.html` is a **design reference created in HTML** — a static prototype showing intended look and behavior, not production code. The task is to **recreate these designs in SwiftUI** in the existing FRUS Explorer codebase, using its established patterns and components (named per screen below). Do not port the HTML.

- One consolidated **final state per surface**, artboards `1a`–`1k` (badges top-left), single turn.
- **Amber dashed notes are design annotations, not UI** — implementation notes for each artboard. The design file's Tweaks panel can hide them (`showAnnotations`).
- `screenshots/` holds a PNG per artboard, captured with annotations visible.

## Fidelity

**High-fidelity in structure and copy; native in implementation.** The mocks mirror stock iPadOS/SwiftUI chrome — implement with native controls (`List` inset-grouped sections, `Picker(.segmented)`, `.bordered` `.controlSize(.small)` menu chips, Swift Charts, `Canvas`), not hand-tuned pixels. Quoted caveat/disclosure strings are **copy-final** (house style: stated coverage, stated limits) — carry them verbatim into `String(localized:)` entries; unquoted captions are directional.

Number convention: **●** = measured on the shipped artifacts (review of 2026-08-10) — reuse as stated. **○** = illustrative — compute the real value from the bundled artifacts at render time. Never hard-code an ○ number.

**The plain-language rule (applies to every surface):** on-screen labels use researcher words; precise definitions, populations, and caveats live in the surface's ⓘ popover (`FeatureInfoButton` / per-card info). Keep existing localization keys where sensible; change `defaultValue` strings. Accessibility labels may keep precise terminology.

| Shipped term | On-screen label |
|---|---|
| Units (Named collections / Central-file classes) | **Show** (Collections / File numbers) |
| Weight (Documents / Volumes) | **Count by** (Documents / Volumes / **Unprinted pointers** — new) |
| Coverage era | **Era** |
| Central Files umbrella: Hidden | **Central Files: Hidden** |
| "Cited, Not Printed" / external citations (sections) | **Unprinted Material** |
| Subject-numeric fold group / leaf | **family** / **single file** ("31 in family", "exact number a pull slip needs") |

## Issue → screen map

| Issue | Carries | Wave | Screens |
|---|---|---|---|
| #825 | Close dead ends: row navigation, Open Collection, uncapped table, deep-link initializer, Cited-Across-the-Series rows | 1 — polish | 1a, 1b, 1c, 1e |
| #826 | One class grain everywhere + use the denominators | 1 — polish | 1a, 1b |
| #832 | Authority-name concatenation (generator bug), Cited-Over-Time inspector/export, lifecycle decision (resolved by removing the card) | 1 — polish | 1a, 1e |
| #827 | Volume/subseries/administration scoping for Collections mode | 2 — value | 1a |
| #833 | Topic door (subject- and search-scoped profiles); rides #827 | 2 | 1g |
| #835 | Sources-page collection-grain card + both cross-links (with #798) | 2–3 | 1h |
| #829 | Surface stored external citations (document rail + collection record + ranking count + graph layer) | independent | 1a, 1e, 1f |
| #828 | Class-label table (owner-gated on the 1910–49 schedule) | 3 | 1b, 1d |
| #834 | External-citation decimal channel (after #828) | 3 | 1d |
| #830 | Research Trip Packet T-0…T-3 | capstone | 1e, 1i, 1j, 1k |
| #831 | Flow index schema 2, era-keyed (measure first) | last, if earned | 1d |

## Screens

### 1a — Collections mode, scoped (`ArchivalAnalyticsView.swift`)

The mode becomes an instrument: "the archival profile of *these* volumes."

- **Toolbar**: unchanged — title, 4-segment mode picker (Collections · Network · Flows · Your Library), ⓘ, Done.
- **ⓘ popover** (drawn open in the mock, anchored to the toolbar info button): title "About these figures" + the full method statement — source-note parsing vs catalog, the three counts, umbrella disclosure with its measured value, era asymmetry/unit-switch pointer, scope population. This replaces the on-page intro paragraph and the "About these figures" footer block, both removed. The old intro/caveat copy is the popover's source text.
- **Filter row** (Wave-B chips, `ViewThatFits` one-row/stacked): **Scope** chip (accent-tinted when active, with ✕: "Scope · Vietnam volumes, 1961–1968 · 11 vols") — reuse `AnalyticsScopeBar` (`.chip` presentation) with its full menu tree (Whole corpus / By Subseries / By Volume / My Volume Scopes / By Detected Topic); **Administration** preset chip (`AdministrationPresetMenu`); **year chip** (`AnalyticsYearRangeBar` `.chip`, "1961–1968 ⌄"); **Show** chip (Collections / File numbers); **Central Files** chip (Hidden/Shown). The Weight chip is gone — replaced by the segmented control in the card. The era-band control becomes a display selector within the scope.
  - Scoping derivation: pass `scopeVolumeIds` into `ArchivalCollectionsData` (already per-(unit, volume)). **Do not intersect with the local index** — the bundled derivation is corpus-wide (F-1); manifest-wide subject scopes are valid with zero downloads.
- **Denominator line** (#826/R-5), a quiet inset box between chips and card: "**8,124 source notes ○ in this scope.** The 10 rows below cover 20% ○ of them. Most of the rest is the central files — switch Show to File numbers to rank those." From bundled `volumeNoteCounts` (shipped, never read until now).
- **Card — "Top collections in this scope"** (`SeriesChartCard`; title says "by era" when unscoped): caption "11 volumes in scope draw on 214 collections ○. Coloured by who holds the records." Controls slot: segmented **Documents | Volumes | Unprinted pointers** — the third counts footnotes naming unprinted material in each collection, from `ExternalCitationIndex` per-target totals (#829; same data as 1e's Unprinted Material section). Horizontal bars, right-aligned label column (~240pt at this width), trailing "count · share%" in `.caption2.monospacedDigit`, chevron — **every row pushes `CollectionDetailView`** (#825a; Person surfaces already solve chart-row navigation). Legend: 4 custodian categories. Trailing button "**Show all 214 units in this scope ○**" opens the uncapped table (#825c); its CSV replaces today's cap-12 export.
  - Vietnam scope ranking (●, from the review's probe; shares ○): Johnson National Security File 753 · Central Files 1967–69 241 · Kennedy National Security Files 159 · Taylor Papers 102 · A/IM Files: Lot 93 D 82 79 · Johnson Recordings and Transcripts 79 · Tom Johnson's Notes of Meetings 73 · Meeting Notes File 46 · Hilsman Papers 43 · Vietnam Working Group Files: Lot 67 D 54 41.
- **Lifecycles card: removed from this mode** (#832 resolved by removal; the per-collection story stays on `CollectionDetailView` → Cited Over Time). Bottom of page keeps a one-line ⓘ pointer.

### 1b — File numbers (class lens) (`ArchivalAnalyticsView` + `ArchivalCollectionsData`)

- Filter row: Scope (Whole corpus) · Era 1961–1968 · **Show: File numbers** · Count by: Documents.
- Denominator: "**22,737 source notes ● in this era.** Rows group related file numbers into families — expand one for the exact number a pull slip needs."
- **Card — "Top file numbers"**: caption "Grouped the same way everywhere in the app. Names arrive with the label table (#828)." **One grain, everywhere** (#826/R-4): subject-numeric rows ranked **folded** via `CollectionKeying.subjectNumericGroup` (shared with the generator — the Network's umbrella expansion already calls it; add a fold-parity test Network == Collections). Tapping a family row expands its constituent designators inline (indented, left rule, rounded-square glyphs — unit honesty): `POL 27` family, 1,090 docs ● → `POL 27 VIET S` 463 ●, `POL 27 ARAB-ISR` 233 ●, `POL 27 CYP` 143 ●, `POL 27-14 VIET` 138 ●, `POL 27 YEMEN` 92 ●, "Show 26 more ○". Each expanded row carries **Show documents** → class-keyed `ArchivalNeighborsRequest.decimalClass` — a class never opens a collection detail. Decimal rows (`751K.00`) are already single files and get a "single file" badge.
- **Labels** (#828, owner-gated on the 1910–49 filing schedule): "`code` — gloss" everywhere a class key shows (rankings, expansions, Flows blocks, Network squares, pickers). The compositional seed (~200 rows: country codes + class-8 suffixes + validated subject-numeric rows, per-row source-edition stamps) covers 87.7% ● of classed documents. All glosses in the mock are ○ until the table lands; an uncovered class shows its bare number.
- ⓘ row at bottom; the popover carries the quoted two-filing-systems caveat verbatim (in the HTML's 1b caveat text, copy-final).

### 1c — Network: sector zones + dock (`ArchivalNetworkView.swift`)

- **Sector zones (new)**: each custodian wedge is an independent tap target. Corner labels in plain language (STATE CENTRAL FILES / STATE LOT FILES / PRESIDENTIAL LIBRARIES / OTHER INSTITUTIONS), small-caps 9pt, sector-tinted. Selecting a wedge: its tint strengthens (~.17) with a subtle inset stroke, the others dim (~.04), a **Group chip** appears in the controls row ("Group · Presidential libraries ✕"), and the dock shows the **group card**: title = group name, caption "Group — tap any wedge to inspect it on its own", detail ""4 of this focus's 12 partners ○ are held by a presidential library. Strongest: Dulles Papers, 34 shared volumes ○."", actions **Show Only This Group** (redraws the graph with just that custodian's partners; radius re-scales to the group's strongest link — the dock discloses the re-scale) and **List These N Collections** (rows push detail). ✕ on the chip restores all four sectors. Wedge hit areas sit **under** the node buttons — node taps always win.
- **Node dock** (#825b): a selected collection's card gains **Open Collection** beside Explore This Collection / Show Archival Neighbors (restores the approved design's dock; also in the context menu). Class squares unchanged — class-keyed neighbors only.
- Everything else as shipped: deterministic layout, guide rings, threshold slider, focus picker, umbrella expansion, permanently-reserved dock, CSV-only export. Plain sector names map 1:1 to `ArchivalRepositoryCategory`; the ⓘ popover keeps the precise definitions ("Department of State" is not only central files).

### 1d — Flows: unprinted decimal channel + eras (`ArchivalFlowsView.swift`)

- Filter row: **References segmented** — "Between documents | To unprinted material" (plainer labels, same `ArchivalFlowLayer`); Focus chip "763.72 — European War ✕" (labels from #828); Outgoing | Incoming; **Era chip** "Through 1947 ⌄" (new, #831 — ships only with schema 2).
- Diagram: focus block left (name + "4,412 outgoing references ○" + "856 stay within the file — excluded ○"); every destination drawn, smallest folded into the dashed remainder block ("12 more classes · 552 refs ○ · tap to expand") — no silent truncation, unchanged. Caption: ""4,412 ○ footnotes here point at unprinted material elsewhere. 856 ○ point back into this file and are left out."" Pinned tooltip on the strongest ribbon.
- Flow card: pair title, "1,842 references ○, 41% ○ of everything this class hands off." Class endpoints: **Show Documents in This Class**; collection endpoints additionally **Open Collection** (#825b).
- **#834** (after #828): harvest decimal-file footnote citations with the own-class exclusion (56% of decimal hits ●; or a same-class flag), anchor-first grammar, never through `decimalClassLocation`, `SAMPLE_OUTPUT` reviewed before trusting. 4,877 pre-war footnotes name a decimal file ●. Updated caveat (popover, copy-final): "This layer now reads three kinds of citation: State Department lot files, collections in the presidential libraries, and file numbers in the pre-1963 central files…"
- **#831** (measure first, lowest lane): regenerate `provenance-flow-index.json` keyed by coverage band (not volume — artifact stays small); measure collection→class density in the same regeneration to decide whether the mixed axis earns a surface.
- On-page caveat block replaced by the ⓘ row; full statements (ribbon claim, own-file rule, era coverage, Ibid. handling) move to the popover.

### 1e — Collection record (`CollectionDetailView.swift`)

Inset-grouped `List`, push/sheet hosting untouched. Section order: Archival Collection · (NARA Catalog when present) · In Your Library · **Unprinted Material** (new) · Related Collections · Cited Over Time · (Divided at NARA when applicable) · Cited Across the Series · Sub-Series · **Archival Analytics** (new) · **Research Trip** (new).

- **Unprinted Material** (#829b): "Editors pointed here for unprinted material **3,914 times across 71 volumes** ○." + top citing-volume rows + "All 71 volumes…". Footer: "Each count is an editor saying: more is filed here than FRUS printed." From bundled `ExternalCitationIndex.referenceCount` / `volumeCounts` (stored + tested, zero UI callers today). Sits deliberately beside In Your Library: one section is what you have; the other is what the archive has that FRUS did not print.
- **Cited Over Time** gains the family's "View as table" inspector + provenance-stamped export (#832b) — the one chart in the family without them.
- **Cited Across the Series** rows navigate again (#825d) — each row opens the volume (the superseded legacy surface had this; its doc comment records the rows "used to be dead ends").
- **Archival Analytics** (#825e): "View Co-Citation Network (focused here)" / "View Reference Flows (focused here)" via the **new `ArchivalAnalyticsView` initializer** (mode + focus/scope parameters) — the change that unlocks every deep link (1g, #798). Follow the scene-addressed hand-off pattern (`AppState.pendingAnalytics`-style).
- **Research Trip** (#830, appears once T-2 ships): "Add to Trip Packet…" — queues this record's resolved series for a packet chapter.
- NARA Catalog honestly absent for NSC Files (no NAID; the N-4 presidential-library join lifts the 1969–76 zero later — review §7.4). #832a (35 concatenated authority names, e.g. `…Lot 00 D 221Office of the Geographer…`) is a generator-side name-assembly fix; no UI.

### 1f — Document Sources sheet: unprinted pointers + graph (`SourceExplorerView.swift` / `MacSourceExplorerView.swift`)

- **Unprinted Material** (#829a): "These footnotes point to unprinted material in:" — rows in reading order (`fn 2 · Vietnam Working Group Files: Lot 67 D 54 · Department of State` …), each pushing the collection record; `⤴ Ibid.` marks inherited attributions; unmatched citations (CIA Job numbers, #808) render honestly inert. Footer: "In reading order. ⤴ marks an "Ibid." followed back the way a reader would. CIA Job numbers match nothing yet (#808)." Wired to `externalCitations(volumeId:documentId:)` — stored, tested, no UI caller today. The most targeted "beyond FRUS" pointer the app can make, at the moment of need.
- **See It as a Graph** (new): mini-preview + "Open Cross-Reference Graph". The existing Cross-Reference Graph gains an **unprinted-citations layer**: every expanded document node also fetches its unprinted pointers via the same per-document API. **Unit honesty**: printed documents = solid circles (expandable); unprinted citations = **dashed rounded squares** — a citation of material with no document behind it, so it terminates the walk and routes to the collection record instead. Legend gains the dashed key ("● printed document — expandable · ▢ unprinted, in an archive — opens the collection record"). Unmatched citations stay off the graph rather than drawn as guesses.

### 1g — The doors (#833; rides #827)

- **Topic door**: `AnalyticsScopeBar`'s existing By Detected Topic tree (volume-grain, `VolumeSubjectProfiles.volumeIds(forSubjectRefs:)`) — seeded **manifest-wide** here, not intersected with the local index.
- **Search door**: the Search facet panel's "Archival provenance" facet (descriptive today) gains "**Open archival profile of these results**" → Archival Analytics scoped to the result set's volumes via the #825e initializer (e.g. "Scope: Search "dien bien phu" · 23 vols ○"). Zero new artifacts.

### 1h — Research Guide · Archival Sourcing: narrative card (#835 + #798) (`SourceProvenanceDashboard.swift`)

Review §8's decision: **relocate no, layer yes** (D-1's "guide untouched" clause amended).

- New card "**Top collections in this scope**" under the page's existing `SeriesScopeBar` + year range: top-8 rows (custodian dot · name · count · chevron), caption "The collections these volumes drew on most.", cap note "Top 8 shown. Rows open the collection record in a sheet." Rows open `CollectionDetailSheet` (self-contained — works in both guide containers, onboarding included). Footer link "Open Archival Analytics" with the one-line detail "Names, ranks, and connects the individual collections behind this page's ten categories."
- **Shared derivation** (`ArchivalCollectionsData`), never a copy. Drift guards: a parity test pins this card against the Collections-mode ranking for an identical scope; both attribute by coverage midpoint; buckets computed from per-volume rows at render time (#763 no-era-rollups). Authority/usage stores decode **lazily, off-main, on first appearance** (onboarding must not pay ~2.5 MB up front). Class half of the card only after #828. **No Flows or Network on this page** (chassis + claim-shape, §8.3c).
- **#798**: the SA-3 → Archival Analytics cross-link ships on iOS too (tractable via the initializer); the analytics surface gains the reverse `ResearchGuideLinkButton`; the Research Guide walkthrough gets its "Find it from…" line (R-11).

### 1i / 1j / 1k — Research Trip Packet (#830, T-0…T-3)

Per `Planning/Research-Trip-Packet-Scope.md` (v1.1) — an exporter over resolutions the app already computes. Entry points: Project Home "Plan an Archive Visit" + a collection's overflow menu (1e).

- **1i Builder sheet**: project summary ("38 engaged documents ○ → 3 repositories, 9 series, 1 unresolved lot ○"); optional visit date with countdown + **lead-time flag chips** (A4 engine: post-1960 records · State Department RGs · lot without a NARA match) escalating "4 weeks minimum ●" to "write early"; chapter list per repository (College Park "strongly encouraged", one draft per agency cluster ●; Johnson Library "required — confirm materials are at this location ●"; LC = non-NARA pointer row); section list with ✓ (T-2) and `T-3 · N-7` badges (Mandatory substitutes, Restriction triage). Generate → PDF; drafts also as plain text.
- **1j Packet pages — Cover & checklist / Inquiry draft**: countdown rows (now / −4 weeks ● / −2 business days ● / day 0 register ●); appointment rows; "availability never promised" banner. Inquiry draft in NARA's six-element structure ●: one address per repository (`archives2reference@nara.gov` ●), topic sentence = the project's stored research question, RG · Entry · Series · NAID table (catalog links), **unresolved lots embedded verbatim as locate-requests** quoting NARA's "do not always carry over" ●, availability questions; asks about records, never for research ●.
- **1k Packet pages — Worksheet / Substitutes / Restrictions / Visit-day**: pull worksheet (series rows with entry · NAID · dates · `numberingNote` [T-3]; document roster with FRUS cite + folder designation; **Box column blank by design** ●); mandatory substitutes (T-3·N-7) "must use" framing ●, range-grain ("file range 763.72/1476–1635, never a document" ●); restriction triage chips from `accessRestriction` (T-3·N-7) + withdrawal/MDR explainer; visit-day card (pull times M–F 9:30–3:00, nothing after 5:15 ●; 3rd-floor consultation area + Wednesday foreign-affairs specialist 9:30–10:30 ●; room rules ●; every volatile fact stamped "as of ⟨date⟩" with its archives.gov link ●).
- Sessions: **T-0** measure on a real project + hand-curate the ~16-row repository JSON (the one new artifact; owner verifies rows; `verifiedDate` per row). **T-1** `TripPacketModel` (repository → RG → series → roster + flags), platform-neutral, fixture-tested. **T-2** chapters 1–3, 6–7 + entry points (ships before N-7). **T-3** chapters 4–5 + `numberingNote` + series date-checks when the N-7 bundle lands. Honesty rules (non-negotiable): no fabricated box numbers; unresolved lots = NARA's predicted case, routed into the inquiry; volatile facts dated + linked; scans range-grain; availability never promised. Verification oracle: fixture project spanning decimal / resolved lot / unresolved lot / presidential-library / post-1960; walk advisories A1–A14 — a packet claim with no source in the traceability table is a defect.

## Interactions & Behavior

- **ⓘ popovers**: every mode's toolbar info button (and 1e-style cards where noted) presents the full method statement; on-page text stays to one plain line + the denominator line. 1a's mock draws the popover open to establish the pattern.
- Chips follow the Wave-B consolidated filter row (`.bordered` `.controlSize(.small)`, icon + caption + value + chevron.down; `ViewThatFits` stacked fallback). Active scope/focus/group chips tint with their semantic color and carry ✕.
- Family expansion (1b) is an inline disclosure, one family open at a time is acceptable; expanded rows are buttons (VoiceOver: label = designator, hint = "Shows indexed documents in this file").
- Sector zones (1c): wedge selection ≠ node selection; node hit areas stay on top. "Show Only This Group" is a filter on the drawn graph, not a new mode; Reduce Motion settles instantly as shipped.
- Uncapped table (1a): reuse `ChartInspectorData` presentation with the full ranking; its export carries the same provenance preamble.
- Deep links (#825e): `ArchivalAnalyticsView(mode:focus:scopeVolumeIds:scopeLabel:)`-shaped initializer; all existing bare call sites unchanged; scene-addressed hand-offs per the codebase's `consumeHandoff` pattern.
- Graph unprinted layer (1f): fetch per expanded node, off-main; dashed nodes non-expandable, tap → collection record; layer toggle lives with the graph's existing controls.
- Every chart keeps "View as table" + provenance-stamped CSV/figure export (D3); the two Canvas modes stay CSV-only.

## State Management

Per mode, extending the shipped `@State`/`@AppStorage` split (selections per-visit, ways-of-working persisted):

- Collections: `scopeVolumeIds: [String]?` + `scopeLabel: String?` (per-visit), `band` (display selector), `unitLensRaw` (persisted), **`countBy`** replacing `weightRaw` (persisted; `.documents / .volumes / .unprintedPointers`; fall back with disclosure when an index is missing, as `weight` does today), `hidesUmbrella` (per-visit), `showsAllUnits` sheet.
- Network: adds `selectedSector: ArchivalRepositoryCategory?` and `sectorFilter: ArchivalRepositoryCategory?` (both per-visit; filter feeds the builder).
- Flows: adds `eraBand` (per-visit; only with schema 2).
- Collection detail: adds the external-citations load (off-main, on appear, like `loadRelated`).
- Packet: `TripPacketModel` + optional `visitDate`; section toggles default all-on.

## Data plan (phase order = waves)

1. **No new data**: #825, #826 (`volumeNoteCounts` ships already), #827, #829 (`ExternalCitationIndex` + `externalCitations(…)` ship already), #833, #835a, #798.
2. **#828** — class-label table artifact (owner supplies the 1910–49 schedule; compositional seed ~200 rows; per-row source stamps). Unlocks #834 and 1h's class half.
3. **#834** — external-citation regeneration adding the decimal channel (own-class exclusion or flag; anchor-first; `SAMPLE_OUTPUT` reviewed).
4. **#831** — flow index schema 2 (era-keyed pairs; measure collection→class density in the same run; build the era chip only then).
5. **#830 T-0** — the repository-table JSON (~16 rows, owner-verified, `verifiedDate` stamped).

Remember the standard bundled-resource enrolment (`xcodegen generate` + scheme restore — schemes must be restored afterwards) per new artifact, and `FRUS-API.openapi.yaml` updates for new queryable surfaces.

## Design Tokens (HTML mock values → SwiftUI)

- Blue `#007AFF` → `Color.blue`/accent (Department of State) · Teal `#30B0C7` → `.teal` (State lot files) · Purple `#AF52DE` → `.purple` (Presidential libraries) · Orange `#FF9500` → `.orange` (Other institutions) · Gray `#8E8E93` → `.gray`
- Grouped bg `#F2F2F7` → `.systemGroupedBackground`; card white → `.secondarySystemGroupedBackground`; separators `rgba(60,60,67,.12–.29)` → system separators; secondary text `#85858B` → `.secondary`
- Type: 17 semibold titles (`.headline`), 15 callout, 14.5 list rows (body), 13 chips (`.caption`), 12 captions (`.caption`), 11–12 disclosures (`.caption2`/`.footnote`); counts `.monospacedDigit()`
- Radii: cards 10–12, chips 8, segmented 9/7; node radii 12–26pt; sector tints .04 dimmed / .17 selected (7% neutral); guide rings dashed 4-4; dashed unprinted nodes 1.5pt dash
- Amber `#E5A83B` appears only in design annotations — not UI

## Assets

None. All iconography is SF Symbols: `archivebox`, `building.columns`, `doc.on.doc`, `magnifyingglass`, `calendar`, `scope`, `chart.bar.xaxis`, `line.3.horizontal.decrease`, `tablecells`, `square.and.arrow.up`, `chevron.down`, `chevron.right`, `info.circle`, `point.3.connected.trianglepath.dotted`, `square.stack.3d.up`, `xmark.circle.fill`, `arrow.triangle.branch`, `plus.circle`.

## Files

- `Archival Analytics Revision.dc.html` — the design reference (open in a browser; pan/zoom canvas; Tweaks toggle hides annotations).
- `screenshots/` — one PNG per artboard: `1a-collections-scoped`, `1b-file-numbers`, `1c-network-sectors`, `1d-flows-unprinted`, `1e-collection-record`, `1f-document-sources`, `1g-doors`, `1h-sources-page-card`, `1i-packet-builder`, `1j-packet-cover-inquiry`, `1k-packet-worksheet-visitday`.
- Key repo files to mirror: `FRUSExplorer/Analytics/ArchivalAnalyticsView.swift`, `ArchivalCollectionsData.swift`, `ArchivalAnalyticsAxes.swift`, `ArchivalNetworkView.swift` (+ `ArchivalNetworkData.swift`), `ArchivalFlowsView.swift` (+ `ArchivalFlowsData.swift`), `AnalyticsChartChrome.swift` (`AnalyticsScopeBar`, `AnalyticsYearRangeBar`), `AdministrationPresetMenu.swift`, `FRUSExplorer/SourceExplorer/CollectionDetailView.swift`, `ExternalCitationIndex.swift`, `SourceExplorerView.swift` / `MacSourceExplorerView.swift`, `FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift`, `SeriesScopeBar.swift`, `SeriesChartCard.swift`.
- Plan of record: `Planning/Archival-Analytics-Adversarial-Review.md` v1.2 (§9 tracker mapping), `Planning/Archival-Analytics-Feasibility.md` v1.9, `Planning/Research-Trip-Packet-Scope.md` v1.1, `Planning/Archival-Analytics-Design-Handoff.md` (the #762–#765 baseline this revises).

## Numbers used in the mocks

Real (●): the five era bands and their volume counts (261/120/64/66/41); Vietnam 1961–68 scoped ranking (753/241/159/102/79/79/73/46/41 over 11 volumes); band note totals (22,737 for 1961–68; the denominators table in review F-5); subject-numeric share 61.6%; `POL 27` fold 1,090 vs leaves 463/233/143/138/92; 87.7% label coverage for ~200 rows; 4,877 pre-war decimal footnotes; 56% own-class share; 35 concatenated names; NARA guidance facts in 1i–1k (4 weeks, 10 business days, pull times, Wednesday specialist, one-address rule). All other counts (scope note totals, shares, external-citation counts, packet fixture numbers) are **illustrative (○)** — compute from the artifacts.
