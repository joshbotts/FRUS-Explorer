# Agentic Analysis Guide — steering one agent to the full-text and the vector strategies together: recommendations from the two C-3 tiers

**Status:** REVIEW, 2026-10-27. Recommendations only; nothing in the guide is changed by this
document.

**Applied in part, 2026-10-29 (guide v1.37).** The recommendations that leave the §12 block and the
deliverable as measured are in the guide: R1 (§14.16, §13), R2 with R3's naming and R4 (a new
§14.17), R5's §14.9 paragraph, R12 (§14.16, §15.1a) and R14 (Appendix A, §9). Four things here
were corrected on the way, from the records and a measurement at the 2026-10-15 generation:
- R5's rule: "the random-pair mean less nine sd" is 34 at this digest (167.1 less 9 × 14.8), not
  "about 20". The guide gives the measured lines instead: copies under about 25, copies and
  distinct documents of one exchange both from 25 to 39.
- R2: `v4`'s join flagged `frus1874/d552` as OTHER-DECADE; it had no scope column. The document
  lay outside its scope set, as the refuter found.
- R12: `v4`'s sentence claims two documents found by no word search where the strict reading
  holds one, so the guide's model sentence is its own.
- §2's R5 evidence: `v2`'s pair at 19 is `frus1969-76v12/d212` with `frus1969-76ve10/d225` (its
  `vec_dups.tsv`); the memo printed `d211`, which sits at 80.

Still waiting: R3's deliverable sentence, R5's clause on the block's Ed2 line, R6 to R11, R13 and
R15, which are R16's treatment arm.

**§9 answered, 2026-10-30.** The owner's answers:
1. the vectors section goes inside the block;
2. centroid similarity is dropped;
3. the third question is chosen from five candidates the owner proposes and a session assesses;
4. READER-FACING OUTPUT is adopted in substance and scope, and its style and language get a pass
   of their own over the runs' raw outputs;
5. the budget is as proposed, and the tier starts that day rather than after build 52.

R16 is designed with them in `C-3-Steering-Tier-Design.md`, which moved R9, R11 and R13 out of the
treatment arm and into that pass.

**R16 ran 2026-10-30** (`C-3-Steering-Tier-Results-2026-10-30.md`), on the owner's corruption
question. By its rule, the treatment is not adopted: reading 4 failed by one item, with B losing
O2 twice where A lost T1 once. Readings 1, 2, 5, 6 and 7 held. Reach tied at two strict documents
an arm. Two parts showed effects of their own:
- R6's vocabulary bullet: V8 4 of 4 against 0 of 4;
- R8: T1 4 of 4 against 3 of 4.

V6 needed no new text: v1.36's line, pasted into the block, gave A 4 of 4.

The owner followed the rule (2026-10-30). The guide records the measurement at v1.38 and adopts
nothing. R7, R8 and R10 are owed a measurement alone.

Written against `Docs/Agentic-Analysis-Guide.md` v1.36 (3,574 lines, `v2` @ `e85cef7`),
the two results files (`C-3-Results-2026-10-26.md`, twelve runs of the §12 block on the
recognition question; `C-3-Vectors-Tier-Results-2026-10-27.md`, four runs with Appendix A and the
artifacts on the owner's Cuba question) and their records (`c3-reader-test/`, `c3-vectors-tier/`:
the prompts as rendered, every memo, overview and collection, every scorer, refuter and judge
verdict with its evidence, and each session's `queries.log`). Every figure below is in those
records; the run labels are the keymaps' (`v2` = O-med+V (1), `v3` = S-high+V (1), `v4` =
O-med+V (2), `v1` = S-high+V (2)). The previous review of this kind is
`Agentic-Guide-Accessibility-Review-2026-10-14.md`, whose R8 became the READER-FACING OUTPUT
section C-3 measured; this one follows its form.

**The question.** The owner asked, on 2026-10-27, for revisions to the guide that *efficiently steer
an agent to use both the full-text and the vector strategies in accordance with the guide's
methodologies and produce the prescribed outputs*, to be measured in sessions after build 52
ships. So each recommendation below says what in the records it answers, the text it proposes, what
it costs in prompt length and in re-pinned tests, and how the next tier measures it. Nothing here
is adopted by being written; §7 is the measurement that decides.

---

## 0. Verdict

The §12 block and the harness's deliverable produce the prescribed outputs reliably: in sixteen
runs across the two tiers no agent fabricated, every quotation was found in its document (863 of
863), every headline number but one was reproduced, and every collection opened. What was lost is
procedural and clusters in a few places. The vectors tier adds four things the guide does not yet
act on.

