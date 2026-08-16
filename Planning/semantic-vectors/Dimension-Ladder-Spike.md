# The 256 / 512 dimension ladder — measured

**Status:** spike complete, 2026-08-16. Decision open.

Run to answer one question: is 512 worth shipping, and if so, as a user option or as the default?
Every number below was produced on this corpus by re-running the shipping generator; nothing is
extrapolated except where it says so.

---

## What was run

`SemanticVectorsGenerator` at `DIMS=512` over the same raw store as the shipping build
(`~/frus-semantic-raw`, 2.2 GB), writing to a scratch directory so **the shipping artifacts were
not touched** — verified after the run: `git status` showed no change to `FRUSExplorer/Resources/`.

`SemanticVectorsKitTests/DimensionLadderBenchmark` then drove the **real kernel** over both artifact
sets: same 601 query rows, same `RERANK_POOL` of 800, one warm pass per width before sampling.

---

## Size — the whole cost

| | 256 (shipping) | 512 | delta |
|---|---|---|---|
| Bundled corpus binary | **9.76 MB** | **19.52 MB** | +9.76 MB — *this lands in the app bundle* |
| Shards, all 552 volumes | **78.01 MB** | **154.79 MB** | +76.78 MB |
| Per shard, mean | 144.7 KB | 287.1 KB | +142.4 KB |
| **Device total, full library** | **87.8 MB** | **174.3 MB** | **+86.5 MB** |

Exactly double throughout, which is what the format predicts: sign bits are `dims / 8` bytes a row
(32 → 64) and shard codes are one int8 a dimension.

## Latency — sublinear, and not the constraint

M1 Max, 601 queries, pool 800. Two runs; medians moved a little between them, the ratio did not.

| stage | 256 | 512 | ratio |
|---|---|---|---|
| Hamming scan, 314,483 documents | 0.96 – 1.11 ms | 1.53 – 1.68 ms | **~1.5–1.6×** |
| Rerank, 800 rows | 0.063 ms | 0.113 ms | **1.78×** |
| **Whole funnel** | **~1.03 ms** | **~1.64 ms** | **~1.6×** |

**Doubling the data costs about 1.6× the time, not 2×** — the scan is bandwidth- and popcount-bound,
and 64 bytes a row still fits the same cache lines it was already touching two of.

**THE ABSOLUTE NUMBERS DO NOT TRANSFER AND THE RATIO DOES.** This is an M1 Max; the design's V-2
called for an "oldest-device latency measurement" and that has still never been run. A phone will be
several times slower at both widths. The decision should rest on the ratio and on the size table,
not on "1.6 ms is nothing" — which is true here and unproven anywhere a reader actually is.

## Recall — from the design, not re-measured here

0.749 at 256 against **0.864** at 512, recall@10 versus exact float-768 neighbours. Re-measuring it
would need the reference neighbour lists the corpus gates produced, which are not in this repo.

---

## The trade, in one line

**+86.5 MB on device, +9.76 MB in the app bundle, ~+0.6 ms a query, for +0.115 recall@10.**

## What this says about the user-option question

Three findings argue against a toggle and for a single decision:

1. **`shippingDims` is inside the provenance digest**, and `SemanticShard.init` refuses any digest
   mismatch. So the two families cannot coexist without either a second bundled provenance or a
   loosened pin — and loosening it invalidates every existing artifact.
2. **The retrieval code is already width-agnostic.** The shard header stores dims at byte offset 8
   and the kernel reads `vectors.dims` rather than a constant, so nothing in the funnel needs
   changing for 512. The obstacle is the pin and the hosting, not the maths.
3. **Mixed state is the real hazard.** A reader who switched mid-library would have some volumes
   reranked at 512 and some at 256, so neighbour lists would depend on download order — the same
   defect class the family rule exists to prevent.

If 512 ships it should ship for everyone, or as a one-way upgrade that re-fetches and refuses to run
mixed. A free-form toggle asks readers to arbitrate a recall/megabyte trade they have no basis to
judge.

## Prerequisite either way

Shard downloads still have **no off switch** (#926, item 1). Doubling the payload before there is a
way to decline it is the wrong order.
