// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - CitableVolumeCatalogueTests

/// The volumes a citation lookup is given by its host (`CitableVolumeCatalogue.swift`): a fixed
/// catalogue outside the app, and the app's `ManifestStore`.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 2: initial implementation
@Suite("FRUSCoreKit — the citation lookup's catalogue")
struct CitableVolumeCatalogueTests {

    @Test("A fixed catalogue answers exactly its entries, in its order")
    func fixedCatalogueAnswersItsEntries() async throws {
        let entries = Array(try testManifestEntries().prefix(3).reversed())
        let catalogue: any CitableVolumeCatalogue = FixedVolumeCatalogue(entries: entries)
        #expect(await catalogue.citableEntries.map(\.volumeId) == entries.map(\.volumeId))
        let empty: any CitableVolumeCatalogue = FixedVolumeCatalogue(entries: [])
        #expect(await empty.citableEntries.isEmpty)
    }

    @Test("A fixed catalogue read from the bundled manifest holds every entry ManifestStore reads from it")
    func fixedCatalogueReadsTheBundledManifest() async throws {
        let entries = try testManifestEntries()
        let catalogue: any CitableVolumeCatalogue = try FixedVolumeCatalogue(contentsOf: try testManifestURL())
        #expect(!entries.isEmpty)
        #expect(await catalogue.citableEntries.map(\.volumeId) == entries.map(\.volumeId))
    }

    @Test("A file that is not a manifest is refused, not read as an empty catalogue")
    func fileThatIsNotAManifestThrows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCatalogueTests-\(UUID().uuidString).json")
        try Data(#"{"volumes": []}"#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: (any Error).self) { try FixedVolumeCatalogue(contentsOf: url) }
    }

    #if !SWIFT_PACKAGE // ManifestStore is the app's
    @Test("The app's ManifestStore, taken as a catalogue, answers its bundled entries (#1523)")
    @MainActor
    func manifestStoreAnswersItsBundledEntries() async throws {
        let entries = Array(try testManifestEntries().prefix(5))
        let store = ManifestStore(bundledEntries: entries)
        let catalogue: any CitableVolumeCatalogue = store
        #expect(await catalogue.citableEntries.map(\.volumeId) == store.bundledEntries.map(\.volumeId))
        #expect(await catalogue.citableEntries.map(\.volumeId) == entries.map(\.volumeId))
    }
    #endif
}
