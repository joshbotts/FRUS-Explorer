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
/// manifest's coverage dates, which volumes are indexed, and the bundled provenance aggregate — so
/// switching lens rewrites one byte per document (314 KB) and never touches a coordinate. The
/// design's remaining lenses (subject tags, administration) are the same shape: a per-volume lookup
/// filling the same palette index. Both are held back for a reason worth stating — 107 subseries and
/// 32 administrations against 16 slots means cycling hues, and a cycled categorical colour that no
/// key can name is decoration.
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
    /// Where the volume's documents were found — the archival category most of its source notes
    /// name. The design singles this one out: *"watch the central files give way to presidential
    /// libraries across the space"*.
    case provenance

    var id: String { rawValue }

    /// Whether this lens can be drawn from what this build carries.
    ///
    /// **A lens that cannot be computed is withheld, not shown empty.** `provenance` reads the
    /// bundled aggregate's schema-2 `byVolume` table; an older artifact carries only `byDecade`, and
    /// colouring every volume "unknown" would say something false about the corpus rather than about
    /// the build. Same posture as `SourceProvenanceData.supportsVolumeScope`.
    ///
    /// - Parameter volumeProvenance: The per-volume provenance table, when the artifact has one.
    /// - Returns: `true` when the lens has data to draw.
    func isAvailable(volumeProvenance: [VolumeProvenance]?) -> Bool {
        switch self {
        case .cluster, .era, .availability: return true
        case .provenance: return !(volumeProvenance ?? []).isEmpty
        }
    }

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
        case .provenance:
            return String(localized: "semanticMap.lens.provenance",
                          defaultValue: "Provenance")
        }
    }

    /// What the lens measures, in one sentence, for the caption under the map.
    ///
    /// `provenance` is the one that needs it, and the first draft of this caption was itself wrong.
    /// It is a **per-volume** reading — the category a volume's source notes name most often — on a
    /// map whose points are documents, so every point in a volume takes one colour. The draft called
    /// that colour the volume's "larger half", which is false for **73 of the 522** covered volumes,
    /// where the winner holds under half the notes; it is a plurality. The caption now says so, and
    /// names the evidence floor, because a solid block of colour otherwise reads as a stronger claim
    /// than the data makes.
    ///
    /// `cluster` gets one too, for a different reason: its key can name only one of the sixteen
    /// colours it uses (`namesEveryColour`), so the caption is what stops the other fifteen from
    /// looking like an unlabelled code.
    var caption: String? {
        switch self {
        case .cluster:
            return String(localized: "semanticMap.lens.cluster.caption",
                          defaultValue: "Colour separates neighbouring regions rather than naming them; the names are on the map.")
        case .era, .availability:
            return nil
        case .provenance:
            return String(localized: "semanticMap.lens.provenance.caption.v2",
                          defaultValue: "Each volume takes the category its source notes name most often — a plurality, not a majority, for 73 of 522 volumes. Volumes with ten notes or fewer are left uncoloured.")
        }
    }

    /// Whether the key under the map can name every colour the lens produces.
    ///
    /// **`cluster` cannot, and says so rather than pretending.** It cycles 179 regions through 15
    /// slots — adjacency, not identity, is what its colour conveys, and the region *names* are drawn
    /// on the map itself. Every other lens names each colour exactly once, and
    /// `SemanticMapSurfaceTests` holds them to it against the slots the colouring actually hands out.
    var namesEveryColour: Bool {
        switch self {
        case .cluster: return false
        case .era, .availability, .provenance: return true
        }
    }

    /// The legend, in palette-index order — so a caller can label the colours without knowing how
    /// the indices are assigned.
    var legend: [String] {
        switch self {
        case .cluster:
            // One entry, and `namesEveryColour` is false: the other fifteen slots cycle through 179
            // regions, which the map labels by name where they sit.
            return [String(localized: "semanticMap.legend.unclustered",
                           defaultValue: "Between regions")]
        case .era:
            return CoverageEra.allCases.map(\.label)
        case .availability:
            return [String(localized: "semanticMap.legend.notDownloaded",
                           defaultValue: "Not downloaded"),
                    String(localized: "semanticMap.legend.downloaded",
                           defaultValue: "Downloaded")]
        case .provenance:
            // Slot 0 is every volume the lens will not speak for: the 30 the aggregate does not cover
            // at all, plus the 24 whose whole volume rests on ten notes or fewer. One slot rather
            // than two because both mean the same thing to a reader — there is not enough here to
            // colour — and a key that named two kinds of absence would invite them to read a
            // distinction that is an artifact of whether one note happened to parse.
            return [String(localized: "semanticMap.legend.noProvenance.v2",
                           defaultValue: "Too few source notes")]
                + SourceProvenanceCategory.allCases.map(\.displayName)
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
        isDownloaded: (String) -> Bool,
        provenanceForVolume: (String) -> SourceProvenanceCategory? = { _ in nil }
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
        case .provenance:
            // Slot 0 is "no source notes", so a volume the aggregate does not cover is visibly a gap
            // rather than silently the first category — which is `centralDecimalFile`, the largest,
            // and would have absorbed every missing volume without a trace.
            for volume in index.volumes {
                guard let range = index.rows(forVolume: volume.volumeID) else { continue }
                let slot: UInt8
                if let category = provenanceForVolume(volume.volumeID),
                   let position = SourceProvenanceCategory.allCases.firstIndex(of: category) {
                    slot = UInt8(1 + position)
                } else {
                    slot = 0
                }
                for row in range where row < colours.count { colours[row] = slot }
            }
        }
        return colours
    }

    /// What a scope does to the map.
    ///
    /// Everything the reader can do to a scoped map needs the same three answers — which rows to
    /// draw brightly, how much is in scope, and which regions still have anything in them — and they
    /// all come from one pass over the volume ranges. Computing them separately is how the count
    /// under the map and the points on it start disagreeing.
    struct ScopeMask: Equatable, Sendable {
        /// One byte per document: `0` in scope, `1` out. **The same array the GPU gets and picking
        /// reads**, which is the point — a mask stored twice is a mask that can differ from itself.
        let flags: [UInt8]
        /// Documents in scope.
        let documentCount: Int
        /// Volumes in scope that the artifact actually covers.
        let volumeCount: Int
        /// Documents in scope per cluster id, for the clusters that have any.
        ///
        /// **Counts rather than a membership set, and the difference is visible on screen.** The
        /// artifact's clusters are whole-corpus, and the label layer ranks by size and keeps the top
        /// dozen — so ranking a scoped map by whole-corpus size gives the labels to the biggest
        /// regions in the *series*, which under a narrow scope may hold three documents each, while
        /// the region the scope actually fills goes unnamed. A region with nothing in scope is absent
        /// entirely rather than present with zero.
        let regionCounts: [UInt16: Int]
    }

    /// Builds the scope mask for a set of volumes.
    ///
    /// - Parameters:
    ///   - volumeIDs: The volumes in scope, or `nil` for the whole series.
    ///   - map: The mapped placements, for cluster membership.
    ///   - index: The vector index, for volume row ranges.
    /// - Returns: The mask, or `nil` for an unscoped map — `nil` rather than an all-zero mask so
    ///   every caller can tell "no scope" from "a scope that happens to include everything", and so
    ///   the unscoped path allocates nothing.
    static func scopeMask(
        volumeIDs: Set<String>?,
        map: SemanticMapVectors,
        index: SemanticVectorIndex
    ) -> ScopeMask? {
        guard let volumeIDs else { return nil }
        // Out by default: a row whose volume is not named is not in scope, and a volume the artifact
        // does not cover contributes nothing rather than silently widening the scope.
        var flags = [UInt8](repeating: 1, count: map.documentCount)
        var documents = 0
        var volumes = 0
        for volume in index.volumes where volumeIDs.contains(volume.volumeID) {
            guard let range = index.rows(forVolume: volume.volumeID) else { continue }
            volumes += 1
            for row in range where row < flags.count {
                flags[row] = 0
                documents += 1
            }
        }
        var regionCounts: [UInt16: Int] = [:]
        map.withPlacements { base, count in
            for row in 0..<min(count, flags.count) where flags[row] == 0 {
                let cluster = base.loadUnaligned(
                    fromByteOffset: row * SemanticMapArtifacts.bytesPerDocument + 4,
                    as: UInt16.self).littleEndian
                if cluster != SemanticMapArtifacts.unclustered {
                    regionCounts[cluster, default: 0] += 1
                }
            }
        }
        return ScopeMask(flags: flags, documentCount: documents,
                         volumeCount: volumes, regionCounts: regionCounts)
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
            // A sequential ramp, dark to light, because era is ordered — but interpolated in
            // **OKLCh**, not in RGB, and the difference is the whole point.
            //
            // The RGB version mixed a blue (0.25, 0.45, 0.85) into a khaki (0.80, 0.80, 0.65) along
            // a straight line, and that line passes close to the grey axis. With only four eras the
            // two interior stops landed on (0.43, 0.57, 0.78) and (0.62, 0.68, 0.72) — a pair of
            // near-identical greys, which is exactly what a reader sees as "no contrast". Mixing two
            // colours on opposite sides of neutral always desaturates the middle; it is a property
            // of the space, not of the endpoints chosen.
            //
            // Interpolating lightness, chroma and HUE separately keeps the middle chromatic. The hue
            // runs *down* from indigo through teal and green to amber rather than taking the short
            // way round through magenta, so lightness climbs monotonically and no two stops share a
            // lightness — the ramp still reads as ordered in greyscale, and stays legible to a
            // reader with red-green colour blindness, for whom the whole path is one axis.
            return (0..<paletteSize).map { index in
                let steps = max(1, CoverageEra.allCases.count - 1)
                let t = Float(min(index, steps)) / Float(steps)
                return oklch(lightness: 0.32 + (0.90 - 0.32) * t,
                             chroma: 0.12 + (0.17 - 0.12) * t,
                             hueDegrees: 272 - 177 * t,
                             alpha: 0.78)
            }
        case .availability:
            return [SIMD4(0.34, 0.36, 0.40, 0.28), SIMD4(0.35, 0.78, 0.52, 0.80)]
                + Array(repeating: SIMD4(0.35, 0.78, 0.52, 0.80), count: paletteSize - 2)
        case .provenance:
            // Categorical, and deliberately NOT the cluster lens's even hue sweep: these ten are a
            // named vocabulary a reader will look up in the legend, so the two central-file
            // categories are neighbouring blues (they are one filing system, renumbered in 1960),
            // presidential libraries and lot files take warm hues, and "no source notes" keeps the
            // dim achromatic slot every lens reserves for absence.
            let hues: [Float] = [0.58, 0.52, 0.08, 0.12, 0.95, 0.75, 0.32, 0.44, 0.68, 0.10]
            let saturations: [Float] = [0.70, 0.55, 0.75, 0.85, 0.60, 0.65, 0.60, 0.55, 0.45, 0.12]
            // `unrecognized` is last, and it is deliberately the DIMMEST of the ten rather than a
            // full-brightness hue. It wins 55 volumes — 9% of the plane — and it means *the parser
            // could not classify these notes*, so drawing it as confidently as "Presidential
            // Libraries" would put the map's loudest claim on its weakest evidence. The first draft
            // gave it saturation 0 at brightness 0.95, i.e. white: the brightest thing on screen.
            let brightnesses: [Float] = [0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.62]
            let categorical = zip(zip(hues, saturations), brightnesses).map { pair, brightness in
                hsb(hue: pair.0, saturation: pair.1, brightness: brightness, alpha: 0.75)
            }
            return ([SIMD4<Float>(0.35, 0.37, 0.42, 0.30)] + categorical
                + Array(repeating: SIMD4<Float>(0.35, 0.37, 0.42, 0.30), count: paletteSize))
                .prefix(paletteSize).map { $0 }
        }
    }

    /// Converts HSB to linear-ish RGBA for the palette.
    /// - Parameters:
    ///   - hue: 0–1.
    ///   - saturation: 0–1.
    ///   - brightness: 0–1.
    ///   - alpha: 0–1.
    /// - Returns: The RGBA colour.
    /// One stop of a perceptual ramp, given in OKLCh and returned as sRGB.
    ///
    /// OKLab is used rather than HSB because HSB's "brightness" is not lightness: a fully saturated
    /// yellow and a fully saturated blue at brightness 0.95 differ by more than half the visible
    /// lightness range, so a ramp built on it climbs unevenly and its middle stops crowd together.
    /// OKLab's L is close enough to perceived lightness that equal steps look equal, which is the
    /// only reason a four-stop ramp can be read as an order at all.
    ///
    /// Returned **gamma-encoded**, matching every other palette here: the renderer's pixel format is
    /// `.bgra8Unorm`, which performs no sRGB decode, so these values reach the screen as written.
    /// Out-of-gamut results are clamped per channel — at the chroma this ramp uses nothing clips,
    /// but a future edit that raises it should degrade to a duller colour rather than a wrapped one.
    ///
    /// - Parameters:
    ///   - lightness: OKLab L, 0…1.
    ///   - chroma: OKLab chroma. Roughly 0…0.4 for displayable colours.
    ///   - hueDegrees: OKLCh hue in degrees.
    ///   - alpha: Straight alpha, passed through untouched.
    /// - Returns: Gamma-encoded sRGB with the given alpha.
    static func oklch(lightness: Float, chroma: Float, hueDegrees: Float, alpha: Float)
        -> SIMD4<Float> {
        let radians = hueDegrees * .pi / 180
        let a = chroma * cos(radians)
        let b = chroma * sin(radians)

        // OKLab -> LMS' -> LMS (Björn Ottosson's matrices).
        let l_ = lightness + 0.3963377774 * a + 0.2158037573 * b
        let m_ = lightness - 0.1055613458 * a - 0.0638541728 * b
        let s_ = lightness - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_

        // LMS -> linear sRGB.
        let red = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let green = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let blue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return SIMD4(gammaEncode(red), gammaEncode(green), gammaEncode(blue), alpha)
    }

    /// Linear sRGB to gamma-encoded sRGB, clamped into gamut.
    /// - Parameter value: One linear channel.
    /// - Returns: The encoded channel, 0…1.
    private static func gammaEncode(_ value: Float) -> Float {
        let clamped = min(max(value, 0), 1)
        return clamped <= 0.0031308
            ? 12.92 * clamped
            : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }

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
