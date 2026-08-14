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

    /// The axis the corpus is currently laid out along, when it is not on the map's own plane.
    private(set) var slice: SemanticAxis?

    /// The scope the reader asked for, whether or not it could be applied yet.
    ///
    /// Distinct from `scope`, which is the *resolved* mask: the two differ exactly while the artifact
    /// is loading or absent, which is the window the first version dropped the request in.
    private(set) var requestedScope: Set<String>??

    /// Whether a scope was asked for but could not be applied.
    ///
    /// The chip has no way to know on its own — it is driven by view state that is written whatever
    /// the model does — so the surface asks.
    var hasUnappliedScope: Bool {
        guard let requestedScope, let ids = requestedScope else { return false }
        return scope == nil && !ids.isEmpty
    }

    /// What the reader has scoped the map to, when they have.
    ///
    /// **A scope narrows the map without shrinking it.** Out-of-scope documents stay on screen as
    /// grey ground, because the question a scope answers here — *where does this subseries, this
    /// administration, this detected topic actually sit in the corpus's language?* — is unanswerable
    /// without the rest of the corpus to sit against. That is the difference between this and the
    /// scope on every other analytics surface, where out-of-scope data is simply excluded from a
    /// sum: here it is the reference frame.
    private(set) var scope: SemanticMapColouring.ScopeMask?

    /// How many in-scope documents a region needs before its name is drawn.
    ///
    /// A label sits at the region's WHOLE-CORPUS centroid, which is where its members are only if it
    /// has members. One in-scope document out of nine thousand puts a name in the middle of a field
    /// of ghosts, and the reader has no way to see that it describes a single point. Five is a
    /// judgement rather than a measurement, and a low one: it drops the degenerate case without
    /// pretending to a threshold nobody has calibrated.
    static let minimumLabelledInScope = 5

    /// The regions to label, re-counted against the scope.
    ///
    /// Two things happen here and both are necessary. A region with (almost) nothing in scope is
    /// **dropped**, because the artifact's cluster centres are whole-corpus and scoping to one
    /// subseries otherwise left the label layer choosing its dozen from all 179 regions, most of them
    /// naming a place that now held nothing but ghosts.
    /// And a surviving region's `documentCount` is **replaced by its in-scope count**, because the
    /// label layer ranks by size and keeps a dozen: rank by the series and a narrow scope gives its
    /// labels to the corpus's biggest regions rather than to the ones it fills.
    var labelledClusters: [SemanticMapArtifacts.Cluster] {
        guard let scope else { return clusters }
        return clusters.compactMap { cluster in
            guard let count = scope.regionCounts[UInt16(clamping: cluster.id)],
                  count >= Self.minimumLabelledInScope else { return nil }
            return SemanticMapArtifacts.Cluster(
                id: cluster.id, terms: cluster.terms, documentCount: count,
                centreX: cluster.centreX, centreY: cluster.centreY, eraCounts: cluster.eraCounts)
        }
    }

    /// The volumes chosen as the axis's poles, low end first.
    ///
    /// Poles are picked by **tapping a document**, not from a list. 552 volumes and 107 subseries do
    /// not fit in a menu anyone would read, and the reader is already pointing at the thing they mean
    /// — "away from what this document is, toward what that one is" is the question a slice answers.
    private(set) var poles: (negative: String?, positive: String?) = (nil, nil)

    /// The grid positions currently on screen, one per row.
    ///
    /// Kept because the map has two layouts — the packed UMAP plane and a semantic-axis slice — and
    /// every interaction has to agree with what is drawn rather than with the artifact.
    private(set) var positions: [SIMD2<Int16>] = []

    /// Whether `unavailable` describes a load still in flight rather than a refusal.
    ///
    /// The two were one string, so a screen that would show the map in a moment announced "Map
    /// unavailable" — a failure headline for a transient state.
    private(set) var isLoadingArtifact = false

    /// The lasso being drawn, in view points. Empty when not drawing.
    private(set) var lassoPath: [CGPoint] = []
    /// What the last completed lasso enclosed.
    private(set) var lassoResult: SemanticMapPicking.LassoResult?

    /// Where the camera is looking, mirrored out of the renderer.
    ///
    /// The renderer is not `@Observable` — it is a drawing object, not a source of truth for SwiftUI
    /// — so gestures go through `pan`/`zoom` here, which move the camera and republish it. That is
    /// what makes the labels follow the map instead of sitting where they were when it loaded.
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
        // No `Task` hop here: `onStats` is already `@MainActor`, and `StatsSink` does the hop.
        made.onStats = { [weak self] measured in self?.accept(measured) }
        renderer = made
    }

    /// Takes a statistics window, keeping the frame counter monotonic.
    ///
    /// **Frames arrive out of order.** `StatsSink` hops each window to the main actor with its own
    /// unstructured `Task`, and independent tasks have no ordering guarantee — so a later frame can
    /// be delivered before an earlier one, and the count that exists to prove the surface is alive
    /// could tick backwards in front of a reader. Dropping a stale window is the whole fix; the
    /// timings it carries are a rolling mean either way.
    ///
    /// - Parameter measured: The window as reported.
    private func accept(_ measured: SemanticMapRenderer.Stats) {
        guard measured.presentedFrames >= stats.presentedFrames else { return }
        stats = measured
    }

    /// Narrows the map to a set of volumes, or restores the whole series.
    ///
    /// - Parameter volumeIDs: The volumes in scope, or `nil` for the whole series.
    func setScope(volumeIDs: Set<String>?) {
        // **Remembered before it is applied, and that ordering is the fix.** The scope chip is gated
        // on `BundledSemanticVectors`, which loads at app start; the mask needs `BundledSemanticMap`,
        // which loads lazily and may never load at all (a provenance mismatch, a build with no map,
        // a device with no Metal). The first version returned early here, so a scope picked during
        // the load — or on a build where the map is dead — was thrown away while the chip went on
        // showing its name. That is the sixth control on this surface to render and do nothing.
        requestedScope = volumeIDs
        guard let map = BundledSemanticMap.vectors, let index else { return }
        scope = SemanticMapColouring.scopeMask(volumeIDs: volumeIDs, map: map, index: index)
        // A selection or a lasso made before the scope may name documents the scope excludes. Both
        // are dropped rather than filtered: a card that survived a scope change would be showing a
        // document the map has stopped drawing, and a lasso whose count no longer matches what a
        // re-draw would catch is worse than no lasso at all.
        selection = nil
        lassoResult = nil
        renderer?.setScopeFlags(scope?.flags ?? [])
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
        isDownloaded: (String) -> Bool,
        provenanceForVolume: (String) -> SourceProvenanceCategory? = { _ in nil }
    ) async {
        guard !isLoaded, let renderer else { return }

        await BundledSemanticMap.prepare()
        guard let map = BundledSemanticMap.vectors,
              let vectorIndex = BundledSemanticVectors.index else {
            let reason = BundledSemanticMap.unavailableReason ?? .pending
            isLoadingArtifact = reason == .pending
            unavailable = Self.describe(reason)
            return
        }
        index = vectorIndex
        unavailable = nil
        isLoadingArtifact = false

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
        positions = points.map(\.position)
        renderer.setPoints(points)
        // `setPoints` rewrites every byte of the vertex buffer, flags included, so the scope has to
        // be re-asserted after each one. This is the same trap the lens hit: a re-layout silently
        // dropped the reader's colouring and painted the corpus in slot 0.
        // Apply whatever the reader asked for while this was loading. The lens does the same thing
        // a few lines later in the view's `.task`, for the same reason and after the same race.
        if let requestedScope {
            scope = SemanticMapColouring.scopeMask(
                volumeIDs: requestedScope, map: map, index: vectorIndex)
        }
        renderer.setScopeFlags(scope?.flags ?? [])
        renderer.frameAll(extent: Float(map.gridExtent))
        camera = renderer.camera
        clusters = BundledSemanticMap.index?.clusters ?? []
        placedCount = points.count
        isLoaded = true
        apply(lens: lens, eraForVolume: eraForVolume, isDownloaded: isDownloaded,
              provenanceForVolume: provenanceForVolume)
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
            at: point, positions: positions, camera: camera, size: size,
            scopeMask: scope?.flags) else {
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
        // The cluster comes from the artifact by ROW, not from the hit: a slice re-lays the same
        // documents out, so a position means something different, but a row still means the same
        // document and therefore the same region.
        let clusterID = map.placement(at: hit.row)?.cluster ?? SemanticMapArtifacts.unclustered
        let region = clusterID == SemanticMapArtifacts.unclustered
            ? nil
            : clusters.first { $0.id == Int(clusterID) }
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

    /// Extends the lasso being drawn.
    /// - Parameter point: The latest point, in view points.
    func extendLasso(to point: CGPoint) {
        // Thin the stroke as it is drawn rather than after: a finger produces a point per frame, and
        // the containment test walks every edge for every candidate, so an unthinned path makes the
        // scan several times more expensive for a shape the reader cannot tell apart.
        if let last = lassoPath.last,
           abs(last.x - point.x) < 4, abs(last.y - point.y) < 4 { return }
        lassoPath.append(point)
    }

    /// Closes the lasso and resolves what it enclosed.
    ///
    /// - Parameter size: The view's size in points.
    func finishLasso(size: CGSize) {
        defer { lassoPath = [] }
        guard let map = BundledSemanticMap.vectors, let index, lassoPath.count >= 3 else {
            lassoResult = nil
            return
        }
        let found = SemanticMapPicking.rows(
            inside: lassoPath, positions: positions, camera: camera, size: size,
            limit: SemanticMapPicking.corpusCaptureLimit,
            scopeMask: scope?.flags)
        guard !found.rows.isEmpty else {
            // **Empty is not the same as nothing happened, once a scope is active.** Unscoped, an
            // empty lasso means the reader enclosed bare canvas and no card is the right answer.
            // Scoped, they may have drawn a careful ring around a dense grey mass — every point of it
            // excluded — and silence reads as a broken control rather than as an answer. So the card
            // appears and says so.
            lassoResult = scope == nil
                ? nil
                : SemanticMapPicking.LassoResult(documentKeys: [], total: 0, regionNames: [])
            return
        }

        // Resolve identity only for the rows that will be kept. `document(at:)` mints a String and
        // walks a volume's id segments; doing it for a discarded row is pure waste.
        var keys: [String] = []
        keys.reserveCapacity(found.rows.count)
        var regionCounts: [Int: Int] = [:]
        for row in found.rows {
            guard let document = index.document(at: row) else { continue }
            keys.append("\(document.volumeID)/\(document.documentID)")
            if let placement = map.placement(at: row),
               placement.cluster != SemanticMapArtifacts.unclustered {
                regionCounts[Int(placement.cluster), default: 0] += 1
            }
        }
        let names = regionCounts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(3)
            .compactMap { entry in
                clusters.first { $0.id == entry.key }?.terms.prefix(2).joined(separator: " ")
            }
        lassoResult = SemanticMapPicking.LassoResult(
            documentKeys: keys, total: found.total, regionNames: Array(names))
    }

    /// Clears the last lasso result.
    func clearLasso() { lassoResult = nil }

    /// A volume's centroid, dequantized into the float vector a pole needs.
    ///
    /// The centroid block stores **volumes in index order first, then subseries**, so a volume's slot
    /// is its position in `index.volumes` — the one place this ordering is relied on, and the reason
    /// it is stated here rather than assumed at the call site.
    ///
    /// - Parameter volumeID: The volume.
    /// - Returns: Its centroid, or `nil` when the artifact does not carry one.
    func centroid(forVolume volumeID: String) -> [Float]? {
        guard let index,
              let vectors = BundledSemanticVectors.corpusVectors,
              let slot = index.volumes.firstIndex(where: { $0.volumeID == volumeID }),
              let stored = vectors.centroid(at: slot) else { return nil }
        return SemanticAxis.dequantize(codes: stored.codes, scale: stored.scale)
    }

    /// Makes the selected document's volume one of the axis's poles.
    ///
    /// - Parameters:
    ///   - volumeID: The volume to use.
    ///   - isPositive: Whether it is the high end.
    ///   - yearForVolume: A volume's coverage midpoint, for the slice's y-axis.
    func setPole(volumeID: String, isPositive: Bool,
                 yearForVolume: (String) -> Int?,
                 reapplyLens: (() -> Void)? = nil) {
        if isPositive { poles.positive = volumeID } else { poles.negative = volumeID }
        guard let negativeID = poles.negative, let positiveID = poles.positive else { return }
        guard negativeID != positiveID,
              let negative = centroid(forVolume: negativeID),
              let positive = centroid(forVolume: positiveID),
              let axis = SemanticAxis.between(
                negative: negative, negativeLabel: negativeID,
                positive: positive, positiveLabel: positiveID) else {
            // Two poles that are the same volume have no direction between them. Say nothing and
            // stay on the map rather than drawing a slice made of rounding error.
            return
        }
        setSlice(axis: axis, yearForVolume: yearForVolume, reapplyLens: reapplyLens)
    }

    /// Clears the poles and returns to the map's own plane.
    /// - Parameter yearForVolume: A volume's coverage midpoint.
    func clearSlice(yearForVolume: (String) -> Int?, reapplyLens: (() -> Void)? = nil) {
        poles = (nil, nil)
        setSlice(axis: nil, yearForVolume: yearForVolume, reapplyLens: reapplyLens)
    }

    /// Lays the corpus out along a semantic axis, or returns it to the map's own plane.
    ///
    /// **x is the projection, y is the volume's coverage year** — the design's "drive the x-axis with
    /// it while y stays date". The date is the *volume's* coverage midpoint, not the document's,
    /// because that is what the bundle knows for all 552 volumes; a per-document date exists only for
    /// volumes this device has indexed, and a y-axis that meant one thing for some rows and another
    /// for the rest would be worse than a coarse one that means the same thing everywhere.
    ///
    /// - Parameters:
    ///   - axis: The axis to slice along, or `nil` to restore the map.
    ///   - yearForVolume: A volume's coverage midpoint year.
    func setSlice(axis: SemanticAxis?,
                  yearForVolume: (String) -> Int?,
                  reapplyLens: (() -> Void)? = nil) {
        slice = axis
        defer { reapplyLens?() }
        guard let renderer, let map = BundledSemanticMap.vectors else { return }
        guard let axis else {
            // Back to the artifact's own coordinates.
            var points = Self.mapPoints(from: map)
            positions = points.map(\.position)
            renderer.setPoints(points)
            renderer.setScopeFlags(scope?.flags ?? [])
            renderer.frameAll(extent: Float(map.gridExtent))
            camera = renderer.camera
            points.removeAll()
            return
        }
        guard let index, let vectors = BundledSemanticVectors.corpusVectors else { return }

        // Year per ROW, resolved once per volume rather than once per document: 552 lookups instead
        // of 314,483.
        var yearByRow = [Int16](repeating: 0, count: map.documentCount)
        var minYear = Int.max, maxYear = Int.min
        for volume in index.volumes {
            guard let rows = index.rows(forVolume: volume.volumeID),
                  let year = yearForVolume(volume.volumeID) else { continue }
            minYear = min(minYear, year); maxYear = max(maxYear, year)
            for row in rows where row < yearByRow.count { yearByRow[row] = Int16(clamping: year) }
        }
        let yearSpan = Float(max(1, maxYear - minYear))

        let extent = Float(SemanticAxis.sliceExtent)

        // Project first, then scale to what was actually observed. A sign-bit cosine against a
        // difference-of-centroids axis concentrates near zero — most of the corpus is unrelated to
        // both poles — so the true range is a narrow band and an unscaled slice is a vertical smear.
        // The ORDER along the axis is the content; the absolute magnitude of a sign-bit cosine is not
        // interpretable on its own, so filling the width costs no meaning. The caveat says it.
        var projections = [Float](repeating: 0, count: map.documentCount)
        var lowest = Float.greatestFiniteMagnitude
        var highest = -Float.greatestFiniteMagnitude
        vectors.withSignBits { base, count in
            for row in 0..<min(count, map.documentCount) {
                let value = axis.project(signBitsAt: base, row: row,
                                         bytesPerRow: vectors.bytesPerRow)
                projections[row] = value
                lowest = min(lowest, value)
                highest = max(highest, value)
            }
        }
        let spread = max(1e-6, highest - lowest)

        var points = [SemanticMapRenderer.MapPoint]()
        points.reserveCapacity(map.documentCount)
        for row in 0..<map.documentCount {
            let x = ((projections[row] - lowest) / spread) * 2 - 1
            let year = Int(yearByRow[row])
            let normalisedYear = year == 0 ? Float(0) : (Float(year - minYear) / yearSpan) * 2 - 1
            points.append(SemanticMapRenderer.MapPoint(
                position: SIMD2<Int16>(Int16(clamping: Int(x * extent)),
                                       Int16(clamping: Int(normalisedYear * extent))),
                colourIndex: 0, flags: 0))
        }
        positions = points.map(\.position)
        renderer.setPoints(points)
        renderer.setScopeFlags(scope?.flags ?? [])
        renderer.frameAll(extent: extent)
        camera = renderer.camera
    }

    /// Reads the artifact's own placements into renderer points.
    /// - Parameter map: The mapped placements.
    /// - Returns: One point per document, in row order.
    static func mapPoints(from map: SemanticMapVectors) -> [SemanticMapRenderer.MapPoint] {
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
        return points
    }

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
    ///   - provenanceForVolume: The archival category most of a volume's source notes name.
    func apply(
        lens: SemanticMapLens,
        eraForVolume: (String) -> CoverageEra?,
        isDownloaded: (String) -> Bool,
        provenanceForVolume: (String) -> SourceProvenanceCategory? = { _ in nil }
    ) {
        guard let renderer, let map = BundledSemanticMap.vectors, let index else { return }
        let colours = SemanticMapColouring.indices(
            for: lens, map: map, index: index,
            eraForVolume: eraForVolume, isDownloaded: isDownloaded,
            provenanceForVolume: provenanceForVolume)
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
/// lens the reader picks, with tap-to-open, lasso capture and axis slices over it.
///
/// It is the body of `SemanticAnalyticsView`, which is where it ended up after starting as a
/// `#if DEBUG` row in Settings ▸ Data & Recovery. The name still says "spike" because that is what
/// it was; the type is what it grew into.
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
    /// Whether a drag draws a lasso instead of panning.
    @State private var isLassoing = false
    /// What was saved, so the card can say so instead of leaving the reader guessing.
    @State private var savedCorpusName: String?
    /// The volumes the map is scoped to, or `nil` for the whole series.
    ///
    /// An array rather than a set because that is `AnalyticsScopeBar`'s binding type, and the whole
    /// point of this control is that it is the same one Archival Analytics and the word cloud use.
    @State private var scopeVolumeIds: [String]?
    /// What to call the active scope, in the reader's terms.
    @State private var scopeLabel: String?
    @Environment(\.modelContext) private var modelContext
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
                    .overlay { lassoOverlay }
                    .overlay { selectionMarker }
                    #if DEBUG
                    // Developer instrumentation, and now DEBUG-gated because this surface ships.
                    // "314483 documents · 0.05 ms mean · 18,849 fps equivalent" is the language of a
                    // rendering spike, not of an analytics window, and it was only ever acceptable
                    // because no user could reach the screen. The numbers are still worth having —
                    // the frame counter is what distinguishes a live surface from a dead one — so
                    // they stay for developers rather than being deleted.
                    .overlay(alignment: .topLeading) { statsOverlay }
                    #endif
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
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if isLassoing {
                                    model.extendLasso(to: value.location)
                                } else {
                                    model.pan(by: CGSize(
                                        width: value.translation.width - pan.width,
                                        height: value.translation.height - pan.height))
                                    pan = value.translation
                                }
                            }
                            .onEnded { _ in
                                if isLassoing {
                                    savedCorpusName = nil
                                    model.finishLasso(size: surfaceSize)
                                } else {
                                    pan = .zero
                                }
                            })
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                model.zoom(by: Float(value.magnification / zoom))
                                zoom = value.magnification
                            }
                            .onEnded { _ in zoom = 1.0 })
                // Siblings, not overlays, for the reason the Open button taught: an overlay of the
                // gestured surface has its buttons swallowed by that surface's gestures.
                //
                // **Stacked rather than layered.** All three are bottom-leading in this ZStack, so as
                // bare siblings a lasso result drew exactly on top of a selection card — hiding Open
                // Document and the pole buttons behind a card that looked like the only thing there.
                VStack(alignment: .leading, spacing: 0) {
                    sliceCard
                    selectionCard
                    lassoCard
                }
            }
            provenanceCaveat
            controls
        }
        // Matches the window, the menu item and the toolbar row. It used to say "Semantic Map",
        // which titled the macOS window differently from every door that opens it.
        //
        // macOS only, as all three sibling analytics views do (#219): there the title IS the window
        // title, while in the iOS sheet a large title spends a band of vertical space that the map
        // wants — and the sheet already carries the surface's name in its about header. VoiceOver
        // gets the name either way.
        #if os(macOS)
        .navigationTitle(String(localized: "semanticAnalytics.title",
                                defaultValue: "Semantic Analytics"))
        #else
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "semanticAnalytics.title",
                                   defaultValue: "Semantic Analytics"))
        #endif
        // In the toolbar rather than beside the point-size slider, and that is a fix: the controls
        // row sits at the bottom of the screen where the iCloud status banner overlays it, so the
        // toggle was drawn but could not be tapped — the drag kept panning. A mode switch has to be
        // reachable whatever transient chrome the app is showing.
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $isLassoing) {
                    Label(String(localized: "semanticMap.lasso", defaultValue: "Lasso"),
                          systemImage: "lasso")
                }
                .toggleStyle(.button)
                // A mode, not a modifier key: the same drag has to pan on one device and enclose on
                // another, and there is no chord a finger can hold.
                .onChange(of: isLassoing) { _, _ in
                    model.clearLasso()
                    savedCorpusName = nil
                }
            }
        }
        #if os(iOS)
        // The map's own document destination. Its host — now `SemanticAnalyticsView`'s
        // `NavigationStack`, previously the Settings stack it was pushed inside — carries none, and a
        // destination declared outside any stack is inert, which is why that wrapper is load-bearing
        // rather than cosmetic. macOS opens a real document window instead and needs none of this.
        .navigationDestination(item: $openedDocument) { entry in
            DocumentView(entry: entry)
        }
        #endif
        .task {
            await model.prepare(lens: lens, eraForVolume: eraForVolume,
                                isDownloaded: isDownloaded,
                                provenanceForVolume: provenanceForVolume)
            // Re-apply after the await. `model.apply` refuses until the index has loaded, so a lens
            // the reader picks *during* the load is otherwise dropped and then overwritten by
            // whatever `prepare` was started with.
            model.apply(lens: lens, eraForVolume: eraForVolume, isDownloaded: isDownloaded,
                        provenanceForVolume: provenanceForVolume)
        }
    }

    /// What the reader is looking at, and what it does and does not mean.
    ///
    /// **The design requires this and names the reason**: *"This is honest in a way the UMAP plane is
    /// not — UMAP preserves neighborhoods, not global distances, and the UI copy should say so."* The
    /// map has shipped without any such caveat until now; a slice makes the omission worse, because a
    /// projection onto a stated axis *looks* like a measurement and the plane behind it is not one.
    @ViewBuilder
    private var provenanceCaveat: some View {
        Group {
            if let slice = model.slice {
                Text(verbatim: Self.sliceCaveat(from: slice.negativeLabel, to: slice.positiveLabel))
            } else {
                Text(String(
                    localized: "semanticMap.caveat.map",
                    defaultValue: """
                        Layout preserves local similarity; distances between far regions are not \
                        meaningful.
                        """))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    /// The caveat a slice carries.
    /// - Parameters:
    ///   - negative: The low-end pole.
    ///   - positive: The high-end pole.
    /// - Returns: The sentence.
    private static func sliceCaveat(from negative: String, to positive: String) -> String {
        String(format: String(
            localized: "semanticMap.caveat.slice %@ %@",
            defaultValue: """
                Left–right is each document's projection onto %@ → %@, from 256-bit signatures, \
                scaled to the observed range. Up–down is the volume's coverage midpoint, not the \
                document's date.
                """), negative, positive)
    }

    /// A volume's coverage era, from the manifest.
    /// - Parameter volumeID: The volume.
    /// - Returns: Its era, when the manifest knows one.
    private func eraForVolume(_ volumeID: String) -> CoverageEra? {
        appState.manifestStore.eraForVolume(volumeID)
    }

    /// Re-applies the active lens.
    ///
    /// `setPoints` rewrites every colour byte, so a re-layout silently drops the lens and paints the
    /// corpus in slot 0 — which is the dim "between regions" colour, so the slice came out grey. The
    /// layout changes; what a colour means does not.
    private func applyLens() {
        model.apply(lens: lens, eraForVolume: eraForVolume, isDownloaded: isDownloaded,
                    provenanceForVolume: provenanceForVolume)
    }

    /// A volume's coverage midpoint year, for the slice's vertical axis.
    ///
    /// The VOLUME's, not the document's: the manifest knows a coverage range for all 552 volumes,
    /// where a per-document date exists only for volumes this device has indexed. A y-axis that meant
    /// one thing for some rows and another for the rest would be worse than a coarse one that means
    /// the same everywhere — and the caveat says which it is.
    ///
    /// - Parameter volumeID: The volume.
    /// - Returns: The midpoint year, when the manifest has a range.
    private func yearForVolume(_ volumeID: String) -> Int? {
        guard let entry = appState.manifestStore.entry(forVolumeId: volumeID) else { return nil }
        // The manifest stores coverage as ISO-ish strings; the leading four characters are the year,
        // which is all a vertical axis over 160 years of corpus needs.
        let years = [entry.dateRange.earliest, entry.dateRange.latest]
            .compactMap { $0.flatMap { Int($0.prefix(4)) } }
            .filter { $0 > 1700 && $0 < 2200 }
        guard !years.isEmpty else { return nil }
        return years.reduce(0, +) / years.count
    }

    /// The archival category most of a volume's source notes name.
    ///
    /// **Dominant, not exclusive**, and the caption under the map says so. Ties break on the
    /// category order in `SourceProvenanceCategory.allCases` rather than arbitrarily, so the map
    /// does not repaint itself between launches over a volume that drew equally from two files.
    ///
    /// Built once per lens application and cached, because the aggregate is a flat array of 522
    /// volumes and a linear scan per volume would be 552 × 522 comparisons for one recolour.
    ///
    /// - Parameter volumeID: The volume.
    /// - Returns: Its dominant category, or `nil` when the aggregate does not cover it.
    private func provenanceForVolume(_ volumeID: String) -> SourceProvenanceCategory? {
        dominantProvenance[volumeID]
    }

    /// Dominant category per volume, derived once from the bundled aggregate.
    private var dominantProvenance: [String: SourceProvenanceCategory] {
        guard let byVolume = appState.sourceProvenanceStore.index?.byVolume else { return [:] }
        var result: [String: SourceProvenanceCategory] = [:]
        result.reserveCapacity(byVolume.count)
        for volume in byVolume {
            var best: SourceProvenanceCategory?
            var bestCount = 0
            // `allCases` order, not the dictionary's: a Swift dictionary has no stable iteration
            // order, so a tie broken by iteration would recolour the map between launches.
            for category in SourceProvenanceCategory.allCases {
                let count = volume.count(for: category)
                if count > bestCount {
                    bestCount = count
                    best = category
                }
            }
            if let best { result[volume.volumeId] = best }
        }
        return result
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
            // A cluster's centre is a coordinate in the MAP's plane. In a slice the same documents
            // sit somewhere else entirely, so a label drawn at that centre names a region that is no
            // longer there — decoration over unrelated coordinates. Hidden rather than recomputed:
            // a slice's x is a projection and its y is a date, and the centroid of a region in that
            // space is a different claim needing its own justification.
            let labels = model.slice == nil
                ? SemanticMapLabelLayout.labels(
                    for: model.labelledClusters, camera: model.camera, size: proxy.size)
                : []
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

    /// The axis the corpus is laid out along, and the way back to the map.
    ///
    /// **This is the only exit from a slice, and for one release there was none.** `clearSlice` was
    /// written when the slice was, and nothing ever called it: picking two poles re-laid the corpus,
    /// hid the region labels, and left closing the window as the only way back — on a surface that
    /// had already shipped four controls which drew correctly and did nothing. The card also makes
    /// the *half-set* state visible, which nothing else did: after "Axis: from here" the reader is
    /// one pole in with no indication of it anywhere on screen.
    @ViewBuilder
    private var sliceCard: some View {
        if model.slice != nil || model.poles.negative != nil {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Label(String(localized: "semanticMap.axis.title", defaultValue: "Axis"),
                          systemImage: "arrow.left.and.right")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 12)
                    Button {
                        model.clearSlice(yearForVolume: yearForVolume, reapplyLens: applyLens)
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "semanticMap.axis.clear",
                                               defaultValue: "Clear axis and return to the map"))
                }
                if let slice = model.slice {
                    Text(verbatim: "\(slice.negativeLabel) → \(slice.positiveLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "semanticMap.axis.back",
                                  defaultValue: "Back to the map")) {
                        model.clearSlice(yearForVolume: yearForVolume, reapplyLens: applyLens)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if let negative = model.poles.negative {
                    // One pole in. Say so, and say what the second one costs.
                    Text(verbatim: negative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "semanticMap.axis.needsSecondPole",
                                defaultValue: "Tap another document and choose \u{201C}…to here\u{201D}."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 340)
            .padding(.horizontal, 12)
            .padding(.top, 12)
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
                // Poles come from tapped documents, so the control lives on the selection card.
                HStack(spacing: 8) {
                    Button(String(localized: "semanticMap.axis.poleFrom",
                                  defaultValue: "Axis: from here")) {
                        model.setPole(volumeID: selection.volumeID, isPositive: false,
                                      yearForVolume: yearForVolume,
                                      reapplyLens: applyLens)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button(String(localized: "semanticMap.axis.poleTo",
                                  defaultValue: "…to here")) {
                        model.setPole(volumeID: selection.volumeID, isPositive: true,
                                      yearForVolume: yearForVolume,
                                      reapplyLens: applyLens)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.poles.negative == nil)
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
        // Routed through provenance, like Cross-Reference Analytics and the corpus browser, NOT
        // minted directly the way Citation Lookup does. This started as a direct
        // `openWindow(value: DocumentWindowID(...))` "matching Citation Lookup", which left
        // `ToolWindowID.semanticAnalytics` written by both launchers and read by nobody — a binding
        // that documented a route it did not take. Routing keeps the property that comment was
        // reaching for (the map is its own window, so it stays put either way) and additionally puts
        // the document where the reader launched the map from; with no live host, `openDocument`
        // mints the standalone window itself.
        Button(String(localized: "semanticMap.selection.open", defaultValue: "Open Document")) {
            appState.openDocument(
                DocumentBrowserEntry(
                    documentId: selection.documentID,
                    volumeId: selection.volumeID,
                    documentNumber: nil,
                    header: "\(selection.volumeID) — \(selection.documentID)",
                    dateline: nil,
                    sourceNote: nil),
                from: .tool(.semanticAnalytics),
                using: openWindow)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        #else
        // `navigationDestination(item:)` driven from state, NOT a value-based `NavigationLink`.
        // Measured when the map was still a pushed destination of the Settings stack: with the link,
        // the destination was registered by a view that was itself a pushed destination, and the push
        // did not stick — the document was built (the log shows its WebKit content loading) and the
        // reader stayed on the map. The map now has a stack of its own, so that particular
        // registration race is gone, but the state-driven form is kept: it is the shape that was
        // actually verified to push, and re-testing a link to save one binding buys nothing.
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

    /// The lasso as it is drawn.
    @ViewBuilder
    private var lassoOverlay: some View {
        if model.lassoPath.count > 1 {
            Path { path in
                path.addLines(model.lassoPath)
                path.closeSubpath()
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            // Closed while drawing, because containment is decided against the closed shape — showing
            // an open stroke would let the reader believe a gap excludes what it does not.
            .background(
                Path { path in
                    path.addLines(model.lassoPath)
                    path.closeSubpath()
                }
                .fill(.white.opacity(0.10)))
            .allowsHitTesting(false)
        }
    }

    /// What the lasso caught, and what can be done with it.
    @ViewBuilder
    private var lassoCard: some View {
        if let result = model.lassoResult {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: result.total == 0
                         ? String(localized: "semanticMap.lasso.emptyInScope",
                                  defaultValue: "Nothing in scope here")
                         : Self.documentCount(result.total))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 12)
                    Button {
                        model.clearLasso()
                        savedCorpusName = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "semanticMap.lasso.dismiss",
                                               defaultValue: "Dismiss"))
                }
                if !result.regionNames.isEmpty {
                    Text(verbatim: result.regionNames.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if result.isTruncated {
                    // Say it before the corpus is made, not only in its provenance afterwards.
                    Text(verbatim: Self.truncationNote(kept: result.documentKeys.count,
                                                       total: result.total))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                // **A lasso is the first capture path that can enclose documents this device cannot
                // search.** Every corpus before it came from a search result set, so its members
                // were indexed by construction; the map draws all 552 volumes. Applying a corpus
                // silently narrows to the indexed keys, and one with none is refused outright — so
                // the coverage is stated here, at capture, rather than discovered later in Search.
                if result.total > 0 {
                    Text(verbatim: coverage(for: result).coverageDescription)
                        .font(.caption)
                        .foregroundStyle(coverage(for: result).isComplete
                                         ? Color.secondary : Color.orange)
                } else {
                    Text(String(localized: "semanticMap.lasso.emptyInScope.detail",
                                defaultValue: """
                                    Everything you enclosed is outside the current scope. Widen the \
                                    scope, or draw around the coloured documents.
                                    """))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if result.total == 0 {
                    EmptyView()
                } else if let saved = savedCorpusName {
                    Label(saved, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button(String(localized: "semanticMap.lasso.save",
                                  defaultValue: "Save as Working Corpus")) {
                        savedCorpusName = saveWorkingCorpus(result)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 340)
            .padding(12)
        }
    }

    /// How much of a lasso this device could actually search.
    ///
    /// Uses `WorkingCorpusResolver` rather than counting volumes here, so the number shown at capture
    /// is produced by the same code that decides what a corpus searches when it is applied. Two
    /// implementations of "reachable" would eventually disagree, and the reader would be told one
    /// number and given the other.
    ///
    /// - Parameter result: What the lasso enclosed.
    /// - Returns: The resolution against this device's index.
    private func coverage(for result: SemanticMapPicking.LassoResult) -> WorkingCorpusResolution {
        WorkingCorpusResolver(indexedVolumeIds: appState.indexedVolumeIds)
            .resolve(WorkingCorpus(name: "", documentKeys: result.documentKeys))
    }

    /// Creates a working corpus from a lasso and returns its name.
    ///
    /// - Parameter result: What the lasso enclosed.
    /// - Returns: The corpus name, or `nil` when the save failed.
    private func saveWorkingCorpus(_ result: SemanticMapPicking.LassoResult) -> String? {
        // Names are NOT unique by design, and both `SearchFilterView` and `SettingsView` look
        // corpora up BY NAME — so two lassos over the same regions must not produce the same string.
        // The capture time disambiguates them and is also the most useful thing to see in a list.
        let regions = result.regionNames.isEmpty
            ? String(localized: "semanticMap.lasso.defaultName", defaultValue: "Map selection")
            : result.regionNames.joined(separator: ", ")
        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        let name = "\(regions) — \(stamp)"
        let corpus = WorkingCorpus(
            name: name,
            documentKeys: result.documentKeys,
            // No query produced this set, and `sourceQuery` exists so a corpus can be re-derived by
            // hand. A lasso cannot be, so claiming one would be worse than leaving it empty.
            sourceQuery: nil,
            // Names the scope, when there was one. A corpus captured from a scoped map holds only
            // that scope's documents, and its provenance is the one place that fact survives after
            // the map is closed — without it, two lassos over the same region under two different
            // scopes are indistinguishable in the corpora list.
            sourceDescription: scopeLabel.map { label in
                String(format: String(localized: "semanticMap.lasso.source.scoped %@",
                                      defaultValue: "Semantic map selection, scoped to %@"), label)
            } ?? String(localized: "semanticMap.lasso.source",
                        defaultValue: "Semantic map selection"),
            indexedVolumeCountAtCapture: appState.indexedVolumeIds.count,
            wasTruncatedAtCapture: result.isTruncated,
            totalMatchCountAtCapture: result.total)
        modelContext.insert(corpus)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SemanticMapSpikeView] working corpus save failed: \(error)")
            #endif
            return nil
        }
        return name
    }

    /// "N documents", localised for plurals.
    /// - Parameter count: How many.
    /// - Returns: The phrase.
    private static func documentCount(_ count: Int) -> String {
        String(format: String(localized: "semanticMap.lasso.count %lld",
                              defaultValue: "%lld documents"), count)
    }

    /// The note shown when a lasso caught more than a corpus may hold.
    /// - Parameters:
    ///   - kept: How many will be saved.
    ///   - total: How many were enclosed.
    /// - Returns: The sentence.
    private static func truncationNote(kept: Int, total: Int) -> String {
        String(format: String(localized: "semanticMap.lasso.truncated %lld %lld",
                              defaultValue: "Saving the first %lld of %lld."), kept, total)
    }

    /// The message shown when there is nothing to draw.
    @ViewBuilder
    private var unavailableOverlay: some View {
        if let message = model.unavailable {
            // "Map unavailable" was also the headline while the artifact was still loading, which
            // reads as a failure for a state that resolves on its own a moment later. The pending
            // case gets a progress view instead; only a real refusal gets the headline.
            if model.isLoadingArtifact {
                ProgressView { Text(verbatim: message) }
                    .controlSize(.large)
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ContentUnavailableView(
                    String(localized: "semanticMap.unavailable", defaultValue: "Map unavailable"),
                    systemImage: "map",
                    description: Text(message))
                .background(.regularMaterial)
            }
        }
    }

    /// The volumes the map is drawing brightly, and the doors that choose them.
    ///
    /// **The same `AnalyticsScopeBar` the rest of the analytics family uses**, with the same
    /// administration menu Archival Analytics puts beside it — so a reader who has scoped a word
    /// cloud to the Nixon volumes or to a detected topic already knows this control, and can put the
    /// *same* segment on the map to see where its language actually sits. That comparison is the
    /// feature: a subseries is an editorial fact, a detected topic is a subject fact, an
    /// administration is a political fact, and the map is the only surface that can show all three
    /// against a layout none of them produced.
    ///
    /// The population is the **series**, not the reader's library — `SemanticVectorIndex.volumes`,
    /// the 552 the artifact covers — for the reason Archival Analytics gives: this derivation is
    /// bundled and is honest with nothing downloaded. The `availability` lens is where the library
    /// enters, and it stays a lens rather than becoming a scope.
    @ViewBuilder
    private var scopeControls: some View {
        let scopable = scopableVolumeIds
        if !scopable.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { scopeBar(scopable); administrationMenu(scopable); Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: 8) { scopeBar(scopable); administrationMenu(scopable) }
            }
            if let scope = model.scope {
                // The denominator, always. A reader looking at a scoped map is looking at a subset
                // whose size they cannot see — most of the screen is still the corpus — and "12
                // volumes" alone would let a scope that resolved to almost nothing look the same as
                // one that resolved to a subseries.
                Text(verbatim: Self.scopeSummary(documents: scope.documentCount,
                                                 volumes: scope.volumeCount,
                                                 ofVolumes: scopable.count))
                    .font(.caption2)
                    .foregroundStyle(scope.documentCount == 0 ? Color.orange : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.hasUnappliedScope {
                // The chip is driven by view state and will show the scope's name whatever the model
                // did with it. When the map is not there to be masked, say so rather than letting the
                // name imply a map that is filtered.
                Text(String(localized: "semanticMap.scope.notApplied",
                            defaultValue: "The map is not loaded, so this scope is not applied yet."))
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The volumes a scope may name — those the artifact actually places.
    private var scopableVolumeIds: Set<String> {
        Set(BundledSemanticVectors.index?.volumes.map(\.volumeID) ?? [])
    }

    /// The shared analytics scope selector.
    /// - Parameter scopable: The volumes in the artifact.
    /// - Returns: The bar.
    private func scopeBar(_ scopable: Set<String>) -> some View {
        AnalyticsScopeBar(
            indexedVolumeIds: scopable,
            volumeTitle: { appState.manifestStore.entry(forVolumeId: $0)?.title ?? $0 },
            // Both halves go through `applyScope`, so a selection cannot change the label without
            // re-masking the map — the shape Archival Analytics arrived at after a scope change left
            // its chart untouched.
            scopeVolumeIds: Binding(get: { scopeVolumeIds },
                                    set: { applyScope($0, label: scopeLabel) }),
            scopeLabel: Binding(get: { scopeLabel },
                                set: { applyScope(scopeVolumeIds, label: $0) }),
            onChange: {},
            presentation: .chip)
    }

    /// Scope to one presidential administration's volumes.
    ///
    /// A second menu rather than a row inside the bar, matching Archival Analytics: an administration
    /// here is a volume SET taken from the bundled profile index, not a year range, so it composes
    /// with a map that has no time axis at all until a slice gives it one.
    ///
    /// - Parameter scopable: The volumes in the artifact.
    /// - Returns: The menu, or nothing when the profiles are unavailable.
    @ViewBuilder
    private func administrationMenu(_ scopable: Set<String>) -> some View {
        let profiles = appState.administrationProfilesStore.index?.administrations ?? []
        if !profiles.isEmpty {
            Menu {
                ForEach(profiles, id: \.id) { profile in
                    // **Disabled rather than dead.** The profile index covers every administration
                    // back to Washington; the map covers the volumes the artifact places. Six
                    // presidents have no mapped volume at all, and the first version gave them a
                    // button that guarded on an empty set and returned — a menu item that highlights
                    // and does nothing, which is the failure this surface has shipped five times.
                    // The `SeriesScopeBar` custom-scope idiom: show it, disable it, say why.
                    let ids = profile.volumes.map(\.volumeId).filter { scopable.contains($0) }
                    if ids.isEmpty {
                        Text(String(format: String(
                            localized: "semanticMap.scope.administration.none %@",
                            defaultValue: "%@ — no mapped volumes"), profile.president))
                            .foregroundStyle(.secondary)
                    } else {
                        Button(profile.president) {
                            applyScope(ids.sorted(), label: profile.president)
                        }
                    }
                }
            } label: {
                Label(String(localized: "semanticMap.scope.administration",
                             defaultValue: "Administration"),
                      systemImage: "person.crop.square")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    /// Applies a scope to the map and remembers what to call it.
    ///
    /// - Parameters:
    ///   - ids: The volumes in scope, or `nil` for the whole series.
    ///   - label: The scope's name.
    private func applyScope(_ ids: [String]?, label: String?) {
        // **The set is compared before the mask is rebuilt**, because `AnalyticsScopeBar` writes its
        // two bindings separately: one menu tap calls this twice, once for the ids and once for the
        // label. Rebuilding on both meant two passes over 314,483 rows per selection, the second of
        // them redundant. The label still updates either way.
        let changed = ids.map(Set.init) != scopeVolumeIds.map(Set.init)
        scopeVolumeIds = ids
        scopeLabel = label
        guard changed else { return }
        model.setScope(volumeIDs: ids.map(Set.init))
        savedCorpusName = nil
    }

    /// How much of the corpus a scope holds, and at what grain.
    ///
    /// **It says "every document in", and that phrase is the honest part.** Every scope this control
    /// offers is a set of VOLUMES — a subseries, an administration's volumes, a detected topic's
    /// volumes — so scoping to *Nuclear Nonproliferation* lights all 7,702 documents in the 26
    /// volumes carrying that tag, not the documents about nonproliferation. On a chart that
    /// distinction hides inside a bar; on a map the reader watches those documents land in regions
    /// named `salmon constantinople`, and without this sentence the obvious reading is that the
    /// model placed them badly.
    ///
    /// - Parameters:
    ///   - documents: Documents in scope.
    ///   - volumes: Volumes in scope.
    ///   - ofVolumes: Volumes the artifact places.
    /// - Returns: The sentence.
    static func scopeSummary(documents: Int, volumes: Int, ofVolumes: Int) -> String {
        guard documents > 0 else {
            return String(localized: "semanticMap.scope.empty",
                          defaultValue: "No mapped documents in this scope.")
        }
        // "mapped documents in whole volumes" rather than "every document in": the map places
        // 314,483 rows against the app's 316,839, because chapter divs, front matter and appendices
        // carry no vector. "Every document" was the wrong word by ~2,356 rows, and on a surface whose
        // whole job is to be honest about what a model can and cannot say, the wrong word is the
        // failure.
        return String(format: String(
            localized: "semanticMap.scope.summary.v3 %@ %lld %lld",
            defaultValue: "In scope: %@ mapped documents — whole volumes, %lld of %lld."),
            documents.formatted(.number), Int64(volumes), Int64(ofVolumes))
    }

    /// The lens picker and point size.
    ///
    /// A plain stack rather than a `Form`. A grouped `Form` capped at `maxHeight: 130` is a scroll
    /// view whose section insets consume most of that budget, and on an iPhone it rendered as an
    /// **empty card with both controls below the fold** — the map drew correctly and there was no way
    /// to change the lens.
    ///
    /// The ~100-point measurement that used to be quoted here covered the lens picker and the slider
    /// only; the scope row and its summary line came later and were not re-measured. What is verified
    /// on an iPhone 17 is that all four are on screen with the map above them — the stack has no
    /// fixed height and the map takes the remainder, so the honest claim is the observation rather
    /// than a number nobody has re-taken.
    /// The lenses this build can actually draw.
    private var availableLenses: [SemanticMapLens] {
        let byVolume = appState.sourceProvenanceStore.index?.byVolume
        return SemanticMapLens.allCases.filter { $0.isAvailable(volumeProvenance: byVolume) }
    }

    /// What the colours mean.
    ///
    /// **The enum has declared a `legend` since V-4 and nothing has ever drawn it.** That was
    /// survivable while the lenses were regions (named on the map itself), a two-state download flag
    /// and an ordered era ramp; it is not survivable for a categorical lens over ten archival
    /// vocabularies, where an unlabelled colour is decoration. Drawn from the same
    /// `SemanticMapColouring.palette` the GPU gets, so a swatch cannot drift from its points.
    @ViewBuilder
    private var legend: some View {
        let entries = Array(lens.legend.enumerated())
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(entries, id: \.offset) { index, name in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Self.swatch(lens: lens, slot: index))
                                    .frame(width: 8, height: 8)
                                Text(verbatim: name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                if let caption = lens.caption {
                    Text(verbatim: caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The colour a legend swatch shows, taken from the renderer's own palette.
    ///
    /// - Parameters:
    ///   - lens: The active lens.
    ///   - slot: The palette index.
    /// - Returns: The colour, opaque — a swatch is read against the surrounding bar rather than the
    ///   map's dark ground, so the palette's own alpha (which exists to let points overlap) would
    ///   make every dot look washed out and the two central-file blues indistinguishable.
    static func swatch(lens: SemanticMapLens, slot: Int) -> Color {
        let palette = SemanticMapColouring.palette(for: lens)
        guard slot >= 0, slot < palette.count else { return .secondary }
        let rgba = palette[slot]
        return Color(.sRGB, red: Double(rgba.x), green: Double(rgba.y), blue: Double(rgba.z),
                     opacity: 1.0)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            scopeControls
            // **A menu, not a segmented control, from the fourth lens onward.** Four segments fit an
            // iPhone only by truncating their own names — "Provenance" is the longest and the first
            // that cannot be shortened without lying about what it shows — and the design lists
            // several more lenses to come. A menu costs one tap and holds any number.
            HStack(spacing: 8) {
                Text(String(localized: "semanticMap.lens", defaultValue: "Colour by"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(String(localized: "semanticMap.lens", defaultValue: "Colour by"),
                       selection: $lens) {
                    ForEach(availableLenses) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer(minLength: 0)
            }
            .onChange(of: lens) { _, value in
                model.apply(lens: value, eraForVolume: eraForVolume,
                            isDownloaded: isDownloaded,
                            provenanceForVolume: provenanceForVolume)
            }
            // A lens whose data this build does not carry is withheld, and if the reader is already
            // ON it — impossible today, but a stored selection would make it reachable — the picker
            // falls back rather than showing a blank name.
            .onChange(of: availableLenses) { _, options in
                if !options.contains(lens) { lens = .cluster; applyLens() }
            }
            legend
            // The availability lens reads a set that is filled by a detached query at boot. Open the
            // map before that returns — likeliest when a restored window appears with no user action
            // — and every point is painted not-on-this-device and stays that way for the life of the
            // window, because nothing else re-applies. It states a fact about the reader's own
            // library, so being wrong is worse here than on any other lens.
            .onChange(of: appState.indexedVolumeIds) { _, _ in applyLens() }

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
        // **On demand, not on a clock.** `isPaused` stops the display link and
        // `enableSetNeedsDisplay` makes a dirty mark the thing that produces a frame; the renderer
        // marks itself dirty from every mutator (`SemanticMapRenderer.register(_:)` and its `didSet`
        // hooks). The map is a still image unless the camera moves, so the free-running loop this
        // replaces spent 60 identical 314,483-point draw calls a second for as long as a window
        // stayed open — which was a fair trade for a spike being measured and is not one for a
        // window a reader leaves open beside their work.
        view.enableSetNeedsDisplay = true
        view.isPaused = true
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
        guard let renderer = model.renderer else { return }
        // Registered before the delegate check rather than after it, so a re-assert that finds the
        // delegate already set still puts the view on the redraw list. Both calls are idempotent —
        // this is belt-and-braces, not a fix for an observed failure — but an on-demand surface that
        // is not on the list draws nothing at all, and that failure is total rather than degraded.
        renderer.register(view)
        guard view.delegate !== renderer else { return }
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