1. **The instruction that made the agents use the vectors is not in the guide.** Four runs of
   four ran all five of §A.5's operations because the harness's deliverable named them, one
   sentence, as a memo section to fill. The guide's own vector text is Appendix A (what the
   artifacts are) and §A.8's addendum (what not to do); nothing in §12, §13 or §14.16 tells an
   agent to run a neighbour pass, when, on what, or what the memo owes for it. A user who hands an
   agent the guide alone gives it no "do".
2. **The agents and the measurement disagree about what the vectors found.** The sessions claimed
   five vector-reached documents; the refuter's rule (no logged full-text or heading query returns
   it) counts two, and all three discounted claims were documents inside the session's own
   chapter-heading scope. Both are honest readings of an undefined term. The guide must define it,
   in both readings, so the memo's claim and the check agree.
3. **One of the five operations produced nothing and cost one item in every run.** Centroid
   similarity was "orientation only" (`v3`), "does not carry the Cuba question across time"
   (`v1`), "only the ordering is used" (`v4`) in the four memos, and its cosines are the figures
   all four runs reported without the calibration offsets or the word *raw* (V6, 0 of 4). The
   reach came from nearest neighbours joined into the database; the counting correction came from
   near-duplicates; the map gave one overview figure and one lost item.
4. **Two of the four lost items trace to figures the guide's own text handed the agent in the
   form the block forbids.** `v4` copied Appendix A's "28.0%" into its memo and lost P5 (no N of M
   at the point of use); `v2` restated the §12 block's own "11 of 695 bundled series" as a finding
   and lost P6 (no script, no output, and the figure is now 698). The appendix's examples model the
   bare percentage the block prohibits, and the block carries a figure an agent cannot re-derive.

Sixteen recommendations follow, in five groups: what the guide tells the agent to *do* with the
vectors (§2, R1–R5), the §12 block (§3, R6–R10), the reader-facing form (§4, R11–R13), the guide's
own figures (§5, R14–R15), and the measurement that decides them (§7, R16).

---

## 1. What the two tiers measured, read together

### 1.1 The figures that matter here

| | C-3, full-text only (12 runs, 9 cells) | C-3 vectors tier (4 runs, 2 cells) |
|---|---|---|
| fabrications; quotations verified | 0; 653 of 653 | 0; 210 of 210 |
| headline numbers reproduced | 60 of 60 | 19 of 20 (`v4`) |
| compliance on the 35 items | 396 of 408 obeyed (0.971); the two recommended cells perfect in 4 of 4 | 0.941, 0.971, 0.971, 1.000; one item lost in three runs, two in one |
| items lost, by id | O2 ×4, R3 ×2, O1, I2, I3, P6, S3, P2 | V6 ×4, P5 ×2, T1, P6, V5 |
| reader judge, 5 items | 5 of 5 in 10 of 12 (J4 missed in both `medium` cells) | 5 of 5 in 4 of 4 |
| the three-part bottom line (O3) | 12 of 12 | 4 of 4 |
| trace table present (O2) | 8 of 12 (the table was required in every run; the misses are untraced numbers) | 4 of 4 |
| vector operations run | none | all five, in 4 of 4; digests compared and both baselines computed in 4 of 4 |
| vector-reached documents, refuter's rule (agent's claim) | — | 0 (1), 1 (2), 1 (2), 0 (0) |
| wall clock, O-med / S-high | 18.2, 19.4 / 30.5, 32.4 min | 23.3, 14.2 / 21.2, 25.2 min |
| collection size, O-med / S-high | 19, 26 / 56, 56 documents | 16, 16 / 23, 22 |

### 1.2 Where the vector work fell in each session, and what it reached

Each `queries.log` is one command a line. The first vector command came after the full-text
scoping and after the first `body_text` reads in every run; the anchors were documents the
full-text or heading pass had already found.

| run | cell | log lines | first vector command | anchors | vector-reached (strict) | the session also claimed |
|---|---|---|---|---|---|---|
| `v2` | O-med+V (1) | 192 | line 117 | 4 | 0 | `frus1969-76ve10/d205` — inside its heading scope (the Cuba chapter of ve10) |
| `v3` | S-high+V (1) | 86 | line 23 | 6 | 1: `frus1958-60v05/d112`, Dulles, March 1959, Hamming 106 to the Mallory memo; its text never says *Cuba* | `frus1961-63v10-12mSupp/d729` — inside its heading scope |
| `v4` | O-med+V (2) | 68 | lines 44–47 (one pass) | 3 | 1: `frus1874/d552`, Fish to Cushing, Hamming 61 to Woodford's `frus1898/d490`; outside the scope set and every ranked list | `frus1969-76ve11p1/d278` — inside its heading scope |
| `v1` | S-high+V (2) | 62 | line 33 | 8 | 0 (its scope was the whole mention set, 12,256 documents matching `cuba OR cuban`, so every neighbour that names Cuba is "full-text-reached" by the rule) | none |

