# EmbeddingGemma 2, stage 2: the full store, the corpus gates, the judged queries and the ladder

**Date:** 2026-10-15 · **Status:** STAGE 2 DONE (plan of record Track B, step B2). B3, which model
ships, is the owner's reading; §10 sets it out and decides nothing. · **Issue:** #1659 · **Design:**
`EmbeddingGemma-2-Spike-2026-10-14.md` §2, steps 5 to 7 · **Stage 1:** `EmbeddingGemma-2-Stage-1-2026-10-14.md`
· **Machine:** the M5 MacBook Air (`Mac17,4`, Apple M5, 10 cores, 32 GB) · **Index:** the Mac app's
`frus.db`, v69, written 2026-10-12, read in place and read-only · **Artifacts and the scripts that made
them:** `eg2-b2-2026-10-15/`; the judging sheet is `eval-eg2-2026-10-15/`; the paired corpus gate is
`tools/semantic-harvest/corpus-gates/compare_corpus.py`.

Every figure was measured on 2026-10-15 on the Air, except the harvest itself (the night of
2026-10-14) and where a line names the record of another day. Nothing shipped changed: no file under
`FRUSExplorer/Resources/` or `Planning/semantic-vectors/shards/`, and nothing was re-embedded for
the 300m. Engineering-side, not legal advice.

## 0. In short

- **The store is sound.** 553 volumes, 314,616 documents, 605,978 chunks; all 2,212 checksums
  verify; the contract matches (model `embeddinggemma-2-Q8_0`, SHA-256 `2188ac1d…`, the prompt with
  its trailing space, 3,200 and 480). It took **12.64 hours** of embedding in one invocation, not
  the 8.6 to 9.1 stage 1 estimated, because the Air slowed steadily through the night (§9).
- **50 documents' text differs from the shipped store's, in five volumes, by corpus edits made after
  the shipped store embedded them** (§2). It changes no figure here: the 40 Gate A queries that
  touch those documents move nothing in the fourth decimal.
- **Gate A at corpus scale (83,119 queries) puts the 300m ahead, outside the noise.** At the shipping
  shape, MRR@10 0.2574 against 0.2503: −0.0071, 95% interval [−0.0085, −0.0057] over queries and
  [−0.0086, −0.0056] over citing volumes, about 2.8% relative. Hit@10 falls from 46.5% to 45.7%.
  EmbeddingGemma 2 wins 32,769 queries and loses 33,809.
- **By era, the 300m leads outside the noise in four of seven eras** (1900–1918, 1939–1945,
  1946–1960, 1961–1976); **the interwar era is level** (−0.0020 [−0.0050, +0.0012]), as are
  1977 onward and pre-1900. Stage 1's interwar signal was its volume's: `frus1938v01` loses again
  at corpus scale (−0.0319 [−0.0589, −0.0073]), and the era as a whole does not.
- **The whole difference is in same-volume citations** (−0.0092, outside the noise). Cross-volume
  citations are level (−0.0011 [−0.0032, +0.0009]), and so are mixed ones.
- **The 25 judged queries cannot rank the two models without a sitting.** EmbeddingGemma 2 shares
  3.6 of its ten documents a query with the 300m's, so 183 of its 250 rows were never judged. The
  sheet is ready, with the August judgments carried over (§6).
- **The rerank pool needs no change**, and the Hamming stage the app actually runs, over 512 sign
  bits, costs either model almost nothing at a pool of 800 (§5).
- **The ladder:** the same sizes and the same kernel time for both models at each width.
  EmbeddingGemma 2 keeps more of its own neighbourhood at 256, but its Gate A at 256 (0.2400) is
  below the 300m's at 512 (0.2574), so a narrower bundle is still a trade (§7).
- **Step 7, the query encoder on an iPhone and the Mac, was not run** and is left for B4 (§8).
- **EmbeddingGemma 2's cosines run about 20 points higher** on typed queries, and the app shows a
  Meaning match as the raw cosine (§11).

## 1. The store (design step 5)

The harvest ran in one invocation through `llama-server` at llama.cpp `a0e6dc73` on port 8089
(`-ngl 99 -c 16384 -np 4 -b 4096 -ub 4096`, alias `embeddinggemma-2-Q8_0`), started 2026-10-14 at
18:16:49 and finished 2026-10-15 at 06:55:14. Its log, the copies of the harvester and manifest it
read and its status script are in `~/frus-b2/`. The server was stopped after the checks below.

