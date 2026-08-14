// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Metal
import MetalKit
import simd

/// Draws the whole corpus in one call.
///
/// The design (`Vector-Embeddings-Semantic-Design.md` §6.3) budgets the discovery map's rendering as
/// "the one place this workstream buys new rendering machinery — budget it honestly (it is a session,
/// not an afternoon)", and specifies **Metal with level-of-detail** on the grounds that SwiftUI
/// `Canvas` degrades past ~20–50k points and the corpus is 6–15× that. This began as the spike that
/// tested the first half of that claim. **The measurement came back: one draw call over 314,483
/// points costs ~0.05 ms**, so level-of-detail is an optimisation this surface has never needed, and
/// none of §6.3's LOD machinery was built.
///
/// ## What it does
///
/// Uploads every document's grid position once and then moves only the camera. Points are drawn as
/// round sprites in a single instanced draw call; colour is a palette *index* per point, so switching
/// lens rewrites 314 KB rather than 5 MB and the palette can follow the theme without touching
/// positions.
///
/// The artifact packs a placement into 6 bytes, but `MapPoint` measures **size 6, alignment 4, stride
/// 8** — `Array.withUnsafeBytes` hands `makeBuffer` the strided length, so the vertex buffer is 8
/// bytes per document, 2.5 MB for the corpus rather than the 1.26 MB an earlier version of this
/// comment claimed. The Metal struct has the same layout, which is what makes the indexing agree.
///
/// **Frames are produced on demand.** The view is paused and every mutator here marks it dirty, so a
/// map nobody is touching costs nothing; see `setNeedsRedraw()`. That is the one thing to know before
/// adding state that affects the picture — a new stored property without a `didSet` will simply not
/// appear until something else moves.
///
/// ## What it deliberately does not do
///
/// No density layer and no level-of-detail. Region labels and picking exist but are not the
/// renderer's: they are pure functions over the same camera in `SemanticMapLabels` and
/// `SemanticMapPicking`, which is what lets them be tested without a GPU.
///
/// **Main-actor-isolated, and that is load-bearing rather than tidiness.** `MTKView` is
/// `NS_SWIFT_UI_ACTOR`, so marking a view dirty is a main-actor call; the two `MTKViewDelegate`
/// witnesses are main-actor for the same reason, and every caller — `SemanticMapModel` and the
/// representable — already was. An earlier version of this file left the class nonisolated and
/// claimed in a comment that "a renderer is a perfectly reasonable thing to build off the main
/// actor". It is not: the class is not `Sendable`, so a renderer built elsewhere could not legally
/// reach the `@MainActor` model that must own it, and the compiler said so — a clean build of the
/// macOS scheme emitted *main actor-isolated property 'needsDisplay' can not be mutated from a
/// nonisolated context*, against a repo rule of zero source warnings.
///
/// Version history:
///   1.0 — V-4a: initial spike
///   1.1 — V-4: promoted with the map into Semantic Analytics. On-demand drawing replaces the
///         free-running 60 fps loop, and the pipeline is compiled once per process rather than once
///         per view-struct initialisation. Main-actor-isolated, which the redraw path requires.
@MainActor
final class SemanticMapRenderer: NSObject, MTKViewDelegate {

    /// One document as the GPU sees it. Layout must match `MapPoint` in the shader exactly.
    struct MapPoint {
        /// Grid position, as stored in the artifact.
        var position: SIMD2<Int16>
        /// Index into the active palette.
        var colourIndex: UInt8
        /// Reserved — downloaded-vs-not, selection, and the anchor's own row will live here.
        var flags: UInt8
    }

    /// Camera and appearance, mirroring `MapUniforms` in the shader.
    struct Uniforms {
        var centre: SIMD2<Float>
        var scale: SIMD2<Float>
        var pointSize: Float
        var alpha: Float
    }

    /// Rolling frame statistics — the spike's original output, now the DEBUG overlay's.
    struct Stats: Sendable, Equatable {
        /// Documents in the vertex buffer.
        var pointCount: Int = 0
        /// Mean GPU frame time over the recent window, in milliseconds.
        var frameMilliseconds: Double = 0
        /// Worst frame in the recent window.
        var worstMilliseconds: Double = 0
        /// Frames presented since the renderer was built.
        ///
        /// **The overlay was unable to tell "drawing" from "drew once and stopped".** A window is
        /// published every 30 samples and the model then keeps that value, so the blank macOS
        /// surface showed a confident "4.09 ms mean" that proved only that some frames had happened
        /// at some point. A running total makes a frozen surface visible.
        ///
        /// Read it differently now that the map draws on demand: a count that stops climbing while
        /// the reader is not touching the map is correct rather than alarming. It is also the reason
        /// `record` publishes on every frame — see there.
        var presentedFrames: Int = 0
    }

