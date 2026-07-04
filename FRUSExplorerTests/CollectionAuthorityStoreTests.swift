// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - CollectionAuthorityStoreTests

/// Exercises `CollectionAuthorityStore` over the **real bundled artifact**
/// (`collection-authority.json`): the decode, and the documented lookup order —
/// lot key, repository-scoped text key, unattributed bucket, unambiguous alias —
/// plus the shared `CollectionKeying` derivations the lookups ride on
/// (Source Explorer Phase 4 step 2).
///
/// Version history:
///   1.0 — Session 2026-07-03: initial implementation
@Suite("CollectionAuthorityStore — bundled artifact lookups")
struct CollectionAuthorityStoreTests {

    /// The bundled index, required by every test in the suite.
    private func index() throws -> CollectionAuthorityIndex {
        try #require(CollectionAuthorityStore.shared,
                     "collection-authority.json must decode from the app bundle")
    }

    @Test("The bundled artifact decodes with the expected shape")
    func artifactDecodes() throws {
        let index = try index()
        #expect(index.schemaVersion == 1)
        #expect(index.collections.count > 4000,
                "the Phase 4 artifact carries ~4,464 records; got \(index.collections.count)")
    }

    @Test("Lot lookup (order step 1): the canonical compact key resolves the record")
    func lotLookup() throws {
        let index = try index()
        let record = try #require(index.record(forLotNorm: "64D199"),
                                  "Lot 64 D 199 (PPS-era Secretary's memoranda) is a corpus staple")
        #expect(record.id == "lot:64D199")
        #expect(record.repository == "Department of State")
        #expect(record.naId == "602231", "the offline NAID resolution ships in the artifact")
        #expect(record.url?.absoluteString.contains("catalog.archives.gov") == true)
        #expect(record.volumeIds.count > 10, "cited across dozens of volumes")
    }

    @Test("Text lookup (order step 2) bridges full library names to the keyword bucket")
    func repositoryScopedTextLookup() throws {
        let index = try index()
        // The full name canonicalizes to "Johnson Library" — the same bridging the
        // generator applied, so the lookup lands in the same bucket.
        let record = try #require(index.record(
            repository: "Lyndon B. Johnson Library",
            leadingSegment: "National Security File"))
        #expect(record.id == "txt:johnson library|national security file")
        #expect(!record.children.isEmpty, "NSF carries sub-series (Country File, …)")
    }

    @Test("Unattributed bucket (order step 3) is reached when the repo-scoped key misses")
    func unattributedFallback() throws {
        let index = try index()
        // "Administrative and Staff Files" is an unattributed doc-note series in the
        // artifact (no Department-of-State bucket exists for it); querying it WITH a
        // repository must still find it through the unattributed bucket, per the
        // documented order — and the bare query resolves the same record directly.
        let viaRepo = try #require(index.record(repository: "Department of State",
                                                leadingSegment: "Administrative and Staff Files"))
        #expect(viaRepo.id == "txt:|administrative and staff files")
        let bare = index.record(repository: nil,
                                leadingSegment: "Administrative and Staff Files")
        #expect(bare?.id == viaRepo.id)
    }

    @Test("Alias lookup (order step 4): unique forms resolve, shared forms never do")
    func aliasLookup() throws {
        let index = try index()
        // A form unique to Lot 64 D 199 (an editor's typo the corpus actually prints).
        let unique = index.uniqueRecord(
            forAliasNorm: CollectionKeying.normalized("Secretary’s Memoranda of Conservation, Lot 64 D 199"))
        #expect(unique?.id == "lot:64D199")
        // "PPS Files" is carried by many lot records — ambiguous, must not resolve.
        #expect(index.uniqueRecord(forAliasNorm: CollectionKeying.normalized("PPS Files")) == nil,
                "a shared alias may never route to one collection")
    }

    @Test("Parsed-note lookup: a lot citation lands on its lot record")
    func parsedLotNote() throws {
        let index = try index()
        let note = "Source: Department of State, Secretary’s Memoranda of Conversation, Lot 64 D 199. Secret."
        let parsed = ParsedSourceNote.lotFile(recordGroup: "RG-59",
                                              lotNumber: "64 D 199", fileIdentifier: nil)
        let record = try #require(index.record(forParsed: parsed, note: note))
        #expect(record.id == "lot:64D199")
    }

    @Test("Parsed-note lookup: a presidential-library citation lands on its text record")
    func parsedLibraryNote() throws {
        let index = try index()
        let note = "Source: Johnson Library, National Security File, Country File, Vietnam, Box 1. Secret."
        let parsed = ParsedSourceNote.presidentialLibrary(
            library: "Johnson Library",
            collection: "National Security File, Country File, Vietnam",
            fileIdentifier: nil)
        let record = try #require(index.record(forParsed: parsed, note: note))
        #expect(record.id == "txt:johnson library|national security file",
                "the leading merge segment (not the full locator chain) is the identity")
    }

    @Test("Front-matter lookup: a class leaf under the central files takes the DoS override")
    func frontMatterCentralFilesOverride() throws {
        let index = try index()
        // Front matter nests the central files under a National Archives heading, but
        // the shared identity forces the Department of State bucket — the same
        // override the generator applied, so the row joins its doc-note siblings.
        let record = try #require(index.record(
            forFrontMatterText: "Central Files 1967–69: POL 27 ARAB–ISR",
            repository: "National Archives",
            lotFileNorm: nil,
            decimalClass: "POL 27 ARAB-ISR"))
        #expect(record.id == "txt:department of state|central files 1967-69")
        #expect(record.repository == "Department of State")
    }

    @Test("Front-matter lookup: a lot-keyed row resolves through its lot, not its text")
    func frontMatterLotRow() throws {
        let index = try index()
        let record = try #require(index.record(
            forFrontMatterText: "Secretary’s Memoranda of Conversation: Lot 64 D 199",
            repository: "National Archives",
            lotFileNorm: "64D199",
            decimalClass: nil))
        #expect(record.id == "lot:64D199")
    }
}
