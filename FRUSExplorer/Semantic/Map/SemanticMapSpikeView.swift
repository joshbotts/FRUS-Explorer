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

/// Owns the map's renderer and its load, outside SwiftUI's view update.
///
/// **This class exists because the first version drew nothing.** What is established from the source
/// and the console: the renderer was built inside `makeUIView`, which then performed two `@State`
/// writes during a view update — `renderer = made`, and then `unavailable = …` from an eager load
/// that ran before `BundledSemanticMap.prepare()` had and so found no map. That is two writes and the
/// console reported exactly two "Modifying state during view update" lines. Nothing was ever uploaded
/// and the screen stayed empty.
///
/// **Which of those two writes took effect is not determined**, and this comment deliberately does
/// not guess. SwiftUI documents a state write during a view update as undefined behaviour; a first
/// draft of this file asserted that the `.task` had "captured the view struct from before the
/// renderer was assigned" and therefore read `nil`, which is not how `@State` reads work — a `@State`
/// property reads through a SwiftUI-owned location, which is why ordinary `.task` and button-action
/// bodies see current values. Nor did the body swapping the surface out destroy the renderer: it was
/// held by the view's own `@State` and `MTKView.delegate` is `weak`, so the swap tore down the view
/// and nothing else. The honest statement is that the code invoked undefined behaviour and the map
/// never appeared; the fix removes the undefined behaviour rather than reasoning about which write
/// survived it.
///
/// The renderer does not need the `MTKView`; the `MTKView` needs the renderer. So it is built here,
/// on the main actor, from a `.task`, and the representable only attaches what already exists —
/// which may be nothing yet, which is why `attach(to:)` runs again on every update.
///
/// Extracting a plain class is what made the load testable: a test can hold one, drive `prepare()`,
/// and read the renderer back. (The two volume lookups are **closures rather than an `AppState`** for
/// ergonomics, not for testability — `AppState()` is default-constructible and the suite builds one
/// in dozens of places.)
///
/// Version history:
///   1.0 — V-4: extracted from the view after the blank-map defect
@MainActor
@Observable
final class SemanticMapModel {

    /// The renderer, once the device has been resolved.
    private(set) var renderer: SemanticMapRenderer?
    /// Why the map cannot be drawn, when it cannot.
    private(set) var unavailable: String?
    /// The most recent frame statistics.
    var stats = SemanticMapRenderer.Stats()
    /// Documents placed, for the overlay.
    private(set) var placedCount = 0

    /// The vector index, for the volume row ranges every lens but `cluster` fills.
    private var index: SemanticVectorIndex?
    /// Whether the points have been uploaded.
    private var isLoaded = false

    /// Creates an empty model.
    init() {}

    /// Builds the renderer and loads the bundled map. Idempotent.
    ///
    /// - Parameters:
    ///   - lens: The lens to colour the first frame by.
    ///   - eraForVolume: A volume's coverage era.
    ///   - isDownloaded: Whether a volume is indexed on this device.
    func prepare(
        lens: SemanticMapLens = .cluster,
        eraForVolume: (String) -> CoverageEra?,
        isDownloaded: (String) -> Bool
    ) async {
        if renderer == nil {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let made = SemanticMapRenderer(device: device) else {
                unavailable = String(localized: "semanticMap.noMetal",
                                     defaultValue: "This device has no Metal renderer.")
                return
            }
            made.onStats = { [weak self] measured in
                Task { @MainActor in self?.stats = measured }
            }
            renderer = made
        }
        guard !isLoaded, let renderer else { return }

        await BundledSemanticMap.prepare()
        guard let map = BundledSemanticMap.vectors,
              let vectorIndex = BundledSemanticVectors.index else {
            unavailable = Self.describe(BundledSemanticMap.unavailableReason ?? .pending)
            return
        }
        index = vectorIndex
        unavailable = nil

        // Positions come straight out of the mapped artifact; only the colour byte is computed,
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
        renderer.frameAll(extent: Float(map.gridExtent))
        placedCount = points.count
        isLoaded = true
        apply(lens: lens, eraForVolume: eraForVolume, isDownloaded: isDownloaded)
    }

