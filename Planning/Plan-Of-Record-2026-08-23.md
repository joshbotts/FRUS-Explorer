# Plan of Record — 2026-08-23, the next wave

**Status:** the single live plan, superseding `Completed/`-bound `Plan-Of-Record-2026-08-17.md`
(discharged in full — every session row shipped; its final state and per-row evidence stay in
that file and in `DEVELOPMENT-PLAN.md`'s 2026-08-23 audit entry). Written from the owner's wave
decision of 2026-08-23, against tree `75c5d40c` and the audit PR #1076.

**How to keep this current:** when a session ships, strike its row in §3 and update the issue.
When this document's sequencing is overtaken, replace it the way it replaced its predecessor.

---

## 1. Ship first: TestFlight build 43

The owner ships the current v2 as **build 43** after reviewing `Docs/EditableContent.md`.
Everything is already in place: `CURRENT_PROJECT_VERSION` is 43 in both `project.yml` and
`project.pbxproj` (bumped in #956), the four tester-facing docs were reconciled with everything
since build 42 (#1075 — including the six index changes forcing a first-launch re-index, which
the notes disclose), and `identifiersAwaitingDeploy` is empty. No engineering precedes the ship.

## 2. The standing gate

**Build-43 tester feedback outranks the order below when it lands** — above all the
clusters/semantic-map **leads-or-noise verdict**, which the What-to-Test notes now put to
testers directly (cluster membership in Browse, the map, the weighted matches). Consequences
are pre-decided: if the verdict demotes the map, removing the Clusters tile is one clean
commit (recorded in `Completed/Browse-Axes-Development-Plan.md`), and §3's W-9/W-10 semantic
re-entry should be re-argued before it is built rather than after.

## 3. The wave

Sessions are sized for one working session each unless noted. Order within a tier is
suggested, not binding; tiers A/B/C/D can interleave as owner inputs land.

### Tier A — ready-to-schedule engineering (unblocked today)

| # | Session | Scope | Gate |
|---|---|---|---|
| W-1 | **#1014 step 1: measure the bare-`Ibid.` gap** | Run the in-code harness (`MEASURE_DECIMAL=1`, `ExternalCitationIndexRunner`) to measure bare-`Ibid.`-after-class within `ibidReach` per era band — the 2,600 figure is an extrapolation and unquotable. Changes no artifact. Ends with a go/no-go on the issue. | Owner machine (needs `VOLUMES_DIR`) |
| W-1b | **#1014 step 2, if go** | The inheritance rule in `FootnoteCitationGrammar`, artifact regeneration, `external_citations` re-index (v46 → 47), `SAMPLE_OUTPUT` read before trusting the run. **This is the wave's index-content batch anchor** — #279's index half boards the same bump (W-4), per the one-bump-per-wave rule. | W-1's verdict; batches with W-4 |
| W-2 | **Cross-platform review: the four owed items** | The only tracker is `Cross-Platform-UI-Adversarial-Review/STATUS.md`, untouched since #924: M-2's Source Explorer half (a value-based window beside the graph's), CW-12 (macOS text scaling, window-fronting audit, iPad probes), the semantic-map slice-poles Handoff deferral (`requestedPoles`), and CW-11 re-capture *prep* (the shot list; captures are owner-lane). | none |
| W-3 | **Semantic-map figure export** | Execute `Map-Figure-Export-And-Visual-Outputs.md` (#1007) — the offscreen Metal render path that lifts `SemanticMapExport`'s "No figure, deliberately" refusal with publication-quality output. | none |
| W-4… (see Tier B) | | | |
| W-6 | **#106 reconciliation** | Rewrite the 166-row, three-doc-generations-stale checklist down to the **13 live `[SCREENSHOT` placeholders** now in the manuals (8 browse-axes, trip packet ×2, iPad rail ×2, macOS Corpus Browser) + `Docs/screenshots/README.md`'s tier list; strike the cancelled rows; note the unreferenced `macos/collections-ribbon.png` and the never-committed Settings-tier spec. Capture stays owner-lane. | none |

### Tier B — the two O-design features (design, then build)

| # | Session | Scope | Gate |
|---|---|---|---|
| W-4 | **#279 per-document classification override** | O-4 design first (reversible override; what honors it; the un-override path + anomaly warnings). Build: the stored override (CloudKit field → R-7 checklist), the honoring surfaces, tests. **Index half boards W-1b's bump** (it has already missed four: v41/42/44/46). Known traps on record: `ProjectLeadEntry.isEditorialNote` is a second synced source of truth; bundled analytics artifacts structurally cannot see an override. | **O-4 (owner)** |
| W-5 | **#266 saved-search freshness** | O-5 design first (a "new" definition that survives reindex — no index-side timestamp exists). Build: the CloudKit field, the off-main evaluate, badges on the three saved-search surfaces. Design landmines on record: cross-device watermark semantics; capped fetches make naive "N new" a floor. | **O-5 (owner)** |
| — | **One Production promotion for both** | R-2b's no-deploy finding (#981) dissolved the old §4.5 batch — these two are now each other's ONLY schema-batch partner. Whichever lands first should wait for the other's field unless the owner decides otherwise; the promotion itself is the owner's Dashboard step per the R-7 checklist. | both designs |

### Tier C — the harvest lane (owner's Mac Studio; #234 and pre-1910 together)

| # | Session | Scope | Gate |
|---|---|---|---|
| W-7 | **#234 early-era people — the NER harvest and what it feeds** | The owner runs the detector harvest on the Mac Studio (`tools/semantic-harvest/NER-RUNBOOK.md`; the free NLTagger control `EarlyEraNERControl` prices the comparison). **The program's §5 gates still bind**: scoring needs the two ground-truth keyings — the M1a identity CSV (`Planning/early-era-people/m1a-eval-candidates.csv`, 300 rows, 0 keyed) and the M2a span sample (`stage_m2a.py` stages it; the scorer refuses to run without `m2a-ground-truth.jsonl`). Sequence: keyings + harvest → `score_detections.py` (detector vs control vs editors' own markup) → then M1b reconciliation, R-2/R-3 (clustering + adversarial review), R-4 bundled artifact, M3 UI. Multiple sessions; the first schedulable engineering is the scoring session once ground truth + a `detected/` store exist. | **Owner: 2 keyings + the harvest run** |
| W-8 | **Pre-1910 Phase-3 tail harvest** | The consular series the June 2026 harvest deliberately left: Instructions (604019), Notes to/from Foreign Consuls (1076611 / 1076629), Domestic & Miscellaneous Letters, Special Agents — all registered as `SURVEY_SERIES` targets in CLAUDE.md's `CentralFilesIndexGenerator` entry. Survey first, then harvest into `central-files-index.json` (schema 3 already accommodates), then the downstream regeneration chain per CLAUDE.md's run order. The executed plan and its reference data are archived at `Completed/BigPicture-Pre1910-CentralFiles.md` + `Completed/Pre1910-CentralFiles-Reference-Data.md` — the method and golden checks live there. Also carries the two minor June leftovers recorded at retirement: enclosure dual-home rendering, and a live UI walkthrough of the classifier surfaces. | Owner machine + `CATALOG_API_KEY` |

### Tier D — the semantic re-entry (order binding, from the V-5 assessment §6)

| # | Session | Scope | Gate |
|---|---|---|---|
| W-9 | **V-5 free-text semantic search, by its own sequence** | The re-entry order is written at `Planning/semantic-vectors/V5-Query-Encoder-Assessment.md` §6 and binds: (1) `CSUserQuery` `textContent` first (the cheap Spotlight-native half), (2) the honest evaluation instrument — whose "positives independent of lexical overlap" requirement the doc-grain subject index (#1016) may now satisfy, which was the missing piece when V-5 was deferred, (3) PRF, (4) the query encoder itself last. | Favorable leads-or-noise verdict (§2) |
| W-10 | **OS-27 adoption** | From sketch (`OS27-Semantic-Retrieval-Design.md`) to code exercised against the actual SDK. Scope the first session as an assessment-against-the-beta rather than a build. | SDK availability; after or beside W-9's step 1 |

## 4. The owner lane

| Item | Feeds |
|---|---|
| Review `EditableContent.md`, ship build 43 | §1 |
| O-4 design (one page: what an override is and who honors it) | W-4 |
| O-5 design (one page: what "new" means across devices and reindexes) | W-5 |
| The two #234 keyings (M1a identity CSV; M2a span sitting) + the Mac Studio NER harvest | W-7 |
| Pre-1910 Phase-3 harvest runs (keyed) | W-8 |
| VoiceOver on-device pass (adoption shipped, #979) | quality |
| Screenshot captures, after W-6 delivers the reconciled 13-shot list | #106 |
| Release habits: `Scripts/check_repository_links.py --stamp`; eyeball the 3 owner-asserted URLs (JFK ×2, LBJ) | each release |
| CloudKit Production promotion for the W-4+W-5 fields (one Dashboard step, batched) | Tier B |

## 5. Closed as unplanned in this wave decision

**#626** (user-editable AI summaries beyond headnotes) — closed 2026-08-23; nothing was built,
the substrate (`SummaryAuthorship`) remains, and the closure comment records the two defects a
revival must fix first. Re-file from the issue if wanted later.

## 6. Backlog — awaiting the owner's disposition

Carried from the discharged plan's §6, reminded to the owner 2026-08-23; **each is either
scheduled into a future wave or closed as unplanned by the owner — none is scheduled here**:

1. **Declassification-gap explorer** (Feature-Priorities §5a.1) — surface the "not declassified" /
   "not printed" markers as data: per-document redaction flags, density by volume/era/topic, a
   browsable not-printed list, plus an MDR/FOIA request-draft generator. One new indexing pass —
   would board W-1b's bump if scheduled now.
2. **Previously-published outbound resolver** (§5a.3) — turn the `previouslyPublished` panel's
   "consult the cited publication" dead end into deep links (Bulletin, Public Papers, UST/TIAS,
   serial set). Cheap; reuses the existing parse.
3. **Parallel-series concordance** (§5a.4) — a curated volume-level map to DBPO/DDF/AAPD/Dodis.
   Needs its own scoping doc first.
4. **Telegram-thread reconstruction** (§5b.5) — Deptel/Embtel chains as a Related axis. Highest
   research delight on the list; needs its own scoping doc + eval baseline.
5. **Coverage map / systematic-review mode** (§5c.6) — "opened 43 of 267" + an exportable
   coverage statement completing the method appendix. Small; no schema change.
6. **Computational dataset export** (§5c.7) — a working corpus as text+metadata+provenance
   bundle for Python/R users. An exporter session.
7. **Read-aloud** (§5d.8) — `AVSpeechSynthesizer` over the render tree. Small-to-medium.
8. **Collection → static-site publish** (§5d.9, minor) — extend the HTML export to a site bundle.
9. **Analytics priorities 8/10/11/12** (BigPicture-Analytics) — geographic/topic charts + the
   administration analytics axis; `place_mentions` (a schema change); per-document "More like
   this"; VIAF/Wikidata enrichment (the only external-fetch item).
10. **Lexical similarity as a query** (Lexical assessment §0) — the withdrawn-as-artifact
    verdict allows a query-time variant.
11. **Hosted quick-start index** (PreIndex 2026-05) — the semantic shard repo has since proven
    the hosting channel.
12. **Restoration depth §B/§C** — `@SceneStorage` navigation paths; macOS window-content
    restoration (M-21's deferred mechanisms). §B notes `SearchParameters` is not `Codable`.
13. **Q&CA dispersion statistic** — `FTS5Vocabulary.occurrencesPerDocument` is built and has
    zero app callers (verified 2026-08-23); either surface it or delete it.
14. **Cross-platform port** — strategic reference only (`Completed/Cross-Platform-Porting-Assessment.md`).
