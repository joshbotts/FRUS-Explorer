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
@testable import FRUSExplorer

/// The map surface: the bundled loader, and what a colour means.
///
/// Version history:
///   1.0 — V-4: initial implementation
@Suite("Semantic map surface")
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
