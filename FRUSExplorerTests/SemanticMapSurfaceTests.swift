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

import Testing
import Foundation
import MetalKit
@testable import FRUSExplorer

/// Whether this host has a GPU at all.
///
/// The renderer tests are *disabled* rather than failed where there is none: a machine without Metal
/// is a real condition, and a red suite there would say something false about the map. Evaluated once
/// so the three traits agree with each other.
private let semanticMapHasMetal = MTLCreateSystemDefaultDevice() != nil

/// The map surface: the bundled loader, what a colour means, and whether anything reaches the GPU.
///
/// Version history:
///   1.0 — V-4: initial implementation
///   1.1 — V-4: adds the model/surface tests, after the map shipped drawing nothing. Every test
///         here before that pass checked the *artifact*, which was correct the whole time — the
///         defect was in the SwiftUI wiring, and the only thing watching that was my own eyes.
///   1.2 — V-4: those model tests asserted `placedCount`, which the model assigns from the array it
///         just built — a tautology that stayed green with `setPoints` stubbed out. They now read
///         the renderer's own `uploadedPointCount` and `uploadCount`. `.serialized` added: seven
///         cases drive `BundledSemanticMap`'s static state and one resets it.
@Suite("Semantic map surface", .serialized)
struct SemanticMapSurfaceTests {

    // MARK: - The bundled map

    /// Coordinates are computed *from* vectors, so a map drawn against a different generation would
    /// place every document where different vectors put it — wrong in a way no reader could detect.
    @MainActor
    @Test("The bundled map loads and pins to the same generation as the vectors")
    func bundledMapLoads() async throws {
        BundledSemanticMap.resetForTesting()
        await BundledSemanticMap.prepare()

        #expect(BundledSemanticMap.isAvailable,
                "map unavailable: \(String(describing: BundledSemanticMap.unavailableReason))")
        let map = try #require(BundledSemanticMap.vectors)
        let mapIndex = try #require(BundledSemanticMap.index)
        let vectors = try #require(BundledSemanticVectors.index)

