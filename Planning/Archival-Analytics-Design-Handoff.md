<!-- Provenance: verbatim README.md from the owner's design handoff zip
     "Archival analytics UI design.zip" (iCloud: 2026-06-30 FRUS Explorer Build 26 screenshots/),
     received 2026-08-08. The zip also holds the annotated HTML mock (Archival Analytics.dc.html)
     and five PNG captures; those stay with the zip — this text is the design contract.
     Integration into the plan of record: Planning/Archival-Analytics-Feasibility.md §7. -->

# Handoff: Archival Analytics (FRUS Explorer)

Implements the archival analytics feature assessed in `Planning/Archival-Analytics-Feasibility.md` (v1.2) and tracked as issues **#762, #763, #764, #765** in `joshbotts/FRUS-Explorer` (branch `v2`).

## Overview

A new **Archival Analytics** surface joining the Analytics family (alongside Corpus Analytics, Person Analytics, Cross-Reference Analytics, Word Cloud — NOT the Research Guide / Series Analytics), with four modes:

1. **Collections** — era × collection rankings + collection lifecycles (#765, doc weights from #763)
2. **Network** — collection co-citation graph in repository sectors, with umbrella expansion into decimal classes (#765; approved direction **2a**)
3. **Flows** — reference hand-off view with user-chosen focus (#764; approved direction **2b**)
4. **Your Library** — per-user archival profile from the local index (#765 rider E)

Plus three new sections on the existing `CollectionDetailView` (#762): Related Collections, Cited Over Time, Divided at NARA.

## About the Design Files

`Archival Analytics.dc.html` is a **design reference created in HTML** — a static prototype showing intended look and behavior, not production code. The task is to **recreate these designs in SwiftUI** using the codebase's established patterns and components (named per screen below). Do not port the HTML.

The design doc contains two turns:
- **Turn 2 (top): the approved directions** — `2a` (Network) and `2b` (Flows).
- **Turn 1 (below): context** — `1a` (#762 detail), `1b` (Collections mode), `1i` (Your Library) are approved as-is; `1c/1e` and `1f/1g` were explored network/flow alternatives and are **not** to be built (1f's heat matrix remains a fine "View as table"-style secondary representation if wanted later).

Amber dashed notes in the mockups are design annotations, not UI. The Tweaks panel toggles them and switches edge-weighting copy (overlap vs. raw shared volumes).

## Fidelity

**High-fidelity in structure and copy; native in implementation.** The mocks deliberately mirror stock iPadOS/SwiftUI chrome — implement with native controls (`List` inset-grouped sections, `Picker(.segmented)`, `.bordered` menu chips, `Canvas`, Swift Charts), not hand-tuned pixel values. Exact hex values below exist only so the HTML matches what the system will give you for free: use `Color.accentColor/.blue`, `.teal`, `.purple`, `.orange`, `.gray`, system fonts and materials. **Caveat/disclosure strings are copy-final** (house style: stated coverage, stated limits) — carry them verbatim into `String(localized:)` entries.

## Where it lives / entry points

- New view `ArchivalAnalyticsView` with a 4-segment mode picker (Collections · Network · Flows · Your Library) in the nav/toolbar, mirroring `PersonAnalyticsView`'s Trends/Network segmenting.
- macOS: new `Window("Archival Analytics", id: "frus.archivalAnalytics")` + Analytics menu item in `FRUSExplorerApp.swift` (see the existing `menu.analytics.*` block, ~line 2840). iOS/iPadOS: same presentation path as the other analytics views.
- Cross-links: `CollectionDetailView` Related-Collections rows push sibling details; "Focus on this class" / "Make focus" hand-offs into Network/Flows follow the existing scene-addressed hand-off pattern (`AppState.pendingAnalytics`-style).

## Screens

### 1. Collection detail additions — mock `1a` (#762)

Extends `FRUSExplorer/SourceExplorer/CollectionDetailView.swift` (plain `List` sections; keep push/sheet hosting untouched). Three new sections inserted after "In Your Library", before "Cited Across the Series":

**Related Collections** (#762-A)
- Top-5 rows (cap + "Show all" if more): collection name (`.callout`), repository caption (`.caption2.secondary`), trailing "N shared vols" (`.caption.monospacedDigit.secondary`) over a 56×4pt overlap meter (blue fill on `quaternary` track), chevron.
- Derivation: intersect `record.volumeIds` against the loaded `CollectionAuthorityStore` (already warm-grouped off-main); rank by **overlap coefficient** (shared ÷ smaller volume list) to damp umbrella records. No new data.
- Row action: push that record's `CollectionDetailView`.
- Footer (verbatim): "Cited alongside this collection in the same volumes' source lists — ranked by overlap coefficient to damp umbrella records. Volume-grain: shared volumes co-fed one compilation, not document-level affinity."

**Cited Over Time** (#762-C)
- Bar chart card (Swift Charts BarMark, ~92pt tall): citing-volume counts bucketed by coverage era ('48–50 … '77–88 in the mock; derive buckets from `manifest.dateRange` midpoints per volume — same join SA-3a uses).
- Caption pattern: "Citing volumes by coverage era… enters the record with the 1947–1949 volumes, peaks across 1958–1968, fades after the 1969–1976 subseries." (Generate the enters/peaks/fades sentence from the data.)

**Divided at NARA** (#762-F)
- Shown only when `LotClaimantsIndex` has >1 claimant for `record.lotFileNorm`.
- Header row: "NARA later distributed material cited as this lot across N catalog series."
- One row per claimant series: name, "NAID xxxxxxx · claims N of its documents" caption, trailing "View" link to the catalog.
- Footer: "From the bundled lot-claimants index — 118 lots series-wide are claimed by more than one NARA series. Offline; no API key required."

### 2. Collections mode — mock `1b` (#765, weights from #763)

- Filter row of chips (reuse `AnalyticsScopeBar`/`AnalyticsYearRangeBar` in `.chip` presentation + `AdministrationPresetMenu`), plus a new **Units chip**: "Units: Named collections ⌄" ↔ "Decimal classes" (menu). Trailing coverage note: "356 of 552 volumes carry clusterable collections".
- Intro `.callout.secondary` paragraph (copy in mock).
- **Card 1 — "Top collections by era"** (`SeriesChartCard`): controls slot holds era segmented (1946–60 / 1961–68 / 1969–76 / 1977–88), weight segmented (**Documents | Volumes**), and an umbrella-filter chip ("Hiding: Central Files umbrella"), mirroring SA-3's category filter. Horizontal BarMarks, labels right-aligned (~330pt column), counts trailing, bars colored by repository category (blue central / teal lot / purple library / orange other). Legend + disclosure line: "The Central Files umbrella record (157 volumes) is hidden — its bar would dwarf the scale."
- **Card 2 — "Collection lifecycles in FRUS sourcing"**: horizontal span bars (min→max coverage year of citing volumes) on a 1900–1990 axis, colored by repository category.
- **"About these figures"** footnote block, verbatim from mock (era asymmetry 2.7% pre-1946, unit-switch pointer, pre-1906 floor, 501-parsed / 356-of-552 coverage, under-merge note).
- Weights: **Volumes** works today from `collection-authority.json`; **Documents** requires `collection-usage-index.json` (#763). Ship the toggle disabled-with-footnote until the artifact lands, or land #763 first.

### 3. Network mode — mock `2a` (approved; #765-B)

Reuses the `PersonCoMentionGraphView` architecture (`FRUSExplorer/Analytics/PersonCoMentionGraphView.swift`): `Canvas` + transparent hit-area buttons, pinned focus, viewport capsule buttons, Reduce-Motion handling, legend bar. Differences from CA-8:

- **Deterministic sector layout, no physics**: four 90° wedges (tinted 7% fills) — STATE—CENTRAL FILES (blue, NW) / STATE—LOT FILES (teal, NE) / PRESIDENTIAL LIBRARIES (purple, SE) / OTHER INSTITUTIONS (orange, SW). Sector = authority `repository` bucketed like SA-3's provenance categories. Radial distance = overlap strength; dashed guide rings at overlap ≥ .75 / ≥ .50 / ≥ .25 (85/155/225pt at mock scale).
- Focus node: 26pt-radius accent circle, white 2pt ring, archivebox glyph, name label beneath (9pt semibold). Partner **collections: circles** (radius ~12–24 by weight, 62% opacity sector color; selected = full color + white ring). Edge spokes tinted by sector color, thickness/opacity by weight.
- **Umbrella expansion** (the revision): a chip "Central Files: Decimal classes ⌄" with menu **Collapsed / Decimal classes / Subject-numeric (1963–73)**. Expanded: the single Central Files node is replaced by its cited classes as **rounded squares** (unit honesty, feasibility §4-I rider b — a class must never look like a collection), clustered inside a dashed hull ellipse labeled "Central Files — decimal ⊖" (tap ⊖ to collapse). Class edges are document-weighted from `document_sources.decimal_class` + the usage index.
- Controls row: Focus label + "Set focus collection…" search field (Person-Analytics pattern), umbrella chip, threshold slider (overlap ≥ 0.25 default; raw shared-volumes alternative).
- Info card (selected class): name + "Decimal class inside Central Files. N documents co-filed with the focus lot's M volumes (document weight, usage index)." Actions: **Show Archival Neighbors** (routes to class-keyed `ArchivalNeighborsRequest.decimalClass` — NOT a collection detail) and **Focus on this class**. Selected collection: actions Explore connections / Open Collection / Show shared volumes.
- Legend adds: circle = "Collection (provenance unit)", square = "Decimal class (subject file — not a collection)".
- Disclosure line: expansion sentence + edge-weighting sentence + "Cited alongside is volume-grain…" caveat (verbatim in mock `1c`/`2a`).

### 4. Flows mode — mock `2b` (approved; #764)

- Filter row: **Focus chip** ("Focus: 763.72 European War" with ✕ to clear), "Set focus class or collection…" search field (unit-aware results), **Outgoing | Incoming** segmented, year-range chip, trailing note "Showing all N destinations — no cap while focused".
- Body card: two-column hand-off diagram. Left: the focused unit as one tall block (label, subject name, "4,412 outgoing references", "856 stay within the file (excluded)"). Right: **every** destination block (code, name, ref count), smallest flows grouped into a dashed "12 more classes · 552 refs · tap to expand" block — **no silent truncation**. Ribbons (bezier bands) left→right, width ∝ reference count; strongest ribbon carries a pinned tooltip "763.72 → 861.00 · 1,842 references".
- Unfocused state = corpus-wide top flows (mock `1h`); clearing focus returns to it. Incoming flips the fan direction.
- Flow-detail card action: "Browse these citations in your library" + verbatim limit note: "Per-citation browsing is limited to your N indexed volumes until the per-edge index ships; the matrix itself is corpus-wide." (#262 stays unblocked.)
- Data: the #764 bundled aggregate — generation-time join of `CrossRefValidationGenerator`'s harvest (2,713,736 refs, 694 volumes) × export provenance units; class-labels table rider for names like "763.72 — European War".
- Draw with `Canvas`/`Path` (filled cubic-bezier bands); respect Reduce Motion for any transitions.

### 5. Your Library mode — mock `1i` (#765-E)

- Intro: "The archival profile of **your** library — computed from the N source notes across your M indexed volumes, not from the bundled corpus-wide aggregates."
- **Card 1**: single stacked horizontal bar (34pt) of repository categories + legend with counts & percentages.
- **Card 2**: "Citation eras across your volumes" — one stacked bar per coverage bucket (pre-1946 / 1946–60 / 1961–68 / 1969–76) showing the decimal→lot→library citation-form shift.
- **Card 3**: "Your most-cited collections" list (name + "N docs") + "Open Archival Neighbors" action.
- Footer (verbatim pattern): "Counted from your own 258 indexed volumes; 294 more exist in the series. Index more volumes and these charts change with you. The corpus-wide modes are independent of what you have downloaded."
- Data: existing `document_sources` columns (`repository`, `record_group`, `lot_file_norm`, `decimal_class`, `citation_era`) — no new artifact, no schema bump. Extends the `localCollectionStats` pattern to the whole library; queries off-main.

## Interactions & Behavior

- Mode picker switches the four modes; each mode owns its filter row. Chips follow the Wave-B consolidated-filter-row pattern (`AnalyticsView.filterRow`): `.bordered` `.controlSize(.small)` menus with icon + caption label + chevron.down; `ViewThatFits` one-row / stacked fallback.
- Network: tap node = select (info dock, CA-8 Win-6 permanently-reserved dock so the canvas never resizes); context menu mirrors dock actions; tap-selected class routes to class-keyed neighbors; double-tap resets viewport; pinch/pan per CA-8; scroll-wheel zoom on macOS via `ScrollWheelZoomCatcher`.
- Flows: tap ribbon → flow card; tap block → pin its flows; tap remainder block → expand; focus field commits like Person Analytics' focus search.
- Every chart card carries the `SeriesChartCard` "View as table" inspector (`ChartDataInspectorView`) and participates in the D3 provenance-stamped CSV/figure export.
- Accessibility: Canvas hidden from VoiceOver with per-node/per-ribbon transparent buttons carrying label/value/hint (CA-8 pattern); adopt shared `AXChartDescriptor` (#268) when it lands; Reduce Motion = settle instantly.

## State Management

Per mode: `mode`, `scopeVolumeIds`/`scopeLabel`, `yearStart/yearEnd`, `unitLens` (.namedCollections / .decimalClasses), Network: `focusCollectionId`, `umbrellaMode` (.collapsed/.decimal/.subjectNumeric), `minOverlap`, `weighting` (.overlap/.rawShared), `selectedNodeId`, history stack; Flows: `focusUnit?` (nil = top flows), `direction` (.outgoing/.incoming), `selectedFlow`. Persist user prefs (`@AppStorage`) for unit lens and weighting only; selections are per-visit `@State` (SA-3 precedent).

## Data plan (phase order = issues)

1. **#762** — no new data. `CollectionAuthorityStore` intersects + `LotClaimantsIndex` + manifest date ranges.
2. **#763** — `collection-usage-index.json` generator (per-(collection, volume) doc counts + per-volume category counts + class × volume counts; ~300–500 KB; int-indexed against authority ids; separate artifact by design). Folds in #267. Unlocks Documents weight (1b), document-weighted class edges (2a).
3. **#764** — flow-matrix aggregate + class-label table (NARA decimal classification guides, public domain). No #262 dependency for aggregates.
4. **#765** — the `ArchivalAnalyticsView` shell + Network/Flows/Collections/Library modes consuming 1–3.

Remember the standard bundled-resource enrolment (`xcodegen generate` + scheme restore) for each new artifact, and `FRUS-API.openapi.yaml` updates for new queryable surfaces.

## Design Tokens (HTML mock values → SwiftUI)

- Blue `#007AFF` → `Color.blue`/accent · Teal `#30B0C7` → `.teal` · Purple `#AF52DE` → `.purple` · Orange `#FF9500` → `.orange` · Gray `#8E8E93` → `.gray`
- Grouped bg `#F2F2F7` → `.systemGroupedBackground`; card white → `.secondarySystemGroupedBackground`; separators `rgba(60,60,67,.12–.29)` → system separators; secondary text `#85858B` → `.secondary`
- Type: 17 semibold titles (`.headline`), 15 rows (`.callout`/body), 13 chips (`.caption`), 12 captions (`.caption`), 11 disclosures (`.caption2`/`.footnote`) — all SF via system styles; counts use `.monospacedDigit()`
- Radii: cards 10–12, chips 8, segmented 9/7; node radii 12–26pt; sector tint fills at 7% opacity; guide rings dashed 4-4

## Assets

None. All iconography is SF Symbols: `archivebox`, `building.columns`, `doc.on.doc`, `magnifyingglass`, `calendar`, `scope`, `chart.bar.xaxis`, `line.3.horizontal.decrease`, `tablecells`, `info.circle`, `square.and.arrow.up`, `chevron.down`, `point.3.connected.trianglepath.dotted`, `xmark.circle.fill`.

## Files

- `screenshots/` — PNG captures of the approved surfaces: `2a-network-sectors`, `2b-flows-focus`, `1a-collection-detail-762`, `1b-collections-eras`, `1i-your-library` (gutter annotation notes may be cropped; open the HTML for the full annotated view).
- `Archival Analytics.dc.html` — the design reference (Turn 2 = approved 2a/2b revisions; Turn 1 = approved 1a/1b/1i + explored alternatives). Open in a browser; pan/zoom canvas.
- Key repo files to mirror: `FRUSExplorer/Analytics/PersonCoMentionGraphView.swift` (graph chrome), `AnalyticsChartChrome.swift` (chips/sections), `AnalyticsView.swift` filterRow (Wave B), `FRUSExplorer/SeriesAnalytics/SeriesChartCard.swift` + `SourceProvenanceDashboard.swift` (card + caveats + category filter), `FRUSExplorer/SourceExplorer/CollectionDetailView.swift`, `CollectionAuthority.swift`, `LotClaimantsIndex.swift`.
- Plan of record: `Planning/Archival-Analytics-Feasibility.md` v1.2 (issues #762–#765; parked items deliberately have no issues).

## Numbers used in the mocks

Real (from the feasibility doc, marked ● in the mocks): 4,423 collections · 11,804 memberships · 356/552 and 501 parsed volumes · 157-volume Central Files umbrella · 67-shared-volume pair (63 D 351 ↔ 66 D 95) · 2.7% pre-1946 named-collection rate · 93–98% 1910s–40s class-key coverage · 2,713,736 refs / 694 volumes / 652 broken · 118 multi-claimed lots. All other counts (flow-cell values, per-era document counts, library percentages) are **illustrative** — compute real ones from the artifacts.
