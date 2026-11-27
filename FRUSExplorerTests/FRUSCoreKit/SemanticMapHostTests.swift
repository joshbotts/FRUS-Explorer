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
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds SemanticVectorsKit as a module of its own; Xcode compiles it into the app.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

// MARK: - SemanticMapHostTests

/// The map's rules as a host outside the app calls them: over the bundled map and vectors, a catalogue's
/// coverage, a set of volumes it serves and the bundled provenance aggregate, each loaded by URL, and in
/// the map's own coordinates where the app works in a view's points. No model, no renderer, no bundle.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S28a — the map's rules moved into FRUSCoreKit
///   1.1 — 2026-11-27: row L32 of the plan of record from 2026-11-25 (#1986) — a slice with no dated
///          volume, which trapped on the unchanged kit, and a slice with one
@Suite("Semantic map — the rules over a host's values")
struct SemanticMapHostTests {

    /// A catalogue's entries by volume, as a host keys the bundled manifest.
    private static func catalogue() throws -> [String: VolumeManifestEntry] {
        Dictionary(try testManifestEntries().map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    @Test("Every lens gives each point a slot from a host's facts, and names every slot it gives")
    func lensesColourFromAHostsFacts() throws {
        let loaded = try SemanticMapFixture.load()
        let catalogue = try Self.catalogue()
        let served = Set(loaded.index.volumes.prefix(4).map(\.volumeID))
        let dominant = SemanticMapVolumes.dominantProvenance(byVolume: try SemanticMapFixture.provenanceByVolume())
        for lens in SemanticMapLens.allCases {
            let slots = SemanticMapColouring.indices(
                for: lens, map: loaded.map, index: loaded.index,
                eraForVolume: { SemanticMapVolumes.era(of: catalogue[$0]) },
                isDownloaded: { served.contains($0) },
                provenanceForVolume: { dominant[$0] })
            #expect(slots.count == loaded.map.documentCount, "\(lens.rawValue)")
            #expect(slots.allSatisfy { Int($0) < SemanticMapColouring.paletteSize }, "\(lens.rawValue)")
            if lens.namesEveryColour {
                #expect(slots.allSatisfy { Int($0) < lens.legend.count }, "\(lens.rawValue) paints an unnamed slot")
            }
        }
        // The era lens bands each volume by its coverage's midpoint, row for row.
        let eras = SemanticMapColouring.indices(
            for: .era, map: loaded.map, index: loaded.index,
            eraForVolume: { SemanticMapVolumes.era(of: catalogue[$0]) }, isDownloaded: { _ in false })
        for volume in loaded.index.volumes.prefix(20) {
            let rows = try #require(loaded.index.rows(forVolume: volume.volumeID))
            let expected = UInt8((SemanticMapVolumes.era(of: catalogue[volume.volumeID])?.rawValue ?? 0)
                                 % SemanticMapColouring.paletteSize)
            #expect(rows.allSatisfy { eras[$0] == expected }, "\(volume.volumeID)")
        }
    }

    @Test("A volume's era keeps every year of its range; the slice's year keeps those inside the series")
    func eraAndYearReadTheCoverage() throws {
        let entry = try #require(try testManifestEntries().first {
            $0.dateRange.earliest != nil && $0.dateRange.latest != nil
        })
        let earliest = try #require(entry.dateRange.earliest.flatMap { Int($0.prefix(4)) })
        let latest = try #require(entry.dateRange.latest.flatMap { Int($0.prefix(4)) })
        #expect(SemanticMapVolumes.era(of: entry) == CoverageEra.bucket(year: (earliest + latest) / 2))
        #expect(SemanticMapVolumes.coverageYear(of: entry) == (earliest + latest) / 2)
        #expect(SemanticMapVolumes.era(of: nil) == nil && SemanticMapVolumes.coverageYear(of: nil) == nil)

        // A range with a year outside the series: the era's midpoint keeps it, the slice's year drops it.
        let odd = try Self.entry(entry, earliest: "1600-01-01", latest: "1960-12-31")
        #expect(SemanticMapVolumes.era(of: odd) == CoverageEra.bucket(year: (1600 + 1960) / 2))
        #expect(SemanticMapVolumes.coverageYear(of: odd) == 1960)
        let undated = try Self.entry(entry, earliest: nil, latest: nil)
        #expect(SemanticMapVolumes.era(of: undated) == nil && SemanticMapVolumes.coverageYear(of: undated) == nil)
    }

