// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import CollectionAuthorityGeneratorCore

/// Two-level merge, conservative-merge guardrails, and deterministic output.
@Suite struct AuthorityBuilderTests {

    // MARK: Two-level merge

    @Test func sameLotNormAlwaysMerges() {
        let refs = [
            CollectionReference(volumeId: "v1", origin: .frontMatter,
                                repository: "Department of State", recordGroup: "59",
                                lotFileNorm: "64D199", rawLot: "64 D 199",
                                displayName: "Lot 64 D 199, Records of the Policy Planning Staff"),
            CollectionReference(volumeId: "v2", origin: .documentNote,
                                repository: "Department of State", recordGroup: "59",
                                lotFileNorm: "64D199", rawLot: "64–D 199",
                                seriesAlias: "PPS Files"),
        ]
        let result = AuthorityBuilder.build(references: refs, resolver: nil)
        #expect(result.collections.count == 1)
        let record = result.collections[0]
        #expect(record.id == "lot:64D199")
        #expect(record.volumeIds == ["v1", "v2"])
        // Front-matter display name wins; variants and the named series are aliases.
        #expect(record.name == "Lot 64 D 199, Records of the Policy Planning Staff")
        #expect(record.aliases.contains("PPS Files"))
        #expect(record.aliases.contains("64 D 199"))
    }

    @Test func textualMergeRequiresSameRepositoryAndSegment() {
        let refs = [
            CollectionReference(volumeId: "v1", origin: .frontMatter,
                                repository: "Johnson Library",
                                leadingSegment: "National Security File",
                                displayName: "National Security File"),
            CollectionReference(volumeId: "v2", origin: .documentNote,
                                repository: "Johnson Library",
                                leadingSegment: "National  Security File"),
            CollectionReference(volumeId: "v3", origin: .documentNote,
                                repository: "Kennedy Library",
                                leadingSegment: "National Security File"),
            CollectionReference(volumeId: "v4", origin: .documentNote,
                                repository: "Kennedy Library",
                                leadingSegment: "National Security File"),
        ]
        let result = AuthorityBuilder.build(references: refs, resolver: nil)
        // Johnson NSF and Kennedy NSF stay separate records.
        #expect(result.collections.count == 2)
        let johnson = result.collections.first { $0.repository == "Johnson Library" }
        #expect(johnson?.volumeIds == ["v1", "v2"])
        // And the collision is reported as an ambiguous cluster left unmerged.
        #expect(result.ambiguous.contains {
            $0.segment == "national security file"
                && $0.repositories == ["johnson library", "kennedy library"]
        })
    }

    @Test func unattributedSeriesNeverMergeIntoAttributedRecords() {
        let refs = [
            CollectionReference(volumeId: "v1", origin: .documentNote,
                                repository: nil, leadingSegment: "Conference Files"),
            CollectionReference(volumeId: "v2", origin: .documentNote,
                                repository: nil, leadingSegment: "Conference Files"),
            CollectionReference(volumeId: "v3", origin: .frontMatter,
                                repository: "Department of State",
                                leadingSegment: "Conference Files",
                                displayName: "Conference Files"),
        ]
        let result = AuthorityBuilder.build(references: refs, resolver: nil)
        #expect(result.collections.count == 2)
        // Ambiguity buckets carry the plural-folded segment form.
        #expect(result.ambiguous.contains { $0.segment == "conference file" })
    }

    @Test func subSeriesMergeUnderTheirCollection() {
        let refs = [
            CollectionReference(volumeId: "v1", origin: .frontMatter,
                                repository: "Johnson Library",
                                leadingSegment: "National Security File",
                                subSegment: "Country File",
                                displayName: "National Security File"),
            CollectionReference(volumeId: "v2", origin: .documentNote,
                                repository: "Johnson Library",
                                leadingSegment: "National Security File",
                                subSegment: "Country  File"),
        ]
        let result = AuthorityBuilder.build(references: refs, resolver: nil)
        #expect(result.collections.count == 1)
        let children = result.collections[0].children
        #expect(children.count == 1)
        #expect(children[0].name == "Country File")
        #expect(children[0].volumeIds == ["v1", "v2"])
    }

    @Test func classChildrenShipFrontMatterVolumesOnly() {
        let refs = [
            CollectionReference(volumeId: "v1", origin: .frontMatter,
                                repository: "Department of State",
                                leadingSegment: "Central Files 1967–69",
                                subDecimalClass: "POL 27 ARAB-ISR",
                                displayName: "Central Files 1967–69"),
            CollectionReference(volumeId: "v2", origin: .documentNote,
                                repository: "Department of State",
                                leadingSegment: "Central Files 1967–69",
                                subDecimalClass: "POL 27 ARAB-ISR"),
        ]
        let result = AuthorityBuilder.build(references: refs, resolver: nil)
        #expect(result.collections.count == 1)
        let child = result.collections[0].children.first
        #expect(child?.decimalClass == "POL 27 ARAB-ISR")
        // S5: doc-side citing documents are recomputed locally; the artifact ships
        // only the front-matter citing volumes for class children.
        #expect(child?.volumeIds == ["v1"])
    }

    // MARK: Size discipline

    @Test func docNoteOnlySingletonsAreExcluded() {
        let refs = [
            CollectionReference(volumeId: "v1", origin: .documentNote,
                                repository: "Kennedy Library",
                                leadingSegment: "President's Office Files"),
        ]
        let result = AuthorityBuilder.build(references: refs, resolver: nil)
        #expect(result.collections.isEmpty)
    }

    @Test func aliasListsAreCappedAndExcludeTheCanonicalName() {
        var aliases: Set<String> = []
        for i in 0..<30 { aliases.insert("Alias Form Number \(String(format: "%02d", i))") }
        aliases.insert("The Name")
        let capped = AuthorityBuilder.cappedAliases(aliases, excludingName: "The  Name")
        #expect(capped.count == AuthorityBuilder.aliasCap)
        #expect(!capped.contains("The Name"))
        #expect(capped == capped.sorted())
    }

    // MARK: Determinism

    @Test func buildIsOrderIndependentAndByteDeterministic() throws {
        let refs = [
            CollectionReference(volumeId: "v2", origin: .documentNote,
                                repository: "Johnson Library",
                                leadingSegment: "National Security File",
                                subSegment: "Country File"),
            CollectionReference(volumeId: "v1", origin: .frontMatter,
                                repository: "Johnson Library",
                                leadingSegment: "National Security File",
                                subSegment: "Agency File",
                                displayName: "National Security File"),
            CollectionReference(volumeId: "v3", origin: .frontMatter,
                                repository: "Department of State", recordGroup: "59",
                                lotFileNorm: "64D199", rawLot: "64 D 199",
                                displayName: "Lot 64 D 199"),
            CollectionReference(volumeId: "v4", origin: .documentNote,
                                repository: "Department of State", recordGroup: "59",
                                lotFileNorm: "64D199", rawLot: "64–D199"),
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let a = AuthorityBuilder.build(references: refs, resolver: nil)
        let b = AuthorityBuilder.build(references: refs.reversed(), resolver: nil)
        let bytesA = try encoder.encode(CollectionAuthorityIndex(
            schemaVersion: 1, generated: "2026-07-03", collections: a.collections))
        let bytesB = try encoder.encode(CollectionAuthorityIndex(
            schemaVersion: 1, generated: "2026-07-03", collections: b.collections))
        #expect(bytesA == bytesB)
        #expect(a.collections.map(\.id) == a.collections.map(\.id).sorted())
    }
}
