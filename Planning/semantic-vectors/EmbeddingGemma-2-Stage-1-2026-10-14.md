# EmbeddingGemma 2, stage 1: the runtime, the file, the Air, and the spike gates

**Date:** 2026-10-14 · **Status:** STAGE 1 DONE (plan of record Track B, step B1). The owner
decided on 2026-10-14 that stage 2 runs, and its harvest started that evening (§6). · **Issue:** #1659 · **Design:** `EmbeddingGemma-2-Spike-2026-10-14.md`
· **Machine:** the M5 MacBook Air (`Mac17,4`, Apple M5, 10 cores, 32 GB), on AC power with Low
Power Mode off, LM Studio open with no model loaded · **Runtime:** llama.cpp `a0e6dc73` (master, 2026-10-14), Release, Metal ·
**Weights:** `embeddinggemma-2-Q8_0.gguf` from `ggml-org/embeddinggemma-2-GGUF`, 309,855,456
bytes, SHA-256 `2188ac1d…40b09135`; the control is the shipped `embeddinggemma-300m-qat-Q4_0.gguf`
(`5a9e0645…`, 229,093,184 bytes) · **Artifacts and the scripts that made them:**
`eg2-stage1-2026-10-14/`; the paired comparison is `tools/semantic-harvest/spike_compare.py`.

Every figure here was measured on 2026-10-14 on the Air, except where a line says it is the
record of another day. Engineering-side, not legal advice.

## 0. In short

- **The encoder works.** The text-only GGUF loads under a current llama.cpp with no `mmproj`
  file, returns unit-length 768-dimension vectors, and needs no flag beyond `--embeddings`.
- **The Air's accelerators engage, and they double the rate.** The Metal backend reports
  `has tensor = true`; with the tensor path disabled the same input embeds at half the speed,
  for both models.
- **EmbeddingGemma 2 is slower than the 300m, by more than the design assumed:** 1.46× the
  300m's time in the harvester on the same runtime, 1.7–1.8× in the embedding alone. The design's
  ballpark took ×1.1–1.3.
- **The full re-embed on the Air: about 8.3 hours of embedding before throttling**, and 8.6
  to 9.1 hours at the dip the 25-minute sustained probe measured (§5). One night.
- **The spike gates: level overall within the spike's noise, a loss on the interwar volume,
  level on the Cold War volume.** At the shipping configuration the overall MRR@10 difference is
  −0.0108, 95% interval [−0.0285, +0.0069]; the interwar volume's is −0.0448 [−0.0804, −0.0135];
  the Cold War volume's +0.0060 [−0.0146, +0.0266]. The pre-1900 volume has no cross-reference to
  gate with, as in August.
- **The new model loses less to truncation.** Against its own full-width neighbours, its 512-wide
  vectors keep recall@10 at 0.921 where the 300m's keep 0.878, and at 256 0.835 against 0.773.
- **The rebuilt runtime changes nothing for the model the app ships:** the 300m through
  `a0e6dc73` reproduces the shipped store chunk for chunk (cosine ≥ 0.999982), and its Gate A at
  full width exactly.
- **The design's stop rule reads two ways here (§6),** and which one applies is the owner's.

## 1. The licence, read first-hand

The design's §1 and §5 left three statements to secondary coverage, because that session's
container could not reach Hugging Face. This one could, and read the repositories' API records
and the card's raw `README.md` on 2026-10-14:

- **`google/embeddinggemma-2`:** `license: apache-2.0` in the card's metadata, not gated, and the
  card's licence link goes to `ai.google.dev/gemma/docs/gemma_4_license`. **The repository holds
  no LICENSE file**: its fifteen files are the model, its configuration, tokenizer and processor
  files, and the card.
- **The card does keep the sentence** "Deployments must adhere to the Gemma Prohibited Use
  Policy", linking the policy page (line 282 of the card as read). Whether a sentence on a card
  binds beyond the Apache grant is the owner's reading, as the design says; it is now a fact
  that the sentence is there.