Three things in this table shape the recommendations. The two strict hits are the two cases §A.5
promises: vocabulary drift (a document on the subject that never uses the subject's word) and a
cross-era neighbour the ranked lists did not reach. Both came from the **nearest-neighbour list of
an era's key document, joined to the database and flagged** (`v3`'s `cuba_in_text = 0`, `v4`'s
`NOT-IN-SCOPE` and `OTHER-DECADE` columns); neither came from the map or the centroids. And the
strict count depends on how wide the full-text scope was drawn: a bare mention set swallows every
neighbour that names the subject, which is why `v1`, the run that did the most vector work (eight
anchors), counts zero.

### 1.3 What each operation yielded

| operation (§A.5) | ran in | what it gave the historian | what it cost |
|---|---|---|---|
| nearest neighbours of a document, joined into the database | 4 of 4 | both strict reaches; the cross-era chains the overviews narrate (1874 → 1898, 1951 → 1969 → 1974) | nothing lost |
| near-duplicates | 4 of 4 | the Blaine instruction's reprint (`frus1881/d405` = `frus1894app2/d394`, Hamming 4) found in three runs; `v2` found two more pairs under 20; one copy cited, counts not doubled | nothing lost |
| the map | 4 of 4 | `v3`'s "about five in six of the Cuba chapter documents from 1950 on sit in one cluster" with an era-matched baseline; `v2`'s reading that Cuba sits in a different cluster in each era | V5 (`v4`: corpus share alone), and the P5 copy of "28.0%" |
| centroid similarity | 4 of 4 | none: adjacent annuals are nearest in every run, as §A.5 says they should be | V6 in 4 of 4: the cosines the reader sees, with no offset and no *raw* |
| Tier-2 rerank (§A.6) | 0 of 4 (one opened a shard header) | — | — |

---

## 2. What the guide tells the agent to do with the vectors

### R1 — The memo owes a VECTORS section, and the guide says so (S)

**Evidence.** The deliverable sentence of the vectors tier (`c3-vectors-tier/prompts/runner.txt`,
item 1) is the only text in the run that told the agent to use the artifacts: "a section headed
VECTORS that names each of Appendix A's operations you ran (…), each with its anchor, the file it
ran over, the baseline it was read against and what it found, or the single word 'none' if you ran
none, and says which documents in the overview you reached through a vector operation and through
no full-text query." Four of four filled it; the four VECTORS sections are the clearest part of
each memo, and the refuter's vector-use step read them directly. The guide's §14.16 (the four
artifacts), §13 (the run record) and §12 carry no such sentence; §A.8's addendum is rules.

**Proposal.** §14.16's memo paragraph gains the sentence as a conditional obligation: *When the
brief hands the agent the vector artifacts, the memo carries a section headed VECTORS, which names
each of §A.5's operations run, each with its anchor, the file it ran over, the baseline it was read
against and what it found, or the single word "none"; which cited documents were vector-reached in
each of §14.17's two readings; and the provenance digest, with the index's `generated` stamp.* §13's
record table gains a row: *the provenance digest and `generated` stamp of the artifacts, if used*
(the Research-State Record already carries it). The harness runbook's generator keeps emitting the
sentence; the guide now says why it is there.

**Cost.** Six lines. No pin.

### R2 — A §14.17: where the vectors enter the scoping pass, and what they owe (M)

**Evidence.** §14 is the methodology, and it mentions the vectors twice: §14.10's label test on
`semantic-map-index.json` and §14.15's "the artifacts not yet opened, by name". Neither says when a
neighbour pass is run or against what. The four sessions each invented a place for it (§1.2) and
all four chose the same shape without being told: anchors from the eras' key documents, neighbours
joined to `document_dates` and the scope set, read before cited. The two that reached a new
document did so with a flagged join (`v3`, `v4`); the two that did not had no flag for "outside
the scope" (`v1`, `v2`).

**Proposal.** A new §14.17, *The second finding aid: when the vectors enter the pass*, after
§14.16, of about forty lines, stating the method the runs converged on as a rule:

1. **The vectors come in after the heading scope and the first anchors, before the scope closes.**
   The full-text pass (§14.1–§14.9) chooses the volumes and the eras' key documents; those are the
   anchors. A neighbour pass run before there is an anchor has nothing to anchor on, and one run
   after the collection is written can add nothing to it.
2. **One anchor per era or per finding**, the nearest ten to twenty-five by Hamming over the corpus
   binary, each neighbour joined on both keys and **flagged three ways**: in the scope set or
   outside it; the anchor's decade or another; the question's literal present in its text or
   absent. A neighbour flagged *outside* or *absent* is the candidate the vectors exist to find
   (§A.5: vocabulary drift, the enclosure in another language). Read it whole; if it bears on the
   question, add it to the scope and the collection, and record it as vector-reached (R4).
