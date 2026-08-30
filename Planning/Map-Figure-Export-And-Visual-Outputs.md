# Offscreen Metal figure export, and the visual-outputs program behind it

**Status:** §6 Phases 1+2 SHIPPED 2026-08-27 (#1100); §6 Phase 3 SHIPPED 2026-08-27 (the
frame-sequence harness — see the status block at the end of Phase 3, which carries the measured
per-frame cost the phase demanded). §7's adjacent ideas remain open, priced, and sequenced below.
Written 2026-08-20 against the tree at `claude/visual-elements-marketing-xt23dc`.

**Why this document exists.** `SemanticMapExport.swift` ships a deliberate refusal: the map gets the
data half of Manual §13.9's "every analytics chart a figure *or* its data" and not the figure half.
Its doc comment names the cause (a Metal point-sprite pass inside an `MTKView`, which the app's
`ImageRenderer` figure path cannot capture), names the two real routes, and calls either one "a
Metal work item, not an adoption." This plan is that work item. §1–§6 specify it. §7 sizes the
adjacent visual-output ideas that the same capability unblocks, so the sequencing decision is made
once rather than per idea.

**What this is not.** It is not a marketing-asset pipeline. §7 keeps those ideas separate and
deliberately behind the export capability, because most of them become easy once a map frame can be
rendered off-screen and hard-to-impossible until then.

---

## 1. The blocker, stated precisely

`SemanticMapExport.swift`'s "No figure, deliberately" section records the refusal and its evidence:

- the map is a Metal point-sprite pass in an `MTKView`;
- `AnalyticsFigureExporter` drives `ImageRenderer` over a SwiftUI view, which captures the SwiftUI
  layer tree and **not** a `CAMetalLayer` drawable — so the map renders as a blank plate;
- the two real routes are an offscreen pass into a private texture, or reading back
  `currentDrawable.texture`.

**The `currentDrawable.texture` route stays refused, and the reasoning in that file still holds.**
`MTKView.framebufferOnly` defaults to `true` and nothing in the repo clears it, and it would capture
the visible viewport at screen resolution rather than a publication plate. Clearing `framebufferOnly`
also costs the on-screen path a tiling optimisation permanently, to serve an operation that happens
when a reader presses Export. This plan takes the offscreen route.

## 2. What has to change in `SemanticMapRenderer`

`draw(in view: MTKView)` (`SemanticMapRenderer.swift:540`) is coupled to the view in exactly four
places, and all four are in the frame-acquisition half rather than the encoding half:

1. `guard view.window != nil` — an offscreen pass has no window and would be rejected outright.
2. `view.currentRenderPassDescriptor` — the export supplies its own descriptor.
3. `view.currentDrawable` and `buffer.present(drawable)` — there is no drawable to present.
4. The clear colour arrives *through* the descriptor, from `view.clearColor`, set at
   `SemanticMapSpikeView.swift:2978` to `MTLClearColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)`.
   The export must supply the same value explicitly. (`draw(in:)`'s own long note already warns that
   `clearColor` is not something an `MTKView` paints on its own — it is the `.clear` load action
   inside the descriptor, and it reaches the surface only if a pass is encoded.)

The encoding half — set pipeline, bind point buffer, bind uniforms, bind palette, one
`drawPrimitives(type: .point, …)` call for the whole corpus — is already view-independent.

**The change is therefore an extraction, not a second renderer.**

```
private func encode(into descriptor: MTLRenderPassDescriptor,
                    buffer: MTLCommandBuffer,
                    uniforms: inout Uniforms)
```

`draw(in:)` keeps its guards, acquires the drawable, calls `encode`, presents. The export builds a
descriptor over its own texture, calls `encode`, and blits out. **One encode path, two callers.**

That structural property is the point of the whole design, and it is the house rule already written
into `SemanticMapCamera`: the projection "has exactly one definition … a second copy of that
arithmetic is a second thing that can drift." A figure produced by a second, export-only draw path
would not be a picture of what the reader saw — it would be a picture of a nearby program.

