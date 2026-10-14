# The EmbeddingGemma 2 spike: what it measures, what a move would end, and what the re-embed costs on the Air

**Date:** 2026-10-14 · **Status:** STAGE 1 RUN on 2026-10-14, on the Air:
`EmbeddingGemma-2-Stage-1-2026-10-14.md` holds the figures, and they replace this file's §4 and
settle three of its §5 lines. Stage 2 runs, the owner's decision of 2026-10-14. Queued by the owner's decision of 2026-10-14 (plan of record
decision 10; since the plan of 2026-10-14, Track B, steps B1 to B5, beside the app's Track A to build 51) · **Issue:** #1659 · **Precedes:** `Gemma-Compliance-Runbook.md`
§0, whose 2026-10-12 re-check found the model, and the issue, which lists what a move would end
and touch. Engineering-side, not legal advice.

Nothing here is measured about EmbeddingGemma 2 itself. The figures are the repository's own
measurements of the model the app ships, EmbeddingGemma 300m, and what public sources say about
the new one, each marked. The spike exists to replace the second kind with the first.

## 0. Why there is a spike

`Gemma-Compliance-Runbook.md` §0 watches for one event: an Apache-2.0 embedder of comparable
quality. On 2026-10-12 the first half arrived. `google/embeddinggemma-2` is on Hugging Face,
ungated, tagged `apache-2.0`, and Google's own announcement and developer guide say Apache 2.0.
The second half, comparable quality on this corpus, is unmeasured, and the runbook's sentence
turns on both. The owner decided on 2026-10-14 to measure it.

## 1. The licence situation, read on 2026-10-14

**How it was read.** The session's container could not reach ai.google.dev or huggingface.co,
so the live Terms, the policy page and the two model cards were not re-read that day. The
readings below are the bundled copy of the Terms (`FRUSExplorer/Resources/gemma-terms-of-use.txt`,
captured 2026-08-28), the runbook's dated re-checks of 2026-10-02 and 2026-10-12, and web search
results of 2026-10-14, which agreed with them on every point they covered.

**EmbeddingGemma 300m, the model the app ships.** Unchanged. The Terms' Appendix lists
EmbeddingGemma by name; the Terms page read "Last modified: April 1, 2026" and the Prohibited
Use Policy "February 21, 2024" at build 50's re-check; the Hugging Face record still says
`license: gemma` with manual gating. No relicensing was found.

**EmbeddingGemma 2.** Apache 2.0 by every source read: the Hugging Face tag and card metadata,
Google's announcement, Google's developer documentation, and the card's licence link, which goes
to Google's Gemma 4 licence page, the plain Apache 2.0 text. Two caveats come only from secondary
coverage and were not seen first-hand: the card is reported to keep the sentence "Deployments
must adhere to the Gemma Prohibited Use Policy", and the repository is reported to have no
LICENSE file. A sentence on a model card is not a condition of the Apache grant, whose
redistribution conditions are its section 4 alone, and Apache 2.0 carries no flow-down duty.
**The owner reads that section of the card before the move is decided.**

**What the app's gates are, and which licence each belongs to.** Every obligation under the
current Terms is built except one. The opt-in download, the consent sheet
(`SemanticModelConsentSheet`), the About notice with the bundled Terms (`GemmaTermsView`), the
`NOTICE` sentence and the per-release policy re-read are live. The custom App Store EULA
(`App-Store-Custom-EULA.md`) is drafted and not entered in App Store Connect; it is owed before
the first App Store submission, and the app is TestFlight-only, so the deadline has not arrived.

| Obligation | Under the Gemma Terms (EmbeddingGemma 300m) | Under Apache 2.0 (EmbeddingGemma 2) |
|---|---|---|
| Use-restriction flow-down as an enforceable provision, plus notice (§3.1, first condition) | Required: the consent sheet plus the custom EULA; for the Mac DMG the consent sheet alone, since the notarize script attaches no licence | None |
| A copy of the terms to every recipient | Required: `GemmaTermsView` | A copy of the Apache licence, which About ▸ Legal already shows for the app's own code; one row names the model |
| Modification notices | Required where the file is modified; the app ships the file unmodified | Apache §4(b), only if the app re-quantizes the file itself |
| The Notice file sentence | Required, verbatim, in `NOTICE` | Apache §4(c) and (d): retain attribution notices; the repository is reported to carry no NOTICE file |
| Policy re-read at every release | Required, since the policy is incorporated by live URL | None |
| Termination with a delete-and-cease duty; the remote-restriction reservation (§3.2, §4.5) | In force; the download design lets the app stop serving the release asset and purge | None |
| Trademark | Describe, never brand | The same: Apache §6 grants no trademark rights |

**What "bundling without gates" would mean.** The vectors, shards and map are Outputs and
already ship gate-free under either licence. Only the encoder weights carry obligations.
- Under the Terms, weights inside the binary are still Distribution. Without a download
  moment, the custom EULA becomes the only enforceable provision for App Store copies, so it
  stops being optional, and the Mac DMG would need a first-launch agreement or a licence sheet.
  The gate can move from download time to install time; it cannot vanish. Bundled weights also
  cannot be recalled under §4.5. And 229 MB in the bundle crosses the iOS default that asks
  before a cellular download over 200 MB.
- Under Apache 2.0 the model can ship inside the binary, or download on first use with no
  agreement step, and the consent sheet, the EULA clause, the Terms screen, the policy re-reads
  and the termination exposure all go.

**The web edition.** The Terms define Distribution to include "making Gemma or its functionality
available as a hosted service via API, web access, or any other electronic or remote means". A
multi-user instance offering a Meaning search therefore distributes to its readers, and its
operator owes the §3.1 flow-down in its own terms with them; only the Notice-file duty is waived
for a hosted service. FRUS Explorer Light's SPEC (phase 4, unbuilt; phase 1 was signed off on
2026-10-13) keeps the weights out of the image, defaults `FRUS_ENCODER` to off and has the admin
accept the Terms at download, which is the right shape for the operator as a recipient, and has
no reader-facing terms for its local-accounts and trusted-proxy modes. Single-user localhost
mode has no third party. Under Apache 2.0 the weights can be baked into the image, the encoder
can default on, and neither the admin consent screen nor reader-facing terms are needed. Per
`CLAUDE.md`'s four rules this is recorded here for the owner and changes nothing in that
repository.

