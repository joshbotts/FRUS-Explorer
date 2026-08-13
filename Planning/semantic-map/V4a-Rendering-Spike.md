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
- **UMAP will make the fill-rate picture worse.** PCA spreads points evenly — measured, 50.8% of a
  256×256 grid is occupied and the densest cell holds 38 points. UMAP concentrates points into
  clusters with empty space between, which raises overdraw exactly where users will look. Re-measure
  after the layout exists rather than assuming this result transfers.

## 3. The finding the spike was not looking for

`v4a-pca-layout-2560.png` is what the corpus looks like under PCA-2D: a single blob, brighter in the
middle, with no structure a reader could use. That is not a rendering defect — it is what 10% of the
variance looks like. It settles two things:

- **PCA is fine for the spike and useless for the product.** It was chosen here precisely because it
  is instant and needs no dependencies, which let the renderer be measured today.
- **The map's value lives entirely in the layout stage.** Until UMAP/HDBSCAN runs, there is nothing
  to render worth rendering, and every remaining §6.3 feature — colour lenses, semantic-axis slices,
  lasso-to-`WorkingCorpus` — is downstream of it.

## 4. What V-4 should do next

1. **The Tier-0 layout stage**, which is now the critical path: a pinned Python environment
   (`uv`-managed, per design §3.1) running PCA-50 → UMAP-2D with a fixed `random_state`, plus
   HDBSCAN or k-means for cluster ids and c-TF-IDF labels through the WordCloudKit tokenizer. Then
   extend `SemanticVectorsGenerator` to pack coordinates + cluster ids into the bundled artifact
   (~1.9 MB at 6 B/doc, the design's §4.1 estimate; the coordinate half measured at 1.26 MB here).
2. **Re-measure this spike against the UMAP layout** before deciding whether a density layer is
   needed, because the clumping changes the fill-rate answer and nothing else does.
3. Only then the interaction design: lenses, slices, lasso, selection → `WorkingCorpus`.

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