**Two properties become settable that are currently `private(set)`:** `aspect`
(`SemanticMapRenderer.swift:206`) and, per-call, `pointSize` (line 200). §3 explains why each is
load-bearing. Prefer passing both as parameters of the offscreen call and restoring the previous
values before returning, over widening the setters — the on-screen view must not be left holding
export geometry.

**No new bundled resource, so no `xcodegen generate` and no scheme restore. No `@Model` change, so
no CloudKit deploy.** Both standing gates are clear; say so in the PR so nobody re-checks.

## 3. The four traps, each of which produces a plausible wrong picture

Every one of these fails *silently* into an image that looks like a map. That is the reason this
section exists and the reason §5 is as heavy as it is.

### Trap 1 — point size is in device **pixels**, not points

`pointSize` (default `2.0`, user-adjustable `1...8` at `SemanticMapSpikeView.swift:2870`) reaches
`[[point_size]]` in the vertex shader (`SemanticMapRenderer.swift:694`, assigned at `:709`). Metal
interprets that in pixels **of the render target**. The on-screen drawable is at
`contentScaleFactor` / `backingScaleFactor`, normally 2 or 3.

So a 3000×2250 plate rendered with the reader's on-screen `pointSize` draws dots at a fraction of
their apparent screen size, and the exported map is dramatically sparser than the one the reader was
looking at. It is still a perfectly plausible map — which is exactly why this must be tested rather
than eyeballed.

**Rule:** the export scales `pointSize` by `exportTextureHeight / onScreenDrawableHeight`, so the
dot subtends the same fraction of the frame. Not by the plate's *point* size, and not by a constant.

### Trap 2 — `aspect` must come from the export texture

`aspect` is assigned only in `mtkView(_:drawableSizeWillChange:)` (`:528`–`:538`), and `scale` derives
from it (`camera.scale(aspect:)`, `:287`). The shader normalises by `scale` in both axes.

An export whose aspect differs from the on-screen view's — which is the normal case, since the plate
is a fixed publication rectangle and the view is whatever the window happens to be — draws the corpus
**stretched**. This bug has already shipped once in this file: the doc comment at `:526` records that
`drawableSizeWillChange` was an empty method and "the corpus was drawn distorted on every device."

**Rule:** set `aspect` from the export texture's own dimensions for the duration of the pass, and
restore it. An export that permanently changed the live view's aspect would distort the screen until
the next resize.

### Trap 3 — the label layer's "identical by construction" guarantee does not survive export

`SemanticMapCamera`'s doc comment states the invariant plainly:

> `aspect` is deliberately **not** stored here. The renderer takes it from the drawable and the label
> layer from the SwiftUI geometry — the same rectangle measured in pixels and in points, so the ratio
> is identical by construction and there is nothing to keep in sync.

In export **there is no shared rectangle.** The Metal pass takes a pixel size we choose; the label
layer (`SemanticMapLabelLayout.labels(for:camera:size:)`, used at `SemanticMapSpikeView.swift:1623`)
takes a point size we choose. The guarantee downgrades from a construction to a convention.

**Rule:** the two sizes are derived from one export rectangle in one place, and a test projects a
known grid coordinate through both paths at export geometry and asserts the same pixel. This is the
single highest-value test in the plan: without it, labels drift off their regions at some plate sizes
and not others, and the figure looks fine at whichever size the developer happened to try.

### Trap 4 — readback storage and byte order

A `.private` texture is not CPU-readable. The uniform path across Apple Silicon and Intel is: render
target `.private` with usage `[.renderTarget, .shaderRead]` → `MTLBlitCommandEncoder` copy into an
`MTLBuffer` with `.storageModeShared` → wrap as `CGImage`. (A `.managed` texture plus
`synchronize(resource:)` also works but adds a platform branch for nothing.)

