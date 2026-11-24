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

/// What the map reads of a volume: its era, its year, and the archival category its notes name most.
///
/// Three per-volume facts the lenses and the slice are drawn by, out of the app so a host reads them
/// from the same files: the era and the year from the manifest's coverage range, the category from the
/// bundled `source-provenance-index.json`. Each is a property of the VOLUME, so every point in a volume
/// takes the same colour and the same height.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S28a — `era(of:)` out of `ManifestStore.eraForVolume(_:)`,
///          and `coverageYear(of:)`, `minimumProvenanceNotes` and `dominantProvenance(byVolume:)` out of
///          `SemanticMapSpikeView`, each of which calls it
public enum SemanticMapVolumes {

    /// The coverage era a volume falls into, from its manifest date range.
    ///
    /// Uses the app's own `CoverageEra` banding rather than a scheme invented at the call site, so
    /// an era-coloured map, an era-split analytics chart and an era-banded feedback log all mean the
    /// same thing by "before 1900".
    ///
    /// - Parameter entry: The volume's manifest entry.
    /// - Returns: The era, or `nil` when the volume has no usable date range.
    public static func era(of entry: VolumeManifestEntry?) -> CoverageEra? {
        guard let entry,
              let earliest = entry.dateRange.earliest.flatMap({ Int($0.prefix(4)) }),
              let latest = entry.dateRange.latest.flatMap({ Int($0.prefix(4)) })
        else { return nil }
        // The midpoint, matching every other era-banding in the app: a volume belongs to exactly one
        // era, and its span is what decides which.
        return CoverageEra.bucket(year: (earliest + latest) / 2)
    }

    /// A volume's coverage midpoint year, for the slice's vertical axis.
    ///
    /// The VOLUME's, not the document's: the manifest knows a coverage range for all 553 volumes,
    /// where a per-document date exists only for volumes a device has indexed. A y-axis that meant
    /// one thing for some rows and another for the rest would be worse than a coarse one that means
    /// the same everywhere — and the slice's caveat says which it is.
    ///
    /// - Parameter entry: The volume's manifest entry.
    /// - Returns: The midpoint year, when the manifest has a range.
    public static func coverageYear(of entry: VolumeManifestEntry?) -> Int? {
        guard let entry else { return nil }
        // The manifest stores coverage as ISO-ish strings; the leading four characters are the year,
        // which is all a vertical axis over 160 years of corpus needs.
        let years = [entry.dateRange.earliest, entry.dateRange.latest]
            .compactMap { $0.flatMap { Int($0.prefix(4)) } }
            .filter { $0 > 1700 && $0 < 2200 }
        guard !years.isEmpty else { return nil }
        return years.reduce(0, +) / years.count
    }

    /// The fewest source notes a volume needs before the lens will colour it.
    ///
    /// **Ten, and the number is a judgement backed by a measurement.** Fifteen of the 523 covered
    /// volumes rest on a single parsed note — `frus1898` carries 1,194 documents on the map and one
    /// note — and the argmax over one note is not a finding about an archive. Twenty-four volumes sit
    /// at ten or fewer and twenty-nine at twenty or fewer, so the curve is flat here and the exact
    /// cut is not load-bearing; what matters is that a volume's colour rests on more than a handful.
    ///
    /// Without it the map drew a boundary a reader could see and could not explain: `frus1898`
    /// (1,194 documents, one note) took the "Other / Unclassified" colour while `frus1899` (810
    /// documents, no notes) took the absence colour, two adjacent volumes of identical editorial
    /// character separated by whether one note happened to parse.
    public static let minimumProvenanceNotes = 10

    /// The category a volume's source notes name most often, when there are enough of them.
    ///
    /// **A plurality, not a majority** — it holds under half the notes for 86 of the 499 volumes
    /// this returns (523 are covered; 24 fall under the floor) — and the caption under the map
    /// says so. Ties break on the category order in
    /// `SourceProvenanceCategory.allCases` rather than arbitrarily, because a Swift dictionary has no
    /// stable iteration order and a tie broken by iteration would recolour the map between launches.
    ///
    /// - Parameter byVolume: The aggregate's per-volume table.
    /// - Returns: The dominant category per volume, omitting volumes below the evidence floor.
    public static func dominantProvenance(
        byVolume: [VolumeProvenance]
    ) -> [String: SourceProvenanceCategory] {
        var result: [String: SourceProvenanceCategory] = [:]
        result.reserveCapacity(byVolume.count)
        for volume in byVolume where volume.totalNotes >= minimumProvenanceNotes {
            var best: SourceProvenanceCategory?
            var bestCount = 0
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
}
