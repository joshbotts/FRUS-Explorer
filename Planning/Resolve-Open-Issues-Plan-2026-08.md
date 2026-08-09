# Resolve Open Issues — Plan of Record, August 2026

**Date:** 2026-08-09 · **Status:** plan of record for the open-issue backlog · **Verified against:**
`v2` @ `9b62f33`, all 37 issues open on 2026-08-09, every body and comment read, every "landed?"
claim below checked in the tree (not inferred from PR prose).

**Version history:**
- 1.0 — Session 2026-08-09: initial plan, from the full open-issue verification sweep.
- 1.1 — Session 2026-08-09: **Tier 0 executed.** QW-1…QW-5 struck through with their measured
  corrections — four of the five items were wrong in ways that would have produced a build error
  (QW-2), a fix that breaks five working links (QW-3), an edit to the wrong file (QW-1), or a red
  test suite (QW-4). The corrections are recorded in place rather than deleted, per §5.

**What this document is.** The 2026-08-09 sweep verified the status of every open issue, closed the
five that were finished, retitled three whose own audit comments had refuted their titles, and
pinned shipped-vs-remaining ledgers on the two navigation-audit issues. This plan prioritizes
**what is left that no live planning document already carries**. Items that *are* carried elsewhere
are listed once in §2 with pointers and are deliberately not re-planned — a second schedule for the
same work is how plans start disagreeing with each other (the failure mode #651 documents).

House rules that bind every session here: implementer ≠ reviewer; UI PRs carry a visual-review
checklist (owner verifies on device); `build-for-testing` before claiming green; `CATALOG_API_KEY`
is owner-held — keyed generator runs are owner-executed; CloudKit `@Model` changes trip the R-7
schema-deploy gate and must batch their Production deploys.

---

## 1. Disposition record — the 2026-08-09 sweep

37 open → **32 open** after verification.

**Closed as completed** (each with an evidence comment on the issue):

| issue | why |
|---|---|
| #765 Archival analytics Phase 3 | All four modes shipped (PRs #785/#786) + D3 export (#789). Un-landed SA-3 cross-link rider folded into #795. |
| #764 Provenance-flow matrix | Generator + index (PR #782) + Flows surface (#786). Class-flow surface declined by its own measurement; label-table rider refuted in the plan of record. |
| #754 Restoration depth | Decision recorded in `Restoration-Depth-Design.md` and delivered by PR #771 (L-45 fix + resume-reading). B/C deferred until A is lived with. |
| #597 TipKit orientation | Phase 0 (#630), Research Guide (#633), Phase 1 (#634), and the "Show Tips Again" recall all shipped. #652 is the surviving split. |
| #663 Digitised scans | Both routes shipped (`digitized-ranges-index.json` PR #730, `roll-scans-index.json` + shared row PR #731). Catalog-field riders carried here as **F-7**. |

**Retitled to match their own measurements:** #795 (widened: both missing Archival Analytics doors),
#405 (narrowed: creator *display*; the similarity axis is measured-negative), #358 (narrowed: the
two real Zotero dead ends; the local-app premise was wrong).

**Status ledgers posted:** #751 and #752 now carry shipped-vs-remaining tables so nobody
re-implements the fixed findings; #651's own scope was narrowed (the consolidated plan was already
corrected — only the runbook edits remain).

---

## 2. Covered elsewhere — pointers, not plans

These issues stay open but their work is scheduled or designed in a live document. This plan does
not duplicate them; it only records the post-plan deltas measured on the issues themselves.