The pipeline's colour format is `.bgra8Unorm` (`SemanticMapRenderer.swift:141`), so the `CGImage`
needs `.byteOrder32Little` with `.premultipliedFirst`. Get it wrong and you get a fully plausible
image with **red and blue swapped** — the map's palette has enough blues and reds that this reads as
a different lens rather than as a bug.

~~Alpha is not a concern: blending is source-over on both RGB and alpha and the clear alpha is 1, so
the texture is opaque.~~

**CORRECTION (2026-08-30, after W-3 shipped).** That sentence was wrong, and W-3 correctly followed
the code rather than the design. Source-over on *alpha* requires `sourceAlphaBlendFactor = .one`; the
pipeline uses `.sourceAlpha` (`SemanticMapRenderer.swift:377`). The readback alpha therefore lands
around 0.79–0.84 rather than 1, while the RGB channel holds a full over-composite against the dark
clear colour — and the `CGImage` is declared `premultipliedFirst`. Composited over
`AnalyticsFigureCanvas`'s forced white ground, the brightest dots **clamp to pure white** instead of
lightening uniformly. No test reads an alpha channel and the offscreen fixture's palette alpha is 1,
so the defect is structurally invisible. Tracked as Gap 4 in `Planning/Visual-Marketing-Plan.md` §1;
the fix is one blend factor plus one assertion, and it touches the shared pipeline, so it must be
verified on screen as well as in the plate.

## 4. Anti-aliasing: supersample, do not add MSAA

The pipeline descriptor sets no `sampleCount`, so it is 1×. Sample count is **part of the pipeline
state**, so a multisampled target requires a second `MTLRenderPipelineState` — which means a second
entry in `pipelineCache`, a second thing to keep in step with the runtime-compiled shader, and a
figure drawn by a pipeline the on-screen map never uses.

**Render at 2× the plate's final pixel size and downsample.** Free anti-aliasing, and it reuses the
exact shipping pipeline. That last part is not a convenience: a figure produced by a different
pipeline is not evidence of what the reader saw.

Cost is bounded and known — the map is one draw call for 314,483 points, and the on-screen frame is
already measured in the DEBUG stats sink. A 2× supersampled plate is a handful of milliseconds.

## 5. Compositing: Metal renders the point layer and nothing else

The on-screen map is the Metal surface plus SwiftUI overlays — `labelOverlay` (`:1614`),
`selectionMarker` (`:1641`), `sliceScaleOverlay`. Drawing labels in Metal would mean text shaping in
a shader and a second layout implementation. Don't.

**The plate is assembled in the existing figure path:**

```
renderer.renderOffscreen(...) -> CGImage
    -> Image(cgImage)                      // the point layer
    -> .overlay { label layer at export geometry }
    -> AnalyticsFigureCanvas(provenance:)  // caption band, margins, plate
    -> ImageRenderer                       // PNG and PDF, both for free
```

Three things this buys, all of them already written and reviewed:

- **The provenance is done.** `SemanticMapExport.provenance(index:scopeLabel:scopedDocumentCount:
  lensLabel:indexedVolumeCount:)` already exists and already ships for the CSV, including the
  supplied `corpusStatement` that overrides the default "only the N volume(s) indexed on this device"
  caveat — which would be false for a bundled whole-series artifact.
- **PDF falls out.** `AnalyticsFigureFormat` already has both cases; `exportFigure` already takes the
  format.
- **The menu wiring is a one-line change.** `AnalyticsSectionExportControl.exportFigure` is
  `Optional` precisely so a data-only surface omits it (`AnalyticsExportDelivery.swift:161`).
  Supplying it makes the PNG and PDF items appear.

### One design conflict to settle before building

`AnalyticsFigureCanvas` paints an explicit white background and forces `.colorScheme(.light)` so a
detached plate does not inherit the user's appearance. The map's clear colour is a hardcoded **dark**.
So the figure is a dark map inset in a light plate.

