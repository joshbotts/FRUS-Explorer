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
import simd

/// What the map's colour means.
///
/// Every lens here is computable from data the app already carries — the map's own cluster ids, the
/// manifest's coverage dates, and which volumes are indexed — so switching lens rewrites one byte per
/// document (314 KB) and never touches a coordinate. The design's remaining lenses (provenance
/// category, subject tags, administration) are the same shape: a per-volume or per-document lookup
/// filling the same palette index.
///
/// Version history:
///   1.0 — V-4: initial implementation
enum SemanticMapLens: String, CaseIterable, Identifiable, Sendable {
    /// The regions the layout found. The map's own structure, and the only lens whose data lives in
    /// the map artifact itself.
    case cluster
    /// When the documents were written — the axis a historian reaches for first.
    case era
    /// Whether this device can open the document. Turns the map into a picture of the reader's own
    /// library against the whole corpus.
    case availability

    var id: String { rawValue }

    /// The user-facing name.
    var displayName: String {
        switch self {
        case .cluster:
            return String(localized: "semanticMap.lens.cluster", defaultValue: "Regions")
        case .era:
            return String(localized: "semanticMap.lens.era", defaultValue: "Era")
        case .availability:
            return String(localized: "semanticMap.lens.availability",
                          defaultValue: "Downloaded")
        }
    }

    /// The legend, in palette-index order — so a caller can label the colours without knowing how
    /// the indices are assigned.
    var legend: [String] {
        switch self {
        case .cluster:
            return [String(localized: "semanticMap.legend.unclustered",
                           defaultValue: "Between regions")]
        case .era:
            return CoverageEra.allCases.map(\.label)
        case .availability:
            return [String(localized: "semanticMap.legend.notDownloaded",
                           defaultValue: "Not downloaded"),
                    String(localized: "semanticMap.legend.downloaded",
                           defaultValue: "Downloaded")]
        }
    }
}

/// Builds the per-document palette indices a lens implies.
///
/// The work is deliberately **per volume, not per document**: every lens except `cluster` is a
/// property of the volume, and the map's rows are contiguous per volume, so a lens is a few hundred
/// range fills rather than 314,483 lookups. `cluster` reads the map's own bytes.
///
/// Version history:
///   1.0 — V-4: initial implementation
enum SemanticMapColouring {

    /// How many palette slots the renderer holds.
    static let paletteSize = 16

    /// Builds colour indices for every document.
    ///
    /// - Parameters:
    ///   - lens: The lens to colour by.
    ///   - map: The mapped placements.
    ///   - index: The vector index, for volume row ranges.
    ///   - eraForVolume: A volume's coverage era.
    ///   - isDownloaded: Whether a volume is indexed on this device.
    /// - Returns: One palette index per document, in row order.
    static func indices(
        for lens: SemanticMapLens,
        map: SemanticMapVectors,
        index: SemanticVectorIndex,
        eraForVolume: (String) -> CoverageEra?,
        isDownloaded: (String) -> Bool
    ) -> [UInt8] {
        var colours = [UInt8](repeating: 0, count: map.documentCount)
        switch lens {
        case .cluster:
            // Clusters are cycled through the palette rather than given unique colours: there are 179
            // of them and 16 slots, and a map that tried to distinguish all of them by hue would
            // distinguish none of them. Adjacency, not identity, is what the colour conveys — the
            // label at a region's centre is what names it.
            map.withPlacements { base, count in
                for row in 0..<count {
                    let cluster = base.loadUnaligned(
                        fromByteOffset: row * SemanticMapArtifacts.bytesPerDocument + 4,
                        as: UInt16.self).littleEndian
                    colours[row] = cluster == SemanticMapArtifacts.unclustered
                        ? 0
                        : UInt8(1 + Int(cluster) % (paletteSize - 1))
                }
            }
        case .era:
            for volume in index.volumes {
                guard let range = index.rows(forVolume: volume.volumeID) else { continue }
                let slot = UInt8((eraForVolume(volume.volumeID)?.rawValue ?? 0) % paletteSize)
                for row in range where row < colours.count { colours[row] = slot }
            }
        case .availability:
            for volume in index.volumes {
                guard let range = index.rows(forVolume: volume.volumeID) else { continue }
                let slot: UInt8 = isDownloaded(volume.volumeID) ? 1 : 0
                for row in range where row < colours.count { colours[row] = slot }
            }
        }
        return colours
    }

    /// The palette a lens draws with.
    ///
    /// Deliberately not one scheme for everything: `era` is ordered and gets a sequential ramp,
    /// `availability` is a two-state contrast, and `cluster` is categorical. Using a categorical
    /// palette for an ordered variable is the commonest way a map lies about its data.
    ///
    /// - Parameter lens: The active lens.
    /// - Returns: RGBA colours, palette-index ordered.
    static func palette(for lens: SemanticMapLens) -> [SIMD4<Float>] {
        switch lens {
        case .cluster:
            // Slot 0 is the unclustered 28% — deliberately dim, so the regions read as figure and
            // the space between them as ground.
            return [SIMD4(0.35, 0.37, 0.42, 0.30)] + (1..<paletteSize).map { index in
                let hue = Float(index - 1) / Float(paletteSize - 1)
                return hsb(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 0.72)
            }
        case .era:
            // A sequential ramp, dark to light, because era is ordered.
            return (0..<paletteSize).map { index in
                let t = Float(min(index, CoverageEra.allCases.count - 1))
                    / Float(max(1, CoverageEra.allCases.count - 1))
                return SIMD4(0.25 + 0.55 * t, 0.45 + 0.35 * t, 0.85 - 0.20 * t, 0.70)
            }
        case .availability:
            return [SIMD4(0.34, 0.36, 0.40, 0.28), SIMD4(0.35, 0.78, 0.52, 0.80)]
                + Array(repeating: SIMD4(0.35, 0.78, 0.52, 0.80), count: paletteSize - 2)
        }
    }

    /// Converts HSB to linear-ish RGBA for the palette.
    /// - Parameters:
    ///   - hue: 0–1.
    ///   - saturation: 0–1.
    ///   - brightness: 0–1.
    ///   - alpha: 0–1.
    /// - Returns: The RGBA colour.
    static func hsb(hue: Float, saturation: Float, brightness: Float, alpha: Float)
        -> SIMD4<Float> {
        let sector = (hue - hue.rounded(.down)) * 6
        let fraction = sector - sector.rounded(.down)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * fraction)
        let t = brightness * (1 - saturation * (1 - fraction))
        switch Int(sector) % 6 {
        case 0: return SIMD4(brightness, t, p, alpha)
        case 1: return SIMD4(q, brightness, p, alpha)
        case 2: return SIMD4(p, brightness, t, alpha)
        case 3: return SIMD4(p, q, brightness, alpha)
        case 4: return SIMD4(t, p, brightness, alpha)
        default: return SIMD4(brightness, p, q, alpha)
        }
    }
}
