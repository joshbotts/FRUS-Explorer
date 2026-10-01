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

    // MARK: A shortened name's full text (#1468)

    @Test("The full text kept for a shortened name survives the alias cap")
    func fullTextAliasIsExemptFromTheCap() {
        var aliases: Set<String> = []
        for i in 0..<30 { aliases.insert("Alias Form Number \(String(format: "%02d", i))") }
        let paragraph = "Indexed Central Files. The main source of documentation for these volumes was "
            + "the Department of State’s indexed central files, arranged by subject and country."
        let capped = AuthorityBuilder.cappedAliases(aliases, excludingName: "Indexed Central Files",
                                                    exempt: [paragraph])
        // The cap keeps the shortest forms, so the paragraph — the longest — went first.
        #expect(capped.contains(paragraph))
        #expect(capped.count == AuthorityBuilder.aliasCap + 1)
        #expect(capped == capped.sorted())
        #expect(capped.filter { $0 != paragraph }
                == AuthorityBuilder.cappedAliases(aliases, excludingName: "Indexed Central Files"))
    }

    @Test("An exempt alias is listed once, and never when it is the name")
    func exemptAliasIsDeduplicated() {
        let capped = AuthorityBuilder.cappedAliases(["Short Form", "Long  Form Text"],
                                                    excludingName: "The Name",
                                                    exempt: ["Long Form Text", "the name."])
        #expect(capped == ["Long  Form Text", "Short Form"], "\(capped)")
    }

    @Test("A record named by its printed title carries its paragraph as an alias past the cap")
    func buildKeepsTheParagraph() throws {
        let paragraph = "Indexed Central Files. The main source of documentation for Foreign Relations, "
            + "1961–1963, Volumes XVII and XVIII was the Department of State’s indexed central files."
        var refs = ["v17", "v18"].map {
            CollectionReference(volumeId: $0, origin: .frontMatter, repository: "Department of State",
                                recordGroup: "59", leadingSegment: "Indexed Central Files",
                                displayName: "Indexed Central Files", fullTextAlias: paragraph)
        }
        // Fourteen shorter forms the same record is cited by, more than the cap keeps.
        for i in 0..<14 {
            refs.append(CollectionReference(
                volumeId: "v\(i)", origin: .frontMatter, repository: "Department of State",
                recordGroup: "59", leadingSegment: "Indexed Central Files",
                displayName: "Indexed Central Files, form \(String(format: "%02d", i))"))
        }
        let record = try #require(AuthorityBuilder.build(references: refs, resolver: nil).collections.first)
        #expect(record.id == "txt:department of state|indexed central file")
        #expect(record.name == "Indexed Central Files")
        #expect(record.aliases.contains(paragraph))
        #expect(record.aliases.count == AuthorityBuilder.aliasCap + 1, "\(record.aliases.count) aliases")
    }

    @Test("Only the paragraph the name was voted from is kept past the cap; another competes under it")
    func onlyTheVotedParagraphIsExempt() throws {
        let voted = "Indexed Central Files. The main source of documentation for these volumes, cited by two."
            + " It is the record's paragraph."
        let other = "Indexed Central Files. Another volume's own account of the same files, cited by one only,"
            + " and longer than every short form."
        var refs = ["v17", "v18"].map {
            CollectionReference(volumeId: $0, origin: .frontMatter, repository: "Department of State",
                                recordGroup: "59", leadingSegment: "Indexed Central Files",
                                displayName: "Indexed Central Files", fullTextAlias: voted)
        }
        refs.append(CollectionReference(volumeId: "v20", origin: .frontMatter, repository: "Department of State",
                                        recordGroup: "59", leadingSegment: "Indexed Central Files",
                                        displayName: "Indexed Central Files", fullTextAlias: other))
        for i in 0..<14 {
            refs.append(CollectionReference(
                volumeId: "v\(i)", origin: .documentNote, repository: "Department of State",
                recordGroup: "59", leadingSegment: "Indexed Central Files",
                displayName: "ICF form \(String(format: "%02d", i))"))
        }
        let record = try #require(AuthorityBuilder.build(references: refs, resolver: nil).collections.first)
        #expect(record.name == "Indexed Central Files")
        #expect(record.aliases.contains(voted))
        #expect(!record.aliases.contains(other), "the cap keeps twelve shorter forms ahead of it")
        #expect(record.aliases.count == AuthorityBuilder.aliasCap + 1, "\(record.aliases.count) aliases")
    }

    @Test("The kept paragraph is the record's former name, counted as the name was, sub-series votes included")
    func theFormerNameCountsSubSeriesVotes() throws {
        // One item each, but v17's carries a sub-series, whose reference voted its parent's
        // paragraph too: before the title rule that paragraph won the name 2–1. "Another…" sorts
        // first, so counting items alone would tie and keep the wrong one.
        let former = "Indexed Central Files. The main source of documentation for these volumes, with a"
            + " sub-series printed beneath it."
        let other = "Indexed Central Files. Another volume's own account of the same files, printed alone"
            + " and longer than every short form."
        let title = "Indexed Central Files"
        var refs = [
            CollectionReference(volumeId: "v17", origin: .frontMatter, repository: "Department of State",
                                recordGroup: "59", leadingSegment: title, displayName: title,
                                fullTextAlias: former),
            CollectionReference(volumeId: "v17", origin: .frontMatter, repository: "Department of State",
                                recordGroup: "59", leadingSegment: title, subSegment: "Telegrams",
                                displayName: title, fullTextAlias: former),
            CollectionReference(volumeId: "v20", origin: .frontMatter, repository: "Department of State",
                                recordGroup: "59", leadingSegment: title, displayName: title,
                                fullTextAlias: other),
        ]
        for i in 0..<14 {
            refs.append(CollectionReference(
                volumeId: "v\(i)", origin: .documentNote, repository: "Department of State",
                recordGroup: "59", leadingSegment: title,
                displayName: "ICF form \(String(format: "%02d", i))"))
        }
        let record = try #require(AuthorityBuilder.build(references: refs, resolver: nil).collections.first)
        #expect(record.name == title)
        #expect(record.aliases.contains(former), "\(record.aliases)")
        #expect(!record.aliases.contains(other))
        // Under the cap, every paragraph is an alias, as every name variant always was.
        let uncapped = try #require(AuthorityBuilder.build(references: Array(refs.prefix(3)),
                                                           resolver: nil).collections.first)
        #expect(uncapped.aliases.contains(former) && uncapped.aliases.contains(other), "\(uncapped.aliases)")
    }

    @Test("A record whose name the title rule did not change gains no alias")
    func anUnchangedNameGainsNothing() throws {
        // Its former name is its name, which is never an alias.
        let refs = [CollectionReference(volumeId: "v1", origin: .frontMatter, repository: "Johnson Library",
                                        leadingSegment: "National Security File",
                                        displayName: "National Security File, Country File")]
        let record = try #require(AuthorityBuilder.build(references: refs, resolver: nil).collections.first)
        #expect(record.name == "National Security File, Country File")
        #expect(record.aliases == ["National Security File"])
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

    /// #1466: the report prints every ambiguous cluster involving the unattributed bucket, past the
    /// listing cap — the shape a collection that lost its repository takes — and counts the rest.
    @Test func reportListsEveryUnattributedClusterPastTheCap() {
        let clusters = [
            AuthorityBuilder.AmbiguousCluster(segment: "nsc file",
                                              repositories: ["Eisenhower Library", "Truman Library"]),
            AuthorityBuilder.AmbiguousCluster(segment: "country file",
                                              repositories: ["Johnson Library", "Kennedy Library"]),
            AuthorityBuilder.AmbiguousCluster(segment: "whitman file",
                                              repositories: ["(unattributed)", "Eisenhower Library"]),
        ]
        let lines = CollectionAuthorityRunner.ambiguousClusterLines(clusters, listed: 1)
        #expect(lines == [
            "  nsc file  ←  Eisenhower Library | Truman Library",
            "  whitman file  ←  (unattributed) | Eisenhower Library",
            "  … 1 more, none involving (unattributed)",
        ])
    }
}
