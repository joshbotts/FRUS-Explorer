# EmbeddingGemma 2, B4 part 2: the move

**Date:** 2026-10-15 · **Status:** B4'S SECOND PULL REQUEST (plan of record §1 and §3, B4; decisions
15 to 19). EmbeddingGemma 2 ships in build 51: its artifacts, its download, the recalibrated
percentage and the Apache licence copy. The public uploads were made on the owner's yes the same day
and read back from their public addresses (§7). ·
**Issue:** #1659 · **Inherits:** the stage-2 memo's §11 and the runtime memo
(`EmbeddingGemma-2-B4-Runtime-2026-10-15.md`, #1673) · **Machine:** the M5 MacBook Air (`Mac17,4`,
32 GB), macOS 27.0.1, Xcode 27.0 · **Artifacts and the scripts that made them:**
`eg2-b4-move-2026-10-15/`.

Every figure was measured on 2026-10-15 on the Air. Engineering-side, not legal advice.

## 0. In short

- **The owner decided B4's two questions first** (§1): the encoder reaches a device as an opt-in
  download with no agreement step (decision 18), and the Meaning chip's percentage is recalibrated
  (decision 19).
- **The artifacts are packed and reproduce.** The bundled tier, the 553 shards, their manifest and
  the map, from the verified store under digest `89481b18…` with `EXPECT_DIGEST` held: byte-identical
  to B2's scratch pack where B2 packed them, a second pack byte for byte, and a control repack of the
  300m's store byte for byte against the files builds 42 to 50 ship (§2).
- **The index states EmbeddingGemma 2's own recall, 0.902**, through the funnel the app runs, and
  carries the model's score calibration. The generator's recall table is keyed by model as well as
  width, and refuses a model the gates never measured (§3).
- **The model downloads from release `encoder-2`, the shards from `generations/89481b18/`**, so
  builds 42 to 50 keep fetching the 300m and its shards from where they were compiled to look (§4).
- **A defect the move would have shipped:** the model store's pin-change purge removed the file by
  the current release's name, so a reader's downloaded 300m (another name) would have stayed on disk,
  229 MB that no storage row counts and no button removes. The purge now takes any other `.gguf` in
  the model's folder (§4).
- **Every semantic percentage is calibrated where its score is made**: the Meaning searcher (query
  offset 0.47) and Related Documents' semantic axis, its re-score floor and its off-index leads
  (document offset 0.40). The UI-test Meaning seam's figures move with the bits and the calibration:
  100, 32 and 3 percent where they were 100, 65 and 61 (§5).
- **The Gemma licence surfaces retire** and EmbeddingGemma 2 is an Open Source row; the copy, both
  manuals, the EditableContent blocks, `NOTICE`, the README and the agentic guide follow (§6).
- **The uploads are public and read back** (§7): the GGUF on release `encoder-2` and the 553 shards
  under `generations/89481b18/`, byte for byte from their addresses and through the app.

## 1. The owner's two decisions

Both were measured on 2026-10-15 on the Air, proposed, and answered by the owner before the parts
they shape were built. **Decided 2026-10-15: the opt-in download, and recalibration** (plan of
record decisions 18 and 19).

### 1a. How the encoder reaches a device