## 2. What the spike measures, in two stages

The runbook's sentence turns on two things, quality and a working encoder, and the ride-along
left a third unmeasured by choice on 2026-08-10: whether the M5 MacBook Air's neural
accelerators engage for an encoder. Stage 1 answers the second and third in an afternoon;
stage 2 answers the first and is the re-embed itself, so if it passes, the move's largest cost is
already paid.

**Stage 1: the runtime, the file, and the Air's throughput (hours).**
1. Build llama.cpp at a commit at or past the `gemma-embedding2` support (its PR 30054,
   2026-10-06). The vendored runtime (`Scripts/build-llama-xcframework.sh`, commit `8663224`,
   last rebuilt 2026-10-05) predates it, so a move needs a rebuild and a new dSYM release on
   `frus-semantic-vectors`; the spike needs only a local `llama-server`.
2. Load the text-only GGUF from `ggml-org/embeddinggemma-2-GGUF` without an `mmproj` file. The
   repository is reported to publish BF16 and Q8_0; community listings put a Q8_0 text file near
   290 MB, a Q4_K_M near 174 MB and BF16 near 533 MB. No QAT Q4_0 was found, and the spike's
   no-Q4 rule (`V0-Spike-Verdict.md` §3) points at the Q8_0. Record the file's size and SHA-256,
   the load time, the resident memory and the per-query latency, against the 300m's figures in
   `V5-Step4-Spike-2026-08-28.md`.
