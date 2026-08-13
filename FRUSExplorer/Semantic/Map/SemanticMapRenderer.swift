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

/// The V-4a spike: can one draw call put the whole corpus on screen?
///
/// The design (`Vector-Embeddings-Semantic-Design.md` §6.3) budgets the discovery map's rendering as
/// "the one place this workstream buys new rendering machinery — budget it honestly (it is a session,
/// not an afternoon)", and specifies **Metal with level-of-detail** on the grounds that SwiftUI
/// `Canvas` degrades past ~20–50k points and the corpus is 6–15× that. This exists to test the first
/// half of that claim before any of the interaction design is built on top of it.
///
/// ## What it does
///
/// Uploads every document's int16 grid position once — 4 bytes each, 1.26 MB for the corpus — and
/// then moves only the camera. Points are drawn as round sprites in a single instanced draw call;
/// colour is a palette *index* per point, so switching lens rewrites 314 KB rather than 5 MB and the
/// palette can follow the theme without touching positions.
///
/// ## What it deliberately does not do yet
///
/// No density layer, no clustering, no labels, no picking. The spike's question is whether the naive
/// path is fast enough to make level-of-detail an optimisation rather than a prerequisite — and the
/// answer determines how much of §6.3's machinery V-4 actually needs. Measure first.
///
/// Version history:
///   1.0 — V-4a: initial spike
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

    /// Rolling frame statistics — the spike's actual output.
    struct Stats: Sendable, Equatable {
        /// Documents in the vertex buffer.
        var pointCount: Int = 0
        /// Mean GPU frame time over the recent window, in milliseconds.
        var frameMilliseconds: Double = 0
        /// Worst frame in the recent window.
        var worstMilliseconds: Double = 0
    }

    /// Called on the main actor whenever the statistics window rolls over.
    var onStats: (@Sendable @MainActor (Stats) -> Void)? {
        get { statsSink.onStats }
        set { statsSink.onStats = newValue }
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var pointBuffer: MTLBuffer?
    private var paletteBuffer: MTLBuffer
    private var pointCount = 0

    /// Camera state, driven by the view's gestures.
    var centre = SIMD2<Float>(0, 0)
    /// Grid units per screen point. Set from the data's extent on first load.
    var scale = SIMD2<Float>(32_768, 32_768)
    /// Sprite size in pixels.
    var pointSize: Float = 2.0

    /// Accumulates GPU frame times off the main actor and publishes a value type when the window
    /// rolls over. GPU-reported timestamps are the honest measure; CPU wall time around `commit` is
    /// not, because the command buffer has barely started when `commit` returns.
    private let statsSink = StatsSink()

    /// Creates the renderer, compiling the pipeline from the app bundle's default library.
    ///
    /// - Parameter device: The Metal device to render with.
    /// - Returns: `nil` when the device has no command queue or the shaders are missing — the caller
    ///   shows an unavailable state rather than crashing, because a simulator or a stripped build
    ///   are both real conditions.
    init?(device: MTLDevice) {
        // Compiled from source at runtime rather than from a `.metal` file in the target.
        //
        // A build-time shader needs the Metal toolchain component installed, which this spike does
        // not justify: its whole purpose is to produce one measurement, and a several-gigabyte
        // developer download is a strange prerequisite for finding out whether a draw call is fast.
        // Runtime compilation costs a few milliseconds once at startup and keeps the shader beside
        // the code that binds its buffers. If the map ships, this moves to a `.metal` file and the
        // toolchain becomes a deliberate decision rather than a precondition for measuring.
        guard let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
              let vertexFunction = library.makeFunction(name: "semanticMapVertex"),
              let fragmentFunction = library.makeFunction(name: "semanticMapFragment")
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // Additive-over-alpha blending: overlapping documents accumulate into a brighter region,
        // which is what makes density legible without a separate heat layer.
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor),
              let palette = device.makeBuffer(
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
        statsSink.setPointCount(points.count)
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
    }

    /// Frames the whole dataset in the view.
    ///
    /// - Parameters:
    ///   - extent: The grid half-extent to fit.
    ///   - aspect: Viewport width divided by height.
    func frameAll(extent: Float, aspect: Float) {
        centre = SIMD2<Float>(0, 0)
        scale = aspect >= 1
            ? SIMD2<Float>(extent * aspect, extent)
            : SIMD2<Float>(extent, extent / aspect)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let buffer = queue.makeCommandBuffer(),
              let pointBuffer, pointCount > 0
        else { return }

        var uniforms = Uniforms(
            centre: centre, scale: scale, pointSize: pointSize, alpha: 1.0)

        if let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(pointBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setVertexBuffer(paletteBuffer, offset: 0, index: 2)
            // ONE draw call for the entire corpus. If this is fast enough, the design's
            // level-of-detail machinery becomes an optimisation rather than a prerequisite.
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pointCount)
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
        /// Published when a window closes; assigned on the main actor before rendering starts.
        var onStats: (@Sendable @MainActor (Stats) -> Void)?

        /// Records the document count for the next published window.
        /// - Parameter count: Documents in the vertex buffer.
        func setPointCount(_ count: Int) {
            lock.lock(); pointCount = count; lock.unlock()
        }

        /// Folds one frame in, publishing when the window rolls over.
        /// - Parameter milliseconds: The frame's GPU duration.
        func record(_ milliseconds: Double) {
            lock.lock()
            samples.append(milliseconds)
            guard samples.count >= 30 else { lock.unlock(); return }
            let stats = Stats(
                pointCount: pointCount,
                frameMilliseconds: samples.reduce(0, +) / Double(samples.count),
                worstMilliseconds: samples.max() ?? 0)
            samples.removeAll(keepingCapacity: true)
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