**Recommendation: accept that, and do not add a light-background map.** The shader's scope treatment
was tuned against the dark ground — the comment at `SemanticMapRenderer.swift:711`–`:729` records that
fading alone was insufficient, that ghosted points are pushed toward the *background*, and that
in-scope points needed a brightness floor because "~88,000 in-scope documents were indistinguishable
from excluded ones." A light ground inverts the premise of that tuning. Offering a light map as an
export option would be a design change wearing an export option's clothes, and it would ship
untested against the one lens whose colours are least separable.

A dark image inset in a light figure reads as a plate. That is the normal way a screenshot appears in
a paper.

### Slice mode

`labelOverlay` draws nothing when `model.slice != nil`, because a slice is a different projection and
a label drawn at a map-plane centroid would name "a region that is no longer there." The export must
match that, **and its provenance line must say the figure is a slice** — otherwise the figure silently
loses its region names and the reader has no way to know why.

## 6. Phasing and tests

### Phase 1 — the capability, with no UI

Extract `encode(...)`; add `renderOffscreen(pixelSize:supersample:) -> CGImage?`. Nothing user-facing
ships. The deliverable is a tested function.

Tests, and what each one catches:

| Test | Catches |
|---|---|
| Non-background pixel count > 0 at a known size with a known point set | The blank-plate failure. Mirrors `WordCloudDriftRenderTests`'s stated posture — "empty is the realistic failure", and the arithmetic suite would pass in full while the screen stayed black |
| Same point set at 1× and 2× covers ~4× the pixel area | **Trap 1.** Without this, the sparse-map bug ships |
| A known grid coordinate lands at the same normalised position for square and non-square exports | **Trap 2** |
| A grid coordinate projected through the shader path and through `SemanticMapLabelLayout.project` at export geometry lands on the same pixel | **Trap 3** |
| Clear to a known non-grey colour, read back, assert channels | **Trap 4** |
| `aspect` and `pointSize` are unchanged after an export call | The on-screen view being left in export geometry |

**Metal availability:** `SemanticMapRenderer.init?` already returns `nil` when there is no device or
command queue, "because a simulator or a stripped build are both real conditions." These tests must
skip cleanly on that path rather than fail — the same posture `UIObstructionTests` takes for its
iPad-only scenario.

### Phase 2 — the figure export

Compositing canvas, label layer at export geometry, slice handling, `exportFigure` wired into the
map's export control. Closes the stated §13.9 gap. Update `SemanticMapExport.swift`'s "No figure,
deliberately" section — **rewrite it rather than delete it**, the way `SemanticMapRenderer.init?`'s
comment was rewritten when its original justification expired. What replaces it: labels and chrome
are SwiftUI, the point layer is Metal, and the two are composited rather than one being reimplemented
in the other.

### Phase 3 — the frame-sequence harness

`renderOffscreen` plus the existing scope machinery is already an animation renderer.
`applyScope(volumeIDs:label:)` (`SemanticMapSpikeView.swift:2697`) → `setScopeFlags` (`:447`) is
literally "light up these volumes", and `manifest.json` carries `dateRange` and `subseries` per
volume, so chronological ordering is free. Stepping one volume per frame in date order and calling
`renderOffscreen` gives a deterministic sequence — deterministic because scope and camera are
explicit state, not a clock.

Cost to know: `setScopeFlags` is a CPU loop over all 314,483 rows writing one byte each. Fine per
volume; measure before driving it per frame.

**The honesty requirement travels with it.** `scopeSummary`'s doc comment (`:2710`) says why: a scope
is a set of *volumes*, so scoping to *Nuclear Nonproliferation* lights all 7,702 documents in the 26
tagged volumes, not the documents about nonproliferation — and "on a chart that distinction hides
inside a bar; on a map the reader watches those documents land in regions named `salmon
constantinople`." Any published animation carries that sentence.