3. **Judge each neighbour against the k-th-neighbour baseline and the set against random pairs**,
   both computed at this digest before the first list is read (§A.5). A neighbour at the median
   25th-neighbour distance is a lead that only reading justifies, as `v3` said of its Dulles
   memorandum at 106.
4. **Near-duplicates before any count over a set you built** (R5).
5. **The map is §14.10's label test**, run when the question is whether a subject forms a region
   of the corpus at all, and any cluster figure carries the set's unclustered share against an
   era-matched baseline on the layout in use, or there is no cluster figure.
6. **Centroid similarity is optional** and has yet to change an answer (§1.3); when it is run, its
   cosines are labelled as R6 says.
7. **What the memo and the overview carry** for all of this: R1's section; R12's sentence.

The section opens with the sentence that frames Appendix A: the vectors are a second finding aid,
anchored on documents the first finding aid found, and a neighbour is a reading suggestion until
the document has been read.

**Cost.** About forty lines of guide text, outside the block; no pin. §14's "Contents" entry is
unchanged.

### R3 — Required and optional operations, named (S)

**Evidence.** §1.3. The deliverable's list treats the five operations as equals, and four of four
ran all five. Centroid similarity gave nothing and lost an item in every run; the map lost two.

**Proposal.** The guide (R2, and R6's block text) names two operations as required when the
artifacts are handed over, nearest neighbours with the flagged join and near-duplicates; one as
conditional, the map, under §14.10's condition; and one as optional, centroid similarity. The memo's
VECTORS section still names all five, each run or "not run, and why" (so a run that skipped one is
distinguishable from one that could not). The design's control arm (§7) keeps the five-equal
sentence, so the change is measured and not assumed.

**Cost.** Two lines. It changes the treatment, so it is one of the arms in R16.

### R4 — "Vector-reached" is defined, in two readings (S)

**Evidence.** §1.2's last column. The refuter's rule, written in the design before any run, is
*returned by no logged full-text or heading query*. Three sessions claimed a document that no
ranked list they read had returned but that sat inside their own chapter-heading scope, and each
claim was discounted. The refuters themselves noted the gap: "under a ranked-retrieval reading it
would therefore count" (`v2`). The strict rule also depends on scope width (`v1`).

**Proposal.** §14.17 defines the term in two readings, and the memo reports each cited document's
status under both:

- **Strict:** no full-text or heading query you logged returns it. Before claiming it, re-run your
  logged queries against the pair and show the result, as the refuter will.
- **Practical:** it was in no result set you had read when the neighbour list surfaced it.

A document inside your own heading scope is practical-reached at most. The overview's sentence
(R12) uses the strict reading only; the practical count is the memo's. The rubric gains an item,
V7, *the memo's vector-reached claims match the strict reading when re-run*, so the agent's claim
and the refuter's count are measured against one definition.

**Cost.** Eight lines. The rubric item is R16's.

### R5 — Near-duplicates before counting, as a recipe from the baseline (S)

**Evidence.** Three of four runs found the same reprint at Hamming 4 and one found two more pairs
under 20; `v2` set its threshold as "more than nine standard deviations below the random mean" and
said which copy it cited. §A.5's paragraph says "very small Hamming distances flag reprints" and
gives no rule; §14.9 (where the corpus double-counts itself) lists the Ed2 twins and the microfiche
supplements and does not mention the vectors, which find reprints the ids do not.

**Proposal.** §14.9 gains a paragraph: *the vectors find the reprints the ids do not. Before any
count over a set you built, take each member's nearest-neighbour distance in the set; a pair closer
than the random-pair mean less nine standard deviations at this digest (under about 20 of 512 at
the 2026-10-15 generation) is a reprint until read; cite one copy and say which.* The block's
SCOPING Ed2 line gains a clause pointing to it when the vectors are in hand.

**Cost.** Five lines.

---

## 3. The §12 block

The block is the measured instrument (C-0d at 99.2%, C-3 at 0.971 over twelve runs). Every change
below makes a new instrument, which is why R16 exists; none is adopted by being written. Where a
change can be made satisfiable by structure rather than by a guarantee, it is (§14.15a).

### R6 — A conditional SEMANTIC VECTORS section inside the block, replacing "paste the addendum" (M)

**Evidence.** §3a (v1.36) tells a user to "paste §A.8's addendum into the §12 block". The addendum
is fourteen lines of prohibitions, two of them carrying the previous generation's numbers
(random-pair mean 193 / sd 17; recall@10 0.851, where the index in use says 0.902), and none of
them tells the agent what to run. V6, the one rule all four runs missed, asks for a calibration
offset on a quantity the app never shows calibrated (a volume-centroid cosine); the rule can be met
by one heading.

**Proposal.** The addendum leaves §A.8 and becomes a conditional section of the block, between
ARCHIVAL SCOPE and the end, in the block's register:

```text
SEMANTIC VECTORS — only when your brief hands you the artifacts of Appendix A. If it does not, run
none of this and write "VECTORS: none" in the memo.
- Before any scoring, print the provenance digest from every artifact you touch and say they agree;
  on a mismatch stop. Identity comes ONLY from semantic-vectors-index.json's id segments: show the
  round trip (decoded length = n for every volume). Never an ordinal, a rowid or a shard's position.
- Compute both baselines at this digest before reading any distance: random pairs (mean, sd, 1st
  percentile) and the k-th-neighbour distribution over a random sample. Read one neighbour against
  the second and a set's cohesion against the first. The figures in the guide are one generation's.
- REQUIRED: for one anchor per era or finding, the nearest 10 to 25 by Hamming over the corpus
  binary, each joined on BOTH keys to document_dates and document_cache and flagged three ways: in
  your scope set or outside it; the anchor's decade or another; the question's literal present in
  its text or absent. A neighbour flagged outside or absent is the candidate the vectors exist to
  find: read it whole before the scope closes, and if it bears on the question add it to the scope
  and the collection.
- REQUIRED: before any count over a set you built, each member's nearest-neighbour distance; a pair
  closer than the random mean less nine sd is a reprint until read. Cite one copy and say which.
- The map only to test whether the subject forms a region (one label test), and any cluster figure
  with the set's unclustered share, N of M, against an era-matched baseline on this layout, or no
  cluster figure. Centroid similarity is optional.
- Head the VECTORS section "All cosines below are raw." If you compare a cosine with the app's
  percentage, apply the index's retrieval.scoreCalibration offsets to it and say so.
- A neighbour is a reading lead, never evidence: no claim in the overview rests on a distance.
  Tier 1 covers all 553 volumes even when this database does not: flag a neighbour whose volume is
  absent from document_cache and cite it by its history.state.gov URL. Absence of a neighbour
  proves nothing: the index's retrieval block states the funnel's measured recall.
- Say which cited documents were vector-reached, in both readings: STRICT, returned by no query you
  logged (re-run them against the pair and show it); PRACTICAL, in no result set you had read when
  the neighbour list surfaced it. A document inside your own heading scope is practical at most.
- None of this vocabulary reaches the overview or the collection: no Hamming, cosine, cluster
  number, "vector" or "neighbour at N". Say "found by its similarity to [the document], by no word
  search, and read before it was cited".
```

Thirty-one lines, against the addendum's fourteen; it carries no generation-specific figure, so a
regeneration does not stale it. §A.8 keeps a one-line pointer to the block. §3a's sentence changes
from "paste §A.8's addendum" to "the block's SEMANTIC VECTORS section applies".

**Cost.** The block grows from 208 to about 239 lines; C-0c found a 27% growth cost no attention,
and this is 15%. New instrument: R16 measures it. V6 should read 4 of 4 by structure.

### R7 — The block carries no figure the agent can restate as a finding (S)

**Evidence.** `v2` lost P6 on "The offline stack barely reaches before 1940 (11 of 695 bundled
series)", the block's own ARCHIVAL SCOPE sentence, put in the memo as a result: the scorer found no
script and no output behind it, and the bundle now holds 698 series. The guide's version history
(v1.33 entry) already notes the figure moved and that the block was "deliberately untouched" as
the measured instrument.