    /// Called on the main actor after every presented frame.
    var onStats: (@Sendable @MainActor (Stats) -> Void)? {
        get { statsSink.onStats }
        set { statsSink.onStats = newValue }
    }

    /// The colour format the pipeline is built for; the MTKView must be given the same one, and
    /// `SemanticMapSurfaceTests` asserts they agree because nothing else does.
    static let pixelFormat: MTLPixelFormat = .bgra8Unorm

    /// The device the pipeline was built on; the MTKView must be given the same one.
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var pointBuffer: MTLBuffer?
    private var paletteBuffer: MTLBuffer
    private var pointCount = 0

    /// Documents actually in the vertex buffer — what `draw(in:)` gates on.
    ///
    /// **This exists so a test can tell an upload from a counter.** The first version of the map's
    /// suite asserted the model's own `placedCount`, which the model assigns from the array it just
    /// built; stubbing `setPoints` to do nothing left every assertion green over a blank screen. This
    /// reads through `pointBuffer`, so it also catches a `makeBuffer` that returned nil.
    var uploadedPointCount: Int { pointBuffer == nil ? 0 : pointCount }

    /// How many times points have been uploaded.
    ///
    /// Idempotence is not observable from `uploadedPointCount` — a re-upload of the same corpus
    /// leaves it identical — so the claim "preparing twice does not re-upload" needs its own counter
    /// or it cannot be tested at all.
    private(set) var uploadCount = 0

    /// Sprite size in pixels.
    var pointSize: Float = 2.0 { didSet { setNeedsRedraw() } }

    /// Where the camera is looking. The label layer projects through the same value, which is the
    /// point of the type: one definition of where a grid coordinate lands.
    private(set) var camera = SemanticMapCamera() { didSet { setNeedsRedraw() } }
    /// Viewport width divided by height, from the drawable rather than assumed.
    private(set) var aspect: Float = 1 { didSet { setNeedsRedraw() } }
    /// The viewport in points, for converting a gesture's translation into grid units.
    private(set) var viewportPoints = CGSize(width: 600, height: 600)

    /// A view held without keeping it alive.
    private final class WeakView {
        weak var view: MTKView?
        init(_ view: MTKView) { self.view = view }
    }

    /// The views to mark dirty, weakly.
    ///
    /// **A list rather than one reference.** Whether SwiftUI realizes *this* representable more than
    /// once is a question this file has answered wrongly before — the suite's version history records
    /// "NOT, as this entry first claimed, SwiftUI realizing the representable more than once; it is
    /// realized once" — so the list is not justified by a measured multiplicity. It is justified by
    /// the cost asymmetry: a second live view costs one redundant dirty mark on a view `draw(in:)`
    /// already skips for having no window, while a single slot holding the wrong instance costs a map
    /// that never redraws at all. The suite does construct several views from one surface, and every
    /// one of them is marked.
    ///
    /// Weak, and it must stay weak: `MTKView.delegate` is itself weak and the model owns the
    /// renderer, so a strong reference here would close a cycle around every window the map opens.
    private var attachedViews: [WeakView] = []

    /// How many views have been marked dirty, in total, across every redraw request.
    ///
    /// **Counts the mark, not the call**, and the distinction is the whole value of the counter.
    /// `UIView` exposes no readable `needsDisplay`, so on the platform the suite runs on there is
    /// nothing else to assert; a counter incremented at the top of `setNeedsRedraw` would stay green
    /// against a body that had stopped marking anything — which is a map frozen at its first frame,
    /// the most complete failure this surface has. So it is incremented immediately after the
    /// platform call, per view, where the two cannot be separated by a one-line edit.
    private(set) var markedViewCount = 0

