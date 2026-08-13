# V-4a rendering spike — the map's renderer is not the problem; its layout is

**Status:** measured 2026-08-12 on the M1 Max Studio. The spike the design asks for before any of
the discovery map's interaction design is built (`Vector-Embeddings-Semantic-Design.md` §6.3:
"Prototype the Metal LOD spike early (V-4a) before committing the full surface").
**Code:** `FRUSExplorer/Semantic/Map/` — `SemanticMapRenderer` (Metal, runtime-compiled shaders) and
`SemanticMapSpikeView` (`#if DEBUG`, Settings ▸ Data & Recovery).
**Evidence:** `v4a-pca-layout-2560.png` beside this file — all 314,483 documents, one draw call.

---

## 0. The verdict in four sentences

1. **Rendering is not the bottleneck the design budgeted for.** One draw call over all 314,483
   documents costs **3.3 ms** at 2560×1440 on an M1 Max — five times inside a 60 fps frame — so
   level-of-detail is an *optimisation for weaker GPUs*, not a prerequisite for the surface.
2. **The cost is fill rate, not vertex count**: 8-pixel points cost 50% more than 2-pixel ones, and
   zooming in (fewer covered pixels, same vertices) drops the frame to 0.6 ms. The lever is point
   size and viewport, not decimation.
3. **PCA-2D is not a shippable layout, and the picture proves it.** The two leading components carry
   **10.0%** of the variance and the corpus renders as one featureless cloud: no clusters, no
   regions, nothing to navigate. The map genuinely needs the UMAP/HDBSCAN stage.
4. So **V-4's blocking dependency is the Tier-0 layout artifact, not the renderer** — which inverts
   the order the design assumed, and is the useful thing this spike found.

## 1. What was measured

One `drawPrimitives(type: .point, vertexCount: 314_483)` into a 2560×1440 offscreen target, timed by
GPU timestamps (`gpuEndTime - gpuStartTime`), 40 frames per configuration after a warm-up. Wall time
around `commit` was deliberately not used: the command buffer has barely started when `commit`
returns, so a CPU-side measurement reports the encode cost and calls it the frame cost.

| configuration | median | p90 | worst |
|---|---|---|---|
| corpus view, 2 px points | **3.28 ms** | 3.76 ms | 3.85 ms |
| corpus view, 4 px points | 3.41 ms | 3.73 ms | 3.81 ms |
| corpus view, 8 px points | 4.03 ms | 4.60 ms | 4.68 ms |
| zoomed 10×, 4 px points | 0.48 ms | 0.90 ms | 0.92 ms |

The zoomed row is the diagnostic one: the same 314,483 vertices, most of them off-screen, run **7×
faster**. Vertex processing is nearly free; the frame is paid for in covered pixels.

## 2. What this does to the design's §6.3 plan

The design specifies "Metal (`MTKView`/point-sprites) with level-of-detail — corpus zoom draws a
precomputed density layer + cluster labels; volume/cluster zoom draws real points", on the stated
grounds that `Canvas` degrades past ~20–50k points and 317k is 6–15× that. The first half stands —
this is Metal, not Canvas. The second half is now priced:

- **The density layer is not needed for performance.** It may still be wanted for *legibility* (see
  §3), which is a different argument and should be made on its own terms.
- **A device measurement is still owed.** An M1 Max is a strong GPU; the headroom is 5× at 60 fps,
  so a GPU 4–5× slower still fits, but that is arithmetic, not a measurement.
- **UMAP changes the fill-rate picture in both directions — measured, see §3a.** The prediction that
  it would be strictly worse was half right: overdraw inside clusters rises sharply, but total lit
  area falls, and which wins depends on point size.

## 3. The finding the spike was not looking for

`v4a-pca-layout-2560.png` is what the corpus looks like under PCA-2D: a single blob, brighter in the
middle, with no structure a reader could use. That is not a rendering defect — it is what 10% of the
variance looks like. It settles two things:

- **PCA is fine for the spike and useless for the product.** It was chosen here precisely because it
  is instant and needs no dependencies, which let the renderer be measured today.