| check | result |
|---|---|
| `shasum -a 256 -c SHA256SUMS` | 2,212 of 2,212 OK; the sums cover every data file (2,215 on disk with the manifest, `runs.jsonl` and the sums) |
| `run-manifest.json` | model `embeddinggemma-2-Q8_0`, `model_file_sha256` `2188ac1d…40b09135`, dim 768, chunks 3,200 and 480, prefix `title: none \| text: ` with the trailing space, batch 64, 553 requested, none missing |
| totals | 314,616 documents, 605,978 chunks, 1,333,780,004 document characters, 45,503.7 s of embedding, all equal to the sum of the 553 volume heads, each of which names the model |
| harvester | `script_sha256` `41a6656d…`, the repository's `harvest_embeddings.py`, unchanged since 2026-09-02 (#1177); the shipped store's last run used the same script |
| pooling (`pool_docs.py`) | no NaN or infinity, no zero vector, chunk norms within 7.3×10⁻⁸ of 1, every chunk tiling clean, no key collision, text and meta in the same order in every volume |

The two stores hold the same 314,616 documents and the same 605,978 chunks, volume for volume.
Exact duplicate int8-256 rows: 496 groups (992 rows) under EmbeddingGemma 2 against the 300m's 639
(1,282), nearly all of them spanning two volumes in both stores (492 and 625 groups).

## 2. The text layers that differ

Comparing the two stores' text layers document by document, not only their character counts, finds
**five volumes, 50 documents and 80 chunks** whose text differs, where the background named three
by character count. Two of the five differ by the same number of characters. Document and chunk
counts are equal in all 553 volumes.

| volume | documents | characters | the shipped store embedded it | what changed in the corpus |
|---|---|---|---|---|
| `frus1926v02` | 1 (`d205`) | −10 | 2026-08-10 | `&#x93;…&#x94;` printed literally became curly quotes: `cdeef4ca0`, 2026-09-29, "fix: characters lost to encoding mistakes" |
| `frus1952-54v14p2` | 1 (`d847`) | −2 | 2026-08-10 | the mojibake `â€™` became `’`, the same commit |
| `frus1958-60v03mSupp` | 1 (`d471`) | 0 | 2026-08-10 | a replacement character became `’`, the same commit |
| `frus1958-60v05mSupp` | 5 | 0 | 2026-08-10 | replacement characters became en dashes (`ETA–1`, `CH–10`), the same commit |
| `frus1981-88v16` | 42 | +56 | 2026-09-09, 23:30 | the volume's cross-references were marked up two days later (`4e9694796`, 2026-09-11, "fix: enrich cross-references"), and the harvester now writes a space between a `<ref>` and the full stop after it (`See Document 375 .`); further edits followed through `59134163c` (2026-09-29, ten no-break spaces) |

So the background's reading holds: the corpus's `volumes/` is unchanged since the bundle's
`99d851c79`, every one of these commits is an ancestor of it, and the shipped store embedded these
volumes before the commits. **The shipped bundle names corpus `99d851c79`, and 50 of its documents
were embedded from older text.** The differences are punctuation and repaired characters. A move
closes the gap, since the new store was embedded from the current text; if the 300m stays, a
re-embed of the five volumes would (not done: nothing shipped was re-embedded). Recorded in the plan
of record's §6e.

**Whether it matters to the comparison:** it does not. 40 of the 83,119 Gate A queries have one of
the 50 documents as their source or a target; without them the overall difference at the shipping
shape is −0.0071 [−0.0084, −0.0057], the same to the fourth decimal (`untouched:` rows in
`gate-a-compare.json`). None of the 3,600 ladder queries is among them, and no row of either
model's judged-query top ten is. `text-differences.json` lists every document.

## 3. The pack (design step 6, first half)

**A control first.** The shipped store, repacked into a scratch folder with `EXPECT_DIGEST` set to the
shipped family's `a726ca60…`, `DIMS=512`, `GENERATED_DATE=2026-10-10` and an empty `LAYOUT_DIR`:
`semantic-vectors-index.json`, `semantic-vectors-binary.bin` and `semantic-shards-manifest.json` are
byte-identical to `FRUSExplorer/Resources/`, and the manifest records every shard's SHA-256, so all
553 shards are too.

**EmbeddingGemma 2**, `SemanticVectorsGenerator` with `EXPECT_DIGEST` unset (a new family, on
purpose), into `~/frus-b2/pack/`, the map skipped:

