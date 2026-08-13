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
///   1.3 — V-4: the map was still blank on **macOS**. The cause turned out to be the SwiftUI
///         `.sheet` — a Metal layer hosted in one draws and presents and never reaches the screen —
///         and NOT, as this entry first claimed, SwiftUI realizing the representable more than once;
///         it is realized once. The late-attach test is still replaced by one that makes several
///         views from one surface and requires every one to be born attached, because that closes a
///         real ordering hole even though it was not the macOS cause.
///   1.4 — V-4: adds the region-label layout tests. Pure functions of (clusters, camera, size), so
///         they run without a GPU — the thing this surface has repeatedly needed and not had.
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
        #expect(model.renderer != nil, "the renderer is built in init, before any view can exist")
        #expect(model.placedCount == 0, "but nothing is uploaded until prepare runs")

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

    /// The macOS regression test, reproduced headlessly.
    ///
    /// The map was blank on macOS because SwiftUI realized the representable **more than once** — a
    /// `.sheet` is where that happens — and connection depended on a later `updateNSView` landing on
    /// the right instance. It landed on the wrong one, so the visible `MTKView` kept `delegate ==
    /// nil`; an `MTKView` with no delegate never draws, so its layer had no contents and the sheet's
    /// white showed through.
    ///
    /// No unit test can call `updateNSView` (`Context` is not constructible), and there is no macOS
    /// test host. But the *seam* is reproducible: create the view more than once from one surface,
    /// as SwiftUI does, and require that **every** view is usable. Under the old shape the first one
    /// came back with no delegate.
    @MainActor
    @Test("Every view the surface creates is born attached, however many it makes",
          .enabled(if: semanticMapHasMetal))
    func everyRealizationIsBornAttached() async throws {
        let model = SemanticMapModel()
        let surface = SemanticMapSurface(model: model)
        let renderer = try #require(model.renderer)

        // Three realizations: the discarded measurement pass, the real one, and a rebuild.
        let views = [surface.makeMap(), surface.makeMap(), surface.makeMap()]
        for (index, view) in views.enumerated() {
            #expect(view.delegate === renderer, "view \(index) was created without a delegate")
            #expect(view.device === renderer.device, "view \(index) must share the pipeline's device")
        }

        // And loading later must not disturb any of them — whichever one SwiftUI composited.
        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        for (index, view) in views.enumerated() {
            surface.attach(to: view)
            #expect(view.delegate === renderer, "view \(index) lost its delegate")
        }
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

    // MARK: - Region labels

    /// The label layer has to land text on the same pixels a point lands on, so its projection is
    /// pinned to the shader's rule: `(grid - centre) / scale`, y up, [-1,1] across the viewport.
    @Test("A region at the camera's centre is drawn at the centre of the view")
    func projectionCentres() {
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: 30_000)
        let size = CGSize(width: 400, height: 200)
        let middle = SemanticMapLabelLayout.project(SIMD2<Float>(0, 0), camera: camera, size: size)
        #expect(abs(middle.x - 200) < 0.001)
        #expect(abs(middle.y - 100) < 0.001)

        // Aspect is applied to the horizontal half-extent, so on a 2:1 viewport the grid's own
        // half-height reaches the top edge while its half-width reaches only the middle of the right.
        let top = SemanticMapLabelLayout.project(SIMD2<Float>(0, 30_000), camera: camera, size: size)
        #expect(abs(top.y) < 0.001, "y is flipped: grid up is view down")
        let right = SemanticMapLabelLayout.project(
            SIMD2<Float>(30_000, 0), camera: camera, size: size)
        #expect(abs(right.x - 300) < 0.001)
    }

    /// Panning must move the names with the points, or the map lies about what it is naming.
    @Test("Moving the camera moves the labels the opposite way")
    func projectionFollowsCamera() {
        let size = CGSize(width: 400, height: 400)
        let origin = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: 30_000)
        let moved = SemanticMapCamera(centre: SIMD2<Float>(15_000, 0), halfExtent: 30_000)
        let before = SemanticMapLabelLayout.project(SIMD2<Float>(0, 0), camera: origin, size: size)
        let after = SemanticMapLabelLayout.project(SIMD2<Float>(0, 0), camera: moved, size: size)
        #expect(after.x < before.x, "camera moved right, so the region moves left on screen")

        // Zooming in spreads two regions apart.
        let close = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: 15_000)
        let wideGap = abs(
            SemanticMapLabelLayout.project(SIMD2<Float>(10_000, 0), camera: origin, size: size).x
            - before.x)
        let closeGap = abs(
            SemanticMapLabelLayout.project(SIMD2<Float>(10_000, 0), camera: close, size: size).x
            - before.x)
        #expect(closeGap > wideGap)
    }

    /// 179 regions and room for two dozen names: the rule is rank by size, then drop anything that
    /// collides with a name already placed. Ranking by size rather than proximity is what keeps the
    /// labelling stable while panning.
    @Test("Crowded regions yield one label, and the largest region wins it")
    func labelsResolveCrowding() {
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: 30_000)
        let size = CGSize(width: 400, height: 400)
        let crowd = [
            makeCluster(id: 1, terms: ["small", "one"], x: 0, y: 0, documents: 100),
            makeCluster(id: 2, terms: ["big", "two"], x: 60, y: 60, documents: 9_000),
            makeCluster(id: 3, terms: ["far", "three"], x: 20_000, y: 0, documents: 500),
        ]
        let labels = SemanticMapLabelLayout.labels(for: crowd, camera: camera, size: size)
        #expect(labels.count == 2, "the two overlapping regions must collapse to one name")
        #expect(labels.first?.id == 2, "and the larger of them keeps it")
        #expect(labels.contains { $0.id == 3 })
        #expect(labels.allSatisfy { $0.text.split(separator: " ").count == 2 })
    }

    /// A name for a region nobody can see is noise, and the limit is what keeps the map readable.
    @Test("Off-screen regions are dropped and the count is capped")
    func labelsCullAndCap() {
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: 1_000)
        let size = CGSize(width: 400, height: 400)
        let offScreen = [makeCluster(id: 9, terms: ["gone"], x: 25_000, y: 0, documents: 5_000)]
        #expect(SemanticMapLabelLayout.labels(for: offScreen, camera: camera, size: size).isEmpty)

        // Spread apart, and kept clear of the edges: a centre near the edge is pulled inward by the
        // clamp, and three of those pulled to the same edge would collide and be dropped — which is
        // the clamp working, not the cap, and would make this test measure the wrong thing.
        let many = (0..<60).map { index in
            makeCluster(id: index, terms: ["t\(index)"],
                        x: -500 + index * 17, y: (index % 2 == 0) ? -900 : 900,
                        documents: 1_000 - index)
        }
        let capped = SemanticMapLabelLayout.labels(
            for: many, camera: camera, size: size, limit: 5, spacing: 1)
        #expect(capped.count == 5)
        #expect(capped.map(\.id) == [0, 1, 2, 3, 4], "the largest five, in size order")

        #expect(SemanticMapLabelLayout.labels(
            for: many, camera: camera, size: .zero).isEmpty, "no view, no labels")
    }

    /// A name running off the edge is worse than a name nudged inward — the first build drew
    /// "srael israeli" and a truncated "seward dayton" against the viewport edges.
    @Test("Labels near an edge are pulled inside the view")
    func labelsStayInsideTheView() {
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: 10_000)
        let size = CGSize(width: 400, height: 400)
        // Centres hard against each edge of the visible grid.
        let edges = [
            makeCluster(id: 1, terms: ["left"], x: -10_000, y: 0, documents: 900),
            makeCluster(id: 2, terms: ["right"], x: 10_000, y: 0, documents: 800),
            makeCluster(id: 3, terms: ["top"], x: 0, y: 10_000, documents: 700),
            makeCluster(id: 4, terms: ["bottom"], x: 0, y: -10_000, documents: 600),
        ]
        let labels = SemanticMapLabelLayout.labels(for: edges, camera: camera, size: size)
        #expect(labels.count == 4)
        for label in labels {
            #expect(label.position.x > 0 && label.position.x < size.width, "\(label.text) x")
            #expect(label.position.y > 0 && label.position.y < size.height, "\(label.text) y")
        }
        // The clamp must not smuggle two names on top of each other.
        for (index, label) in labels.enumerated() {
            for other in labels.dropFirst(index + 1) {
                let gap = hypot(label.position.x - other.position.x,
                                label.position.y - other.position.y)
                #expect(gap >= SemanticMapLabelLayout.defaultSpacing,
                        "\(label.text) and \(other.text) collide after clamping")
            }
        }
    }

    // MARK: - Picking

    /// A tap resolved through a slightly different rule than the one that drew the point would select
    /// the document *next to* the reader's finger — wrongness that reads as imprecision, not a bug.
    /// So the inverse is pinned against the forward projection rather than derived again.
    @Test("Unprojecting a projected point returns the same grid coordinate")
    func unprojectInvertsProject() {
        let cameras = [
            SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: 30_000),
            SemanticMapCamera(centre: SIMD2<Float>(-12_000, 4_500), halfExtent: 3_000),
        ]
        let sizes = [CGSize(width: 400, height: 400), CGSize(width: 900, height: 300),
                     CGSize(width: 300, height: 900)]
        let grids = [SIMD2<Float>(0, 0), SIMD2<Float>(7_500, -2_500), SIMD2<Float>(-14_000, 9_000)]
        for camera in cameras {
            for size in sizes {
                for grid in grids {
                    let round = SemanticMapLabelLayout.unproject(
                        SemanticMapLabelLayout.project(grid, camera: camera, size: size),
                        camera: camera, size: size)
                    #expect(abs(round.x - grid.x) < 1, "x for \(grid) at \(size)")
                    #expect(abs(round.y - grid.y) < 1, "y for \(grid) at \(size)")
                }
            }
        }
    }

    /// Tapping a document must select that document — and tapping empty map must select nothing,
    /// because a pick that always returns *something* would hand the reader an arbitrary document
    /// from across the corpus and call it a result.
    @MainActor
    @Test("A tap selects the document under it, and empty map selects nothing")
    func pickingFindsTheNearestDocument() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let size = CGSize(width: 600, height: 600)
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0),
                                       halfExtent: Float(map.gridExtent))
        // Picking scans what is DRAWN. In map mode that is the artifact's own placements — the same
        // array the model uploads — so the tests go through the same accessor the model does.
        let positions = SemanticMapModel.mapPoints(from: map).map(\.position)

        // Aim at a document the artifact actually holds, and require that one back.
        let target = try #require(map.placement(at: 12_345))
        let onScreen = SemanticMapLabelLayout.project(
            SIMD2<Float>(Float(target.x), Float(target.y)), camera: camera, size: size)
        let hit = try #require(SemanticMapPicking.hit(
            at: onScreen, positions: positions, camera: camera, size: size))
        #expect(hit.position.x == Float(target.x))
        #expect(hit.position.y == Float(target.y))

        // Far outside the grid there is nothing to select, however generous the radius.
        let empty = SemanticMapLabelLayout.project(
            SIMD2<Float>(Float(map.gridExtent) * 4, Float(map.gridExtent) * 4),
            camera: camera, size: size)
        #expect(SemanticMapPicking.hit(at: empty, positions: positions, camera: camera, size: size) == nil)
    }

    /// The row a pick returns is only useful if it resolves to a document, and identity is STORED in
    /// the artifact rather than derived from the ordinal — the design's implicit keying mis-keyed
    /// 15,097 documents, so this checks the pick lands in the keying that replaced it.
    @MainActor
    @Test("A picked row resolves to a real volume and document")
    func pickedRowResolvesToADocument() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let index = try #require(BundledSemanticVectors.index)
        let size = CGSize(width: 600, height: 600)
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0),
                                       halfExtent: Float(map.gridExtent))
        // Picking scans what is DRAWN. In map mode that is the artifact's own placements — the same
        // array the model uploads — so the tests go through the same accessor the model does.
        let positions = SemanticMapModel.mapPoints(from: map).map(\.position)

        // Include the volume whose ids are NOT `dN` — `frus1958-60v05mSupp` keys its 628 documents
        // `eta_d1…`, which is exactly the case a shape assumption would break on.
        var rows = Array(stride(from: 0, to: map.documentCount, by: 41_000))
        if let odd = index.rows(forVolume: "frus1958-60v05mSupp")?.lowerBound { rows.append(odd) }
        for row in rows {
            let placement = try #require(map.placement(at: row))
            let point = SemanticMapLabelLayout.project(
                SIMD2<Float>(Float(placement.x), Float(placement.y)), camera: camera, size: size)
            let hit = try #require(SemanticMapPicking.hit(
                at: point, positions: positions, camera: camera, size: size), "row \(row)")
            let document = try #require(index.document(at: hit.row), "row \(hit.row)")
            #expect(!document.volumeID.isEmpty)
            // NOT `hasPrefix("d")`. A first draft asserted that and passed only because the sampled
            // rows happened to be `dN`: `frus1958-60v05mSupp` keys its 628 documents `eta_d1…`, and
            // the corpus also carries `d373a`, `appA` and `s05sub04`. Asserting the shape would
            // have baked in the same assumption that mis-keyed 15,097 documents when the design
            // tried to derive ids from ordinals.
            #expect(!document.documentID.isEmpty, "row \(hit.row)")
            #expect(index.rows(forVolume: document.volumeID)?.contains(hit.row) == true)
            #expect(index.row(documentID: document.documentID,
                              volumeID: document.volumeID) == hit.row,
                    "identity must round-trip for \(document.volumeID)/\(document.documentID)")
        }
    }

    /// The scan runs once per tap, not per frame — but "once per tap" is still a human waiting, so
    /// the cost is measured rather than assumed. A linear pass over 1.9 MB should be well under the
    /// threshold; if this ever fails, a spatial index has become worth its second source of truth.
    @MainActor
    @Test("Picking the whole corpus is fast enough for a tap")
    func pickingIsFastEnough() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let size = CGSize(width: 600, height: 600)
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0),
                                       halfExtent: Float(map.gridExtent))
        // Picking scans what is DRAWN. In map mode that is the artifact's own placements — the same
        // array the model uploads — so the tests go through the same accessor the model does.
        let positions = SemanticMapModel.mapPoints(from: map).map(\.position)

        let start = ContinuousClock.now
        var found = 0
        for step in 0..<20 {
            let point = CGPoint(x: 40 + Double(step) * 26, y: 40 + Double(step) * 26)
            if SemanticMapPicking.hit(at: point, positions: positions, camera: camera, size: size) != nil {
                found += 1
            }
        }
        let each = (ContinuousClock.now - start) / 20
        #expect(each < .milliseconds(60), "a tap took \(each)")
        #expect(found > 0, "20 taps down the diagonal of a full-corpus map should hit something")
    }

    // MARK: - Lasso

    /// Even-odd, not winding: a hand-drawn path that crosses itself should leave the overlap
    /// *outside*, matching what the stroke looks like. A winding rule would swallow it.
    @Test("Containment is even-odd, and the boundary does not speckle")
    func polygonContainment() {
        let square = [SIMD2<Float>(0, 0), SIMD2<Float>(10, 0),
                      SIMD2<Float>(10, 10), SIMD2<Float>(0, 10)]
        #expect(SemanticMapPicking.contains(polygon: square, x: 5, y: 5))
        #expect(!SemanticMapPicking.contains(polygon: square, x: 15, y: 5))
        #expect(!SemanticMapPicking.contains(polygon: square, x: 5, y: -1))

        // A horizontal edge at the test point's own height is where a naive crossing test counts a
        // vertex twice and punches holes along the edge. Walk a row straight through it.
        for step in 1..<10 {
            #expect(SemanticMapPicking.contains(polygon: square, x: Float(step), y: 5),
                    "hole at x=\(step)")
        }

        // A concave "C": the notch is outside even though it is inside the bounding box.
        let cShape = [SIMD2<Float>(0, 0), SIMD2<Float>(10, 0), SIMD2<Float>(10, 3),
                      SIMD2<Float>(3, 3), SIMD2<Float>(3, 7), SIMD2<Float>(10, 7),
                      SIMD2<Float>(10, 10), SIMD2<Float>(0, 10)]
        #expect(SemanticMapPicking.contains(polygon: cShape, x: 1, y: 5), "the spine is inside")
        #expect(!SemanticMapPicking.contains(polygon: cShape, x: 7, y: 5), "the notch is outside")
    }

    /// The lasso must select what the reader drew — and the denominator must keep counting past the
    /// capture limit, because `WorkingCorpus` stores it as the thing a truncated capture is a
    /// fraction *of*.
    @MainActor
    @Test("A lasso selects the documents inside it and counts every one",
          .enabled(if: semanticMapHasMetal))
    func lassoSelectsEnclosedDocuments() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let size = CGSize(width: 600, height: 600)
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0),
                                       halfExtent: Float(map.gridExtent))
        // Picking scans what is DRAWN. In map mode that is the artifact's own placements — the same
        // array the model uploads — so the tests go through the same accessor the model does.
        let positions = SemanticMapModel.mapPoints(from: map).map(\.position)

        // A box around the whole grid encloses the entire corpus.
        let everything = [CGPoint(x: -50, y: -50), CGPoint(x: 650, y: -50),
                          CGPoint(x: 650, y: 650), CGPoint(x: -50, y: 650)]
        let all = SemanticMapPicking.rows(
            inside: everything, positions: positions, camera: camera, size: size, limit: 100)
        #expect(all.total == map.documentCount, "every document is inside a lasso around everything")
        #expect(all.rows.count == 100, "but only the limit is kept")

        // Degenerate paths select nothing rather than everything.
        #expect(SemanticMapPicking.rows(
            inside: [CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 20)],
            positions: positions, camera: camera, size: size, limit: 100).total == 0)

        // A small box around one document's own position must contain it.
        let target = try #require(map.placement(at: 200_000))
        let at = SemanticMapLabelLayout.project(
            SIMD2<Float>(Float(target.x), Float(target.y)), camera: camera, size: size)
        let tight = [CGPoint(x: at.x - 6, y: at.y - 6), CGPoint(x: at.x + 6, y: at.y - 6),
                     CGPoint(x: at.x + 6, y: at.y + 6), CGPoint(x: at.x - 6, y: at.y + 6)]
        let near = SemanticMapPicking.rows(
            inside: tight, positions: positions, camera: camera, size: size, limit: 5_000)
        #expect(near.rows.contains(200_000), "the lasso must contain the point it was drawn around")
    }

    /// The capture limit is the synced record's size budget, so a lasso must respect it and say so
    /// rather than quietly writing a corpus larger than the model was designed for.
    @MainActor
    @Test("A lasso over everything is capped, and reports what it left out",
          .enabled(if: semanticMapHasMetal))
    func lassoRespectsTheCaptureLimit() async throws {
        await BundledSemanticMap.prepare()
        let map = try #require(BundledSemanticMap.vectors)
        let size = CGSize(width: 600, height: 600)
        let camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0),
                                       halfExtent: Float(map.gridExtent))
        // Picking scans what is DRAWN. In map mode that is the artifact's own placements — the same
        // array the model uploads — so the tests go through the same accessor the model does.
        let positions = SemanticMapModel.mapPoints(from: map).map(\.position)
        let everything = [CGPoint(x: -50, y: -50), CGPoint(x: 650, y: -50),
                          CGPoint(x: 650, y: 650), CGPoint(x: -50, y: 650)]

        let capped = SemanticMapPicking.rows(
            inside: everything, positions: positions, camera: camera, size: size,
            limit: SemanticMapPicking.corpusCaptureLimit)
        #expect(capped.rows.count == SemanticMapPicking.corpusCaptureLimit)
        #expect(capped.total == map.documentCount)

        let result = SemanticMapPicking.LassoResult(
            documentKeys: (0..<capped.rows.count).map { "v/d\($0)" },
            total: capped.total, regionNames: [])
        #expect(result.isTruncated, "a capture that kept 7,500 of 314,483 is truncated")

        // And a capture inside the limit must NOT claim truncation — `wasTruncatedAtCapture` is a
        // three-state read where a wrong `true` is as misleading as a wrong `false`.
        let whole = SemanticMapPicking.LassoResult(
            documentKeys: ["v/d1", "v/d2"], total: 2, regionNames: [])
        #expect(!whole.isTruncated)
    }

    // MARK: - Semantic axis

    /// The axis is the normalised difference of two poles, and two poles that are the same point have
    /// no direction between them — normalising that would produce a direction made of rounding.
    @Test("An axis is the unit difference of its poles, and identical poles make none")
    func axisIsNormalisedDifference() throws {
        let axis = try #require(SemanticAxis.between(
            negative: [1, 0, 0, 0], negativeLabel: "a",
            positive: [0, 1, 0, 0], positiveLabel: "b"))
        let length = axis.direction.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        #expect(abs(length - 1) < 1e-5, "direction must be unit-norm, was \(length)")
        #expect(axis.direction[0] < 0, "away from the negative pole")
        #expect(axis.direction[1] > 0, "toward the positive pole")

        #expect(SemanticAxis.between(negative: [1, 2, 3], negativeLabel: "a",
                                     positive: [1, 2, 3], positiveLabel: "b") == nil)
        #expect(SemanticAxis.between(negative: [], negativeLabel: "a",
                                     positive: [], positiveLabel: "b") == nil)
        #expect(SemanticAxis.between(negative: [1, 0], negativeLabel: "a",
                                     positive: [0, 1, 0], positiveLabel: "b") == nil,
                "mismatched widths have no difference")
    }

    /// The bit convention is the artifact's and must not be re-derived: MSB-first, with zero packed
    /// as a SET bit. Get it backwards and every coordinate is still a plausible number.
    @Test("Projection reads sign bits MSB-first, set-bit-positive")
    func projectionReadsTheArtifactsBitOrder() {
        // A 16-dimension axis pointing entirely at dimension 0.
        var direction = [Float](repeating: 0, count: 16)
        direction[0] = 1
        let axis = SemanticAxis(direction: direction, negativeLabel: "a", positiveLabel: "b")

        // 0b1000_0000 sets the MOST significant bit, which is dimension 0.
        var bytes: [UInt8] = [0b1000_0000, 0b0000_0000]
        var high = Float(0)
        bytes.withUnsafeBytes { raw in
            high = axis.project(signBitsAt: raw.baseAddress!, row: 0, bytesPerRow: 2)
        }
        #expect(high > 0, "a set high bit is +1 along dimension 0")

        bytes = [0b0111_1111, 0b1111_1111]
        var low = Float(0)
        bytes.withUnsafeBytes { raw in
            low = axis.project(signBitsAt: raw.baseAddress!, row: 0, bytesPerRow: 2)
        }
        #expect(low < 0, "a clear high bit is -1 along dimension 0")
        #expect(abs(high + low) < 1e-5, "the two must be exact opposites on this axis")

        // The coordinate is a cosine: a document whose every bit agrees with a uniform axis lands at
        // exactly 1, which is what bounds the slice grid.
        let uniform = SemanticAxis(
            direction: [Float](repeating: 1 / Float(16).squareRoot(), count: 16),
            negativeLabel: "a", positiveLabel: "b")
        var allSet: [UInt8] = [0xFF, 0xFF]
        var extreme = Float(0)
        allSet.withUnsafeBytes { raw in
            extreme = uniform.project(signBitsAt: raw.baseAddress!, row: 0, bytesPerRow: 2)
        }
        #expect(abs(extreme - 1) < 1e-5, "all bits agreeing is the +1 end, was \(extreme)")
    }

    /// Dequantizing a centroid is `code * scale`, and the poles depend on it being exactly that.
    @Test("Centroid dequantization is code times scale")
    func centroidDequantization() {
        let vector = SemanticAxis.dequantize(codes: [127, -128, 0, 64], scale: 0.01)
        #expect(abs(vector[0] - 1.27) < 1e-5)
        #expect(abs(vector[1] + 1.28) < 1e-5)
        #expect(vector[2] == 0)
        #expect(abs(vector[3] - 0.64) < 1e-5)
    }

    /// Builds a cluster record for the layout tests.
    /// - Parameters:
    ///   - id: Cluster id.
    ///   - terms: Its label terms.
    ///   - x: Grid x of its centre.
    ///   - y: Grid y of its centre.
    ///   - documents: How many documents it holds.
    /// - Returns: The cluster.
    private func makeCluster(
        id: Int, terms: [String], x: Int, y: Int, documents: Int
    ) -> SemanticMapArtifacts.Cluster {
        SemanticMapArtifacts.Cluster(
            id: id, terms: terms, documentCount: documents,
            centreX: x, centreY: y, eraCounts: [:])
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