    /// Recolours the map for a lens.
    ///
    /// - Parameters:
    ///   - lens: The lens to colour by.
    ///   - eraForVolume: A volume's coverage era.
    ///   - isDownloaded: Whether a volume is indexed on this device.
    func apply(
        lens: SemanticMapLens,
        eraForVolume: (String) -> CoverageEra?,
        isDownloaded: (String) -> Bool
    ) {
        guard let renderer, let map = BundledSemanticMap.vectors, let index else { return }
        let colours = SemanticMapColouring.indices(
            for: lens, map: map, index: index,
            eraForVolume: eraForVolume, isDownloaded: isDownloaded)
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
}

/// The corpus as a map of its own vocabulary.
///
/// Draws the bundled Tier-0 artifact — 314,483 documents placed by the layout stage, coloured by a
/// lens the reader picks. `#if DEBUG` until the surface earns its place in the app proper.
///
/// Version history:
///   1.0 — V-4a: initial spike
///   1.1 — V-4: reads the bundled artifact; renderer ownership moved to `SemanticMapModel` after
///         the map failed to appear at all
struct SemanticMapSpikeView: View {

    /// The app state, for the volume metadata every lens except `cluster` is computed from.
    let appState: AppState

    @State private var model = SemanticMapModel()
    @State private var lens: SemanticMapLens = .cluster
    @State private var zoom: Double = 1.0
    @State private var pan = CGSize.zero
    @State private var pointSize: Double = 2.0

