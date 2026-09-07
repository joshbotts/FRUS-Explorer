# Plan of record — week of 2026-09-06

**Supersedes `Plan-Of-Record-2026-08-28.md`**, which is two days stale in five specific ways
recorded in §4. Written against the tree at `7b07147c` (build 45 shipped 2026-09-04, index format
version 49).

**What this document is for.** It separates the work that can start today from the work that
cannot, and states the blocker for every row in the second group by name. It was built by reading
all 26 live planning documents and then screening every "startable" claim against the tree and the
session log — 36 candidates, **16 of them cut** as already shipped or genuinely blocked. The cut
list is in §3, because a plan that only lists survivors invites the same re-derivation next week.

---

## §1 — The week's work

Ordered by what a reader of the tree would want fixed first, not by size.

### 1a. Shipped things that do not do what their own design says — DONE 2026-09-06

Seven defects, each landed as its own commit in the PR that carries this plan. Listed here because
the next plan should not re-derive them.

| | What was wrong | Fix |
|---|---|---|
| PV §5 / Q-1 | The export block claimed to carry a parse residual and never did; the session entry asserting otherwise was false the day it was written | `provenance.parseResidual.disclosure`, conditional on an archival-sources block |
| R-5 §8.2 Q-9 | A volume removed and re-downloaded across a parse change was stamped "changed by an update" for every document | `document_revisions.index_version`, bound in both upsert arms |
| V §7 item 1 | `46,234` travelled through two shipped doc comments without the predicate that produced it | Re-measured to **45,030 of 316,839**, predicate stated, plus the axis's **96.7%** reach over it |
| NARA §4 | Five documented `PROJECT_ONLY=1` promises were false — the raw store is gone, and Step 4a's "required" consolidation is now destructive | All five corrected; restoration cost stated |
| NARA 37 units | The "37 file unit gap" was explained as a filter under-returning | Resolved: a NAID-counting artifact over a series NARA re-describes; the two sets are not nested and their union **exceeds** NARA's own count |
| VM refusal 16 | `FrameTimeProbe`'s doc block argued it was *not* `#if DEBUG`-gated. It is | Block rewritten; gate untouched |
| W-19 C-table | The plan owning the C-rows had not recorded C-0b, and its two-by-two did not say which block length each cell measured | C-0b row added; lengths stated |

### 1b. Designed and unbuilt — the semantic cluster

The designs are written and every input is present (`~/frus-semantic-raw`, 2.2 GB). This is the
largest coherent body of work left that needs nobody's permission.

| Row | What | Size |
|---|---|---|
| **S-1** | **V-3 §6.1 item 2** — the semantic axis is generator-only; it never re-scores the other generators' candidates. `RelatedDocumentsEngine.swift:144` | M |
| **S-2** | **V-3 §6.2 / OS-27 §5.5** — Project Leads runs N per-seed engine ranks where one centroid retrieval would do. `ProjectLeadsService.swift:33-39` | M |
| ~~**S-3**~~ ✓ | ~~**V-3 §6.2(a) / §7 item 2** — off-index volume-grain leads: *"N strong matches in a volume you don't have"*. A second Tier-1 Hamming scan in `SemanticSimilarityGenerator`~~ **SHIPPED 2026-09-06, PR #1235** | ✓ |
| **S-4** | **Map §7.3** — two more bundled corpus lenses (`allTerms`, `descriptors`). **Read the screen's warning first**: `WordCloudKit/WordCloudLens.swift:84`'s `bundledCloudLenses` is the GENERATOR'S ARTIFACT CONTRACT with six consumers, not the backdrop's cycle | S |

**Reconnoitred 2026-09-06, and three of the four rows did not survive it.** The cluster was scoped
from the designs; reading the code changed the answer for all but one.

- **S-3 — SHIPPED** (PR below). The threshold the design leaves open turns out not to be a
  constant, and that is measured: over 60 anchors the Hamming distance of the axis's own 120th
  neighbour ranges **104–162**, while a random corpus pair sits at median 194 with a **minimum of
  105** — the bands overlap, so any fixed cutoff admits nothing for some anchors and a swathe for
  others. The rule shipped instead is the anchor's own band, taken from a scan that has already
  run. Yield at half a library: a median of **94 documents across 19 volumes**, 0 of 20 anchors
  empty. The scan cap is 4,096 rather than the rerank pool's 800 because at a **10% library** —
  the reader this exists for — the median rises to 732 and an 800-cap would bind on **43%** of
  anchors.
