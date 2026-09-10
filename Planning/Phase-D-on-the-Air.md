# Phase D on the Air — the semantic pack for FRUS 1981–1988 vol. XVI

Written 2026-09-09 for a run on the MacBook Air rather than the Studio. Every precondition below
was **checked on this machine**, not assumed. The store copied over from the Studio is at
`~/frus-semantic-raw` (2.2 GB: 552 volumes of vectors, 552 of text).

## Preconditions — all verified

| | |
|---|---|
| GGUF SHA-256 | `5a9e0645…de09020` on the Air — **identical** to what the Studio harvest recorded. This is the one that decides whether the whole corpus keeps its provenance digest. |
| Model id | `text-embedding-embeddinggemma-300m-qat`, loaded and listed by LM Studio at `localhost:1234` |
| Python | 3.9.6 — the version the layout stage's pins require (scikit-learn 1.7 and numpy 2.1 both need 3.10+) |
| Disk | 767 GB free |
| Corpus | `/Users/jbotts/Development/frus/volumes`, at OH's `e744e71db` |
| Manifest | already regenerated to 553 volumes on this branch — §4.5's ordering trap needs this **before** pooling, and it is done |
| venv | **not present — step 5 creates it** |

**One difference from the Studio, and it is expected.** `harvest_embeddings.py` has changed since
the August harvest: PR #1177 added the contract guard. Its SHA-256 is now `41a6656d…` where the
store's `run-manifest.json` records `fca03282…`. That value is **not** an input to the provenance
digest — the digest is built from model, GGUF SHA, dims, chunking, prefix, pooling and quantization
(`SemanticVectorsRunner.swift:141`) — and it reaches the index as a separate `harvestScriptSHA256`
field. So expect it to change in step 3's diff. §4.2's allowed-difference list predates that PR.

---

## The commands, in order

### 1. Back up the contract you are about to rewrite

```bash
cp ~/frus-semantic-raw/run-manifest.json /tmp/run-manifest.before.json
```

### 2. Harvest the one new volume

`harvest_embeddings.py` skips any volume that already has a `head.json`, so naming the volume is
belt-and-braces — it makes the run about a minute instead of a scan of 553.

```bash
cd /Users/jbotts/Development/FRUS-Explorer/tools/semantic-harvest && \
VOLUMES="frus1981-88v16" \
VOLUMES_DIR="/Users/jbotts/Development/frus/volumes" \
MANIFEST="/Users/jbotts/Development/FRUS-Explorer/FRUSExplorer/Resources/manifest.json" \
OUT_DIR="$HOME/frus-semantic-raw" \
MODEL="text-embedding-embeddinggemma-300m-qat" \
MODEL_FILE="/Users/jbotts/.lmstudio/models/frus-eval/embeddinggemma-300m-qat/embeddinggemma-300m-qat-Q4_0.gguf" \
PREFIX="title: none | text: " \
caffeinate -i python3 harvest_embeddings.py 2>&1 | tee /tmp/harvest-v16.log
```

**`PREFIX` carries a trailing space and it is load-bearing.** Since PR #1177 the harvester compares
`MODEL`, the GGUF SHA, `PREFIX`, `CHUNK_CHARS` and `OVERLAP_CHARS` against the store's own manifest
and exits non-zero naming the field, so a mistake here now stops the run instead of silently
re-contracting the corpus. Do not reach for `ALLOW_CONTRACT_CHANGE=1`; nothing about this run is a
new family.

### 3. Diff the contract — stop here if anything else moved

```bash
diff <(python3 -m json.tool /tmp/run-manifest.before.json) \
     <(python3 -m json.tool ~/frus-semantic-raw/run-manifest.json)
```

Only these may differ: `generated`, `machine` (Studio → Air), `models_listing`,
`volumes_requested`, `totals_this_run`, and `script_sha256` (see the note above). **`model`,
`model_file_sha256`, `dim`, `chunk_chars`, `overlap_chars` and `prefix` must all be unchanged.**
If any of those six moved, stop and do not pack.

### 4. Confirm the store is whole

`vectors/` is FLAT — three files per volume (`.bin`, `.head.json`, `.meta.jsonl`), not a directory
each — so the count there is 3 × volumes.

```bash
echo "vectors: $(ls ~/frus-semantic-raw/vectors | wc -l)  (expect 1659 = 553 x 3)"
echo "text   : $(ls ~/frus-semantic-raw/text | wc -l)  (expect 553)"
python3 -m json.tool ~/frus-semantic-raw/vectors/frus1981-88v16.head.json
```

The new head should carry `prefix`, `chunk_chars` and `overlap_chars` as well as `model` and `dim`.
The 552 Studio-era heads carry only the latter two — recording the contract per volume is what PR
#1177 added, so this is the first head in the store the packer can check individually.

### 5. Build the layout venv (once on this machine)

```bash
cd /Users/jbotts/Development/FRUS-Explorer && \
python3 -m venv .cache/semantic-map-venv && \
.cache/semantic-map-venv/bin/python -m pip install --upgrade pip && \
.cache/semantic-map-venv/bin/python -m pip install -r tools/semantic-map/requirements.txt
```

Pinned to numpy 2.0.2 / scikit-learn 1.5.2 / umap-learn 0.5.6 by the system Python being 3.9. The
standalone `hdbscan` package is deliberately absent — scikit-learn ships `sklearn.cluster.HDBSCAN`.

### 6. Pool the document matrix

