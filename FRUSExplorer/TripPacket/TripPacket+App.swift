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

// The app's half of the packet (FRUS Explorer Light, S30a): the bundled indexes it reads, through the app's
// stores, and the forms the app calls that pass them. The builder, its data source, the model, the exporter and
// their rules are FRUSCoreKit's (`FRUSCoreKit/TripPacket/`), each given the indexes it reads; the derivation,
// which reads SwiftData, and the views stay the app's.
//
// Version history:
//   1.0 — 2026-11-23 (FRUS Explorer Light, S30a): initial implementation, when the packet moved into
//          FRUSCoreKit

// MARK: - TripPacketIndexes.bundled

extension TripPacketIndexes {

    /// The app's bundled indexes, from their stores: the ones the packet read through the app's overload of
    /// the lot's resolution (`ArchivalIndexes.bundled`) and through the model's and the substitutes' default
    /// arguments.
    static var bundled: TripPacketIndexes {
        TripPacketIndexes(archival: .bundled,
                          seriesFacts: SeriesFactsIndexStore.shared,
                          digitizedRanges: DigitizedRangeIndexStore.shared,
                          rollScans: RollScansIndexStore.shared)
    }
}

// MARK: - TripPacketBuilder

@MainActor
extension TripPacketBuilder {

    /// ``build(sourceDocuments:referenceDocuments:researchQuestion:dataSource:indexes:)`` over the app's
    /// bundled indexes: the two-list entry `ArchiveVisitDerivation.derive` calls.
    static func build(
        sourceDocuments: [(volumeId: String, documentId: String)],
        referenceDocuments: [(volumeId: String, documentId: String)],
        researchQuestion: String?,
        dataSource: some TripPacketReferenceDataSource
    ) async -> TripPacketModel {
        await build(sourceDocuments: sourceDocuments, referenceDocuments: referenceDocuments,
                    researchQuestion: researchQuestion, dataSource: dataSource, indexes: .bundled)
    }
}

// MARK: - TripPacketSeed

extension TripPacketSeed {

    /// ``staticSeedDocuments(from:)`` over the collection's entries as the app stores them, each read as its
    /// kind, its document's ids and its place.
    static func staticSeedDocuments(from entries: [CollectionEntry])
        -> [(volumeId: String, documentId: String)] {
        staticSeedDocuments(from: entries.map {
            (kind: $0.entryKind, volumeId: $0.volumeId, documentId: $0.documentId, sortOrder: $0.sortOrder)
        })
    }
}