| issue | carried by | delta this sweep confirmed |
|---|---|---|
| #353 SourceNoteParser remainder | `Consolidated-Development-Plan-2026-08.md` N-1 | 8 of the listed items shipped (#712–#719, ~3,010 docs; unrecognized 2.8% → 2.2%). The remaining slice is re-scoped by the 2026-08-05 comment: **three anchored decimal-class rules first** (`File No.` prefix 21,960 docs / named-subfile 2,837 / dash-alpha suffix 1,165 — one `currentDateIndexVersion` bump for the set), then WNRC year-first accessions (111), the small decimal tail, and the closing instruction to re-run `SourceExplorerExportGenerator` and adopt the new eval baseline. No harvest dependency — measured worth 11 documents there. |
| #372 Lot-map consolidation | Consolidated plan N-5 | Verified NOT started (`VolumeSourcesView` still reads `VolumeSourcesIndexStore.resolution`). The 2026-08-03 measurement re-split it: **PR 1 repoint = 728 documents, executable now, no harvest**; PR 2 fold = 2 docs + hygiene; the 13-lot cross-RG harvest supplement needs an owner decision on relaxing the record-group guard (raise explicitly — see O-7). |
| #235 Simplify NARA lookup | Consolidated plan N-6 | Unchanged; unstarted. |
| #234 Extend people browser | `People-Early-Era-Program.md` | M0 shipped (#736/#737); M1a measurement ran (#742). The issue stays open as the program umbrella per its own 2026-08-08 analysis (Session-8 enrichment did not and could not reach the 268 no-list volumes). |
| #308 + #261 FRUS-subjects | `308-Subject-Integration-Design.md` | Architecture designed and adversarially reviewed; document-level data still not shippable. The one unblocked owner action is #261's upstream ask — tracked as **O-6**. Scaffolding work can proceed from the design doc when a slot opens; it needs no data. |
| #751 iOS reading journey (remainder) | `iOS-Reading-Journey-Design.md` | Search origin + page-turn-replace shipped (#768). Remaining: the Research/History/leads restructure (deferred pending a **second owner decision** — the typed-path #238/#272 workaround makes it a restructure, not an adoption) and the M-17b device check. Decision tracked as **O-3**. |
| #106 Screenshot checklist | The issue is its own tracker | Settings-North-Star tier added 2026-07-26; also reconcile the five ticked-but-uncommitted rows it flags. |

---

## 3. The plan — tiers, effort, and why

Effort scale: XS ≤ ½ session · S = 1 session · M = 1–2 sessions · L = program.

### Tier 0 — Quick wins ✅ **DONE (2026-08-09)** — one session, one PR

All five were evidence-complete in their issues; none needed a decision. Together they retire two
`bug`-labelled items and the only docs-drift item. **Shipped as one PR with five commits, not five
PRs:** QW-1 and QW-4 both insert rows into `MainWindowView`'s toolbar, and separate PRs off `v2`
would have conflicted on merge for no reviewing benefit.

**What each item got wrong, measured before any edit:**

| item | the plan said | the tree said |
|---|---|---|
| QW-2 | `.badge(cond ? "·" : nil)` | Does not compile. `Tab` is `TabContent`, not `View`; `TabContent.badge` has no optional-String overload. Shipped `Text(verbatim: "·") : nil`. |
| QW-3 | 18 autolinks; de-link when the link text is not a URL | **22**, in twelve volumes — and that predicate de-links five real supplement PDFs. Shipped a two-clause rule (bare-host target **and** non-URL text): 619 http refs, 22 de-linked, 597 kept. Verification doc was wrong too. |
| QW-1 | cross-link in `EducationDashboardView`; XS | That is a dispatcher; the dashboard is `SourceProvenanceDashboard`. Not XS on iOS, where it renders inside the mid-onboarding sheet — macOS arm shipped, iOS arm filed. |
| QW-1 | extend the `ArchivalLibraryQueryTests` assertion | It reads `FRUSExplorerApp.swift`, which is why it stayed green through the whole bug. Needed a **second** test reading `MainWindowView.swift`. |
| QW-4 | `bringMacWindowToFront` + `openWindow(id:)` | That is the pre-#749 idiom `MacWindowFrontingTests` greps for and fails on. Shipped `openWindow.fronting(id:)`. |