| width | provenance digest | binary | 553 shards | index | peak memory | time |
|---|---|---|---|---|---|---|
| 512 | `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101` | 20,476,048 B | 162,377,248 B | 72,994 B, 1,603 id segments | 1,003 MB | 3.6 s |
| 256 | `cafefae881689faf5386a9996ef98446bb64f3998e33b816f0d317eb22d75694` | 10,239,376 B | 81,835,552 B | 72,995 B | 551 MB | 2.8 s |

The 300m was packed at 256 too, for the ladder (digest `57fb4c4b…`, the same sizes). **The packed
sign bits equal the numpy pool's** `pack_bits(truncate(F, D))` for all 314,616 documents, for
EmbeddingGemma 2 at both widths and the 300m at 512 (`pack_parity.py`), so every gate below measured
the vectors the packer would ship. The kernel opened both models' packs at both widths, provenance
and shard checks included, in §7's benchmark. The shipped repack's own peak, measured for the
runbook, is 999 MB at 512.

Two fields of the new pack are the 300m's and would be wrong in a move (§11): its
`retrieval.measuredRecallAt10` reads 0.851 with the 300m's `measuredBy`, because
`SemanticVectorsRunner.measuredRecallAt10` is keyed by width alone.

## 4. Gate A at corpus scale (design step 6)

`compare_corpus.py` scores both models over the same edges, with every one of the 314,616 documents
a candidate and `gate_a_corpus.py`'s exact rank semantics, and pairs them query by query. Both
models face the same 83,119 queries.

**The edges, today's index:** 187,289 clean cross-references scanned; 16,455 dropped as unresolved
page anchors, 11,034 as not in the store and 2,728 as self-references; 157,072 kept (35,685 crossing
volumes), giving 146,241 resolved pairs and **83,119 queries from 527 citing volumes**. August's
assessment read 70,469 queries from 526 volumes over the index of the day (33,390 unresolved
anchors then). The labels have changed since, so absolute figures from the two days are not
comparable, as stage 1 found at spike scale; the 83,119 is today's equivalent of the 70,469.

**The absolute figures, overall:**