- **S-1 — REFUTED, and the reason is stronger than the one first recorded here.** The axis is
  generator-only by construction, not by omission. The ranker consults the **weight before the
  score** (`RelatedDocumentsEngine.swift:87-92` — `guard weight > 0 else { continue }` precedes the
  `isGenerator` ternary), so a fully populated semantic strength map at the shipped weight of 0
  never enters `axisScores`, never reaches `total`, and cannot reorder, add or drop one row. The
  change is invisible to every reader who has not deliberately raised an experimental slider.
  Worse for the row's premise, **S-1 cannot serve the population the axis exists for**: it
  re-scores candidates the *other* generators produced, and the 45,030 documents with an empty
  Related list — the axis's whole justification — have none. Its entire addressable effect is
  reordering rows for readers who both raised the slider and already had candidates. When it is
  eventually taken, three constraints already established should ride with it: write into
  `generatorStrengths` and never `scorerScores` (the ternary would silently discard a scorer on the
  same axis, compiling clean and producing byte-identical output, and scorer scores are used
  **unclamped**, so a negative cosine would read as "no contribution" rather than "dissimilar");
  gate on `weights[.semanticSimilarity] > 0` rather than on data availability, or it falsifies the
  premise `AppState.swift:715-722` rests on when it exempts `.readerAskedForSemantics` from the
  #926 switch; and settle the score floor first, because cosine has no zero and the corpus median
  is ~0.49 — an unfloored re-score puts a "Semantic match · 48%" chip on rows scoring at chance.