**Status: SHIPPED 2026-08-27.** `SemanticMapFrameSequence` (in `FRUSExplorer/Semantic/Map/`)
owns ONLY the ordering, the loop, and the sidecars — the mask is `SemanticMapModel.setScope`
(the same pass the on-screen chip runs) and the frame is `renderOffscreen`, so a frame is a
picture of what the reader would see, by construction. One cumulative-scope frame per covered
volume ascending by `dateRange.earliest` (volume id as the total tiebreak), then a closing
unscoped frame; the model is left unscoped. Hosted exactly where §7.4 predicted — a
generator-style test in the app test target (`SemanticMapFrameSequenceTests`), gated behind
`TEST_RUNNER_RENDER_MAP_FRAMES_DIR` (the `TEST_RUNNER_` prefix is load-bearing: a trailing
KEY=VALUE argument is a build setting and never reaches the test process, and the
`-only-testing` filter must stop at the suite — a function-level filter matches zero tests
and reports "passed"). The honesty requirement travels as designed: `animationGrainSentence`
leads `provenance.txt`, written beside the frames with `frames.csv` (per-frame volume, title,
coverage start, cumulative counts, measured cost).

**The cost question this phase existed to answer, measured 2026-08-27** (iPhone 16e
simulator, M-series host, 1920×1080 at supersample 2): 553 frames in 57.6 s — **mean
103.8 ms, worst 123.9 ms per frame**, mask + upload + render + readback + PNG encode
together. So driving `setScopeFlags` per frame is ~10 fps offline: not a live animation
rate, and exactly enough for a harness whose output is assembled into video afterwards
(`ffmpeg -framerate 12 -i frame-%04d.png -pix_fmt yuv420p map.mp4`). The determinism claim
is a test, not an assertion: the same three-volume sequence rendered twice is byte-identical,
frame for frame.

---

## 7. The adjacent ideas, and where they sit

Assessed 2026-08-20 against the bundled artifacts. Ordered by effort, not by appeal.

### 7.1 Randomised splash lens — trivial, independent of everything above

`LaunchSplashView.swift:50` already draws `WordCloudBackdropView(scope: .corpus, …)`, which cycles
`WordCloudLens.bundledCloudLenses` off `@State private var lensIndex = 0`. Seeding that randomly per
launch gives "a different lens each time" with no new assets.

**What cannot be done, and it is worth writing down so it is not re-proposed:** the iOS launch screen
cannot choose among several images. `Info.plist` uses `UILaunchStoryboardName: LaunchScreen`, and that
storyboard's own header states the rule — "A launch screen runs NO code." The system renders it before
the process exists and caches the snapshot. **Randomisation belongs in `LaunchSplashView`, one layer
up.** If a static plate is added to the storyboard it must stay dim and neutral, because the storyboard
header and `LaunchSplashView`'s own doc comment both require the two to "read as one moment, not as a
screen replaced by a different screen."

### 7.2 Marketing plates from `WordCloudExporter` — small

`WordCloudExport.swift` already renders PNG/PDF at 1200×900 @2x through `ImageRenderer`, up to 140
words, with palette and sentiment colouring and an optional provenance caption band. Two changes make
it a marketing-asset generator: lift the hardcoded private `canvas` to a parameter, and allow
title-only plates (`provenanceLine: nil` already does this).

### 7.3 Two more corpus lenses — small, loader only