3. On the Air, confirm the Metal tensor path is active: the startup log's `has tensor = true`
   line. Upstream llama.cpp enables it on M5-class GPUs (PR 27461); LM Studio's runtime 2.21 is
   reported to fail the self-test on M5 Macs and fall back, losing 2 to 3× on prompt processing
   (its issue #2040, open on 2026-10-14). Any build new enough for step 1 carries the tensor path.
4. Run the three-volume spike through the existing harvester against `llama-server --embeddings`,
   which serves the `/v1/embeddings` and `/v1/models` endpoints the script needs:
   `SPIKE=1 MODEL=<id> MODEL_FILE=<gguf> PREFIX="title: none | text: " OUT_DIR=~/frus-semantic-raw-spike-embeddinggemma-2 python3 tools/semantic-harvest/harvest_embeddings.py`.
   Verify the document prompt against the card first, as the runbook says; #1659 read the card
   as using the prompts the app already uses. The closing `tokens/s` line is the Air's
   throughput, and §4 is re-derived from it. Then run `spike_gates.py` over the new store beside
   the 300m's spike store: the weak-positive gate (MRR@10 per era over cross-reference
   neighbours) and the quantization ladder at 512, the instruments V-0 chose the 300m with.
   If stage 1 shows a weaker gate than the 300m's, or no working encoder, stage 2 does not run.

**Stage 2: the full re-embed and the corpus gates (one night to a night and a day, §4).**
5. The full harvest on the Air into a fresh `OUT_DIR`, with `caffeinate`, under the contract
   guard: the same chunking (3,200 and 480), the same prompt, the new model and SHA-256.
6. Pack with `SemanticVectorsGenerator` into a scratch folder under a new provenance digest,
   never over the shipped artifacts, and run the corpus gates (`tools/semantic-harvest/corpus-gates/`,
   Gate A over 70,469 queries, the rerank-pool sweep) and the 25 judged queries of
   `eval-2026-08-27/` against the 300m's results at the same width. Re-run the dimension ladder
   (`Dimension-Ladder-Spike.md`'s method) at 256 and 512: the card claims near-lossless
   quality to 256, and a narrower width would shrink the bundled tier and every shard.
7. Load the Q8_0 GGUF under the rebuilt runtime on an iPhone and the Mac, through
   `SemanticQueryEncoder`, and run `QueryEncoderParityTests`' procedure with a fixture made by
   `make_query_parity_fixture.py` from the new model: the wrapper's output against
   `llama-embedding`'s for the 25 queries.

**Reading the result.** As V-0 read its gates: the model that leads ships. A tie goes to
Apache 2.0, since every obligation in the runbook's §1 and §6 ends with it. A loss on the gates
leaves the 300m under the Terms, the custom EULA owed before the first App Store submission,
and the runbook's §0 check at every release.

## 3. What a move would then touch

#1659's list stands: a new provenance digest and the family rule, so the move ships as an app
update carrying the new bundled tier, 553 shards, map and layout, and older builds keep the old
shards; the web edition's pinned manifest moves with it; the rebuilt `llama.xcframework` with its
dSYM release; the measurements re-taken, all in the 300m's space today (the corpus gates, the
512 width, `RERANK_POOL` at 800, the 25 judged queries); and the copy and screens, which under
Apache 2.0 shrink rather than change: the consent sheet and the Terms screen retire, the About
section becomes an open-source row, `NOTICE` in both repositories carries an Apache attribution,
`App-Store-Custom-EULA.md` and the runbook move to `Completed/`, and both manuals and the
EditableContent blocks follow. The artifact repository's "Model weights" section is rewritten
before the new GGUF is uploaded, the order the runbook's §2 set. FRUS Explorer Light's
licensing section and encoder default are that repository's to change.

## 4. The re-embed on the M5 MacBook Air: a ballpark

One overnight if the neural accelerators engage, a night and a working day if they do not.
Roughly 6 to 9 hours in the first case and 10 to 18 in the second. The deciding factor is
software, not silicon, and stage 1's step 3 settles it before the night is spent.

