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

// In Xcode the Source Explorer suites run inside the app, whose stores decode the bundled indexes from
// `Bundle.main`. The package has neither the app nor its bundle, so it declares the stores the suites
// read, each decoding the same file from the repository's `FRUSExplorer/Resources`: through the kit's
// loader, as a host outside the app does, where the index has one (`init(contentsOf:)`), and with
// `JSONDecoder` otherwise, as the app's store does. Each is `nil` when its file is missing or will not
// decode, as the app's is. So the suites name the same stores under both compilers, and the package
// reads the bundle's bytes.
//
// Version history:
//   1.0 — 2026-11-08 (FRUS Explorer Light, S22a): initial implementation, for the suites that moved
//         into FRUSCoreKit with the readers and resolvers
//   1.1 — 2026-11-10 (FRUS Explorer Light, S22b): the register's store, the roster the app reads from it,
//         and the reader's AST cache, for the suites that moved with the classifier

/// The shipped copy of a JSON file bundled with the app: the app bundle's in Xcode, the repository's
/// `FRUSExplorer/Resources` in the package, as `testManifestURL()` finds the manifest.
func sourceExplorerShippedFile(_ name: String) throws -> URL {
    #if SWIFT_PACKAGE
    sourceExplorerResource(name)
    #else
    try #require(Bundle.main.url(forResource: name, withExtension: "json"), "\(name).json is not in the app bundle")
    #endif
}

#if SWIFT_PACKAGE
/// The repository's copy of a JSON file bundled with the app.
func sourceExplorerResource(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer/Resources/\(name).json")
}

/// The repository's copy of a bundled index with no loader of its own, decoded as its store decodes it.
private func decodedSourceExplorerResource<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
    try? JSONDecoder().decode(type, from: Data(contentsOf: sourceExplorerResource(name)))
}

/// The app's `CollectionAuthorityStore`: `collection-authority.json`.
enum CollectionAuthorityStore {
    static let shared = try? CollectionAuthorityIndex(contentsOf: sourceExplorerResource("collection-authority"))
}

/// The app's `ExternalCitationIndexStore`: `external-citation-index.json`.
enum ExternalCitationIndexStore {
    static let shared = try? ExternalCitationIndex(contentsOf: sourceExplorerResource("external-citation-index"))
}

/// The app's `DigitizedRangeIndexStore`: `digitized-ranges-index.json`.
enum DigitizedRangeIndexStore {
    static let shared = try? DigitizedRangeIndex(contentsOf: sourceExplorerResource("digitized-ranges-index"))
}

/// The app's `RollScansIndexStore`: `roll-scans-index.json`.
enum RollScansIndexStore {
    static let shared = try? RollScansIndex(contentsOf: sourceExplorerResource("roll-scans-index"))
}

/// The app's `SeriesFactsIndexStore`: `series-facts-index.json`.
enum SeriesFactsIndexStore {
    static let shared = try? SeriesFactsIndex(contentsOf: sourceExplorerResource("series-facts-index"))
}

/// The app's `PresidentialLibraryIndexStore`: `presidential-library-catalog.json`.
enum PresidentialLibraryIndexStore {
    static let shared = try? PresidentialLibraryIndex(contentsOf: sourceExplorerResource("presidential-library-catalog"))
}

/// The app's `CuratedLotResolutionsStore`: `curated-lot-resolutions.json`.
enum CuratedLotResolutionsStore {
    static let shared = try? CuratedLotResolutions(contentsOf: sourceExplorerResource("curated-lot-resolutions"))
}

/// The app's `CuratedLibraryResolutionsStore`: `curated-library-resolutions.json`.
enum CuratedLibraryResolutionsStore {
    static let shared = try? CuratedLibraryResolutions(contentsOf: sourceExplorerResource("curated-library-resolutions"))
}

/// The app's `CollectionUsageIndexStore`: `collection-usage-index.json`.
enum CollectionUsageIndexStore {
    static let shared = try? CollectionUsageIndex(contentsOf: sourceExplorerResource("collection-usage-index"))
}

/// The app's `ProvenanceFlowIndexStore`: `provenance-flow-index.json`.
enum ProvenanceFlowIndexStore {
    static let shared = try? ProvenanceFlowIndex(contentsOf: sourceExplorerResource("provenance-flow-index"))
}

/// The app's `SubjectNumericLabelStore`: `subject-numeric-labels.json`.
enum SubjectNumericLabelStore {
    static let shared = try? SubjectNumericLabelTable(contentsOf: sourceExplorerResource("subject-numeric-labels"))
}

/// The app's `CentralFilesIndexStore`: `central-files-index.json`.
enum CentralFilesIndexStore {
    static let shared = decodedSourceExplorerResource(CentralFilesIndex.self, "central-files-index")
}

/// The app's `VolumeSourcesIndexStore`: `volume-sources-index.json`.
enum VolumeSourcesIndexStore {
    static let shared = decodedSourceExplorerResource(VolumeSourcesIndex.self, "volume-sources-index")
}

/// The app's `LotClaimantsIndexStore`: `lot-claimants-index.json`.
enum LotClaimantsIndexStore {
    static let shared = decodedSourceExplorerResource(LotClaimantsIndex.self, "lot-claimants-index")
}

/// The app's `DecimalClassLabelStore`: `decimal-class-labels.json`.
enum DecimalClassLabelStore {
    static let shared = decodedSourceExplorerResource(DecimalClassLabelTable.self, "decimal-class-labels")
}

/// The app's `POCOMIndexStore`: `pocom-index.json`.
enum POCOMIndexStore {
    static let shared = try? POCOMIndex(contentsOf: sourceExplorerResource("pocom-index"))
}

extension ChiefsOfMissionRoster {
    /// The app's `ChiefsOfMissionRoster.bundled`: the register its `POCOMIndexStore` reads.
    static let bundled = ChiefsOfMissionRoster(index: POCOMIndexStore.shared)
}

/// The app's `DocumentASTCache`, as the suites use it: a source that keeps what it is given, by
/// volume and document, with no limit.
actor DocumentASTCache: DocumentASTSource {
    private var documents: [String: FRUSDocumentAST] = [:]

    func ast(volumeId: String, documentId: String) -> FRUSDocumentAST? {
        documents["\(volumeId)/\(documentId)"]
    }

    func store(_ parsed: [FRUSDocumentAST], volumeId: String) {
        for document in parsed { documents["\(volumeId)/\(document.documentId)"] = document }
    }
}
#endif
