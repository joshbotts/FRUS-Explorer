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

// MARK: - SourceExplorerIndexLoadingTests

/// The loaders of Source Explorer's twelve bundled indexes (`init(contentsOf:)`), which a host outside the
/// app calls with the file where it keeps it: the eleven S22a moved, and the register S22b moved with the
/// classifier; and the decimal-class label table's, which the archival derivations take (S24c).
///
/// Each loader decodes what the app's store decodes, so this suite holds the two together: in Xcode it
/// loads the app bundle's copy and compares the index with the store's, file by file; in the package,
/// whose stores are the suites' own over the same loaders (`SourceExplorerTestSupport.swift`), it loads
/// the repository's copy. Either way every shipped file must load and hold something, and a file that is
/// not there must throw rather than load as an empty index.
///
/// Version history:
///   1.0 — 2026-11-08 (FRUS Explorer Light, S22a): initial implementation
///   1.1 — 2026-11-10 (FRUS Explorer Light, S22b): the register, `POCOMIndex`
///   1.2 — 2026-11-12 (FRUS Explorer Light, S24c): the decimal-class label table, `DecimalClassLabelTable`
@Suite("FRUSCoreKit — Source Explorer's indexes, loaded from a URL")
struct SourceExplorerIndexLoadingTests {

    /// Loads `name` through `load`, requires it to hold something, and holds its stamp and size to the
    /// store's.
    private func expectLoads<Index>(_ name: String, _ load: (URL) throws -> Index, store: Index?,
                                    _ facts: (Index) -> (generated: String, version: Int, count: Int)) throws {
        let loaded = facts(try load(try sourceExplorerShippedFile(name)))
        let stored = facts(try #require(store, "\(name).json: the store holds no index"))
        #expect(loaded.count > 0 && !loaded.generated.isEmpty, "\(name).json loaded \(loaded.count) rows, stamped \(loaded.generated)")
        #expect(loaded.generated == stored.generated && loaded.version == stored.version && loaded.count == stored.count,
                "\(name).json: loaded \(loaded), the store \(stored)")
    }

    @Test("Each index loads from the URL it is given, as the app's store loads the bundle's copy")
    func eachIndexLoadsAsItsStoreDoes() throws {
        try expectLoads("collection-authority", CollectionAuthorityIndex.init(contentsOf:),
                        store: CollectionAuthorityStore.shared) { ($0.generated, $0.schemaVersion, $0.collections.count) }
        try expectLoads("external-citation-index", ExternalCitationIndex.init(contentsOf:),
                        store: ExternalCitationIndexStore.shared) { ($0.generated, $0.schemaVersion, $0.targets.count) }
        try expectLoads("digitized-ranges-index", DigitizedRangeIndex.init(contentsOf:),
                        store: DigitizedRangeIndexStore.shared) { ($0.generated, $0.schemaVersion, $0.ranges.count) }
        try expectLoads("roll-scans-index", RollScansIndex.init(contentsOf:),
                        store: RollScansIndexStore.shared) { ($0.generated, $0.schemaVersion, $0.scans.count) }
        try expectLoads("series-facts-index", SeriesFactsIndex.init(contentsOf:),
                        store: SeriesFactsIndexStore.shared) { ($0.generated, $0.schemaVersion, $0.byNaId.count) }
        try expectLoads("presidential-library-catalog", PresidentialLibraryIndex.init(contentsOf:),
                        store: PresidentialLibraryIndexStore.shared) { ($0.generated, $0.schemaVersion, $0.libraries.count) }
        try expectLoads("curated-lot-resolutions", CuratedLotResolutions.init(contentsOf:),
                        store: CuratedLotResolutionsStore.shared) { ($0.generated, $0.schemaVersion, $0.lots.count) }
        try expectLoads("curated-library-resolutions", CuratedLibraryResolutions.init(contentsOf:),
                        store: CuratedLibraryResolutionsStore.shared) { ($0.generated, $0.schemaVersion, $0.entries.count) }
        try expectLoads("collection-usage-index", CollectionUsageIndex.init(contentsOf:),
                        store: CollectionUsageIndexStore.shared) { ($0.generated, $0.schemaVersion, $0.collections.count) }
        try expectLoads("provenance-flow-index", ProvenanceFlowIndex.init(contentsOf:),
                        store: ProvenanceFlowIndexStore.shared) { ($0.generated, $0.schemaVersion, $0.collectionFlows.count) }
        try expectLoads("subject-numeric-labels", SubjectNumericLabelTable.init(contentsOf:),
                        store: SubjectNumericLabelStore.shared) { ($0.generated, $0.schemaVersion, $0.schedules.count) }
        try expectLoads("decimal-class-labels", DecimalClassLabelTable.init(contentsOf:),
                        store: DecimalClassLabelStore.shared) { ($0.generated, $0.schemaVersion, $0.schedules.count) }
        // The register, which the classifier's addressee rule reads through `ChiefsOfMissionRoster` (S22b).
        try expectLoads("pocom-index", POCOMIndex.init(contentsOf:),
                        store: POCOMIndexStore.shared) { ($0.generated, $0.version, $0.chiefTerritoryIds.count) }
    }

    @Test("A file that is not there throws, rather than loading as an empty index")
    func aMissingFileThrows() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("no-such-index-\(UUID().uuidString).json")
        let loaders: [(String, (URL) throws -> Void)] = [
            ("CollectionAuthorityIndex", { _ = try CollectionAuthorityIndex(contentsOf: $0) }),
            ("POCOMIndex", { _ = try POCOMIndex(contentsOf: $0) }),
            ("ExternalCitationIndex", { _ = try ExternalCitationIndex(contentsOf: $0) }),
            ("DigitizedRangeIndex", { _ = try DigitizedRangeIndex(contentsOf: $0) }),
            ("RollScansIndex", { _ = try RollScansIndex(contentsOf: $0) }),
            ("SeriesFactsIndex", { _ = try SeriesFactsIndex(contentsOf: $0) }),
            ("PresidentialLibraryIndex", { _ = try PresidentialLibraryIndex(contentsOf: $0) }),
            ("CuratedLotResolutions", { _ = try CuratedLotResolutions(contentsOf: $0) }),
            ("CuratedLibraryResolutions", { _ = try CuratedLibraryResolutions(contentsOf: $0) }),
            ("CollectionUsageIndex", { _ = try CollectionUsageIndex(contentsOf: $0) }),
            ("ProvenanceFlowIndex", { _ = try ProvenanceFlowIndex(contentsOf: $0) }),
            ("SubjectNumericLabelTable", { _ = try SubjectNumericLabelTable(contentsOf: $0) }),
            ("DecimalClassLabelTable", { _ = try DecimalClassLabelTable(contentsOf: $0) }),
        ]
        for (name, load) in loaders {
            #expect(throws: (any Error).self, "\(name) loaded a file that is not there") { try load(missing) }
        }
    }
}
