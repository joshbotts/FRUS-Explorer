# #234 early-era people — FEASIBILITY ASSESSMENT

**Status: ASSESSMENT, 2026-09-12. Not a plan of record, not a schedule, and nothing in it is queued. Owner decision: PENDING — the decisions this asks for are listed in §6.3.**

Answers the `N-0 → N-1 → N-2 → N-3 (#234)` row of `Planning/Plan-Of-Record-2026-09-06.md` §2 (the owner
lane) — the N-2 reading `Planning/People-Early-Era-Program.md` §4 says is owed once M2a is scored.
**Reviewed against the evidence pack:** a completeness pass listed 10 gaps, 17 attribution or reference
corrections and 10 internal contradictions. All were applied by hand on 2026-09-12 except one gap item,
which listed questions the pack cannot answer and which §7 already carries. §9 records what was
re-run, what was reproduced only approximately, and what is not independently verified.

**This document assesses; it does not commit.** It is the N-2 reading of the record that
`Planning/People-Early-Era-Program.md` §4 says is owed once M2a is scored — written so that the
decision the owner has to make is stated with its numbers, its sample sizes and its populations,
and so that a later revisit starts from measured ground. Every cost line is *recorded pricing*.
Every "would" is a description of a shape, not a promise to build it.

The question it answers, in the issue's own words: can the People browser, person search, person
analytics and the co-mention graph be extended to the FRUS volumes whose editors published no list
of persons — and if so, in what shape, at what measured quality, and behind which gates.

## The verdict, in one paragraph

**#234 is feasible only in a shape narrower than the issue names, and the thing that decides
feasibility is not the detector — it is the app's own rollup.** A names-only layer built from the
editors' existing `<persName>` markup is buildable now at a measured wrong-name rate of zero on the
64-document gold (0 false name keys of 79 predicted; 88 of 88 predicted spans overlap a gold mention;
gold n = 406), it
reaches 80.6% of the 197,534 in-scope documents, it fits in the bundle at under 1 MB gzipped, it
needs no corpus reindex and no CloudKit deploy — **but it is a correspondent index, not a people
index** (97.8% of the documents it reaches carry only the from/to header names), and **read from the
shipped `PersonClusterer`'s code, it would merge confidently-wrong persons by default** (inferred from
`decide()`, §3.4 — the merge frequency over a real derived table is unmeasured, §7): 83.1% of its
mention rows are single-token surnames (the share of its ~30,327 entries is unmeasured), the
clusterer's rule merges same-surname records of overlapping era, and "Seward" resolves to two
concurrent officeholders in every year of 1861–69 and 1876–80. That is the
#259 defect class reached by a different road, and it is closed by a code change to the clusterer,
not by a rule document (the "synthetic-ref namespace" and "force-merge-only" rules the program cites
as defined are defined nowhere). A second, detected layer is acceptable only at the detector-
*agreement* arm (editor ∪ (filtered NLTagger ∩ filtered sweep), sweep-side boundaries: presence
precision 0.898 [0.852, 0.942], 25 false names over 64 documents — post-hoc, n=64) behind an owner
precision floor; NLTagger alone is borderline; any sweep-bearing presence layer is not acceptable
(≈3.8 wrong names per document). Identity reconciliation — the shape the issue actually describes —
is **not shippable on current evidence**: its only precision instrument is 0 of 300 keyed, POCOM's
surname × year rule is a 55.4% *ceiling* on the marked layer and 12.7% on the detector layer, and the
"Reconciled identity" seal is gated solely on an authority id and cannot say "this is a machine
guess". The honest statement is therefore: **feasible after re-scoping the deliverable from
"people" to "correspondents from markup", with a detected-names tier as an owner decision and an
identity tier that waits on an owner sitting.**

---

## 0. Reading rules for every figure below

**Two populations, never mixed in one sentence.**

| population | volumes | `<persName>` marks | documents | used for |
|---|---|---|---|---|
| **app view** (Program doc §1, §3) | 268 | 253,919 | 199,246 (62.9% of corpus) | the issue's framing only |
| **TEI-rule scope** (NER-RUNBOOK §1, §3; `~/frus-ner-raw/scope.json`) | 267 | 245,747 located | 197,534 | every store, census, artifact and cost figure here |

