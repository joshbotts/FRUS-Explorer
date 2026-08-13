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

import SwiftUI
import MetalKit
import simd

/// The V-4a rendering spike, as a screen you can open and drag.
///
/// **This is a measurement, not a feature.** It answers one question — whether a single Metal draw
/// call can hold the whole corpus at interactive frame rates — because the design budgets level-of-
/// detail machinery on the assumption that it cannot, and that machinery is most of V-4's cost. It
/// is `#if DEBUG` and reachable only from the diagnostics section for that reason.
///
/// ## Where its points come from
///
/// **Not from a bundled artifact, deliberately.** Tier 0's real layout needs the UMAP/HDBSCAN stage
/// that has not run, and shipping a placeholder layout into `Resources` would put a file in the app
/// that looks like the measured thing and is not. Instead it reads a raw `int16` pair-per-document
/// file from a path the developer supplies, and falls back to a synthetic cloud so the renderer can
/// still be exercised on a machine with no data. The synthetic case says so on screen.
///
/// Version history:
///   1.0 — V-4a: initial spike
struct SemanticMapSpikeView: View {

    /// Where a real coordinate file may be found; empty uses the synthetic cloud.
    @AppStorage("frus.semanticMap.spikeCoordsPath") private var coordsPath = ""

    @State private var renderer: SemanticMapRenderer?
    /// The renderer publishes into this from its own thread; `@State` on a struct cannot be
    /// captured by a `@Sendable` closure, and an observable reference can.
    @State private var statsBox = MapStatsBox()
    @State private var isSynthetic = true
    @State private var extent: Float = 32_768
    @State private var zoom: Double = 1.0
    @State private var pan = CGSize.zero
    @State private var pointSize: Double = 2.0
    @State private var unavailable: String?

    var body: some View {
        VStack(spacing: 0) {
            if let unavailable {
                ContentUnavailableView(
                    String(localized: "semanticMap.unavailable",
                           defaultValue: "Metal unavailable"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(unavailable))
            } else {
                mapSurface
            }
            controls
        }
        .navigationTitle(String(localized: "semanticMap.title",
                                defaultValue: "Semantic Map (spike)"))
    }

    /// The Metal surface plus its live statistics.
    private var mapSurface: some View {
        SemanticMapSurface(
            renderer: $renderer,
            onCreate: { made in
                load(into: made)
            })
        .overlay(alignment: .topLeading) { statsOverlay }
        .gesture(
            DragGesture()
                .onChanged { value in
                    apply(pan: CGSize(width: value.translation.width - pan.width,
                                      height: value.translation.height - pan.height))
                    pan = value.translation
                }
                .onEnded { _ in pan = .zero })
        .gesture(
            MagnifyGesture()
                .onChanged { value in apply(zoomFactor: Float(value.magnification / zoom))
                                      zoom = value.magnification }
                .onEnded { _ in zoom = 1.0 })
    }

    /// The numbers this screen exists to produce.
    private var statsOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            let stats = statsBox.latest
            Text("\(stats.pointCount) points")
            Text(String(format: "%.2f ms mean · %.2f ms worst",
                        stats.frameMilliseconds, stats.worstMilliseconds))
            Text(String(format: "%.0f fps equivalent",
                        stats.frameMilliseconds > 0 ? 1000 / stats.frameMilliseconds : 0))
            if isSynthetic {
                Text("synthetic cloud — not corpus data")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption2.monospacedDigit())
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .padding(8)
    }

    /// Point size and the data-source field.
    private var controls: some View {
        Form {
            LabeledContent(String(localized: "semanticMap.pointSize", defaultValue: "Point size")) {
                Slider(value: $pointSize, in: 1...8, step: 0.5)
                    .onChange(of: pointSize) { _, size in
                        renderer?.pointSize = Float(size)
                    }
            }
            TextField(
                String(localized: "semanticMap.coordsPath", defaultValue: "int16 coords file"),
                text: $coordsPath)
            .font(.caption.monospaced())
            Button(String(localized: "semanticMap.reload", defaultValue: "Reload Points")) {
                if let renderer { load(into: renderer) }
            }
        }
        .formStyle(.grouped)
        .frame(maxHeight: 190)
    }

    /// Loads coordinates into a renderer, from disk when a path is set and synthetically otherwise.
    ///
    /// - Parameter renderer: The renderer to fill.
    private func load(into renderer: SemanticMapRenderer) {
        let points: [SemanticMapRenderer.MapPoint]
        if let disk = Self.loadCoordinates(atPath: coordsPath) {
            points = disk
            isSynthetic = false
        } else {
            points = Self.syntheticCloud(count: 314_483)
            isSynthetic = true
        }
        let box = statsBox
        renderer.onStats = { measured in box.latest = measured }
        renderer.setPoints(points)
        renderer.pointSize = Float(pointSize)
        extent = 32_768
        renderer.frameAll(extent: extent, aspect: 1)
        statsBox.latest.pointCount = points.count
    }

