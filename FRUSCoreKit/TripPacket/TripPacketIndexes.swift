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

// MARK: - TripPacketIndexes

/// The bundled indexes an Archives Visit's packet reads, as a host loaded them: the three a document's lot
/// resolves through (``ArchivalIndexes``: `central-files-index.json`, `volume-sources-index.json` and
/// `lot-claimants-index.json`, whose divided lots the model reads too), the series facts a target's
/// facility, years and access come from (`series-facts-index.json`), and the two indexes the A6 substitutes
/// are found in (`digitized-ranges-index.json` and `roll-scans-index.json`, with central files' 1906–1910
/// numerical file). Each is `nil` when it could not be read, which finds nothing through it, as each of the
/// app's stores answers when its file is missing.
///
/// ``TripPacketBuilder`` takes them where the packet's code named the app's stores in default arguments.
/// The app passes its bundle's (`TripPacketIndexes.bundled`, over the stores); a host outside the app decodes
/// the same files and passes them in, so its packet resolves, places and checks the same targets.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S30a): initial implementation, when the packet moved into
///          FRUSCoreKit
public struct TripPacketIndexes: Sendable {
    /// The three indexes a document's lot resolves through, the claimants among them.
    public var archival: ArchivalIndexes
    /// The series facts: a series' reference unit, years and access.
    public var seriesFacts: SeriesFactsIndex?
    /// NARA's digitised decimal-file ranges.
    public var digitizedRanges: DigitizedRangeIndex?
    /// The M862 rolls' scans, for their image counts.
    public var rollScans: RollScansIndex?

    /// Creates the set; every index defaults to none.
    public init(archival: ArchivalIndexes = ArchivalIndexes(), seriesFacts: SeriesFactsIndex? = nil,
                digitizedRanges: DigitizedRangeIndex? = nil, rollScans: RollScansIndex? = nil) {
        self.archival = archival
        self.seriesFacts = seriesFacts
        self.digitizedRanges = digitizedRanges
        self.rollScans = rollScans
    }

    /// The series facts for `naId`: the model's `facts` lookup.
    public func facts(forNaId naId: String) -> SeriesFactsIndex.Facts? {
        seriesFacts?.facts(forNaId: naId)
    }

    /// The series NARA divides a lot across, given the lot as printed: the model's `claimants` lookup.
    public func claimants(forRawLot lot: String) -> [LotClaimant]? {
        archival.claimants?.claimants(forRawLot: lot)
    }

    /// A lot's resolution, given the lot as printed, through the archival three: the model's `lotResolution`
    /// lookup, for a lot only the footnotes cite, and the route the builder resolves the others by.
    public func lotResolution(lotFile: String) -> ArchivalResolution? {
        ArchivalResolver.documentResolution(lotFile: lotFile, indexes: archival)
    }

    /// The A6 substitutes for `citedFiles`, over the two substitute indexes and central files' numerical
    /// file: the model's `substitutes` lookup.
    public func substitutes(citedFiles: [MandatorySubstitutes.CitedFile]) -> MandatorySubstitutes {
        MandatorySubstitutes.build(citedFiles: citedFiles, ranges: digitizedRanges, rolls: rollScans,
                                   numericalFile: archival.centralFiles?.numericalFile)
    }
}