```bash
cd /Users/jbotts/Development/FRUS-Explorer && \
STORE="$HOME/frus-semantic-raw" \
.cache/semantic-map-venv/bin/python tools/semantic-harvest/corpus-gates/pool_docs.py
```

Writes `~/frus-semantic-gates/pool/doc_f32_768.npy`. Its SHA-256 is recorded in the layout's
provenance, so it is the thing that proves the layout was built over this corpus and not the last.

### 7. Rebuild the layout — **defaults, no `DIMS`**

```bash
cd /Users/jbotts/Development/FRUS-Explorer && \
.cache/semantic-map-venv/bin/python tools/semantic-map/build_layout.py
```

~15 minutes. **Do not pass `DIMS=512` here.** The shipped map records `projectedFromDims: 256`
(`Planning/semantic-map/layout-meta.json`), and 512 is the *vector pack's* width, not the layout's.
`SEED`, `MIN_CLUSTER` and the rest are pinned by their defaults; the shipped run used seed
18610810, minClusterSize 250, minSamples 10, PCA 50.

The map **must** be rebuilt. A stale `semantic-map.bin` is refused cleanly by
`SemanticMapReader.init` — no wrong coordinates, but Clusters and the Map disable themselves for
everyone.

**Expect a wall of numpy warnings from PCA on this machine, and ignore them.** The Air's run printed
`divide by zero`, `overflow` and `invalid value encountered in matmul` from
`sklearn/decomposition/_pca.py:611` and `_base.py:149,156` — spurious FP-status flags raised by
numpy 2.0.2 over Apple's Accelerate BLAS, not a corrupted computation. The evidence they are
harmless is not that they look familiar: `explainedVariancePercent` came out **58.36**, identical to
the Studio's run to two decimal places over a *different* input matrix, and the emitted `layout.bin`
is well-formed — 314,571 records, coordinates spanning the full ±30,000 grid, 171 contiguous cluster
ids plus `0xFFFF`, 55,356 distinct x values. A corrupted `X.T @ X` reproduces none of that.

**What the Air's rebuild actually moved**, against the shipped layout: documents 314,483 → 314,571,
clusters **179 → 171**, unclustered 88,207 → 89,449 (28.0% → 28.4%), and the source-matrix SHA. Every
parameter that should be identical is: `projectedFromDims` 256, seed 18610810, PCA 50 components at
58.36%, minClusterSize 250, minSamples 10, UMAP 15/0.1/cosine, and numpy 2.0.2 / scikit-learn 1.5.2 /
umap-learn 0.5.6 — the venv resolved to the Studio's exact pins. `firstKey` is still
`frus1861`/`d1`, so row order held.

### 8. Pack — `DIMS=512`, and pin the digest

```bash
cd /Users/jbotts/Development/FRUS-Explorer && \
STORE="$HOME/frus-semantic-raw" \
DIMS=512 \
LAYOUT_DIR=Planning/semantic-map \
EXPECT_DIGEST=a726ca606bdf4d1984ba7cfda4d5605c2e9dc1a8320654a1b5742e06aa6e3a64 \
GENERATED_DATE=2026-09-09 \
swift run -c release SemanticVectorsGenerator
```

Two guards in one line. `DIMS=512` because the generator's own default is still 256 and packing at
half width takes every consumer to `.provenanceMismatch`; `EXPECT_DIGEST` because the runner then
refuses to write **anything** under a different provenance, which is the 162 MB-re-download
failure the whole of §4.2 is about.

### 9. Verify the pack before trusting it

```bash
cd /Users/jbotts/Development/FRUS-Explorer && python3 -c "
import json
d = json.load(open('FRUSExplorer/Resources/semantic-vectors-index.json'))
print('digest      :', d['provenanceDigest'])
print('  unchanged?:', d['provenanceDigest'] == 'a726ca606bdf4d1984ba7cfda4d5605c2e9dc1a8320654a1b5742e06aa6e3a64')
print('shippingDims:', d['provenance']['shippingDims'], '(want 512)')
print('documents   :', d['documentCount'], '(was 314483; v16 adds 88 → 314571)')
print('volumes     :', len(d['volumes']), '(want 553)')
m = json.load(open('FRUSExplorer/Resources/semantic-map-index.json'))
print('map clusters:', len(m.get('clusters', [])))
"
ls Planning/semantic-vectors/shards/frus1981-88v16.vec
```

### 10. Read the new cluster labels properly

`random_state` is pinned, so a rebuild over identical input reproduces itself — but this input has
one more volume, so **cluster count, membership, ids and labels can all move, and every document on
the map moves.** The label pass has a known failure mode that survived review by eye: the first
artifact's 179 labels were pronounced historically coherent and **168 were wrong**, caught by a unit
fixture rather than by reading. Budget a real check, not a glance.

### 11. Push the shard — before the build reaches anyone

The app fetches shards from `joshbotts/frus-semantic-vectors`, `main`, `shards/`. Push
`Planning/semantic-vectors/shards/frus1981-88v16.vec` there **before** the TestFlight build ships,
or every device that downloads the volume gets a 404. The other 552 shards are byte-identical on a
repack, so their recorded SHA-256s do not move and nobody re-downloads anything.

### 12. Then the suites

```bash
cd /Users/jbotts/Development/FRUS-Explorer && swift test 2>&1 | tail -5
```

`SemanticVectorsArtifactTests` "Volumes are in manifest order and cover the manifest exactly" is
**failing on this branch by design** — the index covers 552 volumes against a manifest of 553. Step
8 is what closes it, and a green `swift test` is the signal that Phase D is done.