Measured: `cloud-vectors-core.json` carries 4 corpus lenses (concepts, topics, actions, sentiment) and
is what the live backdrop reads. **`keyness-baseline.json` additionally carries `allTerms` and
`descriptors` at corpus scope with raw counts** (top 20,000/lens plus each lens's true total). So six
corpus lenses are reachable with a loader and no generator run.

`people` / `places` / `organizations` are **not** available: `WordCloudMultiLensTokenizer` refuses
entity lenses and they are excluded from the bundled vectors pending curation. Corpus-wide entity
clouds need a new `NLTagger` `.nameType` pass — roughly the scale of the existing ~50–60 minute
`CloudVectorsGenerator` run — plus that curation. Probably the most marketable lenses and definitely
the most expensive; price it as its own session.

### 7.4 Volume word-cloud animation — moderate, and the data is complete

Measured over `cloud-vectors-volumes.json`: **552 volumes × 4 lenses × exactly 50 terms, with zero
scopes flagged `belowSignalThreshold`.** No thin volumes, no era fallbacks. 1.29 MB, bundled, offline.

The motion model is what makes this tractable: `WordCloudDriftField` imports no SwiftUI and is
closed-form in absolute time — "Position is a closed-form function of absolute time, not a state that
integrates each frame." Frame *N* at `t = N/fps` is deterministic, reproducible, and identical to what
the device draws. `WordCloudDriftRenderTests` already drives `WordCloudDriftCanvas` through
`ImageRenderer` off-screen, so the harness is half-built.

Two traps already documented in the repo and easy to re-introduce:

- `Canvas` traps on **duplicate symbol ids**, and every bundled scope shares terms across lenses.
  A multi-lens renderer must namespace symbol ids per layer. This once made the shipped indexing
  strip render nothing while every render test passed.
- Depth must come from `PlacedWord.colorIndex`, never the array index, because `WordCloudLayout.place`
  silently drops unplaceable words and compacts the array.

Practical constraint: `ImageRenderer` is `@MainActor` SwiftUI, so this cannot be a plain
`swift run` SPM generator like the other tools. The natural host is a generator-style test in the
existing test target, which is already doing exactly this kind of off-screen render.

### 7.5 Map animations — **gated on §6, and that is the sequencing argument**

The provenance-lens sweep is a premise the codebase already wrote for itself:
`SemanticMapLens.provenance`'s doc comment quotes the design as *"watch the central files give way to
presidential libraries across the space"*. That lens is implemented. `semantic-map-index.json` carries
per-cluster era histograms and 179 labelled regions; `SemanticMapLens.era` ships.

Until Phase 1 exists the only capture route is `xcrun simctl io recordVideo` or macOS screen
recording — which works, needs no code, and is capped at screen resolution. That is the right
stopgap for a quick look, and the wrong thing to build a pipeline on.

### 7.6 Already reachable today, no new capability needed

The Swift Charts analytics family — `ArchivalFlowsView`, `ArchivalNetworkView`,
`PersonCoMentionGraphView`, `CrossReferenceGraphView` — is SwiftUI, so it is already reachable by
`AnalyticsFigureExport`'s `ImageRenderer` path. Static plates from these are close to free, and
`KeynessCloud` + `keyness-baseline.json` produce a *distinctiveness* cloud rather than a frequency
one, which is a better figure and is already built.

---

## 8. The disclosure rule for anything published

Several artifacts carry mandatory caveats, and material derived from them inherits them. This is not
a style preference — the repo has been consistent about it, and a promotional image that drops the
caveat is the one way this program does damage:

- **95.3%** of `provenance-flow-index.json`'s edges are footnotes: a cell describes the editors'
  annotation practice, not a relation between archives.
- The map's per-volume provenance colour is a **plurality, not a majority**, for **73 of 522** volumes.
- A map scope lights **every document in** the scoped volumes, not the documents *about* the subject
  (§6, Phase 3).

`WordCloudExporter`'s provenance caption band and `AnalyticsProvenance` exist for exactly this. Keep
them on anything that shows a count.

---

## 9. Recommended order

1. **§6 Phase 1** — the offscreen capability and its six tests. Self-contained, no UI, no gates.
2. **§6 Phase 2** — the figure export. Closes a stated §13.9 gap; the provenance and menu halves
   already exist.
3. **§7.1 + §7.2** — randomised splash lens and the exporter canvas parameter. Both small, both
   independent, good filler beside the above.
4. **§7.3** — the two extra corpus lenses, loader only.
5. **§6 Phase 3 / §7.4** — the animation harnesses, map and word cloud, once Phase 1 exists.
   *(The map half SHIPPED 2026-08-27 — see Phase 3's status block; the word-cloud half, §7.4,
   remains open.)*
6. **§7.3's entity lenses** — its own session, priced as a generator run plus curation.
