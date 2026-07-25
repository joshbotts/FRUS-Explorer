# Consolidated Development Plan — August 2026

**Date:** 2026-07-25 · **Inputs:** (1) the Settings North Star design handoff
(`design_handoff_settings_northstar/`, dated 2026-07-24, all 10 panes settled); (2)
`Planning/Query-And-Corpus-Analysis-Session-Plan.md` (13 sessions, 5 milestones, dated
2026-07-24); (3) the seven open NARA Catalog issues (#235, #354, #355, #372, #375, #376,
#405) plus the parser session #353 they depend on.

**Where this picks up.** The analytics design program is complete and merged: quick-win
Waves A–C, D1 compare terms (#470–#473), and D3 research-grade export (#474–#479). The
research-rail program is complete; `ResearchStripView` no longer exists (four stale
doc-comment mentions remain — swept in S-0). Those completions moot parts of #368; see
the issue-disposition table at the end.

Three workstreams, deliberately independent lanes: **S** (Settings North Star), **Q**
(Query & Corpus Analysis), **N** (NARA Catalog). Any lane can pause without blocking the
others; the only hard cross-lane edges are called out in *Sequencing*.

House rules that bind every session below: implementer ≠ reviewer; UI PRs carry a
visual-review checklist (owner verifies on device); `build-for-testing` before claiming
green; dual settings surfaces are **parallel** — every settings change edits
`SettingsView.swift` *and* `FRUSSettingsView.swift` until the shared-model work lands
(that duplication is precisely what S-1 begins retiring); `CATALOG_API_KEY` is
owner-held — keyed generator runs are owner-executed, never Claude-executed.

---

## Workstream S — Settings North Star

**Source of truth:** `design_handoff_settings_northstar/README.md` + `Settings
Review.dc.html` (options `1a`–`11b`) + `screenshots/` (panes 01–08 predate the 9b/10a
System-group consolidation; the final 1c tree wins). Final IA: **17 destinations → 13
rows in 4 groups** (Library · Research · Reading & Search · System).

### The handoff's five open engineering questions — dispositions

| # | Question | Disposition |
|---|---|---|
| 1 | NARA key: iCloud Keychain (iOS copy) vs device-local (macOS copy)? | **Resolved from code (2026-07-25).** `NARAAPIKeyStore.storeKey` sets `kSecAttrSynchronizable = true` on add **and** migrates pre-existing items in place on the next save (`NARAAPIKeyStore.swift:74–93`). The key syncs via iCloud Keychain. **iOS copy wins; fix the macOS sentence in S-0.** |
| 2 | Search scope toggles: what happens when all three are off? | **Resolved from code (2026-07-25).** All three off → both MATCH expressions are `nil` → `makeMatchExpressions` **throws `FTS5Error.emptyQuery`** (`SearchService.swift:193–208`). Today that surfaces as a search failure, not as honest empty results — the handoff's last-toggle-can't-turn-off guard is the right fix, and the guard footer can say why truthfully. Implement in S-0. |
| 3 | What's New release-notes source | **Owner decision, deferred to S-5 (About).** Options: bundled markdown per release (offline, versioned with the build — recommended, matches the no-network posture) vs GitHub releases fetch. Until decided, About ships with the version row and no What's New screen. |
| 4 | Free Up Space on iOS: reuse `ManageStorageSheet` logic? | **Yes — planned as-is.** Same candidate logic and `indexOverheadFactor` estimates; S-2 ports the flow with the identical protection rules. Divergence would create a second storage-accounting model to keep honest. |
| 5 | Live previews: cheap data sources? | **Confirmed cheap.** Word Cloud sample = most-recent disk-cached cloud (`WordCloudDiskCache`), fallback to a canned term list; Display prose = canned paragraph (no index dependency); Search snippet = canned query over a bundled sample string. None may touch the index at settings-open time. |

### Sessions

Order follows the handoff's own sequencing; each session is one PR unless noted.

**S-0 — Wording & parity pass (no model, no moves)** *(Effort S)*
Titles ("Summarization", "Search", "Tags", "NARA API"), footers-over-fake-rows, one
get-key URL, macOS detail lines → iOS, "Both" → "Documents & Editorial Notes", Legal
merge prep copy, no-ellipsis-on-nav-links sweep. Plus, from the dispositions above: the
macOS NARA key sentence corrected to iCloud Keychain, and the **last-scope-toggle guard**
with its footer (the one behavioural change in this session — small, self-contained,
kills a live error path). Also sweep the four stale `ResearchStripView` doc-comment
references (`SupportingViews.swift:20,27`, `MacDocumentView.swift:47,116`). Both
platforms in one PR; every string change lands in `Docs/EditableContent.md` in the same
commit.

**S-1 — Shared `SettingsPane` model + 1c regroup** *(Effort M)*
Extend the macOS `SettingsPane` enum (`FRUSSettingsView.swift`) into the one declarative
`[SettingsPane]` model (id · label · icon · group · keywords · platforms · destination)
and drive **both** renderers from it. Adopt the four 1c groups on both platforms —
renames and moves only, zero pane rewrites. iOS keeps `.searchable` (QW-03); the model's
`keywords` feed it. This is the session that ends name/grouping drift; after it, the
dual-settings memory rule relaxes from "edit both views" to "edit the model + at most
two renderers."

**S-2 — Volumes & Storage hub** *(Effort L — the anchor)*
Panes 02+03 merged per 3a+4a: HeroCard (usage bar · "N of M downloaded · indexed" ·
Reindex) → Add Volumes (GitHub browse behind one door; the 540-row browse leaves the
form for a pushed screen) → Downloaded → Needs Attention (pinned when interrupted) →
Keeping Current → **Free Up Space on iOS** (ManageStorageSheet port, same protection
rules) → Rebuild Search Index (footer: "Notes, highlights and tags are never affected.")
→ Settings → Advanced. Word-cloud precompute moves out (to Word Cloud pane);
backup note becomes a footer. Retires three root rows. New shared components introduced
here: HeroCard, StatusRow, NavRow with detail. Consider splitting iOS/macOS into two PRs
if the diff exceeds review appetite.

**S-3 — List grammar (pane 04) + Summarization run-sheet (pane 01)** *(Effort M)*
One grammar: row → editor with visible rename/merge/delete; swipes as shortcuts only;
"New …" row ends every list; counts on rows; Active Project + Project Home pinned;
"User Tags" → "Tags"; macOS symbol-swap radios → picker. Summarization pane keeps one
job (prompts); the batch-run form (6 scope types, prompt picker, concurrency, progress,
iOS background toggle) becomes **one focused sheet shared by both platforms**;
start-disabled reasons surface as sheet footers.

**S-4 — Connections (9b) + Data & Recovery (10a)** *(Effort M)*
One **Connections** destination (NARA Catalog · Zotero): per-service card (status at a
glance + Manage), each opening the 9a editor anatomy (status → About → Account with
usage · Replace Key… · Remove). One **Data & Recovery** door: Export (rows carry
counts; "Obsidian-compatible") → Reports (Broken Cross-References gets its own screen)
→ Diagnostics (Sync Log summarized: "Last event 12:04 · no errors today") → the
labeled what-survives recovery ladder ("Fix iCloud Sync — nothing is deleted" / "Reset
This Device — volumes & index only" / "Erase Everything… — own screen, two
confirmations"). Summarization Probe behind a developer flag. Retires five root rows.

**S-5 — macOS `Form(.grouped)` conversions + About parity** *(Effort M, mechanical)*
Convert the hand-rolled `ScrollView`/`PaneHeader` panes (Display, Search,
Projects/Tags/Scopes, Summarization, Storage, Add Volumes, NARA, Data, Sync
Diagnostics, Reset, About) to the native form idiom the Word Cloud and Zotero panes
already use; ship the shared About Form (version + What's New per Q3 decision →
two-line FRUS summary → Resources with the Research Guide rehomed → Attribution →
Legal + Full Notices). Word Cloud pane picks up its 6a bench items (live sample row,
"Keeps N of M terms" line, single stop-list editor, precompute under Performance) —
coordinate with Q-lane S-1 keyness if that lands first (both touch
`WordCloudSettingsView`; trivial merge either order).

**S-6 — Docs & closeout** *(Effort S)*
One consolidated docs pass for the whole workstream (both manuals' Settings chapters are
restructured wholesale — do it once, not per-session), `EditableContent.md` full
re-sync, screenshot-checklist rows, TestFlight notes. Close #368's settings bullet by
reference.

**Standing risks for S:** every session touches both platforms' parallel views until
S-1 lands (edit both!); `CodingStandardsAuditTests` version-history allowlist may name
settings files (check per session); Settings is the app's most memory-documented
regression surface (`swiftui_codable_rawrepresentable_recursion`,
`dual_settings_views`) — re-read those memories at S-1 and S-2 start.

---

## Workstream Q — Query & Corpus Analysis

**Source of truth:** `Planning/Query-And-Corpus-Analysis-Session-Plan.md` — 13 sessions
in 5 milestones, each already specified to house convention (goal, file-anchored
deliverables, decision points, verification oracle). This plan does not restate them; it
sequences them and pins the cross-lane edges.

**Adopted order** (the session plan's own recommendation, unchanged):

| Block | Sessions | Stop-point property |
|---|---|---|
| Q-M1 | Q-1 NEAR → Q-2 Query Inspector → Q-3 fts5vocab/exact-word | Shippable alone; **no index migration**; fixes the live silent-stemming hazard |
| Q-M2 | R-1 facets → R-2 normalised/comparative → R-3 KWIC | The result set becomes an object |
| Q-M3 | S-1 keyness → S-2 collocation | Signal locators |
| Q-M4 | M-1 working corpus → M-2 query log → M-3 excerpt verification | Method & reproducibility (M-3 can drop in anywhere) |
| Q-M5 | D-1 vocabulary explorer → D-2 coding assist | Discovery (lowest confidence) |

**Cross-lane edges (the only ones):**

1. **Design before build for the four design-heavy sessions.** Q-2 (inspector), R-1
   (facet panel), R-3 (concordance), M-2 (query log/appendix) get their UI from the
   Claude Design pass this plan commissions (see companion requirements doc). **Q-1
   needs no design** — it is parser + syntax-table work — so the lane starts immediately
   while design runs in parallel. Design returning before R-1 implementation is the
   schedule-critical hand-back.
2. **M-1's settings surface lands in the new IA.** The working-corpus manager homes in
   Settings → Research beside Volume Scopes. Schedule M-1 **after S-1** (the regroup) so
   it is born into the 1c tree and the shared pane model, not re-homed later. M-1's
   editor should reuse S-3's list-grammar components (row → editor, counts on rows) —
   another reason S-3 precedes it.
3. **Q-M3's keyness mode** rides the existing word cloud; if S-5 has already rebuilt
   `WordCloudSettingsView` to the 6a bench, the keyness toggle documents itself via the
   bench's consequence line. Either order compiles; S-5-first reads better.
4. **Corpus prerequisite:** before Q-M2, index a substantial slice on the Mac (the
   verification oracles assume it — R-1's procurement-report facet check, R-2's Article
   43/51 crossover). This is owner wall-clock, not engineering time; start the index
   while Q-M1 is in review.

**Verification discipline carried over:** the two source reports are the test oracle
(`NEAR("military guarantee" Europe, 30)` → 0/0/0/3 across 1945–48; Article 43: 42/29/26/8
against Article 51: 10/28/32/18; the OSP within-corpus counts 9/8/0). A mismatch is a
finding about indexed scope, not a test to relax.

---

## Workstream N — NARA Catalog

Tiered by who executes and what unblocks what. The keyed runs are minutes of owner time
each; the engineering sessions are normal PRs.

**N-0 — Keyed data runs (owner-executed, ~10 min total, any time):**
- **#376** — keyed `VolumeSourcesIndexGenerator` regen: drops the 9 remaining fileUnit
  lot entries (58D528 … 92D252), reads the warm `.cache/volume-sources/rgs` cache (0 new
  RG queries). Confirm record-groups stays at **31** afterward. Then optional offline
  `CollectionAuthorityGenerator` re-run + export re-baseline.
- No other keyed run is currently actionable (#375's keyed pass was already tried and
  resolved 2 of 573 — that route is closed; see N-3).

**N-1 — #353 SourceNoteParser session** *(Effort L; the biggest coverage lever)*
~1,850 recoveries across seven verified rule families + the three strategy-steal fixes
(§3.2 library-keyword-anywhere, §3.3 mSupp abstract prefixes, §3.5 secondary-clause lot
steal) + the 36,063-record decimalClass derived-field fix. Every change guarded by the
`SourceNoteEval` harness against `eval-baseline.txt`; after landing, re-run
`SourceExplorerExportGenerator` and adopt the new baseline. **Sequenced before N-2** so
the routing work tests against post-parser classifications once, not twice.

**N-2 — #354 Source Explorer routing pack** *(Effort M–L)*
Five independent items; split into two PRs if needed:
(a) namedFileSeries: catalog keyword live route + personal-papers repository table +
static seriesName→RG map (~939 records offline through already-bundled RG NAIDs) +
txt:→lot: cluster bridge (162 unambiguous);
(b) CFPF tiers: per-document AAD/catalog deep links for the 1,361 D-reel ids ≤1979,
static guidance elsewhere;
(c) RG-256: one bundled record resolves all 1,547 Paris Peace citations offline;
(d) manuscript repositories (~1,502): split into a strategy with static finding-aid
guidance naming the actual repository — **stops issuing a NARA query guaranteed to
miss** (a small design-copy dependency: the guidance card's wording/shape is in the
design brief as an optional item);
(e) numerical-format gate in `CentralFilesIndex.caseNumber(fromFileNumber:)` (334
records; covers both platform call sites).

**N-3 — #375 curated lot NAIDs (owner + Claude)** *(Effort S)*
The control-number route is closed (2 of 573). Owner hand-curates NAIDs for the top ~10
lots (54D270/Marshall Mission = 1,063 records, M-88/CFM = 697, … — 54% of the gap) from
`Planning/source-explorer-export/missed-lots-ranked.tsv`; Claude adds the curated
`lot → NAID` override the generator reads (same pattern as the presidential-library
curation) and re-baselines. Cheap, high-yield, no API dependency.

**N-4 — #355 presidential-library curated NAIDs** *(Effort M; **verify blocker first**)*
~20 curated (library, collection) → NAID entries covering ~66% of the 29k-record
presidentialLibrary bucket. The issue marks this **blocked on §3.7 domain tagging** from
the bundle-hygiene work — confirm whether #351 delivered §3.7 before scheduling;
repository-blind matching would multiply wrong links. Includes neighbor-key
normalization ("NSF" variants, "Dulles papers" casing).

**N-5 — #372 lot-map consolidation** *(Effort M, architectural)*
After N-0's regen: fold volume-sources' surviving lots into central-files at generation
(skipping fileUnit-level entries), repoint `VolumeSourcesView:282` and
`CollectionContentResolver:1275` to `CentralFilesIndexStore.lotFile(forRawLot:)`, drop
the `lots` map from the volume-sources artifact — **keeping** `resolution()`'s
record-group arm, which central-files does not carry. Ends the two-parallel-maps risk
(`project_source_explorer_bundle_propagation`).

**N-6 — #235 Simplify NARA Lookup** *(Effort M, app UI)*
Selection → extended-context analysis (look-behind/look-ahead) through the existing
`SourceNoteParser` grammar → candidate resolutions, with today's manual interface as
fallback. **Scope from scratch** — the `NARALookupContext`/`SelectionResolutionAnalyzer`
described in older plan docs was never built (`project_nara_analyzer_unbuilt`). A
candidate-picker card is in the design brief as an optional surface. Natural slot: after
N-1 (parser rules are what the analyzer runs).

**Parked:** #405 (creator-org similarity dimension) — needs a product decision about
Related-Documents axis weights and a data-harvest design; revisit after N-2 ships the
namedFileSeries route it would build on.

---

## Sequencing — the combined picture

Three lanes, one implementer: the honest constraint is review-and-verify bandwidth, not
parallelism. Proposed interleave (each cell ≈ one working session; lanes may slip
independently):

| Slot | Lane | Session |
|---|---|---|
| 1 | S | S-0 wording/parity (+ owner runs N-0 keyed regen the same day) |
| 2 | Q | Q-1 NEAR *(design brief goes to Claude Design now)* |
| 3 | S | S-1 shared pane model + regroup |
| 4 | Q | Q-2 Query Inspector *(inspector design should be back by here)* |
| 5 | Q | Q-3 fts5vocab + exact-word *(start the big Mac index in the background)* |
| 6 | S | S-2 Volumes & Storage hub |
| 7 | N | N-1 #353 parser session |
| 8 | Q | R-1 facets *(needs design hand-back + the indexed corpus)* |
| 9 | S | S-3 list grammar + run-sheet |
| 10 | Q | R-2 + R-3 |
| 11 | N | N-2 #354 routing (+ N-3 curation riding along) |
| 12 | S | S-4 Connections + Data & Recovery |
| 13 | Q | M-1 working corpus *(now lands in the new IA with S-3 components)* |
| 14 | Q | M-2 query log + M-3 excerpt verification |
| 15 | S | S-5 conversions + About; then S-6 docs closeout |
| 16 | N | N-5 consolidation · N-4 if unblocked · N-6 lookup |
| 17+ | Q | Q-M3 keyness/collocation → Q-M5 discovery, as appetite allows |

Natural pause points: after slot 5 (Q-M1 shipped + settings regrouped), after slot 10
(result-set object complete), after slot 15 (settings program complete). Milestones
Q-M3/Q-M5 and N-6 are appetite-driven tails, not commitments.

---

## Issue disposition

| Issue | Disposition under this plan |
|---|---|
| #368 design pass (doc/analytics/settings) | **Recommend closing with a comment.** Settings → superseded by the North Star handoff (Workstream S). Analytics → delivered by Waves A–C + D1 + D3 (#466–#479). Document view → `ResearchStripView` no longer exists; the rail is collapsible via the C2 titlebar toggle, so the minimum-width complaint is structurally addressed (owner sanity-check on a narrow window before closing). |
| #376 / #353 / #354 / #375 / #355 / #372 / #235 | Scheduled as N-0 … N-6 above. |
| #405 | Parked pending product decision (see N-parked). |
| #306 in-chart scrubber | **Not mooted** by the analytics redesign — still a valid enhancement; unscheduled. |
| #268 shared AXChartDescriptor | **Not mooted** — accessibility work, unscheduled here; pairs naturally with any future analytics session. |
| #266 saved-search freshness | Adjacent to Q-M4 (M-2's log knows last-run hit counts) — fold into M-2's decision points rather than scheduling separately. |
| #308 / #261 / #260 / #259 / #234 | FRUS-subjects & person-authority programs — untouched by this plan. |
| #262 / #263 / #265 / #279 / #270 / #312 / #358 / #106 | Backlog, untouched. |

---

## What Claude Design is being asked for (companion doc)

`Planning/Design-Requirements-Query-Analysis-UI.md` — requirements for the **Query &
Corpus Analysis UI surfaces** (the only substantial UI in this plan without settled
design): Q-2 Query Inspector, R-1 facet panel, R-3 KWIC concordance, M-1 working-corpus
promotion flow, M-2 query log/method appendix, plus small optional items (S-1 keyness
toggle placement, D-1 vocabulary explorer, #354's manuscript-repository guidance card,
#235's candidate-resolution picker). The brief tells design what is **already settled
and out of scope** — the Settings North Star, the just-redesigned analytics surfaces,
and the research rail (which replaced the strip) — so the pass cannot relitigate them.