    var body: some View {
        VStack(spacing: 0) {
            // The surface is ALWAYS present, and an unavailability is drawn OVER it rather than
            // replacing it. Not because a swap would destroy the renderer — it would not, the model
            // owns it — but because a transient or premature unavailable state would otherwise tear
            // down the drawable and rebuild it, which is exactly the churn the old shape produced.
            SemanticMapSurface(model: model)
                .overlay(alignment: .topLeading) { statsOverlay }
                .overlay { unavailableOverlay }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            model.renderer?.pan(by: CGSize(
                                width: value.translation.width - pan.width,
                                height: value.translation.height - pan.height))
                            pan = value.translation
                        }
                        .onEnded { _ in pan = .zero })
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            model.renderer?.zoom(by: Float(value.magnification / zoom))
                            zoom = value.magnification
                        }
                        .onEnded { _ in zoom = 1.0 })
            controls
        }
        .navigationTitle(String(localized: "semanticMap.title", defaultValue: "Semantic Map"))
        .task {
            await model.prepare(lens: lens, eraForVolume: eraForVolume,
                                isDownloaded: isDownloaded)
            // Re-apply after the await. `model.apply` refuses until the index has loaded, so a lens
            // the reader picks *during* the load is otherwise dropped and then overwritten by
            // whatever `prepare` was started with.
            model.apply(lens: lens, eraForVolume: eraForVolume, isDownloaded: isDownloaded)
        }
    }

    /// A volume's coverage era, from the manifest.
    /// - Parameter volumeID: The volume.
    /// - Returns: Its era, when the manifest knows one.
    private func eraForVolume(_ volumeID: String) -> CoverageEra? {
        appState.manifestStore.eraForVolume(volumeID)
    }

    /// Whether a volume is indexed on this device.
    /// - Parameter volumeID: The volume.
    /// - Returns: `true` when the reader can open it.
    private func isDownloaded(_ volumeID: String) -> Bool {
        appState.indexedVolumeIds.contains(volumeID)
    }

    /// Frame statistics, for judging the renderer while the surface is still experimental.
    ///
    /// **No `String(format:)` here, and the reason is a Swift trap worth carrying elsewhere.**
    ///
    /// The first version filled the console with
    /// `String(format:locale:arguments:): Provided argument types ["Swift.Int"] (with inferred
    /// specifiers ["%lld"]) do not match the format string's specifiers … Format '%.0f fps
    /// equivalent' does not match expected '%lld'`. Both halves came from one line:
    ///
    /// ```swift
    /// String(format: "%.0f fps equivalent", ms > 0 ? 1000 / ms : 0)   // ms is a Double
    /// ```
    ///
    /// Under a `CVarArg...` parameter the ternary's branches are erased to the existential
    /// **independently**, so the bare literal `0` takes its default type `Int` — verified by running
    /// it: a `CVarArg...` probe prints `Int` when `ms == 0` and `Double` otherwise. So the argument
    /// really was an `Int` against a `%f`, and it fired only while `frameMilliseconds` was still 0,
    /// i.e. the frames before `StatsSink` publishes its first 30-sample window — which is why there
    /// were about nine and then no more. `LocalizedStringKey` was never involved: `Text("\(count)
    /// points")` builds the key `%lld points` and matches its own `Int`.
    ///
    /// A first draft of this comment said the diagnostic paired a format string from one line with an
    /// argument from another and that the mechanism could not be reproduced. Both were wrong, and the
    /// general rule this leaves is checkable: **`cond ? someDouble : 0` under `CVarArg` is an `Int`
    /// half the time.** `FloatingPointFormatStyle` takes no varargs, so it cannot recur here.
    private var statsOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "\(model.placedCount) documents")
            Text(verbatim: "\(Self.milliseconds(model.stats.frameMilliseconds)) ms mean · "
                 + "\(Self.milliseconds(model.stats.worstMilliseconds)) ms worst")
            Text(verbatim: Self.framesPerSecond(model.stats.frameMilliseconds))
        }
        .font(.caption2.monospacedDigit())
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .padding(8)
    }

    /// Renders a frame time to two places.
    /// - Parameter value: The duration in milliseconds.
    /// - Returns: The formatted number, with no unit.
    private static func milliseconds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    /// Renders a frame time as its frame-rate equivalent.
    /// - Parameter value: The mean frame duration in milliseconds.
    /// - Returns: The rate, or a dash before any frame has been measured.
    private static func framesPerSecond(_ value: Double) -> String {
        guard value > 0 else { return "—" }
        let rate = (1000 / value).formatted(.number.precision(.fractionLength(0)))
        return "\(rate) fps equivalent"
    }

    /// The message shown when there is nothing to draw.
    @ViewBuilder
    private var unavailableOverlay: some View {
        if let message = model.unavailable {
            ContentUnavailableView(
                String(localized: "semanticMap.unavailable", defaultValue: "Map unavailable"),
                systemImage: "map",
                description: Text(message))
            .background(.regularMaterial)
        }
    }

    /// The lens picker and point size.
    ///
    /// A plain stack rather than a `Form`. A grouped `Form` capped at `maxHeight: 130` is a scroll
    /// view whose section insets consume most of that budget, and on an iPhone it rendered as an
    /// **empty card with both controls below the fold** — the map drew correctly and there was no way
    /// to change the lens. Measured on an iPhone 17: this stack is about 100 points and both controls
    /// are on screen.
    private var controls: some View {
        VStack(spacing: 10) {
            Picker(String(localized: "semanticMap.lens", defaultValue: "Colour by"),
                   selection: $lens) {
                ForEach(SemanticMapLens.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            // Hidden visually, kept for VoiceOver: the segments name themselves, and a leading
            // "Colour by" label would push the segmented control into an unusable width.
            .labelsHidden()
            .onChange(of: lens) { _, value in
                model.apply(lens: value, eraForVolume: eraForVolume,
                            isDownloaded: isDownloaded)
            }

            HStack(spacing: 12) {
                Text(String(localized: "semanticMap.pointSize", defaultValue: "Point size"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $pointSize, in: 1...8, step: 0.5)
                    .onChange(of: pointSize) { _, size in model.renderer?.pointSize = Float(size) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

}

/// Bridges `MTKView` into SwiftUI on both platforms.
///
/// Creates no state and owns no renderer: it attaches the one the model already built. That is the
/// whole fix for the blank map — a representable that builds and publishes state during
/// `makeNSView`/`makeUIView` is writing to SwiftUI mid-update, which is undefined behaviour.
///
/// `makeMap()` normally runs *before* the model's `.task` has produced anything, so it attaches
/// nothing and `updateNSView`/`updateUIView` is the path that actually connects the renderer. Those
/// two one-line forwarders are the only part of this file a test cannot drive — `Context` is not
/// constructible — so the suite exercises `attach(to:)` directly and this comment is the record that
/// the forwarding itself is unverified.
struct SemanticMapSurface {

    /// The model holding the renderer.
    let model: SemanticMapModel

    /// Builds the view and attaches the renderer if one already exists.
    ///
    /// The device is set here even when there is no renderer yet, rather than left to `attach`. An
    /// `MTKView` with no device has no drawable and no layer to configure, and the whole point of
    /// this shape is that the surface is created before the model's `.task` has run.
    @MainActor
    func makeMap() -> MTKView {
        let view = MTKView()
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        // Must equal the format the pipeline was built for. Nothing in the compiler links the two,
        // so both sides read one constant and a test asserts they agree.
        view.colorPixelFormat = SemanticMapRenderer.pixelFormat
        view.clearColor = MTLClearColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        view.device = model.renderer?.device ?? MTLCreateSystemDefaultDevice()
        attach(to: view)
        return view
    }

    /// Attaches the renderer once the model has one.
    /// - Parameter view: The view to attach to.
    @MainActor
    func attach(to view: MTKView) {
        guard let renderer = model.renderer, view.delegate !== renderer else { return }
        view.device = renderer.device
        view.delegate = renderer
    }
}

#if os(macOS)
extension SemanticMapSurface: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView { makeMap() }
    func updateNSView(_ nsView: MTKView, context: Context) { attach(to: nsView) }
}
#else
extension SemanticMapSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView { makeMap() }
    func updateUIView(_ uiView: MTKView, context: Context) { attach(to: uiView) }
}
#endif