    /// Marks every attached surface dirty so it asks for one frame.
    ///
    /// **The map draws on demand, not on a clock.** It is a static image unless the camera moves,
    /// the lens changes or the corpus is re-uploaded, so a free-running display link re-issued the
    /// same 314,483-point draw call sixty times a second for as long as a window stayed open —
    /// affordable while this was a spike being measured, not for a window a reader leaves open
    /// beside their work. Every mutator above marks the surface instead, which is why they are
    /// `didSet` rather than plain stored properties.
    private func setNeedsRedraw() {
        attachedViews.removeAll { $0.view == nil }
        for box in attachedViews {
            guard let view = box.view else { continue }
            #if os(macOS)
            view.needsDisplay = true
            #else
            view.setNeedsDisplay()
            #endif
            markedViewCount += 1
        }
    }

    /// Registers a view to receive redraw requests, and asks it for a first frame.
    ///
    /// Idempotent: registering a view already known replaces its entry rather than adding a second.
    ///
    /// - Parameter view: The view this renderer is the delegate of.
    func register(_ view: MTKView) {
        attachedViews.removeAll { $0.view == nil || $0.view === view }
        attachedViews.append(WeakView(view))
        setNeedsRedraw()
    }

    /// How many live views are registered, for tests.
    var attachedViewCount: Int {
        attachedViews.reduce(0) { $0 + ($1.view == nil ? 0 : 1) }
    }

    /// Grid coordinate at the centre of the view.
    var centre: SIMD2<Float> { camera.centre }

    /// Grid units per half-viewport, in each axis.
    ///
    /// Derived rather than stored: the shader maps `(grid - centre) / scale` straight to clip space,
    /// where both axes span [-1,1] whatever shape the viewport is, so a single scale value stretches
    /// the map non-uniformly. It shipped that way — `frameAll` was called with a hardcoded `aspect: 1`
    /// and `drawableSizeWillChange` was empty — and the corpus was drawn distorted on every device.
    var scale: SIMD2<Float> { camera.scale(aspect: aspect) }

    #if DEBUG
    /// Draw calls received, for the blank-surface probe.
    private var drawCallCount = 0
    #endif

    /// Accumulates GPU frame times off the main actor and publishes a value type per frame.
    /// GPU-reported timestamps are the honest measure; CPU wall time around `commit` is not, because
    /// the command buffer has barely started when `commit` returns.
    private let statsSink = StatsSink()

    /// Compiled pipelines, keyed by device.
    ///
    /// **Because the renderer is built more often than it looks.** `SemanticMapModel` constructs one
    /// in `init` — deliberately, so no view can exist before the renderer does — and a `@State`
    /// property's initial value expression is evaluated on *every* initialisation of the view struct,
    /// not only the first. SwiftUI discards the duplicates, but the shader compilation had already
    /// happened. Caching makes the pipeline half of a discarded construction cost a dictionary
    /// lookup — a command queue and a 256-byte palette buffer are still made and thrown away, which
    /// is the cheap part and not worth a second cache.
    ///
    /// A bare dictionary rather than a locked box: the whole type is main-actor-isolated, so the
    /// isolation *is* the synchronisation. A failure is not cached — nothing here would make a second
    /// attempt succeed, but neither does a stored `nil` earn its complexity.
    private static var pipelineCache: [ObjectIdentifier: MTLRenderPipelineState] = [:]

    /// How many times the shader has actually been compiled.
    ///
    /// The point of the cache is that this does *not* grow with the number of renderers, and there is
    /// no other way to observe that: two constructions both succeed either way.
    private(set) static var pipelineCompileCount = 0

    /// The render pipeline for a device, compiling it once per process.
    ///
    /// - Parameter device: The device to build for.
    /// - Returns: The pipeline, or `nil` when the shader will not compile or link.
    static func pipeline(for device: MTLDevice) -> MTLRenderPipelineState? {
        let key = ObjectIdentifier(device)
        if let cached = pipelineCache[key] { return cached }
        guard let built = buildPipeline(for: device) else { return nil }
        pipelineCache[key] = built
        return built
    }

