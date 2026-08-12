# Corpus-scale gates over the full embedding store

The analysis half of the 2026-08-12 Phase-3 store assessment
(`Planning/semantic-spike/Phase3-Store-Assessment.md`; machine copy of every number:
`Planning/semantic-spike/corpus-gates.json`). These re-run the V-0 gates of
`../spike_gates.py` over the FULL 552-volume raw store instead of the 3-volume spike set,
reusing its pinned numeric procedures (pooling rule, `truncate`, `int8_quantize`,
`pack_bits`, tie-breaks, `load_edges` semantics). Like `spike_gates.py` they need numpy
(2.x — `nn_ladder.py` uses `np.bitwise_count`); everything else is stdlib.

Run order (each script checkpoints and resumes; `ASSESS_DIR` defaults to
`~/frus-semantic-gates` and holds every intermediate and output):

1. `pool_docs.py` — streams the raw store (`STORE`, default `~/frus-semantic-raw`) into
   the shared document matrices under `$ASSESS_DIR/pool/`: float-768 pooled vectors,
   int8-256/512 + scales, packed 256-bit signs, `doc_keys.jsonl`, `pool_stats.json`,
   `dup_int8_rows.jsonl`. ~28 s on the M1 Max Studio, plus vector sanity checks
   (norms, NaN, tiling, id hygiene, duplicates).
2. `nn_ladder.py` — 3,600 era-stratified queries (seed 18610810): float-768 truth,
   quantization-ladder recall at corpus scale, hamming-200 funnel, same-volume /
   same-era neighbor structure, near-duplicate census. ~5 min. `MANIFEST` supplies the
   era bands (default `FRUSExplorer/Resources/manifest.json` — run from the repo root).
3. `nn_verify.py` — recomputes 12 queries through the literal full-lexsort slow path and
   asserts identity with the ladder's threshold-prefilter fast path.
4. `rerank_pool_sweep.py` — the RERANK_POOL × rerank-width sweep (200/400/800/1600 ×
   int8-256/512) against the same checkpointed truth. ~2 min.
5. `gate_a_corpus.py` — Gate A weak positives at corpus scale. Needs a copy of the app's
   `frus.db` (+`-wal`/`-shm`) at `$ASSESS_DIR/db/frus.db`; keeps `spike_gates.load_edges`
   semantics but retains cross-volume targets. ~10 min for both configs.

These are assessment tools, not shipping generators — the deterministic packer the raw
store feeds is `SemanticVectorsGenerator` (design doc §3.1 Stage 2, unbuilt as of the
assessment).
