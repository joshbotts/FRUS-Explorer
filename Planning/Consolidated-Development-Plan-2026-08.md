# Consolidated Development Plan — August 2026

**Date:** 2026-07-25 (revised 2026-07-28, and 2026-08-02 for the whole NARA workstream —
see *Status* and the N-wave header) · **Inputs:** (1) the Settings
North Star design handoff (`design_handoff_settings_northstar/`, dated 2026-07-24, all 10
panes settled); (2) `Planning/Query-And-Corpus-Analysis-Session-Plan.md` (13 sessions, 5
milestones, dated 2026-07-24); (3) the seven open NARA Catalog issues (#235, #354, #355,
#372, #375, #376, #405) plus the parser session #353 they depend on; (4) **added
2026-07-26** — the onboarding design handoff (`design_handoff_onboarding_glass_flow/`,
options 1a/4a–4c settled), planned in `Planning/Onboarding-Glass-Flow-Plan.md`.

**Where this picks up.** The analytics design program is complete and merged: quick-win
Waves A–C, D1 compare terms (#470–#473), and D3 research-grade export (#474–#479). The
research-rail program is complete and `ResearchStripView` no longer exists — the stale
doc-comment mentions were swept in S-0. Those completions moot parts of #368; see the
issue-disposition table at the end.

**Status, 2026-07-28.** **Three of four workstreams are complete.** **S** shipped as
PRs #485–#505. **Wave R** (`Planning/Wave-R-Research-Trail-2026-08.md`) is complete but
for **R-2b** (retiring `ResearchSession`/`SessionEvent` from `frusModelTypes`, 19 record
types → 17), which deliberately waits for the R-2a build to have been in the field, since
the migration must still be able to read the rows it converts. **O** shipped as PRs
#525–#535 (+ #537/#540 fixes), and an unplanned **P** tail followed it — see *Delivered
since 2026-07-26*.

**The lanes still open are Q and N.** Both are re-verified against the tree as of
2026-07-28; corrections are marked **[2026-07-28]** inline. The slot table below is kept
as the plan of record; the live remainder is in *What is left*.

Four workstreams, deliberately independent lanes: **S** (Settings North Star — complete),
**Q** (Query & Corpus Analysis), **N** (NARA Catalog), **O** (Onboarding overhaul). Any
lane can pause without blocking the others; the only hard cross-lane edges are called out
in *Sequencing*.

House rules that bind every session below: implementer ≠ reviewer; UI PRs carry a
visual-review checklist (owner verifies on device); `build-for-testing` before claiming
green; settings changes edit **the shared model plus at most two renderers**
(S-1 landed `SettingsPaneModel`; the older "every change edits both `SettingsView.swift`
*and* `FRUSSettingsView.swift`" rule has relaxed by its own terms, and the
`dual_settings_views` note is partially superseded) **[2026-07-28]**; `CATALOG_API_KEY` is
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

**Project integration:** `Planning/QCA-Projects-Integration-Assessment.md` (2026-07-25)
verifies where this lane meets the #377 project features and folds the results in as
**riders** on already-scheduled sessions — M-1 ships project-aware (corpus `projectIds`
attachment, promote defaults, the History/Focus/corpora three-scope family), **[2026-07-29:
M-2's scope correction was itself wrong — see below]** R-1 gains the
Project Home corpus-profile card, Q-2's inspector labels project scopes and dual-counts
empty conjuncts, M-3 gains the Home verify-quotations entry point. One appetite-driven
addition rides the 17+ tail: **Q-V project-vocabulary leads** (keyness of the engaged
set → distinctive-vocabulary lead source, presented beside — never blended into — the
#308 axis leads). The assessment tables four owner decisions (A–D).

### Decisions A–D and the new E — status 2026-07-29

**A — settled** by the design hand-back (promote-from-History ships in M-1's first cut).

**B — CLOSED (owner call, 2026-07-29).** Not "re-homed": R-2a removed *both* of B's
branches. Branch (a), "enrich the `SessionEvent` payload", has no referent — nothing in
the app constructs a `SessionEvent`, and `ResearchTrailMigration.swift:387` calls
`ResearchSessionAdmin.deleteAll` unconditionally at the end of every successful pass, so
anything written there is deleted on the next boot. Branch (b), "a new model referencing
sessions", has nothing to reference — sessions are computed at read time and borrow their
identity from the first activity's row id (`Models/ResearchTrailSessions.swift:87`). Wave R
answered B in writing (`Wave-R-Research-Trail-2026-08.md:241-244`: "enrich
`SearchHistoryEntry`"), and `SearchHistoryEntry.projectId` ships stamped from
`appState.activeProjectId` by both producers (`Search/SearchView.swift:316`,
`App/SearchSheet.swift:223`).

**What B leaves behind is Decision E**, below. Closing B without opening E would silently
delete three of I-2's four asks: I-2 wanted a rendered FTS5 expression, a scope descriptor,
an indexed-volume denominator **and** project attribution. Only the fourth shipped.

**C** (Q-V) and **D** (I-7 saved analytics queries) remain open — but **D narrowed** when B
closed. Its first option was "migrate into the query-log model"; under E's answer that
target is a new `QueryLogEntry`, so D becomes "does the query log carry non-search entries
at all", which is a `kindRaw` discriminator — one identifier now, a whole deploy later.

---

### Decision E — the query-log store shape *(owner-answered 2026-07-29)*

**E is four decisions, not one, and the gating one is not about storage.**

**E-0 — the write rule. ANSWERED: yes, the de-dup key gains a scope signature.**
Both producers guard on `query != lastRecordedHistoryQuery` against a private in-memory var
(`Search/SearchViewModel.swift:585`, `App/MacSearchViewModel.swift:771`). That is a
*consecutive* de-dup, not a uniqueness rule — A→B→A already records A twice — but the one
case it suppresses is the immediately-consecutive scope-only re-run, which is **exactly the
shape of an absence assertion** (same words, project scope then corpus-wide). No column
makes the second claim recordable; the write rule had to change first. Consequence to
budget: **row density rises in two shipped surfaces**, History ▸ Searches and Project Home
▸ Recent Searches.

**E-1 enrichment fields · E-2 the mutable star · E-3 row identity.** Separable; E-2 and E-3
couple only if the star goes off-row.

**E core — ANSWERED: option (v), supersede with a purpose-built `QueryLogEntry`.**
The owner chose (v) over the recommended (i) (widen `SearchHistoryEntry` with typed
columns). The reasoning that carries it: **(v) is the only option that solves all four
sub-problems.** (i) and (iii) both inherit `SearchHistoryEntry.id`, which is documented
*not unique in practice* (`Models/HistoryPaneSnapshot.swift:110-121`) — so the re-run link
and any star keyed to it attach to every duplicate. A fresh model has fresh ids the
migration never touches.

| | cost / consequence |
|---|---|
| **Schema gate** | ~16 identifiers now (213 → ~229), **plus a second, removal deploy later** when `SearchHistoryEntry` is retired or demoted. Two Production promotions, not one. |
| **Migration interlock** | Does **not** trip — `CD_QueryLogEntry` does not match `ResearchTrailMigration.writtenRecordTypes`' prefix filter (`:155-158`, `:171-173`). |
| **The harder gate instead** | CloudKit creates a record type only when a record is first saved (`Models/CloudKitSchemaInventory.swift:293-297`). Until Production is promoted the log **silently fails to sync** — the #488 failure mode. Exercise it once on a Development build before promoting; this is the step no test can verify. |
| **E-2 star** | Solved cleanly — purpose-built, no immutability contract to violate. |
| **E-3 identity** | Solved — fresh unique ids for `rerunOfId` and any future annotation. |
| **Existing rows** | The log starts **empty**. No migration can back-fill expression, scope, denominator or star, so pre-M-2 searches remain visible in `SearchHistoryEntry`/Sessions only. See open question Q9. |
| **"Never two lists"** | Satisfied *after* the re-point. The constraint (README:119) governs display; one purpose-built record backing one lens honours it. **The re-point is the work**: `ResearchTrailSessions`, `ProjectHomeSummary` and `ResearchDataExporter` all read `SearchHistoryEntry` today. |

**The store shape should round-trip `SearchParameters`, not copy `SavedSearch`'s columns.**
`SavedSearch` is the right *precedent* — 14 flat scalars, 16 deployed identifiers, a
documented CloudKit-safe encoding, and the only model in the app that durably encodes a
query for replay (`Models/SavedSearch.swift:16-33`). But its round-trip **drops 8 of
`SearchParameters`' 20 fields, including every scope field** — no `volumeIds`, no
`documentIds`, no `userTagIds`, no `excludeDocumentIds` (`:162-175`). That is deliberate for
saved searches: `applyParameters` resets `projectScope = .off` because "Project History
scope is a live, manual choice — never inherited from a restored snapshot"
(`Search/SearchViewModel.swift:793-798`). **That policy is exactly inverted for a query
log**, whose entire purpose is to record the scope a claim was made in. An absence
assertion reading "0 in OSP Corpus 1950–72 (267 docs)" is a `documentIds` scope; stored
`SavedSearch`-style it would become a corpus-wide search with a date range, and the
appendix would be wrong. Take the encoding idiom and the `SearchParameters` currency; do
not take the field list.

**E-2 resolved by construction:** the record of an *execution* is immutable; the
researcher's *annotation* of it is not. Absence claims are a **fixed pair** — the scope run
in, plus corpus-wide — not an open-ended child table, because the design's second claim is
structurally corpus-wide (README:123), the denominator against which the first means
anything.

**Sequencing.** Nothing must ship before M-2 for correctness, but: **M-1 must precede M-2
and its delete semantics must be settled first** — a log row citing "OSP Corpus (267 docs)"
needs to know whether it stores a frozen label+count or a live reference (probably both).
**R-2b would make E-3 free** but is time-gated on R-2a being in the field, so it cannot
precede M-2 — do not wait for it.

**Three live defects folded into M-2's scope (owner call, 2026-07-29)** rather than filed
separately, since M-2 touches all three surfaces:
1. **`ResearchDataExporter` fetches the whole search-history table unbounded and unscoped
   by project** (`Export/ResearchDataExporter.swift:426-427`) while stamping the export
   with the *active* project's name and research question (`:31-34`). Today's method
   appendix contains every project's queries.
2. **`resultCount` has two silent cap values.** iOS caps at 1,000
   (`Search/SearchViewModel.swift:402,590`); macOS logs **7,500** whenever the concurrent
   `COUNT(*)` throws or is cancelled (`App/MacSearchViewModel.swift:709-711`, cap `:204`) —
   the realistic path at 6–12 s per common term. `resultCountIsExact` is the fix.
3. **`SavedSearch` silently drops volume scope on recall** — deliberate and documented for
   `projectScope`, undocumented for manual volume picks (`Models/SavedSearch.swift:162-175`).

**Still open at M-2 session start** (recorded, not answered): does pinning execute a second
corpus-wide count at pin time (a 6–12 s blocking action with no designed pending state, vs
asserting a number never measured)? Does an explicit pin bypass "Log Research Sessions"
being off — both producers hard-return when it is (`SearchViewModel.swift:578`)? Does
re-run write a new linked row (prose, README:137) or render an ephemeral diff on the old
one (what the macOS mock actually draws)? Are pre-M-2 rows rendered "not recorded" or
excluded? What does the appendix cite when a working corpus is renamed, re-resolved or
deleted?

**M-2 is not one session.** Surface 5's two named homes are two different view stacks —
`HistoryView`/`HistoryPaneSnapshot` (project-scoped, paged, per-row delete) and
`SessionLogView`/`ResearchTrailSessions` (unscoped, derived, **Settings-only**,
`Settings/ResearchSessionsView.swift:107,123`). A segmented Sessions · Queries control with
a project filter requires unifying two snapshot types *and* relocating a Settings-only
surface, on both platforms. Price this before scheduling.


**Cross-lane edges (the only ones):**

1. **Design before build — ✅ CLEARED 2026-07-25.** The Claude Design hand-back
   (`design_handoff_qca/`, designs 1a–5a settled and accepted) arrived before Q-1
   started. `Planning/QCA-Design-Handoff-Assessment.md` is the binding: premises
   verified clean, every open design decision settled (integration decision A =
   promote-from-History ships in M-1's first cut), five minor flags folded into their
   sessions — Q-2's stem line ships count-only until D-1's surface-forms map;
   cross-session controls ("Pin as absence assertion", "Save as working corpus…")
   stay hidden until M-2/M-1 respectively; M-1 must budget the scope-menu family
   retrofit as its hidden bulk. Sessions Q-2/R-1/R-3/M-1/M-2 start from the
   assessment, not a fresh handoff read.
2. **M-1's settings surface lands in the new IA.** The working-corpus manager homes in
   Settings → Research beside Volume Scopes. Schedule M-1 **after S-1** (the regroup) so
   it is born into the 1c tree and the shared pane model, not re-homed later. M-1's
   editor should reuse S-3's list-grammar components (row → editor, counts on rows) —
   another reason S-3 precedes it.
3. **Q-M3's keyness mode** rides the existing word cloud. **[2026-07-28] The ordering
   question is spent — S-5 and O both landed.** The live edge is newer: the cloud is now an
   animated surface with a per-frame drift canvas and a frame-cost probe (`DrawCostMeter`),
   so a keyness re-tokenize must not run on the surface the canvas is animating. The cloud
   has also entered the Q lane's own screens — `CloudSurfaceArbiter.searchScope` backs the
   search empty/pending state (`Search/SearchView.swift:650`, `App/SearchSheet.swift:688`) —
   so Q-2/R-1/R-3 must coexist with it. A real cross-lane edge now, not a hypothetical.
   **[2026-07-29, verified] The feared collision is not real.** The backdrop is bound to
   the **pending** state only (`Analytics/WordCloud/PendingCloudBackdrop.swift:19-21`;
   iOS `Search/SearchView.swift:643-654` inside `if vm.isSearching`, zero arm at `:661`;
   macOS `App/SearchSheet.swift:176-198`), so Q-2's zero-result decomposition — a
   *completed* search — never contends with it. Two real items remain: the two call
   sites are not equivalent, and `PendingCloudRule.shouldShow` already suppresses the
   cloud during indexing, which Q-2 should not re-litigate.
4. **Corpus prerequisite — [2026-07-28] MET.** The Mac index is effectively the whole
   corpus (552 volumes, ~314k documents, a 6.3 GB store); this is no longer owner wall-clock
   to schedule. One consequence replaces it: base query latency at that scale is
   **measured and material** — a
   common term is 6–12 s in SQLite before any snippet work (#548). Q-2's inspector and R-1's
   facets both sit on that, and the 7,500-row macOS fetch is an architectural pagination
   issue. **[2026-07-29] The exporter is the other half of this.** `HistoryPaneSnapshot` already
  pages and pushes the project predicate into the fetch (`:75-83`), but
  `Export/ResearchDataExporter.swift:426-427` fetches the whole search-history table
  **unbounded and unscoped by project** under the active project's header (`:31-34`) —
  so the shipped "method appendix" contains every project's queries. Folded into M-2.

  ~~**Treat result-set pagination as an explicit Q-M2 prerequisite rather than
   discovering it in R-1.**~~

  **[2026-07-29] SETTLED — and the prerequisite as written was the wrong one.** Measured
  read-only against the real 6.3 GB store (316,839 documents / 552 volumes):

  - **Pagination is not the problem.** SQL `LIMIT`/`OFFSET` already exists in
    `searchDocuments`, is exact, and **no caller uses it** — both platforms fetch the cap and
    slice in memory. Paging the fetch removes only ~18% of the cost, and building it would
    mean porting the date sort and checklist exclusion into SQL for no R-1 benefit.
  - **The 6–12 s figure is real but was misattributed.** The cost was the *count* joining
    `document_cache` (1.8 GB) and `document_dates` when the `WHERE` clause is empty — the
    **default** case. `"government"` (195,519 matches): **2.55 s → 0.011 s** cold for the
    same answer with the joins dropped. Shipped.
  - **All five R-1 facet sections are SQL aggregates** over the match set. None needs result
    rows, so the fetch cap is irrelevant to them. The whole panel is ~2.6 s at the worst
    realistic query once the count is cheap and one covering index exists
    (`idx_document_cache_facet`, 8.5 MB — shipped; `document_cache` previously had only its
    PK autoindex, so the document-type aggregate scanned the whole table, and *every* facet
    scanned it with front matter excluded).
  - **The real live defect was the count's failure path**, not its size. `totalMatchCount`
    fell back to `results.count`, which silently made a truncated set equal its own cap
    **and switched off both truncation warnings** — and that number reached the research
    trail. Now optional; the surfaces say "total unavailable" and the warning is driven by
    whether the fetch hit its cap. Shipped.

  **R-1's implementation rule** (not a build item): materialise the match set once per search
  into a TEMP table with an `INTEGER PRIMARY KEY` and drive every facet from it. Acceptance
  criterion is `EXPLAIN QUERY PLAN` showing a covering index — `SCAN dc` in a plan is the
  bug. A stopwatch on a small fixture cannot tell the two apart.

  **Deliberately NOT built:** pagination, a projection/shadow table, cap changes, keyset
  cursors, and the two-phase fetch — that last is the largest remaining latency win (mset
  then hydrate takes the 7,500-row fetch from ~10.5 s to ~0.6 s, byte-identical output) but
  it reshapes `searchDocuments` and R-1 does not need it. Its own session.

  **Bounds R-1 must still surface:** the *result list* stays capped (1,000 iOS / 7,500 macOS)
  even though the count and facets are not — copy is "Describing all 195,519 matches — the
  list shows the first 7,500", never "all 7,500". Per-section display bounds must be
  computed, never templated: real in-match cardinalities are **552** volumes and **14,615**
  person rollups against the mock's "top 4 of 47" / "top 4 of 214", and its "Top 3 hold 60%"
  is **1.7%** for a common term.

**[2026-07-28] A hazard the plan did not name — Q-2's stem line.** The inspector is
specified to show the stem a term resolves to, but the app has *two* stemmers: the Swift
`PorterStemmer` (`FTS5Store/FTS5Tokenizer.swift`) and SQLite's `porter unicode61`
tokenizer, which is what actually built the index. Nothing asserts they agree, so the
inspector could confidently display a stem the engine never computed. Either source the
line from `fts5vocab` (SQLite's real stems — the session plan permits inverting Q-2 and
Q-3) or add a parity test and label the line an approximation. Related: #548 made
`makeContextSnippet` reject words on their first character before stemming, sound only
because Porter never alters a first character; that invariant is pinned by
`SearchSnippetCostTests.stemmingPreservesTheFirstCharacter` and Q work touching stemming
must keep it true.

**Verification discipline carried over:** the two source reports are the test oracle
(`NEAR("military guarantee" Europe, 30)` → 0/0/0/3 across 1945–48; Article 43: 42/29/26/8
against Article 51: 10/28/32/18; the OSP within-corpus counts 9/8/0). A mismatch is a
finding about indexed scope, not a test to relax. **[2026-07-28] These numbers live only in
this plan** — the source reports are not in the repo, so the oracles have no primary source
to check against. Deposit the reports (or their count tables) under `Planning/`, or drop
the OSP clause: an unfalsifiable oracle is worse than none in a lane whose discipline is
that a mismatch is a finding.

---

## Workstream N — NARA Catalog

Tiered by who executes and what unblocks what. The keyed runs are minutes of owner time
each; the engineering sessions are normal PRs.

### [2026-08-02] The full harvest was measured against every N item. Three routes are dead; one new one is the biggest thing in the workstream.

The owner supplied the complete 22-record-group harvest (4.5 GB, **751,880 records** =
20,188 series + 731,692 file units). Every N item was measured against it *and* against
the owner's live index, then each measurement was adversarially re-derived. The results
change the shape of this workstream more than any single session would have.

**The harvest's contribution to the planned work is small.** Item by item, in documents:

| item | planned population | harvest yield |
|---|---|---|
| N-1 / #353 parser | ~1,850 + 939 | **11** |
| N-2 / #354 (a) namedFileSeries offline route | 4,986 | **0** |
| N-2 / #354 (b) CFPF deep links | 1,361 | **0** |
| N-2 / #354 (c) RG 256 Paris Peace | 1,547 | **~1,300–1,500** |
| N-2 / #354 (d)/(e) | ~1,836 | 0 (structural) |
| N-3 / #375 lot curation | 6,366 | **~101 clean + 48 ambiguous** |
| N-4 / #355 presidential libraries | 20,451 | **0** (structural) |
| N-5 / #372 lot-map consolidation | 15,340 | **7–20** (the 728 needs no harvest) |
| **N-8 / #674+#675 acceptance test** *(added 2026-08-04)* | 6,230 exposed | **5 wrong found, 28 ambiguous picks over 725 docs** |

**But the harvest carries a capability nobody planned for.** 17,985 records hold
`digitalObjects` arrays — **10,115,572 individual objects**, each with a live
`catalog.archives.gov` URL. That is a categorically better outcome than a NAID: a PDF of
the microfilm roll rather than a note about which box to visit. New issue **#663**;
measured reach is **~7,000–9,000 decimal-cited documents** plus RG 256's 1,547, against
the 8,974 the entire bundled lot index resolves today. It is now the highest-value item
in the workstream.

**Three findings that change what gets built:**

1. **The `namedFileSeries` offline title-match route returns literally zero** and must be
   dropped, not merely re-estimated. `select count(*), count(record_group),
   count(distinct series_name) from document_sources where citation_era='named_series'`
   → `4986 | 0 | 232`. FRUS series names are Department bureau designators; NARA titles
   are cataloguer prose. There is no shared vocabulary to match on. This was the largest
   single population in #354.
2. **The CFPF file units are not digitised** — all 69 under naId 654098 have zero digital
   objects (verified by streaming all 240,929 RG 59 records). A year-grain NAID lands on
   an empty stub, against an app that already ships the AAD link and the FAQ PDF. Route
   dead.
3. **A harvest creator gazetteer is a trap.** It scores 562 documents on 8 hits, 492 of
   them "National Security Council" — and every one is wrong, because the 22 groups are
   the *foreign-affairs* groups, so an agency's own records usually live outside them and
   a creator-name match inside is a correspondent or a custodial accident. Recorded here
   because it is exactly what a plausible harvest session would build.

**What the Catalog API demonstrated.** Three conclusions worth keeping: (i) the v2 API is
**field-complete** against the bulk export and cheap — the whole 22-group series layer is
~62 calls, minutes, a few MB, versus streaming 22 GB; (ii) `variantControlNumber_is` was
never the limitation — **only 5,466 of 20,188 series (27.1%) carry a lot-type control
number at all**, and 2,900 of RG 59's 4,449 (65.2%), so the gap is NARA's cataloguing,
not our querying; (iii) resolution collapses upward — 199,108 records resolve to NAID 388
(the RG 59 node itself), which is why "search the catalog" so often returns the record
group rather than the series. Full detail in
`Planning/nara-record-group-catalog-runbook.md`.

**Net effect on sequencing:** N-1 loses its harvest dependency entirely (it was always
grammar work). N-2 sheds two of its five items and keeps one, promoted. N-5's first half
detaches from the harvest and can ship immediately. **N-7 (#663) is new and should be
scheduled behind N-2's RG 256 parser, which it inherits.**

**[2026-08-04] The harvest also turned out to be an audit instrument, not only a data
source.** Checking the app's own 2,667 shipped lot→NAID associations against it found five
that are wrong and 28 whose pick between rival candidates is unrecorded — see **N-8**, now
the first item in the lane. That use was not anticipated when the harvest was assessed: the
question then was what it could *add*, and the answer above is "not much". What it can
*check* is a different and, on this evidence, more valuable thing.

**N-0 — Keyed data runs — [2026-08-04] COMPLETE. Nothing here is owed.**
- **#376** ran on **2026-07-29**. Verified against the shipped bundle:
  `volume-sources-index.json` is stamped `generated: 2026-07-29`, its `lots` map holds
  **751 series-level entries and zero `fileUnit`**, the nine targets (58D528 … 92D252) are
  gone, and `recordGroups` is **31** — the confirmation criterion this entry asked for.
  The export re-baseline ran with it: `missed-lots-ranked.tsv` is 581 rows / 6,230
  documents, matching N-3's own post-regen figure below.
- This entry contradicted N-3, which has recorded the re-baseline as done since 2026-07-29,
  and it was still being read as a live owner prerequisite for N-3's curation a week later.
  **There is no keyed run left in this workstream**, and #375's keyed route is closed (2 of
  573), so `CATALOG_API_KEY` is not needed by any planned N session.

**N-8 — #674 + #675 lot-resolution acceptance test** *(Effort M; NEW 2026-08-04. **Do this
first** — it is the only correctness defect in the lane, and everything else adds coverage
on top of a resolver that can currently assert a wrong archive.)*

Two issues, one missing check, on the two sides of the same resolver. Filed after the owner
reported lot **90 D 234** (OES/OA Antarctic files) resolving to a **Census Bureau** series.

**#674 — the live path has no acceptance test at all.** `resolveLotFileVariants`
(`NARACatalogClient.swift:451`) tries three `variantControlNumber_is` forms; when all three
correctly return nothing, it falls back to `searchByLotFile` (:411–419) — a **free-text
phrase query with `maxResults: 1`, returning `results.first`**. `buildResult` (:651–696)
never reads `levelOfDescription` and never compares the parsed `recordGroupNumber` against
the record group that was *requested*, so the `recordGroup: "59"` argument is decorative on
this path. This repo already documented the failure, in the generator:
`NARACatalogHarvestClient.swift:413-416` says NARA's RG filter "does not constrain free-text
results, and the top hit for a lot string is often a giant wrong-RG series
(**census**/military/court) — so we scan the page and take the first RG-59/84 record, not
blindly the #1 result." The generator was hardened; the app was not. **6,230 documents fall
through to this path** (`lotFile|liveRouteOnly`).

**#675 — the bundled errors are a different mechanism: lot-number collision across
bureaus.** State assigned lot numbers per accession, so two offices each held a "66 D 50"
and NARA catalogued both. Every current guard — RG matches, level is `series`, the record
carries the control number — passes for *both* candidates. Swept all **2,667** associations
across the three bundles (622 distinct NAIDs, all found in the harvest):
- **5 confirmed wrong, 11 documents.** Sharpest is `76D482`: FRUS cites *ARA/CAR … Bauxite,
  Jamaica 1974*, **two** series claim the lot (Iran 2602428, Jamaica 1039947), and the
  generator picked Iran. Also `74D476` Cyprus Desk → Jamaica, `66D50` ARA/CCA Cuba → Kenya,
  `61D67` ARA/OAP Panama → INR (unbacked by any control number), plus 90D234.
- **28 lots are claimed by more than one harvested series, riding 725 documents** — the
  pick is currently unrecorded and unreviewable. `64D563` alone is 245 documents.
- Only **3 of 971** central-files rows lack control-number backing, so the bundle is sound
  overall; the exposure is concentrated in the ambiguous band.

**Scope:**
1. **A bureau/creator conjunct in `isAcceptableLotResolution`.** The FRUS citation names the
   office (`ARA/CAR`, `Cyprus Desk`, `OES/OA`); the NARA record names its creator. Disagree
   at bureau level → refuse. This is the guard RG-and-level structurally cannot be, and it
   catches all four bundled errors.
2. **Share that test with the app's live path**, scan a page instead of `maxResults: 1`, and
   consider dropping the free-text fallback for lot files entirely — it fires only when the
   precise query found nothing, so its hit rate on *correct* answers is near zero while its
   hit rate on plausible-looking wrong ones is high. "No matching record found" plus the
   manual `search-within/388` link is already the app's honest outcome elsewhere.
3. **Record ambiguous picks** as `candidates: [naId…]`. N-3 already built the render for
   this — #669's `.candidates` outcome shows several series, each chipped "Possible" — so
   this is a data change, not a UI one.
4. **Correct the five** through `curated-lot-resolutions.json`, which N-3 shipped: `76D482`
   → Jamaica (1039947) is a straight repoint; the other four have no correct NAID in the
   harvest and become referrals or withdrawals.

**Why first.** Every other N item adds coverage. This one stops the resolver asserting a
wrong archive with a working catalogue link and no visible doubt — strictly worse than the
"No matching record found" it would otherwise show, and the failure the #351/#352 guards
were installed to prevent on the bundle side while the live side was never given them.

**N-1 — #353 SourceNoteParser session** *(Effort L; the biggest coverage lever)*
**[2026-08-02] No harvest dependency. Do not budget a harvest-lexicon sub-session.** The
939-document steal fix and the ~1,758 recoverable unrecognized notes reproduce exactly and
land identically with the harvest deleted from disk. The harvest's honest contribution is
**11 documents** (FRC accession → RG), and its own footprint contains 4 it must refuse:
the native key is RG-prefixed (`059-71A6682`), so stripping to `71A6682` aliases across
groups — 50 of 1,349 keys map to >1 RG, and 3 of the 19 covered keys are among them. Move
that item to N-2/N-5 where the harvest is already on disk, and give it an RG-scoped key.
~1,850 recoveries across **six** verified rule families + the three strategy-steal fixes
(§3.2 library-keyword-anywhere, §3.3 mSupp abstract prefixes, §3.5 secondary-clause lot
steal) + the 36,063-record decimalClass derived-field fix **[2026-07-28: the plan said
"seven" families. It is six — the seventh audit row *is* the decimalClass fix, which this
same sentence already counts separately, so it was being paid for twice]**. Every change guarded by the
`SourceNoteEval` harness against `eval-baseline.txt`; after landing, re-run
`SourceExplorerExportGenerator` and adopt the new baseline. **Sequenced before N-2** so
the routing work tests against post-parser classifications once, not twice.

**N-2 — #354 Source Explorer routing pack** *(Effort M–L → S–M)*

**[2026-08-02] Rescoped from five items to three. Item (a)'s offline route and item (b)
are cut; item (c) is promoted to the head and is bigger than the issue thought.**

- **(c) RG 256 is the session.** 537 of the 538 Paris Peace file units are **digitised** —
  450,105 objects, M820 microfilm-roll PDFs — so a correct resolution hands the researcher
  a downloadable ~700-image roll, not a catalog label. Today those 1,547 documents get only
  the `centralFilesPanel` label plus generic prose (`load()`'s switch, :1171–1189, has no
  `.centralFiles` case). **Three caveats belong in the acceptance criteria**, not in a
  footnote: (i) it is a **hand-curated** file, not a generated one — only 303 of 537
  consecutive range titles chain by serial+1, 14 pairs overlap, 16 have high-bound
  inversions, 10 carry literal transcription noise (`185.002-185.00?`, `!84.lMch-Myer`,
  `8670.00/6-86?n.00/25`…), and a *name*-range family (`184.1/Ba-Bernv`) swallows the
  numeric space above 184.1 under any naive dash-split; three independent implementations
  of the same idea resolved 533 / 1,036 / 1,294; (ii) **~10% of documents ride an
  unadjudicable tiebreak** — narrowest-vs-widest flips 144 of 1,438, NARA's own ranges
  overlap, and **0 of 538 carry a scope note or holdings measurement** to settle it, so the
  uncertainty goes in the UI; (iii) the issue's own framing — "one bundled record resolves
  all 1,547 offline" — is a **two-line constant** needing no harvest at all. That premise
  is otherwise correct: RG 256 really is absent from `volume-sources-index.json`'s 31
  `recordGroups` and from every bundled `Resources` JSON (both verified).
- **(d)** manuscript repositories (~1,502) — unchanged, static guidance, no harvest input
  possible (non-federal repositories are outside every record group by construction).
- **(e)** numerical-format gate (334) — unchanged; gate **both** copies (see the
  2026-07-28 note below).
- **CUT — (a) offline title match.** Returns 0 of 4,986; see the finding above. Keep its
  live-route and personal-papers-repository halves, which never depended on the harvest.
  The 45 SWNCC documents still gain RG 353, and 802 JCS/Defense/Army documents gain an RG
  node from bundles the app **already ships**.
- **CUT — (b) CFPF deep links.** 0 of 1,361; the file units are not digitised, and the
  issue's actual ask is a per-document link the harvest has no item level to supply.

The pre-2026-08-02 item text is retained below for the record.

Five independent items; split into two PRs if needed:
(a) namedFileSeries: catalog keyword live route + personal-papers repository table +
static seriesName→RG map (~939 records offline through already-bundled RG NAIDs) +
txt:→lot: cluster bridge (162 unambiguous) **[2026-07-28: the ~939 is right, but it does
NOT include the audit's fifth arrow, SWNCC→RG 353 — RG 353 is bundled nowhere, so that
arrow carries an unpriced one-record bundling cost of its own]**;
(b) CFPF tiers: per-document AAD/catalog deep links for the 1,361 D-reel ids ≤1979,
static guidance elsewhere;
(c) RG-256: one bundled record resolves all 1,547 Paris Peace citations offline;
(d) manuscript repositories (~1,502): split into a strategy with static finding-aid
guidance naming the actual repository — **stops issuing a NARA query guaranteed to
miss** (a small design-copy dependency: the guidance card's wording/shape is in the
design brief as an optional item);
(e) numerical-format gate in `CentralFilesIndex.caseNumber(fromFileNumber:)` (334
records; covers both platform call sites) **[2026-07-28: "both platform call sites" is not
the whole surface — there is a SECOND copy of `caseNumber(fromFileNumber:)` in the
generator package, `CentralFilesIndexGeneratorCore/CentralFilesIndexModels.swift:353`
(the app's is `FRUSExplorer/SourceExplorer/CentralFilesIndex.swift:384`).
Gate only the app copy and the app silently disagrees with the export harness that
produced the 334-record figure, which stops being reproducible. Gate both]**.

**N-3 — #375 curated lot NAIDs (owner + Claude)** *(Effort S)*
The control-number route is closed (2 of 573).

**[2026-08-02] Confirmed definitively against the complete harvest, and one seed is worth
curating first.** Every control number in all 22 groups was extracted — 62,349
occurrences, 51,531 distinct under `SourceNoteParser.lotFileNorm` — and matched against
the live index. The harvest resolves **~25 of the 605 unresolved lots / ~149 documents
(2.3%)**; the extraction is sound (968 of the 971 bundled lots reproduce from the harvest's
own control numbers, 99.7%, with **0 NAID disagreements**), so 2.3% is a real ceiling, not
a parsing artefact. `54 D 270` (1,063 documents) returns **zero** raw byte hits anywhere in
the 3.3 GB `rg_59.json`. Manual curation is the only route, exactly as this issue says.

**Two corrections to the "free win" framing:** (i) **13 of the 24 newly-resolvable lots /
84 documents resolve into a *different* record group than the citation names** and fail
`CatalogRecord.isAcceptableLotResolution` (`NARACatalogHarvestClient.swift:138`) — the
#352 rule installed *because* #335 found wrong-collection resolutions. The history looks
right, but admitting them means relaxing the guard, which is an owner decision about the
app's uncertainty policy. Keeping it leaves ~11 lots / ~70 documents. (ii) `57D284`
carries 48 of the 149 documents and is a **one-of-two pick** (naId 1422076 Torquay 1950 vs
1422086 Special Session 1951), not a clean hit.

**[2026-08-03] The owner curated the top six lots and the app now renders them — N-3's first
increment is shipped.** 2,943 documents, 46% of the unresolved mass. The curation did not
fit the binary the app had, so the outcome model widened to three kinds:

| lot | docs | outcome |
|---|---|---|
| 54D270 Marshall Mission Files | 1,063 | **candidate list** — 10 RG 59 series under creator 10481258, entries A1-1095…A1-1106, all bundled (no API key) |
| M88 CFM Files | 697 | **archivist referral** — NARA arranged the CFM by conference session × document type, ~170 series across A1 310–A1 675, against one flat FRUS lot; no mechanical mapping exists |
| 60D627 / 59D95 / 64D560 / 62D181 | 1,183 | **possible match** — Conference Files, naId 602875, by collection name rather than control number |

Three decisions worth keeping. (i) **Curated rows live in their own bundle**
(`curated-lot-resolutions.json`), because three generator paths rewrite
`central-files-index.json` wholesale and a curated row kept there survives only until the
next harvest. (ii) **Confidence attaches to the (lot → NAID) edge, never the NAID** — 602875
is a *control-number* resolution for nine other lots, so the #351 `untrustworthyNAIDs`
denylist could not have carried this and would have suppressed nine certain resolutions.
(iii) **Curated rows are kept out of `volume-sources-index` and `collection-authority`**,
whose consumers (an icon-only link, a two-field PDF export row, a "resolved offline from the
bundled index" caption) cannot express doubt; confining them to the two Source Explorer
views leaves every other surface honestly saying "unresolved". Tests pin all three.

Incidental fix in the same PR: `SourceNoteParser` defaults every non-`F` lot to RG 59, so
the panel labelled M88's RG 43 collection "RG 59" and issued an RG-59-scoped fallback
search for it. Curation now overrides the parser on both platforms.

**Remaining N-3 work:** the ranked tail below `62D181` in
`Planning/source-explorer-export/missed-lots-ranked.tsv`, curated the same way. The bundle
and both render surfaces now exist, so each further lot is a JSON row, not a code change.

**Curate `Conference Files → naId 602875` first: ~1,425 documents, 22% of the gap, one
row.** 17 unresolved lot norms (59D95, 60D627, 60D629, 62D181, 63D123, 64D559, 64D560,
65D366, 65D533 + 8 OCR variants) are one continuing series. The proof needs **no harvest**:
`central-files-index.json` already maps nine other Conference Files lots to 602875, each
titled "Conference Files", and every note reads "Conference Files: Lot NN D NNN, CF NNNN".
The harvest merely corroborates (RG 59, 1949–1972, Executive Secretariat, entry A1 3051B).
Raw count is 1,572; **147 (9.4%) cite the lot only as a secondary "ibid." reference** while
the document sits elsewhere, so ~1,425 is the honest figure. That 12.6%-baseline
secondary-reference rate already applies to the 661 resolved lots, so it is not new harm.

**Do NOT automate sibling inheritance.** The general rule — "an unindexed lot is a sibling
accession of an indexed one" — leave-one-out tested against the 971 bundled ground-truth
resolutions gives **63 predictions, 33 correct, 30 wrong: 52.4% precision**. The FRUS
prefix is a *bureau* designator, not a series name ("NEA Files" spans 18 distinct NARA
series, "SPA Files" 6, "FE Files" 8); **79 of 92 testable name-groups (85.9%) span more
than one series**. Today an unresolved lot produces a visible, honest absence
(`SourceExplorerView.swift:832` → "No matching record found" + a manual `search-within/388`
link); an automated override would replace that with a confident wrong link about half the
time. Use the harvest to emit a **ranked candidate list for hand-verification** — this
issue's own option 1. Useful corollary: **508 of the 971 bundled lots (52.3%) already share
a naId with another lot**, so the shipped bundle is a better source of candidate groupings
than the harvest's 28.3% multi-lot rate.

**Implementation anchor.** The override must be read at `CentralFilesIndex.swift:81
lotFile(forRawLot:)`, consumed by **both** `SourceExplorerView.swift:832` **and**
`MacSourceExplorerView.swift:274`. `BundledLotResolver` exists only in
`VolumeSourcesIndexGeneratorCore/` and is enrolled in no app target — wiring it there
changes the export generator, not what a user sees.

**Re-baseline the export first — done 2026-07-29, and the figures below are now measured
rather than projected.** The 573-lot figure predated N-0's keyed regen. After it: the gap
is **581 lots / 6,230 records**, and **60D627 (455 records) — one of the nine dropped
`fileUnit` entries — now ranks #3**, so curating "the top ten" from the pre-regen file
would have skipped it entirely. `missed-lots-ranked.tsv` has been regenerated (581 rows)
and the run-book's priority table rebuilt from it. The top-10 share is **55.8%**
(3,475 / 6,230) — it *rises* from 54% rather than falling, because 60D627 enters the
ranking rather than displacing anything.

Owner hand-curates NAIDs for the top ~10
lots (54D270/Marshall Mission = 1,063 records, M-88/CFM = 697, 60D627 = 455, …) from
`Planning/source-explorer-export/missed-lots-ranked.tsv`; Claude adds the curated
`lot → NAID` override the generator reads (same pattern as the presidential-library
curation) and re-baselines. Cheap, high-yield, no API dependency.

**N-4 — #355 presidential-library curated NAIDs** *(Effort M)*
**~6** curated (library, collection) → NAID entries reach ~66% of the 29k-record
presidentialLibrary bucket; ~20 entries reach ~81% **[2026-07-28: the plan previously
attributed ~66% to ~20 entries]**.

**[2026-08-02] Zero harvest contribution, and it is structural — remove the dependency and
schedule this on its own.** An ancestor census over all 751,880 records returns
`{recordGroup: 751,880, series: 731,692}` and **zero collection-level records**:
presidential libraries sit outside every record group, so a record-group-filtered harvest
excludes them by construction. No re-harvest, no additional groups, and no API key changes
that. Sizing re-measured on the live index — **20,451 documents over 1,363 distinct
(repository, collection) pairs** (excluding the Library of Congress): 6 entries → 13,358
(65.3%), 10 → 72.5%, 20 → 16,133 (78.9%), 46 → 84.9%, 100 → 89.7%. The curve is flat past
~50; **stop at 20**. Confirmed: all **438 library-repository clusters in
`collection-authority.json` carry `naId: null`** — nothing to inherit.

**The gate below is still the right gate, and half of it is still open.** `domainFiltered`
(:270) and the #373 front-matter extension (:291–297) block **presidentialLibrary → `lot:`**
— both shipped and tested. But the bridge *this* issue would weaponise is **library A →
library B**, and step 4 `uniqueRecord(forAliasNorm:)` (:306) remains repository-blind over
one global `byAlias` map. Conditions (i) and (ii) stand exactly as written.

**Gate answered 2026-07-28 — §3.7 is HALF delivered, and the missing half is the one this
session depends on.** #351 (PR #370) shipped the cross-domain *refusal*
(`CollectionAuthorityIndex.domainFiltered`, `CollectionAuthority.swift:270`, applied :261)
and #373 extended it to the front-matter path (:295–298); the Carter-Library canary is
closed and tested. But domain **tagging** was never built: `AuthorityCollectionRecord` has
no domain field, the guard is a single hard-coded presidentialLibrary × `lot:` pair, and
lookup step 4 (`uniqueRecord(forAliasNorm:)`, :306) is still repository-blind over a global
`byAlias` map holding 379 globally-unique alias norms owned by library clusters (e.g.
"administrative histories" → Johnson only). A note from library A can still land on
library B's cluster — precisely what seeding curated NAIDs would weaponise.

**N-4 is therefore schedulable, with two conditions folded into its scope:** (i) key the
curated entries repository-first and make lookup repository-aware for library parses
*before* seeding; (ii) keep neighbor-key normalization ("NSF" variants, "Dulles papers"
casing) off the repository-blind alias step. Unguarded but lower risk, for the record:
`namedFileSeries` carries no repository at all and can reach a `lot:` cluster.

**N-5 — #372 lot-map consolidation** *(Effort M, architectural — now split into two PRs)*

**[2026-08-02] Split it. The repoint is worth 728 documents, needs no harvest and no
regeneration, and can ship today; the fold is architectural hygiene worth 2.**
`central-files-index.json` `lotFiles` resolves 661 keys / **8,974** of the 15,340
lot-citing documents; `volume-sources-index.json` `lots` resolves 524 / **8,246**. The
delta is **728 documents across 139 central-files-only keys**, plus **+91 volume
front-matter nodes** (3,024 vs 2,933 of 4,249). Both figures were computable — and the
two-call-site change executable — before the harvest existed. **PR 1 = the repoint. PR 2 =
the fold**, which is worth 2 documents on its own (74D267, 78D26 — also inside the harvest
supplement, so the naive 834 total double-counts them; the correct figure is 832).

**Reachability is narrower than the document count suggests.**
`CollectionGeneratedBlocks.archivalSourceRows` (:475) calls `archivalResolution` once per
`(repository, recordGroup, lotFile, seriesName)` **group** — the 220 central-files-only
lots produce 372 group rows corpus-wide — and only inside the opt-in `.archivalSources`
block of a user-built collection that is then exported. The always-visible half is
`VolumeSourcesView` at **+91 of 4,249 nodes (2.1%)**. Source Explorer already reads
central-files and gains nothing. Nothing is broken today in either surface: the row prints
its label and merely lacks a hyperlink.

**The harvest supplement is 7–20 documents and carries an owner decision.** 24 new lots /
106 documents, of which **13 lots / 84 documents (79%) resolve into a different record
group than the citation names** and fail `isAcceptableLotResolution`
(`NARACatalogHarvestClient.swift:138`) — see N-3. Two lots previously written off as
"numeric-collision noise" are genuine and are the two largest RG-compliant matches:
`428` → naId 2124670 (RG 59, Palestine subject files) and `5226` → naId 2521109 (RG 59,
ISA/MDAP program management), both carrying an `Agency-Assigned Identifier` whose note
reads "This is the Department of State Lot File Number." Excluding them leaves **7**;
keeping the record-group guard and admitting them gives **20**.

**What the harvest genuinely delivers here is validation, worth ~0 documents:** 968 of 971
bundled lots confirmed, **0 NAID disagreements**; `levelOfDescription: series` + HMS/MLR
entries for the 7 volume-sources-only lots (64D171 → 40967113 "P 312"; 78D26 → 824653
"A1 5756"); and proof that **113 bundled lots are control-number-ambiguous** in the catalog
(RG filtering fixes only 4, leaving **1,710 documents** ambiguous; 64D563 alone rides 245
docs across 12 candidate series) — which correctly kills any idea of *regenerating* the
bundle from the harvest. A `VALIDATE_AGAINST_HARVEST=<dir>` tripwire would need the 4.5 GB
extract on disk, so it cannot run in CI or on a fresh clone; the committable form is a
~300 KB derived `lot → NAID` artifact over the 7,634 lot-form keys.

**Two stale premises corrected:** `volume-sources` `lots` now has **zero** fileUnit
entries, and `CentralFilesIndex.untrustworthyNAIDs` is **empty** (0 of 971 flagged), so the
#351 render guard is currently inert.

After N-0's regen: fold volume-sources' surviving lots into central-files at generation
(skipping fileUnit-level entries), repoint the readers to
`CentralFilesIndexStore.lotFile(forRawLot:)`, drop the `lots` map from the volume-sources
artifact — **keeping** `resolution()`'s record-group arm.

**[2026-07-28] Anchors corrected and the reader list completed.** The app sites are
`VolumeSourcesView.swift:291` (the plan said :282, which is a closing brace and never was
the call site) and `CollectionContentResolver.swift:1275–1276` (correct as written). Two
**generator-side** readers were missing from the plan and break if `lots` is dropped
without them: `SourceExplorerExportGeneratorCore/SourceExplorerExportRunner.swift:218`
(the export's diagnostic resolution column) and
`CollectionAuthorityGeneratorCore/OfflineNAIDResolver.swift:57/62–66` (decodes the `lots`
map to feed collection-authority clusters, and carries its own fileUnit guard that becomes
redundant once central-files is the single source). On keeping the record-group arm: it is
not that central-files lacks record groups entirely — each of its 971 lot entries carries
an RG *number* — but it holds no RG *header records*, so volume-sources' 31 resolved RG
headers (170, 200, 218, 319, 383 …) exist nowhere else. Ends the two-parallel-maps risk
(`project_source_explorer_bundle_propagation`).

**N-6 — #235 Simplify NARA Lookup** *(Effort M, app UI)*
Selection → extended-context analysis (look-behind/look-ahead) through the existing
`SourceNoteParser` grammar → candidate resolutions, with today's manual interface as
fallback. **Scope from scratch** — the `NARALookupContext`/`SelectionResolutionAnalyzer`
described in older plan docs was never built (`project_nara_analyzer_unbuilt`). A
candidate-picker card is in the design brief as an optional surface. Natural slot: after
N-1 (parser rules are what the analyzer runs).

**N-7 — #663 link NARA's digitised scans** *(Effort M; NEW 2026-08-02, the highest-value
item in the workstream)*

The harvest holds **10,115,572 digital objects across 17,985 records**, each with a live
`catalog.archives.gov` `objectUrl`. Source Explorer surfaces none of it — the app's
`NARACatalogResult` (`NARACatalogClient.swift:18`) carries seven fields and a digital-object
link is not among them. This is a categorically better outcome than a NAID: a PDF of the
microfilm roll rather than a note about which box to visit in College Park.

**Measured reach:** RG 256 Paris Peace, 537 of 538 file units digitised / 450,105 objects
(the 1,547 documents of N-2 item c); plus RG 59's *Central Decimal Files* (naId 302021 —
2,778 digitised units / 1,530,130 objects) and *Decimal Files* (2555709 — 1,469 / 147,295),
whose file-unit titles are decimal ranges in exactly the form FRUS cites
(`763.72/1476-1635`). Against the 122,033 decimal citations carrying a parsed
`decimal_class`: **9,006 documents (7.4%) have a class with any digitised unit** — the
ceiling — and **7,129 (5.8%) land inside a digitised range** under a partial parser. Call
it **~7,000–9,000 documents**. For scale, the entire bundled lot index resolves 8,974.

**Coverage is front-loaded onto the early twentieth century and must be presented
honestly.** NARA's RG 59 digitisation follows the microfilm publications, so the classes
FRUS cites most have *zero* digitised units — 893 China (10,876 docs), 611 (6,767), 793
(5,780), 711 (5,289) — while classes 131 and 133 (Visa Division, which FRUS barely touches)
are the two most heavily digitised. The UI must say **"scanned microfilm for file range
763.72/1476–1635 (821 pages, PDF)"** — a range, never a document. A wrong range sends the
researcher into the wrong 700-page roll.

**Three smaller fields ride along free** with any bundle refresh: `accessRestriction`
(100% of all 751,880 records; series-level Unrestricted 14,544 / Restricted-Fully 2,773 /
Restricted-Partly 1,904 / Restricted-Possibly 953 — exactly what a researcher planning a
College Park trip needs *before* booking); `inclusiveStartDate`/`inclusiveEndDate` (100% of
the 20,188 series — lets a resolution be date-checked against its own citation);
`findingAids` (3,247 series, 16.1%) and `numberingNote` (385 — NARA's own ordering
instruction, the difference between a request being fillable and being bounced).

**Sequence behind N-2**, whose RG 256 range parser and curation discipline this inherits.
The bundle is ~4,800 rows / <100 KB and committable — but its generator inputs
(`rg_256.json` 170 MB, `rg_59.json` 3.3 GB) are gitignored, so the regeneration path must
be documented or the resource becomes unmaintainable. **[2026-08-04] Documented: the harvest is
unpacked at `/Users/jbotts/Development/nara-record-group-catalog/` (22 shards, 4.5 GB) — see
runbook §2b-1. Both this session and N-2(c) read it directly; neither needs the tarball.**

**Parked:** #405 (creator-org similarity dimension) — **[2026-08-02] measured and it does
not clear the bar.** Creator information reaches only **8,976 of 316,839 corpus documents
(2.8%)**, which is too thin for a Related-Documents axis; the earlier 58.5% figure used
lot-keyed documents as its denominator, which is the wrong one for an axis that must apply
corpus-wide. Separately, a creator gazetteer built from the harvest is actively harmful
(see the finding above). Keep parked; revisit only if a source of creator attribution
appears that is not record-group-scoped.

---

## Workstream O — Onboarding overhaul ("Glass over Word Clouds") — **COMPLETE**

**[2026-07-28] Shipped as PRs #525–#535, plus #537/#540.** Retained below as the record
of what was built and why; nothing here is outstanding. An unplanned drift-engine tail
followed it — see *Delivered since 2026-07-26*.

**Source of truth:** `Planning/Onboarding-Glass-Flow-Plan.md` (2026-07-26), against
`design_handoff_onboarding_glass_flow/` (canonical options **1a, 4a, 4b, 4c**; turns 2–3
are rejected design history). Six sessions, ~8–10 PRs (O-0 is two). This plan does not
restate them.

A full-bleed animated word cloud behind the first-run flow, driven by vectors generated at
build time and bundled, so it renders with zero downloaded volumes — which is what lets the
Add Volumes step preview a scope's vocabulary at the moment the user is choosing what to
download. The handoff also asks for an every-launch splash; recon found its stated trigger does not
exist (the stores open synchronously before first render). **O-0-1 is answered:** the
composition is spent on the first download-and-index wait — minutes long and bare today —
plus a splash restricted to launches with a live reason (fresh install, running CloudKit
import). Never on an ordinary warm start, and the two surfaces are arbitrated so they can
never both claim the screen.

| Session | What it does | Effort |
|---|---|---|
| **O-0** | Two PRs: (1) delete ~770 lines of dead `Onboarding/` code, add characterization tests for the live flow, measure the launch gap; (2) **O-0-2** — `manifest.json` is decoded **twice** before first render (`VolumeLevelTagStore:59` + `ManifestStore:177`); decode once and take 782 KB of main-thread work out of every cold launch | S |
| **O-1** | `WordCloudKit` extraction + `CloudVectorsGenerator` + the two bundled artifacts | L |
| **O-2** | `WordCloudBackdropView`, layout extensions, lens cycle, Reduce Motion | M |
| **O-3** | The cloud outside onboarding: backdrop behind the indexing banners + the occasional splash, under one arbiter | M |
| **O-4** | The three steps in docked glass: segmented scope, transient sheet, scope-reactive backdrop | L |
| **O-5** | Accessibility, both manuals, screenshot rows, acceptance walk-through | S–M |

**Why this lane is cheap to schedule.** It adds **no `@Model` type**, so
`CloudKitSchemaInventoryTests` never fires and no Production schema deploy gates the
release — the release-blocking dependency Q's M-1 and M-2 both carry, and the one R-2b
carries too. It is independent of R-2b. **[2026-07-28] The "only shared file is `FRUSTheme.swift`,
and only additively" claim did not survive the workstream.** The cloud now backs the
search empty/pending state on both platforms (`Search/SearchView.swift:650`,
`App/SearchSheet.swift:688`) via `CloudSurfaceArbiter.searchScope`, so O's output sits
inside Q's own surfaces — recorded as cross-lane edge 3.

**Why it is expensive to slice.** Unlike Q — whose Q-1 ships alone in one small session —
every O screen sits on the backdrop, the backdrop sits on the bundled artifacts, and the
artifacts sit on the generator. The first user-visible increment is O-1 + O-2 + O-4.

**Cross-lane edges:**

1. **O-0 is independent of everything** and worth landing early on its own merits: it
   deletes dead code that two audit backlogs (UI-Audit §A5, `Dynamic-Type-Worklist.md`)
   cite as if it were live, and it covers a 583-line view that today has no behavioural
   tests at all.
2. **O-1's `WordCloudKit` is the fifth generator-adjacent shared target** and starts on
   `GeneratorKit` — so it is a worked example for #270's migration of the older five,
   not an exception to it.
3. **Q-M3 (S-1 keyness) also touches the word-cloud stack.** Keyness extends
   `WordCloudSettingsView` and the frequency path; O-1 extracts the tokenizer beneath it.
   Either order compiles; **O-1 first reads better**, because keyness then lands on the
   shared target rather than being lifted into it afterwards.
4. **No design dependency.** The handoff is settled and accepted; the only open question is
   engineering (O-0-1, the splash premise), and it is answered by a measurement rather than
   by design.

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

### What is left — the live interleave (2026-07-28)

**Two lanes now.** S, O and Wave R (but for R-2b) are complete; the O rows are gone from
this table. One implementer, so the constraint remains review-and-verify bandwidth.

| Slot | Lane | Session |
|---|---|---|
| 1 | Q | **Q-3** fts5vocab + exact-word — *promoted ahead of Q-2, see note* |
| 2 | Q | **Q-1** NEAR |
| 3 | N | **N-8** #674+#675 lot-resolution acceptance test — *jumped the queue: the lane's only correctness defect* |
| 3b | N | **N-1** #353 parser session *(the biggest coverage lever)* |
| 4 | Q | **Q-2** Query Inspector *(consumes Q-3's vocab table for the stem line)* |
| 5 | Q | **R-1** facets — *carrying the pagination prerequisite* |
| 6 | N | **N-2** #354 routing — *now three items, not five* (+ **N-3** curation riding along, after the export re-baseline) |
| 7 | Q | **R-2** + **R-3** |
| 8 | N | **N-7** #663 digitised scans *(inherits N-2's range parser)* |
| 9 | N | **N-5** consolidation · **N-4** now unblocked-with-conditions · **N-6** lookup |
| 10+ | Q · N | M-1 → M-2/M-3; then Q-M3/Q-M5 as appetite allows |

**[2026-08-02] Two things can be pulled forward out of order, because the harvest
measurement detached them from everything else.** **N-5's first half — the repoint — is a
two-call-site change worth 728 documents with no harvest, no regeneration and no
prerequisite**; it can ride any slot as a small PR. And **N-3's Conference Files seed
(~1,425 documents, 22% of the lot gap) needs only one hand-verified row** and does not
depend on N-0's regen, unlike the rest of N-3's ranked curation.

**Why Q-3 moved to the front [2026-07-28].** The session plan always permitted inverting
Q-2 and Q-3 ("Prereq: none (Q-2 consumes it, but the order can invert)"). Doing Q-3 first
gives Q-2's stem line a source of truth — SQLite's own stems via `fts5vocab` — instead of
a second Swift stemmer nothing proves agrees with the index. That was the hazard the
premise re-verification turned up, and reordering is the cheapest way to close it.

**Owner wall-clock is no longer on the critical path.** Both of the slots that carried it
are spent: O-1's corpus generator pass ran, and the Mac index is now effectively the whole
corpus.

**[2026-08-04] And the thing that was said to replace it does not.** This plan asserted
from 2026-07-28 that a `currentDateIndexVersion` bump "costs a multi-hour full reindex", so
any index migration was "a scheduling event in its own right". **Owner-measured: a full
552-volume reindex takes ~10 minutes.** The claim was never measured — the app records no
indexing duration anywhere, so nothing in the repo could have grounded it — and it spread
into the feature-priorities review, where it became the stated reason to batch every
index-shape change into one event. A session that needs a bump should still say so, but it
is a coffee break, not a scheduling constraint, and no work should be deferred or bundled
to avoid paying it twice.

**[2026-08-04] N-0 is complete** — the keyed regen and the export re-baseline both ran on
2026-07-29 (verified against the shipped bundle; see N-0). **No owner-executed step gates
any session in this table**, and the harvest slots 6 and 8 need is unpacked at
`/Users/jbotts/Development/nara-record-group-catalog/` (runbook §2b-1). The one owner wall-clock item left in the lane is
*downstream*: **N-1 changes `SourceNoteParser` output, so it must bump
`currentDateIndexVersion` (now 22) in the same commit**, which triggers a full reindex —
**~10 minutes, owner-measured 2026-08-04**, not the multi-hour figure this document carried
until then. It runs after the PR lands and gates nothing.

**[2026-08-04] R-2b's time gate has opened.** R-2a landed 2026-07-26 (#517, woken by #518)
and shipped in **build 37**, which is in TestFlight — so the migration has had a build in the
field and can now read the rows it converts. R-2b is schedulable; it still carries its own
Production schema deploy through the #488 gate (removing `ResearchSession`/`SessionEvent`
takes `frusModelTypes` from 19 record types to 17), so it needs the R-7 checklist, not just
a slot. **Build 39 has not shipped; nothing in this table waits on it.**

---

## Delivered since 2026-07-26 (unplanned)

Recorded because the plan had no lane for it and because two items change Q's premises.

**Workstream O — complete.** #525/#527 (O-0), #529 (launch screen; #528 landed on a dead
base and was re-landed), #530/#531 (O-1), #532 (O-2), #533 (O-4), #534 (O-3), #535 (O-5),
plus #537 and #540 fixing a backdrop that rendered on no device and moving the indexing
cloud onto the banner.

**A "P" tail — the drift engine.** Owner-requested after O closed: words as particles in
simulated 3-D. #545 (P-1, indexing strip), #549 (P-2, empty search pending state on both
platforms), #551 (fills the frame instead of clumping), #552 (spinner hands over), with
#546/#547/#550 fixing defects introduced inside the same cycle. **This is why the cloud is
now a Q-lane concern** — see cross-lane edge 3.

**Search and indexing performance.** #548 stopped Porter-stemming every word of every
result body — a measured 41 s → ~1.7 s on the macOS worst case, and the origin of the
stem-invariant note in Workstream Q. #541/#542/#543 made the indexing banner queue-grained
and took 552 `stat` calls plus O(n) manifest scans out of the render loop.

**Instrumentation and test infrastructure.** #539/#544 (an in-app frame probe, after three
failed Instruments attempts), #554/#555 (UI-test fixture leak, then an ephemeral store so
no test run can pollute another — the cause of a UI failure that had been misreported as
pre-existing for several PRs).

**A candidate lane, not scheduled.** #536 assessed a bundled lexical-similarity neighbour
index and proposes L-1…L-4 with six queued owner decisions
(`Planning/Lexical-Similarity-Neighbors-Assessment.md`). It competes for the same single
implementer as Q and N; it is listed here so the competition is explicit, not to schedule
it.

---

## Issue disposition

| Issue | Disposition under this plan |
|---|---|
| #368 design pass (doc/analytics/settings) | **Closed 2026-07-28.** Settings → superseded by the North Star handoff (Workstream S). Analytics → delivered by Waves A–C + D1 + D3 (#466–#479). Document view → `ResearchStripView` no longer exists; the rail is collapsible via the C2 titlebar toggle, so the minimum-width complaint is structurally addressed (owner sanity-check on a narrow window before closing). |
| #376 / #353 / #354 / #375 / #355 / #372 / #235 | Scheduled as N-0 … N-6 above. **[2026-08-02] All re-measured against the complete harvest — see the N-wave header. #354 loses two of its five items; #353, #355 and #372's first half lose their harvest dependency entirely.** |
| #674 lot 90 D 234 → Census series · #675 association sweep | **New 2026-08-04.** Scheduled as **N-8** and pulled to the front of the lane: one missing acceptance test on two sides of the resolver (live free-text fallback, and bureau-level lot-number collisions in the bundle). 5 confirmed wrong associations, 28 ambiguous picks over 725 documents, 6,230 documents exposed to the live fallback. |
| #663 digitised-scan links | **New 2026-08-02.** Scheduled as **N-7** — the highest-value item in the workstream (~7,000–9,000 documents, and it delivers an actual page image rather than a NAID). Sequenced behind N-2. |
| #405 | **[2026-08-02] Measured: creator information reaches 2.8% of the corpus, too thin for a Related-Documents axis.** Stays parked; see N-parked. |
| #306 in-chart scrubber | **Not mooted** by the analytics redesign — still a valid enhancement; unscheduled. |
| #268 shared AXChartDescriptor | **Not mooted** — accessibility work, unscheduled here; pairs naturally with any future analytics session. |
| #266 saved-search freshness | Adjacent to Q-M4 (M-2's log knows last-run hit counts **once `resultCount` records whether the count was exact — see Decision E's defect 2**) — fold into M-2's decision points rather than scheduling separately. |
| #308 / #261 / #260 / #259 / #234 | FRUS-subjects & person-authority programs — untouched by this plan. |
| #262 / #263 / #265 / #279 / #312 / #358 / #553 | Backlog, untouched. |
| #270 GeneratorKit migration | Still backlog, but O-1's new `WordCloudKit`/`CloudVectorsGenerator` starts on `GeneratorKit` — a worked example for the older five rather than a sixth exception. |
| #106 screenshot checklist | **[2026-07-28] Not delivered by O-5** — the Onboarding plan's own closeout still lists the ⚙️ fresh-install captures as owner-open. Now **unscheduled**; needs a small follow-up rather than riding a closed workstream. |

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