    /// Compiles and links the point-sprite pipeline.
    ///
    /// - Parameter device: The device to build for.
    /// - Returns: The pipeline, or `nil` when the shader will not compile or link.
    private static func buildPipeline(for device: MTLDevice) -> MTLRenderPipelineState? {
        pipelineCompileCount += 1
        guard let library = try? device.makeLibrary(source: shaderSource, options: nil),
              let vertexFunction = library.makeFunction(name: "semanticMapVertex"),
              let fragmentFunction = library.makeFunction(name: "semanticMapFragment")
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        // Ordinary source-over compositing. `.add` here is the *combine operation*, and with
        // `.sourceAlpha` / `.oneMinusSourceAlpha` factors that is plain alpha blending — overlapping
        // documents saturate toward the source colour rather than accumulating. An earlier version of
        // this comment called it "additive … which is what makes density legible without a separate
        // heat layer"; that is not what these factors do, and a real density layer is still owed.
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    /// Creates the renderer, taking the shared pipeline for this device.
    ///
    /// - Parameter device: The Metal device to render with.
    /// - Returns: `nil` when the device has no command queue or the shaders are missing — the caller
    ///   shows an unavailable state rather than crashing, because a simulator or a stripped build
    ///   are both real conditions.
    init?(device: MTLDevice) {
        // Compiled from source at runtime rather than from a `.metal` file in the target.
        //
        // **The map has now shipped, so the original justification has expired and is replaced
        // rather than left standing.** It read: a build-time shader needs the Metal toolchain
        // component installed, which a spike does not justify. What keeps runtime compilation now is
        // narrower and worth stating plainly — the shader and the code that binds its buffers are
        // the two halves of one contract with no compiler checking between them, and keeping them
        // in one file is what makes a layout mismatch visible. The cost is one compilation per
        // process, because `pipeline(for:)` above caches it; the risk is that a compilation failure
        // becomes a runtime `nil` instead of a build error, which is why `init?` exists and why the
        // caller draws an unavailable state rather than crashing.
        guard let queue = device.makeCommandQueue(),
              let pipeline = Self.pipeline(for: device)
        else { return nil }

        guard let palette = device.makeBuffer(
                length: MemoryLayout<SIMD4<Float>>.stride * 16, options: .storageModeShared)
        else { return nil }

        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.paletteBuffer = palette
        super.init()
        setPalette(Self.defaultPalette)
    }

    /// Uploads the document positions.
    ///
    /// - Parameter points: One entry per document, in artifact row order.
    func setPoints(_ points: [MapPoint]) {
        pointCount = points.count
        uploadCount += 1
        statsSink.setPointCount(points.count)
        defer { setNeedsRedraw() }
        guard !points.isEmpty else { pointBuffer = nil; return }
        pointBuffer = points.withUnsafeBytes { raw in
            device.makeBuffer(bytes: raw.baseAddress!, length: raw.count, options: .storageModeShared)
        }
    }

    /// Replaces only the per-document colour indices, leaving positions untouched.
    ///
    /// This is why a point carries a palette *index* rather than a colour: switching lens rewrites
    /// one byte per document — 314 KB — against the 5 MB a colour-per-point buffer would cost, and
    /// the position half of the buffer is never re-uploaded at all.
    ///
    /// - Parameter colours: One palette index per document, in artifact row order.
    func setColourIndices(_ colours: [UInt8]) {
        guard let pointBuffer, colours.count == pointCount else { return }
        let stride = MemoryLayout<MapPoint>.stride
        let base = pointBuffer.contents()
        for row in 0..<colours.count {
            base.advanced(by: row * stride + MemoryLayout<SIMD2<Int16>>.size)
                .storeBytes(of: colours[row], as: UInt8.self)
        }
        setNeedsRedraw()
    }

    /// Replaces the colour palette.
    ///
    /// - Parameter colours: Up to 16 RGBA colours; a point's `colourIndex` selects one.
    func setPalette(_ colours: [SIMD4<Float>]) {
        let contents = paletteBuffer.contents().bindMemory(
            to: SIMD4<Float>.self, capacity: 16)
        for index in 0..<16 {
            contents[index] = index < colours.count ? colours[index] : SIMD4<Float>(1, 1, 1, 1)
        }
        setNeedsRedraw()
    }

    /// Frames the whole dataset, whatever shape the viewport currently is.
    ///
    /// - Parameter extent: The grid half-extent to fit.
    func frameAll(extent: Float) {
        camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: extent)
    }

    /// Multiplies the zoom about the centre.
    /// - Parameter factor: >1 magnifies.
    func zoom(by factor: Float) {
        guard factor.isFinite, factor > 0 else { return }
        camera.halfExtent /= factor
    }