- **`ggml-org/embeddinggemma-2-GGUF`:** `license: apache-2.0`, no LICENSE file, and a `.src_sha`
  naming the source commit it was converted from, `914f7f89` of `google/embeddinggemma-2`. The
  GGUF's own header says `general.license = apache-2.0`.

## 2. The runtime and the file (design steps 1 and 2)

**The build.** A shallow fetch of llama.cpp at `a0e6dc7384edb8f5d927155e1d26c10b4a310e6d`
(2026-10-14), which is past PR 30054's merge (`4fbc76de`, 2026-10-06). The newest tagged release,
v0.6.0 of 2026-10-05, predates the PR, so a build for this model comes from master or a later
tag. The checkout is 216 MB, more than the 40–60 MB expected, because it carries vocabulary
files. `cmake -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON`, targets `llama-server` and
`llama-embedding`: 51 seconds, no warning. The configure step tried to download the server's web
interface and failed; the API does not need it.

**The file.** 413 tensors (218 Q8_0, 194 F32, one BF16), 280.44 MiB of tensor data at 8.68 bits a
weight, 271.00 M parameters, architecture `gemma-embedding2`: 24 layers at width 512 with a
projection to 768, mean pooling read from the file's own metadata, non-causal attention, a
1,024-token sliding window. That bears out the design's inference about the backbone (§5): the
card states width 512 and a 262,144-entry vocabulary. The header gives a training context of
262,144 where the card says 8,192; the spike ran 4,096-token slots, and no chunk was refused. The
loader retypes two control-looking tokens, its own note, of the kind it prints for the 300m's
`</s>`. **No SEP warning:** the old LM Studio runtime logged a spurious one on every 300m batch
(`tools/semantic-harvest/README.md`, field notes); under this runtime neither model logs one.

**The prompts.** The card's document prompt is `title: {title} | text: {content}` with
`title: none` when there is no title, and its search query prompt is
`task: search result | query: {query}`. Both are the strings the harvest and the app already use
for the 300m, so the spike embedded with `PREFIX="title: none | text: "` unchanged.

**The download.** 309,855,456 bytes against the design's "near 290 MB" from community listings:
81 MB more than the 300m's opt-in download. The repository has no QAT Q4 file; its other text
file is BF16, 557,950,176 bytes.

**Latency and memory, the step-4 spike's method repeated** (`V5-Step4-Spike-2026-08-28.md` §2
and §3): the 25 owner queries under the query prompt through `llama-embedding`, per-query cost
from the slope between one query and a hundred, best of three; peak memory from
`/usr/bin/time -l`.

| | cold: process, load and one query | per query, warm | peak RSS | peak footprint |
|---|---|---|---|---|
| EmbeddingGemma 2 Q8_0, `a0e6dc73` | 688 ms | 2.14 ms | 860 MB | 499 MB |
| EmbeddingGemma 300m Q4_0, `a0e6dc73` | 390 ms | 1.66 ms | 729 MB | 507 MB |
| *the 300m on `8663224`, 2026-08-28 (the record)* | *354 ms* | *2.5 ms* | *861 MB* | *639 MB* |

Neither difference reaches a typed search: the new model's warm query costs half a millisecond
more and its load 0.3 s more, once a load. The CLI's memory is a ceiling, as the step-4 spike
said; the app's own figure is B4's. On the Mac the Metal dylib of this build is 5.5 MB, where
the August build's whole ggml was 3.8 MB; the xcframework's size is measured when B4 rebuilds it.

## 3. The Air's tensor path (design step 3)

**`has tensor = true`.** The Metal backend reports GPU family Apple10 and Metal4, bfloat, and the
tensor API, after compiling its f16 and bfloat self-test kernels:

```
ggml_metal_device_init: GPU family: MTLGPUFamilyApple10  (1010)
ggml_metal_device_init: GPU family: MTLGPUFamilyMetal4  (5002)
ggml_metal_device_init: has bfloat            = true
ggml_metal_device_init: has tensor            = true
ggml_metal_device_init: recommendedMaxWorkingSetSize  = 26800.60 MB
```

