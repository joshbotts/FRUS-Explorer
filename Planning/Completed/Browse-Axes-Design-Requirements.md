# Browse Axes — Design Requirements (#1051)

**Status:** Design input — ready for a design session. No implementation is scoped here.
**Date:** 2026-08-22
**Source issue:** #1051 "Supercharge corpus browser and browse tab"
**Basis:** 13-agent codebase survey (architecture, per-axis data, planning rulings, four verified follow-ups), 2026-08-22.
**Decision namespace:** This document mints its own registers — `R-n` (shared requirements), `A-n` (axis requirements), `Q-n` (open owner decisions). The repo reuses "D-numbers" per program (Research-Rail D1–D8, trip-packet D1–D13), so nothing here cites a bare D-number without naming its register.

---

## 1. Feasibility summary

Issue #1051 names ten browse axes. **Every one is either already shipped or data-ready needing only UI.** No new bundled artifact, no harvest, no SQL schema change, and no CloudKit schema deploy is required for the feasible scope. The design problem is therefore pure interaction design: how the Browse tab (iOS) and Corpus Browser window (macOS) present ~7 additional axes without burying the hierarchy they exist to serve.

| Axis | Verdict | Data source (all bundled/shipped) | Design scope |
|---|---|---|---|
| Tagged people | **Shipped** | SQL person index; `BrowserLevel.people` + `frus.people` window | None (coverage caveat only) |
| Tagged subjects | **Shipped** 2026-08-22 | document-subject-index.json; Topic Index (#1050) | Optional completions (A-7) |
| Downloaded / not | **Shipped** | `filterDownloadedOnly` toggle | None |
| Volume titles | Data-ready | manifest.json `title` (552/552) | A-1 |
| Release date | Data-ready | manifest.json `publicationDate` (552/552) | A-2 |
| Administration | Data-ready | administration-profiles-index.json (171KB, eager-loaded) | A-3 |
| Editor / compiler | Data-ready | manifest.json `editors` (471) + `generalEditor` (418) | A-4 |
| Custom volume scopes | Model shipped, Browse consumes nothing | `CustomVolumeScope` @Model (CloudKit-deployed) | A-5 |
| Working corpora | Model shipped, Browse consumes nothing | `WorkingCorpus` @Model (CloudKit-deployed) | A-6 |
| Semantic clusters | Data-ready, **gated** | semantic-map-index.json + semantic-map.bin | A-8 (conditional) |

Out of the feasible scope entirely: people-axis expansion (#234, owner-gated), per-chapter compiler attribution (needs a prose-extraction harvest), document-level subject regeneration (#261), any new synced model or stored property (CloudKit R-7 gate).

---

## 2. The design problem in one paragraph

Browse today is a hierarchy (corpus → subseries → volume → chapter → document) with exactly two cross-cutting doors (People, Topics) and one filter (downloaded). The feasible scope adds up to seven more ways in. The iOS corpus root currently hosts the doors as rows in a "Cross-volume indices" section; seven more rows will crowd the subseries list the tab exists for. The macOS browser is a separate hand-written twin whose sidebar is a bare subseries list, and whose per-axis-window precedent (People, Topics) must **not** be extended — sixteen singleton windows already strain the un-suppressible Window menu (#824 cleanup, shipped). The design must answer: **how does a reader choose an axis, and what do they land on** — such that every axis reuses one shared volume-list destination (R-1), every count is honest about corpus-vs-device (R-3), and both platforms stay coherent without seven new windows (R-4).

---

## 3. Constraints the design takes as given

These are shipped rulings and test-pinned facts. The design works within them; changing one requires an explicit owner decision, not a design footnote.

**Navigation architecture (iOS).**
- Browse is one value-typed enum + array: `BrowserViewModel.BrowserLevel` (7 cases) with `navigationPath: [BrowserLevel]` (BrowserViewModel.swift:59–100). Adding an axis = new case + 4 exhaustive-switch touch points (hash/==, `levelView`, `breadcrumbLabel`, a corpus-root door).
- **No `NavigationLink` anywhere in Browser/** — every row is a Button mutating the path (two-pane layout renders `navigationPath.last` directly; a nested stack was built and refuted, BrowserView.swift:666–676). Axis views must follow this or be inert in two-pane.
- Top-level index doors **assign** the path (`vm.select`), never append — otherwise the breadcrumb forges "Corpus → People → Topics" (#1050 precedent).
- Cross-surface arrivals use the scene-addressed `Handoff<Request>` pattern, drained from **both** `.onChange` and `.onAppear` (#750 H-8/H-11).
- **People stays the first cross-volume-index row.** Two UI tests use it as the two-pane list-pane oracle (CorpusView.swift:82–85). New doors go below it.

**Navigation architecture (macOS).**
- The Corpus Browser is a `NavigationSplitView` with a bare subseries sidebar and a detail-column `NavigationStack` over `CorpusNavValue` (2 cases, string-keyed, cleanly extensible). Option A — push navigation in the detail column — is the executed ruling (Corpus-Browser-Rework-Plan.md:19–23).
- **No new per-axis singleton `Window` scenes.** 16 exist; each adds an un-suppressible Window-menu entry (regresses #824) and inherits the fronting-gap defect class (11 of ~31 `openWindow` sites already lack `bringMacWindowToFront`). People (`frus.people`) and Topics (`frus.subjects`) windows stay as shipped — their beside-a-document simultaneity rationale defends them as-is, not as a policy. Escape hatch if one axis truly needs simultaneity: the #824(3) marker-keyed `WindowGroup(id:for:)` pattern (no menu entry).
- The `.macCorpusBrowser` volume hand-off consumption (MacCorpusBrowserWindow.swift:205) must survive any sidebar retyping.

**Settled product rulings.**
- **O-3 (2026-08-19):** Browse is the settled destination for reading hand-offs; #751's restructure is closed decided-against. No axis redesign may displace `consumePendingBrowseDocument`.
- **Research-rail D1:** the volume-subjects surface returns only as a separate view, never an accordion or rail tile; any document-rail affordance for subjects requires explicitly amending D1 (subjects-plan P2-iv). Out of scope here.
- **Working corpora have no "new" button** — a corpus is captured from a result set (WorkingCorporaView.swift:27, owner-authored). Browse may list and apply corpora, never create them.
- Subjects-plan P2-i (per-row facet affordance) was explicitly deferred; do not re-litigate inside this design.

**Honesty rules (every counting or derived surface owes these).**
- **Corpus-vs-device split:** bundled artifacts describe all 552 volumes; SQL describes only indexed volumes. The Topic Index's pinned caption + three-state device count ("counting / not counted / N") is the template (SubjectIndexView.swift:126–163).
- **Degraded rows, never blocked lists** for document-grain drills (see R-3).
- **Disclosure sentences travel with their data:** subjects are "detected automatically… some are wrong"; cluster labels are sampled c-TF-IDF terms, not subject headings; administration attribution is coverage (who was in office on the document's date), not production.

---

## 4. Shared infrastructure requirements (build once, reuse per axis)

### R-1 — A shared cross-subseries volume-list level
The single biggest gap. Five independent volume-row implementations exist (iOS `VolumeRowLabel`, macOS `SubseriesVolumeListView`, admin dashboard share rows, scope-editor rows, subject pivot sheet) and **no reusable "arbitrary ordered set of volumes" destination**. Almost every new axis (title, release date, administration, editor, scope, tag) drills to exactly that.

Requirements:
- iOS: one new `BrowserLevel` case (e.g. `.volumeList(axis identity + ordered volumeIds)`), **hashed on the axis identity, not the id array**; one view mapping ids → manifest entries, reusing the already-`internal` `VolumeRowLabel` and the same append-`.volume` Button as SubseriesView. Verified: pushing `.volume` without a subseries ancestor renders correctly today (the Corpus → People → Volume path ships).
- macOS: promote `SubseriesVolumeListView` out of `private` (title parameter instead of subseries); its list contract already accepts an arbitrary `[VolumeManifestEntry]` + path binding.
- The list takes a **caller-supplied order** and never re-sorts (release-date and administration orders are the axis's payload).
- An optional per-row **trailing accessory** (admin doc-count/share, release year, editor role) instead of bespoke twin rows.
- **Unify the badge set** across platforms while building it (iOS shows Downloaded only; macOS adds Side-loaded/Indexed/Downloading) — otherwise the #777 twin-drift problem is reproduced inside the new component. Design must specify one badge vocabulary.
- Known degenerate case to resolve (Q-5): a tag chip tapped on a VolumeView reached without a subseries ancestor silently no-ops while setting latent filter state (`activateTagFilter`, BrowserViewModel.swift:304–316).

### R-2 — One corpus-wide per-volume document count
Verified: `administration-profiles-index.json`'s `volumeTotals` is an **exact count of `<div type="document">` per volume for all 552 volumes** (spot-checked 4 volumes against raw TEI; sums to 314,483 = the semantic pipeline's independent count), bundled and eagerly decoded at launch. Meanwhile manifest `documentCount` is structurally dead (0 in all 552; the header parser cannot compute it) and **three shipped Browse labels gated on it have never rendered** (SubseriesView.swift:360, VolumeView.swift:372, CorpusView.swift:163).

Requirements:
- Browse rows and axis sorts read document counts through a thin accessor over `volumeTotals` (so the dependency on an artifact named for another feature is one named seam).
- The dead `documentCount > 0` gates are resolved as part of this work (lit up via the accessor, or removed) — not left as permanently-false code. Populating manifest.json instead is a contract change to the generator's overlay mode (Q-6).
- Wording: the count is FRUS document divs; Search over the same volume returns more rows (+2,356 quasi-documents corpus-wide). Never present the two as the same universe.

### R-3 — The document-grain drill pattern (working corpora, clusters, administration-in-volume)
Per-document titles/dates exist **only** in the FTS index of indexed volumes and in downloaded TEI. No bundled artifact carries them (deliberate, repeatedly ruled). The app's precedent is a settled hybrid, and the design must import it rather than Browse's own volume-level gate:
1. **Show the list with degraded rows, never block it** — header from `document_cache` when indexed, else id + manifest volume title; three-tier date fallback (Collections pattern, CollectionEntryRows.swift:670–686).
2. **State coverage once at the top** — "N of M documents indexed on this device", orange when incomplete; `WorkingCorpusResolver` already computes exactly this sentence.
3. **Gate only the actions** — Open requires the volume on-device; the affordance for a missing volume is **Download**, not a dead end (semantic-map card + cross-ref graph patterns). Navigation needs only ids once downloaded (the map already mints a metadata-less `DocumentBrowserEntry`).
4. **Never snapshot metadata into synced models** — trips the CloudKit gate and contradicts the record-size design.
Note this introduces Browse's first degraded-row surface (its hierarchy gates at volume level today); the design should say so explicitly so reviewers don't pattern-match the wrong precedent.

### R-4 — macOS absorbs axes in one window
The recorded rulings and code favor **one browser window gaining an axis switcher**: sidebar `Section`s (the bare `List(selection: String?)` takes them natively, but selection must be retyped to an axis/subseries enum — touching the `.onChange` path-reset and `pendingVolumePush` deferral) plus new `CorpusNavValue` cases pushed in the existing detail column. Axis rows may cross-link to the People/Topics windows the way the toolbar already does. `CorpusNavValue` is not Codable and `detailPath` is unrestored `@State` — new levels inherit lost-on-relaunch navigation; the design must not promise deep-linkable/restorable axis URLs without pricing that separately.

---

## 5. Per-axis requirements

### A-1 — Volume titles (find a volume by name)
- **Data truth:** all 552 titles, whitespace-normalized at decode. **Naive alphabetical sort is degenerate:** 409 titles begin "Foreign Relations of the United States", 142 begin "Papers Relating…". iOS has no title search anywhere in Browse; macOS has it only within a selected subseries.
- **Requirement:** a search-first affordance over all 552 volumes (corpus-root `.searchable` or a flat "All volumes" catalogue level), matching title + volumeId. If any A-Z presentation is offered, it must key on the distinctive sub-title segment (post-"Volume N,"), never the raw title.
- This axis is plumbing for every other axis (R-1 gives the destination); treat it as the cheapest and first.

### A-2 — Release date (publication year)
- **Data truth:** `publicationDate` on all 552 — 551 bare "YYYY" strings (1861–2025) + one full ISO date. Parse through the existing `firstYear(in:)` helper (CitationFormatter.swift:216), never string sort.
- **Semantics constraint:** this is the **print year**, not a declassification/release date; for early annuals publication ≈ coverage. The axis must be labeled "publication year" (or equivalent) — promising modern release semantics repeats the #965 false-premise class.
- **Requirement:** sort/group the volume universe by publication year (decade grouping is the obvious grain: 1861–2025). Rows show the year via the existing `VolumeRowLabel` (already displays publicationDate). This is a *presentation* of the volume list, not a separate index — the design should decide whether title/release-date/era are one "All volumes" level with a sort control or separate doors (Q-7).

### A-3 — Administration
- **Data truth:** purpose-built bundled index, eagerly decoded on AppState: 32 administrations (Lincoln #16 → Trump-2 #47) each with `volumes: [{volumeId, pointDocs, rangeDocs}]` **pre-sorted by document count**, term dates, party, coverage span; `volumeTotals` denominators for proportions. No document ids in the bundle; per-document drill inside an *indexed* volume is a `document_dates` range query.
- **Requirement:** an administration index level (roster ordered by presidency number) → drill to the R-1 volume list ordered by the index's document counts, with a count/share trailing accessory.
- **Mandatory disclosures:** (a) a volume spanning two administrations appears under both — volume memberships sum to ~879 against 552 volumes (the dashboard's disclosure, AdministrationProfilesData.swift:344–352); (b) wording is "documents **covering** the X administration", never "published under"; (c) zero-document administrations (Clinton onward) render disabled-with-reason, not hidden dead (the semantic-map scope-menu idiom); (d) pre-Lincoln-dated documents belong to no administration — verify the generator's handling before promising totals reconcile.
- **Owner decision Q-2:** membership = `volumeCount` vs `volumeCountPointOnly` (#791 history: a volume tied to an administration only by range-dated editorial notes was miscounted until a toggle governed it).
- Existing precedent to reuse: two shipped "administration = volume set" scope menus (Archival Analytics, Semantic Map) and the SA-2b dashboard's `VolumeShare` math.

### A-4 — Editor / general editor
- **Data truth:** `editors` non-empty on 471 volumes, `generalEditor` on 418; **81 pre-1920 volumes have neither** (a corpus property — their titleStmt carries no editor elements). 209 raw strings ≈ 171 people; **38 clusters have 2–4 spellings** (E. R. Perkins ×4 forms, Aandahl, Slany…), and surname+initial auto-merge over-merges (Shirley L. vs Steven E. Phillips) — normalization needs a **small curated alias table (~38 rows)**, not a heuristic. ~41 `editors` occurrences are actually division chiefs/directors (role vocabulary flattened at parse time).
- **Requirement:** an editor index level (Topic Index template: letter-sectioned, searchable, per-row volume count) → R-1 volume list. Normalization lives in the **grouping layer only** — the manifest strings feed citation formatters/exporters and must never be rewritten.
- **Owner decision Q-1:** include general editors, with a role badge. Recommended yes — general editors are the most prolific names (Dennett 66, Keefer 54, Glennon 50, Howard 49) and an index without them looks broken; but merging without a badge misattributes compilation work. Note the existing #366 scope facet matches `editors` only — a pre-existing asymmetry the design will surface.
- **Coverage honesty:** the axis structurally cannot reach the 19th-century corpus; the surface says so rather than looking incomplete.
- Per-chapter compilers: **out of scope** (prose-only attribution with surname coreference; a separate harvest project).

### A-5 — Custom volume scopes (browse within a scope)
- **Data truth:** `CustomVolumeScope` @Model (id/name/`volumeIds` of raw manifest ids), CloudKit-deployed, with a two-grain pure resolver. Browse consumes it nowhere today; the #258 design doc contains no Browse mention — genuinely unclaimed territory.
- **Requirement:** browsing a scope = the R-1 volume list over `manifestVolumeIds` (**manifest grain**, so undownloaded members still render — Browse's existing behavior), plus optionally a scope-filter mode over the whole hierarchy following the `filterDownloadedOnly` mechanical pattern.
- **Non-negotiable:** `IndexedResolution.noIndexedMembers` / `.scopeUnavailable` render as explicit states — an empty resolution must **never** fall through to the whole corpus under the scope's label (the #258 HIGH finding).
- **Owner decision Q-3:** application idiom — Search *copies* membership into pickers; WordCloud *stores a live reference* (UUID + unavailable handling). Browse must pick one deliberately or users get a third behavior. Any persisted "Browse is scoped to X" state is device-local UserDefaults (the `filterDownloadedOnly` precedent), never a new stored property on the @Model.
- **Inherited bug:** #862 / B-3 — a scope saved on iOS doesn't appear in lists (undiagnosed). A Browse surface built on scopes inherits it; the design should assume the fix lands first or state the dependency.

### A-6 — Working corpora (browse a captured set)
- **Data truth:** `WorkingCorpus` @Model — document-grain `documentKeys` ("volumeId/documentId", ≤7,500, snapshot-by-design with capture provenance and truncation record), CloudKit-deployed. Derived `volumeIds` gives the volume-grain projection. Settings pane lists corpora but nothing anywhere enumerates their documents.
- **Requirement:** a corpora level (list of the user's corpora with capture provenance + the resolver's coverage sentence) → per-corpus: volume tree (R-1) → document list filtered by keys, rendered under the **R-3 degraded-row pattern** with the coverage header. Truncation-at-capture is disclosed on the corpus row ("saved 7,500 of 9,212 matches").
- **Creation stays capture-from-results** (owner stance) — Browse lists and applies, never creates. Empty state points at the capture surfaces (Search results, semantic-map lasso).

### A-7 — Subject-axis completions (optional; the axis itself is shipped)
Small, already-plumbed gaps the design may fold in:
- `SubjectExplorerRequest.group(categoryKey:)` is declared but nothing sends it and the index doesn't handle it — a category/bucket-grouped presentation of the Topic Index means finishing both ends.
- `SubjectDetailSheet` shows a volume *count* but no volume list — adding one is `volumeIds(forSubjectRef:)` + R-1.
- A Browse-native subject→documents list would be new UI over the shipped filter-only query; the shipped design deliberately hands off to Search instead — changing that is a product decision, not a gap.
- Constraint: no cheap bulk per-subject device-wide counts (deliberately no SQL index on `subject`; the shipped pattern is one correlated count per opened subject).

### A-8 — Semantic clusters (conditional)
- **Data truth:** 179 clusters with 4-term labels, sizes, era histograms (25KB index); document-grain membership via a 1.9MB mmapped binary; documents-in-cluster and per-scope cluster tallies exist in code; a cluster list already ships as the map's accessibility representation. One structural wrinkle: the map loader requires the 10.23MB vector binary loaded first — a Browse list level wants a metadata-only load path or must accept that dependency.
- **Gate:** the Plan of Record flags build-42 tester feedback on the semantic map's "leads-or-noise" question as potentially re-ordering everything. **Design the axis; sequence its implementation after that verdict.**
- **Requirement if built:** a cluster list level (label terms + size + era histogram) → document drill under R-3, reusing the map's selection-card behaviors (isDownloaded-gated Open, Save-as-Working-Corpus). Cross-link to the map view ("See on map").
- **Mandatory disclosures:** labels are sampled c-TF-IDF terms, not subject headings (the shipped card's sentence travels); 88,207 documents (28.0%) are unclustered and unreachable from any cluster list (the accessibility summary's sentence travels); era histograms are volume-coverage-midpoint eras, not document dates.
- **Durability rule:** cluster ids re-mint on artifact regeneration (168/179 labels changed once already) — never persist a cluster id in synced data or deep links; materialize document keys at capture (the WorkingCorpus pattern).
- Cluster 8 holds 38,652 documents against a ~250 floor — drill lists need paging; the 7,500 capture cap discloses truncation.

### Adjacent candidate the design may consider: corpus-wide tag browse
Not in #1051's list, but the survey found the inverted index already shipped (`VolumeLevelTagStore.volumes(forTagSlug:)`, 438 slugs across people/places/topics categories) while tag filtering exists only *within one subseries* — and a code doc-comment already (falsely) claims a "Browse-by-Tag volume list" exists. A tag index level → R-1 list would be the cheapest full axis in the set, and #261's `hsg_tag_gaps.json` (82 tag slugs → subject names) becomes relevant if tag rows cross-link to the Topic Index. Flagged for the owner (Q-8); zero data work either way.

---

## 6. Out of scope, with reasons

| Item | Reason |
|---|---|
| People-axis expansion (more people, early-era coverage) | #234: 268 of 552 volumes contribute zero people (no `ref` attributes); remedy is the owner-gated multi-week M1b/M2/M3 offline program. A browse design must state coverage honestly and never assume derived people. |
| Per-chapter compiler attribution | No structured data exists; preface prose with surname coreference ("compiled by Mr. Goodwin"). A separate harvest project with genuine ambiguity. |
| Any new @Model or stored property on a mirrored model | CloudKit R-7 schema-deploy gate (#488 class). The feasible scope needs none; device-local state uses UserDefaults. |
| Document-level subject data changes | #261 (min-instance filter, curated volumes, upstream ask) proceeds independently. |
| Subjects on the document rail | Requires explicitly amending Research-rail D1 (subjects-plan P2-iv). |
| Deep-linkable / state-restored axis URLs on macOS | `CorpusNavValue` is not Codable, `detailPath` unrestored — priced separately if ever wanted. |

---

## 7. Open decisions for the owner (the design should present these, not bury them)

> **Resolved 2026-08-22.** All nine questions were settled during the design handoff and plan session — the rulings live in `Planning/Browse-Axes-Development-Plan.md` §2 (decision register), which also adds the Archives axis (A-9) this document predates. The list below is kept as the historical statement of each question.

- **Q-1** Editor axis: include general editors with a role badge (recommended), and approve a ~38-row curated alias table maintained in the grouping layer.
- **Q-2** Administration membership: `volumeCount` (any dated doc) vs `volumeCountPointOnly` (#791 history) — pick one for Browse, or expose the dashboard's toggle.
- **Q-3** Scope application idiom in Browse: live reference (WordCloud pattern, with `.scopeUnavailable` handling) vs membership copy (Search pattern). One must be chosen deliberately.
- **Q-4** Semantic-cluster axis timing: design now, implement after the build-42 leads-or-noise verdict — confirm or drop the axis.
- **Q-5** The `activateTagFilter` degenerate case on subseries-less paths: fix (fall back to pushing the subseries level), suppress chips, or accept — currently a silent no-op with latent state.
- **Q-6** Document-count source of record: UI reads `volumeTotals` via an accessor (no generator change) vs widening ManifestGenerator's overlay contract to populate the dead `documentCount`. Either way the three dark labels get resolved.
- **Q-7** Presentation of the volume-metadata axes: one "All volumes" catalogue level with sort/group controls (title / publication year / era / doc count) vs separate doors per axis. Fewer doors is consistent with the crowding constraint.
- **Q-8** Whether to admit the corpus-wide tag-browse axis (data-free, cheapest full axis) into scope.
- **Q-9** iOS corpus-root presentation: how the door list scales (a "Browse by…" section, a hub level, or a mixed toolbar/section split) given People-first is test-pinned and the subseries list must stay primary. This is the core layout question for the design session.

---

## 8. Engineering constraints for the eventual implementation (so the design doesn't promise around them)

- Every axis is built **twice** (iOS BrowserLevel machine; macOS CorpusNavValue/sidebar) — the twins have drifted identically before (#777). The design should specify shared components (R-1) in platform-neutral terms and name the per-platform mounts.
- New source files in `FRUSExplorer/Browser/` need the one-time `xcodegen generate` + scheme restore; a green build is not evidence a new file compiled.
- Bundled-artifact-only reads ⇒ no index-version bump, no CloudKit deploy.
- Boot-guard split: bundled-artifact lists render pre-boot; SearchService-backed halves guard on `isBootComplete` (Topic Index precedent).
- UI-test pins: People-first row; two-pane oracle; breadcrumb wrap behavior on iPhone (~100pt problem, Session 121).
- Feature-session docs rule: the session that ships any axis owes the docs pass (Research Guide, manuals, in-app help), and Docs surfaces are test-pinned (`ResearchGuideCoverageTests`).
- Sequencing reality: #1051 is new-feature work; the Plan of Record's standing triage (bugs → partially-shipped → new) applies, and build-42 tester feedback outranks all of it. This document exists so the design is ready when the slot opens.

---

## 9. Suggested build order (information for the design's phasing, not a plan)

1. **R-1 + R-2** (shared volume list + count accessor) with **A-1/A-2** as the proving axes — smallest surface, no semantics disputes.
2. **A-3 administration** and **A-4 editor** — pure index-level → volume-list reuse; each one settles a Q (Q-2, Q-1).
3. **A-5 scopes** (after/with the #862 fix) and **A-6 working corpora** — introduces the R-3 document-grain pattern.
4. **A-7 subject completions** and the optional tag axis (Q-8) — small, independent.
5. **A-8 semantic clusters** — last, behind Q-4.
