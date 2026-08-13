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
/// on the main actor — **synchronously, in `init`** — and the representable attaches it the moment it
/// creates a view.
///
/// **The macOS cause was the SwiftUI `.sheet`, confirmed by observation**: moving this screen into
/// its own `Window` scene made the map appear, with nothing else changed. A Metal layer hosted in a
/// SwiftUI sheet on macOS draws and presents — a faithful reproduction logged the `MTKView` attached,
/// sized, in `SheetPresentationWindow`, presenting 600 frames at a clean 60 fps — and none of it
/// reaches the screen. **Do not put an `MTKView` in a SwiftUI sheet on macOS.**
///
/// Two things about how that was found are worth keeping, because the failure was in the diagnosing
/// rather than the code. Nineteen candidate mechanisms were reviewed adversarially and every one was
/// refuted, including two of mine; the sheet hypothesis survived only as the last one standing and
/// was settled by *looking*, not by argument. And the symptom was unreadable until `draw(in:)`
/// started encoding an empty pass: `clearColor` is not a property the view paints — it is the
/// `.clear` load action inside `currentRenderPassDescriptor` — so an unpresented layer has no
/// contents at all and composites transparent. White meant nothing reached the screen; dark means
/// attached-and-idle. Without that distinction a screenshot could not tell the two apart, which is
/// what made three confident explanations survive as long as they did.
///
/// Building the renderer in `init` is kept and is independently sound — a renderer that arrives after
/// the last `update*View` could never be attached — but it was **not** the macOS cause.
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
    /// The regions the artifact names, for the label layer.
    private(set) var clusters: [SemanticMapArtifacts.Cluster] = []

    /// The document the reader last tapped, if any.
    private(set) var selection: SemanticMapPicking.Selection?

    /// Where the camera is looking, mirrored out of the renderer.
    ///
    /// The renderer is not `@Observable` — it is driven by a display link and must not publish per
    /// frame — so gestures go through `pan`/`zoom` here, which move the camera and republish it. That
    /// is what makes the labels follow the map instead of sitting where they were when it loaded.
    private(set) var camera = SemanticMapCamera()

    /// The vector index, for the volume row ranges every lens but `cluster` fills.
    private var index: SemanticVectorIndex?
    /// Whether the points have been uploaded.
    private var isLoaded = false

    /// Creates the model and its renderer.
    ///
    /// The renderer is built here rather than in `prepare()` so that no view can ever be created
    /// before it exists. Costs one `MTLCreateSystemDefaultDevice()` and one runtime shader
    /// compilation — a few milliseconds, once, against a surface that would otherwise be silently
    /// blank on macOS.
    init() {
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

    /// Loads the bundled map into the renderer. Idempotent.
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
        camera = renderer.camera
        clusters = BundledSemanticMap.index?.clusters ?? []
        placedCount = points.count
        isLoaded = true
        apply(lens: lens, eraForVolume: eraForVolume, isDownloaded: isDownloaded)
    }

    /// Selects the document nearest a tap, or clears the selection when the tap found nothing.
    ///
    /// - Parameters:
    ///   - point: Where the reader tapped, in view points.
    ///   - size: The view's size in points.
    ///   - isReadable: Whether a volume's XML is on disk — **not** whether it is indexed. The two
    ///     are different gates and this one is the one that matters: on iOS, opening a document
    ///     whose volume is absent leaves `DocumentView` on "Opening document…" forever with no
    ///     error, so a wrong answer here is a dead end rather than a message. A volume that is
    ///     downloaded but not yet indexed reads perfectly well.
    func select(at point: CGPoint, size: CGSize, isReadable: (String) -> Bool) {
        guard let map = BundledSemanticMap.vectors, let index else { return }
        guard let hit = SemanticMapPicking.hit(
            at: point, map: map, camera: camera, size: size) else {
            selection = nil
            return
        }
        guard let document = index.document(at: hit.row) else {
            // A row the artifact places but cannot name is a keying failure, not an empty tap, and
            // saying so is better than silently selecting nothing.
            selection = nil
            #if DEBUG
            print("[SemanticMapModel] row \(hit.row) has a placement but no document id")
            #endif
            return
        }
        let region = clusters.first { $0.id == Int(hit.cluster) }
        selection = SemanticMapPicking.Selection(
            row: hit.row,
            volumeID: document.volumeID,
            documentID: document.documentID,
            position: hit.position,
            regionName: region.map { $0.terms.prefix(3).joined(separator: " ") },
            isDownloaded: isReadable(document.volumeID))
    }

    /// Clears the selection.
    func clearSelection() { selection = nil }

    /// Pans the camera by a gesture translation in points.
    /// - Parameter translation: The delta since the last change.
    func pan(by translation: CGSize) {
        guard let renderer else { return }
        renderer.pan(by: translation)
        camera = renderer.camera
    }

    /// Zooms about the centre.
    /// - Parameter factor: >1 magnifies.
    func zoom(by factor: Float) {
        guard let renderer else { return }
        renderer.zoom(by: factor)
        camera = renderer.camera
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
    /// The surface's size, which picking needs and a gesture does not carry.
    @State private var surfaceSize = CGSize.zero
    #if os(iOS)
    /// The document to push, when the reader opens one.
    @State private var openedDocument: DocumentBrowserEntry?
    #endif
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        VStack(spacing: 0) {
            // The surface is ALWAYS present, and an unavailability is drawn OVER it rather than
            // replacing it. Not because a swap would destroy the renderer — it would not, the model
            // owns it — but because a transient or premature unavailable state would otherwise tear
            // down the drawable and rebuild it, which is exactly the churn the old shape produced.
            // The card is a SIBLING of the gestured surface, not an overlay on it — and that is a
            // fix, not a preference. As an overlay it sat inside the view the tap/drag gestures are
            // attached to, so the surface's `SpatialTapGesture` swallowed the Open button: the
            // button highlighted and nothing opened. A sibling in the ZStack gets its own hits.
            ZStack(alignment: .bottomLeading) {
                SemanticMapSurface(model: model)
                    .overlay { labelOverlay }
                    .overlay { selectionMarker }
                    .overlay(alignment: .topLeading) { statsOverlay }
                    .overlay { unavailableOverlay }
                    // Before the drag gesture, so a tap is a tap and a drag is still a pan.
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                model.select(at: value.location, size: surfaceSize,
                                             isReadable: isReadable)
                            })
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { surfaceSize = $0 }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                model.pan(by: CGSize(
                                    width: value.translation.width - pan.width,
                                    height: value.translation.height - pan.height))
                                pan = value.translation
                            }
                            .onEnded { _ in pan = .zero })
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                model.zoom(by: Float(value.magnification / zoom))
                                zoom = value.magnification
                            }
                            .onEnded { _ in zoom = 1.0 })
                selectionCard
            }
            controls
        }
        .navigationTitle(String(localized: "semanticMap.title", defaultValue: "Semantic Map"))
        #if os(iOS)
        // The map is pushed inside the Settings stack, which carries no document destination of its
        // own. macOS opens a real document window instead and needs none.
        .navigationDestination(item: $openedDocument) { entry in
            DocumentView(entry: entry)
        }
        #endif
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

    /// Whether a volume is indexed on this device — the `availability` lens's question.
    /// - Parameter volumeID: The volume.
    /// - Returns: `true` when the volume is in the search index.
    private func isDownloaded(_ volumeID: String) -> Bool {
        appState.indexedVolumeIds.contains(volumeID)
    }

    /// Whether a volume's XML is on disk — the question that decides whether a tap can open it.
    ///
    /// **Deliberately a different gate from `isDownloaded`.** Reading a document needs the file;
    /// being in the search index is a later, separate step. A volume downloaded but not yet indexed
    /// reads perfectly well, and gating the Open button on the index would refuse it. The colour
    /// lens keeps its own question — that one really is about the index.
    ///
    /// Before boot completes there is no `downloadManager` and nothing is readable, which is honest
    /// rather than conservative: opening would fail then too.
    ///
    /// - Parameter volumeID: The volume.
    /// - Returns: `true` when the document can actually be opened.
    private func isReadable(_ volumeID: String) -> Bool {
        appState.downloadManager?.isVolumeDownloaded(volumeID) ?? false
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
            // The running total is here because the averages alone could not tell a live surface
            // from one that drew thirty frames and stopped — which is exactly the ambiguity the
            // blank macOS map hid behind.
            Text(verbatim: "\(model.stats.presentedFrames) frames presented")
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

    /// The names of the regions, drawn over the points.
    ///
    /// SwiftUI text rather than glyphs in the Metal pass: two dozen labels are nothing to lay out,
    /// they inherit Dynamic Type and the theme for free, and a text renderer in the shader would be
    /// a second typography stack to keep honest. If the label count ever grows past what SwiftUI can
    /// place in a frame, that is the moment to reconsider — not before.
    @ViewBuilder
    private var labelOverlay: some View {
        GeometryReader { proxy in
            let labels = SemanticMapLabelLayout.labels(
                for: model.clusters, camera: model.camera, size: proxy.size)
            ForEach(labels) { label in
                Text(label.text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 2)
                    .shadow(color: .black.opacity(0.6), radius: 5)
                    .position(label.position)
                    .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(false)
    }

    /// A ring on the selected document, drawn where the document is rather than where the finger was.
    @ViewBuilder
    private var selectionMarker: some View {
        if let selection = model.selection {
            GeometryReader { proxy in
                let point = SemanticMapLabelLayout.project(
                    selection.position, camera: model.camera, size: proxy.size)
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.8), radius: 3)
                    .position(point)
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
        }
    }

    /// What the reader tapped, and what they can do about it.
    ///
    /// An **overlay, never a sheet**: a SwiftUI sheet on macOS does not composite the Metal layer
    /// underneath it, which is what made this whole screen blank for two sessions. Anything that
    /// covers the map has to be drawn over it in the same window.
    @ViewBuilder
    private var selectionCard: some View {
        if let selection = model.selection {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "\(selection.volumeID) · \(selection.documentID)")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 12)
                    Button {
                        model.clearSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "semanticMap.selection.dismiss",
                                               defaultValue: "Dismiss"))
                }
                if let region = selection.regionName {
                    Text(verbatim: region)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "semanticMap.selection.betweenRegions",
                                defaultValue: "Between regions"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if selection.isDownloaded {
                    openButton(for: selection)
                } else {
                    // The map draws the whole corpus; this device holds part of it. Saying so beats
                    // an Open button that fails.
                    Text(String(localized: "semanticMap.selection.notDownloaded",
                                defaultValue: "This volume is not on this device."))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 320)
            .padding(12)
        }
    }

    /// The action that opens the selected document, per platform.
    ///
    /// - Parameter selection: The selected document.
    /// - Returns: The button.
    @ViewBuilder
    private func openButton(for selection: SemanticMapPicking.Selection) -> some View {
        #if os(macOS)
        // A real document window, matching Citation Lookup: the map stays put while the document
        // opens beside it, which is the whole point of picking things off a map.
        Button(String(localized: "semanticMap.selection.open", defaultValue: "Open Document")) {
            openWindow(value: DocumentWindowID(
                volumeId: selection.volumeID,
                documentId: selection.documentID,
                header: "\(selection.volumeID) — \(selection.documentID)"))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        #else
        // `navigationDestination(item:)` driven from state, NOT a value-based `NavigationLink`.
        // Measured: with the link, the destination is registered by a view that is *itself* a pushed
        // destination of the Settings stack, and the push did not stick — the document was built
        // (the log shows its WebKit content loading) and the reader stayed on the map. Binding the
        // push to state removes the registration race.
        Button(String(localized: "semanticMap.selection.open", defaultValue: "Open Document")) {
            openedDocument = DocumentBrowserEntry(
                documentId: selection.documentID,
                volumeId: selection.volumeID,
                documentNumber: nil,
                header: "\(selection.volumeID) — \(selection.documentID)",
                dateline: nil,
                sourceNote: nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        #endif
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
/// **Every view it creates is attached before it is returned**, because the model builds its renderer
/// in `init`. That is deliberate and it is the macOS fix: SwiftUI may realize a representable more
/// than once — a `.sheet` is where it does — and when connection depended on a later
/// `updateNSView`, the instance that received the update was not the one composited. The visible
/// `MTKView` kept `delegate == nil`, never drew, and showed the window straight through.
///
/// `update*View` still calls `attach(to:)`, now purely as a belt-and-braces re-assert. Those two
/// one-line forwarders are the only part of this file a test cannot drive — `Context` is not
/// constructible — which is precisely why the fix does not rely on them.
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
        // `init(frame:device:)` rather than the bare `MTKView()` the first version used. This is
        // tidiness, NOT a fix: it was proposed as the cause of the blank macOS surface and that was
        // measured false on macOS 26.6.1 — MTKView's own method list carries `initWithFrame:`, so
        // `MTKView()` lands in MTKView's implementation and its common setup does run. Handing the
        // device in up front is simply possible now that the renderer exists before any view does.
        let view = MTKView(frame: .zero, device: model.renderer?.device)
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        // Must equal the format the pipeline was built for. Nothing in the compiler links the two,
        // so both sides read one constant and a test asserts they agree.
        view.colorPixelFormat = SemanticMapRenderer.pixelFormat
        view.clearColor = MTLClearColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        if view.device == nil { view.device = MTLCreateSystemDefaultDevice() }
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