**Where to read it.** The design expected the line in `llama-server`'s startup log. At this
commit neither `llama-server` nor `llama-embedding` prints it at any verbosity, because ggml
initialises its backends while the arguments are parsed, before the log sink is set up. The
lines above came through a log callback set on `libggml-base` directly
(`eg2-stage1-2026-10-14/metal_props.py`), and the A/B below is the check that matters: whether
the path is used, not whether it is reported.

**What it is worth.** The same 640 chunks of `frus1948v06` (1,514,233 characters with the prompt
and overlap, 304,202 tokens by the server's own count), posted in the harvester's batches of 64:

| | model | tensor path | slots | seconds | characters a second |
|---|---|---|---|---|---|
| A | EmbeddingGemma 2 | on | 4 | 33.44 | 45,280 |
| B | EmbeddingGemma 2 | off (`GGML_METAL_TENSOR_DISABLE=1`) | 4 | 62.61 | 24,186 |
| C | EmbeddingGemma 2 | on | 1 | 34.15 | 44,336 |
| D | EmbeddingGemma 2 | on | 8 | 33.85 | 44,731 |
| E | EmbeddingGemma 2, A again | on | 4 | 31.86 | 47,523 |
| F | EmbeddingGemma 300m | on | 4 | 18.81 | 80,517 |
| G | EmbeddingGemma 300m | off | 4 | 36.42 | 41,582 |

The tensor path is worth 1.87–1.96× for the new model and 1.94× for the 300m. Slots of 1, 4 and
8 land within 7.2% of each other, and the same setting run twice (A and E) moved 5%. **The two tokenizers count this input identically**, 304,202 tokens
each, 4.98 characters a token; the harvester's printed `tok/s` divides by a fixed 4.16, so it
overstates the token rate of both models alike and does not bias a comparison.

**LM Studio's runtime on the Air.** The same 640 chunks through LM Studio 0.4.25 with its selected
engine, `llama.cpp-mac-arm64-apple-metal-advsimd` 2.57.0, the 300m loaded at a context of 2,048 as
the harvest recipe says: 70,774 and 68,724 characters a second over two runs (`bench.jsonl`, runs H
and H2). That is 0.85–0.88× the upstream build with the tensor path and 1.65–1.70× the upstream
build without it, so the report of an M5 fallback (its engine 2.21) does not describe 2.57.0 at
full strength. Whether 2.57.0 uses the tensor API is not in LM Studio's logs, which do not keep the
Metal backend's lines. EmbeddingGemma 2 was not tried under LM Studio, since `llama-server` serves
the harvester as it is.

## 4. The spike (design step 4)

**The harvest**, the harvester unchanged, through `llama-server --embeddings` on port 8089
(`-np 4 -c 16384 -b 4096 -ub 4096`), with `SPIKE=1`, `MODEL_FILE` set and the 300m's prefix:

| store | chunks | seconds | document characters a second |
|---|---|---|---|
| `~/frus-semantic-raw-spike-embeddinggemma-2` | 3,359 | 156.1 | 44,789 |
| `~/frus-semantic-raw-spike-embeddinggemma-300m-llamacpp` (the control) | 3,359 | 107.1 | 65,278 |
| *the shipped store's three volumes, the Studio through LM Studio, 2026-08-10 (the record)* | *3,359* | *110.6* | *63,204* |

Today's extraction of the three volumes is identical to the shipped store's text layer, document
for document, so all three stores hold the same 2,198 documents and the same chunk spans.

**The gates.** `spike_gates.py`, unchanged, over three stores: the shipped vectors (the three
volumes of `~/frus-semantic-raw`), the 300m re-embedded through `a0e6dc73`, and EmbeddingGemma 2,
against the Mac's live index (v69, written 2026-10-12): 343 weak-positive queries, 113 in
`frus1938v01` and 230 in `frus1948v06`, from 657 cross-reference rows (150 dropped as reaching
another volume, 3 as self-references). `frus1861` has none, as in August. Then
`spike_compare.py` over the same stores: Gate A at the 512 width the app has shipped since #933,
the paired differences with a bootstrap interval (10,000 resamples, seed 20261014), and the
runtime parity.

*Gate A, MRR@10* (first relevant result within the top ten; the wider ranks are in the JSON):

| configuration | 300m, overall | EG2, overall | 300m, 1938 | EG2, 1938 | 300m, 1948 | EG2, 1948 |
|---|---|---|---|---|---|---|
| float, 768 | 0.2352 | 0.2254 | 0.2189 | 0.1876 | 0.2432 | 0.2440 |
| float, 512 | 0.2315 | 0.2211 | 0.2289 | 0.1868 | 0.2328 | 0.2379 |
| int8, 512 | 0.2322 | 0.2214 | 0.2294 | 0.1846 | 0.2335 | 0.2395 |
| Hamming 512 pool of 200 → int8-512 (the shipping shape) | 0.2322 | 0.2214 | 0.2294 | 0.1846 | 0.2335 | 0.2395 |
| int8, 256 (V-0's shipping width) | 0.2267 | 0.2145 | 0.2334 | 0.1771 | 0.2234 | 0.2329 |

*Paired, EmbeddingGemma 2 minus the 300m:*

| configuration | scope | ΔMRR@10 [95%] | Δhit@10 [95%] | queries better / worse / equal |
|---|---|---|---|---|
| float, 768 | overall | −0.0098 [−0.0275, +0.0078] | −0.0146 [−0.0466, +0.0175] | 129 / 148 / 66 |
| float, 768 | 1938 | −0.0313 [−0.0626, −0.0021] | +0.0088 [−0.0354, +0.0531] | 42 / 55 / 16 |
| float, 768 | 1948 | +0.0008 [−0.0209, +0.0229] | −0.0261 [−0.0696, +0.0130] | 87 / 93 / 50 |
| shipping shape, 512 | overall | −0.0108 [−0.0285, +0.0069] | −0.0117 [−0.0408, +0.0175] | 122 / 159 / 62 |
| shipping shape, 512 | 1938 | −0.0448 [−0.0804, −0.0135] | −0.0088 [−0.0442, +0.0265] | 37 / 56 / 20 |
| shipping shape, 512 | 1948 | +0.0060 [−0.0146, +0.0266] | −0.0130 [−0.0522, +0.0261] | 85 / 103 / 42 |

The interwar loss is in the order within the top ten, not in whether a cited document reaches
it: hit@10 there is level. The pool of 200 is V-0's spike-scale figure; the app's 800 is sized for
314,616 candidates and would be a third of this spike's 2,198.

*Gate B, recall@10 against each model's own full-width neighbours:*

| rung | 300m | EG2 |
|---|---|---|
| float-512 | 0.8777 | 0.9214 |
| int8-512 | 0.8772 | 0.9197 |
| float-256 | 0.7725 | 0.8346 |
| int8-256 | 0.7726 | 0.8343 |
| Hamming 256 pool of 200 → int8-256 | 0.7715 | 0.8301 |
| binary-256 alone | 0.5262 | 0.4849 |
| float-128 | 0.6567 | 0.6992 |

The new model's own neighbourhoods survive truncation better at every width, and its sign bits
alone are worse, which the rerank absorbs. This is agreement with itself, not quality: at 256 its
Gate A (0.2145 at int8) is still below the 300m's at 512 (0.2322), so a narrower bundle does not
come free from this spike.

**The runtime.** The 300m re-embedded through `a0e6dc73` against the shipped store: per-chunk
cosine 0.999982 at the lowest over 3,359 chunks, rank-1 agreement 1.0 and mutual recall@10 0.9998
over the 2,198 documents, and Gate A identical at full width (the int8 rows differ in the fourth
decimal). Rebuilding the vendored runtime is therefore no risk to the shipped vectors, whichever
way B3 goes.

**How different the two models are.** EmbeddingGemma 2's nearest neighbour is the 300m's for 58%
of documents, and their top tens share 68%. They are different maps, so a move re-takes every
measurement made in the 300m's space, as #1659 lists.

**Against the record.** The 300m's Gate B ladder here reproduces V-0's of 2026-08-10 to the
digit, so these are the vectors V-0 read. Its Gate A does not (V-0 had 265 queries and MRR@10
0.087), because the labels changed: the index's page ranges have filled in since August, and V-0
dropped 122 references as unresolved page anchors where none is dropped now. Gate A figures from
different days are not comparable; within this run all three stores face the same labels.

## 5. The re-embed on the Air, re-derived

The design's ballpark (§4) is replaced by measured rates. The full store holds 553 volumes,
605,978 chunks and 1,333,779,960 document characters (its `head.json` files).

| | rate | the full corpus |
|---|---|---|
| EmbeddingGemma 2 on the Air, `a0e6dc73`, spike harvest | 44,789 characters a second | 8.27 h before throttling |
| the same, at the sustained probe's mean and its trough (0.965 and 0.904 of its early passes) | 43,239 to 40,499 | 8.6 to 9.1 h |
| EmbeddingGemma 300m on the Air, `a0e6dc73` | 65,278 | 5.68 h |
| *the 300m on the Studio through LM Studio, 2026-08-10 (the record)* | *62,131* | *5.96 h* |

**The sustained probe** (`throttle.jsonl`): the bench's 640 chunks re-embedded pass after pass for
25.4 minutes, 48 passes, on EmbeddingGemma 2 with the tensor path. After a first pass at 54,093
characters a second, passes 2 to 6 averaged 49,484. The rate fell to between 44,744 and 46,100
from the 11th to the 18th minute, climbed back to about 49,000, and the last five passes averaged
47,888; the run's mean was 47,771. `pmset` recorded no thermal or performance warning before or
after. Over 25 minutes, then, the fanless Air held within 10% of its early rate, where the
design's ballpark assumed ×1.15 to ×1.3. The spike harvest's rate was taken over its first three
minutes, so the table scales it by the probe's mean and trough against its early passes. Eight
hours is not 25 minutes: the harvester's live ETA shows any further slowing in the first hour.

What the design's table had, against what was measured:
- *Model cost ×1.1 to ×1.3*: measured ×1.46 in the harvester and ×1.7–1.8 in the embedding
  alone. The fixed cost of reading and chunking the XML is the same for both models, which is
  why the harvester's ratio is the smaller.
- *Q8_0 in place of Q4_0 ×1.0*: not separable here, since the two files are different models.
- *The Air with the tensor path ×0.7 to ×0.9 of the Studio's time*: the 300m on the Air through
  the upstream runtime runs at 1.05× the Studio's LM Studio rate, so ×0.95.
- *The Air on plain shaders ×1.5 to ×2.5*: measured ×1.9 slower than with the tensor path.
- *The token count*: the two tokenizers count the bench's input identically. The Studio run's
  record is 1,332,974,542 document characters, 320.4 M tokens at the harvester's 4.16; the
  design's "about 353.7 M tokens" does not match it, and none of its conclusions turned on it.

## 6. Go or no-go for stage 2

The design's rule: "If stage 1 shows a weaker gate than the 300m's, or no working encoder, stage 2
does not run and B5 opens." The encoder works. The gate reads two ways:

- **By its point estimates, the gate is weaker.** EmbeddingGemma 2 is below the 300m overall in
  every configuration, by 0.0098 to 0.0108 MRR@10 (4–5% relative), and it loses more queries than
  it wins (159 to 122 at the shipping shape). On the interwar volume the loss is outside the noise
  at both widths. Read this way, stage 2 does not run and B5, the memo on other Apache-2.0
  embedders, opens.
- **By its intervals, the overall gate is level.** At 343 queries the instrument cannot tell
  apart two models 0.01 MRR apart: both overall intervals include zero, as does the Cold War
  volume's. Stage 2's Gate A runs over 70,469 queries in every era that has cross-references, and it is the instrument B3
  was written to read ("the model that leads ships; a tie goes to Apache 2.0"). Read this way,
  stage 2 runs.

**This session's recommendation is to run stage 2,** for three reasons: the spike cannot resolve
a difference this size, so the corpus gate is the only reading that settles B3; stage 2 costs one
night of the Air and leaves nothing shipped changed; and a tie ends every obligation of the Gemma
Terms. **If it runs, B3 should read the era rows and not only the overall figure**, since the one
signal outside the spike's noise is an era's: the corpus gate's per-era MRR@10 and its interval
for the interwar volumes, where an era-level loss would be a loss for the readers of that era
however the overall figure falls. The rule is the owner's, and so is which reading of it applies.

**The owner's decision, 2026-10-14: stage 2 runs.** The full harvest started on the Air at 18:16
that evening, in one invocation, into `~/frus-semantic-raw-embeddinggemma-2`, with the runtime,
flags and contract below. Its log, its start time and the copies of the harvester and
`manifest.json` it read are in `~/frus-b2/`. The corpus checkout was at `6170e4b32`, whose
`volumes/` is unchanged since the bundle's `99d851c79`.

**Stage 2 as measured here:** `llama-server` from `a0e6dc73` (or later) with the tensor path
on, which beat LM Studio's runtime by 12–15% on the 300m (§3), with `-np 4 -c 16384 -b 4096
-ub 4096`; the harvester's full run into a fresh `OUT_DIR` with `MODEL=embeddinggemma-2-Q8_0`,
`MODEL_FILE` and `PREFIX` as in the spike, under `caffeinate -i`. Disk is not a constraint: a
full store is about 2.2 GB, and about 16 GiB are free.
Step 7, the query encoder on an iPhone and the Mac, needs `llama.xcframework` rebuilt at the same
commit first.

## 7. Not verified

- The spike's three volumes are two gated eras; the pre-1900 era and everything after 1948 are
  read only by stage 2.
- Throttling beyond the probe's 25 minutes; an overnight run on battery or in a warm room.
- The rate with other work on the Mac. When B2 started, Backblaze's `bztransmit` and Photos'
  `photoanalysisd` were each using about 70% of a core. The first two volumes then ran 15–16%
  below the spike's rate (38,177 characters a second for `frus1861` against 45,408), and the
  live ETA read 11.4 h. Whether the two caused it was not tested.
- The query encoder on an iPhone, and the app's memory figure under the new model: B2's step 7
  and B4.
- The model's quality in any sense but these gates; the 25 judged queries are stage 2's.
- Whether the card's Prohibited Use Policy sentence binds: the owner's reading (§1).

## 8. Files

`eg2-stage1-2026-10-14/`:
- `spike-gates.json`: `spike_gates.py`'s output over the three stores. The blind panel it also
  stages was not kept: the panel stopped being a gate on 2026-08-12.
- `spike-compare.json`: `spike_compare.py`'s output.
- `bench.jsonl`, `latency.jsonl`, `throttle.jsonl`, `metal-device.txt`: the measurements in §2, §3
  and §5.
- `bench.py`, `latency.py`, `throttle.py`, `metal_props.py`: the scripts that took them (the
  latency script's scratch file now goes to the system temporary folder).

The two spike stores stay on the Air, outside the repository (13 MB each), with the GGUF at
`~/Development/models/embeddinggemma-2/` and the runtime at `~/Development/llama.cpp-eg2/`.

---

Version history:
  1.0 — 2026-10-14: stage 1 run on the Air: the runtime, the file, the tensor path, the spike gates
  with paired intervals, the re-embed re-derived, and the two readings of the stop rule.
