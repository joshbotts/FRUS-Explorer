# AUDIT B — People Browser Reconciliation & "Find All Mentions" (result-oriented)

Evaluated against a copy of the user's live `frus.db` (6.7 GB, copied 2026-07-03 with WAL/SHM),
replicating the app's exact queries (`PersonMentionStore.allPersonsSortedByName`,
`rollupEntry`, `documentKeys(forRollupId:)`, and the `searchDocuments` filter-only person path).

## Corpus baseline

| Metric | Value |
|---|---|
| `persons` rows (per-volume records) | 63,564 across 284 volumes |
| `person_rollup` identities | 18,641 |
| `person_rollup_member` rows | 63,564 (== persons; drift invariant holds) |
| `person_mentions` rows | 611,307 |
| Rollups with authority id (OOH crosswalk) | 12,759 / 18,641 (68%) |
| Rollups with `mention_count = 0` | 2,355 (12.6%) |
| `person_cluster_candidate` pairs | 345 |
| Rollup version installed | v7 (current) |

Integrity checks that PASSED: `mentions_missing_doccache = 0`; `persons_without_member = 0`;
`members_without_person = 0`; the rollup-filtered search returns exactly `mention_count`
documents for every sampled rollup (Kissinger r944: 13,174 = 13,174; Dulles r1845: 7,400;
r4443: 1,392; r12965: 4,566). **The People-browser "Find all mentions" query path is
mechanically correct when a rollupId is present.** Fragmentation of authority-covered
identities is fully healed: **0 of 12,836 authority ids are split across >1 rollup.**

Marquee figures are single, correct clusters: Kissinger (13,174 mentions / 100 vols),
Nixon (10,268 / 148), Rusk (8,795), JF Dulles (7,400 / 102), Eisenhower (6,127 / 137),
Gromyko (3,290 / 143), Acheson, Eden, Molotov — all one rollup each.

---

## Finding 1 (WORST, user-visible wrong attribution): 67 clusters conflate ≥2 distinct authority identities — 25,614 mentions affected

The clusterer's documented invariant "records with *different* ids are never merged"
(PersonClusterer.swift:38-41) is violated in the live DB: **67 rollups contain members
mapping to 2–3 different canonical ids** (36 of them with ≥100 mentions; 25,614 mentions
total, ~4% of the corpus). Worst cases:

| rollup | shown as | mentions | actually contains |
|---|---|---|---|
| r12965 | Carter, James Earl ("Jimmy"), Jr. | 4,566 | Jimmy Carter + Chip Carter + **Hodding Carter III** |
| r6577 | Herter, Christian Archibald, Sr. | 3,030 | Herter Sr. + Herter Jr. |
| r94 | Hoover, Herbert Clark | 1,983 | Hoover + Hoover Jr. |
| r4689 | Smith, Walter Bedell | 1,729 | + Walter B. Smith II |
| r10139 | **Castro, Raúl** | 1,513 | **Fidel Castro** + Raúl Castro + Raul Hector Castro (AZ governor) |
| r4443 | **Churchill, Clementine** | 1,392 | **Winston Churchill** (48 records) + Clementine (2) |
| r278 | Roosevelt, Franklin D. | 717 | FDR + FDR Jr. |
| r1039 | Richardson, E. R. | 666 | E. R. Richardson + **Elliot Richardson** |
| r9742 | Tran Le Xuan | 461 | Madame Nhu + **Ngo Dinh Nhu** (husband!) |

Winston Churchill — one of the most-mentioned people in FRUS — appears in the People
browser as "Churchill, Clementine" with her (VIAF-less) authority record.

**Root cause chain (verified on r4443):**
1. **Transitive bridging through uncovered members.** `decide()` returns `.none` for two
   records covered by *different* ids, but a record NOT in the crosswalk (9 of Churchill's 50
   members, e.g. `frus1917-72PubDipv07 p_CWS_1`) falls through to the heuristic on mixed
   pairs and union-finds both sides together. Pairwise refusal is not a union-find constraint.
2. **`normalize()` drops generational suffixes** (`jr/sr/ii/iii`) and **honorifics** (`mrs`),
   so "Herter, Christian A., Jr." ≡ "Herter, Christian A." and
   "Churchill, Mrs. Winston S" ≡ "Churchill, Winston S." (exact name relation). Sr/Jr pairs
   are contemporaries, so the 30-year era guardrail never fires. The "Mrs. <husband's name>"
   convention (common in conference volumes) systematically merges wives into husbands
   (19 `Mrs.` persons rows; 6 landed in clusters canonicalized without "Mrs").
3. **Arbitrary authority pick:** `authorityId = members.compactMap(\.authorityId).first`
   (IndexingPipeline.swift:433) — for an (illegally) mixed cluster, input order decides whose
   name/VIAF the whole cluster wears. Clementine's record happened to be first.

## Finding 2: 681 junk rollups (3.7% of the People browser) from one back-of-book index parsed as a persons list