- **The map's value lives entirely in the layout stage.** Until UMAP/HDBSCAN runs, there is nothing
  to render worth rendering, and every remaining §6.3 feature — colour lenses, semantic-axis slices,
  lasso-to-`WorkingCorpus` — is downstream of it.

## 3a. Re-measured against the real layout (2026-08-12, same session)

The layout stage ran, so the "re-measure after the layout exists" caveat below is closed rather than
outstanding. UMAP-2D over the same 314,483 documents: **6.6 min** for the projection, 8.2 min for
HDBSCAN, 179 clusters, 28.0% unclustered. Picture: `v4-umap-layout-2560.png`.

The clumping arrived as predicted — the densest 256×256 cell holds **452 documents against PCA's
38**, while overall occupancy *drops* from 50.8% to 31.4% (clusters and voids, rather than an even
spread). The frame cost follows both facts at once:

| points | PCA layout | UMAP layout |
|---|---|---|
| 2 px | 3.28 ms | **1.90 ms** |
| 4 px | 3.41 ms | 3.23 ms |
| 8 px | 4.03 ms | **5.91 ms** |

**The two layouts cross over.** At small point sizes UMAP is *cheaper* — a third of the screen is
empty, so there are fewer covered pixels than the even PCA spread produces. At 8 px the dense cores
overdraw and it becomes 47% more expensive. That is the same fill-rate story §1 told, now with the
mechanism visible: cost tracks *covered pixels*, and clumping trades a smaller lit area against far
heavier overdraw inside it.

The conclusion is unchanged and now rests on the real artifact: the worst measured case is **5.9 ms**,
still nearly 3× inside a 60 fps frame, so level-of-detail stays an optimisation. The practical lever
is the one this table shows — **point size** — and a map that scales sprite size with zoom is doing
LOD's job for a fraction of LOD's complexity.

## 4. What V-4 should do next

1. ~~**The Tier-0 layout stage**~~ — **done** (`tools/semantic-map/build_layout.py`). `layout.bin` is
   1.89 MB for 314,483 documents at 6 B each, which is the design's §4.1 estimate to two decimal
   places. Cluster *ids* only: labels are Swift's job, because the design wants them through the
   WordCloudKit tokenizer and a second vocabulary here would disagree with every word-cloud surface
   in the app.
2. ~~**Re-measure this spike against the UMAP layout**~~ — **done**, §3a. A density layer is not
   needed for performance; scale point size with zoom instead.
3. **Pack Tier-0 into the bundled artifact**: extend `SemanticVectorsGenerator` to read `layout.bin`,
   emit coordinates + cluster ids, and generate c-TF-IDF cluster labels through `WordCloudKit`. This
   is the next step and the last one before the surface itself.
4. Only then the interaction design: lenses, slices, lasso, selection → `WorkingCorpus`.

## 5. Notes for whoever picks this up

- **The shaders compile at runtime** (`device.makeLibrary(source:)`) rather than from a `.metal`
  file, because a build-time shader needs the Metal toolchain component installed and a
  multi-gigabyte developer download is a strange prerequisite for finding out whether a draw call is
  fast. If the map ships, move them to a `.metal` file and install the toolchain deliberately.
- **A point is 4 bytes** — `int16` x/y — plus a palette *index* rather than a colour, so switching
  lens rewrites 314 KB instead of 5 MB and the palette can follow the theme without touching
  positions. The `flags` byte is reserved for downloaded-vs-not, selection, and the anchor.
- The spike reads coordinates from a developer-supplied file path and falls back to a synthetic
  six-blob cloud, saying so on screen. **It deliberately does not bundle a placeholder layout**: a
  file in `Resources` that looks like the measured artifact and is not is exactly the failure this
  program keeps designing against.

---

Version history:
  1.0 — 2026-08-12: spike executed. Rendering measured at 3.3 ms for the whole corpus; LOD demoted
        to an optimisation; PCA-2D shown to be unusable as a layout, making the Tier-0 UMAP stage
        V-4's critical path.