    /// Pans by a gesture translation in points.
    ///
    /// Converts through the real viewport rather than a constant. The first version divided by a
    /// hardcoded 300, which is right only on a 600-point-wide view.
    ///
    /// - Parameter translation: The delta in points.
    func pan(by translation: CGSize) {
        let halfWidth = Float(max(1, viewportPoints.width / 2))
        let halfHeight = Float(max(1, viewportPoints.height / 2))
        camera.centre.x -= Float(translation.width) / halfWidth * scale.x
        camera.centre.y += Float(translation.height) / halfHeight * scale.y
    }

    /// Records the viewport so framing and panning use the real shape.
    ///
    /// This was an empty method, which is why the map was drawn stretched: the shader normalises by
    /// `scale` in both axes, so without the true aspect a wide viewport squashes the layout.
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        aspect = Float(size.width / size.height)
        #if os(macOS)
        let factor = view.window?.backingScaleFactor ?? 2
        #else
        let factor = view.contentScaleFactor
        #endif
        let points = max(factor, 1)
        viewportPoints = CGSize(width: size.width / points, height: size.height / points)
    }

    func draw(in view: MTKView) {
        #if DEBUG
        // The blank-macOS-surface probe, kept rather than deleted. Six candidate mechanisms were
        // reviewed and all six were refuted, so if the surface is ever blank again the next report
        // should be conclusive instead of another round of theories. It used to print one line every
        // ~2 seconds because frames came from a display link; now that the map draws on demand, 120
        // draws is however long it takes a reader to move the camera 120 times, and a probe that
        // never prints is itself the news.
        drawCallCount += 1
        if drawCallCount % 120 == 1 {
            print("[SemanticMapRenderer] draw view=\(ObjectIdentifier(view)) "
                  + "window=\(view.window != nil) bounds=\(view.bounds.size) "
                  + "drawable=\(view.drawableSize) delegateIsSelf=\(view.delegate === self) "
                  + "uploaded=\(uploadedPointCount) frame=\(drawCallCount)")
        }
        #endif

        // A view with no window is not the one the reader is looking at. SwiftUI can realize a
        // representable more than once — a macOS sheet is where this actually happens — and a
        // discarded view whose display link is still running would otherwise contribute phantom
        // frames to the statistics, making them describe a surface nobody can see.
        guard view.window != nil else { return }

        // NOTE the points are NOT part of this guard. `clearColor` is not something an MTKView
        // paints on its own: it is the `.clear` load action inside `currentRenderPassDescriptor`,
        // and it reaches the screen only if a pass is encoded and presented. Returning early with a
        // drawable in hand would leave the layer with NO CONTENTS — transparent, showing whatever is
        // behind it — which is exactly the white rectangle the macOS map presented, and it is
        // indistinguishable by eye from not being attached at all. Encoding an empty pass costs
        // nothing and makes "dark" mean attached-and-idle, "white" mean not-attached.
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let buffer = queue.makeCommandBuffer()
        else { return }

        var uniforms = Uniforms(
            centre: centre, scale: scale, pointSize: pointSize, alpha: 1.0)

        if let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) {
            if let pointBuffer, pointCount > 0 {
                encoder.setRenderPipelineState(pipeline)
                encoder.setVertexBuffer(pointBuffer, offset: 0, index: 0)
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.setVertexBuffer(paletteBuffer, offset: 0, index: 2)
                // ONE draw call for the entire corpus. If this is fast enough, the design's
                // level-of-detail machinery becomes an optimisation rather than a prerequisite.
                encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pointCount)
            }
            encoder.endEncoding()
        }

        // GPU timestamps, not wall time around `commit`: the command buffer has barely begun when
        // `commit` returns, so a CPU-side measurement here would report the encode cost and call it
        // the frame cost.
        // The completion handler runs on a Metal-owned thread, so the sample window is behind a
        // lock and only a value type crosses to the main actor — capturing `self` here is what
        // Swift 6 correctly refuses.
        let sink = statsSink
        buffer.addCompletedHandler { completed in
            let elapsed = (completed.gpuEndTime - completed.gpuStartTime) * 1000.0
            sink.record(elapsed)
        }
        buffer.present(drawable)
        buffer.commit()
    }

    /// Thread-safe accumulator for frame times.
    ///
    /// A final class behind a lock rather than an actor: `addCompletedHandler` is synchronous and on
    /// Metal's thread, and hopping to an actor per frame would measure the hop.
    final class StatsSink: @unchecked Sendable {
        private let lock = NSLock()
        private var samples: [Double] = []
        private var pointCount = 0
        private var presentedFrames = 0
        /// The last closed window's timings, republished until the next one closes.
        private var window: Stats?
        /// Called after every presented frame; assigned on the main actor before rendering starts.
        var onStats: (@Sendable @MainActor (Stats) -> Void)?

        /// Records the document count for the next published window.
        /// - Parameter count: Documents in the vertex buffer.
        func setPointCount(_ count: Int) {
            lock.lock(); pointCount = count; lock.unlock()
        }

        /// Folds one frame in and publishes.
        ///
        /// **Published on every frame, not every thirtieth**, since the map went on-demand. The old
        /// shape waited for a window of 30 samples to close, which was invisible under a 60 fps
        /// display link and is not now: a map the reader has looked at but not touched draws a
        /// handful of frames and then stops, so the overlay sat at "0 frames presented · 0.00 ms
        /// mean" over a surface that had plainly drawn — the exact reading the counter was added to
        /// prevent. The mean and worst are still over the last closed window of 30, so the figures
        /// stay as steady as they were; only the publish cadence changed.
        ///
        /// - Parameter milliseconds: The frame's GPU duration.
        func record(_ milliseconds: Double) {
            lock.lock()
            samples.append(milliseconds)
            presentedFrames += 1
            if samples.count >= 30 {
                window = Stats(
                    pointCount: pointCount,
                    frameMilliseconds: samples.reduce(0, +) / Double(samples.count),
                    worstMilliseconds: samples.max() ?? 0,
                    presentedFrames: presentedFrames)
                samples.removeAll(keepingCapacity: true)
            }
            // Before the first window closes there are no averages to report, so the frame times
            // read zero — and the frame count, which is the part that says "this surface is alive",
            // is current from frame one.
            var stats = window ?? Stats()
            stats.pointCount = pointCount
            stats.presentedFrames = presentedFrames
            let sink = onStats
            lock.unlock()
            guard let sink else { return }
            Task { @MainActor in sink(stats) }
        }
    }

    /// The point-sprite shader pair.
    ///
    /// `MapPoint` and `MapUniforms` here must match the Swift structs above field for field; there is
    /// no compiler checking that across the boundary, which is why both sides are in one file.
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct MapUniforms {
        float2 centre;
        float2 scale;
        float pointSize;
        float alpha;
    };

    struct MapPoint {
        short2 position;
        uchar colourIndex;
        uchar flags;
    };

    struct RasterPoint {
        float4 position [[position]];
        float pointSize [[point_size]];
        half4 colour;
    };

    vertex RasterPoint semanticMapVertex(
        uint vertexID [[vertex_id]],
        const device MapPoint *points [[buffer(0)]],
        constant MapUniforms &uniforms [[buffer(1)]],
        constant float4 *palette [[buffer(2)]]
    ) {
        MapPoint p = points[vertexID];
        float2 grid = float2(p.position);
        float2 view = (grid - uniforms.centre) / uniforms.scale;
        RasterPoint out;
        out.position = float4(view, 0.0, 1.0);
        out.pointSize = uniforms.pointSize;
        float4 colour = palette[p.colourIndex];
        out.colour = half4(half3(colour.rgb), half(colour.a * uniforms.alpha));
        return out;
    }

    // Round rather than square: a square point at small sizes reads as a pixel-grid artifact
    // rather than as a document, and the corpus view is mostly small points.
    fragment half4 semanticMapFragment(
        RasterPoint in [[stage_in]],
        float2 coordinate [[point_coord]]
    ) {
        float d = length(coordinate - float2(0.5));
        if (d > 0.5) { discard_fragment(); }
        half edge = half(smoothstep(0.5, 0.35, d));
        return half4(in.colour.rgb, in.colour.a * edge);
    }
    """

    /// A neutral palette for the spike: one colour, plus a spread for lens testing.
    static let defaultPalette: [SIMD4<Float>] = [
        SIMD4(0.42, 0.62, 0.90, 0.75),
        SIMD4(0.90, 0.52, 0.36, 0.75),
        SIMD4(0.45, 0.78, 0.52, 0.75),
        SIMD4(0.82, 0.71, 0.36, 0.75),
        SIMD4(0.70, 0.52, 0.86, 0.75),
        SIMD4(0.38, 0.76, 0.82, 0.75),
    ]
}