| configuration | 300m MRR@10 | EG2 MRR@10 | 300m hit@10 | EG2 hit@10 | 300m hit@100 | EG2 hit@100 | median rank, 300m / EG2 |
|---|---|---|---|---|---|---|---|
| float, 768 | 0.2606 | 0.2528 | 0.4689 | 0.4610 | 0.7115 | 0.7111 | 13 / 14 |
| float, 512 | 0.2577 | 0.2506 | 0.4652 | 0.4568 | 0.7078 | 0.7066 | 14 / 15 |
| int8, 512 | 0.2574 | 0.2504 | 0.4649 | 0.4570 | 0.7077 | 0.7065 | 14 / 15 |
| **Hamming 512 bits, pool 800 → int8-512 (ships)** | **0.2574** | **0.2503** | **0.4648** | **0.4565** | 0.7053 | 0.7005 | 14 / 15 |
| int8, 256 | 0.2471 | 0.2416 | 0.4481 | 0.4437 | 0.6902 | 0.6916 | 16 / 16 |
| Hamming 256 bits, pool 800 → int8-256 (shipped before #933) | 0.2468 | 0.2400 | 0.4466 | 0.4383 | 0.6729 | 0.6553 | 16 / 18 |

*Paired, EmbeddingGemma 2 minus the 300m, at the shipping shape.* Each interval is a 95% paired
bootstrap of 10,000 resamples (seed 20261015), first over queries, as `spike_compare.py` does, then
over citing volumes, since the queries of one volume are not independent.

| scope | queries | volumes | 300m | EG2 | ΔMRR@10 | over queries | over volumes | Δhit@10 [queries] | better / worse / equal |
|---|---|---|---|---|---|---|---|---|---|
| **overall** | 83,119 | 527 | 0.2574 | 0.2503 | **−0.0071** | [−0.0085, −0.0057] | [−0.0086, −0.0056] | −0.0083 [−0.0104, −0.0063] | 32,769 / 33,809 / 16,541 |
| pre-1900 | 677 | 44 | 0.1708 | 0.1634 | −0.0073 | [−0.0186, +0.0040] | [−0.0162, +0.0031] | −0.0133 [−0.0369, +0.0103] | 279 / 293 / 105 |
| 1900–1918 | 4,580 | 41 | 0.2071 | 0.1962 | **−0.0109** | [−0.0163, −0.0056] | [−0.0185, −0.0031] | −0.0194 [−0.0288, −0.0103] | 1,799 / 2,045 / 736 |
| **1919–1938, the interwar era** | 9,886 | 76 | 0.1491 | 0.1471 | **−0.0020** | **[−0.0050, +0.0012]** | **[−0.0049, +0.0010]** | −0.0058 [−0.0115, −0.0001] | 4,439 / 4,301 / 1,146 |
| 1939–1945 | 12,753 | 55 | 0.1938 | 0.1860 | **−0.0078** | [−0.0109, −0.0048] | [−0.0110, −0.0046] | −0.0082 [−0.0134, −0.0031] | 5,171 / 5,657 / 1,925 |
| 1946–1960 | 30,390 | 140 | 0.2788 | 0.2688 | **−0.0100** | [−0.0124, −0.0076] | [−0.0126, −0.0074] | −0.0123 [−0.0156, −0.0087] | 11,769 / 12,222 / 6,399 |
| 1961–1976 | 17,262 | 129 | 0.3150 | 0.3083 | **−0.0067** | [−0.0100, −0.0035] | [−0.0105, −0.0028] | −0.0060 [−0.0107, −0.0011] | 6,484 / 6,592 / 4,186 |
| 1977 onward | 7,571 | 42 | 0.3271 | 0.3274 | +0.0003 | [−0.0044, +0.0050] | [−0.0037, +0.0042] | +0.0062 [−0.0009, +0.0135] | 2,828 / 2,699 / 2,044 |
| same-volume citations only | 62,691 | 518 | 0.2901 | 0.2809 | **−0.0092** | [−0.0109, −0.0075] | [−0.0110, −0.0073] | −0.0108 [−0.0133, −0.0083] | 23,554 / 25,268 / 13,869 |
| cross-volume citations only | 13,676 | 507 | 0.0948 | 0.0937 | −0.0011 | [−0.0032, +0.0009] | [−0.0031, +0.0009] | −0.0013 [−0.0055, +0.0028] | 6,572 / 6,002 / 1,102 |
| both | 6,752 | 454 | 0.2837 | 0.2835 | −0.0002 | [−0.0049, +0.0045] | [−0.0047, +0.0044] | +0.0012 [−0.0062, +0.0086] | 2,643 / 2,539 / 1,570 |
| `frus1938v01` (stage 1's interwar volume) | 136 | 1 | 0.1634 | 0.1315 | −0.0319 | [−0.0589, −0.0073] | — | −0.0221 [−0.0735, +0.0221] | 60 / 64 / 12 |
| `frus1948v06` (stage 1's Cold War volume) | 251 | 1 | 0.1936 | 0.1985 | +0.0049 | [−0.0130, +0.0229] | — | −0.0159 [−0.0558, +0.0199] | 101 / 112 / 38 |

The eras are by the citing volume's midpoint year, fixed in the script before any result was read;
the gate's own three bands give pre-1900 −0.0073 [−0.0188, +0.0040], 1900–1945 −0.0061 [−0.0082,
−0.0041] over 26,310 queries, and after 1945 −0.0076 [−0.0094, −0.0058] over 56,132. Relative to the
300m, the era losses are 5.3% (1900–1918), 4.0% (1939–1945), 3.6% (1946–1960) and 2.1% (1961–1976);
the interwar era's is 1.3% and inside the noise.

*Overall, by configuration* (ΔMRR@10, interval over queries):

| float-768 | float-512 | int8-512 | ships (pool 800) | pool 200 | pool 400 | pool 1600 | int8-256 | 256-bit funnel |
|---|---|---|---|---|---|---|---|---|
| −0.0078 [−0.0091, −0.0065] | −0.0071 [−0.0085, −0.0057] | −0.0070 [−0.0084, −0.0056] | −0.0071 [−0.0085, −0.0057] | −0.0074 [−0.0087, −0.0060] | −0.0072 [−0.0086, −0.0058] | −0.0071 [−0.0084, −0.0057] | −0.0054 [−0.0069, −0.0039] | −0.0067 [−0.0082, −0.0052] |

The gap is there at full width, so it is the models', not the quantization's: every 512 shape gives
the same −0.007.

**Per citing volume**, at the shipping shape: 317 of the 527 volumes come out worse under
EmbeddingGemma 2, 200 better and 10 equal. Of the 384 with at least 100 queries, 42 have an interval
wholly below zero and 3 wholly above, where chance alone would put about 10 on each side. The largest
losses among them are `frus1917-72PubDipv07` (−0.0617), `frus1961-63v10` (−0.0606), `frus1955-57v13`
(−0.0540), `frus1950v02` (−0.0529) and `frus1915Supp` (−0.0473, 314 queries); the largest gains
`frus1961-63v16` (+0.0462), `frus1964-68v18` (+0.0328), `frus1969-76v17` (+0.0322) and
`frus1934v04` (+0.0312). Two of the three volumes whose gain is outside the noise are interwar
(`frus1934v04` and `frus1936v01`; the third is `frus1977-80v22`). The loss is broad, not a few
volumes'. Every volume's figure is in `gate-a-compare.json`.

**Against stage 1.** The spike measured −0.0108 [−0.0285, +0.0069] overall at the shipping shape over
343 queries; the corpus gate measures −0.0071 with an interval a tenth as wide. The spike's point
estimate had the sign and roughly the size; its interval could not resolve it.

**How to read the instrument.** Gate A treats a cross-reference as a weak positive and scores a
document against documents, not a typed question against documents; its labels are noisy, and 75%
of its queries cite only their own volume. Its document-to-document form is the shape of the
Related Documents semantic axis more than of a typed Meaning search, which §6's queries measure.
EmbeddingGemma 2 puts slightly fewer volume-mates in its top ten (58.1% of slots against 59.6%, §5)
and loses only on same-volume citations; on the cross-volume ones, the gate's nearest thing to
discovery across volumes, the two are level.

## 5. The rerank pool, and each model against its own neighbours

**Gate A by pool** (MRR@10, Hamming over 512 bits into an int8-512 rerank):

| pool | 200 | 400 | 800 (ships) | 1600 | every candidate (int8-512) |
|---|---|---|---|---|---|
| 300m | 0.2573 | 0.2574 | 0.2574 | 0.2574 | 0.2574 |
| EmbeddingGemma 2 | 0.2499 | 0.2502 | 0.2503 | 0.2504 | 0.2504 |

`RERANK_POOL` at 800 needs no change for EmbeddingGemma 2: past 200 the pool costs neither model a
measurable amount on Gate A.

**Recall@10 against each model's own float-768 neighbours**, 3,600 era-stratified queries (seed
18610810; the same rows for both models), `nn_ladder.py` and `rerank_pool_sweep.py` unchanged, and
`compare_corpus.py`'s sweep with the Hamming stage over 512 bits:

| configuration | 300m | EmbeddingGemma 2 |
|---|---|---|
| int8-512, every candidate | 0.8615 | 0.9054 |
| Hamming 512 bits, pool 200 / 400 / **800** / 1600 → int8-512 | 0.8561 / 0.8599 / **0.8610** / 0.8615 | 0.8877 / 0.8974 / **0.9021** / 0.9038 |
| Hamming 256 bits, pool 200 / 400 / 800 / 1600 → int8-512 (`rerank_pool_sweep.py`) | 0.8135 / 0.8363 / 0.8493 / 0.8558 | 0.7937 / 0.8382 / 0.8674 / 0.8847 |
| int8-256, every candidate | 0.7454 | 0.8055 |
| Hamming 256 bits, pool 200 / 400 / 800 / 1600 → int8-256 | 0.7249 / 0.7363 / 0.7413 / 0.7438 | 0.7354 / 0.7665 / 0.7845 / 0.7942 |

The two sweeps agree to the digit on every row they share, and `nn_verify.py` found no mismatch
against the literal slow path for either model. Three things follow. **The Hamming stage the app runs
since #933 is nearly free**: over 512 sign bits, a pool of 800 keeps 0.8610 of the 300m's 0.8615
and 0.9021 of EmbeddingGemma 2's 0.9054. **EmbeddingGemma 2's sign bits are the weaker funnel at 256**, as
stage 1 found, which a wider pool repays. And **the shipped artifact's stated recall describes the
256-bit scan**: its `measuredRecallAt10` of 0.851 was measured in August with 256 sign bits ahead of an
int8-512 rerank; the funnel the app runs measures 0.861 on today's queries, where the 256-bit one
measures 0.849. Nothing in the app reads the figure (§11).

**Neighbour structure** (float-768 top ten, the 3,600 queries):

| | 300m | EmbeddingGemma 2 |
|---|---|---|
| top-1 in the query's own volume | 77.7% | 77.6% |
| top-10 slots in the query's own volume | 59.6% | 58.1% |
| top-10 slots in the query's era band | 96.8% | 96.6% |
| top-1 cosine, median (p25; minimum) | 0.872 (0.840; 0.644) | 0.917 (0.899; 0.794) |
| top-1 cosine above 0.98 / above 0.995 | 1.67% / 0.75% | 2.22% / 1.00% |

The two models' top-1 neighbour is the same document for 62.5% of queries, and their top tens share
64.8% (stage 1's spike: 58% and 68%). They are different maps, as stage 1 said.

## 6. The 25 judged queries (design step 6)

`RetrievalEvalHarness`, unchanged, against `llama-server` at `a0e6dc73`, the query prompt the August
sitting judged, and the shipping funnel at 512, for each model over its own pack: the 300m over the
shipped artifacts, EmbeddingGemma 2 over its scratch pack.

**The 300m reproduces the August sitting.** 20 of its 25 top tens are the August lists in the same
order and 23 hold the same documents (the five that moved differ from rank 4 down; the encoder in
August was LM Studio, and two volumes were repacked on 2026-10-10). Scored against the August
judgments: precision 0.652 over judged rows and MRR 0.771, the sitting's 0.65 and 0.771.

**EmbeddingGemma 2 returns mostly other documents.** Its top ten shares on average 3.6 documents
with the 300m's August list, and none at all for five queries (Q1, Q20, Q22, Q23, Q25). Of its 250
rows, 67 were judged in August (59 relevant, 8 not) and 183 were not:

| | 300m (August list) | EmbeddingGemma 2 |
|---|---|---|
| rows judged relevant / not / unjudged | 121 / 65 / 64 | 59 / 8 / 183 |
| precision over judged rows | 0.651 | 0.881 |
| precision, unjudged rows counted as misses / as hits | 0.484 / 0.740 | 0.236 / 0.968 |
| MRR, unjudged rows counted as misses / as hits | 0.771 / 0.867 | 0.545 / 0.980 |

EmbeddingGemma 2's 0.881 is over the rows the August routes also found, a sample biased towards
documents both models agree on, and is not its precision. Its bounds contain the 300m's figures on
both measures, overall and in every register but one (`judged-queries-score.json`): on the three
known items its MRR floor, 0.667, already equals the 300m's ceiling, because it ranks the February
1973 Mao memcon (Q17) first where the 300m ranked it second. For "blood telegram" (Q25) it no longer
returns Chargé Trueblood's telegrams, the August sitting's exhibit of a surname collision; its ten
are documents from 1896 to the 1980s, unjudged and none from Dacca. **The sitting cannot rank the two
models until the 183 rows are judged.** `eval-eg2-2026-10-15/` holds the report and a
`verdicts.csv` with every August judgment carried over (67 semantic rows, 131 lexical, 55 PRF);
the 183 blank semantic rows are the sitting, about two fifths of August's 435.

At 256 the top tens move: EmbeddingGemma 2's share 6.0 documents with its own 512 lists and the
300m's 4.8, and no query keeps the same ten under either model.

## 7. The dimension ladder at 256 and 512

`Dimension-Ladder-Spike.md`'s method: both widths packed by the shipping generator into scratch, then
`DimensionLadderBenchmark` driving the real kernel over each pair (601 queries, pool 800, release
build, two runs each, nothing else running).

**Size** is the format's and the same for both models:

| | 256 | 512 |
|---|---|---|
| bundled binary | 10,239,376 B (9.76 MiB) | 20,476,048 B (19.53 MiB) |
| 553 shards | 81,835,552 B (78.04 MiB) | 162,377,248 B (154.86 MiB) |
| device total, full library | 87.81 MiB | 174.38 MiB |

**Time** on the Air (the August figures were the M1 Max Studio's):

| | Hamming scan, 256 | Hamming scan, 512 | ratio | rerank of 800 rows, 256 / 512 |
|---|---|---|---|---|
| 300m, runs 1 and 2 | 0.976 / 0.982 ms | 1.490 / 1.572 ms | 1.53× / 1.60× | 0.062 / 0.110 ms |
| EmbeddingGemma 2, runs 1 and 2 | 0.912 / 1.005 ms | 1.490 / 1.585 ms | 1.63× / 1.58× | 0.062 / 0.110 ms |

The kernel's time is a property of the width and the document count, not the model, and measures
so. The Air's figures overlap the Studio's August ranges (0.96–1.11 and 1.53–1.68 ms).

**Quality.** Against its own neighbours EmbeddingGemma 2 keeps more at 256 (§5: 0.806 flat and 0.785
through the funnel, against the 300m's 0.745 and 0.741), which is the card's near-lossless claim
holding against the model itself. On Gate A both models lose about 0.010 MRR@10 from 512 to 256
(the 300m 0.2574 → 0.2468, EmbeddingGemma 2 0.2503 → 0.2400 through the funnels), and EmbeddingGemma
2 at 256 sits 0.0174 below the 300m at 512. A move at 256 would halve the bundled tier and every
shard and lose on both counts at once; the width stays a separate decision from the model.

## 8. Query-encoder parity on an iPhone and the Mac (design step 7): left for B4

Not run. The procedure loads the GGUF through the app's `SemanticQueryEncoder`, so it needs
`llama.xcframework` rebuilt at `a0e6dc73` or later and its dSYMs released on `frus-semantic-vectors`,
which is B4's first item; a local rebuild swapped into `Vendor/` would change a committed binary in
a measurement session. It also runs on an iPhone, the owner's. Stage 1 already showed the model loads
and embeds under that runtime on the Mac.

One thing was prepared: the reference fixture, `make_query_parity_fixture.py` through `llama-embedding`
at `a0e6dc73` (25 queries, 768 dimensions, GGUF `2188ac1d…`), kept in `~/frus-b2/` and not
committed. **The script writes `llama.cpp 8663224` into the fixture's `referenceEngine` whatever
binary it ran**, so the B4 session that regenerates the fixture at its pinned commit corrects that
label too.

## 9. The harvest's time on the Air

**12.64 hours of embedding** (45,503.7 s), 12 h 38 min of wall clock, against stage 1's 8.6 to 9.1
and the live ETA's 11.4 at the start. The whole run averaged 29,312 document characters a second,
0.65 of the spike's 44,789. Its pace, this run's seconds over the Studio's August seconds for the
same volumes (higher is slower), climbed steadily all night:

| hour | volumes | characters a second | pace against the Studio |
|---|---|---|---|
| 18:00 | 35 | 34,739 | 1.70 |
| 19:00 | 45 | 33,416 | 1.77 |
| 20:00 | 58 | 34,164 | 1.75 |
| 21:00 | 54 | 32,664 | 1.91 |
| 22:00 | 43 | 30,765 | 2.05 |
| 23:00 | 39 | 30,758 | 2.08 |
| 00:00 | 35 | 29,312 | 2.19 |
| 01:00 | 41 | 27,880 | 2.30 |
| 02:00 | 45 | 27,948 | 2.27 |
| 03:00 | 47 | 27,161 | 2.33 |
| 04:00 | 41 | 25,430 | 2.41 |
| 05:00 | 37 | 24,868 | 2.51 |
| 06:00 | 33 | 23,140 | 2.69 |

Recorded, not explained:
- **The first hour was already slow**: 0.78 of the spike's rate, with Backblaze and Photos' analysis
  each using about 70% of a core at the start (stage 1, §7).
- **The battery drained on AC during the first two hours**: `pmset -g log` has the Air on AC from
  17:19 at 80%, then 64% at 18:52, 62% at 18:58 and 56% at 19:27, and 80% again by 02:14: a draw
  above what the adapter supplied while the run was fastest.
- **No thermal or performance warning** was recorded overnight, and the decline is a slope, not a
  step, which fits gradual thermal or power management better than a job starting or stopping.
  Neither was measured: stage 1's sustained probe covered 25 minutes, not twelve hours.

For a later re-embed on the Air: plan on 13 hours, use an adapter that covers the load, and keep
the status script's hourly pace in view.

## 10. For B3: the reading, set out

The plan's rule: the model that leads ships; a tie goes to Apache 2.0; a loss leaves the 300m under
the Terms, the custom EULA owed before the first App Store submission, and B5 opens. What B2 measured:

1. **On Gate A at corpus scale the 300m leads**, by 0.0071 MRR@10 (2.8%) and 0.83 points of hit@10,
   outside both intervals. EmbeddingGemma 2 leads outside the noise in no era; the 300m leads in
   four eras outside it; three are level, the interwar era among them.
2. **The lead is wholly in same-volume citations.** Cross-volume citations are level, and so is
   hit@100 at full width (0.7115 against 0.7111): the new model finds the cited documents about as
   often, and ranks them a little lower.
3. **Gate A measures document against document.** Typed Meaning search, query against document, is
   what the judged queries measure, and they cannot rank the two models yet: 183 unjudged rows.
4. **Licence and cost are as stage 1 recorded:** Apache 2.0 ends every obligation of the Gemma
   Terms; the card's kept Prohibited Use Policy sentence and the missing LICENSE file are the owner's
   to read; the move is B4's lane (§11) with the store already paid for.

Three readings follow, and which applies is the owner's:
- **Gate A decides, and it reads a loss.** The 300m stays; the EULA is owed before submission; B5,
  the memo on other Apache-2.0 embedders, opens.
- **A 2.8% gap on a weak-positive gate is "comparable quality"**, the runbook §0's words. Read so, it
  is a tie, and a tie goes to Apache 2.0: B4 runs.
- **The judged sitting decides.** The 183 rows are the instrument the Meaning route's own verdict
  rested on, and they measure the feature readers type into. B3 waits for the sitting, about two
  fifths of August's.

Build 51 does not wait for Track B by default (plan of record §0). Nothing was posted to #1659.

## 11. What B4 inherits if the move goes ahead

- **The runtime and step 7**: `llama.xcframework` rebuilt at `a0e6dc73` or later, its dSYM release,
  and the parity procedure with a fixture regenerated at that commit and correctly labelled (§8).
- **The store is done and verified** (`~/frus-semantic-raw-embeddinggemma-2`, 2.2 GB), and a pack is
  one command under a new digest. The map is not packed: `build_layout.py` over the new pool and the
  labels re-derived are B4's.
- **`SemanticVectorsRunner.measuredRecallAt10` is keyed by width alone**, so a pack of any other
  model states the 300m's 0.851. The measured figure for EmbeddingGemma 2 through the funnel the app
  runs is 0.902 at a pool of 800 (§5); the table, its `measuredBy` line and their tests change
  together.
- **`RERANK_POOL` stays at 800** (§5).
- **The displayed score.** The chip's "Semantic match · N%" is the raw cosine
  (`SemanticScoreCopy.percent`). On the 25 queries EmbeddingGemma 2's rank-1 cosine has a median of
  0.798 (0.713–0.864) against the 300m's 0.598 (0.455–0.719); its tenth row 0.773 against 0.572; the
  null control "Space aliens" opens at 0.744 against 0.596. The same quality would read about 20
  points higher, and the August verdict already noted junk wearing confident scores. Whether the
  percentage is recalibrated is a design question for the lane. Any other place that reads a cosine
  as a magnitude, the Related Documents axis among them, is the lane's to check.
- **The UI-test Meaning seam's figures move with any repack** (`UITestMeaningSeederTests`,
  `UITestMeaningSeamSearchTests`; the runbook's `SemanticVectorsGenerator` entry).
- **The 50-document text gap of §2 closes**, since the new store was embedded from today's text.
- **Packing needs about a gigabyte of memory** at 512 (§3; the runbook's entry now says so).

## 12. Not verified

- The query encoder on an iPhone or the Mac under the rebuilt runtime, and the app's memory with the
  new model (step 7, B4).
- EmbeddingGemma 2's quality on typed queries: 183 judged rows are owed (§6).
- The pre-1900 era: 677 Gate A queries give an interval eight times as wide as the overall one.
- Why the Air slowed through the night (§9).
- Whether the card's Prohibited Use Policy sentence binds: the owner's reading.
- Gate A against any other day: the labels moved between August and v69 (§4).

## 13. Files

`eg2-b2-2026-10-15/`:
- `store-check.json`: the store's manifest, checksum count and head totals (§1).
- `text-differences.json`: the five volumes and 50 documents of §2, with the corpus commits.
- `pool-stats-*.json`, `neighbors-*.json`, `nn-verify-*.json`, `rerank-pool-sweep-*.json`: the
  committed corpus-gate scripts' outputs per model (§5).
- `rerank-pool-sweep-512bit-*.json`: `compare_corpus.py`'s sweep over 512 sign bits (§5).
- `gate-a-ranks-*.json`: each model's edge census and configurations; `gate-a-compare.json`: the
  paired Gate A by scope and configuration, and every citing volume's figure (§4).
- `judged-queries-score.json` and `score_judged.py`: §6's table, from the committed sheets.
- `ladder-bench.txt`: the benchmark's output (§7). `harvest-pace.json` and `pace.py`: §9.
- `text_diff.py`, `text_diff_all.py`, `pack_parity.py`, `verify_funnel.py`: the checks of §2, §3 and
  §4. `verify_funnel.py` re-derived 20 queries' funnel and float ranks through a literal full sort
  and found no mismatch.

`eval-eg2-2026-10-15/`: the harness report, `stats.json` and the carried-over `verdicts.csv`, with
a README saying what to judge. Outside the repository, on the Air: the store, its run folder
`~/frus-b2/` (the scratch packs, pools, ranks and harness runs among them), the GGUF and the runtime.

---

Version history:
  1.0 — 2026-10-15: stage 2 run on the Air: the store verified, the text layers compared, the pack
  under a new digest, Gate A paired at corpus scale by era and by citation split, the rerank pool and
  the 512-bit funnel, the judged queries and their sheet, the dimension ladder, the harvest's time,
  and B3 set out for the owner.