- 676 canonical names contain digits; 333 contain embedded newlines; 340 are >80 chars.
  Examples in the A–Z list: "Churchill, 532", "Eden, 815–817", "Acheson, Dean G., Assistant
  Secretary of State, 62", "Aid to French North Africa, agreement with Roosevelt for, 823–828"
  (a subject heading, not a person), "Identity 1, 2, etc." (53 mentions!).
- **671 of the 676 digit-names come from a single volume, `frus1941-43`** (Washington/Casablanca
  conferences), whose front matter has a back-of-book *index* that the persons-list parser
  ingested wholesale: 746 `persons` rows, **all 746 with zero mentions**.
- The v7 `purgeNonPersonRows()` pass (`PersonListHeuristics.isLikelyPersonName`) does not
  reject "Surname, <role text>, 62–64" page-number entries or non-name subject headings.
- Impact: pollutes browsing, creates 0-mention rows (disabled "Find all mentions"), and
  produces the 0-mention "duplicate" twins next to real people (see Finding 4).

## Finding 3: mention gaps — 6,486 mention rows invisible to the rollup, 9,861 persons rows with zero same-volume mentions

- **Cross-volume persName refs are never joined.** In split sets the body of part 2 points at
  part 1's persons list: `ref="frus1918Supp01v01#p_LR1"`. `extractPersonRefs`
  (IndexingPipeline.swift:2789) strips only a *leading* `#`, so `person_mentions.person_ref`
  is stored as `frus1918Supp01v01#p_LR1` under volume `frus1918Supp01v02` — it joins neither
  `persons` nor `person_rollup_member`. **6,486 mention rows across 9 volumes** are lost from
  every rollup count and from "Find all mentions" results (e.g. Robert Lansing loses 291
  mentions in frus1918Supp01v02; 360 lost in frus1932v04; also bare refs with no persons list
  at all: frus1873p1v1/p1v2 `p_HF1` = 474 mentions with no persons row → person is entirely
  unfindable from the People browser, and tapping the name in a document shows "Person
  Information Unavailable").
- **9,861 persons rows (15.5%) have zero same-volume mentions**, feeding the 2,355 zero-mention
  rollups (12.6% of the People browser, where "Find all mentions" renders disabled). Drivers:
  the frus1941-43 index artifact (746), volumes whose bodies carry no `persName` refs at all
  (frus1977-80v27: 153/153; frus1969-76ve13: 217/327), and part-1/part-2 lists duplicated
  across parts (frus1951v03p2: 328/553).

## Finding 4: top-50 duplicates & residual fragmentation (minor)

- Top-50 most-mentioned clusters: **8/50 have a visibly compatible duplicate rollup**; 7 of
  the 8 twins are 0-mention frus1941-43 index artifacts (Harriman, Eden, Acheson, Bedell
  Smith, Macmillan, Molotov, Murphy); 1 is a real split: "Rusk, David Dean" (8,795) vs
  "Rusk, David Dean (Dean)" (60).
- Only 29 identical-normalized-name rollup groups exist corpus-wide (58 rollups; 24 groups
  where both sides have mentions) — e.g. "Beaulac, Willard Leon" (22 vs 90). Under-merge
  bias is otherwise working; **fragmentation is a solved problem for the 68% covered by the
  crosswalk** (0 split authority ids).
- Residual variant splits: "Dulles, Alan W." (typo, 4 mentions) vs "Dulles, Allen W.";
  "Eden, Robert Anthony" vs "Eden, Anthony" (incompatible first tokens — heuristic can't
  know Robert Anthony Eden = Anthony Eden; crosswalk doesn't cover that volume).
- No empty canonical names (0).

## Finding 5: "Find All Mentions" tester reports — two concrete app bugs (not DB bugs)

Traced all four launch sites. The People-browser path (`PersonIndexView` row/context menu and
`PersonIndexDetailSheet`) passes `personRollupId` and is verified correct against the DB.
The broken paths are the **document-view** ones:

1. **iOS: tapping a name in a document → PersonDetailSheet → "Find all mentions" does
   literally nothing visible.** `DocumentView.swift:467-473` sets
   `appState.pendingSearch = SearchParameters(personRef: person.ref)` but — unlike every
   other producer (PersonIndexView:126, MainTabView:142/168) — **never sets
   `appState.activeTab = .search`**. The sheet dismisses, the user stays on the Browse tab,
   and the handoff is consumed silently by the Search tab (or sits pending). This exactly
   matches "Find All Mentions does nothing." macOS is unaffected (MainWindowView:131-134
   opens the Search window on any `pendingSearch`).
2. **Both platforms: the document-view path searches the raw per-volume `ref` string,
   unscoped, while displaying the cross-corpus rollup count.** `filterConditions`
   (IndexingPipeline.swift:1780-1788) matches `pm.person_ref = ?` across ALL volumes.
   **4,271 ref strings are shared by 2–30 different people** (`p_BJ1` → 30 distinct rollups),
   so results mix strangers in; conversely the person's other-volume refs (different strings)
   are missed, so results can be a tiny subset of the advertised count
   (`DocumentViewModel.loadPersonMentionCount` shows the rollup's cross-corpus count).
   The sheet already resolves the rollup for the count — it should pass `personRollupId`.
3. Perceived-broken third case: the 2,355 zero-mention rollups + zero-mention front-matter
   entries render the button disabled with no explanation (12.6% of People rows).

---

## Root causes ranked by user impact

1. **Clusterer guardrail hole** (transitive bridging via uncovered members) + suffix/"Mrs."
   over-normalization → 67 conflated identities incl. Churchill-as-Clementine, Fidel-as-Raúl,
   Carter+Hodding Carter (25,614 mentions mislabeled).
2. **iOS tab-switch omission** in DocumentView's "Find all mentions" → the headline tester
   complaint; one-line fix.
3. **Unscoped `personRef` search** from document view → wrong/mixed/undersized results
   vs the displayed count.
4. **frus1941-43 index-as-persons-list parse** → 681 junk People rows + duplicate twins.
5. **Cross-volume `volumeId#ref` mention keys** → 6,486 mentions invisible in 9 volumes.
6. Residual variant splits (Rusk (Dean), Alan/Allen Dulles) — long tail, candidates system
   already surfaces some (345 pairs).

## Remediation plan

| Fix | Where | Version bump needed |
|---|---|---|
| **A. Authority ids as hard union-find constraints.** Pre-merge each authority group into an atom; forbid any union joining atoms with different ids (check ids at `union()` time, not only pairwise). Also make heuristic bridging of an uncovered record into a covered cluster fail when it would connect two different ids (under-merge: leave the bridge as a candidate). | `PersonClusterer.cluster` | `currentPersonRollupVersion` → 8 (rollup rebuild only; **no reindex**) |
| **B. Deterministic authority pick.** For a (now impossible, but defensive) mixed cluster, pick the id held by the most members, not `.first`; log the anomaly. | `IndexingPipeline.consolidatePersonRollup:433` | same bump as A |
| **C. Stop folding "Mrs."** — treat `mrs` as a *distinguishing* token (incompatible with its absence) instead of dropping it; keep dropping `jr/sr/ii/iii` only when the crosswalk covers neither record AND eras are informative, else demote to candidate. | `PersonClusterer.normalize/decide` | same bump as A |
| **D. Harden `PersonListHeuristics.isLikelyPersonName`**: reject names containing page-number runs (`, \d+(–\d+)?(,|$)`), embedded newlines, >80 chars, or no comma+capitalized-surname shape; the existing v7-style purge at consolidation then cleans installed DBs. | `PersonListHeuristics` + purge already wired | same bump as A (purge runs pre-consolidation) |
| **E. Normalize cross-volume refs at parse time**: in `extractPersonRefs`, split `"<vol>#<ref>"` and either record the mention under the target ref (persons lists of split sets are per-set anyway) or add a `target_volume` column. Requires re-index of affected volumes → **bump `currentDateIndexVersion` in the same commit** (repo rule), plus rollup bump to recount. Affected: frus1918Supp01v02, frus1917Supp02v02, frus1932v04, frus1873p1v1/2, +4 more. | `IndexingPipeline.extractPersonRefs` | `currentDateIndexVersion` + rollup bump |
| **F. iOS: add `appState.activeTab = .search`** in DocumentView's `onFindAllMentions`. | `DocumentView.swift:467` | none |
| **G. Document-view sheet passes `personRollupId`** (already resolved for the count; fall back to `personRef` only when the rollup is missing). Fixes both count/results mismatch and cross-volume ref collisions. | `DocumentView.swift` / `MacDocumentView.swift` | none |
| **H. Zero-mention UX**: explain the disabled button ("listed in this volume's front matter but not tagged in any indexed document"). | `PersonIndexDetailSheet` | none |
| I. (Optional) Regenerate the authority crosswalk to raise the 68% rollup coverage — not the cause of any defect found; fragmentation among covered ids is already zero. | `PersonAuthorityIndexGenerator` | rollup bump when shipped |

Suggested order: F+G (ship immediately, fixes the tester report), then A–D as one
rollup-v8 change (pure consolidation rebuild, cheap on-device), then E with its
reindex cost, H/I opportunistically.

## Repro queries (run against a COPY only)
- Mixed-authority clusters: join `person_rollup_member` → bundled `person-authority-index.json` crosswalk, group by rollup, count distinct ids.
- Junk names: `SELECT COUNT(*) FROM person_rollup WHERE canonical_name GLOB '*[0-9]*'` (676).
- Lost mentions: `SELECT COUNT(*) FROM person_mentions pm WHERE NOT EXISTS (SELECT 1 FROM persons p WHERE p.volume_id=pm.volume_id AND p.ref=pm.person_ref)` (6,486).
- Ref collisions: `SELECT ref FROM person_rollup_member GROUP BY ref HAVING COUNT(DISTINCT rollup_id)>1` (4,271).