| Step | Figure | Basis |
|---|---|---|
| The Studio run, EmbeddingGemma 300m | 5.96 h for 605,643 chunks, about 353.7 M tokens embedded, on the M1 Max Studio through LM Studio | `Phase3-Store-Assessment.md`, measured 2026-08 |
| Model cost, EmbeddingGemma 2 | ×1.1 to ×1.3 | a 130 M transformer against about 100 M; small encoders are partly overhead-bound, so less than linear (`tools/semantic-harvest/README.md`, field notes) |
| Q8_0 in place of Q4_0 QAT | ×1.0 | prefill is compute-bound; the Studio runs measured Q8_0 no slower than a Q4 K-quant |
| The Air with the tensor path active | ×0.7 to ×0.9, then ×1.15 to ×1.3 for fanless throttling | an M5 Pro posts about 1,310 tok/s prompt processing against about 530 to 600 for a 32-core M1 Max in llama.cpp's own table; a 10-core base M5 scales to roughly the Studio's rate |
| The Air on plain GPU shaders | ×1.5 to ×2.5 | the ride-along's band (`M2-Semantic-Pipeline-Ride-Along.md` §4.0); consistent with the one M5 Air figure the plan records, a 14 B model prefilled at 75 tok/s through LM Studio |

So the Studio would take about 6.5 to 7.7 hours for the new model, and the Air lands at 5.5 to 9
hours with the accelerators or 10 to 18 without. Two things the ballpark does not cover: the
throttling factor is a guess, since the Studio sustains indefinitely and the Air does not; and the
token count assumes the new model's tokenizer counts about as the 300m's did on this text, likely
for the same 262,144-entry vocabulary and unmeasured. The harvester prints a live ETA that
corrected the spike's extrapolation to within 2.3 percent on the real run, and it settles inside
the first hour.

## 5. Not verified

- The model card's licence section, the Prohibited Use Policy sentence it is reported to keep,
  and the absence of a LICENSE file: all from secondary coverage.
- The text backbone's hidden size: the 140 M embedder fits a 262,144 × 512 table, which is an
  inference from the parameter split, not a reading of the card.
- Quality on this corpus, in any sense; the public MTEB figures (English v2 68.46 at 768
  against 69.67 reported for the 300m, code 78.68 against 68.76) are the card's claims.
- That the Q8_0 text GGUF loads under a current llama.cpp: reported in a llama.cpp fork's issue
  thread, not run here.
- The GGUF sizes: community listings, not the `ggml-org` repository's own figures.

## Sources read on 2026-10-14

- Google, "EmbeddingGemma 2 is a best-in-class open model for natively multimodal embeddings", blog.google, 2026-10-06.
- Google, "EmbeddingGemma 2: The Developer Guide", developers.googleblog.com.
- Google, "Gemma 4: Expanding the Gemmaverse with Apache 2.0", opensource.googleblog.com, 2026-03.
- Google's Gemma 4 licence page, ai.google.dev/gemma/apache_2 (the Apache 2.0 text).
- mixed-news.com, "Google's EmbeddingGemma 2 drops the Gemma licence gate", and s5labs.io, "EmbeddingGemma 2: Open Multimodal Embeddings" (the card's policy sentence and the missing LICENSE file).
- huggingface.co/ggml-org/embeddinggemma-2-GGUF; github.com/AmpereComputingAI/llama.cpp/issues/22 (the architecture's support, PR 30054).
- github.com/ggml-org/llama.cpp/discussions/4167 (Apple Silicon prompt-processing table); github.com/lmstudio-ai/lmstudio-bug-tracker/issues/2040 (the tensor-API self-test on M5 Macs).

---

Version history:
  1.0 — 2026-10-14: the spike's design, the licence reading for both editions, and the Air ballpark, written when the owner queued the spike.
  1.1 — 2026-10-14: the status line points at the stage-1 memo; the text below it is left as the design was written.