- **S-2 — REFUTED BY MEASUREMENT. This row previously read "blocked on a measurement"; that was
  wrong, and the measurement had in fact already been taken.** Three independent grounds, two of
  them measured against the shipped artifacts:
    1. **Scope.** Six of the seven contributing axes are *anchor-keyed by protocol signature*
       (`SimilarityGenerator.candidates(for anchor:)`, `SimilarityScorer.scores(anchor:)`), and a
       project has no anchor — so a centroid can replace exactly one axis, `semanticSimilarity`,
       which **runs zero times at the shipped default**. Replace the per-seed ranks with a centroid
       and you delete every lead source that currently produces leads; add it beside them and you
       add a retrieval and save nothing.
    2. **"Semantically better" is false — it is the *same ranking function*.** For unit vectors,
       `cos(centroid, d)` is a positive rescaling of the per-seed cosine sum `ProjectLeadsAggregator`
       already forms. Driven over the shipped artifacts at k=3 and k=40, the **full 314,483-row
       ordering is identical**, max residual 2.1e-14 — not top-10 agreement, every row in order.
       The one real behavioural difference is that `perSeedRelatedLimit = 30` truncates each seed's
       contribution today, and on a heterogeneous project removing that truncation is measurably
       **worse**: on a real 3-seed project (mean pairwise cosine 0.492) the centroid's top-10
       contains **0 of the 3 seeds' own best neighbours**; at 12 seeds, **0 of 12**.
    3. **The artifact's stated recall does not transfer.** Averaging unlike vectors drives
       components toward zero and the sign bits become noise. Fraction of the exact corpus top-10
       recovered through the shipped 800-candidate funnel: **k=1 → 10.00/10** (the single-document
       regime the artifact's 0.851 describes, intact), k=3 → 8.75, k=12 → 7.50, **k=40 → 6.33**
       (k=40 is `seedCap`). A 40-seed project would lose a third of its own best leads before
       scoring.

  Two hazards the row never carried: a **missing seed shard silently re-centres the project**
  (dropping 1 of 3 seeds leaves **2.6/10** of the full centroid's top-10, minimum 0) where today
  that loss is per-seed and merely thins the list; and the attribution count behind *"Related to N
  of your documents"* becomes an unowned floor decision writing a **CloudKit-mirrored** field, so a
  mixed-build fleet would sort two incomparable score scales in one list.

  **And the cost saving has never been observed.** `ProjectLeadsService.lastCost` is assigned at
  `:309` and **read by nothing** — verified 2026-09-06, the only two hits in the tree are its
  declaration and that assignment — so `RecomputeCost`'s "for the in-app report" describes a report
  that does not exist.

  **Re-scoped, the row is still worth doing**, but as a different thing: *give Project Leads a
  semantic lead source at all — one corpus scan instead of forty* — aimed at the 45,030 empty-list
  documents, not at making the shipped default cheaper. The cheapest alternative if leads *quality*
  is the goal is to raise or drop `perSeedRelatedLimit`'s truncation for the semantic contribution,
  which is the only behavioural difference the centroid actually delivers and keeps per-seed
  attribution honest by construction.
- **S-4 — PARKED, WIP on `claude/s4-two-more-corpus-lenses`.** The loader half builds; there is no
  consumer for it, and the artifact contract warning on `bundledCloudLenses` is the reason to stop
  rather than push through.

### 1c. Provenance and archival residue

| Row | What | Size |
|---|---|---|
| ~~**P-1**~~ | ~~**PV-3's three MIXED sections** — per-row provenance chips~~ **DONE 2026-09-07.** Eight mounts, four per twin, behind one shared `SourceExplorerProvenance`. **Two of the row's three sections were described wrongly** and reading the code changed the work: the pre-1906 country series is NOT "Tier 2 throughout" (its despatch serial is read from the TEI and its own caption says it resolves to no catalogue record) and is mixed between BLOCKS, not per row; and "Pointed At, Not Printed" names `CollectionDetailView`, which has no `anchor` in scope — the branchable section is "Unprinted Material". The lot rule keys on WHICH lookup answered, because **19 of the 20 curated lots return the parser's own string**. 10/10 mutations killed | M |
| ~~**P-2**~~ | ~~**NARA streaming shard write** — 18.5 GB peak; `DEPTH=all` cannot finish~~ **DONE 2026-09-07, and the row's headline is RETRACTED rather than fulfilled.** `writeShard` now streams one record at a time: **2.14–2.36× lower peak**, measured over four real shards, with the streamed peak within 0.7–6.9 MiB of the resident records array. But **`DEPTH=all` is still not finishable** — the array must stay resident (the shard sorts by NAID, and the runner walks it *after* the write for `series-sample.json`), so the extrapolated full-build peak is ~8.6 GB, a 53% cut. Bytes unchanged and now pinned; **nothing pinned them before**. 12/12 mutations killed | M |

### 1d. Assessments and measurements owed

| Row | What | Size |
|---|---|---|
| **A-1** | **C-1 / Tier-E W-12** — the parallel-series concordance assessment (DBPO/DDF/AAPD/Dodis/Wilson Center). The 2026-08-28 plan calls it "the last startable Tier C row"; model it on the W-15 assessment | M |
| ~~**A-2**~~ | ~~**B-4 measurement half** — the query encoder's in-app Metal footprint~~ **DONE 2026-09-07.** Peak footprint **301.6 MB**, post-unload floor **141.4 MB** — ~160 MB while loaded, released completely (ends below its own baseline). Metal peaks **~91 MB LOWER** than the CPU shape (301.6 vs 393), because the mmapped GGUF is resident without being charged to `phys_footprint`. `Planning/semantic-vectors/encoder-footprint-metal.json` | S |
| ~~**A-3**~~ | ~~**VM §3.2 M-6** — measure the in-app decade-accumulation cost~~ **DONE 2026-09-07 — MEASURED, and M-6 is REFUSED as designed.** The row's premise points the wrong way: stripping readback+PNG from the 103.8 ms leaves the **larger** half. The scope step is **57–58% of the frame** (73.9/76.8 ms over two 553-step runs) and **grows 44→93 ms** with the accumulated scope. At decade grain that is 17 steps summing to **1.14 s of blocked main actor** — 17 hitches, not an animation. Viable only if the step is made incremental (accumulation is monotonic ⇒ O(added), not O(corpus)). **The prescribed DEBUG driver was built, could not be run, and was reverted rather than shipped unobserved** | M |

### 1e. Release readiness, startable before the volumes exist

Both de-risk R-1 without an Office of the Historian publication.

| Row | What | Size |
|---|---|---|
| ~~**R-1a**~~ | ~~**NVR §13** — what a *corrected* volume does to the artifacts~~ **ANSWERED 2026-09-07, and it found four live defects.** **Q1 needs no work**: a re-download already forces an unconditional re-index (`indexVolume`'s only guard is file existence). **What was wrong was the scrubbing around it** — `document_dates`, `persons`, `terms`, `document_sources` are per-volume tables written with plain `INSERT OR REPLACE`, so a correction that REMOVED a row stranded it forever, while `auxDeleteVolume` scrubs all four; *delete-then-re-download* was clean and *Update* was not. **Fixed + tested.** **Q2 is not a row-order problem** — row order is safe by construction (verified numerically) — but a **same-count** correction leaves a stale `.vec` shard accepted silently, because shard length is a bijection with document count (552/552) and the purge key is the corpus-free provenance digest. Also fixed: a refused shard was invisible to every repair route | S–M |
| **R-1c** | **Per-volume shard invalidation** (from R-1a). `semantic-shards-manifest.json` already ships `{volumeID, bytes, sha256}` for all 552; record per volume the manifest SHA a shard was adopted under and purge only those whose SHA moved. Keeps the digest-wide purge as the family gate. This is the fix for the silent same-count case | M |
| **R-1d** | **`refreshAfterCorpusChange` is never called on any download path** (from R-1a). Verified: 16 call sites, all in the two hub views; neither `updateVolume` nor a plain catalogue download is among them, though `reindexVolume` two functions below is. **The placement is the open question, not the omission**: `updateVolume` is fire-and-forget so a call there runs before the re-index and would no-op; the completion callback has no main-actor `ModelContext`, and passing `nil` discards the reader's person-cluster overrides | S–M |
| **R-1e** | **Revision stamping on a re-index** (from R-1a, R-5 follow-up). Two reported defects worth verifying before fixing: `auxMarkVanishedRevisions` appears to ignore `.rebaseline`, so a Rebuild Index could stamp `'vanished'` and null `reviewed_at` for documents a parser change stopped emitting; and the `index_version` guard may swallow a genuine correction. **Read as data-loss; not verified by me** | M |
| ~~**R-1b**~~ ✓ | ~~**NVR §13's open code question** — whether any persisted user state names a semantic cluster id~~ **ANSWERED 2026-09-07, and it was not a clean negative.** One carrier (`SemanticMapRequest.focusClusterID`, via window restoration); its guard compared the **vector family** digest, which a relayout does not move, so it passed across precisely the event that invalidates every id. Fixed on a layout identity; the test that named the scenario was a tautology and is replaced | ✓ |

### 1f. One that reduces the owner's own queue

**§7 struck: 0, 1, 2, 3, 4, 6, 7, 8, 9, 11.** Machine-checked against `Visual-Marketing-Plan.md`
itself by `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan`, which exists
because the two documents once disagreed for a day across fourteen merged PRs and neither was
implausible to read. The gate moved here on 2026-09-06: it had been reading
`Plan-Of-Record-2026-08-28.md`, whose own header says *"do NOT read its row states as current"* —
so the check against staleness had itself gone stale. It now finds the one plan of record not
marked SUPERSEDED, and fails if there is not exactly one.


| Row | What | Size |
|---|---|---|
| ~~**F-1**~~ | ~~**VM §7 step 11** — finish the film~~ **SHIPPED 2026-09-06.** `tools/map-film/` → `map-film.mp4`, 1440×1080, 46.08 s, two soft subtitle tracks. The dead width measured **43.5%**, exactly as estimated. Two machine constraints found: `cropdetect` reports no crop (h264 ringing in the flat ground, so measure the PNGs), and this ffmpeg **cannot draw text** — the caption is CoreText | ✓ |

---

## §2 — The owner lane, with the blocker named

Not a backlog. Each of these is blocked on something only the owner can supply, and the plan is
more useful for saying which.

| Row | Blocked by |
|---|---|
| M-1 — store listing GATE A | The four EULA placeholders (address, telephone, support email, governing law) and the App Store Connect privacy nutrition label. *Note: the old plan's "still no `.xcprivacy` in the repo" is false since PR #1191* |
| The capture programme (§7 steps 5, 10–16) | House rule: the owner captures all screenshots and recordings; the plates are a UI export the owner presses. `Planning/Capture-Runbook.md` is the afternoon written down |
| M-3 / M-4 residue, B-5 residue | A composition verdict on a live device and a Mac window. Not a test assertion |
| A-1 (Meaning-mode prompts) | An on-screen check the row itself assigns to the owner |
| B-2 — W-14 read-aloud | Owner deferral, 2026-09-01, with an explicit revisit point: "after the App Store push" |
| B-4 sitting half | Owner appetite plus the outstanding build-44/45 tester verdict |
| B-7 — Differentiate Without Color on the map | A design decision: which second channel carries the encoding |
| R-1 / NVR §10 | The Office of the Historian has not published. The volumes do not exist anywhere |
| N-0 → N-1 → N-2 → N-3 (#234) | The M2a annotation sitting: a human reading 72 documents. Everything downstream is gated on it, and **N-3 is refused by name until N-1 returns a verdict** |
| P10 — place_mentions | Owner curation of the top-300 toponym heads. *Note: the old plan defers it to "the next index bump"; two have shipped since (47→48, 48→49) and it did not ride either* |
| #1081 screenshots, VoiceOver pass, archive-and-upload, launch territories, Gemma check | Owner-only by house rule or by App Store Connect |
| C-3 — OS-27 adoption | An input that does not exist here: no Xcode 27 beta SDK on this machine |
| NARA catalog refresh | Diagnosed and terminated: the S3 listing shows the shipped artifacts derive from a snapshot a refresh would not reproduce |

---

## §3 — What the survey cut, and why

Recorded so next week's survey does not re-propose them. Sixteen of thirty-six candidates:

- **Already shipped**: the M2a 72-document staging (2026-08-25); wave PV in full (PRs #1210–#1219);
  the `.xcprivacy` half of M-1; R-4's badge residue.
- **Decided against, and reversing is the owner's call**: `V §6.3` (three unbuilt map colour
  lenses), `W-17`'s Similar Wording re-argument.
- **Blocked on an owner verdict the design doc does not mention**: `V §7 item 3` (cluster-share
  analytics), `V §7 item 5` (subject-tag denoising), `Map §7.4` (word-cloud animation).
- **Blocked on an owner decision the document itself flags**: the VM batch route and the figure
  filename stamp — §6's lead sentence is *"No draft answered where the output goes"*.
- **Blocked on a CloudKit Production deploy**: `R-5 §8.2 Q-6` (the absent
  `CD_AnnotationReview.CD_annotationId` writer).
- **Refused by the plan itself**: `W-7a` both halves, which row N-3 forbids building ahead of N-1.
- **Terminated by its own diagnostic**: the NARA catalog refresh.
- **Owner action, not owner review**: the repository link check's three owner-asserted URLs; the
  Archive Visit "Seeded from…" caption; M1b's identity reconciliation.

---

## §4 — How `Plan-Of-Record-2026-08-28.md` had gone stale

Five findings, each verified against the tree rather than the document:

1. **§3c's wave PV row shipped whole** and should have been struck — build 45 landed 2026-09-04 and
   PV-0…PV-5 landed 2026-09-05.
2. **§4c's reason for deferring P10 no longer holds.** It defers to "the next index bump"; two have
   shipped since (47→48 in #1223, 48→49 in #1225) and P10 rode neither.
3. **§2a's M-1 says "still no `.xcprivacy` in the repo".** False since PR #1191.
4. **§3b's R-4 residue is closed** (PR #1191).
5. **No rows for the 2026-09-05/06 issue wave** (#1201–#1208); all eight are closed. The tracker now
   holds exactly two open issues, **#234** and **#1081**, both owner-gated.

Also carried forward, since no row tracked it: `Agentic-Guide-Revisions-2026-09-04.md` **Part 2 —
the research skill — is deferred by owner decision** "until there is more usage to test a skill
against".

## §5 — Sources

Built from all 26 documents in `Planning/`, cross-checked against `Planning/DEVELOPMENT-PLAN.md`
and `git log`. The screening pass that cut 16 of 36 candidates is what makes §2 and §3 worth
trusting; its method — generate the candidate list, then verify each claim against the tree before
trusting it — is the discipline `Planning/Agentic-Harness-Runbook.md` §8 applies to workflow
scripts, used here on a survey instead.
