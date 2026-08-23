# Plan of Record — 2026-08-17, after the build-42 TestFlight release

**Status:** the single live plan. Written by consolidating every open planning document and all 36
open issues against the tree at `build-42`/`d7534884` (plus #950, filed after tagging), verifying
claims against code and issue audit trails rather than against document status lines. Seventeen
planning documents were archived to `Planning/Completed/` in the same commit; §8 records where each
one's live residue went, so nothing was dropped by the move.

**The triage rule this plan applies, set by the owner:** known bugs first, then features that are
only partially shipped. New feature work comes after both.

**How to keep this current:** when a session ships, strike its row in §7 and update the issue.
When this document's sequencing is overtaken, replace it the way it replaced its predecessors —
one document, with a disposition table.

---

## 1. Where the build stands

Build **42** (v0.2) is on TestFlight for both platforms, tagged `build-42`. Tester feedback is
incoming and may re-order everything below — particularly on the semantic map, whose
leads-or-noise question the notes ask directly. `identifiersAwaitingDeploy` is empty; Production
CloudKit is deployed through build 40. A full re-index runs on testers' first launch
(`currentDateIndexVersion` 36 → 40).

Three big programs closed or paused in good order: the Cross-Platform UI Adversarial Review shipped
waves 1–3 plus the F-2/M-2/M-4/M-9/P-3/P-8 slate (#889–#924); the semantic program shipped V-0…V-4
at 512 dims with V-5 assessed and deliberately not built
(`semantic-vectors/V5-Query-Encoder-Assessment.md`); Archival Analytics shipped #825–#829 and
#832–#838 down to narrow, audited remainders (§3.1).

**Since this plan was written — the browse-axes program (#1051), complete.** By owner direction,
2026-08-22/23: feasibility survey and design requirements (PR #1053), the development plan
(#1059), then sessions B-1…B-7 (PRs #1060, #1064–#1069) plus the #1070 keyboard-trap regression
fix (#1071). The Browse root is now search-first (design 2a) with eight axes beside the classic
hierarchy — All Volumes, Administrations, Editors, Archives, Clusters, My Scopes, Working
Corpora, and the Topic Index (#1023) beside People — twinned into the macOS Corpus Browser's
sidebar. Along the way it retired two of this plan's Tier-1 items (§2 B-3: #862 was verified
already fixed; #861's class got two more adoptions plus the banner-occlusion fix) and settled
one open question the hard way: **the B-7 semantic-clusters gate was inverted by the owner** —
rather than waiting on the build-42 leads-or-noise verdict, the browsable cluster list shipped
as the *instrument* for it, and the TestFlight What-to-Test files (items 11–12) now put the
question to testers against cluster membership directly. If the verdict demotes the map, removing
the Clusters tile is one clean commit. The program plan and design docs are archived in
`Completed/` (`Browse-Axes-Development-Plan.md`, `Browse-Axes-Design-Requirements.md`,
`browse-axes-design/`); deferred-with-obligations items (collection-lens doc counts, class
browsing, era grouping on the Archives axis) are recorded in the plan's B-5 section, not lost.

## 2. Tier 1 — known bugs

### B-1 · iPad stability pair — #950, #657 *(owner evidence first)*
**#950** (window resizing can crash) is a bare title filed 2026-08-17 — no body, no backtrace.
**#657** (app killed rebuilding the floating tab bar; empty-string tab badge is the prime suspect)
has waited on a device backtrace since 2026-08-01. Both are iPad scene/tab-bar lifecycle, and
**#752's one structural gap lives in the same code** — nothing calls
`requestSceneSessionActivation`, pinned by `WindowTargetingTests.swift:219`. One session, three
issues, after the owner supplies: a #950 repro (what was resized, split view or Stage Manager, and
the crash log from Settings ▸ Privacy ▸ Analytics) and the #657 backtrace if it recurs on build 42.

### B-2 · The index-content batch — #888 (+ #279's index half if its design lands)
**#888** — header extraction leaks source notes into indexed titles (X-2's root cause). Display-time
repair shipped in Wave 1 (`DocumentHeaderDisplay.trimmedHeader`); the stored header is still
polluted, reaching citations, window titles and exports. The fix is at extraction time and **costs
an index-version bump and a full re-index**, which is precisely why it must be batched: any other
pending index-content change rides the same bump or waits for the next one. Candidates to batch:
#279's per-document classification override (index plumbing half — needs O-4's short design first)
and anything tester feedback surfaces. **Rule: one bump per wave of index-content changes, never
one per change.** Build 42 just forced a re-index; the next bump should be worth its cost.

### ~~B-3 · iOS input residuals — #861, #862~~ — DONE (both issues closed)
#928 shipped the app's first keyboard-dismissal affordance and fixed part of both. The residuals
closed during the browse-axes program: **#862**'s scope-save defect was verified already fixed
(`ScopeEditorTarget`, confirmed rather than re-diagnosed in #1051 B-3, PR #1065), and the #861
class was extended by #1070/#1071 — the Browse root search and the Browse scope editor's name
field adopted the bar, and the **cross-cutting occlusion** was fixed: the bottom-inset
sync/indexing banner floated onto the keyboard's accessory row, leaving every #861 Done bar
under a tab root present but unhittable whenever the banner showed. The banner now yields while
the keyboard is up (`MainTabView` 1.15).

### B-4 · Lot-grammar correctness — #809 *(runs inside the S-5 grammar cluster, §4.1)*
`SourceNoteKit`'s shared grammar cannot see a 4-digit lot prefix (`Lot 2015D608`), so those notes
misparse everywhere the grammar is used. A data-correctness bug, scheduled with the cluster that
owns the file rather than alone.

### B-5 · Side-loaded volume residuals — #777
The browse half shipped (#800/#801). Remaining, from the plan-of-record audit: no on-screen
side-loaded label in Browse, the "553 of 552" denominator, and the user-manual coverage.

## 3. Tier 2 — partially-shipped features, finished

### 3.1 Archival Analytics: the audited narrow set *(one session, common files)*
Every item below already carries a precise audit comment on its issue; this is execution, not
investigation. The files are shared — `ArchivalAnalyticsView.swift`, `FRUSTheme.swift`'s popover
copy, `ArchivalCopyRulesTests.swift` — which is why these ship together:

- **#825 (1):** class rows' per-volume usage — `documentsByVolume(forClassKey:)` is decoded and
  unread by any surface; owner confirmed it stays in scope.
- **#825 (2):** the sector-group card's "List These N Collections", deferred by PR #845 with no
  follow-on filed. Build it with the uncapped-list treatment #825(c) established, or record the
  drop on the issue — this plan's default is **build it**.
- **#832 (a):** the 35 concatenated authority names — deferred, not dropped.
- **#838 (1):** the ⓘ consolidation covers one mode of four; Your Library and Flows still render
  on-page blocks the handoff moved to the popover.
- **#838 (3):** copy rule 4 leaks twice, once in this issue's own output — `FRUSTheme.swift:236`
  is outside the scan list of the test written to catch it, and "neighbourhood" is not on the
  banned-word list. Fix the strings, widen the test.
- **#829 rider:** the weights popover must be honest against the **fallback** view — the pointers
  weight drops 3,428 of 4,423 records against Volumes, and the shipped copy does not say so.
- **#838 (2) and (4)** are one-sentence owner decisions (§5).

### 3.2 Semantic storage loose ends — from #926's shipped wave
Two items recorded in PR prose and nowhere else until now: the **storage hero's usage bar
double-counts** shard bytes, and **shards are orphaned on three teardown paths** (volume removal
routes that skip the shard directory). Small, same files (`SemanticShardStore`, the storage hubs).

### 3.3 EditableContent completion
`Docs/EditableContent.md` §13 shipped with its header naming the gap: **about twenty short strings**
from the build-42 plain-language pass (storage-hub reindex controls, person/term popovers, the
Collections search-unavailable notice, the Zotero rate-limit error) have no blocks yet.

### 3.4 R-2b — the research-trail schema retirement *(owner-paired)*
The one live item of Wave R: retire `ResearchSession`/`ResearchTrailMigration`, 19 record types →
17, with its own Production deploy through the R-7 checklist. Spec: `Completed/`
`Wave-R-Research-Trail-2026-08.md` §R-2b (the only specification — the archive move does not
change that). **Deploy batching:** if O-4 (#279) and O-5 (#266) proceed, their schema *additions*
and R-2b's *removals* should share one Dashboard promotion; do not hold R-2b hostage to those
decisions past one more build.

### 3.5 Accessibility and infra debt, code halves
- **#268:** `axChartDescriptor` is adopted at exactly two sites; four chart families remain. The
  owner VoiceOver pass (§5) validates after adoption, not before.
- **#270:** four generators still off `GeneratorKit` (Manifest, Taxonomy, CentralFilesIndex,
  SourceProvenanceIndex).
- **#312:** `UIObstructionTests` — #272's detail column only partially gated. Unstarted.

### 3.6 Collection export parity — #960 *(added 2026-08-18, owner evidence)*
The in-app preview **is** `CollectionItemHTMLRenderer` (`CollectionPreviewView.swift:450`), so HTML
matches by construction — but PDF and DOCX are independent re-implementations with no parity test,
and the owner's build-43 export set shows the drift: DOCX silently drops the word cloud (the option
is never read) and ships an un-refreshed TOC field; PDF wastes a blank page 18 and embeds the
share-card image with app chrome. Two further defects are **shared by every format and the preview
itself** — the `Source: Source:` doubling on post-1969 notes (fix once at a shared point, not three
times) and a mangled `foldered material],` row in Sources & Archives that belongs to #353 (S-5).
The session's first deliverable is the parity harness, which turns the rest into red tests.

## 4. The combination clusters — where one session serves several needs

### 4.1 S-5 · The source-note grammar cluster — #353, #809, ~~#372~~, #733 + #808, #681
All five live in `SourceNoteKit`/the lot pipeline, and three separately touch
`central-files-index.json`'s consumers:
- **#353** — recover ~1,850 unrecognized notes + the three strategy-steal classes (the parser
  session, long-planned).
- **#809** — the 4-digit lot prefix (B-4). Fixing it *inside* #353's session costs nearly nothing;
  alone it still pays the full parity-test toll.
- ~~**#372**~~ — **DONE 2026-08-19.** PRs 1 and 2 had already shipped when this plan was written
  (the repoint and the 758 → 7 lot fold); O-7's cross-RG supplement landed as a table in
  951512a6. Item 1 closed the loop on 2026-08-19: `FOLD_VOLUME_SOURCES` moved the last 7 orphans
  into `central-files-index.json` (971 → 978), volume-sources regenerated to `lots: {}`, and
  Source Explorer's two direct `lotFile(forRawLot:)` call sites now answer them with no repoint.
- **#733 + #808** — CIA Job numbers: front-matter key recognition shipped partially; the
  archival-neighbour path exists on neither side.
- **#681** — acceptance-test coverage for the presidential-library and NARA-collection routes
  (26.8% today); the keyed v2 verification call is O-1's owner half.
Grammar changes ripple into bundled artifacts — if any regeneration is needed, it slots into the
B-2 batch discipline (bundle refreshes are cheap; index bumps are not).

### 4.2 The scene/window cluster — #950, #657, #752, #824, and #751's decision
B-1 is the bug half. **#824** (macOS Window-menu cleanup: 17 entries, two of which are not
windows) is the same mental model on the other platform — cheap to ride along once someone is in
the scene plumbing. **#824 shipped** 2026-08-19 (PR #993). **O-3 is settled** (2026-08-19,
recorded in `iOS-Reading-Journey-Design.md` §3b): Project Home reads in-sheet, and **Research and
History keep handing off to Browse as the settled rule** — so #751's remaining restructure is
closed as decided-against rather than deferred, and the `[ResearchSidebarItem]` projection that
#238/#272 protect is left alone.

### 4.3 The subjects cluster — #308, #261, and the V-5 instrument
Three consumers of one upstream decision. `308-Subject-Integration-Design.md` is written and
reviewed; #261 gates document-level regeneration; and the V-5 assessment needs an evaluation
instrument whose positives are independent of lexical overlap — which the current ~97%
string-match tags cannot be (`V5-Query-Encoder-Assessment.md` §3). O-6 (send the #261 upstream
ask) is the unblocked first move and costs an email.

### 4.4 The archival data follow-ons — #837 (#831 measured and closed; #834 stays deferred)
**#831 is closed by measurement, 2026-08-19** — its own measure-first clause, exercised. Both of
its questions were answered against the corpus and both came back negative for a surface:

- **The mixed (collection↔class) axis is real but concentrated.** 1,886 references over 686 pairs
  (2.7/pair, better than the 1.7 that made #764 ship the class axis as measurement-only) — but the
  top five cells are **30.3%** and reduce to *two* editorial situations (the 1945 Potsdam volumes
  between Truman's PSF and 740.00119; one 1952–54 conference volume between Lot 60 D 627 and
  396.1-BE). Strip those five and the rest is 1.9/pair — the rejected number, within noise.
- **Banding does not survive the class axis.** Per band, class references between units run
  204 / 3,443 / 922 / 103 / **0** — the last band is empty, not thin, because the `dN` idiom
  postdates 1945 while decimal classes end in 1963. Collections band cleanly (3.9–6.5/pair in the
  three middle bands), but **Through 1947 — 261 of 552 volumes — yields 276 references over 56
  pairs**, so a chip would offer half the series and return almost nothing.

Shipped instead: one sentence in the Flows caveat naming the two concentrations, and
`MEASURE=1 swift run ProvenanceFlowIndexGenerator` as the reproducible instrument. **No schema
bump**, so `provenance-flow-index.json` stays at schema 1.

**#837** (the graph's unprinted-citations layer) is unstarted and is now unblocked rather than
waiting: it was sequenced after #831 so it would draw era-keyed data, and there is no era keying
to wait for. **#834** (the decimal channel) stays deferred by design — the pre-war reach, waiting
on the file-number grammar (#965's territory).

### 4.5 The schema-deploy batch — O-4 (#279), O-5 (#266), R-2b
Each alone costs a CloudKit Production promotion (#488 is what happens when one is skipped).
Together they cost one. O-4 and O-5 need short designs first; R-2b is fully specified. §3.4's
rule: batch if the timing aligns within a build, do not hold R-2b indefinitely.

## 5. The owner lane — nothing here is a coding session

| Item | What it is | Blocks |
|---|---|---|
| #950 repro + crash log | resize context, Stage Manager or split view, Analytics log | B-1 |
| #657 backtrace (if it recurs on 42) | device backtrace | B-1 |
| ~~O-3 · #751/#553 leads-list decision~~ | **SETTLED 2026-08-19** — Project Home reads in-sheet (#553); Research/History keep handing off (#751). See `iOS-Reading-Journey-Design.md` §3b | — |
| O-6 · #261 upstream ask | send the email; the ask text is drafted in the issue | 4.3 |
| O-1 · #681 keyed v2 call | one API call to confirm `collectionIdentifier` on v2 | 4.1's test coverage |
| O-2 · #626 design decision | what "wider than headnotes" means | backlog |
| O-4 · #279 design | reversible per-document override; schema field → 4.5 batch | B-2 rider |
| O-5 · #266 design | freshness anchor that survives reindex; schema field → 4.5 batch | backlog |
| ~~O-7 · #372 record-group guard~~ | **SETTLED** — the 13 cross-RG lots admitted as a table, not a rule (951512a6) | — |
| #838 (2) + (4) | two one-sentence ratifications (the 1d exception; the iPhone layout answer) | 3.1 |
| #830 T-0 fact table | confirm the repository-fact table item by item before T-0 builds | trip packet |
| R-2b deploy | Dashboard promotion, 19 → 17 | 3.4 |
| VoiceOver pass | after #268's adoption; Audio Graph on a real screen reader | 3.5 |
| #106 + CW-11 screenshots | the checklist exists; the UI has now settled at build 42 | docs |

## 6. Deferred, each with its reason written down

- **V-5 / free-text semantic search** — assessed 2026-08-16; do not build next. The sequence when
  resumed: `CSUserQuery` `textContent` first, then the honest instrument, then PRF, V-5 last
  (`semantic-vectors/V5-Query-Encoder-Assessment.md` §6).
- **OS-27 adoption** — design sketch only; nothing exercised against the beta SDK.
- **#834 decimal channel** — waits on the deferred file-number grammar; measured, not forgotten.
- **#234 M2/M3 early-era people** — deferred and *live*; `People-Early-Era-Program.md` §5's M2a
  gate (keyed sample) still unmet. #235's simplification rides whenever NARA lookup is next open.
- **Pre-1910 central files** — rate limit granted, harvest unblocked, owner-run
  (`BigPicture-Pre1910-CentralFiles.md` + reference data).
- **#830 research trip packet** — owner-gated at T-0 (§5).
- **Backlog ideas folded from archived docs, none scheduled:** lexical-similarity *as a query*
  (Lexical assessment §0 verdict); the hosted quick-start index (PreIndex 2026-05 — note the
  semantic shard repo has since proven the hosting channel); BigPicture-Analytics postponed
  priorities 8/10/11/12; Feature-Priorities §5's unplanned capabilities (5a.1 declassification-gap
  explorer, 5a.3 previously-published resolver, 5b.5 telegram threads — verify against the tree
  before scoping, that document mispredicted twice); Restoration-Depth §B/§C (M-21's deferred
  mechanisms — recorded only in the archived doc); Q&CA's dispersion statistic
  (`occurrencesPerDocument`, built, zero callers); the Q&CA wave repo marker (verify owed, close).
- **Cross-platform port** — strategic reference only (archived); revisit on demand.

## 7. Session sequence

| # | Session | Issues | Gate |
|---|---|---|---|
| S-1 | iPad stability + scene plumbing | #950, #657, #752, ride: #824 | owner evidence (§5) |
| S-2 | Index-content batch | #888, rider: #279 index half | O-4 design optional; else #888 alone |
| ~~S-3~~ | ~~iOS input finish~~ **DONE** — #862 verified fixed (#1051 B-3); #861 class extended + banner occlusion fixed (#1070/#1071) | ~~#861, #862 residuals~~ closed | — |
| S-4 | Archival narrow set | #825(1,2), #832(a), #838(1,3), #829 rider | #838(2,4) sentences help, don't block |
| S-5 | Source-note grammar cluster | #353, #809, ~~#372~~ (done), #733/#808, #681 tests | O-1 for the tail items |
| S-5b | Collection export parity | #960: harness first, then DOCX cloud/TOC, PDF pagination, shared Source: fix | #960 item 6 rides S-5; RIS/BibTeX titles ride #888 |
| S-6 | Storage + content loose ends | #926 items 2–3, EditableContent §13 gap, #777 residuals | none |
| S-7 | Infra debt | #270 ×4, #268 ×4, #312 | none |
| S-8 | R-2b retirement | schema 19 → 17 | owner deploy (§5, batch per 4.5) |
| S-9+ | Archival follow-ons, subjects scaffolding, backlog | #831 → #837; #308 scaffolding | tester feedback may pre-empt |

Tester feedback on build 42 outranks this order when it lands.

**Shipped outside this table, by owner direction (2026-08-22/23):** the browse-axes program —
#1051 B-1…B-7 plus the #1070 regression (PRs #1053, #1059, #1060, #1064–#1069, #1071) and the
Topic Index (#1023) — see §1's "Since this plan was written" paragraph. It also discharged S-3
above. The next build carries the clusters leads-or-noise items in its What-to-Test notes, so
the tester-feedback gate this table already defers to now has its instrument.

## 8. Planning-document disposition

**Stays live** (each is a spec, a live design, a runbook, or the tracker for open work):
`DEVELOPMENT-PLAN.md` (session log) · `FRUS-Explorer-Specification.md` (spec) · **this document** ·
`308-Subject-Integration-Design.md` (#308/#261) · `iOS-Reading-Journey-Design.md` (#751/O-3) ·
`People-Early-Era-Program.md` (#234) · `Vector-Embeddings-Semantic-Design.md`,
`OS27-Semantic-Retrieval-Design.md`, `semantic-vectors/` (live program + verdicts) ·
`Archival-Analytics-Adversarial-Review.md` (tracker for #825/#830–#838 remainders) ·
`Archival-Analytics-Revision-Design-Handoff/` (artboards cited by #830/#831) ·
`Research-Trip-Packet-Scope.md` (#830) · `Navigation-State-Audit-2026-08.md` (evidence of record
for M-16/M-17b on #751) · `Wave-R-Research-Trail-2026-08.md` (R-2b's only spec) ·
`Cross-Platform-UI-Adversarial-Review/` (live workstream; STATUS.md's owed list is folded into §5)
· runbooks: `352-lot-resolution-runbook.md`, `nara-record-group-catalog-runbook.md`,
`BigPicture-Pre1910-CentralFiles.md` + `Pre1910-CentralFiles-Reference-Data.md` ·
`M2-Semantic-Pipeline-Ride-Along.md` (its seam rules bind any M2 resumption).

**Archived to `Planning/Completed/` in this commit**, residue folded above:

| Document | Why | Residue went to |
|---|---|---|
| `Consolidated-Development-Plan-2026-08.md` | its waves shipped; sequencing superseded twice over | §5 O-lane, §3.4 |
| `Resolve-Open-Issues-Plan-2026-08.md` | tiers 0–2 shipped; declared itself substantially discharged | §2, §3.5, §5 |
| `Eight-Issue-Plan-2026-08.md` | says "superseded" in its own header; only #626 held | §5 O-2 |
| `Feature-Priorities-Review-2026-08.md` | partly discharged; twice overtaken by events | §6 backlog |
| `Query-And-Corpus-Analysis-Session-Plan.md` + `QCA-Design-Handoff-Assessment.md` + `QCA-Projects-Integration-Assessment.md` | wave complete (schema deployed) | §6 (dispersion, marker) |
| `Restoration-Depth-Design.md` | shipped as scoped, #754 closed | §6 (B/C pointer) |
| `Lexical-Similarity-Neighbors-Assessment.md` | withdrawn-as-artifact verdict is final | §6 backlog |
| `Archival-Pool-Depth-Measurement.md` | measurement of record for closed #645 | — |
| `BigPicture-Analytics-CorpusVsSeries.md` | blueprint executed or postponed | §6 backlog |
| `PreIndex-Feasibility.md` | 2026-05 idea, never scheduled | §6 backlog |
| `Cross-Platform-Porting-Assessment.md` | strategic reference, no work rides it | §6 |
| `Dynamic-Type-Worklist.md` | the pass completed; remaining sites are decided-fixed | — |
| `Archival-Analytics-Feasibility.md` + `Archival-Analytics-Design-Handoff.md` | the feature shipped; open remainders live on the Adversarial Review's tracker | §3.1 |

The archive preserves every file readable and indexed in `Completed/README.md`; pointers into
`Completed/` are stable. Nothing was edited in the move.