Under Apache 2.0 neither way needs an agreement: the consent sheet, the Terms screen and the
flow-down retire either way (the spike design's §1).

| | EmbeddingGemma 300m (builds 42–50) | EmbeddingGemma 2 |
|---|---|---|
| the file | 229,093,184 B | 309,855,456 B (+80,762,272) |
| deflate -9 | 218,780,346 B (95.5%) | 282,739,162 B (91.2%) |

Build 50's archives (2026-10-13): the iOS app is 86.2 MB installed and 43.1 MB as a deflate-9 zip,
of which the executable is 23.9 MB raw and 10.0 MB compressed. The App Store encrypts the
executable, which then does not compress, so its download is about 57 MB (an estimate: App Store
Connect has the figure). The Mac app is 120.3 MB. Build 51 adds about 4 MB either way (the rebuilt
`llama.framework`).

- **Inside the binary:** about 400 MB installed and 340 MB to download on iOS, past the default that
  asks before a cellular App Store download over 200 MB, on every fresh install; an update that
  leaves the file alone should not resend it. Every reader carries it, Meaning search or not. The
  Mac app and its DMG grow by the same 310 MB. The repository cannot hold the file (GitHub's 100 MB
  limit, the dSYMs' reason), so the build would fetch it the way the archive fetches the dSYMs: a
  fetch script, a verified cache, a copy phase on both app targets, and the file hosted publicly
  anyway. The download code, its verification and its storage rows would go, and Meaning search
  would work at first launch.
- **An opt-in download, no agreement step:** the app stays about 61 MB to download. The button
  downloads at once (no sheet), with the size and "runs on this device" where they are now. The
  fetcher, its length-then-SHA-256 check, its progress, the app's cellular switch and the Remove
  row are built and tested, and change in four constants (URL, file name, length, and the pin,
  which is the bundled index's). 310 MB is about 50 seconds at 50 Mb/s. A reader who downloaded the
  300m finds it purged at the first launch of build 51 (the pin moves) and the offer back, once.

The encoder's memory and time do not depend on the delivery: on the owner's iPhone 17 Pro it loads
in 630 ms and adds about 170 MB while a Meaning search runs (the runtime memo's §5).

**Proposed, and decided: the opt-in download.** Most readers keep a small app, nothing is added to
the build, and the path is the one already measured. The GGUF goes to a new release, `encoder-2`,
so `encoder-1` stays what builds 42 to 50 fetch, after the artifact repository's Model weights
section is rewritten (§7).

### 1b. Whether the Meaning chip's percentage is recalibrated

The chip showed the raw cosine (`SemanticScoreCopy.percent`), and so did Related Documents'
semantic chip, whose cosine also enters Related's weighted sum (the axis is self-normalising,
#643). EmbeddingGemma 2's cosines sit higher everywhere: an on-topic question's mean cosine over
the whole corpus is 0.62 against the 300m's 0.28 to 0.31, and two documents' 0.71 against 0.49.

Measured over 90 typed queries through both models at `a0e6dc7` (the owner's 25, of which "Space
aliens" is the null control; 45 on-topic questions and 20 off-topic ones written for this
measurement, `eg2-b4-move-2026-10-15/`), each scored against all 314,616 documents' int8-512 rows as
the app scores them, and 600 seeded anchor documents against all others for Related:

| median score | 300m, as shown | EmbeddingGemma 2, raw | EmbeddingGemma 2, recalibrated |
|---|---|---|---|
| owner's queries, best match | 61% | 80% | 62% |
| owner's queries, tenth | 57% | 77% | 57% |
| on-topic queries, best match | 65% | 81% | 65% |
| off-topic queries, best match | 32% | 64% | 32% |
| "Space aliens", best match | 60% | 74% | 52% |
| Related, closest neighbour | 87% | 92% | 86% |
| Related, tenth neighbour | 79% | 88% | 79% |

Raw, an off-topic question's best match reads 64%, the 300m's figure for an on-topic one: the
off-topic best matches span 58–70% and the on-topic ones 72–86%. EmbeddingGemma 2 separates the two
better than the 300m did (on-topic against off-topic best match, AUC 0.997 against 0.988); its raw
numbers hide it in a band twenty points wide.

**Proposed, and decided: recalibrate.** One rule, `shown = (cosine − c) / (1 − c)`, clamped to
0–100%, with `c` measured for the model: 0.47 for a question against a document (the Meaning chip,
the fallback card, the rows of undownloaded volumes, VoiceOver's value) and 0.40 for a document
against a document (Related's chip and its share of Related's sum). The offsets are the
least-squares fits of that rule to the 300m's scores over the same rows (0.462 to 0.477 for typed
queries, 0.398 for Related; `calibration-summary.txt`), rounded. The fitted figures are the table's
last column, within two points of the 300m's on every row but "Space aliens". 100% still means
identical. The constants are pinned to the model's SHA-256, so a later model shows its raw cosine
until it is measured. Related's sum keeps the balance the owner set on 2026-09-10 (the semantic axis
at 0.5), which was tuned on the 300m's scale. The alternatives were to keep the raw cosine (no code
change; every figure about twenty points higher on a typed query and five to nine on Related), or to
drop the number for the rank alone (every surface, both manuals and the EditableContent blocks).

## 2. The pack

**The layout first.** `tools/semantic-map/build_layout.py` over EmbeddingGemma 2's pool
(`~/frus-b2/gates-eg2/pool`, B2's `pool_docs.py` output, in artifact row order): PCA 56.85% of the
variance (the 300m's 58.36%), **140 clusters** (172), 88,059 unclustered (28.0%; 29.3%); UMAP 116 s
and HDBSCAN 111 s, 232 s in all at 5.6 GB peak RSS. A second run wrote the same `layout.bin`, SHA-256
`46799d5a…`, byte for byte. numpy prints divide-by-zero, overflow and invalid-value warnings from
PCA's matmul on this Mac, which are Accelerate's spurious floating-point flags; the reproduction,
the variance and the cluster count are the check.

**Then the generator**, with the model-keyed tables of §3:

```bash
STORE=~/frus-semantic-raw-embeddinggemma-2 EXPECT_DIGEST=89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101 GENERATED_DATE=2026-10-15 .build/release/SemanticVectorsGenerator
```

314,616 documents in 1,603 id segments; the index 73,297 bytes, the binary 20,476,048, the 553 shards
162,377,248, the map 1,887,760 (140 clusters, 88,059 unclustered). The run took 188 s at a peak RSS
of 3.5 GB and a peak footprint of 5.6 GB; the map's labelling is most of both (B2's pack without the
map: 3.6 s, 1.0 GB).

| check | result |
|---|---|
| against B2's scratch pack (`~/frus-b2/pack/eg2-512/`) | the binary, the shard manifest and all 553 shards byte-identical; the index differs only in `retrieval` (§3) |
| a second pack into scratch, the same inputs | all five bundled artifacts and all 553 shards byte for byte |
| a control repack of the 300m's store (`EXPECT_DIGEST=a726ca60…`, `GENERATED_DATE=2026-10-10`, no layout) | its index, binary and shard manifest byte for byte against `HEAD`'s, the files builds 42 to 50 ship |
| the shards against the manifest | 553 of 553 by length and SHA-256; every header carries `89481b18…` |

The cluster labels are the generator's, not curated (c-TF-IDF through the app's tokenizer), and the
second pack reproduced them byte for byte.

## 3. What the index states

**The recall.** `SemanticVectorsRunner.measuredRecallAt10` was keyed by width alone, so B2's pack of
EmbeddingGemma 2 stated the 300m's 0.851 and cited the 300m's measurement (the stage-2 memo's §3).
It is now `funnelMeasurements`, keyed by the model's GGUF SHA-256 and then the width, each entry a
recall and its citation:

| model | 256 | 512 |
|---|---|---|
| EmbeddingGemma 2 | 0.7845 | **0.9021**, Hamming-800 over 512 sign bits → int8-512, the stage-2 memo's §5 |
| EmbeddingGemma 300m | 0.7449 | 0.8510, August's, word for word |

`resolveShippingDims` refuses a width the store's model was not measured at, so a model with no
entry is refused at every width, the default included. The 300m's entries keep August's text so its
control repack stays byte-identical (§2), though its 0.851 describes a 256-bit scan.

**The score calibration.** `SemanticVectorsArtifacts.Index.Retrieval` gains `scoreCalibration`,
optional and outside the digest as `Provenance.queryPrefix` is: it says how to read the vectors,
not how they were made. The generator writes it from `SemanticVectorsRunner.scoreCalibrations`,
keyed by model, which holds EmbeddingGemma 2's offsets and nothing for the 300m, whose artifact
never had the field and decodes unchanged. `calibratedQueryScore(_:)` and
`calibratedDocumentScore(_:)` apply it, and return the cosine itself for a generation with none.
**They do not clamp**: the rule is affine, so a list sorted by the calibrated score is sorted exactly
as by the cosine, with no ties at 0%; every display clamps, as each clamped the raw cosine. The kit
is shared code, and `swift build --target SemanticVectorsKit` and its suites are part of §8.

## 4. The download and the addresses

**The model.** `SemanticModelFetcher.defaultModelURL` is
`…/frus-semantic-vectors/releases/download/encoder-2/embeddinggemma-2-Q8_0.gguf`, and
`SemanticModelStore` pins `embeddinggemma-2-Q8_0.gguf`, 309,855,456 bytes; the SHA-256 is the
bundled index's `modelFileSHA256`, as before. One release a model: `encoder-1` keeps the 300m, which
builds 42 to 50 fetch by their own pin, and the dSYMs.

**The shards.** `SemanticShardFetcher.defaultBaseURL` is
`…/frus-semantic-vectors/main/generations/89481b18/shards`. Through build 50 it was `…/main/shards`,
an address with no version in it; a build verifies each download against the manifest it shipped
with, so publishing EmbeddingGemma 2's shards there would have left every older build refusing every
fetch. Each generation now has its own folder, named by its digest's first eight hex digits, and
`SemanticShardFetcherTests` fails when the bundled digest moves and the address does not.

**The purge.** At launch `purgeIfPinChanged()` discards a stored model whose marker records another
pin. It found the file by `SemanticModelStore.fileName`, which is the upstream release's own name
and so moved with the model: on a device holding `embeddinggemma-300m-qat-Q4_0.gguf` and its marker,
it would have deleted the marker, found no file under the new name, and left 229 MB behind,
uncounted (the storage rows read the new name) and unremovable (Remove Search Model removes the new
name). The purge now also discards every other `.gguf` in the model's folder, which is the model's
own (`makeSemanticModelDirectory`); three tests in `SemanticModelStoreTests` hold it, the test
fixtures write their incoming file outside the folder, where a download lands, and the Mac's check
copy showed it at its first launch (§8).

**The download step.** The Settings row and the search offer card download at once; the consent
sheet is gone (§6). The fetcher's verification, progress and cellular switch are unchanged. A reader
who had the 300m sees the offer again, once, at 310 MB.

## 5. The calibrated score in the app

Applied once, where each score is made, so every surface that shows it, sorts by it or sums it reads
the same number:

- **Meaning** (`SemanticQuerySearcher`): a hit's `score` is the int8 cosine through
  `calibratedQueryScore`, in the corpus-wide search and the search inside a set. The Meaning rows,
  the fallback card, the rows of undownloaded volumes and VoiceOver's value all show it through
  `SemanticScoreCopy`, which clamps and rounds as before.
- **Related Documents** (`SemanticSimilarityGenerator`): the vended strengths and their chips, the
  re-score (a candidate's cosine is calibrated before it is compared with the floor, which is the
  weakest vended strength, so both are on one scale), and the off-index document leads, through
  `calibratedDocumentScore`. The ranker clamps the axis as before (#643).
- **The feedback log** records the score the row showed, under its old key `cosine` so earlier
  verdicts decode; `provenanceDigest` says which generation, and so which scale.
- **The method appendix** records a Meaning search as `route=semantic; model=embeddinggemma-2-Q8_0;
  top=100`: `SemanticSearchBackend.renderedExpression` reads the bundled provenance's model, where
  both view models spelled the 300m's id.

**The UI-test Meaning seam** (#1577 lane 3) answers a question with a document's bundled sign bits
and plants a match file of ±1 rows, whose cosine is `1 − 2h/512`. Its figures move with
EmbeddingGemma 2's bits and with the calibration (`seam-figures.txt`, whose control over the 300m's
pool reproduces the figures the seam quoted through build 50):

| | through build 50 | build 51 |
|---|---|---|
| near question (d2): its three rows | d2 100%, d1 65% (90 bits), d3 61% (100) | d2 100%, d1 32% (92 bits), d3 3% (131) |
| d1 and d3 among the 800 candidates | 2nd and 3rd | 2nd and 50th |
| near: hits, unscored | 78; 722 in 179 volumes | 80; 720 in 248 volumes |
| far question (`frus1861` d1): unscored | 800 in 134 volumes | 800 in 124 volumes |
| far, inside a set of the fixture | d2 24%, d3 24%, d1 16% | d3, d2, d1 (186, 187, 201 bits), each 0% |

Sign vectors sit lower than a model's vectors for the same closeness (two unrelated rows near 0,
where the model's sit near 0.6), so the seam's far rows, about 0.27, fall below the 0.47 offset and
read 0%; their order is still the cosine's. `UITestMeaningSeederTests`, `MeaningResultsSeamTests`,
the seeder's header and both runbooks carry the new figures.

## 6. The licence copy

Under Apache 2.0 the screens shrink, as the spike design's §1 set out:

- **Retired:** the consent sheet (`SemanticModelConsentSheet`) in Settings and on the search offer
  card; About's On-Device Model section with its two Gemma links and the bundled Terms
  (`GemmaTermsView`, `gemma-terms-of-use.txt`, removed from both app targets with `xcodegen` and the
  scheme restore). Their EditableContent blocks (§1.4b, §1.4c, the terms' missing-copy line) carry
  RETIRED banners with their wording kept.
- **New:** an Open Source row in About ▸ Legal, "EmbeddingGemma 2", linking the model card on Hugging
  Face and stating the licence, as llama.cpp's row does (§1.4e).
- **Changed:** the Settings row and footer and the offer card state 310 MB and drop the Gemma Terms;
  the offer button reads "Download Search Model" without the ellipsis a sheet implied. `NOTICE`
  attributes EmbeddingGemma 2 under Apache 2.0 in place of the Gemma notice. The README and its
  EditableContent mirror, both manuals and the agentic guide's §A.7 follow. The custom EULA and the
  compliance runbook are in `Planning/Completed/`, with dated notes at their heads.

## 7. The public uploads

**Made on the owner's word of 2026-10-15, after this pull request merged (#1674, `fafcbff5`), and
read back from their public addresses.** Until then a build from `v2` would have found no model to
download and no match files.

- **`joshbotts/frus-semantic-vectors` `main`**: `38793f0..9be645e`, one commit staged on the Air in
  `~/frus-b4/frus-semantic-vectors` (branch `b4-embeddinggemma-2`): the 553 shards under
  `generations/89481b18/shards/`, their manifest beside them, `LICENSES/Apache-2.0.txt`, and the
  README and NOTICE rewritten for both encoder releases (the Gemma notice kept for `encoder-1`,
  word for word). `shards/` and the root manifest, which builds 42 to 50 read, are untouched. The
  first push of the 155 MB pack failed with HTTP 408; the second, with `http.postBuffer` raised to
  1 GB, went through.
- **Release `encoder-2`**, "Query encoder — EmbeddingGemma 2 Q8_0 (pinned)", published at
  19:03:41Z: `embeddinggemma-2-Q8_0.gguf` (309,855,456 bytes) and `LICENSE-Apache-2.0.txt` (8,002),
  with `~/frus-b4/encoder-2-release-notes.md` as its notes. The upload took 11 minutes.

**Read back:**

| check | result |
|---|---|
| the GGUF from `releases/download/encoder-2/…`, the URL `SemanticModelFetcher` pins | HTTP 200, 309,855,456 bytes in 45 s, SHA-256 `2188ac1d…40b09135` |
| the licence asset | the staged file's SHA-256 |
| every shard from `raw.githubusercontent.com/…/main/generations/89481b18/shards/` | 553 of 553 match the bundled manifest by length, SHA-256 and header digest; 162,377,248 bytes in 306 s |
| the 300m from `encoder-1`, which builds 42 to 50 fetch | still served |
| the repository's description | "553 volumes", still true |

**And through the app**, the Mac's check copy built from this pull request: Download Search Model
fetched the model from `encoder-2` in about 55 seconds and verified it ("Downloaded and verified —
309.9 MB"), and after Remove Downloaded Vectors, Download Missing Vectors fetched the 36 downloaded
volumes' match files from the new folder, all 36 matching the manifest, with no problem reported.

## 8. Checked

- **The package**: `swift build --target SemanticVectorsKit`, then `swift test`: exit 0, 38 test
  targets, 2,900 tests, among them the new ones (the calibration rule and its wire format, the
  model-keyed table, a model with no measurement refused, the committed index's recall and
  calibration).
- **The unit target**, iPhone 17 simulator, iOS 27.0: **7,165 tests in 847 suites passed**, with the
  6 known issues of #1606 (the runtime pull request's run: 7,159; the six new tests are the
  purge's three, the two addresses' and the recorded model's). The gated encoder suite skipped
  itself there, as it does without a model.
- **The encoder suite with EmbeddingGemma 2** (`QueryEncoderParityTests`,
  `FRUS_SEMANTIC_MODEL` the Q8_0 GGUF), the same simulator: 4 of 4 passed, the tier-space ones
  against the new tier: parity min cosine 0.999714 ("Diego Garcia base"), the funnel, the memory
  shape, and the store-verified end to end (the model adopted at the new length and pin, a local
  EmbeddingGemma 2 shard, the judged Olney query's hits in `frus1895p1`).
- **`MeaningResultsSeamTests`**, iOS 27.0: **iPad Pro 13-inch (M5), 3 of 3 passed** (one test run
  first, then the suite; 68, 101 and 353 s with the Mac loaded), the rows reading 100, 32 and 3
  percent and, inside the working corpus, Three, Two and One at 0. **iPhone 17: the first two
  passed** (the same percentages), and the third failed twice before its Meaning search, at
  Filters ▸ My Working Corpora ("no My Working Corpora group after 8 swipes"). **It fails the same
  way at `v2` (`28dd78a0`, without this change)** on the same simulator with the same
  `-only-testing`, so it is not this pull request's; it passed on 2026-10-11, and is recorded in
  `UI-Test-Destinations-Runbook.md`'s entry, not filed.
- **The Mac build** (`FRUSExplorerMac`, DirectDistribution, unsigned): succeeded with the known
  `GeneratedSummary` residue only; the app bundles the new index (`89481b18…`,
  `embeddinggemma-2-Q8_0`, 0.9021, query offset 0.47) and no `gemma-terms-of-use.txt`.
- **The Mac app itself**, the isolated check copy built from this branch over its library of 36
  indexed volumes, which held the 300m (downloaded 2026-10-11) and 149 of its match files: **at the
  first launch the 300m's GGUF and marker were gone and the 149 files discarded** under the new
  generation marker, which is §4's purge seen in the app. With EmbeddingGemma 2 and its 553 files
  put in place by hand (nothing is uploaded yet), Settings read "Downloaded and verified — 309.9 MB"
  with the footer's new sentence; a Meaning search for "reparations" listed **16 closest
  matches** (the 300m's 14 on 2026-10-11), led by the Berlin volume's No. 894 at **60%** (the 300m
  showed it at 63%), then Nos. 942 (59%), 915 (56%), 925, 980 and 916 (55%); About ▸ Legal ▸ Full
  Notices listed EmbeddingGemma 2 under Open Source and no On-Device Model section; and after Remove
  Search Model, **Download Search Model started at once, with no sheet**, and failed "The server
  refused the download (HTTP 404)": `encoder-2` did not exist until the upload. Since the upload the
  same button downloads and verifies the model (§7).

## 9. Not verified

- **An iPhone or iPad with the 300m downloaded, upgraded to build 51**: the purge of the earlier
  file (§4) is tested, and seen on the Mac's check copy (§8), not on an iOS device.
- **EmbeddingGemma 2's quality on typed queries**: the 183 judged rows are the owner's optional
  sitting (the stage-2 memo's §6).
- **The calibration on other queries than these 90**: the offsets fit the medians within two points
  here; the off-topic set is 20 queries written for it.

## 10. Files

`eg2-b4-move-2026-10-15/`:
- `session-topical-queries.txt`, `session-null-queries.txt`: the 65 queries written for §1b (the
  owner's 25 are `../owner-eval-queries-2026-08-27.txt`).
- `score_calibration.py` → `calibration.json`: every query's top ten and corpus statistics, and 600
  anchors' top twenty, for both models. It reads `<dir>/d2/q-<set>-<model>.json`, made by
  `tools/semantic-harvest/make_query_parity_fixture.py` with `QUERIES` set to each file and the
  `a0e6dc7` `llama-embedding`, and B2's pools under `~/frus-b2/`.
- `summarize_calibration.py`, `fit_offset.py`, `offset_errors.py` → `calibration-summary.txt`: §1b's
  table, the fits and the AUCs.
- `seam_figures.py` → `seam-figures.txt`: §5's seam table, with the 300m's pool as the control.
- `layout-meta-run1.json`, `layout-meta-run2.json`, `layout-run1.log`, `pack-eg2.log`: §2's runs.

Outside the repository, on the Air: the clone and release files the uploads came from in `~/frus-b4/` (§7), the
store, B2's pools and packs in `~/frus-b2/`, and the GGUFs.

---

Version history:
  0.1 — 2026-10-15: draft; §1 the two decisions, measured, for the owner.
  1.0 — 2026-10-15: the owner's answers; the pack, the index's recall and calibration, the
  addresses and the purge, the calibrated score in the app and the seam, the licence copy, the
  staged uploads, and the checks (§8), the Mac check copy's among them.
  1.1 — 2026-10-15: the uploads made on the owner's yes and read back, from their addresses and
  through the app (§7).