**Proposal.** The line reads: *The offline stack barely reaches before 1940 (the guide counted
about one bundled series in sixty with a start before 1940; re-derive the figure from
`series-facts-index.json` before you print one). Say so rather than reporting an empty pre-war
roadmap as an archival absence.* One more rule, under REPORTING: *A figure you take from these
rules or from the guide is the guide's measurement at its date, not yours: re-derive it or
attribute it; never present it as a result of this session.*

**Cost.** Two lines changed, one added.

### R8 — KNOWN TRAPS gains the prefix-on-stem line (S)

**Evidence.** `v2` lost T1: `normaliz*` returned 0 in a volume where `normalization` returns 2,
because the stem is `normal` and a prefix longer than the stem reaches nothing; the empty result
went unrecognised. §7.1 states the trap (the guide's line 1003); the block does not.

**Proposal.** After the stemming bullet: *A `term*` prefix is matched against STEMS: `normaliz*`
cannot reach `normalization` (stem `normal`) and `communis*` misses `communism` (stem `commun`).
Before a prefix, look the stem up in the `terms` table, and write the prefix no longer than it.*

**Cost.** Three lines.

### R9 — READER-FACING OUTPUT: the URL carries the pair, and every number has a line (S)

**Evidence.** O1 was violated once in twelve (`r8`, F-med) for 28 history.state.gov URLs whose
paths are id pairs, in an overview the block told to carry those URLs: the rule and the citation
form contradict each other and the scorer resolved it against the agent. O2 was the most-missed
reader rule (4 of 12), and every miss was a number in the overview with no memo line, not a missing
table: "the ambassadors of twelve American republics" (`r10`), "two claims conventions" (`r10`),
"three that proved to be footnotes were dropped" where the memo lists six (`r7`), "the six largest
chapters" where the memo says thirteen (`r9`), "doubles the Central American material" (`r6`).
Counts read out of a document's text, and counts of the method, were not treated as numbers.

**Proposal.** Two edits to the section. The first bullet's "no volume_id/document_id string"
becomes *no volume_id/document_id string except inside a history.state.gov URL after an edition
citation*. The number bullet gains: *A count you read in a document ("twelve republics"), a count
of your own method ("three passages set aside") and a comparison ("doubles") are numbers: each has
a memo line. Before you finish, list every numeral and number-word in the overview, show each in
the trace table, and add the row for any that is missing; say you did.* The second is §14.15a's
form, the exception rather than the guarantee.

**Cost.** Four lines. O1 and O2 are measured items already.

### R10 — A zero is reported beside the query that returned rows (S)

**Evidence.** R3 was lost twice (`r3`, `r8`): an empty query reported, with no query shown that
could return rows on the same surface. The rule says "verify the query can return rows at all",
which is a guarantee; §9 item 6 says what the verification is.

**Proposal.** The REPORTING bullet reads: *If a query returns no rows, say so, and print beside it
the relaxed form of the same query, on the same surface, that did return rows (drop one term, or
widen the date), with its count. A zero with no returning neighbour beside it is an assertion.*

**Cost.** Two lines.

---

## 4. The reader-facing form

### R11 — The collection's prose and notes are reader-facing too, and the vector vocabulary is named (S)

**Evidence.** The block's READER-FACING OUTPUT section binds the overview; the collection's `prose`
and `notes` entries are bound by §15.1a's register in the guide and by nothing in the block. The
judge found "method residue in the collection's notes (Hamming distances, 'vector index', 'about
100,000 characters')" in `v3`, the run it otherwise ranked first on evidence, and "tool talk" in
`v2`'s overview ("the app's document-similarity vectors", "the offline tools cannot resolve"). O1
cannot score these: it reads the overview.

**Proposal.** The section's first bullet names both artifacts: *Write the overview, and every
`prose` and `notes` entry of the collection, in plain prose.* The forbidden list gains the vector
vocabulary (R6's last bullet). The rubric's O1 is scored over the collection's prose and notes as
well, or a sibling item O4 is added for them (R16).

**Cost.** One line in the block; the rubric change is R16's.

### R12 — One model sentence for the vector work in the overview, and one for a document it found (S)

**Evidence.** `v4` wrote the sentence the judge called cleanest: "I also used the app's
document-similarity vectors to find neighbours of key documents; two of the cited documents, the
1874 Fish instruction and the 1974 Rush memorandum, were found that way and by no word search. A
neighbour of this kind is a reading lead, not evidence, and both were read before being cited."
`v3` wrote "the numerical fingerprints that summarise each document's meaning", which explains the
term in the sentence as the block asks, and the judge called the overview the densest. §14.16's
"how this was done" paragraph does not mention the vectors.

**Proposal.** §14.16's *how this was done* paragraph adds: *and, if the vector artifacts were used,
one sentence in the historian's words: which documents were found by similarity and by no word
search (the strict reading), that a similarity is a reading lead and not evidence, and that each
was read before it was cited.* The collection's note on such a document opens, after the
attribution line: *Found by its similarity to [edition citation], by no word search; read in full.*
The two sentences go into §14.16 and §15.1a as the worked form, beside the audit and reader's
forms already there.

**Cost.** Six lines.

### R13 — The bottom line's citations are complete, and the overview stands without the memo (S)

**Evidence.** Not vector-specific, but the judge's two consistent complaints across both tiers:
`v2`'s bottom line cites "1902, Document 313; 1903, Document 331" with no series name and no link,
and sends the historian to "the memo" three times, a file "she does not receive"; `v3` cites six
documents by correspondent and date in place of the document number. The block's citation rule is
one form; the deliverable skeleton says "cited as the edition"; neither says *in the bottom line
too*, and the block's "say 'see the memo' once" licenses the pointer.

**Proposal.** The citation bullet gains *including in the three paragraphs of the bottom line,
where a short form is not a citation*. The number bullet's "say 'see the memo' once" becomes *the
overview is read by someone who does not have the memo: write it so that nothing in it depends on
opening the memo, and name the memo once, in "how this was done", as where the exact figures are.*

**Cost.** Three lines. The judge's J-items already score the result.

---

## 5. The guide's own figures

### R14 — Appendix A models the form the block demands, and carries no stale generation's figure (S)

**Evidence.** `v4`'s P5 loss quotes the appendix: "(28.0% of all placements are; …)". §A.5 gives
the figure once as "88,059 of 314,616 placements (28.0%)" and §A.8 twice as "28%" and "the 28.0%".
§A.6 states recall@10 as 0.851 and §A.8's bullet is headed "Recall 0.851 means misses", where §A.7
gives 0.902 for the shipped generation and the four memos reported 0.902 from the index. The
addendum's "random-pair mean 193 / sd 17" is the 300m generation's (§A.5 now says 167 and 15). §9
item 3 says "the map's unclustered share is 47% before 1900 and 22% in 1945–64", the 2026-08-16
layout's figures, which §A.5 (v1.35) has replaced with 24.8% against 26.9%. v1.35 re-took §A.5's
figures and left these.

**Proposal.** Every share in Appendix A is printed N of M first and the percentage, if at all,
after it, so an agent that copies the appendix copies the block's form. §A.6 and §A.8 read the
recall from the index's `retrieval.measuredRecallAt10` ("0.902 at the 2026-10-15 generation; read
the index's figure, which changes with the generation"). §9 item 3's example moves to the shipped
layout's figures with the layout's date, or says "the share the layout in use gives by era" and
cites §A.5. The appendix's own rule (§A.8: re-record after any regeneration) gets a sentence at the
head of §A.5: *every figure in this appendix is one generation's reading; the agent recomputes
them, and this appendix is re-taken after each regeneration, as it was on 2026-10-26.*

**Cost.** About ten lines changed. No pin.

### R15 — The vectors operating card: a third of the appendix, with the appendix as a file (M, to be measured)

**Evidence.** The prompt the agents received was 714 lines, 332 of them Appendix A. Of the
appendix, the sessions used §A.2 (the family rule), §A.3 (the decode, copied as written and run
553 of 553 in every run), §A.4 (the header offsets), §A.5 (the loop and the baseline recipe) and
§A.8's addendum. §A.6 was not used for scoring by any run; §A.7 is about an embedder no run had;
§A.1's prose and §A.5's worked examples were read once and not needed again. The design's
limitation 3 says the compliance loss cannot be attributed to the vector work rather than to the
328 extra lines; the pre-registered threshold kept the appendix in the prompt.

**Proposal.** A *vectors operating card* of about 110 lines, kept in the guide as §A.9 and emitted
by the generator in place of the whole appendix: §A.2's rule in two lines; §A.3's decode as code;
§A.4's layout table; §A.5's loop and the baseline recipe (random pairs with the seed; the k-th
neighbour over a random sample), with the Python 3.9 note; the three-flag join as code (R2 item 2);
the near-duplicate recipe (R5); and R6's block section. The resources item names the full appendix
as a file to consult (`Docs/Agentic-Analysis-Guide.md`, Appendix A), as the guide already does for
§4 and §7. The card is an arm in R16, not a replacement: if it loses an item the whole appendix
did not, the whole appendix stays.

**Cost.** About 110 lines of guide text, and about 220 fewer lines of prompt. Measured, not adopted.

---

## 6. What not to change

- **§A.3's decode and §A.5's loop.** Copied as written into four sessions, run 553 of 553 and
  reproduced the canary's list in 44 seconds at the Opus pin. The Python 3.9 note (v1.35) was
  in every run's tooling notes and is right.
- **The three-part bottom line, the trace table requirement and the collection contract.** 16 of
  16 on O3; 4 of 4 trace tables in the vectors tier; 16 of 16 collections opened. The reader judge's
  five items were 5 of 5 in 14 of 16 runs, and the two misses were `medium` cells on the first
  question.
- **The deliverable's five-operation sentence**, as the control arm's text (R3 changes it in the
  treatment arm only).
- **§3a's recommendations.** Opus 5.5 at `medium` and Sonnet 5.5 at `high` held with the appendix
  in hand: the same two cells, no fabrication, 5 of 5 reader items, time and usage unchanged. One
  O-med+V run fell below the floor by one item; the design's threshold for pulling the appendix was
  not met.
- **The refuter's strict rule for vector reach**, which stays the measurement; R4 adds the
  practical reading beside it rather than replacing it.
- **Appendix A's place.** The appendix stays the reference; R15 proposes a shorter payload for the
  prompt, not a shorter appendix.

---

## 7. The measurement (R16)

**R16 — A third tier, two arms, the same two cells, after build 52.** The design is C-3's and the
vectors tier's (one generated prompt per arm, instruments blind to the cell, readings written
first), with these settings:

- **Question.** The results file's §6 asks for a question in which the vectors should matter more
  than on Cuba: a subject whose documents are filed under other countries' headings, so that the
  heading scope cannot swallow the neighbours (§1.2, `v1`). One question, not yet printed in any
  planning document, chosen by the owner; its text pasted from a file by the generator as before.
- **Arms.** A, the control: the v1.36 prompt as run on 2026-10-26/27 (Appendix A whole, the
  addendum, the five-equal deliverable sentence). B, the treatment: R15's card in place of the
  appendix, R6's block section in place of the addendum, R3's required/optional naming, R7–R13's
  block edits, and R1's memo obligation stated in the deliverable as the guide would state it. One
  treatment, because eight runs cannot attribute among eight edits; the arms differ by the whole
  revision, which is what a user who follows the revised guide pays.
- **Cells.** O-med and S-high, two runs each per arm: eight runs, in alternating order (A, B, A,
  B by cell). At the vectors tier's cost, about 2 points of the weekly meter a run with instruments,
  16 to 20 points in all, under a line the owner sets.
- **Items.** The 41 (C-3's 35 and V1–V6), plus **V7** (every vector-reached claim in the memo
  holds under the strict reading when the refuter re-runs the logged queries), **O4** (the
  collection's `prose` and `notes` entries carry no SQL, id pair, path or vector vocabulary), and
  **O2'** (the overview's numerals and number-words each have a trace row; scored by the numerals
  check the agent is asked to show). The refuter's reach step reports both readings.
- **Readings, written first.** (1) *Use*: B runs the two required operations in 4 of 4, and runs
  no operation it was told was optional without saying why. (2) *V6*: 4 of 4 obeyed in B by the
  heading; A's result is the vectors tier's 0 of 4 unless the addendum's new line (v1.36) changed
  it, which A measures. (3) *Reach*: B's strict count is at or above A's on the same question,
  and B's claimed count equals its strict count (V7 4 of 4). (4) *The cost*: B loses no more items
  on the 35 than A; a B run that loses two is read against A's on the same cell. (5) *The reader*:
  O4 4 of 4 in B; the judge ranks B's overviews at or above A's in at least two of the four
  cell-matched pairs. (6) *The price*: B's wall clock within A's; the prompt about 220 lines
  shorter. Adoption rule: B goes into the guide as its text if (1), (2) and (4) hold; (3) and (5)
  decide the wording of §3a's paragraph; a B that fails (4) keeps the whole appendix and the
  addendum, and the block edits of R7–R13 are measured again alone.
- **Record.** `Planning/c3-steering-tier/` in the two tiers' layout; a results file; §3a and the
  version history afterwards, with the §15.1 block unchanged (`CollectionTests.publishedExampleMatchesTheGuide`
  pins it) and the block's new length noted where §12's "Which surface answers which block" records
  the measured lengths.

---

## 8. Order and cost

| group | lines added or changed in the guide | changes the measured instrument | pins |
|---|---|---|---|
| R1, R2, R4, R5, R12 (§13, §14.9, §14.16, §14.17, §15.1a) | about 65 | no | none |
| R6–R11, R13 (the §12 block) | block 208 → about 239 | **yes**: new instrument, measured by R16 | the §15.1 block is untouched |
| R14 (Appendix A, §9) | about 10 | no | none |
| R15 (§A.9, the card) | about 110 | the prompt payload, not the block; an arm of R16 | none |
| R3 | 2 | the deliverable sentence, an arm of R16 | none |

Every change is a version-history entry under the guide's convention, each ending "The §15.1 block
is unchanged." The owner's rule of 2026-10-14 (decision 9) applies: a test that pins language is a
reminder, and none of the tests that read the guide pins any text these recommendations touch.

---

## 9. Open to the owner

1. **Whether R6's section lives inside the block or stays a separate appendage** the user pastes
   when the artifacts are in hand. Inside is one text and one instrument; separate keeps the
   measured block at 208 lines for a full-text-only run. The recommendation is inside, with the
   section's first line making it conditional, because the four sessions read one prompt and the
   runs are the evidence that the condition is read.
2. **Whether centroid similarity stays in the list at all.** R3 keeps it as optional so the memo
   still records a choice; dropping it saves a line and removes the operation that produced every
   V6 loss.
3. **The third question.** R16 needs one no planning document prints, on a subject filed under
   other headings. The owner chooses it; this document deliberately proposes none.
4. **Whether the READER-FACING OUTPUT section is called adopted** (the FTS results' open decision),
   which R9, R11 and R13 presuppose by editing it.
5. **Budget and date.** After build 52 ships, at about 16 to 20 points of the weekly meter, under
   a line the owner sets as before.
