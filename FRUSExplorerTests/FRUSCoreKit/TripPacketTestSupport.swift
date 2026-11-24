// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// The packet's builds as its suites have always called them, from before the packet moved into FRUSCoreKit
// (FRUS Explorer Light, S30a): over the bundled indexes wherever a suite names none, as the default arguments
// read them, through the stores. In Xcode those are the app's; in the package, the ones
// `SourceExplorerTestSupport.swift` declares, which decode the same files from the repository. So the moved
// suites call the builder and the model unchanged under both compilers, and the kit's own forms take every
// index from their caller.
//
// Version history:
//   1.0 — 2026-11-23 (FRUS Explorer Light, S30a): initial implementation, for the suites that moved into
//          FRUSCoreKit with the packet

@MainActor
extension TripPacketBuilder {

    /// The one-list build over the bundled indexes, which the builder's suites drive the model through.
    static func build(
        documents: [(volumeId: String, documentId: String)],
        researchQuestion: String?,
        dataSource: some TripPacketReferenceDataSource
    ) async -> TripPacketModel {
        await build(documents: documents, researchQuestion: researchQuestion, dataSource: dataSource,
                    indexes: .bundled)
    }
}

extension TripPacketModel {

    /// `build` as it was declared until the packet moved into FRUSCoreKit: each lookup a suite names none of
    /// reads the bundled stores, as its default argument did, and a pointed-at lot resolves through the bundled
    /// indexes, as the model's own call to the app's one-argument resolution did.
    static func build(
        groups: [(key: String, label: String, category: SourceProvenanceCategory?,
                  repository: String?, lotAsPrinted: String?,
                  resolution: ArchivalResolution?,
                  documents: [Group.DocumentRef])],
        documentYears: [Int?],
        citedFiles: [MandatorySubstitutes.CitedFile] = [],
        unresolvedLotCount: Int,
        unresolvedDocumentCount: Int,
        researchQuestion: String?,
        table: RepositoryFactTable = .current,
        facts: (String) -> SeriesFactsIndex.Facts? = { SeriesFactsIndexStore.shared?.facts(forNaId: $0) },
        substitutes: ([MandatorySubstitutes.CitedFile]) -> MandatorySubstitutes = {
            MandatorySubstitutes.build(citedFiles: $0, ranges: DigitizedRangeIndexStore.shared,
                                       rolls: RollScansIndexStore.shared,
                                       numericalFile: CentralFilesIndexStore.shared?.numericalFile)
        },
        references: [(key: String, form: Target.Form, label: String,
                      repository: String?, lotAsPrinted: String?,
                      seedings: [RefSeeding])] = [],
        referenceCoverage: ReferenceCoverage = .init(documentsWithReferences: 0,
                                                     documentsScanned: 0),
        claimants: (String) -> [LotClaimant]? = {
            LotClaimantsIndexStore.shared?.claimants(forRawLot: $0)
        },
        citedLots: [String: CitedLots] = [:]
    ) -> TripPacketModel {
        build(groups: groups, documentYears: documentYears, citedFiles: citedFiles,
              unresolvedLotCount: unresolvedLotCount, unresolvedDocumentCount: unresolvedDocumentCount,
              researchQuestion: researchQuestion, table: table, facts: facts, substitutes: substitutes,
              references: references, referenceCoverage: referenceCoverage, claimants: claimants,
              lotResolution: { TripPacketIndexes.bundled.lotResolution(lotFile: $0) }, citedLots: citedLots)
    }
}

#if SWIFT_PACKAGE
/// The app's `TripPacketIndexes.bundled` (`TripPacket+App.swift`), over the stores `SourceExplorerTestSupport.swift`
/// declares.
extension TripPacketIndexes {
    static var bundled: TripPacketIndexes {
        TripPacketIndexes(archival: ArchivalIndexes(centralFiles: CentralFilesIndexStore.shared,
                                                    volumeSources: VolumeSourcesIndexStore.shared,
                                                    claimants: LotClaimantsIndexStore.shared),
                          seriesFacts: SeriesFactsIndexStore.shared,
                          digitizedRanges: DigitizedRangeIndexStore.shared,
                          rollScans: RollScansIndexStore.shared)
    }
}
#endif