- **QW-1 · #795 — the two missing Archival Analytics doors** (XS). Add
  `openWindow.fronting(id: "frus.archivalAnalytics")` to the `MainWindowView.swift:297` toolbar
  Menu and the SA-3 dashboard cross-link (`EducationDashboardView`). The manual promised the
  toolbar entry until the same-day #796 review rewrote it to document the gap ("**Archival
  Analytics** … is *not* on this menu") — when the button lands, restore that sentence and the
  window-table row to route through the toolbar menu again. Extend the `ArchivalLibraryQueryTests`
  source assertion to pin the toolbar entry so the two menus cannot drift again.
- **QW-2 · #657 first step — badge `nil`, not `""`** (XS). `MainTabView.swift:154`:
  `.badge(appState.unindexedVolumeCount > 0 ? "·" : nil)`. This is the issue's own suggested first
  move; the empty-string badge materialises a contentless `UILabel` in exactly the
  `_UIFloatingTabBarItemView` stack the crash log names. Cannot be *proven* the fix from here —
  conviction is B-1 — but it is cheap, defensible, and worth a version-history note either way.
- **QW-3 · #659 — de-link the 18 spurious autolinks** (S). Render-layer only, at the
  `.crossReference` case (`ASTToRenderNodeConverter.swift:250`): an `http(s)` target whose link
  text is not itself a URL renders as plain text, never `.crossRefLink`. Keep the `.external`
  branch and its #658 guard test. Verify on `frus1867p1/d303` ("would be", "Shall", "But it") and
  `frus1863p1/d277` ("must be"). Deliberately NOT via `broken-refs-index.json` (needs a keyed regen
  for 18 rows) and NOT tap-suppression (leaves a dead link rendered).
- **QW-4 · #652 — give the macOS History window its second door** (S). One button in the
  **toolbar** "My Research" menu (`MainWindowView.swift:351–367`) — NOT the menu-bar Research menu,
  which already has it (the issue documents this trap). Reuse key `menu.history.completeHistory`;
  icon `clock.arrow.circlepath`; call `bindTool(.history, to: hostID)` (its first host-bound
  producer — fixes History-opened documents falling through the recency chain as a side effect);
  `bringMacWindowToFront`; update the stale tooltip at `:370`; optional ⌘Y on the menu-bar item.
  Register nothing in `DiscoveryTipRegistry`.
