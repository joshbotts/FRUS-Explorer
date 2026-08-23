# Browse Axes — Development Plan (#1051)

**Status:** COMPLETE. Sessions B-1 (PR #1060), B-2 (#1064), B-3 (#1065), B-4 (#1066), B-5 (#1067), B-6 (#1068), and B-7 all shipped. The B-7 gate resolved by owner direction 2026-08-23: rather than waiting on the build-42 semantic-map verdict, the clusters axis ships as the *instrument* testers use to reach it — the browsable membership list is what lets a tester judge leads-or-noise directly, and the TestFlight What-to-Test files carry the ask.
**Date:** 2026-08-22 (status updated 2026-08-23)
**Inputs:**
- `Planning/Browse-Axes-Design-Requirements.md` (the feasibility study; R-1..R-4, A-1..A-8, engineering constraints — all still binding)
- The design handoff (spec text mirrored at `Planning/browse-axes-design/Design-Handoff-README.md`; the authoritative annotated canvas `Browse Axes Proposals.dc.html` + 17 screenshots live in the owner's iCloud: `2026-06-30 FRUS Explorer Build 26 screenshots/Design proposals for requirements.zip`)
- The archival-axis feasibility survey (7 agents, 2026-08-22; verdict data-ready-UI-only; measured findings folded into Session B-5 below)

**Sequencing reality:** #1051 is new-feature work under the Plan of Record's standing triage (bugs → partially-shipped → new); build-42 tester feedback outranks this plan. The plan exists so the work is ready when the slot opens. Sessions are sized for one working session each and are independently shippable in order.

---

## 1. What is being built, in one paragraph

The Browse tab (iOS) and Corpus Browser window (macOS) gain: a search-first corpus root with a Browse-by tile grid (design 2a), an All Volumes catalogue with Title/Published/Era/Length presentation (1e), Administration and Editor indices (1g/1h), browse-and-edit for custom volume scopes plus pan-axis scope capture (1i/3a/3b/3c), working-corpus browsing with the degraded-row document drill (1i), a new **Archives axis** (sibling lenses: provenance-type doors + the collection index, reusing Source Explorer's shipped views), subject-axis completions, and — gated on the build-42 semantic-map verdict — a Semantic Clusters axis (1j). Everything reads bundled artifacts or shipped SwiftData models; **no new artifact, no generator change, no SQL schema change, no CloudKit deploy anywhere in this plan.**

## 2. Decision register (all settled 2026-08-22 — do not re-open in session)

| # | Decision | Ruling |
|---|---|---|
| Q-9 | iOS corpus root | **2a** — search-first root + Browse-by tile grid with **Subseries as a double-width tile**. The owner explicitly accepted the trade this bends: the era hierarchy moves one tap deep; the double-width tile + count copy carry its primacy. People/Topics rows stay above the grid (People-first test oracle intact); `ResumeReadingRow` stays first. |
| Q-7 | Volume-metadata axes | **1e** — one "All Volumes" catalogue level (search + segmented Title / Published / Era / Length). No separate Title/Year doors. Also reused as the scope editor's picker mode (3a). |
| Q-1 | Editor index membership | **Compilers only** (`editors`); general editors stay on the volume page. ~38-row curated alias table normalizes spellings **in the grouping layer only** — manifest strings are never rewritten (citation exporters render them as-printed). |
| Q-2 | Administration membership | **volumeCount** (any dated document), with the any-overlap double-membership disclosure. |
| Q-3 | Scope application idiom | **Live reference** (WordCloud pattern): Browse stores the scope UUID, resolves at render, shows the explicit "Scope unavailable" state on deletion. Filter state itself is device-local UserDefaults. |
| Q-4 | Semantic Clusters | Designed now (1j), ~~implemented only after the build-42 verdict~~ — **resolved 2026-08-23 by owner direction**: B-7 shipped as the *instrument* for the leads-or-noise verdict (testers judge cluster membership in the browsable list; the TestFlight notes carry the ask). |
| Q-5 | Tag chips on subseries-less paths | **Push the subseries level with the filter applied** (replaces today's silent no-op + latent state). |
| Q-6 | Per-volume document counts | **One named accessor over `volumeTotals`** (administration-profiles-index). No generator change. The three dead `documentCount > 0` labels are rewired to the accessor. |
| Q-8 | Tag axis | **Cut.** Topics (shipped) is the subject-style axis. Canvas 1k stays struck-through for the record. |
| — | Scope creation in Browse | **Allowed** (owner call 2026-08-22, supersedes "Browse applies, never creates" **for scopes only**). Working corpora remain capture-only — list and open, never create. |
| — | Archives axis shape | **Sibling lenses**: a provenance-type lens (10 category doors → R-1 volume lists) beside a collection lens (repository-grouped index → `CollectionDetailView` → volumes). **Never nested** — no shipped data maps collections to categories (measured many-to-many; heuristic refuted), and the schema-2 generator field that nesting needs is explicitly not taken. |

## 3. Cross-cutting rules (every session inherits; from the requirements doc + surveys)

1. **Twin platforms:** every axis lands twice — iOS `BrowserLevel` case (4 exhaustive-switch touch points: hash/==, `levelView`, `breadcrumbLabel`, door) and macOS `CorpusNavValue`/sidebar. R-1 is specified platform-neutral; mounts are per-platform. No `NavigationLink` in Browser/; rows are Buttons mutating the path; root doors **assign** (`vm.select`), deeper doors append.
2. **macOS:** one Corpus Browser window absorbs everything (R-4). **No new singleton `Window` scenes.** Sidebar `List(selection:)` retypes from `String?` to an axis/subseries enum in B-1 — preserve the `.onChange` path-reset, `pendingVolumePush` deferral, and the `.macCorpusBrowser` hand-off consumption. People/Topics windows stay as shipped; cross-link only.
3. **Honesty:** the Topic Index caption pattern (pinned coverage caption + three-state device counts) on every counting surface; degraded rows never blocked lists (R-3); disclosure sentences travel with their data; disabled states carry reasons. Captions read live artifact coverage blocks — never hard-code figures (several in-code figures are already stale).
4. **State:** device-local browse state (active scope filter, catalogue sort) in UserDefaults. **No new stored properties on synced @Models** (CloudKit R-7 gate). Never snapshot document metadata into synced models.
5. **Mechanics:** new files in `FRUSExplorer/Browser/` need the one-time `xcodegen generate` + `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`. A green build is not evidence a new file compiled. Bundled-artifact reads ⇒ no index-version bump.
6. **Verification per session:** build-for-testing + run the suite (read the test count back); clean build for strict-concurrency warnings when files were added; UI-test pins checked (People-first row, two-pane list-pane oracle, breadcrumb wrap).
7. **Docs:** each session ships its docs pass (iOS/macOS manuals, in-app Research Guide where applicable, `Docs/EditableContent.md` mirror) and appends its DEVELOPMENT-PLAN.md session log.
8. **Full-row taps:** `.frame(maxWidth:.infinity, alignment:.leading)` **then** `.contentShape(Rectangle())` (the #312 idiom).

---

## Session B-1 — Foundations: R-1 + R-2, the 2a root, and the 1e catalogue

*The proving session: the shared list and count accessor land with volume-title/publication-year as the first axes through them.*

**R-2 — the document-count accessor.**
- One accessor (e.g. `AppState.volumeDocumentCount(_ volumeId:) -> Int?` or a small `VolumeDocumentCounts` wrapper) over `administrationProfilesStore.index?.volumeTotals`, summing pointDocs+rangeDocs+undatedDocs. Nil-tolerant (store's index is Optional — degrade to no label).
- Rewire the three dead gates: `SubseriesView.swift:360` ("N docs"), `VolumeView.swift:372` ("N documents"), `CorpusView.swift:163` (subseries sums) + `CorpusStats`. Audit for tests pinning the current zeros.
- Wording rule everywhere: counts are FRUS document divs; Search over the same volume can return more rows (+2,356 quasi-documents corpus-wide) — never present the two as one universe.

**R-1 — the shared volume list.**
- iOS: new `BrowserLevel.volumeList(...)` carrying an axis identity (title + stable key) and **ordered** volumeIds — hash/== on the axis identity, never the id array. New `VolumeListView`: maps ids → manifest entries preserving caller order (never re-sorts), reuses the internal `VolumeRowLabel`, rows append `.volume` with the shipped Button pattern. Slots: coverage-caption (above rows) and per-row trailing accessory.
- macOS: promote `SubseriesVolumeListView` out of `private`; `subseries:` parameter becomes a display title; contract already takes an arbitrary `[VolumeManifestEntry]` + path binding.
- **One badge vocabulary both platforms** (per the design's 1l spec): Downloaded (`arrow.down.circle.fill`) · Indexed (`checkmark.circle.fill`, green) · Downloading (`arrow.down.circle`, blue) · Side-loaded (quaternary capsule) · Partial (orange) · Planned (gray). iOS gains the Indexed badge; check the macOS synchronous per-row `isVolumeIndexed` read doesn't degrade the iOS list (batch or cache if needed).
- Q-5 fix: `activateTagFilter` falls back to pushing/replacing the subseries level with the filter applied when no `.subseries` ancestor exists.

**The 2a root (iOS).**
- Root order: `ResumeReadingRow` → `.searchable` ("Search 552 volumes by title or number", matching title + volumeId over `browsableEntries`) → People row (**stays first cross-volume row — test-pinned**) → Topics row → **BROWSE BY tile grid** → YOUR SETS rows (My Scopes, Working Corpora — doors only in B-1; levels come in B-3/B-4, so these two tiles/rows may land disabled-with-caption or in B-3) → any remaining root content.
- Grid (2a base, extended for the Archives axis; final arrangement to match the canvas idiom): row 1 **Subseries** double-width tile ("552 volumes by era, 1861–1988"); then paired tiles **All Volumes · Administrations**, **Editors · Publication Year**, **Archives · Semantic Clusters** (Clusters carries the amber "gated Q-4" capsule and is disabled until B-7). Tiles are Buttons that assign the path. Tiles for axes not yet built land with their session, not as dead doors — B-1 ships Subseries + All Volumes tiles; the grid grows per session.
- Update the UI tests that pin root structure **without moving People from first cross-volume position**; re-verify `testBrowseIsTwoPaneOnWideiPad` (list pane = CorpusView unchanged in role).

**The 1e catalogue.**
- New level (`.catalogue` or a specialization of `.volumeList`): `.searchable` (title or volume number) + segmented **Title / Published / Era / Length**.
- Title presentation keys on the **distinctive segment** after "Volume N," (409/552 titles share the boilerplate prefix); Published parses via `firstYear(in:)` (never string sort; one entry is full ISO) with decade section headers; Era uses the subseries start-year grouping; Length sorts on the R-2 accessor.
- Coverage caption: "552 volumes. Counts are FRUS document divs from the bundled index; Search over the same volume can return more rows."
- Label the axis **publication year** — the print year, never declassification/release semantics.

**macOS in B-1.**
- Sidebar retype (`String?` → `enum SidebarSelection { case axis(BrowseAxis); case subseries(String) }`), BROWSE section with **All Volumes**, YOUR SETS placeholder section, SUBSERIES section unchanged. Preserve `.onChange` path-reset + `pendingVolumePush` + `.macCorpusBrowser` hand-off (regression test the Cross-Volume-Provenance volume hand-off).
- All Volumes renders in the detail column root; rows push the existing `.volume` case.

**Tests:** pure logic split out per the `SubjectIndexGrouping` pattern — title-key extraction, year parse (incl. the ISO entry), era bucketing, catalogue section building; accessor-vs-artifact pin (sum over volumeTotals == 314,483); R-1 ordering contract (caller order preserved). New files ⇒ xcodegen. **Docs:** manuals' Browse sections re-shot/reworded for the new root ([SCREENSHOT] placeholders — owner captures).

---

## Session B-2 — Administrations (A-3) + Editors (A-4)

**Administrations (`.administrations` + macOS sidebar row).**
- Index: roster order (presidency number), rows number · name · "term · party" caption · trailing "N vols / N docs". Zero-volume administrations (Clinton onward) render **disabled at reduced opacity with the reason**, never hidden. Coverage caption includes the any-overlap disclosure ("A volume spanning two administrations appears under both — memberships sum to ~879 across 552 volumes").
- Drill: R-1 list in the index's stored order (pointDocs desc — never re-sorted), trailing accessory "N docs / N.N%" (share vs volumeTotals). Dual-membership rows carry the inline "also under X" note. Wording is always "documents **covering** the X administration", never "published under". Membership = volumeCount (Q-2).
- Verify before shipping copy: how the generator counted pre-Lincoln-dated documents (roster starts at Lincoln) so totals reconcile or the caption says so.

**Editors (`.editors` + macOS sidebar row).**
- Topic-Index template: `.searchable`, letter sections, per-row trailing "N volumes". Compilers only (Q-1).
- **Alias table:** ~38 curated rows (the measured variant clusters — Perkins ×4, Aandahl, Slany, Nuermberger, trailing-period/space typos…), applied in the grouping layer; merged rows show the "N spellings merged" tertiary caption; the Phillips pair stays split (surname+initial auto-merge over-merges). Table lives beside the grouping enum (in-code or a tiny bundled JSON — reviewer-checkable in one sitting).
- Header caption verbatim from the design: names the 471/552 coverage and that 81 pre-1920 volumes carry none; general editors credited on the volume page, not indexed.
- Drill → R-1 (volume order: publication year or manifest order — pick one and state it in the caption).

**Tests:** `AdministrationIndexRows` + `EditorIndexGrouping` pure enums (alias fold is the priority — name the tie-break fixtures against the expectation, per the repo's fixture-naming rule); disabled-state rendering; UI pins. **Docs pass.**

---

## Session B-3 — Custom scopes: the #862 gate, then A-5 + the editor + pan-axis capture

**Gate: diagnose and fix #862** (iOS scope saved but not appearing in the list — B-3 in the Plan of Record, "needs diagnosis before code"). Everything below builds on scope visibility; do not stack on an undiagnosed bug.

**My Scopes level (`.scopes`) + browse-within-scope.**
- List rows: name + "N volumes · edited date"; unavailable scope dimmed with "Scope unavailable on this device". Opening a scope → R-1 list at **manifest grain** (`manifestVolumeIds` — undownloaded members still render).
- Filter mode: "Browsing within: X ✕" pinned banner above the subseries content, mechanically the `filterDownloadedOnly` pattern; **live reference** (Q-3): store the scope UUID in UserDefaults, resolve per render, `.scopeUnavailable`/`.noIndexedMembers` are explicit states — an empty resolution **never** falls through to the whole corpus under the scope's label (the #258 HIGH finding).

**3a Scope editor** (pushed `.scopeEditor(id)`): name field, member rows with delete controls + R-1 row content, "Add Volumes…" opening the 1e catalogue in **picker mode** (search/sort, tap-to-check). Writes only the existing `name`/`volumeIds` fields — no schema change. Footer copy per the design.

**3b Pan-axis "Add to Scope…" context menu** — lives **once in the shared R-1 list** (all axes inherit): Add to «most recent», Add to Scope… submenu (checkmarks; adding an existing member no-ops), New Scope from Volume…, then the existing per-row items. macOS: same items on the promoted list's row menus; editor pushes in the detail column — no new window.

**3c Whole-slice capture** — toolbar "Save as Scope…" on every R-1 list; name pre-filled from the axis identity (e.g. "Truman administration (44 volumes)").

**Tests:** resolver states (unavailable/none-indexed/live-edit reflection), editor round-trip, context-menu membership no-op; scope banner persistence. **Docs pass** (scopes move from Settings-only to a Browse feature — both manuals + Research Guide).

---

## Session B-4 — Working corpora (A-6) + the R-3 document drill

- `.corpora` level: rows name + "N documents · captured from Search/Semantic Map · date"; truncation disclosed on the row ("saved 7,500 of 9,212 matches", amber). Footer: capture happens in Search results and the map lasso — **no create here** (owner stance stands).
- Per-corpus: volume tree via derived `volumeIds` (R-1, ordered by volumeId), then `.corpusDocuments(id)` — the app's **first Browse degraded-row surface**, importing the Collections/map precedent deliberately (say so in the PR):
  - Amber coverage header from `WorkingCorpusResolver` ("N of M documents indexed on this device").
  - Indexed rows: header + "place, date · volume title" via the **bulk** paths (`CrossReferenceStore.documentHeaders` + `IndexingPipeline.datesByDocumentKey`, chunked — a corpus holds up to 7,500 keys; per-key queries are rejected at that scale).
  - Unindexed rows degrade to id + manifest volume title + three-tier date fallback; the affordance is a **Download** (or **Index**) capsule — the list never blocks, actions gate.
  - Editorial notes are indexed-but-headerless: `header == nil` is not evidence of an unindexed volume — coverage comes from volume membership, never header presence.
- Never snapshot metadata into the @Model.

**Tests:** degraded-row fallback tiers, coverage computation vs volume membership, chunked bulk loads. **Docs pass.**

---

## Session B-5 — The Archives axis (A-9, sibling lenses)

*New since the requirements doc; feasibility surveyed 2026-08-22 (7 agents, verdict data-ready-UI-only). Reuses Source Explorer's shipped views rather than minting a third collection list (#777 twin-drift class).*

**Data plumbing (small, app-side only).**
- Forward accessor over the already-decoded `volumeCategories` rows: `volumes(forCategory:) -> [(volumeId, docCount)]` (~10 lines beside `CollectionUsageIndex.categoryCounts(forVolumeId:)`).
- All captions read `CollectionUsageIndex.coverage` live (4,429 authority records / 1,839 reached / 264,464 notes / 501-of-552 volumes) — several in-code doc comments carry stale 2026-08-08 figures; never copy them.

**iOS `.archives` level (+ macOS "Archives" sidebar row).**
- Index level with the two **sibling lenses** (segmented control or two sections):
  - **By provenance type:** 10 doors from `SourceProvenanceCategory` display names with volume/doc counts (Central Decimal File 412 vols · 194,834 docs; Presidential Libraries 296 · 29,178; Lot Files 290 · 13,964; …). Every door drills **straight to an R-1 volume list** (per-volume doc counts as trailing accessory; `volumeNoteCounts` as the share denominator). No door nests collections (settled — see §2).
  - **By collection:** mount the existing `CollectionBrowserView` (repository-grouped, searchable, all 4,429 records) with a new optional `onSelect: ((AuthorityCollectionRecord) -> Void)?` seam — nil keeps the sheet for its three existing mounts; the Browse mount **pushes** `CollectionDetailView` in-stack instead. Optional doc-count accessory from the usage index; **front-matter-only records (2,590 of 4,429) render "front matter only", never "0 documents"**; the Central-Files umbrella record inherits the shipped hide-behind-a-visible-chip ruling (`ArchivalCollectionsData.umbrellaCollectionId`) rather than re-litigating.
- `CollectionDetailView` push-hosting: it is push-friendly by design, but inject an **in-place volume route** (optional closure appending `.volume` to the current path) so its citing-volume rows preserve the axis back-stack instead of firing the sheet-era `openBrowseVolume` hand-off that tears down context. The NAID trust gate stays inside the detail — **the axis never renders `record.naId` or catalog links itself**.
- macOS: one new `CorpusNavValue.collection(collectionId: String)` case — carry the **string id** and re-look-up via `CollectionAuthorityStore.record(id:)` (`AuthorityCollectionRecord` is not Hashable; the `.volume` case documents the same re-lookup contract). Archives sidebar selection renders the index at the detail-column root.

**Disclosures the axis owes (pinned caption + row copy):**
1. The population: "Counted from the source note printed under each document — 264,464 documents carry one; 51 volumes, mostly the pre-1906 annuals, print none and cannot appear here" (this is a **post-1906 story**; #965's body-embedded attribution is separate).
2. The collection lens ceiling: "About 28% of sourced documents name an archival collection; most of the rest cite a State Department central-file number" — the category lens is what makes the axis honest about the 72%.
3. Corpus-vs-device (Topic Index pattern) wherever a device count appears.
4. Drawn-from vs pointed-at (#783): external-citation counts are a separate evidence body, never summed — reuse the shipped "Pointed At, Not Printed" wording if surfaced at all.

**Deliberately out (v1):** central-file **class** browsing (10,446 keys, 3,943 single-document — unbrowseable tail; the class story lives in Archival Analytics: cross-link instead); **era grouping** of collections (would trigger the #763 no-stored-rollups drift guard + mandatory parity test — reuse-or-skip, and v1 skips); per-document drill beyond what `collectionNeighbors(scopeVolumeIds:)` already gives the detail view.

**Tests:** forward-accessor pin (category sums vs artifact coverage), `onSelect` seam (nil = sheet, set = push), umbrella-chip inheritance, front-matter-only copy rule. **Docs pass:** iOS manual §14/Browse table, macOS manual §14.5, Research Guide "Find it from…" entries.

---

## Session B-6 — Subject-axis completions (A-7) + program polish

- Wire `SubjectExplorerRequest.group(categoryKey:)` end-to-end: a category-grouped presentation in `SubjectIndexView.load()` + at least one sender ~~(the results-facet section header is the natural door)~~. **Shipped 2026-08-23, with one premise corrected:** the facet section header structurally cannot send `.group` — its Subjects section knows nothing narrower than `.all` (per-row facet doors are the deferred P2-i). The sender is `SubjectDetailSheet`'s **All «area» topics** button, the one surface that knows its bucket exactly; arrival renders as a removable topic-area chip, and a malformed/stale key honestly falls back to the full index.
- `SubjectDetailSheet` gains its covering-volumes list (`volumeIds(forSubjectRef:)` + R-1 join) beside the existing count. **Shipped** — complete membership, six-row preview + Show-all, rows open the volume in the browser.
- Program polish sweep: breadcrumb labels for every new level *(verified — all 18 levels label)*; hand-off drains verified from both `.onChange` and `.onAppear` *(verified intact)*; the stale scene doc-comment table in `FRUSExplorerApp.swift:55–105` updated if any scene metadata drifted *(it had — ten scenes stale; recounted to iOS 12 / macOS 27 against a declaration-by-declaration recount, plus three downstream comment fixes)*; DEVELOPMENT-PLAN.md session logs for B-1..B-6 *(done)*; requirements-doc §7 annotated as resolved *(done in PR #1059)*.

---

## Session B-7 — Semantic Clusters (A-8) — SHIPPED 2026-08-23

~~**Do not start until the owner relays the build-42 semantic-map leads-or-noise verdict (Q-4).**~~ **Gate resolved by owner direction 2026-08-23:** B-7 proceeds *to help testers provide the verdict* — the axis is the instrument, not the verdict's consumer. If the eventual verdict demotes the map, removing the tile remains one clean commit.

- Decide the load path first: the 25KB `semantic-map-index.json` list level either accepts the `BundledSemanticVectors` (10.23MB) dependency or gains a metadata-only decode (preferred — the list should render without the vector binary; membership drill loads the rest). **Decided by measurement: the metadata-only preference rested on a stale premise** — `BundledSemanticVectors.prepare()` runs unconditionally at every launch, the binary is mmapped not read (and is 19.5MB at the shipped 512-dim generation, not 10.23MB), and the drill needs the placements anyway. The level loads through `BundledSemanticMap.prepare()`, inheriting both provenance refusals rather than duplicating one.
- `.clusters` level per design 1j: 4-term label · "N documents" · era mini-histogram; pinned caption (labels are sampled terms, not subject headings; 88,207 documents / 28.0% belong to no cluster and are unreachable here; eras are volume-coverage-midpoint).
- Drill: R-3 degraded document list with paging (cluster 8 = 38,652 docs), reusing the map card's behaviors (`isDownloaded`-gated Open, Save-as-Working-Corpus with the 7,500 truncation disclosure), plus "See on map" cross-link.
- **Never persist cluster ids** in synced data or deep links (ids re-mint per artifact generation); materialize document keys at capture.

---

## 4. Dependencies, risks, and watch-items

| Item | Binding on | Note |
|---|---|---|
| #862 scope-save visibility (open, undiagnosed) | B-3 gate | Diagnose before code; everything in B-3 stacks on scope list visibility. |
| Build-42 tester feedback | Whole plan's slot; B-7 hard gate | Plan-of-Record triage; the semantic verdict can cancel B-7. |
| People-first UI-test oracle | B-1 root rework | 2a keeps People as first cross-volume row; update tests without moving it. |
| macOS sidebar retype | B-1 | The riskiest single change (path-reset, `pendingVolumePush`, `.macCorpusBrowser` hand-off); regression-test volume hand-offs from Cross-Volume Provenance and Collection detail. |
| `CollectionDetailView` non-optional `@Environment(AppState.self)` | B-5 | Traps on declaration — every new host must inject AppState (the About-window incident class). |
| Sheet-hoisting | B-5 | Section-emitting views must not anchor sheets (VolumeSourcesView v1.1 history); the axis pushes instead. |
| Stale in-code coverage figures | B-5 | Captions read artifact coverage blocks at runtime. |
| Twin drift | all | R-1 is the antidote; any per-platform divergence in the shared list is a review blocker, not a style choice. |
| Breadcrumb wrap (~100pt, Session 121) | B-1+ | Axis-list crumbs + long volume titles; crumbs stay width-capped per design 1n. |

## 5. Acceptance (per session, beyond its listed tests)

Build-for-testing green with the test count read back; zero new strict-concurrency warnings on a clean build when files were added; UI-obstruction and browse UI suites pass on iPhone + the iPad two-pane destination; docs pass shipped in the same PR; DEVELOPMENT-PLAN.md session log appended. Each session's PR body carries the per-platform visual-review checklist (the repo's UI-PR rule) with [SCREENSHOT] placeholders for the owner.