    /// `entry` with another coverage range, through its own coding.
    private static func entry(_ entry: VolumeManifestEntry, earliest: String?, latest: String?) throws
        -> VolumeManifestEntry {
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any])
        let key = try #require(object.first { ($0.value as? [String: Any])?.keys.contains("earliest") == true }?.key)
        var range: [String: Any] = [:]
        if let earliest { range["earliest"] = earliest }
        if let latest { range["latest"] = latest }
        object[key] = range
        return try JSONDecoder().decode(VolumeManifestEntry.self,
                                        from: JSONSerialization.data(withJSONObject: object))
    }

    @Test("The plane's positions are the artifact's placements, row for row")
    func planePositionsAreThePlacements() throws {
        let loaded = try SemanticMapFixture.load()
        let positions = SemanticMapPicking.positions(of: loaded.map)
        #expect(positions.count == loaded.map.documentCount)
        for row in stride(from: 0, to: positions.count, by: 997) {
            let placement = try #require(loaded.map.placement(at: row))
            #expect(positions[row] == SIMD2(placement.x, placement.y), "row \(row)")
        }
    }

    @Test("A pick in the map's coordinates finds the point there, refuses empty map and honours the scope")
    func picksInGridCoordinates() throws {
        let loaded = try SemanticMapFixture.load()
        let positions = SemanticMapPicking.positions(of: loaded.map)
        let row = 123_456
        let grid = SIMD2<Float>(Float(positions[row].x), Float(positions[row].y))
        let hit = try #require(SemanticMapPicking.hit(nearGrid: grid, tolerance: 1, positions: positions))
        #expect(hit.position == grid)
        let far = SIMD2<Float>(Float(loaded.map.gridExtent) * 4, Float(loaded.map.gridExtent) * 4)
        #expect(SemanticMapPicking.hit(nearGrid: far, tolerance: 100, positions: positions) == nil)

        // The view-point form is this one over the unprojected tap.
        let camera = SemanticMapCamera(centre: .zero, halfExtent: Float(loaded.map.gridExtent))
        let size = CGSize(width: 600, height: 600)
        let tap = SemanticMapLabelLayout.project(grid, camera: camera, size: size)
        #expect(SemanticMapPicking.hit(at: tap, positions: positions, camera: camera, size: size)?.position == grid)

        // A scope that leaves the point's volume out makes it unpickable.
        let document = try #require(loaded.index.document(at: row))
        let other = try #require(loaded.index.volumes.first { $0.volumeID != document.volumeID }?.volumeID)
        let mask = try #require(SemanticMapColouring.scopeMask(volumeIDs: [other], map: loaded.map,
                                                               index: loaded.index))
        let scoped = SemanticMapPicking.hit(nearGrid: grid, tolerance: 1, positions: positions,
                                            scopeMask: mask.flags)
        #expect(scoped.map { mask.flags[$0.row] == 0 } ?? true, "a ghost was pickable")
    }

    @Test("A lasso in the map's coordinates catches what it encloses, capped, under the scope")
    func lassoesInGridCoordinates() throws {
        let loaded = try SemanticMapFixture.load()
        let positions = SemanticMapPicking.positions(of: loaded.map)
        let extent = Float(loaded.map.gridExtent) + 1
        let everything = [SIMD2<Float>(-extent, -extent), SIMD2(extent, -extent),
                          SIMD2(extent, extent), SIMD2(-extent, extent)]
        let all = SemanticMapPicking.rows(insideGrid: everything, positions: positions,
                                          limit: SemanticMapPicking.corpusCaptureLimit)
        #expect(all.total == loaded.map.documentCount)
        #expect(all.rows == Array(0..<SemanticMapPicking.corpusCaptureLimit), "the first rows, ascending")

        let row = 200_000
        let at = SIMD2<Float>(Float(positions[row].x), Float(positions[row].y))
        let tight = [at + SIMD2(-3, -3), at + SIMD2(3, -3), at + SIMD2(3, 3), at + SIMD2(-3, 3)]
        #expect(SemanticMapPicking.rows(insideGrid: tight, positions: positions, limit: 100).rows.contains(row))
        #expect(SemanticMapPicking.rows(insideGrid: Array(tight.prefix(2)), positions: positions,
                                        limit: 100).total == 0, "two points enclose nothing")

        let volume = try #require(loaded.index.volumes.first?.volumeID)
        let mask = try #require(SemanticMapColouring.scopeMask(volumeIDs: [volume], map: loaded.map,
                                                               index: loaded.index))
        let scoped = SemanticMapPicking.rows(insideGrid: everything, positions: positions,
                                             limit: SemanticMapPicking.corpusCaptureLimit, scopeMask: mask.flags)
        #expect(scoped.total == mask.documentCount)
        #expect(scoped.rows.allSatisfy { mask.flags[$0] == 0 })
    }

    @Test("A region's capture is its members, capped, named for it, and gated by the scope")
    func regionCaptureTakesItsMembers() throws {
        let loaded = try SemanticMapFixture.load()
        let region = try #require(ClustersAxis.ordered(loaded.mapIndex.clusters).first)
        let capture = SemanticMapCapture.region(region, map: loaded.map, index: loaded.index, scopeMask: nil)
        #expect(capture.total == region.documentCount)
        #expect(capture.documentKeys.count == min(region.documentCount, SemanticMapPicking.corpusCaptureLimit))
        #expect(capture.isTruncated == (region.documentCount > SemanticMapPicking.corpusCaptureLimit))
        #expect(capture.regionNames == [region.terms.prefix(3).joined(separator: " ")])
        let member = try #require(capture.documentKeys.first.flatMap(SemanticMapReveal.documentKey))
        let memberRow = try #require(loaded.index.row(documentID: member.documentID, volumeID: member.volumeID))
        #expect(loaded.map.placement(at: memberRow)?.cluster == UInt16(region.id))

        let volume = try #require(loaded.index.volumes.first { volume in
            loaded.index.rows(forVolume: volume.volumeID).map { rows in
                rows.contains { loaded.map.placement(at: $0)?.cluster == UInt16(region.id) }
            } ?? false
        }?.volumeID, "no volume holds the largest region")
        let mask = try #require(SemanticMapColouring.scopeMask(volumeIDs: [volume], map: loaded.map,
                                                               index: loaded.index))
        let scoped = SemanticMapCapture.region(region, map: loaded.map, index: loaded.index, scopeMask: mask.flags)
        #expect(scoped.total == mask.regionCounts[UInt16(region.id)])
        #expect(scoped.documentKeys.allSatisfy { $0.hasPrefix("\(volume)/") })
    }

    @Test("A lasso's capture is named by the regions it caught most of; an empty one says so only under a scope")
    func lassoCaptureNamesItsRegions() throws {
        let loaded = try SemanticMapFixture.load()
        let ordered = ClustersAxis.ordered(loaded.mapIndex.clusters)
        let first = try #require(ordered.first), second = try #require(ordered.dropFirst().first)
        func rows(of region: SemanticMapArtifacts.Cluster, _ count: Int) -> [Int] {
            Array((0..<loaded.map.documentCount).lazy
                .filter { loaded.map.placement(at: $0)?.cluster == UInt16(region.id) }.prefix(count))
        }
        let between = Array((0..<loaded.map.documentCount).lazy
            .filter { loaded.map.placement(at: $0)?.cluster == SemanticMapArtifacts.unclustered }.prefix(3))
        let caught = (rows(of: second, 4) + rows(of: first, 9) + between).sorted()
        let capture = try #require(SemanticMapCapture.lasso(
            rows: caught, total: caught.count + 40, isScoped: false, map: loaded.map, index: loaded.index,
            clusters: loaded.mapIndex.clusters))
        #expect(capture.documentKeys.count == caught.count)
        #expect(capture.total == caught.count + 40)
        #expect(capture.regionNames == [first, second].map { $0.terms.prefix(2).joined(separator: " ") })

        #expect(SemanticMapCapture.lasso(rows: [], total: 0, isScoped: false, map: loaded.map,
                                         index: loaded.index, clusters: loaded.mapIndex.clusters) == nil)
        #expect(SemanticMapCapture.lasso(rows: [], total: 0, isScoped: true, map: loaded.map,
                                         index: loaded.index, clusters: loaded.mapIndex.clusters)
                == SemanticMapPicking.LassoResult(documentKeys: [], total: 0, regionNames: []))
    }

    @Test("A capture's name joins its regions and its stamp, and its description names the scope")
    func captureNameAndDescription() {
        #expect(SemanticMapCapture.corpusName(regionNames: ["soviet polish", "iran shah"], stamp: "S")
                == "soviet polish, iran shah — S")
        #expect(SemanticMapCapture.corpusName(regionNames: [], stamp: "S") == "Map selection — S")
        #expect(SemanticMapCapture.sourceDescription(scopeLabel: nil) == "Semantic map selection")
        #expect(SemanticMapCapture.sourceDescription(scopeLabel: "Truman")
                == "Semantic map selection, scoped to Truman")
        let day = Date(timeIntervalSince1970: 1_795_000_000)   // November 2026
        let stamp = SemanticMapCapture.stamp(for: day, locale: Locale(identifier: "en_US"),
                                             timeZone: TimeZone(identifier: "UTC")!)
        #expect(stamp.contains("2026") && stamp.contains("Nov"), "\(stamp)")
    }

    @Test("A slice lays every row along the axis and up its volume's year, the undated in the gutter")
    func sliceLaysTheCorpusOut() throws {
        let loaded = try SemanticMapFixture.load()
        let catalogue = try Self.catalogue()
        let low = try #require(loaded.index.volumes.first?.volumeID)
        let high = try #require(loaded.index.volumes.last?.volumeID)
        let centroid = { SemanticAxis.centroid(forVolume: $0, index: loaded.index, corpus: loaded.corpus) }
        #expect(centroid(low)?.count == loaded.corpus.dims)
        #expect(centroid("frus-no-such-volume") == nil)
        guard case .axis(let axis) = SemanticMapPoles.resolve(negative: low, positive: high, isReady: true,
                                                              centroid: centroid) else {
            Issue.record("the series' first and last volumes made no axis"); return
        }
        let layout = SemanticMapSlice.layout(
            along: axis, map: loaded.map, index: loaded.index, corpus: loaded.corpus,
            yearForVolume: { SemanticMapVolumes.coverageYear(of: catalogue[$0]) })
        let extent = Int16(SemanticAxis.sliceExtent)
        #expect(layout.positions.count == loaded.map.documentCount)
        #expect(layout.positions.map(\.x).min() == -extent && layout.positions.map(\.x).max() == extent,
                "the projection is scaled to fill the slice's width")
        #expect(layout.scale.minYear < layout.scale.maxYear)

        var undated = 0
        for volume in loaded.index.volumes {
            let rows = try #require(loaded.index.rows(forVolume: volume.volumeID))
            let y: Int16
            if let year = SemanticMapVolumes.coverageYear(of: catalogue[volume.volumeID]) {
                y = Int16(clamping: Int(SemanticMapSlice.y(forYear: year, scale: layout.scale)
                                        * Float(SemanticAxis.sliceExtent)))
            } else {
                undated += rows.count
                y = Int16(clamping: Int(SemanticMapSlice.gutterY * Float(SemanticAxis.sliceExtent)))
            }
            #expect(rows.allSatisfy { abs(Int(layout.positions[$0].y) - Int(y)) <= 1 }, "\(volume.volumeID)")
        }
        #expect(layout.scale.undatedCount == undated)
    }

    @Test("A slice with no dated volume lays every row in the gutter, along the axis, with no year to tick")
    func undatedSliceLaysOutInTheGutter() throws {
        // #1986: with no volume dated, the year span's sentinels were still Int.max and Int.min, and
        // their difference trapped. The app never meets it while the manifest dates all 553 volumes;
        // a host whose catalogue gives no coverage year ended its process here.
        let loaded = try SemanticMapFixture.load()
        let layout = try SemanticMapFixture.slice(loaded, yearForVolume: { _ in nil })
        let extent = Int16(SemanticAxis.sliceExtent)
        let gutter = Int16(clamping: Int(SemanticMapSlice.gutterY * Float(SemanticAxis.sliceExtent)))
        #expect(layout.positions.count == loaded.map.documentCount)
        #expect(layout.positions.allSatisfy { $0.y == gutter }, "an undated row sits off the gutter")
        let xs = layout.positions.map { $0.x }
        #expect(xs.min() == -extent && xs.max() == extent,
                "the order along the axis, which is the slice's content, went with the years")
        #expect(layout.scale == SemanticMapSlice.Scale(minYear: 0, maxYear: 0,
                                                       undatedCount: loaded.map.documentCount,
                                                       hasDatedYears: false))
        #expect(SemanticMapSlice.tickYears(for: layout.scale).isEmpty,
                "a slice with no dated volume would label its edge with a year 0")
    }

    @Test("One dated volume sits on the dated band's lowest line, at the span's floor of a year")
    func oneDatedVolumeSitsOnTheBandsFloor() throws {
        let loaded = try SemanticMapFixture.load()
        let dated = try #require(loaded.index.volumes.dropFirst(5).first?.volumeID)
        let rows = try #require(loaded.index.rows(forVolume: dated))
        try #require(!rows.isEmpty)
        let layout = try SemanticMapFixture.slice(loaded, yearForVolume: { $0 == dated ? 1950 : nil })
        #expect(layout.scale == SemanticMapSlice.Scale(minYear: 1950, maxYear: 1950,
                                                       undatedCount: loaded.map.documentCount - rows.count))
        #expect(layout.scale.hasDatedYears)
        let floorY = SemanticMapSlice.y(forYear: 1950, scale: layout.scale)
        #expect(abs(floorY - -0.82) < 1e-6, "one year spans nothing, so the span's floor of 1 applies")
        let floor = Int16(clamping: Int(floorY * Float(SemanticAxis.sliceExtent)))
        let gutter = Int16(clamping: Int(SemanticMapSlice.gutterY * Float(SemanticAxis.sliceExtent)))
        #expect(rows.allSatisfy { layout.positions[$0].y == floor }, "the dated volume left the band's floor")
        #expect(layout.positions.indices.allSatisfy { rows.contains($0) || layout.positions[$0].y == gutter },
                "an undated row sits off the gutter")
        #expect(SemanticMapSlice.tickYears(for: layout.scale) == [1950])
    }

    @Test("The scope's sentence counts whole volumes, and says when a scope holds nothing mapped")
    func scopeSummaryNamesWholeVolumes() {
        #expect(SemanticMapColouring.scopeSummary(documents: 0, volumes: 0, ofVolumes: 553)
                == "No mapped documents in this scope.")
        #expect(SemanticMapColouring.scopeSummary(documents: 120, volumes: 2, ofVolumes: 553)
                == "In scope: 120 mapped documents — whole volumes, 2 of 553.")
    }

    @Test("A region's name in a tap is its first three terms; between regions it has none")
    func regionNamesByRow() throws {
        let loaded = try SemanticMapFixture.load()
        let clusters = loaded.mapIndex.clusters
        let clustered = try #require((0..<10_000).first {
            loaded.map.placement(at: $0)?.cluster != SemanticMapArtifacts.unclustered
        })
        let between = try #require((0..<10_000).first {
            loaded.map.placement(at: $0)?.cluster == SemanticMapArtifacts.unclustered
        })
        let region = try #require(clusters.first { $0.id == Int(loaded.map.placement(at: clustered)!.cluster) })
        #expect(SemanticMapPicking.regionName(ofRow: clustered, map: loaded.map, clusters: clusters)
                == region.terms.prefix(3).joined(separator: " "))
        #expect(SemanticMapPicking.regionName(ofRow: between, map: loaded.map, clusters: clusters) == nil)
    }
}