Measured on the live index on 2026-09-12 the app view is **267 volumes / 198,936 documents** (§4.0):
`frus1873p1v1` gained its list under #740, nothing else moved, and the Program doc's 268 / 199,246 is
the 2026-08-07 figure the issue's framing quotes. The two populations differ by the 1873
`correspondents` pair (#740, closed — but only `frus1873p1v1` is actually read, §4.0) and `frus1941-43`
(#741, closed).
NER-RUNBOOK §3 reconciles them to the digit. App view: 253,919 − 2,988 − 3,927 + 312 = 247,316 raw
marks. Of those 247,316, the store locates 245,747 (99.4%), which is the TEI-rule count.

**One gold, one sample size.** Every quality figure is over the M2a gold: **64 of 72 staged
documents keyed, 406 mentions, 288 distinct (document, normalised-surface) keys**, bands
18 / 15 / 15 / 16 documents and 186 / 55 / 61 / 104 mentions (1861–1899 / 1900–1929 / 1930–1945 /
1946–), 2 documents naming no one. The 8 unkeyed documents are 3 / 3 / 2 in the three later bands
(measured from `progress.csv`; NER-RUNBOOK §7.2's "2 / 3 / 3" is wrong). Per-band cells are 15–18
documents, so per-band precision carries roughly ±0.13.

**Three normalised-surface keys, all called "K2" or "normalised surface" below, and they are not one
key.** The census (§2.1) folds casefold + whitespace + trailing possessive and strips ONE leading
honorific from a 29-token list, over ALL marked rows — its marked vocabulary is **11,377**. The gold
re-score (§2.2) strips honorifics repeatedly from a 74-token list — its 288 gold keys. The POCOM pass
(§2.5) strips from a 62-entry list over the from/to rows only — its marked vocabulary is **9,969**.
The three agree on every headline ordering and differ in the hundreds on vocabularies; no figure is
carried from one key's population into another's.

**Labels.** MEASURED = computed in this assessment from the local stores, gold or repository, with
the script named. DOCUMENTED = read from the named file. INFERRED = arithmetic or judgement on
measured inputs. **POST-HOC** = an arm or grain chosen after the published §7.2 scores existed; the
intersection arms, every union, and the document-presence grain are all post-hoc. **A ceiling is
never a precision**: "unique-by-year" means one officeholder of that surname was in office, not that
the mention is that person.

**Source tags** (full paths in §8): `[RB §n]` NER-RUNBOOK; `[SD]` score-detections.json; `[PROG §n]`
Program doc; `[M1a]` M1a-Findings; `[RIDE §n]` Ride-Along; `[CEN]` census.json; `[GR]` grains.json /
paired-differences.json; `[GR-V]` analyze.log / followup.log / placename.log; `[ERR]` errors.json;
`[POC]` pocom.json + nobody_band.out / repro_pc2.out; `[APP]` verify-read-app-method/measure.json;
`[SIZE]` grain_sizes.json; `[COST]` rows-check-output.json; `[SCORE-V]` verify-method/*.py outputs;
`[CODE]` file:line at HEAD `bd394443`.

---

## 1. What the harvest and the scores established

### 1.1 The stores on disk — every arm covers the whole scope, no re-run is needed

| layer | rows | scope | cost | source |
|---|---|---|---|---|
| marked (editors' `<persName>`, R-0 offsets) | **245,747** — 140,504 `from` / 95,247 `to` / 9,996 untyped | 267 vols / 197,534 docs | 3.6 min, no model | `[RB §3]`, `[CEN]` |
| qwen3-14b no-think sweep, raw | **3,656,238** (330,979 chunks; 88,009 unlocated = 3.38%; 155 truncated; 0 failed) | same | **997,808 s = 11.55 days**, Mac Studio | `[RB §4.8.3]`, heads re-summed `[SCORE-V]` |
| sweep, frozen filter (all rules) | **2,597,043 (71.0%)**; removed 1,059,195 (title 340,160 / institution 211,865 / place 208,236 / curated 193,798 / boundary 82,167 / pronoun 22,969); 417 removals overlapped an editor-marked person | same | minutes | `[RB §7]`, manifests |
| sweep, boundary-only filter | 3,574,071 | same | minutes | manifest |
| NLTagger control, raw | **1,353,849** | same | **475.8 s**; OS "Version 26.6.2 (Build 25G83)", English pinned | `[RB §4.8.3, §5]`, run-manifest |
| NLTagger control, frozen filter | **1,261,852 (93.2%)**; removed 91,997; 103 editor-overlapping | same | minutes | manifest |

Every store's per-volume body row count equals its `head.json` `mentions` and every arm's
per-volume document count equals the marked head's (267 of 267, 0 mismatches, `[CEN]`,
independently re-counted twice). The Studio store's `run-manifest.json` `totals_this_run`
(3,350,419 / 184,389 docs / 890,913 s) is the **last invocation only** and must not be quoted as the
sweep total `[RB §4.8.3]`. All five arms carry `sampled=false` in every gold volume's head, so no
gold document is unscored.

### 1.2 The six published rows `[SD]`, `[RB §7.2]` — n = 64 documents / 406 mentions

Reproduced to four decimals by two independent scorers and a re-run of the official one
(`[SCORE-V]` `score_mine.py`, `rescore.py`; `score-rerun.json`); the runbook's table carries last-digit display
rounding of the JSON's four-decimal values and nothing else.

| arm | predicted spans | strict P / R / F1 | relaxed P / R / F1 |
|---|---|---|---|
| editor markup (baseline) | 88 | 0.602 / 0.131 / **0.215** | **1.000** / 0.217 / 0.356 |
| raw sweep | 1,003 | 0.346 / 0.855 / 0.492 | 0.378 / 0.933 / 0.538 |
| boundary-only sweep | 976 | 0.355 / 0.855 / 0.502 | 0.388 / 0.933 / 0.548 |
| **filtered sweep** | 736 | 0.471 / 0.855 / **0.608** | 0.514 / **0.931** / 0.662 |
| NLTagger | 343 | 0.434 / 0.367 / 0.398 | 0.752 / 0.635 / 0.689 |
| **filtered NLTagger** | 316 | 0.471 / 0.367 / 0.413 | **0.810** / 0.630 / **0.709** |

Strict = exact (start, end); relaxed = maximum-cardinality one-to-one matching over any overlap
(Kuhn), so relaxed recall is "found the mention regardless of boundary" (`score_detections.py`
`match()`).

**What the record itself concluded from these, with the intervals it attached** (10,000
band-stratified document resamples; reproduced here within 0.3 points with two independent
implementations and seeds `[SCORE-V]`):

- **Boundaries go to the filtered sweep.** NLTagger − filtered sweep = **−21.0 strict**, 95% interval
  **[−28.1, −14.2]**; NLTagger − raw sweep −9.5 [−17.2, −2.4]. With titles and possessives stripped
  on both sides the lead survives: 0.653 vs 0.563 — a post-hoc, hand-picked 45-token check, not a
  pre-registered metric (`audit-2026-09-12-second-sitting/m2a_analysis64.py`; re-implemented in
  `strip_titles.py` at 0.661 against 0.653).
- **Finding the mention is a tie.** NLTagger − filtered sweep = **+2.7 relaxed, [−4.9, +10.2]**;
  filtered NLTagger − filtered sweep +4.7 [−2.7, +12.2] (`[SCORE-V]` addition). NLTagger beats the
  **raw** sweep by +15.1 [+7.0, +22.7].
- **The frozen filter is worth +11.5 strict to the sweep [+9.1, +13.8]**; in-sample it removed 267 raw
  predictions of which 266 matched no gold mention (cost: 0 strict, 1 relaxed hit — `King's`,
  `frus1951v01/d410`).
- **Post-hoc unions (direction, no interval in the record):** editor ∪ filtered NLTagger **0.794**
  relaxed (P 0.816, R 0.773); editor ∪ filtered sweep 0.646 (P 0.493, R 0.936). The record does not
  say how the union was formed; this assessment established by reproduction that it is the
  exact-duplicate (s, e, surface) union — overlap-dedup does not reproduce it (`[GR]` positive
  control 2). Union precision is a lower bound under one-to-one matching (overlap-dedup reads 0.805
  / 0.665).
- **Editor ∪ RAW NLTagger already reads 0.773 relaxed (P 0.767, R 0.778)** (`[SCORE-V]`
  `union_check.json`, post-hoc): the free-layer union beats every sweep arm before the frozen filter
  runs, so (b1) below depends on promoting `filter_detections.py` to a product rule for about two
  points, not for its standing.
- **The frozen stopping rule (raw arms only: strict gap ≥ 10 AND same winner every band) is not
  met** — gap −9.5, winners split (sweep 1861–1929, NLTagger 1930–), met in 2.6% of bootstrap
  resamples — **and cannot be met by the 8 unkeyed documents** (0–1 of 10,000 draws resampling their
  bands; a simulation result, not a proof about the eight). `[RB §7.2]`, SUBSET.md.
- **The record withholds a detector choice** and hands it to N-2 "on the use: offsets or presence"
  `[PROG §4]`, `[RB §7.2]`. This document is that reading.

### 1.3 Per band `[SD]` — small cells, split winners

Strict F1 (raw sweep / filtered sweep / NLTagger): 1861–1899 0.655 / **0.723** / 0.347; 1900–1929
0.440 / 0.567 / 0.387; 1930–1945 0.362 / 0.509 / 0.410; 1946– 0.429 / 0.542 / 0.492. Relaxed: 0.710 /
0.783 / 0.682; 0.466 / 0.600 / 0.688; 0.389 / 0.547 / 0.684; 0.488 / 0.611 / 0.706. Filtered-sweep
relaxed precision by band 0.691 / 0.432 / 0.384 / 0.452; NLTagger 0.723 / 0.842 / 0.714 / 0.795. The
two middle bands hold 55 and 61 mentions.

### 1.4 Caveats the record attaches, and three it should

1. **Sample.** n = 64 / 406; documents were staged at 800–8,000 characters (a stated bias); gold
   documents carry 15.7 raw-sweep predictions each against 18.5 mentions/doc store-wide — **the sample
   is lighter than the corpus**, so no precision here bounds the 2.6M- or 1.26M-row stores `[RB §7.2]`,
   `[SCORE-V]`.
2. **The 1861–1899 band mixes two harness revisions** (27 volumes, 12 of the band's 18 gold documents,
   105 of its 186 mentions) `[RB §4.8.3]`. MEASURED here: it does not move the sweep's gold score —
   raw strict 0.657 (segment 1) vs 0.654 (segment 2), filtered 0.719 vs 0.727; what differs is the
   *control* (0.280 vs 0.441 strict) on 1864–72 correspondence apparatus (`reproduce_analysis.json`).
   The segment is recoverable from the store itself: exactly the 27 heads lacking `failed_chunks`.
3. **The title convention favours the arm that emits titles.** The owner ruled titles inside the span,
   seeds included, so strict F1 partly measures a convention; the stripped-title check is the reading
   that survives it `[RB §7.1–7.2]`.
4. **Quote the editors' markup share as 21.7% by overlap** (baseline relaxed recall, 88 of 406), not
   the collector's 13.1% (a title-convention artefact) `[RB §7.2]`. M1a's ~34% was a different quantity
   on a different population (a bare-surname regex over 12 whole volumes, self-described as a lower
   bound); both say most mentions are unmarked.
5. **The audits were model instances, not human adjudicators.** `adjudication-workflow.js` and both
   `adjudication-journal.jsonl` files record an `agentId` per "adjudicate <band> A/B" task; "blind"
   means the packet omitted which arm emitted a candidate. The gold is single-human-annotator (the
   owner), model-audited: audit 1 found 6 missed mentions in 24 documents (5 accepted), audit 2 found
   none in 40 (`AUDIT-PROPOSED-CORRECTIONS.md`, `AUDIT-2-PROPOSED-CORRECTIONS.md`).
6. **The filter's "frozen before any ground truth" is true of *collected* gold and rests on the
   manifest's self-assertion.** File mtimes (`stat`, verify-method): filtered stores 15:14:31–15:15:04; the owner's typed
   first-sitting files 14:55:04–15:35:02 (11 of 24 existed by 15:15); collected gold ≥ 15:36. The freeze
   precedes collected gold by ~25 min but not the sitting; no independent lock exists.
7. **NLTagger output is a property of the OS build** and the sweep is non-deterministic at
   temperature 0 (+57 mentions between two pilot arms on identical chunks, across an OS/LM Studio
   build change) `[RB §4.6, §4.8.2, §5]` — every detector figure is run-specific.
8. The scorer's FP and miss sample lists are the first 40 in sorted (volume, document) order, not a
   random draw; `[RB §7.2]`'s illustrative strings are era-skewed to 1861–1872. §2.4 below reads the
   complete lists instead.

### 1.5 Errata found in the record by this assessment

- NER-RUNBOOK §3 (line 120) says **zero** marked rows carry a `corresp`. MEASURED: **9,215 rows
  (3.75%)** do — `frus1932v04` 5,028, `frus1918Supp01v02` 2,890, `frus1917Supp02v02` 1,297 — pointing
  into the sibling split-set part's persons list (10,616 `<persName corresp=…>` in the three TEI
  files; 9,215 inside body document divs) (`count_stores.json`, `linked_check.json`). See §4.0.
- NER-RUNBOOK §7.2 / SUBSET.md: the 8 unkeyed are **3 / 3 / 2**, not 2 / 3 / 3.
- The union definition (exact-duplicate dedup) is recorded nowhere but here.
- The audit adjudicators were LLM agents (above).
- M1a's 63.9% unique-by-year is **62.4% on the complete 12-volume sample** and **55.4% at scope**
  (§2.5); 1.5 of the 8.5-point gap is `m1a_survey.py`'s `seg[:8000]` cut.
- `frus1947v04/d341` is marked `none` in `progress.csv` and the documents file yet carries 2 seeded
  gold spans; the collector's "span count, never the mark" rule silently takes the seeds.
- `Charles Francis Adams` in `[RB §7.2]`'s miss illustration belongs to the editor baseline's list, not
  NLTagger's.
- The Ride-Along's R-3 row says clustering is "scored against M2a"; M2a rows carry
  `{v, d, s, e, n, seeded, band}` and no identity field. Identity precision can only come from the
  300-row set (§2.5).

---

## 2. What the scores did not establish, and what this assessment measured to fill it

The scorer's unit is the mention span. The app's unit is *(document, person)* with no offsets
(§3). Nothing in the record measured (a) corpus-scale reach and row volume, (b) any arm at the grain
the app stores, (c) what the false positives and misses *are*, or (d) how far POCOM can anchor any
layer. Each was measured here. Everything in §2.2–2.3 is **POST-HOC** and carries n = 64 / 406 / 288.

### 2.1 The census — corpus scale, TEI-rule scope, gross of precision `[CEN]`

`census.py` streams all 267 volumes of five arms plus two unions (9.1M rows) in 41 s at ~660 MB
RSS, keys every surface as K2 (casefold, whitespace-collapse, trailing possessive stripped, ONE
leading honorific stripped from a fixed 29-token list), and writes a (volume, document, K2) artifact
per arm. Reproduced twice (independent token-based key implementation; byte-identical artifacts).

| arm (267 vols) | rows | distinct K2 surfaces | (doc, K2) pairs — `person_mentions` rows under §4.a's one-ref-per-surface design | documents reached (of 197,534) | per-volume distinct K2, median / max | artifact, grouped compact / gz |
|---|---|---|---|---|---|---|
| marked | 245,747 | 11,377 | **223,505** | **159,182 (80.6%)** | **103** / 696 (`frus1932v04`) | 2.63 MB / **589 KB** |
| filtered control | 1,261,852 | 139,727 | 732,022 | 173,996 (88.1%) | 972 / 2,934 | 8.01 MB / 2.67 MB |
| filtered sweep | 2,597,043 | 412,545 | 1,579,296 | 196,113 (99.3%) | 2,726 / 5,749 | 22.0 MB / 7.15 MB |
| marked ∪ filtered control | (1,507,599 summed) | 143,940 | **864,469** | **192,128 (97.3%)** | 1,002 / 3,005 | 8.99 MB / **2.88 MB** |
| marked ∪ filtered sweep | (2,842,790 summed) | 414,185 | 1,596,691 | 196,162 (99.3%) | 2,730 / 5,751 | 22.2 MB / **7.19 MB** |

Per band, share of documents reached (1861–1899 / 1900–1929 / 1930–1945 / 1946–): marked **94.2 /
75.5 / 85.5 / 65.4%**; filtered control 95.2 / 85.4 / 85.8 / 90.0%; union with control 99.7 / 96.9 /
97.5 / 95.3%; either sweep union ≥ 98.1% in every band.

Facts a ship shape owes to the screen:

- **The marked layer is a correspondence-header index.** Of the 159,182 documents it reaches,
  **155,653 (97.8%)** carry *only* from/to header rows; untyped marks are 9,996 rows (4.1%), and
  `frus1932v04` alone holds 4,503 of them. Four in-scope volumes carry zero marks (`frus1872p2v3` 40
  docs, `frus1902app2` 116, `frus1919Parisv08` 43, `frus1919Parisv13` 2).
- **Reach is gross of precision.** A document "reached" only by a false positive is reached wrongly;
  the sweep's 99.3% is reach at relaxed P 0.514 (n = 64), the control union's 97.3% at P 0.810. The two
  unions are not comparable on reach alone.
- **Surfaces are not identities.** Filtered-sweep top 10 (K2): marshall 12,778; **seward 11,562**; hull
  10,859; johnson 10,761; wilson 10,010; molotov 9,964; roosevelt 8,354; bevin 8,299; **william h.
  seward 8,019**; acheson 7,630 — two Seward keys, and "johnson"/"wilson" each merge several people;
  "japanese government" and "chinese government" sit at ranks 24–25 and "john" at rank 12 of the
  filtered control (3,943), "chiang kai" at rank 29 (2,454, a boundary cut of Chiang Kai-shek). Marked
  top 5: seward 8,929; johnson 5,303; hay 4,863; bayard 3,544; fish 3,481. (Union top-5 counters in
  `census.json` are component sums that double-count the 62,390 / 148,523 exactly coincident spans —
  deduplicated, seward is 12,349 in the sweep union, not 20,491.)
- **The detector vocabularies are singleton-heavy.** 66.5% of the filtered sweep's 412,545 surfaces
  are corpus-wide singletons; 14,206 surfaces (3.4%) carry 68.6% of its mentions. A ≥ 5-occurrence
  floor keeps 50,570 sweep surfaces and 80.9% of mentions, or 23,707 control surfaces and 86.7%.
- **Rows per document:** marked 1.13 per scope document (1.40 per reached document); control union
  4.38; sweep union 8.08. The header markup is densest per document in 1861–1899 (2.61 rows/doc) and
  thinnest in 1946– (0.77), where the filtered sweep finds ~17.

**The grain the app stores is persons rows per (volume, normalised surface)** `[APP]`, `[COST]`:
**30,327** (marked) / **326,305** (filtered control) / **798,129** (filtered sweep) / 340,614
(marked ∪ control), against **62,818** persons rows in the shipped index today (issue #234 readiness
comment) — 0.5× / 5.2× / 12.7× / 5.4×. Single-token surfaces: **83.1%** of marked rows, 53.0% of
filtered-control rows, 31.8% of filtered-sweep rows.

### 2.2 The document-presence grain — the grain the app consumes `[GR]` (POST-HOC; n = 64 / 288 keys)

Key = the normalised surface (casefold, whitespace, trailing possessive, repeated leading
honorifics from a 74-token list); a predicted (document, key) is TRUE when any mention under it
overlaps a gold mention under the scorer's own one-to-one matching. Both positive controls passed
first (six published rows dict-equal to `[SD]`; both runbook unions reproduced).

| arm | P [95%] | R [95%] | F1 [95%] | predicted / true / **false** keys |
|---|---|---|---|---|
| editor | **1.000** | 0.274 [0.225, 0.335] | 0.430 [0.368, 0.501] | 79 / 79 / **0** |
| filtered control | 0.799 [0.719, 0.873] | 0.618 [0.553, 0.679] | 0.697 [0.640, 0.747] | 214 / 171 / **43** |
| filtered sweep | 0.528 [0.456, 0.606] | 0.934 [0.890, 0.973] | 0.675 [0.610, 0.738] | 511 / 270 / **241** |
| control ∩ sweep, control-side spans | 0.872 [0.812, 0.928] | 0.583 | 0.699 | 187 / 163 / **24** |
| control ∩ sweep, sweep-side spans | 0.876 [0.818, 0.930] | 0.590 | 0.705 | 193 / 169 / **24** |
| editor ∪ filtered control | 0.827 [0.761, 0.888] | 0.795 [0.735, 0.849] | 0.811 [0.765, 0.853] | 266 / 220 / **46** |
| editor ∪ intersection (control side) | 0.883 [0.835, 0.928] | 0.760 | 0.817 [0.778, 0.854] | 239 / 211 / **28** |
| **editor ∪ intersection (sweep side)** | **0.898 [0.852, 0.942]** | 0.767 [0.712, 0.820] | **0.828 [0.788, 0.865]** | 245 / 220 / **25** |
| editor ∪ filtered sweep | 0.527 | 0.938 | 0.675 | 512 / 270 / **242** |
| editor ∪ control ∪ sweep | 0.491 [0.427, 0.558] | 0.976 [0.955, 0.992] | 0.653 [0.593, 0.711] | 574 / 282 / **292** |

Per band, presence P / R / F1, editor ∪ intersection (sweep side): 1861–1899 **0.980** / 0.715 / 0.827;
1900–1929 0.973 / 0.837 / 0.900; 1930–1945 **0.745** / 0.864 / 0.800; 1946– 0.842 / 0.766 / 0.802.
Filtered control alone: 0.817 / 0.584 / 0.681; 0.963 / 0.605 / 0.743; **0.698** / 0.727 / 0.712; 0.765 /
0.625 / 0.688. Gold keys per band 137 / 43 / 44 / 64.

Paired bootstrap differences, same resamples `[GR]` (presence grain unless stated):

| comparison | F1 | P | R |
|---|---|---|---|
| editor ∪ int(sweep) − editor ∪ filtered control | +0.017 [−0.010, +0.048] | **+0.071 [+0.028, +0.128]** | −0.028 [−0.061, +0.004] |
| int(control) − filtered control | +0.002 [−0.025, +0.029] | **+0.073 [+0.027, +0.131]** | −0.035 [−0.066, −0.009] |
| editor ∪ filtered control − editor ∪ filtered sweep | **+0.136 [+0.065, +0.207]** | **+0.300 [+0.224, +0.372]** | −0.142 [−0.220, −0.062] |
| editor ∪ filtered control − editor | **+0.380 [+0.308, +0.445]** | — | +0.521 [+0.452, +0.581] |
| filtered control − filtered sweep | +0.022 [−0.052, +0.094] (tie) | | |
| mention grain: editor ∪ int(sweep) − editor ∪ fc, strict F1 | **+0.186 [+0.142, +0.234]** | | |
| mention grain: three-way union − editor ∪ fc, relaxed F1 | −0.187 [−0.244, −0.131] | | |

So at n = 64: the free-layer union effect (+0.38) and the control-over-sweep precision gap (+0.30)
are established; the intersection buys precision from the control at a recall cost with **no F1
change the sample can rank**; NLTagger vs sweep is a tie on presence F1.

**Four caveats that bind every number in this table:**

1. **It is a surface grain, not the identity grain the app stores.** `person_mentions` is UNIQUE
   (volume, document, **person_ref**) `[CODE]` `IndexingPipeline.swift:5843-5849`. MEASURED: 46 of the
   288 gold keys are a token-suffix of another gold key in the same document (seward / william h.
   seward, adams / charles francis adams …); collapsing by last token gives **238** keys. The
   denominator over-counts identities by roughly a sixth, and **no arm has been scored at the identity
   grain** — that needs the unbuilt M1 identity step (`[GR-V]` analyze.log §8).
2. **The credit rule matters, and only for the NLTagger-side arms.** Under overlap credit the control
   is credited for 32 mentions whose *stored key equals no gold key* in the document — 18 partial
   names (Halleck for "Major General H. W. Halleck": same person, fair), 7 title super-strings, and
   **7 garbled strings a browser would show wrongly** ("Seward Mexican", "Wallenberg June",
   "Cardinal", "Geo", "WILLIAM II"). Under a string-equality variant: editor ∪ filtered control
   **0.811 → 0.697** (P 0.726); editor ∪ int(control) 0.817 → 0.710; **editor ∪ int(sweep) 0.828 →
   0.822** (P 0.894); filtered sweep 0.675 → 0.666; editor 0.430 → 0.420 (its two "false" keys are
   the merged "Jessup and Ford" span and "Wilson" vs "Chargé Wilson" — convention, not wrong people)
   (`[GR-V]` analyze.log §7, followup.log §b). The true name-keyed figure lies between the two rules.
3. **Precision is defined only up to the matcher's tie-break** where one gold span is covered by two
   disjoint predictions ("JNO. G. PARKE" → JNO + PARKE): an equally valid maximum matching moves
   filtered control P 0.799 → 0.804 and editor ∪ fc 0.827 → 0.831; no ranking changes.
4. **The three-tier order survives the grain shift** — editor-unions > non-sweep singles > sweep-
   bearing arms > editor alone — but within-tier order does not (mention grain ranks editor ∪
   int(control) first; presence ranks editor ∪ int(sweep) first), and the shift moves the editor
   +0.074 and the three-way union +0.047 (`[GR-V]` analyze.log §1–2).

### 2.3 The intersection arm at mention grain `[GR]` (POST-HOC)

Filtered-control spans overlapping ≥ 1 filtered-sweep span in the same document (267 spans):
relaxed **P 0.891 [0.839, 0.940]**, R 0.586 [0.530, 0.638], F1 0.707; strict F1 0.404. The sweep-side
variant (279 spans) has near-identical relaxed numbers (P 0.864, R 0.594) but **strict F1 0.634**
because it keeps the sweep's title-inclusive boundaries; with the editor layer it reaches strict
**0.672 [0.628, 0.715]** — the highest strict F1 in the record (next: filtered sweep 0.608). Paired
mention-grain precision gains over the filtered control: control side **+0.081 [+0.021, +0.162]**
(excludes zero); sweep side +0.042 [−0.024, +0.120] (does not). Raw control ∩ raw sweep reads P 0.848,
so the frozen filters add ~4 points on top of agreement. By band (control side, relaxed P): 0.973 /
1.000 / **0.726 [0.565, 0.909]** / 0.840. Its recall ceiling is the control's **by construction**
(a subset of its spans).

Its misses are patterned, and the pattern is the *heading line*, not the signature: of 28 missed
Seward / Bayard / Hay / Adams mentions, **22 sit in the first 10% of the document text** ("Mr. Seward
to Mr. Adams", "Lord Lyons to Mr. Seward") and 2 in the last 10%; across all missed gold mentions
19.9% are in the last 10% against 21.4% of all gold — no signature concentration (`[GR-V]`
followup.log §a). The editor layer covers exactly that class (§2.4).

### 2.4 What the errors are `[ERR]` (n = 64 / 406; one reader's categories, counts exact over them)

Positive control: driving the scorer's own `load_ground_truth` / `collect_predictions` / `match`
reproduces every published relaxed figure, so the lists are the scorer's residues, not an
approximation. FP identity (not count) is tie-break-dependent in exactly two pairs (JNO / PARKE;
Generalissimo / Generalissimo Chiang).

**Filtered NLTagger, 60 false positives:** 35 place (sub-national — Rosario Strait(s)/Rosario ×5,
Haro ×4, Fort Langley ×3, Fraser River ×3, Kunming, Shensi, Tungkuan, North Kiangsu, Yellow River,
British Malaya ×2 …), 6 "Samoan", 4 ships (schooner Anna, the Dee, SS President Harding ×2), 4
institutions (Hunzedal — a company, Rickmers Reismühlen Rhederei, "Leg Cairo", "Greek Govt"), 4
document furniture, 3 "Queen Mother", 2 citation-caption names ("Lic. Wolf, Rudolf/51"), 1
fragment (JNO), 1 calendar month (Ramazan). By band 29 / 1 / 15 / 15. **Zero were persons the gold
missed** (one reader's judgement, corroborated by audit 2's zero missed mentions over 40
documents; audit 1 found 5 in 24). **12 of 60 would pass as a person in a browser** (Harding ×2,
Anna, Dee, Bull, Haro, Arro, Ramazan, Seville, Wolf, Rudolf, Hunzedal) — 7 of the 12 from two
documents (`frus1937v01/d566` 5, `frus1864p2/d358` 2). The pseudo-person office class ("Queen Mother"
×3) denotes a real person without naming one.

**Filtered sweep, 358 false positives:** 103 institution/body, 90 place, 72 title-or-office-only, 53
pronoun/common phrase, 17 nested duplicates of a gold hit (same person, different boundary — would
fold, not mint), 10 furniture, 8 ship/treaty/conference, 3 dates, 2 caption names. By band 75 / 71
/ 93 / 119. Survivors are multi-word descriptive phrases the filter's all-tokens-in-a-list rules
cannot reach ("Polish Government" ×10, "Mexican Government" ×6, "the Imperial Government" ×4, "the
Khedive" ×2, "officers" ×6, "Japs/Jap" ×9). **Only 10 of 358 (2.8%) are name-shaped** (Hunzedal ×3,
President Harding ×2, Seville, Lic. Wolf, Rudolf/51, Waalhaven, Socdeco); 9 more are unnamed offices
or epithets that denote one real person ("Queen Mother" ×4, "the Khedive" ×2, "Commanding General
Seville", "Military Governor Bilbao", "the Young Marshal"). At a per-document people list the
filtered sweep places at least one non-person in **53 of 64** documents (`reproduce_analysis.json`).

**Filtered NLTagger, 150 misses:** **101 (67%) are the correspondence frame** — 61 heading line, 30
signature ("WILLIAM H. SEWARD."), 5 routing, 4 addressee, 1 salutation — 46 (31%) unmarked persons in
prose (Count Arco ×5, the eight Lincoln conspirators, Gladstone/Bright/Spurgeon, Chou En-lai …), 3
the R-0 layer's footnote-doubled names. **The editor layer covers 59 of the 61 heading-line misses
and 0 of the other 89**; the post-union residual is 92 (one editor span, "Jessup and Ford", covers
two gold spans and recovers one under one-to-one matching). The filtered sweep finds 142 of the 150.

**Filtered sweep, 28 misses:** 16 unmarked in prose (bare surnames Sherman, Chiang, Chou, Glasier;
title+name; George Washington ×2), 4 all-caps/telegram signatures, 3 heading-line names, 1
salutation, 2 merged list spans (a convention miss), 1 abbreviated ("Pres Truman's"), 1 removed by
the frozen title rule ("King's"). **18 of 28 are in 1861–1899.** The control finds 19 of the 28.

**Eight gold mentions are found by no arm and no editor span**: WILLIAM H. SEWARD and ARCHIBALD
CAMPBELL (all-caps signatures), George Washington ×2, Messrs. Campbell, Aspíroz, Chou, King's.

**Vocabulary-removable ceilings — in-sample, post-hoc, unscorable on these 64 documents:** control
52 of 60, sweep 327 of 358 after removing the firm names and the month the same lists file as
name-shaped. Five of the control's place surfaces (9 mentions: Haro ×4, Rosario ×2, Bull, Arro, Seville) are
single tokens that are also personal names. **FRUS `<placeName>` markup cannot serve as the gazetteer**:
of 12 false toponyms tested, only Kunming (22 elements) and Seville (19) occur inside any
`<placeName>` in their own volume; Shensi, Tungkuan, Kiangsu, Yellow River, Medan, Malaya, Timor,
Takao, Fuhsin, Wilmington occur 0 times inside one against 1–134 plain-text occurrences —
placeName markup is dateline-bound (`[GR-V]` placename.log). Any gazetteer built from these lists
needs the 8 unkeyed documents or a fresh sample to be scored.

**Corpus-scale filter cost, documented beside the 1-of-406 sample figure:** the sweep filter removed
**417** editor-marked person spans of 1,059,195 removals (title 213, curated 71, boundary 69, place
39, institution 25); the control filter **103** of 91,997 (title 85, curated 10, boundary 5, place 3)
(both `run-manifest.json`). On the control the filter's two lost relaxed hits are 3-character "Hon"
fragments — a precision gain, not a recall cost.

### 2.5 How far POCOM can anchor anything `[POC]` — ceilings, not precisions

M1a Measurement 3 reproduces **exactly** from its verbatim code against today's POCOM checkout
(12,384 from/to names, 10,310 surname-known = 83.25%, 7,916 unique-by-year = 63.92%; 4,261 people,
4,167 with a dated appointment; 0 data commits under `people/missions-*/positions-principals` since
2026-08-07). The complete 12-volume sample without the `seg[:8000]` cut is 13,037 names: **81.6% /
62.4%**.

**Whole marked layer, from/to rows, 267 volumes** (235,751 rows, 235,218 with a surname = M1a's
denominator; every document carries a TEI `frus:doc-dateTime-min` year, so the ±1 document-year rule
is primary):

| | rows | share of with-surname |
|---|---|---|
| surname known to POCOM | 189,613 | **80.6%** |
| exactly one officeholder of that surname in office that year | 130,321 | **55.4%** |
| known, but **nobody** of that surname in office that year | 40,563 | **17.2%** |
| known, several in office | 18,729 | 8.0% |

All marked types (245,090 with surname): 79.5% / 54.2%. By band (known / unique): 1861–1899 78.5 /
53.9%; 1900–1929 79.0 / 55.2%; 1930–1945 84.7 / 59.4%; 1946– 79.4 / **49.9%** — flat 50–59%, no era is
a safe identity-first target on POCOM alone. **Seward** is the most-known surname (9,551 from/to
mentions) and unique-by-year for **13** of them (all dated 1875): two Sewards were in office
concurrently throughout 1861–69 (W. H. + F. W.) and 1876–80 (G. F. + F. W.) — never three. The
"nobody in office" band is not a pre-POCOM artefact (0 of 40,563 predate 1777): it is 1940s-heavy
(13,642 = 33.6% dated 1940–49; 6,619 in the 1930s), i.e. wartime and foreign correspondents whose
surnames coincide with POCOM's.

**The detector's novel layer** (filtered-control rows overlapping no marked span: 1,181,285 of
1,261,852; 1,164,835 with a surname): **32.9%** surname-known, **12.7%** unique-by-document-year, and
the "known" share is mostly string coincidence — **George** 4,372 and **John** 3,845 sit among the
top known surnames; 57.4% of the known name nobody in office. Distinct novel surfaces: 135,393
(13.6× the marked layer's 9,969 distinct from/to surfaces under this section's key — §2.1's 11,377 is
every marked row under the census key, see §0), of which 3.4% are uniquely anchored.

**Derived-index ceilings at the (document × K2 surface) grain** — the share of rows that could
carry a POCOM candidate at all / exactly one in-window candidate: marked-only **80.4% / 55.3%**
(223,219 rows); marked ∪ novel control **44.5% / 23.7%** (853,622 rows) — the identity problem for a
detected layer is 3.8× larger in surface rows and mostly outside POCOM. (Surface rows over-count
identities; see §2.2 caveat 1.)

**The instrument that would turn a ceiling into a precision is 0 of 300 keyed** (MEASURED:
`m1a-eval-candidates.csv`, 300 rows, 25 per volume × 12 volumes, 173 from / 127 to, 75 per band,
100 pre-1910, `TRUE_IDENTITY_pocom_slug_or_name` empty in all 300; owner-only). At 300 rows a ~55%
rate carries a 95% half-width of ±5.6 points pooled, ±11.3 per 75-row band. It prices the **marked
from/to population only** (and, being drawn through `m1a_survey.py`'s `seg[:8000]` cut, under-samples
names in long documents); nothing prices the 1.18M novel-control surfaces, and the M2a gold has no
identity column. On the 12-volume population the set is drawn from, **2,499 of 13,037** from/to names
(19.2%) are surname-known yet resolve to nobody or to several officeholders in the year
(`repro_pc2.out`), so roughly a fifth of the keyable rows are un-anchorable by the surname × year rule
by construction.

---

## 3. The grain argument — what the app consumes decides the detector

### 3.1 No shipping person surface reads a character offset `[CODE]`

| surface | what it reads | file:line | grain |
|---|---|---|---|
| `person_mentions` schema | (id, volume_id, document_id, person_ref) UNIQUE(volume_id, document_id, person_ref) ON CONFLICT REPLACE — no span columns | `IndexingPipeline.swift:5843-5849` | document presence |
| `extractPersonRefs` | returns `Set<String>` of refs; inserts only when `<persName>` carries `corresp` or `ref` | `IndexingPipeline.swift:5301-5313`; `FRUSDocumentParser.swift:1174-1176` | presence |
| `persons` schema | PRIMARY KEY (volume_id, ref); `name`, `description`, `role`, `start_year`, `end_year`; written INSERT OR REPLACE | `IndexingPipeline.swift:5891-5897`, `:6939` | identity row per (volume, ref) |
| People browser | `person_rollup` rows via `allPersonsSortedByName` | `PersonIndexView.swift:174-181` → `PersonMentionStore.swift:984-988` | rollup |
| person detail | `volumeMentionCounts` = COUNT(DISTINCT document_id) | `PersonMentionStore.swift:331-335` | presence |
| person search filter | EXISTS over `person_mentions` by (volume, document, ref) or via `person_rollup_member` | `IndexingPipeline.swift:3660-3676` | presence |
| autocomplete | `personsMatchingName` over `persons` | `SearchFilterView.swift:476-477` → `PersonMentionStore.swift:1015-1018` | identity row |
| person analytics | `topPeopleByMentions` / `mentionTrajectories` — **COUNT(\*) over `person_mentions` rows** | `PersonMentionStore.swift:588-599`, `:507-518` | presence (row count) |
| co-mention graph | self-join of `person_mentions` on the same (volume_id, document_id) | `PersonMentionStore.swift:754-779`, `:817-834`, `:872-883` | presence |
| collections Persons Index | `rollupMentions` | `CollectionGeneratedBlocks.swift:165-167` → `PersonMentionStore.swift:369-384` | rollup |
| rollup `mention_count` | COUNT(DISTINCT volume‖document) | `IndexingPipeline.swift:1035-1040` | presence |
| inline `persName` link | keyed on the **TEI element's ref**, resolved through `personsByRef` (the volume's `persons` rows); href `#` when the ref is nil | `ASTToRenderNodeConverter.swift:298-304`; `FRUSRenderNodeHTMLSerializer.swift:724-726`; `DocumentView.swift:1070-1075` | element, not offset |
| highlights (the app's only offset feature) | UTF-16 offsets into the render model's flat text — a **third** coordinate space, distinct from the detectors' R-0 code-point offsets and from `document_cache.body_text` | `FRUSRenderNode.swift:290-296`, `:378-380`; `IndexingPipeline.swift:5056-5058` | not person-related |

Offsets are surplus to every existing surface. They would matter only for inline linking of
*unmarked* detector-found names — a surface that does not exist and would need an R-0 → render-text
mapping plus a new table. The editor-marked names can be linked inline **without** offsets because
the TEI element is the anchor — provided the ref reaches the AST node (a parse-time route) or the
converter's `personLookup` is changed to key on (volume, document, surface) (an artifact route needs
that converter change; today `personLookup` is keyed on ref, `ASTToRenderNodeConverter.swift:302`).

### 3.2 But the stored name IS the span

`persons.name` carries the detection's surface string, so boundary quality re-enters through the
displayed name. The filtered control's strict P 0.471 against relaxed P 0.810 means ~42% of its
correctly located mentions carry a boundary the gold convention rejects — **mostly title omission**
(the filter's title rule strips "Hon", "Esq."), and of the 32 browser-visible non-matching keys 18
are partial names (acceptable), 7 title super-strings, **7 garbled** (§2.2 caveat 2). At corpus scale
the same defect reads "chiang kai" 2,454 rows and "john" 3,943 in the filtered control's top 30
`[CEN]`. The sweep-side arms are the only ones whose presence score survives a string-equality
reading (0.828 → 0.822 against 0.811 → 0.697).

### 3.3 Three defects can appear on screen, and the pack prices two of them

(i) a non-person string listed as a person — a wrong NAME; (ii) a real person's name stored as a
fragment or super-string — a wrong STRING; (iii) two people folded into one entry, or a derived entry
folded into an editor-listed, authority-sealed one — a wrong IDENTITY. The measured precisions price
(i) and (ii). **Nothing in the record prices (iii), and the only mechanism that produces it is the
app's own clusterer** — which is why the defect the program names as its most serious (`[PROG §5]`
constraint 5; #259 closed not-planned because 79% of its proposed merges attacked an installed
guardrail) is the one this assessment turns on.

### 3.4 The clusterer facts `[CODE]` `PersonClusterer.swift`

- Blocking key is `surname|first-given-initial` (`:437`), so every surname-only record of one surname
  shares a block, while "Seward" (`seward|`) and "Seward, William H." (`seward|w`) are never compared.
- `normalize` strips honorifics (`:455-457`, `:490`): "Mr. Seward" == "Seward" → `.exact` (`:374-375`).
- `decide()` returns `.merge` for an `.exact` or `.variant` pair when eras overlap within
  `eraGapYears = 30` (`:134`, `:344-359`) and roles do not conflict; a candidate only on an
  unknown era or a role conflict. Derived rows always carry a mention era from `document_dates`
  (`IndexingPipeline.swift:1109-1130`), so the unknown-era guard never protects them.
- Authority ids are decisive only when **both** records carry one (`:322-324`); the comment at
  `:320-321` says a mixed pair "falls through to the heuristic, which can bridge an uncovered straggler
  into a covered cluster on a strong name+era match" — an authority-uncovered derived entry is exactly
  such a straggler.
- The "Reconciled identity" seal is gated solely on `effectiveAuthorityId != nil`
  (`PersonIndexView.swift:654-660`); `PersonIndexEntry` carries no source field
  (`PersonMentionStore.swift:24-48`); `persons` / `person_rollup` have no source column
  (`IndexingPipeline.swift:5891-5947`); `ProvenanceSource` is pinned at eight cases
  (`ProvenanceChipTests.swift:51`, `:122`).
- `persons` is INSERT OR REPLACE on PRIMARY KEY (volume_id, ref): a synthetic ref colliding with an
  editor `xml:id` silently replaces the editor's row.
- `purgeNonPersonRows` (`IndexingPipeline.swift:1080-1105` → `FRUSDocumentParser.swift:1391`,
  `isLikelyPersonName`) deletes any
  persons row that fails the predicate at every consolidation, silently.
- `auxDeletePersonMentions(forVolumeId:)` (`IndexingPipeline.swift:4573`, `:7375`) wipes a volume's mention rows on every
  store; artifact-applied rows need a per-volume re-apply hook on the `refreshDocumentSubjects`
  pattern (`IndexingPipeline.swift:4630`, `:7682`).
- The rollup rebuild fires on `installedVersion < currentPersonRollupVersion || members != persons ||
  override fingerprint changed` (`IndexingPipeline.swift:913-917`) — adding persons rows triggers it with no bump; **a bump
  is nevertheless required in every shape by the CLAUDE.md rule, because every shape changes the
  clustering rule** — a policy, not a mechanism: the drift check would rebuild without it
  (`currentPersonRollupVersion = 9`, `IndexingPipeline.swift:863`).

**The rules the program cites do not exist as text.** `[PROG §5]` says the synthetic-ref namespace,
index-version bump batching and force-merge-only rollup rules are "defined in
`Planning/Completed/Issues-233-243-Plan.md`"; that file (`:290`) says they "are documented in the
investigation findings", which no file in the tree is; `git log -S` shows the text never existed
(`read-cost` RC-12 reproduce). Only index-bump batching has a general definition elsewhere
(`Plan-Of-Record-2026-08-17.md:82-88`; re-graded to tidiness in `DEVELOPMENT-PLAN.md:2019` because a
reindex is ~10 minutes owner-measured). "Force-merge" in shipped code means exactly the authority-id
union at `PersonClusterer.swift:170-181`.

### 3.5 What the grain decides

- **Presence is the grain, and presence-with-the-name-string is the metric.** The record's "boundaries
  → sweep, presence → tie" is right at mention grain and incomplete at the app's, where the name string
  is the boundary.
- **Detector for a presence surface:** the agreement arm with sweep-side spans — highest presence
  precision (0.898), best stored strings (strict 0.672), robust to the credit rule — with the sweep's
  own 0.514 precision never reaching the screen because it supplies only the string and the veto.
  NLTagger alone only if the owner accepts partial and occasionally garbled strings. The sweep alone
  never, at any presence surface.
- **Offsets** justify the sweep only for an inline-linking surface of unmarked names that does not
  exist; if it is ever designed, the sweep is the only arm with usable boundaries.
- **Every shape** needs a code gate in `PersonClusterer` before a single derived row exists.

---

## 4. Ship shapes

Read every "would" as a description. Engineering budgets are INFERRED, calibrated on one point:
PR #737 / #736 (generator + bundled artifact + app model + PersonIndexView UI + tests) was 2,600
additions across 25 files in one session (`gh pr view 737`).

### 4.0 Step 0 — not a shape: the three split-set second parts

`frus1932v04` (794 documents), `frus1918Supp01v02` (912) and `frus1917Supp02v02` (459) are in the 267
and carry **9,215** body `<persName corresp="frus1932v03#p_JNT1">`-style marks — 5,028 / 2,890 / 1,297
of their 5,225 / 3,310 / 1,498 located marks — into the sibling part's persons list, which holds 597 /
267 / 212 `persName xml:id`s (MEASURED, `count_stores.json`, `linked_check.json`; the three TEI files
carry 10,616 such `corresp` attributes — 5,743 / 3,395 / 1,478 — of which 9,215 sit inside body
document divs). The parser already reads `corresp` as the ref (`FRUSDocumentParser.swift:1174-1176`);
`normalizePersonRef` strips the `volumeId#` prefix (`IndexingPipeline.swift:5287-5291`, doc comment at
`:5299`) on the v13 premise that "each part carries its own copy of the set's persons list"
(`:456-463`) — false for these three (0 `persName xml:id` in each).

**Verified against the live index, 2026-09-12 (MEASURED, read-only `mode=ro` over
`~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db`,
552 volumes / 316,839 documents, every `document_revisions` row at index version 50).** The orphan rows
exist at runtime, and their count is the per-(document, ref) dedupe of the store's per-mention count:

| volume | documents | `persons` rows | `person_mentions` rows (distinct refs / documents) | rows joining to no `persons` row |
|---|---|---|---|---|
| `frus1932v04` | 794 | **0** | 2,552 (434 / 783) | **2,552** |
| `frus1918Supp01v02` | 912 | **0** | 2,114 (108 / 884) | **2,114** |
| `frus1917Supp02v02` | 459 | **0** | 864 (92 / 422) | **864** |
| sibling `frus1932v03` | 799 | 597 | 2,257 (308 / 781) | 0 |
| sibling `frus1918Supp01v01` | 927 | 267 | 2,477 (227 / 907) | 0 |
| sibling `frus1917Supp02v01` | 725 | 212 | 1,771 (172 / 705) | 0 |

So 98.6% of `frus1932v04`'s documents already carry an editor-asserted, identity-bearing person ref
that no surface can show, because the ref's `persons` row lives in the sibling part. Corpus-wide the
index holds **6,288** `person_mentions` rows joining to no `persons` row; **four** volumes carry
mentions and zero `persons` rows — the three above plus **`frus1873p1v2` (454 rows, 37 refs)**, whose
own 57-entry list sits under `xml:id="correspondence"`, a spelling #740's `personsSectionIds`
allow-list (`FRUSDocumentParser.swift:1477-1486`) does not carry, although its doc comment says both
1873 parts use `correspondents` (`frus1873p1v1` does and has its 57 rows). The remaining orphans
(`frus1969-76v14` 129, `frus1964-68v23` 53, …) are a different, smaller class not examined here.

**The app view today is therefore 267 volumes with zero `persons` rows, holding 198,936 documents**
— not the Program doc's 268 / 199,246 of 2026-08-07: `frus1873p1v1` has since gained its list (#740)
and nothing else moved. It is the same *count* as the TEI-rule 267 and differs from that set by exactly two volumes, compared
against `scope.json`: `frus1873p1v2` is in the app view and out of the TEI rule, `frus1941-43` the
reverse.

This is an editor-asserted identity signal at zero model cost. A cross-part join changes both volume
censuses (app view and TEI rule) for three volumes before any of #234 is scoped, and any synthetic
namespace must not collide with these already-stored fragments.

### 4.a Editor-marked names only — "Correspondents, from FRUS markup"

**What a reader sees.** A bundled presence-grain artifact writes one `persons` row per (volume,
normalised surface) and one `person_mentions` row per (volume, document, synthetic ref). People
browser: ~**30,327** new per-volume entries (48% of today's 62,818, issue #234 readiness comment) `[APP]`, a median of **103** distinct
names per volume (max 696) `[CEN]`, **83.1% of its mention rows single-token surnames** `[APP]` (the
entry-grain share is unmeasured), top entries seward / johnson / hay /
bayard / fish, each entry per-volume with no cross-volume merge — so two "seward" entries from two
volumes are asserted neither to be one person nor to be different. Person search answers "documents
where this correspondent is named" — 0 false keys on the 64-document sample, not a corpus-scale
guarantee. Analytics trajectories would over-count under COUNT(\*) by at most the last-token collision
proxy, **0.89%** (1,988 of 223,600 presence rows, `[APP]`) — a bound, not a measured over-count. The co-mention graph's new edges are from↔to pairs — **a correspondence
network, which must be labelled as such, not as co-mention**. Inline links light for editor-marked
names on the parse-time route, or on the artifact route after a converter change (§3.1).

**Measured quality at the consumed grain (n = 64 / 406 / 288).** Presence P **1.000**, R 0.274, F1
0.430 — **0 false name keys of 79**; relaxed mention P 1.000, R 0.217 (quote 21.7%); strict P 0.602 is
the title convention (53 exact + 34 title-extended + 1 split of 88 seeds), not wrong people. Reaches
**49 of the 62** gold documents that name anyone (79.0%) `[APP]`. Corpus: **159,182 of 197,534**
documents (80.6%), 94.2 / 75.5 / 85.5 / 65.4% by band, **97.8% of them header-only** `[CEN]`.

**What it must not claim (M3).** Not "people named in this volume" — *correspondents*. No identity,
no POCOM role, no "Reconciled identity" seal (gated on `authorityId`; a derived row must carry a
distinct Derived marker and a `.frusText` tier-1 chip — "came from FRUS", not "what FRUS says"). Not
the app view's 268 volumes. Its scope is the TEI rule's 267, of which 4 carry zero marks and 3
already carry sibling refs (§4.0). Not that its analytics counts are document counts until the two COUNT(\*)
queries change. Not that a derived entry is the same person as any editor-listed one.

**Engineering pieces (INFERRED 2–3 sessions).** (1) The clusterer code gate: a derived-namespace
record is never merged by the name × era heuristic, never bridged into an authority-covered cluster,
never sealed; joined only on authority-id equality or an explicit user must-link; fixtures for the
surname-only overlapping-era case; `currentPersonRollupVersion` **9 → 10**. (2) The synthetic-ref
namespace in code: deterministic from (volume, normalised surface) — never ordinal, because
`PersonClusterOverride` (`:33-45`) and `SavedSearch.parametersData`'s `PersonRollupAnchor` rebind
through (volumeId, ref) and must survive a regeneration; a prefix that cannot collide with any TEI
`xml:id` or the §4.0 fragments; a test that INSERT OR REPLACE on `persons` never touches an editor
row. (3) Generation-time `isLikelyPersonName` filtering with the refusal count printed. (4) Route a2:
a new bundled resource on the `applyDocumentSubjectsIfNeeded` pattern (`IndexingPipeline.swift:7642`;
stamp `v2:<digest>@<generated>`; precedent 0.8 s for the bucket table, `:7656`), an `applyDerivedPeopleIfNeeded`
backfill, the per-volume re-apply hook in the store path, a `removeVolume` delete; **no
`currentDateIndexVersion` bump** (route a1, parse-time synthetic refs, would bump 50 → 51 and cost
every device the ~10-minute owner-measured reindex — `DEVELOPMENT-PLAN.md:2020`, no device or library
size recorded for that figure). (5) Additive `source` column on `persons`, carried to `person_rollup` worst-of-members; a
Derived marker distinct from the seal; verified on **both** `PersonIndexView` mounts
(`BrowserView.swift:891` and `PersonIndexView.swift:1082`, the macOS People window). (6)
`topPeopleByMentions` / `mentionTrajectories` to COUNT(DISTINCT volume‖document). (7) `role` populated
from the from/to type at zero cost (the clusterer's role guard reads it). (8) One `xcodegen generate`
+ scheme restore. **No CloudKit deploy** (no `@Model` change).

**Size and machine cost.** 223,505 (doc, K2) pairs / 11,377 vocabulary → **2.63 MB / 589 KB gz**
grouped one-letter `[CEN]`; 2.51 MB compact / 735 KB zlib-9 at a lower-cased key (223,600 pairs)
`[COST]`; 0.88 MB gz flat per-row `[SIZE]` — a bundle non-decision. Packing: seconds; the whole
seven-arm census is 41 s. $0. Owner: 0 h mandatory.

**Defect-class verdict: ACCEPTABLE once the code gate and namespace exist** — the only shape with a
measured wrong-name rate of zero in the gold, asserting no identity; and **NOT acceptable before
them**: read from its code, the shipped clusterer's `decide()` would merge same-surname derived
entries of overlapping era (within `eraGapYears = 30`) — across the 61 volumes of the 1861–1899 band
that is most of them, at a frequency not measured over a real derived table (§7) — and could bridge
one into a sealed rollup. Its user-
visible value is bounded — 21.7% of mentions, 80.6% of documents, header names.

### 4.b Plus detected names — three arms, two acceptable, one not

All figures POST-HOC, n = 64 / 406 / 288. Inputs are free and already run (both stores cover all 267
volumes); marginal machine cost is packing. Requirements beyond (a): the control's rows must ship as
a **repack of the stored run with the OS build string pinned by a test** (NLTagger output is a
property of the build; on-device recomputation would also bypass the M2a gate — only a scored
artifact can be scored); `filter_detections.py` promoted from "a scoring ARM, not a product" (its own
docstring) to a reviewed product rule; a computed-tier chip ("a model read this"); a frequency floor
for per-volume lists (median distinct surfaces ~1,000 control / ~2,700 sweep); COUNT(\*) over-count
12.5% (control) / 16.3% (sweep) fixed as in (a); never into rollup identity. INFERRED +1–2 sessions.

**(b1) Filtered NLTagger alone (∪ editor).** Presence P 0.827 [0.761, 0.888], R 0.795, F1 0.811;
**46 false keys / 64 documents ≈ 1 per 1.4**; per band P 0.845 / 0.949 / **0.745** / 0.783. Under
string equality F1 **0.697**. Per document, the filtered control alone places at least one non-person
in **19 of 64** gold documents (false-positive-free in 45), the raw control in 30 (34 clean), the
filtered sweep in 53 (11 clean) (`reproduce_analysis.json` doc_level). The union patches only the heading-line class (59 of 61) and inherits
the control's 43 false pairs. Reader-visible defects: 35 sub-national toponyms, "Samoan", ships,
"Queen Mother", plus partial/garbled strings. **BORDERLINE** — a lesser class than a wrong identity,
but roughly one visibly wrong or incomplete name per document in 1930–1945 is a floor the owner
sets, not the engineer.

**(b2) Editor ∪ (filtered control ∩ filtered sweep), sweep-side spans.** Presence **P 0.898 [0.852,
0.942]**, R 0.767, **F1 0.828 [0.788, 0.865]**; **25 false keys / 64 documents ≈ 1 per 2.6**; robust to
the credit rule (0.822); highest strict F1 in the record (0.672) because the stored strings are the
sweep's. Per band P **0.980 / 0.973 / 0.745 / 0.842**. Its 24 intersection false keys fall 3 / 0 / 12 /
9 by band, half sub-national toponyms (British Malaya, Kunming, Shensi, Yellow River …), the rest
surnames (Harding, Wolf, Rudolf, Seville) — placeName markup removes about 2 of them. Its misses are
dominated by the heading line, which the editor layer covers only in part (59 of the control's 61
heading-line misses, none of its other 89): after the union the arm still misses 67 of 288 keys
(R 0.767). The precision gain over (b1) excludes zero (+0.071 [+0.028, +0.128]); the F1 gain does
not. Reach: the filtered control alone reaches 57 of the 62 gold documents naming anyone; the
intersection's reach was not measured separately and, as a subset of the control's spans, is at most
57. **ACCEPTABLE as the only detected layer**, subject to an owner precision floor per
band and to a corpus-scale census of the intersection that does not yet exist (both stores exist;
`census.py` runs in 41 s — a next step, not a gap in principle). Size, by analogy with the control
union: **8.99 MB / 2.88 MB gz** grouped `[CEN]` or 10.4 MB / 3.8 MB zlib `[COST]` — under the 19.52 MB
semantic-vectors comparator (CLAUDE.md, SemanticVectorsGenerator entry); a download tier is a bundle decision, not forced.

**(b3) Any sweep-bearing presence arm** (filtered sweep alone, ∪ editor, three-way union). Presence P
0.527–0.528, **241–242 false keys / 64 documents ≈ 3.8 per document**; three-way P 0.491, 292 false;
at least one non-person in 53 of 64 documents. The defect is mostly governments, offices and places
(10 of 358 residual FPs are name-shaped) — but at four entries per document a People browser is
unusable and the office class ("the Khedive") misleads by denoting a person without naming one.
**NOT ACCEPTABLE at a presence surface**, which is also the record's own reading: on relaxed presence
the 11.55-day sweep ties an 8-minute pass at best and its raw form is significantly worse. Size
22.2 MB / 7.19 MB gz `[CEN]`.

**Must not claim (all of b):** that a detected entry is editorial; that its count is a document
count; that its name string is the person's name (partial strings are structural on the control
side); that it covers people rather than surfaces. Wording: "Detected name", tier computed; never
the seal.

### 4.c Plus identity reconciliation — the shape the issue describes

**What a reader would see.** Derived entries joined to POCOM careers and to existing rollups. The
ceiling on the marked layer is a POCOM candidate on **80.4%** of (document × surface) rows and a
*single* candidate on **55.3%**; on the union with the detector layer 44.5% / 23.7%; 3.4% of the
detector's 135,393 novel surfaces are uniquely anchored `[POC]` — ceilings. An auto-link on
"unique-by-year" would assert an identity of unmeasured precision on ~55% of marked rows and hand
the wrong Seward a sealed entry (Seward: 13 unique of 9,551).

**Measured quality.** None. The 300-row instrument is 0 keyed; the M2a gold has no identity column;
no keyed sample exists for the novel surfaces.

**Must not claim.** The seal means authority-crosswalk match; a machine join through
`.ohPeopleRegister` would light a chip literally correctly while asserting a computed identity —
the seal must not light and a joined-tier disclosure of its own is needed. `[PROG §5]` constraint 5
governs: candidates (`person_cluster_candidate`, "never auto-merged", `PersonClusterer.swift:71-73`),
never merges, except on authority-id equality or user must-link; under-merge bias means
fragmentation is the accepted cost.

**Cost.** Owner: **2–3 h** to key 300 rows (documented estimate) plus an INFERRED 2–4 h R-3 verdict
sitting. Machine (INFERRED from the vector store's measured 28.2 chunks/s — 605,900 chunks / 21,464 s
over 553 `~/frus-semantic-raw/vectors/*.head.json`, re-summed over heads written on two machines,
552 on the Studio and 1 on the Air): R-2
≈ 3.9 h over the control's 1.26M mentions, ≈ 8 h over the sweep's 2.6M; the Ride-Along priced 4–7 h
for ~750k (~250k marked + ~500k unmarked), so the like-for-like comparison is against the NOVEL
counts — control 1,273,179 (×2.5), sweep 3,406,323 (×6.8) — and the 3.9 h figure embeds 80,567
control rows that overlap an editor mark and need no re-embedding;
"≈ 0 h by reusing the stored chunk vectors" is a representation substitution with a measurement owed
(the stored vector is a 3,200-char chunk under a document prompt, not a per-mention window).
Adversarial review of a 20–30% uncertain band over 33k–102k identity decisions ≈ $15–60 Haiku-class
(INFERRED rescale of `[RIDE §4.4]`'s $45–90 per 100–150k; Sonnet-class ~3×; full population ≤ ~$200);
electricity < $1. Engineering INFERRED +4–6 sessions. **Cost is not the constraint; the owner
sitting is.**

**Defect-class verdict: NOT SHIPPABLE on current evidence.** Every gate that blocks it is owner-only
or undefined, and M2a moved none of them.

### 4.d What the 11.55-day sweep is for

Not a presence layer (§4.b3). It is sunk, non-deterministic, and 27 of its 267 volumes were written by
an unrecoverable harness revision that shows no effect on its gold score. In order of value: (1)
**the name string** — the only arm with usable boundaries (strict 0.608 vs 0.398; 0.653 vs 0.563 with
titles stripped), which is what `persons.name` shows; in the agreement arm it supplies the displayed
string while NLTagger supplies the veto; (2) **the second vote** that lifts precision to 0.87–0.90
with no new model run; (3) **a recall-first review queue** — the three-way union finds 98.0% of
mentions at P 0.44 (relaxed, mention grain) and misses 7 presence keys (archibald campbell, aspíroz,
campbell, chou, george washington, king, william h. seward); the filtered sweep's own 28 misses are 16
unmarked prose names plus signatures and headings (§2.4); (4) **the
offset-bearing layer** if an inline-linking surface for unmarked names is ever designed, after an R-0
→ render-text mapping that does not exist. It is not evidence for identity, roles or dates.

---

## 5. Gates

| gate | status 2026-09-12 | owner | what unblocks it |
|---|---|---|---|
| `[PROG §5]` (1) eval set first | **met for detection** (M2a 64/72, 406 mentions, scored); **not met for identity** | — / owner | the 300-row sitting |
| (2) out of interactive scope | binding; every LLM step here is scripted batch | — | — |
| (3) pilot before corpus, pre-1910 first | **binding and already bypassed once** — the sweep ran all 267 volumes before any precision existed; the "harvest is not shipping" seam is an inference | **owner** | an explicit exemption for editor markup (asserts no identity), or a pinned pre-1910 population: **85 volumes / 53,894 docs by manifest `dateRange.earliest` vs 76 / 42,672 by volume-id year** `[COST]`. The pre-1910 gold already exists — 27 documents / 229 spans from 9 volumes: filtered sweep strict 0.702 / relaxed 0.760, raw sweep 0.616 / 0.667, filtered control 0.379 / 0.708, editor baseline relaxed R 0.258 (`pre1910_check.json`) |
| (4) synthetic-ref namespace / force-merge-only / bump batching | **undefined anywhere** (circular pointers; batching alone has a general rule) | engineer drafts, **owner ratifies** | writing them as a `PersonClusterer` code change + tests, not a document |
| (5) confidently-wrong person is the worst defect | binding; **violated by default** under the shipped clusterer for any derived row | engineer | the code gate; rollup 9 → 10 |
| M2a keyed | **done, 64 of 72**; simulation puts keying the 8 at 0–1 of 10,000 draws meeting the stopping rule (§1.2) | owner (optional) | keying them **only** as a held-out set for scoring any gazetteer or heading-line rule derived from the 64 |
| N-1 scored | done 2026-09-12; stopping rule unmet, unmeetable | — | — |
| N-2 detector choice + build plan | **this document is the reading; the decision is owed** | engineer | owner decisions in §6.3 |
| N-3 / W-7a (more models) | refusal lapsed; needed only if N-2 wants a third detector | engineer | N-2 |
| **300-row identity eval** | **0 of 300 keyed** | **owner only** | ~2–3 h; 100 rows pre-1910 halves it and prices only that slice; prices marked from/to names only |
| M1b / R-4 (derived rows reach the app) | not started; no app code reads any NER store | engineer | gates (4), (5); one xcodegen; no CloudKit deploy |
| M3 provenance | not started; vocabulary exists (8 `ProvenanceSource` cases, chips at 3 sites, seal on `authorityId`); no per-row source field | engineer + **owner wording** | additive `source` column; Derived marker; wording approved |
| R-2 mention-context vectors | not started; harvest-unblocked; cost basis stale ×2.5 (control novel) to ×6.8 (sweep novel) | engineer | pursuing (c) at all |
| R-3 identity clustering + adversarial tier | not started | engineer, gated on owner | the 300 rows keyed; rules written |
| §4.0 cross-part corresp | **MEASURED in the live index**: 5,530 orphan `person_mentions` rows across the three volumes against 0 `persons` rows, 6,288 orphans corpus-wide, plus `frus1873p1v2`'s unread list (454 rows) | engineer | a cross-part join (or a decision to drop the rows) and the `correspondence` spelling in `personsSectionIds` — both #740 / v13-class defects, filed separately from #234 |
| precision floor for any detected layer | **unset** | **owner** | a per-band floor against (post-hoc, n = 64; the 1930–45 band is 15 documents / 44 gold keys): editor ∪ agreement arm ≈ 1 wrong name per 2.6 docs (25 / 64), 1930–45 P 0.745 [0.633, 0.897]; editor ∪ filtered NLTagger ≈ 1 per 1.4 (46 / 64), 1930–45 P 0.745 [0.629, 0.898]; filtered NLTagger alone 1930–45 P 0.698 [0.567, 0.875] |
| on-screen wording | unset | **owner** | "Correspondent from markup" / "Detected name"; never "Reconciled identity" for a derived row |
| bundle-size decision for (b) | open | **owner** | ~2.9–3.8 MB compressed (control-based) vs ~7.2 MB gz (sweep-based); under the 19.52 MB comparator |
| OS-build pin + filter promotion for (b) | not started | engineer + review | repack, not recompute; pinned build string test |
| corpus-scale census of the agreement arm | **not measured** | engineer | 41-s-class pass over the two existing stores |
| identity-grain / string-equality re-score | string-equality **done** (§2.2); last-token identity proxy grain **not scored** | engineer | a small script over the existing gold and stores |
| on-device rollup consolidation time at 62,818 / ~93k / ~340k persons rows | **recorded nowhere** | engineer | a measurement on a real device |
| errata in the record (§1.5) | open | owner authorises | edits to NER-RUNBOOK §3, §7.2, SUBSET.md, the Ride-Along |

---

## 6. The verdict on feasibility

### 6.1 By shape

| shape | feasible? | on what | blocked by |
|---|---|---|---|
| **(a) correspondents from markup** | **Yes, narrowly** — after a code gate, and re-scoped from "people" to "correspondents" | P 1.000 / 0 false keys (n = 64); 80.6% of 197,534 docs; 589 KB gz; no reindex; no deploy | the undefined rules, written as code; §5(3) exemption or a pinned pre-1910 cut |
| **(b2) + detector agreement arm** | **Yes, conditionally** — behind an owner precision floor | presence P 0.898 [0.852, 0.942], 25 false names / 64 docs (post-hoc, n = 64); robust to the credit rule | the floor; a corpus-scale census; OS-build pin; filter promotion; bundle decision |
| (b1) + NLTagger alone | borderline | P 0.827, 46 false / 64; falls to 0.697 F1 under string equality | the floor, with partial/garbled strings accepted |
| (b3) any sweep-bearing presence layer | **No** | P 0.53, ≈ 3.8 wrong names per document | — |
| **(c) identity** | **No, on current evidence** | 0 of 300 keyed; 55.4% / 12.7% are ceilings; seal cannot say "machine guess"; clusterer bridges | the owner sitting; rules in code; a per-band precision |

### 6.2 The first slice, if the owner proceeds

1. **Step 0 first** — the §4.0 cross-part join, now verified in the live index (5,530 orphan mention
   rows over 2,165 documents in the three split-set parts), and the `correspondence` spelling that
   leaves `frus1873p1v2`'s 57-entry list unread. Both are shipped defects of the #740 / v13 class, not
   #234 features, and together they are the cheapest early-era gain in the whole program.
2. **Shape (a) whole-scope** — the evidence supports skipping the pre-1910 pilot for it: engineering
   is slice-independent, machine time is seconds, editor markup asserts no identity, and its
   precision is 1.000 on every band's gold. **But §5(3) is still listed as binding and the exemption is
   the owner's, not the engineer's.** If it is refused, the pre-1910 population must be pinned (85 vs
   76 volumes); on the manifest rule it holds 108,288 of 245,747 marks (44.1%), 12,654 persons rows,
   3.95 of the sweep's 11.55 sunk days.
3. **Shape (b2)** as an owner decision after (a) has exercised the whole ingestion path (persons +
   mentions + rollup gate + chip + re-apply), not before. A pre-1910 slice of (b) is *not*
   informationless: the control's per-band flatness is relaxed-only at ~100 mentions per band (strict
   rises 0.347 → 0.492), and a persons-grain name-string measurement is cheapest there.
4. **The pre-1910 pilot is the right slice for (c)** — from/to is 95.9% of marks in the TEI-rule store,
   the markup share is highest pre-1900 (66.0% best volume vs 12.4% worst post-1946, `[M1a]`), 100 of
   the 300 eval rows sit there, and R-2 would be ≈ 1.4 h against 3.9 h. Nothing in (c) can start
   before the rows are keyed.

### 6.3 The decisions the owner must make

1. **Offsets vs presence is settled by the code, not the owner: presence.** The real decision is the
   **name-string grain**: accept, or refuse, a People browser whose new entries are per-volume surface
   strings with no identity and no cross-volume merge, disclosed as derived — two "seward" entries
   asserted neither same nor different, and 83.1% of the mention rows behind them bare surnames.
   Refusing it refuses (a) and
   (b); accepting it re-scopes the issue.
2. **Whether "correspondents from FRUS markup" counts as extending the People browser.** It reaches
   80.6% of documents and 21.7% of mentions, and lists who wrote to whom. All four verdicts agree it
   must be labelled so.
3. **Ratify the derived-entry rollup rule as a code change** (no heuristic merge, no bridging into
   covered clusters, no seal) and the synthetic-ref namespace — the rules #259 was closed to protect,
   which exist nowhere.
4. **Grant or refuse the §5(3) exemption** for editor markup; if refused, pin the pre-1910 rule.
5. **Set the precision floor, per band, for any detected layer** (§5).
6. **Approve the wording**: "Correspondent from markup" / "Detected name"; never the seal.
7. **Decide the bundle question for (b)** (~3 MB vs ~7 MB compressed) or a per-volume download tier.
8. **Key the 300 rows** (or the 100 pre-1910 rows) before any POCOM-anchored identity is built — the
   only instrument that turns 55.4% into a precision; and accept that no keyed sample exists for the
   1.18M novel surfaces.
9. Optionally, key the 8 unkeyed documents **only** as a held-out set for rules derived from the 64.

### 6.4 What would change the verdict

- **For a detected presence layer to move from "conditional" to "acceptable without a floor
  argument":** a document × identity-grain P / R on a fresh, era-stratified sample of ≥ 100 documents
  drawn from the corpus length distribution (not 800–8,000 chars), scoring the sweep-side agreement
  arm and editor ∪ filtered control at persons-name grain under string equality, with the agreement
  arm's presence-precision interval lower bound ≥ 0.85 and ≤ 1 false name per 3 documents in every
  band. These thresholds are this assessment's, not pre-registered anywhere. Two halves are cheaper
  than that: the string-equality reading already exists (§2.2), and the last-token identity proxy
  (288 → 238 keys) is a small script over the existing gold — what the existing gold cannot give is
  corpus-scale precision, which stays unbounded.
- **For identity:** the 300 keyed rows with unique-in-year candidate precision ≥ 0.90 pooled and
  ≥ 0.80 in every 75-row band (±5.6 / ±11.3 half-widths), a passing test that a synthetic-namespace
  record never merges by heuristic, and a measured per-volume rate at which one surname denotes more
  than one officeholder inside the volume window (the Seward case) to size the disclosure.
- **For (a) to become unacceptable:** a live-index finding that the clusterer gate cannot be written
  without breaking editor rollups, or an owner refusal of the name-string grain.
- **For the sweep to matter for presence:** an inline-linking surface for unmarked names, designed
  and wanted.

---

## 7. What this assessment does not settle, and what expires when

**Not settled.**

- **Corpus-scale precision of any detector arm** — unbounded; the 64-document sample is lighter than
  the corpus and length-windowed.
- **Identity-grain scores** — no arm is scored at (document, identity); every presence figure is
  surface-keyed, ~17% above an identity count.
- **The agreement arm's corpus-scale rows, reach and size** — unmeasured (both stores exist).
- ~~Whether the §4.0 orphan rows exist at runtime~~ — **settled**, measured in the live index (§4.0);
  what remains open is the cross-part join's design.
- **On-device rollup consolidation time** at 5× today's persons rows — recorded nowhere; the drift
  check fires the rebuild on every device on first launch regardless of a bump.
- **iOS-device NLTagger throughput** — unmeasured (moot for a repacked artifact).
- **The frequency of the clusterer's default merge on real derived rows** — the mechanism is
  documented code; the count needs a live consolidation over a derived table.
- **Whether the 42% strict/relaxed gap on the control would be seen by readers** as wrong names —
  7 of 32 are garbled; the rest are partial or title-extended.
- **Any gazetteer's effect** — designed on the 64 documents, scorable only on held-out documents.

**Expiry.**

| figure family | pinned to | expires when |
|---|---|---|
| every M2a figure (§1.2–1.3, §2.2–2.4) | gold at 64 / 72 / 406 / 288, conventions as ruled 2026-09-12, scorer `match()` | the gold is re-keyed, conventions change, or the 8 are keyed (intervals narrow; verdicts do not move) |
| every post-hoc arm and grain | chosen after §7.2 existed | a pre-registered re-score on a fresh sample supersedes them |
| NLTagger rows and every control figure | OS "Version 26.6.2 (Build 25G83)" | any regeneration on another OS build |
| sweep rows and figures | one non-deterministic run; 27 volumes under an unrecoverable revision | any re-run |
| census rows, pairs, surfaces, sizes | the stores as of 2026-09-12; the K2 / lower-cased keys; the frozen filter SHA `dd64d8dc` | a filter rule change, a new text layer (R-0 coordinates), or a different key |
| POCOM ceilings | POCOM HEAD `ccc1f033` (no data commits since 2026-08-07); `manifest.json` `dateRange`; the m1a surname-only rule (with its regex loader's two missed `<date certainty>` / `<principal treatAsConsecutive>` records, ≤ 8 rows) | a POCOM data commit or a matching rule that uses given names |
| app-mechanism facts and file:line | HEAD `bd394443` | any edit to `IndexingPipeline.swift`, `PersonClusterer.swift`, `PersonIndexView.swift`, `PersonMentionStore.swift`, `ProvenanceSource.swift` |
| the 10-minute reindex | `DEVELOPMENT-PLAN.md:2020`, no device or library size | never verifiable as stated |
| engineering session budgets | one calibration point (PR #737) | the first real session |
| dollar lines | `[RIDE §4.4]`'s 2026-08 per-candidate pricing, rescaled | any model-price change |
| the 62,818 persons rows and 268 / 199,246 app-view figures | the owner's index at 2026-08-19 / 2026-08-07 | the next reindex or the §4.0 fix |

---

## 8. Sources

**Evidence root:** `Planning/early-era-people/feasibility-2026-09-12/` — every script, log and summary JSON named
below is preserved there under its agent's directory (the per-arm `artifact-*.json` files, 2.6–22 MB each, and
the raw error listings over 3 MB were not copied; each is regenerable from its script against the stores). The
`synthesis/` folder holds `apply_critique.py`, the exact replacements the completeness pass applied to the draft.

**Measured in this assessment (script → output), each reproduced by two independent verifiers:**

- `[CEN]` `measure-census/census.py` → `census.json`, `artifact-<arm>.json[.gz]`, `artifact-roundtrip.txt`; reproduced by `verify-measure-census-reproduce/verify.py` → `verify.json` and `verify-method/census_rerun.py`; union dedup `verify-method/union_dedup_top.py` → `union_dedup_top.json`.
- `[GR]` `measure-grains/grains.py` → `grains.json`, `grains.log`, `key-lists.txt`; `paired.py` → `paired-differences.json`, `paired.log`; `score-detections.json` (positive control 1); reproduced by `verify-measure-grains-reproduce/verify.py`, `tie.py` and `verify-measure-grains/rerun-*.log`.
- `[GR-V]` `verify-measure-grains/analyze.py` → `analyze.log` (rankings, grain shift, band false keys, string-equality variant §7, last-token collapse §8); `followup.py` → `followup.log` (heading-line positions; overlap-credited non-matching keys); `placename.log`.
- `[ERR]` `measure-errors/extract_errors.py` → `errors-raw.json`; `categorise.py` → `errors.json`, `listing-*.txt`; reproduced by `verify-measure-errors-reproduce/verify.py`, `recount.py` and `verify-me-method/positive_control.py`, `recompute.py`.
- `[POC]` `measure-pocom/measure_pocom.py` → `pocom.json`, `per-volume.csv`, `run.stdout`; reproduced by `verify-measure-pocom-reproduce/verify.py` → `verify.json`; `verify-pocom-method/nobody_band.py` → `nobody_band.out`, `repro_pc2.py` → `repro_pc2.out`. (`pocom.json`'s `interpretation` and `positive_control.sample_population_gap_explained` blocks were added after the run; `repro_pc2.py` reproduces them.)
- `[APP]` `verify-read-app-method/measure.py` → `measure.json`; `[SIZE]` `read-app/grain_sizes.py` → `grain_sizes.json`; reproduced by `verify-read-app-reproduce/grain_repro.py`, `persname_scan.py`, `corresp_context.py`.
- `[COST]` `read-cost/slice.py` → `slice-output.json`; `persons_rows.py` → `persons-rows-output.json`; `effort-ladder.json`; reproduced and extended by `verify-read-cost-reproduce/rows_check.py` → `rows-check-output.json` (union pairs, serialized bytes, pre-1910 by both rules).
- `[SCORE-V]` `verify-read-scores-reproduce/score_mine.py`, `sim8.py`, `filter_in_sample.out` (its script was not kept), `sum_heads.py`; `verify-method/reproduce_analysis.py` → `reproduce_analysis.json` (segment split, bootstrap, doc-surface proxy), `strip_titles.py`, `union_check.py` → `union_check.json`, `pre1910_check.py` → `pre1910_check.json`, `linked_check.py` → `linked_check.json`, `score-rerun.json`.
- `[PROG-V]` `read-program/verify_gates.py` → `verify_gates.json`, `issue-234.txt`; `verify-read-program-reproduce/count_stores.py` → `count_stores.json`, `rescore.py` → `rescore.json`, `bootstrap.py` → `bootstrap.json`.

**Documented (read):**

- `tools/semantic-harvest/NER-RUNBOOK.md` v1.8 §0–§10 (`[RB]`); `tools/semantic-harvest/score_detections.py`, `ner_store.py`, `filter_detections.py`, `stage_m2a.py`, `harvest_ner.py`.
- `/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/`: `score-detections.json` (`[SD]`), `m2a-ground-truth.jsonl`, `m2a-ground-truth-documents.jsonl`, `m2a-manifest.json`, `progress.csv`, `SUBSET.md`, `M2a-INSTRUCTIONS.md`, `AUDIT-PROPOSED-CORRECTIONS.md`, `AUDIT-2-PROPOSED-CORRECTIONS.md`, `audit-2026-09-12/adjudication-workflow.js`, `audit-2026-09-12-second-sitting/m2a_analysis64.py`, the typed annotation files.
- `Planning/People-Early-Era-Program.md` (`[PROG]`); `Planning/early-era-people/M1a-Findings.md` (`[M1a]`), `m1a_survey.py`, `m1a-eval-candidates.csv`; `Planning/M2-Semantic-Pipeline-Ride-Along.md` (`[RIDE]`); `Planning/Completed/Issues-233-243-Plan.md`; `Planning/Plan-Of-Record-2026-08-28.md`, `-2026-09-06.md`, `Completed/Plan-Of-Record-2026-08-17.md`; `Planning/DEVELOPMENT-PLAN.md`; `Planning/Completed/Feature-Priorities-Review-2026-08.md`; `CLAUDE.md`; `gh issue view 234 --comments`; `gh pr view 737, 1285–1289`; `gh issue view 740, 741`.
- Stores: the live index `~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db` (read-only, `mode=ro`, index version 50, 552 volumes / 316,839 documents); `~/frus-ner-raw/{scope.json,marked/}`; `~/frus-ner-raw-control{,-filtered}/`; `~/frus-ner-raw-filtered{,-boundary}/`; `/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw/detected/`; `~/frus-semantic-raw/{text/,vectors/}`; `/Users/jbotts/Development/frus/volumes/` (TEI); `/Users/jbotts/Development/pocom/`; `FRUSExplorer/Resources/manifest.json`.
- Code at HEAD `bd394443` (`[CODE]`): `FRUSExplorer/Search/IndexingPipeline.swift`, `PersonClusterer.swift`, `SearchFilterView.swift`, `SearchModels.swift`; `FRUSExplorer/Models/PersonMentionStore.swift`, `SavedSearch.swift`, `PersonClusterOverride.swift`, `CloudKitSchemaInventory.swift`, `PersonRollupRefresh.swift`; `FRUSExplorer/Browser/PersonIndexView.swift`, `BrowserView.swift`; `FRUSExplorer/Analytics/PersonAnalyticsView.swift`, `PersonCoMentionGraphView.swift`; `FRUSExplorer/Collections/CollectionGeneratedBlocks.swift`; `FRUSExplorer/Provenance/ProvenanceSource.swift`, `ProvenanceChip.swift`; `FRUSExplorerTests/ProvenanceChipTests.swift`; `FRUSExplorer/TEI/ASTToRenderNodeConverter.swift`, `FRUSRenderNodeHTMLSerializer.swift`, `FRUSRenderNode.swift`, `FRUSDocumentParser.swift`; `FRUSExplorer/DocumentView/DocumentView.swift`, `DocumentViewModel.swift`; `WordCloudKit/WordCloudTokenizer.swift`; `EarlyEraNERControlCore/PersonMentionDetector.swift`; `Package.swift`; `project.yml`.

**Ledger.** MEASURED: every corpus row, document, surface and artifact-size count (§2.1, §4); every
gold P / R / F1 at mention and presence grain with its interval (§1.2–1.3, §2.2–2.4); the POCOM
ceilings (§2.5); the app's schema and read paths (§3). DOCUMENTED: the harvest totals and the record's
own intervals and conventions (§1); the runbook's, Program doc's and Ride-Along's statements. INFERRED:
the session budgets; the R-2 hours and dollar lines; the ~18%-of-rows extrapolations (deliberately not
quoted — a grain shift); the §4.0 runtime consequence; the "would pass as a person" and
"vocabulary-removable" judgements (one reader, in-sample); every threshold in §6.4. POST-HOC: every
union, intersection and presence-grain figure.

Nothing under the repository, `~/frus-*`, or the Mac Studio folder was modified by this assessment;
no git state changed.

---

## 9. Verification of this document

**Re-run or reproduced independently before being quoted** (by two verifier passes per report; † =
also by hand in the writing session):
- the six published strict / relaxed rows — the official scorer re-run plus two independent scorers,
  dict-equal to `score-detections.json`;
- both runbook unions (0.794 / 0.646), which reproduce only under exact-duplicate dedup;
- the census — twice, with an independent key implementation; artifacts byte-identical;
- M1a Measurement 3 — reproduced exactly from its verbatim code against today's POCOM checkout;
- every FP and miss count — the scorer's own residues, recounted by a second script;
- the harvest totals — re-summed from all 267 heads of each store;
- the 9,215 cross-part `corresp` rows — recounted from the marked layer, and the TEI's 10,616
  `corresp="<sibling>#…"` attributes (5,743 / 3,395 / 1,478) re-grepped †;
- the live-index rows in §4.0 — queried read-only on 2026-09-12 †;
- the `PersonClusterer` and `IndexingPipeline` lines cited in §3.4 and §4.0 — re-read at HEAD
  `bd394443` †.

**Reproduced only approximately, and quoted with that caveat:**
- the "0 of 10,000 draws" simulation for the 8 unkeyed documents — 0–1 of 10,000 under a different
  seed;
- the stripped-title check (0.653 vs 0.563) — 0.661 on re-implementation;
- the band-stratified bootstrap intervals — within 0.3 points across two implementations and seeds.

**Not independently verified:**
- the "+57 mentions" non-determinism figure (§1.4 item 7), which conflates decoding non-determinism
  with an OS / LM Studio build change between the two pilot arms;
- every FP and miss CATEGORY in §2.4 — one reader's judgement, corroborated only by the second
  audit's zero missed mentions;
- the session budgets, the R-2 hours, the dollar lines and every threshold in §6.4 — INFERRED;
- the frequency of the clusterer's default merge over real derived rows — the mechanism is read from
  code; the count was never run;
- corpus-scale precision of any arm — unbounded by any measurement here.

**How this document was produced.** Eight evidence agents (four readers, four measurers), two
verifiers per report (one re-deriving the numbers, one auditing the method), four assessors under
distinct lenses, two scoring judges, one synthesis writer and one completeness critic — 32 model
instances in one orchestrated run on 2026-09-12; the critic's items and the live-index measurement
were applied by hand afterwards, with every replacement checked to match the draft exactly once. The
M2a audits it cites were model adjudicators too (§1.4 item 5). Every number here traces to a script
and output path under §8; none was carried from a model's memory.
