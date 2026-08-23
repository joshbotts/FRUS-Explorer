# Subjects Integration Follow-up Plan — issues #1021–#1030

*Drafted 2026-08-21 against v2 `b5fd7711`. Every issue premise re-verified at that tip by a
five-agent scoping pass (four clusters + an interactions critic); anchors below are current, not
the possibly-drifted ones in the issue bodies. Scope: the eight issues left open by the subjects
wave (#1018/#1028/#1031). #1019 (the zero-headroom timing budget) is adjacent but out of scope here.*

## 1. The shape of the work

Three sessions, ~9 PRs. The ordering is driven by five hard constraints the scoping verified:

1. **#1025 must be measured BEFORE #1021 merges.** #1021 is the switch that turns the unpriced
   `SharedSubjectScorer` cost from latent to live for every existing user
   (`RelatedDocumentsEngine.swift:225` skips zero-weighted scorers today). Pricing it after
   activation means measuring a regression already shipped.
2. **#1024 precedes #1022-A and #1023** — all three build in `DocumentSubjectStore.swift`, and the
   surface work should land on a settled `score` contract.
3. **#1027 precedes #1023** — both edit `VolumeSubjectVolumesSheet`, and #1027's extracted
   membership resolver is exactly what #1023's pivot-sheet entry point inherits.
4. **#1022-B (the filter-only allowlist) precedes #1023's hand-off** — and is independently
   shippable *now*: the bucket predicate already has end-to-end SQL support
   (`IndexingPipeline.swift:3324`), so bucket-only standalone queries work with no schema change.
5. **#1021 precedes #1030** — the corrected copy describes the post-#1021 reality, and #1021's own
   doc-block rewrite (`RelatedDocumentsView.swift:13–36`, still saying "all six axes" at :27) is
   what lets #1030 stay purely user-facing prose.

Two owner rulings gate Session C entirely (P1, P2 below); everything else has a recommendation and
can proceed on "as recommended".

## 2. Owner decisions

| # | Decision | Blocks | Recommendation |
|---|---|---|---|
| **P1** | **#261 gate.** Is document-level tagging "refined" per D1, discharged by the #308 Phase-3 corrected export — or does the surface wait for #261's own never-executed steps 1–3 (upstream ask, blocklist filter, 11-volume pilot)? | all of #1023 | Genuinely the owner's call; the data shipped and is honest about being recall-oriented, but #261's process was skipped, not passed |
| **P2** | **Subjects view entry points.** (ii) pivot-sheet "browse this subject" + (iii) Browse-tab row beside People are D1-clean. (i) a facet-row affordance is cheap but mixes bucket and subject grain in one gesture. (iv) any rail affordance requires explicitly amending D1. | #1023 | (ii)+(iii); defer (i); (iv) only by explicit D1 amendment |
| **P3** | **#1022 grain mechanism.** Parallel `document_subject_refs` table (~46 MB total both grains; #1018's facet queries, tests and measured pins untouched) vs replacing the bucket table with subject grain + a 106-row map join (+3.8 MB net; rewrites every #1018 facet query and its measured doc comments). | #1022-A | Parallel table |
| **P4** | **#1021 missing-axis semantics.** Backfill defaults in `init?(rawValue:)` only (persistence boundary; keeps the subscript's documented missing-reads-0 and `AxisWeightResetTests:104`) vs flipping the subscript globally. | #1021 | init-backfill only |
| **P5** | **#1021 empty-string.** Under sparse encoding `AxisWeights.default.rawValue == ""`, and a nil `init?` makes a restored macOS Related window **fail to decode**. Decode "" (any zero-pair string) as `.default`, vs a sentinel token. | #1021 | Decode as `.default`; update the `RelatedDocumentsRankerTests:127` nil pin |
| **P6** | **#1021 amnesty.** A stored vector byte-equal to the pre-#308 default vector is what the old serializer wrote for an *untouched* tuning — treating it as unconfigured delivers 0.5 to the largest stranded cohort at zero observable risk. Vs strict "reset is the route". | #1021 | Amnesty for the exact pre-#308 default vector, read-side only (no CloudKit rewrite) |
| **P7** | **#1025 instrumentation & budget.** Permanent `OSSignposter` interval (free in release, Instruments-visible forever) vs transient DEBUG prints; and what counts as acceptable (absolute wall ceiling per device class vs relative marginal-cost rule). | #1025 | OSSignposter; set the budget after seeing numbers |
| **P8** | **#1023 macOS hosting.** Dedicated `frus.subjects` Window (People parity; SceneEnvironmentAudit + boot-guard costs) vs a level inside the Corpus Browser window (no new scene, but subjects stop being browsable beside an open document — the regression PeopleWindowView exists to prevent). | #1023 | Dedicated Window |
| **P9** | **#1023 v1 detail scope.** Volumes-only detail could ship before #1022-A; a Subject Explorer that cannot reach documents undercuts its reason to exist. | #1023 | One coherent launch: bundle #1022-A in Session C |
| **P10** | **#1024 rename.** Keep `score` with the corrected contract (zero churn) vs rename to `orderingWeight` (~20 call sites). | #1024 | Keep name, fix contract |
| **P11** | **Subject-only browse paging.** The existing 1,000-row cap + "loaded · total" header handles the 65,958-doc worst case with zero new pipeline code; true offset paging is supported by the SQL but not the view models. | #1022-B/#1023 | Cap for v1 |
| **P12** | **Durable SavedSearch subject key.** Ref alone (~95 synthetic refs re-mint per upstream drop) vs ref-first-with-name-fallback compound. | #1022-A/#1023 | Compound, resolved ref-first in `makeFilters` |

## 3. Sessions

### Session A — independent correctness (three S PRs, no gating decisions)

**A1 · #1027 — pivot sheet membership.** Repoint `otherVolumeIds`
(`VolumeSubjectsView.swift:147–150`) at complete membership; extract ONE private resolver shared
with `coveringVolumeIds` so the two cannot diverge again (and so #1023 inherits it). List is a lazy
`List` — 551 rows need no cap. Rewrite the empty-state copy (`:238–239` describes the top-15
source); one new localization key. Sorted-volume-id ordering for v1.

**A2 · #1024(b) — the `score` contract.** Restate `VolumeSubjectProfiles.swift:47` to cover both
producers (per-volume TF-IDF from profiles; corpus IDF from the document-grain store) and which
supplies which; note it ranks, never displays; one pinning test. Option (a) — a distinct type —
is rejected: it fights the deliberate unified shape (`subjectsByVolume` exists so five scope menus
accept either producer through one signature), and a third IDF producer has grown since filing.

**A3 · #1022-B — the filter-only allowlist.** ONE shared predicate
(`SearchParameters.supportsFilterOnlySearch`) admitted at **four** sites — not three:
`SearchService.swift:268–276`, `SearchViewModel.swift:569–578`, `MacSearchViewModel.swift:900–906`,
and `QueryInspection.swift:225–226` (`isFilterOnly` — without it the Query Inspector never explains
a subject-only query). Four parallel edits is the repo's documented twin-drift hazard; the shared
predicate is the fix. Admit both `subjectBucket`/`subjectBucketKey` now (bucket-only browse works
today) and the future `subjectRef`. `makeFilters` already carries the −1 matches-nothing sentinel,
so the SQL side needs nothing.

### Session B — tuning (measure, then fix, then document)

**B1 · #1025 — measure on the #1021 branch, before it merges.** `ContinuousClock` around
`gatherSeed`, the seed loop, and each `rank` call (`ProjectLeadsService.swift:180–188`);
A/B at slider 0.0 vs 0.5 — the delta is the scorer's marginal cost. Fixture is the owner's device
library (the engine reads AppState + the live FTS5 index; not unit-testable). Numbers recorded on
the issue; budget set per P7. *The A/B methodology survives #1021's sparse encoding only under
P4's init-backfill option — settle P4 first.*

**B2 · #1021 — the forward fix.** Sparse `rawValue` (emit only non-default axes) **plus** the
init-side backfill (`parsed[axis] ?? axis.defaultWeight`) — without it a sparse string zeroes every
other axis on the three direct `@AppStorage` readers (`RelatedDocumentsView:90`,
`DocumentView:345`, `ResearchRailView:115`) and the window payload, since only
`ProjectLeadsService` does the merge today. Plus P5's empty-string decode and P6's amnesty.
Rewrite the conformance doc block (:13–36). Tests: sparse round-trip; legacy full string with
`sharedSubjects:0.0` still reads 0 through a DIRECT reader path; pre-axis string reads 0.5;
**`RelatedDocumentsRequest` JSON round-trip at `.default` weights** (the window-restore proof);
invert `AxisWeightResetTests:75–84` to pin sparseness. One spurious `commitWeights` inequality per
legacy project string is a harmless one-time format migration. No gates fire.

**B3 · docs pass 1 — #1030 + #1026 in ONE PR.** Four surfaces: the Guide
(`IndexingEducationView.swift:974–975` — "five signals … a sixth stays disabled" → seven, with the
detected-topics caveat already phrased in both manuals' facet sections), both manuals' Related
tables, and `Docs/EditableContent.md` (the mirror is **mandatory** — `mirrorMatchesTheGuide`
iterates the same `mustCover` table over it). Fold in #1026: correct the *false-today* "narrow to
the volumes where a topic is most characteristic" sentence (`:937` — complete-membership resolution
shipped in `f6fb0002`) and add the results-facet sentence. Add ONE `mustCover` row with
**non-vacuous terms** (the file already contains "subjects" and "facet"; pick terms that fail
against current text, per the source-scan-test rule), written to survive docs pass 2.

### Session C — the surface (gated on P1 + P2)

**C1 · #1022-A — subject grain.** Parallel `document_subject_refs` table (P3), populated in the
same transaction from a `subjectRows(forVolume:)` sibling of `bucketRows`
(`DocumentSubjectStore.swift:175`). **Version the stamp** (`v2:` prefix on `digest@generated`,
`IndexingPipeline.swift:6493`/`6525`) — the shared done-marker table would otherwise claim volumes
"done" while the new table is empty; the mismatch forces the free full rebuild. Add the table to
BOTH wipe paths (`removeAllVolumesFromIndex` and `auxDeleteVolume`). Migration lever is the stamp +
drop-and-recreate on a PK probe — **not** `currentDateIndexVersion` (bundled-artifact-derived, not
parse output; the repo documents this distinction). Budget: ~24.7 MB beside 20.9 MB. Settle P3
before writing a line — flipping the grain decision later costs a second corpus-wide rebuild.

**C2 · #1023 — the Subjects surface.** New `SubjectIndexView` (+detail) in `FRUSExplorer/Browser/`
— the wave's ONLY new source files, so xcodegen + scheme restore fires exactly once here (batch any
stragglers into it). List: 13 category groups over 491 subjects, searchable — the
`CollectionBrowserView` shape. Detail: volumes (via A1's shared resolver) + "Find documents"
hand-off through B's allowlist and C1's grain. iOS: a `BrowserLevel` case beside People. macOS:
per P8 a dedicated Window with the `PeopleWindowView` storeReady boot-guard, both
`.environment(appState)` and `.modelContainer(modelContainer)` in the scene block
(SceneEnvironmentAudit), defaultSize. Coverage honesty: `document_subjects` is populated only for
downloaded volumes — the surface owes the "N of M indexed" sentence the scope menus already carry.
Data accessors (`documentFrequency(forSubjectRef:)` or a widened `subjectVocabulary` tuple) ride
C1's store widening — one review of the store's public surface. ~10 new localization keys; run the
collision sweep here, covering A1's one key too.

**C3 · docs pass 2.** The explorer's "find it" lines in the Guide, mirror, and both manuals —
the `mustCover` row from B3 already pins the section exists.

## 4. Cross-cutting facts the plan relies on

- **No CloudKit deploy anywhere** — no `@Model` shape changes in any fix (`leadAxisWeights` changes
  values only; `SavedSearch` archives the whole parameters blob, so a `subjectRef` field rides free).
- **No `currentDateIndexVersion` bump anywhere** — the subject tables' lever is the digest stamp.
- **xcodegen fires once** (C2). All other work extends existing files, tests included.
- **Docs surfaces are pinned by tests**: `ResearchGuideCoverageTests` enforces guide + mirror via
  `mustCover`; the manuals ride the (unpinned) docs-pass convention.
- The #1031 reset is already the escape hatch for pinned tunings; B2 is the forward fix, and P6's
  amnesty is the only rescue that is provably safe.

## 5. Out of scope, noted

- #1019 — the 1 ms snippet budget (pre-existing on v2; three fix options on the issue).
- Any Settings home for axis weights — surveyed and rejected in #1029's record: ranking metrics
  stay in-feature in this codebase by documented principle.
- A rail affordance for Subjects without a D1 amendment (P2-iv).
