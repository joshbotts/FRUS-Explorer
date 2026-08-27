# Plan of Record — 2026-08-23, the next wave

**Status:** the single live plan, superseding `Completed/`-bound `Plan-Of-Record-2026-08-17.md`
(discharged in full — every session row shipped; its final state and per-row evidence stay in
that file and in `DEVELOPMENT-PLAN.md`'s 2026-08-23 audit entry). Written from the owner's wave
decision of 2026-08-23, against tree `75c5d40c` and the audit PR #1076. **Refreshed
2026-08-26 against tree `2ea5c100`** — build 43 shipped, and three rows were overtaken by
work merged after the plan was written (W-6 discharged, W-7 re-sequenced, W-1 re-scoped);
see the strikes and the notes on those rows.

**How to keep this current:** when a session ships, strike its row in §3 and update the issue.
When this document's sequencing is overtaken, replace it the way it replaced its predecessor.

---

## 1. Ship first: TestFlight build 43 — ~~SHIPPED 2026-08-24~~

**Discharged.** Tagged `build-43` at `ad920cff` (annotated; `git show build-43` carries the
headline, the re-index requirement, the CloudKit position and where the tester notes live),
release record in `DEVELOPMENT-PLAN.md` via #1079, content pass via #1078. The link check ran
clean and stamped 2026-08-24. **Still owner-only: the VoiceOver pass and the App Store Connect
archive-and-upload** — nothing in the repo can perform or attest to either.

~~The owner ships the current v2 as **build 43** after reviewing `Docs/EditableContent.md`.
Everything is already in place: `CURRENT_PROJECT_VERSION` is 43 in both `project.yml` and
`project.pbxproj` (bumped in #956), the four tester-facing docs were reconciled with everything
since build 42 (#1075 — including the six index changes forcing a first-launch re-index, which
the notes disclose), and `identifiersAwaitingDeploy` is empty. No engineering precedes the ship.~~

## 2. The standing gate

**Build-43 tester feedback outranks the order below when it lands** — above all the
clusters/semantic-map **leads-or-noise verdict**, which the What-to-Test notes now put to
testers directly (cluster membership in Browse, the map, the weighted matches). Consequences
are pre-decided: if the verdict demotes the map, removing the Clusters tile is one clean
commit (recorded in `Completed/Browse-Axes-Development-Plan.md`), and §3's W-9/W-10 semantic
re-entry should be re-argued before it is built rather than after.

## 3. The wave

Sessions are sized for one working session each unless noted. Order within a tier is
suggested, not binding; tiers A–E can interleave as owner inputs land.

### Tier A — ready-to-schedule engineering (unblocked today)

| # | Session | Scope | Gate |
|---|---|---|---|
| W-1 | **#1014 step 1: measure the bare-`Ibid.` gap** | **Re-scoped 2026-08-26 — the first action is to WRITE a measurement mode, not to run one.** The row previously read "run the in-code harness (`MEASURE_DECIMAL=1`)"; verified against the tree, that harness counts only what `FootnoteCitationScanner.classCandidates(inNote:)` returns, and that function (a) takes a **single note** so it cannot see the preceding footnote that `ibidReach` is measured against, and (b) requires a decimal class **inside the clause**, so a bare `Ibid.` yields zero candidates and is structurally invisible to it. `FootnoteCitationGrammar`'s document-ordered `Ibid.` state exists for the **lot/library** scanner, not for this one. So: add cross-footnote state to the measurement pass, then measure bare-`Ibid.`-after-class within `ibidReach` per era band — the 2,600 figure is an extrapolation and unquotable. Changes no artifact. Ends with a go/no-go on the issue. | Owner machine (needs `VOLUMES_DIR`; present, 694 volumes) |
| W-1b | **#1014 step 2, if go** | The inheritance rule in `FootnoteCitationGrammar`, artifact regeneration, `external_citations` re-index (v46 → 47), `SAMPLE_OUTPUT` read before trusting the run. **This is the wave's index-content batch anchor** — #279's index half was expected to board the same bump (W-4), but the shipped W-4 design applies overrides AFTER parsing (a replay over the existing index), so it has no bump to batch and W-1b's is its own again. | W-1's verdict; batches with W-4 |
| ~~W-18~~ | ~~**#830 packet: the external-references section**~~ *(added 2026-08-25, owner request)* — **DELIVERED 2026-08-26, in the revised shape Archive Visits Phase 1 mandated** | Shipped as the Archive Visits Phase 1 pointed-at channel (`Planning/Archive-Visit-Plan-Design.md` §3d names this row and revises its rendering): the reading list batches through `IndexingPipeline.externalCitationsByKey` (the `documentSourcesByKey` shape, as this row asked), lots resolve through the same `ArchivalResolver` route, `inherited` rows disclose the `Ibid.`, and unresolved rows route into the advance inquiry — all as written here. **One revision, by design decision rather than drift**: not a separate per-repository section but per-seeding itemization *with the claim stated* inside each target row — the §3d argument is that this is the *stronger* form of the #783 separation (evidence grain, not layout grain), and two rules the tests pin keep it honest: counts never sum across claims, and the two claim groups render visibly distinct. This row's "never folded into chapter 3's pull rosters" clause was written when the roster was the artifact; the roster itself left with chapter 3. W-1b's inheritance rule still enriches the same table — when it lands, the packet's pointed-at channel picks it up with no further work. | ~~—~~ |
| W-2 | **Cross-platform review: the four owed items** | The only tracker is `Cross-Platform-UI-Adversarial-Review/STATUS.md`, untouched since #924: M-2's Source Explorer half (a value-based window beside the graph's), CW-12 (macOS text scaling, window-fronting audit, iPad probes), the semantic-map slice-poles Handoff deferral (`requestedPoles`), and CW-11 re-capture *prep* (the shot list; captures are owner-lane). | none |
| W-3 | **Semantic-map figure export** | Execute `Map-Figure-Export-And-Visual-Outputs.md` (#1007) — the offscreen Metal render path that lifts `SemanticMapExport`'s "No figure, deliberately" refusal with publication-quality output. | none |
| W-4… (see Tier B) | | | |
| ~~W-6~~ | ~~**#106 reconciliation**~~ — **DONE 2026-08-24, struck 2026-08-26** | The deliverable shipped as **#1081** ("Screenshot checklist — current manuals and README"), which re-keys the checklist to the current manuals and covers all **13 live `[SCREENSHOT` placeholders** (11 in the iOS manual, 2 in the macOS manual — counted 2026-08-26). #106 was closed NOT_PLANNED the same day, superseded by it. #1081 also adds an owner decision this row did not anticipate — *every committed capture is treated as stale* — which supersedes the tier list in `Docs/screenshots/README.md`. **Consequence: the owner-lane capture row is unblocked today**, because the reconciled list it waited on now exists. | ~~—~~ |

### Tier B — the two O-design features (design, then build)

| # | Session | Scope | Gate |
|---|---|---|---|
| ~~W-4~~ | ~~**#279 per-document classification override**~~ — **SHIPPED 2026-08-26** (with W-5, one PR) | Delivered per the O-4 decisions (`Planning/Completed/W4-Classification-Override-Design.md`): the owner chose **"also restyle the body"** over metadata-only, so the override rewraps the AST's `.editorialNote` shape on render, beside the one-seam `document_cache.is_editorial_note` apply that every filter/facet/count reads. Replay-not-clobber (boot + per-volume, the summaries/notes pattern); rail control + corrections manager (Settings ▸ Search) + anomaly warning; both known traps handled (leads read through a live `@Query`; the bundled-artifact blindness is disclosed in the warning). **The W-1b index-bump clause proved moot**: the override applies AFTER parsing, so parse output is unchanged and no index-version bump exists to batch. 7 identifiers await the reserved promotion. | ~~—~~ |
| ~~W-5~~ | ~~**#266 saved-search freshness**~~ — **SHIPPED 2026-08-26** (with W-4, one PR) | Delivered per the O-5 decisions (`Planning/Completed/W5-Saved-Search-Freshness-Design.md`): watermark = **synced count baseline** on the record ("new since you last ran it anywhere"); badge = **NEW capsule + exact "+N since last run"** — safe because the delta derives from the uncapped `searchCount`, which defuses this row's floor landmine outright; plus the owner's third decision, `lastModified` on `SavedSearch` (the merge tiebreaker the record never had, now stamped by `ModelModificationStamper`). Stamps at the three recall surfaces; sequential cancellable evaluation on appear. 2 identifiers await the reserved promotion. | ~~—~~ |
| — | **One Production promotion for both** | R-2b's no-deploy finding (#981) dissolved the old §4.5 batch — these two are now each other's ONLY schema-batch partner. Whichever lands first should wait for the other's field unless the owner decides otherwise; the promotion itself is the owner's Dashboard step per the R-7 checklist. | both designs |

### Tier C — the harvest lane (owner's Mac Studio; #234 and pre-1910 together)

| # | Session | Scope | Gate |
|---|---|---|---|
| W-7 | **#234 early-era people — the NER harvest and what it feeds** | **Re-sequenced 2026-08-26 by #1083.** The old sequence ("keyings + harvest → `score_detections.py`") and gate ("Owner: 2 keyings + the harvest run") put the ~18-day Studio sweep on the scoring path. It is not on it: `stage_m2a.py`'s wider draw shares **zero volumes** with M1a's pilot twelve, so the existing `detected/` stores cover **0 of the 72 gold documents**, and the runbook now records that "the full sweep is not needed for scoring at all: it is what the scoring verdict authorizes, never its input." **This applies to the free control store too** — it has the same 12-volume scope, so it also needs a targeted re-run (cheap: the Swift control already supports `ONLY_DOCUMENTS`). Scoring instead needs a targeted ~90-chunk / **~8-minute** pass over exactly the gold documents. **There is now schedulable engineering BEFORE the keyings** — see W-7a. After scoring: M1b reconciliation, R-2/R-3 (clustering + adversarial review), R-4 bundled artifact, M3 UI. **The program's §5 gates still bind** (M1a CSV: 300 rows, **0 keyed**, re-counted 2026-08-26; M2a: staged but un-keyed). | **Owner: the M2a sitting** (+ the M1a keying for the separate identity half). The sweep is no longer a gate. |
| W-7a | **#234 harness prerequisite — `ONLY_DOCUMENTS` + a worker pool** *(new 2026-08-26, from #1083)* | Two changes to `tools/semantic-harvest/harvest_ner.py`, both unblocked and both on the critical path. (a) **`ONLY_DOCUMENTS`** — restrict a run to an `m2a-ground-truth.jsonl`'s documents and record `sampled_doc_ids`, without which the scorer refuses the store; the Swift control already implements exactly this (`EarlyEraNERControlRunner`), so the shape is settled and the Python side is a port. Verified 2026-08-26: the identifier appears in **no** Python file under `tools/semantic-harvest/`. (b) **`WORKERS`** — a per-volume thread pool merging results in chunk order, selftest-pinned to write a byte-identical store at any width; the probe measured 3.92× at 4 workers with the knee at 4. Pin both in `selftest_harvest_ner.py`. | None — engineering only |
| W-8 | **Pre-1910 Phase-3 tail harvest** | The consular series the June 2026 harvest deliberately left: Instructions (604019), Notes to/from Foreign Consuls (1076611 / 1076629), Domestic & Miscellaneous Letters, Special Agents — all registered as `SURVEY_SERIES` targets in CLAUDE.md's `CentralFilesIndexGenerator` entry. Survey first, then harvest into `central-files-index.json` (schema 3 already accommodates), then the downstream regeneration chain per CLAUDE.md's run order. The executed plan and its reference data are archived at `Completed/BigPicture-Pre1910-CentralFiles.md` + `Completed/Pre1910-CentralFiles-Reference-Data.md` — the method and golden checks live there. Also carries the two minor June leftovers recorded at retirement: enclosure dual-home rendering, and a live UI walkthrough of the classifier surfaces. | Owner machine + `CATALOG_API_KEY` |

### Tier D — the semantic re-entry (order binding, from the V-5 assessment §6)

| # | Session | Scope | Gate |
|---|---|---|---|
| W-9 | **V-5 free-text semantic search, by its own sequence** | The re-entry order is written at `Planning/semantic-vectors/V5-Query-Encoder-Assessment.md` §6 and binds: (1) `CSUserQuery` `textContent` first (the cheap Spotlight-native half), (2) the honest evaluation instrument — whose "positives independent of lexical overlap" requirement the doc-grain subject index (#1016) may now satisfy, which was the missing piece when V-5 was deferred, (3) PRF, (4) the query encoder itself last. | Favorable leads-or-noise verdict (§2) |
| W-10 | **OS-27 adoption** | From sketch (`OS27-Semantic-Retrieval-Design.md`) to code exercised against the actual SDK. Scope the first session as an assessment-against-the-beta rather than a build. | SDK availability; after or beside W-9's step 1 |

### Tier E — backlog admissions (owner disposition, 2026-08-23)

Six of the fourteen §6 backlog ideas were admitted to the wave; two are assessments whose
deliverable is a scoping verdict, not code.

| # | Session | Scope | Gate |
|---|---|---|---|
| W-11 | **Previously-published outbound resolver** | Turn the `previouslyPublished` panel's "consult the cited publication" dead end into deep links — *Department of State Bulletin* (Internet Archive/HathiTrust), *Public Papers of the Presidents* (American Presidency Project, govinfo), UST/TIAS treaties, the Congressional serial set. A small citation grammar over the already-classified SourceNoteKit parse plus a bundled link table; the presidential-library link work is the shape precedent, and the D12-style stamped-link rules apply to any URL it prints. | none |
| W-12 | **Parallel-series concordance — ASSESSMENT** | A scoping doc, not a build: what a curated volume-level concordance to DBPO (UK), DDF (France), AAPD (Germany), Dodis (Switzerland — open API), and the Wilson Center Digital Archive would contain; what the taxonomy's era/region tags can and cannot key; the curation cost per series; and the honest boundary (document-level alignment is a research project and stays out). Ends with a build/no-build recommendation for the owner. | none |
| W-13 | **Coverage map / systematic-review mode** | "You have opened 43 of the 267 documents in this working corpus — 12 annotated, 224 unread; here they are," computed from `ExportHistoryEntry` + `ProjectEngagedDocuments`, plus an exportable coverage statement completing the method appendix (searched → examined). No schema change. | none |
| W-14 | **Read-aloud** | `AVSpeechSynthesizer` over the render tree — skip footnotes, track position, honor the read-vs-research mode split. Purely additive; serves commuters and low-vision users beyond VoiceOver's posture. | none |
| W-15 | **Geographic/analytics — ASSESSMENT, with historical toponymy first-class** | Assess BigPicture-Analytics priorities 8/10/11/12 together, with the owner's stated requirement: the geographic derivation must take **changing historical place names** into account — the corpus spans 1861–1988, and Constantinople/Istanbul, St. Petersburg/Petrograd/Leningrad, Persia/Iran, Siam/Thailand, Danzig/Gdańsk-class renames mean era-correct names must reconcile to stable places or every regional chart double-counts. The assessment decides: which of the four proceed; how a `place_mentions` table (P10 — the schema change) encodes name-at-date vs. place identity; whether P11's "More like this" still earns a slot beside the shipped semantic Related axis; and P12's external-fetch posture. P10, if it proceeds, boards W-1b's index bump or the next one. Ends with a per-priority recommendation. | none |
| W-16 | **Dispersion statistic: surface or delete** | `FTS5Vocabulary.occurrencesPerDocument` is built with zero callers (verified 2026-08-23). Either surface it where it earns its keep — the Query Inspector is the natural home — or delete it so the vocabulary type stops carrying dead API. XS. | none |
| W-17 | **Lexical similarity as a query** | The approved query-time variant from the withdrawn-artifact verdict (`Completed/Lexical-Similarity-Neighbors-Assessment.md` §0/§9): extract the anchor's top TF-IDF terms (`fts5vocab` supplies df) and run a BM25 OR-query — "more like this" with no bundled artifact. Ship as a Related axis defaulting to weight 0, with the recorded costs stated on-surface (indexed volumes only; results vary with library composition). **Sequence beside W-9's instrument step** so the lexical and semantic routes are judged by the same measure instead of shipping un-compared — and it is the standing fallback if the semantic verdict disappoints. | none (evaluation pairs with W-9) |

## 4. The owner lane

| Item | Feeds |
|---|---|
| ~~Review `EditableContent.md`, ship build 43~~ — **done 2026-08-24** (#1078, tag `build-43`); the **VoiceOver pass** and the **App Store Connect archive-and-upload** remain owed | §1 |
| ~~O-4 design (one page: what an override is and who honors it)~~ — **decided 2026-08-26** (4-question sitting; recorded in `Planning/Completed/W4-Classification-Override-Design.md`) | W-4 |
| ~~O-5 design (one page: what "new" means across devices and reindexes)~~ — **decided 2026-08-26** (same sitting; recorded in `Planning/Completed/W5-Saved-Search-Freshness-Design.md`) | W-5 |
| The two #234 keyings — M1a identity CSV (0/300) and the **M2a span sitting**, which is the one on the critical path. Staged at `~/frus-m2a` **on the Mac Studio**, so the sitting happens there (or re-stage locally; `stage_m2a.py` is `SEED`-pinned, so a re-stage is deterministic). The NER sweep is **no longer a gate** — see W-7. | W-7 |
| Pre-1910 Phase-3 runs — **`CATALOG_API_KEY` is needed for BOTH the survey (`SURVEY_SERIES=…`) and the harvest**, not the harvest alone | W-8 |
| VoiceOver on-device pass (adoption shipped, #979) | quality |
| Screenshot captures — **unblocked 2026-08-24**: the reconciled list exists as **#1081** (13 live placeholders), and its owner decision treats every committed capture as stale | #1081 |
| Release habits: `Scripts/check_repository_links.py --stamp`; eyeball the 3 owner-asserted URLs (JFK ×2, LBJ) | each release |
| ~~CloudKit Production promotion for the W-4+W-5 fields (one Dashboard step, batched)~~ — **DEPLOYED 2026-08-26, the EIGHTH promotion**: the owner exercised each new type/field on a Development build and promoted the whole 41-identifier block (Archive Visits Phase 2's 32 + W-4's 7 + W-5's 2) in one Dashboard step. `identifiersAwaitingDeploy` cleared; baseline restated 219 → 260 (digest per the suite); `deployedThroughBuild` 40 → 43, `deployedOn` 2026-08-26. Production matches the build again — archive visit plans, classification overrides, and saved-search freshness all sync | ~~Tier B~~ |

## 5. Closed as unplanned in this wave decision

**#626** (user-editable AI summaries beyond headnotes) — closed 2026-08-23; nothing was built,
the substrate (`SummaryAuthorship`) remains, and the closure comment records the two defects a
revival must fix first. Re-file from the issue if wanted later.

## 6. Backlog — DISPOSITIONED (owner, 2026-08-23)

The fourteen ideas carried from the discharged plan's §6, each ruled on by the owner. Seven
are admitted to the wave (Tier E, W-11…W-17); one is deferred indefinitely; six are closed as
unplanned. Nothing here is silently dropped — every closed item keeps its archive pointer and
can be revived by re-arguing it, not by claiming it was forgotten.

**Admitted → Tier E** (see §3): #2 previously-published resolver (W-11) · #3 parallel-series
concordance *as an assessment* (W-12) · #5 coverage map (W-13) · #7 read-aloud (W-14) ·
#9 analytics priorities 8/10/11/12 *as an assessment, with changing historical place names a
first-class requirement* (W-15) · #13 dispersion surface-or-delete (W-16) · #10 lexical
similarity as a query (W-17, its evaluation paired with W-9's instrument so the lexical and
semantic routes are judged by one measure).

**Deferred indefinitely** (owner's word — not closed, not scheduled):

- **#1 declassification-gap explorer** (Feature-Priorities §5a.1) — the "not declassified" /
  "not printed" markers as data, density views, the not-printed list, the MDR/FOIA draft
  generator. If ever revived it needs one indexing pass and should board whatever index bump
  is next open (W-1b's, if still pending).

**Closed as unplanned** (archive pointers; revive by re-arguing):

- **#4 telegram-thread reconstruction** (§5b.5) — the Deptel/Embtel exchange axis.
- **#6 computational dataset export** (§5c.7) — the text+metadata+provenance bundle.
- **#8 collection → static-site publish** (§5d.9).
- **#11 hosted quick-start index** (`Completed/PreIndex-Feasibility.md`) — noting for any
  revival that the semantic shard repo proved the hosting channel, and the maintenance cost is
  tracking `currentDateIndexVersion` (four bumps this month alone).
- **#12 restoration depth §B/§C** (`Completed/Restoration-Depth-Design.md`) — `@SceneStorage`
  paths and macOS window-content restoration; the shipped resume-reading affordance stands as
  the accepted depth.
- **#14 cross-platform port** (`Completed/Cross-Platform-Porting-Assessment.md`) — remains a
  strategic reference; Route B is the recorded answer if the question ever goes live.
