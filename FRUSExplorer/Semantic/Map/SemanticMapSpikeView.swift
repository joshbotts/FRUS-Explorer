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
/// The **bundled Tier-0 artifact** — `semantic-map.bin`, 314,483 placements produced by the layout
/// stage and packed by `SemanticVectorsGenerator`. Earlier it read a developer-supplied file, because
/// the layout did not exist yet and bundling a placeholder would have put a file in the app that
/// looked like the measured thing and was not. That file now exists, so the fallback is gone: a
/// device with no map says so rather than drawing something invented.
///
/// Version history:
///   1.0 — V-4a: initial spike
struct SemanticMapSpikeView: View {

    /// The app state, for the volume metadata every lens except `cluster` is computed from.
    let appState: AppState

    /// Which lens the colours mean.
    @State private var lens: SemanticMapLens = .cluster

    @State private var renderer: SemanticMapRenderer?
    /// The renderer publishes into this from its own thread; `@State` on a struct cannot be
    /// captured by a `@Sendable` closure, and an observable reference can.
    @State private var statsBox = MapStatsBox()
    @State private var extent: Float = 32_768
    @State private var zoom: Double = 1.0
    @State private var pan = CGSize.zero
    @State private var pointSize: Double = 2.0
    @State private var unavailable: String?
    /// The vector index, for volume row ranges the lenses fill.
    @State private var index: SemanticVectorIndex?

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
        .navigationTitle(String(localized: "semanticMap.title", defaultValue: "Semantic Map"))
        .task {
            await BundledSemanticMap.prepare()
            if let renderer { load(into: renderer) }
        }
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
        }
        .font(.caption2.monospacedDigit())
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .padding(8)
    }

    /// The lens picker, the legend, and point size.
    private var controls: some View {
        Form {
            Picker(String(localized: "semanticMap.lens", defaultValue: "Colour by"),
                   selection: $lens) {
                ForEach(SemanticMapLens.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: lens) { _, _ in applyLens() }

            LabeledContent(String(localized: "semanticMap.pointSize", defaultValue: "Point size")) {
                Slider(value: $pointSize, in: 1...8, step: 0.5)
                    .onChange(of: pointSize) { _, size in renderer?.pointSize = Float(size) }
            }
        }
        .formStyle(.grouped)
        .frame(maxHeight: 140)
    }

    /// Loads the bundled map into a renderer.
    ///
    /// - Parameter renderer: The renderer to fill.
    private func load(into renderer: SemanticMapRenderer) {
        guard let map = BundledSemanticMap.vectors,
              let index = BundledSemanticVectors.index
        else {
            unavailable = Self.describe(BundledSemanticMap.unavailableReason ?? .pending)
            return
        }
        unavailable = nil

        // Positions are read straight out of the mapped artifact; only the colour byte is computed,
        // which is why switching lens later rewrites 314 KB and never touches a coordinate.
        var points = [SemanticMapRenderer.MapPoint]()
        points.reserveCapacity(map.documentCount)
        map.withPlacements { base, count in
            for row in 0..<count {
                let offset = row * SemanticMapArtifacts.bytesPerDocument
                points.append(SemanticMapRenderer.MapPoint(
                    position: SIMD2<Int16>(
                        Int16(bitPattern: base.loadUnaligned(
                            fromByteOffset: offset, as: UInt16.self).littleEndian),
                        Int16(bitPattern: base.loadUnaligned(
                            fromByteOffset: offset + 2, as: UInt16.self).littleEndian)),
                    colourIndex: 0, flags: 0))
            }
        }
        renderer.setPoints(points)
        renderer.pointSize = Float(pointSize)
        extent = Float(map.gridExtent)
        renderer.frameAll(extent: extent, aspect: 1)
        self.index = index
        applyLens()
    }

    /// Recolours the map for the active lens.
    private func applyLens() {
        guard let renderer, let map = BundledSemanticMap.vectors, let index else { return }
        let downloaded = appState.indexedVolumeIds
        let colours = SemanticMapColouring.indices(
            for: lens, map: map, index: index,
            eraForVolume: { appState.manifestStore.eraForVolume($0) },
            isDownloaded: { downloaded.contains($0) })
        renderer.setPalette(SemanticMapColouring.palette(for: lens))
        renderer.setColourIndices(colours)
    }

    /// Turns an unavailability into a sentence a reader can act on.
    /// - Parameter reason: Why the map is unavailable.
    /// - Returns: The message.
    static func describe(_ reason: SemanticUnavailable) -> String {
        switch reason {
        case .pending:
            return String(localized: "semanticMap.pending", defaultValue: "Loading the map…")
        case .noArtifact:
            return String(localized: "semanticMap.noArtifact",
                          defaultValue: "This build does not carry the semantic map.")
        case .provenanceMismatch:
            return String(localized: "semanticMap.mismatch",
                          defaultValue: """
                              The map and the vectors come from different releases, so the map is \
                              not being drawn.
                              """)
        default:
            return String(localized: "semanticMap.malformed",
                          defaultValue: "The semantic map could not be read.")
        }
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