- **QW-5 · #651 + docs hygiene** (XS, docs only). In `352-lot-resolution-runbook.md`: replace the
  "Still deferred (needs the key)" block with the executed-2026-07-29 record (keep the still-true
  #375 sentence about the 573 manually-curated lots) and add the step-4 line naming the fifteen
  lots the regen re-resolved (65D5, 59D448, 54D341, …). Also fix
  `Restoration-Depth-Design.md`'s header ("Nothing is implemented" — stale since #771). Closes #651.

### Tier 1 — Standing bugs that need diagnosis before a fix can be honest

- **B-1 · #657 — convict or acquit the iPad tab-bar rebuild** (M, owner-in-loop). The open
  question after QW-2: the hang/kill classification (watchdog `0x8BADF00D` vs the thread's
  data-abort at address 0) and the driver that runs in *both* document modes. Protocol per the
  issue's 2026-08-02 comment: owner captures a paused main-thread backtrace **in Read mode** on
  iPad (the rail is not mounted there, so a loop that still shows means the rail is innocent);
  also measure badge-churn frequency during indexing. If QW-2's build stops reaching the stack on
  device, record it and close.
- **B-2 · #777 — side-loaded volumes invisible to Browse** (M). Search finds their documents;
  Browse and the corpus explorer never list the volume. Mechanism hypothesis to verify first: the
  browse tree is manifest-driven, and a side-loaded volume outside `manifest.json` gets FTS5 rows
  but no browse node. Fix shape (after verification): give side-loaded volumes a browse presence —
  either an overlay entry in their subseries when the volume id matches the manifest, or a
  dedicated "Side-loaded" group when it doesn't — plus the same affordance in the macOS Corpus
  Browser (dual-surface parity trap). Both entry paths (Settings ▸ sideload UI and any
  file-association import) must land in the same place.

### Tier 2 — De-risked feature sessions (no gate, evidence already gathered)

Ordered by value density; each is a normal PR-sized session with its spec already on the issue.

- **F-1 · #784 — `external_citations` table + Flows layer** (M, ~2 sessions). Now unblocked
  (#765 closed). The non-negotiables are contractual: anchor-first grammar in its own entry point
  (never route footnote prose through `decimalClassLocation` — the subject-numeric exclusion list
  is calibrated to the sentence bound); its own FTS5 aux table (never `document_sources`, never
  provenance — #783 just removed exactly that); document-ordered pass for the 12,482 stateful
  `Ibid.` inheritances; skip the 142 absence-claim notes. Lots + libraries only (decimal classes
  later, guarded; subject-numeric never — 87.2% OOV). `currentDateIndexVersion` bump; no CloudKit
  gate. Payoff: the only archival-flow signal that reaches 1910–1945, on a surface that shipped
  with the disclosure already phrased.
- **F-2 · #752 tail — scene-addressing sweep** (S). Four verified leftovers, one shared shape:
  M-25 (prefer the activated scene for Spotlight/Handoff/import continuations, or front the
  consuming scene), L-40 (`FRUSExplorerApp.swift:543-553` — origin-scene + `openTab` pairing for
  Source Explorer related-doc taps), L-43 (convert `showResearchGuide` from shared bool to a
  scene-addressed Handoff), L-48 (clear `pendingAuxWindowOriginRaw` after refocus-only
  `openWindow(value:)`). Multi-window iPad test passes per the #769 pattern.
- **F-3 · #775 — facet multi-select + exclude** (M: design ½ + build 1). The Eight-Issue-Plan's
  re-estimate stands: sets and negation move the filter model, the chip vocabulary, and the SQL —
  the facet panel becomes a query builder. Settle the shape first (per-domain include-set +
  exclude-set across Years/Volumes/People, chips that read honestly, `SearchSQLFilters` growing
  set-valued fields with `NOT IN`). The reachability half (#586's old scope: raised bucket limit +
  local sort + display cap, non-lazy `ScrollView` hazard) can ship first and independently.
- **F-4 · #645 remainder — make the archival pool's ordering honest** (S). Per the 2026-08-02
  audit: (1) stratify the collection-authority alias fallback (`aliasNeighbors`' four helper calls
  take `.alphabetical` today); (2) fix the scoped re-cut (`applyScope`'s `prefix(limit)` — binds
  at subseries grain); (3) report the truncation (`totalBeforeLimit` is computed inside the ≤120
  pool — a truncated total presented as complete); (4) convert
  `ArchivalPoolOrderingTests.onlyTheAnchoredPathOptsIn` from a count to an allowlist first, since
  it currently pins the bug shut; (5) write the pool-depth measurement into `Planning/` where the
  PR prose left it.
- **F-5 · #733 — CIA Job numbers as a front-matter key** (S). Keying gap only: the volume-sources
  generator keys no Job number from outline rows (19 paragraph-encoded rows known; measure the
  `<list>`-encoded population while in there). `SourceNoteParser` already owns the Job grammar
  (`#"\bJob\s+([\w–—\-\/]+)"#` — en-dashes) — reuse it, never a second regex. Regenerate
  `volume-sources-index.json` offline.
- **F-6 · #405 (retitled) — series creators in Source Explorer** (S). The measured-positive
  remainder: a bundled `naId → creator heading` map (~622 entries, kilobytes; offline projection
  from the owner's harvest — no key, no re-harvest) rendered as "this series was created by X"
  with a #650-style cohort statement, both Source Explorer views. The similarity axis stays dead
  (2.8% reachability, structural — do not resurrect).
- **F-7 · carried from #663 — the three catalog fields** (S). `accessRestriction` ("Restricted —
  Fully" is trip-planning information), `inclusiveStartDate`/`inclusiveEndDate` (sanity-check a
  resolution against the citation's own date), `findingAids`/`numberingNote` (NARA's own ordering
  instruction) onto `NARACatalogResult` + both views. Bundle-plus-presentation; no index bump.
- **F-8 · #358 (retitled) — Zotero dead-end fallbacks on iOS** (S). (1) Unconnected
  `exportZoteroRIS()` path: offer the web-library/file hand-off instead of an RIS the iOS Zotero
  app cannot open; (2) failed connected send: fall back to file/web-library from `exportError`
  instead of stopping. If the owner instead rules the RIS-to-a-Mac path sufficient, close the
  issue — that standing question is O-3's sibling but needs no design, just a yes/no.
- **F-9 · #306 — in-chart scrubber for year scope** (S). Swift Charts selection
  (`chartXSelection`) to narrow the analytics year filter by dragging on the chart itself; honor
  the existing scope chip + reset affordances.
- **F-10 · #263 — batch citation lookup (footnote triage table)** (S). Paste a block of
  citations → per-row resolved/ambiguous/missing table. Engine unchanged; natural macOS window
  content for `CitationLookupView`; iOS gets the same table in the sheet.
- **F-11 · #265 — corpus-wide glossary/abbreviation lookup** (S). The terms table is already
  indexed by term string; this is a search-scoped UI over it.

### Tier 3 — Infrastructure, tests, accessibility

- **I-1 · #268 — shared `AXChartDescriptor` builder** (M + owner device pass). Zero
  `AXChartDescriptor` exists in the tree while the chart population has grown to five analytics
  families (corpus, person, cross-ref, archival, About-the-Series) — the payoff has grown since
  filing. Extract from `ChartInspectorRow`, adopt per family, then **owner VoiceOver validation
  on device before shipping** (the issue's own gate).
- **I-2 · #312 — the seeded-fixture obstruction test** (S). Gap 1 is unblocked (#336 fixed the
  test-mode `DownloadManager` nil-capture): seed a note/tag, drill into the detail column, assert
  content obstruction with the `navigationBars` oracle. Record gap 2 (swipe-defeats-tap harness
  quirk) as a documented limitation; scenario 4's Browse drill-in needs a different driving
  mechanism per the measured answer (NavigationLink-backed row or accessibility action — not a
  coordinate tap).
- **I-3 · #270 — migrate the 5 original generators onto GeneratorKit** (M, mechanical). One
  generator per PR (Manifest, Taxonomy, CentralFilesIndex, VolumeSourcesIndex,
  SourceProvenanceIndex), byte-verifying each regenerated artifact. Every generator written since
  already uses GeneratorKit, so this is closing a two-standards gap, not adopting a new one. Fold
  each migration into the next session that regenerates that artifact anyway (F-5 touches
  volume-sources — do that one there).

### Tier 4 — Owner-gated: decisions and keyed runs

Engineering on these is blocked or bounded until the named owner action happens. Each is one
sitting, not a session.

- **O-1 · #681 — the presidential-library route** (key + decision). (a) One keyed v2 call to
  confirm `collectionIdentifier` filtering (verified on the public proxy only — inference, not
  measurement, on v2); (b) run the `PresidentialLibraryCatalogGenerator` keyed harvest to
  completion (resumable; completeness self-checked against NARA's `seriesCount`); (c) decide
  guard-vs-caveat for the ~56% of library citations the bundle cannot answer — curation (#355
  pattern) or "offline-first + caveat is guard enough". The engineering follow-through (library
  acceptance test parallel to `LotResolutionAcceptance`, keyed on ancestry `collectionIdentifier`)
  becomes a normal session once (a)+(b) land.
- **O-2 · #626 — user-editable summaries** (design decision). The recorded stop question: what
  distinguishes a user-written summary from a research note (already free-form, tagged, searchable,
  exportable, in the rail)? Options: merge into notes with a "summary" role; or provenance-labelled
  summary editing (AI / AI-edited / human) as the collection-headnote affordance generalized. The
  provenance model half is prior art in headnotes; the distinction question is the owner's.
- **O-3 · #553 + #751 — the leads-list experience, decided once** (design decision). Two open
  remedies for the same Project-leads pain: a peek/preview (owner-deferred "snippets first"
  decision, 2026-08-01) and the Research/History/leads journey restructure (deferred second
  decision, `iOS-Reading-Journey-Design.md` §6). Decide jointly — a restructure that keeps
  journeys in-tab weakens the case for a peek, and vice versa. Also settle M-17b with the device
  check (measure, don't design around).
- **O-4 · #279 — classification override** (design first). Reversible per-document override of
  document/editorial-note typing with anomaly warnings. Almost certainly a CloudKit `@Model` (or a
  field on one) → R-7 schema gate; batch its deploy with O-5 if both proceed. Needs a short design:
  where the override lives, what honors it (indexing? analytics? the editorial-notes toggle #791
  shipped?), and the un-override path.
- **O-5 · #266 — saved-search freshness** (design first). "New results since last run" needs a
  per-search watermark (CloudKit model change → R-7 gate) and a definition of "new" that survives
  reindexing (document identity, not rowid). Batch the schema deploy with O-4.
- **O-6 · #261 — send the upstream ask** (owner email). The gate on all document-level subject
  data: ask Virginia to re-run `export_json.py`/`export_app_bundle.py` post-round-3 and re-run the
  5 stale string-match volumes. Decided 2026-07-09, **still unsent 2026-08-09**. Everything else
  in #308/#261 waits on the data; the #308 scaffolding does not.
- **O-7 · #372 rider — the record-group guard decision** (decision, rides N-5). Admitting the 13
  harvest-resolved lots whose series sit in a different record group than the citation names
  (61D282A → RG 353 etc., 84 documents) means deliberately relaxing
  `isAcceptableLotResolution`'s first conjunct — an uncertainty-policy call, not a flag. Raise it
  when N-5 PR 2 is cut; PR 1 (728 documents) does not wait on it.

---

## 4. Suggested sequencing

**Engineering lane** (each row one session unless noted):

1. ~~**Quick-wins session** — QW-1…QW-5~~ ✅ **2026-08-09.** Retired #795, #659, #652, #651 and
   #657's first step. #657 itself stays open — the badge change is a suspect removed, not a proven
   fix, and B-1 still owes the device backtrace.
2. **B-2** (#777) — the one user-visible data bug.
3. **F-1** (#784), two sessions — the highest-value feature; everything it needs is measured.
4. **F-2** (#752 tail) — closes #752 outright.
5. **F-4** (#645) — closes #645.
6. **F-3 design ½-session** (#775 shape), then **F-3 build**.
7. **F-5 + I-3(volume-sources)** (#733 + one GeneratorKit migration in the same regen).
8. Then F-6…F-11 / I-1 / I-2 by appetite — each is standalone.

**Owner lane, parallel:** B-1 device backtrace (with QW-2 on a build) · O-1 keyed call + harvest ·
O-3 joint decision · O-6 send the ask · O-2 / O-4 / O-5 design sittings as convenient · O-7 when
N-5 PR 2 is cut.

**N-lane interaction:** #353's decimal-class slice (N-1) remains the single largest reachable data
win in the backlog (59,132 documents would gain an archival neighbour) and stays scheduled in the
consolidated plan — nothing in this plan blocks it, and F-1 shares its eval-harness discipline.

## 5. Maintenance

- When an item ships, close its issue with the evidence comment pattern used in the 2026-08-09
  sweep (what landed, where verified, what — if anything — was deliberately not done).
- When an owner decision in Tier 4 resolves, move the freed work into Tier 2 by editing this file —
  do not fork a successor document.
- If a future sweep finds this plan asserting a state the tree has left behind, fix this file in
  the same PR — the #651 rule.