        #expect(map.documentCount == vectors.documentCount)
        #expect(mapIndex.provenanceDigest == vectors.provenance.digestHex)
        #expect(map.clusterCount == mapIndex.clusters.count)
        #expect(map.gridExtent == mapIndex.gridExtent)
    }

    /// Every placement must sit inside the grid the artifact declares, or the renderer's framing
    /// puts documents off screen with no indication anything is wrong.
    @MainActor
    @Test("Every placement is inside the declared grid, and clusters are in range")
    func placementsAreInBounds() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let extent = Int16(clamping: map.gridExtent)

        // Corners of the row space plus a stride through the middle: a systematic error shows at the
        // ends, and a per-row check over 314,483 placements would dominate the suite.
        var rows = [0, map.documentCount - 1]
        rows += stride(from: 0, to: map.documentCount, by: max(1, map.documentCount / 500))
        for row in rows {
            let placement = try #require(map.placement(at: row), "row \(row)")
            #expect(placement.x >= -extent && placement.x <= extent, "row \(row) x")
            #expect(placement.y >= -extent && placement.y <= extent, "row \(row) y")
            if placement.cluster != SemanticMapArtifacts.unclustered {
                #expect(Int(placement.cluster) < map.clusterCount, "row \(row) cluster")
            }
        }
        #expect(map.placement(at: -1) == nil)
        #expect(map.placement(at: map.documentCount) == nil)
    }

    // MARK: - Lenses

    @MainActor
    @Test("The cluster lens dims the unclustered and cycles the rest through the palette")
    func clusterLensColours() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let index = try #require(BundledSemanticVectors.index)

        let colours = SemanticMapColouring.indices(
            for: .cluster, map: map, index: index,
            eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        #expect(colours.count == map.documentCount)
        #expect(colours.allSatisfy { $0 < SemanticMapColouring.paletteSize })

        // Slot 0 is reserved for the unclustered 28%; a clustered document must never take it.
        for row in stride(from: 0, to: map.documentCount, by: 997) {
            let placement = try #require(map.placement(at: row))
            if placement.cluster == SemanticMapArtifacts.unclustered {
                #expect(colours[row] == 0, "row \(row) is unclustered and must use the dim slot")
            } else {
                #expect(colours[row] != 0, "row \(row) is clustered and must not use the dim slot")
            }
        }
    }

    /// The lenses that are properties of a volume must colour a volume's whole row block the same,
    /// which is also why they cost a few hundred range fills rather than 314,483 lookups.
    @MainActor
    @Test("Volume-derived lenses colour each volume's rows uniformly")
    func volumeLensesAreUniformPerVolume() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let index = try #require(BundledSemanticVectors.index)
        let downloaded = Set(index.volumes.prefix(3).map(\.volumeID))

        let colours = SemanticMapColouring.indices(
            for: .availability, map: map, index: index,
            eraForVolume: { _ in nil }, isDownloaded: { downloaded.contains($0) })

        for volume in index.volumes.prefix(6) {
            let range = try #require(index.rows(forVolume: volume.volumeID))
            let expected: UInt8 = downloaded.contains(volume.volumeID) ? 1 : 0
            #expect(range.allSatisfy { colours[$0] == expected }, "\(volume.volumeID) rows")
        }
    }

    @MainActor
    @Test("The era lens bands by the app's own CoverageEra")
    func eraLensUsesCoverageEra() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let index = try #require(BundledSemanticVectors.index)

        let colours = SemanticMapColouring.indices(
            for: .era, map: map, index: index,
            eraForVolume: { $0 == index.volumes[0].volumeID ? .coldWar : .pre1900 },
            isDownloaded: { _ in false })
        let first = try #require(index.rows(forVolume: index.volumes[0].volumeID))
        #expect(colours[first.lowerBound] == UInt8(CoverageEra.coldWar.rawValue))
        let second = try #require(index.rows(forVolume: index.volumes[1].volumeID))
        #expect(colours[second.lowerBound] == UInt8(CoverageEra.pre1900.rawValue))
    }

    /// An ordered variable drawn with a categorical palette is the commonest way a map lies about
    /// its data, so the two are deliberately different ramps.
    @Test("Each lens supplies a full palette, and era's is a ramp rather than categorical hues")
    func palettesAreLensAppropriate() {
        for lens in SemanticMapLens.allCases {
            let palette = SemanticMapColouring.palette(for: lens)
            #expect(palette.count == SemanticMapColouring.paletteSize, "\(lens.rawValue) palette")
            #expect(palette.allSatisfy { $0.w > 0 && $0.w <= 1 }, "\(lens.rawValue) alpha")
            #expect(!lens.displayName.isEmpty)
            #expect(!lens.legend.isEmpty)
        }
        // The era ramp moves monotonically in red across its used slots; a categorical palette would
        // not.
        let era = SemanticMapColouring.palette(for: .era)
        #expect(era[0].x < era[CoverageEra.allCases.count - 1].x)
    }

    // MARK: - The model, and the defect it was extracted for

    /// The test that would have caught the blank map — on its second attempt.
    ///
    /// The screen shipped with the renderer built inside the representable, which wrote SwiftUI state
    /// during a view update; nothing was ever uploaded. Every check on the *artifact* was already
    /// green, so the missing question was whether the artifact reached a GPU buffer.
    ///
    /// **The first version of this test did not ask it.** It asserted `model.placedCount`, which the
    /// model assigns from the array it has just built, one statement after `setPoints` and with no
    /// dependency on it — stub `setPoints` to an empty body and every assertion stayed green over a
    /// blank screen. `uploadedPointCount` reads through the renderer's `pointBuffer`, which is what
    /// `draw(in:)` gates on, so it fails both an empty `setPoints` and a `makeBuffer` returning nil.
    @MainActor
    @Test("Preparing the model uploads every document into the vertex buffer",
          .enabled(if: semanticMapHasMetal))
    func modelUploadsEveryDocument() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)

        let model = SemanticMapModel()
        #expect(model.renderer == nil, "a fresh model must not have built anything yet")
        #expect(model.placedCount == 0)

        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })

        #expect(model.unavailable == nil,
                "prepare reported: \(model.unavailable ?? "")")
        let renderer = try #require(model.renderer)
        #expect(renderer.uploadedPointCount == map.documentCount,
                "every placement must reach the vertex buffer")
        #expect(renderer.uploadCount == 1)
        // Separately: the extraction loop read one point per placement.
        #expect(model.placedCount == map.documentCount)
    }

    /// Idempotence matters because `.task` re-runs on identity changes, and re-uploading 314,483
    /// points on every appearance would be a visible stall.
    ///
    /// It needs `uploadCount`, not `placedCount` or even `uploadedPointCount`: a full re-upload of
    /// the same corpus leaves both of those identical, so neither can tell the two apart. The first
    /// version of this test asserted a number that is invariant under the thing it claimed to detect.
    @MainActor
    @Test("Preparing twice keeps one renderer and uploads only once",
          .enabled(if: semanticMapHasMetal))
    func modelPrepareIsIdempotent() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)

        let model = SemanticMapModel()
        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        let first = try #require(model.renderer)
        // Without this the two assertions below hold trivially when nothing ever loaded.
        #expect(first.uploadedPointCount == map.documentCount)
        #expect(first.uploadCount == 1)

        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        #expect(model.renderer === first)
        #expect(first.uploadCount == 1, "the second prepare must not re-upload")
        #expect(first.uploadedPointCount == map.documentCount)
    }

    /// The representable is built before the model's `.task` has produced a renderer — that ordering
    /// is the whole reason this shape exists — so it must survive being made empty and pick the
    /// renderer up on the next update rather than only working when it happens to be late.
    ///
    /// This drives `attach(to:)`, which is what `updateUIView`/`updateNSView` call. Those two
    /// one-line forwarders are themselves unexercised: `Context` is not constructible outside
    /// SwiftUI, so no unit test can call them. Recorded rather than glossed.
    @MainActor
    @Test("The surface attaches a renderer that arrives after the view was created",
          .enabled(if: semanticMapHasMetal))
    func surfaceAttachesLateRenderer() async throws {
        let model = SemanticMapModel()
        let surface = SemanticMapSurface(model: model)

        let view = surface.makeMap()
        #expect(view.device != nil, "an MTKView with no device has no drawable to render into")
        #expect(view.delegate == nil, "nothing to attach yet")

        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        surface.attach(to: view)

        #expect(view.delegate === model.renderer)
        #expect(view.device === model.renderer?.device,
                "the pipeline was built on the renderer's device; the view must share it")
    }

    /// The view's configuration decides whether a frame is ever produced, and none of it is checked
    /// by the compiler.
    ///
    /// `colorPixelFormat` is the sharp one: it must equal the format the pipeline was built for, in
    /// another file, or every draw call fails at validation. Both now read one constant, and this is
    /// what holds them together.
    @MainActor
    @Test("The MTKView is configured to drive frames, in the pipeline's own pixel format",
          .enabled(if: semanticMapHasMetal))
    func surfaceConfiguresContinuousDrawing() throws {
        let view = SemanticMapSurface(model: SemanticMapModel()).makeMap()
        #expect(view.colorPixelFormat == SemanticMapRenderer.pixelFormat)
        #expect(view.isPaused == false, "a paused view never asks its delegate to draw")
        #expect(view.enableSetNeedsDisplay == false,
                "with no invalidation source, set-needs-display mode draws once and stops")
        #expect(view.preferredFramesPerSecond > 0)
    }

    /// The model decodes placements by hand from the raw block for speed; `SemanticMapVectors`
    /// decodes them through `placement(at:)`. Two decoders over one byte layout, and until now only
    /// the second had a test — so a sign error or a swapped offset in the one that actually feeds the
    /// GPU would have gone unnoticed.
    @MainActor
    @Test("The model's hand decode agrees with the reader's", .enabled(if: semanticMapHasMetal))
    func handDecodeMatchesReader() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)

        var decoded: [(x: Int16, y: Int16)] = []
        map.withPlacements { base, count in
            for row in stride(from: 0, to: count, by: 1_499) {
                let offset = row * SemanticMapArtifacts.bytesPerDocument
                decoded.append((
                    x: Int16(bitPattern: base.loadUnaligned(
                        fromByteOffset: offset, as: UInt16.self).littleEndian),
                    y: Int16(bitPattern: base.loadUnaligned(
                        fromByteOffset: offset + 2, as: UInt16.self).littleEndian)))
            }
        }
        #expect(decoded.count > 100)
        for (index, sample) in decoded.enumerated() {
            let row = index * 1_499
            let reference = try #require(map.placement(at: row), "row \(row)")
            #expect(sample.x == reference.x, "row \(row) x")
            #expect(sample.y == reference.y, "row \(row) y")
        }
    }

    // MARK: - Wiring

    @Test("The map surface reads the bundled artifact rather than a developer file")
    func surfaceReadsTheBundle() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift"),
            encoding: .utf8)
        #expect(source.contains("BundledSemanticMap.prepare()"))
        #expect(source.contains("BundledSemanticMap.vectors"))
        // The spike's fallbacks are gone: a device with no map says so rather than inventing one.
        #expect(!source.contains("syntheticCloud"))
        #expect(!source.contains("spikeCoordsPath"))
    }
}