    /// Pans the camera by a screen-space delta.
    /// - Parameter pan: The delta in points.
    private func apply(pan: CGSize) {
        guard let renderer else { return }
        renderer.centre.x -= Float(pan.width) / 300 * renderer.scale.x
        renderer.centre.y += Float(pan.height) / 300 * renderer.scale.y
    }

    /// Zooms about the centre.
    /// - Parameter zoomFactor: Multiplicative zoom; >1 magnifies.
    private func apply(zoomFactor: Float) {
        guard let renderer, zoomFactor.isFinite, zoomFactor > 0 else { return }
        renderer.scale /= zoomFactor
    }

    /// Reads a raw `int16` x/y pair per document.
    ///
    /// - Parameter path: File path; empty or unreadable yields `nil`.
    /// - Returns: Points with a lens colour derived from position, so the spike shows more than one
    ///   colour without pretending to carry a real lens.
    static func loadCoordinates(atPath path: String) -> [SemanticMapRenderer.MapPoint]? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = try? Data(contentsOf: URL(fileURLWithPath: trimmed)),
              data.count >= 4
        else { return nil }
        let count = data.count / 4
        return data.withUnsafeBytes { raw -> [SemanticMapRenderer.MapPoint] in
            (0..<count).map { index in
                let x = raw.loadUnaligned(fromByteOffset: index * 4, as: Int16.self)
                let y = raw.loadUnaligned(fromByteOffset: index * 4 + 2, as: Int16.self)
                return SemanticMapRenderer.MapPoint(
                    position: SIMD2<Int16>(x, y),
                    colourIndex: UInt8(abs(Int(x) / 6000) % 6),
                    flags: 0)
            }
        }
    }

    /// A deterministic synthetic cloud, for a machine with no coordinate file.
    ///
    /// Six gaussian-ish blobs rather than a uniform field, because uniform points are the *easy*
    /// case for a renderer and a real embedding layout is clumped.
    ///
    /// - Parameter count: How many points to make.
    /// - Returns: The points.
    static func syntheticCloud(count: Int) -> [SemanticMapRenderer.MapPoint] {
        var state: UInt64 = 18_610_810
        func next() -> Float {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return Float(state % 10_000) / 10_000
        }
        return (0..<count).map { index in
            let cluster = index % 6
            let angle = Float(cluster) / 6 * 2 * .pi
            let cx = cos(angle) * 15_000, cy = sin(angle) * 15_000
            let spread: Float = 6_000
            let x = cx + (next() - 0.5) * spread + (next() - 0.5) * spread
            let y = cy + (next() - 0.5) * spread + (next() - 0.5) * spread
            return SemanticMapRenderer.MapPoint(
                position: SIMD2<Int16>(Int16(clamping: Int(x)), Int16(clamping: Int(y))),
                colourIndex: UInt8(cluster), flags: 0)
        }
    }
}

/// Holds the renderer's most recent frame statistics for the overlay.
///
/// `@Observable` and `@MainActor` so the renderer's `@Sendable` publish closure can hop into it
/// without capturing the SwiftUI view.
@MainActor @Observable
final class MapStatsBox {
    /// The most recent published window.
    var latest = SemanticMapRenderer.Stats()
    /// Creates an empty box.
    init() {}
}

/// Bridges `MTKView` into SwiftUI on both platforms.
struct SemanticMapSurface {

    @Binding var renderer: SemanticMapRenderer?
    let onCreate: (SemanticMapRenderer) -> Void

    /// Builds the view and its renderer.
    @MainActor
    func makeMap() -> MTKView {
        let view = MTKView()
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        guard let device = MTLCreateSystemDefaultDevice(),
              let made = SemanticMapRenderer(device: device) else { return view }
        view.device = device
        view.delegate = made
        // `makeNSView`/`makeUIView` already run on the main actor, so this needs no hop — and a
        // `Task` here would capture the non-Sendable binding, which Swift 6 correctly refuses.
        renderer = made
        onCreate(made)
        return view
    }
}

#if os(macOS)
extension SemanticMapSurface: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView { makeMap() }
    func updateNSView(_ nsView: MTKView, context: Context) {}
}
#else
extension SemanticMapSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView { makeMap() }
    func updateUIView(_ uiView: MTKView, context: Context) {}
}
#endif
